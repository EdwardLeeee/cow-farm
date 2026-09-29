"""最小但具代表性的養牛遊戲 API（丟棄式實測程式）。

環境變數：
  COW_DB=sqlite|postgres
  COW_SQLITE_PATH=/path/game.db   COW_SQLITE_SYNC=FULL|NORMAL   COW_SQLITE_READERS=4
  COW_PG_DSN=postgresql://...     COW_PG_POOL=20
  COW_TICK_SEC=1.0                市場 tick 週期（加速）
  COW_WS_PUSH=1                   每次 tick 後把快照推給所有 WebSocket 連線
  COW_WS_AUTH=1                   WebSocket 連線時用 ?token= 驗證（查一次 DB）
  COW_START_MILK=0                新帳號倉庫初始牛奶（實測時放大，避免 sell 因存貨不足失敗）

市場公式是佔位用的簡單均值回歸＋噪音＋成交量衝擊，不是 cowecon 的引擎。
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import math
import os
import random
import secrets
import time
from collections import deque
from contextlib import asynccontextmanager
from typing import Literal

from fastapi import Depends, FastAPI, Header, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import Response
from pydantic import BaseModel, Field

from .db import BASE_PRICES, BARN_CAP, INSUFFICIENT, make_db, produced_units

log = logging.getLogger("cowbench")

CFG = {
    "db": os.environ.get("COW_DB", "sqlite"),
    "sqlite_path": os.environ.get("COW_SQLITE_PATH", "game.db"),
    "sqlite_sync": os.environ.get("COW_SQLITE_SYNC", "FULL"),
    "sqlite_readers": int(os.environ.get("COW_SQLITE_READERS", "4")),
    "pg_dsn": os.environ.get("COW_PG_DSN", ""),
    "pg_pool": int(os.environ.get("COW_PG_POOL", "20")),
    "tick_sec": float(os.environ.get("COW_TICK_SEC", "1.0")),
    "ws_push": os.environ.get("COW_WS_PUSH", "1") == "1",
    "ws_auth": os.environ.get("COW_WS_AUTH", "1") == "1",
    "start_milk": int(os.environ.get("COW_START_MILK", "0")),
}

db = make_db(
    CFG["db"],
    sqlite_path=CFG["sqlite_path"],
    synchronous=CFG["sqlite_sync"],
    dsn=CFG["pg_dsn"],
    pool_size=CFG["pg_pool"],
    readers=CFG["sqlite_readers"],
)


class Market:
    """記憶體內快照；GET /v1/market 直接回傳預先序列化好的 bytes。"""

    def __init__(self) -> None:
        self.prices = dict(BASE_PRICES)
        self.tick = 0
        self.pub_at = 0.0
        self.history = {c: deque(maxlen=20) for c in BASE_PRICES}
        self.rng = random.Random(42)
        self.snapshot_bytes = b"{}"
        self.snapshot_text = "{}"
        self.tick_durations = deque(maxlen=2000)
        self._publish({}, time.time())

    def compute(self, rows):
        """佔位公式：往（基本價×時段波動）回歸 + 常態噪音 − 成交量衝擊，夾在 0.5–2 倍基本價。"""
        new = {}
        for commodity, price, base, volume, tick in rows:
            t = tick + 1
            target = base * (1 + 0.10 * math.sin(2 * math.pi * t / 300))
            impact = min(0.05, volume * 1e-5)
            noise = self.rng.gauss(0, 0.01) * base
            p = price + 0.1 * (target - price) + noise - impact * price
            new[commodity] = int(max(base * 0.5, min(base * 2, round(p))))
        return new

    def _publish(self, new, now):
        prev = dict(self.prices)
        self.prices.update(new)
        if new:
            self.tick += 1
        for c, p in self.prices.items():
            self.history[c].append(p)
        self.pub_at = now
        snap = {
            "tick": self.tick,
            "pub_at": round(now, 6),
            "prices": {
                c: {"price": p, "base": BASE_PRICES[c], "chg": p - prev.get(c, p)}
                for c, p in self.prices.items()
            },
            "history": {c: list(h) for c, h in self.history.items()},
        }
        self.snapshot_text = json.dumps(snap, separators=(",", ":"))
        self.snapshot_bytes = self.snapshot_text.encode()

    async def run(self, hub: Hub) -> None:
        period = CFG["tick_sec"]
        next_t = time.monotonic()
        while True:
            next_t += period
            await asyncio.sleep(max(0.0, next_t - time.monotonic()))
            t0 = time.perf_counter()
            now = time.time()
            try:
                new, _rows = await db.tick(now, self.compute)
                self._publish(new, now)
            except Exception:  # noqa: BLE001
                log.exception("tick failed")
                continue
            self.tick_durations.append(time.perf_counter() - t0)
            if CFG["ws_push"] and hub.conns:
                hub.spawn_broadcast(self.snapshot_text)


class Hub:
    def __init__(self) -> None:
        self.conns: set[WebSocket] = set()
        self.stats = deque(maxlen=5000)
        self._tasks: set[asyncio.Task] = set()
        self.accepted = 0
        self.rejected = 0

    def spawn_broadcast(self, snap_text: str) -> None:
        t = asyncio.create_task(self.broadcast(snap_text))
        self._tasks.add(t)
        t.add_done_callback(self._tasks.discard)

    async def _send(self, ws: WebSocket, msg: str) -> bool:
        try:
            await ws.send_text(msg)
            return True
        except Exception:  # noqa: BLE001
            self.conns.discard(ws)
            return False

    async def broadcast(self, snap_text: str) -> None:
        conns = list(self.conns)
        sent_ns = time.time_ns()
        msg = '{"sent_ns":%d,"snap":%s}' % (sent_ns, snap_text)
        t0 = time.perf_counter()
        results = await asyncio.gather(*(self._send(ws, msg) for ws in conns))
        dur = time.perf_counter() - t0
        self.stats.append(
            {
                "n": len(conns),
                "ok": sum(results),
                "fanout_s": round(dur, 6),
                "sent_ns": sent_ns,
                "msg_bytes": len(msg),
            }
        )


market = Market()
hub = Hub()


@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.start()
    task = asyncio.create_task(market.run(hub))
    try:
        yield
    finally:
        task.cancel()
        await db.close()


app = FastAPI(title="cowbench", lifespan=lifespan)


# ------------------------------------------------------------------ models


class SessionOut(BaseModel):
    player_id: int
    token: str


class FarmOut(BaseModel):
    player_id: int
    cows: int
    milk: int
    coins: int
    pending_milk: int
    server_time: float


class CollectOut(BaseModel):
    collected: int
    milk: int
    server_time: float


class SellIn(BaseModel):
    commodity: Literal["milk"] = "milk"
    qty: int = Field(ge=1, le=1000)


class SellOut(BaseModel):
    sold: int
    price: int
    milk: int
    coins: int


async def token_hash(authorization: str | None = Header(default=None)) -> bytes:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="missing token")
    return hashlib.sha256(authorization[7:].encode()).digest()


# ------------------------------------------------------------------ routes


@app.post("/v1/session", response_model=SessionOut, status_code=201)
async def create_session() -> SessionOut:
    token = secrets.token_urlsafe(32)
    pid = await db.create_player(
        hashlib.sha256(token.encode()).digest(), time.time(), CFG["start_milk"]
    )
    return SessionOut(player_id=pid, token=token)


@app.get("/v1/farm", response_model=FarmOut)
async def get_farm(th: bytes = Depends(token_hash)) -> FarmOut:
    row = await db.farm(th)
    if row is None:
        raise HTTPException(status_code=401, detail="bad token")
    now = time.time()
    pending = min(BARN_CAP - row.milk, produced_units(row.cows, row.last_collect_at, now))
    return FarmOut(
        player_id=row.player_id,
        cows=row.cows,
        milk=row.milk,
        coins=row.coins,
        pending_milk=pending,
        server_time=now,
    )


@app.post("/v1/collect", response_model=CollectOut)
async def collect(th: bytes = Depends(token_hash)) -> CollectOut:
    now = time.time()
    res = await db.collect(th, now)
    if res is None:
        raise HTTPException(status_code=401, detail="bad token")
    got, milk = res
    return CollectOut(collected=got, milk=milk, server_time=now)


@app.post("/v1/sell", response_model=SellOut)
async def sell(body: SellIn, th: bytes = Depends(token_hash)) -> SellOut:
    price = market.prices[body.commodity]
    res = await db.sell(th, body.commodity, body.qty, price, time.time())
    if res is None:
        raise HTTPException(status_code=401, detail="bad token")
    if res == INSUFFICIENT:
        raise HTTPException(status_code=409, detail="not enough stock")
    milk, coins = res
    return SellOut(sold=body.qty, price=price, milk=milk, coins=coins)


@app.get("/v1/market")
async def get_market() -> Response:
    return Response(content=market.snapshot_bytes, media_type="application/json")


@app.websocket("/v1/ws/market")
async def ws_market(ws: WebSocket, token: str | None = None):
    if CFG["ws_auth"]:
        pid = await db.auth(hashlib.sha256((token or "").encode()).digest()) if token else None
        if pid is None:
            hub.rejected += 1
            await ws.close(code=4401)
            return
    await ws.accept()
    hub.accepted += 1
    hub.conns.add(ws)
    try:
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        hub.conns.discard(ws)


@app.get("/healthz")
async def healthz():
    return {"ok": True, "db": db.kind, "pid": os.getpid()}


@app.get("/debug/stats")
async def debug_stats(last: int = 50):
    td = sorted(market.tick_durations)
    return {
        "pid": os.getpid(),
        "cfg": {k: v for k, v in CFG.items() if k != "pg_dsn"},
        "ws_conns": len(hub.conns),
        "ws_accepted": hub.accepted,
        "ws_rejected": hub.rejected,
        "broadcasts": list(hub.stats)[-last:],
        "tick": market.tick,
        "tick_p50_ms": round(td[len(td) // 2] * 1000, 3) if td else None,
        "tick_max_ms": round(td[-1] * 1000, 3) if td else None,
        "counts": await db.counts(),
    }
