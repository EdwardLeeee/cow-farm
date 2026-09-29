"""資料庫層：SQLite（WAL，單一 writer thread）與 PostgreSQL（asyncpg pool）。

兩邊的交易內容一致：
- create_player：新增 players 與 farms 兩列。
- farm：用 token 雜湊 join 出牧場。
- collect：鎖住牧場列，依伺服器時間算產量後寫回。
- sell：扣倉庫、加金幣（條件式 UPDATE，不足就不動）→ 寫一筆 trades → 最後才碰熱點列
  market.volume_acc（全服共用的一列），讓熱點列鎖的時間最短。
- tick：讀出並清空成交量、寫入新價格。
"""

from __future__ import annotations

import asyncio
import os
import sqlite3
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass

# 佔位的遊戲參數（不是 cowecon 的正式數值）
MILK_PER_COW_PER_SEC = 0.05  # 每頭牛每秒 0.05 單位
BARN_CAP = 10**12  # 實測時放很大，避免容量上限干擾 sell
START_COWS = 3
START_COINS = 1000

INSUFFICIENT = "insufficient"

# 1＝每筆 sell 在交易最後累加 market.volume_acc（全服共用的熱點列，brief 的寫法）。
# 0＝只寫 trades（append-only），由 tick 彙總；只在 DB 微基準比較時使用。
SELL_HOTROW = os.environ.get("COW_SELL_HOTROW", "1") == "1"


@dataclass
class FarmRow:
    player_id: int
    cows: int
    milk: int
    coins: int
    last_collect_at: float


SQLITE_SCHEMA = """
CREATE TABLE IF NOT EXISTS players (
  id INTEGER PRIMARY KEY,
  token_hash BLOB NOT NULL UNIQUE,
  created_at REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS farms (
  player_id INTEGER PRIMARY KEY REFERENCES players(id),
  cows INTEGER NOT NULL,
  milk INTEGER NOT NULL,
  coins INTEGER NOT NULL,
  last_collect_at REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS market (
  commodity TEXT PRIMARY KEY,
  price INTEGER NOT NULL,
  base_price INTEGER NOT NULL,
  volume_acc INTEGER NOT NULL,
  tick INTEGER NOT NULL,
  updated_at REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS trades (
  id INTEGER PRIMARY KEY,
  player_id INTEGER NOT NULL,
  commodity TEXT NOT NULL,
  qty INTEGER NOT NULL,
  price INTEGER NOT NULL,
  ts REAL NOT NULL
);
"""

PG_SCHEMA = """
CREATE TABLE IF NOT EXISTS players (
  id BIGSERIAL PRIMARY KEY,
  token_hash BYTEA NOT NULL UNIQUE,
  created_at DOUBLE PRECISION NOT NULL
);
CREATE TABLE IF NOT EXISTS farms (
  player_id BIGINT PRIMARY KEY REFERENCES players(id),
  cows INTEGER NOT NULL,
  milk BIGINT NOT NULL,
  coins BIGINT NOT NULL,
  last_collect_at DOUBLE PRECISION NOT NULL
);
CREATE TABLE IF NOT EXISTS market (
  commodity TEXT PRIMARY KEY,
  price INTEGER NOT NULL,
  base_price INTEGER NOT NULL,
  volume_acc BIGINT NOT NULL,
  tick BIGINT NOT NULL,
  updated_at DOUBLE PRECISION NOT NULL
);
CREATE TABLE IF NOT EXISTS trades (
  id BIGSERIAL PRIMARY KEY,
  player_id BIGINT NOT NULL,
  commodity TEXT NOT NULL,
  qty INTEGER NOT NULL,
  price INTEGER NOT NULL,
  ts DOUBLE PRECISION NOT NULL
);
"""

BASE_PRICES = {"milk": 100, "beef": 800}


def produced_units(cows: int, last: float, now: float) -> int:
    return max(0, int((now - last) * MILK_PER_COW_PER_SEC * cows))


# --------------------------------------------------------------------------- SQLite


class SqliteDB:
    """單一 writer thread 序列化所有寫入；reader threads 平行讀（WAL 讓讀寫不互擋）。"""

    kind = "sqlite"

    def __init__(self, path: str, synchronous: str = "FULL", readers: int = 4):
        self.path = path
        self.synchronous = synchronous
        self._local = threading.local()
        self._writer = ThreadPoolExecutor(1, "sqlite-w", initializer=self._init_conn)
        self._readers = ThreadPoolExecutor(readers, "sqlite-r", initializer=self._init_conn)

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.path, isolation_level=None, check_same_thread=True)
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute(f"PRAGMA synchronous={self.synchronous}")
        conn.execute("PRAGMA busy_timeout=5000")
        return conn

    def _init_conn(self) -> None:
        self._local.conn = self._connect()

    def _run(self, fn, args):
        return fn(self._local.conn, *args)

    async def _read(self, fn, *args):
        return await asyncio.get_running_loop().run_in_executor(self._readers, self._run, fn, args)

    async def _write(self, fn, *args):
        return await asyncio.get_running_loop().run_in_executor(self._writer, self._run, fn, args)

    # ---- lifecycle
    async def start(self) -> None:
        await self._write(_sq_init_schema)

    async def close(self) -> None:
        self._writer.shutdown(wait=True)
        self._readers.shutdown(wait=True)

    # ---- API
    async def create_player(self, token_hash: bytes, now: float, start_milk: int) -> int:
        return await self._write(_sq_create, token_hash, now, start_milk)

    async def auth(self, token_hash: bytes) -> int | None:
        return await self._read(_sq_auth, token_hash)

    async def farm(self, token_hash: bytes) -> FarmRow | None:
        return await self._read(_sq_farm, token_hash)

    async def collect(self, token_hash: bytes, now: float):
        pid = await self.auth(token_hash)
        if pid is None:
            return None
        return await self._write(_sq_collect, pid, now)

    async def sell(self, token_hash: bytes, commodity: str, qty: int, price: int, now: float):
        pid = await self.auth(token_hash)
        if pid is None:
            return None
        return await self._write(_sq_sell, pid, commodity, qty, price, now)

    async def sell_by_pid(self, pid: int, commodity: str, qty: int, price: int, now: float):
        return await self._write(_sq_sell, pid, commodity, qty, price, now)

    async def tick(self, now: float, compute):
        return await self._write(_sq_tick, now, compute)

    async def counts(self):
        return await self._read(_sq_counts)


def _sq_init_schema(conn: sqlite3.Connection):
    conn.executescript(SQLITE_SCHEMA)
    for c, p in BASE_PRICES.items():
        conn.execute(
            "INSERT OR IGNORE INTO market(commodity, price, base_price, volume_acc, tick, updated_at)"
            " VALUES (?,?,?,0,0,0)",
            (c, p, p),
        )


def _sq_create(conn, token_hash, now, start_milk):
    conn.execute("BEGIN IMMEDIATE")
    try:
        cur = conn.execute(
            "INSERT INTO players(token_hash, created_at) VALUES (?,?)", (token_hash, now)
        )
        pid = cur.lastrowid
        conn.execute(
            "INSERT INTO farms(player_id, cows, milk, coins, last_collect_at) VALUES (?,?,?,?,?)",
            (pid, START_COWS, start_milk, START_COINS, now),
        )
        conn.execute("COMMIT")
        return pid
    except BaseException:
        conn.execute("ROLLBACK")
        raise


def _sq_auth(conn, token_hash):
    row = conn.execute("SELECT id FROM players WHERE token_hash=?", (token_hash,)).fetchone()
    return row[0] if row else None


def _sq_farm(conn, token_hash):
    row = conn.execute(
        "SELECT f.player_id, f.cows, f.milk, f.coins, f.last_collect_at"
        " FROM players p JOIN farms f ON f.player_id = p.id WHERE p.token_hash=?",
        (token_hash,),
    ).fetchone()
    return FarmRow(*row) if row else None


def _sq_collect(conn, pid, now):
    conn.execute("BEGIN IMMEDIATE")
    try:
        cows, milk, last = conn.execute(
            "SELECT cows, milk, last_collect_at FROM farms WHERE player_id=?", (pid,)
        ).fetchone()
        got = min(BARN_CAP - milk, produced_units(cows, last, now))
        conn.execute(
            "UPDATE farms SET milk=?, last_collect_at=? WHERE player_id=?", (milk + got, now, pid)
        )
        conn.execute("COMMIT")
        return got, milk + got
    except BaseException:
        conn.execute("ROLLBACK")
        raise


def _sq_sell(conn, pid, commodity, qty, price, now):
    conn.execute("BEGIN IMMEDIATE")
    try:
        rows = conn.execute(
            "UPDATE farms SET milk = milk - ?, coins = coins + ?"
            " WHERE player_id=? AND milk >= ? RETURNING milk, coins",
            (qty, qty * price, pid, qty),
        ).fetchall()
        if not rows:
            conn.execute("ROLLBACK")
            return INSUFFICIENT
        conn.execute(
            "INSERT INTO trades(player_id, commodity, qty, price, ts) VALUES (?,?,?,?,?)",
            (pid, commodity, qty, price, now),
        )
        if SELL_HOTROW:  # 熱點列最後才更新
            conn.execute(
                "UPDATE market SET volume_acc = volume_acc + ? WHERE commodity=?", (qty, commodity)
            )
        conn.execute("COMMIT")
        return rows[0]
    except BaseException:
        conn.execute("ROLLBACK")
        raise


def _sq_tick(conn, now, compute):
    conn.execute("BEGIN IMMEDIATE")
    try:
        rows = conn.execute(
            "SELECT commodity, price, base_price, volume_acc, tick FROM market"
        ).fetchall()
        new = compute(rows)
        for commodity, price in new.items():
            conn.execute(
                "UPDATE market SET price=?, volume_acc=0, tick=tick+1, updated_at=?"
                " WHERE commodity=?",
                (price, now, commodity),
            )
        conn.execute("COMMIT")
        return new, rows
    except BaseException:
        conn.execute("ROLLBACK")
        raise


def _sq_counts(conn):
    return {
        t: conn.execute(f"SELECT count(*) FROM {t}").fetchone()[0]
        for t in ("players", "farms", "trades", "market")
    }


# --------------------------------------------------------------------------- PostgreSQL


class PgDB:
    kind = "postgres"

    def __init__(self, dsn: str, pool_size: int = 20):
        self.dsn = dsn
        self.pool_size = pool_size
        self.pool = None

    async def start(self) -> None:
        import asyncpg

        self.pool = await asyncpg.create_pool(
            self.dsn, min_size=min(4, self.pool_size), max_size=self.pool_size
        )
        async with self.pool.acquire() as conn:
            await conn.execute(PG_SCHEMA)
            for c, p in BASE_PRICES.items():
                await conn.execute(
                    "INSERT INTO market(commodity, price, base_price, volume_acc, tick, updated_at)"
                    " VALUES ($1,$2,$2,0,0,0) ON CONFLICT DO NOTHING",
                    c,
                    p,
                )

    async def close(self) -> None:
        if self.pool:
            await self.pool.close()

    async def create_player(self, token_hash: bytes, now: float, start_milk: int) -> int:
        async with self.pool.acquire() as conn, conn.transaction():
            pid = await conn.fetchval(
                "INSERT INTO players(token_hash, created_at) VALUES ($1,$2) RETURNING id",
                token_hash,
                now,
            )
            await conn.execute(
                "INSERT INTO farms(player_id, cows, milk, coins, last_collect_at)"
                " VALUES ($1,$2,$3,$4,$5)",
                pid,
                START_COWS,
                start_milk,
                START_COINS,
                now,
            )
            return pid

    async def auth(self, token_hash: bytes) -> int | None:
        return await self.pool.fetchval("SELECT id FROM players WHERE token_hash=$1", token_hash)

    async def farm(self, token_hash: bytes) -> FarmRow | None:
        row = await self.pool.fetchrow(
            "SELECT f.player_id, f.cows, f.milk, f.coins, f.last_collect_at"
            " FROM players p JOIN farms f ON f.player_id = p.id WHERE p.token_hash=$1",
            token_hash,
        )
        return FarmRow(*row) if row else None

    async def collect(self, token_hash: bytes, now: float):
        async with self.pool.acquire() as conn:
            pid = await conn.fetchval("SELECT id FROM players WHERE token_hash=$1", token_hash)
            if pid is None:
                return None
            async with conn.transaction():
                cows, milk, last = await conn.fetchrow(
                    "SELECT cows, milk, last_collect_at FROM farms WHERE player_id=$1 FOR UPDATE",
                    pid,
                )
                got = min(BARN_CAP - milk, produced_units(cows, last, now))
                await conn.execute(
                    "UPDATE farms SET milk=$2, last_collect_at=$3 WHERE player_id=$1",
                    pid,
                    milk + got,
                    now,
                )
                return got, milk + got

    async def sell(self, token_hash: bytes, commodity: str, qty: int, price: int, now: float):
        async with self.pool.acquire() as conn:
            pid = await conn.fetchval("SELECT id FROM players WHERE token_hash=$1", token_hash)
            if pid is None:
                return None
            return await self._sell(conn, pid, commodity, qty, price, now)

    async def sell_by_pid(self, pid: int, commodity: str, qty: int, price: int, now: float):
        async with self.pool.acquire() as conn:
            return await self._sell(conn, pid, commodity, qty, price, now)

    async def _sell(self, conn, pid, commodity, qty, price, now):
        tr = conn.transaction()
        await tr.start()
        try:
            row = await conn.fetchrow(
                "UPDATE farms SET milk = milk - $2, coins = coins + $3"
                " WHERE player_id=$1 AND milk >= $2 RETURNING milk, coins",
                pid,
                qty,
                qty * price,
            )
            if row is None:
                await tr.rollback()
                return INSUFFICIENT
            await conn.execute(
                "INSERT INTO trades(player_id, commodity, qty, price, ts) VALUES ($1,$2,$3,$4,$5)",
                pid,
                commodity,
                qty,
                price,
                now,
            )
            if SELL_HOTROW:  # 熱點列最後才更新
                await conn.execute(
                    "UPDATE market SET volume_acc = volume_acc + $2 WHERE commodity=$1",
                    commodity,
                    qty,
                )
            await tr.commit()
            return (row[0], row[1])
        except BaseException:
            await tr.rollback()
            raise

    async def tick(self, now: float, compute):
        async with self.pool.acquire() as conn, conn.transaction():
            rows = await conn.fetch(
                "SELECT commodity, price, base_price, volume_acc, tick FROM market"
                " ORDER BY commodity FOR UPDATE"
            )
            rows = [tuple(r) for r in rows]
            new = compute(rows)
            for commodity, price in new.items():
                await conn.execute(
                    "UPDATE market SET price=$2, volume_acc=0, tick=tick+1, updated_at=$3"
                    " WHERE commodity=$1",
                    commodity,
                    price,
                    now,
                )
            return new, rows

    async def counts(self):
        out = {}
        async with self.pool.acquire() as conn:
            for t in ("players", "farms", "trades", "market"):
                out[t] = await conn.fetchval(f"SELECT count(*) FROM {t}")
        return out


def make_db(kind: str, *, sqlite_path: str = "", synchronous: str = "FULL", dsn: str = "",
            pool_size: int = 20, readers: int = 4):
    if kind == "sqlite":
        return SqliteDB(sqlite_path, synchronous=synchronous, readers=readers)
    if kind == "postgres":
        return PgDB(dsn, pool_size=pool_size)
    raise ValueError(kind)
