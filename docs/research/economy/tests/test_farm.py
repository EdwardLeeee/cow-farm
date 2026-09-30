"""牧場規則測試：新鮮度單調、產奶積分可分段、奶桶上限、配種機率、成本遞增、新手開局。"""

import random
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from cowecon import DEFAULT, HOUR, MINUTE, Exchange  # noqa: E402
from cowecon.farm import (  # noqa: E402
    Cow,
    Farm,
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
        """商店小牛一長大就出貨，在軟邊界上限價格（1.7 倍）下期望值也要低於小牛價格。"""
        q = FP.shop_recessive_freq
        p_aa = q * q
        # 3 個稀有基因座各自獨立：稀有度 k 的機率
        from math import comb

        exp_mult = sum(comb(3, k) * p_aa ** k * (1 - p_aa) ** (3 - k) * FP.tier_mult[k] for k in range(4))
        for t in range(3):
            v = FP.adult_weight_kg[t] * FP.bull_weight_mult * DEFAULT.beef.base_price * DEFAULT.beef.soft_hi * exp_mult
            self.assertLess(v, FP.calf_price, f"type={t}")


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
