"""S21 牧場資料（D34）：改名、換頭像、成就（協定 1.6、2.3、2.5 節；server/achievements.py）。"""

from __future__ import annotations

from conftest import T0, Harness, new_rid
from cowecon import DEFAULT, Cow
from cowecon.farm import make_genotype
from server import achievements as A
from server.breeds import ALL as ALL_BREEDS
from server.game import Game, Player, week_id, week_start
from test_api import OB, err, give, state

FP = DEFAULT.farm


def ach(st, key):
    return next(a for a in st["achievements"] if a["key"] == key)


def rename(h, tok, name, rid=None):
    return h.post("/v1/ranch/rename", tok, {"name": name, "request_id": rid or new_rid()})


def test_rename_first_free_then_paid_and_survives_restart(db_dsn):
    with Harness(db_dsn) as h:
        s = h.session("小花的快樂牧場")
        tok, pid = s["token"], s["player_id"]
        st = state(h, tok)
        assert st["profile"] == {"avatar": None, "renames": 0}
        assert st["economy"]["rename_price"] == A.RENAME_PRICE
        coins0 = st["coins"]
        r = rename(h, tok, "  新的牧場  ").json()  # 第一次免費；前後空白照 D23 去掉
        assert (r["name"], r["cost"], r["coins"]) == ("新的牧場", 0, coins0)
        assert r["profile"] == {"avatar": None, "renames": 1} and r["state"]["ranch_name"] == "新的牧場"
        assert err(rename(h, tok, "x"), 400, "invalid_name")["detail"]["reason"] == "too_short"
        err(h.post("/v1/ranch/rename", tok, {"name": 3, "request_id": new_rid()}), 400, "bad_request")
        give(h, tok, coins=A.RENAME_PRICE - 1)
        e = err(rename(h, tok, "第三個名字"), 409, "not_enough_coins")
        assert e["detail"] == {"need": A.RENAME_PRICE, "have": A.RENAME_PRICE - 1}
        assert state(h, tok)["ranch_name"] == "新的牧場"  # 錢不夠：什麼都沒改
        give(h, tok, coins=5000)
        rid = new_rid()
        r1, r2 = rename(h, tok, "第三個名字", rid).json(), rename(h, tok, "第三個名字", rid).json()
        assert r1 == r2 and r1["cost"] == A.RENAME_PRICE  # 同一個 request_id 重送：只改一次、只扣一次錢
        st = state(h, tok)
        assert st["coins"] == 5000 - A.RENAME_PRICE and st["profile"]["renames"] == 2
        assert h.get("/v1/leaderboard", tok, kind="networth").json()["me"]["ranch"]["name"] == "第三個名字"
    with Harness(db_dsn) as h:  # 重開伺服器：名字從 players 表讀回來，不會變回舊的
        p = h.server.game.players[pid]
        assert (p.name, p.renames) == ("第三個名字", 2)


def test_avatar_only_discovered_breeds(db_dsn):
    with Harness(db_dsn, bots=2) as h:
        tok = h.session()["token"]
        found = sorted(c["breed"] for c in state(h, tok)["codex"])
        locked = next(b for b in ALL_BREEDS if b not in found)
        e = err(h.post("/v1/ranch/avatar", tok, {"breed": locked, "request_id": new_rid()}), 409, "avatar_locked")
        assert e["detail"] == {"breed": locked}
        err(h.post("/v1/ranch/avatar", tok, {"breed": "unicorn", "request_id": new_rid()}), 400, "bad_request")
        assert state(h, tok)["profile"]["avatar"] is None
        r = h.post("/v1/ranch/avatar", tok, {"breed": found[0], "request_id": new_rid()}).json()
        assert r["avatar"] == found[0] and r["profile"] == {"avatar": found[0], "renames": 0}
        lb = h.get("/v1/leaderboard", tok, kind="networth").json()
        assert lb["me"]["ranch"]["avatar"] == found[0]
        bots = [x["ranch"] for x in lb["entries"] if x["ranch"]["is_bot"]]
        assert bots and all(r["avatar"] is None for r in bots)  # 電腦牧場沒有頭像


def test_achievements_shape_and_unlocks_from_actions(db_dsn):
    with Harness(db_dsn) as h:
        a, b = h.session("甲牧場")["token"], h.session("乙牧場")["token"]
        st = state(h, a)
        assert [x["key"] for x in st["achievements"]] == [k for k, _ in A.ACHIEVEMENTS]
        for x, (key, goal) in zip(st["achievements"], A.ACHIEVEMENTS):
            if isinstance(goal, tuple):
                assert set(x) == {"key", "progress", "tiers"} and [t["goal"] for t in x["tiers"]] == list(goal)
            elif isinstance(goal, int):
                assert set(x) == {"key", "unlocked_at", "progress", "goal"} and x["goal"] == goal
            else:
                assert set(x) == {"key", "unlocked_at"}
            assert x.get("unlocked_at") is None
        assert ach(st, "codex")["progress"] == len(st["codex"])
        h.advance(OB.starter_calf_remaining_s)
        now = h.clock.now()
        assert h.post("/v1/collect", a, {"request_id": new_rid()}).json()["collected"] > 0
        q = state(h, a)["warehouse"]["milk_total"]
        assert h.post("/v1/sell", a, {"commodity": "milk", "qty": q, "request_id": new_rid()}).status_code == 200
        st = state(h, a)
        assert ach(st, "firstMilk")["unlocked_at"] == now and ach(st, "firstSale")["unlocked_at"] == now
        # 借種：借的人 borrow、newLife；公牛的主人 popularBull 加 1
        sb = state(h, b)
        bull = next(c for c in sb["cows"] if c["bull"])
        lst = h.post("/v1/stud/list", b, {"cow_id": bull["id"], "request_id": new_rid()}).json()["listing"]
        give(h, a, coins=10_000, slots=10)
        dam = next(c for c in state(h, a)["cows"] if not c["bull"])
        body = {"listing_id": lst["id"], "dam": dam["id"], "price": lst["fee"]["price"], "request_id": new_rid()}
        assert h.post("/v1/stud/borrow", a, body).status_code == 200
        st = state(h, a)
        assert ach(st, "borrow")["unlocked_at"] == now and ach(st, "newLife")["unlocked_at"] == now
        pop = ach(state(h, b), "popularBull")
        assert pop["progress"] == 1 and pop["unlocked_at"] is None
        # 出貨：firstShip；評到 A 才算 gradeA
        ox = next(c for c in st["cows"] if c["bull"])
        r = h.post("/v1/ship", a, {"cow_id": ox["id"], "request_id": new_rid()}).json()
        st = state(h, a)
        assert ach(st, "firstShip")["unlocked_at"] == now
        assert ach(st, "gradeA")["progress"] == (1 if r["grade"] == "A" else 0)
        # 等級、總資產：做動作之後檢查（S21 以前就達標的記成那個時間）
        p = h.server.game.players[st["player_id"]]
        p.earned = 300_000  # Lv 10 以上
        give(h, a, coins=150_000)
        h.post("/v1/collect", a, {"request_id": new_rid()})
        st = state(h, a)
        assert [t["unlocked_at"] for t in ach(st, "level")["tiers"]] == [now, None]
        assert [t["unlocked_at"] for t in ach(st, "rich")["tiers"]] == [now, None]
        assert ach(st, "level")["progress"] == p.level() and ach(st, "rich")["progress"] >= 150_000
        for key in A.NOT_YET:
            assert ach(st, key)["unlocked_at"] is None


def test_rice_codex_and_legend_rules():
    """服務層：稻米累計到 1,000 公斤解鎖；圖鑑每一階的時間 = 第 N 種被發現的時間；擁有傳說牛。"""
    game = Game(DEFAULT, "ach-unit", T0)
    p = game.create_player(T0, "單元牧場")
    p.count("rice", 600.0, T0 + 1)
    assert "rice" not in p.ach and p.ach_n["rice"] == 600.0
    p.count("rice", 450.0, T0 + 2)
    assert p.ach["rice"] == T0 + 2
    p.codex = {b: T0 + i * 100.0 for i, b in enumerate(ALL_BREEDS[:12])}
    from server.views import achievements_view

    codex = next(x for x in achievements_view(game, p, T0 + 5000) if x["key"] == "codex")
    assert codex["progress"] == 12
    assert [t["unlocked_at"] for t in codex["tiers"]] == [T0 + 400.0, T0 + 1100.0, None]
    legend = Cow(99, make_genotype(2, [(1, 1), (1, 1), (1, 1)]), False, T0, FP)
    assert legend.tier == 3
    p.add_codex(legend, T0 + 7)
    assert p.ach["legend"] == T0 + 7


def test_week_champion_includes_income_earned_before_the_week_closes():
    """週冠軍：週一 00:00 結算上一週的第 1 名。上一週的收入就算新的一週先有收入（week_earned 歸零）也還記得；
    伺服器關著跨過好幾週，回來時一週一週補算。"""
    w = week_id(T0) + 1
    game = Game(DEFAULT, "weeks", T0)
    a, b = game.create_player(T0, "甲"), game.create_player(T0, "乙")
    t = week_start(w) - 3600.0
    assert game.close_weeks(t) and game.champ_week == w - 1  # 第一次只記從這一週開始
    a.add_income(300, t)
    b.add_income(500, t)  # 上一週 b 第 1
    t2 = week_start(w) + 60.0
    b.add_income(100, t2)  # 新的一週先有收入（week_earned 歸零）：b 上一週的 500 要記得，冠軍還是 b
    a.add_income(1000, t2)
    assert game.close_weeks(t2)
    assert game.week_champs == {w - 1: b.pid} and game.week_champ_at(b.pid) == week_start(w)
    assert game.week_champ_at(a.pid) is None
    assert game.close_weeks(week_start(w + 3) + 1.0)  # 伺服器關了三週：w 是 a，之後兩週沒人有收入
    assert game.week_champs == {w - 1: b.pid, w: a.pid, w + 1: None, w + 2: None}
    assert not game.close_weeks(week_start(w + 3) + 2.0)  # 同一週不重算


def test_week_champions_saved_and_shown(db_dsn):
    """週冠軍存在 meta、重開伺服器讀回來；state 的 weekChamp 是那一週結束的時間。"""
    w = week_id(T0) + 1
    t0 = week_start(w) - 30 * 60.0  # 週日 23:30
    with Harness(db_dsn, t0=t0) as h:
        s = h.session("週冠軍牧場")
        tok, pid = s["token"], s["player_id"]
        h.advance(60)  # 第一個 tick：從這一週開始結算
        h.server.game.players[pid].add_income(800, h.clock.now())
        h.advance(40 * 60)  # 跨過週一 00:00
        assert h.server.game.week_champs == {w - 1: pid}
        assert ach(state(h, tok), "weekChamp")["unlocked_at"] == week_start(w)
    with Harness(db_dsn, t0=t0) as h:
        assert h.server.game.week_champs == {w - 1: pid} and h.server.game.champ_week == w
        assert ach(state(h, tok), "weekChamp")["unlocked_at"] == week_start(w)


def test_tailwind_needs_super_event(db_dsn):
    """在那種商品的超級大事件期間賣出：tailwind（D33 的新聞等級；+100% 是超級大事件）。"""
    with Harness(db_dsn) as h:
        tok = h.session()["token"]
        h.advance(60)
        now = h.clock.now()
        h.server.game.ex.inject_event(("beef",), 2.0, now, 4 * 3600.0)  # 牛肉的超級大事件
        h.post("/v1/collect", tok, {"request_id": new_rid()})
        q = state(h, tok)["warehouse"]["milk_total"]
        h.post("/v1/sell", tok, {"commodity": "milk", "qty": q, "request_id": new_rid()})
        assert ach(state(h, tok), "tailwind")["unlocked_at"] is None  # 牛奶不在超級大事件裡
        h.server.game.ex.inject_event(("milk",), 2.0, now, 4 * 3600.0)
        h.advance(60)  # 再產一點奶來賣
        now = h.clock.now()
        h.post("/v1/collect", tok, {"request_id": new_rid()})
        q = state(h, tok)["warehouse"]["milk_total"]
        assert q > 0
        h.post("/v1/sell", tok, {"commodity": "milk", "qty": q, "request_id": new_rid()})
        assert ach(state(h, tok), "tailwind")["unlocked_at"] == now


def test_old_save_without_profile_loads():
    """S21 以前的存檔沒有 avatar、renames、ach、ach_n、prev_week：照預設讀進來；新的存了再讀一樣。"""
    game = Game(DEFAULT, "old-save", T0)
    p = game.create_player(T0, "舊牧場")
    p.avatar, p.renames = "holstein", 2
    p.unlock("firstMilk", T0 + 5)
    p.count("rice", 12.5, T0 + 6)
    p.prev_week, p.prev_week_earned = 7, 120.0
    new = p.state_dict()
    back = Player.from_state(DEFAULT, p.pid, p.name, False, T0, new)
    assert back.state_dict() == new
    old = {
        k: v for k, v in new.items() if k not in ("avatar", "renames", "ach", "ach_n", "prev_week", "prev_week_earned")
    }
    q = Player.from_state(DEFAULT, p.pid, p.name, False, T0, old)
    assert (q.avatar, q.renames, q.ach, q.ach_n, q.prev_week, q.prev_week_earned) == (None, 0, {}, {}, None, 0.0)
