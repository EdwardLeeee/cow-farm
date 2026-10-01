"""HTTP 與 WebSocket 端點（協定 v2，文件在 docs/protocol.md；路徑維持 /v1）。

- 全部 JSON；除了 POST /v1/session 以外都要 Authorization: Bearer <token>。
- 會改狀態的請求都帶 request_id（UUID）；同一位玩家同一個 request_id 重送，回第一次的回應。
- 錯誤一律 {"error": {"code": "...", "message": "<繁中>"}}，HTTP 4xx（伺服器錯誤 500）。app 依 code 查字串表，
  message 只供除錯。
- COWFARM_WEB_DIR 指向 Flutter 網頁版的輸出（app/build/web）時，在 / 提供網頁；資料夾不存在就略過。
"""

from __future__ import annotations

import json
import logging
import time
import uuid
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any, Literal, Optional

from fastapi import Depends, FastAPI, Header, Query, Request, WebSocket, WebSocketDisconnect
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, ConfigDict
from starlette.exceptions import HTTPException as StarletteHTTPException

from . import views as V
from .config import Config
from .game import GameError, Player, ship_value
from .runtime import GameServer
from .store import Store

log = logging.getLogger("cowfarm")


# ---------------------------------------------------------------------------
# 請求格式（多的欄位忽略，方便日後只加不改）
# ---------------------------------------------------------------------------
class _Req(BaseModel):
    model_config = ConfigDict(extra="ignore")


class ActionReq(_Req):
    request_id: str


class SessionReq(_Req):
    ranch_name: Any  # 字串；在 runtime 檢查（協定 2.2 節）
    request_id: Optional[str] = None  # 選填：網路逾時重送時不會多建一個牧場


class QuoteReq(_Req):
    commodity: Literal["milk", "beef", "rice"]
    qty: Any  # 數字；在服務層嚴格檢查（不接受字串或 true/false）


class SellReq(QuoteReq):
    request_id: str


class ShipReq(_Req):
    cow_id: Any
    request_id: str


class BreedReq(_Req):
    sire: Any
    dam: Any
    request_id: str


class UpgradeReq(_Req):
    kind: Literal["pen", "bucket", "warehouse", "fresh", "field"]
    request_id: str


# ---- v0.2 ----
class ShopBuyReq(_Req):
    grade: Literal["A", "B", "C"]
    request_id: str


class FieldAssignReq(_Req):
    cow_id: Any
    field: Any = None  # 田的編號（從 0 開始）；沒給就找第一塊空田
    request_id: str


class CowActionReq(_Req):
    cow_id: Any
    request_id: str


class StudListReq(_Req):
    cow_id: Any  # D26 起不收 price（借種費由系統算；有送也忽略）
    request_id: str


class StudUnlistReq(_Req):
    listing_id: Any
    request_id: str


class StudBorrowReq(_Req):
    listing_id: Any
    dam: Any
    price: Any  # 預覽時看到的借種費；跟現在的不一樣回 409 price_changed（D26）
    request_id: str


def _rid(v: str) -> str:
    try:
        return str(uuid.UUID(v))
    except (ValueError, AttributeError, TypeError):
        raise GameError("bad_request", "request_id 要是 UUID", 400)


def _err(status: int, code: str, message: str, detail: Optional[dict] = None) -> JSONResponse:
    body = {"error": {"code": code, "message": message}}
    if detail:
        body["error"]["detail"] = detail
    return JSONResponse(body, status_code=status)


def create_app(cfg: Optional[Config] = None, store: Optional[Store] = None, clock=None) -> FastAPI:
    from . import logsafe

    logsafe.install()
    cfg = cfg or Config.from_env()
    store = store or Store(cfg.pg_dsn)
    server = GameServer(cfg, store, clock)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        await server.start()
        try:
            yield
        finally:
            await server.stop()

    app = FastAPI(
        title="cow-farm",
        version="2",
        lifespan=lifespan,
        docs_url="/v1/docs",
        openapi_url="/v1/openapi.json",
        redoc_url=None,
    )
    app.state.server = server
    # 區網試玩：token 放在 Authorization header（不用 cookie），所以開放所有來源；flutter run -d web-server 用別的埠也能連
    app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

    # ---- 錯誤格式 ----
    @app.exception_handler(GameError)
    async def _game_error(request: Request, exc: GameError):
        return _err(exc.status, exc.code, exc.message, exc.detail)

    @app.exception_handler(RequestValidationError)
    async def _validation(request: Request, exc: RequestValidationError):
        fields = []
        for e in exc.errors():
            loc = [str(x) for x in e.get("loc", ()) if x not in ("body", "query")]
            fields.append(".".join(loc) or "body")
        return _err(
            400, "bad_request", "請求格式不對：" + "、".join(sorted(set(fields))), {"fields": sorted(set(fields))}
        )

    @app.exception_handler(StarletteHTTPException)
    async def _http(request: Request, exc: StarletteHTTPException):
        codes = {404: ("not_found", "找不到這個網址"), 405: ("method_not_allowed", "不支援這個方法")}
        code, msg = codes.get(exc.status_code, ("http_error", "請求失敗"))
        return _err(exc.status_code, code, msg)

    @app.exception_handler(Exception)
    async def _internal(request: Request, exc: Exception):
        log.exception("未預期的錯誤：%s %s", request.method, request.url.path)
        return _err(500, "internal", "伺服器發生錯誤，請稍後再試")

    # ---- 認證 ----
    def current(authorization: Optional[str] = Header(None)) -> Player:
        token = None
        if authorization and authorization.lower().startswith("bearer "):
            token = authorization[7:].strip()
        return server.auth(token)

    def state_of(p: Player, now: float) -> dict:
        return V.state_view(server.game, server.game.players[p.pid], now, server.clock)

    def base(now: float) -> dict:
        return V.time_fields(server.clock, now)

    # ---- 帳號 ----
    @app.post("/v1/session")
    async def session(req: SessionReq):
        """建立牧場：取好名字才建立（協定 2.1 節）。"""
        rid = _rid(req.request_id) if req.request_id is not None else None
        token, p, created = await server.create_session(req.ranch_name, rid)
        now = server.clock.now()
        return {
            **base(now),
            "token": token,
            "player_id": p.pid,
            "ranch_name": p.name,
            "created": created,
            "state": state_of(p, now),
        }

    @app.get("/v1/state")
    async def state(p: Player = Depends(current)):
        return state_of(p, server.clock.now())

    # ---- 動作 ----
    @app.post("/v1/collect")
    async def collect(req: ActionReq, p: Player = Depends(current)):
        g = server.game

        def respond(res, now):
            st = state_of(p, now)
            return {
                **base(now),
                "collected": V.r6(res["collected"]),
                "spoiled": V.r6(res["spoiled"]),
                "warehouse_full": res["warehouse_full"],
                "coins": st["coins"],
                "bucket": st["bucket"],
                "warehouse": st["warehouse"],
                "state": st,
            }

        return await server.run_action(
            p.pid, lambda now: g.collect(p.pid, now), _rid(req.request_id), "collect", respond
        )

    @app.post("/v1/sell/quote")
    async def sell_quote(req: QuoteReq, p: Player = Depends(current)):
        now = server.clock.now()
        q = server.game.quote(p.pid, req.commodity, req.qty, now)
        return {**base(now), **_sale_fields(q), "warn_big_order": q["discount"] >= 0.05}

    @app.post("/v1/sell")
    async def sell(req: SellReq, p: Player = Depends(current)):
        g = server.game

        def respond(res, now):
            st = state_of(p, now)
            m = g.ex.markets[req.commodity]
            f = g.players[p.pid].farm
            return {
                **base(now),
                **_sale_fields(res),
                "price_after": V.r6(m.price),
                "next_unit_price": V.r6(V.next_unit_price(m, f.impact[req.commodity], now)),
                "coins": st["coins"],
                "warehouse": st["warehouse"],
                "state": st,
            }

        return await server.run_action(
            p.pid, lambda now: g.sell(p.pid, req.commodity, req.qty, now), _rid(req.request_id), "sell", respond
        )

    @app.post("/v1/ship")
    async def ship(req: ShipReq, p: Player = Depends(current)):
        g = server.game

        def respond(res, now):
            st = state_of(p, now)
            lot = res["lot"]
            f = g.players[p.pid].farm
            est = g.ex.markets["beef"].quote(f.impact["beef"], [(lot.qty, f.beef_lot_mult(lot, now))], now)
            grade = V.GRADE_NAMES[lot.grade] if 0 <= lot.grade < 3 else None
            return {
                **base(now),
                "cow_id": res["cow_id"],
                "grade": grade,
                "grade_probs": V.grade_dict(res["grade_probs"]),
                "beef": {
                    "qty": V.r6(lot.qty),
                    "tier": lot.tier,
                    "shipped_at": lot.t,
                    "grade": grade,
                    "grade_mult": f.fp.beef_grade_mult[lot.grade] if grade else None,
                    "quality": round(lot.mult / f.fp.tier_mult[lot.tier], 4),
                    "value_estimate": round(est.proceeds),
                },
                "coins": st["coins"],
                "warehouse": st["warehouse"],
                "state": st,
            }

        return await server.run_action(
            p.pid, lambda now: g.ship(p.pid, req.cow_id, now), _rid(req.request_id), "ship", respond
        )

    # ---- 商店（等級抽牛）。v1 的 /v1/buy_calf 在協定 v2 拿掉了（打它是 404 not_found） ----
    @app.get("/v1/shop")
    async def shop(p: Player = Depends(current)):
        now = server.clock.now()
        pl = server.game.players[p.pid]
        return {
            **base(now),
            "coins": int(round(pl.farm.coins)),
            "free_slots": pl.farm.free_slots(),
            "grades": server.game.shop_info(),
        }

    @app.post("/v1/shop/buy")
    async def shop_buy(req: ShopBuyReq, p: Player = Depends(current)):
        g = server.game

        def respond(cow, now):
            pl = g.players[p.pid]
            st = state_of(p, now)
            gi = pl.farm.fp.shop_grade_names.index(req.grade)
            return {
                **base(now),
                "grade": req.grade,
                "cow": V.cow_view(g, pl, cow, now),
                "cost": int(round(pl.farm.fp.shop_grade_price[gi])),
                "coins": st["coins"],
                "pen": st["pen"],
                "state": st,
            }

        return await server.run_action(
            p.pid, lambda now: g.shop_buy(p.pid, req.grade, now), _rid(req.request_id), "shop_buy", respond
        )

    # ---- v0.2：出貨前看評級機率 ----
    @app.get("/v1/ship/preview")
    async def ship_preview(cow_id: int = Query(...), p: Player = Depends(current)):
        g = server.game
        now = server.clock.now()
        pl = g.players[p.pid]
        c = g._cow(pl, cow_id)
        blockers = []
        try:
            g.ship_check(pl, c, now)
        except GameError as e:
            blockers.append({"code": e.code, "message": e.message, **(e.detail or {})})
        fp = pl.farm.fp
        from cowecon.farm import beef_grade_probs, beef_weight

        probs = beef_grade_probs(fp, c, now)
        by_grade = {
            gn: round(ship_value(g, pl, c, now, fp.beef_grade_mult[i] * fp.tier_mult[c.tier]))
            for i, gn in enumerate(V.GRADE_NAMES)
        }
        return {
            **base(now),
            "cow_id": c.cid,
            "weight_kg": V.r2(beef_weight(fp, c, now)),
            "tier": c.tier,
            "grade_probs": V.grade_dict(probs),
            "grade_mult": dict(zip(V.GRADE_NAMES, fp.beef_grade_mult)),
            "value_by_grade": by_grade,
            "expected_value": round(ship_value(g, pl, c, now)),
            "can_ship": not blockers,
            "blockers": blockers,
        }

    @app.get("/v1/breed/preview")
    async def breed_preview(sire: int = Query(...), dam: int = Query(...), p: Player = Depends(current)):
        now = server.clock.now()
        return {**base(now), **server.game.breed_preview(p.pid, sire, dam, now)}

    @app.post("/v1/breed")
    async def breed(req: BreedReq, p: Player = Depends(current)):
        g = server.game

        def respond(res, now):
            pl = g.players[p.pid]
            st = state_of(p, now)
            return {
                **base(now),
                "calf": V.cow_view(g, pl, res["calf"], now),
                "sire": {"id": res["sire"].cid, "bred": res["sire"].bred},
                "dam": {"id": res["dam"].cid, "bred": res["dam"].bred},
                "coins": st["coins"],
                "state": st,
            }

        return await server.run_action(
            p.pid, lambda now: g.breed(p.pid, req.sire, req.dam, now), _rid(req.request_id), "breed", respond
        )

    @app.post("/v1/upgrade")
    async def upgrade(req: UpgradeReq, p: Player = Depends(current)):
        g = server.game

        def respond(res, now):
            st = state_of(p, now)
            return {
                **base(now),
                "kind": res["kind"],
                "cost": res["cost"],
                "coins": st["coins"],
                "upgrades": st["upgrades"],
                "pen": st["pen"],
                "state": st,
            }

        return await server.run_action(
            p.pid, lambda now: g.upgrade(p.pid, req.kind, now), _rid(req.request_id), "upgrade", respond
        )

    # ---- 行情與排行榜 ----
    @app.get("/v1/market")
    async def market(p: Player = Depends(current)):
        return server.market_view()

    @app.get("/v1/market/history")
    async def market_history(
        commodity: Literal["milk", "beef", "rice"] = Query(...),
        range: Literal["1h", "1d", "7d"] = Query("1d"),
        p: Player = Depends(current),
    ):
        return server.market_history(commodity, range)

    @app.get("/v1/leaderboard")
    async def leaderboard(
        kind: Literal["networth", "collection", "weekly"] = Query("networth"), p: Player = Depends(current)
    ):
        return server.leaderboard(kind, p)

    # ---- v0.2：田地 ----
    @app.post("/v1/field/assign")
    async def field_assign(req: FieldAssignReq, p: Player = Depends(current)):
        g = server.game

        def respond(res, now):
            st = state_of(p, now)
            return {**base(now), **res, "fields": st["fields"], "rice": st["rice"], "coins": st["coins"], "state": st}

        return await server.run_action(
            p.pid,
            lambda now: g.field_assign(p.pid, req.cow_id, req.field, now),
            _rid(req.request_id),
            "field_assign",
            respond,
        )

    @app.post("/v1/field/recall")
    async def field_recall(req: CowActionReq, p: Player = Depends(current)):
        g = server.game

        def respond(res, now):
            st = state_of(p, now)
            return {**base(now), **res, "fields": st["fields"], "rice": st["rice"], "coins": st["coins"], "state": st}

        return await server.run_action(
            p.pid, lambda now: g.field_recall(p.pid, req.cow_id, now), _rid(req.request_id), "field_recall", respond
        )

    @app.post("/v1/field/harvest")
    async def field_harvest(req: ActionReq, p: Player = Depends(current)):
        g = server.game

        def respond(res, now):
            st = state_of(p, now)
            return {
                **base(now),
                "harvested": V.r6(res["harvested"]),
                "fields": st["fields"],
                "rice": st["rice"],
                "warehouse": st["warehouse"],
                "coins": st["coins"],
                "state": st,
            }

        return await server.run_action(
            p.pid, lambda now: g.harvest(p.pid, now), _rid(req.request_id), "field_harvest", respond
        )

    @app.post("/v1/field/expand")
    async def field_expand(req: ActionReq, p: Player = Depends(current)):
        g = server.game

        def respond(res, now):
            st = state_of(p, now)
            return {
                **base(now),
                "kind": "field",
                "cost": res["cost"],
                "fields": st["fields"],
                "upgrades": st["upgrades"],
                "coins": st["coins"],
                "state": st,
            }

        return await server.run_action(
            p.pid, lambda now: g.upgrade(p.pid, "field", now), _rid(req.request_id), "field_expand", respond
        )

    # ---- v0.2：借種市場 ----
    @app.get("/v1/stud")
    async def stud(p: Player = Depends(current)):
        g = server.game
        now = server.clock.now()
        rows = sorted(g.stud.listings.values(), key=lambda l: (g.stud.price(l, now), l.lid))  # 這一刻便宜的在前
        return {
            **base(now),
            "listings": [V.listing_view(g, l, p.pid, now) for l in rows],
            "mine": [V.listing_view(g, l, p.pid, now) for l in g.stud.owner_listings(p.pid)],
        }

    @app.get("/v1/stud/log")
    async def stud_log(p: Player = Depends(current)):
        """借種紀錄（S18-11；協定 4.6 節）。"""
        return await server.stud_log_view(p)

    @app.get("/v1/stud/preview")
    async def stud_preview(listing_id: int = Query(...), dam: int = Query(...), p: Player = Depends(current)):
        now = server.clock.now()
        return {**base(now), **server.game.stud_preview(p.pid, listing_id, dam, now)}

    @app.post("/v1/stud/list")
    async def stud_list(req: StudListReq, p: Player = Depends(current)):
        g = server.game

        def respond(res, now):
            st = state_of(p, now)
            return {
                **base(now),
                "listing": V.listing_view(g, res["listing"], p.pid, now),
                "coins": st["coins"],
                "state": st,
            }

        return await server.run_action(
            p.pid,
            lambda now: g.stud_list(p.pid, req.cow_id, now),
            _rid(req.request_id),
            "stud_list",
            respond,
        )

    @app.post("/v1/stud/unlist")
    async def stud_unlist(req: StudUnlistReq, p: Player = Depends(current)):
        g = server.game

        def respond(res, now):
            st = state_of(p, now)
            return {**base(now), **res, "coins": st["coins"], "state": st}

        return await server.run_action(
            p.pid, lambda now: g.stud_unlist(p.pid, req.listing_id), _rid(req.request_id), "stud_unlist", respond
        )

    @app.post("/v1/stud/borrow")
    async def stud_borrow(req: StudBorrowReq, p: Player = Depends(current)):
        g = server.game
        if req.price is None:  # 一定要帶預覽時看到的借種費（電腦假玩家才不帶）
            raise GameError("bad_request", "price 要是整數（預覽時看到的借種費）", 400, {"fields": ["price"]})

        def respond(res, now):
            pl = g.players[p.pid]
            st = state_of(p, now)
            lst = res["listing"]
            return {
                **base(now),
                "calf": V.cow_view(g, pl, res["calf"], now),
                "price": res["price"],
                "listing_id": lst.lid,
                "dam": {"id": res["dam"].cid, "bred": res["dam"].bred},
                "coins": st["coins"],
                "state": st,
            }

        return await server.run_action(
            p.pid,
            lambda now: g.stud_borrow(p.pid, req.listing_id, req.dam, now, expected_price=req.price),
            _rid(req.request_id),
            "stud_borrow",
            respond,
        )

    # ---- 即時推播 ----
    @app.websocket("/v1/ws")
    async def ws(websocket: WebSocket, token: Optional[str] = None):
        offered = list(websocket.scope.get("subprotocols") or [])
        tok = token
        for sp in offered:
            if sp.startswith("cowfarm.token."):
                tok = sp[len("cowfarm.token.") :]
        await websocket.accept(subprotocol="cowfarm.v1" if "cowfarm.v1" in offered else None)
        try:
            p = server.auth(tok)
        except GameError as e:
            await websocket.send_text(
                json.dumps({"type": "error", "error": {"code": e.code, "message": e.message}}, ensure_ascii=False)
            )
            await websocket.close(code=4401, reason="unauthorized")
            return
        server.ws[websocket] = p.pid
        try:
            now = server.clock.now()
            await websocket.send_text(
                json.dumps({"type": "hello", **base(now), "player_id": p.pid, "protocol": 2}, ensure_ascii=False)
            )
            await websocket.send_text(json.dumps(server.market_message(), ensure_ascii=False))
            while True:
                await websocket.receive_text()  # 用戶端送什麼都忽略；只用來知道連線還在
                server.last_seen[p.pid] = time.time()
        except WebSocketDisconnect:
            pass
        finally:
            server.ws.pop(websocket, None)

    @app.get("/healthz")
    async def healthz():
        return server.health()

    # ---- 網頁版（Flutter build web） ----
    if cfg.web_dir:
        d = Path(cfg.web_dir)
        if d.is_dir():
            app.mount("/", StaticFiles(directory=str(d), html=True), name="web")
            log.info("網頁版：%s", d)
        else:
            log.warning("COWFARM_WEB_DIR=%s 不存在，先不提供網頁版（API 照常）", d)

    return app


def _sale_fields(q: dict) -> dict:
    return {
        "commodity": q["commodity"],
        "qty": V.r6(q["qty"]),
        "avg_price": V.r6(q["avg_price"]),
        "total": q["total"],
        "market_price": V.r6(q["market_price"]),
        "discount": round(q["discount"], 6),
    }
