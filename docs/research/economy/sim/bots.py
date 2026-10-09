"""玩家 bot（v0.2 規則）。

所有 bot 共用一套經營流程，差別在偏好（PROFILES）：
- D 乳牛派：母乳牛留到產奶掉到八成；配種偏好生乳牛。
- B 肉牛派：每頭牛到最佳體重（成年 72 小時）就出貨；配種偏好生肉牛。
- F 耕田派：會擴建田地，讓每頭耕牛都下田；配種偏好生耕牛（乳牛 × 肉牛 = 全部耕牛）。
- C 配種收集派：看重稀有度（商店挑高等級、借稀有公牛），稀有母牛多留一陣子。
- T 抓時機派：牛奶、稻米、牛肉都先存著，價格 ≥ 24 小時均價（或快變差）才賣。
- L 出借公牛派：自己的公牛都上架借種（價位看稀有度，一天沒人借就降一檔），自己的母牛向別人借種。
- Z 懶得照顧（v0.3）：照 D 經營，但每天只清一次大便、不雇小幫手、不餵飼料（量照顧的懲罰有多大）；地板買軟墊地。
- Y 飼料投機（v0.3 B）：照 D 經營，另外低買高賣飼料（spec_trade）：某種飼料的新聞開始以後（新聞不預告），
  價格跌到基本價的 SPEC_BUY_RATIO 以下就買到倉庫上限；賣回的錢（扣手續費）≥ 平均成本 × SPEC_SELL_MARGIN 就全部賣回。
- W 大戶：壓力測試。囤貨前照 D 經營；囤貨時換成大牧場，囤 48 小時後一次倒出／分批／一直囤。

v0.3 照顧（除了 Z，每種玩法都會）：每次上線先清大便、處理病牛（值得就治療，不值得就出貨）；新手保護過後，
預期省下的治療費（牛的頭數 × SICK_P_DAY × 治療費）不少於一天的小幫手錢才雇（預付到 HELPER_AHEAD_D 天後）；
掃地機照划算與否買（ROBOT_PAYBACK_D 天內省回買價）和修（robot_care），掃地機在動時不雇小幫手；照自己的玩法餵飼料（PROFILES 的 feed：B 豆粕、D 牧草、其他玉米），
稀有小牛先吃指定的飼料，還沒吃齊就 45 分鐘後回來再餵（care_return）；牛夠多就租最划算的長快地板（FLOOR_GAIN），
懶得照顧的買軟墊地（少生病）。

每次上線的順序：清大便、病牛 → 賣（或存）→ 出貨已配過種的到期牛 → 配種（自己的公牛優先，沒有就借種）→ 出貨其餘到期牛
→ 耕牛下田 → （L）上架公牛 → 花錢：掃地機、小幫手、商店補空格、奶桶、田地（F）／倉庫冷藏（T）、地板、擴建牛舍 → 餵飼料。
教學（每人第一次上線的 30 分鐘）：每分鐘賣奶、第 15 分鐘擴建、小公牛長大就配種、配完派去田裡。
"""

from __future__ import annotations

import math
import random
from typing import Dict, List, Optional, Tuple

from cowecon.farm import (
    BEEF, DAIRY, OX, Cow, Farm, beef_storage_factor, beef_value_at_base, cow_milk_rate, cow_rice_rate, freshness,
    is_milker, milk_frac, required_feeds, rice_factor, shop_grade_distribution,
)
from cowecon.params import DAY, HOUR, MINUTE, EconomyParams

STRATEGIES = ("D", "B", "F", "C", "T", "L", "Z", "Y", "W")
STRATEGY_NAMES = {"D": "乳牛派", "B": "肉牛派", "F": "耕田派", "C": "配種收集派", "T": "抓時機派", "L": "出借公牛派",
                  "Z": "懶得照顧", "Y": "飼料投機", "W": "大戶"}
CARE_STRATEGIES = ("D", "B", "F", "C", "T", "L")  # 照顧好的六種玩法（週收入差距的目標只看這六種）
PLAYER_STRATEGIES = CARE_STRATEGIES + ("Z", "Y")

BUCKET_TARGET_H = 6.0  # 奶桶至少放得下幾小時產量
DAIRY_SHIP_FRAC = 0.8  # 產奶（耕田）掉到八成以下就出貨
RARE_KEEP_FRAC = 0.6  # C：稀有母牛留到六成
PEAK_H = 72.0  # 最佳體重（成年後小時）
BULL_WAIT_MAX_H = 120.0  # 沒配過種的公牛最多等到這個年齡
HOLD_THR = 1.0  # T：價格 ≥ 24 小時均價 × 這個倍數才賣
HOLD_FRESH_SELL = 0.97  # T：新鮮度（牛奶、稻米、牛肉）掉到這以下就賣
HOLD_WH_TARGET_H = 14.0
HOLD_MIN_COWS = 12  # T：牛群少於這個數量時照 D 經營
STUD_RELIST_H = 24.0  # L：上架多久沒人借就降一檔
PANIC_SHIP_AGE_H = 48.0
TRACK_PLAYERS = 500  # 只追蹤前幾位玩家每頭牛的產出（量商店等級的實際價值；省記憶體）
# 照顧好的玩家不雇小幫手（每次上線照樣清大便）時，每頭牛每天平均生病幾次：100 人 30 天 seed 1–3 量的（六種玩法
# 0.079–0.086，2026-10-08）。小幫手一天 2,000 ÷（0.083 × 治療 5,000）≈ 5 頭以上才划算。
SICK_P_DAY = 0.083
HELPER_AHEAD_D = 2.0  # 小幫手預付到幾天後（不到就再加一天）
LAZY_CLEAN_H = 24.0  # Z：隔多久才清一次大便
# 掃地機壞掉以後到下次上線修好之前，每頭牛平均生病幾次（cow-back 2026-10-09 試算量的：電腦玩家 0.009–0.015，取高的）
ROBOT_SICK_PER_BREAK = 0.015
ROBOT_PAYBACK_D = 14.0  # 買掃地機：每天省下的錢要在幾天內把買價省回來
# Y 飼料投機（v0.3 B）：跌到基本價的幾成以下才買（大事件 −25–40%；手續費 25%，跌不到三成五沒得賺）、
# 賣回的錢（扣手續費和滑價）要比平均成本多幾成才賣
SPEC_BUY_RATIO = 0.65
SPEC_SELL_MARGIN = 1.05
CURE_PROD_H = 24.0  # 估治療值不值得：治好後多算幾小時的產量
# 長快地板每頭牛每天多賺多少淨收入（乾草床, 青草地）：100 人 30 天 seed 1、2，大家免費鋪同一種地板量第 3–4 週
# （牛群約 23 頭），2026-10-08。電腦玩家照「牛的頭數 × 這個 − 租金」挑最划算的地板，牛少就不租。
FLOOR_GAIN: Dict[str, Tuple[float, float]] = {
    "D": (370.0, 990.0), "B": (590.0, 1140.0), "F": (450.0, 860.0), "C": (460.0, 890.0), "T": (510.0, 1010.0),
    "L": (280.0, 610.0), "Z": (390.0, 840.0), "Y": (370.0, 990.0), "W": (0.0, 0.0),
}

# 中性估值：一頭牛一生（照模擬的平均市價）實際賺多少幣，依（用途、公母）× 稀有度 0–3。
# 來源：v0.2 模擬實測（1,000 人 28 天、seed 1，追蹤前 500 位玩家每頭牛的牛奶、稻米、出貨收入；
# World.summary()["value"]["kind"]），取整到百。2026-09-30 平衡調整（牛奶 14 瓶／時、12 幣、稻米 12 公斤／時）後重新量。bot 用它估商店等級與借種對象的價值。
VALUE_TABLE: Dict[Tuple[int, bool], Tuple[float, float, float, float]] = {
    (DAIRY, False): (15500.0, 21400.0, 28300.0, 42000.0),
    (DAIRY, True): (3600.0, 4800.0, 6500.0, 9500.0),
    (OX, False): (6900.0, 9600.0, 13400.0, 21900.0),
    (OX, True): (7600.0, 10300.0, 14800.0, 22200.0),
    (BEEF, False): (10700.0, 14200.0, 18600.0, 28100.0),
    (BEEF, True): (11700.0, 15400.0, 20400.0, 30100.0),
}
SHOP_CHOICE_SCALE = 1000.0  # 挑商店等級的個人差異（隨機效用的尺度，幣）

# v0.3：care = 照顧（full 照顧好、lazy 懶得照顧）；feed = 平常餵哪種飼料（None 不餵）
GRASS, HAY, OAT, ALFALFA, CORN, SOY = range(6)
PROFILES: Dict[str, dict] = {
    "D": {"pref": (1.25, 1.0, 1.0), "rarity": 0.0, "milker": "decline", "fields": False, "hold": False, "lend": False,
          "care": "full", "feed": GRASS},
    "B": {"pref": (1.0, 1.0, 1.25), "rarity": 0.0, "milker": "peak", "fields": False, "hold": False, "lend": False,
          "care": "full", "feed": SOY},
    "F": {"pref": (1.0, 1.25, 1.0), "rarity": 0.0, "milker": "decline", "fields": True, "hold": False, "lend": False,
          "care": "full", "feed": CORN},
    "C": {"pref": (1.0, 1.0, 1.0), "rarity": 0.6, "milker": "decline", "fields": False, "hold": False, "lend": False,
          "care": "full", "feed": CORN},
    "T": {"pref": (1.25, 1.0, 1.0), "rarity": 0.0, "milker": "decline", "fields": False, "hold": True, "lend": False,
          "care": "full", "feed": CORN},
    "L": {"pref": (1.0, 1.0, 1.0), "rarity": 0.2, "milker": "decline", "fields": False, "hold": False, "lend": True,
          "care": "full", "feed": CORN},
    "Z": {"pref": (1.25, 1.0, 1.0), "rarity": 0.0, "milker": "decline", "fields": False, "hold": False, "lend": False,
          "care": "lazy", "feed": None},
    "Y": {"pref": (1.25, 1.0, 1.0), "rarity": 0.0, "milker": "decline", "fields": False, "hold": False, "lend": False,
          "care": "full", "feed": GRASS, "spec": True},
    "W": {"pref": (1.25, 1.0, 1.0), "rarity": 0.0, "milker": "decline", "fields": False, "hold": False, "lend": False,
          "care": "full", "feed": None},
}


class Bot:
    __slots__ = (
        "pid", "strategy", "prof", "farm", "rng", "sched", "ledger", "joined_at", "tut_end", "taste",
        "first_sale", "first_expand", "first_breed", "returns", "whale", "worth", "grade_value", "last_clean",
        "care_return_at", "spec",
    )

    def __init__(self, pid: int, strategy: str, params: EconomyParams, joined_at: float, rng: random.Random, sched, ledger, n_days: int):
        self.pid = pid
        self.strategy = strategy
        self.prof = PROFILES[strategy]
        self.rng = rng
        self.sched = sched
        self.joined_at = joined_at
        self.tut_end = joined_at + 30 * MINUTE
        self.farm = Farm(params, joined_at, rng, care=True)
        self.ledger = ledger
        self.farm.log = ledger
        self.taste = rng.uniform(0.0, 0.3)  # 每位玩家對稀有的偏好不同（挑商店等級用）
        self.first_sale: Optional[float] = None
        self.first_expand: Optional[float] = None
        self.first_breed: Optional[float] = None
        self.returns: set = set()
        self.whale: Optional[dict] = None
        self.worth = [0.0] * n_days
        self.grade_value = grade_values(params, self.prof, self.taste)
        self.last_clean = joined_at  # Z：上次清大便的時間
        self.care_return_at = 0.0  # 已經排好回來餵小牛的時間
        self.spec = [[0, 0.0] for _ in range(len(params.care.feed_kg))]  # Y：每種飼料投機買的 [份數, 總成本]


# 由 world 設定
_W: Dict[str, object] = {}


def _mk(cid: str):
    return _W["ex"].markets[cid]


# ---------------------------------------------------------------------------
# 估值
# ---------------------------------------------------------------------------
def _val(prof: dict, t: int, bull: bool, tier: int, fp, bonus: float) -> float:
    return VALUE_TABLE[(t, bull)][tier] * prof["pref"][t] * (1.0 + bonus * tier)


def grade_values(params: EconomyParams, prof: dict, taste: float) -> List[float]:
    """這位玩家眼中商店 A／B／C 各值多少（期望值）。"""
    fp = params.farm
    bonus = prof["rarity"] + taste
    out = []
    for gi in range(len(fp.shop_grade_names)):
        ev = 0.0
        for (t, bull, mask), p in shop_grade_distribution(fp, gi).items():
            ev += p * _val(prof, t, bull, bin(mask).count("1"), fp, bonus)
        out.append(ev)
    return out


def _p_recessive(g: int, locus: int) -> float:
    return (((g >> (2 * locus)) & 1) + ((g >> (2 * locus + 1)) & 1)) / 2.0


def offspring_value(prof: dict, fp, sire_g: int, dam_g: int, bonus: float) -> float:
    """小牛的期望價值（用途、稀有度都用精確機率；各基因座獨立）。"""
    ps, pd = _p_recessive(sire_g, 0), _p_recessive(dam_g, 0)  # 給 F（肉用）等位基因的機率
    p_type = ((1 - ps) * (1 - pd), ps * (1 - pd) + (1 - ps) * pd, ps * pd)
    tier_p = [1.0, 0.0, 0.0, 0.0]
    for L in (1, 2, 3):
        q = _p_recessive(sire_g, L) * _p_recessive(dam_g, L)
        tier_p = [tier_p[k] * (1 - q) + (tier_p[k - 1] * q if k > 0 else 0.0) for k in range(4)]
    v = 0.0
    for t in range(3):
        if p_type[t] <= 0:
            continue
        per = sum(tier_p[k] * 0.5 * (VALUE_TABLE[(t, False)][k] + VALUE_TABLE[(t, True)][k]) * (1.0 + bonus * k) for k in range(4))
        v += p_type[t] * per * prof["pref"][t]
    return v


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


def choose_grade(b: Bot) -> Optional[int]:
    """隨機效用：每一級的效用 = 這位玩家估的淨賺（期望價值 − 價格）+ 個人差異（Gumbel，尺度 1,000 幣），
    在買得起的等級裡挑效用最高的。三級淨賺接近時三級都會有人買；某一級明顯划算時份額會集中到那一級。"""
    f = b.farm
    prices = f.fp.shop_grade_price
    best, best_u = None, None
    for gi, price in enumerate(prices):
        if f.coins < price:
            continue
        e = -math.log(-math.log(max(1e-12, min(1 - 1e-12, b.rng.random()))))  # Gumbel(0, 1)
        u = b.grade_value[gi] - price + SHOP_CHOICE_SCALE * e
        if best_u is None or u > best_u:
            best, best_u = gi, u
    return best


def fill_slots(b: Bot, now: float, leave_free: int = 0) -> None:
    f = b.farm
    while f.free_slots() > leave_free:
        gi = choose_grade(b)
        if gi is None or f.buy_shop(gi, now, b.rng) is None:
            break


def expand_and_fill(b: Bot, now: float) -> None:
    f = b.farm
    cheapest = f.fp.shop_grade_price[-1]
    while True:
        cost = f.next_pen_cost()
        if cost is None or f.coins < cost + cheapest or not f.can_expand_at(now):
            break
        f.expand_pen(now)
        fill_slots(b, now)


def is_due(b: Bot, c: Cow, now: float) -> bool:
    """這頭牛該出貨了嗎（不管有沒有配過種）。"""
    if not c.is_adult(now):
        return False
    fp = b.farm.fp
    a = c.adult_age_h(now)
    prof = b.prof
    if c.listed is not None:
        return False
    if is_milker(c):
        if prof["milker"] == "peak":
            return a >= PEAK_H
        limit = RARE_KEEP_FRAC if (b.strategy == "C" and c.tier >= 1) else DAIRY_SHIP_FRAC
        return milk_frac(fp, a) < limit
    if c.ctype == OX and c.field >= 0:
        return milk_frac(fp, a) < DAIRY_SHIP_FRAC
    if c.ctype == OX and b.farm.free_field() >= 0:
        return milk_frac(fp, a) < DAIRY_SHIP_FRAC  # 有空田就去耕，不急著出貨
    if c.bull and not c.bred and a < BULL_WAIT_MAX_H and _unbred_dams(b.farm, now):
        return False  # 還有母牛等著配
    return a >= PEAK_H


def _unbred_dams(f: Farm, now: float) -> bool:
    return any((not c.bull) and c.is_adult(now) and not c.bred for c in f.cows)


def ship_list(b: Bot, cows: List[Cow], now: float) -> None:
    f = b.farm
    for c in cows:
        if c.field >= 0:
            f.recall(c, now)
    ok = [c for c in cows if f.can_ship(c, now)]
    if not ok:
        return
    if b.prof["hold"] and len(f.cows) >= HOLD_MIN_COWS:
        for c in ok:
            f.ship_to_storage(c, now, b.rng)
    else:
        f.ship_many(ok, _mk("beef"), now, b.rng)


def breeding_pass(b: Bot, now: float) -> None:
    """每頭沒配過的成年母牛配一次：自己的公牛免費優先；沒有就向別人借（值得才借）。"""
    f = b.farm
    fp = f.fp
    dams = [c for c in f.cows if not c.bull and c.is_adult(now) and not c.bred and c.listed is None]
    if not dams:
        return
    dams.sort(key=lambda c: c.adult_at)
    bonus = b.prof["rarity"] + b.taste
    lend = b.prof["lend"]
    sm = _W["stud"]
    for dam in dams:
        if f.free_slots() <= 0:
            break
        sires = [] if lend else [c for c in f.cows if c.bull and c.is_adult(now) and not c.bred and c.listed is None]
        own = max(sires, key=lambda s: offspring_value(b.prof, fp, s.g, dam.g, bonus)) if sires else None
        own_val = offspring_value(b.prof, fp, own.g, dam.g, bonus) if own else 0.0
        # 借種候選：每種（用途、稀有度）最便宜的一筆
        best, best_gain = None, 0.0
        if own is None or b.strategy == "C":
            reserve = 0.0
            for t in range(3):
                for tier in range(len(fp.tier_mult)):  # 價值等級 0–3 和雜種（借種費便宜，基因照舊）
                    lst = sm.cheapest(t, tier, now, exclude_owner=b.pid)
                    if lst is None or sm.price(lst, now) > f.coins - reserve:
                        continue
                    gain = offspring_value(b.prof, fp, lst.g, dam.g, bonus) - sm.price(lst, now)
                    if gain > best_gain:
                        best, best_gain = lst, gain
        use_own = own is not None and (best is None or own_val >= best_gain)
        if dam.field >= 0:
            f.recall(dam, now)
        if use_own:
            if own.field >= 0:
                f.recall(own, now)
            f.breed(own, dam, now, b.rng)
        elif best is not None:
            owner = None if best.owner is None else _W["bots"][best.owner]
            price = sm.price(best, now)
            calf = sm.borrow(best.lid, f, b.pid, dam, now, b.rng, owner.farm if owner else None)
            if calf is not None:
                _W["world"].stud_log.append((now, price, owner.strategy if owner else None, b.strategy, best.ctype, best.tier))
                if owner is None:
                    sm.npc_refill(now, _W["npc_rng"])


def assign_fields(b: Bot, now: float) -> None:
    f = b.farm
    fp = f.fp
    idle = [c for c in f.cows if c.ctype == OX and f.can_work(c, now) and milk_frac(fp, c.adult_age_h(now)) >= DAIRY_SHIP_FRAC]
    if b.prof["lend"]:
        idle = [c for c in idle if not (c.bull and not c.bred)]  # L：沒配過的公牛拿去上架
    idle.sort(key=lambda c: -c.tier)
    for c in idle:
        i = f.free_field()
        if i < 0:
            break
        f.assign_field(c, i, now)


def lending(b: Bot, now: float) -> None:
    """L：沒配過的公牛長到最壯（借種費最高，D26）才上架；上架一天沒人借、又太老就下架（之後出貨）。
    一成年就上架的話，小公牛只有 30 幾公斤、借種費 40 幣上下，借的人最划算，借種市場會被便宜的小公牛占滿
    （ceo 2026-10-02 看完整模擬後決定）。"""
    f = b.farm
    sm = _W["stud"]
    for lst in list(sm.owner_listings(b.pid)):
        if now - lst.listed_at < STUD_RELIST_H * HOUR:
            continue
        c = f.cow_by_id(lst.cow_id)
        if c is None or c.adult_age_h(now) >= BULL_WAIT_MAX_H:
            sm.unlist(lst.lid, f)
    for c in f.cows:
        if c.bull and sm.can_list(f, c, now) and f.fp.peak_age_h[c.ctype] <= c.adult_age_h(now) < BULL_WAIT_MAX_H:
            sm.list_bull(f, b.pid, c, now)


def hold_sell(b: Bot, now: float) -> None:
    """T：三種商品都等好價錢。"""
    f = b.farm
    fp = f.fp
    mk, bk, rk = _mk("milk"), _mk("beef"), _mk("rice")
    f.drop_spoiled(now)
    f.collect(now)
    if mk.price >= mk.moving_average() * HOLD_THR:
        f.sell_all_milk(mk, now)
    else:
        old = [l for l in f.lots if freshness(fp, (now - l.t) / HOUR, f.fresh_level) < HOLD_FRESH_SELL]
        if old:
            f.sell_lots(mk, old, now)
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
    f.harvest(now)
    if f.rice_lots:
        if rk.price >= rk.moving_average() * HOLD_THR:
            f.sell_rice(rk, f.rice_stock(), now)
        else:
            q = sum(l.qty for l in f.rice_lots if rice_factor(fp, (now - l.t) / HOUR) < HOLD_FRESH_SELL)
            if q > 0:
                f.sell_rice(rk, q, now)
    if f.beef_lots:
        if bk.price >= bk.moving_average() * HOLD_THR:
            f.sell_beef(bk, f.beef_stock(), now)
        else:
            q = sum(l.qty for l in f.beef_lots if beef_storage_factor(fp, (now - l.t) / HOUR) < HOLD_FRESH_SELL + 0.02)
            if q > 0:
                f.sell_beef(bk, q, now)
    # 利多：D33 起新聞不預告，上線時看到已經開始的利多才知道。開始後 20 分鐘（漲到全幅之後）還沒到就排那時回來賣；
    # 已經過了就照上面「價格夠高就賣」處理（以前看提前公告的利多，在開始前就排好）
    for ev in _W["ex"].started(now):
        if ev.factor > 1.0 and ev.eid not in b.returns:
            b.returns.add(ev.eid)
            if ev.start_at + 20 * MINUTE > now:
                _W["world"].schedule(ev.start_at + 20 * MINUTE, b.pid, "hold_return", 5 * MINUTE)


def hold_return(b: Bot, world, now: float) -> None:
    f = b.farm
    for cid, sell in (("milk", lambda m: f.sell_all_milk(m, now)), ("rice", lambda m: f.sell_rice(m, f.rice_stock(), now) if f.rice_stock() > 0 else None), ("beef", lambda m: f.sell_beef(m, f.beef_stock(), now) if f.beef_stock() > 0 else None)):
        m = _mk(cid)
        if m.price >= m.moving_average() * HOLD_THR:
            if cid == "rice":
                f.harvest(now)
            sell(m)


# ---------------------------------------------------------------------------
# 照顧（v0.3）
# ---------------------------------------------------------------------------
def cure_value(f: Farm, c: Cow, now: float) -> float:
    """治好這頭病牛多值多少（粗估，基本價）：出貨價值多回來的九成 + CURE_PROD_H 小時的產量。
    小牛、還沒長到最壯的牛用長到最壯時的體重算。"""
    fp = f.fp
    p = f.p
    if c.is_adult(now) and c.adult_age_h(now) >= fp.peak_age_h[c.ctype]:
        v = beef_value_at_base(fp, c, now, p.beef.base_price)
    else:
        kg = fp.peak_weight_kg[c.ctype] * (fp.bull_weight_mult if c.bull else 1.0) + c.bonus
        v = kg * fp.tier_mult[c.vt] * p.beef.base_price
    v *= 1.0 - p.care.sick_beef_mult
    t = max(now, c.adult_at)
    v += CURE_PROD_H * (cow_milk_rate(fp, c, t) * fp.tier_mult[c.vt] * p.milk.base_price
                        + cow_rice_rate(fp, c, t) * p.rice.base_price)
    return v


def care_start(b: Bot, now: float) -> None:
    """上線先清大便（Z 每天一次），再處理病牛：值得就治療，不值得（或治不起）就出貨，小牛先放著。"""
    f = b.farm
    if b.prof["care"] == "full":
        f.clean(now)
    elif now - b.last_clean >= LAZY_CLEAN_H * HOUR:
        f.clean(now)
        b.last_clean = now
    else:
        f.advance(now)
    sick = [c for c in f.cows if c.sick_since is not None]
    if not sick:
        return
    sm = _W["stud"]
    cure_price = f.p.care.cure_price
    ship = []
    for c in sick:
        if c.listed is not None:
            sm.unlist(c.listed, f)
        if c.field >= 0:
            f.recall(c, now)
        if f.coins >= cure_price and cure_value(f, c, now) >= cure_price:
            f.cure(c, now, b.rng)
        elif c.is_adult(now):
            ship.append(c)
    if ship:
        ship_list(b, ship, now)


def robot_daily_cost(cp, m: int, n_cows: int) -> float:
    """第 m 款掃地機每天的預期花費：（修理費 + 壞掉期間病牛的治療費）÷ 平均幾天壞一次。"""
    return (cp.robot_repair[m] + n_cows * ROBOT_SICK_PER_BREAK * cp.cure_price) / cp.robot_mtbf_d[m]


def robot_rng(b: Bot, now: float) -> random.Random:
    """掃地機壞掉的時間用的亂數：由這位玩家（編號、taste）和現在的時間導出，跟玩家自己的亂數分開。
    掃地機的運氣就不會打亂玩家其他的隨機決定（比較有沒有掃地機、不同參數時，其他的事照同一條路走），也不必另外存檔。"""
    return random.Random(f"robot:{b.pid}:{b.taste!r}:{now!r}")


def robot_care(b: Bot, now: float) -> None:
    """掃地機（使用者 2026-10-09，cow-back 試算的 R3）：照顧好的玩家照划算與否決定，新手保護期間不買。
    沒有掃地機時每天的花費 = min(不清的預期治療費, 小幫手一天)。
    - 買（或換另一款）：（現在每天的花費 − 那一款每天的花費）× ROBOT_PAYBACK_D ≥ 買價，挑省最多的；留一頭 C 級小牛的錢。
    - 壞了：修好以後到下次壞掉之前省下的錢 ≥ 修理費就修，不然就不修（改雇小幫手）。"""
    f = b.farm
    cp = f.p.care
    if b.prof["care"] != "full" or now < f.created_at + cp.newbie_safe_s:
        return
    n = len(f.cows)
    alt = min(n * SICK_P_DAY * cp.cure_price, cp.helper_price_per_day)
    reserve = f.fp.shop_grade_price[-1]
    cur = robot_daily_cost(cp, f.robot, n) if f.robot >= 0 else alt
    best, best_v = -1, 0.0
    for m in range(len(cp.robot_price)):
        if m == f.robot:
            continue
        v = (cur - robot_daily_cost(cp, m, n)) * ROBOT_PAYBACK_D - cp.robot_price[m]
        if v > best_v:
            best, best_v = m, v
    if best >= 0 and f.coins >= cp.robot_price[best] + reserve:
        f.buy_robot(best, now, robot_rng(b, now))
        return
    if f.robot >= 0 and not f.robot_working(now):
        m = f.robot
        save = (alt - n * ROBOT_SICK_PER_BREAK * cp.cure_price / cp.robot_mtbf_d[m]) * cp.robot_mtbf_d[m]
        if save >= cp.robot_repair[m] and f.coins >= cp.robot_repair[m] + reserve:
            f.repair_robot(now, robot_rng(b, now))


def hire_helper(b: Bot, now: float) -> None:
    """划算才雇（ceo 2026-10-08）：新手保護期間不會生病，不雇；預期省下的治療費（牛的頭數 × SICK_P_DAY × 治療費）
    少於一天的小幫手錢也不雇。雇的話預付到 HELPER_AHEAD_D 天後，留一頭 C 級小牛的錢。"""
    f = b.farm
    if b.prof["care"] != "full":
        return
    cp = f.p.care
    if now < f.created_at + cp.newbie_safe_s or len(f.cows) * SICK_P_DAY * cp.cure_price < cp.helper_price_per_day:
        return
    if f.robot_working(now):  # 掃地機在動：不雇
        return
    reserve = f.fp.shop_grade_price[-1]
    while f.helper_until < now + HELPER_AHEAD_D * DAY and f.coins >= cp.helper_price_per_day + reserve:
        if not f.hire_helper(1, now):
            break


def best_floor(b: Bot, n_cows: int) -> int:
    """照顧好的玩家該租哪種長快地板：牛的頭數 × FLOOR_GAIN − 租金 最大的（都不划算就 0 = 泥土地）。"""
    cp = b.farm.p.care
    best, best_v = 0, 0.0
    for i, g in zip((1, 2), FLOOR_GAIN[b.strategy]):
        v = n_cows * g - cp.floor_rent_per_day[i]
        if v > best_v:
            best, best_v = i, v
    return best


def change_floor(b: Bot, now: float) -> None:
    """地板（ceo 2026-10-08）：
    - 懶得照顧（不雇小幫手）：買軟墊地（生病速度 ×0.5），留兩頭 C 級小牛的錢。
    - 照顧好的：照 best_floor 租長快地板，預付到 HELPER_AHEAD_D 天後（留一頭 C 級小牛的錢）。租約還沒到期就不換別種；
      不划算了就不再續租，到期自動回泥土地。"""
    f = b.farm
    cp = f.p.care
    sm = _W["stud"]
    if b.prof["care"] == "lazy":
        i = len(cp.floor_ids) - 1  # 軟墊地
        if not (f.floors >> i) & 1:
            if f.coins < cp.floor_price[i] + 2 * f.fp.shop_grade_price[-1] or not f.buy_floor(i, now):
                return
        if f.floor != i:
            f.use_floor(i, now)
            sm.follow_owner(b.pid, f)
        return
    want = best_floor(b, len(f.cows))
    if not want or f.rented not in (0, want):
        return
    reserve = f.fp.shop_grade_price[-1]
    rented = False
    while f.rent_until < now + HELPER_AHEAD_D * DAY and f.coins >= cp.floor_rent_per_day[want] + reserve:
        if not f.rent_floor(want, 1, now):
            break
        rented = True
    if f.floor != want and f.has_floor(want, now):
        f.use_floor(want, now)
        rented = True
    if rented:
        sm.follow_owner(b.pid, f)


def feed_pass(b: Bot, now: float) -> None:
    """照顧好的玩家：稀有小牛先吃還沒吃過的指定飼料，其他能吃的牛照自己的玩法餵（PROFILES 的 feed）。
    先算好每種要幾份、一次買齊（倉庫有的先用），再一頭一頭餵。小牛還有指定的飼料沒吃齊、45 分鐘後還是小牛，
    就排一次回來餵（care_return）。"""
    f = b.farm
    if b.prof["care"] != "full":
        return
    cp = f.p.care
    plan = []
    again = False
    for c in f.cows:
        k = b.prof["feed"]
        if not c.is_adult(now):
            missing = [x for x in required_feeds(cp, c.g) if not (c.fed >> x) & 1]
            if missing:
                k = missing[0]
                if len(missing) > 1 or f.feed_block(c, k, now) == "full":
                    again = again or now + cp.calf_feed_cooldown_s < c.adult_at
        if k is not None and f.feed_block(c, k, now) in (None, "no_feed"):
            plan.append((c, k))
    need = [0] * len(cp.feed_kg)
    for _c, k in plan:
        need[k] += 1
    for k, n in enumerate(need):
        if n > f.feeds[k]:  # v0.3 B：照市價買（含滑價）
            f.buy_feed_market(k, min(n - f.feeds[k], cp.feed_cap - f.feeds[k]), _W["ex"].feeds[cp.feed_ids[k]], now)
    for c, k in plan:
        f.feed(c, k, now)
    if again and b.care_return_at <= now:
        b.care_return_at = now + cp.calf_feed_cooldown_s
        _W["world"].schedule(b.care_return_at, b.pid, "care_return", 2 * MINUTE)


def spec_trade(b: Bot, now: float) -> None:
    """Y 飼料投機（v0.3 B）：
    - 賣：投機買的那批，賣回的錢（扣手續費、滑價）≥ 平均成本 × SPEC_SELL_MARGIN 就全部賣回。
    - 買：這種飼料的新聞已經開始（不預告，開始以後才知道）、價格 ≤ 基本價 × SPEC_BUY_RATIO，就買到倉庫上限，
      留一頭 C 級小牛的錢。投機的飼料不拿來餵（跟平常餵的分開記）。"""
    f = b.farm
    cp = f.p.care
    ex = _W["ex"]
    for k, fid in enumerate(cp.feed_ids):
        units, cost = b.spec[k]
        m = ex.feeds[fid]
        if units > 0 and f.feeds[k] >= units:
            q = f.quote_feed_sell(k, units, m, now)
            if q.amount >= cost * SPEC_SELL_MARGIN and f.sell_feed_market(k, units, m, now) is not None:
                b.spec[k] = [0, 0.0]
                continue
    news = {ev.targets[0] for ev in ex.feed_started(now)}
    reserve = f.fp.shop_grade_price[-1]
    for k, fid in enumerate(cp.feed_ids):
        m = ex.feeds[fid]
        if fid not in news or m.price > m.base_price * SPEC_BUY_RATIO:
            continue
        n = cp.feed_cap - f.feeds[k]
        while n > 0 and f.coins < f.quote_feed_buy(k, n, m, now).amount + reserve:
            n //= 2
        if n > 0:
            res = f.buy_feed_market(k, n, m, now)
            if res is not None:
                b.spec[k][0] += n
                b.spec[k][1] += res.amount


def care_return(b: Bot, world, now: float) -> None:
    """回來餵稀有小牛（只餵）。"""
    feed_pass(b, now)


# ---------------------------------------------------------------------------
# 一次上線
# ---------------------------------------------------------------------------
def manage(b: Bot, world, now: float) -> None:
    f = b.farm
    prof = b.prof
    # 0. 清大便、病牛
    care_start(b, now)
    # 1. 賣（或存）
    if prof["hold"] and len(f.cows) >= HOLD_MIN_COWS:
        hold_sell(b, now)
    else:
        f.sell_all_milk(_mk("milk"), now)
        f.sell_all_rice(_mk("rice"), now)
        if f.beef_lots:
            f.sell_beef(_mk("beef"), f.beef_stock(), now)
    if prof["lend"]:
        lending(b, now)
    # 2. 出貨已配過種（或不能配種）的到期牛 → 空出格子給小牛
    due = [c for c in f.cows if is_due(b, c, now)]
    ship_list(b, [c for c in due if c.bred or c.bull], now)
    # 3. 配種
    breeding_pass(b, now)
    # 4. 其餘到期的牛
    due = [c for c in f.cows if is_due(b, c, now)]
    ship_list(b, due, now)
    # 5. 耕牛下田
    assign_fields(b, now)
    if prof["lend"]:
        lending(b, now)
    # 6. 花錢
    robot_care(b, now)
    hire_helper(b, now)
    fill_slots(b, now)
    maintain_bucket(f, now)
    if prof["fields"]:
        idle_ox = sum(1 for c in f.cows if c.ctype == OX and c.is_adult(now) and c.field < 0 and not c.is_busy())
        young_ox = sum(1 for c in f.cows if c.ctype == OX and not c.is_adult(now))
        want = idle_ox + young_ox - sum(1 for fl in f.fields if fl.ox < 0)
        cheapest = f.fp.shop_grade_price[-1]
        while want > 0:
            cost = f.next_field_cost()
            if cost is None or f.coins < cost + cheapest:
                break
            f.expand_field(now)
            want -= 1
        assign_fields(b, now)
    if prof["hold"] and len(f.cows) >= HOLD_MIN_COWS:
        rate = herd_milk_rate(f, now)
        if f.fresh_level < 1:
            f.upgrade_fresh(now)
        while f.wh_capacity() < HOLD_WH_TARGET_H * rate:
            if not f.upgrade_wh(now):
                break
    change_floor(b, now)
    expand_and_fill(b, now)
    # 7. 餵飼料
    feed_pass(b, now)
    # 8. Y：飼料投機（v0.3 B）
    if prof.get("spec"):
        spec_trade(b, now)


def tutorial_step(b: Bot, world, now: float) -> None:
    f = b.farm
    f.sell_all_milk(_mk("milk"), now)
    if f.free_slots() <= 0:
        f.expand_pen(now)
    if f.free_slots() > 0:
        bulls = [c for c in f.cows if c.bull and c.can_breed_now(now)]
        cows = [c for c in f.cows if not c.bull and c.can_breed_now(now)]
        if bulls and cows:
            f.breed(bulls[0], cows[0], now, b.rng)
    for c in f.cows:  # 配完種的耕牛派去田裡
        if c.ctype == OX and c.bred and f.can_work(c, now) and f.free_field() >= 0:
            f.assign_field(c, f.free_field(), now)


# ---------------------------------------------------------------------------
# W 大戶
# ---------------------------------------------------------------------------
def setup_whale(b: Bot, cfg: dict) -> None:
    b.whale = dict(cfg)
    b.whale["results"] = []
    b.whale["ready"] = False


def _whale_become_big(b: Bot, now: float) -> None:
    """囤貨開始時換成大牧場：N 頭剛成年的一般母乳牛（年齡錯開）、滿級奶桶、倉庫、冷藏。"""
    f = b.farm
    fp = f.fp
    n = b.whale["cows"]
    f.advance(now)
    for c in list(f.cows):
        if c.field >= 0:
            f.recall(c, now)
    f.cows = []
    f.slots = n + 2
    f.bucket_level = fp.bucket_max_level
    f.wh_level = fp.wh_max_level
    f.fresh_level = len(fp.fresh_costs)
    for i in range(n):
        f.cows.append(Cow(f._new_id(), 0, False, now, fp, adult_at=now - (i % 24) * HOUR, origin="whale"))
    b.whale["ready"] = True


def whale_session(b: Bot, world, now: float) -> None:
    w = b.whale
    mode = w["mode"]
    if now < w["hoard_from"]:
        manage(b, world, now)
        return
    if not w["ready"]:
        _whale_become_big(b, now)
    if now < w["dump_at"]:
        b.farm.collect(now)  # 只收不賣；牛也不出貨
        if not w.get("scheduled"):
            w["scheduled"] = True
            if mode == "dump":
                world.schedule(w["dump_at"], b.pid, "whale_dump", 5 * MINUTE)
            elif mode == "batch":
                for k in range(w["batches"]):
                    world.schedule(w["dump_at"] + k * w["batch_gap_s"], b.pid, "whale_batch", 5 * MINUTE)
        return
    if not w.get("done"):
        return  # 倒貨期間只由 whale_dump / whale_batch 動作
    b.farm.sell_all_milk(_mk("milk"), now)


def _whale_sell(b: Bot, now: float, frac: float) -> None:
    f = b.farm
    w = b.whale
    mk, bk = _mk("milk"), _mk("beef")
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
    adults = [c for c in f.cows if f.can_ship(c, now)]
    k = max(1, round(len(adults) * frac)) if adults else 0
    cows = adults[:k]
    if cows:
        # 每頭先抽評級（和 ship_many 用同一個 rng 順序），估值用實際評級倍率
        lot_rng_state = b.rng.getstate()
        from cowecon.farm import beef_weight, draw_beef_grade

        values = 0.0
        for c in cows:
            g = draw_beef_grade(f.fp, c, now, b.rng)
            values += beef_weight(f.fp, c, now) * f.fp.beef_grade_mult[g] * f.fp.tier_mult[c.tier]
        b.rng.setstate(lot_rng_state)
        res = f.ship_many(cows, bk, now, b.rng)
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
def panic_sell(b: Bot, world, now: float) -> None:
    f = b.farm
    f.sell_all_milk(_mk("milk"), now)
    f.sell_all_rice(_mk("rice"), now)
    if f.beef_lots:
        f.sell_beef(_mk("beef"), f.beef_stock(), now)
    adults = [c for c in f.cows if c.is_adult(now) and c.adult_age_h(now) >= PANIC_SHIP_AGE_H and c.listed is None]
    for c in adults:
        if c.field >= 0:
            f.recall(c, now)
    if adults:
        f.ship_many(adults, _mk("beef"), now, b.rng)


EXTRA_FUNCS = {
    "care_return": care_return,
    "hold_return": hold_return,
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
        elif b.strategy == "W":
            whale_session(b, world, now)
        else:
            manage(b, world, now)
    else:
        EXTRA_FUNCS[kind](b, world, now)
    f = b.farm
    if b.first_sale is None and f.n_sales > 0:
        b.first_sale = now - b.joined_at
    if b.first_expand is None and f.expansions > 0:
        b.first_expand = now - b.joined_at
    if b.first_breed is None and f.first_breed_used:
        b.first_breed = now - b.joined_at
