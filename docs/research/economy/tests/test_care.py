"""v0.3 照顧規則（docs/design/v0.3-care.md、決定 D35）：長大才揭曉與雜種牛、飼料、地板、大便與生病、治療、打掃小幫手、存檔。"""

import json
import math
import random
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import sim  # noqa: E402,F401  （把 backend/ 加進 sys.path）

from cowecon import DAY, DEFAULT, HOUR, MINUTE, Exchange  # noqa: E402
from cowecon.farm import (  # noqa: E402
    HYBRID,
    Cow,
    Farm,
    StudListing,
    StudMarket,
    beef_expected_mult,
    beef_grade_probs,
    beef_weight,
    cow_milk_between,
    cow_milk_rate,
    cow_rice_rate,
    make_genotype,
    required_feeds,
    shop_grade_distribution,
    stud_fee,
)

T0 = 1791129600.0
FP = DEFAULT.farm
CP = DEFAULT.care
GRASS, HAY, OAT, ALFALFA, CORN, SOY = range(6)


def genes(t, mask=0):
    """用途 t、顯現的稀有特徵位元 mask（純合）。"""
    return make_genotype(t, [(1, 1) if (mask >> i) & 1 else (0, 0) for i in range(3)])


def farm(care=True, seed=1):
    f = Farm(DEFAULT, T0, random.Random(seed), care=care)
    f.coins = 1e7
    f.slots = 40
    return f


def add_cow(f, t, mask=0, bull=False, now=T0, adult_h=None, origin="breed", rng=None):
    """在 now 把一頭牛放進牧場（adult_h = None：剛出生的小牛；否則已經成年 adult_h 小時）。"""
    f.advance(now)
    adult_at = None if adult_h is None else now - adult_h * HOUR
    c = Cow(f._new_id(), genes(t, mask), bull, now, FP, adult_at=adult_at, origin=origin, speed=f.speed)
    if f.care:
        f._arm(c, rng or random.Random(c.cid))
    f.cows.append(c)
    return c


def stock(f, k=SOY, n=100):
    f.feeds[k] += n


class TestReveal(unittest.TestCase):
    """第 1 節：每頭小牛一樣 3 小時長大；稀有以上的品種小牛時期沒吃齊指定的飼料，長大變雜種牛。"""

    def test_every_calf_grows_in_three_hours(self):
        for mask in range(8):
            c = Cow(1, genes(2, mask), False, T0, FP)
            self.assertEqual(c.adult_at - T0, 3 * HOUR)

    def test_required_feeds_table(self):
        self.assertEqual(required_feeds(CP, genes(2, 6)), (CORN, SOY))  # 白和牛
        self.assertEqual(required_feeds(CP, genes(0, 3)), (ALFALFA,))  # 奶油棉花牛
        for t in range(3):
            for mask in (0, 1, 2, 4):  # 一般、優良：沒有指定
                self.assertEqual(required_feeds(CP, genes(t, mask)), ())
            for mask in (3, 5, 6, 7):  # 稀有、傳說：每種都有 1 或 2 種
                self.assertIn(len(required_feeds(CP, genes(t, mask))), (1, 2))

    def test_missing_required_feed_makes_hybrid(self):
        f = farm()
        stock(f, CORN)
        c = add_cow(f, 2, 6)
        self.assertTrue(f.feed(c, CORN, T0))
        f.advance(c.adult_at)
        self.assertTrue(c.grown)
        self.assertEqual(c.vt, HYBRID)
        self.assertTrue(c.hybrid)
        self.assertEqual(c.tier, 2)  # 基因的稀有度照舊（配種用）

    def test_all_required_feeds_keep_the_breed(self):
        f = farm()
        stock(f, CORN)
        stock(f, SOY)
        c = add_cow(f, 2, 6)
        self.assertTrue(f.feed(c, CORN, T0))
        self.assertTrue(f.feed(c, SOY, T0 + 45 * MINUTE))
        f.advance(c.adult_at + HOUR)
        self.assertEqual(c.vt, 2)

    def test_feed_at_adulthood_is_not_a_calf_feed(self):
        f = farm()
        stock(f, CORN)
        stock(f, SOY)
        c = add_cow(f, 2, 6)
        f.feed(c, CORN, T0)
        self.assertTrue(f.feed(c, SOY, c.adult_at))  # 成年那一刻餵：成牛的冷卻，不算小牛時期
        self.assertEqual(c.fed, 1 << CORN)
        self.assertEqual(c.fed_until, c.adult_at + CP.feed_cooldown_s)
        self.assertEqual(c.vt, HYBRID)

    def test_common_good_starter_and_care_off_never_hybrid(self):
        f = farm()
        common = add_cow(f, 0, 0)
        good = add_cow(f, 0, 4)
        off = farm(care=False)
        rare_off = add_cow(off, 1, 7)
        starter = f.cows[1]  # 開局的小公牛：就算基因是傳說也不會變雜種
        starter.g, starter.tier, starter.vt = genes(1, 7), 3, 3
        f.advance(T0 + 4 * HOUR)
        off.advance(T0 + 4 * HOUR)
        self.assertEqual((common.vt, good.vt, starter.vt, rare_off.vt), (0, 1, 3, 3))

    def test_hybrid_value_is_index_four(self):
        """雜種牛：奶進奶桶第 5 格、倍數 0.6；牛肉批次 tier 4；耕田 × 0.6；出貨評級的稀有度分數算一般。"""
        f = farm()
        f.advance(T0 + 30 * HOUR)
        dairy = add_cow(f, 0, 3, now=T0 + 30 * HOUR)
        ox = add_cow(f, 1, 3, now=T0 + 30 * HOUR)
        common_ox = add_cow(f, 1, 0, now=T0 + 30 * HOUR)
        t = dairy.adult_at + 2 * HOUR
        f.bucket_level = 10
        f.advance(t)
        self.assertEqual(dairy.vt, HYBRID)
        self.assertGreater(f.bucket[HYBRID], 0)
        self.assertEqual(FP.tier_mult[HYBRID], 0.6)
        self.assertAlmostEqual(cow_rice_rate(FP, ox, t), cow_rice_rate(FP, common_ox, t) * 0.6)
        self.assertEqual(beef_grade_probs(FP, ox, t), beef_grade_probs(FP, common_ox, t))
        self.assertAlmostEqual(beef_expected_mult(FP, ox, t), beef_expected_mult(FP, common_ox, t) * 0.6)
        lot = f.ship_to_storage(ox, t, random.Random(1))
        self.assertEqual(lot.tier, HYBRID)
        self.assertAlmostEqual(lot.mult, FP.beef_grade_mult[lot.grade] * 0.6)

    def test_hybrid_bull_stud_fee(self):
        f = farm()
        sm = StudMarket(DEFAULT)
        bull = add_cow(f, 2, 6, bull=True)
        t = bull.adult_at + 10 * HOUR
        lst = sm.list_bull(f, "p1", bull, t)
        self.assertEqual(lst.vt, HYBRID)
        self.assertEqual(lst.tier, 2)
        price, kg, _ = sm.fee(lst, t)
        self.assertEqual(price, round(kg * 0.6 / 10) * 10)
        self.assertIs(sm.cheapest(2, HYBRID, t), lst)
        self.assertIsNone(sm.cheapest(2, 2, t))
        back = StudListing.from_dict(json.loads(json.dumps(lst.to_dict())))
        self.assertEqual((back.vt, back.tier), (HYBRID, 2))


class TestFeed(unittest.TestCase):
    """第 2 節（ceo 2026-10-03）：一份長固定公斤數、最多 +60 kg；成牛冷卻 4 小時、小牛 45 分鐘；過了最壯不能餵。"""

    def test_buy_feed_price_and_cap(self):
        f = farm()
        f.coins = 10_000
        self.assertTrue(f.buy_feed(SOY, CP.feed_cap, T0))
        self.assertEqual(f.coins, 10_000 - CP.feed_price[SOY] * CP.feed_cap)
        self.assertFalse(f.buy_feed(SOY, 1, T0))  # 倉庫滿了
        self.assertTrue(f.buy_feed(GRASS, 3, T0, price=7.0))
        self.assertEqual(f.feeds[GRASS], 3)
        f.coins = 1
        self.assertFalse(f.buy_feed(HAY, 1, T0))

    def test_cooldowns(self):
        f = farm()
        stock(f, GRASS)
        calf = add_cow(f, 2)
        self.assertTrue(f.feed(calf, GRASS, T0))
        self.assertEqual(f.feed_block(calf, GRASS, T0 + 44 * MINUTE), "full")
        self.assertTrue(f.feed(calf, GRASS, T0 + 45 * MINUTE))
        adult = add_cow(f, 2, adult_h=1, now=T0 + HOUR)
        self.assertTrue(f.feed(adult, GRASS, T0 + HOUR))
        self.assertEqual(f.feed_block(adult, GRASS, T0 + 5 * HOUR - 1), "full")
        self.assertTrue(f.feed(adult, GRASS, T0 + 5 * HOUR))
        self.assertEqual(f.feeds[GRASS], 100 - 4)

    def test_bonus_kg_cap_and_blocks(self):
        f = farm()
        stock(f, SOY)
        c = add_cow(f, 2, adult_h=0)
        t = T0
        while f.feed_block(c, SOY, t) is None:
            f.feed(c, SOY, t)
            t += CP.feed_cooldown_s
        self.assertEqual(c.bonus, CP.bonus_max_kg)  # 8 × 7 = 56，第 8 次到 60 停
        self.assertEqual(f.feed_block(c, SOY, t), "bonus_max")
        old = add_cow(f, 2, adult_h=FP.peak_age_h[2], now=t)
        self.assertEqual(f.feed_block(old, SOY, t), "past_peak")
        f.feeds[GRASS] = 0
        self.assertEqual(f.feed_block(add_cow(f, 2, now=t), GRASS, t), "no_feed")

    def test_listed_bull_cannot_eat(self):
        f = farm()
        stock(f, SOY)
        sm = StudMarket(DEFAULT)
        bull = add_cow(f, 2, bull=True, adult_h=1)
        self.assertTrue(f.feed(bull, SOY, T0))
        t = T0 + 5 * HOUR
        lst = sm.list_bull(f, "p1", bull, t)
        self.assertEqual(lst.bonus, 8.0)
        self.assertEqual(f.feed_block(bull, SOY, t), "listed")

    def test_bonus_grows_in_with_age(self):
        """體重 = 照年紀的體重 + 加成 ×（成年後的年紀 ÷ 長到最壯的時間）：剛成年加成還沒長出來，長到最壯全部長出來。"""
        f = farm()
        c = add_cow(f, 2, bull=True, adult_h=0)
        plain = add_cow(f, 2, bull=True, adult_h=0)
        c.bonus = 40.0
        pa = FP.peak_age_h[2]
        for frac in (0.0, 0.25, 1.0, 1.5):
            t = T0 + frac * pa * HOUR
            self.assertAlmostEqual(beef_weight(FP, c, t), beef_weight(FP, plain, t) + 40.0 * min(frac, 1.0))
            fee, kg, _ = stud_fee(FP, 2, 0, c.adult_at, t, 1.0, 40.0)
            self.assertAlmostEqual(kg, beef_weight(FP, c, t))

    def test_no_calf_arbitrage_with_max_feed_and_fastest_floor(self):
        """「買 C 級小牛、灌最貴的飼料、一長大就出貨」：最快的地板（2 小時長大）、小牛冷卻 45 分鐘（餵 3 次）、成年那一刻
        再餵 1 次，價格用總價格上限 2.2 倍、照實際評級機率，期望收入也低於 C 級價格 + 飼料錢。
        加成如果不跟著年紀長出來（直接加 32 公斤），1.48 倍市價就回本，這個測試會失敗。"""
        speed = max(CP.floor_speed)
        grow_h = FP.tier_growth_h[0] / speed
        n_calf = int(grow_h * HOUR // CP.calf_feed_cooldown_s) + (1 if grow_h * HOUR % CP.calf_feed_cooldown_s else 0)
        n_feeds = n_calf + 1
        bonus = min(CP.bonus_max_kg, n_feeds * CP.feed_kg[SOY])
        cost = FP.shop_grade_price[2] + n_feeds * CP.feed_price[SOY]
        price = DEFAULT.beef.base_price * 2.2
        ev = 0.0
        for (t, bull, mask), p in shop_grade_distribution(FP, "C").items():
            c = Cow(1, genes(t, mask), bull, T0, FP, speed=speed)
            c.bonus = bonus
            ev += p * beef_weight(FP, c, c.adult_at) * beef_expected_mult(FP, c, c.adult_at) * price
        self.assertEqual(n_feeds, 4)
        self.assertLess(ev, cost)


class TestPoopAndHelper(unittest.TestCase):
    """第 5 節：每頭牛每 3 小時一坨、最多 4 坨；清掉以後照原本的時鐘繼續拉；小幫手每 30 分鐘清全部。"""

    def test_schedule_and_cap(self):
        f = farm()  # 開局 2 頭牛，時鐘從開牧場算
        self.assertEqual(f.poop_total(T0 + 3 * HOUR - 1), 0)
        self.assertEqual(f.poop_total(T0 + 3 * HOUR), 2)
        self.assertEqual(f.poop_total(T0 + 12 * HOUR), 8)
        self.assertEqual(f.poop_total(T0 + 30 * HOUR), 8)

    def test_clean_and_clock(self):
        f = farm()
        self.assertEqual(f.clean(T0 + 4 * HOUR), 2)
        self.assertEqual(f.poop_total(T0 + 6 * HOUR - 1), 0)
        self.assertEqual(f.poop_total(T0 + 6 * HOUR), 2)
        f.advance(T0 + 9 * HOUR)
        a, b = f.cows
        self.assertEqual(f.clean(T0 + 9 * HOUR, {a.cid: 1, b.cid: 5}), 3)
        self.assertEqual((a.poop, b.poop), (1, 0))

    def test_helper_cleans_every_half_hour(self):
        f = farm()
        f.coins = 10_000
        self.assertTrue(f.hire_helper(1, T0 + 5 * HOUR))
        self.assertEqual(f.coins, 10_000 - CP.helper_price_per_day)
        self.assertEqual(f.poop_total(T0 + 5 * HOUR), 0)  # 雇用那一刻先清一次
        self.assertEqual(f.poop_total(T0 + 6 * HOUR), 0)  # 6:00 拉的，6:00 也清：先拉再清
        add_cow(f, 0, now=T0 + 6 * HOUR + 10 * MINUTE)  # 9:10 拉第一坨，9:30 清
        self.assertEqual(f.poop_total(T0 + 9 * HOUR + 29 * MINUTE), 1)
        self.assertEqual(f.poop_total(T0 + 9 * HOUR + 30 * MINUTE), 0)
        for c in range(20):
            add_cow(f, 0, now=T0 + 6 * HOUR + c * 7 * MINUTE)
        f.advance(T0 + 5 * HOUR + DAY)
        self.assertEqual(sum(c.sick_since is not None for c in f.cows), 0)
        self.assertGreater(f.poop_total(T0 + 5 * HOUR + DAY + 4 * HOUR), 0)  # 到期就不清了

    def test_helper_prepay_limit(self):
        f = farm()
        self.assertTrue(f.hire_helper(CP.helper_max_days, T0))
        self.assertFalse(f.hire_helper(1, T0 + HOUR))
        self.assertTrue(f.hire_helper(1, T0 + DAY))
        self.assertEqual(f.helper_until, T0 + 8 * DAY)
        self.assertFalse(f.hire_helper(0, T0 + 2 * DAY))

    def test_care_off_no_poop(self):
        f = farm(care=False)
        f.advance(T0 + 10 * DAY)
        self.assertEqual(f.poop_total(T0 + 10 * DAY), 0)
        self.assertTrue(all(c.thr is None and c.sick_since is None for c in f.cows))


class TestSickness(unittest.TestCase):
    """生病：每頭牛每小時的風險 = 1.5% ×（髒 − 0.5）；新手 24 小時不生病；生病的時間精確、跟結算的次數無關。"""

    def test_newbie_safe_day(self):
        f = farm()
        f.advance(T0 + CP.newbie_safe_s)
        self.assertEqual(f.hazard, 0.0)
        self.assertEqual(f.poop_total(T0 + CP.newbie_safe_s), 8)

    def test_exact_sick_time(self):
        """24 小時後髒的程度一直是 4（每頭 4 坨）：風險率 r = sick_rate_per_h × 3.5／小時，門檻 2r → 第 26 小時整生病。"""
        f = farm()
        a, b = f.cows
        r = CP.sick_rate_per_h * (4 - CP.sick_dirt_free)
        a.thr, b.thr = 2 * r, 10.0
        f.advance(T0 + 30 * HOUR)
        self.assertAlmostEqual(a.sick_since, T0 + 26 * HOUR, delta=1e-3)
        self.assertIsNone(b.sick_since)
        self.assertAlmostEqual(f.hazard, r * 6)

    def test_overnight_target(self):
        """使用者 2026-10-08「睡一覺偶爾有病牛」：10 頭成牛、睡前清乾淨、不清不雇小幫手，睡 8 小時後至少一頭病牛的機會
        約 1/4（20–30%）；一整天不管約九成（80% 以上）。每頭牛的大便時鐘相位隨機，取 200 次平均。"""

        def p_any(hours, trials=200):
            rng = random.Random(1)
            tot = 0.0
            for _ in range(trials):
                f = farm()
                t = T0 + 3 * DAY
                f.cows = []
                for i in range(10):
                    c = Cow(i + 10, genes(0), False, T0, FP, adult_at=T0)
                    c.poop_at = T0 - rng.uniform(0, CP.poop_every_s)
                    f.cows.append(c)
                f.care_t = t
                _, h, _ = f._care_sim(t + hours * HOUR)
                tot += 1 - math.exp(-10 * (h - f.hazard))
            return tot / trials

        self.assertTrue(0.20 <= p_any(8) <= 0.30)
        self.assertGreaterEqual(p_any(24), 0.80)

    def test_independent_of_settle_steps(self):
        def run(step):
            rng = random.Random(9)
            f = Farm(DEFAULT, T0, rng, care=True)
            f.coins, f.slots = 1e7, 40
            for _ in range(10):
                f.buy_shop("C", T0, rng)
            t = T0
            for stop in (T0 + DAY + 7 * HOUR, T0 + 3 * DAY):  # 中途清一次
                while t < stop:
                    t = min(stop, t + step)
                    f.advance(t)
                f.clean(t)
            return f

        fs = [run(s) for s in (HOUR, 7 * MINUTE, 31 * HOUR)]
        for f in fs[1:]:
            self.assertEqual([c.poop for c in f.cows], [c.poop for c in fs[0].cows])
            for c, c0 in zip(f.cows, fs[0].cows):
                self.assertEqual(c.sick_since is None, c0.sick_since is None)
                if c.sick_since is not None:
                    self.assertAlmostEqual(c.sick_since, c0.sick_since, delta=1e-3)
            self.assertAlmostEqual(f.hazard, fs[0].hazard, places=9)
        self.assertTrue(any(c.sick_since is not None for c in fs[0].cows))

    def test_sick_cow_stops_producing(self):
        """只留一頭乳牛、一頭耕牛（在田裡）：t0 + 3 小時兩頭各拉一坨，髒的程度 1 > 0.5，門檻很小，馬上生病。"""
        f = farm()
        t0 = T0 + 2 * DAY
        f.advance(t0)
        f.cows.clear()
        dairy = add_cow(f, 0, adult_h=5, now=t0)
        ox = add_cow(f, 1, adult_h=5, now=t0)
        f.bucket_level = 12
        f.collect(t0)
        self.assertTrue(f.assign_field(ox, 0, t0))
        for c in (dairy, ox):
            c.h0, c.thr = f.hazard, 1e-9
        end = t0 + 6 * HOUR
        before = f.bucket_preview(end)
        self.assertTrue(f.is_sick(dairy, end))
        f.advance(end)
        self.assertEqual(f.bucket, before)  # 預覽也算到還沒結算的生病
        ss = dairy.sick_since
        self.assertAlmostEqual(ss, t0 + 3 * HOUR, delta=0.01)
        self.assertAlmostEqual(f.bucket_total(), cow_milk_between(FP, dairy, t0, ss))
        self.assertAlmostEqual(f.fields[0].rice, cow_rice_rate(FP, ox, t0) * (ox.sick_since - t0) / HOUR, places=6)

    def test_sick_cow_rules_and_cure(self):
        f = farm()
        sm = StudMarket(DEFAULT)
        t = T0 + 2 * DAY
        f.advance(t)
        bull = add_cow(f, 1, bull=True, adult_h=10, now=t)
        dam = add_cow(f, 1, adult_h=10, now=t)
        healthy = add_cow(f, 1, bull=True, adult_h=10, now=t)
        bull.sick_since = dam.sick_since = t
        self.assertFalse(f.can_breed(bull, dam, t))
        self.assertFalse(sm.can_list(f, bull, t))
        self.assertFalse(f.can_work(bull, t))
        self.assertTrue(f.can_ship(bull, t))
        sick_mult = f._grade_mult(bull, t, None)[1]
        self.assertAlmostEqual(sick_mult, f._grade_mult(healthy, t, None)[1] * CP.sick_beef_mult)
        f.coins = CP.cure_price - 1
        self.assertFalse(f.cure(bull, t, random.Random(1)))
        f.coins = CP.cure_price
        self.assertTrue(f.cure(bull, t, random.Random(1)))
        self.assertEqual(f.coins, 0)
        self.assertIsNone(bull.sick_since)
        self.assertEqual(bull.h0, f.hazard)
        self.assertAlmostEqual(bull.thr, -math.log(1 - random.Random(1).random()))
        self.assertFalse(f.cure(healthy, t, random.Random(1)))

    def test_new_cows_get_thresholds_from_the_rng_after_genes(self):
        rng = random.Random(4)
        f = Farm(DEFAULT, T0, rng, care=True)
        ref = random.Random(4)
        from cowecon.farm import shop_genotype

        shop_genotype(FP, 0, ref), shop_genotype(FP, 1, ref)
        self.assertEqual([c.thr for c in f.cows], [-math.log(1 - ref.random()) for _ in range(2)])
        off = Farm(DEFAULT, T0, random.Random(4))
        self.assertEqual([c.g for c in off.cows], [c.g for c in f.cows])  # 開關不影響基因


class TestFloor(unittest.TestCase):
    """第 4 節：買地板、換地板（年紀速度）；大便、吃飽冷卻是現實時間。"""

    def test_buy_and_use(self):
        f = farm()
        f.coins = 5000
        calf = add_cow(f, 0)
        self.assertFalse(f.use_floor(1, T0))
        self.assertTrue(f.buy_floor(1, T0))
        self.assertEqual(f.coins, 5000 - CP.floor_price[1])
        self.assertFalse(f.buy_floor(1, T0))
        self.assertTrue(f.use_floor(1, T0 + HOUR))
        self.assertEqual((f.floor, f.speed), (1, 1.25))
        self.assertAlmostEqual(calf.adult_at, T0 + HOUR + 2 * HOUR / 1.25)
        self.assertEqual(calf.poop_at, T0)
        self.assertTrue(f.use_floor(0, T0 + 2 * HOUR))  # 泥土地免費換回來
        self.assertEqual(f.speed, 1.0)

    def test_listing_follows_floor(self):
        f = farm()
        sm = StudMarket(DEFAULT)
        bull = add_cow(f, 2, bull=True, adult_h=1)
        lst = sm.list_bull(f, "p1", bull, T0)
        f.buy_floor(2, T0)
        f.use_floor(2, T0 + HOUR)
        sm.follow_owner("p1", f)
        self.assertEqual((lst.speed, lst.adult_at), (1.5, bull.adult_at))


class TestFloorPhases(unittest.TestCase):
    """ceo 2026-10-08：地板分兩段。長快地板（乾草床、青草地）只乘「長到最壯之前」，軟墊地只乘「過了最壯以後」。"""

    def setUp(self):
        self.f = farm()
        self.f.floors = 0b1111
        self.p = FP.peak_age_h[0]

    def test_meadow_only_speeds_up_before_peak(self):
        f, p = self.f, self.p
        cow = add_cow(f, 0, adult_h=0)
        f.use_floor(2, T0)
        self.assertAlmostEqual(cow.adult_age_h(T0 + p / 1.5 * HOUR), p)  # 最壯只要 2/3 的時間
        self.assertAlmostEqual(cow.adult_age_h(T0 + (p / 1.5 + 10) * HOUR), p + 10)  # 之後照常
        calf = add_cow(f, 0, now=T0)
        self.assertAlmostEqual(calf.adult_at - T0, FP.tier_growth_h[0] / 1.5 * HOUR)  # 小牛長大也快

    def test_cushion_only_slows_after_peak(self):
        f, p = self.f, self.p
        cow = add_cow(f, 0, adult_h=0)
        f.use_floor(3, T0)
        self.assertAlmostEqual(cow.adult_age_h(T0 + p * HOUR), p)  # 最壯之前照常
        self.assertAlmostEqual(cow.adult_age_h(T0 + (p + 20) * HOUR), p + 15)  # 之後 ×0.75
        calf = add_cow(f, 0, now=T0)
        self.assertAlmostEqual(calf.adult_at - T0, FP.tier_growth_h[0] * HOUR)

    def test_switch_keeps_age_continuous(self):
        """換地板時年紀不跳（最壯之前、之後都一樣），換回泥土地也是。"""
        f, p = self.f, self.p
        young = add_cow(f, 0, adult_h=10)
        old = add_cow(f, 0, adult_h=p + 30)
        calf = add_cow(f, 0, now=T0)
        t = T0
        for i, floor in enumerate((2, 3, 1, 0, 3)):
            t += (7 + 11 * i) * HOUR
            before = [c.adult_age_h(t) for c in (young, old, calf)]
            f.use_floor(floor, t)
            for c, a in zip((young, old, calf), before):
                self.assertAlmostEqual(c.adult_age_h(t), a, places=9)
            self.assertAlmostEqual(calf.adult_at - calf.born_at, FP.tier_growth_h[0] * HOUR / f.speed, places=6)

    def test_production_integral_across_peak(self):
        """產奶的區間積分 = 每小時產量的數值積分，跨過最壯那一刻、換過地板都一樣。"""
        f = self.f
        cow = add_cow(f, 0, adult_h=20)
        f.use_floor(3, T0)
        t0, t1 = T0 + 30 * HOUR, T0 + 140 * HOUR  # 年紀 50 → 最壯 72 → 之後 ×0.75
        n = 20000
        dt = (t1 - t0) / n
        num = sum(cow_milk_rate(FP, cow, t0 + (k + 0.5) * dt) for k in range(n)) * dt / HOUR
        self.assertAlmostEqual(cow_milk_between(FP, cow, t0, t1), num, places=3)
        f.use_floor(2, T0 + 60 * HOUR)  # 最壯之前換成青草地
        t0 = T0 + 60 * HOUR
        num = sum(cow_milk_rate(FP, cow, t0 + (k + 0.5) * dt) for k in range(n)) * dt / HOUR
        self.assertAlmostEqual(cow_milk_between(FP, cow, t0, t0 + n * dt), num, places=3)

    def test_save_and_listing(self):
        f, p = self.f, self.p
        sm = StudMarket(DEFAULT)
        bull = add_cow(f, 2, bull=True, adult_h=p + 5)
        lst = sm.list_bull(f, "p1", bull, T0)
        f.use_floor(3, T0 + HOUR)
        sm.follow_owner("p1", f)
        self.assertTrue(sm.fee(lst, T0 + 2 * HOUR)[2])  # 過了最壯：借種費照最壯算
        d = json.loads(json.dumps(f.to_dict()))
        self.assertEqual((d["speed"] if "speed" in d else 1.0, d["late_speed"]), (1.0, 0.75))
        g = Farm.from_dict(DEFAULT, d)
        c = g.cow_by_id(bull.cid)
        self.assertEqual(c.adult_age_h(T0 + 9 * HOUR), bull.adult_age_h(T0 + 9 * HOUR))


class TestMilkLots(unittest.TestCase):
    def test_tiny_bucket_remainders_stay_in_the_bucket(self):
        """零頭不變成一批（照數量賣和照批賣才會拿到同樣的批次）：留在奶桶，攢夠了下次一起收。"""
        f = farm(care=False)
        f.advance(T0)
        f.bucket = [5.0, 1e-13, 0.0, 0.0, 2e-4]
        self.assertEqual(f.collect(T0), 5.0)
        self.assertEqual([(l.tier, l.qty) for l in f.lots], [(0, 5.0)])
        self.assertEqual(f.bucket[1:], [1e-13, 0.0, 0.0, 2e-4])


class TestCareSave(unittest.TestCase):
    def test_round_trip_and_continue(self):
        rng = random.Random(3)
        f = Farm(DEFAULT, T0, rng, care=True)
        f.coins, f.slots = 1e7, 40
        for _ in range(6):
            f.buy_shop("B", T0, rng)
        f.buy_feed(SOY, 20, T0)
        f.feed(f.cows[3], SOY, T0)
        f.buy_floor(3, T0)
        f.use_floor(3, T0 + HOUR)
        f.hire_helper(1, T0 + 2 * HOUR)
        t = T0 + 2 * DAY
        f.advance(t)
        d = json.loads(json.dumps(f.to_dict()))
        g = Farm.from_dict(DEFAULT, d)
        self.assertEqual(g.to_dict(), d)
        f.advance(t + 3 * DAY)
        g.advance(t + 3 * DAY)
        self.assertEqual(g.to_dict(), f.to_dict())
        self.assertTrue(any(c.sick_since is not None for c in g.cows))

    def test_old_save_loads_with_care_off(self):
        f = Farm(DEFAULT, T0, random.Random(3))
        d = json.loads(json.dumps(f.to_dict()))
        for k in ("care", "care_t", "hazard", "feeds", "floor", "floors", "helper_from", "helper_until"):
            del d[k]
        d["bucket"] = d["bucket"][:4]
        for c in d["cows"]:
            for k in ("vt", "grown", "fed", "bonus", "fed_until", "poop", "poop_at", "h0", "thr", "sick_since"):
                del c[k]
        g = Farm.from_dict(DEFAULT, d)
        self.assertFalse(g.care)
        self.assertEqual(len(g.bucket), 5)
        self.assertEqual(g.feeds, [0] * 6)
        g.advance(T0 + 5 * DAY)
        self.assertEqual(g.poop_total(T0 + 5 * DAY), 0)
        ex = Exchange(DEFAULT, 1, T0)
        self.assertGreater(g.sell_all_milk(ex.markets["milk"], T0 + 5 * DAY), 0)


if __name__ == "__main__":
    unittest.main()
