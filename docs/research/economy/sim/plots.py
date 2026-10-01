"""畫圖：讀 out/runs/ 與 out/goals.json，輸出 out/*.png。

    cd docs/research/economy && python3 -m sim.report && python3 -m sim.plots

配色與線條照 dataviz skill 的參考色盤（淺色底）：類別色依固定順序
藍 #2a78d6、橘 #eb6834、青 #1baf7a、黃 #eda100、粉 #e87ba4、綠 #008300（v0.2 六種策略；
validate_palette.js：相鄰 CVD ΔE 9.1、一般視覺 ΔE 19.6；青、黃、粉對底色不到 3:1，所以圖上有直接標籤，
筆記另附表格）。商店 A／B／C 是有順序的等級，用單一色相的有序色階 #184f95／#3987e5／#86b6ef（--ordinal 通過）。
中文字型用 Noto Sans CJK TC（從系統的 .ttc 取出 TC 字面；取不到就退回 JP 字面，再不行改英文標籤）。
"""

from __future__ import annotations

import csv
import json
import sys
import tempfile
from pathlib import Path
from typing import Dict, List

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib import font_manager  # noqa: E402

HERE = Path(__file__).resolve().parent.parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import sim  # noqa: E402,F401
from sim import scenarios as S  # noqa: E402

RUNS = HERE / "out" / "runs"
OUT = HERE / "out"

# ---- 色票（dataviz 參考色盤，淺色） ----
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK2 = "#52514e"
MUTED = "#898781"
GRID = "#e1e0d9"
AXIS = "#c3c2b7"
BLUE, ORANGE, AQUA, YELLOW, MAGENTA, GREEN = "#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300"
STRATS = ("D", "B", "F", "C", "T", "L")
STRAT_COLOR = {"D": BLUE, "B": ORANGE, "F": AQUA, "C": YELLOW, "T": MAGENTA, "L": GREEN}
STRAT_LABEL = {"D": "乳牛派", "B": "肉牛派", "F": "耕田派", "C": "配種收集派", "T": "抓時機派", "L": "出借公牛派"}
CIDS = ("milk", "beef", "rice")
CN = {"milk": "牛奶", "beef": "牛肉", "rice": "稻米"}
CCOLOR = {"milk": BLUE, "beef": ORANGE, "rice": AQUA}
GRADE_COLOR = {"A": "#184f95", "B": "#3987e5", "C": "#86b6ef"}
DPI = 150
LW = 1.0  # 1pt ≈ 2px（150 dpi）


def setup_font() -> str:
    """回傳使用的字型名稱。"""
    import subprocess

    try:
        out = subprocess.run(["fc-match", "-f", "%{file}|%{index}", "Noto Sans CJK TC:style=Regular"], capture_output=True, text=True, timeout=10).stdout
        path, idx = out.split("|")
        from fontTools.ttLib import TTCollection

        cache = Path(tempfile.gettempdir()) / "cowecon_fonts"
        cache.mkdir(exist_ok=True)
        target = cache / "NotoSansCJKtc-Regular.otf"
        if not target.exists():
            coll = TTCollection(path)
            coll.fonts[int(idx)].save(str(target))
        font_manager.fontManager.addfont(str(target))
        name = font_manager.FontProperties(fname=str(target)).get_name()
    except Exception:  # noqa: BLE001 — 取不到 TC 字面就退回
        names = {f.name for f in font_manager.fontManager.ttflist}
        name = "Noto Sans CJK JP" if "Noto Sans CJK JP" in names else "DejaVu Sans"
    plt.rcParams.update({
        "font.family": name,
        "axes.unicode_minus": False,
        "figure.facecolor": SURFACE,
        "axes.facecolor": SURFACE,
        "savefig.facecolor": SURFACE,
        "axes.edgecolor": AXIS,
        "axes.linewidth": 0.5,
        "axes.labelcolor": INK2,
        "axes.titlecolor": INK,
        "axes.titlesize": 11,
        "axes.titleweight": "bold",
        "axes.titlelocation": "left",
        "axes.labelsize": 9,
        "xtick.color": MUTED,
        "ytick.color": MUTED,
        "xtick.labelcolor": INK2,
        "ytick.labelcolor": INK2,
        "xtick.labelsize": 8,
        "ytick.labelsize": 8,
        "xtick.major.width": 0.5,
        "ytick.major.width": 0.5,
        "grid.color": GRID,
        "grid.linewidth": 0.5,
        "grid.linestyle": "-",
        "legend.frameon": False,
        "legend.fontsize": 8,
        "lines.solid_capstyle": "round",
        "lines.solid_joinstyle": "round",
    })
    return name


def style_axes(ax, ygrid=True):
    ax.grid(False)
    if ygrid:
        ax.grid(True, axis="y")
    ax.set_axisbelow(True)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)


def ref_line(ax, y, label, color=AXIS, va="center"):
    """參考線：標籤放在圖框右側外面，不會壓到資料。"""
    ax.axhline(y, color=color, linewidth=0.6, zorder=1)
    ax.annotate(label, xy=(1.0, y), xycoords=("axes fraction", "data"), xytext=(4, 0), textcoords="offset points", ha="left", va="center", fontsize=7.5, color=INK2, annotation_clip=False)


def read_csv(path: Path) -> Dict[str, List[float]]:
    cols: Dict[str, List[float]] = {}
    with open(path) as fh:
        for row in csv.DictReader(fh):
            for k, v in row.items():
                cols.setdefault(k, []).append(float(v))
    return cols


def save(fig, name: str) -> None:
    fig.savefig(OUT / name, dpi=DPI, bbox_inches="tight", pad_inches=0.15)
    plt.close(fig)
    print("wrote", OUT / name)


# ---------------------------------------------------------------------------
def fig_price_path(goals) -> None:
    run = "base_1000_s1"
    d = read_csv(RUNS / f"{run}_prices_5m.csv")
    days = [t / 24 for t in d["t_h"]]
    fig, axes = plt.subplots(3, 1, figsize=(9, 7.2), sharex=True)
    for ax, cid in zip(axes, CIDS):
        style_axes(ax)
        ax.plot(days, d[cid], color=CCOLOR[cid], linewidth=LW * 0.8, zorder=3)
        ref_line(ax, 1.7, "軟邊界 1.7 倍")
        ref_line(ax, 1.0, "基本價")
        ref_line(ax, 0.6, "軟邊界 0.6 倍")
        ax.set_ylim(0.5, 1.8)
        ax.set_ylabel(f"{CN[cid]}／基本價")
        r = goals["a_price"]["1000"][cid]
        ax.text(0.005, 0.97, f"{CN[cid]}：{r['inside_min']:.1%} 的時間在 0.6–1.7 倍內；1–99 百分位 {r['p1']:.2f}–{r['p99']:.2f} 倍", transform=ax.transAxes, fontsize=8, color=INK2, va="top")
    axes[-1].set_xlabel("開服後第幾天（2026-10-05 週一 00:00 起，台灣時間）")
    axes[-1].set_xlim(0, 30)
    fig.suptitle("v0.2 三種商品 30 天價格：有起伏但不崩（1,000 名玩家，seed 1，每 5 分鐘取樣）", x=0.01, ha="left", fontsize=11, fontweight="bold", color=INK)
    fig.tight_layout()
    save(fig, "price_30d_1000.png")


def fig_price_distribution(goals) -> None:
    a = goals["a_price"]
    pops = [p for p in ("10", "100", "1000", "10000") if p in a]
    fig, ax = plt.subplots(figsize=(9, 4.4))
    style_axes(ax)
    for j, cid in enumerate(CIDS):
        off = (j - 1) * 0.18
        for i, p in enumerate(pops):
            r = a[p][cid]
            x = i + off
            ax.plot([x, x], [r["p1"], r["p99"]], color=CCOLOR[cid], linewidth=LW, zorder=3)
            ax.plot([x, x], [r["p5"], r["p95"]], color=CCOLOR[cid], linewidth=LW * 4.5, solid_capstyle="butt", zorder=3, label=CN[cid] if i == 0 else None)
            ax.plot([x], [r["p50"]], marker="o", markersize=5, color=CCOLOR[cid], markeredgecolor=SURFACE, markeredgewidth=1.2, zorder=4)
            ax.annotate(f"{r['inside_min']:.1%}", xy=(x, r["p1"]), xytext=(0, -4), textcoords="offset points", ha="center", va="top", fontsize=6.5, color=INK2)
    ref_line(ax, 1.7, "軟邊界 1.7")
    ref_line(ax, 1.0, "基本價")
    ref_line(ax, 0.6, "軟邊界 0.6")
    ax.set_xticks(range(len(pops)))
    ax.set_xticklabels([f"{int(p):,} 人（{a[p]['days']} 天）" for p in pops])
    ax.set_ylim(0.45, 1.8)
    ax.set_ylabel("價格／基本價")
    ax.legend(loc="upper left", ncol=3)
    ax.text(0.99, 0.02, "細線 1–99 百分位、粗段 5–95、圓點中位數；下方數字 = 在 0.6–1.7 倍內的時間（各 seed 最低）", transform=ax.transAxes, ha="right", va="bottom", fontsize=7, color=MUTED)
    worst = min(a[p][cid]["inside_min"] for p in pops for cid in CIDS)
    ax.set_title(f"每種人數、三種商品，價格至少 {worst:.1%} 的時間落在 0.6–1.7 倍")
    fig.tight_layout()
    save(fig, "price_distribution.png")


def fig_strategies(goals) -> None:
    b = goals["b_strategies"]
    pop = "10000" if "10000" in b else "1000"
    row = b[pop]
    weeks = [w["week"] for w in row["weeks"]]
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.4))
    style_axes(ax1)
    style_axes(ax2)
    for k in STRATS:
        ys = [w["means"][k] / 1000 for w in row["weeks"]]
        ax1.plot(weeks, ys, color=STRAT_COLOR[k], linewidth=LW, marker="o", markersize=4.5, markeredgecolor=SURFACE, markeredgewidth=1.0, label=STRAT_LABEL[k])
    ax1.set_xticks(weeks)
    ax1.set_xticklabels([f"第 {w} 週" for w in weeks])
    ax1.set_ylabel("平均週收入（千幣）")
    ax1.set_ylim(0, None)
    ax1.legend(loc="upper left", ncol=2)
    ax1.set_title(f"六種玩法的週收入（{int(pop):,} 名玩家）")
    # 右：差距與耕田÷乳牛（兩個都是比值，同一個軸）
    spread = [w["max_over_min"] for w in row["weeks"]]
    fd = [w["F_over_D"] for w in row["weeks"]]
    ax2.plot(weeks, spread, color=INK2, linewidth=LW, marker="o", markersize=4.5, markeredgecolor=SURFACE, markeredgewidth=1.0, label="六種玩法 最高÷最低")
    ax2.plot(weeks, fd, color=STRAT_COLOR["F"], linewidth=LW, marker="o", markersize=4.5, markeredgecolor=SURFACE, markeredgewidth=1.0, label="耕田派÷乳牛派")
    ax2.annotate(f"{spread[-1]:.2f}", xy=(weeks[-1], spread[-1]), xytext=(6, 0), textcoords="offset points", va="center", fontsize=7.5, color=INK2)
    if abs(fd[-1] - spread[-1]) > 0.02:  # 兩個值一樣時只標一次，免得疊在一起
        ax2.annotate(f"{fd[-1]:.2f}", xy=(weeks[-1], fd[-1]), xytext=(6, 0), textcoords="offset points", va="center", fontsize=7.5, color=INK2)
    ref_line(ax2, 1.5, "上限 1.5 倍")
    ref_line(ax2, 1.07, "耕田 1.07")
    ref_line(ax2, 0.93, "耕田 0.93")
    ax2.axhline(1.0, color=AXIS, linewidth=0.6)
    ax2.set_xticks(weeks)
    ax2.set_xticklabels([f"第 {w} 週" for w in weeks])
    ax2.set_xlim(weeks[0] - 0.2, weeks[-1] + 0.5)
    ax2.set_ylim(0.7, 1.7)
    ax2.set_ylabel("比值")
    ax2.legend(loc="upper right")
    ax2.set_title("差距都在 1.5 倍內；耕田派 ÷ 乳牛派在 0.93–1.07")
    fig.tight_layout()
    save(fig, "strategy_weekly.png")


def fig_shop(goals) -> None:
    sh = goals["new_c_shop"]
    if "surplus" not in sh:
        return
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.0), gridspec_kw={"width_ratios": [1, 1.3]})
    style_axes(ax1)
    grades = ("A", "B", "C")
    xs = range(3)
    prices = [sh["grades"][g]["price"] for g in grades]
    surplus = [sh["surplus"][g] for g in grades]
    w = 0.22
    ax1.bar([x - w / 2 - 0.02 for x in xs], [p / 1000 for p in prices], width=w, color=MUTED, label="價格", zorder=3)
    ax1.bar([x + w / 2 + 0.02 for x in xs], [s / 1000 for s in surplus], width=w, color=BLUE, label="淨賺（一生價值 − 價格）", zorder=3)
    for x, p, s in zip(xs, prices, surplus):
        ax1.annotate(f"{p / 1000:.1f}", xy=(x - w / 2 - 0.02, p / 1000), xytext=(0, 2), textcoords="offset points", ha="center", va="bottom", fontsize=7, color=INK2)
        ax1.annotate(f"{s / 1000:.1f}", xy=(x + w / 2 + 0.02, s / 1000), xytext=(0, 2), textcoords="offset points", ha="center", va="bottom", fontsize=7, color=INK2)
    ax1.set_xticks(list(xs))
    ax1.set_xticklabels([f"{g} 級" for g in grades])
    ax1.set_ylabel("千幣")
    ax1.legend(loc="upper center", bbox_to_anchor=(0.5, -0.1), ncol=2)
    ax1.set_title(f"三級淨賺相差 {sh['surplus_max_over_min'] - 1:.1%} 以內（1,000 人實測）", fontsize=9.5)
    # 右：各策略的購買份額（堆疊橫條，有序色階）
    style_axes(ax2, ygrid=False)
    ax2.grid(True, axis="x")
    pops = sh["pops"]["1000"]["per_strategy"]
    names = list(STRATS)
    lefts = [0.0] * len(names)
    for g in grades:
        vals_g = []
        for k in names:
            t = sum(pops[k].values()) or 1
            vals_g.append(pops[k][g] / t * 100)
        ax2.barh(range(len(names)), vals_g, left=lefts, color=GRADE_COLOR[g], height=0.55, label=f"{g} 級", edgecolor=SURFACE, linewidth=1.0, zorder=3)
        for i, (l, v) in enumerate(zip(lefts, vals_g)):
            if v >= 9:
                ax2.text(l + v / 2, i, f"{v:.0f}%", ha="center", va="center", fontsize=7, color="#ffffff" if g != "C" else INK)
        lefts = [l + v for l, v in zip(lefts, vals_g)]
    ax2.set_yticks(range(len(names)))
    ax2.set_yticklabels([STRAT_LABEL[k] for k in names])
    ax2.invert_yaxis()
    ax2.set_xlim(0, 100)
    ax2.set_xlabel("購買份額（%）")
    ax2.legend(loc="lower right", ncol=3, bbox_to_anchor=(1.0, 1.0), fontsize=7.5)
    ax2.set_title("各玩法買了哪一級（1,000 人，seed 1–2）", fontsize=9.5, loc="left")
    fig.suptitle("商店 A／B／C：沒有明顯最划算的一級，三級都有人買", x=0.01, ha="left", fontsize=10.5, fontweight="bold", color=INK)
    fig.tight_layout()
    save(fig, "shop_grades.png")


def fig_whale(goals) -> None:
    cases = [("10", "100", "10 人，大戶 100 頭"), ("1000", "100", "1,000 人，大戶 100 頭"), ("100", "1000", "100 人，大戶 1,000 頭"), ("1000", "1000", "1,000 人，大戶 1,000 頭")]
    cases = [c for c in cases if (RUNS / f"whale_{c[0]}_{c[1]}cows_dump_s1_window_1m.csv").exists()]
    fig, axes = plt.subplots(1, len(cases), figsize=(3.1 * len(cases), 3.4), sharey=True)
    if len(cases) == 1:
        axes = [axes]
    bound = goals["c_whale"]["bound_single_dump"] * 100
    later = []  # 倒貨 2 小時後到 30 小時的差距（分岔）
    for ax, (n, cows, title) in zip(axes, cases):
        style_axes(ax)
        w = {m: read_csv(RUNS / f"whale_{n}_{cows}cows_{m}_s1_window_1m.csv") for m in ("hold", "dump", "batch")}
        t = [th - S.DUMP_H for th in w["hold"]["t_h"]]
        for cid, color, label in (("milk", BLUE, "牛奶"), ("beef", ORANGE, "牛肉")):
            gap = [(1 - a / b) * 100 for a, b in zip(w["dump"][cid], w["hold"][cid])]
            later += [g for x, g in zip(t, gap) if 2 <= x <= 30]
            sel = [(x, g) for x, g in zip(t, gap) if -1 <= x <= 8]
            ax.plot([x for x, _ in sel], [g for _, g in sel], color=color, linewidth=LW, label=label)
        ax.axhline(0, color=AXIS, linewidth=0.6)
        ax.axhline(bound, color=INK2, linewidth=0.6)
        ax.annotate(f"理論上限 {bound:.2f}%", xy=(1.0, bound), xycoords=("axes fraction", "data"), xytext=(-2, 2), textcoords="offset points", ha="right", va="bottom", fontsize=7, color=INK2)
        ax.axvline(0, color=AXIS, linewidth=0.6)
        ax.set_title(title, fontsize=9.5)
        ax.set_xlabel("倒貨後幾小時")
        ax.set_xlim(-1, 8)
    axes[0].set_ylabel("倒貨比不倒貨低多少（%）")
    axes[0].set_ylim(-1.0, 2.0)
    axes[0].legend(loc="upper left")
    worst = max(case[cid]["dump_vs_hold"].get("max_drop_direct", 0) for case in goals["c_whale"]["cases"].values() for cid in ("milk", "beef"))
    fig.suptitle(f"大戶一次倒出囤了 48 小時的牛奶和全部的牛：2 小時內價格最多低 {worst:.2%}（對照 = 同 seed、一直囤著不賣）", x=0.01, ha="left", fontsize=10.5, fontweight="bold", color=INK)
    fig.text(0.01, -0.02, f"幾小時後的起伏是其他玩家看到稍微不同的價格、做了不同決定，兩條路徑慢慢分岔，不是倒貨本身壓價：倒貨後 2–30 小時的差距在 {min(later):+.2f}% 到 {max(later):+.2f}% 之間，有正有負。", ha="left", va="top", fontsize=8, color=INK2)
    fig.tight_layout()
    save(fig, "whale_gap.png")

    # 大戶自己的成交均價：一次倒 vs 分 8 批
    c = goals["c_whale"]["cases"]
    keys = [k for k in ("10p_100cows", "100p_100cows", "1000p_100cows", "100p_1000cows", "1000p_1000cows") if k in c]
    labels = {"10p_100cows": "10 人\n100 頭", "100p_100cows": "100 人\n100 頭", "1000p_100cows": "1,000 人\n100 頭", "100p_1000cows": "100 人\n1,000 頭", "1000p_1000cows": "1,000 人\n1,000 頭"}
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.0), sharey=True)
    for ax, cid, name in ((axes[0], "milk", "牛奶"), (axes[1], "beef", "牛肉")):
        style_axes(ax)
        width = 0.16  # 約 24px（150 dpi、每組 150px）
        for j, (mode, color, lab) in enumerate((("dump", BLUE, "一次倒出"), ("batch", ORANGE, "分 8 批（每 3 小時一批）"))):
            vals = []
            for k in keys:
                r = c[k][cid]
                p, m = r.get(f"{mode}_avg_price"), r.get(f"{mode}_avg_market")
                vals.append((1 - p / m) * 100 if p and m else 0.0)
            xs = [i + (j - 0.5) * (width + 0.14) for i in range(len(keys))]
            ax.bar(xs, vals, width=width, color=color, label=lab, zorder=3)
            for x, v in zip(xs, vals):
                ax.annotate(f"{v:.1f}%", xy=(x, v), xytext=(0, 2), textcoords="offset points", ha="center", va="bottom", fontsize=6.5, color=INK2)
        ax.set_xticks(range(len(keys)))
        ticks = []
        for k in keys:
            hrs = c[k][cid].get("dump_hours_of_server_flow")
            ticks.append(labels[k] + (f"\n≈全服 {hrs:.1f} 小時" if hrs else ""))
        ax.set_xticklabels(ticks, fontsize=7.5)
        ax.set_title(f"{name}：成交價比當下市價低多少（滑價）", fontsize=9.5)
        ax.axhline(0, color=AXIS, linewidth=0.6)
        ax.set_ylim(0, 34)
    axes[0].set_ylabel("平均折扣（%）")
    handles, labs = axes[0].get_legend_handles_labels()
    fig.legend(handles, labs, loc="upper right", ncol=2, bbox_to_anchor=(0.99, 0.99))
    diffs = [(c[k][cid]["dump_slip"] - c[k][cid]["batch_slip"]) * 100 for k in keys for cid in ("milk", "beef") if (c[k][cid].get("dump_hours_of_server_flow") or 0) >= 3] or [0.0]
    fig.suptitle(f"囤貨量達全服 3 小時以上的賣量時，一次倒出的滑價比分批大 {min(diffs):.0f}–{max(diffs):.0f} 個百分點", x=0.01, ha="left", fontsize=10.5, fontweight="bold", color=INK)
    fig.text(0.01, -0.03, "橫軸第三行 = 大戶倒出的量相當於全服其他玩家平常幾小時的賣量（估計）。囤貨只佔全服 1–2 小時的量時，倒出和分批差不多：市場吃得下，而分批裡夜間那幾批遇到的市場比較淺。", ha="left", va="top", fontsize=8, color=INK2)
    fig.tight_layout(rect=(0, 0, 1, 0.93))
    save(fig, "whale_price.png")


def fig_panic(goals) -> None:
    n = "1000"
    if not (RUNS / f"event_{n}_panic_s1_window_1m.csv").exists():
        return
    wp = read_csv(RUNS / f"event_{n}_panic_s1_window_1m.csv")
    wc = read_csv(RUNS / f"event_{n}_calm_s1_window_1m.csv")
    t = [th - S.EVENT_H for th in wp["t_h"]]
    fig, axes = plt.subplots(1, 4, figsize=(14, 3.6))
    sel = [i for i, x in enumerate(t) if -1 <= x <= 8]
    for ax, cid in zip(axes, CIDS):
        style_axes(ax)
        ax.plot([t[i] for i in sel], [wc[cid][i] for i in sel], color=MUTED, linewidth=LW, label="沒有恐慌（對照）")
        ax.plot([t[i] for i in sel], [wp[cid][i] for i in sel], color=BLUE, linewidth=LW, label="60% 玩家 30 分鐘內全賣")
        ax.axvline(0, color=AXIS, linewidth=0.6)
        ref_line(ax, 1.0, "基本價")
        r = goals["panic_after_event"][n][cid]
        rec = f"，{r['recover_90pct_h']:.1f} 小時回復九成" if r.get("recover_90pct_h") is not None else ""
        ax.set_title(f"{CN[cid]}：多跌 {r['max_drop_direct']:.1%}{rec}", fontsize=9.5)
        ax.set_xlabel("+40% 新聞開始後幾小時")
        ax.set_ylabel(f"{CN[cid]}／基本價")
        ax.set_xlim(-1, 8)
    axes[0].legend(loc="upper right", fontsize=7)
    ax = axes[3]
    style_axes(ax)
    sel2 = [i for i, x in enumerate(t) if -1 <= x <= 3]
    ax.plot([t[i] for i in sel2], [wc["online"][i] for i in sel2], color=MUTED, linewidth=LW, label="對照")
    ax.plot([t[i] for i in sel2], [wp["online"][i] for i in sel2], color=BLUE, linewidth=LW, label="恐慌")
    ax.set_title("同時在線人數", fontsize=9.5)
    ax.set_xlabel("新聞開始後幾小時")
    ax.set_ylim(0, None)
    ax.legend(loc="upper right")
    fig.suptitle(f"三種商品 +40% 後 60% 玩家同時全賣：牛肉多跌最多（大家一次出貨很多頭），牛奶、稻米多跌很少（{int(n):,} 名玩家）", x=0.01, ha="left", fontsize=10.5, fontweight="bold", color=INK)
    fig.tight_layout()
    save(fig, "panic_event.png")


def fig_low(goals) -> None:
    n = "1000"
    if not (RUNS / f"low_{n}_s1_window_1m.csv").exists():
        return
    wl = read_csv(RUNS / f"low_{n}_s1_window_1m.csv")
    wr = read_csv(RUNS / f"low_{n}_s1_ref_window_1m.csv")
    t = [th / 24 for th in wl["t_h"]]
    fig, axes = plt.subplots(2, 1, figsize=(9, 4.8), sharex=True)
    style_axes(axes[0])
    style_axes(axes[1])
    axes[0].plot(t, wr["online"], color=MUTED, linewidth=LW * 0.8, label="平常")
    axes[0].plot(t, wl["online"], color=BLUE, linewidth=LW * 0.8, label="這天只有兩成的人上線")
    axes[0].set_ylabel("同時在線人數")
    axes[0].legend(loc="upper left", ncol=2)
    axes[1].plot(t, wr["milk"], color=MUTED, linewidth=LW * 0.8, label="平常")
    axes[1].plot(t, wl["milk"], color=BLUE, linewidth=LW * 0.8, label="人少的一天")
    ref_line(axes[1], 1.0, "基本價")
    axes[1].set_ylabel("牛奶／基本價")
    for ax in axes:
        ax.axvspan(S.LOW_DAY, S.LOW_DAY + 1, color="#f0efec", zorder=0, linewidth=0)
    r = goals["low_online_day"][n]
    axes[1].set_xlabel("開服後第幾天（灰底 = 人少的那一天）")
    diffs = "、".join(f"{CN[c]} {abs(r[c + '_low_over_ref_mean'] - 1):.1%}" for c in CIDS)
    fig.suptitle(f"某天線上人數只剩兩成：平均價格只差 {diffs}（{int(n):,} 名玩家）", x=0.01, ha="left", fontsize=10.5, fontweight="bold", color=INK)
    fig.tight_layout()
    save(fig, "low_online.png")


def main() -> None:
    name = setup_font()
    print("font:", name)
    goals = json.loads((OUT / "goals.json").read_text())
    fig_price_path(goals)
    fig_price_distribution(goals)
    fig_strategies(goals)
    fig_shop(goals)
    fig_whale(goals)
    fig_panic(goals)
    fig_low(goals)


if __name__ == "__main__":
    main()
