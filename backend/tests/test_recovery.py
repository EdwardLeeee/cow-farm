"""重啟回復（需要 PostgreSQL）。

1. 當機後從資料庫回復：市場（含亂數、pending、24 小時歷史）、新聞產生器、每座牧場，和當機前的記憶體逐數字相同。
2. 「跑一半當機、回復、再跑」和「一路跑到底」：價格與每座牧場最後完全一樣（含 4 位假玩家）。
3. 真的伺服器程序：SIGKILL 之後重開，進度與行情都還在（同一個 token 還能用）。
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
    }


def play_hour(h: Harness, tok: str, hour: int) -> None:
    """一個遊戲小時的固定劇本：先跑 tick（假玩家跟著動），再做幾個動作（這些成交會留在下一個 tick 的 pending 裡）。"""
    h.advance(3600)
    h.post("/v1/collect", tok, {"request_id": new_rid()})
    st = h.get("/v1/state", tok).json()
    if st["warehouse"]["milk_total"] > 0:
        frac = 1.0 if hour % 2 else 0.5
        h.post("/v1/sell", tok, {"commodity": "milk", "qty": st["warehouse"]["milk_total"] * frac, "request_id": new_rid()})
    if hour == 1:
        h.post("/v1/upgrade", tok, {"kind": "pen", "request_id": new_rid()})
        cows = h.get("/v1/state", tok).json()["cows"]
        bull = next(c for c in cows if c["bull"])
        cow = next(c for c in cows if not c["bull"])
        h.post("/v1/breed", tok, {"sire": bull["id"], "dam": cow["id"], "request_id": new_rid()})
    if hour == 3:
        bull = next(c for c in h.get("/v1/state", tok).json()["cows"] if c["bull"])
        h.post("/v1/ship", tok, {"cow_id": bull["id"], "request_id": new_rid()})
        h.post("/v1/sell", tok, {"commodity": "beef", "qty": 10, "request_id": new_rid()})


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
    bots = [p for p in a["players"].values() if p["bot"]]
    assert len(bots) == 4 and all(p["farm"]["n_sales"] > 0 for p in bots)  # 假玩家真的有在賣


# ---------------------------------------------------------------------------
# 真的伺服器程序
# ---------------------------------------------------------------------------
PORT = 18787


def start_server(dsn: str, log):
    env = dict(os.environ, COWFARM_PG_DSN=dsn, COWFARM_TIME_SCALE="720", COWFARM_BOTS="4", COWFARM_PORT=str(PORT),
               COWFARM_HOST="127.0.0.1", COWFARM_SEED="proc", PYTHONUNBUFFERED="1")
    env.pop("COWFARM_WEB_DIR", None)
    proc = subprocess.Popen([sys.executable, "-m", "server"], cwd=BACKEND, env=env, stdout=log, stderr=subprocess.STDOUT)
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
        "coins": st["coins"], "level_progress": st["level_progress"], "codex": st["codex"],
        "cows": [{k: c[k] for k in ("id", "type", "bull", "tier", "born_at", "adult_at", "ready_at")} for c in st["cows"]],
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
        s = c.post("/v1/session").json()
        hd = {"Authorization": f"Bearer {s['token']}"}
        assert c.post("/v1/collect", headers=hd, json={"request_id": new_rid()}).status_code == 200
        assert c.post("/v1/sell", headers=hd, json={"commodity": "milk", "qty": 12, "request_id": new_rid()}).status_code == 200
        asyncio.run(_ws_once(s["token"]))  # 連一次 WebSocket：網址帶 token，日誌裡不能出現
        time.sleep(3)  # 倍率 720：約 36 遊戲分鐘，假玩家做完教學的一部分
        before = c.get("/v1/state", headers=hd).json()
        hist_before = c.get("/v1/market/history", headers=hd, params={"commodity": "milk", "range": "1h"}).json()["points"]
        health_before = c.get("/healthz").json()
        assert health_before["ticks"] > 20 and health_before["bot_actions"] > 0
        os.kill(proc.pid, signal.SIGKILL)
        proc.wait(timeout=10)

        proc = start_server(dsn, log)
        after = c.get("/v1/state", headers=hd).json()  # 同一個 token
        assert stable(after) == stable(before)
        assert after["server_time"] >= before["server_time"]
        hist_after = c.get("/v1/market/history", headers=hd, params={"commodity": "milk", "range": "1h"}).json()["points"]
        t_last = hist_before[-1][0]
        assert [p for p in hist_after if p[0] <= t_last][-len(hist_before):] == hist_before  # 價格歷史都還在
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
