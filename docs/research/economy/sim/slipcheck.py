"""一般玩家實際付了多少滑價：100 人與 1,000 人各跑 10 天（seed 7），統計每筆賣單的折扣。寫 out/slippage_normal.json。

    cd docs/research/economy && python3 -m sim.slipcheck   # 約 20 秒
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
import sim  # noqa: E402,F401  （把 backend/ 加進 sys.path；cowecon 在 backend/cowecon/）

from cowecon import market as M  # noqa: E402
from sim.world import World  # noqa: E402


def main() -> None:
    acc: dict = {}
    orig = M.Market.execute_sale

    def patched(self, imp, parts, now):
        r = orig(self, imp, parts, now)
        gross = sum(q * self.price * m for q, m in parts if q > 0)
        if gross > 0:
            a = acc.setdefault(self.cp.id, [0.0, 0.0, []])
            a[0] += gross
            a[1] += gross - r.proceeds
            a[2].append(r.avg_discount)
        return r

    M.Market.execute_sale = patched
    out = {}
    try:
        for n in (100, 1000):
            acc.clear()
            World({"players": n, "days": 10, "tick_s": 60}, seed=7).run()
            for cid, (g, loss, ds) in acc.items():
                ds.sort()
                out[f"{n}_{cid}"] = {
                    "orders": len(ds),
                    "value_weighted": loss / g,
                    "median": ds[len(ds) // 2],
                    "p90": ds[int(len(ds) * 0.9)],
                    "p99": ds[int(len(ds) * 0.99)],
                }
                print(n, cid, {k: (round(v, 4) if isinstance(v, float) else v) for k, v in out[f"{n}_{cid}"].items()})
    finally:
        M.Market.execute_sale = orig
    (HERE / "out" / "slippage_normal.json").write_text(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
