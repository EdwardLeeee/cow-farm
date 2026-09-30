"""模擬世界：時間軸、玩家上線、市場 tick、紀錄與統計。

用法（程式內）：summary = World(scenario, seed).run()
scenario 是純資料 dict（見 scenarios.py），M1 伺服器測試可以直接沿用。
"""

from __future__ import annotations

import heapq
import math
import random
import statistics
import time
from array import array
from typing import Dict, List, Optional

from cowecon.market import Exchange
from cowecon.params import DAY, DEFAULT, HOUR, MINUTE, with_overrides

from . import bots as B
from .population import TUTORIAL_S, Schedule, sample_local_minute

# bot 可調常數的預設值（情境可以用 scenario["bot"] 覆寫）
BOT_TUNABLES = {k: getattr(B, k) for k in (
    "BUCKET_TARGET_H", "DAIRY_SHIP_FRAC", "S4_PRICE_THR", "S4_FRESH_SELL", "S4_WH_TARGET_H",
    "S4_BEEF_WAIT_FRAC", "S4_BULL_WAIT_H", "S4_HOLD_MIN_COWS", "PANIC_SHIP_AGE_H",
)}

START_EPOCH = 1791129600.0  # 2026-10-05（週一）00:00 台灣時間

AMOUNT_KINDS = ("milk", "beef", "calf", "breed", "expand", "bucket", "warehouse", "fresh")
QTY_KINDS = ("milk", "beef", "collect", "spoiled")


class Ledger:
    """每位玩家「類別 × 第幾天」的收支（array，省記憶體）。"""

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

    def qty_days(self, kind: str, d0: int, d1: int) -> float:
        j = self._QIDX[kind]
        return sum(self.qty[j * self.n + d] for d in range(d0, min(d1, self.n)))


class World:
    def __init__(self, scenario: dict, seed: int):
        sc = self.sc = scenario
        self.seed = seed
        self.params = with_overrides(DEFAULT, sc.get("overrides", {}))
        for k, v in BOT_TUNABLES.items():
            setattr(B, k, sc.get("bot", {}).get(k, v))
        for k in sc.get("bot", {}):
            if k not in BOT_TUNABLES:
                raise KeyError(f"未知 bot 參數：{k}")
        self.t0 = START_EPOCH
        self.dt = float(sc.get("tick_s", 60))
        self.n_days = int(sc["days"])
        self.ticks_per_day = int(round(DAY / self.dt))
        self.n_ticks = self.n_days * self.ticks_per_day
        self.ex = Exchange(self.params, seed, self.t0, events_enabled=sc.get("events", True))
        B._MARKETS.clear()
        B._MARKETS.update(self.ex.markets)
        self.online_int = array("d", [0.0]) * (self.n_ticks + 2)
        self.online_frac = array("d", [0.0]) * (self.n_ticks + 2)
        self.heap: List[tuple] = []
        self._seq = 0
        self.low_days = {int(d): float(k) for d, k in sc.get("low_online_days", {}).items()}

        # 玩家
        n = int(sc["players"])
        mix = sc.get("mix", {"S1": 0.25, "S2": 0.25, "S3": 0.25, "S4": 0.25})
        strategies = self._assign(n, mix)
        self.bots: List[B.Bot] = []
        for pid in range(n):
            self._add_bot(pid, strategies[pid])

        # 大戶
        wcfg = sc.get("whale")
        self.whale: Optional[B.Bot] = None
        if wcfg:
            pid = len(self.bots)
            join = self.t0 + wcfg.get("join_h", 0.0) * HOUR
            b = self._add_bot(pid, "S5", join=join)
            B.setup_whale(b, join + TUTORIAL_S, {
                "cows": wcfg["cows"],
                "mode": wcfg["mode"],
                "hoard_from": self.t0 + wcfg["hoard_from_h"] * HOUR,
                "dump_at": self.t0 + wcfg["dump_at_h"] * HOUR,
                "batches": wcfg.get("batches", 1),
                "batch_gap_s": wcfg.get("batch_gap_h", 1.0) * HOUR,
            })
            b.tut_end = join  # 大戶跳過教學
            self.whale = b

        # 指定事件
        for ev in sc.get("inject_events", []):
            self.ex.inject_event(
                targets=ev["targets"], factor=ev["factor"], start_at=self.t0 + ev["at_h"] * HOUR,
                half_life_s=ev.get("half_life_h", 4.0) * HOUR, announce_lead_s=ev.get("announce_min", 0) * MINUTE,
                headline=ev.get("headline", "（情境事件）"),
            )
        # 恐慌賣：事件後一段時間內，指定比例的玩家都上線賣
        panic = sc.get("panic")
        if panic:
            prng = random.Random(f"{seed}:panic")
            t_start = self.t0 + panic["at_h"] * HOUR
            for b in self.bots:
                if prng.random() < panic["share"]:
                    self.schedule(t_start + prng.uniform(0, panic["window_min"] * MINUTE), b.pid, "panic_sell", 5 * MINUTE)

        # 紀錄
        self.rec: Dict[str, array] = {k: array("d") for k in (
            "t", "milk", "beef", "online", "milk_e", "beef_e", "milk_y", "beef_y", "milk_x", "beef_x",
            "milk_ev", "beef_ev", "milk_D", "milk_flow", "beef_D", "beef_flow",
        )}
        self.wall = {}

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
        b = B.Bot(pid, strategy, self.params, join, rng_a, sched, Ledger(self.t0, self.n_days), self.n_days)
        self.bots.append(b)
        if strategy != "S5":
            for k in range(int(TUTORIAL_S // MINUTE)):
                self.schedule(join + k * MINUTE, pid, "tutorial", 0.0)
            self._add_online(join, TUTORIAL_S)
        return b

    def schedule(self, t: float, pid: int, kind: str, dur: float) -> None:
        self._seq += 1
        heapq.heappush(self.heap, (t, self._seq, pid, kind))
        if dur > 0:
            self._add_online(t, dur)

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
            if b.strategy == "S5" and b.whale is not None and day == 0:
                pass
            for s, dur in b.sched.day_sessions(day_start, keep):
                if s < b.tut_end:
                    continue
                self.schedule(s, b.pid, "session", dur)

    # ---- 執行 ----
    def run(self, progress: bool = False) -> dict:
        t_wall = time.time()
        bots = self.bots
        rec = self.rec
        mk, bk = self.ex.markets["milk"], self.ex.markets["beef"]
        run_int = 0.0
        tick = 0
        n_sessions = 0
        for day in range(self.n_days):
            self._schedule_day(day)
            for _ in range(self.ticks_per_day):
                t = self.t0 + tick * self.dt
                t_end = t + self.dt
                heap = self.heap
                while heap and heap[0][0] < t_end:
                    t_ev, _, pid, kind = heapq.heappop(heap)
                    if t_ev < self.t0 + self.n_days * DAY:
                        B.act(bots[pid], self, t_ev, kind)
                        n_sessions += 1
                run_int += self.online_int[tick]
                online = run_int + self.online_frac[tick]
                self.ex.step(t_end, online)
                rec["t"].append(t_end)
                rec["milk"].append(mk.price)
                rec["beef"].append(bk.price)
                rec["online"].append(online)
                rec["milk_e"].append(mk.excess)
                rec["beef_e"].append(bk.excess)
                rec["milk_y"].append(mk.pressure)
                rec["beef_y"].append(bk.pressure)
                rec["milk_x"].append(mk.x)
                rec["beef_x"].append(bk.x)
                rec["milk_ev"].append(mk.event_log)
                rec["beef_ev"].append(bk.event_log)
                rec["milk_D"].append(mk.demand_rate())
                rec["milk_flow"].append(mk.flow)
                rec["beef_D"].append(bk.demand_rate())
                rec["beef_flow"].append(bk.flow)
                tick += 1
            # 每天結束：記錄每位玩家的總資產
            t_day = self.t0 + (day + 1) * DAY
            for b in bots:
                b.worth[day] = b.farm.net_worth(t_day, mk.price, bk.price)
            if progress:
                print(f"  day {day + 1}/{self.n_days}  sessions={n_sessions}  wall={time.time() - t_wall:.0f}s", flush=True)
        self.wall = {"seconds": time.time() - t_wall, "actions": n_sessions}
        return self.summary()

    # ---- 統計 ----
    def summary(self) -> dict:
        from .analyze import price_stats, strategy_weeks

        p = self.params
        out = {
            "scenario": self.sc,
            "seed": self.seed,
            "params_fingerprint": p.fingerprint(),
            "tick_s": self.dt,
            "wall": self.wall,
            "players": len(self.bots),
        }
        out["price"] = {
            "milk": price_stats([x / p.milk.base_price for x in self.rec["milk"]], self.dt),
            "beef": price_stats([x / p.beef.base_price for x in self.rec["beef"]], self.dt),
        }
        out["online"] = {
            "mean": statistics.fmean(self.rec["online"]),
            "max": max(self.rec["online"]),
        }
        out["excess_mean"] = {
            "milk": statistics.fmean(self.rec["milk_e"]),
            "beef": statistics.fmean(self.rec["beef_e"]),
        }
        out["pressure_mean"] = {
            "milk": statistics.fmean(self.rec["milk_y"]),
            "beef": statistics.fmean(self.rec["beef_y"]),
        }
        out["strategies"] = strategy_weeks(self)
        ob = [b for b in self.bots if b.strategy != "S5"]

        def pct(xs, q):
            xs = sorted(xs)
            return xs[min(len(xs) - 1, int(q * len(xs)))] if xs else None

        onboarding = {}
        for key in ("first_sale", "first_expand", "first_breed"):
            vals = [getattr(b, key) / MINUTE for b in ob if getattr(b, key) is not None]
            onboarding[key] = {
                "n": len(vals), "of": len(ob),
                "median_min": pct(vals, 0.5), "p90_min": pct(vals, 0.9), "max_min": max(vals) if vals else None,
                "min_min": min(vals) if vals else None,
            }
        out["onboarding"] = onboarding
        out["events"] = [ev.to_dict() for ev in self.ex.event_log_history]
        if self.whale is not None:
            out["whale"] = whale_summary(self)
        return out


def whale_summary(w: World) -> dict:
    b = w.whale
    res = b.whale["results"]
    out = {"mode": b.whale["mode"], "cows": b.whale["cows"], "orders": []}
    tot = {}
    for kind, t, units, proceeds, values, price, disc in res:
        out["orders"].append({"kind": kind, "t_h": (t - w.t0) / HOUR, "units": units, "proceeds": proceeds, "value_units": values, "price": price, "avg_discount": disc})
        d = tot.setdefault(kind, {"units": 0.0, "proceeds": 0.0, "value_units": 0.0, "price_x_value": 0.0})
        d["units"] += units
        d["proceeds"] += proceeds
        d["value_units"] += values
        d["price_x_value"] += price * values
    for kind, d in tot.items():
        # 平均成交價（每單位「有效量」= 數量 × 新鮮度 × 稀有度 × 肉質），與同時段市價的比
        d["avg_price"] = d["proceeds"] / d["value_units"] if d["value_units"] else None
        d["avg_market_price"] = d["price_x_value"] / d["value_units"] if d["value_units"] else None
    out["totals"] = tot
    return out
