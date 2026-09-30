"""玩家 bot。

- 教學（所有人）：開局 30 分鐘每分鐘動作一次：收奶賣奶、第一次擴建、第一次配種。
- S1 即賣：乳牛；每次上線把牛奶全部賣掉；產奶掉到八成以下就出貨換新牛。
- S2 牛肉派：肉用牛；牛奶照賣；到最佳體重就出貨。
- S3 配種收集：留最好的公牛，優先配種、留稀有牛；一般牛照 S1 規則出貨。
- S4 抓時機：乳牛；牛奶存倉庫，價格 ≥ 24 小時均價 × 門檻，或新鮮度開始掉才賣；
  該出貨的牛等牛肉價好再出貨（有期限）；看到提前公告的利多會回來賣。
- S5 大戶：壓力測試。開局給大牧場，囤牛奶和牛，指定時間一次倒出（dump）、分批賣（batch），
  或一直囤著不賣（hold，當對照組：倒貨前兩條路徑完全相同，差別就是倒貨的影響）。

所有 bot 的花錢順序相同：補滿空格的小牛 → 奶桶夠放 6 小時 → 策略專屬升級 → 擴建（留一頭小牛的錢）。
"""

from __future__ import annotations

import random
from typing import Dict, List, Optional

from cowecon.farm import Cow, Farm, beef_quality, beef_weight, cow_milk_rate, freshness, milk_frac
from cowecon.params import DAY, HOUR, MINUTE, EconomyParams

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


class Bot:
    __slots__ = (
        "pid", "strategy", "farm", "rng", "sched", "ledger", "joined_at", "tut_end",
        "first_sale", "first_expand", "first_breed", "returns", "whale", "worth",
    )

    def __init__(self, pid: int, strategy: str, params: EconomyParams, joined_at: float, rng: random.Random, sched, ledger, n_days: int):
        self.pid = pid
        self.strategy = strategy
        self.rng = rng
        self.sched = sched
        self.joined_at = joined_at
        self.tut_end = joined_at + 30 * MINUTE
        self.farm = Farm(params, joined_at, rng)
        self.ledger = ledger
        self.farm.log = ledger
        self.first_sale: Optional[float] = None
        self.first_expand: Optional[float] = None
        self.first_breed: Optional[float] = None
        self.returns: set = set()  # S4：已經安排回來賣的事件
        self.whale: Optional[dict] = None
        self.worth = [0.0] * n_days


# ---------------------------------------------------------------------------
# 共用動作
# ---------------------------------------------------------------------------
def herd_milk_rate(f: Farm, now: float) -> float:
    return sum(cow_milk_rate(f.fp, c, now) for c in f.cows)


def maintain_bucket(f: Farm, now: float, target_h: float = BUCKET_TARGET_H) -> None:
    need = target_h * herd_milk_rate(f, now)
    while f.bucket_capacity() < need:
        if not f.upgrade_bucket(now):
            break


def fill_slots(b: Bot, now: float, type_idx: int, bull: bool = False, leave_free: int = 0) -> None:
    f = b.farm
    while f.free_slots() > leave_free and f.coins >= f.fp.calf_price:
        if f.buy_calf(type_idx, bull, now, b.rng) is None:
            break


def expand_and_fill(b: Bot, now: float, type_idx: int) -> None:
    f = b.farm
    while True:
        cost = f.next_pen_cost()
        if cost is None or f.coins < cost + f.fp.calf_price or not f.can_expand_at(now):
            break
        f.expand_pen(now)
        f.buy_calf(type_idx, False, now, b.rng)


def ship_due(f: Farm, now: float, due) -> None:
    cows = [c for c in f.cows if c.is_adult(now) and due(c)]
    if cows:
        f.ship_many(cows, _beef(f), now)


# 為了少傳參數，world 在建構時把市場掛到這兩個全域
_MARKETS: Dict[str, object] = {}


def _milk(_f=None):
    return _MARKETS["milk"]


def _beef(_f=None):
    return _MARKETS["beef"]


# ---------------------------------------------------------------------------
# 教學：開局 30 分鐘
# ---------------------------------------------------------------------------
def tutorial_step(b: Bot, world, now: float) -> None:
    f = b.farm
    f.sell_all_milk(_milk(), now)
    if f.free_slots() <= 0:
        f.expand_pen(now)
    if f.free_slots() > 0:
        bulls = [c for c in f.cows if c.bull and c.is_adult(now) and now >= c.ready_at]
        cows = [c for c in f.cows if not c.bull and c.is_adult(now) and now >= c.ready_at]
        if bulls and cows:
            f.breed(bulls[0], cows[0], now, b.rng)


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


def s1(b: Bot, world, now: float) -> None:
    f = b.farm
    f.sell_all_milk(_milk(), now)
    ship_due(f, now, _dairy_due(f, now))
    fill_slots(b, now, 0)
    maintain_bucket(f, now)
    expand_and_fill(b, now, 0)


def s2(b: Bot, world, now: float) -> None:
    f = b.farm
    fp = f.fp
    f.sell_all_milk(_milk(), now)
    ship_due(f, now, lambda c: c.adult_age_h(now) >= fp.peak_age_h[c.ctype])
    fill_slots(b, now, 2)
    maintain_bucket(f, now)
    expand_and_fill(b, now, 2)


def _p_recessive(g: int, locus: int) -> float:
    return (((g >> (2 * locus)) & 1) + ((g >> (2 * locus + 1)) & 1)) / 2.0


def expected_tier(sire: int, dam: int) -> float:
    return sum(_p_recessive(sire, L) * _p_recessive(dam, L) for L in (1, 2, 3))


def _bull_score(c: Cow):
    carriers = sum(_p_recessive(c.g, L) for L in (1, 2, 3))
    return (c.tier, carriers, -c.born_at)


def s3(b: Bot, world, now: float) -> None:
    f = b.farm
    fp = f.fp
    f.sell_all_milk(_milk(), now)
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

    ship_due(f, now, due)
    if best is None or best not in f.cows:
        bulls = [c for c in f.cows if c.bull]
        best = max(bulls, key=_bull_score) if bulls else None
    if best is None:
        if f.free_slots() > 0:
            f.buy_calf(0, True, now, b.rng)
    elif best.is_adult(now):
        # 每次上線用種公牛配一頭（公牛冷卻時間內只能配一次）
        ready = [c for c in f.cows if not c.bull and c.is_adult(now) and now >= c.ready_at]
        if ready and f.free_slots() > 0 and now >= best.ready_at:
            dam = max(ready, key=lambda c: (expected_tier(best.g, c.g), c.tier))
            f.breed(best, dam, now, b.rng)
    fill_slots(b, now, 0, leave_free=1 if best is not None else 0)
    maintain_bucket(f, now)
    expand_and_fill(b, now, 0)


def s4(b: Bot, world, now: float) -> None:
    f = b.farm
    fp = f.fp
    if len(f.cows) < S4_HOLD_MIN_COWS and not f.lots:
        s1(b, world, now)
        return
    mk = _milk()
    bk = _beef()
    f.drop_spoiled(now)
    f.collect(now)
    hot = mk.price >= mk.moving_average() * S4_PRICE_THR
    if hot:
        f.sell_all_milk(mk, now)
    else:
        old = [l for l in f.lots if freshness(fp, (now - l.t) / HOUR, f.fresh_level) < S4_FRESH_SELL]
        if old:
            f.sell_lots(mk, old, now)
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
                f.sell_lots(mk, sell, now)
            f.collect(now)
            if f.bucket_total() > 1e-6:
                f.sell_all_milk(mk, now)
    # 提前公告的牛奶利多：安排在事件開始後 20 分鐘回來
    for ev in world.ex.upcoming(now):
        if "milk" in ev.targets and ev.factor > 1.0 and ev.eid not in b.returns:
            b.returns.add(ev.eid)
            world.schedule(ev.start_at + 20 * MINUTE, b.pid, "s4_return", 5 * MINUTE)
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

    ship_due(f, now, due)
    fill_slots(b, now, 0)
    maintain_bucket(f, now)
    rate = herd_milk_rate(f, now)
    if len(f.cows) >= 5 and f.fresh_level < 1:
        f.upgrade_fresh(now)
    while f.wh_capacity() < S4_WH_TARGET_H * rate:
        if not f.upgrade_wh(now):
            break
    expand_and_fill(b, now, 0)


def s4_return(b: Bot, world, now: float) -> None:
    """S4 看到公告後回來：價格夠好就把倉庫的牛奶全賣掉。"""
    mk = _milk()
    if mk.price >= mk.moving_average() * S4_PRICE_THR:
        b.farm.sell_all_milk(mk, now)


# ---------------------------------------------------------------------------
# S5 大戶
# ---------------------------------------------------------------------------
def setup_whale(b: Bot, now: float, cfg: dict) -> None:
    """開局直接給大牧場：cfg['cows'] 頭乳牛（年齡錯開）、滿級奶桶、倉庫、冷藏。"""
    f = b.farm
    fp = f.fp
    n = cfg["cows"]
    f.slots = n + 2
    f.bucket_level = fp.bucket_max_level
    f.wh_level = fp.wh_max_level
    f.fresh_level = len(fp.fresh_costs)
    f.cows = []
    for i in range(n):
        g = 0  # 一般乳牛
        c = Cow(f._new_id(), g, False, now, fp, adult_at=now - (i % 24) * HOUR)
        f.cows.append(c)
    b.whale = dict(cfg)
    b.whale["results"] = []


def s5(b: Bot, world, now: float) -> None:
    w = b.whale
    f = b.farm
    mode = w["mode"]
    hoarding = mode != "none" and w["hoard_from"] <= now < w["dump_at"]
    if hoarding:
        f.collect(now)  # 只收不賣；牛也不出貨
        if not w.get("scheduled"):
            w["scheduled"] = True
            if mode == "dump":
                world.schedule(w["dump_at"], b.pid, "whale_dump", 5 * MINUTE)
            elif mode == "batch":
                for k in range(w["batches"]):
                    world.schedule(w["dump_at"] + k * w["batch_gap_s"], b.pid, "whale_batch", 5 * MINUTE)
            # mode == "hold"：一直囤、不賣（對照組）
        return
    if mode != "none" and now >= w["dump_at"] and not w.get("done"):
        return  # 倒貨期間只由 whale_dump / whale_batch 動作
    # 平常：照 S1 經營，但牛群維持原規模（不擴建）
    f.sell_all_milk(_milk(), now)
    ship_due(f, now, _dairy_due(f, now))
    fill_slots(b, now, 0)


def _whale_sell(b: Bot, now: float, frac: float) -> None:
    f = b.farm
    w = b.whale
    mk, bk = _milk(), _beef()
    f.collect(now)
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
        res = f.sell_lots(mk, sell, now)
        w["results"].append(("milk", now, res.units, res.proceeds, values, res.price, res.avg_discount))
    adults = [c for c in f.cows if c.is_adult(now)]
    k = max(1, round(len(adults) * frac)) if adults else 0
    cows = adults[:k]
    if cows:
        values = sum(beef_quality(f.fp, c, now) * f.fp.tier_mult[c.tier] * beef_weight(f.fp, c, now) for c in cows)
        res = f.ship_many(cows, bk, now)
        w["results"].append(("beef", now, res.units, res.proceeds, values, res.price, res.avg_discount))


def whale_dump(b: Bot, world, now: float) -> None:
    _whale_sell(b, now, 1.0)
    b.whale["done"] = True


def whale_batch(b: Bot, world, now: float) -> None:
    w = b.whale
    w["batch_i"] = w.get("batch_i", 0) + 1
    left = w["batches"] - w["batch_i"] + 1
    _whale_sell(b, now, 1.0 / left)
    if left <= 1:
        w["done"] = True


# ---------------------------------------------------------------------------
# 恐慌賣（情境：大利多事件後所有人同時賣）
# ---------------------------------------------------------------------------
PANIC_SHIP_AGE_H = 48.0  # 恐慌賣時，成年滿幾小時的牛一起出貨（快到出貨時間的先出）


def panic_sell(b: Bot, world, now: float) -> None:
    f = b.farm
    f.sell_all_milk(_milk(), now)
    adults = [c for c in f.cows if c.is_adult(now) and c.adult_age_h(now) >= PANIC_SHIP_AGE_H]
    if adults:
        f.ship_many(adults, _beef(), now)


STRATEGY_FUNCS = {"S1": s1, "S2": s2, "S3": s3, "S4": s4, "S5": s5}
EXTRA_FUNCS = {
    "s4_return": s4_return,
    "whale_dump": whale_dump,
    "whale_batch": whale_batch,
    "panic_sell": panic_sell,
}


def act(b: Bot, world, now: float, kind: str) -> None:
    if kind == "tutorial":
        tutorial_step(b, world, now)
    elif kind == "session":
        if now < b.tut_end:
            tutorial_step(b, world, now)
        else:
            STRATEGY_FUNCS[b.strategy](b, world, now)
    else:
        EXTRA_FUNCS[kind](b, world, now)
    # 新手里程碑（不論在教學內或之後達成都記）
    f = b.farm
    if b.first_sale is None and f.n_sales > 0:
        b.first_sale = now - b.joined_at
    if b.first_expand is None and f.expansions > 0:
        b.first_expand = now - b.joined_at
    if b.first_breed is None and f.first_breed_used:
        b.first_breed = now - b.joined_at
