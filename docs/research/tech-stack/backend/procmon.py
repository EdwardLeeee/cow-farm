"""量測期間的系統取樣：伺服器程序 CPU／RSS、PG 容器 cgroup、MemAvailable 看門狗、lo 流量。"""

from __future__ import annotations

import asyncio
import os
import platform
import time

import psutil

WATCH_CPUS = (2, 3, 6, 7)


def meminfo_mb(key: str = "MemAvailable") -> float:
    with open("/proc/meminfo") as f:
        for line in f:
            if line.startswith(key + ":"):
                return int(line.split()[1]) / 1024
    return float("nan")


def lo_bytes() -> tuple[int, int]:
    with open("/proc/net/dev") as f:
        for line in f:
            if line.strip().startswith("lo:"):
                parts = line.split(":", 1)[1].split()
                return int(parts[0]), int(parts[8])  # rx_bytes, tx_bytes
    return 0, 0


def cpu_jiffies() -> dict[int, tuple[int, int]]:
    """每顆邏輯 CPU 的 (busy, total) jiffies。"""
    out = {}
    with open("/proc/stat") as f:
        for line in f:
            if line.startswith("cpu") and line[3].isdigit():
                name, *vals = line.split()
                vals = list(map(int, vals))
                idle = vals[3] + vals[4]
                total = sum(vals[:8])
                out[int(name[3:])] = (total - idle, total)
    return out


def cur_mhz(cpu: int) -> float | None:
    try:
        with open(f"/sys/devices/system/cpu/cpu{cpu}/cpufreq/scaling_cur_freq") as f:
            return int(f.read()) / 1000
    except OSError:
        return None


def vmstat(keys=("allocstall_normal", "allocstall_movable", "pgscan_direct", "pgmajfault")) -> dict:
    out = {}
    with open("/proc/vmstat") as f:
        for line in f:
            k, v = line.split()
            if k in keys:
                out[k] = int(v)
    return out


def cgroup_dir(pid: int) -> str | None:
    try:
        with open(f"/proc/{pid}/cgroup") as f:
            path = f.read().strip().split("::", 1)[1]
    except (OSError, IndexError):
        return None
    d = "/sys/fs/cgroup" + path
    # podman 會在 libpod-<id>.scope 底下再開 container 子群組；往上找到含所有程序的那層
    if d.endswith("/container"):
        d = d[: -len("/container")]
    return d


def cgroup_cpu_usec(d: str) -> int:
    with open(os.path.join(d, "cpu.stat")) as f:
        for line in f:
            if line.startswith("usage_usec"):
                return int(line.split()[1])
    return 0


def cgroup_mem(d: str) -> int:
    try:
        with open(os.path.join(d, "memory.current")) as f:
            return int(f.read())
    except OSError:
        return 0


def env_snapshot() -> dict:
    return {
        "time": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "loadavg": os.getloadavg(),
        "mem_available_mb": round(meminfo_mb(), 1),
        "swap_free_mb": round(meminfo_mb("SwapFree"), 1),
        "cpu_mhz": {c: cur_mhz(c) for c in WATCH_CPUS},
        "python": platform.python_version(),
    }


class Sampler:
    def __init__(self, server_pid: int | None = None, pg_pid: int | None = None,
                 interval: float = 0.5, mem_floor_mb: float = 1000.0):
        self.server = psutil.Process(server_pid) if server_pid else None
        self.pg_cg = cgroup_dir(pg_pid) if pg_pid else None
        self.me = psutil.Process()
        self.interval = interval
        self.mem_floor_mb = mem_floor_mb
        self.abort_reason: str | None = None
        self.samples: list[dict] = []
        self._task: asyncio.Task | None = None
        self._marks: dict[str, dict] = {}

    def _point(self) -> dict:
        p = {"t": time.monotonic(), "mem_avail_mb": meminfo_mb(), "lo": lo_bytes(),
             "cpus": cpu_jiffies(), "me_cpu": sum(self.me.cpu_times()[:2]),
             "mhz2": cur_mhz(2), "vm": vmstat()}
        if self.server:
            try:
                ct = self.server.cpu_times()
                p["srv_cpu"] = ct.user + ct.system
                p["srv_sys"] = ct.system
                p["srv_rss"] = self.server.memory_info().rss
                p["srv_threads"] = self.server.num_threads()
                p["srv_fds"] = self.server.num_fds()
            except psutil.Error:
                p["srv_gone"] = True
        if self.pg_cg:
            p["pg_cpu_usec"] = cgroup_cpu_usec(self.pg_cg)
            p["pg_mem"] = cgroup_mem(self.pg_cg)
        return p

    def mark(self, name: str) -> None:
        self._marks[name] = self._point()

    async def _loop(self) -> None:
        while True:
            pt = self._point()
            self.samples.append({k: pt[k] for k in pt if k not in ("cpus", "vm")})
            if pt["mem_avail_mb"] < self.mem_floor_mb and not self.abort_reason:
                self.abort_reason = f"MemAvailable {pt['mem_avail_mb']:.0f} MB < {self.mem_floor_mb} MB"
            await asyncio.sleep(self.interval)

    def start(self) -> None:
        self._task = asyncio.create_task(self._loop())

    async def stop(self) -> None:
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass

    def window(self, a: str, b: str) -> dict:
        """兩個 mark 之間的 CPU%、流量等。CPU% 以 1 顆邏輯 CPU＝100%。"""
        pa, pb = self._marks[a], self._marks[b]
        dt = pb["t"] - pa["t"]
        out: dict = {"window_s": round(dt, 3)}
        in_win = [s for s in self.samples if pa["t"] <= s["t"] <= pb["t"]]
        if "srv_cpu" in pa and "srv_cpu" in pb:
            out["server_cpu_pct"] = round((pb["srv_cpu"] - pa["srv_cpu"]) / dt * 100, 1)
            out["server_cpu_s"] = round(pb["srv_cpu"] - pa["srv_cpu"], 3)
            out["server_sys_cpu_s"] = round(pb["srv_sys"] - pa["srv_sys"], 3)
            rss = [s["srv_rss"] for s in in_win if "srv_rss" in s] + [pb.get("srv_rss", 0)]
            out["server_rss_mb_peak"] = round(max(rss) / 2**20, 1)
            out["server_rss_mb_end"] = round(pb.get("srv_rss", 0) / 2**20, 1)
            out["server_rss_mb_start"] = round(pa.get("srv_rss", 0) / 2**20, 1)
            out["server_fds_peak"] = max([s.get("srv_fds", 0) for s in in_win] + [pb.get("srv_fds", 0)])
        if "pg_cpu_usec" in pa and "pg_cpu_usec" in pb:
            out["pg_cpu_pct"] = round((pb["pg_cpu_usec"] - pa["pg_cpu_usec"]) / 1e6 / dt * 100, 1)
            out["pg_cpu_s"] = round((pb["pg_cpu_usec"] - pa["pg_cpu_usec"]) / 1e6, 3)
            out["pg_mem_mb_peak"] = round(max([s.get("pg_mem", 0) for s in in_win] + [pb["pg_mem"]]) / 2**20, 1)
        out["loadgen_cpu_pct"] = round((pb["me_cpu"] - pa["me_cpu"]) / dt * 100, 1)
        rx = pb["lo"][0] - pa["lo"][0]
        out["lo_bytes_per_s"] = round(rx / dt, 1)
        out["mem_available_mb_min"] = round(min([s["mem_avail_mb"] for s in in_win] + [pb["mem_avail_mb"]]), 1)
        busy = {}
        for c in WATCH_CPUS:
            b0, t0 = pa["cpus"][c]
            b1, t1 = pb["cpus"][c]
            busy[c] = round((b1 - b0) / max(1, t1 - t0) * 100, 1)
        out["cpu_busy_pct"] = busy
        if "server_cpu_pct" in out:
            # 同一顆 CPU 2 上其他程序（非伺服器）佔用的比例，用來判斷外部干擾
            out["cpu2_other_pct"] = round(busy[2] - out["server_cpu_pct"], 1)
        mhz = [s["mhz2"] for s in in_win if s.get("mhz2")]
        out["cpu2_mhz_mean"] = round(sum(mhz) / len(mhz)) if mhz else None
        out["vmstat_delta"] = {k: pb["vm"][k] - pa["vm"].get(k, 0) for k in pb["vm"]}
        return out
