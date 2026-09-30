"""行情引擎測試：價格邊界、滑價隨單量單調、每位玩家上限、tick 大小不影響結果、結果固定。

執行：cd docs/research/economy && python3 -m unittest -v
"""

import math
import random
import statistics
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import sim  # noqa: E402,F401  （把 backend/ 加進 sys.path；cowecon 在 backend/cowecon/）

from cowecon import DEFAULT, HOUR, MINUTE, Exchange, ImpactState, with_overrides  # noqa: E402
from cowecon.market import Market, _ramp_integral  # noqa: E402

T0 = 1791129600.0  # 2026-10-05 00:00 台灣時間


def run_market(dt, days, seed, seller_rate_per_h=0.0, seller_size=0.0, online=5.0, params=DEFAULT, events=True):
    """只跑市場：一個連續時間的 Poisson 賣家（與 tick 無關），回傳每 5 分鐘取樣的 log(價格/基本價)。"""
    ex = Exchange(params, seed, T0, events_enabled=events)
    rng = random.Random(f"seller:{seed}")
    next_sale = T0 + (rng.expovariate(seller_rate_per_h / HOUR) if seller_rate_per_h > 0 else 1e18)
    imps = [ImpactState() for _ in range(50)]
    out = []
    t = T0
    n = int(days * 86400 / dt)
    sample_every = int(300 // dt)
    for i in range(n):
        t_end = t + dt
        while next_sale < t_end:
            imp = imps[rng.randrange(len(imps))]
            ex.markets["milk"].execute_sale(imp, [(seller_size, 1.0)], next_sale)
            next_sale += rng.expovariate(seller_rate_per_h / HOUR)
        ex.step(t_end, online)
        t = t_end
        if (i + 1) % sample_every == 0:
            out.append(math.log(ex.markets["milk"].price / params.milk.base_price))
    return out, ex


class TestPriceBounds(unittest.TestCase):
    def test_hard_bounds_under_extreme_selling_and_events(self):
        p = DEFAULT
        cp = p.milk
        ex = Exchange(p, 7, T0)
        # 疊加多個 −40% 與 +40% 事件
        for k in range(4):
            ex.inject_event(("milk",), 0.6, T0 + (2 + k) * HOUR, 6 * HOUR)
            ex.inject_event(("milk",), 1.4, T0 + (30 + k) * HOUR, 6 * HOUR)
        m = ex.markets["milk"]
        imps = [ImpactState() for _ in range(200)]
        lo, hi = 1e9, 0.0
        t = T0
        for i in range(3 * 1440):
            t += 60
            if i < 1440:  # 第一天：每分鐘 200 位玩家倒大量
                for imp in imps:
                    m.execute_sale(imp, [(1e6, 1.0)], t - 1)
            ex.step(t, 3.0)
            r = m.price / cp.base_price
            lo, hi = min(lo, r), max(hi, r)
        self.assertGreaterEqual(lo, cp.hard_lo - 1e-12)
        self.assertLessEqual(hi, cp.hard_hi + 1e-12)
        self.assertLess(lo, 0.8)  # 真的有被壓下去

    def test_soft_band_pulls_back(self):
        """把賣壓 y 直接設到 −1（價格 ≈ 0.37 倍），軟邊界要在 2 小時內拉回 0.6 附近。"""
        p = DEFAULT
        ex = Exchange(p, 3, T0, events_enabled=False)
        m = ex.markets["milk"]
        m.y = -1.0
        t = T0
        for _ in range(120):
            t += 60
            ex.step(t, 5.0)
        self.assertGreater(m.price / p.milk.base_price, 0.55)


class TestSlippage(unittest.TestCase):
    def setUp(self):
        self.ex = Exchange(DEFAULT, 1, T0, events_enabled=False)
        self.m = self.ex.markets["milk"]
        t = T0
        for _ in range(60):
            t += 60
            self.ex.step(t, 5.0)
        self.t = t

    def test_average_price_non_increasing_total_non_decreasing(self):
        m, t = self.m, self.t
        prev_avg, prev_total = float("inf"), -1.0
        depth = m.depth()
        for q in [1, 5, 10, 50, 100, 500, 1000, 5000, 20000, 1e5, 1e6]:
            res = m.quote(ImpactState(), [(q, 1.0)], t)
            avg = res.proceeds / q
            self.assertLessEqual(avg, prev_avg + 1e-9, f"q={q}")
            self.assertGreaterEqual(res.proceeds, prev_total - 1e-9, f"q={q}")
            # 下限：邊際價格不低於 (1 − κ·qmax) × 市價
            self.assertGreaterEqual(avg, m.price * (1 - DEFAULT.milk.slip_kappa * DEFAULT.milk.slip_qmax) - 1e-9)
            prev_avg, prev_total = avg, res.proceeds
        self.assertGreater(depth, 0)

    def test_splitting_in_same_instant_does_not_help(self):
        m, t = self.m, self.t
        q = 3 * m.depth()
        whole = m.quote(ImpactState(), [(q, 1.0)], t).proceeds
        imp = ImpactState()
        parts = 0.0
        for _ in range(30):
            parts += m.execute_sale(imp, [(q / 30, 1.0)], t).proceeds
        self.assertAlmostEqual(whole, parts, delta=whole * 1e-9)

    def test_spreading_over_time_helps(self):
        m, t = self.m, self.t
        q = 3 * m.depth()
        whole = m.quote(ImpactState(), [(q, 1.0)], t).proceeds
        imp = ImpactState()
        spread = 0.0
        for k in range(10):
            spread += m.quote(imp, [(q / 10, 1.0)], t + k * 3 * HOUR).proceeds
            m.execute_sale(imp, [(q / 10, 1.0)], t + k * 3 * HOUR)  # 不 step 市場，只比滑價
        self.assertGreater(spread, whole)

    def test_ramp_integral_matches_numeric(self):
        for a, b, d, qm in [(0, 5, 10, 1), (3, 30, 10, 1), (12, 40, 10, 1), (0, 100, 7, 0.5)]:
            n = 20000
            h = (b - a) / n
            num = sum(min((a + (i + 0.5) * h) / d, qm) for i in range(n)) * h
            self.assertAlmostEqual(_ramp_integral(a, b, d, qm), num, places=4)


class TestPlayerCap(unittest.TestCase):
    def test_single_dump_counted_at_most_c_D_W(self):
        ex = Exchange(DEFAULT, 5, T0, events_enabled=False)
        m = ex.markets["milk"]
        t = T0
        for _ in range(120):
            t += 60
            ex.step(t, 20.0)
        cp = DEFAULT.milk
        dem = m.demand_rate()
        res = m.execute_sale(ImpactState(), [(1e9, 1.0)], t)
        self.assertAlmostEqual(res.counted, cp.player_cap_frac * dem * cp.player_cap_window_s / HOUR, delta=1e-6)
        # 額度用完後，同一位玩家立刻再賣，不再計入
        imp = ImpactState()
        m.execute_sale(imp, [(1e9, 1.0)], t)
        again = m.execute_sale(imp, [(1e9, 1.0)], t)
        self.assertAlmostEqual(again.counted, 0.0, delta=1e-9)

    def test_single_player_max_impact_bound(self):
        """背景賣量 = 需求（e≈0）時，一位玩家一次倒超大量，價格最多被壓低 1 − exp(−λ↓·c·W)。

        c = player_cap_frac、W = player_cap_window_s（小時）。預設值：1 − exp(−0.12×0.25×0.25) ≈ 0.75%。
        """
        p = with_overrides(DEFAULT, {"milk.noise_sd": 1e-9})
        mk = []
        for _ in range(2):
            m = Market(p.milk, T0, random.Random(1))
            m.ref_flow, m.ref_online, m.online = 5000.0, 10.0, 10.0
            mk.append(m)
        base, dump = mk
        t = T0
        worst = 0.0
        dt = 60.0
        for i in range(12 * 60):
            t += dt
            for m in mk:  # 背景賣量剛好等於需求
                q = m.demand_rate() * dt / HOUR
                m.pending_counted += q
                m.pending_actual += q
            if i == 120:
                dump.execute_sale(ImpactState(), [(1e9, 1.0)], t - 1)  # 長期平均只會加上平常單量的 5 倍
            for m in mk:
                m.step(t, 10.0, 0.0)
            worst = max(worst, 1 - dump.price / base.price)
        cp = p.milk
        bound = 1 - math.exp(-cp.pressure_down_per_h * cp.player_cap_frac * cp.player_cap_window_s / HOUR)
        self.assertGreater(worst, 0.5 * bound)
        self.assertLessEqual(worst, bound + 1e-9)
        self.assertLess(worst, 0.01)


class TestDemand(unittest.TestCase):
    def test_surge_cap(self):
        """線上人數突然變 20 倍，需求最多放大到長期平均線上 × online_surge_cap。"""
        m = Market(DEFAULT.milk, T0, random.Random(1))
        m.ref_flow, m.ref_online, m.online = 1000.0, 10.0, 10.0
        base = m.demand_rate()
        m.online = 200.0
        cap = DEFAULT.milk.online_surge_cap
        npc = DEFAULT.milk.npc_online_equiv
        self.assertAlmostEqual(m.demand_rate(), base * (cap * 10 + npc) / (10 + npc))

    def test_whale_does_not_inflate_reference_flow(self):
        a = Market(DEFAULT.milk, T0, random.Random(1))
        b = Market(DEFAULT.milk, T0, random.Random(1))
        t = T0
        for i in range(24 * 60):
            t += 60
            for m in (a, b):
                m.execute_sale(ImpactState(), [(20.0, 1.0)], t - 30)
            if i == 600:
                b.execute_sale(ImpactState(), [(1e7, 1.0)], t - 10)
            a.step(t, 5.0, 0.0)
            b.step(t, 5.0, 0.0)
        self.assertLess(b.ref_flow / a.ref_flow, 1.05)


class TestLongRunLevel(unittest.TestCase):
    def test_persistent_oversupply_is_absorbed(self):
        """天天都多賣 30%（例如每天早上都有人倒整晚的奶）：幾天後價格回到目標價附近，只有突發的賣壓會壓價。"""
        p = with_overrides(DEFAULT, {"milk.noise_sd": 1e-9})
        m = Market(p.milk, T0, random.Random(1))
        m.ref_flow, m.ref_online, m.online = 1000.0, 10.0, 10.0
        t = T0
        dt = 60.0
        for _ in range(7 * 1440):
            dem = m.demand_rate()
            m.pending_counted += 1.3 * dem * dt / HOUR
            m.pending_actual += dem * dt / HOUR
            t += dt
            m.step(t, 10.0, 0.0)
        self.assertLess(m.y, -0.05)  # 原始賣壓很大
        self.assertLess(abs(m.pressure), 0.01)  # 但作用在價格上的已被吸收


class TestTickInvariance(unittest.TestCase):
    def test_statistics_do_not_depend_on_tick(self):
        """同樣的連續時間賣家，1 分鐘與 5 分鐘 tick 的價格平均與標準差要一致（統計誤差內）。"""
        stats = {}
        for dt in (60, 300):
            pooled = []
            for seed in range(6):
                s, _ = run_market(dt, 20, seed, seller_rate_per_h=30, seller_size=20, online=3.0)
                pooled += s
            stats[dt] = (statistics.fmean(pooled), statistics.pstdev(pooled))
        (m1, s1), (m5, s5) = stats[60], stats[300]
        self.assertLess(abs(m1 - m5), 0.02, stats)
        self.assertLess(abs(s1 - s5) / s1, 0.1, stats)

    def test_pressure_equilibrium_same_for_any_tick(self):
        """持續超賣 e=0.5：賣壓 y 的穩態 = −λ·e / k_y，與 tick 大小無關。"""
        for dt in (60, 300, 900):
            p = with_overrides(DEFAULT, {"milk.noise_sd": 1e-9})
            m = Market(p.milk, T0, random.Random(1))
            m.ref_flow = 1000.0
            m.ref_online = 10.0
            m.online = 10.0
            t = T0
            # 讓計入流量 = 1.5 × 需求：每步塞 1.5·D·dt 的量，用超大額度的新玩家
            for _ in range(int(24 * HOUR / dt)):
                dem = m.demand_rate()
                m.pending_counted += 1.5 * dem * dt / HOUR
                m.pending_actual += 1.5 * dem * dt / HOUR / 1.5  # 維持長期平均 = 需求
                t += dt
                m.step(t, 10.0, 0.0)
            k_y = math.log(2) / (p.milk.pressure_half_life_s / HOUR)
            expect = -p.milk.pressure_down_per_h * m.excess / k_y
            self.assertAlmostEqual(m.y, expect, delta=0.01, msg=f"dt={dt}")  # 原始賣壓（未扣長期平均）
            self.assertAlmostEqual(m.excess, 0.5, delta=0.05, msg=f"dt={dt}")

    def test_event_sequence_independent_of_tick(self):
        seqs = []
        for dt in (60, 300):
            ex = Exchange(DEFAULT, 11, T0)
            t = T0
            for _ in range(int(10 * 86400 / dt)):
                t += dt
                ex.step(t, 1.0)
            # 同一個 tick 裡同時變成可見的事件，出現順序會跟 tick 大小有關；比「有哪些事件」要照開始時間排序
            seqs.append(sorted((e.start_at, e.factor, e.targets, e.headline) for e in ex.event_log_history))
        self.assertEqual(seqs[0], seqs[1])
        self.assertGreater(len(seqs[0]), 15)


class TestEvents(unittest.TestCase):
    def test_injected_event_hidden_until_announced(self):
        ex = Exchange(DEFAULT, 1, T0, events_enabled=False)
        ev = ex.inject_event(("milk",), 1.2, T0 + 10 * HOUR, 3 * HOUR, announce_lead_s=30 * MINUTE)
        self.assertEqual(ex.upcoming(T0 + 9 * HOUR), [])
        self.assertEqual(ex.upcoming(T0 + 9.75 * HOUR), [ev])
        self.assertEqual(ex.upcoming(T0 + 10.1 * HOUR), [])
        self.assertEqual(ev.log_effect(T0 + 9.9 * HOUR), 0.0)
        self.assertGreater(ev.log_effect(T0 + 10.5 * HOUR), 0.0)


class TestDeterminism(unittest.TestCase):
    def test_same_seed_same_prices(self):
        a, _ = run_market(60, 3, 42, seller_rate_per_h=20, seller_size=30)
        b, _ = run_market(60, 3, 42, seller_rate_per_h=20, seller_size=30)
        c, _ = run_market(60, 3, 43, seller_rate_per_h=20, seller_size=30)
        self.assertEqual(a, b)
        self.assertNotEqual(a, c)


if __name__ == "__main__":
    unittest.main()
