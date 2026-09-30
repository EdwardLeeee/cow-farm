"""跑全部情境，結果寫進 out/runs/。

    cd docs/research/economy
    python3 -m sim.run                 # 全部（已經有結果的會跳過）
    python3 -m sim.run --only base_100 # 名稱包含 base_100 的情境
    python3 -m sim.run --force --jobs 4

每個情境輸出：
- <name>.json：摘要（價格分布、各策略週收入、新手時間、大戶成交…）
- <name>_prices_5m.csv：每 5 分鐘一筆的價格（價格/基本價）、線上人數、超賣比例
- <name>_window_1m.csv：大戶、事件、人少情境在關鍵時間前後每 1 分鐘的紀錄
- <name>_players.csv：基本情境每位玩家的週收入與總資產
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
from multiprocessing import Pool
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
import sim  # noqa: E402,F401  （把 backend/ 加進 sys.path；cowecon 在 backend/cowecon/）

from cowecon.params import DAY, HOUR  # noqa: E402
from sim import scenarios as S  # noqa: E402

RUNS = HERE / "out" / "runs"


def _window(sc: dict):
    if sc["group"] == "whale":
        return S.DUMP_H - 6, S.DUMP_H + 30
    if sc["group"] == "event":
        return S.EVENT_H - 6, S.EVENT_H + 18
    if sc["group"] == "low":
        return S.LOW_DAY * 24 - 24, S.LOW_DAY * 24 + 48
    return None


def run_one(sc: dict) -> str:
    from sim.world import World

    name = sc["name"]
    t0 = time.time()
    w = World(sc, sc["seed"])
    summary = w.run()
    p = w.params
    rec = w.rec
    n = len(rec["t"])
    step5 = max(1, int(round(300 / w.dt)))
    with open(RUNS / f"{name}_prices_5m.csv", "w", newline="") as fh:
        wr = csv.writer(fh)
        wr.writerow(["t_h", "milk", "beef", "online", "milk_excess", "beef_excess"])
        for i in range(step5 - 1, n, step5):
            wr.writerow([f"{(rec['t'][i] - w.t0) / HOUR:.4f}", f"{rec['milk'][i] / p.milk.base_price:.5f}", f"{rec['beef'][i] / p.beef.base_price:.5f}", f"{rec['online'][i]:.3f}", f"{rec['milk_e'][i]:.4f}", f"{rec['beef_e'][i]:.4f}"])
    win = _window(sc)
    if win:
        a, b = win
        with open(RUNS / f"{name}_window_1m.csv", "w", newline="") as fh:
            wr = csv.writer(fh)
            cols = ["milk", "beef", "online", "milk_e", "beef_e", "milk_y", "beef_y", "milk_ev", "beef_ev"]
            wr.writerow(["t_h"] + cols)
            for i in range(n):
                th = (rec["t"][i] - w.t0) / HOUR
                if a <= th <= b:
                    row = [f"{th:.4f}"]
                    for c in cols:
                        v = rec[c][i]
                        if c in ("milk",):
                            v /= p.milk.base_price
                        elif c in ("beef",):
                            v /= p.beef.base_price
                        row.append(f"{v:.6f}")
                    wr.writerow(row)
    if sc["group"] == "base":
        with open(RUNS / f"{name}_players.csv", "w", newline="") as fh:
            wr = csv.writer(fh)
            wr.writerow(["pid", "strategy", "sessions_per_day", "week1", "week2", "week3", "week4", "worth_end", "slots_end", "cows_end", "first_sale_min", "first_expand_min", "first_breed_min"])
            last = w.n_days - 1
            for bt in w.bots:
                wk = [bt.ledger.amount_days("milk", 7 * k, 7 * k + 7) + bt.ledger.amount_days("beef", 7 * k, 7 * k + 7) for k in range(4)]
                wr.writerow([bt.pid, bt.strategy, bt.sched.per_day] + [f"{x:.0f}" for x in wk] + [f"{bt.worth[last]:.0f}", bt.farm.slots, len(bt.farm.cows)] + [f"{x / 60:.2f}" if x is not None else "" for x in (bt.first_sale, bt.first_expand, bt.first_breed)])
    summary["wall"]["total_seconds"] = time.time() - t0
    (RUNS / f"{name}.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1))
    return f"{name}: {time.time() - t0:.0f}s"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="只跑名稱包含這段文字的情境（逗號分隔多個）")
    ap.add_argument("--jobs", type=int, default=max(1, min(4, (os.cpu_count() or 2) - 1)))
    ap.add_argument("--force", action="store_true", help="已有結果也重跑")
    args = ap.parse_args()
    RUNS.mkdir(parents=True, exist_ok=True)
    todo = []
    pats = [x for x in args.only.split(",") if x]
    for sc in S.all_scenarios():
        if pats and not any(p in sc["name"] for p in pats):
            continue
        if not args.force and (RUNS / f"{sc['name']}.json").exists():
            continue
        todo.append(sc)
    # 大的先跑，平行比較有效率
    todo.sort(key=lambda s: -s["players"] * s["days"])
    print(f"{len(todo)} 個情境，{args.jobs} 個行程", flush=True)
    if not todo:
        return
    with Pool(args.jobs, maxtasksperchild=1) as pool:
        for msg in pool.imap_unordered(run_one, todo):
            print(msg, flush=True)


if __name__ == "__main__":
    main()
