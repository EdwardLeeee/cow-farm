"""v0.3 C1 照顧（協定 2.3、2.6 節；企劃 docs/design/v0.3-care.md）。

- 服務層（不需要資料庫）：餵食的規則和錯誤、全部餵的順序、長大揭曉（圖鑑、成就、配種表）、成就 clean 的時間、
  病牛的限制、GET 用的結算複本跟下一個動作存的一樣。
- HTTP（需要 PostgreSQL）：餵食和揭曉、雜種牛的奶和肉、大便和生病和治療、小幫手、地板。
"""

from __future__ import annotations

import pytest

from conftest import T0, Harness, new_rid
from cowecon import DEFAULT, Cow
from cowecon.farm import HYBRID, make_genotype
from server.breeds import FEED_IDS
from server.game import CLEAN_DAYS, Game, GameError
from server.views import cow_view
from test_api import CP, FP, err, give, state

HOUR = 3600.0
DAY = 24 * HOUR
OATS, SOY = FEED_IDS.index("oats"), FEED_IDS.index("soy")
STRAWBERRY = make_genotype(0, [(1, 1), (1, 1), (1, 1)])  # 草莓牛（傳說乳牛）：燕麥、豆粕
VELVET = make_genotype(0, [(1, 1), (0, 0), (1, 1)])  # 黑絨乳牛（稀有）：燕麥、豆粕
HOLSTEIN = make_genotype(0, [(0, 0), (0, 0), (0, 0)])
ANGUS = make_genotype(2, [(0, 0), (0, 0), (0, 0)])


def calf(p, g, bull=False, now=T0, origin="breed"):
    """白箱：放一頭剛出生的小牛（照牧場現在的年紀速度；不會生病）。"""
    f = p.farm
    c = Cow(f._new_id(), g, bull, now, f.fp, origin=origin, speed=f.speed, late_speed=f.late_speed)
    f.cows.append(c)
    return c


def adult(p, g, bull, now, age_h=1.0):
    """白箱：放一頭已經長大揭曉（沒變雜種）、成年 age_h 小時的牛（不會生病）。"""
    f = p.farm
    c = Cow(f._new_id(), g, bull, now - age_h * HOUR - 3 * HOUR, f.fp, adult_at=now - age_h * HOUR, origin="A")
    c.grown, c.vt = True, c.tier
    f.cows.append(c)
    return c


def never_sick(p):
    for c in p.farm.cows:
        c.thr = None


def code_of(fn, *args, **kw):
    with pytest.raises(GameError) as e:
        fn(*args, **kw)
    return e.value


# ---------------------------------------------------------------------------
# 服務層
# ---------------------------------------------------------------------------
def test_feed_rules_and_errors():
    """餵食（協定 2.6 節）：倉庫沒有、吃飽冷卻、過了最壯、加成滿了、上架中的公牛都不能餵，錯誤碼各不同；什麼都沒扣。"""
    game = Game(DEFAULT, "feed-unit", T0)
    p = game.create_player(T0, "餵食牧場")
    f = p.farm
    f.coins = 1e6
    now = T0 + 60
    game.settle(p.pid, now)
    old = adult(p, HOLSTEIN, False, now, age_h=FP.peak_age_h[0] + 1)  # 過了最壯
    young = adult(p, ANGUS, True, now, age_h=1)
    assert code_of(game.feed, p.pid, young.cid, OATS, now).code == "out_of_feed"
    quote = p.farm.quote_feed_buy(OATS, 3, game.ex.feeds["oats"], now)  # v0.3 B：照市價（含滑價）
    assert game.buy_feed(p.pid, OATS, 3, now)["cost"] == int(round(quote.amount))
    assert code_of(game.buy_feed, p.pid, OATS, CP.feed_cap, now).code == "feed_cap"
    assert code_of(game.buy_feed, p.pid, "oats", 0, now).code == "bad_request"
    e = code_of(game.feed, p.pid, old.cid, OATS, now)
    assert e.code == "feed_no_effect" and e.detail == {"cow_id": old.cid, "reason": "past_peak"}
    game.feed(p.pid, young.cid, OATS, now)
    assert young.bonus == CP.feed_kg[OATS] and f.feeds[OATS] == 2
    e = code_of(game.feed, p.pid, young.cid, OATS, now + 60)
    assert e.code == "cow_full" and e.detail == {"cow_id": young.cid, "until": now + CP.feed_cooldown_s}
    young.bonus = CP.bonus_max_kg
    e = code_of(game.feed, p.pid, young.cid, OATS, now + CP.feed_cooldown_s)
    assert e.code == "feed_no_effect" and e.detail["reason"] == "bonus_max"
    young.bonus = 0.0
    game.stud_list(p.pid, young.cid, now + CP.feed_cooldown_s)
    e = code_of(game.feed, p.pid, young.cid, OATS, now + CP.feed_cooldown_s)
    assert e.code == "cow_listed" and e.detail["listing_id"] == young.listed
    assert f.feeds[OATS] == 2  # 失敗都沒扣
    v = cow_view(game, p, young, now + CP.feed_cooldown_s)
    assert v["feed_block"] == "listed" and v["feed_bonus_kg"] == 0.0
    assert code_of(game._feed_index, "pizza").code == "bad_request"


def test_feed_all_feeds_calves_first_then_by_id():
    """全部餵一樣的（企劃 2.2）：份數不夠先餵小牛、再照編號；一頭都餵不到回 nothing_to_feed。"""
    game = Game(DEFAULT, "feed-all", T0)
    p = game.create_player(T0, "全部餵")
    f = p.farm
    f.coins = 1e6
    now = T0 + 60
    game.settle(p.pid, now)
    cow, starter_calf = f.cows
    late = calf(p, HOLSTEIN, now=now)
    game.buy_feed(p.pid, OATS, 2, now)
    assert game.feed_all(p.pid, "oats", now)["fed"] == [starter_calf.cid, late.cid]  # 小牛先（照編號）
    game.buy_feed(p.pid, OATS, 5, now)
    assert game.feed_all(p.pid, "oats", now)["fed"] == [cow.cid]  # 小牛吃飽了，剩成牛
    assert code_of(game.feed_all, p.pid, "oats", now).code == "nothing_to_feed"
    assert f.feeds[OATS] == 4


def test_reveal_codex_achievements_and_pairs():
    """長大揭曉（企劃第 1 節）：吃齊指定飼料的稀有小牛長成原本的品種（圖鑑、pureBreed、legend 記長大的時間），
    少吃一種變雜種牛（圖鑑 "hybrid"、不算配種表）。配種、借種生的小牛記爸媽的品種（畫面上的，雜種是 hybrid）。"""
    game = Game(DEFAULT, "reveal", T0)
    p = game.create_player(T0, "揭曉牧場")
    f = p.farm
    f.coins = 1e6
    f.slots = 20
    never_sick(p)
    now = T0 + 60
    game.settle(p.pid, now)
    sire = adult(p, STRAWBERRY, True, now)
    dam = adult(p, STRAWBERRY, False, now)
    mixed_sire = adult(p, VELVET, True, now)
    mixed_sire.vt = HYBRID  # 已經是雜種牛的公牛（基因照舊）
    dam2 = adult(p, STRAWBERRY, False, now)
    game.settle(p.pid, now)
    assert p.codex["strawberry"] == now - HOUR and p.codex["hybrid"] == now - HOUR and "velvetBlack" not in p.codex
    # 白箱：adult() 放的牛照「已經長大」記；把傳說成就清掉，只看小牛長大的那一刻
    p.ach.pop("legend", None)
    p.ach.pop("pureBreed", None)
    good = game.breed(p.pid, sire.cid, dam.cid, now)["calf"]  # 草莓 × 草莓：一定是草莓牛
    bad = game.breed(p.pid, mixed_sire.cid, dam2.cid, now + 1)["calf"]
    assert p.parents[good.cid] == [STRAWBERRY, False, STRAWBERRY, False]
    assert p.parents[bad.cid] == [VELVET, True, STRAWBERRY, False]
    assert cow_view(game, p, good, now)["breed"] is None and cow_view(game, p, good, now)["need"] == ["oats", "soy"]
    game.buy_feed(p.pid, OATS, 2, now)
    game.buy_feed(p.pid, SOY, 1, now)
    game.feed(p.pid, good.cid, OATS, now)
    game.feed(p.pid, good.cid, SOY, now + CP.calf_feed_cooldown_s)
    game.feed(p.pid, bad.cid, OATS, now + 1)
    t = max(good.adult_at, bad.adult_at) + 1
    q = game.preview(p, t)  # GET 用的複本：跟下一個動作存的一樣
    game.settle(p.pid, t)
    assert q.codex == p.codex and q.ach == p.ach and q.pairs == p.pairs
    assert good.vt == 3 and bad.vt == HYBRID
    assert p.codex["hybrid"] == now - HOUR  # 第一次發現的時間不會被後來的蓋掉
    assert p.ach["legend"] == good.adult_at == p.ach["pureBreed"]
    assert p.pairs == {"strawberry,strawberry,strawberry": [good.adult_at, 1]}  # 雜種牛不算
    assert p.parents == {}
    v = cow_view(game, p, bad, t)
    assert v["breed"] == "hybrid" and v["tier"] == bad.tier and v["hybrid"] and v["missed"] == ["soy"]
    assert v["ate"] == ["oats"] and v["stud_fee"] is None  # 母牛
    assert p.codex_count() == len([b for b in p.codex if b != "hybrid"])
    game.set_avatar(p.pid, "hybrid", t)
    assert p.avatar == "hybrid"


def test_avatar_hybrid_locked_until_found():
    game = Game(DEFAULT, "avatar", T0)
    p = game.create_player(T0, "頭像")
    e = code_of(game.set_avatar, p.pid, "hybrid", T0)
    assert e.code == "avatar_locked" and e.detail == {"breed": "hybrid"}
    assert code_of(game.set_avatar, p.pid, "mix", T0).code == "bad_request"


def test_clean_achievement_streak():
    """成就 clean：連續 7 天沒有牛生病。從開牧場起算；有牛生病就停，最後一頭病牛治好那一刻重新算。"""
    game = Game(DEFAULT, "clean", T0)
    p = game.create_player(T0, "乾淨")
    never_sick(p)
    p.farm.coins = 1e6
    cow = p.farm.cows[0]
    game.settle(p.pid, T0 + 6 * DAY)
    assert "clean" not in p.ach and p.clean_from == T0
    cow.sick_since = T0 + 6.5 * DAY  # 白箱：在 6.5 天生病
    game.settle(p.pid, T0 + 6.6 * DAY)
    assert p.clean_from is None and "clean" not in p.ach
    assert game.cure(p.pid, cow.cid, T0 + 7 * DAY)["cost"] == int(CP.cure_price)
    cow.thr = None  # 治好時重新抽了門檻：白箱讓它不再生病
    game.observe_care(p, T0 + 7 * DAY)  # 執行期在動作之後叫
    assert p.clean_from == T0 + 7 * DAY and p.ach["healer"] == T0 + 7 * DAY
    game.settle(p.pid, T0 + 13 * DAY)
    assert "clean" not in p.ach
    game.settle(p.pid, T0 + 15 * DAY)
    assert p.ach["clean"] == T0 + 14 * DAY  # 滿 7 天那一刻，不是看到的時間
    # 滿 7 天以後才生病：照樣記在滿 7 天那一刻
    q = game.create_player(T0, "乾淨二")
    never_sick(q)
    q.farm.cows[0].sick_since = T0 + 8 * DAY
    game.settle(q.pid, T0 + 9 * DAY)
    assert q.ach["clean"] == T0 + CLEAN_DAYS * DAY and q.clean_from is None


def test_sick_cows_are_blocked():
    """病牛不能配種、上架、下田；借別人生病的公牛回 bull_sick（協定 2.6 節）。出貨可以，估值只剩一成。"""
    game = Game(DEFAULT, "sick", T0)
    a = game.create_player(T0, "甲")
    b = game.create_player(T0, "乙")
    now = T0 + DAY
    for p in (a, b):
        p.farm.coins = 1e6
        p.farm.slots = 10
        never_sick(p)
        game.settle(p.pid, now)
    bull = adult(a, ANGUS, True, now)
    ox = adult(a, make_genotype(1, []), False, now)
    dam = adult(b, ANGUS, False, now)
    lst = game.stud_list(a.pid, bull.cid, now)["listing"]
    bull.sick_since = ox.sick_since = now
    assert code_of(game.field_assign, a.pid, ox.cid, None, now).code == "cow_sick"
    assert [x["code"] for x in game.stud_preview(b.pid, lst.lid, dam.cid, now)["blockers"]] == ["bull_sick"]
    e = code_of(game.stud_borrow, b.pid, lst.lid, dam.cid, now, expected_price=game.stud.price(lst, now))
    assert e.code == "bull_sick"
    dam.sick_since = now
    codes = [x["code"] for x in game.stud_preview(b.pid, lst.lid, dam.cid, now)["blockers"]]
    assert codes == ["cow_sick", "bull_sick"]
    game.stud_unlist(a.pid, lst.lid)
    assert code_of(game.stud_list, a.pid, bull.cid, now).code == "cow_sick"
    v = cow_view(game, a, bull, now)
    assert v["sick"] and v["sick_since"] == now and not v["can_breed"] and v["can_ship"]
    from server.game import ship_value

    healthy = ship_value(game, a, bull, now) / CP.sick_beef_mult
    cured = ship_value(game, a, bull, now, cured=True)  # 出貨預覽的 expected_value_cured
    bull.sick_since = None
    assert ship_value(game, a, bull, now) == pytest.approx(healthy)
    assert ship_value(game, a, bull, now) == cured


# ---------------------------------------------------------------------------
# HTTP（需要 PostgreSQL）
# ---------------------------------------------------------------------------
@pytest.fixture
def h(db_dsn):
    with Harness(db_dsn, bots=0) as hh:
        yield hh


def cow_of(st, cid):
    return next(c for c in st["cows"] if c["id"] == cid)


def test_http_feed_reveal_hybrid_milk_and_beef(h):
    """餵食、長大揭曉、雜種牛的奶和肉（協定 2.3、2.6 節）。"""
    tok = h.session()["token"]
    p = give(h, tok, coins=1_000_000, slots=20)
    game = h.server.game
    now = h.clock.now()
    game.settle(p.pid, now)
    never_sick(p)
    good = calf(p, STRAWBERRY, now=now)
    bad = calf(p, VELVET, now=now)  # 母牛：長大會產（雜種牛的）奶
    err(h.post("/v1/ranch/avatar", tok, {"breed": "hybrid", "request_id": new_rid()}), 409, "avatar_locked")
    st = state(h, tok)
    for c in (good, bad):
        v = cow_of(st, c.cid)
        assert v["breed"] is None and v["tier"] is None and v["need"] == ["oats", "soy"] and v["ate"] == []
    e = err(h.post("/v1/feed", tok, {"cow_id": good.cid, "feed": "oats", "request_id": new_rid()}), 409, "out_of_feed")
    assert e["detail"] == {"feed": "oats"}
    err(h.post("/v1/feed", tok, {"cow_id": good.cid, "feed": "pizza", "request_id": new_rid()}), 400, "bad_request")
    coins = st["coins"]
    price = st["feed_quotes"]["oats"]  # v0.3 B：現在的市價
    r = h.post("/v1/feed/buy", tok, {"feed": "oats", "qty": 3, "request_id": new_rid()}).json()
    assert 3 * price <= r["cost"] <= 3 * price * (1 + DEFAULT.feedmarket.slip_kappa) + 1  # 市價 ×（1 + 滑價）
    assert r["feeds"]["oats"] == 3 and abs(r["coins"] - (coins - r["cost"])) <= 1
    h.post("/v1/feed/buy", tok, {"feed": "soy", "qty": 1, "request_id": new_rid()})
    rid = new_rid()
    r = h.post("/v1/feed", tok, {"cow_id": good.cid, "feed": "oats", "request_id": rid}).json()
    assert r["cow"]["ate"] == ["oats"] and r["cow"]["feed_block"] == "full" and r["feeds"]["oats"] == 2
    assert r["cow"]["fed_until"] == r["server_time"] + CP.calf_feed_cooldown_s
    assert h.post("/v1/feed", tok, {"cow_id": good.cid, "feed": "oats", "request_id": rid}).json() == r  # 重送
    assert p.farm.feeds[OATS] == 2
    e = err(h.post("/v1/feed", tok, {"cow_id": good.cid, "feed": "soy", "request_id": new_rid()}), 409, "cow_full")
    assert e["detail"]["until"] == r["cow"]["fed_until"]
    h.post("/v1/feed", tok, {"cow_id": bad.cid, "feed": "oats", "request_id": new_rid()})
    starter_calf = next(c for c in p.farm.cows if c.bull and c.origin == "start")
    r = h.post("/v1/feed/all", tok, {"feed": "oats", "request_id": new_rid()}).json()
    assert r["fed"] == [starter_calf.cid] and r["feeds"]["oats"] == 0  # 吃飽的略過
    h.advance(CP.calf_feed_cooldown_s, tick=False)
    h.post("/v1/feed", tok, {"cow_id": good.cid, "feed": "soy", "request_id": new_rid()})
    # 長大揭曉：GET 不存檔，但算進去；found_at = 長大的時間
    h.advance(FP.tier_growth_h[0] * HOUR, tick=False)
    st = state(h, tok)
    g, b = cow_of(st, good.cid), cow_of(st, bad.cid)
    assert (g["breed"], g["tier"], g["hybrid"], g["missed"]) == ("strawberry", 3, False, [])
    assert (b["breed"], b["tier"], b["hybrid"], b["missed"]) == ("hybrid", 2, True, ["soy"])
    codex = {e["breed"]: e["found_at"] for e in st["codex"]}
    assert codex["strawberry"] == g["adult_at"] and codex["hybrid"] == b["adult_at"]
    ach = {a["key"]: a for a in st["achievements"]}
    assert ach["legend"]["unlocked_at"] == g["adult_at"] == ach["pureBreed"]["unlocked_at"]
    r = h.post("/v1/ranch/avatar", tok, {"breed": "hybrid", "request_id": new_rid()}).json()
    assert r["avatar"] == "hybrid" and p.codex["hybrid"] == b["adult_at"]  # 動作存下來的跟 GET 看到的一樣
    # 雜種牛的奶：bucket.hybrid、倉庫的批次 hybrid（tier 送 0）。奶桶先收空（滿了就不再產）
    h.post("/v1/collect", tok, {"request_id": new_rid()})
    h.advance(HOUR, tick=False)
    st = state(h, tok)
    assert st["bucket"]["hybrid"] > 0 and st["economy"]["hybrid_mult"] == FP.tier_mult[HYBRID]
    assert st["bucket"]["qty"] == pytest.approx(sum(st["bucket"]["by_tier"]) + st["bucket"]["hybrid"], abs=1e-5)
    r = h.post("/v1/collect", tok, {"request_id": new_rid()}).json()
    lots = r["warehouse"]["milk_lots"]
    assert any(lt["hybrid"] and lt["tier"] == 0 for lt in lots) and any(not lt["hybrid"] for lt in lots)
    pv = h.get("/v1/ship/preview", tok, cow_id=bad.cid).json()
    assert pv["hybrid"] is True and pv["sick"] is False and pv["tier"] == 2 and pv["expected_value_cured"] is None
    r = h.post("/v1/ship", tok, {"cow_id": bad.cid, "request_id": new_rid()}).json()
    assert r["beef"]["hybrid"] is True and r["beef"]["tier"] == 0
    beef = r["warehouse"]["beef_lots"][-1]
    assert beef["hybrid"] is True and beef["tier"] == 0 and beef["breed"] == "hybrid" and beef["cow_id"] == bad.cid


def test_http_poop_sick_cure_helper(h):
    """大便、清大便、生病、治療、小幫手（協定 2.6 節）。"""
    tok = h.session()["token"]
    p = give(h, tok, coins=1_000_000)
    created = p.created_at
    cow, starter_calf = p.farm.cows
    starter_calf.thr = None
    h.advance(CP.poop_every_s, tick=False)
    st = state(h, tok)
    assert st["poop"]["total"] == 2 and cow_of(st, cow.cid)["poop"] == 1 and st["poop"]["dirt"] == 1.0
    r = h.post("/v1/clean", tok, {"piles": [{"cow_id": cow.cid, "n": 5}], "request_id": new_rid()}).json()
    assert r["cleaned"] == 1 and r["poop"]["total"] == 1
    err(h.post("/v1/clean", tok, {"piles": [{"cow_id": 999, "n": 1}], "request_id": new_rid()}), 404, "cow_not_found")
    err(h.post("/v1/clean", tok, {"piles": {"1": 1}, "request_id": new_rid()}), 400, "bad_request")
    assert h.post("/v1/clean", tok, {"request_id": new_rid()}).json()["cleaned"] == 1
    e = err(h.post("/v1/cure", tok, {"cow_id": cow.cid, "request_id": new_rid()}), 409, "cow_not_sick")
    assert e["detail"] == {"cow_id": cow.cid}
    # 生病：新手保護（24 小時）一過、牧場髒就會病。白箱把門檻設得很小，病的時間 = 保護結束那一刻
    cow.h0, cow.thr = p.farm.hazard, 1e-12
    h.advance(CP.newbie_safe_s, tick=False)
    st = state(h, tok)
    v = cow_of(st, cow.cid)
    assert v["sick"] is True and v["sick_since"] == pytest.approx(created + CP.newbie_safe_s)
    assert v["milk_per_h"] >= 0 and not v["can_breed"] and st["poop"]["safe_until"] is None
    pv = h.get("/v1/ship/preview", tok, cow_id=cow.cid).json()
    assert pv["sick"] is True and pv["expected_value"] == v["ship_value"]
    assert pv["expected_value_cured"] > pv["expected_value"] / CP.sick_beef_mult * 0.9
    coins = st["coins"]
    r = h.post("/v1/cure", tok, {"cow_id": cow.cid, "request_id": new_rid()}).json()
    assert r["cost"] == int(CP.cure_price) and r["coins"] == coins - r["cost"] and r["cow"]["sick"] is False
    cured = h.get("/v1/ship/preview", tok, cow_id=cow.cid).json()  # 治好以後的估值 = 治療前預覽給的
    assert cured["sick"] is False and cured["expected_value_cured"] is None
    assert cured["expected_value"] == pv["expected_value_cured"]
    ach = {a["key"]: a for a in r["state"]["achievements"]}
    assert ach["healer"]["unlocked_at"] == r["server_time"] and ach["clean"]["unlocked_at"] is None
    # 小幫手：預付最多 7 天（含還沒到期的），雇用那一刻先清一次
    r = h.post("/v1/helper", tok, {"days": 3, "request_id": new_rid()}).json()
    assert r["cost"] == int(3 * CP.helper_price_per_day) and r["helper"]["until"] == r["server_time"] + 3 * DAY
    assert r["poop"]["total"] == 0
    e = err(h.post("/v1/helper", tok, {"days": 5, "request_id": new_rid()}), 409, "max_days")
    assert e["detail"] == {"max_days": CP.helper_max_days}
    err(h.post("/v1/helper", tok, {"days": 0, "request_id": new_rid()}), 400, "bad_request")
    give(h, tok, coins=0)
    e = err(h.post("/v1/helper", tok, {"days": 1, "request_id": new_rid()}), 409, "not_enough_coins")
    assert e["detail"] == {"need": int(CP.helper_price_per_day), "have": 0}


def test_http_floors(h):
    """地板：買斷（軟墊地）、租（青草地、乾草床）、換；到期自動換回泥土地（協定 2.6 節）。"""
    tok = h.session()["token"]
    p = give(h, tok, coins=1_000_000)
    calf_id = next(c.cid for c in p.farm.cows if c.bull)
    err(h.post("/v1/floor/buy", tok, {"floor": "meadow", "request_id": new_rid()}), 400, "bad_request")
    r = h.post("/v1/floor/buy", tok, {"floor": "cushion", "request_id": new_rid()}).json()
    assert r["cost"] == int(CP.floor_price[3]) and r["floors"]["owned"] == ["dirt", "cushion"]
    err(h.post("/v1/floor/buy", tok, {"floor": "cushion", "request_id": new_rid()}), 409, "floor_owned")
    e = err(h.post("/v1/floor/use", tok, {"floor": "hay_bed", "request_id": new_rid()}), 409, "floor_locked")
    assert e["detail"] == {"floor": "hay_bed"}
    r = h.post("/v1/floor/rent", tok, {"floor": "meadow", "days": 2, "request_id": new_rid()}).json()
    assert r["cost"] == int(2 * CP.floor_rent_per_day[2]) and r["until"] == r["server_time"] + 2 * DAY
    assert r["floors"] == {
        "current": "dirt",
        "owned": ["dirt", "cushion"],
        "rented": "meadow",
        "rent_until": r["until"],
    }  # 租了不會自動換上
    e = err(
        h.post("/v1/floor/rent", tok, {"floor": "hay_bed", "days": 1, "request_id": new_rid()}), 409, "floor_rented"
    )
    assert e["detail"] == {"floor": "meadow", "until": r["until"]}
    err(h.post("/v1/floor/rent", tok, {"floor": "meadow", "days": 6, "request_id": new_rid()}), 409, "max_days")
    before = cow_of(state(h, tok), calf_id)["adult_at"]
    r = h.post("/v1/floor/use", tok, {"floor": "meadow", "request_id": new_rid()}).json()
    assert r["floors"]["current"] == "meadow"
    after = cow_of(r["state"], calf_id)["adult_at"]
    assert r["server_time"] < after < before  # 長得快：小牛提早長大（年紀不跳）
    h.advance(2 * DAY + 1, tick=False)
    assert state(h, tok)["floor"] == {
        "current": "dirt",
        "owned": ["dirt", "cushion"],
        "rented": None,
        "rent_until": None,
    }
    r = h.post("/v1/floor/use", tok, {"floor": "cushion", "request_id": new_rid()}).json()
    assert r["floors"]["current"] == "cushion"


def test_http_robot(h):
    """大便掃地機（協定 2.6 節）：買、在動時看不到什麼時候壞、壞了才給 broken_at、修理、換款、錯誤碼。"""
    tok = h.session()["token"]
    p = give(h, tok, coins=100_000)
    err(h.post("/v1/robot/repair", tok, {"request_id": new_rid()}), 409, "no_robot")
    err(h.post("/v1/robot/buy", tok, {"model": "turbo", "request_id": new_rid()}), 400, "bad_request")
    h.advance(CP.poop_every_s, tick=False)
    assert state(h, tok)["poop"]["total"] == 2
    rid = new_rid()
    r = h.post("/v1/robot/buy", tok, {"model": "basic", "request_id": rid}).json()
    assert r["model"] == "basic" and r["cost"] == int(CP.robot_price[0]) and r["coins"] == 100_000 - r["cost"]
    assert r["robot"] == {"model": "basic", "working": True, "since": r["server_time"], "broken_at": None}
    assert r["poop"]["total"] == 0  # 買來那一刻先清一次
    assert h.post("/v1/robot/buy", tok, {"model": "basic", "request_id": rid}).json() == r  # 重送只扣一次
    e = err(h.post("/v1/robot/buy", tok, {"model": "basic", "request_id": new_rid()}), 409, "robot_owned")
    assert e["detail"] == {"model": "basic"}
    e = err(h.post("/v1/robot/repair", tok, {"request_id": new_rid()}), 409, "robot_working")
    assert e["detail"] == {"model": "basic"}
    until = p.farm.robot_until  # 白箱：抽好的壞掉時間（玩家看不到）
    assert until > r["server_time"]
    h.advance(until - h.clock.now() + CP.poop_every_s, tick=False)
    st = state(h, tok)
    assert st["robot"] == {"model": "basic", "working": False, "since": r["server_time"], "broken_at": until}
    give(h, tok, coins=0)
    err(h.post("/v1/robot/repair", tok, {"request_id": new_rid()}), 409, "not_enough_coins")
    give(h, tok, coins=10_000)
    r2 = h.post("/v1/robot/repair", tok, {"request_id": new_rid()}).json()
    assert r2["cost"] == int(CP.robot_repair[0]) and r2["coins"] == 10_000 - r2["cost"]
    assert r2["robot"]["working"] and r2["robot"]["since"] == r2["server_time"] and r2["poop"]["total"] == 0
    r3 = h.post("/v1/robot/buy", tok, {"model": "sturdy", "request_id": new_rid()})
    err(r3, 409, "not_enough_coins")
    give(h, tok, coins=20_000)
    r3 = h.post("/v1/robot/buy", tok, {"model": "sturdy", "request_id": new_rid()}).json()  # 換款，舊的不退錢
    assert r3["robot"]["model"] == "sturdy" and r3["coins"] == 20_000 - int(CP.robot_price[1])
