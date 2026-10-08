"""把遊戲狀態變成 API 回應的 JSON（欄位說明在 docs/protocol.md）。只讀，不改任何狀態。

- 時間欄位一律是遊戲時間的 Unix 秒數（數字，可有小數）；名字以 _real 結尾的是現實時間。
- 協定 v2：不送給玩家看的文字（D25）。名字、新聞都送代碼，app 用字串表依語言顯示。
"""

from __future__ import annotations

import math
import time
from typing import Dict, List, Optional, Tuple

from cowecon.farm import (
    DAIRY,
    OX,
    Cow,
    beef_grade_probs,
    beef_quality,
    beef_storage_factor,
    beef_weight,
    bucket_cap,
    cow_milk_rate,
    cow_rice_rate,
    field_cap_for,
    fresh_times_h,
    freshness,
    is_milker,
    milk_frac,
    rice_factor,
    stud_fee,
    wh_cap,
)
from cowecon.params import HEADLINES, HOUR

from . import achievements as A
from .breeds import ORDER as BREED_ORDER
from .breeds import breed_of_genes
from .game import TYPE_WIRE, Game, Player, level_threshold, ship_value, stud_fee_view
from .names import name_words, station_words

GRADE_NAMES = ("A", "B", "C")


def r6(x: float) -> float:
    return round(float(x), 6)


def r2(x: float) -> float:
    return round(float(x), 2)


def ci(x) -> Optional[int]:
    """費用、金幣一律是整數；None（已滿級）照樣是 None。"""
    return None if x is None else int(round(x))


def cow_stage(p: Player, c: Cow, now: float) -> str:
    """calf：還沒長大；adult：壯年；old：過了巔峰（母乳牛產奶、耕牛工作力開始下降；其他牛肉質開始下降）。"""
    fp = p.farm.fp
    if now < c.adult_at:
        return "calf"
    a = c.adult_age_h(now)
    if is_milker(c) or c.ctype == OX:
        return "old" if a > fp.milk_prime_h else "adult"
    return "old" if a > fp.peak_age_h[c.ctype] + fp.beef_hold_h else "adult"


def grade_dict(probs) -> dict:
    return {g: round(x, 6) for g, x in zip(GRADE_NAMES, probs)}


def cow_view(game: Game, p: Player, c: Cow, now: float) -> dict:
    fp = p.farm.fp
    adult = c.is_adult(now)
    working = c.field >= 0
    return {
        "id": c.cid,
        "type": TYPE_WIRE[c.ctype],
        "bull": c.bull,
        "tier": c.tier,
        "breed": breed_of_genes(c.g),
        "stage": cow_stage(p, c, now),
        "born_at": c.born_at,
        "adult_at": c.adult_at,
        "age_h": r2((now - c.born_at) / HOUR),
        "milk_per_h": r2(cow_milk_rate(fp, c, now)),
        "milk_frac": r2(milk_frac(fp, c.adult_age_h(now))) if adult and (is_milker(c) or c.ctype == OX) else 0.0,
        "weight_kg": r2(beef_weight(fp, c, now)),
        "beef_quality": r2(beef_quality(fp, c, now)) if adult else 1.0,
        "ship_value": round(ship_value(game, p, c, now)),
        # v0.2
        "bred": c.bred,
        "working": working,
        "field": c.field if working else None,
        "listed": c.listed,
        "can_breed": c.can_breed_now(now),
        "can_ship": adult and not c.is_busy(),
        "can_work": c.ctype == OX and adult and not c.is_busy(),
        "rice_per_h": r2(cow_rice_rate(fp, c, now)) if c.ctype == OX else 0.0,
        "grade_probs": grade_dict(beef_grade_probs(fp, c, now)) if adult else None,
        "origin": c.origin or None,
        # D26：成年、沒配過種的公牛現在的借種費（上架前就先算好給 S04-04）；其他牛 null
        "stud_fee": stud_fee_view(fp, c.tier, *stud_fee(fp, c.ctype, c.tier, c.adult_at, now))
        if c.bull and adult and not c.bred
        else None,
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
        milk_lots.append(
            {
                "qty": r6(l.qty),
                "tier": l.tier,
                "collected_at": l.t,
                "freshness": round(fr, 4),
                "fresh_until": l.t + full_h * HOUR,
                "spoils_at": l.t + zero_h * HOUR,
            }
        )
    beef_lots = []
    for l in f.beef_lots:
        beef_lots.append(
            {
                "qty": r6(l.qty),
                "tier": l.tier,
                "breed": breed_of_genes(l.genes) if l.genes is not None else None,  # 舊存檔的批次沒有基因
                "cow_id": l.cow_id,
                "shipped_at": l.t,
                "quality": round(f.beef_lot_mult(l, now) / fp.tier_mult[l.tier], 4),
                "storage_factor": round(beef_storage_factor(fp, (now - l.t) / HOUR), 4),
                "grade": GRADE_NAMES[l.grade] if 0 <= l.grade < 3 else None,
            }
        )
    rice_lots = [
        {"qty": r6(l.qty), "harvested_at": l.t, "quality": round(rice_factor(fp, (now - l.t) / HOUR), 4)}
        for l in f.rice_lots
    ]
    return {
        "capacity": r2(f.wh_capacity()),
        "used": r6(f.wh_used()),
        "milk_total": r6(sum(l.qty for l in f.lots if freshness(fp, (now - l.t) / HOUR, f.fresh_level) > 0)),
        "beef_total": r6(f.beef_stock()),
        "milk_lots": milk_lots,
        "beef_lots": beef_lots,
        "rice_total": r6(f.rice_stock()),
        "rice_lots": rice_lots,
    }


def _first_open_at(p: Player, now: float) -> Optional[float]:
    f = p.farm
    if f.expansions > 0:
        return None
    t = f.created_at + f.p.onboarding.first_expand_unlock_s
    return t if now < t else None


def pen_view(p: Player, now: float) -> dict:
    f = p.farm
    return {
        "slots": f.slots,
        "used": len(f.cows),
        "next_cost": ci(f.next_pen_cost()),
        "next_open_at": _first_open_at(p, now),
        "max_slots": f.fp.pen_max_slots,
    }


def upgrades_view(p: Player, now: float) -> dict:
    f = p.farm
    fp = f.fp
    full_h, half_h = fresh_times_h(fp, f.fresh_level)
    nfull_h, nhalf_h = fresh_times_h(fp, f.fresh_level + 1)
    bc = f.next_bucket_cost()
    wc = f.next_wh_cost()
    fc = f.next_fresh_cost()
    flc = f.next_field_cost()
    return {
        "pen": {
            "level": f.expansions,
            "cost": ci(f.next_pen_cost()),
            "next_open_at": _first_open_at(p, now),
            "slots": f.slots,
            "next_slots": f.slots + 1 if f.next_pen_cost() is not None else None,
        },
        "bucket": {
            "level": f.bucket_level,
            "max": fp.bucket_max_level,  # level 的上限（S10「第 n / max 級」）
            "cost": ci(bc),
            "capacity": r2(bucket_cap(fp, f.bucket_level)),
            "next_capacity": r2(bucket_cap(fp, f.bucket_level + 1)) if bc is not None else None,
        },
        "warehouse": {
            "level": f.wh_level,
            "max": fp.wh_max_level,
            "cost": ci(wc),
            "capacity": r2(wh_cap(fp, f.wh_level)),
            "next_capacity": r2(wh_cap(fp, f.wh_level + 1)) if wc is not None else None,
        },
        "fresh": {
            "level": f.fresh_level,
            "max": len(fp.fresh_costs),  # fresh_costs 是升到 1、2、3、4 級的費用
            "cost": ci(fc),
            "fresh_h": full_h,
            "half_h": half_h,
            "next_fresh_h": nfull_h if fc is not None else None,
            "next_half_h": nhalf_h if fc is not None else None,
        },
        "field": {
            "level": len(f.fields) - fp.field_start,
            "cost": ci(flc),
            "count": len(f.fields),
            "max": fp.field_max,
        },
    }


def fields_view(p: Player, now: float) -> List[dict]:
    f = p.farm
    fp = f.fp
    grown = f.field_preview(now)
    out = []
    for i, (fl, q) in enumerate(zip(f.fields, grown)):
        ox = f.cow_by_id(fl.ox) if fl.ox >= 0 else None
        cap = field_cap_for(fp, ox) if ox is not None else None
        out.append(
            {
                "index": i,
                "cow_id": ox.cid if ox is not None else None,
                "rice": r6(q),
                "capacity": r2(cap) if cap is not None else None,
                "per_hour": r6(cow_rice_rate(fp, ox, now)) if ox is not None else 0.0,
            }
        )
    return out


def rice_view(p: Player, now: float) -> dict:
    f = p.farm
    return {"in_fields": r6(sum(f.field_preview(now))), "stock": r6(f.rice_stock()), "per_hour": r6(f.rice_rate(now))}


def shop_view(game: Game, p: Player) -> dict:
    fp = p.farm.fp
    return {"grades": [{"grade": g, "price": ci(fp.shop_grade_price[i])} for i, g in enumerate(fp.shop_grade_names)]}


def ranch_ref(p: Player) -> dict:
    """協定 1.6 節的「牧場」：真人送自己取的名字，電腦送三組詞的編號（app 依玩家的語言組）。"""
    words = None
    if p.is_bot:  # 電腦牧場存三組詞的編號；沒存的（測試用的電腦玩家）從名字反查
        words = p.name_words if p.name_words is not None else name_words(p.name)
    return {
        "player_id": p.pid,
        "name": p.name if words is None else None,
        "name_words": words,
        "is_bot": p.is_bot,
        "level": p.level(),
        "avatar": None if p.is_bot else p.avatar,  # S21：頭像的品種代號；電腦和沒選過的是 null（app 畫荷斯坦）
    }


def station_ref(game: Game, listing_id: int) -> dict:
    """公營種牛站（電腦系統上架、沒有主人）：沒有 player_id（所以沒有 #編號）和等級。"""
    return {
        "player_id": None,
        "name": None,
        "name_words": station_words(game.seed, listing_id),
        "is_bot": True,
        "level": None,
        "avatar": None,
    }


def listing_view(game: Game, lst, me: Optional[int], now: float) -> dict:
    owner = game.players.get(lst.owner) if lst.owner is not None else None
    return {
        "id": lst.lid,
        "breed": breed_of_genes(lst.g),
        "type": TYPE_WIRE[lst.ctype],
        "tier": lst.tier,
        "owner": ranch_ref(owner) if owner is not None else station_ref(game, lst.lid),
        "is_mine": lst.owner is not None and lst.owner == me,
        "cow_id": lst.cow_id if lst.owner is not None else None,
        "listed_at": lst.listed_at,
        "fee": game.stud_fee(lst, now),  # 這一刻現算（D26）
    }


def codex_view(p: Player) -> List[dict]:
    """圖鑑：已發現的品種與第一次發現的時間，先發現的在前。"""
    rows = sorted(p.codex.items(), key=lambda x: (x[1], BREED_ORDER[x[0]]))
    return [{"breed": b, "found_at": t} for b, t in rows]


def time_fields(clock, now: float) -> dict:
    return {"server_time": now, "real_time": time.time(), "time_scale": clock.scale}


def state_view(game: Game, p: Player, now: float, clock) -> dict:
    f = p.farm
    lv = p.level()
    return {
        **time_fields(clock, now),
        "player_id": p.pid,
        "ranch_name": p.name,
        "coins": int(round(f.coins)),
        "level": lv,
        "level_progress": {
            "earned": int(round(p.earned)),
            "level_at": level_threshold(lv),
            "next_at": level_threshold(lv + 1),
        },
        "cows": [cow_view(game, p, c, now) for c in f.cows],
        "bucket": bucket_view(p, now),
        "warehouse": warehouse_view(p, now),
        "pen": pen_view(p, now),
        "upgrades": upgrades_view(p, now),
        "shop": shop_view(game, p),
        "codex": codex_view(p),
        # v0.2
        "fields": fields_view(p, now),
        "rice": rice_view(p, now),
        "stud": {
            "listings": [listing_view(game, l, p.pid, now) for l in game.stud.owner_listings(p.pid)],
            "income": int(round(p.stud_income)),
        },
        "economy": economy_view(f.fp),
        "profile": {"avatar": p.avatar, "renames": p.renames},  # S21 牧場資料（D34）
        "achievements": achievements_view(game, p, now),
    }


def achievements_view(game: Game, p: Player, now: float) -> List[dict]:
    """成就（S21；server/achievements.py）：18 個，順序跟設計稿 BADGES 一樣。時間都是遊戲時間（同 codex[].found_at）。
    一般的 {key, unlocked_at}；有計數的再加 progress、goal；分階段的 {key, progress, tiers[{goal, unlocked_at}]}。"""
    found = sorted(p.codex.values())
    progress = {
        "gradeA": p.ach_n.get("gradeA", 0.0),
        "popularBull": p.ach_n.get("popularBull", 0.0),
        "rice": r2(p.ach_n.get("rice", 0.0)),
        "codex": float(len(found)),
        "level": float(p.level()),
        "rich": float(round(game.net_worth(p, now))),
    }
    out = []
    for key, goal in A.ACHIEVEMENTS:
        if isinstance(goal, tuple):
            tiers = []
            for i, g in enumerate(goal, start=1):
                if key == "codex":  # 第 g 種牛被發現的時間
                    at = found[g - 1] if len(found) >= g else None
                else:
                    at = p.ach.get(A.tier_key(key, i))
                tiers.append({"goal": g, "unlocked_at": at})
            out.append({"key": key, "progress": progress[key], "tiers": tiers})
        elif key == "weekChamp":
            out.append({"key": key, "unlocked_at": game.week_champ_at(p.pid)})
        elif isinstance(goal, int):
            out.append({"key": key, "unlocked_at": p.ach.get(key), "progress": progress[key], "goal": goal})
        else:
            out.append({"key": key, "unlocked_at": None if key in A.NOT_YET else p.ach.get(key)})
    return out


def economy_view(fp) -> dict:
    """S05「優良牛奶 ×1.3」、S09 品種卡用的倍數（協定 2.3 節）：直接讀 params，app 不寫死經濟參數。"""
    return {
        "tier_mult": list(fp.tier_mult),  # 一般、優良、稀有、傳說：牛奶、牛肉的賣價倍率，也是耕牛的稻米產量倍率
        "beef_grade_mult": dict(zip(GRADE_NAMES, fp.beef_grade_mult)),
        "ox_rice_per_h": fp.rice_per_h[OX],  # 壯年耕牛每遊戲小時的稻米公斤數（× tier_mult × 年齡曲線）
        "dairy_milk_per_h": fp.milk_per_h[DAIRY],  # 壯年母乳牛每遊戲小時產奶瓶數（× 年齡曲線；稀有度不影響產量）
        "calf_grow_h": list(fp.tier_growth_h),  # 小牛長大要幾遊戲小時，依稀有度（params 的 tier_growth_h）
        "peak_weight_kg": {TYPE_WIRE[i]: w for i, w in enumerate(fp.peak_weight_kg)},  # 母牛的最佳體重，依用途
        "bull_weight_mult": fp.bull_weight_mult,  # 公牛的體重 = 母牛 × 這個
        "rename_price": A.RENAME_PRICE,  # S21：第二次起改名的價錢（第一次免費，看 profile.renames）
        "field_cap_h": fp.field_cap_h,  # 一塊田最多存這頭耕牛壯年幾小時的量（fields[].capacity 不乘年齡曲線）
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


def _news_codes() -> Dict[Tuple[str, str], str]:
    """(HEADLINES 的 key, 標題) → 新聞代碼 `<商品>_<up|down>.<序號>`（app 查字串表 news.<代碼>，序號從 1 開始）。"""
    out = {}
    for key, titles in HEADLINES.items():
        commodity, sign = key[:-1], key[-1]
        for i, title in enumerate(titles):
            out[(key, title)] = f"{commodity}_{'up' if sign == '+' else 'down'}.{i + 1}"
    return out


_NEWS_CODES = _news_codes()


def news_code(ev) -> Optional[str]:
    """引擎挑標題的方式（cowecon.market）：單一商品用那個商品、三種一起用 all，再看利多利空。
    用標題反查代碼，不改引擎的事件和 news 表。測試注入的事件（不在 HEADLINES）回傳 None。"""
    key = (ev.targets[0] if len(ev.targets) == 1 else "all") + ("+" if ev.factor > 1.0 else "-")
    return _NEWS_CODES.get((key, ev.headline))


def news_item(ev, now: float) -> dict:
    if len(ev.targets) == 1:
        commodity = ev.targets[0]
    else:
        commodity = None  # 不只一種商品
    if now < ev.start_at:
        state = "upcoming"
    elif now < ev.end_at:
        state = "active"
    else:
        state = "ended"
    return {
        "id": ev.eid,
        "code": news_code(ev),
        "params": {},  # 目前的標題都沒有佔位符
        "pct": round(ev.factor - 1.0, 4),  # 全幅時讓價格變多少（+0.18 = 漲 18%）
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
