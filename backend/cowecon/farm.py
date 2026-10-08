"""牧場規則：牛的一生、產奶與奶桶、耕田與稻米、倉庫新鮮度、出貨評級、配種與借種、商店等級、各項成本。

時間用 Unix 秒；牛的年齡在函式內換成小時。所有產量都是封閉式積分，只在玩家上線或動到牛群時結算，
所以離線多久都算得準，也不需要每分鐘跑每位玩家。

v0.2（企劃書 4.0、決定 D17）
- 用途：MM 乳牛、MF 耕牛、FF 肉牛。只有成年「母」乳牛產奶；出貨肉量 肉牛 > 耕牛 > 乳牛。
- 耕田：成年耕牛（公母都行）派到田裡，稻米持續長在田裡（最多 field_cap_h 小時的量），收成時進倉庫。
  在田裡的牛要先叫回來，才能出貨、配種、上架借種。
- 商店：只挑 A／B／C 等級，用途、公母、稀有特徵都隨機；shop_grade_distribution() 算精確機率。
- 出貨：肉品隨機評 A／B／C 級（beef_grade_probs() 算精確機率），牛肉賣價 × 評級倍率 × 稀有度倍率。
- 配種：每頭牛一輩子一次（公母一樣）；自己的公母免費；借種用 StudMarket（付錢給公牛主人，小牛歸借的人）。

M1 伺服器加的部分：出貨兩步（ship_to_storage → sell_beef）、sell_milk／quote_milk、bucket_preview、
所有物件的 to_dict()／from_dict()（純 JSON）。v0.2 的新欄位都有預設值，讀舊存檔不會出錯，
但舊存檔裡的兼用牛會變成耕牛、不再產奶（規則變了），原型建議重置。

基因（整數位元）：4 個基因座，每座 2 個等位基因，佔 2 個位元。
- 第 0 座「用途」：0 = 乳用 M、1 = 肉用 F。MM 乳牛、MF 耕牛、FF 肉牛。
- 第 1–3 座「稀有」A/B/C：1 = 隱性稀有。某座兩個都是 1（純合）就顯現該特徵；
  顯現幾個 = 稀有度（0 一般、1 優良、2 稀有、3 傳說）。

v0.3 照顧（docs/design/v0.3-care.md、決定 D35；參數在 CareParams）
- 小牛長大（adult_at）那一刻揭曉品種：稀有以上的品種要在小牛時期吃過指定的飼料（required_feeds），少一種就變雜種牛
  （價值等級 HYBRID = 4，倍數 0.6；基因照舊，配種用得到）。Farm.advance 一定先揭曉，所以成年後吃的不算小牛時期。
- 飼料：一份長固定公斤數（feed_kg），加成最多 bonus_max_kg，跟著年紀長出來（beef_weight）。吃飽冷卻、過了最壯不能餵。
- 地板：Farm.use_floor → set_speed（A0 的年紀速度）。
- 大便與生病：每頭牛照自己的時鐘（poop_at）每 poop_every_s 拉一坨，最多 poop_max_per_cow 坨。髒的程度 = 大便 ÷ 牛數，
  每頭牛的風險率 = sick_rate_per_h ×（髒 − sick_dirt_free）。牧場記一條累積風險（hazard），每頭牛出生（或治好）時抽一個
  Exp(1) 門檻，累積風險多出門檻就生病；事件之間風險率是常數，生病的時間精確反推。所以跟上線幾次、tick 多大都無關。
  病牛不產奶、不耕田、不能配種上架借種，出貨牛肉只剩一成；治療 cure_price。打掃小幫手每 helper_clean_s 清全部。
- 照顧規則開關（Farm.care）：大便、生病、變雜種只在開著時發生。舊存檔讀進來是關的。研究模擬和伺服器的電腦玩家開，
  真人的牧場到 v0.3 C1（協定和按鈕都好了）才開。餵食、地板、小幫手不受開關影響。
"""

from __future__ import annotations

import heapq
import math
import random
from itertools import product
from typing import Dict, List, Optional, Sequence, Tuple, Union

from .market import ImpactState, Market, SaleResult
from .params import DAY, HOUR, CareParams, EconomyParams, FarmParams

N_LOCI = 4
RARE_LOCI = (1, 2, 3)
DAIRY, OX, BEEF = 0, 1, 2  # 用途索引


# ---------------------------------------------------------------------------
# 基因
# ---------------------------------------------------------------------------
def cow_type(g: int) -> int:
    """0 乳牛 MM、1 耕牛 MF、2 肉牛 FF。"""
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


def shop_genotype(fp: FarmParams, type_idx: int, rng: random.Random, q: Optional[float] = None) -> int:
    """指定用途、稀有基因隨機（每個等位基因是隱性的機率 q；預設 = C 級）。"""
    if q is None:
        q = fp.shop_grade_recessive_freq[2]
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
    """精確機率：{(用途, 稀有特徵位元): 機率}。公母各半（另計）。給畫面公開配種機率用。"""
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


MIN_LOT = 1e-3  # 倉庫裡一批牛奶最少幾瓶（Farm.collect）
HYBRID = 4  # 價值等級：雜種牛（tier_mult、stud_fee_per_kg 的第 5 格；v0.3）


def required_feeds(cp: CareParams, g: int) -> Tuple[int, ...]:
    """這個基因長大會是的品種，小牛時期要吃到哪幾種飼料（飼料索引）。一般、優良的品種沒有指定，回傳 ()。"""
    t, m = cow_type(g), rare_mask(g)
    for rt, rm, feeds in cp.required_feeds:
        if rt == t and rm == m:
            return feeds
    return ()


# ---------------------------------------------------------------------------
# 商店等級（A／B／C）
# ---------------------------------------------------------------------------
def shop_grade_index(fp: FarmParams, grade: Union[str, int]) -> int:
    if isinstance(grade, int):
        if 0 <= grade < len(fp.shop_grade_names):
            return grade
        raise KeyError(f"未知商店等級：{grade}")
    try:
        return fp.shop_grade_names.index(grade)
    except ValueError:
        raise KeyError(f"未知商店等級：{grade}") from None


def shop_grade_price(fp: FarmParams, grade: Union[str, int]) -> float:
    return fp.shop_grade_price[shop_grade_index(fp, grade)]


def shop_draw(fp: FarmParams, grade: Union[str, int], rng: random.Random) -> Tuple[int, bool]:
    """抽一頭商店小牛：回傳 (基因, 是不是公牛)。抽的順序固定：用途 → 公母 → 3 個稀有基因座各 2 個等位基因。"""
    gi = shop_grade_index(fp, grade)
    u = rng.random()
    acc = 0.0
    type_idx = len(fp.shop_type_probs) - 1
    for i, p in enumerate(fp.shop_type_probs):
        acc += p
        if u < acc:
            type_idx = i
            break
    bull = rng.random() < fp.shop_bull_prob
    g = shop_genotype(fp, type_idx, rng, fp.shop_grade_recessive_freq[gi])
    return g, bull


def shop_grade_distribution(fp: FarmParams, grade: Union[str, int]) -> Dict[Tuple[int, bool, int], float]:
    """精確機率：{(用途, 是否公牛, 稀有特徵位元): 機率}。給商店按鈕公開機率用。"""
    gi = shop_grade_index(fp, grade)
    q = fp.shop_grade_recessive_freq[gi]
    p_show = q * q  # 某個基因座兩個都是隱性
    out: Dict[Tuple[int, bool, int], float] = {}
    for t, pt in enumerate(fp.shop_type_probs):
        for bull, ps in ((True, fp.shop_bull_prob), (False, 1.0 - fp.shop_bull_prob)):
            for mask in range(8):
                pm = 1.0
                for i in range(3):
                    pm *= p_show if (mask >> i) & 1 else (1.0 - p_show)
                p = pt * ps * pm
                if p > 0:
                    out[(t, bull, mask)] = out.get((t, bull, mask), 0.0) + p
    return out


def shop_grade_tier_probs(fp: FarmParams, grade: Union[str, int]) -> List[float]:
    """商店某等級抽到稀有度 0–3 的機率。"""
    probs = [0.0, 0.0, 0.0, 0.0]
    for (_t, _b, mask), p in shop_grade_distribution(fp, grade).items():
        probs[bin(mask).count("1")] += p
    return probs


# ---------------------------------------------------------------------------
# 牛
# ---------------------------------------------------------------------------
class Cow:
    """bred：這輩子配過種了沒（公母一樣，借出去也算）。field：在第幾塊田工作（−1 = 沒有）。
    listed：上架借種的編號（None = 沒有）。origin：來源（start、A/B/C 商店等級、breed、stud），分析用。

    v0.3 照顧：tier 是基因的稀有度（0–3，配種、畫面用）；vt 是價值等級（倍數用），長大揭曉（grown）時決定，
    雜種牛是 HYBRID。fed：小牛時期吃過的飼料（位元）；bonus：飼料加成（公斤）；fed_until：吃飽冷卻到什麼時候。
    poop：還沒清的大便；poop_at：拉大便的時鐘起點（現實時間，地板不會動它）。h0、thr：生病的起點和門檻（thr = None
    不會生病）；sick_since：從什麼時候生病（None = 健康）。"""

    __slots__ = (
        "cid",
        "g",
        "bull",
        "born_at",
        "adult_at",
        "ready_at",
        "tier",
        "ctype",
        "bred",
        "field",
        "listed",
        "origin",
        "speed",
        "late_speed",
        "peak_h",
        "vt",
        "grown",
        "fed",
        "bonus",
        "fed_until",
        "poop",
        "poop_at",
        "h0",
        "thr",
        "sick_since",
    )

    def __init__(
        self,
        cid: int,
        g: int,
        bull: bool,
        born_at: float,
        fp: FarmParams,
        adult_at: Optional[float] = None,
        origin: str = "",
        speed: float = 1.0,
        late_speed: float = 1.0,
    ):
        self.cid = cid
        self.g = g
        self.bull = bull
        self.born_at = born_at
        self.tier = tier_of(g)
        self.ctype = cow_type(g)
        # 年紀走多快（v0.3 的地板，ceo 2026-10-08 改成分兩段）。所有年齡曲線（長大、最壯、產奶耕田的全速期、變老、肉質）
        # 都用「年紀小時」。長到最壯之前（小牛、成年到 peak_h）每個現實的遊戲小時走 speed 年紀小時（長快地板 1.25／1.5），
        # 之後走 late_speed（長慢地板 0.75）。兩個都不存在牛身上的存檔，由牧場（Farm.speed、late_speed）設。
        # adult_at、born_at 是照現在的速度推算的時間；換速度時 Farm.set_speed 重新推算，年紀不會跳。
        self.speed = speed
        self.late_speed = late_speed
        self.peak_h = fp.peak_age_h[self.ctype]
        self.adult_at = adult_at if adult_at is not None else born_at + fp.tier_growth_h[self.tier] * HOUR / speed
        self.ready_at = self.adult_at  # v0.1 的配種冷卻；v0.2 沒有冷卻，固定 = 成年時間（相容保留）
        self.bred = False
        self.field = -1
        self.listed: Optional[int] = None
        self.origin = origin
        self.vt = self.tier
        self.grown = False
        self.fed = 0
        self.bonus = 0.0
        self.fed_until = 0.0
        self.poop = 0
        self.poop_at = born_at
        self.h0 = 0.0
        self.thr: Optional[float] = None
        self.sick_since: Optional[float] = None

    @property
    def hybrid(self) -> bool:
        return self.vt == HYBRID

    def is_adult(self, now: float) -> bool:
        return now >= self.adult_at

    def adult_age_h(self, now: float) -> float:
        """成年後的年紀小時（小牛是負的）：長到最壯（peak_h）之前每個現實的遊戲小時走 speed，之後走 late_speed。"""
        a = (now - self.adult_at) / HOUR * self.speed
        if self.late_speed == self.speed or a <= self.peak_h:
            return a
        return self.peak_h + (a - self.peak_h) / self.speed * self.late_speed

    def is_busy(self) -> bool:
        """在田裡或上架借種中：不能出貨、配種。"""
        return self.field >= 0 or self.listed is not None

    def can_breed_now(self, now: float) -> bool:
        """病牛不能配種（只看已經結算的；還沒結算的生病用 Farm.is_sick）。"""
        return self.is_adult(now) and not self.bred and not self.is_busy() and self.sick_since is None

    def to_dict(self) -> dict:
        return {
            "id": self.cid,
            "g": self.g,
            "bull": self.bull,
            "born_at": self.born_at,
            "adult_at": self.adult_at,
            "ready_at": self.ready_at,
            "bred": self.bred,
            "field": self.field,
            "listed": self.listed,
            "origin": self.origin,
            "vt": self.vt,
            "grown": self.grown,
            "fed": self.fed,
            "bonus": self.bonus,
            "fed_until": self.fed_until,
            "poop": self.poop,
            "poop_at": self.poop_at,
            "h0": self.h0,
            "thr": self.thr,
            "sick_since": self.sick_since,
        }

    @classmethod
    def from_dict(cls, fp: FarmParams, d: dict) -> "Cow":
        """v0.3 的欄位缺的時候（舊存檔）給預設值：還沒揭曉、沒吃過、沒有大便、不會生病。"""
        c = cls(d["id"], d["g"], d["bull"], d["born_at"], fp, adult_at=d["adult_at"], origin=d.get("origin", ""))
        c.ready_at = d.get("ready_at", c.adult_at)
        c.bred = d.get("bred", False)
        c.field = d.get("field", -1)
        c.listed = d.get("listed")
        c.vt = d.get("vt", c.tier)
        c.grown = d.get("grown", False)
        c.fed = d.get("fed", 0)
        c.bonus = d.get("bonus", 0.0)
        c.fed_until = d.get("fed_until", 0.0)
        c.poop = d.get("poop", 0)
        c.poop_at = d.get("poop_at", c.born_at)
        c.h0 = d.get("h0", 0.0)
        c.thr = d.get("thr")
        c.sick_since = d.get("sick_since")
        return c


# ---- 年齡曲線（產奶、耕田共用） ----
def milk_frac(fp: FarmParams, age_h: float) -> float:
    """成年後 age_h 小時的產奶（耕田）比例（壯年 = 1）。"""
    if age_h < 0:
        return 0.0
    if age_h <= fp.milk_prime_h:
        return 1.0
    if age_h >= fp.milk_decline_end_h:
        return fp.milk_old_frac
    return 1.0 - (1.0 - fp.milk_old_frac) * (age_h - fp.milk_prime_h) / (fp.milk_decline_end_h - fp.milk_prime_h)


work_frac = milk_frac  # 耕牛的工作力照同一條曲線


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


def is_milker(cow: Cow) -> bool:
    """v0.2：只有母乳牛產奶。"""
    return cow.ctype == DAIRY and not cow.bull


def cow_milk_rate(fp: FarmParams, cow: Cow, now: float) -> float:
    """現在每小時產奶（瓶），不含新手加倍。"""
    if not is_milker(cow) or now < cow.adult_at:
        return 0.0
    return fp.milk_per_h[cow.ctype] * milk_frac(fp, cow.adult_age_h(now))


def _work_hours(fp: FarmParams, cow: Cow, t0: float, t1: float) -> float:
    """t0 到 t1 之間的「壯年產量小時」= ∫ milk_frac(年紀) d(現實小時)（產奶、耕田共用）。

    年紀小時的積分 ÷ 速度：每個現實小時的產量照年紀曲線，年紀走得快只是全速期比較短。長到最壯前後速度不同時，在最壯那一刻
    切兩段（t0–t1 之間牧場的速度不變，Farm 保證）。"""
    s = cow.speed
    a0 = max(0.0, (t0 - cow.adult_at) / HOUR * s) if s == cow.late_speed else max(0.0, cow.adult_age_h(t0))
    a1 = (t1 - cow.adult_at) / HOUR * s if s == cow.late_speed else cow.adult_age_h(t1)
    if s == cow.late_speed:
        return (_milk_frac_cum(fp, a1) - _milk_frac_cum(fp, a0)) / s
    p = cow.peak_h
    early = (_milk_frac_cum(fp, min(a1, p)) - _milk_frac_cum(fp, min(a0, p))) / s
    late = (_milk_frac_cum(fp, max(a1, p)) - _milk_frac_cum(fp, max(a0, p))) / cow.late_speed
    return early + late


def cow_milk_between(fp: FarmParams, cow: Cow, t0: float, t1: float) -> float:
    """t0 到 t1 之間產了幾瓶。"""
    if not is_milker(cow) or t1 <= cow.adult_at or t1 <= t0:
        return 0.0
    return fp.milk_per_h[cow.ctype] * _work_hours(fp, cow, t0, t1)


# ---- 耕田 ----
def cow_rice_rate(fp: FarmParams, cow: Cow, now: float) -> float:
    """這頭牛在田裡時每小時產多少稻米（公斤）：耕牛才有，× 稀有度倍率 × 年齡曲線。"""
    if now < cow.adult_at:
        return 0.0
    return fp.rice_per_h[cow.ctype] * fp.tier_mult[cow.vt] * work_frac(fp, cow.adult_age_h(now))


def cow_rice_between(fp: FarmParams, cow: Cow, t0: float, t1: float) -> float:
    if fp.rice_per_h[cow.ctype] <= 0 or t1 <= cow.adult_at or t1 <= t0:
        return 0.0
    return fp.rice_per_h[cow.ctype] * fp.tier_mult[cow.vt] * _work_hours(fp, cow, t0, t1)


def field_cap_for(fp: FarmParams, cow: Cow) -> float:
    """這頭耕牛下田時，一塊田最多累積多少稻米（公斤）= 壯年產量 × field_cap_h。"""
    return fp.rice_per_h[cow.ctype] * fp.tier_mult[cow.vt] * fp.field_cap_h


def rice_factor(fp: FarmParams, age_h: float) -> float:
    """倉庫裡的稻米放了 age_h 小時後剩幾成價值。"""
    if age_h <= fp.rice_full_h:
        return 1.0
    if age_h >= fp.rice_floor_h:
        return fp.rice_floor
    return 1.0 - (1.0 - fp.rice_floor) * (age_h - fp.rice_full_h) / (fp.rice_floor_h - fp.rice_full_h)


# ---- 牛肉 ----
def beef_weight(fp: FarmParams, cow: Cow, now: float) -> float:
    """出貨可得的牛肉（公斤）。小牛不能出貨，回傳 0。

    v0.3 飼料加成跟著年紀長出來：照年紀的體重 + 加成 ×（成年後的年紀 ÷ 長到最壯的時間，最多 1）。"""
    if now < cow.adult_at:
        return 0.0
    a = cow.adult_age_h(now)
    t = cow.ctype
    w0, w1, pa = fp.adult_weight_kg[t], fp.peak_weight_kg[t], fp.peak_age_h[t]
    f = min(a / pa, 1.0)
    w = w0 + (w1 - w0) * f
    return w * (fp.bull_weight_mult if cow.bull else 1.0) + cow.bonus * f


def bonus_weight(fp: FarmParams, cow: Cow, now: float) -> float:
    """體重裡已經長出來的飼料加成（公斤）。"""
    if now < cow.adult_at or not cow.bonus:
        return 0.0
    return cow.bonus * min(cow.adult_age_h(now) / fp.peak_age_h[cow.ctype], 1.0)


def beef_quality(fp: FarmParams, cow: Cow, now: float) -> float:
    """年齡因素（1 = 剛好；過了最佳體重 beef_hold_h 之後下降）。v0.2 起用在出貨評級的機率，不直接乘在價格上。"""
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


def beef_condition(fp: FarmParams, cow: Cow, now: float) -> float:
    """狀態 0–1：體重接近最佳（體重 ÷ 最佳體重）× 年齡剛好（beef_quality）。"""
    if now < cow.adult_at:
        return 0.0
    peak = fp.peak_weight_kg[cow.ctype] * (fp.bull_weight_mult if cow.bull else 1.0)
    return min(1.0, beef_weight(fp, cow, now) / peak) * beef_quality(fp, cow, now)


def beef_grade_probs(fp: FarmParams, cow: Cow, now: float) -> Tuple[float, float, float]:
    """出貨評到 A／B／C 的精確機率（給出貨確認畫面公開）。"""
    w = fp.beef_grade_tier_weight
    tier = 0 if cow.vt == HYBRID else cow.vt  # 雜種牛的稀有度分數算一般
    s = (1.0 - w) * beef_condition(fp, cow, now) + w * tier / 3.0
    pa = min(1.0, max(0.0, fp.beef_grade_a0 + fp.beef_grade_a1 * s))
    pc = min(1.0 - pa, max(0.0, fp.beef_grade_c0 * (1.0 - s)))
    return pa, 1.0 - pa - pc, pc


def beef_expected_mult(fp: FarmParams, cow: Cow, now: float) -> float:
    """評級倍率的期望值 × 稀有度倍率（估值、預覽用）。"""
    probs = beef_grade_probs(fp, cow, now)
    return sum(p * m for p, m in zip(probs, fp.beef_grade_mult)) * fp.tier_mult[cow.vt]


def draw_beef_grade(fp: FarmParams, cow: Cow, now: float, rng: random.Random) -> int:
    """抽出貨評級：0 = A、1 = B、2 = C。用掉 rng 一個亂數。"""
    pa, pb, _pc = beef_grade_probs(fp, cow, now)
    u = rng.random()
    if u < pa:
        return 0
    if u < pa + pb:
        return 1
    return 2


def beef_value_at_base(fp: FarmParams, cow: Cow, now: float, base_price: float) -> float:
    """以基本價、評級期望值、不含滑價估的出貨價值（幣）。"""
    return beef_weight(fp, cow, now) * beef_expected_mult(fp, cow, now) * base_price


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
    return round(fp.pen_cost_base * fp.pen_cost_growth**expansions_done)


def field_cost(fp: FarmParams, n_fields: int) -> Optional[float]:
    """現在有 n_fields 塊田時，再開一塊的價格；到上限回傳 None。"""
    if n_fields >= fp.field_max:
        return None
    return round(fp.field_cost_base * fp.field_cost_growth ** max(0, n_fields - fp.field_start))


def bucket_cap(fp: FarmParams, level: int) -> float:
    return fp.bucket_start_cap * fp.bucket_cap_growth**level


def bucket_cost(fp: FarmParams, level: int) -> float:
    return round(fp.bucket_cost_base * fp.bucket_cost_growth**level)


def wh_cap(fp: FarmParams, level: int) -> float:
    return fp.wh_start_cap * fp.wh_cap_growth**level


def wh_cost(fp: FarmParams, level: int) -> float:
    return round(fp.wh_cost_base * fp.wh_cost_growth**level)


def fresh_cost(fp: FarmParams, level: int) -> Optional[float]:
    return fp.fresh_costs[level] if level < len(fp.fresh_costs) else None


def breed_fee(fp: FarmParams, sire: Cow, dam: Cow) -> float:
    """v0.2：自己的公母配種免費，永遠回傳 0（相容保留；借種的價錢看 StudMarket）。"""
    return 0.0


# ---------------------------------------------------------------------------
# 倉庫裡的批次
# ---------------------------------------------------------------------------
class Lot:
    """一批牛奶。tier = 價值等級（0–3；雜種牛的奶是 HYBRID）。"""

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
    """倉庫裡的一批牛肉（出貨一頭牛 = 一批）。tier = 價值等級（雜種牛是 HYBRID）。mult = 評級倍率 × 稀有度倍率
    （病牛再 × sick_beef_mult；v0.1 是肉質 × 稀有度）；
    grade：0 A、1 B、2 C（−1 = 舊存檔沒有評級）；qty 單位是公斤。
    genes：出貨那頭牛的基因（伺服器拿來顯示品種；None = 2026-10-02 之前出貨的，存檔裡沒有）。"""

    __slots__ = ("tier", "qty", "mult", "t", "cow_id", "grade", "genes")

    def __init__(
        self,
        tier: int,
        qty: float,
        mult: float,
        t: float,
        cow_id: int = 0,
        grade: int = -1,
        genes: Optional[int] = None,
    ):
        self.tier = tier
        self.qty = qty
        self.mult = mult
        self.t = t
        self.cow_id = cow_id
        self.grade = grade
        self.genes = genes

    def to_dict(self) -> list:
        return [self.tier, self.qty, self.mult, self.t, self.cow_id, self.grade, self.genes]

    @classmethod
    def from_dict(cls, d: Sequence) -> "BeefLot":
        return cls(
            d[0],
            d[1],
            d[2],
            d[3],
            d[4] if len(d) > 4 else 0,
            d[5] if len(d) > 5 else -1,
            d[6] if len(d) > 6 else None,  # 舊存檔是 6 個元素
        )


class RiceLot:
    """倉庫裡的一批稻米（收成一次 = 一批），qty 公斤。"""

    __slots__ = ("qty", "t")

    def __init__(self, qty: float, t: float):
        self.qty = qty
        self.t = t

    def to_dict(self) -> list:
        return [self.qty, self.t]

    @classmethod
    def from_dict(cls, d: Sequence) -> "RiceLot":
        return cls(d[0], d[1])


class Field:
    """一塊田：ox = 在田裡工作的牛（Cow.cid，−1 = 空）；rice = 田裡已經長好、還沒收的稻米（公斤）；t = 上次結算時間。"""

    __slots__ = ("ox", "rice", "t")

    def __init__(self, t: float, ox: int = -1, rice: float = 0.0):
        self.ox = ox
        self.rice = rice
        self.t = t

    def to_dict(self) -> list:
        return [self.ox, self.rice, self.t]

    @classmethod
    def from_dict(cls, d: Sequence) -> "Field":
        return cls(d[2], d[0], d[1])


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
        "p",
        "fp",
        "coins",
        "cows",
        "slots",
        "expansions",
        "bucket_level",
        "wh_level",
        "fresh_level",
        "bucket",
        "bucket_t",
        "lots",
        "created_at",
        "impact",
        "_next_cid",
        "first_breed_used",
        "log",
        "n_sales",
        "beef_lots",
        "fields",
        "rice_lots",
        "track",
        "speed",
        "late_speed",
        "care",
        "care_t",
        "hazard",
        "feeds",
        "floor",
        "floors",
        "helper_from",
        "helper_until",
        "stats",
    )

    def __init__(self, params: EconomyParams, now: float, rng: random.Random, care: bool = False):
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
        self.rice_lots: List[RiceLot] = []  # v0.2：收成後放在倉庫、還沒賣的稻米
        self.fields: List[Field] = [Field(now) for _ in range(fp.field_start)]
        self.impact = {cid: ImpactState() for cid in params.commodity_ids}
        self._next_cid = 1
        self.first_breed_used = False
        self.n_sales = 0  # 賣過幾次（牛奶、牛肉、稻米）；教學與任務用
        self.log: Optional[list] = None  # 模擬時設成 list 就會記錄每筆收支
        self.track: Optional[dict] = None  # 模擬時設成 dict 就會記錄每頭牛的產出（不存檔）
        self.stats: Optional[dict] = None  # 模擬時設成 dict 就會累計牛的時間、生病的時間（秒；不存檔）
        # 牛的年紀走多快（v0.3 的地板設；1.0 = 泥土地）：speed 長到最壯之前、late_speed 之後。全部的牛一起，換的時候用 set_speed
        self.speed = 1.0
        self.late_speed = 1.0

        cow = Cow(
            self._new_id(),
            shop_genotype(fp, ob.starter_cow_type, rng),
            False,
            now - fp.tier_growth_h[0] * HOUR,
            fp,
            adult_at=now,
            origin="start",
        )
        calf = Cow(
            self._new_id(),
            shop_genotype(fp, ob.starter_calf_type, rng),
            True,
            now,
            fp,
            adult_at=now + ob.starter_calf_remaining_s,
            origin="start",
        )
        cow.poop_at = now  # 大便的時鐘從開牧場算
        self.cows = [cow, calf]
        self.bucket = [0.0] * len(fp.tier_mult)  # 價值等級 0–3 和雜種牛（HYBRID）
        self.bucket[cow.tier] = float(ob.start_bucket)
        self.bucket_t = now
        # v0.3 照顧
        self.care = care  # 照顧規則開關：大便、生病、變雜種（說明見檔頭）
        self.care_t = now  # 大便、生病結算到什麼時候
        self.hazard = 0.0  # 牧場的累積風險（每頭牛一樣）
        self.feeds = [0] * len(params.care.feed_kg)  # 倉庫裡每種飼料幾份
        self.floor = 0  # 正在用的地板（CareParams.floor_ids 的索引）
        self.floors = 1  # 擁有的地板（位元）；泥土地開局就有
        self.helper_from = 0.0  # 這次雇用小幫手從什麼時候開始（每 helper_clean_s 清一次的起點）
        self.helper_until = 0.0
        if care:
            for c in self.cows:  # 亂數用在開局兩頭牛的基因之後
                self._arm(c, rng)

    def _new_id(self) -> int:
        i = self._next_cid
        self._next_cid += 1
        return i

    def _record(self, now: float, kind: str, amount: float, qty: float = 0.0) -> None:
        if self.log is not None:
            self.log.append((now, kind, amount, qty))

    def _track(self, cow: Cow, key: int, v: float) -> None:
        """模擬用：記錄每頭牛的產出。key：0 牛奶瓶、1 稻米公斤、2 出貨收入（幣）。"""
        if self.track is None:
            return
        r = self.track.get(cow.cid)
        if r is None:
            r = self.track[cow.cid] = [0.0, 0.0, 0.0, cow.origin, cow.ctype, cow.bull, cow.vt, cow.born_at]
        r[key] += v

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

    def rice_rate(self, now: float) -> float:
        """田裡所有耕牛現在每小時產稻米（公斤）。"""
        by_id = {c.cid: c for c in self.cows}
        return sum(cow_rice_rate(self.fp, by_id[f.ox], now) for f in self.fields if f.ox >= 0 and f.ox in by_id)

    def bucket_total(self) -> float:
        return sum(self.bucket)

    def cow_by_id(self, cid: int) -> Optional[Cow]:
        for c in self.cows:
            if c.cid == cid:
                return c
        return None

    # ---- 結算：長大揭曉、大便與生病、奶桶與田地（離線也會累積，滿了就停） ----
    def advance(self, now: float) -> None:
        self._reveal(now)
        if now > self.care_t:
            self._care_advance(now)
        if now > self.bucket_t:
            if self.track is not None:
                self._advance_bucket_tracked(now)
            else:
                self.bucket, _ = self._bucket_calc(now, per_cow=False)
            self.bucket_t = now
        self._advance_fields(now)

    def set_speed(self, speed: float, now: float, late_speed: Optional[float] = None) -> None:
        """換年紀速度（v0.3 換地板，use_floor）：speed = 長到最壯之前、late_speed = 之後（None = 跟 speed 一樣）。
        先結算到 now（之前那段照舊的速度），再把每頭牛的 adult_at、born_at 照新的速度重新推算，年紀小時在 now 連續、
        之後照新的速度走。上架借種的公牛要另外叫 StudMarket.follow_owner。大便的時鐘（poop_at）、吃飽冷卻是現實時間，不動。"""
        if late_speed is None:
            late_speed = speed
        if speed == self.speed and late_speed == self.late_speed:
            return
        self.advance(now)
        r = self.speed / speed
        for c in self.cows:
            calf_h = (c.adult_at - c.born_at) * c.speed  # 小牛期的年紀（秒 × 速度），換速度後不變
            a = c.adult_age_h(now)
            if a <= c.peak_h:
                c.adult_at = now + (c.adult_at - now) * r
            else:  # 過了最壯：最壯那一刻照新的 late_speed 推回去，adult_at 再照新的 speed 推回去
                peak_at = now - (a - c.peak_h) / late_speed * HOUR
                c.adult_at = peak_at - c.peak_h / speed * HOUR
            c.ready_at = c.adult_at
            c.born_at = c.adult_at - calf_h / speed
            c.speed = speed
            c.late_speed = late_speed
        self.speed = speed
        self.late_speed = late_speed

    def bucket_preview(self, now: float) -> List[float]:
        """到 now 為止奶桶裡各價值等級的牛奶（瓶），不改狀態。advance() 用同一個算法。"""
        out, _ = self._bucket_calc(now, per_cow=False, pending=True)
        return out

    def _bucket_calc(self, now: float, per_cow: bool, pending: bool = False):
        """pending：還沒結算的揭曉和生病也算進去（預覽用；advance 已經先結算了，不用）。"""
        t0 = self.bucket_t
        if now <= t0:
            return list(self.bucket), []
        fp = self.fp
        ob = self.p.onboarding
        sick = self._pending_sick(now) if pending else None
        produced = [0.0] * len(self.bucket)
        cow_q = []
        boost_end = self.created_at + ob.newbie_boost_s
        bt0, bt1 = max(t0, self.created_at), min(now, boost_end)
        extra = ob.newbie_boost_mult - 1.0
        for c in self.cows:
            if not is_milker(c) or now <= c.adult_at:
                continue
            t1 = self._healthy_until(c, now, sick)  # 生病就不產奶
            q = cow_milk_between(fp, c, t0, t1)
            b1 = min(bt1, t1)
            if b1 > bt0 and extra > 0:
                q += extra * cow_milk_between(fp, c, bt0, b1)
            produced[c.vt if c.grown else self._reveal_vt(c)] += q
            if per_cow:
                cow_q.append((c, q))
        total = sum(produced)
        room = self.bucket_capacity() - self.bucket_total()
        out = list(self.bucket)
        scale = 0.0
        if total > 0 and room > 0:
            scale = min(1.0, room / total)
            for i in range(len(out)):
                out[i] += produced[i] * scale
        return out, [(c, q * scale) for c, q in cow_q]

    def _advance_bucket_tracked(self, now: float) -> None:
        out, cow_q = self._bucket_calc(now, per_cow=True)
        self.bucket = out
        for c, q in cow_q:
            self._track(c, 0, q)

    def _advance_fields(self, now: float) -> None:
        if not self.fields:
            return
        fp = self.fp
        by_id = None
        for f in self.fields:
            if now <= f.t:
                continue
            if f.ox >= 0:
                if by_id is None:
                    by_id = {c.cid: c for c in self.cows}
                ox = by_id.get(f.ox)
                if ox is not None:
                    cap = field_cap_for(fp, ox)
                    if f.rice < cap:
                        q = min(cap - f.rice, cow_rice_between(fp, ox, f.t, self._healthy_until(ox, now)))
                        if q > 0:
                            f.rice += q
                            self._track(ox, 1, q)
            f.t = now

    def field_preview(self, now: float) -> List[float]:
        """到 now 為止每塊田長好的稻米（公斤），不改狀態。"""
        by_id = {c.cid: c for c in self.cows}
        sick = self._pending_sick(now)
        out = []
        for f in self.fields:
            r = f.rice
            if now > f.t and f.ox >= 0 and f.ox in by_id:
                ox = by_id[f.ox]
                cap = field_cap_for(self.fp, ox)
                if r < cap:
                    r += min(cap - r, cow_rice_between(self.fp, ox, f.t, self._healthy_until(ox, now, sick)))
            out.append(r)
        return out

    # ---- 長大揭曉（v0.3 第 1 節）----
    def _reveal_vt(self, c: Cow) -> int:
        """長大那一刻的價值等級（不改狀態）：照顧規則開著、稀有以上、小牛時期沒吃齊指定的飼料 → 雜種牛。
        開局送的牛不會變雜種。"""
        if self.care and c.origin != "start":
            need = required_feeds(self.p.care, c.g)
            if any(not (c.fed >> k) & 1 for k in need):
                return HYBRID
        return c.tier

    def _reveal(self, now: float) -> None:
        for c in self.cows:
            if not c.grown and c.adult_at <= now:
                c.grown = True
                c.vt = self._reveal_vt(c)
                if c.tier >= 2:
                    self._record(c.adult_at, "rare_grown", 0.0, 1.0)
                    if c.vt == HYBRID:
                        self._record(c.adult_at, "hybrid", 0.0, 1.0)

    # ---- 大便與生病（v0.3 第 5 節）----
    def _arm(self, c: Cow, rng: random.Random) -> None:
        """出生（或治好）時抽生病的門檻：累積風險再多 Exp(1) 就生病。"""
        c.h0 = self.hazard
        c.thr = -math.log(1.0 - rng.random())

    def _care_sim(self, now: float) -> Tuple[List[int], float, Dict[int, float]]:
        """從 care_t 到 now 的大便與生病，不改狀態：回傳 (每頭牛的大便, 牧場的累積風險, {牛的編號: 生病的時間})。

        髒的程度只在事件時改變：某頭牛拉大便（poop_at + k × poop_every_s）、小幫手清（helper_from + k × helper_clean_s）、
        新手保護結束。事件之間每頭牛的風險率是常數，累積風險是分段的直線，生病的時間在那一段裡精確反推。
        剛好在 now 的事件算進這次（下次從 now 之後的事件開始）。"""
        cows = self.cows
        poop = [c.poop for c in cows]
        n = len(cows)
        H = self.hazard
        sick: Dict[int, float] = {}
        t = self.care_t
        if not self.care or n == 0 or now <= t:
            return poop, H, sick
        cp = self.p.care
        P = cp.poop_every_s
        cap = cp.poop_max_per_cow
        heap = []  # (下一坨的時間, 第幾頭, 第幾坨)：還沒到上限的牛
        for i, c in enumerate(cows):
            if poop[i] < cap:
                k = max(1, math.floor((t - c.poop_at) / P) + 1)
                heap.append((c.poop_at + k * P, i, k))
        heapq.heapify(heap)
        total = sum(poop)
        hs = cp.helper_clean_s
        hk = max(1, math.floor((t - self.helper_from) / hs) + 1) if self.helper_until > t else 0
        safe_end = self.created_at + cp.newbie_safe_s
        rate_s = cp.sick_rate_per_h / HOUR
        # 還沒生病、會生病的牛，照「累積風險到多少會生病」排好
        pend = sorted((c.h0 + c.thr, i) for i, c in enumerate(cows) if c.thr is not None and c.sick_since is None)
        pi = 0
        while t < now:
            t1 = now
            if heap and heap[0][0] < t1:
                t1 = heap[0][0]
            if hk:
                tm = self.helper_from + hk * hs
                if tm > self.helper_until:
                    hk = 0
                elif tm < t1:
                    t1 = tm
            if t < safe_end < t1:
                t1 = safe_end
            t1 = max(t1, t)
            # [t, t1) 這一段的風險
            if t >= safe_end:
                r = rate_s * (total / n - cp.sick_dirt_free)
                if r > 0.0:
                    H1 = H + r * (t1 - t)
                    while pi < len(pend) and pend[pi][0] <= H1:
                        lim, i = pend[pi]
                        sick[cows[i].cid] = t + max(0.0, lim - H) / r
                        pi += 1
                    H = H1
            t = t1
            # t 這一刻的事件：先拉大便，再讓小幫手清
            while heap and heap[0][0] <= t:
                _, i, k = heapq.heappop(heap)
                poop[i] += 1
                total += 1
                if poop[i] < cap:
                    heapq.heappush(heap, (cows[i].poop_at + (k + 1) * P, i, k + 1))
            if hk and self.helper_from + hk * hs <= t:
                hk += 1
                if total:
                    in_heap = {i for _, i, _ in heap}
                    for i, c in enumerate(cows):
                        if poop[i] >= cap and i not in in_heap:
                            k = max(1, math.floor((t - c.poop_at) / P) + 1)
                            heapq.heappush(heap, (c.poop_at + k * P, i, k))
                        poop[i] = 0
                    total = 0
        return poop, H, sick

    def _care_advance(self, now: float) -> None:
        if self.care:
            poop, self.hazard, sick = self._care_sim(now)
            for c, q in zip(self.cows, poop):
                c.poop = q
                s = sick.get(c.cid)
                if s is not None:
                    c.sick_since = s
                    self._record(s, "sick", 0.0, 1.0)
        if self.stats is not None:
            self.stats["cow_s"] = self.stats.get("cow_s", 0.0) + len(self.cows) * (now - self.care_t)
            self.stats["sick_s"] = self.stats.get("sick_s", 0.0) + self._sick_seconds(self.care_t, now)
        self.care_t = now

    def _sick_seconds(self, t0: float, t1: float, sick: Optional[Dict[int, float]] = None) -> float:
        """t0 到 t1 之間全部的牛病著的時間加起來（秒）。"""
        tot = 0.0
        for c in self.cows:
            s = c.sick_since
            if s is None and sick:
                s = sick.get(c.cid)
            if s is not None and s < t1:
                tot += t1 - max(t0, s)
        return tot

    def care_stats(self, now: float) -> Tuple[float, float]:
        """模擬用：(牛的時間, 病牛的時間)，秒，算到 now（不改狀態）。要先設 stats = {}。"""
        st = self.stats or {}
        cow_s, sick_s = st.get("cow_s", 0.0), st.get("sick_s", 0.0)
        if now > self.care_t:
            cow_s += len(self.cows) * (now - self.care_t)
            sick_s += self._sick_seconds(self.care_t, now, self._pending_sick(now))
        return cow_s, sick_s

    def _pending_sick(self, now: float) -> Optional[Dict[int, float]]:
        """care_t 到 now 之間會生病的牛（不改狀態；預覽用）。"""
        if not self.care or now <= self.care_t:
            return None
        return self._care_sim(now)[2]

    def _healthy_until(self, c: Cow, now: float, sick: Optional[Dict[int, float]] = None) -> float:
        """這頭牛在 now 之前健康到什麼時候（產奶、耕田的積分算到這裡）。"""
        s = c.sick_since
        if s is None and sick:
            s = sick.get(c.cid)
        return now if s is None else min(now, s)

    def is_sick(self, c: Cow, now: float) -> bool:
        """這頭牛在 now 是不是病著（含還沒結算的）。"""
        if c.sick_since is not None:
            return True
        sick = self._pending_sick(now)
        return bool(sick) and c.cid in sick

    def poop_total(self, now: float) -> int:
        """到 now 為止還沒清的大便（坨），不改狀態。"""
        return sum(self._care_sim(now)[0])

    def clean(self, now: float, piles: Optional[Dict[int, int]] = None) -> int:
        """清大便：piles = {牛的編號: 清幾坨}；None = 全部清掉。回傳清了幾坨。"""
        self.advance(now)
        n = 0
        for c in self.cows:
            k = c.poop if piles is None else min(c.poop, max(0, int(piles.get(c.cid, 0))))
            c.poop -= k
            n += k
        if n:
            self._record(now, "clean", 0.0, n)
        return n

    def cure(self, cow: Cow, now: float, rng: random.Random) -> bool:
        """治療一頭病牛（cure_price），馬上好；重新抽生病的門檻。"""
        cp = self.p.care
        if cow not in self.cows or self.coins < cp.cure_price:
            return False
        self.advance(now)
        if cow.sick_since is None:
            return False
        self.coins -= cp.cure_price
        cow.sick_since = None
        self._arm(cow, rng)
        self._record(now, "cure", -cp.cure_price, 1.0)
        return True

    def hire_helper(self, days: int, now: float) -> bool:
        """雇打掃小幫手 days 天（接在還沒到期的後面），預付最多 helper_max_days 天。雇用那一刻先清一次。"""
        cp = self.p.care
        if days < 1:
            return False
        until = max(now, self.helper_until) + days * DAY
        cost = cp.helper_price_per_day * days
        if until - now > cp.helper_max_days * DAY + 1e-6 or self.coins < cost:
            return False
        self.advance(now)
        if self.helper_until <= now:
            self.helper_from = now
            for c in self.cows:
                c.poop = 0
        self.coins -= cost
        self.helper_until = until
        self._record(now, "helper", -cost, float(days))
        return True

    def set_care(self, on: bool, now: float, rng: random.Random) -> None:
        """打開（或關掉）照顧規則。打開時還沒有門檻的牛照現在的累積風險抽門檻。"""
        if on == self.care:
            return
        self.advance(now)
        self.care = on
        if on:
            for c in self.cows:
                if c.thr is None and c.sick_since is None:
                    self._arm(c, rng)

    # ---- 飼料（v0.3 第 2 節）----
    def buy_feed(self, k: int, n: int, now: float, price: Optional[float] = None) -> bool:
        """買 n 份第 k 種飼料（price = 每份的價格；None = 參數的固定價。飼料市場在 PR B）。每種最多 feed_cap 份。"""
        cp = self.p.care
        if not (0 <= k < len(cp.feed_kg)) or n < 1 or self.feeds[k] + n > cp.feed_cap:
            return False
        cost = (cp.feed_price[k] if price is None else price) * n
        if self.coins < cost:
            return False
        self.coins -= cost
        self.feeds[k] += n
        self._record(now, "feed_buy", -cost, float(n))
        return True

    def feed_block(self, cow: Cow, k: int, now: float) -> Optional[str]:
        """不能餵的原因（None = 可以）：no_feed 倉庫沒有、full 吃飽冷卻中、listed 上架借種中（借種費的加成停在上架那一刻）、
        past_peak 過了最壯（加成只算長到最壯之前）、bonus_max 加成滿了。小牛時期吃的算指定飼料，也算加成。"""
        cp = self.p.care
        if cow not in self.cows or not (0 <= k < len(cp.feed_kg)):
            return "bad"
        if self.feeds[k] <= 0:
            return "no_feed"
        if now < cow.fed_until:
            return "full"
        if cow.listed is not None:
            return "listed"
        if cow.is_adult(now):
            if cow.adult_age_h(now) >= self.fp.peak_age_h[cow.ctype]:
                return "past_peak"
            if cow.bonus >= cp.bonus_max_kg:
                return "bonus_max"
        return None

    def feed(self, cow: Cow, k: int, now: float) -> bool:
        if self.feed_block(cow, k, now) is not None:
            return False
        self.advance(now)  # 先揭曉：成年那一刻（含）之後吃的不算小牛時期
        cp = self.p.care
        self.feeds[k] -= 1
        if cow.is_adult(now):
            cooldown = cp.feed_cooldown_s
        else:
            cow.fed |= 1 << k
            cooldown = cp.calf_feed_cooldown_s
        cow.bonus = min(cp.bonus_max_kg, cow.bonus + cp.feed_kg[k])
        cow.fed_until = now + cooldown
        self._record(now, "feed", 0.0, cp.feed_kg[k])
        return True

    # ---- 地板（v0.3 第 4 節）----
    def buy_floor(self, i: int, now: float) -> bool:
        cp = self.p.care
        if not (0 <= i < len(cp.floor_speed)) or (self.floors >> i) & 1 or self.coins < cp.floor_price[i]:
            return False
        self.coins -= cp.floor_price[i]
        self.floors |= 1 << i
        self._record(now, "floor", -cp.floor_price[i])
        return True

    def use_floor(self, i: int, now: float) -> bool:
        """換成買過的地板（免費）。上架借種的公牛：呼叫端要再叫 StudMarket.follow_owner。"""
        cp = self.p.care
        if not (0 <= i < len(cp.floor_speed)) or not (self.floors >> i) & 1:
            return False
        self.set_speed(cp.floor_speed[i], now, cp.floor_late_speed[i])
        self.floor = i
        return True

    # ---- 牛奶 ----
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
        took = 0.0
        for i in range(len(self.bucket)):
            q = self.bucket[i] * scale
            # 零頭（例如浮點數算出來的 1e-13 瓶、剛生病那一刻的產量）留在奶桶，攢夠了下次一起收。倉庫裡每一批都夠大，
            # 照數量賣（伺服器，_fifo_take 的容差）和照批賣（研究模擬的 sell_lots）才會拿到同樣的批次。
            if q >= MIN_LOT:
                self.lots.append(Lot(i, q, now))
                self.bucket[i] -= q
                took += q
        if took:
            self._record(now, "collect", 0.0, took)
        return took

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

    # ---- 耕田與稻米 ----
    def next_field_cost(self) -> Optional[float]:
        return field_cost(self.fp, len(self.fields))

    def expand_field(self, now: float) -> bool:
        cost = self.next_field_cost()
        if cost is None or self.coins < cost:
            return False
        self.coins -= cost
        self.fields.append(Field(now))
        self._record(now, "field", -cost)
        return True

    def can_work(self, cow: Cow, now: float) -> bool:
        return (
            cow in self.cows
            and cow.ctype == OX
            and cow.is_adult(now)
            and not cow.is_busy()
            and not self.is_sick(cow, now)
        )

    def assign_field(self, cow: Cow, idx: int, now: float) -> bool:
        """把成年耕牛派到第 idx 塊田（田要是空的）。"""
        if not (0 <= idx < len(self.fields)) or self.fields[idx].ox >= 0 or not self.can_work(cow, now):
            return False
        self.advance(now)
        f = self.fields[idx]
        f.ox = cow.cid
        f.t = now
        cow.field = idx
        return True

    def recall(self, cow: Cow, now: float) -> bool:
        """把牛從田裡叫回來。已經長好的稻米留在田裡，收成時一起收。"""
        if cow not in self.cows or cow.field < 0:
            return False
        self.advance(now)
        f = self.fields[cow.field]
        f.ox = -1
        cow.field = -1
        return True

    def free_field(self) -> int:
        for i, f in enumerate(self.fields):
            if f.ox < 0:
                return i
        return -1

    def harvest(self, now: float) -> float:
        """所有田的稻米收進倉庫（一批）。回傳公斤數。"""
        self.advance(now)
        total = sum(f.rice for f in self.fields)
        if total <= 0:
            return 0.0
        for f in self.fields:
            f.rice = 0.0
        self.rice_lots.append(RiceLot(total, now))
        self._record(now, "harvest", 0.0, total)
        return total

    def rice_stock(self) -> float:
        return sum(l.qty for l in self.rice_lots)

    def rice_lot_mult(self, lot: RiceLot, now: float) -> float:
        return rice_factor(self.fp, (now - lot.t) / HOUR)

    def quote_rice(self, market: Market, qty: float, now: float) -> SaleResult:
        parts = [(q, self.rice_lot_mult(l, now)) for l, q in _fifo_take(self.rice_lots, qty)]
        return market.quote(self.impact["rice"], parts, now)

    def sell_rice(self, market: Market, qty: float, now: float) -> SaleResult:
        """從倉庫賣 qty 公斤稻米（最舊的先賣）。"""
        taken = _fifo_take(self.rice_lots, qty)
        parts = [(q, self.rice_lot_mult(l, now)) for l, q in taken]
        res = market.execute_sale(self.impact["rice"], parts, now)
        whole = set()
        for l, q in taken:
            if q >= l.qty:
                whole.add(id(l))
            else:
                l.qty -= q
        self.rice_lots = [l for l in self.rice_lots if id(l) not in whole]
        coins = round(res.proceeds)
        self.coins += coins
        if res.units > 0:
            self.n_sales += 1
        self._record(now, "rice", coins, res.units)
        return res

    def sell_all_rice(self, market: Market, now: float) -> float:
        """收成並把倉庫的稻米全部賣掉。回傳收入。"""
        self.harvest(now)
        q = self.rice_stock()
        if q <= 0:
            return 0.0
        return round(self.sell_rice(market, q, now).proceeds)

    # ---- 出貨 ----
    def can_ship(self, cow: Cow, now: float) -> bool:
        """成年、不在田裡、沒有上架借種。"""
        return cow in self.cows and cow.is_adult(now) and not cow.is_busy()

    def _grade_mult(self, cow: Cow, now: float, rng: Optional[random.Random]) -> Tuple[int, float]:
        """(評級, 賣價倍率 = 評級倍率 × 價值等級倍率 × 病牛倍率)。rng=None 時用期望值（評級記為 −1），伺服器一定要傳 rng。
        呼叫前要先 advance(now)（揭曉、生病都結算好）。"""
        fp = self.fp
        sick = self.p.care.sick_beef_mult if cow.sick_since is not None else 1.0
        if rng is None:
            return -1, beef_expected_mult(fp, cow, now) * sick
        g = draw_beef_grade(fp, cow, now, rng)
        self._record(now, "grade_" + fp.beef_grade_names[g], 0.0, 1.0)
        return g, fp.beef_grade_mult[g] * fp.tier_mult[cow.vt] * sick

    def ship(self, cow: Cow, market: Market, now: float, rng: Optional[random.Random] = None) -> Optional[SaleResult]:
        """出貨一頭成年牛，當場評級並賣掉。"""
        return self.ship_many([cow], market, now, rng)

    def ship_many(
        self, cows: Sequence[Cow], market: Market, now: float, rng: Optional[random.Random] = None
    ) -> Optional[SaleResult]:
        """一次出貨多頭（同一筆單，滑價一起算）。每頭依序評級。"""
        cows = [c for c in cows if self.can_ship(c, now)]
        if not cows:
            return None
        self.advance(now)
        parts = []
        for c in cows:
            _g, mult = self._grade_mult(c, now, rng)
            parts.append((beef_weight(self.fp, c, now), mult))
            if c.bonus:
                self._record(now, "bonus_kg", 0.0, bonus_weight(self.fp, c, now) * mult)
        res = market.execute_sale(self.impact["beef"], parts, now)
        for c in cows:
            self.cows.remove(c)
        coins = round(res.proceeds)
        self.coins += coins
        if self.track is not None:
            value = sum(q * m for q, m in parts)
            for c, (q, m) in zip(cows, parts):
                self._track(c, 2, res.proceeds * (q * m) / value if value > 0 else 0.0)
        self._record(now, "beef", coins, res.units)
        return res

    def ship_to_storage(self, cow: Cow, now: float, rng: Optional[random.Random] = None) -> Optional[BeefLot]:
        """M1 的出貨：成年牛 → 倉庫裡的一批牛肉（當場評級，還沒賣）。之後用 sell_beef 賣。"""
        if not self.can_ship(cow, now):
            return None
        self.advance(now)
        w = beef_weight(self.fp, cow, now)
        g, mult = self._grade_mult(cow, now, rng)
        if cow.bonus:
            self._record(now, "bonus_kg", 0.0, bonus_weight(self.fp, cow, now) * mult)
        lot = BeefLot(cow.vt, w, mult, now, cow.cid, g, cow.g)
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
        """從倉庫賣 qty 公斤牛肉（最舊的先賣）。"""
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

    # ---- 商店、配種 ----
    def buy_shop(self, grade: Union[str, int], now: float, rng: random.Random) -> Optional[Cow]:
        """v0.2 商店：挑 A／B／C 等級，用途、公母、稀有特徵隨機。"""
        fp = self.fp
        gi = shop_grade_index(fp, grade)
        price = fp.shop_grade_price[gi]
        if self.free_slots() <= 0 or self.coins < price:
            return None
        self.advance(now)
        self.coins -= price
        g, bull = shop_draw(fp, gi, rng)
        cow = Cow(
            self._new_id(),
            g,
            bull,
            now,
            fp,
            origin=fp.shop_grade_names[gi],
            speed=self.speed,
            late_speed=self.late_speed,
        )
        if self.care:
            self._arm(cow, rng)
        self.cows.append(cow)
        self._record(now, "calf", -price)
        self._record(now, "shop_" + fp.shop_grade_names[gi], 0.0, 1.0)
        return cow

    def buy_calf(self, type_idx: int, bull: bool, now: float, rng: random.Random) -> Optional[Cow]:
        """v0.1 的商店（指定用途與公母、C 級基因、calf_price）。v0.2 改用 buy_shop，這個只為相容保留。"""
        price = self.fp.calf_price
        if self.free_slots() <= 0 or self.coins < price:
            return None
        self.advance(now)
        self.coins -= price
        cow = Cow(
            self._new_id(),
            shop_genotype(self.fp, type_idx, rng),
            bull,
            now,
            self.fp,
            origin="legacy",
            speed=self.speed,
            late_speed=self.late_speed,
        )
        if self.care:
            self._arm(cow, rng)
        self.cows.append(cow)
        self._record(now, "calf", -price)
        return cow

    def can_breed(self, sire: Cow, dam: Cow, now: float) -> bool:
        """自己的公牛配自己的母牛：兩頭都成年、這輩子沒配過、不在田裡或上架中，牛舍有空格。"""
        return (
            sire.bull
            and not dam.bull
            and sire in self.cows
            and dam in self.cows
            and sire.can_breed_now(now)
            and dam.can_breed_now(now)
            and self.free_slots() > 0
            and not self.is_sick(sire, now)
            and not self.is_sick(dam, now)
        )

    def breed_cost(self, sire: Cow, dam: Cow) -> float:
        """v0.2：自己的公母配種免費。"""
        return 0.0

    def breed(self, sire: Cow, dam: Cow, now: float, rng: random.Random) -> Optional[Cow]:
        if not self.can_breed(sire, dam, now):
            return None
        self.advance(now)
        self.first_breed_used = True
        calf = self._make_calf(sire.g, dam, now, rng, "breed")
        sire.bred = True
        dam.bred = True
        self._record(now, "breed", 0.0, 1.0)
        return calf

    def _make_calf(self, sire_g: int, dam: Cow, now: float, rng: random.Random, origin: str) -> Cow:
        g = breed_genotype(sire_g, dam.g, rng)
        calf = Cow(
            self._new_id(),
            g,
            rng.random() < 0.5,
            now,
            self.fp,
            origin=origin,
            speed=self.speed,
            late_speed=self.late_speed,
        )
        if self.care:
            self._arm(calf, rng)
        self.cows.append(calf)
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
    def net_worth(self, now: float, milk_price: float, beef_price: float, rice_price: Optional[float] = None) -> float:
        """現金 + 倉庫（牛奶、牛肉、稻米、飼料）+ 奶桶 + 田裡的稻米 + 成年牛出貨價值（評級期望值，病牛一成）
        + 小牛（C 級價）。估值，不含滑價。rice_price 沒給就用稻米基本價。"""
        if rice_price is None:
            rice_price = self.p.rice.base_price
        fp = self.fp
        v = self.coins
        for l in self.lots:
            v += l.qty * milk_price * self.lot_mult(l, now)
        v += sum(q * milk_price * fp.tier_mult[i] for i, q in enumerate(self.bucket))
        for bl in self.beef_lots:
            v += bl.qty * beef_price * self.beef_lot_mult(bl, now)
        for rl in self.rice_lots:
            v += rl.qty * rice_price * self.rice_lot_mult(rl, now)
        v += sum(f.rice for f in self.fields) * rice_price
        cp = self.p.care
        for c in self.cows:
            if c.is_adult(now):
                sick = cp.sick_beef_mult if c.sick_since is not None else 1.0
                v += beef_weight(fp, c, now) * beef_expected_mult(fp, c, now) * beef_price * sick
            else:
                v += fp.shop_grade_price[-1]
        v += sum(q * p for q, p in zip(self.feeds, cp.feed_price))
        return v

    # ---- 存檔與回復 ----
    def to_dict(self) -> dict:
        """完整狀態（純 JSON）。log、track（模擬用）不存。"""
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
            "rice_lots": [l.to_dict() for l in self.rice_lots],
            "fields": [f.to_dict() for f in self.fields],
            "created_at": self.created_at,
            "impact": {k: v.to_dict() for k, v in self.impact.items()},
            "next_cid": self._next_cid,
            "first_breed_used": self.first_breed_used,
            "n_sales": self.n_sales,
            **({"speed": self.speed} if self.speed != 1.0 else {}),  # 年紀速度；1.0 不寫，存檔跟以前一樣
            **({"late_speed": self.late_speed} if self.late_speed != 1.0 else {}),
            "care": self.care,
            "care_t": self.care_t,
            "hazard": self.hazard,
            "feeds": list(self.feeds),
            "floor": self.floor,
            "floors": self.floors,
            "helper_from": self.helper_from,
            "helper_until": self.helper_until,
        }

    @classmethod
    def from_dict(cls, params: EconomyParams, d: dict) -> "Farm":
        """從 to_dict() 回復。v0.2 新欄位（田地、稻米、配種次數…）缺的時候給預設值（讀得進 v0.1 存檔）。"""
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
        f.bucket = list(d["bucket"]) + [0.0] * (len(fp.tier_mult) - len(d["bucket"]))  # v0.2 的奶桶只有 4 格
        f.bucket_t = d["bucket_t"]
        f.lots = [Lot.from_dict(x) for x in d["lots"]]
        f.beef_lots = [BeefLot.from_dict(x) for x in d.get("beef_lots", [])]
        f.rice_lots = [RiceLot.from_dict(x) for x in d.get("rice_lots", [])]
        f.fields = (
            [Field.from_dict(x) for x in d["fields"]]
            if "fields" in d
            else [Field(d["bucket_t"]) for _ in range(fp.field_start)]
        )
        f.created_at = d["created_at"]
        f.impact = {k: ImpactState.from_dict(v) for k, v in d["impact"].items()}
        for cid in params.commodity_ids:
            f.impact.setdefault(cid, ImpactState())
        f._next_cid = d["next_cid"]
        f.first_breed_used = d["first_breed_used"]
        f.n_sales = d["n_sales"]
        f.speed = d.get("speed", 1.0)
        f.late_speed = d.get("late_speed", 1.0)
        for c in f.cows:  # 牛的存檔不存速度，跟牧場一樣
            c.speed = f.speed
            c.late_speed = f.late_speed
        # v0.3 照顧：舊存檔是關的
        f.care = d.get("care", False)
        f.care_t = d.get("care_t", d["bucket_t"])
        f.hazard = d.get("hazard", 0.0)
        nf = len(params.care.feed_kg)
        f.feeds = (list(d.get("feeds", [])) + [0] * nf)[:nf]
        f.floor = d.get("floor", 0)
        f.floors = d.get("floors", 1)
        f.helper_from = d.get("helper_from", 0.0)
        f.helper_until = d.get("helper_until", 0.0)
        f.log = None
        f.track = None
        f.stats = None
        return f


# ---------------------------------------------------------------------------
# 借種市場（全服共用；第一個跨玩家的狀態）
# ---------------------------------------------------------------------------
def stud_fee(
    fp: FarmParams,
    ctype: int,
    tier: int,
    adult_at: Optional[float],
    now: float,
    speed: float = 1.0,
    bonus: float = 0.0,
) -> Tuple[float, float, bool]:
    """借種費（D26）：公牛現在的體重 × 每公斤價格（依價值等級；雜種牛是 HYBRID），四捨五入到 stud_fee_round 幣。

    體重跟 beef_weight 同一個算法（公牛，成年後 peak_age_h 小時長到最佳體重，之後不變；飼料加成 bonus 跟著年紀長出來）。
    adult_at = None 是公營種牛站（沒有真的牛）：用那種用途公牛的最佳體重。speed：主人牧場的年紀速度（Cow.speed）。
    回傳 (借種費, 體重公斤, 是否已經長到最壯)。
    """
    w0, w1, pa = fp.adult_weight_kg[ctype], fp.peak_weight_kg[ctype], fp.peak_age_h[ctype]
    frac = 1.0 if adult_at is None else min(max(now - adult_at, 0.0) / HOUR * speed / pa, 1.0)
    kg = (w0 + (w1 - w0) * frac) * fp.bull_weight_mult + bonus * frac
    step = fp.stud_fee_round
    return math.floor(kg * fp.stud_fee_per_kg[tier] / step + 0.5) * step, kg, frac >= 1.0


class StudListing:
    """一筆上架：owner = 主人的識別碼（None = 公營種牛站）；cow_id = 主人牧場裡那頭公牛；
    g、ctype、tier 是上架當下公牛的基因（畫面顯示與配種機率用）；adult_at 是公牛長大的時間，借種費依「現在」的體重算
    （StudMarket.fee）。公營種牛站沒有真的牛，adult_at = None（用最佳體重算）。
    vt：價值等級（雜種公牛是 HYBRID，借種費每公斤 0.6）；bonus：公牛的飼料加成（上架期間不能餵，所以固定）。"""

    __slots__ = ("lid", "owner", "cow_id", "g", "ctype", "tier", "vt", "bonus", "adult_at", "listed_at", "speed")

    def __init__(
        self,
        lid: int,
        owner,
        cow_id: int,
        g: int,
        adult_at: Optional[float],
        listed_at: float,
        speed: float = 1.0,
        hybrid: bool = False,
        bonus: float = 0.0,
    ):
        self.lid = lid
        self.owner = owner
        self.cow_id = cow_id
        self.g = g
        self.ctype = cow_type(g)
        self.tier = tier_of(g)
        self.vt = HYBRID if hybrid else self.tier
        self.bonus = bonus
        self.adult_at = adult_at
        self.listed_at = listed_at
        self.speed = speed  # 主人牧場的年紀速度；主人換速度時 StudMarket.follow_owner 跟著改

    def to_dict(self) -> dict:
        return {
            "id": self.lid,
            "owner": self.owner,
            "cow_id": self.cow_id,
            "g": self.g,
            "adult_at": self.adult_at,
            "listed_at": self.listed_at,
            **({"speed": self.speed} if self.speed != 1.0 else {}),
            **({"hybrid": True} if self.vt == HYBRID else {}),
            **({"bonus": self.bonus} if self.bonus else {}),
        }

    @classmethod
    def from_dict(cls, d: dict) -> "StudListing":
        return cls(
            d["id"],
            d["owner"],
            d["cow_id"],
            d["g"],
            d["adult_at"],
            d["listed_at"],
            d.get("speed", 1.0),
            d.get("hybrid", False),
            d.get("bonus", 0.0),
        )


class StudMarket:
    """借種：主人把自己成年、沒配過、沒在田裡的公牛上架；借種費由系統依公牛現在的體重和稀有度算（D26），
    跟著公牛長大自動漲。別的玩家用自己成年、沒配過的母牛借種：付錢給主人（公營種牛站的錢不給任何人），
    小牛歸借的人，公牛和母牛的「這輩子一次」都用掉。公牛留在主人牧場。

    伺服器要在同一個交易裡處理：借的人牧場、主人牧場（公營種牛站沒有）、上架清單。
    """

    def __init__(self, params: EconomyParams):
        self.p = params
        self.listings: Dict[int, StudListing] = {}
        self._next_id = 1
        self._npc_count = 0
        self._index: Dict[Tuple[int, int], List[int]] = {}  # (用途, 價值等級) → 上架編號（價格會變，用的時候現算）

    def _add(self, lst: StudListing) -> None:
        self.listings[lst.lid] = lst
        self._index.setdefault((lst.ctype, lst.vt), []).append(lst.lid)
        if lst.owner is None:
            self._npc_count += 1

    def _remove(self, lid: int) -> Optional[StudListing]:
        lst = self.listings.pop(lid, None)
        if lst is None:
            return None
        self._index[(lst.ctype, lst.vt)].remove(lid)
        if lst.owner is None:
            self._npc_count -= 1
        return lst

    def fee(self, lst: StudListing, now: float) -> Tuple[float, float, bool]:
        """這一刻的借種費：(價格, 公牛體重, 是否已經長到最壯)。"""
        return stud_fee(self.p.farm, lst.ctype, lst.vt, lst.adult_at, now, lst.speed, lst.bonus)

    def price(self, lst: StudListing, now: float) -> float:
        return self.fee(lst, now)[0]

    def cheapest(self, ctype: int, tier: int, now: float, exclude_owner=None) -> Optional[StudListing]:
        """某用途、某價值等級（雜種是 HYBRID）這一刻最便宜的上架（同價先上架的在前；跳過 exclude_owner 自己的）。"""
        best, best_key = None, None
        for lid in self._index.get((ctype, tier), []):
            lst = self.listings[lid]
            if exclude_owner is not None and lst.owner == exclude_owner:
                continue
            key = (self.price(lst, now), lid)
            if best_key is None or key < best_key:
                best, best_key = lst, key
        return best

    # ---- 上架 ----
    def can_list(self, farm: Farm, cow: Cow, now: float) -> bool:
        return (
            cow in farm.cows
            and cow.bull
            and cow.is_adult(now)
            and not cow.bred
            and not cow.is_busy()
            and not farm.is_sick(cow, now)
        )

    def list_bull(self, farm: Farm, owner, cow: Cow, now: float) -> Optional[StudListing]:
        if owner is None or not self.can_list(farm, cow, now):
            return None
        farm.advance(now)  # 揭曉（雜種公牛的借種費不一樣）
        lst = StudListing(self._next_id, owner, cow.cid, cow.g, cow.adult_at, now, cow.speed, cow.hybrid, cow.bonus)
        self._next_id += 1
        self._add(lst)
        cow.listed = lst.lid
        return lst

    def unlist(self, lid: int, farm: Optional[Farm] = None) -> bool:
        """下架。farm = 主人的牧場（清掉公牛的上架標記）；公營種牛站的上架不用給。"""
        lst = self._remove(lid)
        if lst is None:
            return False
        if farm is not None:
            c = farm.cow_by_id(lst.cow_id)
            if c is not None and c.listed == lid:
                c.listed = None
        return True

    def owner_listings(self, owner) -> List[StudListing]:
        return [l for l in self.listings.values() if l.owner == owner]

    def follow_owner(self, owner, farm: "Farm") -> None:
        """主人換了年紀速度（Farm.set_speed）之後：上架的公牛照新的長大時間和速度算借種費。"""
        for lst in self.owner_listings(owner):
            c = farm.cow_by_id(lst.cow_id)
            if c is not None:
                lst.adult_at, lst.speed = c.adult_at, c.speed

    # ---- 借種 ----
    def can_borrow(
        self, lid: int, borrower: Farm, borrower_id, dam: Cow, now: float, owner_farm: Optional[Farm] = None
    ) -> bool:
        lst = self.listings.get(lid)
        if lst is None or lst.owner == borrower_id and lst.owner is not None:
            return False
        if not (
            dam in borrower.cows
            and not dam.bull
            and dam.can_breed_now(now)
            and borrower.free_slots() > 0
            and borrower.coins >= self.price(lst, now)
            and not borrower.is_sick(dam, now)
        ):
            return False
        if lst.owner is not None:
            if owner_farm is None:
                return False
            bull = owner_farm.cow_by_id(lst.cow_id)
            if bull is None or bull.bred or bull.listed != lid or owner_farm.is_sick(bull, now):
                return False
        return True

    def borrow(
        self,
        lid: int,
        borrower: Farm,
        borrower_id,
        dam: Cow,
        now: float,
        rng: random.Random,
        owner_farm: Optional[Farm] = None,
    ) -> Optional[Cow]:
        """借種配種，用這一刻的借種費；回傳小牛（放在借的人牧場）。失敗回傳 None，狀態不變。"""
        if not self.can_borrow(lid, borrower, borrower_id, dam, now, owner_farm):
            return None
        price = self.price(self.listings[lid], now)
        lst = self._remove(lid)
        borrower.advance(now)
        borrower.coins -= price
        borrower._record(now, "stud_out", -price, 1.0)
        calf = borrower._make_calf(lst.g, dam, now, rng, "stud")
        dam.bred = True
        borrower.first_breed_used = True
        if lst.owner is not None:
            bull = owner_farm.cow_by_id(lst.cow_id)
            bull.bred = True
            bull.listed = None
            owner_farm.coins += price
            owner_farm._record(now, "stud_in", price, 1.0)
        return calf

    # ---- 電腦假玩家 ----
    def npc_refill(self, now: float, rng: random.Random) -> List[StudListing]:
        """公營種牛站：乳牛、耕牛、肉牛每種至少一筆，而且總共至少 npc_stud_listings 筆（協定第 4 節）。
        缺哪種用途補哪種（站上最少的用途先補，一樣少就照乳牛、耕牛、肉牛的順序）。C 級基因：大多是一般公牛。
        2026-10-02 以前是用途輪流補，借走哪一種都補下一個輪到的，站上可能一陣子沒有某種用途；那時存下來的
        偏一邊的站（例如肉牛、肉牛、耕牛），下次呼叫就會補上缺的用途（暫時多一筆）。"""
        fp = self.p.farm
        added = []
        while True:
            have = [0, 0, 0]
            for l in self.listings.values():
                if l.owner is None:
                    have[l.ctype] += 1
            if self._npc_count >= fp.npc_stud_listings and min(have) > 0:
                break
            ctype = min(range(3), key=lambda i: (have[i], i))
            g = shop_genotype(fp, ctype, rng)  # 亂數用量跟用途無關，換了補法也不會打亂之後的亂數
            lst = StudListing(self._next_id, None, 0, g, None, now)  # 沒有真的牛：借種費用最佳體重算
            self._next_id += 1
            self._add(lst)
            added.append(lst)
        return added

    # ---- 存檔 ----
    def to_dict(self) -> dict:
        return {
            "next_id": self._next_id,
            "listings": [l.to_dict() for l in self.listings.values()],
        }

    @classmethod
    def from_dict(cls, params: EconomyParams, d: dict) -> "StudMarket":
        m = cls(params)
        m._next_id = d["next_id"]  # 舊存檔還有 npc_type（以前輪流補的位置），現在用不到
        for x in d["listings"]:
            m._add(StudListing.from_dict(x))
        return m
