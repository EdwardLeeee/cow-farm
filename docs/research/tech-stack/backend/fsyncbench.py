"""量測資料庫所在磁碟的 fsync 延遲（寫 4 KiB 後 fsync，重複 N 次）。

SQLite synchronous=FULL 與 PostgreSQL synchronous_commit=on 每次 commit 都要等一次 fsync，
所以「每秒最多幾筆互相排隊的寫入交易」大約是 1 / fsync 延遲。
例：.venv/bin/python fsyncbench.py --dir <scratchpad>/data --n 500 --out results/fsync.json
"""

from __future__ import annotations

import argparse
import json
import os
import time


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--dir", required=True)
    p.add_argument("--n", type=int, default=500)
    p.add_argument("--out", required=True)
    a = p.parse_args()
    path = os.path.join(a.dir, "fsync_probe.bin")
    buf = os.urandom(4096)
    res = {}
    for mode in ("fsync", "fdatasync"):
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        lat = []
        for i in range(a.n):
            os.pwrite(fd, buf, (i % 256) * 4096)
            t0 = time.perf_counter()
            (os.fsync if mode == "fsync" else os.fdatasync)(fd)
            lat.append((time.perf_counter() - t0) * 1000)
        os.close(fd)
        lat.sort()
        res[mode] = {
            "n": a.n,
            "p50_ms": round(lat[len(lat) // 2], 3),
            "p90_ms": round(lat[int(len(lat) * 0.9)], 3),
            "p99_ms": round(lat[int(len(lat) * 0.99)], 3),
            "max_ms": round(lat[-1], 3),
            "mean_ms": round(sum(lat) / len(lat), 3),
        }
    os.remove(path)
    with open(a.out, "w") as f:
        json.dump({"dir": a.dir, "results": res}, f, indent=1)
    print(json.dumps(res, indent=1))


if __name__ == "__main__":
    main()
