"""牧場規則測試：新鮮度單調、產奶積分可分段、奶桶上限、配種機率、成本遞增、新手開局。"""

import random
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import sim  # noqa: E402,F401  （把 backend/ 加進 sys.path；cowecon 在 backend/cowecon/）

from cowecon import DEFAULT, HOUR, MINUTE, Exchange  # noqa: E402
from cowecon.farm import (  # noqa: E402
    Cow,
    Farm,
    StudMarket,
    cow_milk_rate,
    beef_quality,
    beef_weight,
    breed_genotype,
    bucket_cost,
    cow_milk_between,
    freshness,
    make_genotype,
    offspring_distribution,
    pen_cost,
    tier_distribution,
    tier_of,
)

T0 = 1791129600.0
FP = DEFAULT.farm


class TestFreshness(unittest.TestCase):
    def test_monotone_in_age_and_level(self):
        for level in range(len(FP.fresh_costs) + 1):
            prev = 2.0
            for i in range(0, 200 * 4):
                f = freshness(FP, i / 4.0, level)
                self.assertLessEqual(f, prev + 1e-12)
                self.assertGreaterEqual(f, 0.0)
                prev = f
        for age in [0, 3, 6, 7, 12, 24, 48, 60, 90, 120]:
            vals = [freshness(FP, age, L) for L in range(len(FP.fresh_costs) + 1)]
            self.assertEqual(vals, sorted(vals), f"age={age}")

    def test_key_points(self):
        self.assertEqual(freshness(FP, 6.0, 0), 1.0)
        self.assertAlmostEqual(freshness(FP, 48.0, 0), 0.5)
        self.assertAlmostEqual(freshness(FP, 90.0, 0), 0.0)
        self.assertLess(freshness(FP, 6.5, 0), 1.0)


class TestMilk(unittest.TestCase):
    def test_integral_is_additive(self):
        rng = random.Random(1)
        for _ in range(200):
            cow = Cow(1, make_genotype(rng.randrange(3), [(0, 0)] * 3), False, T0, FP)
            t0 = T0 + rng.uniform(-5, 200) * HOUR
            t1 = t0 + rng.uniform(0, 100) * HOUR
            t2 = t1 + rng.uniform(0, 100) * HOUR
            whole = cow_milk_between(FP, cow, t0, t2)
            parts = cow_milk_between(FP, cow, t0, t1) + cow_milk_between(FP, cow, t1, t2)
            self.assertAlmostEqual(whole, parts, places=6)

    def test_numeric_integral(self):
        cow = Cow(1, make_genotype(0, [(0, 0)] * 3), False, T0, FP)
        t0, t1 = T0 + 40 * HOUR, T0 + 200 * HOUR
        n = 20000
        h = (t1 - t0) / n
        from cowecon.farm import cow_milk_rate

        num = sum(cow_milk_rate(FP, cow, t0 + (i + 0.5) * h) for i in range(n)) * h / HOUR
        self.assertAlmostEqual(cow_milk_between(FP, cow, t0, t1), num, delta=num * 1e-4)

    def test_bucket_stops_when_full_and_offline_is_exact(self):
        f1 = Farm(DEFAULT, T0, random.Random(3))
        f2 = Farm(DEFAULT, T0, random.Random(3))
        f1.advance(T0 + 10 * HOUR)
        for k in range(1, 601):
            f2.advance(T0 + k * MINUTE)
        self.assertAlmostEqual(f1.bucket_total(), f2.bucket_total(), places=6)
        self.assertAlmostEqual(f1.bucket_total(), f1.bucket_capacity(), places=6)

    def test_old_cows_produce_less(self):
        cow = Cow(1, make_genotype(0, [(0, 0)] * 3), False, T0, FP)
        young = cow_milk_between(FP, cow, cow.adult_at, cow.adult_at + HOUR)
        old = cow_milk_between(FP, cow, cow.adult_at + 200 * HOUR, cow.adult_at + 201 * HOUR)
        self.assertAlmostEqual(young, FP.milk_per_h[0])
        self.assertAlmostEqual(old, FP.milk_per_h[0] * FP.milk_old_frac)


class TestBeef(unittest.TestCase):
    def test_weight_up_then_quality_down(self):
        cow = Cow(1, make_genotype(2, [(0, 0)] * 3), False, T0, FP)
        prev_w, prev_q = 0.0, 1.0
        for h in range(0, 300):
            t = cow.adult_at + h * HOUR
            w, q = beef_weight(FP, cow, t), beef_quality(FP, cow, t)
            self.assertGreaterEqual(w, prev_w - 1e-9)
            self.assertLessEqual(q, prev_q + 1e-12)
            prev_w, prev_q = w, q
        self.assertAlmostEqual(beef_weight(FP, cow, cow.adult_at + FP.peak_age_h[2] * HOUR), FP.peak_weight_kg[2])

    def test_no_calf_arbitrage(self):
        """商店 C 級小牛一長大就出貨，在軟邊界上限價格（1.7 倍）、評到 A 級，期望值也要低於 C 級價格。"""
        from cowecon.farm import shop_grade_distribution

        best = max(FP.beef_grade_mult)
        v = 0.0
        for (t, bull, mask), p in shop_grade_distribution(FP, "C").items():
            w = FP.adult_weight_kg[t] * (FP.bull_weight_mult if bull else 1.0)
            v += p * w * DEFAULT.beef.base_price * DEFAULT.beef.soft_hi * best * FP.tier_mult[bin(mask).count("1")]
        self.assertLess(v, FP.shop_grade_price[FP.shop_grade_names.index("C")])


class TestAgeSpeed(unittest.TestCase):
    """年紀速度（v0.3 地板的基礎；A0 先做重構，速度 1 的數字逐位不變）：Farm.set_speed 換速度時年紀連續，
    之後照新速度走；每個現實小時的產量照年紀曲線（全速期變短或變長）。"""

    def setUp(self):
        self.t = T0 + 10 * HOUR
        self.f = Farm(DEFAULT, T0, random.Random(3))
        self.dairy = Cow(50, make_genotype(0, [(0, 0)] * 3), False, T0, FP, adult_at=self.t - 10 * HOUR)
        self.calf = Cow(51, make_genotype(2, [(0, 0)] * 3), True, self.t, FP)  # 剛出生
        self.f.cows += [self.dairy, self.calf]
        self.f.slots = 10

    def test_speed_one_is_bit_identical(self):
        """速度 1：所有算式乘除 1.0，結果跟以前一模一樣（研究模擬的逐數字比對也靠這個）。"""
        c = Cow(1, make_genotype(0, [(0, 0)] * 3), False, T0, FP)
        self.assertEqual(c.adult_at, T0 + FP.tier_growth_h[0] * HOUR)
        t = c.adult_at + 7.3 * HOUR
        self.assertEqual(c.adult_age_h(t), (t - c.adult_at) / HOUR)
        self.assertNotIn("speed", self.f.to_dict())  # 速度 1 不寫進存檔，存檔跟以前一樣

    def test_switch_keeps_age_continuous(self):
        f, t = self.f, self.t
        age0, left0 = self.dairy.adult_age_h(t), self.calf.adult_at - t
        f.set_speed(1.5, t)
        self.assertAlmostEqual(self.dairy.adult_age_h(t), age0)
        self.assertAlmostEqual(self.calf.adult_at - t, left0 / 1.5)  # 小牛快 1.5 倍長大
        t2 = t + 4 * HOUR
        self.assertAlmostEqual(self.dairy.adult_age_h(t2), age0 + 4 * 1.5)
        f.set_speed(0.75, t2)
        t3 = t2 + 2 * HOUR
        self.assertAlmostEqual(self.dairy.adult_age_h(t3), age0 + 4 * 1.5 + 2 * 0.75)
        back = Farm.from_dict(DEFAULT, f.to_dict())  # 存檔：牧場的速度，牛跟著
        self.assertEqual(back.speed, 0.75)
        self.assertTrue(all(c.speed == 0.75 for c in back.cows))
        self.assertAlmostEqual(back.cow_by_id(50).adult_age_h(t3), self.dairy.adult_age_h(t3))

    def test_production_follows_age_curve(self):
        """每個現實小時的產量照年紀曲線：區間產量 = 每小時產量的積分（速度 1.5 也成立）；
        壯年的每小時產量不變，只是壯年期變短。"""
        f, t, c = self.f, self.t, self.dairy
        rate_prime = cow_milk_rate(FP, c, t)
        f.set_speed(1.5, t)
        self.assertAlmostEqual(cow_milk_rate(FP, c, t), rate_prime)
        t1 = t + 120 * HOUR
        n = 12000
        num = sum(cow_milk_rate(FP, c, t + (i + 0.5) * (t1 - t) / n) for i in range(n)) * (t1 - t) / n / HOUR
        self.assertAlmostEqual(cow_milk_between(FP, c, t, t1), num, delta=num * 1e-4)
        prime_left = FP.milk_prime_h - c.adult_age_h(t)  # 年紀小時
        self.assertAlmostEqual(cow_milk_rate(FP, c, t + prime_left / 1.5 * HOUR - 60), rate_prime)

    def test_stud_listing_follows_owner(self):
        """上架的公牛：主人換速度以後，借種費照新的長大時間和速度算（跟出貨體重同一個算法）。"""
        sm = StudMarket(DEFAULT)
        bull = Cow(60, make_genotype(2, [(0, 0)] * 3), True, T0, FP, adult_at=self.t)
        self.f.cows.append(bull)
        lst = sm.list_bull(self.f, "owner", bull, self.t + 10 * HOUR)
        self.f.set_speed(1.5, self.t + 20 * HOUR)
        sm.follow_owner("owner", self.f)
        t = self.t + 30 * HOUR
        self.assertAlmostEqual(sm.fee(lst, t)[1], beef_weight(FP, bull, t))
        self.assertAlmostEqual(bull.adult_age_h(t), 20 + 10 * 1.5)


class TestBreeding(unittest.TestCase):
    def test_distribution_sums_to_one_and_matches_sampling(self):
        rng = random.Random(5)
        sire = make_genotype(1, [(1, 0), (1, 1), (0, 0)])
        dam = make_genotype(0, [(1, 1), (1, 0), (1, 0)])
        dist = offspring_distribution(sire, dam)
        self.assertAlmostEqual(sum(dist.values()), 1.0)
        n = 40000
        counts = {}
        for _ in range(n):
            g = breed_genotype(sire, dam, rng)
            key = (g & 3 and ((g & 1) + ((g >> 1) & 1)), tier_of(g))
            counts[key] = counts.get(key, 0) + 1
        tiers = tier_distribution(sire, dam)
        emp = [0.0] * 4
        for (_t, tier), c in counts.items():
            emp[tier] += c / n
        for a, b in zip(tiers, emp):
            self.assertAlmostEqual(a, b, delta=0.01)

    def test_true_breeding_rare(self):
        g = make_genotype(0, [(1, 1)] * 3)
        self.assertEqual(tier_distribution(g, g), [0.0, 0.0, 0.0, 1.0])


class TestCosts(unittest.TestCase):
    def test_costs_increase(self):
        self.assertEqual([pen_cost(FP, i) for i in range(10)], sorted(pen_cost(FP, i) for i in range(10)))
        self.assertEqual([bucket_cost(FP, i) for i in range(10)], sorted(bucket_cost(FP, i) for i in range(10)))


class TestOnboarding(unittest.TestCase):
    def test_starter_farm(self):
        ex = Exchange(DEFAULT, 1, T0)
        f = Farm(DEFAULT, T0, random.Random(1))
        self.assertEqual(len(f.cows), 2)
        self.assertGreater(f.bucket_total(), 0)  # 打開就有牛奶可以賣
        earned = f.sell_all_milk(ex.markets["milk"], T0 + 30)
        self.assertGreater(earned, 0)
        calf = [c for c in f.cows if c.bull][0]
        self.assertAlmostEqual(calf.adult_at - T0, DEFAULT.onboarding.starter_calf_remaining_s)


if __name__ == "__main__":
    unittest.main()
