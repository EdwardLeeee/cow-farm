"""經濟情境在伺服器的服務層重跑（v0.2：server.game.Game + server.bots），達到經濟筆記的目標。

情境照 docs/research/economy/sim/scenarios.py（v0.2），目標照 docs/research/2026-09-economy.md 第 9 節：
- 三種商品的價格 95% 以上的時間在基本價 0.6–1.7 倍。
- 六種玩法每週收入「最高 ÷ 最低」≤ 1.5；耕田派 ÷ 乳牛派在 ±15% 內。
- 大戶倒貨：2 小時內壓低的比例不超過理論上限（由參數算）；一次倒出的滑價比分批大。
- 新手：第一次賣奶 ≤ 5 分鐘、第一次擴建中位數 10–20 分鐘、全部 30 分鐘內第一次配種。
- 借種有成交、出借收入不失控；商店三級都有人買；出貨三種評級都會出現。
- 大利多後恐慌賣：多跌有限並且回復；某天只有兩成的人上線：價格和平常差不多。

經濟代理還在調 backend/cowecon/params.py 的數值（不改 API），所以這裡**不寫死任何會隨參數變的數字**：
上限由參數算，其他都是企劃目標的門檻。

規模：10 人（seed 1–5）與 100 人（seed 1–3）各 30 天、大戶與恐慌 100 人 23 天、人少 100 人 20 天，
和筆記同樣的 seed。1,000 人（30 天，約 1 分鐘）預設不跑，設 COWFARM_SCENARIO_1000=1 才跑。
1,000 人的大戶與 10,000 人沒有在服務層重跑。

另外：服務層和研究模擬（docs/research/economy/sim）在同一個 seed 下逐數字相同。
比對前先把研究模擬的 bot 調整值（VALUE_TABLE 等）複製到伺服器的 bot，比的是「流程」是否相同；
兩邊的調整值有沒有同步，另外由 test_bot_tunables_match_research 提醒（只警告，不算失敗）。
研究模擬的資料夾不在時，這幾個比對測試會 skip。整個檔案約 2 分鐘；照 AGENTS.md 用 systemd-run 限制記憶體執行。
"""

from __future__ import annotations

import json
import math
import os
import statistics
import sys
import warnings
from contextlib import contextmanager
from functools import lru_cache
from pathlib import Path

import pytest

import harness as H
from server import bots as MB

RESEARCH = Path(__file__).resolve().parents[2] / "docs" / "research" / "economy"
GOALS = RESEARCH / "out" / "goals.json"
CIDS = ("milk", "beef", "rice")
TUNABLES = (
    "VALUE_TABLE",
    "PROFILES",
    "BUCKET_TARGET_H",
    "DAIRY_SHIP_FRAC",
    "RARE_KEEP_FRAC",
    "PEAK_H",
    "BULL_WAIT_MAX_H",
    "HOLD_THR",
    "HOLD_FRESH_SELL",
    "HOLD_WH_TARGET_H",
    "HOLD_MIN_COWS",
    "STUD_PRICE_BY_TIER",
    "STUD_RELIST_H",
    "PANIC_SHIP_AGE_H",
    "SHOP_CHOICE_SCALE",
)


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


# ---------------------------------------------------------------------------
# 價格、收入、新手
# ---------------------------------------------------------------------------
SEEDS = {10: [1, 2, 3, 4, 5], 100: [1, 2, 3]}


@pytest.mark.parametrize("players", [10, 100])
def test_price_band(players):
    worst = {}
    for s in SEEDS[players]:
        w = run("base", players, s)
        for cid in CIDS:
            st = H.price_stats(ratios(w, cid))
            worst[cid] = min(worst.get(cid, 1.0), st["inside_soft_band"])
            assert st["inside_soft_band"] >= 0.95, (players, s, cid, st)
            cp = w.params.commodity(cid)
            assert cp.hard_lo - 1e-9 <= st["min"] and st["max"] <= cp.hard_hi + 1e-9  # 硬邊界
    print(
        f"\n{players} 人：價格在 0.6–1.7 倍的時間（各 seed 最低）" + "、".join(f"{c} {v:.2%}" for c, v in worst.items())
    )


@pytest.mark.parametrize("players", [10, 100])
def test_strategy_income(players):
    per = [H.strategy_weeks(run("base", players, s)) for s in SEEDS[players]]
    keys = MB.PLAYER_STRATEGIES
    worst = 0.0
    for wk in range(4):
        means = {k: statistics.fmean(p[k]["weeks"][wk] for p in per) for k in keys}
        ratio = max(means.values()) / min(means.values())
        worst = max(worst, ratio)
        assert ratio <= 1.5, (players, wk + 1, means)
    tot = {k: statistics.fmean(p[k]["total"] for p in per) for k in keys}
    f_over_d = tot["F"] / tot["D"]
    print(
        f"\n{players} 人：每週最高÷最低最大 {worst:.3f}；28 天合計最高 {max(tot, key=tot.get)}；耕田派÷乳牛派 {f_over_d:.3f}"
    )
    assert 0.85 <= f_over_d <= 1.15, tot


@pytest.mark.parametrize("players", [10, 100])
def test_onboarding(players):
    for s in SEEDS[players]:
        ob = H.onboarding(run("base", players, s))
        assert ob["first_sale"]["n"] == ob["of"] and ob["first_sale"]["max"] <= 5
        assert 10 <= ob["first_expand"]["median"] <= 20
        assert ob["first_breed"]["n"] == ob["of"] and ob["first_breed"]["max"] <= 30


def test_stud_shop_grades_100():
    ws = [run("base", 100, s) for s in SEEDS[100]]
    borrows = sum(H.stud_stats(w)["borrows"] for w in ws)
    share = statistics.fmean(H.stud_stats(w)["lender_share"] for w in ws)
    shop = {g: sum(H.shop_counts(w)[g] for w in ws) for g in ("A", "B", "C")}
    grades = {g: sum(H.stud_stats(w)["grades"][g] for w in ws) for g in ("A", "B", "C")}
    n_shop = sum(shop.values())
    per_day = borrows / (len(ws) * 100 * 30)
    print(
        f"\n100 人：借種每人每天 {per_day:.2f} 筆、出借公牛派借種收入占 {share:.1%}；商店份額 "
        + "、".join(f"{g} {v / n_shop:.0%}" for g, v in shop.items())
        + "；出貨評級 "
        + "、".join(f"{g} {v / sum(grades.values()):.0%}" for g, v in grades.items())
    )
    assert borrows > 0
    assert share < 0.2  # 出借收入不失控（筆記：約 3%）
    assert all(v / n_shop >= 0.05 for v in shop.values()), shop  # 三級都有人買
    assert all(v > 0 for v in grades.values()), grades


# ---------------------------------------------------------------------------
# 大戶、恐慌賣、人少的一天
# ---------------------------------------------------------------------------
def single_dump_bound(params) -> float:
    """一個玩家一次倒貨最多壓低的比例（由參數算；v0.1 筆記是 0.75%）。"""
    cp = params.milk
    return 1 - math.exp(-cp.pressure_down_per_h * cp.player_cap_frac * cp.player_cap_window_s / 3600.0)


def test_whale_dump():
    hold = run("whale", 100, 1, mode="hold", cows=100)
    dump = run("whale", 100, 1, mode="dump", cows=100)
    batch = run("whale", 100, 1, mode="batch", cows=100)
    bound = max(
        single_dump_bound(hold.params),
        1
        - math.exp(
            -hold.params.beef.pressure_down_per_h
            * hold.params.beef.player_cap_frac
            * hold.params.beef.player_cap_window_s
            / 3600.0
        ),
    )
    lines = []
    for cid in ("milk", "beef"):
        g = H.gap_stats(dump, hold, cid, H.DUMP_H, direct_h=2.0)
        assert g["max_drop_direct"] <= bound + 1e-9, (cid, g, bound)
        td, tb = H.whale_totals(dump)[cid], H.whale_totals(batch)[cid]
        lines.append(
            f"{cid}：2 小時內最多低 {g['max_drop_direct']:.3%}（上限 {bound:.2%}），滑價 倒 {td['slip']:.1%}／分批 {tb['slip']:.1%}"
        )
        if cid == "milk":
            assert td["slip"] > tb["slip"], (td, tb)  # 一次倒出比分批吃虧
    print("\n100 人＋大戶 100 頭：" + "；".join(lines))


def test_panic_after_big_news():
    calm = run("panic", 100, 1, with_panic=False)
    pan = run("panic", 100, 1, with_panic=True)
    lines = []
    for cid in CIDS:
        g = H.gap_stats(pan, calm, cid, H.EVENT_H + 0.25)
        assert g["max_drop_direct"] < 0.15, (cid, g)  # 大家一起賣會跌，但有限
        if g["max_drop_direct"] >= 0.003:
            assert g["recover_90pct_h"] is not None and g["recover_90pct_h"] <= 8.0, (cid, g)  # 之後回升
        rec = f"{g['recover_90pct_h']:.1f} 小時回復九成" if g["recover_90pct_h"] is not None else "跌幅太小不計回復"
        lines.append(f"{cid} 多跌 {g['max_drop_direct']:.1%}、{rec}")
    print("\n恐慌賣（100 人）：" + "；".join(lines))


def test_low_online_day():
    low = run("low", 100, 1, low=True)
    ref = run("low", 100, 1, low=False)
    d0 = H.LOW_DAY * 1440
    out = []
    for cid in CIDS:
        r = [a / b for a, b in zip(low.rec[cid][d0 : d0 + 1440], ref.rec[cid][d0 : d0 + 1440])]
        mean = statistics.fmean(r)
        out.append(f"{cid} {mean:.3f}")
        assert 0.95 <= mean <= 1.05, (cid, mean)
    on_low = statistics.fmean(low.rec["online"][d0 : d0 + 1440])
    on_ref = statistics.fmean(ref.rec["online"][d0 : d0 + 1440])
    assert on_low < 0.4 * on_ref
    print(f"\n人少的一天（100 人）：在線 {on_ref:.1f}→{on_low:.1f}，人少÷平常 " + "、".join(out))


# ---------------------------------------------------------------------------
# 和研究模擬逐數字相同
# ---------------------------------------------------------------------------
def research():
    if not (RESEARCH / "sim" / "world.py").exists():
        pytest.skip("找不到 docs/research/economy/sim")
    if str(RESEARCH) not in sys.path:
        sys.path.insert(0, str(RESEARCH))
    import sim  # noqa: F401  （把 backend/ 加進 sys.path）

    assert sim
    from sim import bots as SB
    from sim.world import World

    return World, SB


@contextmanager
def research_tunables(SB):
    """暫時把研究模擬的 bot 調整值複製到伺服器的 bot（比的是流程，不是調整值）。"""
    saved = {k: getattr(MB, k) for k in TUNABLES}
    try:
        for k in TUNABLES:
            setattr(MB, k, getattr(SB, k))
        yield
    finally:
        for k, v in saved.items():
            setattr(MB, k, v)


def test_bot_tunables_match_research():
    _World, SB = research()
    diff = [k for k in TUNABLES if getattr(SB, k) != getattr(MB, k)]
    if diff:
        warnings.warn(f"server/bots.py 的調整值和研究模擬不同，要同步：{diff}", UserWarning)


@pytest.mark.parametrize("which", ["base_10_s1", "whale_100_dump", "panic_100"])
def test_identical_to_research_sim(which):
    World, SB = research()
    sc = {
        "base_10_s1": H.base(10, 1),
        "whale_100_dump": H.whale(100, "dump", 100, 1),
        "panic_100": H.panic(100, True, 1),
    }[which]
    ref = World(sc, sc["seed"])
    ref.run()
    with research_tunables(SB):
        mine = H.ServiceWorld(sc, sc["seed"]).run()
    for cid in CIDS:
        assert list(ref.rec[cid]) == list(mine.rec[cid]), cid
    assert [b.farm.coins for b in ref.bots] == [b.farm.coins for b in mine.bots]
    assert [list(b.ledger.amount) for b in ref.bots] == [list(b.ledger.amount) for b in mine.bots]
    assert [list(b.ledger.qty) for b in ref.bots] == [list(b.ledger.qty) for b in mine.bots]
    assert [(len(b.farm.cows), b.farm.slots, len(b.farm.fields)) for b in ref.bots] == [
        (len(b.farm.cows), b.farm.slots, len(b.farm.fields)) for b in mine.bots
    ]
    assert ref.stud.to_dict() == mine.game.stud.to_dict()


def test_numbers_match_research_note():
    """筆記 goals.json 是用現在這份參數跑的時候，服務層的數字和它相同；參數已經改過就 skip（等經濟代理重跑）。"""
    World, SB = research()
    if not GOALS.exists():
        pytest.skip("找不到 goals.json")
    g = json.loads(GOALS.read_text())
    if g.get("params_fingerprint") != H.DEFAULT.fingerprint():
        pytest.skip(f"goals.json 是參數 {g.get('params_fingerprint')} 跑的，現在是 {H.DEFAULT.fingerprint()}")
    with research_tunables(SB):
        row = g["a_price"]["10"]
        for cid in CIDS:
            inside = min(
                H.price_stats(ratios(H.ServiceWorld(H.base(10, s), s).run(), cid))["inside_soft_band"]
                for s in SEEDS[10]
            )
            assert inside == pytest.approx(row[cid]["inside_min"], abs=1e-12), cid


@pytest.mark.skipif(
    os.environ.get("COWFARM_SCENARIO_1000") != "1", reason="1,000 人 30 天約 1 分鐘；設 COWFARM_SCENARIO_1000=1 才跑"
)
def test_goals_1000_players():
    w = H.ServiceWorld(H.base(1000, 1), 1).run()
    for cid in CIDS:
        assert H.price_stats(ratios(w, cid))["inside_soft_band"] >= 0.95
    b = H.goal_b(w)
    assert max(b["week_max_over_min"]) <= 1.5
    assert 0.85 <= b["F_over_D"] <= 1.15
