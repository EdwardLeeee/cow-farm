"""讀 out/runs/ 的結果，算出 v0.2 各目標（v0.3 加照顧，goal_care）的實際數字，寫 out/goals.json 並印出摘要。

    cd docs/research/economy && python3 -m sim.report

v0.1 的結果保留在 out/v0.1/（這支程式不再讀它）。
"""

from __future__ import annotations

import csv
import json
import math
import statistics
import sys
from pathlib import Path
from typing import Dict, List, Optional

HERE = Path(__file__).resolve().parent.parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import sim  # noqa: E402,F401
from cowecon.farm import stud_fee  # noqa: E402
from cowecon.params import DEFAULT, HOUR  # noqa: E402
from sim import scenarios as S  # noqa: E402

RUNS = HERE / "out" / "runs"
OUT = HERE / "out"
STRATS = ("D", "B", "F", "C", "T", "L")
NAMES = {"D": "乳牛派", "B": "肉牛派", "F": "耕田派", "C": "配種收集派", "T": "抓時機派", "L": "出借公牛派"}
CIDS = tuple(DEFAULT.commodity_ids)
WHALE_CAP = 0.01  # 提出的上限：一位玩家一次倒貨，2 小時內價格最多低 1%（理論上限 0.75%）


def load(name: str) -> Optional[dict]:
    f = RUNS / f"{name}.json"
    return json.loads(f.read_text()) if f.exists() else None


def load_window(name: str) -> Dict[str, List[float]]:
    cols: Dict[str, List[float]] = {}
    with open(RUNS / f"{name}_window_1m.csv") as fh:
        for row in csv.DictReader(fh):
            for k, v in row.items():
                cols.setdefault(k, []).append(float(v))
    return cols


def base_runs(n: int) -> List[dict]:
    return [d for d in (load(f"base_{n}_s{s}") for s in S.POP_SEEDS.get(n, [])) if d]


# ---------------------------------------------------------------------------
# (a) 價格
# ---------------------------------------------------------------------------
def goal_a() -> dict:
    out = {}
    for n in S.POP_SEEDS:
        runs = base_runs(n)
        if not runs:
            continue
        row = {"seeds": len(runs), "days": runs[0]["scenario"]["days"]}
        for cid in CIDS:
            ps = [d["price"][cid] for d in runs]
            row[cid] = {
                "inside_min": min(p["inside_soft_band"] for p in ps),
                "inside_mean": statistics.fmean(p["inside_soft_band"] for p in ps),
                **{k: statistics.fmean(p[k] for p in ps) for k in ("p1", "p5", "p50", "p95", "p99", "mean", "log_sd", "daily_range_median", "worst_1h_drop", "max_drawdown")},
                "min": min(p["min"] for p in ps),
                "max": max(p["max"] for p in ps),
            }
        row["pressure_mean"] = {cid: statistics.fmean(d["pressure_mean"][cid] for d in runs) for cid in CIDS}
        row["online_mean"] = statistics.fmean(d["online"]["mean"] for d in runs)
        # D33（2026-10-03）起超級大事件 +100%、黑天鵝 −90% 照設計會把總價格帶出 0.6–1.7 倍，目標改成 ≥90%；
        # 新聞以外的部分 ≥95% 由 backend/tests/test_scenarios.py 的 test_price_band 擋（研究筆記第 11 節）
        row["pass"] = all(row[c]["inside_min"] >= 0.90 for c in CIDS)
        out[str(n)] = row
    return out


# ---------------------------------------------------------------------------
# (b) 各策略週收入、新增 a：耕田派 vs 乳牛派
# v0.3 起「週收入」= 收入（賣出＋借種）− 照顧花費（地板、小幫手、飼料、治療），使用者 2026-10-08 選的口徑；
# 只算收入的照舊列出（revenue_*），只當參考、不算過不過。
# ---------------------------------------------------------------------------
def goal_b() -> dict:
    out = {}
    for n in S.POP_SEEDS:
        runs = base_runs(n)
        if not runs:
            continue
        n_weeks = min(len(d["strategies"]["D"]["weeks"]) for d in runs)
        weeks = []
        for w in range(n_weeks):
            means = {k: statistics.fmean(d["strategies"][k]["weeks"][w]["care_net_mean"] for d in runs) for k in STRATS}
            rev = {k: statistics.fmean(d["strategies"][k]["weeks"][w]["revenue_mean"] for d in runs) for k in STRATS}
            parts = {k: {p: statistics.fmean(d["strategies"][k]["weeks"][w][p + "_mean"] for d in runs) for p in ("milk", "beef", "rice", "stud_in", "care_spend")} for k in STRATS}
            weeks.append({
                "week": w + 1,
                "means": means,
                "revenue_means": rev,
                "parts": parts,
                "max_over_min": max(means.values()) / min(means.values()),
                "revenue_max_over_min": max(rev.values()) / min(rev.values()),
                "top": max(means, key=means.get),
                "bottom": min(means, key=means.get),
                "F_over_D": means["F"] / means["D"],
            })
        tot = {k: sum(wk["means"][k] for wk in weeks) for k in STRATS}
        rev_tot = {k: sum(wk["revenue_means"][k] for wk in weeks) for k in STRATS}
        worth = {k: statistics.fmean(d["strategies"][k]["worth_end_mean"] for d in runs) for k in STRATS}
        net = {k: statistics.fmean(sum(x["net_mean"] for x in d["strategies"][k]["weeks"]) for d in runs) for k in STRATS}
        slots = {k: statistics.fmean(d["strategies"][k]["slots_end_mean"] for d in runs) for k in STRATS}
        fields = {k: statistics.fmean(d["strategies"][k]["fields_end_mean"] for d in runs) for k in STRATS}
        types = {k: [sum(d["strategies"][k]["type_counts_end"][i] for d in runs) for i in range(3)] for k in STRATS}
        tiers = {k: [sum(d["strategies"][k]["tier_counts_end"][i] for d in runs) for i in range(4)] for k in STRATS}
        f_over_d = [wk["F_over_D"] for wk in weeks]
        # 全服收入組成（各策略人數加權，28 天）
        comp = {p: 0.0 for p in ("milk", "beef", "rice", "stud_in")}
        for d in runs:
            for k in STRATS:
                st = d["strategies"][k]
                for wk_ in st["weeks"][:n_weeks]:
                    for p in comp:
                        comp[p] += st["n"] * wk_[p + "_mean"]
        comp_total = sum(comp.values())
        share = {p: v / comp_total for p, v in comp.items()}
        ranking = sorted(tot, key=tot.get, reverse=True)
        out[str(n)] = {
            "seeds": len(runs),
            "weeks": weeks,
            "total": tot,
            "total_max_over_min": max(tot.values()) / min(tot.values()),
            "total_top": max(tot, key=tot.get),
            "total_bottom": min(tot, key=tot.get),
            "total_F_over_D": tot["F"] / tot["D"],
            "week_max_over_min_worst": max(wk["max_over_min"] for wk in weeks),
            "revenue_total": rev_tot,
            "revenue_week_max_over_min_worst": max(wk["revenue_max_over_min"] for wk in weeks),
            "week_F_over_D_range": [min(f_over_d), max(f_over_d)],
            "net": net,
            "worth_end": worth,
            "slots_end": slots,
            "fields_end": fields,
            "type_counts_end": types,
            "tier_counts_end": tiers,
            "revenue_share": share,
            "ranking": ranking,
            "F_rank": ranking.index("F") + 1,
            "pass_spread": max(wk["max_over_min"] for wk in weeks) <= 1.5,
            "pass_farm_vs_dairy": 0.93 <= tot["F"] / tot["D"] <= 1.07,
            "pass_milk_share": 0.25 <= share["milk"] <= 0.40,
        }
    return out


# ---------------------------------------------------------------------------
# v0.3 照顧（docs/design/v0.3-care.md 第 9 節）
# ---------------------------------------------------------------------------
CARE_ALL = STRATS + ("Z",)


def goal_care() -> dict:
    """各人數、各玩法（含 Z 懶得照顧）：病牛的時間比例、飼料回報（豆粕看 B）、懶得照顧少賺多少、
    小幫手（打掃牛）＋地板＋治療＋掃地機佔收入、最後有掃地機的比例、稀有小牛變雜種的比例。各 seed 加總再算比例。"""
    out = {}
    for n in S.POP_SEEDS:
        runs = [d for d in base_runs(n) if "care" in d]
        if not runs:
            continue
        row = {}
        for k in CARE_ALL:
            cs = [d["care"][k] for d in runs if k in d["care"]]
            if not cs:
                continue

            def tot(key):
                return sum(c[key] * c["n"] for c in cs)

            rev, feed, rare = tot("revenue"), tot("feed_spend"), tot("rare_grown")
            row[k] = {
                "revenue_mean": rev / sum(c["n"] for c in cs),
                "care_net_mean": (rev - tot("helper_spend") - tot("floor_spend") - tot("cure_spend") - tot("robot_spend") - feed)
                / sum(c["n"] for c in cs),
                "sick_share": statistics.fmean(c["sick_share"] for c in cs),
                "feed_roi": tot("bonus_value") / feed if feed else None,
                "feed_share": feed / rev if rev else None,
                "care_spend_share": (tot("helper_spend") + tot("floor_spend") + tot("cure_spend") + tot("robot_spend")) / rev
                if rev else None,
                "helper_share": tot("helper_spend") / rev if rev else None,
                "robot_share": tot("robot_spend") / rev if rev else None,
                "robot_owners": tot("robot_owners") / sum(c["n"] for c in cs),
                "sick_per_player": tot("sick") / sum(c["n"] for c in cs),
                "cures_per_player": tot("cures") / sum(c["n"] for c in cs),
                "hybrid_share": tot("hybrid") / rare if rare else None,
            }
        care = [row[k] for k in STRATS if k in row]
        lazy = row.get("Z")
        row["summary"] = {
            "sick_share_max": max(r["sick_share"] for r in care),
            # 收入 − 照顧花費（跟玩法差距同一個口徑）；只算收入的列在 lazy_over_D_revenue 當參考
            "lazy_over_D": lazy["care_net_mean"] / row["D"]["care_net_mean"] if lazy and "D" in row else None,
            "lazy_over_D_revenue": lazy["revenue_mean"] / row["D"]["revenue_mean"] if lazy and "D" in row else None,
            "lazy_over_care_mean": lazy["care_net_mean"] / statistics.fmean(r["care_net_mean"] for r in care) if lazy else None,
            "care_spend_share_range": [min(r["care_spend_share"] for r in care), max(r["care_spend_share"] for r in care)],
            "soymeal_roi_B": row["B"]["feed_roi"] if "B" in row else None,
        }
        sm = row["summary"]
        sm["pass_sick"] = sm["sick_share_max"] < 0.02
        sm["pass_lazy"] = sm["lazy_over_D"] is not None and 0.6 <= sm["lazy_over_D"] <= 0.8
        sm["pass_soymeal_roi"] = sm["soymeal_roi_B"] is not None and 1.5 <= sm["soymeal_roi_B"] <= 2.5
        sm["pass_spend_share"] = 0.05 <= sm["care_spend_share_range"][0] and sm["care_spend_share_range"][1] <= 0.20  # ceo 2026-10-08 放寬到 20%
        out[str(n)] = row
    return out


# ---------------------------------------------------------------------------
# (c) 大戶拋售
# ---------------------------------------------------------------------------
def _gap_stats(t: List[float], p_a: List[float], p_b: List[float], t_evt: float, direct_h: float = 3.0, horizon_h: float = 18.0) -> dict:
    """p_a 相對 p_b（對照組，同 seed）的差距。max_drop_direct：事件後 direct_h 小時內的最大跌幅；
    recover_90pct_h：之後差距縮到最大值一成以內要幾小時（最大跌幅 < 0.3% 時不算）。"""
    direct, full = [], []
    for th, a, b in zip(t, p_a, p_b):
        if t_evt <= th <= t_evt + horizon_h:
            g = 1.0 - a / b
            full.append((th, g))
            if th <= t_evt + direct_h:
                direct.append((th, g))
    if not direct:
        return {}
    t_max, g_max = max(direct, key=lambda x: x[1])
    rec90 = None
    if g_max >= 0.003:
        for th, g in full:
            if th >= t_max and g <= 0.1 * g_max:
                rec90 = th - t_evt
                break
    pre = [abs(1.0 - a / b) for th, a, b in zip(t, p_a, p_b) if th < t_evt]
    return {
        "max_drop_direct": g_max,
        "t_max_h": t_max - t_evt,
        "recover_90pct_h": rec90,
        "max_drop_18h": max(g for _, g in full),
        "pre_event_max_abs_diff": max(pre) if pre else None,
    }


def _hours_of_flow(run: str, cid: str, units) -> Optional[float]:
    """大戶倒出的量相當於「其他玩家平常幾小時的賣出量」（估計：對照組第 3 週賣出收入 ÷ 基本價 ÷ 168）。"""
    if not units:
        return None
    summ = load(run)
    base = DEFAULT.commodity(cid).base_price
    coins = sum(st["n"] * st["weeks"][2][cid + "_mean"] for k, st in summ["strategies"].items() if k != "W")
    per_h = coins / base / 168.0
    return units / per_h if per_h > 0 else None


def goal_c() -> dict:
    cp = DEFAULT.milk
    k_y = math.log(2) / (cp.pressure_half_life_s / HOUR)
    bound_dump = 1 - math.exp(-cp.pressure_down_per_h * cp.player_cap_frac * cp.player_cap_window_s / HOUR)
    bound_sustained = 1 - math.exp(-cp.pressure_down_per_h * cp.player_cap_frac / k_y)
    out = {"bound_single_dump": bound_dump, "bound_single_player_sustained": bound_sustained, "pressure_half_life_h": cp.pressure_half_life_s / HOUR, "cases": {}}
    for n, cows in ((10, 100), (100, 100), (1000, 100), (100, 1000), (1000, 1000)):
        names = {m: f"whale_{n}_{cows}cows_{m}_s1" for m in ("hold", "dump", "batch")}
        if not all((RUNS / f"{v}.json").exists() for v in names.values()):
            continue
        win = {m: load_window(v) for m, v in names.items()}
        summ = {m: load(v) for m, v in names.items()}
        case = {"players": n, "whale_cows": cows}
        for cid in ("milk", "beef"):
            case[cid] = {
                "dump_vs_hold": _gap_stats(win["dump"]["t_h"], win["dump"][cid], win["hold"][cid], S.DUMP_H, direct_h=2.0),
                "batch_vs_hold": _gap_stats(win["batch"]["t_h"], win["batch"][cid], win["hold"][cid], S.DUMP_H, direct_h=24.0, horizon_h=30.0),
            }
            td = summ["dump"]["whale"]["totals"].get(cid, {})
            tb = summ["batch"]["whale"]["totals"].get(cid, {})
            case[cid]["dump_units"] = td.get("units")
            case[cid]["dump_avg_price"] = td.get("avg_price")
            case[cid]["dump_avg_market"] = td.get("avg_market_price")
            case[cid]["batch_avg_price"] = tb.get("avg_price")
            case[cid]["batch_avg_market"] = tb.get("avg_market_price")
            if td.get("avg_price") and tb.get("avg_price"):
                case[cid]["dump_over_batch"] = td["avg_price"] / tb["avg_price"]
                case[cid]["dump_slip"] = 1 - td["avg_price"] / td["avg_market_price"]
                case[cid]["batch_slip"] = 1 - tb["avg_price"] / tb["avg_market_price"]
            case[cid]["dump_hours_of_server_flow"] = _hours_of_flow(names["hold"], cid, td.get("units"))
        case["pass_drop"] = all(case[c]["dump_vs_hold"].get("max_drop_direct", 1) <= WHALE_CAP for c in ("milk", "beef"))
        out["cases"][f"{n}p_{cows}cows"] = case
    return out


# ---------------------------------------------------------------------------
# (d) 新手
# ---------------------------------------------------------------------------
def goal_d() -> dict:
    vals = {"first_sale": [], "first_expand": [], "first_breed": []}
    of = 0
    for n, seeds in S.POP_SEEDS.items():
        for s in seeds:
            f = RUNS / f"base_{n}_s{s}_players.csv"
            if not f.exists():
                continue
            with open(f) as fh:
                for row in csv.DictReader(fh):
                    if row["strategy"] == "W":
                        continue
                    of += 1
                    for k, col in (("first_sale", "first_sale_min"), ("first_expand", "first_expand_min"), ("first_breed", "first_breed_min")):
                        if row[col]:
                            vals[k].append(float(row[col]))

    def q(xs, p):
        xs = sorted(xs)
        return xs[min(len(xs) - 1, int(p * len(xs)))] if xs else None

    out = {"players": of}
    for k, xs in vals.items():
        out[k] = {"n": len(xs), "median": q(xs, 0.5), "p10": q(xs, 0.1), "p90": q(xs, 0.9), "max": max(xs) if xs else None, "min": min(xs) if xs else None}
    out["pass"] = (
        out["first_sale"]["n"] == of and out["first_sale"]["max"] <= 5
        and out["first_breed"]["n"] == of and out["first_breed"]["max"] <= 30
    )
    return out


# ---------------------------------------------------------------------------
# 新增 b：借種市場
# ---------------------------------------------------------------------------
def goal_stud() -> dict:
    fp = DEFAULT.farm
    milk_day = fp.milk_per_h[0] * 24 * DEFAULT.milk.base_price  # 一頭壯年乳牛一天的奶錢（基本價）
    top = stud_fee(fp, 2, 3, None, 0.0)[0]  # D26：最貴的是長到最壯的傳說肉牛公牛
    out = {"milk_money_per_day": milk_day, "top_price": top, "top_price_days_of_milk": top / milk_day, "pops": {}}
    for n in S.POP_SEEDS:
        runs = base_runs(n)
        if not runs:
            continue
        days = runs[0]["scenario"]["days"]
        st = [d["stud"] for d in runs]
        by_price: Dict[str, float] = {}
        for x in st:
            for k, v in x["by_price"].items():
                by_price[k] = by_price.get(k, 0) + v / len(st)
        lender_week = [x["lender_income_mean"] / days * 7 for x in st]
        out["pops"][str(n)] = {
            "trades_per_day": statistics.fmean(x["trades"] for x in st) / days,
            "trades_per_player_day": statistics.fmean(x["trades"] for x in st) / days / n,
            "share_player_listing": statistics.fmean(x["trades_player_listing"] / x["trades"] if x["trades"] else 0 for x in st),
            "by_price_mean": by_price,
            "lender_income_per_week": statistics.fmean(lender_week),
            "lender_income_share": statistics.fmean(x["lender_income_share"] for x in st),
            "lender_income_max_30d": max(x["lender_income_max"] for x in st),
            "max_trade_price": max(x["max_trade_price"] for x in st),
        }
    pops = out["pops"]
    out["pass"] = all(p["trades_per_day"] > 0 and p["lender_income_share"] < 0.2 for p in pops.values()) if pops else False
    return out


# ---------------------------------------------------------------------------
# 新增 c：商店 A／B／C
# ---------------------------------------------------------------------------
def goal_shop() -> dict:
    from cowecon.farm import shop_grade_tier_probs

    fp = DEFAULT.farm
    out = {"grades": {}, "pops": {}}
    for gi, g in enumerate(fp.shop_grade_names):
        out["grades"][g] = {"price": fp.shop_grade_price[gi], "tier_probs": shop_grade_tier_probs(fp, g)}
    for n in S.POP_SEEDS:
        runs = base_runs(n)
        if not runs:
            continue
        shares = {}
        tot = {g: sum(d["shop"]["all"][g] for d in runs) for g in ("A", "B", "C")}
        s = sum(tot.values())
        shares = {g: tot[g] / s if s else 0.0 for g in tot}
        per_strategy = {k: {g: sum(d["shop"][k][g] for d in runs) for g in ("A", "B", "C")} for k in STRATS}
        vals = {}
        for g in ("A", "B", "C"):
            items = [(d["value"]["origin"][g]["n"], d["value"]["origin"][g]["mean"]) for d in runs if g in d["value"]["origin"]]
            nn = sum(i[0] for i in items)
            if nn:
                vals[g] = {"n": nn, "mean": sum(i[0] * i[1] for i in items) / nn}
        out["pops"][str(n)] = {"shares": shares, "per_strategy": per_strategy, "value": vals}
    # 以 1,000 人（seed 1、2）的實際價值判斷
    ref = out["pops"].get("1000") or next(iter(out["pops"].values()), None)
    if ref and len(ref["value"]) == 3:
        surplus = {g: ref["value"][g]["mean"] - out["grades"][g]["price"] for g in ("A", "B", "C")}
        per_coin = {g: ref["value"][g]["mean"] / out["grades"][g]["price"] for g in ("A", "B", "C")}
        out["surplus"] = surplus
        out["value_per_coin"] = per_coin
        out["surplus_max_over_min"] = max(surplus.values()) / min(surplus.values())
        out["pass"] = out["surplus_max_over_min"] <= 1.10 and all(v >= 0.10 for v in ref["shares"].values())
    return out


# ---------------------------------------------------------------------------
# 其他情境
# ---------------------------------------------------------------------------
def panic_scenario() -> dict:
    out = {}
    for n in (100, 1000):
        a, b = f"event_{n}_panic_s1", f"event_{n}_calm_s1"
        if not ((RUNS / f"{a}.json").exists() and (RUNS / f"{b}.json").exists()):
            continue
        wp, wc = load_window(a), load_window(b)
        row = {}
        for cid in CIDS:
            g = _gap_stats(wp["t_h"], wp[cid], wc[cid], S.EVENT_H + 0.25)
            pre = [p for th, p in zip(wc["t_h"], wc[cid]) if S.EVENT_H - 1 <= th < S.EVENT_H]
            peak_calm = max(p for th, p in zip(wc["t_h"], wc[cid]) if S.EVENT_H <= th <= S.EVENT_H + 3)
            row[cid] = {**g, "pre_price": statistics.fmean(pre), "peak_calm": peak_calm}
        row["online_peak_panic"] = max(o for th, o in zip(wp["t_h"], wp["online"]) if S.EVENT_H <= th <= S.EVENT_H + 2)
        row["online_peak_calm"] = max(o for th, o in zip(wc["t_h"], wc["online"]) if S.EVENT_H <= th <= S.EVENT_H + 2)
        out[str(n)] = row
    return out


def low_scenario() -> dict:
    out = {}
    for n in (100, 1000):
        a, b = f"low_{n}_s1", f"low_{n}_s1_ref"
        if not ((RUNS / f"{a}.json").exists() and (RUNS / f"{b}.json").exists()):
            continue
        wl, wr = load_window(a), load_window(b)
        d0, d1 = S.LOW_DAY * 24, S.LOW_DAY * 24 + 24
        row = {}
        for label, w in (("low", wl), ("ref", wr)):
            sel = [i for i, th in enumerate(w["t_h"]) if d0 <= th < d1]
            row[label] = {"online_mean": statistics.fmean(w["online"][i] for i in sel)}
            for cid in CIDS:
                row[label][cid + "_mean"] = statistics.fmean(w[cid][i] for i in sel)
        for cid in CIDS:
            ratio = [wl[cid][i] / wr[cid][i] for i, th in enumerate(wl["t_h"]) if d0 <= th < d1]
            row[cid + "_low_over_ref_mean"] = statistics.fmean(ratio)
            row[cid + "_low_over_ref_max"] = max(ratio)
            row[cid + "_low_over_ref_min"] = min(ratio)
        out[str(n)] = row
    return out


def tick_compare() -> dict:
    out = {}
    for seed in (1, 2):
        a, b = load(f"base_1000_s{seed}"), load(f"base_1000_s{seed}_tick300")
        if not (a and b):
            continue
        row = {}
        for cid in CIDS:
            row[cid] = {k: {"tick60": a["price"][cid][k], "tick300": b["price"][cid][k]} for k in ("inside_soft_band", "p5", "p50", "p95", "log_sd", "daily_range_median")}
            row[cid]["pressure_mean"] = {"tick60": a["pressure_mean"][cid], "tick300": b["pressure_mean"][cid]}
        row["revenue_28d"] = {k: {"tick60": a["strategies"][k]["revenue_total_mean"], "tick300": b["strategies"][k]["revenue_total_mean"]} for k in STRATS}
        row["wall_s"] = {"tick60": a["wall"]["seconds"], "tick300": b["wall"]["seconds"]}
        out[f"s{seed}"] = row
    a, b = load("base_1000_s1"), load("base_1000_s2")
    if a and b:
        out["seed_to_seed_tick60"] = {cid: {"p50": [a["price"][cid]["p50"], b["price"][cid]["p50"]], "log_sd": [a["price"][cid]["log_sd"], b["price"][cid]["log_sd"]]} for cid in CIDS}
    return out


def beef_grades() -> dict:
    out = {}
    for n in S.POP_SEEDS:
        runs = base_runs(n)
        if runs:
            tot = {g: sum(d["beef_grades"][g] for d in runs) for g in ("A", "B", "C")}
            s = sum(tot.values())
            out[str(n)] = {g: tot[g] / s for g in tot} if s else {}
    return out


def walls() -> dict:
    out = {}
    for f in sorted(RUNS.glob("*.json")):
        d = json.loads(f.read_text())
        out[f.stem] = {"players": d["players"], "tick_s": d["tick_s"], "days": d["scenario"]["days"], "seconds": round(d["wall"].get("total_seconds", d["wall"]["seconds"]), 1), "actions": d["wall"].get("actions")}
    return out


def main() -> None:
    goals = {
        "engine_version": "0.3.0",
        "params_fingerprint": DEFAULT.fingerprint(),
        "a_price": goal_a(),
        "b_strategies": goal_b(),
        "c_whale": goal_c(),
        "d_onboarding": goal_d(),
        "new_b_stud": goal_stud(),
        "new_c_shop": goal_shop(),
        "beef_grades": beef_grades(),
        "care": goal_care(),
        "panic_after_event": panic_scenario(),
        "low_online_day": low_scenario(),
        "tick_60_vs_300": tick_compare(),
        "wall": walls(),
    }
    bs = goals["b_strategies"]
    goals["farm_not_always_top"] = {
        "F_rank_by_pop": {n: bs[n]["F_rank"] for n in ("10", "100", "1000") if n in bs},
        "pass": any(bs[n]["F_rank"] > 1 for n in ("10", "100", "1000") if n in bs),
    }
    (OUT / "goals.json").write_text(json.dumps(goals, ensure_ascii=False, indent=1))
    print("(a) 價格在 0.6–1.7 倍的時間（各 seed 最低）")
    for n, row in goals["a_price"].items():
        print(f"  {n:>6} 人（{row['days']} 天）: " + "  ".join(f"{c} {row[c]['inside_min']:.4f}（p1–p99 {row[c]['p1']:.2f}–{row[c]['p99']:.2f}）" for c in CIDS) + f"  pass={row['pass']}")
    print("(b) 各策略收入 − 照顧花費（千幣）；新增 a 耕田÷乳牛；括號是只算收入的（參考）")
    for n, row in goals["b_strategies"].items():
        tot = " ".join(f"{k}:{v / 1000:.0f}" for k, v in row["total"].items())
        wk = " ".join(f"{w['max_over_min']:.2f}（{w['revenue_max_over_min']:.2f}）" for w in row["weeks"])
        print(f"  {n:>6} 人: {tot}  合計 max/min={row['total_max_over_min']:.3f} 排名={''.join(row['ranking'])}（耕田第 {row['F_rank']}）  每週 max/min={wk}  F/D={row['total_F_over_D']:.3f}（每週 {row['week_F_over_D_range'][0]:.2f}–{row['week_F_over_D_range'][1]:.2f}）  牛奶佔 {row['revenue_share']['milk']:.1%}")
    c = goals["c_whale"]
    print(f"(c) 大戶：理論上限 一次倒貨 {c['bound_single_dump']:.2%}、持續賣 {c['bound_single_player_sustained']:.2%}")
    for k, case in c["cases"].items():
        for cid in ("milk", "beef"):
            g = case[cid]["dump_vs_hold"]
            print(f"  {k} {cid}: 倒出≈全服 {case[cid].get('dump_hours_of_server_flow') or float('nan'):.1f} 小時；2 小時內最多低 {g.get('max_drop_direct', float('nan')):.2%}；滑價 倒 {case[cid].get('dump_slip', float('nan')):.1%} vs 分批 {case[cid].get('batch_slip', float('nan')):.1%}；均價 倒/分批 {case[cid].get('dump_over_batch', float('nan')):.3f}")
    d = goals["d_onboarding"]
    print(f"(d) 新手（{d['players']} 人）：" + "  ".join(f"{k} 中位 {v['median']}、最慢 {v['max']}（{v['n']} 人）" for k, v in d.items() if isinstance(v, dict)) + f" pass={d['pass']}")
    sb = goals["new_b_stud"]
    print(f"新增 b 借種：最高價 {sb['top_price']:.0f} ≈ {sb['top_price_days_of_milk']:.2f} 天奶錢（{sb['milk_money_per_day']:.0f}/天）")
    for n, p in sb["pops"].items():
        print(f"  {n:>6} 人: 每天 {p['trades_per_day']:.1f} 筆（每人 {p['trades_per_player_day']:.2f}），玩家上架 {p['share_player_listing']:.0%}，出借派收入 {p['lender_income_per_week']:.0f}/週、佔 {p['lender_income_share']:.1%}，最高成交 {p['max_trade_price']:.0f}")
    sh = goals["new_c_shop"]
    if "surplus" in sh:
        print("新增 c 商店：" + "  ".join(f"{g} 價 {sh['grades'][g]['price']:.0f} 淨賺 {sh['surplus'][g]:.0f} 每元 {sh['value_per_coin'][g]:.1f}" for g in ("A", "B", "C")) + f"  淨賺 max/min {sh['surplus_max_over_min']:.3f} pass={sh.get('pass')}")
    for n, p in sh["pops"].items():
        print(f"  {n:>6} 人 份額: " + " ".join(f"{g} {p['shares'][g]:.0%}" for g in ("A", "B", "C")))
    print("v0.3 照顧：病牛時間（照顧好的最高）、懶得照顧÷乳牛派、小幫手＋地板＋治療佔收入、豆粕回報（B）")
    for n, row in goals["care"].items():
        sm = row["summary"]
        print(
            f"  {n:>6} 人: 病牛 {sm['sick_share_max']:.2%}  懶得照顧÷乳牛 {sm['lazy_over_D']:.2f}  "
            f"花費 {sm['care_spend_share_range'][0]:.1%}–{sm['care_spend_share_range'][1]:.1%}  豆粕回報 {sm['soymeal_roi_B']:.2f}  "
            + " ".join(f"{k}:回報{row[k]['feed_roi'] or 0:.2f}/雜種{row[k]['hybrid_share'] or 0:.0%}" for k in CARE_ALL if k in row)
        )
    print("出貨評級：" + "  ".join(f"{n} 人 " + "/".join(f"{v:.0%}" for v in r.values()) for n, r in goals["beef_grades"].items()))
    for n, row in goals["panic_after_event"].items():
        print(f"  恐慌賣 {n} 人: " + "  ".join(f"{cid} 多跌 {row[cid].get('max_drop_direct', 0):.2%} 回復九成 {row[cid].get('recover_90pct_h')}" for cid in CIDS))
    for n, row in goals["low_online_day"].items():
        print(f"  人少 {n} 人: 線上 {row['ref']['online_mean']:.1f}→{row['low']['online_mean']:.1f} " + "  ".join(f"{cid} 人少÷平常 {row[cid + '_low_over_ref_mean']:.3f}" for cid in CIDS))
    for seed, t in goals["tick_60_vs_300"].items():
        if not seed[1:].isdigit():
            continue
        print(f"  tick 60/300（{seed}）: " + "  ".join(f"{cid} p50 {t[cid]['p50']['tick60']:.3f}/{t[cid]['p50']['tick300']:.3f} 賣壓 {t[cid]['pressure_mean']['tick60']:+.3f}/{t[cid]['pressure_mean']['tick300']:+.3f}" for cid in CIDS))
        print("    收入 " + " ".join(f"{k} {v['tick60'] / 1000:.0f}/{v['tick300'] / 1000:.0f}" for k, v in t["revenue_28d"].items()))


if __name__ == "__main__":
    main()
