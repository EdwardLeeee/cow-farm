"""伺服器執行期：載入／建立世界、遊戲時鐘、市場 tick、假玩家、動作的存檔與防重送、WebSocket 推播。

一個程序（uvicorn 1 個 worker）負責全部，狀態在記憶體，資料庫是持久紀錄（T1）。

- 每個會改狀態的動作：全部排成一列（一個 asyncio.Lock；v0.2 的借種會同時改兩位玩家）→ 查 request_id →
  呼叫服務層（同步）→ 同一個交易寫所有動到的牧場（樂觀鎖）、借種市場、成交紀錄、request_id 與回應 →
  成功才回覆。寫入失敗就把記憶體改回去。
- 每遊戲分鐘一個 tick：先讓這一分鐘該動的假玩家動作（走同一套服務層），算同時在線人數，
  Exchange.step，再把市場狀態、價格、新聞寫進資料庫。
- 重啟：從資料庫載入最後一個 tick 的市場狀態，加上之後的成交（依序號）重建 pending，每個數字都和
  當機前一樣；遊戲時間從上次存下的時間接著走（關機期間暫停）。
"""

from __future__ import annotations

import asyncio
import hashlib
import heapq
import json
import logging
import math
import random
import secrets
import time
from collections import deque
from typing import Any, Callable, Deque, Dict, List, Optional, Set, Tuple

from cowecon import DEFAULT, ENGINE_VERSION, Exchange, StudMarket
from cowecon.params import DAY, HOUR, MINUTE

from . import bots as B
from . import views as V
from .clock import GameClock
from .config import Config
from .breeds import breed_of_genes
from .game import Game, GameError, Player, week_id, week_start
from .names import random_ranch_name
from .population import TUTORIAL_S, day_sessions_with, local_midnight_utc
from .store import Store

log = logging.getLogger("cowfarm")

TICK_S = 60.0
HISTORY_KEEP_S = 7 * DAY + HOUR  # 記憶體裡留幾天的價格（走勢圖 7d）
PRICE_PRUNE_S = 8 * DAY  # 資料庫的價格留幾天
BOT_JOIN_SPREAD_S = 1 * HOUR  # 假玩家在開服後 1 遊戲小時內陸續加入
MAX_TICKS_PER_COMMIT = 120
# 伺服器的存檔格式（跟經濟引擎的版本分開算）。不一樣就拒絕啟動，原型階段不做搬移（ceo 2026-10-02）。
# 2：v0.2（沒有這個欄位的舊世界）；3：協定 v2 的 24 品種圖鑑（品種代號 → 第一次發現的時間）。
WORLD_FORMAT = 3


def token_hash(token: str) -> bytes:
    return hashlib.sha256(token.encode()).digest()


class ServerBots:
    """伺服器裡的假玩家排程。策略函式（server.bots）拿它當 ctx：upcoming()、schedule()。

    排程可以在重啟後重建：每位假玩家每天的上線時間用 (種子, 玩家, 第幾天) 導出的亂數抽，
    S4 安排的回訪存在牧場狀態的 bot 欄位，已經做過的動作用 last_t 跳過。
    """

    npc_rng = None  # ctx：電腦假玩家補借種上架的亂數，None = 服務層預設（由上架編號導出）

    def __init__(self, server: "GameServer"):
        self.server = server
        self.game = server.game
        self.heap: List[tuple] = []
        self._seq = 0
        self.bots: Dict[int, B.Bot] = {}
        self.intervals: List[Tuple[float, float]] = []  # 在線的時段（遊戲時間）
        self.days_done: Set[int] = set()
        self.day0 = 0.0

    # ---- ctx ----
    def upcoming(self, now: float):
        return self.game.ex.upcoming(now)

    def schedule(self, t: float, pid: int, kind: str, dur: float, persist: bool = True) -> None:
        self._seq += 1
        # 同一個遊戲時間的動作依玩家編號排序（不依排程先後），重啟後重建的排程順序才會一樣
        heapq.heappush(self.heap, (t, pid, self._seq, kind))
        if dur > 0:
            self.intervals.append((t, t + dur))
        if persist:
            meta = self.game.players[pid].bot
            meta.setdefault("extra", []).append([t, kind, dur])

    # ---- 建立與載入 ----
    def attach(self, p: Player) -> None:
        meta = p.bot
        b = B.Bot(self.game, p.pid, meta["strategy"], meta["joined_at"], meta.get("taste", 0.0), rng=None)
        b.returns = set(meta.get("returns", []))
        self.bots[p.pid] = b
        last = meta.get("last_t")
        for k in range(int(TUTORIAL_S // MINUTE)):
            t = meta["joined_at"] + k * MINUTE
            if last is None or t > last:
                self.schedule(t, p.pid, "tutorial", 0.0, persist=False)
        self.intervals.append((meta["joined_at"], meta["joined_at"] + TUTORIAL_S))
        for t, kind, dur in meta.get("extra", []):
            if last is None or t > last:
                self.schedule(t, p.pid, kind, dur, persist=False)
            elif dur > 0:
                self.intervals.append((t, t + dur))  # 已經做過，但在線時段可能還沒結束

    def ensure_days(self, now: float) -> None:
        """排好「今天」和「明天」（台灣時間）的上線時段。"""
        d_now = int((now - self.day0) // DAY)
        for d in (d_now, d_now + 1):
            if d < 0 or d in self.days_done:
                continue
            self.days_done.add(d)
            day_start = self.day0 + d * DAY
            for pid, b in self.bots.items():
                meta = self.game.players[pid].bot
                r = random.Random(f"{self.game.seed}:sched:{pid}:{d}")
                last = meta.get("last_t")
                for s, dur in day_sessions_with(r, meta["per_day"], meta["shift_min"], day_start):
                    if s < b.tut_end:
                        continue
                    self.intervals.append((s, s + dur))  # 在線時段：重啟前已經開始的也要算
                    if last is not None and s <= last:
                        continue
                    self._seq += 1
                    heapq.heappush(self.heap, (s, pid, self._seq, "session"))

    def online(self, a: float, b: float) -> float:
        """[a, b) 之間平均有幾位假玩家在線（依時段重疊比例，和模擬相同）。"""
        total = 0.0
        keep = []
        for s, e in self.intervals:
            if e <= a:
                continue
            keep.append((s, e))
            ov = min(b, e) - max(a, s)
            if ov > 0:
                total += ov / (b - a)
        self.intervals = keep
        return total

    async def run_until(self, t_end: float) -> int:
        """執行 t_end 之前該做的假玩家動作（每個動作 = 一次存檔）。"""
        n = 0
        while self.heap and self.heap[0][0] < t_end:
            t_ev, pid, _, kind = heapq.heappop(self.heap)
            b = self.bots.get(pid)
            if b is None:
                continue

            def fn(_now, b=b, pid=pid, t_ev=t_ev, kind=kind):
                # 這次動作的亂數（挑商店等級、抽牛、評級、配種）：由 (種子, 玩家, 時間, 動作) 導出，重啟後一樣
                b.rng = random.Random(f"{self.game.seed}:bot:{pid}:{t_ev!r}:{kind}")
                try:
                    B.act(b, self, t_ev, kind)
                except Exception:  # noqa: BLE001
                    # 策略中途出錯：前面已經做完的服務層動作照樣存檔（記憶體和資料庫保持一致）
                    log.exception("bot %s action %s failed", pid, kind)
                    self.server.stats["errors"] += 1
                meta = self.game.players[pid].bot
                meta["returns"] = sorted(b.returns)
                meta["last_t"] = t_ev
                meta["extra"] = [x for x in meta.get("extra", []) if x[0] + x[2] > t_ev]  # 在線時段結束才刪
                return None

            try:
                await self.server.run_action(pid, fn, now=t_ev)
                n += 1
            except GameError:
                pass
            except Exception:  # noqa: BLE001
                log.exception("bot %s action %s failed", pid, kind)
        return n


class GameServer:
    def __init__(self, cfg: Config, store: Store, clock=None):
        self.cfg = cfg
        self.store = store
        self.clock = clock
        self.game: Optional[Game] = None
        self.tokens: Dict[bytes, int] = {}
        self.write_lock = asyncio.Lock()  # 所有會改狀態的動作排成一列（借種會同時改兩位玩家）
        self.history: Dict[str, Deque[Tuple[float, float]]] = {}
        self.news_seen: Set[int] = set()
        self.news_log: Dict[int, Any] = {}  # eid → MarketEvent（已公開過的，含已結束）
        self.bots: Optional[ServerBots] = None
        self.ws: Dict[Any, int] = {}  # WebSocket → player_id
        self.last_seen: Dict[int, float] = {}  # player_id → 最後一次請求的現實時間
        self.tasks: List[asyncio.Task] = []
        self.stats = {"ticks": 0, "bot_actions": 0, "errors": 0, "tick_lag_s": 0.0, "started_real": time.time()}
        self._lb_cache: Dict[str, Tuple[float, list]] = {}
        self.fingerprint = DEFAULT.fingerprint()

    # ------------------------------------------------------------------ 啟動
    async def start(self) -> None:
        await self.store.start()
        data = await self.store.load()
        if "world" not in data["meta"]:
            await self._create_world()
        else:
            await self._restore(data)
        await self._ensure_bots()
        log.info(
            "cowecon %s 參數指紋 %s（和 docs/research/economy/out/goals.json 的 params_fingerprint 相同，才是模擬驗證過的那一份參數）",
            ENGINE_VERSION,
            self.fingerprint,
        )
        log.info(
            "遊戲時間 %.0f、倍率 %s、玩家 %d（假玩家 %d）",
            self.clock.now(),
            self.clock.scale,
            len(self.game.players),
            len(self.bots.bots),
        )
        if self.cfg.run_loops:
            self.tasks.append(asyncio.create_task(self._tick_loop(), name="tick"))
            self.tasks.append(asyncio.create_task(self._push_loop(), name="push"))

    async def stop(self) -> None:
        for t in self.tasks:
            t.cancel()
        for t in self.tasks:
            try:
                await t
            except (asyncio.CancelledError, Exception):  # noqa: BLE001
                pass
        self.tasks = []
        for ws in list(self.ws):
            try:
                await ws.close(code=1001)
            except Exception:  # noqa: BLE001
                pass
        if self.game is not None and self.clock is not None and self.store.pool is not None:
            try:  # 正常關機：存下現在的遊戲時間，重啟後從這裡接著走（強制終止時則從最後一個 tick 接著走）
                await self.store.put_meta("clock", self._clock_meta())
            except Exception:  # noqa: BLE001
                log.exception("關機時存遊戲時鐘失敗")
        await self.store.close()

    def _ex_meta(self) -> dict:
        d = self.game.ex.to_dict(include_hist=False, include_history=False)
        d.pop("markets")
        return d

    def _market_snaps(self) -> Dict[str, dict]:
        return {cid: m.to_dict(include_hist=False) for cid, m in self.game.ex.markets.items()}

    def _clock_meta(self) -> dict:
        return {"game_t": self.clock.now(), "scale": self.clock.scale, "real_t": time.time()}

    async def _create_world(self) -> None:
        seed = self.cfg.seed or secrets.token_hex(16)
        t0 = self.cfg.game_start if self.cfg.game_start is not None else time.time()
        t0 = math.floor(t0 / TICK_S) * TICK_S
        self.game = Game(DEFAULT, seed, t0)
        self.game.stud.npc_refill(t0, self.game.npc_rng())  # 電腦假玩家先上架幾頭公牛，借種市場不會是空的
        if self.clock is None:
            self.clock = GameClock(t0, self.cfg.time_scale)
        world = {
            "seed": seed,
            "game_start": t0,
            "created_real": time.time(),
            "fingerprint": self.fingerprint,
            "engine": ENGINE_VERSION,
            "format": WORLD_FORMAT,
        }
        prices = {cid: m.price for cid, m in self.game.ex.markets.items()}
        await self.store.init_world(
            {
                "world": world,
                "exchange": self._ex_meta(),
                "clock": self._clock_meta(),
                "stud": self.game.stud.to_dict(),
            },
            self._market_snaps(),
            t0,
            prices,
        )
        for cid, p in prices.items():
            self.history[cid] = deque([(t0, p)])
        self.bots = ServerBots(self)
        self.bots.day0 = local_midnight_utc(t0)
        log.info("建立新世界：開服遊戲時間 %.0f", t0)

    async def _restore(self, data: dict) -> None:
        meta = data["meta"]
        world = meta["world"]
        engine = str(world.get("engine", "0.1.0"))
        if engine.split(".")[:2] != ENGINE_VERSION.split(".")[:2] or set(data["markets"]) != set(DEFAULT.commodity_ids):
            raise RuntimeError(
                f"資料庫裡的世界是引擎 {engine} 建的（商品 {sorted(data['markets'])}），和這版伺服器（引擎 {ENGINE_VERSION}）不相容。"
                "原型階段不做搬移：請清掉資料庫重建新世界（backend/README.md「從舊資料庫升級」），"
                "或用 COWFARM_PG_DSN 指到另一個空的資料庫。"
            )
        fmt = world.get("format", 2)
        if fmt != WORLD_FORMAT:
            raise RuntimeError(
                f"資料庫裡的世界是存檔格式 {fmt}，這版伺服器是格式 {WORLD_FORMAT}（協定 v2 的 24 品種圖鑑），不相容。"
                "原型階段不做搬移：請清掉資料庫重建新世界（backend/README.md「從舊資料庫升級」），"
                "或用 COWFARM_PG_DSN 指到另一個空的資料庫。"
            )
        if world.get("fingerprint") != self.fingerprint:
            log.warning("參數指紋不同：資料庫 %s，程式 %s", world.get("fingerprint"), self.fingerprint)
        ex_d = dict(meta["exchange"])
        ex_d["markets"] = data["markets"]
        ex_t = ex_d["t"]
        hist = {
            cid: await self.store.price_history(cid, ex_t - DEFAULT.commodity(cid).ma_window_s)
            for cid in data["markets"]
        }
        ex = Exchange.from_dict(DEFAULT, ex_d, hist)
        stud = StudMarket.from_dict(DEFAULT, meta["stud"]) if "stud" in meta else StudMarket(DEFAULT)
        self.game = Game(DEFAULT, world["seed"], exchange=ex, stud=stud)
        for r in data["players"]:
            p = Player.from_state(
                DEFAULT,
                r["id"],
                r["ranch_name"],
                r["is_bot"],
                r["created_game_t"],
                r["state"],
                token_hash=bytes(r["token_sha256"]) if r["token_sha256"] is not None else None,
                version=r["version"],
                game_t=r["game_t"],
            )
            self.game.add_player(p)
            if p.token_hash is not None:
                self.tokens[p.token_hash] = p.pid
        self.game.trade_seq = data["max_seq"]
        # 上一個 tick 之後的成交：照序號重建 pending（T1：全服成交量由 tick 彙總）
        n_pending = 0
        for tr in await self.store.trades_since(ex_t):
            if tr["contrib"]:
                ex.markets[tr["commodity"]].apply_contribution(tr["contrib"])
                n_pending += 1
        for cid in data["markets"]:
            self.history[cid] = deque(await self.store.price_history(cid, ex_t - HISTORY_KEEP_S))
        from cowecon.market import MarketEvent

        for r in data["news"]:
            ev = next((e for e in ex.events if e.eid == r["id"]), None)
            if ev is None:  # 已經結束的新聞：只剩列表要顯示的欄位
                ev = MarketEvent.from_state(
                    {
                        "id": r["id"],
                        "targets": list(r["targets"]),
                        "factor": r["factor"],
                        "announce_at": r["announce_at"],
                        "start_at": r["start_at"],
                        "ramp_s": 0.0,
                        "half_life_s": 1.0,
                        "end_at": r["end_at"],
                        "headline": r["headline"],
                        "rare": r["rare"],
                    }
                )
            self.news_log[r["id"]] = ev
            self.news_seen.add(r["id"])
        # 遊戲時間：從上次存下的時間接著走（關機期間暫停）
        resume = max(
            [ex_t, meta.get("clock", {}).get("game_t", ex_t), data["max_trade_t"] or ex_t]
            + [p.game_t for p in self.game.players.values()]
        )
        if self.clock is None:
            self.clock = GameClock(resume, self.cfg.time_scale)
        self.bots = ServerBots(self)
        self.bots.day0 = local_midnight_utc(world["game_start"])
        for p in self.game.players.values():
            if p.is_bot and p.bot:
                self.bots.attach(p)
        log.info("從資料庫回復：市場 t=%.0f、之後的成交 %d 筆、接續遊戲時間 %.0f", ex_t, n_pending, resume)

    async def _ensure_bots(self) -> None:
        have = [p for p in self.game.players.values() if p.is_bot]
        n_new = self.cfg.bots - len(have)
        if n_new <= 0:
            self.bots.ensure_days(self.clock.now())
            return
        game = self.game
        now = self.clock.now()
        mix = list(B.PLAYER_STRATEGIES)
        # 六種玩法各六分之一：依序輪流，再用固定種子打亂
        order = [mix[i % len(mix)] for i in range(len(have) + n_new)]
        random.Random(f"{game.seed}:assign").shuffle(order)
        for i in range(len(have), len(have) + n_new):
            pid = game.next_pid
            r = random.Random(f"{game.seed}:botmeta:{pid}")
            joined = now + r.uniform(0.0, BOT_JOIN_SPREAD_S)
            name = random_ranch_name(r)
            p = game.create_player(joined, name, is_bot=True, pid=pid)
            p.bot = {
                "strategy": order[i],
                "joined_at": joined,
                "per_day": r.randint(4, 8),
                "shift_min": r.uniform(-60.0, 60.0),
                "taste": r.uniform(0.0, 0.3),
                "returns": [],
                "extra": [],
                "last_t": None,
            }
            await self.store.create_player(pid, None, name, True, joined, p.state_dict())
            p.version = 1
            self.bots.attach(p)
        self.bots.ensure_days(now)
        log.info("加入 %d 位假玩家", n_new)

    # ------------------------------------------------------------------ 帳號
    async def create_session(self) -> Tuple[str, Player]:
        now = self.clock.now()
        token = secrets.token_urlsafe(32)
        th = token_hash(token)
        game = self.game
        pid = game.next_pid
        name = random_ranch_name(random.SystemRandom())
        p = game.create_player(now, name, is_bot=False, pid=pid, token_hash=th)
        try:
            await self.store.create_player(pid, th, name, False, now, p.state_dict())
        except Exception:
            game.players.pop(pid, None)
            raise
        p.version = 1
        self.tokens[th] = pid
        self.last_seen[pid] = time.time()
        return token, p

    def auth(self, token: Optional[str]) -> Player:
        if not token:
            raise GameError("unauthorized", "缺少登入憑證，請先建立訪客帳號", 401)
        pid = self.tokens.get(token_hash(token))
        if pid is None:
            raise GameError("unauthorized", "登入憑證無效，請重新建立訪客帳號", 401)
        self.last_seen[pid] = time.time()
        return self.game.players[pid]

    # ------------------------------------------------------------------ 動作
    async def run_action(
        self,
        pid: int,
        fn: Callable[[float], Any],
        request_id: Optional[str] = None,
        endpoint: Optional[str] = None,
        respond: Optional[Callable[[Any, float], dict]] = None,
        now: Optional[float] = None,
    ) -> Any:
        """執行一個會改狀態的動作並存檔。fn(now) 是同步的服務層呼叫。

        所有動作排成一列（write_lock）：借種會同時改借的人和公牛主人兩座牧場，排成一列才不會兩個動作
        各自拿著舊的牧場去存檔。原型的量（30 位假玩家＋幾位真人）綽綽有餘；上萬人時要改成只鎖相關玩家（M3）。
        """
        async with self.write_lock:
            if request_id is not None:
                prev = await self.store.processed(pid, request_id)
                if prev is not None:
                    ep, resp = prev
                    if ep != endpoint:
                        raise GameError("request_id_reused", "這個 request_id 已經用在別的動作", 409, {"endpoint": ep})
                    return resp
            game = self.game
            p = game.player(pid)
            game.begin()
            backup = p.copy()
            stud_backup = game.stud.to_dict()
            seq0 = game.trade_seq
            t = self.clock.now() if now is None else now
            try:
                result = fn(t)
            except GameError:
                game.take_captured()  # 服務層先檢查後修改：檢查不過時什麼都沒改
                raise
            except Exception:
                self._undo(pid, backup, stud_backup, game.take_captured(), seq0)
                raise
            trades = game.take_captured()
            try:
                response = respond(result, t) if respond is not None else result
            except Exception:
                self._undo(pid, backup, stud_backup, trades, seq0)  # 回應組不出來：當作沒做，記憶體改回去
                raise
            others = []
            for opid in sorted(game.touched - {pid}):
                q = game.players[opid]
                others.append((opid, q.state_dict(), q.version, max(t, q.game_t)))
            try:
                await self.store.commit_action(
                    pid,
                    p.state_dict(),
                    p.version,
                    max(t, p.game_t),
                    trades,
                    (request_id, endpoint, response) if request_id is not None else None,
                    others=others,
                    stud=game.stud.to_dict() if game.stud_dirty else None,
                )
            except Exception:
                self._undo(pid, backup, stud_backup, trades, seq0)
                self.stats["errors"] += 1
                raise
            p.version += 1
            p.game_t = max(t, p.game_t)
            for opid, _st, _v, gt in others:
                q = game.players[opid]
                q.version += 1
                q.game_t = gt
            events, game.stud_events = game.stud_events, []
        for ev in events:
            await self._notify_stud(ev)
        return response

    def _undo(self, pid: int, backup: Player, stud_backup: dict, trades: List[dict], seq0: int) -> None:
        """存檔失敗（或程式出錯）：記憶體改回動作之前。牧場、別人的牧場、借種市場用備份；市場扣回成交的貢獻。"""
        game = self.game
        game.players[pid] = backup
        for opid, b in game.backups.items():
            game.players[opid] = b
        game.stud = StudMarket.from_dict(game.params, stud_backup)
        for tr in trades:
            c = tr["contrib"]
            if c:
                m = game.ex.markets[tr["commodity"]]
                m.pending_counted -= c[0]
                m.pending_actual -= c[1]
                m.pending_ord_w -= c[2]
                m.pending_ord_wq -= c[3]
        game.trade_seq = seq0
        game.begin()
        # （假玩家的 Bot 物件用 property 讀牧場與借種市場，會自動指到還原後的物件）

    async def _notify_stud(self, ev: dict) -> None:
        """有人借了你的公牛：推播給主人（在線的話）。"""
        owner = ev.get("owner")
        if owner is None:
            return
        borrower = self.game.players.get(ev["borrower"])
        msg = {
            "type": "stud",
            "event": "borrowed",
            **V.time_fields(self.clock, self.clock.now()),
            "listing_id": ev["listing_id"],
            "cow": {"id": ev["cow_id"], "breed": breed_of_genes(ev["g"])},
            "price": int(round(ev["price"])),
            "borrower": V.ranch_ref(borrower) if borrower is not None else None,
        }
        text = json.dumps(msg, ensure_ascii=False)
        for ws, wpid in list(self.ws.items()):
            if wpid == owner:
                try:
                    await ws.send_text(text)
                except Exception:  # noqa: BLE001
                    self.ws.pop(ws, None)

    # ------------------------------------------------------------------ tick
    def _real_online(self) -> int:
        pids = set(self.ws.values())
        if self.cfg.online_window_s > 0:
            cutoff = time.time() - self.cfg.online_window_s
            pids.update(pid for pid, ts in self.last_seen.items() if ts >= cutoff)
        return len(pids)

    async def tick_once(self) -> Optional[float]:
        """做一個 tick（t_end = 上一個 tick + 1 遊戲分鐘），回傳 t_end；還沒到時間就回 None。"""
        batch = await self._advance(max_ticks=1)
        return batch[-1] if batch else None

    async def _advance(self, max_ticks: int = MAX_TICKS_PER_COMMIT) -> List[float]:
        game = self.game
        done: List[Tuple[float, Dict[str, dict], Dict[str, float]]] = []
        new_news: List[dict] = []
        while len(done) < max_ticks:
            t_end = game.ex.t + TICK_S
            if t_end > self.clock.now():
                break
            self.bots.ensure_days(t_end)
            self.stats["bot_actions"] += await self.bots.run_until(t_end)
            online = self.bots.online(t_end - TICK_S, t_end) + self._real_online()
            game.tick(t_end, online)
            prices = {cid: m.price for cid, m in game.ex.markets.items()}
            for cid, p in prices.items():
                h = self.history.setdefault(cid, deque())
                h.append((t_end, p))
                while h and h[0][0] < t_end - HISTORY_KEEP_S:
                    h.popleft()
            for ev in game.ex.visible(t_end):
                if ev.eid not in self.news_seen:
                    self.news_seen.add(ev.eid)
                    self.news_log[ev.eid] = ev
                    new_news.append(ev.to_state())
            done.append((t_end, None, prices))
            self.stats["ticks"] += 1
        if not done:
            return []
        t_last = done[-1][0]
        done[-1] = (t_last, self._market_snaps(), done[-1][2])
        await self.store.commit_ticks(done, self._ex_meta(), self._clock_meta(), new_news)
        for n in new_news:
            ev = self.news_log[n["id"]]
            await self.broadcast({"type": "news", **V.news_item(ev, self.clock.now())})
        if self.stats["ticks"] % 60 == 0:
            await self.store.prune(t_last - PRICE_PRUNE_S)
        return [d[0] for d in done]

    async def _tick_loop(self) -> None:
        while True:
            try:
                wait = self.clock.real_seconds_until(self.game.ex.t + TICK_S)
                if wait > 0:
                    await asyncio.sleep(wait)
                self.stats["tick_lag_s"] = max(0.0, -self.clock.real_seconds_until(self.game.ex.t + TICK_S))
                await self._advance()
            except asyncio.CancelledError:
                raise
            except Exception:  # noqa: BLE001
                self.stats["errors"] += 1
                log.exception("tick 失敗")
                await asyncio.sleep(1.0)

    # ------------------------------------------------------------------ 推播
    def market_message(self) -> dict:
        now = self.clock.now()
        msg = {"type": "market", **V.time_fields(self.clock, now), "tick_t": self.game.ex.t}
        for cid in self.game.cids:
            msg[cid] = V.quote_view(self.game, cid, self.history[cid], now)
        return msg

    async def broadcast(self, msg: dict) -> None:
        if not self.ws:
            return
        text = json.dumps(msg, ensure_ascii=False, separators=(",", ":"))
        dead = []
        for ws in list(self.ws):
            try:
                await ws.send_text(text)
            except Exception:  # noqa: BLE001
                dead.append(ws)
        for ws in dead:
            self.ws.pop(ws, None)

    async def _push_loop(self) -> None:
        while True:
            try:
                await asyncio.sleep(self.cfg.ws_push_s)
                await self.broadcast(self.market_message())
            except asyncio.CancelledError:
                raise
            except Exception:  # noqa: BLE001
                log.exception("推播失敗")

    # ------------------------------------------------------------------ 查詢
    def market_view(self) -> dict:
        now = self.clock.now()
        out = {**V.time_fields(self.clock, now), "tick_t": self.game.ex.t, "next_tick_at": self.game.ex.t + TICK_S}
        for cid in self.game.cids:
            m = self.game.ex.markets[cid]
            # D24：市場畫面沒有走勢圖，不送 history（要看走勢用 /v1/market/history）；單位的字在 app 的字串表
            out[cid] = {
                **V.quote_view(self.game, cid, self.history[cid], now),
                "base_price": m.cp.base_price,
                "ratio": V.r6(m.ratio()),
            }
        out["news"] = self.news_list(now)
        return out

    def news_list(self, now: float, limit: int = 20) -> List[dict]:
        evs = [ev for ev in self.news_log.values() if ev.announce_at <= now and ev.end_at > now - 24 * HOUR]
        evs.sort(key=lambda e: (e.announce_at, e.eid), reverse=True)
        return [V.news_item(ev, now) for ev in evs[:limit]]

    HISTORY_RANGES = {"1h": (HOUR, MINUTE), "1d": (DAY, 5 * MINUTE), "7d": (7 * DAY, 30 * MINUTE)}

    def market_history(self, commodity: str, rng: str) -> dict:
        span, step = self.HISTORY_RANGES[rng]
        now = self.clock.now()
        pts = [x for x in self.history[commodity] if x[0] >= now - span]
        return {
            **V.time_fields(self.clock, now),
            "commodity": commodity,
            "range": rng,
            "step_s": step,
            "points": V.downsample(pts, step),
            "ma24": V.r6(self.game.ex.markets[commodity].moving_average()),
        }

    def leaderboard(self, kind: str, me: Player, top: int = 50) -> dict:
        now = self.clock.now()
        cached = self._lb_cache.get(kind)
        if cached is None or time.time() - cached[0] > 3.0:
            game = self.game
            rows = []
            for p in game.players.values():
                if kind == "networth":
                    score = game.net_worth(p, now)
                elif kind == "collection":
                    score = float(len(p.codex))
                else:
                    score = p.weekly_income(now)
                rows.append((score, p.pid))
            rows.sort(key=lambda x: (-x[0], x[1]))
            cached = (time.time(), rows)
            self._lb_cache[kind] = cached
        rows = cached[1]
        players = self.game.players

        def entry(rank, score, pid):
            return {
                "rank": rank,
                "ranch": V.ranch_ref(players[pid]),  # 協定 1.6 節；每列的等級是 ranch.level
                "score": round(score) if kind != "collection" else int(score),
                "is_me": pid == me.pid,
            }

        entries = [entry(i + 1, s, pid) for i, (s, pid) in enumerate(rows[:top])]
        mine = next((entry(i + 1, s, pid) for i, (s, pid) in enumerate(rows) if pid == me.pid), None)
        out = {**V.time_fields(self.clock, now), "kind": kind, "total": len(rows), "entries": entries, "me": mine}
        if kind == "weekly":
            # 週一 00:00（台灣時間，遊戲時間）重算；換算成現實時間給 app 依手機時區顯示（照現在的倍率換算）
            wid = week_id(now)
            scale = self.clock.scale
            out["week_started_at_real"] = out["real_time"] - (now - week_start(wid)) / scale
            out["next_reset_at_real"] = out["real_time"] + (week_start(wid + 1) - now) / scale
        return out

    def health(self) -> dict:
        return {
            "ok": True,
            "server_time": self.clock.now(),
            "time_scale": self.clock.scale,
            "tick_t": self.game.ex.t,
            "players": sum(1 for p in self.game.players.values() if not p.is_bot),
            "bots": sum(1 for p in self.game.players.values() if p.is_bot),
            "ws": len(self.ws),
            "fingerprint": self.fingerprint,
            **self.stats,
            "prices": {cid: m.price for cid, m in self.game.ex.markets.items()},
        }
