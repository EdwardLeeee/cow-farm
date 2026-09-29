"""純資料庫的 sell 交易微基準（不經 HTTP）。

用 cowbench/db.py 同一份交易程式，C 個 coroutine 各自用不同玩家連續 sell（closed-loop），
量每秒成功交易數與延遲。SQLite 的 DB 工作在本程序內；PG 另加容器的 CPU。

例：
  taskset -c 2 .venv/bin/python dbbench.py --db sqlite --path <scratch>/bench.db --sync FULL \
      --out results/dbbench_sqlite_full.json
  taskset -c 2 .venv/bin/python dbbench.py --db postgres --dsn "$(scripts/pg.sh dsn)" \
      --pg-pid "$(scripts/pg.sh pid)" --out results/dbbench_pg.json
"""

from __future__ import annotations

import argparse
import asyncio
import os
import time

import uvloop

import cowbench.db as dbm
from loadgen import pctl, write_json
from procmon import Sampler, env_snapshot


async def run(a) -> None:
    db = dbm.make_db(a.db, sqlite_path=a.path, synchronous=a.sync, dsn=a.dsn, pool_size=a.pool)
    await db.start()
    levels_c = [int(x) for x in a.concurrency.split(",")]
    pids = [await db.create_player(os.urandom(32), time.time(), 10**12) for _ in range(max(levels_c))]
    env_before = env_snapshot()
    sampler = Sampler(os.getpid(), a.pg_pid, interval=0.5, mem_floor_mb=a.mem_floor)
    sampler.start()
    out_modes = []
    for hotrow in [h == "1" for h in a.hotrow.split(",")]:
        dbm.SELL_HOTROW = hotrow
        levels = []
        for c in levels_c:
            lats: list[float] = []
            res_count = {"ok": 0, "insufficient": 0, "error": 0}
            t_end = [time.monotonic() + 1.0]  # 1 秒暖身

            async def worker(i: int, lats=lats, res_count=res_count, t_end=t_end, record=False):
                while time.monotonic() < t_end[0]:
                    t0 = time.perf_counter()
                    try:
                        r = await db.sell_by_pid(pids[i], "milk", 1, 100, time.time())
                        k = "insufficient" if r == dbm.INSUFFICIENT else "ok"
                    except Exception:  # noqa: BLE001
                        k = "error"
                    if record:
                        lats.append((time.perf_counter() - t0) * 1000)
                        res_count[k] += 1

            await asyncio.gather(*(worker(i) for i in range(c)))
            sampler.mark(f"a{hotrow}{c}")
            t0 = time.monotonic()
            t_end[0] = t0 + a.duration
            await asyncio.gather(*(worker(i, record=True) for i in range(c)))
            sampler.mark(f"b{hotrow}{c}")
            win = sampler.window(f"a{hotrow}{c}", f"b{hotrow}{c}")
            lats.sort()
            lvl = {
                "concurrency": c,
                "tx_per_s": round(res_count["ok"] / win["window_s"], 1),
                "counts": res_count,
                "p50_ms": pctl(lats, 0.5),
                "p90_ms": pctl(lats, 0.9),
                "p99_ms": pctl(lats, 0.99),
                "max_ms": round(lats[-1], 3) if lats else None,
                "system": win,
            }
            levels.append(lvl)
            print(f"{a.db} sync={a.sync} hotrow={int(hotrow)} c={c:>4}: {lvl['tx_per_s']} tx/s "
                  f"p50 {lvl['p50_ms']} p99 {lvl['p99_ms']} max {lvl['max_ms']} "
                  f"procCPU {win.get('server_cpu_pct')}% pgCPU {win.get('pg_cpu_pct')} {res_count}",
                  flush=True)
            if sampler.abort_reason:
                break
            await asyncio.sleep(1)
        out_modes.append({"hotrow": hotrow, "levels": levels})
    await sampler.stop()
    counts = await db.counts()
    await db.close()
    write_json(a.out, {"cmd": "dbbench", "args": {k: v for k, v in vars(a).items() if k != "dsn"},
                       "env_before": env_before, "aborted": sampler.abort_reason,
                       "modes": out_modes, "final_counts": counts})


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--db", choices=("sqlite", "postgres"), required=True)
    p.add_argument("--path", default="")
    p.add_argument("--sync", default="FULL")
    p.add_argument("--dsn", default="")
    p.add_argument("--pool", type=int, default=20)
    p.add_argument("--pg-pid", type=int)
    p.add_argument("--concurrency", default="1,8,32,128")
    p.add_argument("--hotrow", default="1", help="逗號分隔：1＝更新熱點列，0＝只寫 trades")
    p.add_argument("--duration", type=float, default=10)
    p.add_argument("--mem-floor", type=float, default=800)
    p.add_argument("--out", required=True)
    uvloop.run(run(p.parse_args()))


if __name__ == "__main__":
    main()
