"""電腦假玩家（v0.2 規則）。

照 docs/research/economy/sim/bots.py（v0.2）移植，判斷規則和數字完全相同；差別只在「動手」的部分
全部改成呼叫服務層（server.game.Game），和真人走同一組函式，對市場與借種市場的影響也就一樣。
每一步呼叫 cowecon 的順序和研究模擬相同，所以同一個 seed 的結果逐數字相同
（backend/tests/test_scenarios.py 會比對）。

所有 bot 共用一套經營流程，差別在偏好（PROFILES）：
- D 乳牛派：母乳牛留到產奶掉到八成；配種偏好生乳牛。
- B 肉牛派：每頭牛到最佳體重（成年 72 小時）就出貨；配種偏好生肉牛。
- F 耕田派：會擴建田地，讓每頭耕牛都下田；配種偏好生耕牛。
- C 配種收集派：看重稀有度（商店挑高等級、借稀有公牛），稀有母牛多留一陣子。
- T 抓時機派：牛奶、稻米、牛肉都先存著，價格 ≥ 24 小時均價（或快變差）才賣。
- L 出借公牛派：自己的公牛都上架借種（價位看稀有度，一天沒人借就降一檔），自己的母牛向別人借種。
- W 大戶（只給情境測試）：囤貨前照 D 經營；囤貨時換成大牧場，囤 48 小時後一次倒出／分批／一直囤。

每次上線的順序：賣（或存）→ 出貨已配過種的到期牛 → 配種（自己的公牛優先，沒有就借種）→ 出貨其餘到期牛
→ 耕牛下田 →（L）上架公牛 → 花錢：商店補空格、奶桶、田地（F）／倉庫冷藏（T）、擴建牛舍。
教學（每人第一次上線的 30 分鐘）：每分鐘賣奶、第 15 分鐘擴建、小公牛長大就配種、配完派去田裡。

ctx（呼叫端提供）要有：upcoming(now)、schedule(t, pid, kind, dur)、npc_rng（None = 服務層預設）。
"""

from __future__ import annotations

import math
import random
from typing import Dict, List, Optional, Tuple

from cowecon.farm import (
    BEEF,
    DAIRY,
    OX,
    Cow,
    Farm,
    beef_storage_factor,
    beef_weight,
    cow_milk_rate,
    draw_beef_grade,
    freshness,
    is_milker,
    milk_frac,
    rice_factor,
    shop_grade_distribution,
)
from cowecon.params import HOUR, MINUTE, EconomyParams

from .game import Game, GameError

STRATEGIES = ("D", "B", "F", "C", "T", "L", "W")
STRATEGY_NAMES = {
    "D": "乳牛派",
    "B": "肉牛派",
    "F": "耕田派",
    "C": "配種收集派",
    "T": "抓時機派",
    "L": "出借公牛派",
    "W": "大戶",
}
PLAYER_STRATEGIES = ("D", "B", "F", "C", "T", "L")

BUCKET_TARGET_H = 6.0  # 奶桶至少放得下幾小時產量
DAIRY_SHIP_FRAC = 0.8  # 產奶（耕田）掉到八成以下就出貨
RARE_KEEP_FRAC = 0.6  # C：稀有母牛留到六成
PEAK_H = 72.0  # 最佳體重（成年後小時）
BULL_WAIT_MAX_H = 120.0  # 沒配過種的公牛最多等到這個年齡
HOLD_THR = 1.0  # T：價格 ≥ 24 小時均價 × 這個倍數才賣
HOLD_FRESH_SELL = 0.97  # T：新鮮度（牛奶、稻米、牛肉）掉到這以下就賣
HOLD_WH_TARGET_H = 14.0
HOLD_MIN_COWS = 12  # T：牛群少於這個數量時照 D 經營
STUD_PRICE_BY_TIER = (0, 1, 2, 3)  # L：稀有度 → stud_prices 的第幾檔
STUD_RELIST_H = 24.0  # L：上架多久沒人借就降一檔
PANIC_SHIP_AGE_H = 48.0
TUTORIAL_S = 30 * MINUTE

# 中性估值：一頭牛一生實際賺多少幣，依（用途、公母）× 稀有度 0–3（研究模擬實測，見 sim/bots.py 的說明）。
# 經濟代理重新量過時要同步這張表（tests/test_scenarios.py 的 test_bot_tunables_match_research 會提醒）。
VALUE_TABLE: Dict[Tuple[int, bool], Tuple[float, float, float, float]] = {
    (DAIRY, False): (15500.0, 21400.0, 28300.0, 42000.0),
    (DAIRY, True): (3600.0, 4800.0, 6500.0, 9500.0),
    (OX, False): (6900.0, 9600.0, 13400.0, 21900.0),
    (OX, True): (7600.0, 10300.0, 14800.0, 22200.0),
    (BEEF, False): (10700.0, 14200.0, 18600.0, 28100.0),
    (BEEF, True): (11700.0, 15400.0, 20400.0, 30100.0),
}
SHOP_CHOICE_SCALE = 1000.0  # 挑商店等級的個人差異（隨機效用的尺度，幣）

PROFILES: Dict[str, dict] = {
    "D": {"pref": (1.25, 1.0, 1.0), "rarity": 0.0, "milker": "decline", "fields": False, "hold": False, "lend": False},
    "B": {"pref": (1.0, 1.0, 1.25), "rarity": 0.0, "milker": "peak", "fields": False, "hold": False, "lend": False},
    "F": {"pref": (1.0, 1.25, 1.0), "rarity": 0.0, "milker": "decline", "fields": True, "hold": False, "lend": False},
    "C": {"pref": (1.0, 1.0, 1.0), "rarity": 0.6, "milker": "decline", "fields": False, "hold": False, "lend": False},
    "T": {"pref": (1.25, 1.0, 1.0), "rarity": 0.0, "milker": "decline", "fields": False, "hold": True, "lend": False},
    "L": {"pref": (1.0, 1.0, 1.0), "rarity": 0.2, "milker": "decline", "fields": False, "hold": False, "lend": True},
    "W": {"pref": (1.25, 1.0, 1.0), "rarity": 0.0, "milker": "decline", "fields": False, "hold": False, "lend": False},
}


class Bot:
    """一位假玩家的決策狀態。牧場在 game.players[pid].farm（和真人一樣）。

    rng：這位 bot 做決定（挑商店等級）與服務層抽亂數（商店、配種、評級）用的亂數。
    情境測試給固定的亂數以便和研究模擬比對；伺服器每次動作前換成由 (種子, 玩家, 時間) 導出的亂數。
    """

    __slots__ = (
        "game",
        "pid",
        "strategy",
        "prof",
        "rng",
        "joined_at",
        "tut_end",
        "taste",
        "returns",
        "whale",
        "first_sale",
        "first_expand",
        "first_breed",
        "grade_value",
        "sched",
        "ledger",
        "worth",
    )

    def __init__(
        self, game: Game, pid: int, strategy: str, joined_at: float, taste: float, rng: Optional[random.Random] = None
    ):
        self.game = game
        self.pid = pid
        self.strategy = strategy
        self.prof = PROFILES[strategy]
        self.rng = rng
        self.joined_at = joined_at
        self.tut_end = joined_at + TUTORIAL_S
        self.taste = taste  # 對稀有的個人偏好（挑商店等級用）
        self.returns: set = set()
        self.whale: Optional[dict] = None
        self.first_sale: Optional[float] = None
        self.first_expand: Optional[float] = None
        self.first_breed: Optional[float] = None
        self.grade_value = grade_values(game.params, self.prof, taste)
        self.sched = None
        self.ledger = None
        self.worth = None

    @property
    def farm(self) -> Farm:
        return self.game.players[self.pid].farm


def _mk(b: Bot, cid: str):
    return b.game.ex.markets[cid]


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
    ps, pd = _p_recessive(sire_g, 0), _p_recessive(dam_g, 0)
    p_type = ((1 - ps) * (1 - pd), ps * (1 - pd) + (1 - ps) * pd, ps * pd)
    tier_p = [1.0, 0.0, 0.0, 0.0]
    for L in (1, 2, 3):
        q = _p_recessive(sire_g, L) * _p_recessive(dam_g, L)
        tier_p = [tier_p[k] * (1 - q) + (tier_p[k - 1] * q if k > 0 else 0.0) for k in range(4)]
    v = 0.0
    for t in range(3):
        if p_type[t] <= 0:
            continue
        per = sum(
            tier_p[k] * 0.5 * (VALUE_TABLE[(t, False)][k] + VALUE_TABLE[(t, True)][k]) * (1.0 + bonus * k)
            for k in range(4)
        )
        v += p_type[t] * per * prof["pref"][t]
    return v


# ---------------------------------------------------------------------------
# 服務層的包裝（失敗就當沒做，和模擬裡 Farm 方法回傳 None／False 一樣）
# ---------------------------------------------------------------------------
def _try(fn, *args, **kw):
    try:
        return fn(*args, **kw)
    except GameError:
        return None


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


def sell_all_rice(b: Bot, now: float) -> None:
    """收成並把倉庫的稻米全部賣掉 ＝ Farm.sell_all_rice。"""
    b.game.harvest(b.pid, now)
    q = b.farm.rice_stock()
    if q > 0:
        b.game.sell(b.pid, "rice", q, now)


def sell_milk_prefix(b: Bot, lots, now: float):
    """賣掉倉庫最前面（最舊）的這幾批牛奶 ＝ Farm.sell_lots（這幾批一定是最舊的）。"""
    return b.game.sell(b.pid, "milk", sum(l.qty for l in lots), now)


def ship_many(b: Bot, cows: List[Cow], now: float) -> Optional[dict]:
    """一次出貨多頭並立刻賣掉（同一筆單，滑價一起算）＝ Farm.ship_many：每頭依序評級、再一起賣。"""
    return b.game.ship_and_sell(b.pid, [c.cid for c in cows], now, rng=b.rng)


def herd_milk_rate(f: Farm, now: float) -> float:
    return sum(cow_milk_rate(f.fp, c, now) for c in f.cows)


def maintain_bucket(b: Bot, now: float) -> None:
    f = b.farm
    need = BUCKET_TARGET_H * herd_milk_rate(f, now)
    while f.bucket_capacity() < need:
        if _try(b.game.upgrade, b.pid, "bucket", now) is None:
            break


def choose_grade(b: Bot) -> Optional[int]:
    """隨機效用：每一級的效用 = 這位玩家估的淨賺 + 個人差異（Gumbel，尺度 1,000 幣），在買得起的等級裡挑最高的。"""
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
        if gi is None or _try(b.game.shop_buy, b.pid, gi, now, rng=b.rng) is None:
            break


def expand_and_fill(b: Bot, now: float) -> None:
    f = b.farm
    cheapest = f.fp.shop_grade_price[-1]
    while True:
        cost = f.next_pen_cost()
        if cost is None or f.coins < cost + cheapest or not f.can_expand_at(now):
            break
        _try(b.game.upgrade, b.pid, "pen", now)
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
    g = b.game
    f = b.farm
    for c in cows:
        if c.field >= 0:
            g.field_recall(b.pid, c.cid, now)
    ok = [c for c in cows if f.can_ship(c, now)]
    if not ok:
        return
    if b.prof["hold"] and len(f.cows) >= HOLD_MIN_COWS:
        for c in ok:
            g.ship(b.pid, c.cid, now, rng=b.rng)
    else:
        ship_many(b, ok, now)


def breeding_pass(b: Bot, ctx, now: float) -> None:
    """每頭沒配過的成年母牛配一次：自己的公牛免費優先；沒有就向別人借（值得才借）。"""
    g = b.game
    f = b.farm
    fp = f.fp
    dams = [c for c in f.cows if not c.bull and c.is_adult(now) and not c.bred and c.listed is None]
    if not dams:
        return
    dams.sort(key=lambda c: c.adult_at)
    bonus = b.prof["rarity"] + b.taste
    lend = b.prof["lend"]
    sm = g.stud
    for dam in dams:
        if f.free_slots() <= 0:
            break
        sires = [] if lend else [c for c in f.cows if c.bull and c.is_adult(now) and not c.bred and c.listed is None]
        own = max(sires, key=lambda s: offspring_value(b.prof, fp, s.g, dam.g, bonus)) if sires else None
        own_val = offspring_value(b.prof, fp, own.g, dam.g, bonus) if own else 0.0
        best, best_gain = None, 0.0
        if own is None or b.strategy == "C":
            for t in range(3):
                for tier in range(4):
                    lst = sm.cheapest(t, tier, exclude_owner=b.pid)
                    if lst is None or lst.price > f.coins:
                        continue
                    gain = offspring_value(b.prof, fp, lst.g, dam.g, bonus) - lst.price
                    if gain > best_gain:
                        best, best_gain = lst, gain
        use_own = own is not None and (best is None or own_val >= best_gain)
        if dam.field >= 0:
            g.field_recall(b.pid, dam.cid, now)
        if use_own:
            if own.field >= 0:
                g.field_recall(b.pid, own.cid, now)
            _try(g.breed, b.pid, own.cid, dam.cid, now, rng=b.rng)
        elif best is not None:
            _try(g.stud_borrow, b.pid, best.lid, dam.cid, now, rng=b.rng, npc_rng=getattr(ctx, "npc_rng", None))


def assign_fields(b: Bot, now: float) -> None:
    f = b.farm
    fp = f.fp
    idle = [
        c
        for c in f.cows
        if c.ctype == OX and f.can_work(c, now) and milk_frac(fp, c.adult_age_h(now)) >= DAIRY_SHIP_FRAC
    ]
    if b.prof["lend"]:
        idle = [c for c in idle if not (c.bull and not c.bred)]  # L：沒配過的公牛拿去上架
    idle.sort(key=lambda c: -c.tier)
    for c in idle:
        i = f.free_field()
        if i < 0:
            break
        b.game.field_assign(b.pid, c.cid, i, now)


def lending(b: Bot, now: float) -> None:
    """L：沒配過的成年公牛都上架；一天沒人借就降一檔；最便宜也沒人借、又太老就下架（之後出貨）。"""
    g = b.game
    f = b.farm
    fp = f.fp
    sm = g.stud
    prices = fp.stud_prices
    for lst in list(sm.owner_listings(b.pid)):
        if now - lst.listed_at < STUD_RELIST_H * HOUR:
            continue
        c = f.cow_by_id(lst.cow_id)
        g.stud_unlist(b.pid, lst.lid)
        if c is None:
            continue
        i = prices.index(lst.price)
        if i > 0:
            _try(g.stud_list, b.pid, c.cid, prices[i - 1], now)
        elif c.adult_age_h(now) < BULL_WAIT_MAX_H:
            _try(g.stud_list, b.pid, c.cid, prices[0], now)
    for c in list(f.cows):
        if c.bull and sm.can_list(f, c, now) and c.adult_age_h(now) < BULL_WAIT_MAX_H:
            _try(g.stud_list, b.pid, c.cid, prices[STUD_PRICE_BY_TIER[c.tier]], now)


def hold_sell(b: Bot, ctx, now: float) -> None:
    """T：三種商品都等好價錢。"""
    g = b.game
    f = b.farm
    fp = f.fp
    mk, bk, rk = _mk(b, "milk"), _mk(b, "beef"), _mk(b, "rice")
    g.drop_spoiled(b.pid, now)
    g.collect(b.pid, now)
    if mk.price >= mk.moving_average() * HOLD_THR:
        sell_all_milk(b, now)
    else:
        old = [l for l in f.lots if freshness(fp, (now - l.t) / HOUR, f.fresh_level) < HOLD_FRESH_SELL]
        if old:
            sell_milk_prefix(b, old, now)
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
                sell_milk_prefix(b, sell, now)
            g.collect(b.pid, now)
            if f.bucket_total() > 1e-6:
                sell_all_milk(b, now)
    g.harvest(b.pid, now)
    if f.rice_lots:
        if rk.price >= rk.moving_average() * HOLD_THR:
            g.sell(b.pid, "rice", f.rice_stock(), now)
        else:
            q = sum(l.qty for l in f.rice_lots if rice_factor(fp, (now - l.t) / HOUR) < HOLD_FRESH_SELL)
            if q > 0:
                g.sell(b.pid, "rice", q, now)
    if f.beef_lots:
        if bk.price >= bk.moving_average() * HOLD_THR:
            g.sell(b.pid, "beef", f.beef_stock(), now)
        else:
            q = sum(l.qty for l in f.beef_lots if beef_storage_factor(fp, (now - l.t) / HOUR) < HOLD_FRESH_SELL + 0.02)
            if q > 0:
                g.sell(b.pid, "beef", q, now)
    # 提前公告的利多：事件開始後 20 分鐘回來賣
    for ev in ctx.upcoming(now):
        if ev.factor > 1.0 and ev.eid not in b.returns:
            b.returns.add(ev.eid)
            ctx.schedule(ev.start_at + 20 * MINUTE, b.pid, "hold_return", 5 * MINUTE)


def hold_return(b: Bot, ctx, now: float) -> None:
    g = b.game
    f = b.farm
    for cid in ("milk", "rice", "beef"):
        m = _mk(b, cid)
        if m.price >= m.moving_average() * HOLD_THR:
            if cid == "milk":
                sell_all_milk(b, now)
            elif cid == "rice":
                g.harvest(b.pid, now)
                if f.rice_stock() > 0:
                    g.sell(b.pid, "rice", f.rice_stock(), now)
            elif f.beef_stock() > 0:
                g.sell(b.pid, "beef", f.beef_stock(), now)


# ---------------------------------------------------------------------------
# 一次上線
# ---------------------------------------------------------------------------
def manage(b: Bot, ctx, now: float) -> None:
    g = b.game
    f = b.farm
    prof = b.prof
    # 1. 賣（或存）
    if prof["hold"] and len(f.cows) >= HOLD_MIN_COWS:
        hold_sell(b, ctx, now)
    else:
        sell_all_milk(b, now)
        sell_all_rice(b, now)
        if f.beef_lots:
            g.sell(b.pid, "beef", f.beef_stock(), now)
    if prof["lend"]:
        lending(b, now)
    # 2. 出貨已配過種（或不能配種）的到期牛 → 空出格子給小牛
    due = [c for c in f.cows if is_due(b, c, now)]
    ship_list(b, [c for c in due if c.bred or c.bull], now)
    # 3. 配種
    breeding_pass(b, ctx, now)
    # 4. 其餘到期的牛
    due = [c for c in f.cows if is_due(b, c, now)]
    ship_list(b, due, now)
    # 5. 耕牛下田
    assign_fields(b, now)
    if prof["lend"]:
        lending(b, now)
    # 6. 花錢
    fill_slots(b, now)
    maintain_bucket(b, now)
    if prof["fields"]:
        idle_ox = sum(1 for c in f.cows if c.ctype == OX and c.is_adult(now) and c.field < 0 and not c.is_busy())
        young_ox = sum(1 for c in f.cows if c.ctype == OX and not c.is_adult(now))
        want = idle_ox + young_ox - sum(1 for fl in f.fields if fl.ox < 0)
        cheapest = f.fp.shop_grade_price[-1]
        while want > 0:
            cost = f.next_field_cost()
            if cost is None or f.coins < cost + cheapest:
                break
            _try(g.upgrade, b.pid, "field", now)
            want -= 1
        assign_fields(b, now)
    if prof["hold"] and len(f.cows) >= HOLD_MIN_COWS:
        rate = herd_milk_rate(f, now)
        if f.fresh_level < 1:
            _try(g.upgrade, b.pid, "fresh", now)
        while f.wh_capacity() < HOLD_WH_TARGET_H * rate:
            if _try(g.upgrade, b.pid, "warehouse", now) is None:
                break
    expand_and_fill(b, now)


def tutorial_step(b: Bot, ctx, now: float) -> None:
    g = b.game
    f = b.farm
    sell_all_milk(b, now)
    if f.free_slots() <= 0:
        _try(g.upgrade, b.pid, "pen", now)
    if f.free_slots() > 0:
        bulls = [c for c in f.cows if c.bull and c.can_breed_now(now)]
        cows = [c for c in f.cows if not c.bull and c.can_breed_now(now)]
        if bulls and cows:
            _try(g.breed, b.pid, bulls[0].cid, cows[0].cid, now, rng=b.rng)
    for c in list(f.cows):  # 配完種的耕牛派去田裡
        if c.ctype == OX and c.bred and f.can_work(c, now) and f.free_field() >= 0:
            g.field_assign(b.pid, c.cid, f.free_field(), now)


# ---------------------------------------------------------------------------
# W 大戶（情境測試用）
# ---------------------------------------------------------------------------
def setup_whale(b: Bot, cfg: dict) -> None:
    b.whale = dict(cfg)
    b.whale["results"] = []
    b.whale["ready"] = False


def _whale_become_big(b: Bot, now: float) -> None:
    """囤貨開始時換成大牧場（測試專用的管理動作，直接改牧場）。"""
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


def whale_session(b: Bot, ctx, now: float) -> None:
    w = b.whale
    mode = w["mode"]
    if now < w["hoard_from"]:
        manage(b, ctx, now)
        return
    if not w["ready"]:
        _whale_become_big(b, now)
    if now < w["dump_at"]:
        b.game.collect(b.pid, now)  # 只收不賣；牛也不出貨
        if not w.get("scheduled"):
            w["scheduled"] = True
            if mode == "dump":
                ctx.schedule(w["dump_at"], b.pid, "whale_dump", 5 * MINUTE)
            elif mode == "batch":
                for k in range(w["batches"]):
                    ctx.schedule(w["dump_at"] + k * w["batch_gap_s"], b.pid, "whale_batch", 5 * MINUTE)
        return
    if not w.get("done"):
        return  # 倒貨期間只由 whale_dump / whale_batch 動作
    sell_all_milk(b, now)


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
        res = sell_milk_prefix(b, sell, now)
        w["results"].append(("milk", now, res["qty"], res["proceeds"], values, res["market_price"], res["discount"]))
    adults = [c for c in f.cows if f.can_ship(c, now)]
    k = max(1, round(len(adults) * frac)) if adults else 0
    cows = adults[:k]
    if cows:
        state = b.rng.getstate()  # 先照同一個亂數順序算出評級，估值用實際評級倍率
        values = 0.0
        for c in cows:
            gr = draw_beef_grade(f.fp, c, now, b.rng)
            values += beef_weight(f.fp, c, now) * f.fp.beef_grade_mult[gr] * f.fp.tier_mult[c.tier]
        b.rng.setstate(state)
        res = ship_many(b, cows, now)
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
    g = b.game
    f = b.farm
    sell_all_milk(b, now)
    sell_all_rice(b, now)
    if f.beef_lots:
        g.sell(b.pid, "beef", f.beef_stock(), now)
    adults = [c for c in f.cows if c.is_adult(now) and c.adult_age_h(now) >= PANIC_SHIP_AGE_H and c.listed is None]
    for c in adults:
        if c.field >= 0:
            g.field_recall(b.pid, c.cid, now)
    if adults:
        ship_many(b, adults, now)


EXTRA_FUNCS = {
    "hold_return": hold_return,
    "whale_dump": whale_dump,
    "whale_batch": whale_batch,
    "panic_sell": panic_sell,
}


def act(b: Bot, ctx, now: float, kind: str) -> None:
    if kind == "tutorial":
        tutorial_step(b, ctx, now)
    elif kind == "session":
        if now < b.tut_end:
            tutorial_step(b, ctx, now)
        elif b.strategy == "W":
            whale_session(b, ctx, now)
        else:
            manage(b, ctx, now)
    else:
        EXTRA_FUNCS[kind](b, ctx, now)
    f = b.farm
    if b.first_sale is None and f.n_sales > 0:
        b.first_sale = now - b.joined_at
    if b.first_expand is None and f.expansions > 0:
        b.first_expand = now - b.joined_at
    if b.first_breed is None and f.first_breed_used:
        b.first_breed = now - b.joined_at
