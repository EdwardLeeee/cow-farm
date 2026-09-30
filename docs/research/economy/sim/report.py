"""讀 out/runs/ 的結果，算出四個目標的實際數字，寫 out/goals.json 並印出摘要。

    cd docs/research/economy && python3 -m sim.report
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
import sim  # noqa: E402,F401  （把 backend/ 加進 sys.path；cowecon 在 backend/cowecon/）

from cowecon.params import DEFAULT, HOUR  # noqa: E402
from sim import scenarios as S  # noqa: E402

RUNS = HERE / "out" / "runs"
OUT = HERE / "out"
STRATS = ("S1", "S2", "S3", "S4")


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


# ---------------------------------------------------------------------------
# (a) 價格
# ---------------------------------------------------------------------------
def goal_a() -> dict:
    out = {}
    for n, seeds in S.POP_SEEDS.items():
        runs = [d for d in (load(f"base_{n}_s{s}") for s in seeds) if d]
        if not runs:
            continue
        row = {"seeds": len(runs)}
        for cid in ("milk", "beef"):
            ps = [d["price"][cid] for d in runs]
            row[cid] = {
                "inside_min": min(p["inside_soft_band"] for p in ps),
                "inside_mean": statistics.fmean(p["inside_soft_band"] for p in ps),
                **{k: statistics.fmean(p[k] for p in ps) for k in ("p1", "p5", "p50", "p95", "p99", "mean", "log_sd", "daily_range_median", "worst_1h_drop", "max_drawdown")},
                "min": min(p["min"] for p in ps),
                "max": max(p["max"] for p in ps),
            }
        row["excess_mean"] = {cid: statistics.fmean(d["excess_mean"][cid] for d in runs) for cid in ("milk", "beef")}
        row["pressure_mean"] = {cid: statistics.fmean(d["pressure_mean"][cid] for d in runs) for cid in ("milk", "beef")}
        row["online_mean"] = statistics.fmean(d["online"]["mean"] for d in runs)
        row["pass"] = all(row[c]["inside_min"] >= 0.95 for c in ("milk", "beef"))
        out[str(n)] = row
    return out


# ---------------------------------------------------------------------------
# (b) 各策略週收入
# ---------------------------------------------------------------------------
def goal_b() -> dict:
    out = {}
    for n, seeds in S.POP_SEEDS.items():
        runs = [d for d in (load(f"base_{n}_s{s}") for s in seeds) if d]
        if not runs:
            continue
        weeks = []
        for w in range(4):
            means = {k: statistics.fmean(d["strategies"][k]["weeks"][w]["revenue_mean"] for d in runs) for k in STRATS}
            weeks.append({
                "week": w + 1,
                "means": means,
                "max_over_min": max(means.values()) / min(means.values()),
                "top": max(means, key=means.get),
                "S4_over_S1": means["S4"] / means["S1"],
            })
        tot = {k: sum(wk["means"][k] for wk in weeks) for k in STRATS}
        worth = {k: statistics.fmean(d["strategies"][k]["worth_end_mean"] for d in runs) for k in STRATS}
        net = {k: statistics.fmean(sum(x["net_mean"] for x in d["strategies"][k]["weeks"]) for d in runs) for k in STRATS}
        herd = {k: statistics.fmean(d["strategies"][k]["slots_end_mean"] for d in runs) for k in STRATS}
        tiers = {k: [sum(d["strategies"][k]["tier_counts_end"][i] for d in runs) for i in range(4)] for k in STRATS}
        out[str(n)] = {
            "seeds": len(runs),
            "weeks": weeks,
            "total_28d": tot,
            "total_max_over_min": max(tot.values()) / min(tot.values()),
            "total_top": max(tot, key=tot.get),
            "total_S4_over_S1": tot["S4"] / tot["S1"],
            "week_max_over_min_worst": max(wk["max_over_min"] for wk in weeks),
            "net_28d": net,
            "worth_end": worth,
            "slots_end": herd,
            "tier_counts_end": tiers,
            "pass_spread": max(wk["max_over_min"] for wk in weeks) <= 1.5,
            "pass_s4_top_total": max(tot, key=tot.get) == "S4",
        }
    return out


# ---------------------------------------------------------------------------
# (c) 大戶拋售
# ---------------------------------------------------------------------------
def _gap_stats(t: List[float], p_a: List[float], p_b: List[float], t_evt: float, direct_h: float = 3.0, horizon_h: float = 18.0) -> dict:
    """p_a 相對 p_b（對照組，同 seed）的差距。

    - max_drop_direct：事件後 direct_h 小時內的最大跌幅 = 這個動作本身造成的影響。
    - max_drop_18h：18 小時內的最大差距；之後其他 bot 看到不同價格而做了不同決定，路徑會慢慢分岔（蝴蝶效應），
      這部分不算「倒貨造成的下跌」，只列出來參考。
    - recover_90pct_h：直接影響的最大跌幅之後，差距縮到最大值一成以內要幾小時（最大跌幅 < 0.3% 時視為無明顯下跌，不算）。
    """
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
    """大戶倒出的量相當於「其他玩家平常幾小時的賣出量」（估計）。

    用對照組第 3 週（第 15–21 天）S1–S4 的賣出收入 ÷ 基本價 ÷ 168 小時估全服每小時賣出量；
    市價平均在基本價 ±5% 內，所以誤差約 ±5%。
    """
    if not units:
        return None
    summ = load(run)
    base = DEFAULT.commodity(cid).base_price
    kind = "milk_mean" if cid == "milk" else "beef_mean"
    coins = sum(st["n"] * st["weeks"][2][kind] for k, st in summ["strategies"].items() if k != "S5")
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
                # 扣掉「分批期間市價本來就在變」的影響：只比滑價（成交價 ÷ 成交當下市價）
                case[cid]["dump_slip"] = 1 - td["avg_price"] / td["avg_market_price"]
                case[cid]["batch_slip"] = 1 - tb["avg_price"] / tb["avg_market_price"]
            # 大戶倒出的量相當於全服平常幾小時的賣出量（用對照組倒貨前 24 小時的流量估）
            case[cid]["dump_hours_of_server_flow"] = _hours_of_flow(names["hold"], cid, td.get("units"))
        case["pass_drop"] = all(case[c]["dump_vs_hold"].get("max_drop_direct", 1) <= 0.15 for c in ("milk", "beef"))
        case["pass_dump_worse_slippage"] = all(case[c].get("dump_slip", 0) > case[c].get("batch_slip", 1) for c in ("milk", "beef"))
        case["pass_dump_worse_raw"] = all(case[c].get("dump_over_batch", 2) < 1.0 for c in ("milk", "beef"))
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
        out["first_sale"]["max"] is not None and out["first_sale"]["max"] <= 5
        and out["first_breed"]["max"] is not None and out["first_breed"]["max"] <= 30 and out["first_breed"]["n"] == of
        and out["first_expand"]["median"] is not None and 10 <= out["first_expand"]["median"] <= 20
    )
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
        for cid in ("milk", "beef"):
            g = _gap_stats(wp["t_h"], wp[cid], wc[cid], S.EVENT_H + 0.25)
            pre = [p for th, p in zip(wc["t_h"], wc[cid]) if S.EVENT_H - 1 <= th < S.EVENT_H]
            peak_calm = max(p for th, p in zip(wc["t_h"], wc[cid]) if S.EVENT_H <= th <= S.EVENT_H + 3)
            peak_panic = max(p for th, p in zip(wp["t_h"], wp[cid]) if S.EVENT_H <= th <= S.EVENT_H + 3)
            low_panic = min(p for th, p in zip(wp["t_h"], wp[cid]) if S.EVENT_H <= th <= S.EVENT_H + 6)
            row[cid] = {**g, "pre_price": statistics.fmean(pre), "peak_calm": peak_calm, "peak_panic": peak_panic, "low_panic_6h": low_panic}
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
            row[label] = {
                "online_mean": statistics.fmean(w["online"][i] for i in sel),
                "milk_mean": statistics.fmean(w["milk"][i] for i in sel),
                "beef_mean": statistics.fmean(w["beef"][i] for i in sel),
                "milk_min": min(w["milk"][i] for i in sel),
                "milk_max": max(w["milk"][i] for i in sel),
                "milk_excess_mean": statistics.fmean(w["milk_e"][i] for i in sel),
                "beef_excess_mean": statistics.fmean(w["beef_e"][i] for i in sel),
                "milk_y_mean": statistics.fmean(w["milk_y"][i] for i in sel),
            }
        ratio = [wl["milk"][i] / wr["milk"][i] for i, th in enumerate(wl["t_h"]) if d0 <= th < d1]
        row["milk_low_over_ref_mean"] = statistics.fmean(ratio)
        row["milk_low_over_ref_max"] = max(ratio)
        out[str(n)] = row
    return out


def tick_compare() -> dict:
    """同一個 seed 用 1 分鐘與 5 分鐘 tick 跑，比較價格分布與各策略收入（兩個 seed）。"""
    out = {}
    for seed in (1, 2):
        a, b = load(f"base_1000_s{seed}"), load(f"base_1000_s{seed}_tick300")
        if not (a and b):
            continue
        row = {}
        for cid in ("milk", "beef"):
            row[cid] = {k: {"tick60": a["price"][cid][k], "tick300": b["price"][cid][k]} for k in ("inside_soft_band", "p5", "p50", "p95", "log_sd", "daily_range_median")}
            row[cid]["pressure_mean"] = {"tick60": a["pressure_mean"][cid], "tick300": b["pressure_mean"][cid]}
        row["revenue_28d"] = {k: {"tick60": a["strategies"][k]["revenue_total_mean"], "tick300": b["strategies"][k]["revenue_total_mean"]} for k in STRATS}
        row["wall_s"] = {"tick60": a["wall"]["seconds"], "tick300": b["wall"]["seconds"]}
        out[f"s{seed}"] = row
    # 參考：同樣 1 分鐘 tick、不同 seed 的差距（隨機性本身有多大）
    a, b = load("base_1000_s1"), load("base_1000_s2")
    if a and b:
        out["seed_to_seed_tick60"] = {cid: {"p50": [a["price"][cid]["p50"], b["price"][cid]["p50"]], "log_sd": [a["price"][cid]["log_sd"], b["price"][cid]["log_sd"]]} for cid in ("milk", "beef")}
    return out


def walls() -> dict:
    out = {}
    for f in sorted(RUNS.glob("*.json")):
        d = json.loads(f.read_text())
        out[f.stem] = {"players": d["players"], "tick_s": d["tick_s"], "seconds": round(d["wall"].get("total_seconds", d["wall"]["seconds"]), 1), "actions": d["wall"].get("actions")}
    return out


def main() -> None:
    goals = {
        "params_fingerprint": DEFAULT.fingerprint(),
        "a_price": goal_a(),
        "b_strategies": goal_b(),
        "c_whale": goal_c(),
        "d_onboarding": goal_d(),
        "panic_after_event": panic_scenario(),
        "low_online_day": low_scenario(),
        "tick_60_vs_300": tick_compare(),
        "wall": walls(),
    }
    (OUT / "goals.json").write_text(json.dumps(goals, ensure_ascii=False, indent=1))
    a = goals["a_price"]
    print("(a) 價格在 0.6–1.7 倍的時間比例（各 seed 最低）")
    for n, row in a.items():
        print(f"  {n:>6} 人: 牛奶 {row['milk']['inside_min']:.4f}  牛肉 {row['beef']['inside_min']:.4f}  "
              f"牛奶 p1–p99 {row['milk']['p1']:.2f}–{row['milk']['p99']:.2f}  牛肉 p1–p99 {row['beef']['p1']:.2f}–{row['beef']['p99']:.2f}  pass={row['pass']}")
    print("(b) 各策略 28 天收入（千幣）與最大/最小")
    for n, row in goals["b_strategies"].items():
        tot = " ".join(f"{k}:{v / 1000:.0f}" for k, v in row["total_28d"].items())
        wk = " ".join(f"{w['max_over_min']:.2f}" for w in row["weeks"])
        print(f"  {n:>6} 人: {tot}  總計 max/min={row['total_max_over_min']:.3f} top={row['total_top']} S4/S1={row['total_S4_over_S1']:.3f}  每週 max/min={wk}")
    c = goals["c_whale"]
    print(f"(c) 大戶：理論上限 一次倒貨 {c['bound_single_dump']:.2%}、持續賣 {c['bound_single_player_sustained']:.2%}")
    for k, case in c["cases"].items():
        for cid in ("milk", "beef"):
            g = case[cid]["dump_vs_hold"]
            print(f"  {k} {cid}: 倒出量≈全服 {case[cid].get('dump_hours_of_server_flow') or float('nan'):.1f} 小時的量；2 小時內最大跌幅 {g.get('max_drop_direct', float('nan')):.2%}（{g.get('t_max_h', float('nan')):.2f}h），90%回復 {g.get('recover_90pct_h')}h；"
                  f"滑價 倒 {case[cid].get('dump_slip', float('nan')):.1%} vs 分批 {case[cid].get('batch_slip', float('nan')):.1%}；均價 倒/分批 = {case[cid].get('dump_over_batch', float('nan')):.3f}")
    d = goals["d_onboarding"]
    print(f"(d) 新手（{d['players']} 人）：" + "  ".join(f"{k} 中位 {v['median']} 分、p90 {v['p90']}、最慢 {v['max']}（{v['n']} 人）" for k, v in d.items() if isinstance(v, dict)) + f" pass={d['pass']}")
    for n, row in goals["panic_after_event"].items():
        print(f"  大利多後恐慌賣 {n} 人: " + "  ".join(f"{cid} 3 小時內多跌 {row[cid].get('max_drop_direct', 0):.2%}（{row[cid].get('t_max_h', 0):.2f}h）90%回復 {row[cid].get('recover_90pct_h')}h 事件前 {row[cid]['pre_price']:.3f} 峰值 {row[cid]['peak_calm']:.3f}→{row[cid]['peak_panic']:.3f}" for cid in ("milk", "beef")))
    for n, row in goals["low_online_day"].items():
        print(f"  人少的一天 {n} 人: 線上 {row['ref']['online_mean']:.1f}→{row['low']['online_mean']:.1f}，牛奶均價 {row['ref']['milk_mean']:.3f}→{row['low']['milk_mean']:.3f}（low/ref 平均 {row['milk_low_over_ref_mean']:.3f}，最大 {row['milk_low_over_ref_max']:.3f}）")
    for seed, t in goals["tick_60_vs_300"].items():
        if not seed[1:].isdigit():
            continue
        print(f"  tick 60s vs 300s（{seed}）: " + "  ".join(f"{cid} p50 {t[cid]['p50']['tick60']:.3f}/{t[cid]['p50']['tick300']:.3f} sd {t[cid]['log_sd']['tick60']:.3f}/{t[cid]['log_sd']['tick300']:.3f} 賣壓 {t[cid]['pressure_mean']['tick60']:+.3f}/{t[cid]['pressure_mean']['tick300']:+.3f}" for cid in ("milk", "beef")))
        print("    收入 " + " ".join(f"{k} {v['tick60'] / 1000:.0f}/{v['tick300'] / 1000:.0f}" for k, v in t["revenue_28d"].items()) + f"  耗時 {t['wall_s']['tick60']:.0f}s/{t['wall_s']['tick300']:.0f}s")
    ss = goals["tick_60_vs_300"].get("seed_to_seed_tick60")
    if ss:
        print("  參考：1 分鐘 tick、seed 1 vs seed 2：" + "  ".join(f"{cid} p50 {v['p50'][0]:.3f}/{v['p50'][1]:.3f} sd {v['log_sd'][0]:.3f}/{v['log_sd'][1]:.3f}" for cid, v in ss.items()))


if __name__ == "__main__":
    main()
