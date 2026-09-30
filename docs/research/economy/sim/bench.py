"""伺服器角度的成本：每個 tick、每次玩家動作要多久，每位玩家要存多少資料。

    cd docs/research/economy && python3 -m sim.bench
"""

from __future__ import annotations

import json
import random
import statistics
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from cowecon import DEFAULT, HOUR, Exchange, Farm  # noqa: E402
from cowecon.farm import Cow, shop_genotype  # noqa: E402

T0 = 1791129600.0


def timeit(fn, n):
    samples = []
    for _ in range(5):
        t = time.perf_counter()
        for _ in range(n):
            fn()
        samples.append((time.perf_counter() - t) / n)
    return statistics.median(samples), max(samples)


def main() -> None:
    ex = Exchange(DEFAULT, 1, T0)
    state = {"t": T0}

    def step():
        state["t"] += 60
        ex.step(state["t"], 300.0)

    tick_med, tick_max = timeit(step, 2000)

    rng = random.Random(1)
    farm = Farm(DEFAULT, T0, rng)
    farm.slots = 22
    farm.bucket_level = 10
    farm.wh_level = 6
    for i in range(20):
        farm.cows.append(Cow(100 + i, shop_genotype(DEFAULT.farm, 0, rng), False, T0 - 10 * HOUR, DEFAULT.farm, adult_at=T0 - (i * 5) * HOUR))
    mk = ex.markets["milk"]
    clock = {"t": state["t"]}

    def session():
        clock["t"] += 3 * HOUR
        farm.sell_all_milk(mk, clock["t"])

    sess_med, sess_max = timeit(session, 200)

    def advance():
        clock["t"] += 60
        farm.advance(clock["t"])

    adv_med, adv_max = timeit(advance, 2000)
    imp = json.dumps({k: v.to_dict() for k, v in farm.impact.items()})
    market_state = json.dumps({cid: m.snapshot() for cid, m in ex.markets.items()})
    out = {
        "exchange_step_us": {"median": tick_med * 1e6, "max": tick_max * 1e6},
        "sell_all_milk_20_cows_us": {"median": sess_med * 1e6, "max": sess_max * 1e6},
        "farm_advance_20_cows_us": {"median": adv_med * 1e6, "max": adv_max * 1e6},
        "impact_state_json_bytes": len(imp),
        "market_snapshot_json_bytes": len(market_state),
        "python": sys.version.split()[0],
    }
    print(json.dumps(out, indent=1))
    (HERE / "out" / "bench.json").write_text(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
