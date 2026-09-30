"""把遊戲狀態變成 API 回應的 JSON（欄位說明在 docs/protocol.md）。只讀，不改任何狀態。

時間欄位一律是遊戲時間的 Unix 秒數（數字，可有小數）。app 照台灣時間 UTC+8 顯示。
"""

from __future__ import annotations

import math
from typing import Dict, List, Optional

from cowecon.farm import (
    Cow,
    beef_quality,
    beef_storage_factor,
    beef_weight,
    bucket_cap,
    cow_milk_rate,
    fresh_times_h,
    freshness,
    milk_frac,
    wh_cap,
)
from cowecon.params import HOUR

from .game import TYPE_WIRE, Game, Player, level_threshold, ship_value

TIER_NAMES = ("一般", "優良", "稀有", "傳說")
TYPE_NAMES = ("乳用", "兼用", "肉用")


def r6(x: float) -> float:
    return round(float(x), 6)


def r2(x: float) -> float:
    return round(float(x), 2)


def ci(x) -> Optional[int]:
    """費用、金幣一律是整數；None（已滿級）照樣是 None。"""
    return None if x is None else int(round(x))


def cow_stage(p: Player, c: Cow, now: float) -> str:
    """calf：還沒長大；adult：壯年；old：過了巔峰（母牛產奶開始下降／公牛肉質開始下降）。"""
    fp = p.farm.fp
    if now < c.adult_at:
        return "calf"
    a = c.adult_age_h(now)
    if c.bull:
        return "old" if a > fp.peak_age_h[c.ctype] + fp.beef_hold_h else "adult"
    return "old" if a > fp.milk_prime_h else "adult"


def cow_view(game: Game, p: Player, c: Cow, now: float) -> dict:
    fp = p.farm.fp
    adult = c.is_adult(now)
    return {
        "id": c.cid,
        "type": TYPE_WIRE[c.ctype],
        "type_name": TYPE_NAMES[c.ctype],
        "bull": c.bull,
        "tier": c.tier,
        "tier_name": TIER_NAMES[c.tier],
        "stage": cow_stage(p, c, now),
        "born_at": c.born_at,
        "adult_at": c.adult_at,
        "ready_at": c.ready_at,
        "breed_ready": adult and now >= c.ready_at,
        "age_h": r2((now - c.born_at) / HOUR),
        "milk_per_h": r2(cow_milk_rate(fp, c, now)),
        "milk_frac": r2(milk_frac(fp, c.adult_age_h(now))) if adult and not c.bull else 0.0,
        "weight_kg": r2(beef_weight(fp, c, now)),
        "beef_quality": r2(beef_quality(fp, c, now)) if adult else 1.0,
        "ship_value": round(ship_value(game, p, c, now)),
    }


def bucket_view(p: Player, now: float) -> dict:
    f = p.farm
    by_tier = f.bucket_preview(now)
    ob = f.p.onboarding
    boost_until = f.created_at + ob.newbie_boost_s
    return {
        "qty": r6(sum(by_tier)),
        "by_tier": [r6(x) for x in by_tier],
        "capacity": r2(f.bucket_capacity()),
        "per_hour": r6(f.milk_rate(now)),  # 已含新手期加倍
        "boost": {"mult": ob.newbie_boost_mult, "until": boost_until} if now < boost_until else None,
    }


def warehouse_view(p: Player, now: float) -> dict:
    f = p.farm
    fp = f.fp
    full_h, half_h = fresh_times_h(fp, f.fresh_level)
    zero_h = full_h + 2 * (half_h - full_h)
    milk_lots = []
    for l in f.lots:
        fr = freshness(fp, (now - l.t) / HOUR, f.fresh_level)
        milk_lots.append({
            "qty": r6(l.qty), "tier": l.tier, "collected_at": l.t, "freshness": round(fr, 4),
            "fresh_until": l.t + full_h * HOUR, "spoils_at": l.t + zero_h * HOUR,
        })
    beef_lots = []
    for l in f.beef_lots:
        beef_lots.append({
            "qty": r6(l.qty), "tier": l.tier, "cow_id": l.cow_id, "shipped_at": l.t,
            "quality": round(f.beef_lot_mult(l, now) / fp.tier_mult[l.tier], 4),
            "storage_factor": round(beef_storage_factor(fp, (now - l.t) / HOUR), 4),
        })
    return {
        "capacity": r2(f.wh_capacity()),
        "used": r6(f.wh_used()),
        "milk_total": r6(sum(l.qty for l in f.lots if freshness(fp, (now - l.t) / HOUR, f.fresh_level) > 0)),
        "beef_total": r6(f.beef_stock()),
        "milk_lots": milk_lots,
        "beef_lots": beef_lots,
    }


def _first_open_at(p: Player, now: float) -> Optional[float]:
    f = p.farm
    if f.expansions > 0:
        return None
    t = f.created_at + f.p.onboarding.first_expand_unlock_s
    return t if now < t else None


def pen_view(p: Player, now: float) -> dict:
    f = p.farm
    return {"slots": f.slots, "used": len(f.cows), "next_cost": ci(f.next_pen_cost()), "next_open_at": _first_open_at(p, now), "max_slots": f.fp.pen_max_slots}


def upgrades_view(p: Player, now: float) -> dict:
    f = p.farm
    fp = f.fp
    full_h, half_h = fresh_times_h(fp, f.fresh_level)
    nfull_h, nhalf_h = fresh_times_h(fp, f.fresh_level + 1)
    bc = f.next_bucket_cost()
    wc = f.next_wh_cost()
    fc = f.next_fresh_cost()
    return {
        "pen": {"level": f.expansions, "cost": ci(f.next_pen_cost()), "next_open_at": _first_open_at(p, now), "slots": f.slots, "next_slots": f.slots + 1 if f.next_pen_cost() is not None else None},
        "bucket": {"level": f.bucket_level, "cost": ci(bc), "capacity": r2(bucket_cap(fp, f.bucket_level)), "next_capacity": r2(bucket_cap(fp, f.bucket_level + 1)) if bc is not None else None},
        "warehouse": {"level": f.wh_level, "cost": ci(wc), "capacity": r2(wh_cap(fp, f.wh_level)), "next_capacity": r2(wh_cap(fp, f.wh_level + 1)) if wc is not None else None},
        "fresh": {"level": f.fresh_level, "cost": ci(fc), "fresh_h": full_h, "half_h": half_h,
                  "next_fresh_h": nfull_h if fc is not None else None, "next_half_h": nhalf_h if fc is not None else None},
    }


def codex_view(p: Player) -> List[dict]:
    return [{"type": TYPE_WIRE[t], "tier": tier} for t, tier in sorted(p.codex)]


def time_fields(clock, now: float) -> dict:
    import time as _time

    return {"server_time": now, "real_time": _time.time(), "time_scale": clock.scale}


def state_view(game: Game, p: Player, now: float, clock) -> dict:
    f = p.farm
    lv = p.level()
    return {
        **time_fields(clock, now),
        "player_id": p.pid,
        "ranch_name": p.name,
        "coins": int(round(f.coins)),
        "level": lv,
        "level_progress": {"earned": int(round(p.earned)), "level_at": level_threshold(lv), "next_at": level_threshold(lv + 1)},
        "cows": [cow_view(game, p, c, now) for c in f.cows],
        "bucket": bucket_view(p, now),
        "warehouse": warehouse_view(p, now),
        "pen": pen_view(p, now),
        "upgrades": upgrades_view(p, now),
        "shop": {"calf_price": {w: ci(f.fp.calf_price) for w in TYPE_WIRE}},
        "breed": {"first_free": f.p.onboarding.first_breed_free and not f.first_breed_used},
        "codex": codex_view(p),
    }


def change_24h(hist, price: float, now: float) -> Dict[str, float]:
    """hist：[(t, price)] 依時間排序。24 遊戲小時前（或最早一筆）的價格 → 漲跌（幣與比例）。"""
    target = now - 24 * HOUR
    ref = None
    for t, pr in hist:
        if t <= target:
            ref = pr
        else:
            break
    if ref is None:
        ref = hist[0][1] if hist else price
    return {"change_24h": r6(price - ref), "change_24h_pct": r6(price / ref - 1.0 if ref else 0.0)}


def quote_view(game: Game, cid: str, hist, now: float) -> dict:
    m = game.ex.markets[cid]
    return {"price": r6(m.price), **change_24h(hist, m.price, now), "ma24": r6(m.moving_average())}


def news_item(ev, now: float) -> dict:
    if len(ev.targets) == 1:
        commodity = ev.targets[0]
    else:
        commodity = None  # 兩種商品都受影響
    if now < ev.start_at:
        state = "upcoming"
    elif now < ev.end_at:
        state = "active"
    else:
        state = "ended"
    return {
        "id": ev.eid,
        "title": ev.headline,
        "commodity": commodity,
        "targets": list(ev.targets),
        "direction": "up" if ev.factor > 1.0 else "down",
        "big": bool(ev.rare),
        "time": ev.announce_at,
        "announce_at": ev.announce_at,
        "start_at": ev.start_at,
        "end_at": ev.end_at,
        "state": state,
    }


def downsample(points, step_s: float) -> List[List[float]]:
    """每 step_s 取最後一筆（收盤價）。points 依時間排序。"""
    out: List[List[float]] = []
    last_bucket = None
    for t, p in points:
        b = math.floor(t / step_s)
        if b == last_bucket:
            out[-1] = [t, r6(p)]
        else:
            out.append([t, r6(p)])
            last_bucket = b
    return out


def next_unit_price(market, imp, now: float) -> float:
    """這位玩家現在再賣「一單位」一般品質的貨，拿得到的價格（市價扣掉自己最近賣量造成的滑價）。"""
    cp = market.cp
    recent, _allow = market._refreshed_impact(imp, now, market.demand_rate())
    return market.price * (1.0 - cp.slip_kappa * min(recent / market.depth(), cp.slip_qmax))
