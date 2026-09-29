"""即時行情：WebSocket 廣播 vs HTTP 輪詢，以及伺服器重啟後的斷線重連。

子命令
  ws         N 條 WebSocket 連線；伺服器每次 tick（5 秒）後把快照推給全部連線。
             量：送出→收到延遲、伺服器 CPU／RSS、每連線記憶體、lo 介面流量。
  poll       N 個客戶端每 10 秒 GET /v1/market 一次（每次新連線）。
             量：回應延遲、資料新鮮度（快照發布→客戶端拿到）、伺服器 CPU、流量。
  reconnect  N 條 WebSocket 連線帶指數退避（full jitter）重連；中途 SIGKILL 伺服器、
             等 --gap 秒後重啟，量每個客戶端多久連回來。

客戶端是自寫的最小 WebSocket 客戶端（asyncio.Protocol：握手、解 frame、回 pong），
每連線記憶體比 websockets 函式庫小，才能在這台只剩約 1 GB 可用記憶體的機器上開到上萬條。
客戶端分成 --procs 個程序（spawn），各自負責一部分連線。
"""

from __future__ import annotations

import argparse
import asyncio
import base64
import concurrent.futures as cf
import hashlib
import json
import multiprocessing as mp
import os
import random
import signal
import struct
import subprocess
import time

import psutil
import uvloop

from loadgen import fetch_json, load_tokens, pctl, write_json
from procmon import Sampler, env_snapshot, lo_bytes, meminfo_mb

GUID = b"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


class WSClient(asyncio.Protocol):
    def __init__(self, host: str, port: int, token: str, on_text):
        self.host, self.port, self.token = host, port, token
        self.on_text = on_text
        self.buf = bytearray()
        self.hs_done = False
        loop = asyncio.get_running_loop()
        self.opened: asyncio.Future = loop.create_future()
        self.closed: asyncio.Future = loop.create_future()
        self.transport = None

    def connection_made(self, transport):
        self.transport = transport
        key = base64.b64encode(os.urandom(16))
        self.expect = base64.b64encode(hashlib.sha1(key + GUID).digest())
        transport.write(
            (
                f"GET /v1/ws/market?token={self.token} HTTP/1.1\r\n"
                f"Host: {self.host}:{self.port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                f"Sec-WebSocket-Key: {key.decode()}\r\nSec-WebSocket-Version: 13\r\n\r\n"
            ).encode()
        )

    def data_received(self, data: bytes):
        self.buf += data
        if not self.hs_done:
            i = self.buf.find(b"\r\n\r\n")
            if i < 0:
                return
            head = bytes(self.buf[:i])
            del self.buf[: i + 4]
            if not head.startswith(b"HTTP/1.1 101") or self.expect not in head:
                if not self.opened.done():
                    self.opened.set_exception(ConnectionError(head.split(b"\r\n")[0].decode()))
                self.transport.close()
                return
            self.hs_done = True
            if not self.opened.done():
                self.opened.set_result(True)
        self._parse()

    def _parse(self):
        buf = self.buf
        while len(buf) >= 2:
            b0, b1 = buf[0], buf[1]
            op, ln, idx = b0 & 0x0F, b1 & 0x7F, 2
            if ln == 126:
                if len(buf) < 4:
                    return
                ln, idx = struct.unpack_from(">H", buf, 2)[0], 4
            elif ln == 127:
                if len(buf) < 10:
                    return
                ln, idx = struct.unpack_from(">Q", buf, 2)[0], 10
            if b1 & 0x80:
                idx += 4  # 伺服器不該遮罩；保險起見略過
            if len(buf) < idx + ln:
                return
            payload = bytes(buf[idx : idx + ln])
            del buf[: idx + ln]
            if op == 0x1:
                self.on_text(payload)
            elif op == 0x9:
                self.send_frame(0xA, payload)
            elif op == 0x8:
                self.send_frame(0x8, payload[:2])
                self.transport.close()

    def send_frame(self, op: int, payload: bytes):
        mask = os.urandom(4)
        n = len(payload)
        hdr = bytes([0x80 | op, 0x80 | n]) if n < 126 else bytes([0x80 | op, 0x80 | 126]) + struct.pack(">H", n)
        body = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        if self.transport and not self.transport.is_closing():
            self.transport.write(hdr + mask + body)

    def connection_lost(self, exc):
        if not self.opened.done():
            self.opened.set_exception(ConnectionError("lost before open"))
        if not self.closed.done():
            self.closed.set_result(time.time())


def parse_push(payload: bytes) -> tuple[int, float]:
    """'{"sent_ns":N,"snap":{"tick":T,"pub_at":P,...' → (sent_ns, pub_at)。"""
    j = payload.index(b",", 11)
    sent_ns = int(payload[11:j])
    k = payload.index(b'"pub_at":', j) + 9
    e = payload.index(b",", k)
    return sent_ns, float(payload[k:e])


def rss_mb() -> float:
    return psutil.Process().memory_info().rss / 2**20


# ----------------------------------------------------------------------------- ws


async def _ws_worker(p: dict) -> dict:
    loop = asyncio.get_running_loop()
    lat_ms: list[float] = []
    age_ms: list[float] = []
    cnt = {"msgs": 0, "bytes": 0, "msgs_total": 0}
    m0, m1 = p["t_measure_start"] * 1e9, p["t_measure_end"] * 1e9

    def on_text(payload: bytes):
        now = time.time_ns()
        cnt["msgs_total"] += 1
        if m0 <= now <= m1:
            sent_ns, pub_at = parse_push(payload)
            lat_ms.append((now - sent_ns) / 1e6)
            age_ms.append(now / 1e6 - pub_at * 1000)
            cnt["msgs"] += 1
            cnt["bytes"] += len(payload)

    rss0 = rss_mb()
    protos: list[WSClient] = []
    failed = 0
    stopped_for_mem = None
    sem = asyncio.Semaphore(64)
    await asyncio.sleep(max(0.0, p["t_connect_start"] - time.time()))
    t_c0 = time.time()

    async def one(tok: str):
        nonlocal failed
        async with sem:
            pr = WSClient(p["host"], p["port"], tok, on_text)
            try:
                await loop.create_connection(lambda: pr, p["host"], p["port"])
                await asyncio.wait_for(pr.opened, 15)
                protos.append(pr)
            except Exception:  # noqa: BLE001
                failed += 1

    tasks = []
    interval = 1.0 / p["connect_rate"]
    for i, tok in enumerate(p["tokens"]):
        if i % 200 == 0 and meminfo_mb() < p["mem_floor"]:
            stopped_for_mem = f"MemAvailable {meminfo_mb():.0f} MB < {p['mem_floor']} at {i}"
            break
        tasks.append(asyncio.create_task(one(tok)))
        target = t_c0 + (i + 1) * interval
        d = target - time.time()
        if d > 0:
            await asyncio.sleep(d)
    await asyncio.gather(*tasks)
    t_connected = time.time()
    rss1 = rss_mb()
    min_mem = meminfo_mb()
    while time.time() < p["t_measure_end"] + 0.5:
        await asyncio.sleep(0.5)
        min_mem = min(min_mem, meminfo_mb())
    for pr in protos:
        if pr.transport:
            pr.transport.abort()
    return {"connected": len(protos), "failed": failed, "stopped_for_mem": stopped_for_mem,
            "connect_s": round(t_connected - t_c0, 3), "rss0_mb": round(rss0, 1),
            "rss_connected_mb": round(rss1, 1), "lat_ms": lat_ms, "age_ms": age_ms, "cnt": cnt,
            "min_mem_avail_mb": round(min_mem, 1)}


def ws_worker(p: dict) -> dict:
    return uvloop.run(_ws_worker(p))


# ----------------------------------------------------------------------------- poll


async def _poll_worker(p: dict) -> dict:
    import aiohttp

    connector = aiohttp.TCPConnector(limit=0, force_close=True)
    session = aiohttp.ClientSession(connector=connector, timeout=aiohttp.ClientTimeout(total=10))
    lat_ms: list[float] = []
    fresh_ms: list[float] = []
    cnt = {"req": 0, "ok": 0, "err": 0, "bytes": 0, "new_tick": 0, "missed_ticks": 0}
    m0, m1 = p["t_measure_start"], p["t_measure_end"]
    url = f"http://{p['host']}:{p['port']}/v1/market"

    async def client(i: int):
        rng = random.Random(i + p["seed"])
        last_tick = None
        t_next = p["t_start"] + rng.uniform(0, p["interval"])
        while True:
            d = t_next - time.time()
            if d > 0:
                await asyncio.sleep(d)
            if time.time() > m1:
                return
            t0 = time.time()
            try:
                async with session.get(url, headers={"Connection": "close"}) as r:
                    body = await r.read()
                    ok = r.status == 200
            except Exception:  # noqa: BLE001
                ok, body = False, b""
            t1 = time.time()
            if m0 <= t0 <= m1:
                cnt["req"] += 1
                if ok:
                    cnt["ok"] += 1
                    cnt["bytes"] += len(body)
                    lat_ms.append((t1 - t0) * 1000)
                else:
                    cnt["err"] += 1
            if ok:
                snap = json.loads(body)
                tick = snap["tick"]
                if last_tick is not None and tick > last_tick and m0 <= t0 <= m1:
                    cnt["new_tick"] += 1
                    cnt["missed_ticks"] += tick - last_tick - 1
                    fresh_ms.append((t1 - snap["pub_at"]) * 1000)
                last_tick = tick
            t_next += p["interval"]

    rss0 = rss_mb()
    await asyncio.gather(*(client(i) for i in range(p["n"])))
    rss1 = rss_mb()
    await session.close()
    return {"lat_ms": lat_ms, "fresh_ms": fresh_ms, "cnt": cnt, "rss0_mb": rss0, "rss_mb": rss1}


def poll_worker(p: dict) -> dict:
    return uvloop.run(_poll_worker(p))


# ----------------------------------------------------------------------------- reconnect


async def _rc_worker(p: dict) -> dict:
    loop = asyncio.get_running_loop()
    events: list[tuple] = []  # (t_drop, t_back, attempts)
    attempts_ts: list[float] = []
    state = {"connected": 0}
    stop_at = p["t_stop"]

    def backoff(k: int, rng: random.Random) -> float:
        if p["policy"] == "fixed1":
            return 1.0
        return rng.uniform(0, min(p["cap"], p["base"] * 2**k))  # full jitter

    async def client(tok: str, i: int):
        rng = random.Random(i + 17)
        k = 0
        t_drop = None
        tries = 0
        await asyncio.sleep(max(0.0, p["t_connect_start"] - time.time()) + i / p["connect_rate"])
        while time.time() < stop_at:
            pr = WSClient(p["host"], p["port"], tok, lambda _b: None)
            tries += 1
            if t_drop is not None:
                attempts_ts.append(time.time())
            try:
                await loop.create_connection(lambda: pr, p["host"], p["port"])
                await asyncio.wait_for(pr.opened, 5)
            except Exception:  # noqa: BLE001
                if pr.transport:
                    pr.transport.abort()
                await asyncio.sleep(backoff(k, rng))
                k += 1
                continue
            if t_drop is not None:
                events.append((t_drop, time.time(), tries))
            state["connected"] += 1
            k, tries = 0, 0
            remaining = stop_at - time.time()
            try:
                t_drop = await asyncio.wait_for(asyncio.shield(pr.closed), max(0.1, remaining))
            except asyncio.TimeoutError:
                pr.transport.abort()
                return
            state["connected"] -= 1
            await asyncio.sleep(backoff(k, rng))
            k += 1

    await asyncio.gather(*(client(t, i) for i, t in enumerate(p["tokens"])))
    return {"events": events, "attempts_ts": attempts_ts, "n": len(p["tokens"])}


def rc_worker(p: dict) -> dict:
    return uvloop.run(_rc_worker(p))


# ----------------------------------------------------------------------------- parent


def split(lst: list, k: int) -> list[list]:
    return [lst[i::k] for i in range(k)]


def stats(vals: list[float]) -> dict:
    v = sorted(vals)
    return {"n": len(v), "p50": pctl(v, 0.5), "p90": pctl(v, 0.9), "p99": pctl(v, 0.99),
            "max": round(v[-1], 3) if v else None}


async def lo_baseline(seconds: float = 3.0) -> float:
    a = lo_bytes()[0]
    await asyncio.sleep(seconds)
    return (lo_bytes()[0] - a) / seconds


async def cmd_ws(a) -> None:
    if meminfo_mb() < a.mem_floor:
        raise SystemExit(f"MemAvailable {meminfo_mb():.0f} MB < --mem-floor {a.mem_floor}; not starting")
    tokens = load_tokens(a.tokens)[: a.n]
    env_before = env_snapshot()
    srv = psutil.Process(a.server_pid)
    srv_rss0 = srv.memory_info().rss / 2**20
    base_lo = await lo_baseline()
    pool = cf.ProcessPoolExecutor(a.procs, mp_context=mp.get_context("spawn"))
    await asyncio.gather(*(asyncio.wrap_future(pool.submit(time.sleep, 0.1)) for _ in range(a.procs)))
    t_c = time.time() + 1.0
    connect_budget = a.n / a.connect_rate + 5
    t_m0 = t_c + connect_budget
    t_m1 = t_m0 + a.duration
    futs = [asyncio.wrap_future(pool.submit(ws_worker, {
        "tokens": part, "host": a.host, "port": a.port, "connect_rate": a.connect_rate / a.procs,
        "t_connect_start": t_c, "t_measure_start": t_m0, "t_measure_end": t_m1,
        "mem_floor": a.mem_floor})) for part in split(tokens, a.procs)]
    sampler = Sampler(a.server_pid, None, interval=0.5, mem_floor_mb=a.mem_floor)
    sampler.start()
    await asyncio.sleep(max(0.0, t_m0 - time.time()))
    srv_rss_conn = srv.memory_info().rss / 2**20
    dbg0 = await fetch_json(a.base, "/debug/stats?last=0")
    sampler.mark("a")
    await asyncio.sleep(a.duration)
    sampler.mark("b")
    parts = await asyncio.gather(*futs)
    await sampler.stop()
    pool.shutdown()
    dbg = await fetch_json(a.base, "/debug/stats?last=200")
    win = sampler.window("a", "b")
    connected = sum(x["connected"] for x in parts)
    bc = [b for b in dbg.get("broadcasts", []) if t_m0 * 1e9 <= b["sent_ns"] <= t_m1 * 1e9]
    res = {
        "cmd": "ws", "label": a.label, "args": vars(a), "env_before": env_before,
        "connected": connected, "failed": sum(x["failed"] for x in parts),
        "stopped_for_mem": [x["stopped_for_mem"] for x in parts if x["stopped_for_mem"]],
        "server_ws_conns_at_measure": dbg0.get("ws_conns"),
        "connect_s": max(x["connect_s"] for x in parts),
        "latency_ms_send_to_recv": stats([v for x in parts for v in x["lat_ms"]]),
        "age_ms_publish_to_recv": stats([v for x in parts for v in x["age_ms"]]),
        "msgs_in_window": sum(x["cnt"]["msgs"] for x in parts),
        "payload_bytes_in_window": sum(x["cnt"]["bytes"] for x in parts),
        "broadcasts_in_window": bc,
        "fanout_s": stats([b["fanout_s"] * 1000 for b in bc]),
        "server_rss_mb_before": round(srv_rss0, 1),
        "server_rss_mb_connected": round(srv_rss_conn, 1),
        "server_kb_per_conn": round((srv_rss_conn - srv_rss0) * 1024 / connected, 2) if connected else None,
        "client_kb_per_conn": round(sum(x["rss_connected_mb"] - x["rss0_mb"] for x in parts) * 1024 / connected, 2) if connected else None,
        "lo_baseline_bytes_per_s": round(base_lo, 1),
        "system": win,
        "min_mem_avail_mb": min([x["min_mem_avail_mb"] for x in parts] + [win["mem_available_mb_min"]]),
    }
    res["lo_bytes_per_s_net"] = round(win["lo_bytes_per_s"] - base_lo, 1)
    write_json(a.out, res)
    print(json.dumps({k: res[k] for k in ("connected", "failed", "stopped_for_mem", "connect_s",
                      "latency_ms_send_to_recv", "fanout_s", "server_kb_per_conn", "client_kb_per_conn",
                      "lo_bytes_per_s_net", "min_mem_avail_mb")}, ensure_ascii=False))
    print({k: win[k] for k in ("server_cpu_pct", "server_rss_mb_peak", "cpu2_other_pct", "cpu2_mhz_mean")})


async def cmd_poll(a) -> None:
    if meminfo_mb() < a.mem_floor:
        raise SystemExit(f"MemAvailable {meminfo_mb():.0f} MB < --mem-floor {a.mem_floor}; not starting")
    env_before = env_snapshot()
    base_lo = await lo_baseline()
    pool = cf.ProcessPoolExecutor(a.procs, mp_context=mp.get_context("spawn"))
    await asyncio.gather(*(asyncio.wrap_future(pool.submit(time.sleep, 0.1)) for _ in range(a.procs)))
    t_s = time.time() + 1.0
    t_m0 = t_s + a.warmup
    t_m1 = t_m0 + a.duration
    per = [a.n // a.procs + (1 if i < a.n % a.procs else 0) for i in range(a.procs)]
    futs = [asyncio.wrap_future(pool.submit(poll_worker, {
        "n": per[i], "seed": i * 100000, "host": a.host, "port": a.port, "interval": a.interval,
        "t_start": t_s, "t_measure_start": t_m0, "t_measure_end": t_m1})) for i in range(a.procs)]
    sampler = Sampler(a.server_pid, None, interval=0.5, mem_floor_mb=a.mem_floor)
    sampler.start()
    await asyncio.sleep(max(0.0, t_m0 - time.time()))
    sampler.mark("a")
    await asyncio.sleep(a.duration)
    sampler.mark("b")
    parts = await asyncio.gather(*futs)
    await sampler.stop()
    pool.shutdown()
    win = sampler.window("a", "b")
    cnt: dict = {}
    for x in parts:
        for k, v in x["cnt"].items():
            cnt[k] = cnt.get(k, 0) + v
    res = {"cmd": "poll", "label": a.label, "args": vars(a), "env_before": env_before,
           "counts": cnt, "req_per_s": round(cnt["req"] / a.duration, 1),
           "latency_ms": stats([v for x in parts for v in x["lat_ms"]]),
           "freshness_ms_publish_to_recv": stats([v for x in parts for v in x["fresh_ms"]]),
           "lo_baseline_bytes_per_s": round(base_lo, 1), "system": win,
           "client_rss_mb": [round(x["rss_mb"], 1) for x in parts]}
    res["lo_bytes_per_s_net"] = round(win["lo_bytes_per_s"] - base_lo, 1)
    write_json(a.out, res)
    print(json.dumps({k: res[k] for k in ("counts", "req_per_s", "latency_ms",
                      "freshness_ms_publish_to_recv", "lo_bytes_per_s_net")}, ensure_ascii=False))
    print({k: win[k] for k in ("server_cpu_pct", "server_rss_mb_peak", "cpu2_other_pct", "cpu2_mhz_mean",
                                "mem_available_mb_min")})


async def cmd_reconnect(a) -> None:
    if meminfo_mb() < a.mem_floor:
        raise SystemExit(f"MemAvailable {meminfo_mb():.0f} MB < --mem-floor {a.mem_floor}; not starting")
    tokens = load_tokens(a.tokens)[: a.n]
    env_before = env_snapshot()
    pool = cf.ProcessPoolExecutor(a.procs, mp_context=mp.get_context("spawn"))
    await asyncio.gather(*(asyncio.wrap_future(pool.submit(time.sleep, 0.1)) for _ in range(a.procs)))
    t_c = time.time() + 1.0
    t_kill = t_c + a.n / a.connect_rate + 5
    t_stop = t_kill + a.gap + a.observe
    futs = [asyncio.wrap_future(pool.submit(rc_worker, {
        "tokens": part, "host": a.host, "port": a.port, "connect_rate": a.connect_rate / a.procs,
        "t_connect_start": t_c, "t_stop": t_stop, "policy": a.policy, "base": a.base_delay,
        "cap": a.cap})) for part in split(tokens, a.procs)]
    await asyncio.sleep(max(0.0, t_kill - time.time()))
    dbg = await fetch_json(a.base, "/debug/stats?last=0")
    conns_before = dbg.get("ws_conns")
    old_pid = int(open(os.path.join(a.run_dir, "server.pid")).read())
    os.kill(old_pid, signal.SIGKILL)
    t_killed = time.time()
    await asyncio.sleep(a.gap)
    t_restart = time.time()
    proc = subprocess.Popen(["scripts/server.sh", "start"], stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL, env=os.environ.copy())
    t_up = None
    import aiohttp
    async with aiohttp.ClientSession() as s:
        while t_up is None and time.time() < t_restart + 30:
            try:
                async with s.get(a.base + "/healthz", timeout=aiohttp.ClientTimeout(total=0.5)) as r:
                    if r.status == 200:
                        t_up = time.time()
            except Exception:  # noqa: BLE001
                await asyncio.sleep(0.02)
    proc.wait()
    parts = await asyncio.gather(*futs)
    pool.shutdown()
    dbg2 = await fetch_json(a.base, "/debug/stats?last=0")
    ev = [e for x in parts for e in x["events"] if e[0] >= t_killed - 1]
    att = sorted(t for x in parts for t in x["attempts_ts"] if t >= t_killed - 1)
    since_up = [(e[1] - t_up) * 1000 for e in ev] if t_up else []
    since_drop = [(e[1] - e[0]) * 1000 for e in ev]
    per_sec: dict[int, int] = {}
    for t in att:
        if t_up and t >= t_up:
            per_sec[int(t - t_up)] = per_sec.get(int(t - t_up), 0) + 1
    res = {
        "cmd": "reconnect", "label": a.label, "args": vars(a), "env_before": env_before,
        "ws_conns_before_kill": conns_before, "ws_conns_after": dbg2.get("ws_conns"),
        "old_pid": old_pid, "new_pid": dbg2.get("pid"),
        "restart_to_healthy_s": round(t_up - t_restart, 3) if t_up else None,
        "reconnected": len(ev), "n": a.n,
        "reconnect_ms_since_server_up": stats(since_up),
        "reconnect_ms_since_drop": stats(since_drop),
        "attempts_per_client": stats([e[2] for e in ev]),
        "attempts_total_after_kill": len(att),
        "attempts_per_s_after_up_first10s": [per_sec.get(i, 0) for i in range(10)],
    }
    write_json(a.out, res)
    print(json.dumps({k: res[k] for k in res if k not in ("args", "env_before")}, ensure_ascii=False))


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=18080)
    p.add_argument("--server-pid", type=int)
    p.add_argument("--tokens", required=True)
    p.add_argument("--procs", type=int, default=2)
    p.add_argument("--mem-floor", type=float, default=900)
    p.add_argument("--label", default="ws")
    p.add_argument("--out", required=True)
    sub = p.add_subparsers(dest="cmd", required=True)
    w = sub.add_parser("ws")
    w.add_argument("--n", type=int, required=True)
    w.add_argument("--connect-rate", type=float, default=500)
    w.add_argument("--duration", type=float, default=30)
    q = sub.add_parser("poll")
    q.add_argument("--n", type=int, required=True)
    q.add_argument("--interval", type=float, default=10)
    q.add_argument("--warmup", type=float, default=12)
    q.add_argument("--duration", type=float, default=30)
    r = sub.add_parser("reconnect")
    r.add_argument("--n", type=int, required=True)
    r.add_argument("--connect-rate", type=float, default=500)
    r.add_argument("--gap", type=float, default=5)
    r.add_argument("--observe", type=float, default=60)
    r.add_argument("--policy", choices=("jitter", "fixed1"), default="jitter")
    r.add_argument("--base-delay", type=float, default=0.5)
    r.add_argument("--cap", type=float, default=30)
    r.add_argument("--run-dir", default=os.environ.get("COW_RUN_DIR", ""))
    a = p.parse_args()
    a.base = f"http://{a.host}:{a.port}"
    fn = {"ws": cmd_ws, "poll": cmd_poll, "reconnect": cmd_reconnect}[a.cmd]
    uvloop.run(fn(a))


if __name__ == "__main__":
    main()
