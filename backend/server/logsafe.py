"""日誌不寫 token：uvicorn 即使關掉存取日誌，WebSocket 握手仍會用 uvicorn.error 記錄完整路徑（含 ?token=）。"""

from __future__ import annotations

import logging
import re

_TOKEN_RE = re.compile(r"(token=|cowfarm\.token\.)[A-Za-z0-9_\-.~%]+")


class RedactTokens(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        try:
            msg = record.getMessage()
        except Exception:  # noqa: BLE001
            return True
        red = _TOKEN_RE.sub(r"\1***", msg)
        if red != msg:
            record.msg, record.args = red, ()
        return True


def install() -> None:
    """掛在 uvicorn 與伺服器用到的 logger 上（logger 層級的 filter，handler 還沒建立也有效）。"""
    f = RedactTokens()
    for name in ("uvicorn", "uvicorn.error", "uvicorn.access", "cowfarm", ""):
        lg = logging.getLogger(name)
        if not any(isinstance(x, RedactTokens) for x in lg.filters):
            lg.addFilter(f)
