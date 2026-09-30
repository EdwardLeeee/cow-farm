"""各策略每單位實際賣到多少錢（第 15–30 天）：看抓時機派（T）的每單位優勢，以及它少賣了多少量（v0.2）。

    cd docs/research/economy && python3 -m sim.unitprice   # 1,000 人 30 天，約 30 秒；寫 out/unitprice.json
"""

from __future__ import annotations

import json
import statistics
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import sim  # noqa: E402,F401
from sim.world import World  # noqa: E402


def main(players: int = 1000, days: int = 30, seed: int = 1) -> None:
    w = World({"players": players, "days": days, "tick_s": 60}, seed=seed)
    w.run()
    d0, d1 = 14, days
    out = {"players": players, "seed": seed, "days": [d0 + 1, d1],
           "market_avg": {"milk": statistics.fmean(w.rec["milk"]), "beef": statistics.fmean(w.rec["beef"])}}
    for s in ("D", "B", "F", "C", "T", "L"):
        bs = [b for b in w.bots if b.strategy == s]
        per = len(bs) * (d1 - d0)
        row = {}
        for cid, unit in (("milk", "bottle"), ("beef", "kg"), ("rice", "kg")):
            q = sum(b.ledger.qty_days(cid, d0, d1) for b in bs)
            a = sum(b.ledger.amount_days(cid, d0, d1) for b in bs)
            row[f"{cid}_per_{unit}"] = a / q if q else None  # 含稀有度、新鮮度、評級、滑價
            row[f"{cid}_{unit}s_per_player_day"] = q / per
        out[s] = row
    out["T_over_D"] = {k: (out["T"][k] / out["D"][k] if out["D"][k] else None) for k in out["D"]}
    print(json.dumps(out, indent=1, ensure_ascii=False))
    (HERE / "out" / "unitprice.json").write_text(json.dumps(out, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
