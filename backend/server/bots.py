"""電腦假玩家：S1–S4 策略（S5 大戶與恐慌賣只給情境測試用）。

照 docs/research/economy/sim/bots.py 移植，判斷規則和數字完全相同；差別只在「動手」的部分
全部改成呼叫服務層（server.game.Game），和真人走同一組函式，對市場的影響也就一樣。
每一步呼叫 cowecon 的順序和原本的模擬相同，所以同一個 seed 的結果和研究模擬逐數字相同
（backend/tests/test_scenarios.py 會比對）。

- 教學（所有人）：開局 30 分鐘每分鐘動作一次：收奶賣奶、第一次擴建、第一次配種。
- S1 即賣：乳牛；每次上線把牛奶全部賣掉；產奶掉到八成以下就出貨換新牛。
- S2 牛肉派：肉用牛；牛奶照賣；到最佳體重就出貨。
- S3 配種收集：留最好的公牛，優先配種、留稀有牛；一般牛照 S1 規則出貨。
- S4 抓時機：乳牛；牛奶存倉庫，價格 ≥ 24 小時均價才賣，或新鮮度開始掉才賣；
  該出貨的牛等牛肉價好再出貨（有期限）；看到提前公告的利多會回來賣。
- S5 大戶（壓力測試）：開局給大牧場，囤貨後一次倒出、分批賣，或一直囤著（對照組）。

出貨在 M1 是兩步（牛 → 倉庫裡的牛肉 → 賣出）。假玩家出貨後立刻賣，結果和模擬的「出貨即賣出」相同。
"""

from __future__ import annotations

import random
from typing import List, Optional

from cowecon.farm import Cow, Farm, beef_quality, beef_weight, cow_milk_rate, freshness, milk_frac
from cowecon.params import HOUR, MINUTE

from .game import Game, GameError

STRATEGIES = ("S1", "S2", "S3", "S4", "S5")
STRATEGY_NAMES = {"S1": "即賣", "S2": "牛肉派", "S3": "配種收集", "S4": "抓時機", "S5": "大戶"}

BUCKET_TARGET_H = 6.0  # 奶桶至少放得下幾小時產量
DAIRY_SHIP_FRAC = 0.8  # 產奶掉到幾成以下就出貨
S4_PRICE_THR = 1.0  # S4：價格 ≥ 24 小時均價 × 這個倍數才賣
S4_FRESH_SELL = 0.97  # S4：新鮮度掉到這以下就賣
S4_WH_TARGET_H = 14.0  # S4：倉庫要放得下幾小時產量
S4_BEEF_WAIT_FRAC = 0.75  # S4：母牛產奶掉到這以下就不等牛肉價，直接出貨
S4_BULL_WAIT_H = 36.0  # S4：公牛過了最佳體重最多再等幾小時
S4_HOLD_MIN_COWS = 12  # S4：牛群少於這個數量時先照 S1 經營（早期存貨會拖慢擴建）
PANIC_SHIP_AGE_H = 48.0  # 恐慌賣時，成年滿幾小時的牛一起出貨

TUTORIAL_S = 30 * MINUTE


class Bot:
    """一位假玩家的決策狀態。牧場本身在 game.players[pid].farm（和真人一樣）。

    rng：配種與買小牛的亂數。None = 用服務層的預設（伺服器用）；情境測試給固定的亂數以便和模擬比對。
    """

    __slots__ = (
        "game", "pid", "strategy", "rng", "joined_at", "tut_end", "returns", "whale",
        "first_sale", "first_expand", "first_breed", "sched", "ledger", "worth",
    )

    def __init__(self, game: Game, pid: int, strategy: str, joined_at: float, rng: Optional[random.Random] = None):
        self.game = game
        self.pid = pid
        self.strategy = strategy
        self.rng = rng
        self.joined_at = joined_at
        self.tut_end = joined_at + TUTORIAL_S
        self.returns: set = set()  # S4：已經安排回來賣的事件
        self.whale: Optional[dict] = None
        self.first_sale: Optional[float] = None
        self.first_expand: Optional[float] = None
        self.first_breed: Optional[float] = None
        self.sched = None
        self.ledger = None
        self.worth = None

    @property
    def farm(self) -> Farm:
        return self.game.players[self.pid].farm


# ---------------------------------------------------------------------------
# 共用動作（都經過服務層）
# ---------------------------------------------------------------------------
def herd_milk_rate(f: Farm, now: float) -> float:
    return sum(cow_milk_rate(f.fp, c, now) for c in f.cows)


def sell_all_milk(b: Bot, now: float, max_rounds: int = 50) -> None:
    """收奶並全部賣掉；倉庫放不下時重複「收 → 賣」。和 Farm.sell_all_milk 同一個順序。"""
    g = b.game
    for _ in range(max_rounds):
        g.collect(b.pid, now)
        f = b.farm
        if not f.lots:
            break
        g.sell(b.pid, "milk", f.wh_used(), now)
        if f.bucket_total() <= 1e-9:
            break


def sell_lots_prefix(b: Bot, lots, now: float):
    """賣掉倉庫最前面（最舊）的這幾批。lots 一定是 f.lots 的前幾批。"""
    return b.game.sell(b.pid, "milk", sum(l.qty for l in lots), now)


def ship_and_sell(b: Bot, cows: List[Cow], now: float) -> Optional[dict]:
    """一次出貨多頭並立刻賣出（同一筆單，滑價一起算）＝ 模擬的 Farm.ship_many。"""
    cows = [c for c in cows if c in b.farm.cows and c.is_adult(now)]
    if not cows:
        return None
    for c in cows:
        b.game.ship(b.pid, c.cid, now)
    return b.game.sell(b.pid, "beef", b.farm.beef_stock(), now)


def try_upgrade(b: Bot, kind: str, now: float) -> bool:
    try:
        b.game.upgrade(b.pid, kind, now)
        return True
    except GameError:
        return False


def try_buy_calf(b: Bot, type_idx: int, bull: bool, now: float) -> Optional[Cow]:
    try:
        return b.game.buy_calf(b.pid, type_idx, bull, now, rng=b.rng)
    except GameError:
        return None


def try_breed(b: Bot, sire: Cow, dam: Cow, now: float) -> bool:
    try:
        b.game.breed(b.pid, sire.cid, dam.cid, now, rng=b.rng)
        return True
    except GameError:
        return False


def maintain_bucket(b: Bot, now: float) -> None:
    f = b.farm
    need = BUCKET_TARGET_H * herd_milk_rate(f, now)
    while f.bucket_capacity() < need:
        if not try_upgrade(b, "bucket", now):
            break


def fill_slots(b: Bot, now: float, type_idx: int, bull: bool = False, leave_free: int = 0) -> None:
    f = b.farm
    while f.free_slots() > leave_free and f.coins >= f.fp.calf_price:
        if try_buy_calf(b, type_idx, bull, now) is None:
            break


def expand_and_fill(b: Bot, now: float, type_idx: int) -> None:
    f = b.farm
    while True:
        cost = f.next_pen_cost()
        if cost is None or f.coins < cost + f.fp.calf_price or not f.can_expand_at(now):
            break
        try_upgrade(b, "pen", now)
        try_buy_calf(b, type_idx, False, now)


def ship_due(b: Bot, now: float, due) -> None:
    cows = [c for c in b.farm.cows if c.is_adult(now) and due(c)]
    if cows:
        ship_and_sell(b, cows, now)


def _milk(b: Bot):
    return b.game.ex.markets["milk"]


def _beef(b: Bot):
    return b.game.ex.markets["beef"]


# ---------------------------------------------------------------------------
# 教學：開局 30 分鐘
# ---------------------------------------------------------------------------
def tutorial_step(b: Bot, ctx, now: float) -> None:
    f = b.farm
    sell_all_milk(b, now)
    if f.free_slots() <= 0:
        try_upgrade(b, "pen", now)
    if f.free_slots() > 0:
        bulls = [c for c in f.cows if c.bull and c.is_adult(now) and now >= c.ready_at]
        cows = [c for c in f.cows if not c.bull and c.is_adult(now) and now >= c.ready_at]
        if bulls and cows:
            try_breed(b, bulls[0], cows[0], now)


# ---------------------------------------------------------------------------
# 策略
# ---------------------------------------------------------------------------
def _dairy_due(f: Farm, now: float):
    fp = f.fp

    def due(c: Cow) -> bool:
        if c.bull:
            return c.adult_age_h(now) >= fp.peak_age_h[c.ctype]
        return milk_frac(fp, c.adult_age_h(now)) < DAIRY_SHIP_FRAC

    return due


def s1(b: Bot, ctx, now: float) -> None:
    sell_all_milk(b, now)
    ship_due(b, now, _dairy_due(b.farm, now))
    fill_slots(b, now, 0)
    maintain_bucket(b, now)
    expand_and_fill(b, now, 0)


def s2(b: Bot, ctx, now: float) -> None:
    fp = b.farm.fp
    sell_all_milk(b, now)
    ship_due(b, now, lambda c: c.adult_age_h(now) >= fp.peak_age_h[c.ctype])
    fill_slots(b, now, 2)
    maintain_bucket(b, now)
    expand_and_fill(b, now, 2)


def _p_recessive(g: int, locus: int) -> float:
    return (((g >> (2 * locus)) & 1) + ((g >> (2 * locus + 1)) & 1)) / 2.0


def expected_tier(sire: int, dam: int) -> float:
    return sum(_p_recessive(sire, L) * _p_recessive(dam, L) for L in (1, 2, 3))


def _bull_score(c: Cow):
    carriers = sum(_p_recessive(c.g, L) for L in (1, 2, 3))
    return (c.tier, carriers, -c.born_at)


def s3(b: Bot, ctx, now: float) -> None:
    f = b.farm
    fp = f.fp
    sell_all_milk(b, now)
    bulls = [c for c in f.cows if c.bull]
    best = max(bulls, key=_bull_score) if bulls else None

    def due(c: Cow) -> bool:
        a = c.adult_age_h(now)
        if c.bull:
            if c is best:
                return a >= fp.milk_decline_end_h  # 種公牛留久一點
            return a >= fp.peak_age_h[c.ctype]
        limit = DAIRY_SHIP_FRAC if c.tier == 0 else 0.6  # 稀有母牛多留一陣子配種
        return milk_frac(fp, a) < limit

    ship_due(b, now, due)
    if best is None or best not in f.cows:
        bulls = [c for c in f.cows if c.bull]
        best = max(bulls, key=_bull_score) if bulls else None
    if best is None:
        if f.free_slots() > 0:
            try_buy_calf(b, 0, True, now)
    elif best.is_adult(now):
        # 每次上線用種公牛配一頭（公牛冷卻時間內只能配一次）
        ready = [c for c in f.cows if not c.bull and c.is_adult(now) and now >= c.ready_at]
        if ready and f.free_slots() > 0 and now >= best.ready_at:
            dam = max(ready, key=lambda c: (expected_tier(best.g, c.g), c.tier))
            try_breed(b, best, dam, now)
    fill_slots(b, now, 0, leave_free=1 if best is not None else 0)
    maintain_bucket(b, now)
    expand_and_fill(b, now, 0)


def s4(b: Bot, ctx, now: float) -> None:
    g = b.game
    f = b.farm
    fp = f.fp
    if len(f.cows) < S4_HOLD_MIN_COWS and not f.lots:
        s1(b, ctx, now)
        return
    mk = _milk(b)
    bk = _beef(b)
    g.drop_spoiled(b.pid, now)
    g.collect(b.pid, now)
    hot = mk.price >= mk.moving_average() * S4_PRICE_THR
    if hot:
        sell_all_milk(b, now)
    else:
        old = [l for l in f.lots if freshness(fp, (now - l.t) / HOUR, f.fresh_level) < S4_FRESH_SELL]
        if old:
            sell_lots_prefix(b, old, now)
        # 倉庫快滿或奶桶收不完：賣最舊的騰位置
        if f.bucket_total() > 1e-6 or f.wh_used() > 0.85 * f.wh_capacity():
            lots = sorted(f.lots, key=lambda l: l.t)
            need = f.bucket_total() + f.wh_used() - 0.6 * f.wh_capacity()
            sell, acc = [], 0.0
            for l in lots:
                if acc >= need:
                    break
                sell.append(l)
                acc += l.qty
            if sell:
                sell_lots_prefix(b, sell, now)
            g.collect(b.pid, now)
            if f.bucket_total() > 1e-6:
                sell_all_milk(b, now)
    # 提前公告的牛奶利多：安排在事件開始後 20 分鐘回來
    for ev in ctx.upcoming(now):
        if "milk" in ev.targets and ev.factor > 1.0 and ev.eid not in b.returns:
            b.returns.add(ev.eid)
            ctx.schedule(ev.start_at + 20 * MINUTE, b.pid, "s4_return", 5 * MINUTE)
    # 出貨：牛肉價好才出，但有期限
    beef_hot = bk.price >= bk.moving_average() * S4_PRICE_THR

    def due(c: Cow) -> bool:
        a = c.adult_age_h(now)
        if c.bull:
            if a < fp.peak_age_h[c.ctype]:
                return False
            return beef_hot or a >= fp.peak_age_h[c.ctype] + S4_BULL_WAIT_H
        fr = milk_frac(fp, a)
        if fr >= DAIRY_SHIP_FRAC:
            return False
        return beef_hot or fr < S4_BEEF_WAIT_FRAC

    ship_due(b, now, due)
    fill_slots(b, now, 0)
    maintain_bucket(b, now)
    rate = herd_milk_rate(f, now)
    if len(f.cows) >= 5 and f.fresh_level < 1:
        try_upgrade(b, "fresh", now)
    while f.wh_capacity() < S4_WH_TARGET_H * rate:
        if not try_upgrade(b, "warehouse", now):
            break
    expand_and_fill(b, now, 0)


def s4_return(b: Bot, ctx, now: float) -> None:
    """S4 看到公告後回來：價格夠好就把倉庫的牛奶全賣掉。"""
    mk = _milk(b)
    if mk.price >= mk.moving_average() * S4_PRICE_THR:
        sell_all_milk(b, now)


# ---------------------------------------------------------------------------
# S5 大戶（只有情境測試用）
# ---------------------------------------------------------------------------
def setup_whale(b: Bot, now: float, cfg: dict) -> None:
    """開局直接給大牧場：cfg['cows'] 頭乳牛（年齡錯開）、滿級奶桶、倉庫、冷藏。測試專用的管理動作。"""
    f = b.farm
    fp = f.fp
    n = cfg["cows"]
    f.slots = n + 2
    f.bucket_level = fp.bucket_max_level
    f.wh_level = fp.wh_max_level
    f.fresh_level = len(fp.fresh_costs)
    f.cows = []
    for i in range(n):
        c = Cow(f._new_id(), 0, False, now, fp, adult_at=now - (i % 24) * HOUR)
        f.cows.append(c)
    b.whale = dict(cfg)
    b.whale["results"] = []


def s5(b: Bot, ctx, now: float) -> None:
    w = b.whale
    mode = w["mode"]
    hoarding = mode != "none" and w["hoard_from"] <= now < w["dump_at"]
    if hoarding:
        b.game.collect(b.pid, now)  # 只收不賣；牛也不出貨
        if not w.get("scheduled"):
            w["scheduled"] = True
            if mode == "dump":
                ctx.schedule(w["dump_at"], b.pid, "whale_dump", 5 * MINUTE)
            elif mode == "batch":
                for k in range(w["batches"]):
                    ctx.schedule(w["dump_at"] + k * w["batch_gap_s"], b.pid, "whale_batch", 5 * MINUTE)
        return
    if mode != "none" and now >= w["dump_at"] and not w.get("done"):
        return  # 倒貨期間只由 whale_dump / whale_batch 動作
    # 平常：照 S1 經營，但牛群維持原規模（不擴建）
    sell_all_milk(b, now)
    ship_due(b, now, _dairy_due(b.farm, now))
    fill_slots(b, now, 0)


def _whale_sell(b: Bot, now: float, frac: float) -> None:
    f = b.farm
    w = b.whale
    b.game.collect(b.pid, now)
    lots = sorted(f.lots, key=lambda l: l.t)
    total = sum(l.qty for l in lots)
    target = total * frac
    sell, acc = [], 0.0
    for l in lots:
        if acc >= target - 1e-9:
            break
        sell.append(l)
        acc += l.qty
    if sell:
        values = sum(l.qty * f.lot_mult(l, now) for l in sell)
        res = sell_lots_prefix(b, sell, now)
        w["results"].append(("milk", now, res["qty"], res["proceeds"], values, res["market_price"], res["discount"]))
    adults = [c for c in f.cows if c.is_adult(now)]
    k = max(1, round(len(adults) * frac)) if adults else 0
    cows = adults[:k]
    if cows:
        values = sum(beef_quality(f.fp, c, now) * f.fp.tier_mult[c.tier] * beef_weight(f.fp, c, now) for c in cows)
        res = ship_and_sell(b, cows, now)
        w["results"].append(("beef", now, res["qty"], res["proceeds"], values, res["market_price"], res["discount"]))


def whale_dump(b: Bot, ctx, now: float) -> None:
    _whale_sell(b, now, 1.0)
    b.whale["done"] = True


def whale_batch(b: Bot, ctx, now: float) -> None:
    w = b.whale
    w["batch_i"] = w.get("batch_i", 0) + 1
    left = w["batches"] - w["batch_i"] + 1
    _whale_sell(b, now, 1.0 / left)
    if left <= 1:
        w["done"] = True


def panic_sell(b: Bot, ctx, now: float) -> None:
    """情境：大利多事件後大家同時賣。"""
    f = b.farm
    sell_all_milk(b, now)
    adults = [c for c in f.cows if c.is_adult(now) and c.adult_age_h(now) >= PANIC_SHIP_AGE_H]
    if adults:
        ship_and_sell(b, adults, now)


STRATEGY_FUNCS = {"S1": s1, "S2": s2, "S3": s3, "S4": s4, "S5": s5}
EXTRA_FUNCS = {"s4_return": s4_return, "whale_dump": whale_dump, "whale_batch": whale_batch, "panic_sell": panic_sell}


def act(b: Bot, ctx, now: float, kind: str) -> None:
    """一次上線（session）、教學的一分鐘，或排好的回訪。ctx 要有 upcoming(now) 與 schedule(t, pid, kind, dur)。"""
    if kind == "tutorial":
        tutorial_step(b, ctx, now)
    elif kind == "session":
        if now < b.tut_end:
            tutorial_step(b, ctx, now)
        else:
            STRATEGY_FUNCS[b.strategy](b, ctx, now)
    else:
        EXTRA_FUNCS[kind](b, ctx, now)
    # 新手里程碑（不論在教學內或之後達成都記）
    f = b.farm
    if b.first_sale is None and f.n_sales > 0:
        b.first_sale = now - b.joined_at
    if b.first_expand is None and f.expansions > 0:
        b.first_expand = now - b.joined_at
    if b.first_breed is None and f.first_breed_used:
        b.first_breed = now - b.joined_at
