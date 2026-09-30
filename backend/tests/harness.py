"""在服務層重跑經濟情境（不經過資料庫，速度和研究模擬差不多）。

ServiceWorld 照 docs/research/economy/sim/world.py 的時間軸、上線排程、市場 tick 與統計移植；
差別是玩家動作全部經過 server.game.Game（伺服器的服務層）與 server.bots（移植的策略）。
情境資料照 docs/research/economy/sim/scenarios.py 複製一份（純資料）。
"""

from __future__ import annotations

import heapq
import math
import random
import statistics
import sys
import time
from array import array
from pathlib import Path
from typing import Dict, List, Optional

BACKEND = Path(__file__).resolve().parent.parent
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

from cowecon.params import DAY, DEFAULT, HOUR, MINUTE, with_overrides  # noqa: E402
from server import bots as B  # noqa: E402
from server.game import Game  # noqa: E402
from server.population import TUTORIAL_S, Schedule, sample_local_minute  # noqa: E402

START_EPOCH = 1791129600.0  # 2026-10-05（週一）00:00 台灣時間

# ---------------------------------------------------------------------------
# 情境（照 docs/research/economy/sim/scenarios.py）
# ---------------------------------------------------------------------------
DAYS = 30
DUMP_H = 20 * 24 + 21  # 大戶倒貨：第 21 天晚上 21:00
EVENT_H = 20 * 24 + 20  # 大利多：第 21 天晚上 20:00
LOW_DAY = 15  # 線上很少的那一天


def base(players: int, seed: int, tick_s: int = 60, days: int = DAYS) -> dict:
    return {"name": f"base_{players}_s{seed}", "group": "base", "players": players, "days": days, "tick_s": tick_s, "seed": seed}


def whale(players: int, mode: str, cows: int, seed: int = 1) -> dict:
    return {
        "name": f"whale_{players}_{cows}cows_{mode}_s{seed}", "group": "whale", "players": players, "days": 23, "tick_s": 60, "seed": seed,
        "whale": {"cows": cows, "mode": mode, "hoard_from_h": DUMP_H - 48, "dump_at_h": DUMP_H if mode != "hold" else 10 ** 6, "batches": 8, "batch_gap_h": 3.0},
    }


def panic(players: int, with_panic: bool, seed: int = 1) -> dict:
    sc = {
        "name": f"event_{players}_{'panic' if with_panic else 'calm'}_s{seed}", "group": "event", "players": players, "days": 23, "tick_s": 60, "seed": seed,
        "inject_events": [{"targets": ["milk", "beef"], "factor": 1.4, "at_h": EVENT_H, "half_life_h": 4.0, "headline": "（情境）全國牧場節：鮮奶、牛肉收購價大漲"}],
    }
    if with_panic:
        sc["panic"] = {"at_h": EVENT_H + 0.25, "share": 0.6, "window_min": 30}
    return sc


def low_online(players: int, seed: int = 1, low: bool = True) -> dict:
    return {"name": f"low_{players}_s{seed}" + ("" if low else "_ref"), "group": "low", "players": players, "days": 20, "tick_s": 60, "seed": seed,
            "low_online_days": {LOW_DAY: 0.2} if low else {}}


# ---------------------------------------------------------------------------
# 帳本（每位玩家「類別 × 第幾天」的收支）
# ---------------------------------------------------------------------------
AMOUNT_KINDS = ("milk", "beef", "calf", "breed", "expand", "bucket", "warehouse", "fresh")
QTY_KINDS = ("milk", "beef", "collect", "spoiled")


class Ledger:
    __slots__ = ("t0", "n", "amount", "qty")
    _AIDX = {k: i for i, k in enumerate(AMOUNT_KINDS)}
    _QIDX = {k: i for i, k in enumerate(QTY_KINDS)}

    def __init__(self, t0: float, n_days: int):
        self.t0 = t0
        self.n = n_days
        self.amount = array("d", [0.0]) * (len(AMOUNT_KINDS) * n_days)
        self.qty = array("d", [0.0]) * (len(QTY_KINDS) * n_days)

    def append(self, rec) -> None:
        now, kind, amount, qty = rec
        d = int((now - self.t0) // DAY)
        if d < 0 or d >= self.n:
            return
        i = self._AIDX.get(kind)
        if i is not None:
            self.amount[i * self.n + d] += amount
        j = self._QIDX.get(kind)
        if j is not None:
            self.qty[j * self.n + d] += qty

    def amount_days(self, kind: str, d0: int, d1: int) -> float:
        i = self._AIDX[kind]
        return sum(self.amount[i * self.n + d] for d in range(d0, min(d1, self.n)))


# ---------------------------------------------------------------------------
# 世界
# ---------------------------------------------------------------------------
class ServiceWorld:
    def __init__(self, scenario: dict, seed: int):
        sc = self.sc = scenario
        self.seed = seed
        self.params = with_overrides(DEFAULT, sc.get("overrides", {}))
        self.t0 = START_EPOCH
        self.dt = float(sc.get("tick_s", 60))
        self.n_days = int(sc["days"])
        self.ticks_per_day = int(round(DAY / self.dt))
        self.n_ticks = self.n_days * self.ticks_per_day
        # 服務層（和伺服器同一個 Game 類別）；市場亂數的種子和研究模擬相同
        self.game = Game(self.params, seed, self.t0, events_enabled=sc.get("events", True))
        self.ex = self.game.ex
        self.online_int = array("d", [0.0]) * (self.n_ticks + 2)
        self.online_frac = array("d", [0.0]) * (self.n_ticks + 2)
        self.heap: List[tuple] = []
        self._seq = 0
        self.low_days = {int(d): float(k) for d, k in sc.get("low_online_days", {}).items()}

        n = int(sc["players"])
        mix = sc.get("mix", {"S1": 0.25, "S2": 0.25, "S3": 0.25, "S4": 0.25})
        strategies = self._assign(n, mix)
        self.bots: List[B.Bot] = []
        for pid in range(n):
            self._add_bot(pid, strategies[pid])

        wcfg = sc.get("whale")
        self.whale: Optional[B.Bot] = None
        if wcfg:
            pid = len(self.bots)
            join = self.t0 + wcfg.get("join_h", 0.0) * HOUR
            b = self._add_bot(pid, "S5", join=join)
            B.setup_whale(b, join + TUTORIAL_S, {
                "cows": wcfg["cows"], "mode": wcfg["mode"],
                "hoard_from": self.t0 + wcfg["hoard_from_h"] * HOUR, "dump_at": self.t0 + wcfg["dump_at_h"] * HOUR,
                "batches": wcfg.get("batches", 1), "batch_gap_s": wcfg.get("batch_gap_h", 1.0) * HOUR,
            })
            b.tut_end = join
            self.whale = b

        for ev in sc.get("inject_events", []):
            self.ex.inject_event(
                targets=ev["targets"], factor=ev["factor"], start_at=self.t0 + ev["at_h"] * HOUR,
                half_life_s=ev.get("half_life_h", 4.0) * HOUR, announce_lead_s=ev.get("announce_min", 0) * MINUTE,
                headline=ev.get("headline", "（情境事件）"),
            )
        pan = sc.get("panic")
        if pan:
            prng = random.Random(f"{seed}:panic")
            t_start = self.t0 + pan["at_h"] * HOUR
            for b in self.bots:
                if prng.random() < pan["share"]:
                    self.schedule(t_start + prng.uniform(0, pan["window_min"] * MINUTE), b.pid, "panic_sell", 5 * MINUTE)

        self.rec: Dict[str, array] = {k: array("d") for k in ("t", "milk", "beef", "online", "milk_e", "beef_e", "milk_y", "beef_y")}
        self.wall: dict = {}

    # ---- 給 bot 用的 ctx ----
    def upcoming(self, now: float):
        return self.ex.upcoming(now)

    def schedule(self, t: float, pid: int, kind: str, dur: float) -> None:
        self._seq += 1
        heapq.heappush(self.heap, (t, self._seq, pid, kind))
        if dur > 0:
            self._add_online(t, dur)

    # ---- 建構 ----
    def _assign(self, n: int, mix: Dict[str, float]) -> List[str]:
        names = list(mix)
        counts = [int(math.floor(n * mix[k])) for k in names]
        i = 0
        while sum(counts) < n:
            counts[i % len(names)] += 1
            i += 1
        out: List[str] = []
        for k, c in zip(names, counts):
            out += [k] * c
        random.Random(f"{self.seed}:assign").shuffle(out)
        return out

    def _add_bot(self, pid: int, strategy: str, join: Optional[float] = None) -> B.Bot:
        rng_s = random.Random(f"{self.seed}:sched:{pid}")
        rng_a = random.Random(f"{self.seed}:bot:{pid}")
        sched = Schedule(rng_s)
        if join is None:
            join_h = self.sc.get("join_spread_h")
            if join_h is None:
                m = (sample_local_minute(rng_s) + sched.shift_min) % 1440.0
                join = self.t0 + m * MINUTE
            else:
                join = self.t0 + rng_s.uniform(0, join_h) * HOUR
        p = self.game.create_player(join, f"bot{pid}", is_bot=True, rng=rng_a, pid=pid)
        b = B.Bot(self.game, pid, strategy, join, rng=rng_a)
        b.sched = sched
        b.ledger = Ledger(self.t0, self.n_days)
        b.worth = [0.0] * self.n_days
        p.farm.log = b.ledger
        self.bots.append(b)
        if strategy != "S5":
            for k in range(int(TUTORIAL_S // MINUTE)):
                self.schedule(join + k * MINUTE, pid, "tutorial", 0.0)
            self._add_online(join, TUTORIAL_S)
        return b

    def _add_online(self, s: float, dur: float) -> None:
        a = (s - self.t0) / self.dt
        b = (s + dur - self.t0) / self.dt
        if b <= 0 or a >= self.n_ticks:
            return
        a = max(a, 0.0)
        b = min(b, float(self.n_ticks))
        ia, ib = int(a), int(b)
        if ia == ib:
            self.online_frac[ia] += b - a
        else:
            self.online_frac[ia] += ia + 1 - a
            self.online_frac[ib] += b - ib
            self.online_int[ia + 1] += 1.0
            self.online_int[ib] -= 1.0

    def _schedule_day(self, day: int) -> None:
        day_start = self.t0 + day * DAY
        keep = self.low_days.get(day, 1.0)
        for b in self.bots:
            for s, dur in b.sched.day_sessions(day_start, keep):
                if s < b.tut_end:
                    continue
                self.schedule(s, b.pid, "session", dur)

    # ---- 執行 ----
    def run(self, stop_after_ticks: Optional[int] = None) -> "ServiceWorld":
        t_wall = time.time()
        rec = self.rec
        mk, bk = self.ex.markets["milk"], self.ex.markets["beef"]
        run_int = 0.0
        tick = 0
        n_actions = 0
        for day in range(self.n_days):
            self._schedule_day(day)
            for _ in range(self.ticks_per_day):
                t = self.t0 + tick * self.dt
                t_end = t + self.dt
                heap = self.heap
                while heap and heap[0][0] < t_end:
                    t_ev, _, pid, kind = heapq.heappop(heap)
                    if t_ev < self.t0 + self.n_days * DAY:
                        B.act(self.bots[pid], self, t_ev, kind)
                        n_actions += 1
                run_int += self.online_int[tick]
                online = run_int + self.online_frac[tick]
                self.game.tick(t_end, online)
                self.game.captured.clear()  # 沒有資料庫：成交紀錄不用留
                rec["t"].append(t_end)
                rec["milk"].append(mk.price)
                rec["beef"].append(bk.price)
                rec["online"].append(online)
                rec["milk_e"].append(mk.excess)
                rec["beef_e"].append(bk.excess)
                rec["milk_y"].append(mk.pressure)
                rec["beef_y"].append(bk.pressure)
                tick += 1
            t_day = self.t0 + (day + 1) * DAY
            for b in self.bots:
                b.worth[day] = b.farm.net_worth(t_day, mk.price, bk.price)
        self.wall = {"seconds": time.time() - t_wall, "actions": n_actions}
        return self


# ---------------------------------------------------------------------------
# 統計（照 docs/research/economy/sim/analyze.py、report.py）
# ---------------------------------------------------------------------------
WEEKS = ((0, 7), (7, 14), (14, 21), (21, 28))


def price_stats(ratios, lo=0.6, hi=1.7) -> dict:
    n = len(ratios)
    xs = sorted(ratios)

    def pct(q):
        k = (n - 1) * q
        a, b = math.floor(k), math.ceil(k)
        return xs[a] + (xs[b] - xs[a]) * (k - a)

    return {
        "inside_soft_band": sum(1 for r in ratios if lo <= r <= hi) / n,
        "p1": pct(0.01), "p50": pct(0.5), "p99": pct(0.99), "min": xs[0], "max": xs[-1],
    }


def strategy_weeks(w: ServiceWorld) -> Dict[str, dict]:
    groups: Dict[str, list] = {}
    for b in w.bots:
        groups.setdefault(b.strategy, []).append(b)
    out = {}
    for s, bs in sorted(groups.items()):
        weeks = []
        for d0, d1 in WEEKS:
            if d1 > w.n_days:
                break
            rev = [b.ledger.amount_days("milk", d0, d1) + b.ledger.amount_days("beef", d0, d1) for b in bs]
            weeks.append(statistics.fmean(rev))
        out[s] = {"n": len(bs), "weeks": weeks, "total": sum(weeks)}
    return out


def goal_b(w: ServiceWorld) -> dict:
    st = strategy_weeks(w)
    keys = ("S1", "S2", "S3", "S4")
    weeks = []
    for i in range(len(st["S1"]["weeks"])):
        vals = {k: st[k]["weeks"][i] for k in keys}
        weeks.append(max(vals.values()) / min(vals.values()))
    tot = {k: st[k]["total"] for k in keys}
    return {"week_max_over_min": weeks, "total": tot, "top": max(tot, key=tot.get), "S4_over_S1": tot["S4"] / tot["S1"]}


def onboarding(w: ServiceWorld) -> dict:
    ob = [b for b in w.bots if b.strategy != "S5"]
    out = {"of": len(ob)}
    for key in ("first_sale", "first_expand", "first_breed"):
        vals = sorted(getattr(b, key) / MINUTE for b in ob if getattr(b, key) is not None)
        out[key] = {"n": len(vals), "median": vals[len(vals) // 2] if vals else None, "max": vals[-1] if vals else None}
    return out


def whale_totals(w: ServiceWorld) -> dict:
    tot: Dict[str, dict] = {}
    for kind, t, units, proceeds, values, price, disc in w.whale.whale["results"]:
        d = tot.setdefault(kind, {"units": 0.0, "proceeds": 0.0, "value_units": 0.0, "price_x_value": 0.0})
        d["units"] += units
        d["proceeds"] += proceeds
        d["value_units"] += values
        d["price_x_value"] += price * values
    for d in tot.values():
        d["avg_price"] = d["proceeds"] / d["value_units"]
        d["avg_market_price"] = d["price_x_value"] / d["value_units"]
        d["slip"] = 1 - d["avg_price"] / d["avg_market_price"]
    return tot


def gap_stats(w_a: ServiceWorld, w_b: ServiceWorld, cid: str, t_evt_h: float, direct_h: float = 3.0, horizon_h: float = 18.0) -> dict:
    """w_a 相對對照組 w_b（同 seed）的價格差距。照 report.py 的 _gap_stats。"""
    direct, full = [], []
    for t, a, b in zip(w_a.rec["t"], w_a.rec[cid], w_b.rec[cid]):
        th = (t - w_a.t0) / HOUR
        if t_evt_h <= th <= t_evt_h + horizon_h:
            g = 1.0 - a / b
            full.append((th, g))
            if th <= t_evt_h + direct_h:
                direct.append((th, g))
    t_max, g_max = max(direct, key=lambda x: x[1])
    rec90 = None
    if g_max >= 0.003:
        for th, g in full:
            if th >= t_max and g <= 0.1 * g_max:
                rec90 = th - t_evt_h
                break
    return {"max_drop_direct": g_max, "t_max_h": t_max - t_evt_h, "recover_90pct_h": rec90}
