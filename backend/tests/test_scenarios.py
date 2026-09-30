"""經濟情境在伺服器的服務層重跑（server.game.Game + server.bots），達到經濟筆記的目標。

情境照 docs/research/economy/sim/scenarios.py，目標照 docs/research/2026-09-economy.md：
- (a) 每種人數下 95% 以上的時間，價格在基本價 0.6–1.7 倍。
- (b) S1–S4 每週收入「最高 ÷ 最低」≤ 1.5；100 人時 28 天合計 S4 最高。
- (c) 大戶倒貨：2 小時內價格最多低於理論上限 0.75%；一次倒出的均價比分 8 批差。
- (d) 新手：第一次賣奶 ≤ 5 分鐘、第一次擴建中位數 10–20 分鐘、全部 30 分鐘內第一次配種。
- 大利多後恐慌賣：多跌有限並且回復；某天只有兩成的人上線：價格和平常差不多。

規模：10 人（seed 1–5）與 100 人（seed 1–3）各 30 天、大戶與恐慌 100 人 23 天、人少 100 人 20 天，
和筆記同樣的 seed。1,000 人（30 天，約 40 秒）預設不跑，設 COWFARM_SCENARIO_1000=1 才跑。
1,000 人的大戶情境與 10,000 人沒有在服務層重跑（筆記裡也只各跑 1–2 個 seed）。

另外：服務層和研究模擬（docs/research/economy/sim）在同一個 seed 下逐數字相同，所以筆記的數字
就是伺服器的數字。研究模擬的資料夾不在時，這幾個比對測試會 skip。
整個檔案約 1–2 分鐘；照 AGENTS.md 用 systemd-run 限制記憶體執行。
"""

from __future__ import annotations

import json
import math
import os
import statistics
import sys
from functools import lru_cache
from pathlib import Path

import pytest

import harness as H

RESEARCH = Path(__file__).resolve().parents[2] / "docs" / "research" / "economy"
GOALS = RESEARCH / "out" / "goals.json"


@lru_cache(maxsize=None)
def run(name: str, players: int, seed: int, **kw) -> H.ServiceWorld:
    if name == "base":
        sc = H.base(players, seed)
    elif name == "whale":
        sc = H.whale(players, kw["mode"], kw["cows"], seed)
    elif name == "panic":
        sc = H.panic(players, kw["with_panic"], seed)
    elif name == "low":
        sc = H.low_online(players, seed, low=kw["low"])
    else:
        raise KeyError(name)
    return H.ServiceWorld(sc, seed).run()


def ratios(w, cid):
    base = w.params.commodity(cid).base_price
    return [p / base for p in w.rec[cid]]


def goals_json():
    if not GOALS.exists():
        pytest.skip("找不到 docs/research/economy/out/goals.json")
    return json.loads(GOALS.read_text())


# ---------------------------------------------------------------------------
# (a) 價格、(b) 策略收入、(d) 新手
# ---------------------------------------------------------------------------
SEEDS = {10: [1, 2, 3, 4, 5], 100: [1, 2, 3]}


@pytest.mark.parametrize("players", [10, 100])
def test_goal_a_price_band(players):
    worst = 1.0
    for s in SEEDS[players]:
        w = run("base", players, s)
        for cid in ("milk", "beef"):
            st = H.price_stats(ratios(w, cid))
            worst = min(worst, st["inside_soft_band"])
            assert st["inside_soft_band"] >= 0.95, (players, s, cid, st)
            assert 0.45 <= st["min"] and st["max"] <= 2.2  # 硬邊界
    print(f"\n(a) {players} 人：價格在 0.6–1.7 倍的時間（各 seed 最低）{worst:.4%}")


@pytest.mark.parametrize("players", [10, 100])
def test_goal_b_strategy_income(players):
    runs = [run("base", players, s) for s in SEEDS[players]]
    per = [H.strategy_weeks(w) for w in runs]
    keys = ("S1", "S2", "S3", "S4")
    worst = 0.0
    for wk in range(4):
        means = {k: statistics.fmean(p[k]["weeks"][wk] for p in per) for k in keys}
        ratio = max(means.values()) / min(means.values())
        worst = max(worst, ratio)
        assert ratio <= 1.5, (players, wk + 1, means)
    tot = {k: statistics.fmean(p[k]["total"] for p in per) for k in keys}
    top = max(tot, key=tot.get)
    print(f"\n(b) {players} 人：每週最高÷最低最大 {worst:.3f}；28 天合計最高 {top}，S4÷S1 = {tot['S4'] / tot['S1']:.3f}")
    if players >= 100:
        assert top == "S4", tot  # 筆記：100 人以上 S4 最高；10 人時樣本太小，筆記裡也不是
        assert 1.0 < tot["S4"] / tot["S1"] < 1.1


@pytest.mark.parametrize("players", [10, 100])
def test_goal_d_onboarding(players):
    for s in SEEDS[players]:
        ob = H.onboarding(run("base", players, s))
        assert ob["first_sale"]["n"] == ob["of"] and ob["first_sale"]["max"] <= 5
        assert 10 <= ob["first_expand"]["median"] <= 20
        assert ob["first_breed"]["n"] == ob["of"] and ob["first_breed"]["max"] <= 30


@pytest.mark.parametrize("players", [10, 100])
def test_numbers_match_research_note(players):
    """服務層重跑的結果 = 筆記 goals.json 的數字（同 seed、同一份引擎）。"""
    g = goals_json()
    row = g["a_price"][str(players)]
    for cid in ("milk", "beef"):
        inside = min(H.price_stats(ratios(run("base", players, s), cid))["inside_soft_band"] for s in SEEDS[players])
        assert inside == pytest.approx(row[cid]["inside_min"], abs=1e-12), cid
    b = g["b_strategies"][str(players)]
    per = [H.strategy_weeks(run("base", players, s)) for s in SEEDS[players]]
    for k in ("S1", "S2", "S3", "S4"):
        tot = sum(statistics.fmean(p[k]["weeks"][wk] for p in per) for wk in range(4))
        assert tot == pytest.approx(b["total_28d"][k], rel=1e-12), k
    assert g["params_fingerprint"] == H.DEFAULT.fingerprint()


# ---------------------------------------------------------------------------
# (c) 大戶
# ---------------------------------------------------------------------------
BOUND_SINGLE_DUMP = 1 - math.exp(-0.12 * 0.25 * 0.25)  # 0.75%：一個玩家一次倒貨最多壓低的比例


def test_goal_c_whale_dump():
    hold = run("whale", 100, 1, mode="hold", cows=100)
    dump = run("whale", 100, 1, mode="dump", cows=100)
    batch = run("whale", 100, 1, mode="batch", cows=100)
    lines = []
    for cid in ("milk", "beef"):
        g = H.gap_stats(dump, hold, cid, H.DUMP_H, direct_h=2.0)
        assert g["max_drop_direct"] <= BOUND_SINGLE_DUMP + 1e-9, (cid, g)
        td, tb = H.whale_totals(dump)[cid], H.whale_totals(batch)[cid]
        assert td["avg_price"] < tb["avg_price"], (cid, td, tb)  # 拋售不划算
        assert td["slip"] > tb["slip"]
        lines.append(f"{cid}：2 小時內最多低 {g['max_drop_direct']:.3%}（上限 {BOUND_SINGLE_DUMP:.2%}），倒出均價÷分批 = {td['avg_price'] / tb['avg_price']:.3f}")
    print("\n(c) 100 人＋大戶 100 頭：" + "；".join(lines))


# ---------------------------------------------------------------------------
# 恐慌賣、人少的一天
# ---------------------------------------------------------------------------
def test_panic_after_big_news():
    calm = run("panic", 100, 1, with_panic=False)
    pan = run("panic", 100, 1, with_panic=True)
    lines = []
    for cid in ("milk", "beef"):
        g = H.gap_stats(pan, calm, cid, H.EVENT_H + 0.25)
        assert 0.0 < g["max_drop_direct"] < 0.15, (cid, g)  # 大家一起賣會跌，但有限
        assert g["recover_90pct_h"] is not None and g["recover_90pct_h"] <= 8.0, (cid, g)  # 之後回升
        lines.append(f"{cid} 多跌 {g['max_drop_direct']:.1%}、{g['recover_90pct_h']:.1f} 小時回復九成")
    print("\n恐慌賣（100 人）：" + "；".join(lines))


def test_low_online_day():
    low = run("low", 100, 1, low=True)
    ref = run("low", 100, 1, low=False)
    d0 = H.LOW_DAY * 1440
    r = [a / b for a, b in zip(low.rec["milk"][d0:d0 + 1440], ref.rec["milk"][d0:d0 + 1440])]
    mean = statistics.fmean(r)
    assert 0.95 <= mean <= 1.05, mean
    on_low = statistics.fmean(low.rec["online"][d0:d0 + 1440])
    on_ref = statistics.fmean(ref.rec["online"][d0:d0 + 1440])
    assert on_low < 0.4 * on_ref
    print(f"\n人少的一天（100 人）：在線 {on_ref:.1f}→{on_low:.1f}，牛奶價 人少÷平常 平均 {mean:.3f}")


# ---------------------------------------------------------------------------
# 和研究模擬逐數字相同
# ---------------------------------------------------------------------------
def research_world():
    if not (RESEARCH / "sim" / "world.py").exists():
        pytest.skip("找不到 docs/research/economy/sim")
    if str(RESEARCH) not in sys.path:
        sys.path.insert(0, str(RESEARCH))
    import sim  # noqa: F401  （把 backend/ 加進 sys.path）
    from sim.world import World

    return World


@pytest.mark.parametrize("which", ["base_10_s1", "whale_100_dump"])
def test_identical_to_research_sim(which):
    World = research_world()
    if which == "base_10_s1":
        sc, mine = H.base(10, 1), run("base", 10, 1)
    else:
        sc, mine = H.whale(100, "dump", 100, 1), run("whale", 100, 1, mode="dump", cows=100)
    ref = World(sc, sc["seed"])
    ref.run()
    assert list(ref.rec["milk"]) == list(mine.rec["milk"])
    assert list(ref.rec["beef"]) == list(mine.rec["beef"])
    assert [b.farm.coins for b in ref.bots] == [b.farm.coins for b in mine.bots]
    assert [list(b.ledger.amount) for b in ref.bots] == [list(b.ledger.amount) for b in mine.bots]
    assert [(len(b.farm.cows), b.farm.slots) for b in ref.bots] == [(len(b.farm.cows), b.farm.slots) for b in mine.bots]


@pytest.mark.skipif(os.environ.get("COWFARM_SCENARIO_1000") != "1", reason="1,000 人 30 天約 40 秒；設 COWFARM_SCENARIO_1000=1 才跑")
def test_goals_1000_players():
    w = H.ServiceWorld(H.base(1000, 1), 1).run()
    for cid in ("milk", "beef"):
        assert H.price_stats(ratios(w, cid))["inside_soft_band"] >= 0.95
    b = H.goal_b(w)
    assert max(b["week_max_over_min"]) <= 1.5
    assert b["top"] == "S4"
