"""測試共用：建立獨立的測試資料庫、用手動時鐘啟動 app。

需要 PostgreSQL（scripts/pg.sh up）。找不到連線設定時，用到資料庫的測試會 skip。
測試資料庫名稱都以 cowfarm_test_ 開頭，每次重建，不會碰到試玩用的 cowfarm 資料庫。
"""

from __future__ import annotations

import asyncio
import os
import sys
import uuid
from pathlib import Path

import pytest

BACKEND = Path(__file__).resolve().parent.parent
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))
TESTS = Path(__file__).resolve().parent
if str(TESTS) not in sys.path:
    sys.path.insert(0, str(TESTS))

from server.config import default_dsn  # noqa: E402

T0 = 1791129600.0  # 2026-10-05（週一）00:00 台灣時間


def _dsn_or_none():
    try:
        return default_dsn()
    except RuntimeError:
        return None


_CREATED: set = set()


async def _drop(admin_dsn: str, names) -> None:
    import asyncpg

    conn = await asyncpg.connect(admin_dsn)
    try:
        for name in names:
            await conn.execute(f'DROP DATABASE IF EXISTS "{name}" WITH (FORCE)')
    finally:
        await conn.close()


@pytest.fixture(scope="session", autouse=True)
def _drop_test_databases():
    """測試結束後刪掉這次建立的 cowfarm_test_* 資料庫（COWFARM_KEEP_TEST_DB=1 時保留，方便除錯）。"""
    yield
    admin = _dsn_or_none()
    if admin and _CREATED and os.environ.get("COWFARM_KEEP_TEST_DB") != "1":
        asyncio.run(_drop(admin, sorted(_CREATED)))


async def _recreate(admin_dsn: str, name: str) -> None:
    import asyncpg

    conn = await asyncpg.connect(admin_dsn)
    try:
        await conn.execute(f'DROP DATABASE IF EXISTS "{name}" WITH (FORCE)')
        await conn.execute(f'CREATE DATABASE "{name}"')
    finally:
        await conn.close()


def make_test_db(tag: str) -> str:
    """建立（或重建）一個測試資料庫，回傳它的 DSN。"""
    admin = _dsn_or_none()
    if admin is None:
        pytest.skip("沒有 PostgreSQL 連線設定（先執行 scripts/pg.sh up）")
    name = f"cowfarm_test_{tag}"
    asyncio.run(_recreate(admin, name))
    _CREATED.add(name)
    return default_dsn(name)


def new_rid() -> str:
    return str(uuid.uuid4())


@pytest.fixture
def db_dsn(request):
    tag = request.node.name.lower().replace("[", "_").replace("]", "")[:40]
    return make_test_db("".join(ch if ch.isalnum() else "_" for ch in tag))


class Harness:
    """TestClient + 手動時鐘：時間只在 advance() 時前進，tick 由測試自己叫。"""

    def __init__(
        self,
        dsn: str,
        bots: int = 0,
        seed: str = "test-seed",
        t0: float = T0,
        clock_t: float = None,
        online_window_s: float = 30.0,
        web_dir: str = None,
    ):
        from fastapi.testclient import TestClient

        from server.app import create_app
        from server.clock import ManualClock
        from server.config import Config

        self.dsn = dsn
        self.clock = ManualClock(t0 if clock_t is None else clock_t, scale=144.0)
        self.cfg = Config(
            time_scale=144.0,
            pg_dsn=dsn,
            bots=bots,
            seed=seed,
            game_start=t0,
            run_loops=False,
            online_window_s=online_window_s,
            web_dir=web_dir,
        )
        self.app = create_app(self.cfg, clock=self.clock)
        self.server = self.app.state.server
        self.client = TestClient(self.app)

    def __enter__(self):
        self.client.__enter__()
        return self

    def __exit__(self, *exc):
        self.client.__exit__(*exc)

    def advance(self, seconds: float, tick: bool = True) -> None:
        """遊戲時間往前 seconds 秒；tick=True 時把到期的市場 tick 都跑完。"""
        self.clock.advance(seconds)
        if tick:
            while self.client.portal.call(self.server.tick_once) is not None:
                pass

    def session(self) -> dict:
        r = self.client.post("/v1/session")
        assert r.status_code == 200, r.text
        return r.json()

    def auth(self, token: str) -> dict:
        return {"Authorization": f"Bearer {token}"}

    def get(self, path: str, token: str, **params):
        return self.client.get(path, headers=self.auth(token), params=params)

    def post(self, path: str, token: str, body: dict):
        return self.client.post(path, headers=self.auth(token), json=body)
