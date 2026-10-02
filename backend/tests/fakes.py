"""帳號測試用的假零件（協定第 5 節）。真的驗證程式另外在 tests/test_accounts.py 用自己產生的金鑰測。"""

from __future__ import annotations

import json
from typing import List, Optional

from cryptography.fernet import Fernet

from server.accounts import AccountServices, Identity, RevokeError, SignInError, TokenCipher


def fake_token(sub: str, nonce: Optional[str] = None, **extra) -> str:
    """假的 id_token：「fake.」加上一段 JSON。email、name 這類欄位放進去，測伺服器不會存。"""
    return "fake." + json.dumps({"sub": sub, "nonce": nonce, **extra})


class FakeVerifier:
    def __init__(self, providers=("apple", "google")):
        self.providers = set(providers)

    def configured(self, provider: str) -> bool:
        return provider in self.providers

    def verify(self, provider: str, id_token: str) -> Identity:
        if provider not in self.providers:
            raise SignInError("not_configured")
        if not isinstance(id_token, str) or not id_token.startswith("fake."):
            raise SignInError("token_invalid")
        d = json.loads(id_token[5:])
        if d.get("expired"):
            raise SignInError("token_expired")
        return Identity(provider, d["sub"], d.get("nonce"), not d.get("nonce_optional", False))


class FakeApple:
    def __init__(self):
        self.exchanged: List[str] = []
        self.revoked: List[str] = []
        self.fail_revoke = False

    def configured(self) -> bool:
        return True

    def exchange_code(self, code: str) -> str:
        if code == "bad":
            raise SignInError("code_invalid")
        self.exchanged.append(code)
        return f"refresh-{code}"

    def revoke(self, refresh_token: str) -> None:
        if self.fail_revoke:
            raise RevokeError("HTTP 503")
        self.revoked.append(refresh_token)


def fake_services(apple: Optional[FakeApple] = None) -> AccountServices:
    return AccountServices(
        verifier=FakeVerifier(), apple=apple or FakeApple(), cipher=TokenCipher(Fernet.generate_key())
    )
