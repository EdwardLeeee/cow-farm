"""SQLite 線上備份與驗證工具。

backup SRC DST   用 Online Backup API 複製（sqlite3 CLI 的 `.backup` 指令用的是同一個 API；
                 這台機器沒裝 sqlite3 CLI，所以用 Python 標準庫的 Connection.backup）。
                 備份完對 DST 跑 PRAGMA integrity_check。
check DB         players／farms／trades 的列數與內容雜湊，market 只數列數（每秒 tick 會變）。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import time

TABLES = (
    ("players", "id, hex(token_hash)", "id"),
    ("farms", "player_id, milk, coins", "player_id"),
    ("trades", "id, player_id, qty, price", "id"),
)


def checksum(db: str) -> dict:
    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    out = {}
    for t, cols, order in TABLES:
        h = hashlib.md5()
        n = 0
        for row in conn.execute(f"SELECT {cols} FROM {t} ORDER BY {order}"):
            h.update(repr(row).encode())
            n += 1
        out[t] = [n, h.hexdigest()]
    out["market"] = [conn.execute("SELECT count(*) FROM market").fetchone()[0], "-"]
    conn.close()
    return out


def backup(src: str, dst: str) -> dict:
    if os.path.exists(dst):
        os.remove(dst)
    s = sqlite3.connect(src)
    d = sqlite3.connect(dst)
    t0 = time.perf_counter()
    s.backup(d)  # pages=-1：一步複製完，WAL 模式下只持有讀取交易，不擋 writer
    dur = time.perf_counter() - t0
    ok = d.execute("PRAGMA integrity_check").fetchone()[0]
    d.close()
    s.close()
    return {"seconds": round(dur, 4), "integrity_check": ok, "bytes": os.path.getsize(dst)}


def main() -> None:
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("backup")
    b.add_argument("src")
    b.add_argument("dst")
    c = sub.add_parser("check")
    c.add_argument("db")
    a = p.parse_args()
    if a.cmd == "backup":
        print(json.dumps(backup(a.src, a.dst)))
    else:
        print(json.dumps(checksum(a.db)))


if __name__ == "__main__":
    main()
