"""HTTP／WebSocket 協定測試（需要 PostgreSQL），v0.2。

欄位、request_id 防重送、各種錯誤、牛肉倉庫、排行榜，以及 v0.2 的商店等級、出貨評級、配種一次、田地、借種。
時間用手動時鐘（conftest.Harness），不會真的等。

經濟代理還在調 backend/cowecon/params.py 的數值：這裡的期望值一律用引擎（cowecon）算，不寫死數字。
"""

from __future__ import annotations

import random
import time

import pytest
from starlette.websockets import WebSocketDisconnect

from conftest import T0, Harness, new_rid
from cowecon import DEFAULT
from cowecon.farm import (
    Cow,
    beef_grade_probs,
    cow_rice_rate,
    cow_type,
    draw_beef_grade,
    make_genotype,
    offspring_distribution,
    rare_mask,
    shop_draw,
    shop_grade_distribution,
    shop_grade_tier_probs,
    stud_fee,
    tier_distribution,
    tier_of,
)
from cowecon.params import HEADLINES
from server.breeds import ALL as ALL_BREEDS
from server.breeds import BREEDS, FEED_IDS, FLOOR_IDS, breed_id
from server.game import TYPE_WIRE, Game, GameError, week_id, week_start
from server.names import load_words, station_words

TIER_NAMES = {t[0] for t in DEFAULT.events.tiers}  # D33：新聞的級別 normal、big、super、crash

FP = DEFAULT.farm
OB = DEFAULT.onboarding
CP = DEFAULT.care


@pytest.fixture
def h(db_dsn):
    with Harness(db_dsn, bots=3) as hh:
        yield hh


def err(r, status, code):
    assert r.status_code == status, r.text
    body = r.json()
    assert set(body) == {"error"}, body
    assert body["error"]["code"] == code, body
    assert isinstance(body["error"]["message"], str) and body["error"]["message"]
    return body["error"]


def state(h, tok):
    return h.get("/v1/state", tok).json()


def sell_all_milk(h, tok):
    h.post("/v1/collect", tok, {"request_id": new_rid()})
    q = state(h, tok)["warehouse"]["milk_total"]
    if q > 0:
        r = h.post("/v1/sell", tok, {"commodity": "milk", "qty": q, "request_id": new_rid()})
        assert r.status_code == 200, r.text


def give(h, tok, coins=None, slots=None):
    """測試用：直接改記憶體裡的牧場（下一個動作會一起存檔）。"""
    p = h.server.game.players[state(h, tok)["player_id"]]
    if coins is not None:
        p.farm.coins = float(coins)
    if slots is not None:
        p.farm.slots = slots
    return p


def check_offspring_distribution(pv):
    """配種、借種預覽的 distribution（協定 3.7、4.3；S08-06、S18-06 一列一個品種）：p 加總是 1；
    依 tier、type、bull 加總後跟 tier_probs、type_probs、bull_prob 一樣；形狀跟商店（3.5）一樣。"""
    rows = pv["distribution"]
    assert rows and sum(r["p"] for r in rows) == pytest.approx(1.0, abs=1e-12)
    tiers, types, bull = [0.0] * 4, {t: 0.0 for t in TYPE_WIRE}, 0.0
    for r in rows:
        assert set(r) == {"type", "bull", "traits", "tier", "breed", "p"} and r["p"] > 0
        assert r["tier"] == bin(r["traits"]).count("1") and r["breed"] == breed_id(
            TYPE_WIRE.index(r["type"]), r["traits"]
        )
        tiers[r["tier"]] += r["p"]
        types[r["type"]] += r["p"]
        bull += r["p"] if r["bull"] else 0.0
    assert tiers == pytest.approx(pv["tier_probs"], abs=1e-12)
    assert types == pytest.approx(pv["type_probs"], abs=1e-12) and bull == pytest.approx(pv["bull_prob"], abs=1e-12)


def expected_fee(h, pid, cow_id):
    """借種費的期望值（協定 1.6 節）：用引擎的公式算（D26），不寫死數字。"""
    c = h.server.game.players[pid].farm.cow_by_id(cow_id)
    price, kg, at_max = stud_fee(FP, c.ctype, c.tier, c.adult_at, h.clock.now())
    return {"price": int(price), "per_kg": FP.stud_fee_per_kg[c.tier], "kg": round(kg, 2), "at_max": at_max}


def next_rng(h, pid):
    """服務層下一次會用的亂數（白箱：由伺服器種子、玩家、計數導出）。"""
    p = h.server.game.players[pid]
    return random.Random(f"{h.server.game.seed}:rng:{pid}:{p.rng_n + 1}")


# ---------------------------------------------------------------------------
# 帳號、狀態、錯誤格式
# ---------------------------------------------------------------------------
def test_session_and_state_fields(h):
    s = h.session()
    assert s["created"] is True and s["token"] and isinstance(s["player_id"], int)
    assert (
        s["ranch_name"] == "小花的快樂牧場" and s["state"]["player_id"] == s["player_id"]
    )  # 回應附完整的 state（S02-02）
    st = state(h, s["token"])
    for k in (
        "server_time",
        "real_time",
        "time_scale",
        "coins",
        "level",
        "cows",
        "bucket",
        "warehouse",
        "pen",
        "upgrades",
        "shop",
        "codex",
        "fields",
        "rice",
        "stud",
        "feeds",
        "poop",
        "floor",
        "helper",
        "feed_quotes",
        "robot",
    ):
        assert k in st, k
    assert st["coins"] == OB.start_coins and isinstance(st["coins"], int)
    assert "breed" not in st and set(st["shop"]) == {"grades"}  # 協定 v2 拿掉 v0.1 的相容欄位
    assert st["shop"]["grades"] == [
        {"grade": g, "price": int(FP.shop_grade_price[i])} for i, g in enumerate(FP.shop_grade_names)
    ]
    assert st["bucket"]["per_hour"] == pytest.approx(FP.milk_per_h[0] * OB.newbie_boost_mult)  # 乳牛 × 新手期加倍
    assert st["pen"]["next_open_at"] == st["server_time"] + OB.first_expand_unlock_s
    assert len(st["fields"]) == FP.field_start and st["fields"][0]["cow_id"] is None
    assert st["upgrades"]["field"]["cost"] == int(round(h.server.game.players[s["player_id"]].farm.next_field_cost()))
    assert st["rice"] == {"in_fields": 0.0, "stock": 0.0, "per_hour": 0.0}
    assert set(st["stud"]) == {"listings", "income"} and st["stud"]["listings"] == []  # D26：不再選價位
    economy = {  # S05、S09 的倍數：直接讀 params，app 不寫死
        "tier_mult": list(FP.tier_mult)[:4],  # 一般～傳說；引擎的第 5 格是雜種牛（hybrid_mult）
        "hybrid_mult": FP.tier_mult[4],
        "beef_grade_mult": dict(zip("ABC", FP.beef_grade_mult)),
        "ox_rice_per_h": FP.rice_per_h[1],
        "dairy_milk_per_h": FP.milk_per_h[0],
        "calf_grow_h": list(FP.tier_growth_h),
        "peak_weight_kg": dict(zip(TYPE_WIRE, FP.peak_weight_kg)),
        "bull_weight_mult": FP.bull_weight_mult,
        "field_cap_h": FP.field_cap_h,
        "rename_price": 1000,  # S21：第二次起改名的價錢
        # v0.3 C1 照顧
        "feeds": [{"id": k, "kg": CP.feed_kg[i], "price": int(CP.feed_price[i])} for i, k in enumerate(FEED_IDS)],
        "feed_cap": CP.feed_cap,
        "feed_cooldown_h": 4.0,
        "calf_feed_cooldown_h": 0.75,
        "feed_bonus_max_kg": CP.bonus_max_kg,
        "floors": [
            {"id": "dirt", "speed": 1.0, "late_speed": 1.0, "sick_mult": 1.0, "price": None, "rent_per_day": None},
            {"id": "hay_bed", "speed": 1.25, "late_speed": 1.0, "sick_mult": 1.0, "price": None, "rent_per_day": 8000},
            {"id": "meadow", "speed": 1.5, "late_speed": 1.0, "sick_mult": 1.0, "price": None, "rent_per_day": 20000},
            {"id": "cushion", "speed": 1.0, "late_speed": 0.75, "sick_mult": 0.5, "price": 3000, "rent_per_day": None},
        ],
        "floor_rent_max_days": CP.floor_rent_max_days,
        "helper_per_day": int(CP.helper_price_per_day),
        "helper_max_days": CP.helper_max_days,
        "robots": [
            {"id": "basic", "price": 3000, "repair": 750, "mtbf_days": 1.0},
            {"id": "sturdy", "price": 12000, "repair": 3000, "mtbf_days": 3.0},
        ],
        "robot_clean_min": 60.0,
        "helper_clean_min": 30.0,
        "cure_price": int(CP.cure_price),
        "sick_beef_mult": CP.sick_beef_mult,
        "poop_every_h": 3.0,
        "poop_max_per_cow": CP.poop_max_per_cow,
        "sick_rate_per_h": CP.sick_rate_per_h,
        "sick_dirt_free": CP.sick_dirt_free,
    }
    assert st["economy"] == economy
    assert [f["id"] for f in economy["floors"]] == list(FLOOR_IDS) == list(CP.floor_ids)
    assert st["feeds"] == {k: 0 for k in FEED_IDS}
    assert st["poop"] == {"total": 0, "dirt": 0.0, "safe_until": st["server_time"] + CP.newbie_safe_s}
    assert st["floor"] == {"current": "dirt", "owned": ["dirt"], "rented": None, "rent_until": None}
    assert st["helper"] == {"until": None}
    assert st["robot"] == {"model": None, "working": False, "since": None, "broken_at": None}
    cows = {c["id"]: c for c in st["cows"]}
    assert len(cows) == 2
    for c in cows.values():
        for k in (
            "id",
            "type",
            "bull",
            "tier",
            "breed",
            "stage",
            "adult_at",
            "milk_per_h",
            "weight_kg",
            "ship_value",
            "bred",
            "working",
            "field",
            "listed",
            "can_breed",
            "can_ship",
            "grade_probs",
            "hybrid",
            "need",
            "ate",
            "missed",
            "feed_bonus_kg",
            "fed_until",
            "feed_block",
            "poop",
            "sick",
            "sick_since",
        ):
            assert k in c, k
        for k in ("type_name", "tier_name", "ready_at", "breed_ready"):  # 協定 v2：不送中文、拿掉 v0.1 欄位
            assert k not in c, k
        assert c["bred"] is False and c["working"] is False and c["listed"] is None
        assert c["hybrid"] is False and c["missed"] == [] and c["sick"] is False and c["poop"] == 0
    calf = next(c for c in cows.values() if c["bull"])
    assert calf["stage"] == "calf" and calf["type"] == TYPE_WIRE[OB.starter_calf_type]
    assert calf["adult_at"] == st["server_time"] + OB.starter_calf_remaining_s and calf["grade_probs"] is None
    assert calf["breed"] is None and calf["tier"] is None  # v0.3：小牛長大才揭曉品種
    cow = next(c for c in cows.values() if not c["bull"])
    # 圖鑑：長大那一刻才算發現（v0.3）。開局的成牛一建立牧場就算，小公牛長大時再算
    p = h.server.game.players[st["player_id"]]
    g = p.farm.cow_by_id(cow["id"]).g
    assert cow["breed"] == BREEDS[cow_type(g)][rare_mask(g)] and cow["type"] == TYPE_WIRE[cow_type(g)]
    assert st["codex"] == [{"breed": cow["breed"], "found_at": p.created_at}] and cow["breed"] in BREEDS[0]
    h.advance(OB.starter_calf_remaining_s, tick=False)
    st = state(h, s["token"])  # GET 不存檔，但長大揭曉照樣算進去（found_at = 長大的時間）
    g = p.farm.cow_by_id(calf["id"]).g
    calf = next(c for c in st["cows"] if c["id"] == calf["id"])
    assert calf["breed"] == BREEDS[cow_type(g)][rare_mask(g)] and calf["tier"] == tier_of(g)
    assert {e["breed"]: e["found_at"] for e in st["codex"]} == {
        cow["breed"]: p.created_at,
        calf["breed"]: calf["adult_at"],
    } or calf["breed"] == cow["breed"]


def test_session_name_rules(h):
    """建立牧場：名字照協定 2.2 節檢查；不能用的名字回 400 invalid_name，什麼都不建立。"""
    n0 = len(h.server.game.players)
    for name, reason, width, char in (
        ("A", "too_short", 1, None),
        ("   ", "too_short", 0, None),
        ("晨光河畔牧場小屋X", "too_long", 17, None),
        ("小花牧場🐮", "emoji", 10, "U+1F42E"),
        ("牧\u202e場", "bad_char", 4, "U+202E"),
    ):
        e = err(h.client.post("/v1/session", json={"ranch_name": name}), 400, "invalid_name")
        assert e["detail"] == {"reason": reason, "width": width, **({"char": char} if char else {})}, name
    err(h.client.post("/v1/session"), 400, "bad_request")  # v1 的寫法（沒有本文）
    e = err(h.client.post("/v1/session", json={}), 400, "bad_request")
    assert e["detail"]["fields"] == ["ranch_name"]
    err(h.client.post("/v1/session", json={"ranch_name": 12}), 400, "bad_request")
    err(h.client.post("/v1/session", json={"ranch_name": "牛", "request_id": "abc"}), 400, "bad_request")
    assert len(h.server.game.players) == n0
    s = h.session("\u3000 ฟาร์มสุขใจ \u3000")  # 前後空白去掉；泰文的上下標記號算 0
    assert s["ranch_name"] == "ฟาร์มสุขใจ" and state(h, s["token"])["ranch_name"] == "ฟาร์มสุขใจ"
    assert h.session("小花的快樂牧場")["player_id"] != h.session("小花的快樂牧場")["player_id"]  # 名字不必唯一


def test_session_request_id_replay(h):
    """建立牧場帶 request_id：10 分鐘內重送回同一個牧場、發新 token（前一次的作廢），不會多建一個。"""
    rid = new_rid()
    a = h.session("小花的快樂牧場", request_id=rid)
    b = h.session("別的名字", request_id=rid)
    assert a["created"] is True and b["created"] is False
    assert b["player_id"] == a["player_id"] and b["ranch_name"] == "小花的快樂牧場"  # 名字以第一次為準
    assert b["token"] != a["token"]
    err(h.get("/v1/state", a["token"]), 401, "unauthorized")
    assert state(h, b["token"])["player_id"] == a["player_id"]
    n = h.client.portal.call(_count, h, "SELECT count(*) FROM players WHERE NOT is_bot")
    assert n == 1
    # 超過 10 分鐘（現實時間）的 request_id 當成新的
    h.client.portal.call(_count, h, "UPDATE session_requests SET created_at = now() - interval '11 minutes'")
    c = h.session("小花的快樂牧場", request_id=rid)
    assert c["created"] is True and c["player_id"] != a["player_id"]


def test_unauthorized_and_validation_errors(h):
    err(h.client.get("/v1/state"), 401, "unauthorized")
    err(h.get("/v1/state", "not-a-token"), 401, "unauthorized")
    tok = h.session()["token"]
    e = err(h.post("/v1/shop/buy", tok, {"grade": "S", "request_id": new_rid()}), 400, "bad_request")
    assert e["detail"]["fields"] == ["grade"]
    err(h.post("/v1/collect", tok, {}), 400, "bad_request")  # 缺 request_id
    err(h.post("/v1/collect", tok, {"request_id": "abc"}), 400, "bad_request")
    err(h.post("/v1/sell", tok, {"commodity": "milk", "qty": "5", "request_id": new_rid()}), 400, "bad_request")
    err(h.post("/v1/sell", tok, {"commodity": "milk", "qty": True, "request_id": new_rid()}), 400, "bad_request")
    err(h.post("/v1/sell", tok, {"commodity": "milk", "qty": -1, "request_id": new_rid()}), 400, "bad_request")
    err(h.post("/v1/sell", tok, {"commodity": "gold", "qty": 1, "request_id": new_rid()}), 400, "bad_request")
    err(h.post("/v1/ship", tok, {"cow_id": "1", "request_id": new_rid()}), 400, "bad_request")
    e = err(h.post("/v1/stud/borrow", tok, {"listing_id": 1, "dam": 1, "request_id": new_rid()}), 400, "bad_request")
    assert e["detail"]["fields"] == ["price"]  # 借種要帶預覽看到的借種費（D26）
    e = err(
        h.post("/v1/stud/borrow", tok, {"listing_id": 1, "dam": 1, "price": None, "request_id": new_rid()}),
        400,
        "bad_request",
    )
    assert e["detail"]["fields"] == ["price"]
    err(h.client.get("/v1/nope"), 404, "not_found")


def test_buy_calf_removed(h):
    """協定 v2 拿掉 v1 的 /v1/buy_calf（v1 回 410 gone）：現在跟不存在的網址一樣。"""
    tok = h.session()["token"]
    err(h.post("/v1/buy_calf", tok, {"type": "dairy", "bull": False, "request_id": new_rid()}), 404, "not_found")


# ---------------------------------------------------------------------------
# 賣出（三種商品）與 request_id
# ---------------------------------------------------------------------------
def test_collect_quote_sell(h):
    tok = h.session()["token"]
    body = h.post("/v1/collect", tok, {"request_id": new_rid()}).json()
    assert body["collected"] == pytest.approx(OB.start_bucket) and body["warehouse"]["milk_total"] == pytest.approx(
        OB.start_bucket
    )
    assert body["bucket"]["qty"] == 0 and body["state"]["coins"] == OB.start_coins
    q = h.post("/v1/sell/quote", tok, {"commodity": "milk", "qty": OB.start_bucket}).json()
    assert q["qty"] == OB.start_bucket and q["total"] > 0 and q["avg_price"] < q["market_price"]
    assert state(h, tok)["warehouse"]["milk_total"] == pytest.approx(OB.start_bucket)  # 試算不改狀態
    s = h.post("/v1/sell", tok, {"commodity": "milk", "qty": OB.start_bucket, "request_id": new_rid()}).json()
    assert s["total"] == q["total"] and s["coins"] == OB.start_coins + s["total"]
    assert s["price_after"] == s["market_price"] and s["next_unit_price"] < s["market_price"]
    err(h.post("/v1/sell", tok, {"commodity": "milk", "qty": 1, "request_id": new_rid()}), 409, "not_enough_stock")
    err(h.post("/v1/sell/quote", tok, {"commodity": "beef", "qty": 1}), 409, "not_enough_stock")
    err(h.post("/v1/sell/quote", tok, {"commodity": "rice", "qty": 1}), 409, "not_enough_stock")


def test_partial_sell_leaves_rest(h):
    tok = h.session()["token"]
    h.post("/v1/collect", tok, {"request_id": new_rid()})
    h.post("/v1/sell", tok, {"commodity": "milk", "qty": 7.5, "request_id": new_rid()})
    assert state(h, tok)["warehouse"]["milk_total"] == pytest.approx(OB.start_bucket - 7.5)
    e = err(
        h.post("/v1/sell", tok, {"commodity": "milk", "qty": OB.start_bucket, "request_id": new_rid()}),
        409,
        "not_enough_stock",
    )
    assert e["detail"]["have"] == pytest.approx(OB.start_bucket - 7.5)


async def _count(h, sql, *args):
    async with h.server.store.pool.acquire() as conn:
        return await conn.fetchval(sql, *args)


def test_request_id_replay(h):
    tok = h.session()["token"]
    h.post("/v1/collect", tok, {"request_id": new_rid()})
    rid = new_rid()
    a = h.post("/v1/sell", tok, {"commodity": "milk", "qty": 10, "request_id": rid})
    h.advance(120)  # 時間過了、價格變了，重送還是拿到第一次的結果
    b = h.post("/v1/sell", tok, {"commodity": "milk", "qty": 10, "request_id": rid})
    assert a.status_code == b.status_code == 200 and a.json() == b.json()
    st = state(h, tok)
    assert st["coins"] == a.json()["coins"]  # 只成交一次
    assert h.client.portal.call(_count, h, "SELECT count(*) FROM trades WHERE player_id=$1", st["player_id"]) == 1
    err(h.post("/v1/collect", tok, {"request_id": rid}), 409, "request_id_reused")
    # 失敗的請求不會被記住：同一個 request_id 之後條件滿足了會成功
    rid2 = new_rid()
    err(h.post("/v1/upgrade", tok, {"kind": "pen", "request_id": rid2}), 409, "not_yet_available")
    h.advance(OB.first_expand_unlock_s)
    give(h, tok, coins=10_000)
    assert h.post("/v1/upgrade", tok, {"kind": "pen", "request_id": rid2}).status_code == 200
    # request_id 以玩家為範圍：別人用同一個 UUID 不受影響
    tok2 = h.session()["token"]
    assert h.post("/v1/collect", tok2, {"request_id": rid}).status_code == 200


def test_request_id_replay_shop_and_ship(h):
    tok = h.session()["token"]
    give(h, tok, coins=100_000, slots=10)
    rid = new_rid()
    a = h.post("/v1/shop/buy", tok, {"grade": "B", "request_id": rid}).json()
    b = h.post("/v1/shop/buy", tok, {"grade": "B", "request_id": rid}).json()
    assert a == b and len(state(h, tok)["cows"]) == 3  # 只抽了一頭、只扣一次錢
    assert state(h, tok)["coins"] == 100_000 - int(FP.shop_grade_price[1])
    cow = next(c for c in state(h, tok)["cows"] if not c["bull"] and c["stage"] != "calf")
    rid = new_rid()
    s1 = h.post("/v1/ship", tok, {"cow_id": cow["id"], "request_id": rid}).json()
    s2 = h.post("/v1/ship", tok, {"cow_id": cow["id"], "request_id": rid}).json()
    assert s1 == s2 and len(state(h, tok)["warehouse"]["beef_lots"]) == 1


# ---------------------------------------------------------------------------
# 錯誤：錢不夠、牛不存在、牛舍滿、還沒長大
# ---------------------------------------------------------------------------
def test_upgrade_max_level(h):
    """S10「第 n / max 級」：max 直接讀 params；升到最高級以後 cost 是 null，再升回 409 max_level。"""
    tok = h.session()["token"]
    up = state(h, tok)["upgrades"]
    assert (up["bucket"]["max"], up["warehouse"]["max"], up["fresh"]["max"]) == (
        FP.bucket_max_level,
        FP.wh_max_level,
        len(FP.fresh_costs),
    )
    give(h, tok, coins=sum(FP.fresh_costs))
    for _ in FP.fresh_costs:
        assert h.post("/v1/upgrade", tok, {"kind": "fresh", "request_id": new_rid()}).status_code == 200
    fresh = state(h, tok)["upgrades"]["fresh"]
    assert fresh["level"] == fresh["max"] and fresh["cost"] is None and fresh["next_fresh_h"] is None
    err(h.post("/v1/upgrade", tok, {"kind": "fresh", "request_id": new_rid()}), 409, "max_level")


def test_not_enough_coins(h):
    tok = h.session()["token"]
    e = err(h.post("/v1/upgrade", tok, {"kind": "fresh", "request_id": new_rid()}), 409, "not_enough_coins")
    assert e["detail"] == {"need": int(FP.fresh_costs[0]), "have": int(OB.start_coins)}
    err(h.post("/v1/field/expand", tok, {"request_id": new_rid()}), 409, "not_enough_coins")
    give(h, tok, slots=5)  # 有空格，但錢不夠任何等級
    for g in FP.shop_grade_names:
        err(h.post("/v1/shop/buy", tok, {"grade": g, "request_id": new_rid()}), 409, "not_enough_coins")
    assert state(h, tok)["coins"] == OB.start_coins


def test_pen_full_and_first_expand(h):
    tok = h.session()["token"]
    give(h, tok, coins=100_000)
    err(h.post("/v1/shop/buy", tok, {"grade": "C", "request_id": new_rid()}), 409, "pen_full")
    e = err(h.post("/v1/upgrade", tok, {"kind": "pen", "request_id": new_rid()}), 409, "not_yet_available")
    assert e["detail"]["open_at"] == state(h, tok)["pen"]["next_open_at"]


def test_cow_not_found(h):
    tok = h.session()["token"]
    err(h.post("/v1/ship", tok, {"cow_id": 999, "request_id": new_rid()}), 404, "cow_not_found")
    err(h.post("/v1/breed", tok, {"sire": 999, "dam": 1, "request_id": new_rid()}), 404, "cow_not_found")
    err(h.get("/v1/breed/preview", tok, sire=2, dam=999), 404, "cow_not_found")
    err(h.get("/v1/ship/preview", tok, cow_id=999), 404, "cow_not_found")
    err(h.post("/v1/field/assign", tok, {"cow_id": 999, "request_id": new_rid()}), 404, "cow_not_found")
    err(
        h.post("/v1/stud/list", tok, {"cow_id": 999, "request_id": new_rid()}),
        404,
        "cow_not_found",
    )


# ---------------------------------------------------------------------------
# 商店：機率和引擎一致、抽牛用引擎的抽法
# ---------------------------------------------------------------------------
def test_shop_probabilities_match_engine(h):
    tok = h.session()["token"]
    shop = h.get("/v1/shop", tok).json()
    assert [g["grade"] for g in shop["grades"]] == list(FP.shop_grade_names)
    for gi, g in enumerate(shop["grades"]):
        assert g["price"] == int(FP.shop_grade_price[gi])
        assert g["tier_probs"] == pytest.approx(shop_grade_tier_probs(FP, gi), abs=1e-15)
        dist = shop_grade_distribution(FP, gi)
        assert {
            (TYPE_WIRE.index(r["type"]), r["bull"], r["traits"]): r["p"] for r in g["distribution"]
        } == pytest.approx(dist, abs=1e-15)
        assert sum(r["p"] for r in g["distribution"]) == pytest.approx(1.0)
        assert all(r["breed"] == BREEDS[TYPE_WIRE.index(r["type"])][r["traits"]] for r in g["distribution"])
        assert g["type_probs"] == pytest.approx({TYPE_WIRE[t]: p for t, p in enumerate(FP.shop_type_probs)})
        assert g["bull_prob"] == pytest.approx(FP.shop_bull_prob)


def test_shop_buy_uses_engine_draw(h):
    """白箱：抽到的牛 = 引擎 shop_draw 用伺服器這一次的亂數抽出來的那頭。"""
    tok = h.session()["token"]
    p = give(h, tok, coins=1_000_000, slots=20)
    for grade in ("A", "B", "C", "A", "C"):
        g, bull = shop_draw(FP, grade, next_rng(h, p.pid))
        r = h.post("/v1/shop/buy", tok, {"grade": grade, "request_id": new_rid()}).json()
        assert r["cow"]["type"] == TYPE_WIRE[cow_type(g)] and r["cow"]["bull"] == bull
        assert r["cost"] == int(FP.shop_grade_price[FP.shop_grade_names.index(grade)]) and r["cow"]["origin"] == grade
        assert r["cow"]["stage"] == "calf" and r["cow"]["breed"] is None and r["cow"]["tier"] is None  # 長大才揭曉
        assert p.farm.cow_by_id(r["cow"]["id"]).g == g


def test_codex_records_first_found_time(h):
    """圖鑑記品種和第一次發現的時間（v0.3：長大揭曉那一刻）：抽到的小牛長大才加一格，同品種再長大不改時間；
    沒吃指定飼料的稀有小牛長成雜種牛，圖鑑多一格 "hybrid"（不算 24 種）；收藏榜 = 24 種裡發現幾種。"""
    tok = h.session()["token"]
    p = give(h, tok, coins=10_000_000, slots=40)
    h.advance(OB.starter_calf_remaining_s, tick=False)
    before = {e["breed"]: e["found_at"] for e in state(h, tok)["codex"]}
    for _ in range(12):
        h.advance(60, tick=False)
        r = h.post("/v1/shop/buy", tok, {"grade": "A", "request_id": new_rid()}).json()
        assert r["cow"]["breed"] is None
    assert {e["breed"]: e["found_at"] for e in state(h, tok)["codex"]} == before  # 小牛還沒長大
    h.advance(FP.tier_growth_h[0] * 3600, tick=False)
    seen = dict(before)
    for c in sorted(p.farm.cows, key=lambda c: c.adult_at):  # 長大的時間；雜種牛（沒吃指定飼料）是 "hybrid"
        b = "hybrid" if p.farm._reveal_vt(c) == 4 else BREEDS[cow_type(c.g)][rare_mask(c.g)]
        seen.setdefault(b, c.adult_at)
    codex = state(h, tok)["codex"]
    assert {e["breed"]: e["found_at"] for e in codex} == seen  # 第一次的時間不會被後來的同品種蓋掉
    assert [e["found_at"] for e in codex] == sorted(e["found_at"] for e in codex)  # 先發現的在前
    assert all(e["breed"] in ALL_BREEDS or e["breed"] == "hybrid" for e in codex) and len(seen) > len(before)
    h.post("/v1/collect", tok, {"request_id": new_rid()})  # 動作才存檔；收藏榜看存下來的
    assert {b: t for b, t in p.codex.items()} == seen
    lb = h.get("/v1/leaderboard", tok, kind="collection").json()
    assert lb["me"]["score"] == len([b for b in seen if b != "hybrid"]) == p.codex_count()


def test_shop_sampling_matches_probabilities():
    """服務層抽很多次（不經過資料庫）：各稀有度、用途、公母的比例在精確機率的 4.5 個標準差內。"""
    game = Game(DEFAULT, "shop-sample", T0)
    p = game.create_player(T0, "x")
    p.farm.coins = 1e12
    p.farm.slots = 10**6
    n = 4000
    for grade in FP.shop_grade_names:
        tiers, types, bulls = [0] * 4, [0] * 3, 0
        for _ in range(n):
            c = game.shop_buy(p.pid, grade, T0)
            tiers[c.tier] += 1
            types[c.ctype] += 1
            bulls += c.bull
        for obs, prob in (
            list(zip(tiers, shop_grade_tier_probs(FP, grade)))
            + list(zip(types, FP.shop_type_probs))
            + [(bulls, FP.shop_bull_prob)]
        ):
            sd = (n * prob * (1 - prob)) ** 0.5
            assert abs(obs - n * prob) <= 4.5 * sd + 1, (grade, obs, n * prob)


# ---------------------------------------------------------------------------
# 出貨評級
# ---------------------------------------------------------------------------
def test_ship_grade_probs_and_draw_match_engine(h):
    tok = h.session()["token"]
    h.advance(3 * 3600)
    st = state(h, tok)
    cow = next(c for c in st["cows"] if not c["bull"])
    p = h.server.game.players[st["player_id"]]
    engine_cow = p.farm.cow_by_id(cow["id"])
    now = h.clock.now()
    probs = beef_grade_probs(FP, engine_cow, now)
    assert [cow["grade_probs"][g] for g in "ABC"] == pytest.approx(probs, abs=1e-6)
    pv = h.get("/v1/ship/preview", tok, cow_id=cow["id"]).json()
    assert [pv["grade_probs"][g] for g in "ABC"] == pytest.approx(probs, abs=1e-6)
    assert pv["can_ship"] and pv["grade_mult"] == dict(zip("ABC", FP.beef_grade_mult))
    assert pv["value_by_grade"]["A"] > pv["value_by_grade"]["B"] > pv["value_by_grade"]["C"]
    expected = "ABC"[draw_beef_grade(FP, engine_cow, now, next_rng(h, p.pid))]
    r = h.post("/v1/ship", tok, {"cow_id": cow["id"], "request_id": new_rid()}).json()
    assert r["grade"] == expected and r["beef"]["grade"] == expected
    assert r["beef"]["grade_mult"] == FP.beef_grade_mult["ABC".index(expected)]
    assert [r["grade_probs"][g] for g in "ABC"] == pytest.approx(probs, abs=1e-6)
    lot = r["state"]["warehouse"]["beef_lots"][0]
    assert lot["grade"] == expected
    assert lot["breed"] == cow["breed"] and lot["cow_id"] == cow["id"]  # S05-02「荷斯坦 #4 出貨」
    s = h.post("/v1/sell", tok, {"commodity": "beef", "qty": lot["qty"], "request_id": new_rid()}).json()
    assert s["total"] == pytest.approx(r["beef"]["value_estimate"], abs=1)


def test_ship_grade_sampling():
    """服務層出貨很多頭：評級比例在 beef_grade_probs 的 4.5 個標準差內。"""
    game = Game(DEFAULT, "grade-sample", T0)
    p = game.create_player(T0, "x")
    fp = FP
    now = T0 + 200 * 3600
    template = Cow(999, 2, False, T0, fp, adult_at=now - fp.peak_age_h[2] * 3600)  # 剛到最佳體重的一般肉牛
    probs = beef_grade_probs(fp, template, now)
    n = 3000
    counts = [0, 0, 0]
    for i in range(n):
        c = Cow(1000 + i, 2, False, T0, fp, adult_at=template.adult_at)
        p.farm.cows.append(c)
        lot = game.ship(p.pid, c.cid, now)["lot"]
        counts[lot.grade] += 1
    for obs, prob in zip(counts, probs):
        sd = (n * prob * (1 - prob)) ** 0.5
        assert abs(obs - n * prob) <= 4.5 * sd + 1, (counts, probs)


def test_beef_storage_decay(h):
    tok = h.session()["token"]
    st = state(h, tok)
    cow = next(c for c in st["cows"] if not c["bull"])
    r = h.post("/v1/ship", tok, {"cow_id": cow["id"], "request_id": new_rid()}).json()
    assert r["state"]["warehouse"]["used"] == 0  # 牛肉不佔牛奶倉庫
    h.advance(FP.beef_hold_h * 3600, tick=False)
    assert state(h, tok)["warehouse"]["beef_lots"][0]["storage_factor"] == pytest.approx(1.0)
    h.advance((FP.beef_decline_h + 1) * 3600, tick=False)
    assert state(h, tok)["warehouse"]["beef_lots"][0]["storage_factor"] == pytest.approx(FP.beef_quality_min)


# ---------------------------------------------------------------------------
# 配種：自己配免費、一輩子一次
# ---------------------------------------------------------------------------
def test_breed_once_and_free(h):
    tok = h.session()["token"]
    st = state(h, tok)
    bull = next(c for c in st["cows"] if c["bull"])
    cow = next(c for c in st["cows"] if not c["bull"])
    err(h.post("/v1/breed", tok, {"sire": cow["id"], "dam": bull["id"], "request_id": new_rid()}), 400, "invalid_pair")
    e = err(
        h.post("/v1/breed", tok, {"sire": bull["id"], "dam": cow["id"], "request_id": new_rid()}), 409, "cow_not_adult"
    )
    assert e["detail"]["until"] == bull["adult_at"]
    h.advance(OB.starter_calf_remaining_s)
    give(h, tok, coins=10_000)
    assert h.post("/v1/upgrade", tok, {"kind": "pen", "request_id": new_rid()}).status_code == 200
    pv = h.get("/v1/breed/preview", tok, sire=bull["id"], dam=cow["id"]).json()
    p = h.server.game.players[st["player_id"]]
    sire_g, dam_g = p.farm.cow_by_id(bull["id"]).g, p.farm.cow_by_id(cow["id"]).g
    assert pv["can_breed"] and not {"fee", "normal_fee", "first_free"} & set(pv)  # 自己配免費，v2 拿掉費用欄位
    assert pv["tier_probs"] == pytest.approx(tier_distribution(sire_g, dam_g))
    types = [0.0, 0.0, 0.0]
    for (t, _m), pr in offspring_distribution(sire_g, dam_g).items():
        types[t] += pr
    assert pv["type_probs"] == pytest.approx({TYPE_WIRE[i]: types[i] for i in range(3)})
    check_offspring_distribution(pv)
    coins0 = state(h, tok)["coins"]
    r = h.post("/v1/breed", tok, {"sire": bull["id"], "dam": cow["id"], "request_id": new_rid()})
    assert r.status_code == 200, r.text
    b = r.json()
    assert "fee" not in b and b["coins"] == coins0  # 自己配免費
    assert b["calf"]["stage"] == "calf" and b["calf"]["adult_at"] > b["server_time"] and b["calf"]["origin"] == "breed"
    assert b["sire"]["bred"] and b["dam"]["bred"]
    assert set(b["sire"]) == set(b["dam"]) == {"id", "bred"}  # v0.2 沒有冷卻，v2 拿掉 ready_at
    # 一輩子一次：公母都不能再配、公牛也不能上架
    e = err(
        h.post("/v1/breed", tok, {"sire": bull["id"], "dam": cow["id"], "request_id": new_rid()}), 409, "already_bred"
    )
    assert e["detail"]["cow_id"] in (bull["id"], cow["id"])
    err(
        h.post("/v1/stud/list", tok, {"cow_id": bull["id"], "request_id": new_rid()}),
        409,
        "already_bred",
    )
    pv2 = h.get("/v1/breed/preview", tok, sire=bull["id"], dam=cow["id"]).json()
    assert not pv2["can_breed"] and "already_bred" in {x["code"] for x in pv2["blockers"]}
    cows = {c["id"]: c for c in state(h, tok)["cows"]}
    assert cows[bull["id"]]["bred"] and not cows[bull["id"]]["can_breed"]


# ---------------------------------------------------------------------------
# 田地
# ---------------------------------------------------------------------------
def test_field_flow(h):
    tok = h.session()["token"]
    st = state(h, tok)
    ox = next(c for c in st["cows"] if c["bull"])  # 開局的小公牛是耕牛
    cow = next(c for c in st["cows"] if not c["bull"])
    assert ox["type"] == "dual" and "type_name" not in ox
    assert ox["rice_per_h"] == 0.0 and cow["rice_per_h"] == 0.0  # 耕牛小牛、乳牛都是 0
    err(h.post("/v1/field/assign", tok, {"cow_id": ox["id"], "request_id": new_rid()}), 409, "cow_not_adult")
    err(h.post("/v1/field/assign", tok, {"cow_id": cow["id"], "request_id": new_rid()}), 409, "not_an_ox")
    h.advance(OB.starter_calf_remaining_s)
    # 成年耕牛還沒下田：rice_per_h 是「下田的話」每小時的產量（S04-06「耕田 11 公斤稻米／時」），不是 0
    idle = next(c for c in state(h, tok)["cows"] if c["id"] == ox["id"])
    engine_ox = h.server.game.players[st["player_id"]].farm.cow_by_id(ox["id"])
    assert not idle["working"] and idle["rice_per_h"] > 0
    assert idle["rice_per_h"] == round(cow_rice_rate(FP, engine_ox, h.clock.now()), 2)
    r = h.post("/v1/field/assign", tok, {"cow_id": ox["id"], "request_id": new_rid()}).json()
    assert r["field"] == 0 and r["fields"][0]["cow_id"] == ox["id"]
    c = next(c for c in r["state"]["cows"] if c["id"] == ox["id"])
    assert c["working"] and c["field"] == 0 and not c["can_ship"] and not c["can_breed"]
    assert c["rice_per_h"] == idle["rice_per_h"]  # 下田前後同一個值
    assert r["fields"][0]["per_hour"] == pytest.approx(c["rice_per_h"], abs=0.005)  # 田的 per_hour 取到 6 位
    err(h.post("/v1/ship", tok, {"cow_id": ox["id"], "request_id": new_rid()}), 409, "cow_in_field")
    err(h.post("/v1/breed", tok, {"sire": ox["id"], "dam": cow["id"], "request_id": new_rid()}), 409, "cow_in_field")
    err(h.post("/v1/field/assign", tok, {"cow_id": ox["id"], "request_id": new_rid()}), 409, "cow_in_field")
    h.advance(2 * 3600)
    st = state(h, tok)
    grown = st["fields"][0]["rice"]
    p = h.server.game.players[st["player_id"]]
    assert grown == pytest.approx(p.farm.field_preview(h.clock.now())[0], abs=1e-6) and grown > 0
    assert st["rice"]["per_hour"] > 0 and st["fields"][0]["capacity"] > 0
    hv = h.post("/v1/field/harvest", tok, {"request_id": new_rid()}).json()
    assert hv["harvested"] == pytest.approx(grown, abs=1e-6) and hv["warehouse"]["rice_total"] == pytest.approx(
        grown, abs=1e-6
    )
    s = h.post("/v1/sell", tok, {"commodity": "rice", "qty": grown / 2, "request_id": new_rid()}).json()
    assert (
        s["commodity"] == "rice"
        and s["total"] > 0
        and s["warehouse"]["rice_total"] == pytest.approx(grown / 2, abs=1e-6)
    )
    rc = h.post("/v1/field/recall", tok, {"cow_id": ox["id"], "request_id": new_rid()}).json()
    assert rc["fields"][0]["cow_id"] is None
    err(h.post("/v1/field/recall", tok, {"cow_id": ox["id"], "request_id": new_rid()}), 409, "cow_not_in_field")
    # 開新田、指定田號
    give(h, tok, coins=1_000_000)
    cost = p.farm.next_field_cost()
    ex = h.post("/v1/field/expand", tok, {"request_id": new_rid()}).json()
    assert ex["cost"] == int(round(cost)) and len(ex["fields"]) == FP.field_start + 1
    err(
        h.post("/v1/field/assign", tok, {"cow_id": ox["id"], "field": 99, "request_id": new_rid()}),
        404,
        "field_not_found",
    )
    assert (
        h.post("/v1/field/assign", tok, {"cow_id": ox["id"], "field": 1, "request_id": new_rid()}).json()["field"] == 1
    )
    assert h.post("/v1/upgrade", tok, {"kind": "field", "request_id": new_rid()}).status_code == 200  # upgrade 也能開田


def test_field_capacity_and_per_hour_when_full(h):
    """S17：田的容量 = economy 的 ox_rice_per_h × tier_mult × field_cap_h（壯年的產量，不乘年齡曲線）。
    長滿就停，但 fields[].per_hour 不會變 0；rice.per_hour 是所有有牛的田加起來，長滿的也算（farm.rice_rate）。
    有沒有長滿看 rice ≥ capacity（協定 2.3）。"""
    tok = h.session()["token"]
    st = state(h, tok)
    starter = next(c for c in st["cows"] if c["bull"])  # 開局的小公牛是一般耕牛
    h.advance(OB.starter_calf_remaining_s)
    p = give(h, tok, coins=1_000_000, slots=10)
    now = h.clock.now()
    rare = Cow(p.farm._new_id(), make_genotype(1, [(1, 1), (1, 1), (0, 0)]), True, now, FP, adult_at=now)  # 稀有耕牛
    rare.grown, rare.vt = True, rare.tier  # 已經長大揭曉、沒變雜種（v0.3）
    p.farm.cows.append(rare)
    assert rare.tier == 2
    r = h.post("/v1/field/assign", tok, {"cow_id": rare.cid, "field": 0, "request_id": new_rid()}).json()
    eco, f0 = r["state"]["economy"], r["fields"][0]
    assert eco["field_cap_h"] == FP.field_cap_h
    assert f0["capacity"] == round(eco["ox_rice_per_h"] * eco["tier_mult"][2] * eco["field_cap_h"], 2)
    assert h.post("/v1/field/expand", tok, {"request_id": new_rid()}).status_code == 200
    # 壯年（成年後 milk_prime_h 小時內）全速：field_cap_h 小時就長滿。多等 2 小時讓第 0 塊長滿，再派開局的耕牛去第 1 塊
    assert FP.field_cap_h + 3 < FP.milk_prime_h
    h.advance((FP.field_cap_h + 2) * 3600)
    assert (
        h.post("/v1/field/assign", tok, {"cow_id": starter["id"], "field": 1, "request_id": new_rid()}).status_code
        == 200
    )
    h.advance(3600)
    st = state(h, tok)
    full, growing = st["fields"]
    assert full["rice"] == pytest.approx(full["capacity"], abs=1e-6)  # 長滿就停
    assert growing["rice"] < growing["capacity"]
    cows = {c["id"]: c for c in st["cows"]}
    for f in (full, growing):  # 長滿了 per_hour 也不是 0：就是那頭牛的 rice_per_h（取位不同）
        assert f["per_hour"] > 0 and f["per_hour"] == pytest.approx(cows[f["cow_id"]]["rice_per_h"], abs=0.005)
    assert st["rice"]["per_hour"] == pytest.approx(full["per_hour"] + growing["per_hour"], abs=1e-5)  # 長滿的也算
    # S17「每小時」要的是還在長的量：app 只加 rice < capacity 的田，所以比 rice.per_hour 少
    assert sum(f["per_hour"] for f in st["fields"] if f["rice"] < f["capacity"]) < st["rice"]["per_hour"]


# ---------------------------------------------------------------------------
# 借種：錢給主人、小牛歸借的人、一次用掉
# ---------------------------------------------------------------------------
def test_stud_borrow_pays_owner_and_calf_goes_to_borrower(h):
    a = h.session()["token"]  # 主人
    b = h.session()["token"]  # 借的人
    h.advance(OB.starter_calf_remaining_s)
    sa, sb = state(h, a), state(h, b)
    bull = next(c for c in sa["cows"] if c["bull"])
    lst = h.post("/v1/stud/list", a, {"cow_id": bull["id"], "request_id": new_rid()}).json()["listing"]
    price = lst["fee"]["price"]  # D26：系統依公牛現在的體重和稀有度算
    assert (
        lst["is_mine"] and lst["fee"] == expected_fee(h, sa["player_id"], bull["id"]) and lst["breed"] == bull["breed"]
    )
    assert lst["owner"] == {  # 協定 1.6 節的牧場物件；真人送自己的名字
        "player_id": sa["player_id"],
        "name": sa["ranch_name"],
        "name_words": None,
        "is_bot": False,
        "level": sa["level"],
        "avatar": None,  # S21：沒選過頭像
    }
    assert not {"owner_id", "owner_name", "is_bot", "type_name", "tier_name"} & set(lst)
    assert next(c for c in state(h, a)["cows"] if c["id"] == bull["id"])["listed"] == lst["id"]
    err(h.post("/v1/ship", a, {"cow_id": bull["id"], "request_id": new_rid()}), 409, "cow_listed")
    # 主人不能借自己的
    own_cow = next(c for c in sa["cows"] if not c["bull"])
    err(
        h.post(
            "/v1/stud/borrow",
            a,
            {"listing_id": lst["id"], "dam": own_cow["id"], "price": price, "request_id": new_rid()},
        ),
        409,
        "own_listing",
    )
    # 借的人：錢與空格
    dam = next(c for c in sb["cows"] if not c["bull"])
    err(
        h.post(
            "/v1/stud/borrow", b, {"listing_id": lst["id"], "dam": dam["id"], "price": price, "request_id": new_rid()}
        ),
        409,
        "pen_full",
    )
    give(h, b, coins=price - 1, slots=5)
    err(
        h.post(
            "/v1/stud/borrow", b, {"listing_id": lst["id"], "dam": dam["id"], "price": price, "request_id": new_rid()}
        ),
        409,
        "not_enough_coins",
    )
    give(h, b, coins=price + 1000)
    pv = h.get("/v1/stud/preview", b, listing_id=lst["id"], dam=dam["id"]).json()
    pa = h.server.game.players[sa["player_id"]]
    assert pv["can_borrow"] and pv["fee"]["price"] == price and "price" not in pv
    assert pv["tier_probs"] == pytest.approx(
        tier_distribution(
            pa.farm.cow_by_id(bull["id"]).g, h.server.game.players[sb["player_id"]].farm.cow_by_id(dam["id"]).g
        )
    )
    check_offspring_distribution(pv)
    a_coins, b_cows = state(h, a)["coins"], len(state(h, b)["cows"])
    rid = new_rid()
    r1 = h.post("/v1/stud/borrow", b, {"listing_id": lst["id"], "dam": dam["id"], "price": price, "request_id": rid})
    assert r1.status_code == 200, r1.text
    r2 = h.post("/v1/stud/borrow", b, {"listing_id": lst["id"], "dam": dam["id"], "price": price, "request_id": rid})
    assert r1.json() == r2.json()  # 重送：同一個結果、只付一次
    body = r1.json()
    assert body["price"] == price and body["coins"] == 1000 and body["calf"]["origin"] == "stud" and body["dam"]["bred"]
    assert state(h, a)["coins"] == a_coins + price  # 錢給主人
    assert len(state(h, b)["cows"]) == b_cows + 1  # 小牛歸借的人
    assert state(h, a)["stud"]["income"] == price
    bull_after = next(c for c in state(h, a)["cows"] if c["id"] == bull["id"])
    assert bull_after["bred"] and bull_after["listed"] is None  # 公牛的一次用掉、自動下架
    assert lst["id"] not in {x["id"] for x in h.get("/v1/stud", b).json()["listings"]}
    err(
        h.post(
            "/v1/stud/borrow", b, {"listing_id": lst["id"], "dam": dam["id"], "price": price, "request_id": new_rid()}
        ),
        404,
        "listing_not_found",
    )
    # 被借走的上架：預覽也回 404 listing_not_found（協定 4.3，算不出借種費和小牛機率），不是 200 加 listing_gone
    e = err(h.get("/v1/stud/preview", b, listing_id=lst["id"], dam=dam["id"]), 404, "listing_not_found")
    assert e["detail"] == {"listing_id": lst["id"]}
    # 主人牧場在同一個交易裡存進資料庫
    import json as _json

    row = h.client.portal.call(_count, h, "SELECT state FROM farms WHERE player_id=$1", sa["player_id"])
    row = _json.loads(row) if isinstance(row, str) else row
    assert int(round(row["farm"]["coins"])) == a_coins + price


def test_stud_fee_follows_weight_and_price_changed(h):
    """D26：借種費 = 公牛現在的體重 × 每公斤價格，跟著長大自動漲；借種時跟預覽的不同就回 409 price_changed，什麼都不扣。"""
    a = h.session()["token"]
    b = h.session()["token"]
    h.advance(OB.starter_calf_remaining_s)
    sa = state(h, a)
    bull = next(c for c in sa["cows"] if c["bull"])
    cow = next(c for c in sa["cows"] if not c["bull"])
    assert bull["stud_fee"] == expected_fee(h, sa["player_id"], bull["id"]) and not bull["stud_fee"]["at_max"]
    assert bull["stud_fee"]["kg"] == pytest.approx(bull["weight_kg"], abs=0.01)  # 跟出貨的體重同一個算法
    assert cow["stud_fee"] is None  # 母牛沒有
    lst = h.post("/v1/stud/list", a, {"cow_id": bull["id"], "request_id": new_rid()}).json()["listing"]
    give(h, b, coins=100_000, slots=5)
    dam = next(c for c in state(h, b)["cows"] if not c["bull"])
    old = h.get("/v1/stud/preview", b, listing_id=lst["id"], dam=dam["id"]).json()["fee"]["price"]
    new = old
    for _ in range(100):  # 公牛長大到借種費變了
        h.advance(600, tick=False)
        new = expected_fee(h, sa["player_id"], bull["id"])["price"]
        if new != old:
            break
    assert new > old
    listed = next(x for x in h.get("/v1/stud", b).json()["listings"] if x["id"] == lst["id"])
    assert listed["fee"]["price"] == new  # 上架清單也是現算的
    coins_b = state(h, b)["coins"]
    body = {"listing_id": lst["id"], "dam": dam["id"], "price": old, "request_id": new_rid()}
    e = err(h.post("/v1/stud/borrow", b, body), 409, "price_changed")
    assert e["detail"] == {"price": new, "expected": old}
    assert state(h, b)["coins"] == coins_b and len(state(h, b)["cows"]) == 2  # 什麼都沒扣、沒有小牛
    r = h.post("/v1/stud/borrow", b, {**body, "price": new, "request_id": new_rid()})
    assert r.status_code == 200, r.text
    assert r.json()["price"] == new and state(h, b)["coins"] == coins_b - new
    sa2 = state(h, a)
    assert sa2["stud"]["income"] == new
    assert next(c for c in sa2["cows"] if c["id"] == bull["id"])["stud_fee"] is None  # 配過種就沒有借種費


def test_stud_log(h):
    """借種紀錄（S18-11；協定 4.6 節）：借出、借入各一筆，跟借種同一個交易寫入；對方是牧場物件（含公營種牛站）；
    重送不會多記；超過保留期限的刪掉。"""
    a = h.session("主人牧場")["token"]
    b = h.session("借方牧場")["token"]
    h.advance(OB.starter_calf_remaining_s)
    sa, sb = state(h, a), state(h, b)
    bull = next(c for c in sa["cows"] if c["bull"])
    lst = h.post("/v1/stud/list", a, {"cow_id": bull["id"], "request_id": new_rid()}).json()["listing"]
    give(h, b, coins=100_000, slots=10)
    dam = next(c for c in sb["cows"] if not c["bull"])
    body = {"listing_id": lst["id"], "dam": dam["id"], "price": lst["fee"]["price"], "request_id": new_rid()}
    r = h.post("/v1/stud/borrow", b, body).json()
    assert h.post("/v1/stud/borrow", b, body).json() == r  # 重送：回第一次的結果，不會多記一筆

    def ref(tok):
        st = state(h, tok)
        return {
            "player_id": st["player_id"],
            "name": st["ranch_name"],
            "name_words": None,
            "is_bot": False,
            "level": st["level"],
            "avatar": None,  # S21：沒選過頭像
        }

    la = h.get("/v1/stud/log", a).json()
    assert la["keep_days"] == 30 and la["income_total"] == r["price"]
    assert la["entries"] == [
        {
            "kind": "out",
            "t": r["server_time"],
            "price": r["price"],
            "bull": {"id": bull["id"], "breed": bull["breed"]},
            "calf": None,
            "ranch": ref(b),
        }
    ]
    lb = h.get("/v1/stud/log", b).json()
    assert lb["income_total"] == 0
    assert lb["entries"] == [
        {
            "kind": "in",
            "t": r["server_time"],
            "price": r["price"],
            "bull": {"id": None, "breed": bull["breed"]},
            "calf": {"id": r["calf"]["id"], "breed": r["calf"]["breed"]},
            "ranch": ref(a),
        }
    ]
    # 向公營種牛站借：對方是公營種牛站的牧場物件（沒有 player_id）
    npc = next(x for x in h.get("/v1/stud", a).json()["listings"] if x["owner"]["player_id"] is None)
    cow_a = next(c for c in sa["cows"] if not c["bull"])
    give(h, a, coins=100_000, slots=10)
    body2 = {"listing_id": npc["id"], "dam": cow_a["id"], "price": npc["fee"]["price"], "request_id": new_rid()}
    assert h.post("/v1/stud/borrow", a, body2).status_code == 200
    la = h.get("/v1/stud/log", a).json()
    assert [e["kind"] for e in la["entries"]] == ["in", "out"]  # 新的在前
    e = la["entries"][0]
    assert e["ranch"] == npc["owner"] and e["bull"] == {"id": None, "breed": npc["breed"]}
    assert e["price"] == npc["fee"]["price"] and la["income_total"] == r["price"]  # 借入不算收入
    # 超過保留期限的刪掉（伺服器每 60 個 tick 清一次；這裡直接叫）
    h.client.portal.call(h.server.store.prune, 0.0, 7, h.clock.now() + 1)
    assert h.get("/v1/stud/log", a).json()["entries"] == [] and h.get("/v1/stud/log", b).json()["entries"] == []


def test_stud_unlist_and_npc_listings(h):
    a = h.session()["token"]
    h.advance(OB.starter_calf_remaining_s)
    sa = state(h, a)
    bull = next(c for c in sa["cows"] if c["bull"])
    lst = h.post("/v1/stud/list", a, {"cow_id": bull["id"], "request_id": new_rid()}).json()["listing"]
    err(h.post("/v1/stud/list", a, {"cow_id": bull["id"], "request_id": new_rid()}), 409, "cow_listed")
    u = h.post("/v1/stud/unlist", a, {"listing_id": lst["id"], "request_id": new_rid()}).json()
    assert (
        u["listing_id"] == lst["id"] and next(c for c in u["state"]["cows"] if c["id"] == bull["id"])["listed"] is None
    )
    err(h.post("/v1/stud/unlist", a, {"listing_id": lst["id"], "request_id": new_rid()}), 404, "listing_not_found")
    dam = next(c for c in sa["cows"] if not c["bull"])
    err(h.get("/v1/stud/preview", a, listing_id=lst["id"], dam=dam["id"]), 404, "listing_not_found")  # 下架後的預覽
    # 公營種牛站（電腦系統上架）：錢不給任何人，借走後會補上
    market = h.get("/v1/stud", a).json()
    npc = [x for x in market["listings"] if x["owner"]["player_id"] is None]
    assert len(npc) >= FP.npc_stud_listings
    assert {h.server.game.stud.listings[x["id"]].ctype for x in npc} == {0, 1, 2}  # 乳牛、耕牛、肉牛各一（協定第 4 節）
    now = h.clock.now()
    for x in npc:  # 公營種牛站：用那種用途公牛的最佳體重算（一般公牛：乳牛 300、耕牛 540、肉牛 970）
        lst_e = h.server.game.stud.listings[x["id"]]
        price, kg, _ = stud_fee(FP, lst_e.ctype, lst_e.tier, None, now)
        assert x["fee"] == {
            "price": int(price),
            "per_kg": FP.stud_fee_per_kg[x["tier"]],
            "kg": round(kg, 2),
            "at_max": True,
        }
        if x["tier"] == 0:
            assert x["fee"]["price"] == {"dairy": 300, "dual": 540, "beef": 970}[x["type"]]
    for x in npc:  # 沒有 #編號和等級；名字是詞庫編號，由上架編號決定
        o = x["owner"]
        assert o["is_bot"] and o["name"] is None and o["level"] is None and x["cow_id"] is None
        assert o["name_words"] == station_words(h.server.game.seed, x["id"]) and all(
            0 <= w < 12 for w in o["name_words"]
        )
    give(h, a, coins=10_000, slots=5)
    dam = next(c for c in sa["cows"] if not c["bull"])
    p0 = npc[0]["fee"]["price"]
    r = h.post(
        "/v1/stud/borrow", a, {"listing_id": npc[0]["id"], "dam": dam["id"], "price": p0, "request_id": new_rid()}
    ).json()
    assert r["price"] == p0 and r["coins"] == 10_000 - p0
    after = [x for x in h.get("/v1/stud", a).json()["listings"] if x["owner"]["player_id"] is None]
    assert len(after) >= FP.npc_stud_listings and npc[0]["id"] not in {x["id"] for x in after}


# ---------------------------------------------------------------------------
# 行情、排行榜、WebSocket、網頁版
# ---------------------------------------------------------------------------
def test_market_and_history(h):
    tok = h.session()["token"]
    h.advance(3 * 3600)
    m = h.get("/v1/market", tok).json()
    for cid in DEFAULT.commodity_ids:
        q = m[cid]
        assert set(q) == {
            "price",
            "change_24h",
            "change_24h_pct",
            "ma24",
            "base_price",
            "ratio",
        }  # v2：沒有 history、unit
        assert q["base_price"] == DEFAULT.commodity(cid).base_price
        assert q["ratio"] == pytest.approx(q["price"] / q["base_price"], abs=1e-5)
    assert m["tick_t"] == m["server_time"]
    for rng, step in (("1h", 60), ("1d", 300), ("7d", 1800)):
        r = h.get("/v1/market/history", tok, commodity="rice", range=rng).json()
        assert r["step_s"] == step and r["points"]
    err(h.get("/v1/market/history", tok, commodity="gold", range="1h"), 400, "bad_request")


def test_leaderboard_ranch_and_level(h):
    """每列是協定 1.6 節的牧場物件（含等級）；電腦牧場送詞庫編號，組回去就是伺服器存的名字。"""
    tok = h.session()["token"]
    st = state(h, tok)
    h.advance(3600)
    words = load_words()
    for kind in ("networth", "collection", "weekly"):
        lb = h.get("/v1/leaderboard", tok, kind=kind).json()
        assert lb["kind"] == kind and lb["total"] == 4
        assert all(set(e) == {"rank", "ranch", "score", "is_me"} for e in lb["entries"])
        bots = [e["ranch"] for e in lb["entries"] if e["ranch"]["is_bot"]]
        assert len(bots) == 3
        for r in bots:
            p = h.server.game.players[r["player_id"]]
            assert r["name"] is None and r["level"] == p.level()
            assert "".join(words[g][i] for g, i in zip(("first", "second", "third"), r["name_words"])) == p.name
        assert [e["rank"] for e in lb["entries"]] == [1, 2, 3, 4]
        me = lb["me"]
        assert me["is_me"] and me["ranch"] == {
            "player_id": st["player_id"],
            "name": st["ranch_name"],
            "name_words": None,
            "is_bot": False,
            "level": st["level"],
            "avatar": None,  # S21：沒選過頭像
        }
        assert sum(e["is_me"] for e in lb["entries"]) == 1
        if kind == "weekly":  # 下次重算的現實時間（app 依手機時區顯示「每週一 00:00 重新計算」）
            assert lb["week_started_at_real"] <= lb["real_time"] < lb["next_reset_at_real"]
            span = (lb["next_reset_at_real"] - lb["week_started_at_real"]) * lb["time_scale"]
            assert span == pytest.approx(7 * 86400)
            assert week_start(week_id(lb["server_time"]) + 1) - lb["server_time"] == pytest.approx(
                (lb["next_reset_at_real"] - lb["real_time"]) * lb["time_scale"]
            )
        else:
            assert "next_reset_at_real" not in lb


def test_websocket_push_and_auth(h):
    tok = h.session()["token"]
    with h.client.websocket_connect(f"/v1/ws?token={tok}") as ws:
        hello = ws.receive_json()
        assert hello["type"] == "hello" and hello["protocol"] == 2
        m = ws.receive_json()
        assert m["type"] == "market" and "server_time" in m
        for cid in DEFAULT.commodity_ids:
            assert set(m[cid]) >= {"price", "change_24h", "ma24"}
    with h.client.websocket_connect("/v1/ws", subprotocols=["cowfarm.v1", f"cowfarm.token.{tok}"]) as ws:
        assert ws.receive_json()["type"] == "hello"
    with h.client.websocket_connect("/v1/ws?token=bad") as ws:
        e = ws.receive_json()
        assert e["type"] == "error" and e["error"]["code"] == "unauthorized"
        with pytest.raises(WebSocketDisconnect) as exc:
            ws.receive_json()
        assert exc.value.code == 4401


def test_websocket_stud_notice_to_owner(h):
    a = h.session()["token"]
    b = h.session()["token"]
    h.advance(OB.starter_calf_remaining_s)
    bull = next(c for c in state(h, a)["cows"] if c["bull"])
    lst = h.post("/v1/stud/list", a, {"cow_id": bull["id"], "request_id": new_rid()}).json()["listing"]
    give(h, b, coins=10_000, slots=5)
    dam = next(c for c in state(h, b)["cows"] if not c["bull"])
    with h.client.websocket_connect(f"/v1/ws?token={a}") as ws:
        ws.receive_json()
        ws.receive_json()
        assert (
            h.post(
                "/v1/stud/borrow",
                b,
                {"listing_id": lst["id"], "dam": dam["id"], "price": lst["fee"]["price"], "request_id": new_rid()},
            ).status_code
            == 200
        )
        n = ws.receive_json()
        assert (
            n["type"] == "stud"
            and n["event"] == "borrowed"
            and n["listing_id"] == lst["id"]
            and n["price"] == lst["fee"]["price"]
        )
        sb = state(h, b)  # 借方是協定 1.6 節的牧場物件（G-05「{cow} 借給 {ranch}」）
        assert n["cow"] == {"id": bull["id"], "breed": bull["breed"]} and "cow_id" not in n
        assert n["borrower"] == {
            "player_id": sb["player_id"],
            "name": sb["ranch_name"],
            "name_words": None,
            "is_bot": False,
            "level": sb["level"],
            "avatar": None,  # S21：沒選過頭像
        }


def test_news_pushed_over_websocket(h):
    tok = h.session()["token"]
    with h.client.websocket_connect(f"/v1/ws?token={tok}") as ws:
        ws.receive_json()
        ws.receive_json()
        h.advance(86400)  # 平均每天好幾則新聞
        assert h.server.news_log, "這個 seed 第一天應該有新聞"
        n = ws.receive_json()
        while n["type"] != "news":
            n = ws.receive_json()
        for k in (
            "id",
            "code",
            "params",
            "pct",
            "commodity",
            "targets",
            "direction",
            "tier",
            "big",
            "time",
            "start_at",
            "end_at",
        ):
            assert k in n
        assert "title" not in n  # v2：送代碼，app 查字串表 news.<code>
        assert n["direction"] in ("up", "down") and set(n["targets"]) <= set(DEFAULT.commodity_ids)
        # 代碼對回引擎挑的標題；幅度 = factor − 1，正負跟利多利空一致
        ev = h.server.news_log[n["id"]]
        key, idx = n["code"].split(".")
        commodity, kind = key.rsplit("_", 1)
        # D33：超級大事件、黑天鵝用專屬標題（代碼 _super、_swan；HEADLINES 的 ++、--）
        suffix, direction = {"up": ("+", "up"), "down": ("-", "down"), "super": ("++", "up"), "swan": ("--", "down")}[
            kind
        ]
        assert direction == n["direction"] and n["params"] == {}
        assert (kind in ("super", "swan")) == (n["tier"] in ("super", "crash"))
        assert HEADLINES[commodity + suffix][int(idx) - 1] == ev.headline
        assert commodity == (n["commodity"] or "all")
        assert n["pct"] == pytest.approx(ev.factor - 1.0, abs=1e-4) and (n["pct"] > 0) == (direction == "up")
        # D33：級別和幅度對得上；big = 大事件以上
        _name, _p, lo, hi, _up = next(t for t in DEFAULT.events.tiers if t[0] == ev.tier)
        assert n["tier"] == ev.tier and lo - 1e-4 <= abs(n["pct"]) <= hi + 1e-4
        assert n["big"] == (n["tier"] != "normal")
    ids = {x["id"] for x in h.get("/v1/market", tok).json()["news"]}
    assert n["id"] in ids
    for x in h.get("/v1/market", tok).json()["news"]:
        assert x["tier"] in TIER_NAMES and x["big"] == (x["tier"] != "normal")
        assert x["announce_at"] == x["start_at"] == x["time"] and x["state"] != "upcoming"  # D33：全部不預告


def test_news_tier_saved_and_old_rows_without_tier(db_dsn):
    """D33：新聞的級別存進 news 表（rare 照舊存 = 大事件以上）。D33 以前的列 tier 是 NULL：
    重開伺服器時，已經結束的新聞從 news 表讀回來，照 rare 當 big／normal；還在進行的照交易所存檔裡的級別。"""
    import asyncio

    import asyncpg

    async def query(sql):
        conn = await asyncpg.connect(db_dsn)
        try:
            return await conn.fetch(sql)
        finally:
            await conn.close()

    with Harness(db_dsn) as h:
        h.advance(2 * 86400)
    rows = asyncio.run(query("SELECT id, tier, rare FROM news ORDER BY id"))
    assert len(rows) >= 4
    assert all(r["tier"] in TIER_NAMES and r["rare"] == (r["tier"] != "normal") for r in rows)
    asyncio.run(query("UPDATE news SET tier = NULL"))  # 變成 D33 以前存的樣子
    with Harness(db_dsn) as h:
        active = {ev.eid for ev in h.server.game.ex.events}
        ended = [r for r in rows if r["id"] not in active]
        assert ended, "要有已經結束、從 news 表讀回來的新聞"
        for r in rows:
            ev = h.server.news_log[r["id"]]
            assert ev.tier == (r["tier"] if r["id"] in active else ("big" if r["rare"] else "normal"))


def _set_maintenance(h, value):
    """測試用：直接寫 meta 的 maintenance（跟 scripts/maint.py 一樣），再叫伺服器重讀。"""

    async def go():
        async with h.server.store.pool.acquire() as conn:
            if value is None:
                await conn.execute("DELETE FROM meta WHERE key='maintenance'")
            else:
                await conn.execute(
                    "INSERT INTO meta(key, value) VALUES('maintenance', $1) "
                    "ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value",
                    value,
                )

    h.client.portal.call(go)
    h.client.portal.call(h.server.reload_maintenance)


def test_maintenance(h):
    """維護（協定第 6 節）：/v1/status 不用 token；預告時照常玩並推 maintenance；開始後 503、WebSocket 4503；結束後恢復。"""
    tok = h.session()["token"]
    st = h.client.get("/v1/status").json()
    assert st["protocol"] == 2 and st["maintenance"] is None and "server_time" in st
    assert state(h, tok)["maintenance"] is None
    now = time.time()
    with h.client.websocket_connect(f"/v1/ws?token={tok}") as ws:
        ws.receive_json()
        ws.receive_json()
        _set_maintenance(h, {"starts_at_real": now + 3600, "ends_at_real": now + 7200})  # 預告
        m = ws.receive_json()
        assert m["type"] == "maintenance"
        assert m["maintenance"] == {"starts_at_real": now + 3600, "ends_at_real": now + 7200, "active": False}
        assert h.client.get("/v1/status").json()["maintenance"]["active"] is False
        assert state(h, tok)["maintenance"]["ends_at_real"] == now + 7200  # 預告時照常玩
        _set_maintenance(h, {"starts_at_real": now - 1, "ends_at_real": now + 3600})  # 開始了
        m = ws.receive_json()
        assert m["type"] == "maintenance" and m["maintenance"]["active"] is True
        with pytest.raises(WebSocketDisconnect) as exc:
            ws.receive_json()
        assert exc.value.code == 4503
    e = err(h.get("/v1/state", tok), 503, "maintenance")
    assert e["detail"] == {"ends_at_real": now + 3600}
    err(h.client.post("/v1/session", json={"ranch_name": "牧場"}), 503, "maintenance")
    assert h.client.get("/v1/status").json()["maintenance"]["active"] is True  # 維護中也能打
    with h.client.websocket_connect("/v1/ws?token=bad") as ws:  # 維護中：先說維護，不管 token
        assert ws.receive_json()["type"] == "maintenance"
        with pytest.raises(WebSocketDisconnect) as exc:
            ws.receive_json()
        assert exc.value.code == 4503
    _set_maintenance(h, None)  # 結束
    assert h.get("/v1/state", tok).status_code == 200 and h.client.get("/v1/status").json()["maintenance"] is None
    with h.client.websocket_connect(f"/v1/ws?token={tok}") as ws:
        assert ws.receive_json()["type"] == "hello"


def test_maintenance_script_notifies_server(h, db_dsn):
    """scripts/maint.py 寫資料庫並 NOTIFY，執行中的伺服器不用重啟就知道。"""
    import os
    import subprocess
    import sys
    from pathlib import Path

    script = Path(__file__).resolve().parents[1] / "scripts" / "maint.py"
    env = {**os.environ, "COWFARM_PG_DSN": db_dsn}

    def run(*args):
        r = subprocess.run([sys.executable, str(script), *args], env=env, capture_output=True, text=True, timeout=60)
        assert r.returncode == 0, r.stderr
        return r.stdout

    def wait_status(pred):
        for _ in range(50):
            m = h.client.get("/v1/status").json()["maintenance"]
            if pred(m):
                return m
            time.sleep(0.1)
        raise AssertionError("伺服器沒有收到通知")

    assert "已安排" in run("schedule", "+1h", "+30m")
    m = wait_status(lambda m: m is not None)
    assert m["active"] is False and m["ends_at_real"] - m["starts_at_real"] == pytest.approx(1800)
    assert "預告中" in run("status")
    assert "已結束" in run("end")
    wait_status(lambda m: m is None)
    assert "沒有安排" in run("status")


def test_client_time_is_ignored(h):
    """用戶端送時間欄位也沒用：伺服器只看自己的遊戲時鐘。"""
    tok = h.session()["token"]
    r = h.post("/v1/collect", tok, {"request_id": new_rid(), "server_time": 9e12, "now": 9e12, "time": 9e12})
    assert r.status_code == 200
    assert r.json()["collected"] == pytest.approx(OB.start_bucket)
    assert r.json()["server_time"] == h.clock.now()


def test_static_web_dir(db_dsn, tmp_path):
    """COWFARM_WEB_DIR 有東西就在 / 提供網頁；資料夾不存在時照常啟動，API 不受影響。"""
    (tmp_path / "index.html").write_text("<html>cow</html>", encoding="utf-8")
    with Harness(db_dsn, web_dir=str(tmp_path)) as hh:
        r = hh.client.get("/")
        assert r.status_code == 200 and "cow" in r.text
        assert hh.client.post("/v1/session", json={"ranch_name": "牧場"}).status_code == 200  # API 優先於靜態檔
    with Harness(db_dsn, web_dir=str(tmp_path / "missing")) as hh:
        err(hh.client.get("/"), 404, "not_found")
        assert hh.client.post("/v1/session", json={"ranch_name": "牧場"}).status_code == 200


def test_old_world_format_is_refused(db_dsn):
    """v0.2 的世界（圖鑑還是「用途 × 稀有度」，沒有 format 欄位）：伺服器拒絕啟動，不會讀到一半壞掉。"""
    import asyncio

    import asyncpg

    with Harness(db_dsn) as hh:
        hh.session()

    async def make_v02():
        conn = await asyncpg.connect(db_dsn)
        try:
            await conn.execute("UPDATE meta SET value = value - 'format' WHERE key='world'")
            await conn.execute("UPDATE farms SET state = jsonb_set(state, '{codex}', '[[0, 0], [1, 0]]')")
        finally:
            await conn.close()

    asyncio.run(make_v02())
    with pytest.raises(RuntimeError, match="存檔格式 2"):
        with Harness(db_dsn):
            pass


def test_old_v01_world_is_refused(db_dsn):
    """舊（v0.1）世界的資料庫：伺服器拒絕啟動並說明怎麼處理，不會讀到一半壞掉。"""
    import asyncio

    import asyncpg

    with Harness(db_dsn) as hh:
        hh.session()

    async def make_old():
        conn = await asyncpg.connect(db_dsn)
        try:
            await conn.execute("UPDATE meta SET value = jsonb_set(value, '{engine}', '\"0.1.0\"') WHERE key='world'")
            await conn.execute("DELETE FROM markets WHERE commodity='rice'")
        finally:
            await conn.close()

    asyncio.run(make_old())
    with pytest.raises(RuntimeError, match="不相容"):
        with Harness(db_dsn):
            pass


def test_game_error_does_not_mutate():
    """服務層先檢查後修改：錯誤時牧場完全沒變（直接測服務層）。"""
    game = Game(DEFAULT, "nomut", T0)
    p = game.create_player(T0, "x")
    before = p.state_dict()
    for fn in (
        lambda: game.shop_buy(p.pid, "A", T0),
        lambda: game.ship(p.pid, 2, T0),
        lambda: game.breed(p.pid, 2, 1, T0),
        lambda: game.field_assign(p.pid, 1, None, T0),
        lambda: game.upgrade(p.pid, "field", T0),
        lambda: game.stud_list(p.pid, 2, T0),
        lambda: game.sell(p.pid, "rice", 1, T0),
    ):
        with pytest.raises(GameError):
            fn()
    assert p.state_dict() == before
