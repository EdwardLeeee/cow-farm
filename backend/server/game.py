"""服務層：所有會改變遊戲狀態的動作都在這裡，真人（HTTP API）和電腦假玩家呼叫同一組函式。

規則
- 全部是同步函式，中間沒有 await：在 asyncio 伺服器裡，一個動作從讀到改完不會被別的請求插隊。
- 先檢查、後修改：檢查不過就丟 GameError，狀態一點都沒動；檢查過了才呼叫 cowecon 的方法。
- 時間 now 一律是「遊戲時間」（Unix 秒），由呼叫端給：API 用伺服器的遊戲時鐘，假玩家用排程時間，
  測試用模擬時間。手機不送任何時間。
- 每筆成交記在 self.captured（成交紀錄，含對下一個 tick 的貢獻），由呼叫端寫進資料庫的 trades 表；
  依 T1，成交只寫 trades，全服成交量由市場 tick 彙總。
"""

from __future__ import annotations

import math
import random
from typing import Dict, List, Optional, Sequence, Tuple

from cowecon import DEFAULT, EconomyParams, Exchange, Farm
from cowecon.farm import Cow, breed_fee, freshness, offspring_distribution, tier_distribution
from cowecon.params import DAY, HOUR, TZ_OFFSET_S

COMMODITIES = ("milk", "beef")
TYPE_WIRE = ("dairy", "dual", "beef")  # cowecon 的用途 0/1/2
TYPE_INDEX = {w: i for i, w in enumerate(TYPE_WIRE)}
UPGRADE_KINDS = ("pen", "bucket", "warehouse", "fresh")
SELL_ALL_TOL = 1e-6  # 賣出數量和庫存差在這以內，視為全部賣出


class GameError(Exception):
    """玩家看得到的錯誤。status 是 HTTP 狀態碼，code 是穩定的英文代碼，message 是繁中說明。"""

    def __init__(self, code: str, message: str, status: int = 409, detail: Optional[dict] = None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.status = status
        self.detail = detail


# ---------------------------------------------------------------------------
# 等級（只是顯示）：累積賣出收入 ≥ 500 × (2^(L−1) − 1) 就是 L 級
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
        "pid", "name", "is_bot", "token_hash", "created_at", "farm", "codex", "earned",
        "week", "week_earned", "bot", "version", "game_t",
    )

    def __init__(self, pid: int, name: str, is_bot: bool, created_at: float, farm: Farm, token_hash: Optional[bytes] = None):
        self.pid = pid
        self.name = name
        self.is_bot = is_bot
        self.token_hash = token_hash
        self.created_at = created_at
        self.farm = farm
        self.codex: set = set()  # {(用途 0–2, 稀有度 0–3)}：出現過的牛
        self.earned = 0.0  # 累積賣出收入（幣），換算等級
        self.week = week_id(created_at)
        self.week_earned = 0.0
        self.bot: Optional[dict] = None  # 假玩家的排程資料（策略、加入時間、S4 已安排的回訪…）
        self.version = 0  # 資料庫樂觀鎖的版本號
        self.game_t = created_at  # 最後一次寫入時的遊戲時間

    def add_codex(self, cow: Cow) -> None:
        self.codex.add((cow.ctype, cow.tier))

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
            "codex": sorted([list(x) for x in self.codex]),
            "earned": self.earned,
            "week": self.week,
            "week_earned": self.week_earned,
            "bot": self.bot,
        }

    @classmethod
    def from_state(cls, params: EconomyParams, pid: int, name: str, is_bot: bool, created_at: float, state: dict,
                   token_hash: Optional[bytes] = None, version: int = 0, game_t: Optional[float] = None) -> "Player":
        p = cls(pid, name, is_bot, created_at, Farm.from_dict(params, state["farm"]), token_hash)
        p.codex = {tuple(x) for x in state.get("codex", [])}
        p.earned = state.get("earned", 0.0)
        p.week = state.get("week", week_id(created_at))
        p.week_earned = state.get("week_earned", 0.0)
        p.bot = state.get("bot")
        p.version = version
        p.game_t = game_t if game_t is not None else created_at
        return p


# ---------------------------------------------------------------------------
# 服務層
# ---------------------------------------------------------------------------
class Game:
    def __init__(self, params: EconomyParams = DEFAULT, seed: str = "cowfarm", t0: float = 0.0,
                 exchange: Optional[Exchange] = None, events_enabled: bool = True):
        self.params = params
        self.seed = str(seed)
        self.ex = exchange if exchange is not None else Exchange(params, self.seed, t0, events_enabled=events_enabled)
        self.players: Dict[int, Player] = {}
        self.next_pid = 1
        self.trade_seq = 0  # 成交序號；當機回復時照這個順序重建 pending
        self.captured: List[dict] = []  # 還沒寫進資料庫的成交紀錄

    # ---- 共用 ----
    def player(self, pid: int) -> Player:
        p = self.players.get(pid)
        if p is None:
            raise GameError("player_not_found", "找不到這個牧場", 404)
        return p

    def _rng(self, p: Player, rng: Optional[random.Random]) -> random.Random:
        """真人的亂數：由伺服器秘密種子、玩家、牧場的牛編號導出（可重現、重啟後不用另存亂數狀態）。"""
        if rng is not None:
            return rng
        return random.Random(f"{self.seed}:rng:{p.pid}:{p.farm._next_cid}")

    def _cow(self, p: Player, cow_id) -> Cow:
        if not isinstance(cow_id, int) or isinstance(cow_id, bool):
            raise GameError("bad_request", "牛的編號要是整數", 400)
        c = p.farm.cow_by_id(cow_id)
        if c is None:
            raise GameError("cow_not_found", "找不到這頭牛", 404, {"cow_id": cow_id})
        return c

    def take_captured(self) -> List[dict]:
        out, self.captured = self.captured, []
        return out

    # ---- 帳號 ----
    def create_player(self, now: float, name: str, is_bot: bool = False, rng: Optional[random.Random] = None,
                      pid: Optional[int] = None, token_hash: Optional[bytes] = None) -> Player:
        if pid is None:
            pid = self.next_pid
        if pid in self.players:
            raise ValueError(f"player {pid} 已存在")
        self.next_pid = max(self.next_pid, pid + 1)
        farm = Farm(self.params, now, rng if rng is not None else random.Random(f"{self.seed}:new:{pid}"))
        p = Player(pid, name, is_bot, now, farm, token_hash)
        for c in farm.cows:
            p.add_codex(c)
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

    # ---- 賣出 ----
    def _check_sell(self, p: Player, commodity: str, qty) -> None:
        if commodity not in COMMODITIES:
            raise GameError("bad_request", "commodity 只能是 milk 或 beef", 400)
        if isinstance(qty, bool) or not isinstance(qty, (int, float)) or not math.isfinite(qty) or qty <= 0:
            raise GameError("bad_request", "qty 要是大於 0 的數字", 400)

    def _stock(self, p: Player, commodity: str, now: float) -> float:
        f = p.farm
        if commodity == "milk":
            return sum(l.qty for l in f.lots if freshness(f.fp, (now - l.t) / HOUR, f.fresh_level) > 0.0)
        return f.beef_stock()

    def _resolve_qty(self, p: Player, commodity: str, qty: float, now: float) -> float:
        have = self._stock(p, commodity, now)
        if have <= 1e-9:
            raise GameError("not_enough_stock", "倉庫裡沒有" + ("牛奶" if commodity == "milk" else "牛肉") + "可以賣", 409, {"have": round(have, 6)})
        if qty > have + SELL_ALL_TOL:
            raise GameError("not_enough_stock", "倉庫裡沒有這麼多" + ("牛奶" if commodity == "milk" else "牛肉"), 409, {"have": round(have, 6), "want": qty})
        return have if qty >= have - SELL_ALL_TOL else float(qty)

    def quote(self, pid: int, commodity: str, qty, now: float) -> dict:
        """賣出前試算，不改任何狀態。"""
        p = self.player(pid)
        self._check_sell(p, commodity, qty)
        q = self._resolve_qty(p, commodity, float(qty), now)
        m = self.ex.markets[commodity]
        res = p.farm.quote_milk(m, q, now) if commodity == "milk" else p.farm.quote_beef(m, q, now)
        return _sale_dict(commodity, res)

    def sell(self, pid: int, commodity: str, qty, now: float) -> dict:
        p = self.player(pid)
        self._check_sell(p, commodity, qty)
        f = p.farm
        if commodity == "milk":
            f.drop_spoiled(now)
        q = self._resolve_qty(p, commodity, float(qty), now)
        m = self.ex.markets[commodity]
        market_t = self.ex.t
        res = f.sell_milk(m, q, now) if commodity == "milk" else f.sell_beef(m, q, now)
        coins = round(res.proceeds)
        p.add_income(coins, now)
        out = _sale_dict(commodity, res)
        if res.units > 0:
            self.trade_seq += 1
            self.captured.append({
                "seq": self.trade_seq, "player_id": pid, "commodity": commodity, "qty": res.units,
                "proceeds": res.proceeds, "coins": coins, "price": res.price, "discount": res.avg_discount,
                "t": now, "market_t": market_t, "contrib": list(m.last_contribution) if m.last_contribution else None,
            })
        return out

    # ---- 出貨 ----
    def ship(self, pid: int, cow_id, now: float) -> dict:
        p = self.player(pid)
        c = self._cow(p, cow_id)
        if not c.is_adult(now):
            raise GameError("cow_not_adult", "小牛還沒長大，不能出貨", 409, {"adult_at": c.adult_at})
        lot = p.farm.ship_to_storage(c, now)
        return {"cow_id": c.cid, "lot": lot}

    # ---- 買小牛 ----
    def buy_calf(self, pid: int, type_idx: int, bull: bool, now: float, rng: Optional[random.Random] = None) -> Cow:
        p = self.player(pid)
        f = p.farm
        if type_idx not in (0, 1, 2):
            raise GameError("bad_request", "type 只能是 dairy、dual 或 beef", 400)
        if f.free_slots() <= 0:
            raise GameError("pen_full", "牛舍滿了，先擴建或出貨", 409, {"slots": f.slots})
        if f.coins < f.fp.calf_price:
            raise GameError("not_enough_coins", "金幣不夠", 409, {"need": int(round(f.fp.calf_price)), "have": int(round(f.coins))})
        cow = f.buy_calf(type_idx, bool(bull), now, self._rng(p, rng))
        if cow is None:  # 上面已經檢查過，理論上不會發生
            raise GameError("rejected", "現在不能買小牛", 409)
        p.add_codex(cow)
        return cow

    # ---- 配種 ----
    def _breed_pair(self, p: Player, sire_id, dam_id, now: float) -> Tuple[Cow, Cow, List[dict]]:
        sire = self._cow(p, sire_id)
        dam = self._cow(p, dam_id)
        if sire is dam or not sire.bull or dam.bull:
            raise GameError("invalid_pair", "配種要一頭公牛（sire）和一頭母牛（dam）", 400)
        blockers: List[dict] = []
        f = p.farm
        for role, c in (("sire", sire), ("dam", dam)):
            if not c.is_adult(now):
                blockers.append({"code": "cow_not_adult", "message": "還沒長大", "cow_id": c.cid, "until": c.adult_at})
            elif now < c.ready_at:
                blockers.append({"code": "breed_cooldown", "message": "配種冷卻中", "cow_id": c.cid, "until": c.ready_at})
        if f.free_slots() <= 0:
            blockers.append({"code": "pen_full", "message": "牛舍滿了，小牛沒地方放"})
        fee = f.breed_cost(sire, dam)
        if f.coins < fee:
            blockers.append({"code": "not_enough_coins", "message": "金幣不夠", "need": int(round(fee)), "have": int(round(f.coins))})
        return sire, dam, blockers

    def breed_preview(self, pid: int, sire_id, dam_id, now: float) -> dict:
        p = self.player(pid)
        sire, dam, blockers = self._breed_pair(p, sire_id, dam_id, now)
        dist = offspring_distribution(sire.g, dam.g)
        type_probs = [0.0, 0.0, 0.0]
        for (t, _mask), pr in dist.items():
            type_probs[t] += pr
        return {
            "sire": sire.cid, "dam": dam.cid,
            "fee": int(round(p.farm.breed_cost(sire, dam))), "normal_fee": int(round(breed_fee(p.farm.fp, sire, dam))),
            "first_free": p.farm.breed_cost(sire, dam) == 0,
            "tier_probs": tier_distribution(sire.g, dam.g),
            "type_probs": {TYPE_WIRE[i]: type_probs[i] for i in range(3)},
            "bull_prob": 0.5,
            "can_breed": not blockers, "blockers": blockers,
        }

    def breed(self, pid: int, sire_id, dam_id, now: float, rng: Optional[random.Random] = None) -> dict:
        p = self.player(pid)
        sire, dam, blockers = self._breed_pair(p, sire_id, dam_id, now)
        if blockers:
            b = blockers[0]
            detail = {k: v for k, v in b.items() if k not in ("code", "message")}
            messages = {"cow_not_adult": "還沒長大，不能配種", "breed_cooldown": "配種冷卻中", "pen_full": "牛舍滿了，小牛沒地方放", "not_enough_coins": "金幣不夠"}
            raise GameError(b["code"], messages[b["code"]], 409, detail or None)
        fee = p.farm.breed_cost(sire, dam)
        calf = p.farm.breed(sire, dam, now, self._rng(p, rng))
        if calf is None:
            raise GameError("rejected", "現在不能配種", 409)
        p.add_codex(calf)
        return {"calf": calf, "fee": int(round(fee)), "sire": sire, "dam": dam}

    # ---- 升級 ----
    def upgrade(self, pid: int, kind: str, now: float) -> dict:
        p = self.player(pid)
        f = p.farm
        if kind not in UPGRADE_KINDS:
            raise GameError("bad_request", "kind 只能是 pen、bucket、warehouse 或 fresh", 400)
        cost = {"pen": f.next_pen_cost, "bucket": f.next_bucket_cost, "warehouse": f.next_wh_cost, "fresh": f.next_fresh_cost}[kind]()
        if cost is None:
            raise GameError("max_level", "已經是最高級", 409)
        if kind == "pen" and not f.can_expand_at(now):
            open_at = f.created_at + self.params.onboarding.first_expand_unlock_s
            raise GameError("not_yet_available", "擴建還沒開放", 409, {"open_at": open_at})
        if f.coins < cost:
            raise GameError("not_enough_coins", "金幣不夠", 409, {"need": int(round(cost)), "have": int(round(f.coins))})
        ok = {"pen": f.expand_pen, "bucket": f.upgrade_bucket, "warehouse": f.upgrade_wh, "fresh": f.upgrade_fresh}[kind](now)
        if not ok:
            raise GameError("rejected", "現在不能升級", 409)
        return {"kind": kind, "cost": int(round(cost))}

    # ---- 排行榜用 ----
    def net_worth(self, p: Player, now: float) -> float:
        return p.farm.net_worth(now, self.ex.markets["milk"].price, self.ex.markets["beef"].price)


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


def ship_value(game: Game, p: Player, cow: Cow, now: float) -> float:
    """這頭牛現在出貨、立刻賣掉的估計收入（幣，含這位玩家的滑價）。小牛是 0。"""
    from cowecon.farm import beef_quality, beef_weight

    if not cow.is_adult(now):
        return 0.0
    f = p.farm
    w = beef_weight(f.fp, cow, now)
    mult = beef_quality(f.fp, cow, now) * f.fp.tier_mult[cow.tier]
    res = game.ex.markets["beef"].quote(f.impact["beef"], [(w, mult)], now)
    return res.proceeds


def calf_types() -> Sequence[str]:
    return TYPE_WIRE
