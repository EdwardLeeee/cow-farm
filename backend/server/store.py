"""PostgreSQL 存取（asyncpg）。

表（原型可以簡化，但重啟一定要能回復）
- meta：世界設定（亂數種子、開服時間、參數指紋、引擎版本）、遊戲時鐘、交易所的新聞產生器與進行中的事件、
  借種市場（StudMarket.to_dict()，v0.2；全服一份，和改到它的動作同一個交易寫入）。
- players：id、token 的 SHA-256、牧場名、是不是假玩家、建立時間。
- farms：player_id、狀態 JSONB（cowecon Farm.to_dict() 加上圖鑑、累積收入、假玩家排程）、版本號（樂觀鎖）。
- markets：商品、Market.to_dict()（不含 24 小時歷史，那在 price_history）、更新時間。
- price_history：每個 tick 的價格，走勢圖與 24 小時均線用。
- trades：成交紀錄。依 T1，成交只寫這張表，全服成交量由市場 tick 彙總，不更新同一列。
  每筆存「對下一個 tick 的貢獻」與序號，伺服器當機後照序號重建 pending。
- news：出現過的新聞事件。
- processed_requests：request_id → 第一次的回應，防止重送時重複成交。
"""

from __future__ import annotations

import json
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

import asyncpg

SCHEMA = """
CREATE TABLE IF NOT EXISTS meta (
    key text PRIMARY KEY,
    value jsonb NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS players (
    id bigint PRIMARY KEY,
    token_sha256 bytea UNIQUE,
    ranch_name text NOT NULL,
    is_bot boolean NOT NULL DEFAULT false,
    created_game_t double precision NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS farms (
    player_id bigint PRIMARY KEY REFERENCES players(id) ON DELETE CASCADE,
    state jsonb NOT NULL,
    version integer NOT NULL,
    game_t double precision NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS markets (
    commodity text PRIMARY KEY,
    snapshot jsonb NOT NULL,
    t double precision NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS price_history (
    commodity text NOT NULL,
    t double precision NOT NULL,
    price double precision NOT NULL,
    PRIMARY KEY (commodity, t)
);
CREATE TABLE IF NOT EXISTS trades (
    seq bigint PRIMARY KEY,
    player_id bigint NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    commodity text NOT NULL,
    qty double precision NOT NULL,
    coins bigint NOT NULL,
    proceeds double precision NOT NULL,
    price double precision NOT NULL,
    discount double precision NOT NULL,
    t double precision NOT NULL,
    market_t double precision NOT NULL,
    contrib jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS trades_market_t ON trades (market_t);
CREATE INDEX IF NOT EXISTS trades_player_t ON trades (player_id, t);
CREATE TABLE IF NOT EXISTS news (
    id bigint PRIMARY KEY,
    headline text NOT NULL,
    targets text[] NOT NULL,
    factor double precision NOT NULL,
    rare boolean NOT NULL,
    announce_at double precision NOT NULL,
    start_at double precision NOT NULL,
    end_at double precision NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS processed_requests (
    player_id bigint NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    request_id uuid NOT NULL,
    endpoint text NOT NULL,
    response jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (player_id, request_id)
);
"""


def dumps(v: Any) -> str:
    # allow_nan=False：JSONB 存不了 NaN／Infinity，出現就是 bug，早點失敗
    return json.dumps(v, ensure_ascii=False, allow_nan=False, separators=(",", ":"))


class VersionConflict(Exception):
    """樂觀鎖失敗：資料庫裡的版本和記憶體不同（多個程序同時寫同一個牧場）。"""


class Store:
    def __init__(self, dsn: str, pool_size: int = 5):
        self.dsn = dsn
        self.pool_size = pool_size
        self.pool: Optional[asyncpg.Pool] = None

    async def start(self) -> None:
        async def init(conn):
            await conn.set_type_codec("jsonb", encoder=lambda v: v if isinstance(v, str) else dumps(v), decoder=json.loads, schema="pg_catalog")

        self.pool = await asyncpg.create_pool(self.dsn, min_size=1, max_size=self.pool_size, init=init)
        async with self.pool.acquire() as conn:
            await conn.execute(SCHEMA)

    async def close(self) -> None:
        if self.pool is not None:
            await self.pool.close()
            self.pool = None

    # ---- 讀 ----
    async def load(self) -> Dict[str, Any]:
        """整個世界：meta、所有玩家與牧場、市場、24 小時價格、上一個 tick 之後的成交、新聞。"""
        async with self.pool.acquire() as conn:
            meta = {r["key"]: r["value"] for r in await conn.fetch("SELECT key, value FROM meta")}
            players = await conn.fetch(
                "SELECT p.id, p.token_sha256, p.ranch_name, p.is_bot, p.created_game_t, f.state, f.version, f.game_t "
                "FROM players p JOIN farms f ON f.player_id = p.id ORDER BY p.id"
            )
            markets = {r["commodity"]: r["snapshot"] for r in await conn.fetch("SELECT commodity, snapshot FROM markets")}
            max_seq = await conn.fetchval("SELECT COALESCE(MAX(seq), 0) FROM trades")
            max_trade_t = await conn.fetchval("SELECT MAX(t) FROM trades")
            news = await conn.fetch("SELECT * FROM news ORDER BY id")
            return {"meta": meta, "players": players, "markets": markets, "max_seq": max_seq, "max_trade_t": max_trade_t, "news": news}

    async def price_history(self, commodity: str, t_from: float, t_to: Optional[float] = None) -> List[Tuple[float, float]]:
        async with self.pool.acquire() as conn:
            if t_to is None:
                rows = await conn.fetch("SELECT t, price FROM price_history WHERE commodity=$1 AND t >= $2 ORDER BY t", commodity, t_from)
            else:
                rows = await conn.fetch("SELECT t, price FROM price_history WHERE commodity=$1 AND t >= $2 AND t <= $3 ORDER BY t", commodity, t_from, t_to)
        return [(r["t"], r["price"]) for r in rows]

    async def trades_since(self, market_t: float) -> List[asyncpg.Record]:
        async with self.pool.acquire() as conn:
            return await conn.fetch("SELECT seq, commodity, contrib FROM trades WHERE market_t >= $1 ORDER BY seq", market_t)

    async def processed(self, player_id: int, request_id: str) -> Optional[Tuple[str, Any]]:
        async with self.pool.acquire() as conn:
            r = await conn.fetchrow("SELECT endpoint, response FROM processed_requests WHERE player_id=$1 AND request_id=$2", player_id, request_id)
        return (r["endpoint"], r["response"]) if r else None

    # ---- 寫 ----
    async def init_world(self, meta: Dict[str, Any], markets: Dict[str, dict], market_t: float, prices: Dict[str, float]) -> None:
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                for k, v in meta.items():
                    await conn.execute("INSERT INTO meta(key, value) VALUES($1, $2) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value, updated_at=now()", k, v)
                for cid, snap in markets.items():
                    await conn.execute("INSERT INTO markets(commodity, snapshot, t) VALUES($1, $2, $3)", cid, snap, market_t)
                    await conn.execute("INSERT INTO price_history(commodity, t, price) VALUES($1, $2, $3) ON CONFLICT DO NOTHING", cid, market_t, prices[cid])

    async def put_meta(self, key: str, value: Any) -> None:
        async with self.pool.acquire() as conn:
            await conn.execute("INSERT INTO meta(key, value) VALUES($1, $2) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value, updated_at=now()", key, value)

    async def create_player(self, pid: int, token_hash: Optional[bytes], name: str, is_bot: bool, created_t: float, state: dict) -> None:
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                await conn.execute(
                    "INSERT INTO players(id, token_sha256, ranch_name, is_bot, created_game_t) VALUES($1, $2, $3, $4, $5)",
                    pid, token_hash, name, is_bot, created_t,
                )
                await conn.execute("INSERT INTO farms(player_id, state, version, game_t) VALUES($1, $2, 1, $3)", pid, state, created_t)

    async def commit_action(self, pid: int, state: dict, version: int, game_t: float, trades: Sequence[dict],
                            request: Optional[Tuple[str, str, Any]] = None,
                            others: Sequence[Tuple[int, dict, int, float]] = (), stud: Optional[dict] = None) -> None:
        """一個動作的結果，同一個交易：牧場狀態（樂觀鎖）、被動到的別的牧場（借種的主人）、借種市場、
        成交紀錄、request_id 與回應。"""
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                for p_id, p_state, p_version, p_t in [(pid, state, version, game_t), *others]:
                    r = await conn.execute(
                        "UPDATE farms SET state=$1, version=version+1, game_t=$2, updated_at=now() WHERE player_id=$3 AND version=$4",
                        p_state, p_t, p_id, p_version,
                    )
                    if r != "UPDATE 1":
                        raise VersionConflict(f"player {p_id} version {p_version}")
                if stud is not None:
                    await conn.execute("INSERT INTO meta(key, value) VALUES('stud', $1) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value, updated_at=now()", stud)
                if trades:
                    await conn.executemany(
                        "INSERT INTO trades(seq, player_id, commodity, qty, coins, proceeds, price, discount, t, market_t, contrib) "
                        "VALUES($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)",
                        [(tr["seq"], tr["player_id"], tr["commodity"], tr["qty"], tr["coins"], tr["proceeds"], tr["price"], tr["discount"],
                          tr["t"], tr["market_t"], tr["contrib"]) for tr in trades],
                    )
                if request is not None:
                    rid, endpoint, response = request
                    await conn.execute(
                        "INSERT INTO processed_requests(player_id, request_id, endpoint, response) VALUES($1, $2, $3, $4)",
                        pid, rid, endpoint, response,
                    )

    async def commit_ticks(self, ticks: Sequence[Tuple[float, Dict[str, dict], Dict[str, float]]], exchange_meta: dict, clock_meta: dict,
                           news: Iterable[dict] = ()) -> None:
        """一個或多個 tick：最後一個的市場狀態、每個 tick 的價格、交易所 meta、遊戲時鐘、新的新聞。"""
        t_last, snaps, _ = ticks[-1]
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                for cid, snap in snaps.items():
                    await conn.execute("UPDATE markets SET snapshot=$2, t=$3, updated_at=now() WHERE commodity=$1", cid, snap, t_last)
                await conn.executemany(
                    "INSERT INTO price_history(commodity, t, price) VALUES($1, $2, $3) ON CONFLICT DO NOTHING",
                    [(cid, t, p) for t, _s, prices in ticks for cid, p in prices.items()],
                )
                await conn.execute("INSERT INTO meta(key, value) VALUES('exchange', $1) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value, updated_at=now()", exchange_meta)
                await conn.execute("INSERT INTO meta(key, value) VALUES('clock', $1) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value, updated_at=now()", clock_meta)
                for n in news:
                    await conn.execute(
                        "INSERT INTO news(id, headline, targets, factor, rare, announce_at, start_at, end_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT (id) DO NOTHING",
                        n["id"], n["headline"], list(n["targets"]), n["factor"], n["rare"], n["announce_at"], n["start_at"], n["end_at"],
                    )

    async def prune(self, price_before: float, requests_older_than_days: int = 7) -> None:
        async with self.pool.acquire() as conn:
            await conn.execute("DELETE FROM price_history WHERE t < $1", price_before)
            await conn.execute("DELETE FROM processed_requests WHERE created_at < now() - make_interval(days => $1)", requests_older_than_days)

    async def weekly_income(self, since_t: float) -> Dict[int, int]:
        async with self.pool.acquire() as conn:
            rows = await conn.fetch("SELECT player_id, SUM(coins) AS s FROM trades WHERE t >= $1 GROUP BY player_id", since_t)
        return {r["player_id"]: int(r["s"]) for r in rows}
