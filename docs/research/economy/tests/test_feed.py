"""飼料市場（v0.3 B，企劃第 3 節；參數 FeedMarketParams）：跟牛奶等分開、兩邊的壓力、滑價和手續費、每人上限、
邊界、飼料新聞、存檔、Farm 照市價買和賣回。"""

import json
import random
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import sim  # noqa: E402,F401  （把 backend/ 加進 sys.path）

from cowecon import DEFAULT, HOUR, MINUTE, Exchange, Farm, ImpactState  # noqa: E402
from cowecon.market import FEED_EID_BASE, FeedMarket  # noqa: E402

T0 = 1791129600.0
FM = DEFAULT.feedmarket
CP = DEFAULT.care
SOY = CP.feed_ids.index("soy")


def market(fid="soy", seed=1):
    k = CP.feed_ids.index(fid)
    return FeedMarket(FM, fid, CP.feed_price[k], T0, random.Random(seed))


def run(m, hours, buy_per_h=0.0, sell_per_h=0.0, online=10.0, tick=60.0):
    """每個 tick 有一位玩家買（或賣回）固定的量；每位玩家只出現一次，不受個人上限影響。"""
    t = m.t
    for _ in range(int(hours * HOUR / tick)):
        if buy_per_h:
            m.execute_buy(ImpactState(), buy_per_h * tick / HOUR, t)
        if sell_per_h:
            m.execute_sell(ImpactState(), sell_per_h * tick / HOUR, t)
        t += tick
        m.step(t, online, 0.0)
    return m


class TestIsolation(unittest.TestCase):
    def test_milk_beef_rice_unchanged_by_feed_markets(self):
        """同一個 seed、同樣的賣出順序，有沒有飼料市場，牛奶、牛肉、稻米的價格和新聞逐數字相同。"""

        def series(feeds):
            ex = Exchange(DEFAULT, "iso", T0, feeds_enabled=feeds)
            imp = {cid: ImpactState() for cid in ex.markets}
            out = []
            t = T0
            for i in range(3 * 24 * 60):
                t += 60.0
                if i % 7 == 0:
                    for cid, m in ex.markets.items():
                        m.execute_sale(imp[cid], [(30.0, 1.0)], t)
                if feeds and i % 5 == 0:
                    for fm in ex.feeds.values():
                        fm.execute_buy(ImpactState(), 12.0, t)
                ex.step(t, 8.0)
                out.append(tuple(m.price for m in ex.markets.values()))
            return out, [ev.to_state() for ev in ex.event_log_history]

        self.assertEqual(series(True), series(False))

    def test_feed_news_only_normal_and_big_one_feed_each(self):
        ex = Exchange(DEFAULT, "news", T0)
        t = T0
        for _ in range(30 * 24):
            t += HOUR
            ex.step(t, 5.0)
        evs = ex.feed_event_history
        self.assertGreater(len(evs), 60)  # 每天約 3 則
        self.assertTrue(all(ev.tier in ("normal", "big") for ev in evs))
        self.assertTrue(all(len(ev.targets) == 1 and ev.targets[0] in CP.feed_ids for ev in evs))
        self.assertTrue(all(ev.eid > FEED_EID_BASE for ev in evs))
        self.assertTrue(all(0.6 - 1e-9 <= ev.factor <= 1.4 + 1e-9 for ev in evs))


class TestPrice(unittest.TestCase):
    def test_buying_pushes_up_selling_back_pushes_down_and_returns_to_base(self):
        calm = run(market(), 24, buy_per_h=20.0)  # 平常的買進量
        hot = run(market(), 24, buy_per_h=20.0)
        run(hot, 3, buy_per_h=80.0)  # 突然很多人買
        peak = hot.pressure
        self.assertGreater(peak, 0.05)
        dump = run(market(), 24, buy_per_h=20.0)
        run(dump, 3, buy_per_h=20.0, sell_per_h=80.0)  # 很多人賣回
        self.assertLess(dump.pressure, -0.05)
        run(hot, 48, buy_per_h=20.0)  # 回到平常：壓力消退到高峰的兩成以下
        self.assertLess(abs(hot.pressure), 0.2 * peak)
        self.assertLess(abs(calm.pressure), 0.02)

    def test_bounds(self):
        """總價格永遠在基本價的 price_lo–price_hi 之間（0.5–2.0 倍），新聞以外的部分在硬邊界裡。"""
        for buy, sell in ((5000.0, 0.0), (0.0, 5000.0)):
            m = run(market(), 6, buy_per_h=20.0)
            t = m.t
            for i in range(2 * 24 * 60):
                if buy:
                    m.execute_buy(ImpactState(), buy / 60.0, t)
                if sell:
                    m.execute_sell(ImpactState(), sell / 60.0, t)
                t += 60.0
                m.step(t, 5.0, 0.9 if buy else -0.9)  # 新聞也推到極端
                self.assertGreaterEqual(m.ratio(), FM.price_lo - 1e-12)
                self.assertLessEqual(m.ratio(), FM.price_hi + 1e-12)
                self.assertGreaterEqual(m.ratio_ex_news, FM.hard_lo - 1e-12)
                self.assertLessEqual(m.ratio_ex_news, FM.hard_hi + 1e-12)
        self.assertEqual((FM.price_lo, FM.price_hi), (0.5, 2.0))


class TestTrades(unittest.TestCase):
    def test_buy_slippage_and_sell_fee(self):
        m = run(market(), 12, buy_per_h=20.0)
        p = m.price
        one = m.quote_buy(ImpactState(), 1, m.t)
        many = m.quote_buy(ImpactState(), 150, m.t)
        self.assertGreater(one.amount, p)  # 買一份也有一點滑價
        self.assertGreater(many.amount / 150, one.amount)  # 越買越貴
        self.assertLessEqual(many.avg_slip, FM.slip_kappa * FM.slip_qmax + 1e-12)
        back = m.quote_sell(ImpactState(), 1, m.t)
        self.assertLess(back.amount, p * (1 - FM.sell_fee))  # 手續費 25% 再加滑價
        self.assertGreater(back.amount, p * (1 - FM.sell_fee) * (1 - FM.slip_kappa))
        # 買進和賣回的滑價對稱（同樣的量、同樣的最近成交量）
        self.assertAlmostEqual(m.quote_buy(ImpactState(), 40, m.t).avg_slip, m.quote_sell(ImpactState(), 40, m.t).avg_slip)

    def test_player_cap_limits_pressure(self):
        m = run(market(), 12, buy_per_h=20.0)
        imp = ImpactState()
        res = m.execute_buy(imp, 1000, m.t)
        cap = FM.player_cap_frac * m.supply_rate() * FM.player_cap_window_s / HOUR
        self.assertAlmostEqual(res.counted, cap)
        res2 = m.execute_buy(imp, 10, m.t)
        self.assertEqual(res2.counted, 0.0)  # 額度用完
        self.assertGreater(m.execute_buy(imp, 10, m.t + 2 * HOUR).counted, 0.0)  # 時間到了又有


class TestFarm(unittest.TestCase):
    def test_buy_and_sell_back(self):
        ex = Exchange(DEFAULT, "farm", T0)
        f = Farm(DEFAULT, T0, random.Random(1), care=True)
        f.coins = 10_000
        m = ex.feeds["soy"]
        q = f.quote_feed_buy(SOY, 10, m, T0)
        res = f.buy_feed_market(SOY, 10, m, T0)
        self.assertEqual(res.amount, q.amount)
        self.assertAlmostEqual(f.coins, 10_000 - res.amount)
        self.assertEqual(f.feeds[SOY], 10)
        self.assertIsNone(f.buy_feed_market(SOY, CP.feed_cap, m, T0))  # 放不下
        f.coins = 1.0
        self.assertIsNone(f.buy_feed_market(SOY, 1, m, T0))  # 錢不夠
        back = f.sell_feed_market(SOY, 4, m, T0 + MINUTE)
        self.assertAlmostEqual(f.coins, 1.0 + back.amount)
        self.assertEqual(f.feeds[SOY], 6)
        self.assertIsNone(f.sell_feed_market(SOY, 7, m, T0))  # 份數不夠
        self.assertLess(back.amount / 4, res.amount / 10)  # 馬上賣回一定虧（手續費）

    def test_farm_impact_round_trip(self):
        f = Farm(DEFAULT, T0, random.Random(2), care=True)
        d = json.loads(json.dumps(f.to_dict()))
        self.assertIn("soy:buy", d["impact"])
        for fid in CP.feed_ids:  # 舊存檔沒有飼料的影響狀態
            del d["impact"][f"{fid}:buy"], d["impact"][f"{fid}:sell"]
        g = Farm.from_dict(DEFAULT, d)
        self.assertIn("oats:sell", g.impact)


class TestSave(unittest.TestCase):
    def test_round_trip_and_continue(self):
        def drive(ex, t0, t1):
            t = t0
            while t < t1:
                t += 60.0
                for i, fm in enumerate(ex.feeds.values()):
                    if int(t) % (300 + 60 * i) == 0:
                        fm.execute_buy(ImpactState(), 15.0, t)
                ex.step(t, 6.0)

        a = Exchange(DEFAULT, "save", T0)
        drive(a, T0, T0 + 30 * HOUR)
        d = json.loads(json.dumps(a.to_dict()))
        b = Exchange.from_dict(DEFAULT, d)
        self.assertEqual(b.to_dict(), d)
        drive(a, T0 + 30 * HOUR, T0 + 60 * HOUR)
        drive(b, T0 + 30 * HOUR, T0 + 60 * HOUR)
        self.assertEqual(b.to_dict(), a.to_dict())

    def test_old_save_without_feeds(self):
        """v0.3 B 以前的存檔：飼料市場從存檔的時間、基本價開始，牛奶等不受影響。"""
        a = Exchange(DEFAULT, "old", T0)
        t = T0
        for _ in range(120):
            t += 60.0
            a.step(t, 4.0)
        d = json.loads(json.dumps(a.to_dict()))
        for k in ("feeds", "feed_generator", "feed_events", "feed_history"):
            del d[k]
        b = Exchange.from_dict(DEFAULT, d, seed="old")
        self.assertEqual({fid: fm.t for fid, fm in b.feeds.items()}, {fid: t for fid in CP.feed_ids})
        self.assertEqual({fid: fm.base_price for fid, fm in b.feeds.items()}, dict(zip(CP.feed_ids, CP.feed_price)))
        self.assertEqual(b.markets["milk"].to_dict(), a.markets["milk"].to_dict())


if __name__ == "__main__":
    unittest.main()
