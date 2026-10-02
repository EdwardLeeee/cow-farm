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

from .breeds import breed_id, breed_of_genes

CALF_BULL_PROB = 0.5  # 配種、借種生出公牛的機率（cowecon Farm.breed：rng.random() < 0.5，跟基因無關）
TYPE_WIRE = ("dairy", "dual", "beef")  # 基因用途 0/1/2 的協定名稱；v0.2 的「耕牛」沿用 dual（見 docs/protocol.md）
TYPE_INDEX = {w: i for i, w in enumerate(TYPE_WIRE)}
UPGRADE_KINDS = ("pen", "bucket", "warehouse", "fresh", "field")
SELL_ALL_TOL = 1e-6  # 賣出數量和庫存差在這以內，視為全部賣出
GOODS_NAME = {"milk": "牛奶", "beef": "牛肉", "rice": "稻米"}


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

    def add_codex(self, cow: Cow, now: float) -> None:
        """牛一出生（或抽到、借種生下）就算發現；記第一次的時間，之後出貨也不會消失。"""
        self.codex.setdefault(breed_of_genes(cow.g), now)

    def add_income(self, coins: float, now: float) -> None:
        self.earned += coins
        w = week_id(now)
        if w != self.week:
            self.week, self.week_earned = w, 0.0
        self.week_earned += coins

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
        farm = Farm(self.params, now, rng if rng is not None else random.Random(f"{self.seed}:new:{pid}"))
        p = Player(pid, name, is_bot, now, farm, token_hash)
        for c in farm.cows:
            p.add_codex(c, now)
        self.players[pid] = p
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
        p.add_codex(cow, now)
        return cow

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
        p.add_codex(calf, now)
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
        return {"harvested": p.farm.harvest(now)}

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
        return stud_fee_view(self.params.farm, lst.tier, price, kg, at_max)

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
            self._touch(owner.pid)
        calf = self.stud.borrow(lst.lid, p.farm, pid, dam, now, self._rng(p, rng), owner.farm if owner else None)
        if calf is None:  # 上面已經檢查過，理論上不會發生
            raise GameError("rejected", "現在不能借種", 409)
        self.stud_dirty = True
        p.add_codex(calf, now)
        if owner is not None:
            owner.stud_income += price
            owner.add_income(price, now)
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

    # ---- 排行榜用 ----
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


def ship_value(game: Game, p: Player, cow: Cow, now: float, mult: Optional[float] = None) -> float:
    """這頭牛現在出貨、立刻賣掉的估計收入（幣，含這位玩家的滑價）。mult 沒給就用評級期望值。小牛是 0。"""
    from cowecon.farm import beef_expected_mult, beef_weight

    if not cow.is_adult(now):
        return 0.0
    f = p.farm
    w = beef_weight(f.fp, cow, now)
    if mult is None:
        mult = beef_expected_mult(f.fp, cow, now)
    res = game.ex.markets["beef"].quote(f.impact["beef"], [(w, mult)], now)
    return res.proceeds
