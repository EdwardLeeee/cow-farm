"""帳號：綁定 Apple／Google、找回、換回、刪除牧場要用的零件（協定第 5 節；研究在 docs/research/2026-10-sso-verification.md）。

- Verifier：驗 Apple identity token、Google ID token（簽章、iss、aud、exp），只取帳號識別碼 sub 和 nonce。
  真的用 JwksVerifier（Apple、Google 的公鑰清單，快取一小時）；測試用假的。
- AppleClient：用 authorization code 換 refresh token（/auth/token）、撤銷（/auth/revoke）。client secret 是用 .p8 金鑰
  現簽的 ES256 JWT。真的用 AppleRestClient（httpx）；測試用假的。
- TokenCipher：Apple 的 refresh token 加密保存（Fernet）；金鑰是一個檔案（權限 600，不進 git）。
- NonceBook、TicketBook、ReplayBook：nonce、換回憑單、帳號端點的 request_id 重送記錄。都只放記憶體，10 分鐘有效，
  伺服器重開就沒有（重送記錄裡有新的登入憑證，不寫進資料庫）。

這裡的程式不碰遊戲狀態；呼叫網路的（驗證要抓公鑰、呼叫 Apple）都是同步函式，runtime 用 asyncio.to_thread 呼叫。
日誌不寫 token、authorization code、refresh token、nonce。
"""

from __future__ import annotations

import base64
import hashlib
import os
import secrets
import time
from collections import OrderedDict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Optional, Protocol, Sequence, Tuple

import httpx
import jwt
from cryptography.fernet import Fernet, InvalidToken

PROVIDERS = ("apple", "google")
APPLE_ISSUER = "https://appleid.apple.com"
APPLE_JWKS = "https://appleid.apple.com/auth/keys"
GOOGLE_ISSUERS = ("accounts.google.com", "https://accounts.google.com")
GOOGLE_JWKS = "https://www.googleapis.com/oauth2/v3/certs"
SHORT_TTL_S = 600.0  # nonce、換回憑單、重送記錄的有效時間（現實秒數）


class SignInError(Exception):
    """登入憑證驗證不過；reason 是協定 5.2 節的 sign_in_failed reason。"""

    def __init__(self, reason: str):
        super().__init__(reason)
        self.reason = reason


class RevokeError(Exception):
    """Apple 撤銷失敗（之後重試）。"""


@dataclass(frozen=True)
class Identity:
    provider: str
    subject: str  # sub：Apple／Google 給的帳號識別碼
    nonce: Optional[str]  # token 裡的 nonce（沒有就是 None）
    nonce_required: bool  # Apple 的 nonce_supported 是 false 時，nonce 可以沒有


# ---------------------------------------------------------------------------
# 驗證登入憑證
# ---------------------------------------------------------------------------
class Verifier(Protocol):
    def configured(self, provider: str) -> bool: ...

    def verify(self, provider: str, id_token: str) -> Identity: ...


class JwksVerifier:
    """照官方文件驗：RS256 簽章（公鑰清單裡 kid 對得上的那把）、iss、aud（我們的 client ID）、exp。

    Apple 文件寫「JWS E256」，但 Apple 的 OpenID 設定和公鑰都是 RS256，以設定為準（研究文件 1.1 節）。
    只接受 RS256，不讓 token 自己指定演算法。
    """

    def __init__(
        self,
        apple_client_ids: Sequence[str] = (),
        google_client_ids: Sequence[str] = (),
        jwk_clients: Optional[Dict[str, Any]] = None,
        leeway_s: float = 30.0,
    ):
        self.audiences = {"apple": tuple(apple_client_ids), "google": tuple(google_client_ids)}
        self.issuers = {"apple": (APPLE_ISSUER,), "google": GOOGLE_ISSUERS}
        self.leeway_s = leeway_s
        self._clients = dict(jwk_clients or {})

    def configured(self, provider: str) -> bool:
        return bool(self.audiences.get(provider))

    def _client(self, provider: str):
        c = self._clients.get(provider)
        if c is None:
            url = APPLE_JWKS if provider == "apple" else GOOGLE_JWKS
            c = jwt.PyJWKClient(url, cache_keys=True, lifespan=3600)
            self._clients[provider] = c
        return c

    def verify(self, provider: str, id_token: str) -> Identity:
        if provider not in PROVIDERS or not self.configured(provider):
            raise SignInError("not_configured")
        if not isinstance(id_token, str) or not id_token:
            raise SignInError("token_invalid")
        try:
            key = self._client(provider).get_signing_key_from_jwt(id_token)
            claims = jwt.decode(
                id_token,
                key.key,
                algorithms=["RS256"],
                audience=list(self.audiences[provider]),
                issuer=list(self.issuers[provider]),
                leeway=self.leeway_s,
                options={"require": ["exp", "iat", "sub", "aud", "iss"]},
            )
        except jwt.ExpiredSignatureError:
            raise SignInError("token_expired") from None
        except (jwt.InvalidTokenError, jwt.PyJWKClientError):
            raise SignInError("token_invalid") from None
        sub = claims.get("sub")
        if not isinstance(sub, str) or not sub:
            raise SignInError("token_invalid")
        nonce_supported = claims.get("nonce_supported")
        # Apple：nonce_supported 是 false 的平台不支援 nonce（文件：「otherwise, you can proceed treating the
        # anti-replay value as optional」）；其他情況 nonce 一定要有
        required = not (provider == "apple" and nonce_supported in (False, "false"))
        nonce = claims.get("nonce")
        return Identity(provider, sub, nonce if isinstance(nonce, str) else None, required)


# ---------------------------------------------------------------------------
# Apple：換 refresh token、撤銷
# ---------------------------------------------------------------------------
class AppleClient(Protocol):
    def configured(self) -> bool: ...

    def exchange_code(self, code: str) -> str: ...

    def revoke(self, refresh_token: str) -> None: ...


class AppleRestClient:
    """Sign in with Apple REST API。client secret 每次現簽（有效 1 小時就夠，不存）。"""

    TOKEN_URL = "https://appleid.apple.com/auth/token"
    REVOKE_URL = "https://appleid.apple.com/auth/revoke"

    def __init__(
        self,
        team_id: str,
        key_id: str,
        client_id: str,
        private_key_pem: str,
        transport: Optional[httpx.BaseTransport] = None,
        timeout_s: float = 15.0,
    ):
        self.team_id = team_id
        self.key_id = key_id
        self.client_id = client_id
        self._key = private_key_pem
        self._http = httpx.Client(transport=transport, timeout=timeout_s)

    def configured(self) -> bool:
        return bool(self.team_id and self.key_id and self.client_id and self._key)

    def client_secret(self, now: Optional[float] = None) -> str:
        now = int(now if now is not None else time.time())
        claims = {
            "iss": self.team_id,
            "iat": now,
            "exp": now + 3600,
            "aud": APPLE_ISSUER,
            "sub": self.client_id,
        }
        return jwt.encode(claims, self._key, algorithm="ES256", headers={"kid": self.key_id})

    def exchange_code(self, code: str) -> str:
        data = {
            "client_id": self.client_id,
            "client_secret": self.client_secret(),
            "code": code,
            "grant_type": "authorization_code",
        }
        try:
            r = self._http.post(self.TOKEN_URL, data=data)
        except httpx.HTTPError:
            raise SignInError("code_invalid") from None
        if r.status_code != 200:
            raise SignInError("code_invalid")
        token = r.json().get("refresh_token")
        if not isinstance(token, str) or not token:
            raise SignInError("code_invalid")
        return token

    def revoke(self, refresh_token: str) -> None:
        data = {
            "client_id": self.client_id,
            "client_secret": self.client_secret(),
            "token": refresh_token,
            "token_type_hint": "refresh_token",
        }
        try:
            r = self._http.post(self.REVOKE_URL, data=data)
        except httpx.HTTPError as e:
            raise RevokeError(type(e).__name__) from None
        if r.status_code != 200:  # 已經撤銷過的也回 200（文件），重試是安全的
            raise RevokeError(f"HTTP {r.status_code}")


class NotConfiguredApple:
    """還沒有 Apple 金鑰（M4 以前）：Apple 綁定回 not_configured；撤銷失敗、留在佇列等金鑰。"""

    def configured(self) -> bool:
        return False

    def exchange_code(self, code: str) -> str:
        raise SignInError("not_configured")

    def revoke(self, refresh_token: str) -> None:
        raise RevokeError("not_configured")


# ---------------------------------------------------------------------------
# refresh token 加密
# ---------------------------------------------------------------------------
class TokenCipher:
    """Fernet（AES-128-CBC＋HMAC-SHA256）。金鑰不見了就解不開：只能請使用者到 Apple 帳號設定自己解除。"""

    def __init__(self, key: bytes):
        self._f = Fernet(key)

    @classmethod
    def from_file(cls, path: Path, create: bool = True) -> "TokenCipher":
        """讀金鑰檔；沒有就產生一個（權限 600）。照 secrets-custody：不進 git、不寫日誌、要備份。"""
        path = Path(path)
        if not path.exists():
            if not create:
                raise FileNotFoundError(path)
            path.parent.mkdir(parents=True, exist_ok=True)
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "wb") as f:
                f.write(Fernet.generate_key())
        return cls(path.read_bytes().strip())

    def encrypt(self, text: str) -> bytes:
        return self._f.encrypt(text.encode())

    def decrypt(self, blob: bytes) -> str:
        try:
            return self._f.decrypt(bytes(blob)).decode()
        except InvalidToken:
            raise RevokeError("decrypt_failed") from None


# ---------------------------------------------------------------------------
# 記憶體裡的短效記錄
# ---------------------------------------------------------------------------
class _Expiring:
    def __init__(self, ttl_s: float = SHORT_TTL_S, max_items: int = 20_000):
        self.ttl_s = ttl_s
        self.max_items = max_items
        self._d: "OrderedDict[Any, Tuple[float, Any]]" = OrderedDict()

    def _gc(self, now: float) -> None:
        while self._d:
            k, (exp, _v) = next(iter(self._d.items()))
            if exp > now and len(self._d) <= self.max_items:
                break
            self._d.popitem(last=False)

    def put(self, key, value, now: Optional[float] = None) -> float:
        now = time.time() if now is None else now
        self._gc(now)
        exp = now + self.ttl_s
        self._d[key] = (exp, value)
        return exp

    def get(self, key, now: Optional[float] = None):
        now = time.time() if now is None else now
        item = self._d.get(key)
        if item is None or item[0] <= now:
            return None
        return item[1]

    def pop(self, key, now: Optional[float] = None):
        now = time.time() if now is None else now
        item = self._d.pop(key, None)
        if item is None or item[0] <= now:
            return None
        return item[1]


class NonceBook(_Expiring):
    """伺服器發的 nonce（協定 5.1 節）：只能用一次，10 分鐘有效。"""

    def issue(self, now: Optional[float] = None) -> Tuple[str, float]:
        nonce = base64.urlsafe_b64encode(secrets.token_bytes(24)).decode().rstrip("=")
        return nonce, self.put(nonce, True, now)

    def consume(self, nonce, now: Optional[float] = None) -> bool:
        return isinstance(nonce, str) and self.pop(nonce, now) is not None


def nonce_matches(claim: Optional[str], nonce: str) -> bool:
    """token 裡的 nonce 等於原值，或等於原值的 SHA-256（十六進位小寫）都算對（協定 5.0 節）。"""
    if claim is None:
        return False
    return secrets.compare_digest(claim, nonce) or secrets.compare_digest(
        claim, hashlib.sha256(nonce.encode()).hexdigest()
    )


@dataclass
class SwitchTicket:
    from_pid: int  # 發出憑單的牧場（換回後會刪除）
    target_pid: int  # 要換回的牧場
    provider: str
    subject: str


class TicketBook(_Expiring):
    def issue(self, ticket: SwitchTicket, now: Optional[float] = None) -> Tuple[str, float]:
        code = secrets.token_urlsafe(24)
        return code, self.put(code, ticket, now)

    def take(self, code, now: Optional[float] = None) -> Tuple[str, Optional[SwitchTicket]]:
        """用掉一張憑單：("ok", 憑單)、("expired", None)、("missing", None)。"""
        if not isinstance(code, str):
            return "missing", None
        now = time.time() if now is None else now
        item = self._d.pop(code, None)
        if item is None:
            return "missing", None
        if item[0] <= now:
            return "expired", None
        return "ok", item[1]


@dataclass
class AccountServices:
    """runtime 用的一組帳號零件；測試把 verifier、apple 換成假的。"""

    verifier: Verifier
    apple: AppleClient
    cipher: Optional[TokenCipher]
    nonces: NonceBook = field(default_factory=NonceBook)
    tickets: TicketBook = field(default_factory=TicketBook)
    replays: _Expiring = field(default_factory=_Expiring)


def services_from_config(cfg) -> AccountServices:
    """照設定組出真的零件（協定 5.5 節的環境變數）。沒設定的那一家，綁定和找回回 not_configured。"""
    verifier = JwksVerifier(cfg.apple_client_ids, cfg.google_client_ids)
    apple: AppleClient = NotConfiguredApple()
    if cfg.apple_team_id and cfg.apple_key_id and cfg.apple_key_file and cfg.apple_client_ids:
        pem = Path(cfg.apple_key_file).read_text()
        apple = AppleRestClient(cfg.apple_team_id, cfg.apple_key_id, cfg.apple_client_ids[0], pem)
    cipher = TokenCipher.from_file(Path(cfg.token_key_file)) if cfg.token_key_file else None
    return AccountServices(verifier=verifier, apple=apple, cipher=cipher)
