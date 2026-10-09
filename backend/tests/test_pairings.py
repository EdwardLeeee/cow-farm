"""圖鑑的配種表（C1b；企劃 v0.3 第 13.2 節；設計稿 S09-03；協定 2.7 節）：代表配法的資料表、爸爸媽媽分開算、
配出過幾次、只算配種和借種、雜種牛不算。"""

from __future__ import annotations

from itertools import product

import pytest

from conftest import T0, Harness, new_rid
from cowecon import DEFAULT
from cowecon.farm import make_genotype, offspring_distribution
from server import pairings as P
from server.breeds import ALL, BREEDS
from server.game import Game
from server.views import pairings_view
from test_api import state
from test_care import STRAWBERRY, adult, never_sick

HOLSTEIN = make_genotype(0, [])
ANGUS = make_genotype(2, [])
FLUFFY = make_genotype(0, [(1, 1), (0, 0), (0, 0)])  # 蓬蓬荷斯坦


def test_table_shape_and_examples():
    assert list(P.TABLE) == list(ALL)
    for child, rows in P.TABLE.items():
        assert len(rows) == P.REPRESENTATIVE and len(set(rows)) == P.REPRESENTATIVE, child
        probs = [P.pair_prob(s, d, child, 0.3) for s, d in rows]
        assert all(x > 0 for x in probs) and probs == sorted(probs, reverse=True), child
        assert all(P.pair_prob(s, d, child, 0.3) == P.pair_prob(d, s, child, 0.3) for s, d in rows)  # 兩個方向一樣
    # 企劃 13.2 的例子：蓬蓬荷斯坦 × 蓬蓬荷斯坦；同一對的兩個方向排在一起（設計稿的假資料也是這樣）
    assert P.TABLE["fluffyHolstein"] == [
        ("fluffyHolstein", "fluffyHolstein"),
        ("fluffyHolstein", "cottonCream"),
        ("cottonCream", "fluffyHolstein"),
        ("fluffyHolstein", "velvetBlack"),
    ]
    assert P.TABLE["strawberry"] == [
        ("strawberry", "strawberry"),
        ("strawberry", "goldenEar"),
        ("goldenEar", "strawberry"),
        ("goldenEar", "goldenEar"),
    ]
    assert P.TABLE["yellow"][:2] == [("holstein", "angus"), ("angus", "holstein")]  # 耕牛要乳牛配肉牛


def test_pair_prob_matches_genetics():
    """估計的機率 = 爸媽的基因照 q 抽（沒顯現的特徵帶一份隱性的機會 2q/(1+q)）再用 offspring_distribution 算。"""
    q = 0.3
    het = 2 * q / (1 + q)

    def genotypes(breed):
        """這個品種可能的基因和機率：顯現的特徵純合；沒顯現的 AA 或 Aa（隱性在第一個位置）。"""
        t, m = next((t, m) for t, row in enumerate(BREEDS) for m, b in enumerate(row) if b == breed)
        for carry in product((0, 1), repeat=3):
            pr = 1.0
            alleles = []
            for i in range(3):
                if (m >> i) & 1:
                    if carry[i]:
                        pr = 0.0
                    alleles.append((1, 1))
                else:
                    pr *= het if carry[i] else 1 - het
                    alleles.append((carry[i], 0))
            if pr > 0:
                yield make_genotype(t, alleles), pr

    for x, y, child in (("fluffyHolstein", "cottonCream", "fluffyHolstein"), ("holstein", "wagyu", "buffalo")):
        tc, mc = next((t, m) for t, row in enumerate(BREEDS) for m, b in enumerate(row) if b == child)
        exact = sum(
            px * py * offspring_distribution(gx, gy).get((tc, mc), 0.0)
            for gx, px in genotypes(x)
            for gy, py in genotypes(y)
        )
        assert P.pair_prob(x, y, child, q) == pytest.approx(exact, abs=1e-12)


def test_record_counts_and_old_saves():
    pairs = {}
    P.record(pairs, "strawberry", "holstein", "holstein", 9.0)
    P.record(pairs, "strawberry", "holstein", "holstein", 5.0)
    P.record(pairs, "holstein", "strawberry", "holstein", 7.0)  # 反過來是另一列
    assert pairs == {"strawberry,holstein,holstein": [5.0, 2], "holstein,strawberry,holstein": [7.0, 1]}
    assert P.load({"a,b,c": 3.0, "d,e,f": [4.0, 6]}) == {"a,b,c": [3.0, 1], "d,e,f": [4.0, 6]}  # C1a 只存時間


def test_breeding_records_pairs_without_parent_order():
    """配種：爸爸、媽媽分開算（反過來是另一列）；雜種爸爸記 hybrid；長成雜種牛的小牛不算；同一列配出過幾次。"""
    game = Game(DEFAULT, "pairs", T0)
    p = game.create_player(T0, "配種表")
    p.farm.coins, p.farm.slots = 1e6, 20
    never_sick(p)
    now = T0 + 60
    game.settle(p.pid, now)
    hol_bull, ang_cow = adult(p, HOLSTEIN, True, now), adult(p, ANGUS, False, now)
    ang_bull, hol_cow = adult(p, ANGUS, True, now), adult(p, HOLSTEIN, False, now)
    mix_bull, hol_cow2 = adult(p, HOLSTEIN, True, now), adult(p, HOLSTEIN, False, now)
    mix_bull.vt = 4  # 雜種公牛（基因是一般荷斯坦，小牛一定是荷斯坦）
    straw_bull, straw_cow = adult(p, STRAWBERRY, True, now), adult(p, STRAWBERRY, False, now)
    hol_bull2, ang_cow2 = adult(p, HOLSTEIN, True, now), adult(p, ANGUS, False, now)
    a = game.breed(p.pid, hol_bull.cid, ang_cow.cid, now)["calf"]
    b = game.breed(p.pid, ang_bull.cid, hol_cow.cid, now + 30)["calf"]
    m = game.breed(p.pid, mix_bull.cid, hol_cow2.cid, now + 60)["calf"]
    s = game.breed(p.pid, straw_bull.cid, straw_cow.cid, now + 90)["calf"]  # 沒吃指定的飼料：長成雜種牛
    a2 = game.breed(p.pid, hol_bull2.cid, ang_cow2.cid, now + 120)["calf"]  # 同一列再配一次
    game.settle(p.pid, now + 10 * 3600)
    assert s.hybrid and not m.hybrid
    assert p.pairs == {
        "holstein,angus,yellow": [a.adult_at, 2],
        "angus,holstein,yellow": [b.adult_at, 1],
        "hybrid,holstein,holstein": [m.adult_at, 1],
    }
    assert a2.adult_at > a.adult_at
    assert pairings_view(p) == [
        {"sire": "holstein", "dam": "angus", "child": "yellow", "count": 2, "found_at": a.adult_at},
        {"sire": "angus", "dam": "holstein", "child": "yellow", "count": 1, "found_at": b.adult_at},
        {"sire": "hybrid", "dam": "holstein", "child": "holstein", "count": 1, "found_at": m.adult_at},
    ]


def test_shop_calves_do_not_count():
    game = Game(DEFAULT, "pairs-shop", T0)
    p = game.create_player(T0, "商店")
    p.farm.coins, p.farm.slots = 1e7, 40
    for _ in range(10):
        game.shop_buy(p.pid, "A", T0)
    game.settle(p.pid, T0 + 24 * 3600)
    assert p.pairs == {} and p.parents == {}


@pytest.fixture
def h(db_dsn):
    with Harness(db_dsn, bots=0) as hh:
        yield hh


def test_http_pairings(h):
    tok = h.session()["token"]
    r = h.get("/v1/codex/pairings", tok).json()
    assert list(r["pairings"]) == list(ALL) and "server_time" in r
    assert r["pairings"]["fluffyHolstein"][:2] == [
        {"sire": "fluffyHolstein", "dam": "fluffyHolstein"},
        {"sire": "fluffyHolstein", "dam": "cottonCream"},
    ]
    assert all(len(v) == 4 for v in r["pairings"].values())
    assert h.client.get("/v1/codex/pairings").status_code == 401
    st = state(h, tok)
    assert st["pairings"] == []
    p = h.server.game.players[st["player_id"]]
    p.farm.coins, p.farm.slots = 1e6, 10
    now = h.clock.now()
    never_sick(p)
    bull, cow = adult(p, HOLSTEIN, True, now), adult(p, FLUFFY, False, now)
    r = h.post("/v1/breed", tok, {"sire": bull.cid, "dam": cow.cid, "request_id": new_rid()})
    assert r.status_code == 200, r.text
    calf = p.farm.cow_by_id(r.json()["calf"]["id"])
    h.advance(DEFAULT.farm.tier_growth_h[0] * 3600, tick=False)
    st = state(h, tok)
    child = next(c for c in st["cows"] if c["id"] == calf.cid)["breed"]
    assert st["pairings"] == [
        {"sire": "holstein", "dam": "fluffyHolstein", "child": child, "count": 1, "found_at": calf.adult_at}
    ]
    h.post("/v1/collect", tok, {"request_id": new_rid()})  # 動作存下來的跟 GET 看到的一樣
    assert p.pairs == {f"holstein,fluffyHolstein,{child}": [calf.adult_at, 1]}
