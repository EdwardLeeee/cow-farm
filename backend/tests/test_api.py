"""HTTP／WebSocket 協定測試（需要 PostgreSQL）：欄位、request_id 防重送、各種錯誤、牛肉倉庫、排行榜。

時間用手動時鐘（conftest.Harness），不會真的等。
"""

from __future__ import annotations

import pytest
from starlette.websockets import WebSocketDisconnect

from conftest import Harness, new_rid


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


def milk_total(h, tok):
    return h.get("/v1/state", tok).json()["warehouse"]["milk_total"]


def sell_all_milk(h, tok):
    h.post("/v1/collect", tok, {"request_id": new_rid()})
    q = milk_total(h, tok)
    if q > 0:
        r = h.post("/v1/sell", tok, {"commodity": "milk", "qty": q, "request_id": new_rid()})
        assert r.status_code == 200, r.text


# ---------------------------------------------------------------------------
def test_session_and_state_fields(h):
    s = h.session()
    assert s["created"] is True and s["token"] and isinstance(s["player_id"], int)
    assert s["ranch_name"] and len(s["ranch_name"]) >= 6
    st = h.get("/v1/state", s["token"]).json()
    for k in ("server_time", "real_time", "time_scale", "coins", "level", "cows", "bucket", "warehouse", "pen", "upgrades", "shop", "codex"):
        assert k in st, k
    assert st["coins"] == 100 and isinstance(st["coins"], int)
    assert st["shop"]["calf_price"] == {"dairy": 1000, "dual": 1000, "beef": 1000}
    assert st["bucket"]["per_hour"] == pytest.approx(55.0)  # 乳牛 11 瓶／時 × 新手期 5 倍
    assert st["pen"]["next_open_at"] == st["server_time"] + 15 * 60
    cows = {c["id"]: c for c in st["cows"]}
    assert len(cows) == 2
    for c in cows.values():
        for k in ("id", "type", "bull", "tier", "stage", "adult_at", "ready_at", "milk_per_h", "weight_kg", "ship_value"):
            assert k in c, k
    calf = next(c for c in cows.values() if c["bull"])
    assert calf["stage"] == "calf" and calf["type"] == "dual" and calf["adult_at"] == st["server_time"] + 20 * 60
    assert {"type": "dairy", "tier": next(c for c in cows.values() if not c["bull"])["tier"]} in st["codex"]


def test_unauthorized_and_validation_errors(h):
    err(h.client.get("/v1/state"), 401, "unauthorized")
    err(h.get("/v1/state", "not-a-token"), 401, "unauthorized")
    tok = h.session()["token"]
    e = err(h.post("/v1/buy_calf", tok, {"type": "cat", "bull": "yes", "request_id": new_rid()}), 400, "bad_request")
    assert set(e["detail"]["fields"]) == {"type", "bull"}
    err(h.post("/v1/collect", tok, {}), 400, "bad_request")  # 缺 request_id
    err(h.post("/v1/collect", tok, {"request_id": "abc"}), 400, "bad_request")
    err(h.post("/v1/sell", tok, {"commodity": "milk", "qty": "5", "request_id": new_rid()}), 400, "bad_request")
    err(h.post("/v1/sell", tok, {"commodity": "milk", "qty": True, "request_id": new_rid()}), 400, "bad_request")
    err(h.post("/v1/sell", tok, {"commodity": "milk", "qty": -1, "request_id": new_rid()}), 400, "bad_request")
    err(h.post("/v1/ship", tok, {"cow_id": "1", "request_id": new_rid()}), 400, "bad_request")
    err(h.client.get("/v1/nope"), 404, "not_found")


def test_collect_quote_sell(h):
    tok = h.session()["token"]
    r = h.post("/v1/collect", tok, {"request_id": new_rid()})
    assert r.status_code == 200
    body = r.json()
    assert body["collected"] == pytest.approx(20.0) and body["warehouse"]["milk_total"] == pytest.approx(20.0)
    assert body["bucket"]["qty"] == 0 and body["state"]["coins"] == 100
    q = h.post("/v1/sell/quote", tok, {"commodity": "milk", "qty": 20}).json()
    assert q["qty"] == 20 and q["total"] > 150 and q["avg_price"] < q["market_price"]
    assert milk_total(h, tok) == pytest.approx(20.0)  # 試算不改狀態
    s = h.post("/v1/sell", tok, {"commodity": "milk", "qty": 20, "request_id": new_rid()}).json()
    assert s["total"] == q["total"] and s["coins"] == 100 + s["total"]
    assert s["price_after"] == s["market_price"] and s["next_unit_price"] < s["market_price"]
    assert s["state"]["warehouse"]["milk_total"] == 0
    err(h.post("/v1/sell", tok, {"commodity": "milk", "qty": 1, "request_id": new_rid()}), 409, "not_enough_stock")
    err(h.post("/v1/sell/quote", tok, {"commodity": "beef", "qty": 1}), 409, "not_enough_stock")


def test_partial_sell_leaves_rest(h):
    tok = h.session()["token"]
    h.post("/v1/collect", tok, {"request_id": new_rid()})
    h.post("/v1/sell", tok, {"commodity": "milk", "qty": 7.5, "request_id": new_rid()})
    assert milk_total(h, tok) == pytest.approx(12.5)
    e = err(h.post("/v1/sell", tok, {"commodity": "milk", "qty": 13, "request_id": new_rid()}), 409, "not_enough_stock")
    assert e["detail"]["have"] == pytest.approx(12.5)


def test_request_id_replay(h):
    tok = h.session()["token"]
    h.post("/v1/collect", tok, {"request_id": new_rid()})
    rid = new_rid()
    a = h.post("/v1/sell", tok, {"commodity": "milk", "qty": 10, "request_id": rid})
    h.advance(120)  # 時間過了、價格變了，重送還是拿到第一次的結果
    b = h.post("/v1/sell", tok, {"commodity": "milk", "qty": 10, "request_id": rid})
    assert a.status_code == b.status_code == 200
    assert a.json() == b.json()
    st = h.get("/v1/state", tok).json()
    assert st["coins"] == a.json()["coins"]  # 只成交一次
    assert st["warehouse"]["milk_total"] == pytest.approx(10.0)
    trades = h.client.portal.call(_count_trades, h, st["player_id"])
    assert trades == 1
    # 同一個 request_id 拿去做別的動作
    err(h.post("/v1/collect", tok, {"request_id": rid}), 409, "request_id_reused")
    # 失敗的請求不會被記住：同一個 request_id 之後條件滿足了會成功
    rid2 = new_rid()
    err(h.post("/v1/upgrade", tok, {"kind": "pen", "request_id": rid2}), 409, "not_yet_available")
    h.advance(15 * 60)
    sell_all_milk(h, tok)  # 湊到 280 幣
    ok = h.post("/v1/upgrade", tok, {"kind": "pen", "request_id": rid2})
    assert ok.status_code == 200, ok.text
    # request_id 以玩家為範圍：別人用同一個 UUID 不受影響
    tok2 = h.session()["token"]
    assert h.post("/v1/collect", tok2, {"request_id": rid}).status_code == 200


async def _count_trades(h, pid):
    async with h.server.store.pool.acquire() as conn:
        return await conn.fetchval("SELECT count(*) FROM trades WHERE player_id=$1", pid)


def test_not_enough_coins(h):
    tok = h.session()["token"]
    e = err(h.post("/v1/upgrade", tok, {"kind": "fresh", "request_id": new_rid()}), 409, "not_enough_coins")
    assert e["detail"] == {"need": 1500, "have": 100}
    # 空出一格再買小牛：100 幣不夠 1000
    st = h.get("/v1/state", tok).json()
    cow = next(c for c in st["cows"] if not c["bull"])
    assert h.post("/v1/ship", tok, {"cow_id": cow["id"], "request_id": new_rid()}).status_code == 200
    err(h.post("/v1/buy_calf", tok, {"type": "dairy", "bull": False, "request_id": new_rid()}), 409, "not_enough_coins")
    assert h.get("/v1/state", tok).json()["coins"] == 100


def test_pen_full_and_first_expand(h):
    tok = h.session()["token"]
    err(h.post("/v1/buy_calf", tok, {"type": "beef", "bull": True, "request_id": new_rid()}), 409, "pen_full")
    e = err(h.post("/v1/upgrade", tok, {"kind": "pen", "request_id": new_rid()}), 409, "not_yet_available")
    assert e["detail"]["open_at"] == h.get("/v1/state", tok).json()["pen"]["next_open_at"]


def test_cow_not_found(h):
    tok = h.session()["token"]
    err(h.post("/v1/ship", tok, {"cow_id": 999, "request_id": new_rid()}), 404, "cow_not_found")
    err(h.post("/v1/breed", tok, {"sire": 999, "dam": 1, "request_id": new_rid()}), 404, "cow_not_found")
    err(h.get("/v1/breed/preview", tok, sire=2, dam=999), 404, "cow_not_found")
    # 別人的牛也是「不存在」
    other = h.session()
    mine = h.get("/v1/state", tok).json()["cows"][0]["id"]
    assert h.get("/v1/state", other["token"]).json()["player_id"] != h.get("/v1/state", tok).json()["player_id"]
    st_other = h.get("/v1/state", other["token"]).json()
    assert all(c["id"] in (1, 2) for c in st_other["cows"]) and mine in (1, 2)  # id 是各牧場自己的編號


def test_breed_flow_and_cooldown(h):
    tok = h.session()["token"]
    st = h.get("/v1/state", tok).json()
    bull = next(c for c in st["cows"] if c["bull"])
    cow = next(c for c in st["cows"] if not c["bull"])
    err(h.post("/v1/ship", tok, {"cow_id": bull["id"], "request_id": new_rid()}), 409, "cow_not_adult")
    err(h.post("/v1/breed", tok, {"sire": cow["id"], "dam": bull["id"], "request_id": new_rid()}), 400, "invalid_pair")
    e = err(h.post("/v1/breed", tok, {"sire": bull["id"], "dam": cow["id"], "request_id": new_rid()}), 409, "cow_not_adult")
    assert e["detail"]["until"] == bull["adult_at"]
    sell_all_milk(h, tok)  # 100 + 約 200 幣 → 夠第一次擴建 280
    h.advance(20 * 60)
    sell_all_milk(h, tok)
    assert h.post("/v1/upgrade", tok, {"kind": "pen", "request_id": new_rid()}).status_code == 200
    pv = h.get("/v1/breed/preview", tok, sire=bull["id"], dam=cow["id"]).json()
    assert pv["can_breed"] and pv["fee"] == 0 and pv["first_free"] and pv["normal_fee"] == 300
    assert sum(pv["tier_probs"]) == pytest.approx(1.0) and sum(pv["type_probs"].values()) == pytest.approx(1.0)
    r = h.post("/v1/breed", tok, {"sire": bull["id"], "dam": cow["id"], "request_id": new_rid()})
    assert r.status_code == 200, r.text
    b = r.json()
    now = b["server_time"]
    assert b["calf"]["stage"] == "calf" and b["calf"]["adult_at"] > now and b["fee"] == 0
    assert b["sire"]["ready_at"] == pytest.approx(now + 2 * 3600) and b["dam"]["ready_at"] == pytest.approx(now + 24 * 3600)
    e = err(h.post("/v1/breed", tok, {"sire": bull["id"], "dam": cow["id"], "request_id": new_rid()}), 409, "breed_cooldown")
    assert e["detail"]["until"] == pytest.approx(now + 2 * 3600)
    pv2 = h.get("/v1/breed/preview", tok, sire=bull["id"], dam=cow["id"]).json()
    assert not pv2["can_breed"] and {x["code"] for x in pv2["blockers"]} >= {"breed_cooldown", "pen_full"}
    assert pv2["fee"] == 300  # 第一次免費用掉了


def test_ship_to_warehouse_then_sell_beef(h):
    tok = h.session()["token"]
    st = h.get("/v1/state", tok).json()
    cow = next(c for c in st["cows"] if not c["bull"])
    h.advance(3600)
    est = next(c for c in h.get("/v1/state", tok).json()["cows"] if c["id"] == cow["id"])["ship_value"]
    r = h.post("/v1/ship", tok, {"cow_id": cow["id"], "request_id": new_rid()}).json()
    kg = r["beef"]["qty"]
    assert kg > 30 and r["beef"]["value_estimate"] == pytest.approx(est, abs=2)
    st = r["state"]
    assert all(c["id"] != cow["id"] for c in st["cows"])
    assert st["warehouse"]["beef_total"] == pytest.approx(kg) and st["warehouse"]["used"] == 0  # 牛肉不佔牛奶倉庫
    coins0 = st["coins"]
    s = h.post("/v1/sell", tok, {"commodity": "beef", "qty": kg / 2, "request_id": new_rid()}).json()
    assert s["coins"] == coins0 + s["total"] and s["state"]["warehouse"]["beef_total"] == pytest.approx(kg / 2)
    # 放久了會衰減（原型規則：24 小時後開始降，最低 6 成）
    h.advance(24 * 3600, tick=False)
    lot = h.get("/v1/state", tok).json()["warehouse"]["beef_lots"][0]
    assert lot["storage_factor"] == pytest.approx(1.0)
    h.advance(96 * 3600 + 3600, tick=False)
    lot = h.get("/v1/state", tok).json()["warehouse"]["beef_lots"][0]
    assert lot["storage_factor"] == pytest.approx(0.6)


def test_market_history_and_news(h):
    tok = h.session()["token"]
    h.advance(3 * 3600)
    m = h.get("/v1/market", tok).json()
    for cid in ("milk", "beef"):
        q = m[cid]
        for k in ("price", "change_24h", "ma24", "history"):
            assert k in q
        assert len(q["history"]) >= 30 and q["history"][-1][0] <= m["server_time"]
    assert m["tick_t"] == m["server_time"]
    for rng, step in (("1h", 60), ("1d", 300), ("7d", 1800)):
        r = h.get("/v1/market/history", tok, commodity="milk", range=rng).json()
        assert r["step_s"] == step and r["points"]
    err(h.get("/v1/market/history", tok, commodity="gold", range="1h"), 400, "bad_request")


def test_leaderboard_marks_bots(h):
    tok = h.session()["token"]
    h.advance(3600)
    for kind in ("networth", "collection", "weekly"):
        lb = h.get("/v1/leaderboard", tok, kind=kind).json()
        assert lb["kind"] == kind and lb["total"] == 4
        bots = [e for e in lb["entries"] if e["is_bot"]]
        assert len(bots) == 3 and all(e["name"].startswith("電腦") for e in bots)
        assert [e["rank"] for e in lb["entries"]] == [1, 2, 3, 4]
        me = lb["me"]
        assert me["is_me"] and not me["is_bot"] and not me["name"].startswith("電腦")
        assert sum(e["is_me"] for e in lb["entries"]) == 1


def test_websocket_push_and_auth(h):
    tok = h.session()["token"]
    with h.client.websocket_connect(f"/v1/ws?token={tok}") as ws:
        hello = ws.receive_json()
        assert hello["type"] == "hello" and hello["protocol"] == 1
        m = ws.receive_json()
        assert m["type"] == "market" and set(m["milk"]) >= {"price", "change_24h", "ma24"} and "server_time" in m
    with h.client.websocket_connect("/v1/ws", subprotocols=["cowfarm.v1", f"cowfarm.token.{tok}"]) as ws:
        assert ws.receive_json()["type"] == "hello"
    with h.client.websocket_connect("/v1/ws?token=bad") as ws:
        e = ws.receive_json()
        assert e["type"] == "error" and e["error"]["code"] == "unauthorized"
        with pytest.raises(WebSocketDisconnect) as exc:
            ws.receive_json()
        assert exc.value.code == 4401


def test_news_pushed_over_websocket(h):
    tok = h.session()["token"]
    with h.client.websocket_connect(f"/v1/ws?token={tok}") as ws:
        ws.receive_json()
        ws.receive_json()
        h.advance(86400)  # 平均每天 3 則新聞
        assert h.server.news_log, "這個 seed 第一天應該有新聞"
        n = ws.receive_json()
        while n["type"] != "news":
            n = ws.receive_json()
        for k in ("id", "title", "commodity", "direction", "time", "start_at", "end_at", "state"):
            assert k in n
        assert n["direction"] in ("up", "down")
    ids = {x["id"] for x in h.get("/v1/market", tok).json()["news"]}
    assert n["id"] in ids


def test_client_time_is_ignored(h):
    """用戶端送時間欄位也沒用：伺服器只看自己的遊戲時鐘。"""
    tok = h.session()["token"]
    r = h.post("/v1/collect", tok, {"request_id": new_rid(), "server_time": 9e12, "now": 9e12, "time": 9e12})
    assert r.status_code == 200
    assert r.json()["collected"] == pytest.approx(20.0)
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
