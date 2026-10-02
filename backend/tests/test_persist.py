"""cowecon 的存檔與回復：Market、Exchange、Farm、ImpactState、Cow、Lot（和 BeefLot、RiceLot、Field、StudMarket）。

- 每個類別：to_dict → JSON 字串 → from_dict → to_dict 完全相同。
- 同一個 seed「跑到一半存檔、回復、再跑」和「一路跑到底」，每個數字都一樣（價格、每座牧場的全部狀態）。
不需要資料庫。
"""

from __future__ import annotations

import json
import random

import pytest

from cowecon import DEFAULT, MINUTE, BeefLot, Cow, Exchange, Farm, Field, ImpactState, Lot, RiceLot, StudMarket
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
    farm.beef_lots.append(BeefLot(1, 250.0, 1.3, t, 9, 0, 0b101101))
    farm.rice_lots.append(RiceLot(40.5, t))
    farm.fields.append(Field(t, -1, 3.25))

    imp = farm.impact["milk"]
    assert ImpactState.from_dict(rt(imp.to_dict())).to_dict() == imp.to_dict()
    for c in farm.cows:
        assert Cow.from_dict(DEFAULT.farm, rt(c.to_dict())).to_dict() == c.to_dict()
    lot = farm.lots[-1]
    assert Lot.from_dict(rt(lot.to_dict())).to_dict() == lot.to_dict()
    bl = farm.beef_lots[-1]
    assert BeefLot.from_dict(rt(bl.to_dict())).to_dict() == bl.to_dict()
    assert BeefLot.from_dict(rt(bl.to_dict())).genes == 0b101101
    old = BeefLot.from_dict([1, 250.0, 1.3, t, 9, 0])  # 2026-10-02 之前的存檔：6 個元素、沒有基因
    assert old.genes is None and old.grade == 0 and old.cow_id == 9
    rl = farm.rice_lots[-1]
    assert RiceLot.from_dict(rt(rl.to_dict())).to_dict() == rl.to_dict()
    fl = farm.fields[-1]
    assert Field.from_dict(rt(fl.to_dict())).to_dict() == fl.to_dict()
    sm = StudMarket(DEFAULT)
    sm.npc_refill(t, random.Random(5))
    assert StudMarket.from_dict(DEFAULT, rt(sm.to_dict())).to_dict() == sm.to_dict()
    m = ex.markets["milk"]
    assert Market.from_dict(DEFAULT.milk, rt(m.to_dict())).to_dict() == m.to_dict()
    assert Exchange.from_dict(DEFAULT, rt(ex.to_dict())).to_dict() == ex.to_dict()
    assert Farm.from_dict(DEFAULT, rt(farm.to_dict())).to_dict() == farm.to_dict()


def test_old_save_beef_lots_without_genes():
    """新程式讀舊存檔：2026-10-02 之前的牛肉批次是 6 個元素、沒有基因。整個牧場讀得進來，
    genes 是 None（state 的 breed 給 null），其他欄位不變；再存一次就是 7 個元素。"""
    farm = Farm(DEFAULT, T0, random.Random(1))
    farm.beef_lots.append(BeefLot(1, 250.0, 1.3, T0, 9, 0, 0b101101))
    old = rt(farm.to_dict())
    old["beef_lots"] = [x[:6] for x in old["beef_lots"]]  # 舊程式存的樣子
    back = Farm.from_dict(DEFAULT, old)
    assert back.beef_lots[0].genes is None
    assert back.beef_lots[0].to_dict() == old["beef_lots"][0] + [None]
    assert {k: v for k, v in rt(back.to_dict()).items() if k != "beef_lots"} == {
        k: v for k, v in old.items() if k != "beef_lots"
    }


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
    """一群牧場在同一個市場上隨機做各種動作（v0.2）：收奶、分批賣、商店等級抽牛、出貨評級進倉庫、賣牛肉、
    配種（一輩子一次）、耕牛下田／叫回、收成、賣稻米、借種上架／借用、升級與開田。"""

    def __init__(self, seed: int):
        self.ex = Exchange(DEFAULT, f"drv{seed}", T0)
        self.stud = StudMarket(DEFAULT)
        self.rng = random.Random(f"driver:{seed}")
        self.npc_rng = random.Random(f"npc:{seed}")
        self.stud.npc_refill(T0, self.npc_rng)
        self.farm_rngs = [random.Random(f"farm:{seed}:{i}") for i in range(N_FARMS)]
        self.farms = [Farm(DEFAULT, T0 + i * 7 * MINUTE, self.farm_rngs[i]) for i in range(N_FARMS)]
        self.tick = 0
        self.prices = []
        self.done = {}  # 成功做過的動作次數（只用來確認測試有涵蓋到，不存檔）

    def _ok(self, key, result):
        if result:
            self.done[key] = self.done.get(key, 0) + 1
        return result

    def step(self):
        t = T0 + (self.tick + 1) * 60.0
        mk, bk, rk = self.ex.markets["milk"], self.ex.markets["beef"], self.ex.markets["rice"]
        for i, f in enumerate(self.farms):
            if t < f.created_at or self.rng.random() > 0.08:
                continue
            fr = self.farm_rngs[i]
            a = self.rng.random()
            adults = [c for c in f.cows if f.can_ship(c, t)]
            if a < 0.25:
                f.sell_all_milk(mk, t)
            elif a < 0.35:
                f.drop_spoiled(t)
                f.collect(t)
                stock = f.wh_used()
                if stock > 0:
                    f.sell_milk(mk, stock * self.rng.choice((0.3, 0.5, 1.0)), t)
            elif a < 0.42:
                if adults:
                    self._ok("ship", f.ship_to_storage(self.rng.choice(adults), t, fr))
            elif a < 0.48:
                if f.beef_lots:
                    f.sell_beef(bk, f.beef_stock() * self.rng.choice((0.4, 1.0)), t)
            elif a < 0.56:
                if f.free_slots() <= 0:
                    f.expand_pen(t)
                self._ok("shop", f.buy_shop(self.rng.randrange(3), t, fr))
            elif a < 0.63:
                if f.free_slots() <= 0:
                    f.expand_pen(t)  # 小牛要有空格
                for c in f.cows:
                    if c.bull and c.listed is not None and not c.bred:
                        self._ok("unlist", self.stud.unlist(c.listed, f))  # 自己配：先下架
                    if c.field >= 0 and not c.bred:
                        f.recall(c, t)
                bulls = [c for c in f.cows if c.bull and c.can_breed_now(t)]
                cows = [c for c in f.cows if not c.bull and c.can_breed_now(t)]
                if bulls and cows:
                    self._ok("breed", f.breed(bulls[0], cows[-1], t, fr))
            elif a < 0.72:
                oxen = [c for c in f.cows if f.can_work(c, t)]
                if oxen and f.free_field() >= 0:
                    self._ok("field", f.assign_field(oxen[0], f.free_field(), t))
                working = [c for c in f.cows if c.field >= 0]
                if working and self.rng.random() < 0.3:
                    f.recall(working[0], t)
            elif a < 0.80:
                self._ok("harvest", f.harvest(t))
                if f.rice_stock() > 0:
                    f.sell_rice(rk, f.rice_stock() * self.rng.choice((0.5, 1.0)), t)
            elif a < 0.88:
                bulls = [c for c in f.cows if c.bull and self.stud.can_list(f, c, t)]
                if bulls:
                    self._ok("list", self.stud.list_bull(f, i, bulls[0], t))
                dams = [c for c in f.cows if not c.bull and c.can_breed_now(t)]
                lst = [l for l in self.stud.listings.values() if l.owner != i]
                if dams and lst:
                    pick = self.rng.choice(sorted(lst, key=lambda l: l.lid))
                    owner = self.farms[pick.owner] if pick.owner is not None else None
                    calf = self._ok("borrow", self.stud.borrow(pick.lid, f, i, dams[0], t, fr, owner))
                    if calf is not None and owner is None:
                        self.stud.npc_refill(t, self.npc_rng)
            else:
                getattr(
                    f, self.rng.choice(("upgrade_bucket", "upgrade_wh", "upgrade_fresh", "expand_pen", "expand_field"))
                )(t)
        self.ex.step(t, 1.0 + 4.0 * self.rng.random())
        self.prices.append(tuple(self.ex.markets[c].price for c in ("milk", "beef", "rice")))
        self.tick += 1

    def run(self, n):
        for _ in range(n):
            self.step()

    def to_json(self) -> str:
        return json.dumps(
            {
                "ex": self.ex.to_dict(),
                "stud": self.stud.to_dict(),
                "farms": [f.to_dict() for f in self.farms],
                "rng": rng_to_state(self.rng),
                "npc_rng": rng_to_state(self.npc_rng),
                "farm_rngs": [rng_to_state(r) for r in self.farm_rngs],
                "tick": self.tick,
            },
            allow_nan=False,
        )

    @classmethod
    def from_json(cls, s: str, prices) -> "Driver":
        d = json.loads(s)
        drv = cls.__new__(cls)
        drv.ex = Exchange.from_dict(DEFAULT, d["ex"])
        drv.stud = StudMarket.from_dict(DEFAULT, d["stud"])
        drv.farms = [Farm.from_dict(DEFAULT, x) for x in d["farms"]]
        drv.rng = rng_from_state(d["rng"])
        drv.npc_rng = rng_from_state(d["npc_rng"])
        drv.farm_rngs = [rng_from_state(x) for x in d["farm_rngs"]]
        drv.tick = d["tick"]
        drv.prices = list(prices)
        drv.done = {}
        return drv

    def fingerprint(self):
        return {
            "prices": self.prices,
            "farms": [f.to_dict() for f in self.farms],
            "ex": self.ex.to_dict(),
            "stud": self.stud.to_dict(),
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
    assert a["stud"] == b["stud"]
    # 有真的測到東西：三種價格有動、有新聞、有配過種、有田、有借種上架／成交
    assert all(len({p[k] for p in a["prices"]}) > 1000 for k in range(3))
    assert a["ex"]["history"], "三天內應該有新聞事件"
    for key in ("ship", "shop", "breed", "field", "harvest", "list", "borrow"):
        assert straight.done.get(key, 0) > 0, (key, straight.done)
