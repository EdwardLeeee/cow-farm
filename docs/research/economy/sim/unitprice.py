"""各策略每單位實際賣到多少錢（第 15–30 天）：看 S4 抓時機的每單位優勢，以及它少賣了多少量。

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

from sim.world import World  # noqa: E402


def main(players: int = 1000, days: int = 30, seed: int = 1) -> None:
    w = World({"players": players, "days": days, "tick_s": 60}, seed=seed)
    w.run()
    d0, d1 = 14, days
    out = {"players": players, "seed": seed, "days": [d0 + 1, d1],
           "market_avg": {"milk": statistics.fmean(w.rec["milk"]), "beef": statistics.fmean(w.rec["beef"])}}
    for s in ("S1", "S2", "S3", "S4"):
        bs = [b for b in w.bots if b.strategy == s]
        mq = sum(b.ledger.qty_days("milk", d0, d1) for b in bs)
        ma = sum(b.ledger.amount_days("milk", d0, d1) for b in bs)
        bq = sum(b.ledger.qty_days("beef", d0, d1) for b in bs)
        ba = sum(b.ledger.amount_days("beef", d0, d1) for b in bs)
        per = len(bs) * (d1 - d0)
        out[s] = {
            "milk_per_bottle": ma / mq if mq else None,  # 含稀有度、新鮮度、滑價
            "beef_per_kg": ba / bq if bq else None,
            "milk_bottles_per_player_day": mq / per,
            "beef_kg_per_player_day": bq / per,
            "spoiled_per_player_day": sum(b.ledger.qty_days("spoiled", d0, d1) for b in bs) / per,
        }
    for k in ("milk_per_bottle", "beef_per_kg", "milk_bottles_per_player_day", "beef_kg_per_player_day"):
        out.setdefault("S4_over_S1", {})[k] = out["S4"][k] / out["S1"][k]
    print(json.dumps(out, indent=1, ensure_ascii=False))
    (HERE / "out" / "unitprice.json").write_text(json.dumps(out, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
