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
from . import accounts as A
from . import ranchname
from .names import compose_name, random_name_words
from .population import TUTORIAL_S, day_sessions_with, local_midnight_utc
from .store import Store

log = logging.getLogger("cowfarm")

TICK_S = 60.0
HISTORY_KEEP_S = 7 * DAY + HOUR  # 記憶體裡留幾天的價格（走勢圖 7d）
PRICE_PRUNE_S = 8 * DAY  # 資料庫的價格留幾天
BOT_JOIN_SPREAD_S = 1 * HOUR  # 假玩家在開服後 1 遊戲小時內陸續加入
MAX_TICKS_PER_COMMIT = 120
SESSION_REPLAY_S = 600.0  # 建立牧場的 request_id 在多久（現實秒數）內重送算同一次（協定 2.1 節）
STUD_LOG_KEEP_DAYS = 30  # 借種紀錄保留幾個遊戲天（協定 4.6 節；s18.logKeep）
STUD_LOG_LIMIT = 200  # 一次最多回幾筆
ADMIN_CHANNEL = "cowfarm_admin"  # 營運腳本改了設定就 NOTIFY 這個頻道（payload 是改了什麼，例 maintenance）
MAINT_RELOAD_S = 30.0  # 沒收到通知時，每隔多久（現實秒數）自己再讀一次維護設定（備援）
NAME_MESSAGES = {  # invalid_name 的 message（只供除錯；app 依 detail.reason 查字串表 s02.err*）
    "too_short": "名字太短",
    "too_long": "名字太長",
    "emoji": "名字不能用表情符號",
    "bad_char": "名字裡有不能用的字",
}
# 伺服器的存檔格式（跟經濟引擎的版本分開算）。不一樣就拒絕啟動，原型階段不做搬移（ceo 2026-10-02）。
# 2：v0.2（沒有這個欄位的舊世界）；3：協定 v2 的 24 品種圖鑑（品種代號 → 第一次發現的時間）；
# 4：借種費依體重自動算（D26：借種上架改存公牛長大的時間，不存價位）。
WORLD_FORMAT = 4


def _sign_in_failed(reason: str) -> GameError:
    return GameError("sign_in_failed", "登入失敗", 400, {"reason": reason})


def resume_game_time(saved: float, clock_meta: Optional[dict], scale: float, now_real: float) -> float:
    """重啟後從哪個遊戲時間接著走。

    - 倍率 1（正式版）：照真實時間走，伺服器關著的那段也算（ceo 2026-10-02）：上次存下的遊戲時間 +
      從那時到現在的現實秒數。clock 的 meta 每個 tick 和正常關機時都會存（含 real_t）。
    - 其他倍率（試玩）：關機期間暫停，從 saved（最後一個 tick、動作或關機時的遊戲時間）接著走。
    """
    if scale == 1.0 and clock_meta and "real_t" in clock_meta and "game_t" in clock_meta:
        return max(saved, clock_meta["game_t"] + max(0.0, now_real - clock_meta["real_t"]))
    return saved


def token_hash(token: str) -> bytes:
    return hashlib.sha256(token.encode()).digest()


class ServerBots:
    """伺服器裡的假玩家排程。策略函式（server.bots）拿它當 ctx：upcoming()、schedule()。

    排程可以在重啟後重建：每位假玩家每天的上線時間用 (種子, 玩家, 第幾天) 導出的亂數抽，
    S4 安排的回訪存在牧場狀態的 bot 欄位，已經做過的動作用 last_t 跳過。
    """

    npc_rng = None  # ctx：電腦假玩家補借種上架的亂數，None = 服務層預設（由上架編號導出）
    skip_until = 0.0  # 這之前的動作不做（倍率 1 重啟後：關機的那段不補做，見 resume_game_time）

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
            if b is None or t_ev < self.skip_until:
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
    def __init__(self, cfg: Config, store: Store, clock=None, accounts: Optional[A.AccountServices] = None):
        self.cfg = cfg
        self.store = store
        self.clock = clock
        # 帳號（協定第 5 節）：驗證器、Apple、加密、nonce、換回憑單、重送記錄。None = 照設定組（start 時）
        self.accounts = accounts
        self.links: Dict[int, Dict[str, float]] = {}  # player_id → {provider: 綁定的現實時間}
        self.link_owner: Dict[Tuple[str, str], int] = {}  # (provider, sub) → player_id
        self.revoked: Dict[bytes, Tuple[int, str]] = {}  # 失效登入憑證的雜湊 → (player_id, 原因)
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
        # 維護（協定第 6 節）：meta 的 maintenance = {"starts_at_real", "ends_at_real"}（現實時間），scripts/maint.py 寫
        self.maintenance: Optional[dict] = None
        self._maint_closed = False  # 這次維護開始時已經關過所有 WebSocket
        self._maint_checked = 0.0

    # ------------------------------------------------------------------ 啟動
    async def start(self) -> None:
        await self.store.start()
        data = await self.store.load()
        if "world" not in data["meta"]:
            await self._create_world()
        else:
            await self._restore(data)
        # 牧場編號接在「含已刪除的最大編號」後面（軟刪除的空殼還在，編號不重複使用）；要在加電腦玩家之前
        self.game.next_pid = max(self.game.next_pid, int(data["max_pid"]) + 1)
        for r in data["links"]:
            self.links.setdefault(r["player_id"], {})[r["provider"]] = r["linked_at_real"]
            self.link_owner[(r["provider"], r["subject"])] = r["player_id"]
        for r in data["revoked"]:
            self.revoked[bytes(r["token_sha256"])] = (r["player_id"], r["reason"])
        if self.accounts is None:
            self.accounts = A.services_from_config(self.cfg)
        await self._ensure_bots()
        self.maintenance = data["meta"].get("maintenance")
        self._maint_checked = time.time()
        await self.store.listen(ADMIN_CHANNEL, self._on_admin_notify)
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
            self.tasks.append(asyncio.create_task(self.process_revocations(), name="revoke"))

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
                f"資料庫裡的世界是存檔格式 {fmt}，這版伺服器是格式 {WORLD_FORMAT}，不相容。"
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
        # 遊戲時間：試玩倍率從上次存下的時間接著走（關機期間暫停）；倍率 1 照真實時間走，關機那段也算
        saved = max(
            [ex_t, meta.get("clock", {}).get("game_t", ex_t), data["max_trade_t"] or ex_t]
            + [p.game_t for p in self.game.players.values()]
        )
        resume = resume_game_time(saved, meta.get("clock"), self.cfg.time_scale, time.time())
        if self.clock is None:
            self.clock = GameClock(resume, self.cfg.time_scale)
        self.bots = ServerBots(self)
        self.bots.day0 = local_midnight_utc(world["game_start"])
        for p in self.game.players.values():
            if p.is_bot and p.bot:
                self.bots.attach(p)
        if resume > saved:  # 關機的那段：市場照樣補跑 tick、奶桶照樣累積，假玩家不補做那段的動作
            self.bots.skip_until = resume
        log.info(
            "從資料庫回復：市場 t=%.0f、之後的成交 %d 筆、接續遊戲時間 %.0f（關機期間 %.0f 秒%s）",
            ex_t,
            n_pending,
            resume,
            resume - saved,
            "照算" if resume > saved else "暫停",
        )

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
            words = random_name_words(r)  # 協定只送編號，app 依玩家的語言組；繁中名字存著給日誌看
            name = compose_name(words)
            p = game.create_player(joined, name, is_bot=True, pid=pid)
            p.name_words = words
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
    async def create_session(self, ranch_name, request_id: Optional[str] = None) -> Tuple[str, Player, bool]:
        """建立牧場（協定 2.1 節）：取好名字才建立。回傳 (token, 牧場, 這次有沒有建立)。

        request_id：SESSION_REPLAY_S 秒內同一個 request_id 重送，回同一個牧場並發新 token（前一次的作廢，
        反正手機沒收到），不會多建一個。排在 write_lock 裡，同時送來的兩個重送也只會建一個。
        """
        if not isinstance(ranch_name, str):
            raise GameError("bad_request", "ranch_name 要是字串", 400, {"fields": ["ranch_name"]})
        chk = ranchname.check(ranch_name)
        if chk.reason is not None:
            detail = {"reason": chk.reason, "width": chk.width}
            if chk.char is not None:
                detail["char"] = chk.char
            raise GameError("invalid_name", NAME_MESSAGES[chk.reason], 400, detail)
        async with self.write_lock:
            game = self.game
            if request_id is not None:
                pid = await self.store.session_request(request_id, SESSION_REPLAY_S)
                if pid is not None and pid in game.players:
                    p = game.players[pid]
                    token = secrets.token_urlsafe(32)
                    th = token_hash(token)
                    await self.store.set_token(pid, th)
                    if p.token_hash is not None:
                        self.tokens.pop(p.token_hash, None)
                    p.token_hash = th
                    self.tokens[th] = pid
                    self.last_seen[pid] = time.time()
                    return token, p, False
            now = self.clock.now()
            token = secrets.token_urlsafe(32)
            th = token_hash(token)
            pid = game.next_pid
            p = game.create_player(now, chk.name, is_bot=False, pid=pid, token_hash=th)
            try:
                await self.store.create_player(pid, th, chk.name, False, now, p.state_dict(), request_id=request_id)
            except Exception:
                game.players.pop(pid, None)
                raise
            p.version = 1
            self.tokens[th] = pid
            self.last_seen[pid] = time.time()
            return token, p, True

    def auth(self, token: Optional[str]) -> Player:
        if not token:
            raise GameError("unauthorized", "缺少登入憑證，請先建立訪客帳號", 401)
        th = token_hash(token)
        pid = self.tokens.get(th)
        if pid is None:
            rv = self.revoked.get(th)
            if rv is not None and rv[1] == "signed_in_elsewhere":  # 協定 5.7 節：舊手機看 S14-05
                raise GameError("signed_in_elsewhere", "這個牧場已經在另一支手機登入", 401)
            raise GameError("unauthorized", "登入憑證無效，請重新建立訪客帳號", 401)
        self.last_seen[pid] = time.time()
        return self.game.players[pid]

    # ------------------------------------------------------------------ 帳號（協定第 5 節）
    def account_view(self, pid: int) -> dict:
        links = self.links.get(pid, {})
        return {"links": [{"provider": prov, "linked_at_real": links[prov]} for prov in sorted(links)]}

    def issue_nonce(self) -> Tuple[str, float]:
        return self.accounts.nonces.issue()

    async def _verify(self, provider: str, id_token, nonce) -> A.Identity:
        """驗登入憑證（在背景執行緒：第一次要抓公鑰）並比對 nonce。nonce 不論成功失敗都用掉（協定 5.0 節）。"""
        fresh = self.accounts.nonces.consume(nonce)
        try:
            ident = await asyncio.to_thread(self.accounts.verifier.verify, provider, id_token)
        except A.SignInError as e:
            raise _sign_in_failed(e.reason) from None
        if not fresh:
            raise _sign_in_failed("nonce_invalid")
        if ident.nonce is None:
            if ident.nonce_required:
                raise _sign_in_failed("nonce_invalid")
        elif not A.nonce_matches(ident.nonce, nonce):
            raise _sign_in_failed("nonce_invalid")
        return ident

    async def link_account(self, p: Player, provider: str, id_token, nonce, code) -> dict:
        """綁定（協定 5.2 節）。Apple 要用 authorization code 換 refresh token（網路），在鎖外面換，換完再檢查一次。"""
        ident = await self._verify(provider, id_token, nonce)
        key = (provider, ident.subject)

        def check() -> bool:
            """True = 已經綁在這個牧場；別的情況丟錯誤。"""
            owner = self.link_owner.get(key)
            if owner == p.pid:
                return True
            if owner is not None:
                target = self.game.players.get(owner)
                ticket, exp = self.accounts.tickets.issue(A.SwitchTicket(p.pid, owner, provider, ident.subject))
                raise GameError(
                    "account_in_use",
                    "這個帳號已經綁了別的牧場",
                    409,
                    {
                        "provider": provider,
                        "ranch": V.ranch_ref(target) if target is not None else None,
                        "switch_ticket": ticket,
                        "ticket_expires_at_real": exp,
                    },
                )
            if provider in self.links.get(p.pid, {}):
                raise GameError("provider_already_linked", "這個牧場已經綁了同一種帳號", 409, {"provider": provider})
            return False

        async with self.write_lock:
            if p.pid not in self.game.players:
                raise GameError("unauthorized", "登入憑證無效", 401)
            done = check()
        enc = None
        if not done and provider == "apple":
            if not code or not isinstance(code, str):
                raise GameError(
                    "bad_request", "Apple 綁定要送 authorization_code", 400, {"fields": ["authorization_code"]}
                )
            if self.accounts.cipher is None or not self.accounts.apple.configured():
                raise _sign_in_failed("not_configured")
            try:
                refresh = await asyncio.to_thread(self.accounts.apple.exchange_code, code)
            except A.SignInError as e:
                raise _sign_in_failed(e.reason) from None
            enc = self.accounts.cipher.encrypt(refresh)
        async with self.write_lock:
            try:
                if p.pid not in self.game.players:
                    raise GameError("unauthorized", "登入憑證無效", 401)
                done = check()
            except GameError:
                if enc is not None:  # 換到了卻用不上：撤銷，不留 Apple 的授權
                    await self.store.enqueue_revocation(enc)
                    asyncio.ensure_future(self.process_revocations())
                raise
            if not done:
                linked_at = time.time()
                await self.store.link_account(provider, ident.subject, p.pid, linked_at, enc)
                self.links.setdefault(p.pid, {})[provider] = linked_at
                self.link_owner[key] = p.pid
        return {
            "linked": {"provider": provider, "linked_at_real": self.links[p.pid][provider]},
            "account": self.account_view(p.pid),
        }

    async def unlink_account(self, p: Player, provider: str) -> dict:
        async with self.write_lock:
            links = self.links.get(p.pid, {})
            if provider not in links:
                raise GameError("not_linked", "這個牧場沒有綁這種帳號", 404, {"provider": provider})
            await self.store.unlink_account(p.pid, provider)
            del links[provider]
            for k in [k for k, v in self.link_owner.items() if v == p.pid and k[0] == provider]:
                del self.link_owner[k]
        asyncio.ensure_future(self.process_revocations())
        return {"account": self.account_view(p.pid)}

    def _new_token(self) -> Tuple[str, bytes]:
        token = secrets.token_urlsafe(32)
        return token, token_hash(token)

    def _apply_rotation(self, target: Player, new_hash: bytes) -> Optional[bytes]:
        """記憶體：換登入憑證，舊的記成「在另一支手機找回」。回傳舊的雜湊。"""
        old = target.token_hash
        if old is not None:
            self.tokens.pop(old, None)
            self.revoked[old] = (target.pid, "signed_in_elsewhere")
        target.token_hash = new_hash
        self.tokens[new_hash] = target.pid
        self.last_seen[target.pid] = time.time()
        return old

    async def recover_account(self, provider: str, id_token, nonce) -> Tuple[str, Player]:
        """找回（協定 5.5 節）：發新登入憑證；舊手機收到 signed_in_elsewhere，開著的 WebSocket 也關掉。"""
        ident = await self._verify(provider, id_token, nonce)
        async with self.write_lock:
            owner = self.link_owner.get((provider, ident.subject))
            target = self.game.players.get(owner) if owner is not None else None
            if target is None:
                raise GameError("account_not_linked", "這個帳號沒有備份過牧場", 404, {"provider": provider})
            token, th = self._new_token()
            await self.store.rotate_token(target.pid, th, target.token_hash)
            self._apply_rotation(target, th)
        await self._close_player_ws(target.pid, "signed_in_elsewhere", "這個牧場已經在另一支手機登入")
        return token, target

    def _remove_player_memory(self, p: Player) -> None:
        self.game.players.pop(p.pid, None)
        if p.token_hash is not None:
            self.tokens.pop(p.token_hash, None)
        for th in [th for th, (pid, _r) in self.revoked.items() if pid == p.pid]:
            del self.revoked[th]
        self.links.pop(p.pid, None)
        for k in [k for k, v in self.link_owner.items() if v == p.pid]:
            del self.link_owner[k]
        self.last_seen.pop(p.pid, None)
        self._lb_cache.clear()

    def _unlist_all(self, p: Player) -> Optional[dict]:
        """他上架的公牛全部下架；回傳要存的借種市場（沒有上架就 None）。"""
        mine = self.game.stud.owner_listings(p.pid)
        for lst in mine:
            self.game.stud.unlist(lst.lid, p.farm)
        return self.game.stud.to_dict() if mine else None

    async def delete_ranch(self, p: Player) -> None:
        """刪除牧場（協定 5.6 節，軟刪除）。"""
        async with self.write_lock:
            if p.pid not in self.game.players:
                raise GameError("unauthorized", "登入憑證無效", 401)
            stud_backup = self.game.stud.to_dict()
            stud = self._unlist_all(p)
            try:
                await self.store.delete_player(p.pid, stud)
            except Exception:
                self.game.stud = StudMarket.from_dict(self.game.params, stud_backup)
                raise
            self._remove_player_memory(p)
        await self._close_player_ws(p.pid, "unauthorized", "牧場已經刪除")
        asyncio.ensure_future(self.process_revocations())

    async def switch_ranch(self, p: Player, ticket_code) -> Tuple[str, Player]:
        """換回那個牧場（協定 5.3 節）：刪除現在的牧場、發新登入憑證給那個牧場，同一個資料庫交易。"""
        async with self.write_lock:
            status, t = self.accounts.tickets.take(ticket_code)
            if status == "expired":
                raise _sign_in_failed("ticket_expired")
            if t is None or t.from_pid != p.pid or p.pid not in self.game.players:
                raise _sign_in_failed("ticket_invalid")
            target = self.game.players.get(t.target_pid)
            if target is None or self.link_owner.get((t.provider, t.subject)) != target.pid:
                raise _sign_in_failed("ticket_invalid")
            token, th = self._new_token()
            stud_backup = self.game.stud.to_dict()
            stud = self._unlist_all(p)
            try:
                await self.store.switch_ranch(p.pid, stud, target.pid, th, target.token_hash)
            except Exception:
                self.game.stud = StudMarket.from_dict(self.game.params, stud_backup)
                raise
            self._remove_player_memory(p)
            self._apply_rotation(target, th)
        await self._close_player_ws(p.pid, "unauthorized", "牧場已經刪除")
        await self._close_player_ws(target.pid, "signed_in_elsewhere", "這個牧場已經在另一支手機登入")
        asyncio.ensure_future(self.process_revocations())
        return token, target

    async def _close_player_ws(self, pid: int, code: str, message: str) -> None:
        text = json.dumps({"type": "error", "error": {"code": code, "message": message}}, ensure_ascii=False)
        for ws, wpid in list(self.ws.items()):
            if wpid != pid:
                continue
            try:
                await ws.send_text(text)
                await ws.close(code=4401, reason=code)
            except Exception:  # noqa: BLE001
                pass
            self.ws.pop(ws, None)

    async def process_revocations(self) -> int:
        """撤銷佇列（Apple 的 refresh token）：試一次，成功就刪，失敗延後重試（1 分鐘起、每次加倍、最多 1 小時）。
        TN3194：拿不到 token 也要完成刪除；這裡只是盡量讓 Apple 那邊也解除。回傳這次成功幾筆。"""
        ok = 0
        try:
            rows = await self.store.revocations_due()
        except Exception:  # noqa: BLE001
            log.exception("讀撤銷佇列失敗")
            return 0
        for r in rows:
            retry = min(3600.0, 60.0 * 2 ** min(int(r["attempts"]), 6))
            try:
                if self.accounts.cipher is None:
                    raise A.RevokeError("no_key")
                refresh = self.accounts.cipher.decrypt(r["refresh_enc"])
                await asyncio.to_thread(self.accounts.apple.revoke, refresh)
            except A.RevokeError as e:
                await self.store.revocation_failed(r["id"], str(e), retry)
                continue
            except Exception as e:  # noqa: BLE001
                log.exception("撤銷 Apple 登入失敗")
                await self.store.revocation_failed(r["id"], type(e).__name__, retry)
                continue
            await self.store.revocation_done(r["id"])
            ok += 1
        return ok

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
                    stud_log=[self._stud_log_row(ev) for ev in game.stud_events],
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

    @staticmethod
    def _stud_log_row(ev: dict) -> dict:
        """一次借種 → 借種紀錄的一列（跟借種同一個交易寫入）。公營種牛站：lender_id NULL、station true。"""
        station = ev["owner"] is None
        return {
            "t": ev["t"],
            "lender_id": ev["owner"],
            "station": station,
            "borrower_id": ev["borrower"],
            "listing_id": ev["listing_id"],
            "bull_cow_id": None if station else ev["cow_id"],
            "bull_breed": breed_of_genes(ev["g"]),
            "calf_id": ev["calf_id"],
            "calf_breed": breed_of_genes(ev["calf_g"]),
            "price": int(round(ev["price"])),
        }

    async def stud_log_view(self, me: Player) -> dict:
        """GET /v1/stud/log（協定 4.6 節）：借出與借入，新的在前；對方牧場刪除了是 null。"""
        now = self.clock.now()
        rows = await self.store.stud_log_for(me.pid, now - STUD_LOG_KEEP_DAYS * DAY, STUD_LOG_LIMIT)
        players = self.game.players
        entries = []
        for r in rows:
            out = not r["station"] and r["lender_id"] == me.pid
            if out:
                other = players.get(r["borrower_id"]) if r["borrower_id"] is not None else None
                ranch = V.ranch_ref(other) if other is not None else None
            elif r["station"]:
                ranch = V.station_ref(self.game, r["listing_id"])
            else:
                other = players.get(r["lender_id"]) if r["lender_id"] is not None else None
                ranch = V.ranch_ref(other) if other is not None else None
            entries.append(
                {
                    "kind": "out" if out else "in",
                    "t": r["t"],
                    "price": r["price"],
                    "bull": {"id": r["bull_cow_id"] if out else None, "breed": r["bull_breed"]},
                    "calf": None if out else {"id": r["calf_id"], "breed": r["calf_breed"]},
                    "ranch": ranch,
                }
            )
        return {
            **V.time_fields(self.clock, now),
            "keep_days": STUD_LOG_KEEP_DAYS,
            "income_total": int(round(me.stud_income)),
            "entries": entries,
        }

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
            await self.store.prune(t_last - PRICE_PRUNE_S, stud_log_before=t_last - STUD_LOG_KEEP_DAYS * DAY)
            await self.process_revocations()
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
                if time.time() - self._maint_checked > MAINT_RELOAD_S:
                    await self.reload_maintenance()
                await self.maintenance_tick()
                await self.broadcast(self.market_message())
            except asyncio.CancelledError:
                raise
            except Exception:  # noqa: BLE001
                log.exception("推播失敗")

    # ------------------------------------------------------------------ 維護
    def _on_admin_notify(self, _conn, _pid, _channel, payload) -> None:
        if payload == "maintenance":
            asyncio.ensure_future(self.reload_maintenance())

    def maintenance_view(self) -> Optional[dict]:
        """協定 6.1 節的 maintenance 物件；沒有安排維護是 None。開始時間到了就算維護中，直到腳本結束它
        （過了預計結束時間也一樣，營運要延長就改時間）。"""
        m = self.maintenance
        if not m:
            return None
        return {
            "starts_at_real": m["starts_at_real"],
            "ends_at_real": m["ends_at_real"],
            "active": time.time() >= m["starts_at_real"],
        }

    def maintenance_message(self) -> dict:
        return {
            "type": "maintenance",
            **V.time_fields(self.clock, self.clock.now()),
            "maintenance": self.maintenance_view(),
        }

    async def reload_maintenance(self) -> None:
        """重讀維護設定；有變（預告、改時間、取消）就推給所有連線，已經開始就關掉連線。"""
        value = await self.store.get_meta("maintenance")
        self._maint_checked = time.time()
        if value != self.maintenance:
            self.maintenance = value
            log.info("維護設定：%s", value)
            view = self.maintenance_view()
            if view is None or not view["active"]:  # 已經開始的由 maintenance_tick 推一次再關連線
                await self.broadcast(self.maintenance_message())
        await self.maintenance_tick()

    async def maintenance_tick(self) -> None:
        """維護開始的那一刻：推 maintenance 訊息後用 4503 關掉所有 WebSocket（之後新的連線一連上就關）。"""
        view = self.maintenance_view()
        if view is None or not view["active"]:
            self._maint_closed = False
            return
        if self._maint_closed:
            return
        self._maint_closed = True
        text = json.dumps(self.maintenance_message(), ensure_ascii=False)
        for ws in list(self.ws):
            try:
                await ws.send_text(text)
                await ws.close(code=4503, reason="maintenance")
            except Exception:  # noqa: BLE001
                pass
            self.ws.pop(ws, None)

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
