"""從 out/goals.json 產生研究筆記用的 Markdown 表格（寫 out/tables.md），避免手抄數字出錯（v0.2）。

    cd docs/research/economy && python3 -m sim.tables
"""

from __future__ import annotations

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
OUT = HERE / "out"
POPS = ("10", "100", "1000", "10000")
STRATS = ("D", "B", "F", "C", "T", "L")
STR = {"D": "乳牛派", "B": "肉牛派", "F": "耕田派", "C": "配種收集派", "T": "抓時機派", "L": "出借公牛派"}
CN = {"milk": "牛奶", "beef": "牛肉", "rice": "稻米"}
CIDS = ("milk", "beef", "rice")


def pct(x, d=1):
    return "—" if x is None else f"{x * 100:.{d}f}%"


def main() -> None:
    g = json.loads((OUT / "goals.json").read_text())
    L = []
    a = g["a_price"]
    L.append("### 表 A：價格分布（價格 ÷ 基本價，每 1 分鐘取樣）\n")
    L.append("| 人數 | 天數 | seed 數 | 商品 | 在 0.6–1.7 倍內（各 seed 最低） | 1% | 5% | 中位數 | 95% | 99% | 最低 | 最高 | 每日高低差中位數 | 平均賣壓 |")
    L.append("|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for n in POPS:
        if n not in a:
            continue
        r = a[n]
        for cid in CIDS:
            p = r[cid]
            L.append(f"| {int(n):,} | {r['days']} | {r['seeds']} | {CN[cid]} | {pct(p['inside_min'], 2)} | {p['p1']:.2f} | {p['p5']:.2f} | {p['p50']:.2f} | {p['p95']:.2f} | {p['p99']:.2f} | {p['min']:.2f} | {p['max']:.2f} | {pct(p['daily_range_median'], 0)} | {r['pressure_mean'][cid] * 100:+.1f}% |")
    L.append("")

    b = g["b_strategies"]
    L.append("### 表 B：各策略平均週收入（千幣；賣牛奶、牛肉、稻米 + 借種收入）\n")
    L.append("| 人數 | 週 | " + " | ".join(STR[k] for k in STRATS) + " | 最高÷最低 | 最高 | 最低 | 耕田÷乳牛 |")
    L.append("|---:|---|" + "---:|" * len(STRATS) + "---:|---|---|---:|")
    for n in POPS:
        if n not in b:
            continue
        r = b[n]
        for w in r["weeks"]:
            m = w["means"]
            L.append(f"| {int(n):,} | 第 {w['week']} 週 | " + " | ".join(f"{m[k] / 1000:.0f}" for k in STRATS) + f" | {w['max_over_min']:.2f} | {STR[w['top']]} | {STR[w['bottom']]} | {w['F_over_D']:.2f} |")
        t = r["total"]
        L.append(f"| {int(n):,} | **合計** | " + " | ".join(f"{t[k] / 1000:.0f}" for k in STRATS) + f" | {r['total_max_over_min']:.2f} | {STR[r['total_top']]} | {STR[r['total_bottom']]} | {r['total_F_over_D']:.2f} |")
    L.append("")
    L.append("### 表 B1：全服收入組成與耕田派排名（28 天，各策略人數加權）\n")
    L.append("| 人數 | 牛奶 | 牛肉 | 稻米 | 借種 | 30 天合計排名（高→低） | 耕田派名次 | 耕田÷乳牛 |")
    L.append("|---:|---:|---:|---:|---:|---|---:|---:|")
    for n in POPS:
        if n not in b:
            continue
        r = b[n]
        sh = r["revenue_share"]
        L.append(f"| {int(n):,} | {sh['milk']:.1%} | {sh['beef']:.1%} | {sh['rice']:.1%} | {sh['stud_in']:.1%} | " + "＞".join(STR[k] for k in r["ranking"]) + f" | 第 {r['F_rank']} | {r['total_F_over_D']:.3f} |")
    L.append("")

    ref = "1000" if "1000" in b else next(iter(b))
    r = b[ref]
    last = r["weeks"][-1]
    L.append(f"### 表 B2：收入來源與第 30 天的牧場（{int(ref):,} 人，第 {last['week']} 週）\n")
    L.append("| 策略 | 牛奶 | 牛肉 | 稻米 | 借種收入 | 合計淨收入（扣商店與借種費，千幣） | 第 30 天總資產（千幣） | 牛舍格數 | 田地 | 牛群 乳／耕／肉 | 稀有度 一般／優良／稀有／傳說 |")
    L.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|")
    for k in STRATS:
        pt = last["parts"][k]
        tot = sum(pt.values())
        ty = r["type_counts_end"][k]
        tt = sum(ty) or 1
        tc = r["tier_counts_end"][k]
        tct = sum(tc) or 1
        L.append(f"| {STR[k]} | {pt['milk'] / tot:.0%} | {pt['beef'] / tot:.0%} | {pt['rice'] / tot:.0%} | {pt['stud_in'] / tot:.0%} | {r['net'][k] / 1000:.0f} | {r['worth_end'][k] / 1000:.0f} | {r['slots_end'][k]:.1f} | {r['fields_end'][k]:.1f} | "
                 + "／".join(f"{x / tt:.0%}" for x in ty) + " | " + "／".join(f"{x / tct:.0%}" for x in tc) + " |")
    L.append("")

    c = g["c_whale"]
    L.append(f"### 表 C：大戶拋售（理論上限：一次倒貨 {pct(c['bound_single_dump'], 2)}，一個人不停地賣 {pct(c['bound_single_player_sustained'], 1)}）\n")
    L.append("| 情境 | 商品 | 倒出量 ≈ 全服幾小時的賣量 | 倒貨後 2 小時內價格最多低 | 一次倒出的滑價 | 分 8 批的滑價 | 倒出均價 ÷ 分批均價 |")
    L.append("|---|---|---:|---:|---:|---:|---:|")
    names = {"10p_100cows": "10 人＋大戶 100 頭", "100p_100cows": "100 人＋大戶 100 頭", "1000p_100cows": "1,000 人＋大戶 100 頭", "100p_1000cows": "100 人＋大戶 1,000 頭", "1000p_1000cows": "1,000 人＋大戶 1,000 頭"}
    for k, case in c["cases"].items():
        for cid in ("milk", "beef"):
            x = case[cid]
            h = x.get("dump_hours_of_server_flow")
            L.append(f"| {names.get(k, k)} | {CN[cid]} | {h:.1f} | {pct(x['dump_vs_hold'].get('max_drop_direct'), 2)} | {pct(x.get('dump_slip'))} | {pct(x.get('batch_slip'))} | {x.get('dump_over_batch', float('nan')):.2f} |")
    L.append("")

    d = g["d_onboarding"]
    L.append(f"### 表 D：新手（{d['players']:,} 位玩家，全部基本情境合計）\n")
    L.append("| 里程碑 | 目標 | 最快 | 中位數 | 90% | 最慢 | 達成人數 |")
    L.append("|---|---|---:|---:|---:|---:|---:|")
    for key, name, goal in (("first_sale", "第一次賣東西", "5 分鐘內"), ("first_expand", "第一次擴建", "約 15 分鐘"), ("first_breed", "第一次配種", "30 分鐘內")):
        x = d[key]
        L.append(f"| {name} | {goal} | {x['min']:.0f} 分 | {x['median']:.0f} 分 | {x['p90']:.0f} 分 | {x['max']:.0f} 分 | {x['n']:,}／{d['players']:,} |")
    L.append("")

    sb = g["new_b_stud"]
    L.append(f"### 表 E：借種市場（最高借種價 {sb['top_price']:,.0f} 幣 ≈ 一頭壯年乳牛 {sb['top_price_days_of_milk']:.2f} 天的奶錢，{sb['milk_money_per_day']:,.0f} 幣／天，基本價）\n")
    L.append("| 人數 | 每天成交 | 每人每天 | 玩家上架的比例 | 300 | 800 | 2,000 | 5,000 | 電腦假玩家 300 | 出借派借種收入（幣／週） | 佔出借派收入 | 單一出借派 30 天最多 |")
    L.append("|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for n, p in sb["pops"].items():
        bp = p["by_price_mean"]
        L.append(f"| {int(n):,} | {p['trades_per_day']:.1f} | {p['trades_per_player_day']:.2f} | {p['share_player_listing']:.0%} | {bp.get('300', 0):.0f} | {bp.get('800', 0):.0f} | {bp.get('2000', 0):.0f} | {bp.get('5000', 0):.0f} | {bp.get('300_npc', 0):.0f} | {p['lender_income_per_week']:,.0f} | {p['lender_income_share']:.1%} | {p['lender_income_max_30d']:,.0f} |")
    L.append("\n（300／800／2,000／5,000 欄 = 各價位的成交筆數，多個 seed 平均。）\n")

    sh = g["new_c_shop"]
    L.append("### 表 F：商店 A／B／C\n")
    L.append("| 等級 | 價格 | 稀有度 一般／優良／稀有／傳說 | 1,000 人實測一生價值 | 淨賺（價值 − 價格） | 每 1 幣換到的價值 |")
    L.append("|---|---:|---|---:|---:|---:|")
    refp = sh["pops"].get("1000", {})
    for gname in ("A", "B", "C"):
        gd = sh["grades"][gname]
        v = refp.get("value", {}).get(gname, {})
        L.append(f"| {gname} | {gd['price']:,.0f} | " + "／".join(f"{x:.1%}" for x in gd["tier_probs"]) + f" | {v.get('mean', float('nan')):,.0f}（{v.get('n', 0):,} 頭） | {sh.get('surplus', {}).get(gname, float('nan')):,.0f} | {sh.get('value_per_coin', {}).get(gname, float('nan')):.1f} |")
    L.append("")
    L.append("| 人數 | A 份額 | B 份額 | C 份額 |")
    L.append("|---:|---:|---:|---:|")
    for n, p in sh["pops"].items():
        L.append(f"| {int(n):,} | {p['shares']['A']:.0%} | {p['shares']['B']:.0%} | {p['shares']['C']:.0%} |")
    L.append("")

    bg = g["beef_grades"]
    L.append("### 表 G：出貨評級實際分布\n")
    L.append("| 人數 | A | B | C |")
    L.append("|---:|---:|---:|---:|")
    for n, r2 in bg.items():
        L.append(f"| {int(n):,} | {r2.get('A', 0):.0%} | {r2.get('B', 0):.0%} | {r2.get('C', 0):.0%} |")
    L.append("")

    pe = g["panic_after_event"]
    L.append("### 表 H：大利多（三種商品 +40%）後 60% 玩家 30 分鐘內全賣（對照 = 同 seed、同一則新聞、沒有恐慌）\n")
    L.append("| 人數 | 商品 | 新聞前 | 新聞高點（對照） | 3 小時內比對照多跌 | 回復九成（新聞後） | 同時在線高峰 恐慌／對照 |")
    L.append("|---:|---|---:|---:|---:|---:|---:|")
    for n, r2 in pe.items():
        for cid in CIDS:
            x = r2[cid]
            rec = f"{x['recover_90pct_h']:.1f} 小時" if x.get("recover_90pct_h") is not None else "—（跌幅 < 0.3%）"
            L.append(f"| {int(n):,} | {CN[cid]} | {x['pre_price']:.2f} | {x['peak_calm']:.2f} | {pct(x['max_drop_direct'])} | {rec} | {r2['online_peak_panic']:.0f}／{r2['online_peak_calm']:.0f} |")
    L.append("")

    lo = g["low_online_day"]
    L.append("### 表 I：某天只有兩成的人上線（第 16 天，對照 = 同 seed 平常的那天）\n")
    L.append("| 人數 | 平均同時在線 平常→人少 | 牛奶 人少÷平常 | 牛肉 人少÷平常 | 稻米 人少÷平常 |")
    L.append("|---:|---:|---:|---:|---:|")
    for n, r2 in lo.items():
        L.append(f"| {int(n):,} | {r2['ref']['online_mean']:.1f}→{r2['low']['online_mean']:.1f} | " + " | ".join(f"{r2[c + '_low_over_ref_mean']:.3f}（{r2[c + '_low_over_ref_min']:.2f}–{r2[c + '_low_over_ref_max']:.2f}）" for c in CIDS) + " |")
    L.append("")

    tc = g["tick_60_vs_300"]
    L.append("### 表 J：tick 1 分鐘 vs 5 分鐘（1,000 人，同 seed）\n")
    L.append("| seed | 商品 | 中位數 1 分／5 分 | 對數標準差 1 分／5 分 | 平均賣壓 1 分／5 分 |")
    L.append("|---|---|---:|---:|---:|")
    for sd, r2 in tc.items():
        if not sd[1:].isdigit():
            continue
        for cid in CIDS:
            x = r2[cid]
            L.append(f"| {sd} | {CN[cid]} | {x['p50']['tick60']:.3f}／{x['p50']['tick300']:.3f} | {x['log_sd']['tick60']:.3f}／{x['log_sd']['tick300']:.3f} | {x['pressure_mean']['tick60'] * 100:+.1f}%／{x['pressure_mean']['tick300'] * 100:+.1f}% |")
    L.append("")
    for sd, r2 in tc.items():
        if not sd[1:].isdigit():
            continue
        L.append(f"- {sd} 28 天收入（千幣，1 分／5 分）：" + "、".join(f"{STR[k]} {v['tick60'] / 1000:.0f}／{v['tick300'] / 1000:.0f}" for k, v in r2["revenue_28d"].items()))
    ss = tc.get("seed_to_seed_tick60")
    if ss:
        L.append("- 參考：同樣 1 分鐘 tick，seed 1 與 seed 2 的中位數 " + "、".join(f"{CN[cid]} {v['p50'][0]:.3f}／{v['p50'][1]:.3f}" for cid, v in ss.items()) + "。")
    L.append("")
    w = g["wall"]
    L.append("### 表 K：模擬耗時（牆鐘時間，單一行程，一次只跑一個）\n")
    L.append("| 情境 | 玩家 | 天數 | tick | 秒 | 玩家動作次數 |")
    L.append("|---|---:|---:|---:|---:|---:|")
    for k in ("base_10_s1", "base_100_s1", "base_1000_s1", "base_1000_s1_tick300", "base_10000_s1"):
        if k in w:
            v = w[k]
            L.append(f"| {k} | {v['players']:,} | {v['days']} | {v['tick_s']:.0f} 秒 | {v['seconds']:.0f} | {v['actions']:,} |")
    (OUT / "tables.md").write_text("\n".join(L) + "\n")
    print("\n".join(L))


if __name__ == "__main__":
    main()
