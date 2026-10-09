"""服務層：所有會改變遊戲狀態的動作都在這裡，真人（HTTP API）和電腦假玩家呼叫同一組函式。

規則
- 全部是同步函式，中間沒有 await：在 asyncio 伺服器裡，一個動作從讀到改完不會被別的請求插隊。
- 先檢查、後修改：檢查不過就丟 GameError，狀態一點都沒動；檢查過了才呼叫 cowecon 的方法。
- 時間 now 一律是「遊戲時間」（Unix 秒），由呼叫端給：API 用伺服器的遊戲時鐘，假玩家用排程時間，
  測試用模擬時間。手機不送任何時間。
- 每筆成交記在 self.captured（成交紀錄，含對下一個 tick 的貢獻），由呼叫端寫進資料庫的 trades 表；
  依 T1，成交只寫 trades，全服成交量由市場 tick 彙總。
- v0.2：借種會改到「別人」的牧場（錢給公牛主人）。改別人之前先呼叫 _touch()，執行期會把動到的每位玩家
  和借種市場在同一個交易裡存檔；存檔失敗時用 backups 還原。
"""

from __future__ import annotations

import json
import math
import random
from typing import Dict, List, Optional, Sequence, Set, Tuple

from cowecon import DEFAULT, EconomyParams, Exchange, Farm, StudMarket
from cowecon.farm import (
    HYBRID,
    OX,
    Cow,
    beef_grade_probs,
    freshness,
    offspring_distribution,
    shop_grade_distribution,
    shop_grade_tier_probs,
    tier_distribution,
)
from cowecon.params import DAY, HOUR, TZ_OFFSET_S

from . import achievements as A
from . import pairings as PAIRINGS
from .breeds import ALL as ALL_BREEDS
from .breeds import FEED_IDS, FEED_INDEX, FLOOR_IDS, FLOOR_INDEX
from .breeds import HYBRID as HYBRID_BREED
from .breeds import breed_id, shown_breed

CALF_BULL_PROB = 0.5  # 配種、借種生出公牛的機率（cowecon Farm.breed：rng.random() < 0.5，跟基因無關）
TYPE_WIRE = ("dairy", "dual", "beef")  # 基因用途 0/1/2 的協定名稱；v0.2 的「耕牛」沿用 dual（見 docs/protocol.md）
TYPE_INDEX = {w: i for i, w in enumerate(TYPE_WIRE)}
UPGRADE_KINDS = ("pen", "bucket", "warehouse", "fresh", "field")
SELL_ALL_TOL = 1e-6  # 賣出數量和庫存差在這以內，視為全部賣出
GOODS_NAME = {"milk": "牛奶", "beef": "牛肉", "rice": "稻米"}
CLEAN_DAYS = 7  # 成就 clean：連續幾天沒有牛生病（遊戲天）


class GameError(Exception):
    """玩家看得到的錯誤。status 是 HTTP 狀態碼，code 是穩定的英文代碼，message 是繁中說明。"""

    def __init__(self, code: str, message: str, status: int = 409, detail: Optional[dict] = None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.status = status
        self.detail = detail


# ---------------------------------------------------------------------------
# 等級（只是顯示）：累積收入（賣出 + 借種收入）≥ 500 × (2^(L−1) − 1) 就是 L 級
# ---------------------------------------------------------------------------
def level_threshold(level: int) -> int:
    return 500 * (2 ** (level - 1) - 1)


def level_for(earned: float) -> int:
    lv = 1
    while earned >= level_threshold(lv + 1):
        lv += 1
    return lv


def week_id(t: float) -> int:
    """遊戲時間所在的「週」（週一 00:00 台灣時間起算）。"""
    days = (t + TZ_OFFSET_S) / DAY
    return int(math.floor((days + 3.0) / 7.0))


def week_start(wid: int) -> float:
    return (wid * 7.0 - 3.0) * DAY - TZ_OFFSET_S


# ---------------------------------------------------------------------------
# 一位玩家
# ---------------------------------------------------------------------------
class Player:
    __slots__ = (
        "pid",
        "name",
        "is_bot",
        "token_hash",
        "created_at",
        "farm",
        "codex",
        "earned",
        "week",
        "week_earned",
        "bot",
        "version",
        "game_t",
        "rng_n",
        "stud_income",
        "name_words",
        "avatar",
        "renames",
        "ach",
        "ach_n",
        "prev_week",
        "prev_week_earned",
        "grown_ids",
        "parents",
        "pairs",
        "clean_from",
    )

    def __init__(
        self, pid: int, name: str, is_bot: bool, created_at: float, farm: Farm, token_hash: Optional[bytes] = None
    ):
        self.pid = pid
        self.name = name
        self.is_bot = is_bot
        self.token_hash = token_hash
        self.created_at = created_at
        self.farm = farm
        self.codex: Dict[str, float] = {}  # 圖鑑：品種代號 → 第一次發現的遊戲時間（24 種，server/breeds.py）
        self.earned = 0.0  # 累積收入（賣出 + 借種收入，幣），換算等級
        self.week = week_id(created_at)
        self.week_earned = 0.0
        self.bot: Optional[dict] = None  # 假玩家的排程資料
        self.version = 0  # 資料庫樂觀鎖的版本號
        self.game_t = created_at  # 最後一次寫入時的遊戲時間
        self.rng_n = 0  # 伺服器亂數的計數（每用一次 +1；重啟後接著數）
        self.stud_income = 0.0  # 借種收入累計（幣）
        self.name_words: Optional[List[int]] = None  # 電腦牧場名的三組詞編號（協定 1.6 節）；真人是 None
        # S21 牧場資料（D34）
        self.avatar: Optional[str] = None  # 頭像的品種代號；None = 沒選過（app 畫荷斯坦）
        self.renames = 0  # 改過幾次名；0 = 下次改名免費
        self.ach: Dict[str, float] = {}  # 成就 → 解鎖的遊戲時間（分階段的 key 是 level.1 這種，server/achievements.py）
        self.ach_n: Dict[str, float] = {}  # 有計數的成就 → 目前的數字（gradeA、popularBull、rice）
        # 上一週的週收入：新的一週第一次有收入時 week_earned 會歸零，週冠軍要看上一週的（runtime 的週結算）
        self.prev_week: Optional[int] = None
        self.prev_week_earned = 0.0
        # v0.3 C1：長大揭曉（Game.observe_care）
        self.grown_ids: Set[int] = set()  # 已經處理過長大揭曉的牛（只留還在牧場的）
        self.parents: Dict[int, List] = {}  # 真人配種、借種生的小牛 → [爸爸的基因, 爸爸是雜種, 媽媽的基因, 媽媽是雜種]
        # 配種表（C1b）："爸爸品種,媽媽品種,小牛品種"（畫面上的品種）→ [第一次長大的時間, 配出過幾次]
        self.pairs: Dict[str, List[float]] = {}
        self.clean_from: Optional[float] = created_at  # 成就 clean：從什麼時候起沒有牛生病（None = 現在有病牛）

    def found(self, breed: str, t: float) -> None:
        """圖鑑：記第一次發現的時間（長大揭曉那一刻）；之後出貨也不會消失。"""
        if breed not in self.codex or t < self.codex[breed]:
            self.codex[breed] = t

    def codex_count(self) -> int:
        """圖鑑發現了幾種（24 種裡的；雜種牛不算，企劃 v0.3 第 1.1 節）：收藏榜、成就 codex。"""
        return sum(1 for b in self.codex if b != HYBRID_BREED)

    def add_income(self, coins: float, now: float) -> None:
        self.earned += coins
        w = week_id(now)
        if w != self.week:
            self.prev_week, self.prev_week_earned = self.week, self.week_earned
            self.week, self.week_earned = w, 0.0
        self.week_earned += coins
        self.observe_level(now)

    # ---- 成就（S21） ----
    def unlock(self, key: str, now: float) -> None:
        """記第一次解鎖的遊戲時間；已經解鎖的不變（同一次結算裡更早的時間優先）。"""
        if key not in self.ach or now < self.ach[key]:
            self.ach[key] = now

    def count(self, key: str, amount: float, now: float) -> None:
        """有計數的成就加 amount，到目標就解鎖。"""
        n = self.ach_n.get(key, 0.0) + amount
        self.ach_n[key] = n
        if n >= A.goal_of(key):
            self.unlock(key, now)

    def observe_tiers(self, key: str, value: float, now: float) -> None:
        """分階段的成就：value 到了哪幾階就解鎖哪幾階。"""
        for i, goal in enumerate(A.GOALS[key], start=1):
            if value >= goal:
                self.unlock(A.tier_key(key, i), now)

    def observe_level(self, now: float) -> None:
        self.observe_tiers("level", self.level(), now)

    def week_income(self, wid: int) -> float:
        """某一週的收入（週結算用）：這一週或上一週的才記得，更早的是 0。"""
        if self.week == wid:
            return self.week_earned
        if self.prev_week == wid:
            return self.prev_week_earned
        return 0.0

    def weekly_income(self, now: float) -> float:
        return self.week_earned if self.week == week_id(now) else 0.0

    def level(self) -> int:
        return level_for(self.earned)

    # ---- 存檔 ----
    def state_dict(self) -> dict:
        return {
            "farm": self.farm.to_dict(),
            "codex": dict(sorted(self.codex.items())),
            "earned": self.earned,
            "week": self.week,
            "week_earned": self.week_earned,
            "bot": self.bot,
            "rng_n": self.rng_n,
            "stud_income": self.stud_income,
            "name_words": self.name_words,
            "avatar": self.avatar,
            "renames": self.renames,
            "ach": dict(sorted(self.ach.items())),
            "ach_n": dict(sorted(self.ach_n.items())),
            "prev_week": self.prev_week,
            "prev_week_earned": self.prev_week_earned,
            "grown_ids": sorted(self.grown_ids),
            "parents": {str(k): v for k, v in sorted(self.parents.items())},
            "pairs": dict(sorted(self.pairs.items())),
            "clean_from": self.clean_from,
        }

    @classmethod
    def from_state(
        cls,
        params: EconomyParams,
        pid: int,
        name: str,
        is_bot: bool,
        created_at: float,
        state: dict,
        token_hash: Optional[bytes] = None,
        version: int = 0,
        game_t: Optional[float] = None,
    ) -> "Player":
        p = cls(pid, name, is_bot, created_at, Farm.from_dict(params, state["farm"]), token_hash)
        p.codex = dict(state.get("codex", {}))  # 舊格式（v0.2 的 [用途, 稀有度]）的世界在載入前就被拒絕（runtime）
        p.earned = state.get("earned", 0.0)
        p.week = state.get("week", week_id(created_at))
        p.week_earned = state.get("week_earned", 0.0)
        p.bot = state.get("bot")
        p.version = version
        p.game_t = game_t if game_t is not None else created_at
        p.rng_n = state.get("rng_n", 0)
        p.stud_income = state.get("stud_income", 0.0)
        p.name_words = state.get("name_words")
        # S21 以前的存檔沒有這些：照預設（沒選過頭像、沒改過名、沒有成就）
        p.avatar = state.get("avatar")
        p.renames = state.get("renames", 0)
        p.ach = dict(state.get("ach", {}))
        p.ach_n = dict(state.get("ach_n", {}))
        p.prev_week = state.get("prev_week")
        p.prev_week_earned = state.get("prev_week_earned", 0.0)
        # v0.3 C1（存檔格式 5；更舊的世界在載入前就被拒絕）
        p.grown_ids = set(state.get("grown_ids", ()))
        p.parents = {int(k): list(v) for k, v in state.get("parents", {}).items()}
        p.pairs = PAIRINGS.load(state.get("pairs", {}))  # C1b：[第一次的時間, 次數]（C1a 只記時間）
        p.clean_from = state.get("clean_from", created_at)
        return p

    def copy(self) -> "Player":
        """深複製（存檔失敗時還原用）。"""
        p = Player.from_state(
            self.farm.p,
            self.pid,
            self.name,
            self.is_bot,
            self.created_at,
            json.loads(json.dumps(self.state_dict())),
            self.token_hash,
            self.version,
            self.game_t,
        )
        return p


# ---------------------------------------------------------------------------
# 服務層
# ---------------------------------------------------------------------------
class Game:
    def __init__(
        self,
        params: EconomyParams = DEFAULT,
        seed: str = "cowfarm",
        t0: float = 0.0,
        exchange: Optional[Exchange] = None,
        events_enabled: bool = True,
        stud: Optional[StudMarket] = None,
    ):
        self.params = params
        self.seed = str(seed)
        self.ex = exchange if exchange is not None else Exchange(params, self.seed, t0, events_enabled=events_enabled)
        self.cids: Tuple[str, ...] = tuple(self.ex.markets)
        self.stud = stud if stud is not None else StudMarket(params)
        self.players: Dict[int, Player] = {}
        self.next_pid = 1
        self.trade_seq = 0  # 成交序號；當機回復時照這個順序重建 pending
        self.captured: List[dict] = []  # 還沒寫進資料庫的成交紀錄
        self.touched: Set[int] = set()  # 這個動作改到的「別的」玩家
        self.backups: Dict[int, Player] = {}  # 改之前的樣子（存檔失敗時還原）
        self.stud_dirty = False  # 借種市場有沒有改
        self.stud_events: List[dict] = []  # 借種成交（給執行期通知主人）
        # 週冠軍（成就 weekChamp）：週 id → 那一週收入第 1 名的玩家（沒人有收入是 None）。執行期在每個 tick 結算、存在 meta
        self.week_champs: Dict[int, Optional[int]] = {}
        self.champ_week: Optional[int] = None  # 已經結算到哪一週（這一週還沒結束）

    # ---- 共用 ----
    def player(self, pid: int) -> Player:
        p = self.players.get(pid)
        if p is None:  # pid 都是驗過 token 的玩家；不在表示牧場剛被刪除，跟之後的請求一樣回 401（協定 5.6）
            raise GameError("unauthorized", "登入憑證無效", 401)
        return p

    def _rng(self, p: Player, rng: Optional[random.Random]) -> random.Random:
        """真人的亂數：由伺服器秘密種子、玩家、計數導出（每次用都不同、重啟後接著數、不必另存亂數狀態）。"""
        if rng is not None:
            return rng
        p.rng_n += 1
        return random.Random(f"{self.seed}:rng:{p.pid}:{p.rng_n}")

    def npc_rng(self) -> random.Random:
        """電腦假玩家補借種上架用的亂數（由上架編號導出，重啟後一樣）。"""
        return random.Random(f"{self.seed}:npc:{self.stud._next_id}")

    def _cow(self, p: Player, cow_id, field: str = "cow_id") -> Cow:
        if not isinstance(cow_id, int) or isinstance(cow_id, bool):
            raise GameError("bad_request", f"{field} 要是整數（牛的編號）", 400)
        c = p.farm.cow_by_id(cow_id)
        if c is None:
            raise GameError("cow_not_found", "找不到這頭牛", 404, {"cow_id": cow_id})
        return c

    def _touch(self, pid: int) -> None:
        """要改別的玩家之前呼叫：記下改之前的樣子。"""
        if pid not in self.backups and pid in self.players:
            self.backups[pid] = self.players[pid].copy()
        self.touched.add(pid)

    def begin(self) -> None:
        self.captured = []
        self.touched = set()
        self.backups = {}
        self.stud_dirty = False
        self.stud_events = []

    def take_captured(self) -> List[dict]:
        out, self.captured = self.captured, []
        return out

    # ---- 帳號 ----
    def create_player(
        self,
        now: float,
        name: str,
        is_bot: bool = False,
        rng: Optional[random.Random] = None,
        pid: Optional[int] = None,
        token_hash: Optional[bytes] = None,
    ) -> Player:
        if pid is None:
            pid = self.next_pid
        if pid in self.players:
            raise ValueError(f"player {pid} 已存在")
        self.next_pid = max(self.next_pid, pid + 1)
        # v0.3 照顧規則（大便、生病、變雜種）：C1 起全部牧場都開（存檔格式 5）
        farm = Farm(self.params, now, rng if rng is not None else random.Random(f"{self.seed}:new:{pid}"), care=True)
        p = Player(pid, name, is_bot, now, farm, token_hash)
        self.players[pid] = p
        self.settle(pid, now)  # 開局的成牛這一刻長大：圖鑑發現（小公牛長大時再發現）
        return p

    def add_player(self, p: Player) -> None:
        self.players[p.pid] = p
        self.next_pid = max(self.next_pid, p.pid + 1)

    # ---- 市場 ----
    def tick(self, t_end: float, online: float) -> None:
        self.ex.step(t_end, online)

    # ---- 收奶 ----
    def collect(self, pid: int, now: float) -> dict:
        p = self.player(pid)
        f = p.farm
        spoiled = f.drop_spoiled(now)
        took = f.collect(now)
        if took > 0:
            p.unlock("firstMilk", now)
        full = f.bucket_total() > 1e-9 and f.wh_used() >= f.wh_capacity() - 1e-9
        return {"collected": took, "spoiled": spoiled, "warehouse_full": full}

    def drop_spoiled(self, pid: int, now: float) -> float:
        return self.player(pid).farm.drop_spoiled(now)

    # ---- 賣出（牛奶、牛肉、稻米） ----
    def _check_sell(self, commodity: str, qty) -> None:
        if commodity not in self.cids:
            raise GameError("bad_request", "commodity 只能是 " + "、".join(self.cids), 400)
        if isinstance(qty, bool) or not isinstance(qty, (int, float)) or not math.isfinite(qty) or qty <= 0:
            raise GameError("bad_request", "qty 要是大於 0 的數字", 400)

    def stock(self, p: Player, commodity: str, now: float) -> float:
        f = p.farm
        if commodity == "milk":
            return sum(l.qty for l in f.lots if freshness(f.fp, (now - l.t) / HOUR, f.fresh_level) > 0.0)
        if commodity == "beef":
            return f.beef_stock()
        return f.rice_stock()

    def _resolve_qty(self, p: Player, commodity: str, qty: float, now: float) -> float:
        have = self.stock(p, commodity, now)
        name = GOODS_NAME.get(commodity, commodity)
        if have <= 0.0:
            raise GameError("not_enough_stock", f"倉庫裡沒有{name}可以賣", 409, {"have": round(have, 6)})
        if qty > have + SELL_ALL_TOL:
            raise GameError("not_enough_stock", f"倉庫裡沒有這麼多{name}", 409, {"have": round(have, 6), "want": qty})
        return have if qty >= have - SELL_ALL_TOL else float(qty)

    def quote(self, pid: int, commodity: str, qty, now: float) -> dict:
        """賣出前試算，不改任何狀態。"""
        p = self.player(pid)
        self._check_sell(commodity, qty)
        q = self._resolve_qty(p, commodity, float(qty), now)
        m = self.ex.markets[commodity]
        f = p.farm
        res = {"milk": f.quote_milk, "beef": f.quote_beef, "rice": f.quote_rice}[commodity](m, q, now)
        return _sale_dict(commodity, res)

    def sell(self, pid: int, commodity: str, qty, now: float) -> dict:
        p = self.player(pid)
        self._check_sell(commodity, qty)
        f = p.farm
        if commodity == "milk":
            f.drop_spoiled(now)
        q = self._resolve_qty(p, commodity, float(qty), now)
        m = self.ex.markets[commodity]
        market_t = self.ex.t
        res = {"milk": f.sell_milk, "beef": f.sell_beef, "rice": f.sell_rice}[commodity](m, q, now)
        coins = round(res.proceeds)
        p.add_income(coins, now)
        out = _sale_dict(commodity, res)
        if res.units > 0:
            p.unlock("firstSale", now)
            if self.super_event_on(commodity, now):
                p.unlock("tailwind", now)  # 在超級大事件期間賣出
            self.trade_seq += 1
            self.captured.append(
                {
                    "seq": self.trade_seq,
                    "player_id": pid,
                    "commodity": commodity,
                    "qty": res.units,
                    "proceeds": res.proceeds,
                    "coins": coins,
                    "price": res.price,
                    "discount": res.avg_discount,
                    "t": now,
                    "market_t": market_t,
                    "contrib": list(m.last_contribution) if m.last_contribution else None,
                }
            )
        return out

    # ---- 出貨（當場評級，牛肉進倉庫） ----
    def _check_free(self, c: Cow, action: str) -> None:
        if c.field >= 0:
            raise GameError(
                "cow_in_field", f"這頭牛在田裡工作，先叫回來才能{action}", 409, {"cow_id": c.cid, "field": c.field}
            )
        if c.listed is not None:
            raise GameError(
                "cow_listed",
                f"這頭牛正在借種市場上架，先下架才能{action}",
                409,
                {"cow_id": c.cid, "listing_id": c.listed},
            )

    def ship_check(self, p: Player, c: Cow, now: float) -> None:
        if not c.is_adult(now):
            raise GameError("cow_not_adult", "小牛還沒長大，不能出貨", 409, {"cow_id": c.cid, "until": c.adult_at})
        self._check_free(c, "出貨")

    def ship(self, pid: int, cow_id, now: float, rng: Optional[random.Random] = None) -> dict:
        p = self.player(pid)
        c = self._cow(p, cow_id)
        self.ship_check(p, c, now)
        probs = beef_grade_probs(p.farm.fp, c, now)
        lot = p.farm.ship_to_storage(c, now, self._rng(p, rng))
        if lot is None:
            raise GameError("rejected", "現在不能出貨", 409)
        p.unlock("firstShip", now)
        if lot.grade == 0:
            p.count("gradeA", 1, now)
        return {"cow_id": c.cid, "lot": lot, "grade_probs": probs}

    def ship_and_sell(
        self, pid: int, cow_ids: Sequence[int], now: float, rng: Optional[random.Random] = None
    ) -> Optional[dict]:
        """一次出貨多頭並當場賣掉（同一筆單、滑價一起算）＝ Farm.ship_many。電腦假玩家用；
        倉庫裡原本的牛肉不動。不能出貨的牛略過；一頭都不能出貨時回傳 None。"""
        p = self.player(pid)
        f = p.farm
        cows = [c for c in (f.cow_by_id(i) for i in cow_ids) if c is not None and f.can_ship(c, now)]
        if not cows:
            return None
        m = self.ex.markets["beef"]
        market_t = self.ex.t
        res = f.ship_many(cows, m, now, self._rng(p, rng))
        coins = round(res.proceeds)
        p.add_income(coins, now)
        if res.units > 0:
            self.trade_seq += 1
            self.captured.append(
                {
                    "seq": self.trade_seq,
                    "player_id": pid,
                    "commodity": "beef",
                    "qty": res.units,
                    "proceeds": res.proceeds,
                    "coins": coins,
                    "price": res.price,
                    "discount": res.avg_discount,
                    "t": now,
                    "market_t": market_t,
                    "contrib": list(m.last_contribution) if m.last_contribution else None,
                }
            )
        return _sale_dict("beef", res)

    # ---- 商店（A／B／C 等級抽牛） ----
    def shop_grade(self, grade) -> int:
        names = self.params.farm.shop_grade_names
        if isinstance(grade, str) and grade in names:
            return names.index(grade)
        raise GameError("bad_request", "grade 只能是 " + "、".join(names), 400)

    def shop_buy(self, pid: int, grade, now: float, rng: Optional[random.Random] = None) -> Cow:
        p = self.player(pid)
        f = p.farm
        gi = grade if isinstance(grade, int) and not isinstance(grade, bool) else self.shop_grade(grade)
        price = f.fp.shop_grade_price[gi]
        if f.free_slots() <= 0:
            raise GameError("pen_full", "牛舍滿了，先擴建或出貨", 409, {"slots": f.slots})
        if f.coins < price:
            raise GameError(
                "not_enough_coins", "金幣不夠", 409, {"need": int(round(price)), "have": int(round(f.coins))}
            )
        cow = f.buy_shop(gi, now, self._rng(p, rng))
        if cow is None:
            raise GameError("rejected", "現在不能買牛", 409)
        return cow  # 抽到的是小牛：長大揭曉時才算發現（observe_care）

    def shop_info(self) -> List[dict]:
        fp = self.params.farm
        out = []
        for gi, name in enumerate(fp.shop_grade_names):
            dist = shop_grade_distribution(fp, gi)
            type_p = [0.0, 0.0, 0.0]
            bull_p = 0.0
            rows = []
            for (t, bull, mask), pr in sorted(dist.items()):
                type_p[t] += pr
                if bull:
                    bull_p += pr
                rows.append(
                    {
                        "type": TYPE_WIRE[t],
                        "bull": bull,
                        "traits": mask,
                        "tier": bin(mask).count("1"),
                        "breed": breed_id(t, mask),
                        "p": pr,
                    }
                )
            out.append(
                {
                    "grade": name,
                    "price": int(round(fp.shop_grade_price[gi])),
                    "tier_probs": shop_grade_tier_probs(fp, gi),
                    "type_probs": {TYPE_WIRE[i]: type_p[i] for i in range(3)},
                    "bull_prob": bull_p,
                    "distribution": rows,
                }
            )
        return out

    # ---- 配種（自己的公母，免費，一輩子一次） ----
    def _breed_blockers(self, p: Player, c: Cow, now: float) -> List[dict]:
        out = []
        if not c.is_adult(now):
            out.append({"code": "cow_not_adult", "message": "還沒長大", "cow_id": c.cid, "until": c.adult_at})
        if c.bred:
            out.append({"code": "already_bred", "message": "這輩子已經配過種", "cow_id": c.cid})
        if c.field >= 0:
            out.append({"code": "cow_in_field", "message": "在田裡工作，先叫回來", "cow_id": c.cid})
        if c.listed is not None:
            out.append({"code": "cow_listed", "message": "正在借種市場上架，先下架", "cow_id": c.cid})
        if p.farm.is_sick(c, now):
            out.append({"code": "cow_sick", "message": "生病了，先治療", "cow_id": c.cid})
        return out

    def _breed_pair(self, p: Player, sire_id, dam_id, now: float) -> Tuple[Cow, Cow, List[dict]]:
        sire = self._cow(p, sire_id, "sire")
        dam = self._cow(p, dam_id, "dam")
        if sire is dam or not sire.bull or dam.bull:
            raise GameError("invalid_pair", "配種要一頭公牛（sire）和一頭母牛（dam）", 400)
        blockers = self._breed_blockers(p, sire, now) + self._breed_blockers(p, dam, now)
        if p.farm.free_slots() <= 0:
            blockers.append({"code": "pen_full", "message": "牛舍滿了，小牛沒地方放"})
        return sire, dam, blockers

    @staticmethod
    def _probs(sire_g: int, dam_g: int) -> dict:
        """配種、借種預覽的機率（協定 3.7、4.3）。distribution 的形狀跟商店（3.5）一樣，公母各半另外乘進去。"""
        dist = offspring_distribution(sire_g, dam_g)
        type_probs = [0.0, 0.0, 0.0]
        for (t, _mask), pr in dist.items():
            type_probs[t] += pr
        rows = [
            {
                "type": TYPE_WIRE[t],
                "bull": bull,
                "traits": mask,
                "tier": bin(mask).count("1"),
                "breed": breed_id(t, mask),
                "p": dist[(t, mask)] * (CALF_BULL_PROB if bull else 1.0 - CALF_BULL_PROB),
            }
            for t, bull, mask in sorted((t, bull, mask) for (t, mask) in dist for bull in (False, True))
        ]
        return {
            "tier_probs": tier_distribution(sire_g, dam_g),
            "type_probs": {TYPE_WIRE[i]: type_probs[i] for i in range(3)},
            "bull_prob": CALF_BULL_PROB,
            "distribution": rows,
        }

    def breed_preview(self, pid: int, sire_id, dam_id, now: float) -> dict:
        p = self.player(pid)
        sire, dam, blockers = self._breed_pair(p, sire_id, dam_id, now)
        return {
            "sire": sire.cid,
            "dam": dam.cid,
            **self._probs(sire.g, dam.g),
            "can_breed": not blockers,
            "blockers": blockers,
        }

    def breed(self, pid: int, sire_id, dam_id, now: float, rng: Optional[random.Random] = None) -> dict:
        p = self.player(pid)
        sire, dam, blockers = self._breed_pair(p, sire_id, dam_id, now)
        if blockers:
            b = blockers[0]
            detail = {k: v for k, v in b.items() if k not in ("code", "message")}
            raise GameError(b["code"], b["message"], 409, detail or None)
        calf = p.farm.breed(sire, dam, now, self._rng(p, rng))
        if calf is None:
            raise GameError("rejected", "現在不能配種", 409)
        self._note_parents(p, calf, sire.g, sire.hybrid, dam)
        p.unlock("newLife", now)  # 第一次配種生出小牛
        return {"calf": calf, "sire": sire, "dam": dam}

    # ---- 田地 ----
    def _field_index(self, p: Player, field) -> int:
        if field is None:
            i = p.farm.free_field()
            if i < 0:
                raise GameError("no_free_field", "沒有空的田，先擴建田地或叫回一頭牛", 409)
            return i
        if not isinstance(field, int) or isinstance(field, bool):
            raise GameError("bad_request", "field 要是整數（田的編號，從 0 開始）", 400)
        if not 0 <= field < len(p.farm.fields):
            raise GameError("field_not_found", "沒有這塊田", 404, {"field": field})
        if p.farm.fields[field].ox >= 0:
            raise GameError(
                "field_occupied", "這塊田已經有牛在工作", 409, {"field": field, "cow_id": p.farm.fields[field].ox}
            )
        return field

    def field_assign(self, pid: int, cow_id, field, now: float) -> dict:
        p = self.player(pid)
        c = self._cow(p, cow_id)
        if c.ctype != OX:
            raise GameError("not_an_ox", "只有耕牛能下田", 409, {"cow_id": c.cid})
        if not c.is_adult(now):
            raise GameError("cow_not_adult", "小牛還沒長大，不能下田", 409, {"cow_id": c.cid, "until": c.adult_at})
        self._check_free(c, "下田")
        self._check_healthy(p, c, now)
        i = self._field_index(p, field)
        if not p.farm.assign_field(c, i, now):
            raise GameError("rejected", "現在不能下田", 409)
        return {"cow_id": c.cid, "field": i}

    def field_recall(self, pid: int, cow_id, now: float) -> dict:
        p = self.player(pid)
        c = self._cow(p, cow_id)
        if c.field < 0:
            raise GameError("cow_not_in_field", "這頭牛沒有在田裡", 409, {"cow_id": c.cid})
        i = c.field
        p.farm.recall(c, now)
        return {"cow_id": c.cid, "field": i}

    def harvest(self, pid: int, now: float) -> dict:
        p = self.player(pid)
        kg = p.farm.harvest(now)
        if kg > 0:
            p.count("rice", kg, now)
        return {"harvested": kg}

    # ---- 借種市場 ----
    def _listing(self, lid) -> "object":
        if not isinstance(lid, int) or isinstance(lid, bool):
            raise GameError("bad_request", "listing_id 要是整數", 400)
        lst = self.stud.listings.get(lid)
        if lst is None:
            raise GameError("listing_not_found", "這筆借種已經不在了（被借走或下架）", 404, {"listing_id": lid})
        return lst

    def stud_fee(self, lst, now: float) -> dict:
        """借種費（協定 1.6 節）：這一刻依公牛的體重和稀有度算（D26）。"""
        price, kg, at_max = self.stud.fee(lst, now)
        return stud_fee_view(self.params.farm, lst.vt, price, kg, at_max)  # 價值等級：雜種公牛每公斤 0.6

    def stud_list(self, pid: int, cow_id, now: float) -> dict:
        """上架：主人只決定要不要上架，借種費由系統算（D26）。"""
        p = self.player(pid)
        c = self._cow(p, cow_id)
        if not c.bull:
            raise GameError("not_a_bull", "只有公牛能上架借種", 409, {"cow_id": c.cid})
        if not c.is_adult(now):
            raise GameError("cow_not_adult", "還沒長大，不能上架", 409, {"cow_id": c.cid, "until": c.adult_at})
        if c.bred:
            raise GameError("already_bred", "這頭公牛這輩子已經配過種", 409, {"cow_id": c.cid})
        self._check_free(c, "上架")
        self._check_healthy(p, c, now)
        lst = self.stud.list_bull(p.farm, pid, c, now)
        if lst is None:
            raise GameError("rejected", "現在不能上架", 409)
        self.stud_dirty = True
        return {"listing": lst}

    def stud_unlist(self, pid: int, lid) -> dict:
        p = self.player(pid)
        lst = self._listing(lid)
        if lst.owner != pid:
            raise GameError("listing_not_found", "這不是你的上架", 404, {"listing_id": lid})
        self.stud.unlist(lid, p.farm)
        self.stud_dirty = True
        return {"listing_id": lid, "cow_id": lst.cow_id}

    def _borrow_blockers(self, p: Player, lst, dam: Cow, now: float) -> List[dict]:
        out = []
        if lst.owner == p.pid:
            out.append({"code": "own_listing", "message": "這是你自己上架的公牛：自己的公牛直接配種（免費）"})
        out += self._breed_blockers(p, dam, now)
        if p.farm.free_slots() <= 0:
            out.append({"code": "pen_full", "message": "牛舍滿了，小牛沒地方放"})
        price = self.stud.price(lst, now)
        if p.farm.coins < price:
            out.append(
                {
                    "code": "not_enough_coins",
                    "message": "金幣不夠",
                    "need": int(round(price)),
                    "have": int(round(p.farm.coins)),
                }
            )
        if lst.owner is not None:
            owner = self.players.get(lst.owner)
            bull = owner.farm.cow_by_id(lst.cow_id) if owner else None
            if bull is None or bull.bred or bull.listed != lst.lid:
                out.append({"code": "listing_gone", "message": "這頭公牛已經不能借了"})
            elif owner.farm.is_sick(bull, now):
                out.append({"code": "bull_sick", "message": "這頭公牛生病了，主人治好以前不能借"})
        return out

    def stud_preview(self, pid: int, lid, dam_id, now: float) -> dict:
        p = self.player(pid)
        lst = self._listing(lid)
        dam = self._cow(p, dam_id, "dam")
        if dam.bull:
            raise GameError("invalid_pair", "借種要用自己的母牛（dam）", 400)
        blockers = self._borrow_blockers(p, lst, dam, now)
        return {
            "listing_id": lst.lid,
            "dam": dam.cid,
            "fee": self.stud_fee(lst, now),
            **self._probs(lst.g, dam.g),
            "can_borrow": not blockers,
            "blockers": blockers,
        }

    def stud_borrow(
        self,
        pid: int,
        lid,
        dam_id,
        now: float,
        rng: Optional[random.Random] = None,
        npc_rng: Optional[random.Random] = None,
        expected_price=None,
    ) -> dict:
        """借種，用這一刻的借種費。expected_price = 玩家預覽時看到的價格（API 一定帶；電腦假玩家不帶）：
        跟現在的不一樣就回 409 price_changed，什麼都不扣（S18-12）。"""
        p = self.player(pid)
        lst = self._listing(lid)
        dam = self._cow(p, dam_id, "dam")
        if dam.bull:
            raise GameError("invalid_pair", "借種要用自己的母牛（dam）", 400)
        price = self.stud.price(lst, now)
        if expected_price is not None:
            if isinstance(expected_price, bool) or not isinstance(expected_price, (int, float)):
                raise GameError("bad_request", "price 要是整數（預覽時看到的借種費）", 400, {"fields": ["price"]})
            if expected_price != price:
                raise GameError(
                    "price_changed",
                    "借種費變了",
                    409,
                    {"price": int(round(price)), "expected": expected_price},
                )
        blockers = self._borrow_blockers(p, lst, dam, now)
        if blockers:
            b = blockers[0]
            detail = {k: v for k, v in b.items() if k not in ("code", "message")}
            status = 404 if b["code"] == "listing_gone" else 409
            raise GameError(b["code"], b["message"], status, detail or None)
        owner = self.players.get(lst.owner) if lst.owner is not None else None
        if owner is not None:
            self._touch(owner.pid)  # 主人的牧場不先結算：借種不會讓揭曉、生病的紀錄漏掉，主人下次動作時照樣記到
        calf = self.stud.borrow(lst.lid, p.farm, pid, dam, now, self._rng(p, rng), owner.farm if owner else None)
        if calf is None:  # 上面已經檢查過，理論上不會發生
            raise GameError("rejected", "現在不能借種", 409)
        self.stud_dirty = True
        self._note_parents(p, calf, lst.g, lst.vt == HYBRID, dam)
        p.unlock("newLife", now)
        p.unlock("borrow", now)  # 第一次借到別人的公牛（公營種牛站的也算）
        if owner is not None:
            owner.stud_income += price
            owner.add_income(price, now)
            owner.count("popularBull", 1, now)  # 自己的公牛被借走
        else:
            self.stud.npc_refill(now, npc_rng if npc_rng is not None else self.npc_rng())
        self.stud_events.append(
            {
                "owner": lst.owner,
                "borrower": pid,
                "listing_id": lst.lid,
                "price": price,
                "cow_id": lst.cow_id,
                "g": lst.g,
                "hybrid": lst.vt == HYBRID,
                "t": now,
                "calf_id": calf.cid,
                "calf_g": calf.g,
            }
        )
        return {"calf": calf, "price": int(round(price)), "listing": lst, "dam": dam}

    # ---- 升級 ----
    def upgrade(self, pid: int, kind: str, now: float) -> dict:
        p = self.player(pid)
        f = p.farm
        if kind not in UPGRADE_KINDS:
            raise GameError("bad_request", "kind 只能是 " + "、".join(UPGRADE_KINDS), 400)
        cost = {
            "pen": f.next_pen_cost,
            "bucket": f.next_bucket_cost,
            "warehouse": f.next_wh_cost,
            "fresh": f.next_fresh_cost,
            "field": f.next_field_cost,
        }[kind]()
        if cost is None:
            raise GameError("max_level", "已經是最高級", 409)
        if kind == "pen" and not f.can_expand_at(now):
            open_at = f.created_at + self.params.onboarding.first_expand_unlock_s
            raise GameError("not_yet_available", "擴建還沒開放", 409, {"open_at": open_at})
        if f.coins < cost:
            raise GameError(
                "not_enough_coins", "金幣不夠", 409, {"need": int(round(cost)), "have": int(round(f.coins))}
            )
        ok = {
            "pen": f.expand_pen,
            "bucket": f.upgrade_bucket,
            "warehouse": f.upgrade_wh,
            "fresh": f.upgrade_fresh,
            "field": f.expand_field,
        }[kind](now)
        if not ok:
            raise GameError("rejected", "現在不能升級", 409)
        return {"kind": kind, "cost": int(round(cost))}

    # ---- 照顧（v0.3；協定 2.6 節）----
    def settle(self, pid: int, now: float) -> None:
        """結算到 now（長大揭曉、大便、生病、奶桶、田地），再記長大揭曉和生病的結果（observe_care）。
        執行期在每個動作之前叫：動作本身就不會再有新的揭曉、生病（同一個 now），出貨、治療之前的事件都記得到。"""
        p = self.player(pid)
        p.farm.advance(now)
        self.observe_care(p, now)

    def preview(self, p: Player, now: float) -> Player:
        """GET /v1/state 用：結算到 now 的複本（本身不改、不存檔）。結算跟幾時做無關，所以複本跟下一個動作
        會存的一樣：揭曉的品種、圖鑑的時間（= 長大的時間）、成就、大便、病牛都對得上。"""
        q = p.copy()
        q.farm.advance(now)
        self.observe_care(q, now)
        return q

    def observe_care(self, p: Player, now: float) -> None:
        """牧場結算以後叫（只讀牧場、改 Player）：
        - 長大揭曉：圖鑑（found_at = 長大的時間）、成就 legend、pureBreed、配種表（C1b）。
        - 成就 clean：連續 CLEAN_DAYS 天沒有牛生病（時間照生病、治好的那一刻精確算）。"""
        f = p.farm
        new = sorted((c for c in f.cows if c.grown and c.cid not in p.grown_ids), key=lambda c: (c.adult_at, c.cid))
        for c in new:
            t = c.adult_at
            child = shown_breed(c.g, c.hybrid)
            p.found(child, t)
            if not c.hybrid:
                if c.tier == 3:
                    p.unlock("legend", t)  # 擁有一頭傳說牛（長大、沒變雜種）
                if c.tier >= 2 and c.origin != "start":
                    p.unlock("pureBreed", t)  # 照品種的飼料養大一頭稀有以上的小牛
            par = p.parents.pop(c.cid, None)
            if par is not None and not c.hybrid:  # 變成雜種牛不算（企劃 13.2）
                PAIRINGS.record(p.pairs, shown_breed(par[0], par[1]), shown_breed(par[2], par[3]), child, t)
        p.grown_ids = {c.cid for c in f.cows if c.grown}
        live = {c.cid for c in f.cows}
        if any(cid not in live for cid in p.parents):  # 理論上小牛不會在長大前離開；保險起見不留孤兒
            p.parents = {k: v for k, v in p.parents.items() if k in live}
        sick = [c.sick_since for c in f.cows if c.sick_since is not None]
        if p.clean_from is not None:
            first = min(sick) if sick else now
            if first - p.clean_from >= CLEAN_DAYS * DAY:
                p.unlock("clean", p.clean_from + CLEAN_DAYS * DAY)
            if sick:
                p.clean_from = None
        elif not sick:
            p.clean_from = now  # 最後一頭病牛剛治好（或出貨）

    def _note_parents(self, p: Player, calf: Cow, sire_g: int, sire_hybrid: bool, dam: Cow) -> None:
        """真人配種、借種生的小牛：記爸媽，長大揭曉時寫進配種表（電腦假玩家不記）。"""
        if not p.is_bot:
            p.parents[calf.cid] = [sire_g, sire_hybrid, dam.g, dam.hybrid]

    def _check_healthy(self, p: Player, c: Cow, now: float) -> None:
        if p.farm.is_sick(c, now):
            raise GameError("cow_sick", "這頭牛生病了，先治療", 409, {"cow_id": c.cid})

    @staticmethod
    def _feed_index(feed) -> int:
        if not isinstance(feed, str) or feed not in FEED_INDEX:
            raise GameError("bad_request", "feed 要是飼料代號（協定 1.6 節）", 400, {"fields": ["feed"]})
        return FEED_INDEX[feed]

    @staticmethod
    def _floor_index(floor) -> int:
        if not isinstance(floor, str) or floor not in FLOOR_INDEX:
            raise GameError("bad_request", "floor 要是地板代號（協定 1.6 節）", 400, {"fields": ["floor"]})
        return FLOOR_INDEX[floor]

    @staticmethod
    def _int_arg(v, field: str, lo: int = 1) -> int:
        if isinstance(v, bool) or not isinstance(v, int) or v < lo:
            raise GameError("bad_request", f"{field} 要是 ≥ {lo} 的整數", 400, {"fields": [field]})
        return v

    @staticmethod
    def _coins(f: Farm, cost: float) -> None:
        if f.coins < cost:
            raise GameError(
                "not_enough_coins", "金幣不夠", 409, {"need": int(round(cost)), "have": int(round(f.coins))}
            )

    def feed_status(self, p: Player, c: Cow, now: float) -> Optional[str]:
        """這頭牛現在能不能吃（不看倉庫有沒有）：None 可以；full 吃飽冷卻中、listed 上架借種中、
        past_peak 過了最壯、bonus_max 加成滿了（cows[].feed_block）。"""
        f = p.farm
        cp = f.p.care
        if now < c.fed_until:
            return "full"
        if c.listed is not None:
            return "listed"
        if c.is_adult(now):
            if c.adult_age_h(now) >= f.fp.peak_age_h[c.ctype]:
                return "past_peak"
            if c.bonus >= cp.bonus_max_kg:
                return "bonus_max"
        return None

    @classmethod
    def parse_piles(cls, piles) -> Optional[Dict[int, int]]:
        """POST /v1/clean 的 piles：[{"cow_id", "n"}] → {牛的編號: 清幾坨}（同一頭牛出現幾次就加起來）；None = 全部清。"""
        if piles is None:
            return None
        bad = GameError("bad_request", "piles 要是 [{cow_id, n}] 的陣列（n 是 ≥ 1 的整數）", 400, {"fields": ["piles"]})
        if not isinstance(piles, list):
            raise bad
        out: Dict[int, int] = {}
        for x in piles:
            if not isinstance(x, dict):
                raise bad
            cid, n = x.get("cow_id"), x.get("n")
            for v in (cid, n):
                if isinstance(v, bool) or not isinstance(v, int):
                    raise bad
            if n < 1:
                raise bad
            out[cid] = out.get(cid, 0) + n
        return out

    def clean(self, pid: int, now: float, piles: Optional[Dict[int, int]] = None) -> dict:
        """清大便：piles = {牛的編號: 清幾坨}（app 劃過去清掉的）；None = 全部。"""
        p = self.player(pid)
        if piles is not None:
            for cid in piles:
                self._cow(p, cid)
        n = p.farm.clean(now, piles)
        return {"cleaned": n, "poop": sum(c.poop for c in p.farm.cows)}

    def cure(self, pid: int, cow_id, now: float, rng: Optional[random.Random] = None) -> dict:
        p = self.player(pid)
        f = p.farm
        c = self._cow(p, cow_id)
        f.advance(now)
        if c.sick_since is None:
            raise GameError("cow_not_sick", "這頭牛沒有生病", 409, {"cow_id": c.cid})
        cost = f.p.care.cure_price
        self._coins(f, cost)
        if not f.cure(c, now, self._rng(p, rng)):
            raise GameError("rejected", "現在不能治療", 409, {"cow_id": c.cid})
        p.unlock("healer", now)  # 治好一頭病牛
        return {"cow_id": c.cid, "cost": int(round(cost))}

    def _capture_feed(self, pid: int, fid: str, res, sign: int, now: float, market_t: float, m) -> None:
        """飼料的成交也記進成交紀錄（v0.3 B）：當機重啟時照順序把對飼料市場的貢獻加回去（commodity = 飼料代號）。
        coins：買是負的（花的錢）、賣回是正的；不算收入（等級、週收入照舊只看賣牛奶、牛肉、稻米和借種）。"""
        self.trade_seq += 1
        self.captured.append(
            {
                "seq": self.trade_seq,
                "player_id": pid,
                "commodity": fid,
                "qty": res.units,
                "proceeds": sign * res.amount,
                "coins": sign * int(round(res.amount)),
                "price": res.price,
                "discount": res.avg_slip,
                "t": now,
                "market_t": market_t,
                "contrib": list(m.last_contribution) if m.last_contribution else None,
            }
        )

    def buy_feed(self, pid: int, kind, n, now: float) -> dict:
        """跟飼料市場買（v0.3 B）：市價 ×（1 + 滑價），算進全服的買進量。kind：飼料代號或索引（電腦假玩家用索引）。
        回傳 cost（整數，畫面用）和 amount（實際扣的錢，未取整）。"""
        p = self.player(pid)
        f = p.farm
        cp = f.p.care
        k = kind if isinstance(kind, int) and not isinstance(kind, bool) else self._feed_index(kind)
        n = self._int_arg(n, "qty")
        if f.feeds[k] + n > cp.feed_cap:
            raise GameError(
                "feed_cap", "倉庫放不下這麼多飼料", 409, {"feed": FEED_IDS[k], "cap": cp.feed_cap, "have": f.feeds[k]}
            )
        m = self.ex.feeds[FEED_IDS[k]]
        self._coins(f, f.quote_feed_buy(k, n, m, now).amount)
        market_t = self.ex.t
        res = f.buy_feed_market(k, n, m, now)
        if res is None:
            raise GameError("rejected", "現在不能買飼料", 409)
        self._capture_feed(pid, FEED_IDS[k], res, -1, now, market_t, m)
        return {
            "feed": FEED_IDS[k],
            "kind": k,
            "n": n,
            "cost": int(round(res.amount)),
            "amount": res.amount,
            "price": res.price,
        }

    def sell_feed(self, pid: int, kind, n, now: float) -> dict:
        """把飼料賣回飼料市場（v0.3 B）：市價 ×（1 − 手續費）× 滑價，算進全服的賣回量。這次只有電腦假玩家
        （飼料投機）用；HTTP 端點在 C2。"""
        p = self.player(pid)
        f = p.farm
        k = kind if isinstance(kind, int) and not isinstance(kind, bool) else self._feed_index(kind)
        n = self._int_arg(n, "qty")
        if f.feeds[k] < n:
            raise GameError("out_of_feed", "倉庫沒有這麼多飼料", 409, {"feed": FEED_IDS[k]})
        m = self.ex.feeds[FEED_IDS[k]]
        market_t = self.ex.t
        res = f.sell_feed_market(k, n, m, now)
        if res is None:
            raise GameError("rejected", "現在不能賣回飼料", 409)
        self._capture_feed(pid, FEED_IDS[k], res, 1, now, market_t, m)
        return {"feed": FEED_IDS[k], "kind": k, "n": n, "amount": res.amount, "price": res.price}

    def _feed_check(self, p: Player, c: Cow, k: int, now: float) -> None:
        f = p.farm
        if f.feeds[k] <= 0:
            raise GameError("out_of_feed", "倉庫沒有這種飼料", 409, {"feed": FEED_IDS[k]})
        why = self.feed_status(p, c, now)
        if why == "full":
            raise GameError("cow_full", "吃飽了，等一下再餵", 409, {"cow_id": c.cid, "until": c.fed_until})
        if why == "listed":
            raise GameError(
                "cow_listed", "正在借種市場上架，先下架才能餵", 409, {"cow_id": c.cid, "listing_id": c.listed}
            )
        if why is not None:
            raise GameError("feed_no_effect", "餵了也不會長肉", 409, {"cow_id": c.cid, "reason": why})

    def feed(self, pid: int, cow_id, kind, now: float) -> dict:
        """餵一頭牛一份飼料。kind：飼料代號或索引（電腦假玩家用索引）。"""
        p = self.player(pid)
        c = self._cow(p, cow_id)
        k = kind if isinstance(kind, int) and not isinstance(kind, bool) else self._feed_index(kind)
        self._feed_check(p, c, k, now)
        if not p.farm.feed(c, k, now):
            raise GameError("rejected", "現在不能餵", 409, {"cow_id": c.cid})
        return {"cow_id": c.cid, "feed": FEED_IDS[k], "kind": k}

    def feed_all(self, pid: int, kind, now: float) -> dict:
        """全部餵一樣的（企劃 2.2）：現在能吃這種飼料的牛各餵一份，份數不夠先餵小牛、再照編號。"""
        p = self.player(pid)
        f = p.farm
        k = self._feed_index(kind)
        if f.feeds[k] <= 0:
            raise GameError("out_of_feed", "倉庫沒有這種飼料", 409, {"feed": FEED_IDS[k]})
        order = sorted(f.cows, key=lambda c: (c.is_adult(now), c.cid))
        fed = []
        for c in order:
            if f.feeds[k] <= 0:
                break
            if f.feed_block(c, k, now) is None and f.feed(c, k, now):
                fed.append(c.cid)
        if not fed:
            raise GameError("nothing_to_feed", "現在沒有牛能吃這種飼料", 409, {"feed": FEED_IDS[k]})
        return {"feed": FEED_IDS[k], "fed": fed}

    def _max_days(self, until: float, now: float, max_days: int) -> None:
        if until - now > max_days * DAY + 1e-6:
            raise GameError("max_days", f"最多預付 {max_days} 天", 409, {"max_days": max_days})

    def hire_helper(self, pid: int, days, now: float) -> dict:
        p = self.player(pid)
        f = p.farm
        cp = f.p.care
        days = self._int_arg(days, "days")
        self._max_days(max(now, f.helper_until) + days * DAY, now, cp.helper_max_days)
        cost = cp.helper_price_per_day * days
        self._coins(f, cost)
        if not f.hire_helper(days, now):
            raise GameError("rejected", "現在不能雇小幫手", 409)
        return {"days": days, "cost": int(round(cost)), "until": f.helper_until}

    # ---- 大便掃地機：這次只有服務層（電腦假玩家用）；HTTP 端點、協定、錯誤碼在之後的伺服器 PR ----
    def buy_robot(self, pid: int, model: int, now: float, rng: Optional[random.Random] = None) -> dict:
        p = self.player(pid)
        if not p.farm.buy_robot(model, now, self._rng(p, rng)):
            raise GameError("rejected", "現在不能買這款掃地機", 409)
        return {"model": model}

    def repair_robot(self, pid: int, now: float, rng: Optional[random.Random] = None) -> dict:
        p = self.player(pid)
        if not p.farm.repair_robot(now, self._rng(p, rng)):
            raise GameError("rejected", "現在不能修掃地機", 409)
        return {"model": p.farm.robot}

    def buy_floor(self, pid: int, floor, now: float) -> dict:
        """買斷地板（軟墊地）。電腦假玩家傳索引。"""
        f = self.player(pid).farm
        cp = f.p.care
        i = floor if isinstance(floor, int) and not isinstance(floor, bool) else self._floor_index(floor)
        if (f.floors >> i) & 1:
            raise GameError("floor_owned", "已經有這種地板了", 409, {"floor": FLOOR_IDS[i]})
        if cp.floor_price[i] <= 0:
            raise GameError("bad_request", "這種地板只能租", 400, {"fields": ["floor"]})
        self._coins(f, cp.floor_price[i])
        if not f.buy_floor(i, now):
            raise GameError("rejected", "現在不能買這種地板", 409)
        return {"floor": FLOOR_IDS[i], "cost": int(round(cp.floor_price[i]))}

    def rent_floor(self, pid: int, floor, days, now: float) -> dict:
        """租長快地板（按天預付，接在還沒到期的後面）；正在用這種地板的話，上架的公牛照新的租約算借種費。"""
        f = self.player(pid).farm
        cp = f.p.care
        i = floor if isinstance(floor, int) and not isinstance(floor, bool) else self._floor_index(floor)
        days = self._int_arg(days, "days")
        if cp.floor_rent_per_day[i] <= 0:
            raise GameError("bad_request", "這種地板不能租", 400, {"fields": ["floor"]})
        f.advance(now)  # 租約在 now 以前到期的先結算掉
        if f.rented and f.rented != i:
            raise GameError(
                "floor_rented",
                "已經租了別種地板，到期以後才能租這種",
                409,
                {"floor": FLOOR_IDS[f.rented], "until": f.rent_until},
            )
        self._max_days((f.rent_until if f.rented == i else now) + days * DAY, now, cp.floor_rent_max_days)
        cost = cp.floor_rent_per_day[i] * days
        self._coins(f, cost)
        if not f.rent_floor(i, days, now):
            raise GameError("rejected", "現在不能租這種地板", 409)
        self._follow_floor(pid, f)
        return {"floor": FLOOR_IDS[i], "days": days, "cost": int(round(cost)), "until": f.rent_until}

    def _follow_floor(self, pid: int, f) -> None:
        if self.stud.owner_listings(pid):
            self.stud.follow_owner(pid, f)
            self.stud_dirty = True

    def use_floor(self, pid: int, floor, now: float) -> dict:
        """換地板（年紀速度）；上架借種的公牛跟著主人的速度算借種費。換成正在用的那種：什麼都不變。"""
        f = self.player(pid).farm
        i = floor if isinstance(floor, int) and not isinstance(floor, bool) else self._floor_index(floor)
        f.advance(now)
        if not f.has_floor(i, now):
            raise GameError("floor_locked", "沒有這種地板（先買或租）", 409, {"floor": FLOOR_IDS[i]})
        if not f.use_floor(i, now):
            raise GameError("rejected", "現在不能換地板", 409)
        self._follow_floor(pid, f)
        return {"floor": FLOOR_IDS[i]}

    # ---- 排行榜用 ----
    # ---- 牧場資料（S21，D34） ----
    def rename(self, pid: int, name: str, now: float) -> dict:
        """改名：第一次免費，之後每次 RENAME_PRICE 幣，次數不限；#編號不變。name 已經照 D23 檢查過（執行期）。"""
        p = self.player(pid)
        cost = 0 if p.renames == 0 else A.RENAME_PRICE
        if p.farm.coins < cost:
            raise GameError("not_enough_coins", "金幣不夠", 409, {"need": cost, "have": int(round(p.farm.coins))})
        p.farm.coins -= cost
        p.name = name
        p.renames += 1
        return {"name": name, "cost": cost}

    def set_avatar(self, pid: int, breed, now: float) -> dict:
        """換頭像：只能選圖鑑裡發現過的品種（雜種牛 "hybrid" 也是，發現過才能選），免費。"""
        p = self.player(pid)
        if not isinstance(breed, str) or (breed not in ALL_BREEDS and breed != HYBRID_BREED):
            raise GameError("bad_request", "breed 要是品種代號（協定 1.6 節）", 400, {"fields": ["breed"]})
        if breed not in p.codex:
            raise GameError("avatar_locked", "還沒在圖鑑發現這個品種", 409, {"breed": breed})
        p.avatar = breed
        return {"avatar": breed}

    def super_event_on(self, commodity: str, now: float) -> bool:
        """這種商品現在是不是在超級大事件裡（成就 tailwind；D33 的新聞等級）。"""
        return any(
            ev.tier == "super" and commodity in ev.targets and ev.start_at <= now < ev.end_at for ev in self.ex.events
        )

    def observe_achievements(self, p: Player, now: float) -> None:
        """看現在的狀態解鎖的成就（等級、總資產）：執行期在每個動作之後叫。
        S21 以前就已經達標的牧場，在第一次動作時記成那個時間。"""
        p.observe_level(now)
        p.observe_tiers("rich", self.net_worth(p, now), now)

    def close_weeks(self, now: float) -> bool:
        """週結算（成就 weekChamp）：結束的每一週記收入第 1 名（同分照編號小的，跟排行榜一樣；電腦也算）。
        有結算回傳 True（執行期要存 meta）。第一次叫只記「從這一週開始」，不往回算。"""
        cur = week_id(now)
        if self.champ_week is None:
            self.champ_week = cur
            return True
        changed = False
        while self.champ_week < cur:
            w = self.champ_week
            best = max(
                ((p.week_income(w), -p.pid) for p in self.players.values() if p.week_income(w) > 0), default=None
            )
            self.week_champs[w] = -best[1] if best is not None else None
            self.champ_week = w + 1
            changed = True
        return changed

    def week_champ_at(self, pid: int) -> Optional[float]:
        """這位玩家第一次拿週冠軍的時間（那一週結束、週一 00:00）；沒拿過是 None。"""
        weeks = [w for w, champ in self.week_champs.items() if champ == pid]
        return week_start(min(weeks) + 1) if weeks else None

    def net_worth(self, p: Player, now: float) -> float:
        m = self.ex.markets
        return p.farm.net_worth(now, m["milk"].price, m["beef"].price, m["rice"].price if "rice" in m else None)


def _sale_dict(commodity: str, res) -> dict:
    total = round(res.proceeds)
    return {
        "commodity": commodity,
        "qty": res.units,
        "proceeds": res.proceeds,
        "total": total,
        "avg_price": res.proceeds / res.units if res.units > 0 else 0.0,
        "discount": res.avg_discount,
        "market_price": res.price,
        "counted": res.counted,
    }


def stud_fee_view(fp, tier: int, price: float, kg: float, at_max: bool) -> dict:
    """協定 1.6 節的借種費物件。"""
    return {"price": int(round(price)), "per_kg": fp.stud_fee_per_kg[tier], "kg": round(kg, 2), "at_max": at_max}


def ship_value(game: Game, p: Player, cow: Cow, now: float, mult: Optional[float] = None, cured: bool = False) -> float:
    """這頭牛現在出貨、立刻賣掉的估計收入（幣，含這位玩家的滑價）。mult 沒給就用評級期望值（含稀有度、雜種牛的倍數）。
    病牛再乘 sick_beef_mult（只剩一成）；cured = True 算治好以後（治療馬上好，體重、評級不變）。小牛是 0。"""
    from cowecon.farm import beef_expected_mult, beef_weight

    if not cow.is_adult(now):
        return 0.0
    f = p.farm
    w = beef_weight(f.fp, cow, now)
    if mult is None:
        mult = beef_expected_mult(f.fp, cow, now)
    if not cured and f.is_sick(cow, now):
        mult *= f.p.care.sick_beef_mult
    res = game.ex.markets["beef"].quote(f.impact["beef"], [(w, mult)], now)
    return res.proceeds
