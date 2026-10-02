"""日誌不寫 token（協定 1.3 節、第 7 節；server/logsafe.py）。不需要資料庫。

WebSocket 的 token 放在網址 /v1/ws?token=… 或子協定 cowfarm.token.…：
- uvicorn 的存取日誌不開（server/__main__.py 的 access_log=False）。
- WebSocket 握手那一行 uvicorn 用 uvicorn.error 記（存取日誌關掉也會記），由 logsafe 遮成 token=***。
"""

from __future__ import annotations

import ast
import logging
from pathlib import Path

from server import logsafe

MAIN = Path(__file__).resolve().parents[1] / "server" / "__main__.py"


class _Collect(logging.Handler):
    def __init__(self):
        super().__init__()
        self.lines = []

    def emit(self, record):
        self.lines.append(self.format(record))


def test_websocket_handshake_line_hides_token():
    logsafe.install()
    lg = logging.getLogger("uvicorn.error")
    h, level = _Collect(), lg.level
    lg.addHandler(h)
    lg.setLevel(logging.INFO)
    try:
        # uvicorn 的 WebSocket 實作在握手時這樣記（路徑含查詢字串）
        lg.info('%s - "WebSocket %s" [accepted]', "127.0.0.1:54604", "/v1/ws?token=not-a-real-token_123")
        lg.info("offered %s", ["cowfarm.v1", "cowfarm.token.not-a-real-token_123"])
    finally:
        lg.removeHandler(h)
        lg.setLevel(level)
    assert h.lines == [
        '127.0.0.1:54604 - "WebSocket /v1/ws?token=***" [accepted]',
        "offered ['cowfarm.v1', 'cowfarm.token.***']",
    ]


def test_server_runs_without_access_log():
    """伺服器的 uvicorn.run 要帶 access_log=False：存取日誌會記每個請求的完整網址。"""
    calls = [
        n
        for n in ast.walk(ast.parse(MAIN.read_text(encoding="utf-8")))
        if isinstance(n, ast.Call) and ast.unparse(n.func) == "uvicorn.run"
    ]
    assert len(calls) == 1
    kw = {k.arg: k.value for k in calls[0].keywords}
    assert "access_log" in kw and isinstance(kw["access_log"], ast.Constant) and kw["access_log"].value is False
