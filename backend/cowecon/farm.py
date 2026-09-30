"""牧場規則：牛的一生、產奶與奶桶、倉庫新鮮度、牛肉價值、配種機率、各項成本。

時間用 Unix 秒；牛的年齡在函式內換成小時。所有產量都是封閉式積分，只在玩家上線或動到牛群時結算，
所以離線多久都算得準，也不需要每分鐘跑每位玩家。

M1 伺服器加的部分（模擬沒有用到，模擬結果不變）：
- 出貨改成兩步：ship_to_storage() 把牛變成倉庫裡的牛肉批次，sell_beef() 再賣。牛肉批次沿用牛的肉質曲線
  （放進去 beef_hold_h 內不變，之後 beef_decline_h 降到 beef_quality_min），不佔牛奶倉庫容量。
  這是原型規則（ceo 2026-09-30 核准），試玩後再定。
- sell_milk()／quote_milk()：照「最舊的先賣」賣指定數量，可以只賣一批的一部分。
- bucket_preview()：不改狀態，算現在奶桶有多少（給畫面用）。
- Cow、Lot、BeefLot、Farm 都有 to_dict()／from_dict()（純 JSON）。

基因（整數位元）：4 個基因座，每座 2 個等位基因，佔 2 個位元。
- 第 0 座「用途」：0 = 乳用 M、1 = 肉用 F。MM 乳用、MF 兼用、FF 肉用。
- 第 1–3 座「稀有」A/B/C：1 = 隱性稀有。某座兩個都是 1（純合）就顯現該特徵；
  顯現幾個 = 稀有度（0 一般、1 優良、2 稀有、3 傳說）。
"""

from __future__ import annotations

import math
import random
from itertools import product
from typing import Dict, List, Optional, Sequence, Tuple

from .market import ImpactState, Market, SaleResult
from .params import HOUR, EconomyParams, FarmParams

N_LOCI = 4
RARE_LOCI = (1, 2, 3)


# ---------------------------------------------------------------------------
# 基因
# ---------------------------------------------------------------------------
def cow_type(g: int) -> int:
    """0 乳用 MM、1 兼用 MF、2 肉用 FF。"""
    pair = g & 3
    return (pair & 1) + (pair >> 1)


def rare_mask(g: int) -> int:
    """顯現的稀有特徵（位元 0/1/2 對應 A/B/C）。"""
    m = 0
    for i, locus in enumerate(RARE_LOCI):
        if (g >> (2 * locus)) & 3 == 3:
            m |= 1 << i
    return m


def carrier_mask(g: int) -> int:
    """帶有（至少一個）隱性稀有基因的特徵。畫面上不直接顯示，玩家要從血統推。"""
    m = 0
    for i, locus in enumerate(RARE_LOCI):
        if (g >> (2 * locus)) & 3:
            m |= 1 << i
    return m


def tier_of(g: int) -> int:
    return bin(rare_mask(g)).count("1")


def make_genotype(type_idx: int, rare_alleles: Sequence[Tuple[int, int]]) -> int:
    """type_idx: 0/1/2；rare_alleles: 3 組 (a, b)。"""
    m = {0: (0, 0), 1: (1, 0), 2: (1, 1)}[type_idx]
    g = m[0] | (m[1] << 1)
    for locus, (a, b) in zip(RARE_LOCI, rare_alleles):
        g |= (a | (b << 1)) << (2 * locus)
    return g


def shop_genotype(fp: FarmParams, type_idx: int, rng: random.Random) -> int:
    q = fp.shop_recessive_freq
    alleles = [(1 if rng.random() < q else 0, 1 if rng.random() < q else 0) for _ in RARE_LOCI]
    return make_genotype(type_idx, alleles)


def breed_genotype(sire: int, dam: int, rng: random.Random) -> int:
    """每個基因座從父母各隨機取一個等位基因。"""
    child = 0
    for locus in range(N_LOCI):
        a = (sire >> (2 * locus + rng.getrandbits(1))) & 1
        b = (dam >> (2 * locus + rng.getrandbits(1))) & 1
        child |= (a | (b << 1)) << (2 * locus)
    return child


def offspring_distribution(sire: int, dam: int) -> Dict[Tuple[int, int], float]:
    """精確機率：{(用途, 稀有特徵位元): 機率}。給畫面公開配種機率用。"""
    per_locus = []
    for locus in range(N_LOCI):
        sa = [(sire >> (2 * locus)) & 1, (sire >> (2 * locus + 1)) & 1]
        da = [(dam >> (2 * locus)) & 1, (dam >> (2 * locus + 1)) & 1]
        per_locus.append([(a | (b << 1)) for a in sa for b in da])  # 4 種等機率
    out: Dict[Tuple[int, int], float] = {}
    for combo in product(*per_locus):
        g = 0
        for locus, pair in enumerate(combo):
            g |= pair << (2 * locus)
        key = (cow_type(g), rare_mask(g))
        out[key] = out.get(key, 0.0) + 1.0 / 256.0
    return out


def tier_distribution(sire: int, dam: int) -> List[float]:
    """小牛稀有度 0–3 的機率。"""
    probs = [0.0, 0.0, 0.0, 0.0]
    for (_t, mask), p in offspring_distribution(sire, dam).items():
        probs[bin(mask).count("1")] += p
    return probs


# ---------------------------------------------------------------------------
# 牛
# ---------------------------------------------------------------------------
class Cow:
    __slots__ = ("cid", "g", "bull", "born_at", "adult_at", "ready_at", "tier", "ctype")

    def __init__(self, cid: int, g: int, bull: bool, born_at: float, fp: FarmParams, adult_at: Optional[float] = None):
        self.cid = cid
        self.g = g
        self.bull = bull
        self.born_at = born_at
        self.tier = tier_of(g)
        self.ctype = cow_type(g)
        self.adult_at = adult_at if adult_at is not None else born_at + fp.tier_growth_h[self.tier] * HOUR
        self.ready_at = self.adult_at  # 可以配種的時間

    def is_adult(self, now: float) -> bool:
        return now >= self.adult_at

    def adult_age_h(self, now: float) -> float:
        return (now - self.adult_at) / HOUR

    def to_dict(self) -> dict:
        return {"id": self.cid, "g": self.g, "bull": self.bull, "born_at": self.born_at, "adult_at": self.adult_at, "ready_at": self.ready_at}

    @classmethod
    def from_dict(cls, fp: FarmParams, d: dict) -> "Cow":
        c = cls(d["id"], d["g"], d["bull"], d["born_at"], fp, adult_at=d["adult_at"])
        c.ready_at = d["ready_at"]
        return c


# ---- 產奶 ----
def milk_frac(fp: FarmParams, age_h: float) -> float:
    """成年後 age_h 小時的產奶比例（壯年 = 1）。"""
    if age_h < 0:
        return 0.0
    if age_h <= fp.milk_prime_h:
        return 1.0
    if age_h >= fp.milk_decline_end_h:
        return fp.milk_old_frac
    return 1.0 - (1.0 - fp.milk_old_frac) * (age_h - fp.milk_prime_h) / (fp.milk_decline_end_h - fp.milk_prime_h)


def _milk_frac_cum(fp: FarmParams, a: float) -> float:
    """∫_0^a milk_frac（小時）。"""
    if a <= 0:
        return 0.0
    p, e, f = fp.milk_prime_h, fp.milk_decline_end_h, fp.milk_old_frac
    if a <= p:
        return a
    if a <= e:
        d = a - p
        return p + d - (1.0 - f) * d * d / (2.0 * (e - p))
    return p + (e - p) * (1.0 + f) / 2.0 + f * (a - e)


def cow_milk_rate(fp: FarmParams, cow: Cow, now: float) -> float:
    """現在每小時產奶（瓶），不含新手加倍。"""
    if cow.bull or now < cow.adult_at:
        return 0.0
    return fp.milk_per_h[cow.ctype] * milk_frac(fp, cow.adult_age_h(now))


def cow_milk_between(fp: FarmParams, cow: Cow, t0: float, t1: float) -> float:
    """t0 到 t1 之間產了幾瓶。"""
    if cow.bull or t1 <= cow.adult_at or t1 <= t0:
        return 0.0
    a0 = max(0.0, (t0 - cow.adult_at) / HOUR)
    a1 = (t1 - cow.adult_at) / HOUR
    return fp.milk_per_h[cow.ctype] * (_milk_frac_cum(fp, a1) - _milk_frac_cum(fp, a0))


# ---- 牛肉 ----
def beef_weight(fp: FarmParams, cow: Cow, now: float) -> float:
    """出貨可得的牛肉（公斤）。小牛不能出貨，回傳 0。"""
    if now < cow.adult_at:
        return 0.0
    a = cow.adult_age_h(now)
    t = cow.ctype
    w0, w1, pa = fp.adult_weight_kg[t], fp.peak_weight_kg[t], fp.peak_age_h[t]
    w = w0 + (w1 - w0) * min(a / pa, 1.0)
    return w * (fp.bull_weight_mult if cow.bull else 1.0)


def beef_quality(fp: FarmParams, cow: Cow, now: float) -> float:
    a = cow.adult_age_h(now)
    start = fp.peak_age_h[cow.ctype] + fp.beef_hold_h
    if a <= start:
        return 1.0
    return max(fp.beef_quality_min, 1.0 - (1.0 - fp.beef_quality_min) * (a - start) / fp.beef_decline_h)


def beef_storage_factor(fp: FarmParams, age_h: float) -> float:
    """倉庫裡的牛肉放了 age_h 小時後剩幾成價值（原型規則：沿用牛的肉質曲線）。"""
    if age_h <= fp.beef_hold_h:
        return 1.0
    return max(fp.beef_quality_min, 1.0 - (1.0 - fp.beef_quality_min) * (age_h - fp.beef_hold_h) / fp.beef_decline_h)


def beef_value_at_base(fp: FarmParams, cow: Cow, now: float, base_price: float) -> float:
    """以基本價、不含滑價估的出貨價值（幣）。"""
    return beef_weight(fp, cow, now) * beef_quality(fp, cow, now) * fp.tier_mult[cow.tier] * base_price


# ---- 新鮮度 ----
def fresh_times_h(fp: FarmParams, level: int) -> Tuple[float, float]:
    """(維持 100% 的時數, 降到 50% 的時數)。"""
    return fp.fresh_full_h + fp.fresh_full_step_h * level, fp.fresh_half_h + fp.fresh_half_step_h * level


def freshness(fp: FarmParams, age_h: float, level: int = 0) -> float:
    """倉庫裡放了 age_h 小時的牛奶，賣價剩幾成。0 = 壞掉。"""
    full, half = fresh_times_h(fp, level)
    if age_h <= full:
        return 1.0
    f = 1.0 - 0.5 * (age_h - full) / (half - full)
    return f if f > 0.0 else 0.0


# ---- 成本 ----
def pen_cost(fp: FarmParams, expansions_done: int) -> float:
    """第 expansions_done+1 次擴建的價格（第一次擴建另用 OnboardingParams.first_expand_cost）。"""
    return round(fp.pen_cost_base * fp.pen_cost_growth ** expansions_done)


def bucket_cap(fp: FarmParams, level: int) -> float:
    return fp.bucket_start_cap * fp.bucket_cap_growth ** level


def bucket_cost(fp: FarmParams, level: int) -> float:
    return round(fp.bucket_cost_base * fp.bucket_cost_growth ** level)


def wh_cap(fp: FarmParams, level: int) -> float:
    return fp.wh_start_cap * fp.wh_cap_growth ** level


def wh_cost(fp: FarmParams, level: int) -> float:
    return round(fp.wh_cost_base * fp.wh_cost_growth ** level)


def fresh_cost(fp: FarmParams, level: int) -> Optional[float]:
    return fp.fresh_costs[level] if level < len(fp.fresh_costs) else None


def breed_fee(fp: FarmParams, sire: Cow, dam: Cow) -> float:
    return round(fp.breed_fee_base * (1 + max(sire.tier, dam.tier)))


# ---------------------------------------------------------------------------
# 倉庫裡的一批牛奶
# ---------------------------------------------------------------------------
class Lot:
    __slots__ = ("tier", "qty", "t")

    def __init__(self, tier: int, qty: float, t: float):
        self.tier = tier
        self.qty = qty
        self.t = t

    def to_dict(self) -> list:
        return [self.tier, self.qty, self.t]

    @classmethod
    def from_dict(cls, d: Sequence) -> "Lot":
        return cls(d[0], d[1], d[2])


class BeefLot:
    """倉庫裡的一批牛肉（出貨一頭牛 = 一批）。mult = 出貨當下的肉質 × 稀有度倍率；qty 單位是公斤。"""

    __slots__ = ("tier", "qty", "mult", "t", "cow_id")

    def __init__(self, tier: int, qty: float, mult: float, t: float, cow_id: int = 0):
        self.tier = tier
        self.qty = qty
        self.mult = mult
        self.t = t
        self.cow_id = cow_id

    def to_dict(self) -> list:
        return [self.tier, self.qty, self.mult, self.t, self.cow_id]

    @classmethod
    def from_dict(cls, d: Sequence) -> "BeefLot":
        return cls(d[0], d[1], d[2], d[3], d[4] if len(d) > 4 else 0)


def _fifo_take(lots: Sequence, qty: float) -> List[Tuple[object, float]]:
    """最舊的先拿，湊到 qty：回傳 [(批次, 拿多少)]，最後一批可能只拿一部分。不改任何狀態。

    差在 1e-9（相對）以內視為整批，這樣「把某幾批加起來的量」一定剛好拿到那幾批整批。
    """
    out: List[Tuple[object, float]] = []
    rem = qty
    tol = 1e-9 * max(1.0, qty)
    for l in lots:
        if rem <= tol:
            break
        if rem >= l.qty - tol:
            out.append((l, l.qty))
            rem -= l.qty
        else:
            out.append((l, rem))
            rem = 0.0
            break
    return out


# ---------------------------------------------------------------------------
# 牧場
# ---------------------------------------------------------------------------
class Farm:
    """一位玩家的牧場。伺服器每個 API 動作對應一個方法；方法失敗回傳 False/None，不丟例外。"""

    __slots__ = (
        "p", "fp", "coins", "cows", "slots", "expansions", "bucket_level", "wh_level", "fresh_level",
        "bucket", "bucket_t", "lots", "created_at", "impact", "_next_cid", "first_breed_used", "log", "n_sales",
        "beef_lots",
    )

    def __init__(self, params: EconomyParams, now: float, rng: random.Random):
        self.p = params
        fp = self.fp = params.farm
        ob = params.onboarding
        self.coins = float(ob.start_coins)
        self.cows: List[Cow] = []
        self.slots = fp.pen_start_slots
        self.expansions = 0
        self.bucket_level = 0
        self.wh_level = 0
        self.fresh_level = 0
        self.created_at = now
        self.lots: List[Lot] = []
        self.beef_lots: List[BeefLot] = []  # M1：出貨後放在倉庫、還沒賣的牛肉
        self.impact = {"milk": ImpactState(), "beef": ImpactState()}
        self._next_cid = 1
        self.first_breed_used = False
        self.n_sales = 0  # 賣過幾次（牛奶或牛肉）；教學與任務用
        self.log: Optional[list] = None  # 模擬時設成 list 就會記錄每筆收支

        cow = Cow(self._new_id(), shop_genotype(fp, ob.starter_cow_type, rng), False, now - fp.tier_growth_h[0] * HOUR, fp, adult_at=now)
        calf = Cow(self._new_id(), shop_genotype(fp, ob.starter_calf_type, rng), True, now, fp, adult_at=now + ob.starter_calf_remaining_s)
        self.cows = [cow, calf]
        self.bucket = [0.0, 0.0, 0.0, 0.0]
        self.bucket[cow.tier] = float(ob.start_bucket)
        self.bucket_t = now

    def _new_id(self) -> int:
        i = self._next_cid
        self._next_cid += 1
        return i

    def _record(self, now: float, kind: str, amount: float, qty: float = 0.0) -> None:
        if self.log is not None:
            self.log.append((now, kind, amount, qty))

    # ---- 查詢 ----
    def free_slots(self) -> int:
        return self.slots - len(self.cows)

    def bucket_capacity(self) -> float:
        return bucket_cap(self.fp, self.bucket_level)

    def wh_capacity(self) -> float:
        return wh_cap(self.fp, self.wh_level)

    def wh_used(self) -> float:
        return sum(l.qty for l in self.lots)

    def milk_rate(self, now: float) -> float:
        """整座牧場現在每小時產奶（瓶），含新手加倍。"""
        r = sum(cow_milk_rate(self.fp, c, now) for c in self.cows)
        if now < self.created_at + self.p.onboarding.newbie_boost_s:
            r *= self.p.onboarding.newbie_boost_mult
        return r

    def bucket_total(self) -> float:
        return sum(self.bucket)

    # ---- 奶桶：離線也會累積，滿了就停 ----
    def advance(self, now: float) -> None:
        if now <= self.bucket_t:
            return
        self.bucket = self.bucket_preview(now)
        self.bucket_t = now

    def bucket_preview(self, now: float) -> List[float]:
        """到 now 為止奶桶裡各稀有度的牛奶（瓶），不改狀態。advance() 用同一個算法。"""
        t0 = self.bucket_t
        if now <= t0:
            return list(self.bucket)
        fp = self.fp
        ob = self.p.onboarding
        produced = [0.0, 0.0, 0.0, 0.0]
        boost_end = self.created_at + ob.newbie_boost_s
        bt0, bt1 = max(t0, self.created_at), min(now, boost_end)
        extra = ob.newbie_boost_mult - 1.0
        for c in self.cows:
            if c.bull or now <= c.adult_at:
                continue
            q = cow_milk_between(fp, c, t0, now)
            if bt1 > bt0 and extra > 0:
                q += extra * cow_milk_between(fp, c, bt0, bt1)
            produced[c.tier] += q
        total = sum(produced)
        room = self.bucket_capacity() - self.bucket_total()
        out = list(self.bucket)
        if total > 0 and room > 0:
            scale = min(1.0, room / total)
            for i in range(4):
                out[i] += produced[i] * scale
        return out

    def collect(self, now: float) -> float:
        """奶桶 → 倉庫。倉庫放不下的留在奶桶。回傳收了幾瓶。"""
        self.advance(now)
        total = self.bucket_total()
        if total <= 0:
            return 0.0
        room = self.wh_capacity() - self.wh_used()
        take = min(total, max(0.0, room))
        if take <= 0:
            return 0.0
        scale = take / total
        for i in range(4):
            q = self.bucket[i] * scale
            if q > 0:
                self.lots.append(Lot(i, q, now))
                self.bucket[i] -= q
        self._record(now, "collect", 0.0, take)
        return take

    def drop_spoiled(self, now: float) -> float:
        lost = 0.0
        keep = []
        for l in self.lots:
            if freshness(self.fp, (now - l.t) / HOUR, self.fresh_level) <= 0.0:
                lost += l.qty
            else:
                keep.append(l)
        self.lots = keep
        if lost:
            self._record(now, "spoiled", 0.0, lost)
        return lost

    def lot_mult(self, lot: Lot, now: float) -> float:
        return self.fp.tier_mult[lot.tier] * freshness(self.fp, (now - lot.t) / HOUR, self.fresh_level)

    # ---- 賣奶 ----
    def sell_lots(self, market: Market, lots: Sequence[Lot], now: float) -> SaleResult:
        parts = [(l.qty, self.lot_mult(l, now)) for l in lots]
        res = market.execute_sale(self.impact["milk"], parts, now)
        ids = {id(l) for l in lots}
        self.lots = [l for l in self.lots if id(l) not in ids]
        coins = round(res.proceeds)
        self.coins += coins
        if res.units > 0:
            self.n_sales += 1
        self._record(now, "milk", coins, res.units)
        return res

    def sell_all_milk(self, market: Market, now: float, max_rounds: int = 50) -> float:
        """收奶並全部賣掉；倉庫放不下時重複「收 → 賣」。回傳收入。"""
        earned = 0.0
        for _ in range(max_rounds):
            self.collect(now)
            if not self.lots:
                break
            res = self.sell_lots(market, list(self.lots), now)
            earned += round(res.proceeds)
            if self.bucket_total() <= 1e-9:
                break
        return earned

    def _milk_parts(self, qty: float, now: float) -> List[Tuple[Lot, float]]:
        return _fifo_take(self.lots, qty)

    def quote_milk(self, market: Market, qty: float, now: float) -> SaleResult:
        """試算從倉庫賣 qty 瓶（最舊的先賣），不改狀態。已經壞掉的牛奶不算（賣之前會先丟掉）。"""
        fresh = [l for l in self.lots if freshness(self.fp, (now - l.t) / HOUR, self.fresh_level) > 0.0]
        parts = [(q, self.lot_mult(l, now)) for l, q in _fifo_take(fresh, qty)]
        return market.quote(self.impact["milk"], parts, now)

    def sell_milk(self, market: Market, qty: float, now: float) -> SaleResult:
        """從倉庫賣 qty 瓶（最舊的先賣，最後一批可以只賣一部分）。整批時和 sell_lots 完全相同。"""
        taken = self._milk_parts(qty, now)
        parts = [(q, self.lot_mult(l, now)) for l, q in taken]
        res = market.execute_sale(self.impact["milk"], parts, now)
        whole = set()
        for l, q in taken:
            if q >= l.qty:
                whole.add(id(l))
            else:
                l.qty -= q
        self.lots = [l for l in self.lots if id(l) not in whole]
        coins = round(res.proceeds)
        self.coins += coins
        if res.units > 0:
            self.n_sales += 1
        self._record(now, "milk", coins, res.units)
        return res

    # ---- 出貨 ----
    def ship(self, cow: Cow, market: Market, now: float) -> Optional[SaleResult]:
        """出貨一頭成年牛換牛肉收入。"""
        if cow not in self.cows or not cow.is_adult(now):
            return None
        self.advance(now)  # 先把這頭牛到現在為止的產奶結算進奶桶
        w = beef_weight(self.fp, cow, now)
        mult = beef_quality(self.fp, cow, now) * self.fp.tier_mult[cow.tier]
        res = market.execute_sale(self.impact["beef"], [(w, mult)], now)
        self.cows.remove(cow)
        coins = round(res.proceeds)
        self.coins += coins
        self._record(now, "beef", coins, w)
        return res

    def ship_many(self, cows: Sequence[Cow], market: Market, now: float) -> Optional[SaleResult]:
        """一次出貨多頭（同一筆單，滑價一起算）。"""
        cows = [c for c in cows if c in self.cows and c.is_adult(now)]
        if not cows:
            return None
        self.advance(now)
        parts = [(beef_weight(self.fp, c, now), beef_quality(self.fp, c, now) * self.fp.tier_mult[c.tier]) for c in cows]
        res = market.execute_sale(self.impact["beef"], parts, now)
        for c in cows:
            self.cows.remove(c)
        coins = round(res.proceeds)
        self.coins += coins
        self._record(now, "beef", coins, res.units)
        return res

    def ship_to_storage(self, cow: Cow, now: float) -> Optional[BeefLot]:
        """M1 的出貨：成年牛 → 倉庫裡的一批牛肉（還沒賣）。之後用 sell_beef 賣。"""
        if cow not in self.cows or not cow.is_adult(now):
            return None
        self.advance(now)  # 先把這頭牛到現在為止的產奶結算進奶桶
        w = beef_weight(self.fp, cow, now)
        mult = beef_quality(self.fp, cow, now) * self.fp.tier_mult[cow.tier]
        lot = BeefLot(cow.tier, w, mult, now, cow.cid)
        self.cows.remove(cow)
        self.beef_lots.append(lot)
        self._record(now, "ship", 0.0, w)
        return lot

    def beef_lot_mult(self, lot: BeefLot, now: float) -> float:
        return lot.mult * beef_storage_factor(self.fp, (now - lot.t) / HOUR)

    def beef_stock(self) -> float:
        return sum(l.qty for l in self.beef_lots)

    def quote_beef(self, market: Market, qty: float, now: float) -> SaleResult:
        parts = [(q, self.beef_lot_mult(l, now)) for l, q in _fifo_take(self.beef_lots, qty)]
        return market.quote(self.impact["beef"], parts, now)

    def sell_beef(self, market: Market, qty: float, now: float) -> SaleResult:
        """從倉庫賣 qty 公斤牛肉（最舊的先賣）。出貨當下立刻全部賣掉時，和 ship_many 完全相同。"""
        taken = _fifo_take(self.beef_lots, qty)
        parts = [(q, self.beef_lot_mult(l, now)) for l, q in taken]
        res = market.execute_sale(self.impact["beef"], parts, now)
        whole = set()
        for l, q in taken:
            if q >= l.qty:
                whole.add(id(l))
            else:
                l.qty -= q
        self.beef_lots = [l for l in self.beef_lots if id(l) not in whole]
        coins = round(res.proceeds)
        self.coins += coins
        if res.units > 0:
            self.n_sales += 1
        self._record(now, "beef", coins, res.units)
        return res

    # ---- 買小牛、配種 ----
    def buy_calf(self, type_idx: int, bull: bool, now: float, rng: random.Random) -> Optional[Cow]:
        price = self.fp.calf_price
        if self.free_slots() <= 0 or self.coins < price:
            return None
        self.advance(now)
        self.coins -= price
        cow = Cow(self._new_id(), shop_genotype(self.fp, type_idx, rng), bull, now, self.fp)
        self.cows.append(cow)
        self._record(now, "calf", -price)
        return cow

    def can_breed(self, sire: Cow, dam: Cow, now: float) -> bool:
        return (
            sire.bull and not dam.bull and sire in self.cows and dam in self.cows
            and now >= sire.ready_at and now >= dam.ready_at and self.free_slots() > 0
        )

    def breed_cost(self, sire: Cow, dam: Cow) -> float:
        if self.p.onboarding.first_breed_free and not self.first_breed_used:
            return 0.0
        return breed_fee(self.fp, sire, dam)

    def breed(self, sire: Cow, dam: Cow, now: float, rng: random.Random) -> Optional[Cow]:
        if not self.can_breed(sire, dam, now):
            return None
        fee = self.breed_cost(sire, dam)
        if self.coins < fee:
            return None
        self.advance(now)
        self.coins -= fee
        self.first_breed_used = True
        g = breed_genotype(sire.g, dam.g, rng)
        calf = Cow(self._new_id(), g, rng.random() < 0.5, now, self.fp)
        self.cows.append(calf)
        sire.ready_at = now + self.fp.bull_breed_cooldown_h * HOUR
        dam.ready_at = now + self.fp.cow_breed_cooldown_h * HOUR
        self._record(now, "breed", -fee)
        return calf

    # ---- 擴建與升級 ----
    def next_pen_cost(self) -> Optional[float]:
        if self.slots >= self.fp.pen_max_slots:
            return None
        if self.expansions == 0:
            return self.p.onboarding.first_expand_cost
        return pen_cost(self.fp, self.expansions)

    def can_expand_at(self, now: float) -> bool:
        """第一次擴建要等教學開放。"""
        return self.expansions > 0 or now >= self.created_at + self.p.onboarding.first_expand_unlock_s

    def expand_pen(self, now: float) -> bool:
        cost = self.next_pen_cost()
        if cost is None or self.coins < cost or not self.can_expand_at(now):
            return False
        self.coins -= cost
        self.slots += 1
        self.expansions += 1
        self._record(now, "expand", -cost)
        return True

    def next_bucket_cost(self) -> Optional[float]:
        if self.bucket_level >= self.fp.bucket_max_level:
            return None
        return bucket_cost(self.fp, self.bucket_level)

    def upgrade_bucket(self, now: float) -> bool:
        cost = self.next_bucket_cost()
        if cost is None or self.coins < cost:
            return False
        self.advance(now)  # 升級前先用舊容量結算
        self.coins -= cost
        self.bucket_level += 1
        self._record(now, "bucket", -cost)
        return True

    def next_wh_cost(self) -> Optional[float]:
        if self.wh_level >= self.fp.wh_max_level:
            return None
        return wh_cost(self.fp, self.wh_level)

    def upgrade_wh(self, now: float) -> bool:
        cost = self.next_wh_cost()
        if cost is None or self.coins < cost:
            return False
        self.coins -= cost
        self.wh_level += 1
        self._record(now, "warehouse", -cost)
        return True

    def next_fresh_cost(self) -> Optional[float]:
        return fresh_cost(self.fp, self.fresh_level)

    def upgrade_fresh(self, now: float) -> bool:
        cost = self.next_fresh_cost()
        if cost is None or self.coins < cost:
            return False
        self.coins -= cost
        self.fresh_level += 1
        self._record(now, "fresh", -cost)
        return True

    # ---- 估值 ----
    def net_worth(self, now: float, milk_price: float, beef_price: float) -> float:
        """現金 + 倉庫牛奶（市價×新鮮度）+ 奶桶 + 成年牛出貨價值 + 小牛買價。估值，不含滑價。"""
        v = self.coins
        for l in self.lots:
            v += l.qty * milk_price * self.lot_mult(l, now)
        v += sum(q * milk_price * self.fp.tier_mult[i] for i, q in enumerate(self.bucket))
        for bl in self.beef_lots:
            v += bl.qty * beef_price * self.beef_lot_mult(bl, now)
        for c in self.cows:
            if c.is_adult(now):
                v += beef_weight(self.fp, c, now) * beef_quality(self.fp, c, now) * self.fp.tier_mult[c.tier] * beef_price
            else:
                v += self.fp.calf_price
        return v

    # ---- 存檔與回復 ----
    def to_dict(self) -> dict:
        """完整狀態（純 JSON）。log（模擬用的帳本）不存。"""
        return {
            "coins": self.coins,
            "cows": [c.to_dict() for c in self.cows],
            "slots": self.slots,
            "expansions": self.expansions,
            "bucket_level": self.bucket_level,
            "wh_level": self.wh_level,
            "fresh_level": self.fresh_level,
            "bucket": list(self.bucket),
            "bucket_t": self.bucket_t,
            "lots": [l.to_dict() for l in self.lots],
            "beef_lots": [l.to_dict() for l in self.beef_lots],
            "created_at": self.created_at,
            "impact": {k: v.to_dict() for k, v in self.impact.items()},
            "next_cid": self._next_cid,
            "first_breed_used": self.first_breed_used,
            "n_sales": self.n_sales,
        }

    @classmethod
    def from_dict(cls, params: EconomyParams, d: dict) -> "Farm":
        f = cls.__new__(cls)
        f.p = params
        fp = f.fp = params.farm
        f.coins = d["coins"]
        f.cows = [Cow.from_dict(fp, c) for c in d["cows"]]
        f.slots = d["slots"]
        f.expansions = d["expansions"]
        f.bucket_level = d["bucket_level"]
        f.wh_level = d["wh_level"]
        f.fresh_level = d["fresh_level"]
        f.bucket = list(d["bucket"])
        f.bucket_t = d["bucket_t"]
        f.lots = [Lot.from_dict(x) for x in d["lots"]]
        f.beef_lots = [BeefLot.from_dict(x) for x in d.get("beef_lots", [])]
        f.created_at = d["created_at"]
        f.impact = {k: ImpactState.from_dict(v) for k, v in d["impact"].items()}
        f._next_cid = d["next_cid"]
        f.first_breed_used = d["first_breed_used"]
        f.n_sales = d["n_sales"]
        f.log = None
        return f

    def cow_by_id(self, cid: int) -> Optional[Cow]:
        for c in self.cows:
            if c.cid == cid:
                return c
        return None
