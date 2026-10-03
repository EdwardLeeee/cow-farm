"""帳號：備份、找回、換回、刪除牧場（協定第 5 節；需要 PostgreSQL）。驗證器和 Apple 用假的（tests/fakes.py）。

驗收（brief 3.7）：綁定、解除、找回、換回、刪除都有測試；資料庫沒有 email 和姓名；舊手機的 token 失效後收到 401（WebSocket 4401）。
刪除是軟刪除（ceo 2026-10-02 的條件）：空殼只留編號和時間，任何地方都找不到他的名字、帳號識別碼、token 雜湊。
"""

from __future__ import annotations

import asyncio

import pytest
from starlette.websockets import WebSocketDisconnect

from conftest import Harness, new_rid
from server.game import GameError
from cowecon import DEFAULT
from fakes import FakeApple, fake_services, fake_token

OB = DEFAULT.onboarding

EMAIL = "someone.secret@example.com"
NAME = "王小明測試"


@pytest.fixture
def env(db_dsn):
    apple = FakeApple()
    with Harness(db_dsn, bots=1, accounts=fake_services(apple)) as h:
        yield h, apple


def nonce(h) -> str:
    r = h.client.post("/v1/account/nonce")
    assert r.status_code == 200, r.text
    return r.json()["nonce"]


def link(h, tok, provider, sub, code="code1", **extra):
    n = nonce(h)
    body = {"provider": provider, "id_token": fake_token(sub, n, email=EMAIL, name=NAME), "nonce": n, **extra}
    if provider == "apple" and code is not None:
        body["authorization_code"] = code
    return h.post("/v1/account/link", tok, body)


def recover(h, provider, sub, **extra):
    n = nonce(h)
    return h.client.post(
        "/v1/account/recover", json={"provider": provider, "id_token": fake_token(sub, n), "nonce": n, **extra}
    )


def err(r, status, code):
    assert r.status_code == status, r.text
    e = r.json()["error"]
    assert e["code"] == code, e
    return e


def state(h, tok):
    return h.get("/v1/state", tok).json()


def q(h, sql, *args):
    async def go():
        async with h.server.store.pool.acquire() as conn:
            return await conn.fetch(sql, *args)

    return h.client.portal.call(go)


def db_text(h) -> str:
    """整個資料庫（遊戲資料的表）轉成文字，用來確認某些字串不存在。"""
    out = []
    for t in (
        "players",
        "farms",
        "account_links",
        "revoked_tokens",
        "processed_requests",
        "session_requests",
        "stud_log",
        "meta",
        "apple_revoke_queue",
    ):
        out += [str(dict(r)) for r in q(h, f"SELECT * FROM {t}")]
    return "\n".join(out)


def test_nonce_is_required_and_single_use(env):
    h, _apple = env
    tok = h.session()["token"]
    n = nonce(h)
    body = {"provider": "google", "id_token": fake_token("g-1", n), "nonce": n}
    assert h.post("/v1/account/link", tok, body).status_code == 200
    e = err(h.post("/v1/account/link", tok, body), 400, "sign_in_failed")  # 同一個 nonce 再用一次
    assert e["detail"] == {"reason": "nonce_invalid"}
    n2 = nonce(h)
    bad = {"provider": "google", "id_token": fake_token("g-1", "other"), "nonce": n2}  # token 裡的 nonce 對不上
    assert err(h.post("/v1/account/link", tok, bad), 400, "sign_in_failed")["detail"]["reason"] == "nonce_invalid"
    import hashlib

    n3 = nonce(h)  # token 裡放 SHA-256 的也算對（有些套件會先雜湊）
    hashed = {"provider": "google", "id_token": fake_token("g-1", hashlib.sha256(n3.encode()).hexdigest()), "nonce": n3}
    assert h.post("/v1/account/link", tok, hashed).status_code == 200
    n4 = nonce(h)  # 沒有 nonce 的 token：只有 Apple 不支援 nonce 的平台可以
    assert err(
        h.post("/v1/account/link", tok, {"provider": "google", "id_token": fake_token("g-1"), "nonce": n4}),
        400,
        "sign_in_failed",
    )["detail"] == {"reason": "nonce_invalid"}
    n5 = nonce(h)
    expired = {"provider": "google", "id_token": fake_token("g-1", n5, expired=True), "nonce": n5}
    assert err(h.post("/v1/account/link", tok, expired), 400, "sign_in_failed")["detail"] == {"reason": "token_expired"}


def test_link_google_and_apple_store_no_email(env):
    h, apple = env
    s = h.session()
    tok = s["token"]
    r = link(h, tok, "google", "g-100")
    assert r.status_code == 200, r.text
    assert [x["provider"] for x in r.json()["account"]["links"]] == ["google"]
    assert link(h, tok, "google", "g-100").status_code == 200  # 已經綁在這個牧場：200
    e = err(link(h, tok, "apple", "a-100", code=None), 400, "bad_request")  # Apple 要 authorization_code
    assert e["detail"]["fields"] == ["authorization_code"]
    assert err(link(h, tok, "apple", "a-100", code="bad"), 400, "sign_in_failed")["detail"] == {
        "reason": "code_invalid"
    }
    r = link(h, tok, "apple", "a-100", code="code-a")
    assert r.status_code == 200, r.text
    assert apple.exchanged == ["code-a"]
    links = state(h, tok)["account"]["links"]
    assert [x["provider"] for x in links] == ["apple", "google"] and all(x["linked_at_real"] > 0 for x in links)
    # 一個牧場每種帳號只能綁一個
    err(link(h, tok, "google", "g-200"), 409, "provider_already_linked")
    # 資料庫：存帳號識別碼；Apple 的 refresh token 是加密的；沒有 email、姓名、原本的 token
    rows = {r["provider"]: r for r in q(h, "SELECT * FROM account_links WHERE player_id=$1", s["player_id"])}
    assert rows["google"]["subject"] == "g-100" and rows["google"]["apple_refresh_enc"] is None
    enc = bytes(rows["apple"]["apple_refresh_enc"])
    assert b"refresh-code-a" not in enc and h.server.accounts.cipher.decrypt(enc) == "refresh-code-a"
    text = db_text(h)
    assert EMAIL not in text and NAME not in text and "refresh-code-a" not in text and "fake." not in text


def test_account_in_use_then_switch(env):
    h, _apple = env
    a = h.session("備份過的牧場")
    b = h.session("新手機的牧場")
    assert link(h, a["token"], "google", "g-300").status_code == 200
    e = err(link(h, b["token"], "google", "g-300"), 409, "account_in_use")
    d = e["detail"]
    assert d["provider"] == "google" and d["ranch"] == {
        "player_id": a["player_id"],
        "name": "備份過的牧場",
        "name_words": None,
        "is_bot": False,
        "level": 1,
        "avatar": None,  # S21：沒選過頭像
    }
    rid = new_rid()
    body = {"switch_ticket": d["switch_ticket"], "request_id": rid}
    r1 = h.post("/v1/account/switch", b["token"], body)
    assert r1.status_code == 200, r1.text
    sw = r1.json()
    assert sw["player_id"] == a["player_id"] and sw["created"] is False and sw["state"]["ranch_name"] == "備份過的牧場"
    assert h.post("/v1/account/switch", b["token"], body).json() == sw  # 回應掉了重送：同一個回應（不是 401）
    err(h.get("/v1/state", b["token"]), 401, "unauthorized")  # 這支手機原本的牧場已經刪除
    err(h.get("/v1/state", a["token"]), 401, "signed_in_elsewhere")  # 那個牧場原本的手機
    assert state(h, sw["token"])["player_id"] == a["player_id"]
    e = err(h.post("/v1/account/switch", sw["token"], {"switch_ticket": d["switch_ticket"]}), 400, "sign_in_failed")
    assert e["detail"]["reason"] == "ticket_invalid"  # 憑單只能用一次
    lb = h.get("/v1/leaderboard", sw["token"], kind="networth").json()
    assert b["player_id"] not in {x["ranch"]["player_id"] for x in lb["entries"]}  # 刪掉的牧場不在排行榜


def test_recover_signs_out_old_phone(env):
    h, _apple = env
    a = h.session("找回測試牧場")
    assert link(h, a["token"], "google", "g-400").status_code == 200
    err(recover(h, "google", "g-nobody"), 404, "account_not_linked")
    with h.client.websocket_connect(f"/v1/ws?token={a['token']}") as ws:
        ws.receive_json()  # hello
        ws.receive_json()  # market
        n = nonce(h)
        first = {"provider": "google", "id_token": fake_token("g-400", n), "nonce": n, "request_id": new_rid()}
        r1 = h.client.post("/v1/account/recover", json=first)
        assert r1.status_code == 200, r1.text
        rec = r1.json()
        assert rec["player_id"] == a["player_id"] and rec["state"]["ranch_name"] == "找回測試牧場"
        # 舊手機開著的連線：先送 signed_in_elsewhere 再 4401
        m = ws.receive_json()
        assert m["type"] == "error" and m["error"]["code"] == "signed_in_elsewhere"
        with pytest.raises(WebSocketDisconnect) as exc:
            ws.receive_json()
        assert exc.value.code == 4401
    err(h.get("/v1/state", a["token"]), 401, "signed_in_elsewhere")
    with h.client.websocket_connect(f"/v1/ws?token={a['token']}") as ws:
        assert ws.receive_json()["error"]["code"] == "signed_in_elsewhere"
        with pytest.raises(WebSocketDisconnect) as exc:
            ws.receive_json()
        assert exc.value.code == 4401
    # 網路逾時重送：整個請求原封不動，拿到第一次的回應（nonce 雖然已經用掉，這是重送）
    assert h.client.post("/v1/account/recover", json=first).json() == rec
    # 再找回一次（新的 request_id）：發新 token，上一支也登出
    rec2 = recover(h, "google", "g-400").json()
    assert rec2["token"] != rec["token"]
    err(h.get("/v1/state", rec["token"]), 401, "signed_in_elsewhere")
    assert state(h, rec2["token"])["player_id"] == a["player_id"]


def test_recover_replay_needs_the_same_id_token(env):
    """找回的重送要 request_id 和 id_token 都一樣（ceo 2026-10-02 審查）：只拿到 request_id 的人，
    亂寫 id_token 或用自己的帳號，都拿不到上一次回應裡的 token，照一般找回處理。"""
    h, _apple = env
    a = h.session()
    assert link(h, a["token"], "google", "g-410").status_code == 200
    rid = new_rid()
    first = recover(h, "google", "g-410", request_id=rid)
    assert first.status_code == 200, first.text
    forged = {"provider": "google", "id_token": "garbage", "nonce": nonce(h), "request_id": rid}
    r = h.client.post("/v1/account/recover", json=forged)
    assert err(r, 400, "sign_in_failed")["detail"]["reason"] == "token_invalid" and "token" not in r.json()
    err(recover(h, "google", "g-nobody", request_id=rid), 404, "account_not_linked")
    assert state(h, first.json()["token"])["player_id"] == a["player_id"]  # 第一次拿到的 token 沒被換掉


def test_unlink_revokes_apple(env):
    h, apple = env
    tok = h.session()["token"]
    assert link(h, tok, "apple", "a-500", code="c5").status_code == 200
    r = h.post("/v1/account/unlink", tok, {"provider": "apple"})
    assert r.status_code == 200 and r.json()["account"] == {"links": []}
    h.client.portal.call(h.server.process_revocations)
    assert apple.revoked == ["refresh-c5"] and not q(h, "SELECT * FROM apple_revoke_queue")
    err(h.post("/v1/account/unlink", tok, {"provider": "apple"}), 404, "not_linked")
    err(recover(h, "apple", "a-500"), 404, "account_not_linked")  # 解除後就不能用這個帳號找回


def test_delete_is_soft_and_leaves_no_personal_data(env):
    h, apple = env
    a = h.session(NAME + "的牧場")
    b = h.session("借方牧場")
    pid = a["player_id"]
    assert link(h, a["token"], "apple", "a-600", code="c6").status_code == 200
    assert link(h, a["token"], "google", "g-600").status_code == 200
    # 先在「另一支手機」找回一次：原本的 token 變成 signed_in_elsewhere
    old_token = a["token"]
    a = {**a, "token": recover(h, "google", "g-600").json()["token"]}
    err(h.get("/v1/state", old_token), 401, "signed_in_elsewhere")
    # 先留一些跟他有關的東西：上架、別人跟他借種、request_id 記錄
    h.advance(OB.starter_calf_remaining_s)
    bull = next(c for c in state(h, a["token"])["cows"] if c["bull"])
    lst = h.post("/v1/stud/list", a["token"], {"cow_id": bull["id"], "request_id": new_rid()}).json()["listing"]
    h.server.game.players[b["player_id"]].farm.coins = 1e6
    h.server.game.players[b["player_id"]].farm.slots = 10
    dam = next(c for c in state(h, b["token"])["cows"] if not c["bull"])
    borrow = {"listing_id": lst["id"], "dam": dam["id"], "price": lst["fee"]["price"], "request_id": new_rid()}
    assert h.post("/v1/stud/borrow", b["token"], borrow).status_code == 200
    assert h.post("/v1/collect", a["token"], {"request_id": new_rid()}).status_code == 200
    milk = state(h, a["token"])["warehouse"]["milk_total"]
    sold = h.post("/v1/sell", a["token"], {"commodity": "milk", "qty": milk, "request_id": new_rid()})
    assert sold.status_code == 200, sold.text
    n_before = h.get("/v1/leaderboard", b["token"], kind="networth").json()["total"]
    # 刪除（帶 request_id）；回應掉了重送拿到同一個回應，不是 401
    rid = new_rid()
    r = h.post("/v1/account/delete", a["token"], {"request_id": rid})
    assert r.status_code == 200 and r.json()["deleted"] is True
    assert h.post("/v1/account/delete", a["token"], {"request_id": rid}).json() == r.json()
    err(h.get("/v1/state", a["token"]), 401, "unauthorized")
    err(h.post("/v1/account/delete", a["token"], {}), 401, "unauthorized")
    err(h.get("/v1/state", old_token), 401, "unauthorized")  # 牧場刪了，更早那支手機也改回 unauthorized（5.7 節）
    # 空殼：只有編號和時間
    row = q(h, "SELECT * FROM players WHERE id=$1", pid)[0]
    assert row["ranch_name"] == "" and row["token_sha256"] is None and row["deleted_at"] is not None
    for t in ("farms", "account_links", "revoked_tokens", "processed_requests", "session_requests"):
        assert not q(h, f"SELECT 1 FROM {t} WHERE player_id=$1", pid), t
    assert not q(h, "SELECT 1 FROM stud_log WHERE lender_id=$1 OR borrower_id=$1", pid)
    text = db_text(h)
    assert NAME not in text and "a-600" not in text and "g-600" not in text and EMAIL not in text
    # 設計如此：市場的成交紀錄留著（行情重算要用），連到的是只有編號的空殼，沒有個資
    assert q(h, "SELECT 1 FROM trades WHERE player_id=$1", pid)
    # 任何畫面都看不到他：排行榜、借種市場；別人的借種紀錄顯示「已刪除的牧場」
    lb = h.get("/v1/leaderboard", b["token"], kind="networth").json()
    assert lb["total"] == n_before - 1 and pid not in {x["ranch"]["player_id"] for x in lb["entries"]}
    assert all(x["owner"]["player_id"] != pid for x in h.get("/v1/stud", b["token"]).json()["listings"])
    log = h.get("/v1/stud/log", b["token"]).json()["entries"]
    assert [e["ranch"] for e in log] == [None]
    # Apple 撤銷
    h.client.portal.call(h.server.process_revocations)
    assert apple.revoked == ["refresh-c6"] and not q(h, "SELECT * FROM apple_revoke_queue")
    # 同一個 Apple 帳號可以再綁新的牧場
    c = h.session("新的牧場")
    assert link(h, c["token"], "apple", "a-600", code="c7").status_code == 200


def test_revocation_queue_runs_one_at_a_time(env):
    """撤銷佇列同時被叫好幾次（解除、刪除後的背景那份＋定期那份）：同一筆只向 Apple 撤銷一次。
    直接放進佇列（不經過解除），才不會被背景那份先處理掉、測不到同時跑的情況。"""
    h, apple = env
    h.client.portal.call(h.server.store.enqueue_revocation, h.server.accounts.cipher.encrypt("refresh-c51"))

    async def three_at_once():
        return await asyncio.gather(*(h.server.process_revocations() for _ in range(3)))

    assert sorted(h.client.portal.call(three_at_once)) == [0, 0, 1]
    assert apple.revoked == ["refresh-c51"] and not q(h, "SELECT * FROM apple_revoke_queue")


def test_revocation_retries(env):
    h, apple = env
    tok = h.session()["token"]
    assert link(h, tok, "apple", "a-700", code="c8").status_code == 200
    apple.fail_revoke = True
    assert h.post("/v1/account/delete", tok, {}).json()["deleted"] is True  # Apple 連不上也照樣刪除（TN3194）
    assert h.client.portal.call(h.server.process_revocations) == 0
    row = q(h, "SELECT attempts, last_error FROM apple_revoke_queue")[0]
    assert row["attempts"] == 1 and "503" in row["last_error"]
    apple.fail_revoke = False
    assert h.client.portal.call(h.server.process_revocations) == 0  # 還沒到重試時間
    q(h, "UPDATE apple_revoke_queue SET next_try_at = now()")
    assert h.client.portal.call(h.server.process_revocations) == 1
    assert apple.revoked == ["refresh-c8"] and not q(h, "SELECT * FROM apple_revoke_queue")


def test_delete_without_body(env):
    """有些 HTTP 用戶端 POST 時完全不帶本文：刪除照樣成功（不是 400）。"""
    h, _apple = env
    tok = h.session()["token"]
    r = h.client.post("/v1/account/delete", headers=h.auth(tok))
    assert r.status_code == 200 and r.json()["deleted"] is True, r.text
    err(h.get("/v1/state", tok), 401, "unauthorized")


def test_action_queued_during_delete_is_unauthorized(env):
    """動作驗過 token、還在排隊等鎖時牧場被刪掉：回 401 unauthorized（協定 5.6），
    不是協定錯誤碼表沒有的 player_not_found（404）。直接呼叫 run_action 模擬排在刪除後面的那個動作。"""
    h, _apple = env
    a = h.session()
    assert h.post("/v1/account/delete", a["token"], {}).status_code == 200
    with pytest.raises(GameError) as e:
        h.client.portal.call(h.server.run_action, a["player_id"], lambda now: None, new_rid(), "collect")
    assert (e.value.code, e.value.status) == ("unauthorized", 401)


def test_reads_racing_a_delete_are_unauthorized(env):
    """GET 驗過 token、還沒處理就被刪掉牧場（FastAPI 在執行緒裡跑 token 檢查，中間插得進刪除）：
    回 401 unauthorized（協定 5.6），不是 500 internal。用「驗完 token 就把牧場拿掉」的 auth 模擬。"""
    h, _apple = env
    a = h.session()
    cow = state(h, a["token"])["cows"][0]["id"]
    real_auth, gone = h.server.auth, {}

    def auth_then_deleted(token):
        p = real_auth(token)
        gone[p.pid] = h.server.game.players.pop(p.pid)
        return p

    h.server.auth = auth_then_deleted
    try:
        for path, params in (("/v1/state", {}), ("/v1/shop", {}), ("/v1/ship/preview", {"cow_id": cow})):
            r = h.get(path, a["token"], **params)
            h.server.game.players.update(gone)  # 放回去，下一個請求的 token 檢查才過得了
            err(r, 401, "unauthorized")
    finally:
        h.server.auth = real_auth
        h.server.game.players.update(gone)


def test_deleted_ids_are_not_reused(db_dsn):
    """軟刪除的編號不會被新牧場重複使用，重開伺服器也一樣（#1234 不會一下是 A、一下是 B）。"""
    with Harness(db_dsn, accounts=fake_services()) as h:
        s = h.session("最後一個")
        assert h.post("/v1/account/delete", s["token"], {}).json()["deleted"] is True
        deleted = s["player_id"]
    with Harness(db_dsn, accounts=fake_services()) as h:
        assert h.session("重開後的新牧場")["player_id"] > deleted
        assert deleted not in h.server.game.players


def test_not_configured_server(db_dsn):
    """還沒設定 Apple／Google 的伺服器（M4 以前）：綁定、找回回 not_configured，其他照常。"""

    with Harness(db_dsn) as h:
        tok = h.session()["token"]
        n = nonce(h)
        body = {"provider": "google", "id_token": fake_token("g", n), "nonce": n}
        assert err(h.post("/v1/account/link", tok, body), 400, "sign_in_failed")["detail"] == {
            "reason": "not_configured"
        }
        n = nonce(h)
        r = h.client.post("/v1/account/recover", json={"provider": "apple", "id_token": "x", "nonce": n})
        assert err(r, 400, "sign_in_failed")["detail"] == {"reason": "not_configured"}
        assert h.get("/v1/state", tok).json()["account"] == {"links": []}
