"""cowecon 的存檔與回復：Market、Exchange、Farm、ImpactState、Cow、Lot（和 BeefLot）。

- 每個類別：to_dict → JSON 字串 → from_dict → to_dict 完全相同。
- 同一個 seed「跑到一半存檔、回復、再跑」和「一路跑到底」，每個數字都一樣（價格、每座牧場的全部狀態）。
不需要資料庫。
"""

from __future__ import annotations

import json
import random

import pytest

from cowecon import DEFAULT, MINUTE, BeefLot, Cow, Exchange, Farm, ImpactState, Lot
from cowecon.market import Market, rng_from_state, rng_to_state

T0 = 1791129600.0


def rt(d):
    """經過 JSON 字串來回一次（和寫進資料庫一樣）。"""
    return json.loads(json.dumps(d, allow_nan=False))


def test_each_class_round_trips():
    ex = Exchange(DEFAULT, "persist", T0)
    rng = random.Random(3)
    farm = Farm(DEFAULT, T0, rng)
    t = T0
    for i in range(300):
        t += 60
        ex.step(t, 5.0 + i % 7)
        if i % 17 == 0:
            farm.sell_all_milk(ex.markets["milk"], t)
    farm.lots.append(Lot(2, 12.5, t))
    farm.beef_lots.append(BeefLot(1, 250.0, 1.3, t, 9))

    imp = farm.impact["milk"]
    assert ImpactState.from_dict(rt(imp.to_dict())).to_dict() == imp.to_dict()
    for c in farm.cows:
        assert Cow.from_dict(DEFAULT.farm, rt(c.to_dict())).to_dict() == c.to_dict()
    lot = farm.lots[-1]
    assert Lot.from_dict(rt(lot.to_dict())).to_dict() == lot.to_dict()
    bl = farm.beef_lots[-1]
    assert BeefLot.from_dict(rt(bl.to_dict())).to_dict() == bl.to_dict()
    m = ex.markets["milk"]
    assert Market.from_dict(DEFAULT.milk, rt(m.to_dict())).to_dict() == m.to_dict()
    assert Exchange.from_dict(DEFAULT, rt(ex.to_dict())).to_dict() == ex.to_dict()
    assert Farm.from_dict(DEFAULT, rt(farm.to_dict())).to_dict() == farm.to_dict()


def test_rng_state_keeps_gauss_cache():
    r = random.Random(7)
    r.gauss(0, 1)  # 留下一個快取的常態亂數
    r2 = rng_from_state(rt(rng_to_state(r)))
    assert [r.gauss(0, 1) for _ in range(5)] == [r2.gauss(0, 1) for _ in range(5)]


def test_market_restore_with_external_hist():
    """伺服器的做法：市場存檔不含歷史，歷史另外從價格表補回來。"""
    ex = Exchange(DEFAULT, "hist", T0)
    t = T0
    for _ in range(2000):  # 超過 24 小時，歷史有被剪掉過
        t += 60
        ex.step(t, 3.0)
    m = ex.markets["beef"]
    snap = rt(m.to_dict(include_hist=False))
    hist = [(tt, p) for tt, p in m._hist]
    m2 = Market.from_dict(DEFAULT.beef, snap, hist)
    assert m2.to_dict() == m.to_dict()
    assert m2.moving_average() == m.moving_average()


# ---------------------------------------------------------------------------
# 跑到一半存檔、回復、再跑
# ---------------------------------------------------------------------------
N_FARMS = 12
DAYS = 3


class Driver:
    """一群牧場在同一個市場上隨機做各種動作（收奶、分批賣、出貨進倉庫、賣牛肉、買小牛、配種、升級）。"""

    def __init__(self, seed: int):
        self.ex = Exchange(DEFAULT, f"drv{seed}", T0)
        self.rng = random.Random(f"driver:{seed}")
        self.farm_rngs = [random.Random(f"farm:{seed}:{i}") for i in range(N_FARMS)]
        self.farms = [Farm(DEFAULT, T0 + i * 7 * MINUTE, self.farm_rngs[i]) for i in range(N_FARMS)]
        self.tick = 0
        self.prices = []

    def step(self):
        t = T0 + (self.tick + 1) * 60.0
        mk, bk = self.ex.markets["milk"], self.ex.markets["beef"]
        for i, f in enumerate(self.farms):
            if t < f.created_at or self.rng.random() > 0.08:
                continue
            fr = self.farm_rngs[i]
            a = self.rng.random()
            if a < 0.35:
                f.sell_all_milk(mk, t)
            elif a < 0.5:
                f.drop_spoiled(t)
                f.collect(t)
                stock = f.wh_used()
                if stock > 0:
                    f.sell_milk(mk, stock * self.rng.choice((0.3, 0.5, 1.0)), t)
            elif a < 0.6:
                adults = [c for c in f.cows if c.is_adult(t)]
                if adults:
                    f.ship_to_storage(self.rng.choice(adults), t)
            elif a < 0.7:
                if f.beef_lots:
                    f.sell_beef(bk, f.beef_stock() * self.rng.choice((0.4, 1.0)), t)
            elif a < 0.8:
                if f.free_slots() <= 0:
                    f.expand_pen(t)
                f.buy_calf(self.rng.randrange(3), self.rng.random() < 0.5, t, fr)
            elif a < 0.9:
                bulls = [c for c in f.cows if c.bull and c.is_adult(t) and t >= c.ready_at]
                cows = [c for c in f.cows if not c.bull and c.is_adult(t) and t >= c.ready_at]
                if bulls and cows:
                    f.breed(bulls[0], cows[-1], t, fr)
            else:
                getattr(f, self.rng.choice(("upgrade_bucket", "upgrade_wh", "upgrade_fresh", "expand_pen")))(t)
        self.ex.step(t, 1.0 + 4.0 * self.rng.random())
        self.prices.append((self.ex.markets["milk"].price, self.ex.markets["beef"].price))
        self.tick += 1

    def run(self, n):
        for _ in range(n):
            self.step()

    def to_json(self) -> str:
        return json.dumps({
            "ex": self.ex.to_dict(),
            "farms": [f.to_dict() for f in self.farms],
            "rng": rng_to_state(self.rng),
            "farm_rngs": [rng_to_state(r) for r in self.farm_rngs],
            "tick": self.tick,
        }, allow_nan=False)

    @classmethod
    def from_json(cls, s: str, prices) -> "Driver":
        d = json.loads(s)
        drv = cls.__new__(cls)
        drv.ex = Exchange.from_dict(DEFAULT, d["ex"])
        drv.farms = [Farm.from_dict(DEFAULT, x) for x in d["farms"]]
        drv.rng = rng_from_state(d["rng"])
        drv.farm_rngs = [rng_from_state(x) for x in d["farm_rngs"]]
        drv.tick = d["tick"]
        drv.prices = list(prices)
        return drv

    def fingerprint(self):
        return {
            "prices": self.prices,
            "farms": [f.to_dict() for f in self.farms],
            "ex": self.ex.to_dict(),
        }


@pytest.mark.parametrize("seed", [1, 2])
def test_resume_equals_uninterrupted(seed):
    total = DAYS * 1440
    straight = Driver(seed)
    straight.run(total)

    first = Driver(seed)
    first.run(total // 2)
    saved = first.to_json()
    del first
    resumed = Driver.from_json(saved, straight.prices[: total // 2])
    resumed.run(total - total // 2)

    a, b = straight.fingerprint(), resumed.fingerprint()
    assert a["prices"] == b["prices"]
    assert a["farms"] == b["farms"]
    assert a["ex"] == b["ex"]
    # 有真的測到東西：價格有動、有牛肉批次與部分賣出、有新聞
    assert len({p for p, _ in a["prices"]}) > 1000
    assert any(f["beef_lots"] for f in a["farms"]) or any(f["n_sales"] > 5 for f in a["farms"])
    assert a["ex"]["history"], "三天內應該有新聞事件"
