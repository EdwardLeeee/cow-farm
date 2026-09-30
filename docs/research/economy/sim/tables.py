"""從 out/goals.json 產生研究筆記用的 Markdown 表格（寫 out/tables.md），避免手抄數字出錯。

    cd docs/research/economy && python3 -m sim.tables
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
OUT = HERE / "out"
POPS = ("10", "100", "1000", "10000")
STR = {"S1": "S1 即賣", "S2": "S2 牛肉派", "S3": "S3 配種收集", "S4": "S4 抓時機"}


def pct(x, d=1):
    return "—" if x is None else f"{x * 100:.{d}f}%"


def main() -> None:
    g = json.loads((OUT / "goals.json").read_text())
    L = []
    a = g["a_price"]
    L.append("### 表 A：價格分布（價格 ÷ 基本價，每 1 分鐘取樣，30 天）\n")
    L.append("| 人數 | seed 數 | 商品 | 在 0.6–1.7 倍內（各 seed 最低） | 1% | 5% | 中位數 | 95% | 99% | 最低 | 最高 | 每日高低差中位數 | 平均賣壓 |")
    L.append("|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for n in POPS:
        if n not in a:
            continue
        r = a[n]
        for cid, name in (("milk", "牛奶"), ("beef", "牛肉")):
            p = r[cid]
            L.append(f"| {int(n):,} | {r['seeds']} | {name} | {pct(p['inside_min'], 2)} | {p['p1']:.2f} | {p['p5']:.2f} | {p['p50']:.2f} | {p['p95']:.2f} | {p['p99']:.2f} | {p['min']:.2f} | {p['max']:.2f} | {pct(p['daily_range_median'], 0)} | {r['pressure_mean'][cid] * 100:+.1f}% |")
    L.append("")

    b = g["b_strategies"]
    L.append("### 表 B：各策略平均週收入（千幣；牛奶＋牛肉賣出收入）\n")
    L.append("| 人數 | 週 | S1 即賣 | S2 牛肉派 | S3 配種收集 | S4 抓時機 | 最高÷最低 | 最高 | S4÷S1 |")
    L.append("|---:|---|---:|---:|---:|---:|---:|---|---:|")
    for n in POPS:
        if n not in b:
            continue
        r = b[n]
        for w in r["weeks"]:
            m = w["means"]
            L.append(f"| {int(n):,} | 第 {w['week']} 週 | {m['S1'] / 1000:.0f} | {m['S2'] / 1000:.0f} | {m['S3'] / 1000:.0f} | {m['S4'] / 1000:.0f} | {w['max_over_min']:.2f} | {w['top']} | {w['S4_over_S1']:.3f} |")
        t = r["total_28d"]
        L.append(f"| {int(n):,} | **28 天合計** | {t['S1'] / 1000:.0f} | {t['S2'] / 1000:.0f} | {t['S3'] / 1000:.0f} | {t['S4'] / 1000:.0f} | {r['total_max_over_min']:.2f} | {r['total_top']} | {r['total_S4_over_S1']:.3f} |")
    L.append("")
    L.append("### 表 B2：第 30 天的牧場（10,000 人）\n")
    n = "10000" if "10000" in b else "1000"
    r = b[n]
    L.append("| 策略 | 28 天淨收入（扣小牛與配種費，千幣） | 第 30 天總資產（千幣） | 牛舍格數 | 牛群稀有度 一般／優良／稀有／傳說 |")
    L.append("|---|---:|---:|---:|---|")
    for k in ("S1", "S2", "S3", "S4"):
        tc = r["tier_counts_end"][k]
        tot = sum(tc)
        L.append(f"| {STR[k]} | {r['net_28d'][k] / 1000:.0f} | {r['worth_end'][k] / 1000:.0f} | {r['slots_end'][k]:.1f} | " + "／".join(f"{x / tot:.0%}" for x in tc) + " |")
    L.append("")

    c = g["c_whale"]
    L.append(f"### 表 C：大戶拋售（理論上限：一次倒貨 {pct(c['bound_single_dump'], 2)}，一個人不停地賣 {pct(c['bound_single_player_sustained'], 1)}）\n")
    L.append("| 情境 | 商品 | 倒出量 ≈ 全服幾小時的賣量 | 倒貨後 2 小時內價格最多低 | 一次倒出的滑價 | 分 8 批的滑價 | 倒出均價 ÷ 分批均價 |")
    L.append("|---|---|---:|---:|---:|---:|---:|")
    names = {"10p_100cows": "10 人＋大戶 100 頭", "100p_100cows": "100 人＋大戶 100 頭", "1000p_100cows": "1,000 人＋大戶 100 頭", "100p_1000cows": "100 人＋大戶 1,000 頭", "1000p_1000cows": "1,000 人＋大戶 1,000 頭"}
    for k, case in c["cases"].items():
        for cid, name in (("milk", "牛奶"), ("beef", "牛肉")):
            r = case[cid]
            h = r.get("dump_hours_of_server_flow")
            L.append(f"| {names.get(k, k)} | {name} | {h:.1f} | {pct(r['dump_vs_hold'].get('max_drop_direct'), 2)} | {pct(r.get('dump_slip'))} | {pct(r.get('batch_slip'))} | {r.get('dump_over_batch', float('nan')):.2f} |")
    L.append("")

    d = g["d_onboarding"]
    L.append(f"### 表 D：新手（{d['players']:,} 位玩家，全部基本情境合計）\n")
    L.append("| 里程碑 | 目標 | 最快 | 中位數 | 90% | 最慢 | 達成人數 |")
    L.append("|---|---|---:|---:|---:|---:|---:|")
    for key, name, goal in (("first_sale", "第一次賣奶", "5 分鐘內"), ("first_expand", "第一次擴建", "約 15 分鐘"), ("first_breed", "第一次配種", "30 分鐘內")):
        r = d[key]
        L.append(f"| {name} | {goal} | {r['min']:.0f} 分 | {r['median']:.0f} 分 | {r['p90']:.0f} 分 | {r['max']:.0f} 分 | {r['n']:,}／{d['players']:,} |")
    L.append("")

    pe = g["panic_after_event"]
    L.append("### 表 E：大利多（+40%）後 60% 玩家 30 分鐘內全賣（對照 = 同 seed、同一則新聞、沒有恐慌）\n")
    L.append("| 人數 | 商品 | 新聞前 | 新聞高點（對照） | 3 小時內比對照多跌 | 發生在新聞後 | 回復九成（新聞後） | 同時在線高峰 恐慌／對照 |")
    L.append("|---:|---|---:|---:|---:|---:|---:|---:|")
    for n, r in pe.items():
        for cid, name in (("milk", "牛奶"), ("beef", "牛肉")):
            x = r[cid]
            rec = f"{x['recover_90pct_h']:.1f} 小時" if x.get("recover_90pct_h") is not None else "—"
            L.append(f"| {int(n):,} | {name} | {x['pre_price']:.2f} | {x['peak_calm']:.2f} | {pct(x['max_drop_direct'])} | {x['t_max_h'] + 0.25:.1f} 小時 | {rec} | {r['online_peak_panic']:.0f}／{r['online_peak_calm']:.0f} |")
    L.append("")

    lo = g["low_online_day"]
    L.append("### 表 F：某天只有兩成的人上線（第 16 天，對照 = 同 seed 平常的那天）\n")
    L.append("| 人數 | 平均同時在線 平常→人少 | 牛奶均價 平常→人少 | 人少÷平常（平均） | 人少÷平常（最大） | 牛肉均價 平常→人少 |")
    L.append("|---:|---:|---:|---:|---:|---:|")
    for n, r in lo.items():
        L.append(f"| {int(n):,} | {r['ref']['online_mean']:.1f}→{r['low']['online_mean']:.1f} | {r['ref']['milk_mean']:.3f}→{r['low']['milk_mean']:.3f} | {r['milk_low_over_ref_mean']:.3f} | {r['milk_low_over_ref_max']:.3f} | {r['ref']['beef_mean']:.3f}→{r['low']['beef_mean']:.3f} |")
    L.append("")

    tc = g["tick_60_vs_300"]
    L.append("### 表 G：tick 1 分鐘 vs 5 分鐘（1,000 人，同 seed）\n")
    L.append("| seed | 商品 | 中位數 1 分／5 分 | 對數標準差 1 分／5 分 | 平均賣壓 1 分／5 分 | 在 0.6–1.7 倍內 1 分／5 分 |")
    L.append("|---|---|---:|---:|---:|---:|")
    for sd, r in tc.items():
        if not sd[1:].isdigit():
            continue
        for cid, name in (("milk", "牛奶"), ("beef", "牛肉")):
            x = r[cid]
            L.append(f"| {sd} | {name} | {x['p50']['tick60']:.3f}／{x['p50']['tick300']:.3f} | {x['log_sd']['tick60']:.3f}／{x['log_sd']['tick300']:.3f} | {x['pressure_mean']['tick60'] * 100:+.1f}%／{x['pressure_mean']['tick300'] * 100:+.1f}% | {pct(x['inside_soft_band']['tick60'], 2)}／{pct(x['inside_soft_band']['tick300'], 2)} |")
    L.append("")
    L.append("| seed | 28 天收入（千幣）1 分／5 分 | 耗時 1 分／5 分 |")
    L.append("|---|---|---:|")
    for sd, r in tc.items():
        if not sd[1:].isdigit():
            continue
        L.append(f"| {sd} | " + "、".join(f"{k} {v['tick60'] / 1000:.0f}／{v['tick300'] / 1000:.0f}" for k, v in r["revenue_28d"].items()) + f" | {r['wall_s']['tick60']:.0f}／{r['wall_s']['tick300']:.0f} 秒 |")
    ss = tc.get("seed_to_seed_tick60")
    if ss:
        L.append("")
        L.append("參考（隨機性本身有多大）：同樣 1 分鐘 tick、seed 1 與 seed 2 的中位數 " + "、".join(f"{'牛奶' if cid == 'milk' else '牛肉'} {v['p50'][0]:.3f}／{v['p50'][1]:.3f}" for cid, v in ss.items()) + "。")
    L.append("")
    w = g["wall"]
    L.append("### 表 H：模擬耗時（牆鐘時間，單一行程）\n")
    L.append("| 情境 | 玩家 | tick | 秒 | 玩家動作次數 |")
    L.append("|---|---:|---:|---:|---:|")
    for k in ("base_10_s1", "base_100_s1", "base_1000_s1", "base_1000_s1_tick300", "base_10000_s1"):
        if k in w:
            v = w[k]
            L.append(f"| {k} | {v['players']:,} | {v['tick_s']:.0f} 秒 | {v['seconds']:.0f} | {v['actions']:,} |")
    (OUT / "tables.md").write_text("\n".join(L) + "\n")
    print("\n".join(L))


if __name__ == "__main__":
    main()
