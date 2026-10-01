"""丟棄式 spike：PyJWT + cryptography 能不能照 Apple、Google 文件的步驟驗 token、簽 client secret、加密 refresh token。

跑法（在 backend/ 下，需要網路抓 Apple、Google 的公鑰）：
  .venv/bin/pip install pyjwt==2.15.1 cryptography==50.0.2
  .venv/bin/python ../docs/research/sso/sso_spike.py > ../docs/research/sso/result-<日期>.json
只用自己產生的金鑰模擬 token，沒有用到真的 Apple、Google 帳號或金鑰。
"""

import base64
import hashlib
import json
import os
import platform
import statistics
import sys
import time

import jwt
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from jwt import PyJWKClient

out = {}
# 1. 真的 Apple JWKS：PyJWKClient 拿得到、每把都是 RS256
t = time.perf_counter()
apple = PyJWKClient("https://appleid.apple.com/auth/keys", cache_keys=True, lifespan=3600)
keys = apple.get_jwk_set().keys
out["apple_jwks"] = {
    "n": len(keys),
    "algs": sorted({k.algorithm_name for k in keys}),
    "ms": round((time.perf_counter() - t) * 1000),
}
t = time.perf_counter()
google = PyJWKClient("https://www.googleapis.com/oauth2/v3/certs", cache_keys=True, lifespan=3600)
gk = google.get_jwk_set().keys
out["google_jwks"] = {
    "n": len(gk),
    "algs": sorted({k.algorithm_name for k in gk}),
    "ms": round((time.perf_counter() - t) * 1000),
}

# 2. 模擬：自己的 RSA 金鑰簽一張「像 Apple 的」identity token，照文件的 5 個步驟驗
priv = rsa.generate_private_key(public_exponent=65537, key_size=2048)
now = int(time.time())
nonce = base64.urlsafe_b64encode(os.urandom(24)).decode().rstrip("=")
claims = {
    "iss": "https://appleid.apple.com",
    "aud": "com.oraclelee.cowfarm",
    "sub": "001234.abcd.5678",
    "iat": now,
    "exp": now + 600,
    "nonce": hashlib.sha256(nonce.encode()).hexdigest(),
    "nonce_supported": True,
    "email": "x@privaterelay.appleid.com",
}
tok = jwt.encode(claims, priv, algorithm="RS256", headers={"kid": "TEST"})
got = jwt.decode(
    tok,
    priv.public_key(),
    algorithms=["RS256"],
    audience="com.oraclelee.cowfarm",
    issuer="https://appleid.apple.com",
    options={"require": ["exp", "iat", "sub", "aud", "iss"]},
)
out["apple_like_ok"] = got["sub"] == claims["sub"] and got["nonce"] == hashlib.sha256(nonce.encode()).hexdigest()
for name, bad in (("wrong_aud", dict(audience="other.app")), ("wrong_iss", dict(issuer="https://evil"))):
    try:
        jwt.decode(
            tok,
            priv.public_key(),
            algorithms=["RS256"],
            **{"audience": "com.oraclelee.cowfarm", "issuer": "https://appleid.apple.com", **bad},
        )
        out[name] = "沒擋住"
    except jwt.InvalidTokenError as e:
        out[name] = type(e).__name__
expired = jwt.encode({**claims, "exp": now - 10}, priv, algorithm="RS256")
try:
    jwt.decode(
        expired,
        priv.public_key(),
        algorithms=["RS256"],
        audience="com.oraclelee.cowfarm",
        issuer="https://appleid.apple.com",
    )
    out["expired"] = "沒擋住"
except jwt.ExpiredSignatureError as e:
    out["expired"] = type(e).__name__
none_alg = jwt.encode(claims, None, algorithm="none")  # alg=none 的偽造 token
try:
    jwt.decode(
        none_alg,
        priv.public_key(),
        algorithms=["RS256"],
        audience="com.oraclelee.cowfarm",
        issuer="https://appleid.apple.com",
    )
    out["alg_none"] = "沒擋住"
except jwt.InvalidTokenError as e:
    out["alg_none"] = type(e).__name__
# Google 的 iss 有兩種寫法
g = jwt.encode(
    {**claims, "iss": "accounts.google.com", "aud": "WEB_CLIENT_ID.apps.googleusercontent.com"}, priv, algorithm="RS256"
)
out["google_iss_list"] = jwt.decode(
    g,
    priv.public_key(),
    algorithms=["RS256"],
    audience="WEB_CLIENT_ID.apps.googleusercontent.com",
    issuer=["accounts.google.com", "https://accounts.google.com"],
)["iss"]

# 3. Apple 的 client secret：P-256 金鑰（.p8 的格式）用 ES256 簽，最長 6 個月
p8 = ec.generate_private_key(ec.SECP256R1())
secret = jwt.encode(
    {
        "iss": "TEAMID1234",
        "iat": now,
        "exp": now + 15777000,
        "aud": "https://appleid.apple.com",
        "sub": "com.oraclelee.cowfarm",
    },
    p8,
    algorithm="ES256",
    headers={"kid": "KEYID12345"},
)
hdr = jwt.get_unverified_header(secret)
out["client_secret"] = {
    "alg": hdr["alg"],
    "kid": hdr["kid"],
    "len": len(secret),
    "verifies": jwt.decode(secret, p8.public_key(), algorithms=["ES256"], audience="https://appleid.apple.com")["sub"],
}

# 4. refresh token 加密保存（Fernet：AES-128-CBC + HMAC-SHA256，金鑰從環境變數讀）
key = Fernet.generate_key()
f = Fernet(key)
enc = f.encrypt(b"rca7...lABoQ")
out["fernet"] = {"roundtrip": f.decrypt(enc) == b"rca7...lABoQ", "cipher_len": len(enc)}

# 5. 驗一張 token 要多久（RS256 驗簽＋欄位檢查；公鑰已經在記憶體）
pub = priv.public_key()
ts = []
for _ in range(1000):
    t = time.perf_counter()
    jwt.decode(tok, pub, algorithms=["RS256"], audience="com.oraclelee.cowfarm", issuer="https://appleid.apple.com")
    ts.append((time.perf_counter() - t) * 1e6)
ts.sort()
out["decode_us"] = {"n": 1000, "median": round(statistics.median(ts)), "p99": round(ts[989]), "max": round(ts[-1])}
out["env"] = {"python": sys.version.split()[0], "machine": platform.machine(), "pyjwt": jwt.__version__}
print(json.dumps(out, ensure_ascii=False, indent=1))
