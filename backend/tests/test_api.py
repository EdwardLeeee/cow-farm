"""HTTP／WebSocket 協定測試（需要 PostgreSQL），v0.2。

欄位、request_id 防重送、各種錯誤、牛肉倉庫、排行榜，以及 v0.2 的商店等級、出貨評級、配種一次、田地、借種。
時間用手動時鐘（conftest.Harness），不會真的等。

經濟代理還在調 backend/cowecon/params.py 的數值：這裡的期望值一律用引擎（cowecon）算，不寫死數字。
"""

from __future__ import annotations

import random

import pytest
from starlette.websockets import WebSocketDisconnect

from conftest import T0, Harness, new_rid
from cowecon import DEFAULT
from cowecon.farm import (
    Cow,
    beef_grade_probs,
    cow_type,
    draw_beef_grade,
    offspring_distribution,
    shop_draw,
    shop_grade_distribution,
    shop_grade_tier_probs,
    tier_distribution,
    tier_of,
)
from cowecon.params import HEADLINES
from server.game import TYPE_WIRE, Game, GameError, week_id, week_start
from server.names import load_words, station_words

FP = DEFAULT.farm
OB = DEFAULT.onboarding


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
    assert s["ranch_name"] and len(s["ranch_name"]) >= 6
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
    assert st["stud"]["prices"] == [int(x) for x in FP.stud_prices] and st["stud"]["listings"] == []
    cows = {c["id"]: c for c in st["cows"]}
    assert len(cows) == 2
    for c in cows.values():
        for k in (
            "id",
            "type",
            "bull",
            "tier",
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
        ):
            assert k in c, k
        for k in ("type_name", "tier_name", "ready_at", "breed_ready"):  # 協定 v2：不送中文、拿掉 v0.1 欄位
            assert k not in c, k
        assert c["bred"] is False and c["working"] is False and c["listed"] is None
    calf = next(c for c in cows.values() if c["bull"])
    assert calf["stage"] == "calf" and calf["type"] == TYPE_WIRE[OB.starter_calf_type]
    assert calf["adult_at"] == st["server_time"] + OB.starter_calf_remaining_s and calf["grade_probs"] is None
    cow = next(c for c in cows.values() if not c["bull"])
    assert {"type": "dairy", "tier": cow["tier"]} in st["codex"]


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
    err(h.post("/v1/stud/list", tok, {"cow_id": 2, "price": 123, "request_id": new_rid()}), 400, "bad_request")
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
        h.post("/v1/stud/list", tok, {"cow_id": 999, "price": FP.stud_prices[0], "request_id": new_rid()}),
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
        assert g["type_probs"] == pytest.approx({TYPE_WIRE[t]: p for t, p in enumerate(FP.shop_type_probs)})
        assert g["bull_prob"] == pytest.approx(FP.shop_bull_prob)


def test_shop_buy_uses_engine_draw(h):
    """白箱：抽到的牛 = 引擎 shop_draw 用伺服器這一次的亂數抽出來的那頭。"""
    tok = h.session()["token"]
    p = give(h, tok, coins=1_000_000, slots=20)
    for grade in ("A", "B", "C", "A", "C"):
        g, bull = shop_draw(FP, grade, next_rng(h, p.pid))
        r = h.post("/v1/shop/buy", tok, {"grade": grade, "request_id": new_rid()}).json()
        assert (
            r["cow"]["type"] == TYPE_WIRE[cow_type(g)] and r["cow"]["bull"] == bull and r["cow"]["tier"] == tier_of(g)
        )
        assert r["cost"] == int(FP.shop_grade_price[FP.shop_grade_names.index(grade)]) and r["cow"]["origin"] == grade


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
        h.post("/v1/stud/list", tok, {"cow_id": bull["id"], "price": FP.stud_prices[0], "request_id": new_rid()}),
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
    err(h.post("/v1/field/assign", tok, {"cow_id": ox["id"], "request_id": new_rid()}), 409, "cow_not_adult")
    err(h.post("/v1/field/assign", tok, {"cow_id": cow["id"], "request_id": new_rid()}), 409, "not_an_ox")
    h.advance(OB.starter_calf_remaining_s)
    r = h.post("/v1/field/assign", tok, {"cow_id": ox["id"], "request_id": new_rid()}).json()
    assert r["field"] == 0 and r["fields"][0]["cow_id"] == ox["id"]
    c = next(c for c in r["state"]["cows"] if c["id"] == ox["id"])
    assert c["working"] and c["field"] == 0 and not c["can_ship"] and not c["can_breed"]
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


# ---------------------------------------------------------------------------
# 借種：錢給主人、小牛歸借的人、一次用掉
# ---------------------------------------------------------------------------
def test_stud_borrow_pays_owner_and_calf_goes_to_borrower(h):
    a = h.session()["token"]  # 主人
    b = h.session()["token"]  # 借的人
    h.advance(OB.starter_calf_remaining_s)
    sa, sb = state(h, a), state(h, b)
    bull = next(c for c in sa["cows"] if c["bull"])
    price = int(FP.stud_prices[1])
    lst = h.post("/v1/stud/list", a, {"cow_id": bull["id"], "price": price, "request_id": new_rid()}).json()["listing"]
    assert lst["is_mine"] and lst["price"] == price
    assert lst["owner"] == {  # 協定 1.6 節的牧場物件；真人送自己的名字
        "player_id": sa["player_id"],
        "name": sa["ranch_name"],
        "name_words": None,
        "is_bot": False,
        "level": sa["level"],
    }
    assert not {"owner_id", "owner_name", "is_bot", "type_name", "tier_name"} & set(lst)
    assert next(c for c in state(h, a)["cows"] if c["id"] == bull["id"])["listed"] == lst["id"]
    err(h.post("/v1/ship", a, {"cow_id": bull["id"], "request_id": new_rid()}), 409, "cow_listed")
    # 主人不能借自己的
    own_cow = next(c for c in sa["cows"] if not c["bull"])
    err(
        h.post("/v1/stud/borrow", a, {"listing_id": lst["id"], "dam": own_cow["id"], "request_id": new_rid()}),
        409,
        "own_listing",
    )
    # 借的人：錢與空格
    dam = next(c for c in sb["cows"] if not c["bull"])
    err(
        h.post("/v1/stud/borrow", b, {"listing_id": lst["id"], "dam": dam["id"], "request_id": new_rid()}),
        409,
        "pen_full",
    )
    give(h, b, coins=price - 1, slots=5)
    err(
        h.post("/v1/stud/borrow", b, {"listing_id": lst["id"], "dam": dam["id"], "request_id": new_rid()}),
        409,
        "not_enough_coins",
    )
    give(h, b, coins=price + 1000)
    pv = h.get("/v1/stud/preview", b, listing_id=lst["id"], dam=dam["id"]).json()
    pa = h.server.game.players[sa["player_id"]]
    assert pv["can_borrow"] and pv["price"] == price
    assert pv["tier_probs"] == pytest.approx(
        tier_distribution(
            pa.farm.cow_by_id(bull["id"]).g, h.server.game.players[sb["player_id"]].farm.cow_by_id(dam["id"]).g
        )
    )
    a_coins, b_cows = state(h, a)["coins"], len(state(h, b)["cows"])
    rid = new_rid()
    r1 = h.post("/v1/stud/borrow", b, {"listing_id": lst["id"], "dam": dam["id"], "request_id": rid})
    assert r1.status_code == 200, r1.text
    r2 = h.post("/v1/stud/borrow", b, {"listing_id": lst["id"], "dam": dam["id"], "request_id": rid})
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
        h.post("/v1/stud/borrow", b, {"listing_id": lst["id"], "dam": dam["id"], "request_id": new_rid()}),
        404,
        "listing_not_found",
    )
    # 主人牧場在同一個交易裡存進資料庫
    import json as _json

    row = h.client.portal.call(_count, h, "SELECT state FROM farms WHERE player_id=$1", sa["player_id"])
    row = _json.loads(row) if isinstance(row, str) else row
    assert int(round(row["farm"]["coins"])) == a_coins + price


def test_stud_unlist_and_npc_listings(h):
    a = h.session()["token"]
    h.advance(OB.starter_calf_remaining_s)
    sa = state(h, a)
    bull = next(c for c in sa["cows"] if c["bull"])
    lst = h.post(
        "/v1/stud/list", a, {"cow_id": bull["id"], "price": FP.stud_prices[0], "request_id": new_rid()}
    ).json()["listing"]
    err(
        h.post("/v1/stud/list", a, {"cow_id": bull["id"], "price": FP.stud_prices[0], "request_id": new_rid()}),
        409,
        "cow_listed",
    )
    u = h.post("/v1/stud/unlist", a, {"listing_id": lst["id"], "request_id": new_rid()}).json()
    assert (
        u["listing_id"] == lst["id"] and next(c for c in u["state"]["cows"] if c["id"] == bull["id"])["listed"] is None
    )
    err(h.post("/v1/stud/unlist", a, {"listing_id": lst["id"], "request_id": new_rid()}), 404, "listing_not_found")
    # 公營種牛站（電腦系統上架）：錢不給任何人，借走後會補上
    market = h.get("/v1/stud", a).json()
    npc = [x for x in market["listings"] if x["owner"]["player_id"] is None]
    assert len(npc) >= FP.npc_stud_listings and all(x["price"] == int(FP.npc_stud_price) for x in npc)
    for x in npc:  # 沒有 #編號和等級；名字是詞庫編號，由上架編號決定
        o = x["owner"]
        assert o["is_bot"] and o["name"] is None and o["level"] is None and x["cow_id"] is None
        assert o["name_words"] == station_words(h.server.game.seed, x["id"]) and all(
            0 <= w < 12 for w in o["name_words"]
        )
    give(h, a, coins=10_000, slots=5)
    dam = next(c for c in sa["cows"] if not c["bull"])
    r = h.post("/v1/stud/borrow", a, {"listing_id": npc[0]["id"], "dam": dam["id"], "request_id": new_rid()}).json()
    assert r["price"] == int(FP.npc_stud_price) and r["coins"] == 10_000 - int(FP.npc_stud_price)
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
    lst = h.post(
        "/v1/stud/list", a, {"cow_id": bull["id"], "price": FP.stud_prices[0], "request_id": new_rid()}
    ).json()["listing"]
    give(h, b, coins=10_000, slots=5)
    dam = next(c for c in state(h, b)["cows"] if not c["bull"])
    with h.client.websocket_connect(f"/v1/ws?token={a}") as ws:
        ws.receive_json()
        ws.receive_json()
        assert (
            h.post(
                "/v1/stud/borrow", b, {"listing_id": lst["id"], "dam": dam["id"], "request_id": new_rid()}
            ).status_code
            == 200
        )
        n = ws.receive_json()
        assert (
            n["type"] == "stud"
            and n["event"] == "borrowed"
            and n["listing_id"] == lst["id"]
            and n["price"] == int(FP.stud_prices[0])
        )
        sb = state(h, b)  # 借方是協定 1.6 節的牧場物件（G-05「{cow} 借給 {ranch}」）
        assert n["cow"] == {"id": bull["id"]} and "cow_id" not in n
        assert n["borrower"] == {
            "player_id": sb["player_id"],
            "name": sb["ranch_name"],
            "name_words": None,
            "is_bot": False,
            "level": sb["level"],
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
        commodity, direction = key.rsplit("_", 1)
        assert direction == n["direction"] and n["params"] == {}
        assert HEADLINES[commodity + ("+" if direction == "up" else "-")][int(idx) - 1] == ev.headline
        assert commodity == (n["commodity"] or "all")
        assert n["pct"] == pytest.approx(ev.factor - 1.0, abs=1e-4) and (n["pct"] > 0) == (direction == "up")
    ids = {x["id"] for x in h.get("/v1/market", tok).json()["news"]}
    assert n["id"] in ids


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
        assert hh.client.post("/v1/session").status_code == 200  # API 優先於靜態檔
    with Harness(db_dsn, web_dir=str(tmp_path / "missing")) as hh:
        err(hh.client.get("/"), 404, "not_found")
        assert hh.client.post("/v1/session").status_code == 200


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
        lambda: game.stud_list(p.pid, 2, FP.stud_prices[0], T0),
        lambda: game.sell(p.pid, "rice", 1, T0),
    ):
        with pytest.raises(GameError):
            fn()
    assert p.state_dict() == before
