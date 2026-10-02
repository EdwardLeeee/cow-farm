"""帳號零件的單元測試（不需要資料庫、不連網路）：真的驗證程式用自己產生的金鑰和假的公鑰清單，
呼叫 Apple 的程式用 httpx 的假傳輸層（協定第 5 節；docs/research/2026-10-sso-verification.md）。"""

from __future__ import annotations

import hashlib
import os
import stat
import time
import urllib.parse

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa

from server.accounts import (
    APPLE_ISSUER,
    AppleRestClient,
    JwksVerifier,
    NonceBook,
    RevokeError,
    SignInError,
    SwitchTicket,
    TicketBook,
    TokenCipher,
    nonce_matches,
)

APP_ID = "com.oraclelee.cowfarm"
WEB_ID = "1234-web.apps.googleusercontent.com"
KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)


class FakeJWKClient:
    """代替 PyJWKClient：不管 kid，都給同一把公鑰（真的 PyJWKClient 會照 kid 挑）。"""

    def __init__(self, public_key):
        self.public_key = public_key

    def get_signing_key_from_jwt(self, token):
        class K:
            key = self.public_key

        return K()


def verifier():
    pub = KEY.public_key()
    return JwksVerifier([APP_ID], [WEB_ID], jwk_clients={"apple": FakeJWKClient(pub), "google": FakeJWKClient(pub)})


def token(**over):
    now = int(time.time())
    claims = {"iss": APPLE_ISSUER, "aud": APP_ID, "sub": "001234.abc", "iat": now, "exp": now + 600, "nonce": "n1"}
    claims.update(over)
    return jwt.encode({k: v for k, v in claims.items() if v is not None}, KEY, algorithm="RS256", headers={"kid": "K1"})


def reason(fn):
    with pytest.raises(SignInError) as e:
        fn()
    return e.value.reason


def test_jwks_verifier_follows_official_checks():
    v = verifier()
    ident = v.verify("apple", token(email="x@privaterelay.appleid.com"))
    assert (ident.provider, ident.subject, ident.nonce, ident.nonce_required) == ("apple", "001234.abc", "n1", True)
    assert reason(lambda: v.verify("apple", token(aud="other.app"))) == "token_invalid"  # aud 不是我們的
    assert reason(lambda: v.verify("apple", token(iss="https://evil.example"))) == "token_invalid"
    assert reason(lambda: v.verify("apple", token(exp=int(time.time()) - 120))) == "token_expired"
    assert reason(lambda: v.verify("apple", token(sub=None))) == "token_invalid"  # 一定要有 sub
    assert reason(lambda: v.verify("apple", "not-a-jwt")) == "token_invalid"
    forged = jwt.encode(
        {"iss": APPLE_ISSUER, "aud": APP_ID, "sub": "x", "exp": int(time.time()) + 60}, None, algorithm="none"
    )
    assert reason(lambda: v.verify("apple", forged)) == "token_invalid"  # alg=none
    # 拿公鑰當 HS256 的密碼（演算法混淆）也擋得住：只接受 RS256
    pem = KEY.public_key().public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo)
    try:
        hs = jwt.encode(
            {"iss": APPLE_ISSUER, "aud": APP_ID, "sub": "x", "exp": int(time.time()) + 60}, pem, algorithm="HS256"
        )
    except jwt.InvalidKeyError:
        hs = None  # 新版 PyJWT 直接拒絕用 PEM 當 HMAC 密碼
    if hs is not None:
        assert reason(lambda: v.verify("apple", hs)) == "token_invalid"
    # Apple：nonce_supported 是 false 的平台，nonce 可以沒有
    assert v.verify("apple", token(nonce=None, nonce_supported=False)).nonce_required is False


def test_google_issuers_and_audience():
    v = verifier()
    for iss in ("accounts.google.com", "https://accounts.google.com"):
        assert v.verify("google", token(iss=iss, aud=WEB_ID)).subject == "001234.abc"
    assert reason(lambda: v.verify("google", token(iss="accounts.google.com", aud=APP_ID))) == "token_invalid"
    assert reason(lambda: v.verify("google", token(iss=APPLE_ISSUER, aud=WEB_ID))) == "token_invalid"


def test_not_configured():
    v = JwksVerifier()
    assert not v.configured("apple") and not v.configured("google")
    assert reason(lambda: v.verify("apple", token())) == "not_configured"
    assert reason(lambda: verifier().verify("facebook", token())) == "not_configured"


def test_apple_rest_client_requests():
    p8 = ec.generate_private_key(ec.SECP256R1())
    pem = p8.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())
    seen = []

    def handler(request: httpx.Request) -> httpx.Response:
        form = dict(urllib.parse.parse_qsl(request.content.decode()))
        seen.append((str(request.url), form))
        if request.url.path == "/auth/token":
            if form["code"] == "used":
                return httpx.Response(400, json={"error": "invalid_grant"})
            return httpx.Response(
                200, json={"access_token": "a", "refresh_token": "r-" + form["code"], "id_token": "i"}
            )
        if form["token"] == "down":
            return httpx.Response(503)
        return httpx.Response(200)

    c = AppleRestClient("TEAMID1234", "KEYID12345", APP_ID, pem.decode(), transport=httpx.MockTransport(handler))
    assert c.configured()
    assert c.exchange_code("c1") == "r-c1"
    url, form = seen[-1]
    assert url == "https://appleid.apple.com/auth/token"
    assert form["grant_type"] == "authorization_code" and form["client_id"] == APP_ID and form["code"] == "c1"
    # client secret：ES256、kid、iss = Team ID、sub = client_id、aud = Apple、最多 1 小時
    secret = form["client_secret"]
    assert jwt.get_unverified_header(secret) == {"alg": "ES256", "kid": "KEYID12345", "typ": "JWT"}
    claims = jwt.decode(secret, p8.public_key(), algorithms=["ES256"], audience=APPLE_ISSUER)
    assert claims["iss"] == "TEAMID1234" and claims["sub"] == APP_ID and claims["exp"] - claims["iat"] == 3600
    assert reason(lambda: c.exchange_code("used")) == "code_invalid"
    c.revoke("r-c1")
    url, form = seen[-1]
    assert url == "https://appleid.apple.com/auth/revoke"
    assert form["token"] == "r-c1" and form["token_type_hint"] == "refresh_token" and form["client_id"] == APP_ID
    with pytest.raises(RevokeError):
        c.revoke("down")


def test_token_cipher_key_file(tmp_path):
    path = tmp_path / "keys" / "token.key"
    c = TokenCipher.from_file(path)
    assert stat.S_IMODE(os.stat(path).st_mode) == 0o600  # 照 secrets-custody：只有自己能讀
    blob = c.encrypt("rca7...lABoQ")
    assert b"rca7" not in blob and c.decrypt(blob) == "rca7...lABoQ"
    assert TokenCipher.from_file(path).decrypt(blob) == "rca7...lABoQ"  # 重開以後用同一把金鑰
    with pytest.raises(RevokeError):
        c.decrypt(b"garbage")


def test_nonce_rules():
    book = NonceBook()
    n, exp = book.issue(now=1000.0)
    assert exp == 1000.0 + 600 and len(n) >= 32
    assert book.consume(n, now=1001.0) and not book.consume(n, now=1002.0)  # 只能用一次
    n2, _ = book.issue(now=1000.0)
    assert not book.consume(n2, now=1000.0 + 601)  # 過期
    assert not book.consume(None) and not book.consume("never-issued")
    assert nonce_matches("abc", "abc") and nonce_matches(hashlib.sha256(b"abc").hexdigest(), "abc")
    assert not nonce_matches(None, "abc") and not nonce_matches("abd", "abc")


def test_switch_tickets():
    book = TicketBook()
    code, exp = book.issue(SwitchTicket(1, 2, "apple", "s"), now=1000.0)
    assert book.take(code, now=1001.0)[0] == "ok"
    assert book.take(code, now=1002.0) == ("missing", None)  # 只能用一次
    code2, _ = book.issue(SwitchTicket(1, 2, "apple", "s"), now=1000.0)
    assert book.take(code2, now=1000.0 + 601) == ("expired", None)
    assert book.take(None) == ("missing", None)
