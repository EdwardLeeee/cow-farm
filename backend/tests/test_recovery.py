"""重啟回復（需要 PostgreSQL）。

1. 當機後從資料庫回復：市場（含亂數、pending、24 小時歷史）、新聞產生器、每座牧場、借種市場，和當機前的記憶體逐數字相同。
2. 「跑一半當機、回復、再跑」和「一路跑到底」：價格與每座牧場最後完全一樣（含 4 位假玩家）。
3. 真的伺服器程序：SIGKILL 之後重開，進度與行情都還在（同一個 token 還能用）。
4. 倍率 1（正式版）：關機的那段照真實時間算（奶桶照樣累積、市場補跑 tick、假玩家不補做）；試玩倍率暫停。
"""

from __future__ import annotations

import asyncio
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

import httpx

from conftest import Harness, make_test_db, new_rid

BACKEND = Path(__file__).resolve().parent.parent


def world_state(server) -> dict:
    g = server.game
    return {
        "ex": g.ex.to_dict(include_hist=True, include_history=False),
        "players": {pid: p.state_dict() for pid, p in sorted(g.players.items())},
        "trade_seq": g.trade_seq,
        "history": {cid: list(h) for cid, h in server.history.items()},
        "stud": g.stud.to_dict(),
    }


def play_hour(h: Harness, tok: str, hour: int) -> None:
    """一個遊戲小時的固定劇本（v0.2）：先跑 tick（假玩家跟著動），再做幾個動作（這些成交會留在下一個 tick 的 pending 裡）。"""
    h.advance(3600)
    h.post("/v1/collect", tok, {"request_id": new_rid()})
    st = h.get("/v1/state", tok).json()
    if st["warehouse"]["milk_total"] > 0:
        frac = 1.0 if hour % 2 else 0.5
        h.post(
            "/v1/sell", tok, {"commodity": "milk", "qty": st["warehouse"]["milk_total"] * frac, "request_id": new_rid()}
        )
    cows = st["cows"]
    ox = next((c for c in cows if c["bull"] and c["type"] == "dual"), None)
    if hour == 0 and ox is not None:
        h.post("/v1/field/assign", tok, {"cow_id": ox["id"], "request_id": new_rid()})  # 開局小公牛是耕牛，下田
    if hour == 2:
        h.post("/v1/field/harvest", tok, {"request_id": new_rid()})
        rice = h.get("/v1/state", tok).json()["warehouse"]["rice_total"]
        if rice > 0:
            h.post("/v1/sell", tok, {"commodity": "rice", "qty": rice, "request_id": new_rid()})
    if hour == 3 and ox is not None:
        h.post("/v1/field/recall", tok, {"cow_id": ox["id"], "request_id": new_rid()})
        h.post("/v1/upgrade", tok, {"kind": "pen", "request_id": new_rid()})
        cow = next(c for c in cows if not c["bull"])
        npc = next(x for x in h.get("/v1/stud", tok).json()["listings"] if x["owner"]["player_id"] is None)
        h.post("/v1/stud/borrow", tok, {"listing_id": npc["id"], "dam": cow["id"], "request_id": new_rid()})
        h.post("/v1/stud/list", tok, {"cow_id": ox["id"], "price": 800, "request_id": new_rid()})
    if hour == 5:
        adult = next((c for c in h.get("/v1/state", tok).json()["cows"] if c["can_ship"]), None)
        if adult is not None:
            h.post("/v1/ship", tok, {"cow_id": adult["id"], "request_id": new_rid()})
            h.post("/v1/sell", tok, {"commodity": "beef", "qty": 10, "request_id": new_rid()})
    if hour == 6 and h.get("/v1/state", tok).json()["coins"] >= 900:
        h.post("/v1/shop/buy", tok, {"grade": "C", "request_id": new_rid()})


HOURS = 8
CRASH_AFTER = 4
SEED = "recovery"


def test_restore_is_exact():
    dsn = make_test_db("restore_exact")
    with Harness(dsn, bots=4, seed=SEED, online_window_s=0) as h:
        tok = h.session()["token"]
        for hour in range(CRASH_AFTER):
            play_hour(h, tok, hour)
        before = world_state(h.server)
        assert any(m["pending_ord_w"] > 0 for m in before["ex"]["markets"].values()), "當機前要有還沒 tick 的成交"
        now = h.clock.now()
        # 「當機」：舊的伺服器不做任何收尾，直接從資料庫起一個新的
        with Harness(dsn, bots=4, seed=SEED, clock_t=now, online_window_s=0) as h2:
            after = world_state(h2.server)
            assert after["ex"] == before["ex"]
            assert after["players"] == before["players"]
            assert after["trade_seq"] == before["trade_seq"]
            assert after["history"] == before["history"]
            assert after["stud"] == before["stud"]
            assert h2.get("/v1/state", tok).status_code == 200  # 同一個 token 還能用


def run_script(dsn: str, crash: bool) -> dict:
    with Harness(dsn, bots=4, seed=SEED, online_window_s=0) as h:
        tok = h.session()["token"]
        for hour in range(HOURS if not crash else CRASH_AFTER):
            play_hour(h, tok, hour)
        if not crash:
            return world_state(h.server)
        now = h.clock.now()
    with Harness(dsn, bots=4, seed=SEED, clock_t=now, online_window_s=0) as h2:
        for hour in range(CRASH_AFTER, HOURS):
            play_hour(h2, tok, hour)
        return world_state(h2.server)


def test_resume_after_crash_equals_uninterrupted():
    a = run_script(make_test_db("straight"), crash=False)
    b = run_script(make_test_db("crashed"), crash=True)
    assert a["history"] == b["history"]
    assert a["ex"] == b["ex"]
    assert a["players"] == b["players"]
    assert a["trade_seq"] == b["trade_seq"]
    assert a["stud"] == b["stud"]
    bots = [p for p in a["players"].values() if p["bot"]]
    assert len(bots) == 4 and all(p["farm"]["n_sales"] > 0 for p in bots)  # 假玩家真的有在賣


# ---------------------------------------------------------------------------
# 真的伺服器程序
# ---------------------------------------------------------------------------
PORT = 18787


def start_server(dsn: str, log):
    env = dict(
        os.environ,
        COWFARM_PG_DSN=dsn,
        COWFARM_TIME_SCALE="720",
        COWFARM_BOTS="4",
        COWFARM_PORT=str(PORT),
        COWFARM_HOST="127.0.0.1",
        COWFARM_SEED="proc",
        PYTHONUNBUFFERED="1",
    )
    env.pop("COWFARM_WEB_DIR", None)
    proc = subprocess.Popen(
        [sys.executable, "-m", "server"], cwd=BACKEND, env=env, stdout=log, stderr=subprocess.STDOUT
    )
    for _ in range(100):
        try:
            if httpx.get(f"http://127.0.0.1:{PORT}/healthz", timeout=1).status_code == 200:
                return proc
        except httpx.HTTPError:
            pass
        if proc.poll() is not None:
            break
        time.sleep(0.2)
    proc.kill()
    raise RuntimeError("伺服器沒有啟動，看日誌")


def stable(st: dict) -> dict:
    """不會隨時間變的部分（奶桶、新鮮度、估值會隨遊戲時間變）。"""
    return {
        "coins": st["coins"],
        "level_progress": st["level_progress"],
        "codex": st["codex"],
        "cows": [
            {k: c[k] for k in ("id", "type", "bull", "tier", "born_at", "adult_at", "bred", "field", "listed")}
            for c in st["cows"]
        ],
        "rice_lots": [(l["qty"], l["harvested_at"]) for l in st["warehouse"]["rice_lots"]],
        "milk_lots": [(l["qty"], l["tier"], l["collected_at"]) for l in st["warehouse"]["milk_lots"]],
        "beef_lots": [(l["qty"], l["tier"], l["shipped_at"]) for l in st["warehouse"]["beef_lots"]],
        "pen": {k: st["pen"][k] for k in ("slots", "used", "next_cost")},
        "levels": {k: v["level"] for k, v in st["upgrades"].items()},
    }


def test_real_server_survives_sigkill(tmp_path):
    dsn = make_test_db("sigkill")
    base = f"http://127.0.0.1:{PORT}"
    log = open(tmp_path / "server.log", "w")
    proc = start_server(dsn, log)
    try:
        c = httpx.Client(base_url=base, timeout=5)
        s = c.post("/v1/session", json={"ranch_name": "回復測試牧場"}).json()
        hd = {"Authorization": f"Bearer {s['token']}"}
        assert c.post("/v1/collect", headers=hd, json={"request_id": new_rid()}).status_code == 200
        assert (
            c.post("/v1/sell", headers=hd, json={"commodity": "milk", "qty": 12, "request_id": new_rid()}).status_code
            == 200
        )
        asyncio.run(_ws_once(s["token"]))  # 連一次 WebSocket：網址帶 token，日誌裡不能出現
        # 等假玩家做完教學的一部分、開局小公牛長大（倍率 720 平常約 3 秒）。用輪詢不用固定睡：機器忙的時候
        # tick 跑得慢，只是等久一點，不會因此失敗（ceo 2026-10-02）；最多等 30 秒。
        deadline = time.time() + 30
        while True:
            health = c.get("/healthz").json()
            ox = next(x for x in c.get("/v1/state", headers=hd).json()["cows"] if x["bull"])
            if health["ticks"] > 20 and health["bot_actions"] > 0 and ox["stage"] != "calf":
                break
            assert time.time() < deadline, f"30 秒內伺服器只跑了 {health['ticks']} 個 tick"
            time.sleep(0.2)
        assert (
            c.post("/v1/field/assign", headers=hd, json={"cow_id": ox["id"], "request_id": new_rid()}).status_code
            == 200
        )
        before = c.get("/v1/state", headers=hd).json()
        assert any(x["working"] for x in before["cows"])
        hist_before = c.get("/v1/market/history", headers=hd, params={"commodity": "milk", "range": "1h"}).json()[
            "points"
        ]
        health_before = c.get("/healthz").json()
        assert health_before["ticks"] > 20 and health_before["bot_actions"] > 0
        # 價格歷史是記憶體先更新、再寫進資料庫：等下一個 tick 開始（上一個 tick 的寫入一定已經完成），
        # 確定 hist_before 的最後一點已經寫入，再強制關機。沒等的話，最後一點可能還沒寫入，重開後會重算出些微不同的價格。
        t_last = hist_before[-1][0]
        deadline = time.time() + 30  # 機器忙的時候等久一點；等不到就明確失敗，不要帶著沒寫完的價格往下測
        while c.get("/healthz").json()["tick_t"] < t_last + 60:
            assert time.time() < deadline, "30 秒內沒有等到下一個 tick"
            time.sleep(0.05)
        os.kill(proc.pid, signal.SIGKILL)
        proc.wait(timeout=10)

        proc = start_server(dsn, log)
        after = c.get("/v1/state", headers=hd).json()  # 同一個 token
        assert stable(after) == stable(before)
        assert after["server_time"] >= before["server_time"]
        hist_after = c.get("/v1/market/history", headers=hd, params={"commodity": "milk", "range": "1h"}).json()[
            "points"
        ]
        assert [p for p in hist_after if p[0] <= t_last][-len(hist_before) :] == hist_before  # 價格歷史都還在
        health_after = c.get("/healthz").json()
        assert health_after["tick_t"] >= health_before["tick_t"]
        assert health_after["bots"] == 4 and health_after["players"] == 1
        # 遊戲時間暫停：重開後接著走，不會跳過關機的那段
        assert health_after["server_time"] - health_before["server_time"] < 720 * 30
    finally:
        if proc.poll() is None:
            proc.send_signal(signal.SIGTERM)
            try:
                proc.wait(timeout=15)
            except subprocess.TimeoutExpired:
                proc.kill()
        log.close()
    text = (tmp_path / "server.log").read_text()
    assert "Traceback" not in text, text[-3000:]
    assert "從資料庫回復" in text
    assert "WebSocket /v1/ws?token=***" in text and s["token"] not in text  # token 不寫進日誌


async def _ws_once(token: str) -> None:
    import websockets

    async with websockets.connect(f"ws://127.0.0.1:{PORT}/v1/ws?token={token}") as ws:
        assert json.loads(await ws.recv())["type"] == "hello"


def test_resume_game_time_rules():
    """重啟後從哪個遊戲時間接著走（不需要資料庫）。"""
    from server.runtime import resume_game_time

    meta = {"game_t": 1000.0, "scale": 1.0, "real_t": 5000.0}
    assert resume_game_time(1000.0, meta, 1.0, 5000.0 + 3600) == 1000.0 + 3600  # 正式版：關機一小時照算
    assert resume_game_time(1200.0, meta, 1.0, 5000.0 + 10) == 1200.0  # 不會比存下的動作時間早
    assert resume_game_time(1000.0, meta, 1.0, 4000.0) == 1000.0  # 主機時間倒退也不會倒退
    assert resume_game_time(1000.0, meta, 144.0, 5000.0 + 3600) == 1000.0  # 試玩倍率：暫停
    assert resume_game_time(1000.0, None, 1.0, 9e9) == 1000.0  # 沒有存過時鐘


def test_restart_after_one_hour_at_scale_1(db_dsn):
    """正式版（倍率 1）關機一小時後重開：遊戲時間照真實時間走；奶桶照樣累積、市場補跑那段的 tick，
    假玩家不補做那段的動作（ceo 2026-10-02）。用真的時鐘；「關了一小時」= 把存下的現實時間往前撥一小時。"""
    import asyncpg
    import pytest
    from fastapi.testclient import TestClient

    from server.app import create_app
    from server.config import Config

    def make_app():
        return create_app(Config(time_scale=1.0, pg_dsn=db_dsn, bots=2, seed="realtime-seed", run_loops=False))

    with TestClient(make_app()) as c:
        s = c.post("/v1/session", json={"ranch_name": "正式版牧場"}).json()
        hd = {"Authorization": f"Bearer {s['token']}"}
        before = c.get("/v1/state", headers=hd).json()
    # 正常關機時存下了遊戲時鐘（含 real_t）

    async def shift_one_hour():
        conn = await asyncpg.connect(db_dsn)
        try:
            await conn.execute(
                "UPDATE meta SET value = jsonb_set(value, '{real_t}', to_jsonb((value->>'real_t')::float8 - 3600)) "
                "WHERE key='clock'"
            )
        finally:
            await conn.close()

    asyncio.run(shift_one_hour())
    app = make_app()
    with TestClient(app) as c:
        server = app.state.server
        after = c.get("/v1/state", headers=hd).json()  # 同一個 token
        gap = after["server_time"] - before["server_time"]
        assert 3600 <= gap < 3600 + 60, gap
        assert server.bots.skip_until == pytest.approx(after["server_time"], abs=60)
        # 奶桶照樣累積（開局的乳牛加上新手期加倍，一小時一定滿）
        assert before["bucket"]["qty"] < before["bucket"]["capacity"]
        assert after["bucket"]["qty"] == pytest.approx(after["bucket"]["capacity"])
        # 市場補跑關機那段的 tick
        t0 = server.game.ex.t
        n = 0
        while c.portal.call(server.tick_once) is not None:
            n += 1
        assert n >= 59 and server.game.ex.t - t0 >= 3600 - 60
        # 假玩家：關機那段排好的動作都跳過，沒有任何一個動作的時間落在那段
        bots = [p for p in server.game.players.values() if p.is_bot]
        assert len(bots) == 2
        assert all(p.bot["last_t"] is None or p.bot["last_t"] >= server.bots.skip_until for p in bots)
