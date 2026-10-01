"""v0.2 規則（企劃書 4.0、決定 D17）：只有母乳牛產奶、耕田與稻米、商店等級、出貨評級、配種一次、借種、存檔。"""

import json
import random
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import sim  # noqa: E402,F401  （把 backend/ 加進 sys.path）

from cowecon import DEFAULT, HOUR, MINUTE, Exchange, Farm, StudMarket  # noqa: E402
from cowecon.farm import (  # noqa: E402
    Cow, beef_grade_probs, beef_weight, cow_milk_between, cow_rice_between, draw_beef_grade, field_cap_for,
    make_genotype, rice_factor, shop_draw, shop_grade_distribution, shop_grade_tier_probs, stud_fee, tier_of,
)

T0 = 1791129600.0
FP = DEFAULT.farm


def cow(t, bull, tier=0, cid=1, adult_h=0.0):
    alleles = [(1, 1) if i < tier else (0, 0) for i in range(3)]
    return Cow(cid, make_genotype(t, alleles), bull, T0 - 10 * HOUR, FP, adult_at=T0 - adult_h * HOUR)


class TestTypes(unittest.TestCase):
    def test_only_adult_dairy_females_milk(self):
        for t in range(3):
            for bull in (False, True):
                q = cow_milk_between(FP, cow(t, bull), T0, T0 + 10 * HOUR)
                if t == 0 and not bull:
                    self.assertGreater(q, 0)
                else:
                    self.assertEqual(q, 0.0, f"type={t} bull={bull}")

    def test_beef_weight_order(self):
        w = [beef_weight(FP, cow(t, False, adult_h=72), T0) for t in range(3)]
        self.assertLess(w[0], w[1])
        self.assertLess(w[1], w[2])

    def test_only_oxen_farm(self):
        for t in range(3):
            q = cow_rice_between(FP, cow(t, False), T0, T0 + 5 * HOUR)
            self.assertEqual(q > 0, t == 1)


class TestShopGrades(unittest.TestCase):
    def test_exact_distribution(self):
        exp_tier = []
        for gr in FP.shop_grade_names:
            dist = shop_grade_distribution(FP, gr)
            self.assertAlmostEqual(sum(dist.values()), 1.0, places=12)
            tp = shop_grade_tier_probs(FP, gr)
            exp_tier.append(sum(i * p for i, p in enumerate(tp)))
        self.assertEqual(exp_tier, sorted(exp_tier, reverse=True))  # A > B > C

    def test_sampling_matches_exact(self):
        rng = random.Random(3)
        for gr in FP.shop_grade_names:
            n = 30000
            counts = {}
            for _ in range(n):
                g, bull = shop_draw(FP, gr, rng)
                key = (g & 3 and ((g & 1) + ((g >> 1) & 1)), bull, tier_of(g))
                counts[key] = counts.get(key, 0) + 1
            exact = {}
            for (t, bull, mask), p in shop_grade_distribution(FP, gr).items():
                key = (t, bull, bin(mask).count("1"))
                exact[key] = exact.get(key, 0.0) + p
            for key, p in exact.items():
                self.assertAlmostEqual(counts.get(key, 0) / n, p, delta=0.012, msg=f"{gr} {key}")

    def test_buy_shop(self):
        f = Farm(DEFAULT, T0, random.Random(1))
        f.coins = 10000
        f.slots = 5
        c = f.buy_shop("A", T0 + 60, random.Random(2))
        self.assertIsNotNone(c)
        self.assertEqual(c.origin, "A")
        self.assertEqual(f.coins, 10000 - FP.shop_grade_price[0])


class TestBeefGrades(unittest.TestCase):
    def test_probs_sum_and_monotone(self):
        for t in range(3):
            prev = -1.0
            for tier in range(4):
                c = cow(t, False, tier, adult_h=80)
                pa, pb, pc = beef_grade_probs(FP, c, T0)
                self.assertAlmostEqual(pa + pb + pc, 1.0)
                self.assertTrue(min(pa, pb, pc) >= 0)
                self.assertGreaterEqual(pa, prev)
                prev = pa
            # 體重還在長：越接近最佳體重 A 越多；過了最佳期：越老 A 越少
            c = cow(t, False)
            seq = [beef_grade_probs(FP, c, T0 + h * HOUR)[0] for h in (1, 20, 50, 72, 96)]
            self.assertEqual(seq, sorted(seq))
            late = [beef_grade_probs(FP, c, T0 + h * HOUR)[0] for h in (96, 120, 150, 200)]
            self.assertEqual(late, sorted(late, reverse=True))

    def test_sampling(self):
        rng = random.Random(9)
        c = cow(2, True, 1, adult_h=60)
        probs = beef_grade_probs(FP, c, T0)
        n = 40000
        cnt = [0, 0, 0]
        for _ in range(n):
            cnt[draw_beef_grade(FP, c, T0, rng)] += 1
        for a, b in zip(probs, cnt):
            self.assertAlmostEqual(a, b / n, delta=0.01)


class TestBreeding(unittest.TestCase):
    def setUp(self):
        self.f = Farm(DEFAULT, T0, random.Random(1))
        self.f.slots = 6
        self.t = T0 + 30 * MINUTE

    def test_once_and_free(self):
        f, t = self.f, self.t
        bull = [c for c in f.cows if c.bull][0]
        dam = [c for c in f.cows if not c.bull][0]
        coins = f.coins
        self.assertIsNotNone(f.breed(bull, dam, t, random.Random(2)))
        self.assertEqual(f.coins, coins)  # 自己配免費
        self.assertTrue(bull.bred and dam.bred)
        other = Cow(99, dam.g, False, T0, FP, adult_at=T0)
        f.cows.append(other)
        self.assertIsNone(f.breed(bull, other, t, random.Random(2)))  # 公牛配過了

    def test_field_blocks_breeding_and_shipping(self):
        f, t = self.f, self.t
        bull = [c for c in f.cows if c.bull][0]
        dam = [c for c in f.cows if not c.bull][0]
        self.assertTrue(f.assign_field(bull, 0, t))
        self.assertFalse(f.can_breed(bull, dam, t))
        self.assertIsNone(f.ship(bull, Exchange(DEFAULT, 1, T0).markets["beef"], t + 80 * HOUR, random.Random(1)))
        self.assertTrue(f.recall(bull, t + HOUR))
        self.assertTrue(f.can_breed(bull, dam, t + HOUR))


class TestFields(unittest.TestCase):
    def test_accrual_additive_and_capped(self):
        a = Farm(DEFAULT, T0, random.Random(5))
        b = Farm(DEFAULT, T0, random.Random(5))
        t = T0 + 30 * MINUTE
        for f in (a, b):
            ox = [c for c in f.cows if c.bull][0]
            f.assign_field(ox, 0, t)
        a.advance(t + 3 * HOUR)
        for k in range(1, 181):
            b.advance(t + k * MINUTE)
        self.assertAlmostEqual(a.fields[0].rice, b.fields[0].rice, places=6)
        a.advance(t + 100 * HOUR)
        ox = [c for c in a.cows if c.bull][0]
        self.assertAlmostEqual(a.fields[0].rice, field_cap_for(FP, ox))

    def test_harvest_and_rice_storage(self):
        f = Farm(DEFAULT, T0, random.Random(5))
        t = T0 + 30 * MINUTE
        ox = [c for c in f.cows if c.bull][0]
        f.assign_field(ox, 0, t)
        got = f.harvest(t + 2 * HOUR)
        self.assertGreater(got, 0)
        self.assertAlmostEqual(f.rice_stock(), got)
        vals = [rice_factor(FP, h) for h in range(0, 400, 5)]
        self.assertEqual(vals, sorted(vals, reverse=True))
        self.assertEqual(rice_factor(FP, 1000), FP.rice_floor)
        ex = Exchange(DEFAULT, 1, T0)
        res = f.sell_rice(ex.markets["rice"], got, t + 2 * HOUR)
        self.assertAlmostEqual(res.units, got)
        self.assertEqual(f.rice_stock(), 0)


class TestStudMarket(unittest.TestCase):
    def setUp(self):
        self.owner = Farm(DEFAULT, T0, random.Random(1))
        self.borrower = Farm(DEFAULT, T0, random.Random(2))
        self.borrower.slots = 5
        self.borrower.coins = 5000
        self.sm = StudMarket(DEFAULT)
        self.t = T0 + 30 * MINUTE

    def test_lend_and_borrow(self):
        o, b, sm, t = self.owner, self.borrower, self.sm, self.t
        bull = [c for c in o.cows if c.bull][0]
        dam = [c for c in b.cows if not c.bull][0]
        lst = sm.list_bull(o, "owner", bull, t)  # D26：不選價位，借種費依體重算
        self.assertIsNotNone(lst)
        self.assertFalse(o.can_ship(bull, t))  # 上架中不能出貨
        self.assertIsNone(sm.borrow(lst.lid, b, "owner", dam, t, random.Random(3), o))  # 不能借自己的
        oc, bc = o.coins, b.coins
        price = sm.price(lst, t)
        self.assertEqual(price, stud_fee(FP, bull.ctype, bull.tier, bull.adult_at, t)[0])
        calf = sm.borrow(lst.lid, b, "borrower", dam, t, random.Random(3), o)
        self.assertIsNotNone(calf)
        self.assertIn(calf, b.cows)
        self.assertEqual(o.coins, oc + price)
        self.assertEqual(b.coins, bc - price)
        self.assertTrue(bull.bred and dam.bred)
        self.assertIsNone(bull.listed)
        self.assertNotIn(lst.lid, sm.listings)
        self.assertIsNone(sm.list_bull(o, "owner", bull, t))  # 用過一次，不能再上架

    def test_npc_listing_is_a_sink(self):
        b, sm, t = self.borrower, self.sm, self.t
        sm.npc_refill(t, random.Random(4))
        self.assertEqual(len(sm.listings), FP.npc_stud_listings)
        lid = next(iter(sm.listings))
        dam = [c for c in b.cows if not c.bull][0]
        bc = b.coins
        lst = sm.listings[lid]
        price = sm.price(lst, t)  # 公營種牛站：用那種用途公牛的最佳體重算
        self.assertEqual(price, stud_fee(FP, lst.ctype, lst.tier, None, t)[0])
        self.assertIsNotNone(sm.borrow(lid, b, "borrower", dam, t, random.Random(5)))
        self.assertEqual(b.coins, bc - price)
        sm.npc_refill(t, random.Random(4))
        self.assertEqual(sum(1 for l in sm.listings.values() if l.owner is None), FP.npc_stud_listings)

    def test_unlist(self):
        o, sm, t = self.owner, self.sm, self.t
        bull = [c for c in o.cows if c.bull][0]
        lst = sm.list_bull(o, "owner", bull, t)
        self.assertTrue(sm.unlist(lst.lid, o))
        self.assertIsNone(bull.listed)
        self.assertTrue(o.can_ship(bull, t))


class TestPersistence(unittest.TestCase):
    def test_roundtrip_new_fields(self):
        ex = Exchange(DEFAULT, 7, T0)
        f = Farm(DEFAULT, T0, random.Random(1))
        f.slots = 6
        f.coins = 20000
        rng = random.Random(2)
        t = T0 + 30 * MINUTE
        bull = [c for c in f.cows if c.bull][0]
        dam = [c for c in f.cows if not c.bull][0]
        f.breed(bull, dam, t, rng)
        f.assign_field(bull, 0, t)
        f.expand_field(t)
        f.buy_shop("B", t, rng)
        f.harvest(t + 3 * HOUR)
        sm = StudMarket(DEFAULT)
        sm.npc_refill(t, rng)
        blob = json.loads(json.dumps({"farm": f.to_dict(), "sm": sm.to_dict(), "ex": ex.to_dict()}))
        g = Farm.from_dict(DEFAULT, blob["farm"])
        self.assertEqual(g.to_dict(), f.to_dict())
        self.assertEqual(StudMarket.from_dict(DEFAULT, blob["sm"]).to_dict(), sm.to_dict())
        self.assertEqual(Exchange.from_dict(DEFAULT, blob["ex"]).to_dict(), ex.to_dict())
        # 回復後繼續跑，結果一樣
        t2 = t + 10 * HOUR
        f.advance(t2)
        g.advance(t2)
        self.assertEqual(g.to_dict(), f.to_dict())

    def test_loads_v01_save(self):
        f = Farm(DEFAULT, T0, random.Random(1))
        d = f.to_dict()
        for k in ("fields", "rice_lots"):
            d.pop(k)
        d["impact"].pop("rice")
        for c in d["cows"]:
            for k in ("bred", "field", "listed", "origin"):
                c.pop(k)
        g = Farm.from_dict(DEFAULT, d)
        self.assertEqual(len(g.fields), FP.field_start)
        self.assertIn("rice", g.impact)
        self.assertFalse(any(c.bred for c in g.cows))


if __name__ == "__main__":
    unittest.main()
