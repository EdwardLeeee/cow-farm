"""統計：價格分布、各策略週收入、目標檢查。

- 程式內：World.summary() 會呼叫 price_stats、strategy_weeks。
- 命令列：python3 -m sim.analyze  → 讀 out/*.json，印出目標表並寫 out/goals.json。
"""

from __future__ import annotations

import json
import math
import statistics
import sys
from pathlib import Path
from typing import Dict, List

HERE = Path(__file__).resolve().parent.parent
OUT = HERE / "out"

WEEKS = ((0, 7), (7, 14), (14, 21), (21, 28))


def _pct(xs: List[float], q: float) -> float:
    xs = sorted(xs)
    if not xs:
        return float("nan")
    k = (len(xs) - 1) * q
    lo, hi = math.floor(k), math.ceil(k)
    return xs[lo] + (xs[hi] - xs[lo]) * (k - lo)


def price_stats(ratios: List[float], dt: float, soft=(0.6, 1.7)) -> dict:
    """ratios：每個 tick 的 價格/基本價。"""
    n = len(ratios)
    inside = sum(1 for r in ratios if soft[0] <= r <= soft[1]) / n
    logs = [math.log(r) for r in ratios]
    # 最大回撤：從前高到後低的最大跌幅
    peak, mdd = ratios[0], 0.0
    for r in ratios:
        if r > peak:
            peak = r
        dd = 1.0 - r / peak
        if dd > mdd:
            mdd = dd
    per_day = int(round(86400 / dt))
    ranges = []
    for d in range(n // per_day):
        seg = ratios[d * per_day:(d + 1) * per_day]
        ranges.append(max(seg) / min(seg) - 1.0)
    # 1 小時內最大跌幅（看「一次砸盤」這種急跌）
    per_h = max(1, int(round(3600 / dt)))
    worst_1h = 0.0
    for i in range(per_h, n):
        drop = 1.0 - ratios[i] / max(ratios[i - per_h:i])
        if drop > worst_1h:
            worst_1h = drop
    return {
        "n": n,
        "inside_soft_band": inside,
        "inside_0.8_1.25": sum(1 for r in ratios if 0.8 <= r <= 1.25) / n,
        "p1": _pct(ratios, 0.01), "p5": _pct(ratios, 0.05), "p25": _pct(ratios, 0.25), "p50": _pct(ratios, 0.5),
        "p75": _pct(ratios, 0.75), "p95": _pct(ratios, 0.95), "p99": _pct(ratios, 0.99),
        "min": min(ratios), "max": max(ratios), "mean": statistics.fmean(ratios),
        "log_sd": statistics.pstdev(logs),
        "max_drawdown": mdd,
        "daily_range_median": statistics.median(ranges) if ranges else None,
        "worst_1h_drop": worst_1h,
    }


PLAYER_KEYS = ("D", "B", "F", "C", "T", "L")


def strategy_weeks(world) -> dict:
    """各策略每週收入（賣牛奶、牛肉、稻米的收入 + 借種收入，幣）等統計。大戶（W）另計。
    v0.3：care_net_mean = 收入 − 照顧花費（地板、掃地機、飼料、治療），玩法差距的目標用這個（使用者 2026-10-08）。"""
    groups: Dict[str, list] = {}
    for b in world.bots:
        groups.setdefault(b.strategy, []).append(b)
    out = {}
    for s, bs in sorted(groups.items()):
        weeks = []
        for d0, d1 in WEEKS:
            if d1 > world.n_days:
                break
            rev = [b.ledger.revenue_days(d0, d1) for b in bs]
            care = [b.ledger.care_days(d0, d1) for b in bs]
            part = {k: statistics.fmean([b.ledger.amount_days(k, d0, d1) for b in bs]) for k in ("milk", "beef", "rice", "stud_in")}
            opex = [-(b.ledger.amount_days("calf", d0, d1) + b.ledger.amount_days("stud_out", d0, d1)) for b in bs]
            capex = [-sum(b.ledger.amount_days(k, d0, d1) for k in ("expand", "bucket", "warehouse", "fresh", "field")) for b in bs]
            weeks.append({
                "days": [d0, d1],
                "revenue_mean": statistics.fmean(rev), "revenue_median": statistics.median(rev),
                "revenue_p25": _pct(rev, 0.25), "revenue_p75": _pct(rev, 0.75),
                "milk_mean": part["milk"], "beef_mean": part["beef"], "rice_mean": part["rice"], "stud_in_mean": part["stud_in"],
                "net_mean": statistics.fmean([r - o for r, o in zip(rev, opex)]),
                "care_spend_mean": statistics.fmean(care),
                "care_net_mean": statistics.fmean([r - c for r, c in zip(rev, care)]),
                "opex_mean": statistics.fmean(opex), "capex_mean": statistics.fmean(capex),
                "spoiled_mean": statistics.fmean([b.ledger.qty_days("spoiled", d0, d1) for b in bs]),
            })
        last = world.n_days - 1
        worth = [b.worth[last] for b in bs]
        tiers = [0, 0, 0, 0]
        types = [0, 0, 0]
        herd = []
        for b in bs:
            herd.append(len(b.farm.cows))
            for c in b.farm.cows:
                tiers[c.tier] += 1
                types[c.ctype] += 1
        out[s] = {
            "n": len(bs),
            "weeks": weeks,
            "worth_end_mean": statistics.fmean(worth),
            "worth_end_median": statistics.median(worth),
            "herd_end_mean": statistics.fmean(herd),
            "slots_end_mean": statistics.fmean([b.farm.slots for b in bs]),
            "fields_end_mean": statistics.fmean([len(b.farm.fields) for b in bs]),
            "tier_counts_end": tiers,
            "type_counts_end": types,
            "revenue_total_mean": sum(w["revenue_mean"] for w in weeks),
            "care_net_total_mean": sum(w["care_net_mean"] for w in weeks),
        }
    return out


def week_ratios(strategies: dict, keys=PLAYER_KEYS) -> List[dict]:
    """每週各策略平均週收入（收入 − 照顧花費）的 最大/最小、最高者、耕田÷乳牛、抓時機÷乳牛。"""
    rows = []
    keys = [k for k in keys if k in strategies]
    n_weeks = min(len(strategies[k]["weeks"]) for k in keys)
    for w in range(n_weeks):
        vals = {k: strategies[k]["weeks"][w]["care_net_mean"] for k in keys}
        hi, lo = max(vals.values()), min(vals.values())
        rows.append({
            "week": w + 1,
            "means": vals,
            "max_over_min": hi / lo if lo > 0 else float("inf"),
            "top": max(vals, key=vals.get),
            "F_over_D": vals["F"] / vals["D"] if vals.get("D") and "F" in vals else None,
            "T_over_D": vals["T"] / vals["D"] if vals.get("D") and "T" in vals else None,
        })
    return rows


def main(argv: List[str]) -> None:
    files = sorted(OUT.glob("*.json"))
    for f in files:
        if f.name in ("goals.json",):
            continue
        d = json.loads(f.read_text())
        if "price" not in d:
            continue
        print(f"== {f.stem}  players={d['players']} tick={d['tick_s']}s wall={d['wall'].get('seconds', 0):.0f}s")
        for cid in d["price"]:
            ps = d["price"][cid]
            print(f"  {cid}: inside={ps['inside_soft_band']:.4f} p1={ps['p1']:.3f} p5={ps['p5']:.3f} p50={ps['p50']:.3f} p95={ps['p95']:.3f} p99={ps['p99']:.3f} mdd={ps['max_drawdown']:.3f}")
        if d.get("strategies"):
            for row in week_ratios(d["strategies"]):
                means = " ".join(f"{k}={v:,.0f}" for k, v in row["means"].items())
                print(f"  week{row['week']}: {means}  max/min={row['max_over_min']:.2f} top={row['top']} F/D={row['F_over_D']:.3f}")


if __name__ == "__main__":
    main(sys.argv[1:])
