"""HTTP 負載產生器（aiohttp＋uvloop，單一 asyncio 程序）。

子命令
  seed   建立 N 個訪客帳號，token 存到 scratchpad（不要放進 repo）
  mixed  N 個同時在線玩家，每人每 10–20 秒一個動作：30% GET farm、30% GET market、25% collect、15% sell
  ramp   固定速率（open-loop）階梯加壓，同樣的動作比例，找單核飽和點
  sell   只打 POST /v1/sell 的 closed-loop 併發測試（每個 worker 用不同玩家）

連線模式
  close      每個請求新開 TCP 連線並帶 Connection: close（主要模式：uvicorn 預設 keep-alive 5 秒，
             比玩家 10–20 秒的操作間隔短，真實手機多半每次都要重新連線）
  keepalive  連線池重用連線
"""

from __future__ import annotations

import argparse
import asyncio
import gzip
import json
import math
import os
import random
import time

import aiohttp
import uvloop

from procmon import Sampler, env_snapshot

MIX = (("farm", 0.30), ("market", 0.30), ("collect", 0.25), ("sell", 0.15))


def pick(rng: random.Random) -> str:
    r = rng.random()
    acc = 0.0
    for name, w in MIX:
        acc += w
        if r < acc:
            return name
    return MIX[-1][0]


def pctl(sorted_vals: list[float], q: float) -> float | None:
    """nearest-rank 百分位。"""
    if not sorted_vals:
        return None
    k = max(0, min(len(sorted_vals) - 1, math.ceil(q * len(sorted_vals)) - 1))
    return round(sorted_vals[k], 3)


def classify(ep: str, status) -> str:
    if isinstance(status, int):
        if 200 <= status < 300:
            return "ok"
        if ep == "sell" and status == 409:
            return "business"  # 存貨不足：遊戲規則內的結果，不算錯誤
        return f"http_{status}"
    return f"exc_{status}"


def summarize(rows: list[tuple], window_s: float) -> dict:
    out: dict = {"window_s": round(window_s, 3)}
    groups: dict[str, list] = {}
    for r in rows:
        groups.setdefault(r[0], []).append(r)
    groups["ALL"] = rows
    for ep, rs in groups.items():
        cls: dict[str, int] = {}
        lats = []
        for _ep, _t, lat, st in rs:
            c = classify(_ep, st)
            cls[c] = cls.get(c, 0) + 1
            if c in ("ok", "business"):
                lats.append(lat)
        lats.sort()
        n = len(rs)
        err = sum(v for k, v in cls.items() if k not in ("ok", "business"))
        out[ep] = {
            "count": n,
            "rps": round(n / window_s, 2) if window_s else None,
            "classes": cls,
            "error_rate": round(err / n, 5) if n else None,
            "p50_ms": pctl(lats, 0.50),
            "p90_ms": pctl(lats, 0.90),
            "p99_ms": pctl(lats, 0.99),
            "p999_ms": pctl(lats, 0.999),
            "max_ms": round(lats[-1], 3) if lats else None,
            "mean_ms": round(sum(lats) / len(lats), 3) if lats else None,
        }
    return out


def write_raw(path: str, rows: list[tuple]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with gzip.open(path, "wt") as f:
        f.write("endpoint,start_s,latency_ms,status\n")
        for ep, t, lat, st in rows:
            f.write(f"{ep},{t:.4f},{lat:.3f},{st}\n")


def write_json(path: str, obj: dict) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)
    print(f"wrote {path}")


class Client:
    def __init__(self, base: str, conn_mode: str, limit: int, timeout_s: float = 10.0):
        self.base = base
        self.close = conn_mode == "close"
        connector = aiohttp.TCPConnector(limit=limit, force_close=self.close, ttl_dns_cache=None)
        self.session = aiohttp.ClientSession(
            connector=connector, timeout=aiohttp.ClientTimeout(total=timeout_s)
        )

    async def request(self, ep: str, token: str, rng: random.Random) -> tuple[object, float]:
        h = {"Authorization": f"Bearer {token}"}
        if self.close:
            h["Connection"] = "close"
        body = None
        if ep == "farm":
            method, path = "GET", "/v1/farm"
        elif ep == "market":
            method, path = "GET", "/v1/market"
        elif ep == "collect":
            method, path = "POST", "/v1/collect"
        elif ep == "sell":
            method, path = "POST", "/v1/sell"
            body = {"commodity": "milk", "qty": rng.randint(1, 10)}
        elif ep == "sell1":
            method, path = "POST", "/v1/sell"
            body = {"commodity": "milk", "qty": 1}
        else:
            raise ValueError(ep)
        t0 = time.perf_counter()
        try:
            async with self.session.request(method, self.base + path, headers=h, json=body) as r:
                await r.read()
                st: object = r.status
        except Exception as e:  # noqa: BLE001
            st = type(e).__name__
        return st, (time.perf_counter() - t0) * 1000

    async def aclose(self) -> None:
        await self.session.close()


async def fetch_json(base: str, path: str) -> dict | None:
    try:
        async with aiohttp.ClientSession() as s, s.get(base + path) as r:
            return await r.json()
    except Exception as e:  # noqa: BLE001
        return {"error": repr(e)}


def load_tokens(path: str) -> list[str]:
    with open(path) as f:
        return json.load(f)["tokens"]


# ----------------------------------------------------------------------------- seed


async def cmd_seed(a) -> None:
    client = Client(a.base, "keepalive", a.concurrency)
    tokens: list[str] = []
    rows = []
    sem = asyncio.Semaphore(a.concurrency)
    t_begin = time.perf_counter()

    async def one(i: int):
        async with sem:
            t0 = time.perf_counter()
            try:
                async with client.session.post(a.base + "/v1/session") as r:
                    data = await r.json()
                    st = r.status
                    if st == 201:
                        tokens.append(data["token"])
            except Exception as e:  # noqa: BLE001
                st = type(e).__name__
            rows.append(("session", t0 - t_begin, (time.perf_counter() - t0) * 1000, st))

    await asyncio.gather(*(one(i) for i in range(a.n)))
    wall = time.perf_counter() - t_begin
    await client.aclose()
    os.makedirs(os.path.dirname(a.tokens), exist_ok=True)
    with open(a.tokens, "w") as f:
        json.dump({"tokens": tokens}, f)
    res = {"cmd": "seed", "args": vars(a), "wall_s": round(wall, 3),
           "sessions_per_s": round(len(tokens) / wall, 1), "summary": summarize(rows, wall)}
    write_json(a.out, res)


# ----------------------------------------------------------------------------- mixed


async def cmd_mixed(a) -> None:
    tokens = load_tokens(a.tokens)[: a.users]
    assert len(tokens) >= a.users, f"only {len(tokens)} tokens"
    env_before = env_snapshot()
    client = Client(a.base, a.conn, a.limit)
    sampler = Sampler(a.server_pid, a.pg_pid, interval=0.5, mem_floor_mb=a.mem_floor)
    sampler.start()
    rows: list[tuple] = []
    t_begin = time.monotonic()
    m_start = t_begin + a.warmup
    m_end = m_start + a.duration
    state = {"stopping": False, "inflight": 0, "started": 0}

    async def vu(i: int):
        rng = random.Random(i * 7919 + a.seed)
        await asyncio.sleep(rng.uniform(0, a.think_max))
        while not state["stopping"]:
            ep = pick(rng)
            ts = time.monotonic()
            state["inflight"] += 1
            state["started"] += 1
            st, lat = await client.request(ep, tokens[i], rng)
            state["inflight"] -= 1
            if m_start <= ts < m_end:
                rows.append((ep, ts - m_start, lat, st))
            if state["stopping"]:
                break
            await asyncio.sleep(rng.uniform(a.think_min, a.think_max))

    tasks = [asyncio.create_task(vu(i)) for i in range(a.users)]
    aborted = None
    while time.monotonic() < m_start:
        await asyncio.sleep(0.2)
        if sampler.abort_reason:
            aborted = sampler.abort_reason
            break
    sampler.mark("a")
    while not aborted and time.monotonic() < m_end:
        await asyncio.sleep(0.2)
        if sampler.abort_reason:
            aborted = sampler.abort_reason
    sampler.mark("b")
    state["stopping"] = True
    grace_end = time.monotonic() + 10
    while state["inflight"] > 0 and time.monotonic() < grace_end:
        await asyncio.sleep(0.05)
    for t in tasks:
        t.cancel()
    await asyncio.gather(*tasks, return_exceptions=True)
    await sampler.stop()
    await client.aclose()
    window = sampler.window("a", "b")
    res = {
        "cmd": "mixed",
        "label": a.label,
        "args": vars(a),
        "env_before": env_before,
        "aborted": aborted,
        "inflight_at_end": state["inflight"],
        "system": window,
        "summary": summarize(rows, window["window_s"]),
        "server_debug": await fetch_json(a.base, "/debug/stats?last=5"),
    }
    s = res["summary"]["ALL"]
    if s["count"] and "server_cpu_s" in window:
        res["server_cpu_ms_per_req"] = round(window["server_cpu_s"] / s["count"] * 1000, 4)
        if "pg_cpu_s" in window:
            res["total_cpu_ms_per_req"] = round(
                (window["server_cpu_s"] + window["pg_cpu_s"]) / s["count"] * 1000, 4
            )
    write_raw(os.path.join(a.raw_dir, f"{a.label}.csv.gz"), rows)
    write_json(a.out, res)
    print(json.dumps({"ALL": s, "system": window, "per_req": {
        k: res.get(k) for k in ("server_cpu_ms_per_req", "total_cpu_ms_per_req")}}, indent=1))


# ----------------------------------------------------------------------------- ramp


async def _ramp_worker(p: dict) -> dict:
    """單一產生器程序：在指定的牆鐘時間開始，以固定速率（open-loop）送 step 秒。"""
    tokens = load_tokens(p["tokens"])
    client = Client(p["base"], p["conn"], p["limit"])
    rng = random.Random(p["seed"])
    rows: list[tuple] = []
    lags: list[float] = []
    state = {"inflight": 0, "dropped": 0}
    rate = p["rate"]
    await asyncio.sleep(max(0.0, p["t_start_wall"] - time.time()))
    cpu0 = time.process_time()
    t0 = time.monotonic()

    async def one(intended: float, ep: str, tok: str):
        start = time.monotonic()
        lags.append((start - intended) * 1000)
        state["inflight"] += 1
        st, _lat = await client.request(ep, tok, rng)
        state["inflight"] -= 1
        # 延遲從「預定送出時間」算起，含產生器排隊（避免 coordinated omission）
        rows.append((ep, intended - t0, (time.monotonic() - intended) * 1000, st))

    sent = 0
    pending: set = set()
    while True:
        el = time.monotonic() - t0
        if el >= p["step"]:
            break
        due = int(el * rate)
        while sent < due:
            if state["inflight"] >= p["max_inflight"]:
                state["dropped"] += 1
            else:
                tk = asyncio.create_task(
                    one(t0 + sent / rate, pick(rng), tokens[rng.randrange(len(tokens))])
                )
                pending.add(tk)
                tk.add_done_callback(pending.discard)
            sent += 1
        await asyncio.sleep(0.005)
    send_cpu = time.process_time() - cpu0
    if pending:
        await asyncio.wait(pending, timeout=15)
    await client.aclose()
    return {"rows": rows, "lags": lags, "dropped": state["dropped"], "sent": sent,
            "cpu_s": time.process_time() - cpu0, "send_cpu_s": send_cpu}


def ramp_worker(p: dict) -> dict:
    return uvloop.run(_ramp_worker(p))


async def cmd_ramp(a) -> None:
    import concurrent.futures as cf
    import multiprocessing as mp

    env_before = env_snapshot()
    pool = cf.ProcessPoolExecutor(a.procs, mp_context=mp.get_context("spawn"))
    # 先讓子程序啟動完成
    await asyncio.gather(*(asyncio.wrap_future(pool.submit(time.sleep, 0.1)) for _ in range(a.procs)))
    sampler = Sampler(a.server_pid, a.pg_pid, interval=0.5, mem_floor_mb=a.mem_floor)
    sampler.start()
    steps = []
    for rate in [float(x) for x in a.rates.split(",")]:
        t_start = time.time() + 1.0
        futs = [
            asyncio.wrap_future(pool.submit(ramp_worker, {
                "tokens": a.tokens, "base": a.base, "conn": a.conn, "limit": a.limit,
                "seed": a.seed * 1000 + i + int(rate), "rate": rate / a.procs, "step": a.step,
                "max_inflight": a.max_inflight, "t_start_wall": t_start}))
            for i in range(a.procs)
        ]
        await asyncio.sleep(max(0.0, t_start - time.time()))
        sampler.mark(f"a{rate}")
        await asyncio.sleep(a.step)
        sampler.mark(f"b{rate}")
        parts = await asyncio.gather(*futs)
        rows = [r for part in parts for r in part["rows"]]
        lags = sorted(x for part in parts for x in part["lags"])
        win = sampler.window(f"a{rate}", f"b{rate}")
        summ = summarize(rows, a.step)
        gen_cpu = [round(part["send_cpu_s"] / a.step * 100, 1) for part in parts]
        step = {
            "target_rps": rate,
            "system": win,
            "summary_all": summ["ALL"],
            "summary": summ,
            "generator_procs": a.procs,
            "generator_cpu_pct_each": gen_cpu,
            "dropped_at_generator": sum(part["dropped"] for part in parts),
            "gen_lag_p50_ms": pctl(lags, 0.5),
            "gen_lag_p99_ms": pctl(lags, 0.99),
            "generator_limited": max(gen_cpu) > 90 or (pctl(lags, 0.99) or 0) > 50,
        }
        if summ["ALL"]["count"] and "server_cpu_s" in win:
            step["server_cpu_ms_per_req"] = round(win["server_cpu_s"] / summ["ALL"]["count"] * 1000, 4)
            if "pg_cpu_s" in win:
                step["total_cpu_ms_per_req"] = round(
                    (win["server_cpu_s"] + win["pg_cpu_s"]) / summ["ALL"]["count"] * 1000, 4)
        steps.append(step)
        write_raw(os.path.join(a.raw_dir, f"{a.label}_r{int(rate)}.csv.gz"), rows)
        sa = summ["ALL"]
        print(f"rate {rate:>6.0f}: got {sa['rps']} rps p50 {sa['p50_ms']} p99 {sa['p99_ms']} "
              f"err {sa['error_rate']} srvCPU {win.get('server_cpu_pct')}% pgCPU {win.get('pg_cpu_pct')} "
              f"genCPU {gen_cpu} lag99 {step['gen_lag_p99_ms']} drop {step['dropped_at_generator']} "
              f"memMin {win['mem_available_mb_min']}", flush=True)
        if sampler.abort_reason:
            break
        if (sa["p99_ms"] or 0) > a.slo_ms or (sa["error_rate"] or 0) > 0.01:
            break
        await asyncio.sleep(a.cooldown)
    await sampler.stop()
    pool.shutdown()
    res = {"cmd": "ramp", "label": a.label, "args": vars(a), "env_before": env_before,
           "aborted": sampler.abort_reason, "steps": steps}
    write_json(a.out, res)


# ----------------------------------------------------------------------------- sell


async def cmd_sell(a) -> None:
    tokens = load_tokens(a.tokens)
    env_before = env_snapshot()
    sampler = Sampler(a.server_pid, a.pg_pid, interval=0.5, mem_floor_mb=a.mem_floor)
    sampler.start()
    levels = []
    for c in [int(x) for x in a.concurrency.split(",")]:
        assert c <= len(tokens)
        client = Client(a.base, "keepalive", c)
        rows: list[tuple] = []
        t_end = [0.0]

        async def worker(i: int, rows=rows, client=client, t_end=t_end):
            rng = random.Random(i)
            while time.monotonic() < t_end[0]:
                ts = time.monotonic()
                st, lat = await client.request("sell1", tokens[i], rng)
                rows.append(("sell", ts, lat, st))

        # 暖身 2 秒（建立連線）後才開始計
        t_end[0] = time.monotonic() + 2
        await asyncio.gather(*(worker(i) for i in range(c)))
        rows.clear()
        sampler.mark(f"a{c}")
        t0 = time.monotonic()
        t_end[0] = t0 + a.duration
        await asyncio.gather(*(worker(i) for i in range(c)))
        sampler.mark(f"b{c}")
        await client.aclose()
        win = sampler.window(f"a{c}", f"b{c}")
        rows = [(ep, ts - t0, lat, st) for ep, ts, lat, st in rows]
        summ = summarize(rows, win["window_s"])["ALL"]
        lvl = {"concurrency": c, "system": win, "summary": summ}
        levels.append(lvl)
        write_raw(os.path.join(a.raw_dir, f"{a.label}_c{c}.csv.gz"), rows)
        print(f"c={c:>4}: {summ['classes']} ok/s {round(summ['classes'].get('ok', 0) / win['window_s'], 1)} "
              f"p50 {summ['p50_ms']} p99 {summ['p99_ms']} srvCPU {win.get('server_cpu_pct')}% "
              f"pgCPU {win.get('pg_cpu_pct')} genCPU {win['loadgen_cpu_pct']}%", flush=True)
        if sampler.abort_reason:
            break
        await asyncio.sleep(2)
    await sampler.stop()
    res = {"cmd": "sell", "label": a.label, "args": vars(a), "env_before": env_before,
           "aborted": sampler.abort_reason, "levels": levels,
           "server_debug": await fetch_json(a.base, "/debug/stats?last=1")}
    write_json(a.out, res)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--base", default="http://127.0.0.1:18080")
    p.add_argument("--server-pid", type=int)
    p.add_argument("--pg-pid", type=int)
    p.add_argument("--mem-floor", type=float, default=1000.0)
    p.add_argument("--seed", type=int, default=1)
    p.add_argument("--out", required=True)
    p.add_argument("--raw-dir", default="results/raw")
    p.add_argument("--label", default="run")
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("seed")
    s.add_argument("--n", type=int, required=True)
    s.add_argument("--concurrency", type=int, default=32)
    s.add_argument("--tokens", required=True)
    m = sub.add_parser("mixed")
    m.add_argument("--tokens", required=True)
    m.add_argument("--users", type=int, required=True)
    m.add_argument("--warmup", type=float, default=20)
    m.add_argument("--duration", type=float, default=60)
    m.add_argument("--think-min", type=float, default=10)
    m.add_argument("--think-max", type=float, default=20)
    m.add_argument("--conn", choices=("close", "keepalive"), default="close")
    m.add_argument("--limit", type=int, default=2000)
    r = sub.add_parser("ramp")
    r.add_argument("--tokens", required=True)
    r.add_argument("--rates", required=True)
    r.add_argument("--step", type=float, default=20)
    r.add_argument("--cooldown", type=float, default=3)
    r.add_argument("--slo-ms", type=float, default=250)
    r.add_argument("--max-inflight", type=int, default=2000)
    r.add_argument("--conn", choices=("close", "keepalive"), default="close")
    r.add_argument("--limit", type=int, default=2000)
    r.add_argument("--procs", type=int, default=2)
    se = sub.add_parser("sell")
    se.add_argument("--tokens", required=True)
    se.add_argument("--concurrency", default="1,8,32,128")
    se.add_argument("--duration", type=float, default=15)
    a = p.parse_args()
    fn = {"seed": cmd_seed, "mixed": cmd_mixed, "ramp": cmd_ramp, "sell": cmd_sell}[a.cmd]
    uvloop.run(fn(a))


if __name__ == "__main__":
    main()
