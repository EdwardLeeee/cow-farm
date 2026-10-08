"""模擬世界（v0.2；v0.3 加照顧的統計）：時間軸、玩家上線、三個市場的 tick、借種市場、紀錄與統計。

用法（程式內）：summary = World(scenario, seed).run()
scenario 是純資料 dict（見 scenarios.py），M1 伺服器測試可以直接沿用。
"""

from __future__ import annotations

import heapq
import random
import statistics
import time
from array import array
from typing import Dict, List, Optional

from cowecon.farm import StudMarket
from cowecon.market import Exchange
from cowecon.params import DAY, DEFAULT, HOUR, MINUTE, with_overrides

from . import bots as B
from .population import TUTORIAL_S, Schedule, sample_local_minute

START_EPOCH = 1791129600.0  # 2026-10-05（週一）00:00 台灣時間

# bot 可調常數的預設值（情境可以用 scenario["bot"] 覆寫）
BOT_TUNABLES = {k: getattr(B, k) for k in (
    "BUCKET_TARGET_H", "DAIRY_SHIP_FRAC", "RARE_KEEP_FRAC", "PEAK_H", "BULL_WAIT_MAX_H", "HOLD_THR", "HOLD_FRESH_SELL",
    "HOLD_WH_TARGET_H", "HOLD_MIN_COWS", "STUD_RELIST_H", "PANIC_SHIP_AGE_H", "TRACK_PLAYERS", "SHOP_CHOICE_SCALE",
    "SICK_P_DAY", "HELPER_AHEAD_D", "LAZY_CLEAN_H", "CURE_PROD_H", "FLOOR_GAIN",
)}

AMOUNT_KINDS = ("milk", "beef", "rice", "calf", "breed", "expand", "bucket", "warehouse", "fresh", "field", "stud_in", "stud_out",
                "feed_buy", "cure", "helper", "floor")
QTY_KINDS = ("milk", "beef", "rice", "collect", "spoiled", "harvest", "breed", "stud_in", "stud_out",
             "grade_A", "grade_B", "grade_C", "shop_A", "shop_B", "shop_C",
             "feed_buy", "feed", "clean", "sick", "cure", "bonus_kg", "hybrid", "rare_grown")
REVENUE_KINDS = ("milk", "beef", "rice", "stud_in")  # 收入 = 賣出收入 + 借種收入
# v0.3 照顧的花費。玩法週收入差距的目標用「收入 − 照顧花費」比（使用者 2026-10-08 選的口徑；只算收入的照舊列出當參考）
CARE_KINDS = ("floor", "helper", "feed_buy", "cure")


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

    def revenue_days(self, d0: int, d1: int) -> float:
        return sum(self.amount_days(k, d0, d1) for k in REVENUE_KINDS)

    def care_days(self, d0: int, d1: int) -> float:
        """照顧花費（正數）：地板、小幫手、飼料、治療。"""
        return -sum(self.amount_days(k, d0, d1) for k in CARE_KINDS)


class World:
    def __init__(self, scenario: dict, seed: int):
        sc = self.sc = scenario
        self.seed = seed
        self.params = with_overrides(DEFAULT, sc.get("overrides", {}))
        self.cids = tuple(self.params.commodity_ids)
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
        self.stud = StudMarket(self.params)
        self.npc_rng = random.Random(f"{seed}:npc")
        self.stud.npc_refill(self.t0, self.npc_rng)
        self.stud_log: List[tuple] = []  # (時間, 價錢, 主人策略或 None, 借的人策略, 公牛用途, 公牛稀有度)
        self.online_int = array("d", [0.0]) * (self.n_ticks + 2)
        self.online_frac = array("d", [0.0]) * (self.n_ticks + 2)
        self.heap: List[tuple] = []
        self._seq = 0
        self.low_days = {int(d): float(k) for d, k in sc.get("low_online_days", {}).items()}
        self.bots: List[B.Bot] = []
        B._W.clear()
        B._W.update({"ex": self.ex, "stud": self.stud, "bots": self.bots, "npc_rng": self.npc_rng, "world": self})

        # 玩家
        n = int(sc["players"])
        mix = sc.get("mix", {k: 1.0 / len(B.PLAYER_STRATEGIES) for k in B.PLAYER_STRATEGIES})
        strategies = self._assign(n, mix)
        for pid in range(n):
            self._add_bot(pid, strategies[pid])

        # 大戶
        wcfg = sc.get("whale")
        self.whale: Optional[B.Bot] = None
        if wcfg:
            b = self._add_bot(len(self.bots), "W")
            B.setup_whale(b, {
                "cows": wcfg["cows"],
                "mode": wcfg["mode"],
                "hoard_from": self.t0 + wcfg["hoard_from_h"] * HOUR,
                "dump_at": self.t0 + wcfg["dump_at_h"] * HOUR,
                "batches": wcfg.get("batches", 1),
                "batch_gap_s": wcfg.get("batch_gap_h", 1.0) * HOUR,
            })
            self.whale = b
            # 囤貨開始那一刻一定要有一次上線（換成大牧場）
            self.schedule(self.t0 + wcfg["hoard_from_h"] * HOUR, b.pid, "session", 5 * MINUTE)

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
                if b.strategy != "W" and prng.random() < panic["share"]:
                    self.schedule(t_start + prng.uniform(0, panic["window_min"] * MINUTE), b.pid, "panic_sell", 5 * MINUTE)

        # 紀錄
        keys = ["t", "online"]
        for cid in self.cids:
            # _xn：新聞以外的部分（基本價倍數，D33 起軟邊界只管這部分）
            keys += [cid, f"{cid}_e", f"{cid}_y", f"{cid}_x", f"{cid}_ev", f"{cid}_xn", f"{cid}_D", f"{cid}_flow"]
        self.rec: Dict[str, array] = {k: array("d") for k in keys}
        self.wall = {}

    # ---- 建構 ----
    def _assign(self, n: int, mix: Dict[str, float]) -> List[str]:
        names = list(mix)
        counts = [int(n * mix[k]) for k in names]
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
        if pid < B.TRACK_PLAYERS:
            b.farm.track = {}
        b.farm.stats = {}
        self.bots.append(b)
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
            for s, dur in b.sched.day_sessions(day_start, keep):
                if s < b.tut_end:
                    continue
                self.schedule(s, b.pid, "session", dur)

    # ---- 執行 ----
    def run(self, progress: bool = False) -> dict:
        t_wall = time.time()
        bots = self.bots
        rec = self.rec
        mks = [(cid, self.ex.markets[cid]) for cid in self.cids]
        run_int = 0.0
        tick = 0
        n_sessions = 0
        t_end_all = self.t0 + self.n_days * DAY
        for day in range(self.n_days):
            self._schedule_day(day)
            for _ in range(self.ticks_per_day):
                t = self.t0 + tick * self.dt
                t_end = t + self.dt
                heap = self.heap
                while heap and heap[0][0] < t_end:
                    t_ev, _, pid, kind = heapq.heappop(heap)
                    if t_ev < t_end_all:
                        B.act(bots[pid], self, t_ev, kind)
                        n_sessions += 1
                run_int += self.online_int[tick]
                online = run_int + self.online_frac[tick]
                self.ex.step(t_end, online)
                rec["t"].append(t_end)
                rec["online"].append(online)
                for cid, m in mks:
                    rec[cid].append(m.price)
                    rec[f"{cid}_e"].append(m.excess)
                    rec[f"{cid}_y"].append(m.pressure)
                    rec[f"{cid}_x"].append(m.x)
                    rec[f"{cid}_ev"].append(m.event_log)
                    rec[f"{cid}_xn"].append(m.ratio_ex_news)
                    rec[f"{cid}_D"].append(m.demand_rate())
                    rec[f"{cid}_flow"].append(m.flow)
                tick += 1
            t_day = self.t0 + (day + 1) * DAY
            pm, pb, pr = (self.ex.markets[c].price for c in ("milk", "beef", "rice"))
            for b in bots:
                b.worth[day] = b.farm.net_worth(t_day, pm, pb, pr)
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
        out["price"] = {cid: price_stats([x / p.commodity(cid).base_price for x in self.rec[cid]], self.dt) for cid in self.cids}
        out["online"] = {"mean": statistics.fmean(self.rec["online"]), "max": max(self.rec["online"])}
        out["excess_mean"] = {cid: statistics.fmean(self.rec[f"{cid}_e"]) for cid in self.cids}
        out["pressure_mean"] = {cid: statistics.fmean(self.rec[f"{cid}_y"]) for cid in self.cids}
        out["strategies"] = strategy_weeks(self)
        ob = [b for b in self.bots if b.strategy != "W"]

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
        out["stud"] = stud_summary(self)
        out["shop"] = shop_summary(self)
        out["value"] = value_summary(self)
        out["beef_grades"] = {g: sum(b.ledger.qty_days("grade_" + g, 0, self.n_days) for b in ob) for g in ("A", "B", "C")}
        out["fields"] = {s: statistics.fmean([len(b.farm.fields) for b in ob if b.strategy == s] or [0]) for s in B.PLAYER_STRATEGIES}
        out["care"] = care_summary(self)
        if self.whale is not None:
            out["whale"] = whale_summary(self)
        return out


def stud_summary(w: World) -> dict:
    log = w.stud_log
    by_price: Dict[str, int] = {}
    for _t, price, owner_s, _b, _ct, _tier in log:
        key = f"{int(price)}{'_npc' if owner_s is None else ''}"
        by_price[key] = by_price.get(key, 0) + 1
    players = [b for b in w.bots if b.strategy != "W"]
    lenders = [b for b in players if b.strategy == "L"]
    lend_in = [b.ledger.amount_days("stud_in", 0, w.n_days) for b in lenders]
    lend_rev = [b.ledger.revenue_days(0, w.n_days) for b in lenders]
    all_in = sum(b.ledger.amount_days("stud_in", 0, w.n_days) for b in players)
    return {
        "trades": len(log),
        "trades_player_listing": sum(1 for x in log if x[2] is not None),
        "trades_npc_listing": sum(1 for x in log if x[2] is None),
        "by_price": by_price,
        "listings_open_end": len(w.stud.listings),
        "lender_income_mean": statistics.fmean(lend_in) if lend_in else 0.0,
        "lender_income_share": (sum(lend_in) / sum(lend_rev)) if lend_rev and sum(lend_rev) > 0 else 0.0,
        "lender_income_max": max(lend_in) if lend_in else 0.0,
        "all_player_stud_income": all_in,
        "max_trade_price": max((x[1] for x in log), default=0.0),
    }


def care_summary(w: World) -> dict:
    """v0.3 照顧，各玩法每位玩家平均（整段模擬）：病牛的時間佔牛的時間、飼料花費和多賣的錢（回報倍數）、
    小幫手／地板／治療的花費和佔收入、生病和治療的次數、稀有小牛長大時變雜種的比例。

    飼料多賣的錢 = 出貨時體重裡的飼料加成（公斤 × 評級 × 稀有度倍率）× 整段的牛肉平均價（不含滑價，估計）。"""
    end = w.t0 + w.n_days * DAY
    avg_beef = statistics.fmean(w.rec["beef"])
    out = {}
    for s in B.PLAYER_STRATEGIES:
        bs = [b for b in w.bots if b.strategy == s]
        if not bs:
            continue
        cow_s = sick_s = 0.0
        for b in bs:
            c_s, s_s = b.farm.care_stats(end)
            cow_s += c_s
            sick_s += s_s
        n = len(bs)

        def spend(k):
            return -sum(b.ledger.amount_days(k, 0, w.n_days) for b in bs) / n

        def qty(k):
            return sum(b.ledger.qty_days(k, 0, w.n_days) for b in bs) / n

        rev = sum(b.ledger.revenue_days(0, w.n_days) for b in bs) / n
        feed = spend("feed_buy")
        bonus_value = qty("bonus_kg") * avg_beef
        care = spend("helper") + spend("floor") + spend("cure")
        out[s] = {
            "n": n, "revenue": rev, "sick_share": sick_s / cow_s if cow_s else 0.0,
            "feed_spend": feed, "feed_units": qty("feed_buy"), "bonus_value": bonus_value,
            "feed_roi": bonus_value / feed if feed else None,
            "helper_spend": spend("helper"), "floor_spend": spend("floor"), "cure_spend": spend("cure"),
            "care_spend_share": care / rev if rev else None,
            "sick": qty("sick"), "cures": qty("cure"), "cleaned": qty("clean"),
            "hybrid": qty("hybrid"), "rare_grown": qty("rare_grown"),
            "hybrid_share": qty("hybrid") / qty("rare_grown") if qty("rare_grown") else None,
        }
    return out


def shop_summary(w: World) -> dict:
    out = {}
    for s in B.PLAYER_STRATEGIES:
        bs = [b for b in w.bots if b.strategy == s]
        out[s] = {g: sum(b.ledger.qty_days("shop_" + g, 0, w.n_days) for b in bs) for g in ("A", "B", "C")}
    tot = {g: sum(v[g] for v in out.values()) for g in ("A", "B", "C")}
    out["all"] = tot
    return out


def value_summary(w: World) -> dict:
    """追蹤的玩家（pid < TRACK_PLAYERS）每頭牛一生的實際價值（出貨了才算，出生在最後 8 天前）。

    價值 = 產奶瓶數 × 該稀有度倍率 × 牛奶時間平均價 + 稻米公斤 × 稻米時間平均價 + 出貨收入。
    """
    p = w.params
    fp = p.farm
    avg = {cid: statistics.fmean(w.rec[cid]) for cid in w.cids}
    cutoff = w.t0 + (w.n_days - 8) * DAY
    by_origin: Dict[str, List[float]] = {}
    by_kind: Dict[str, List[float]] = {}
    for b in w.bots:
        tr = b.farm.track
        if not tr or b.strategy == "W":
            continue
        alive = {c.cid for c in b.farm.cows}
        for cid, r in tr.items():
            milk_q, rice_q, beef_c, origin, ctype, bull, tier, born = r
            if cid in alive or born > cutoff or origin in ("start", "whale", "legacy"):
                continue
            v = milk_q * fp.tier_mult[tier] * avg["milk"] + rice_q * avg["rice"] + beef_c
            by_origin.setdefault(origin, []).append(v)
            by_kind.setdefault(f"{ctype}{'M' if bull else 'F'}{tier}", []).append(v)
    return {
        "origin": {k: {"n": len(v), "mean": statistics.fmean(v)} for k, v in by_origin.items()},
        "kind": {k: {"n": len(v), "mean": statistics.fmean(v)} for k, v in by_kind.items()},
        "avg_price": avg,
    }


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
        # 平均成交價（每單位「有效量」= 數量 × 新鮮度 × 稀有度 × 評級），與同時段市價的比
        d["avg_price"] = d["proceeds"] / d["value_units"] if d["value_units"] else None
        d["avg_market_price"] = d["price_x_value"] / d["value_units"] if d["value_units"] else None
    out["totals"] = tot
    return out
