"""啟動伺服器：cd backend && .venv/bin/python -m server

環境變數：COWFARM_TIME_SCALE（預設 1）、COWFARM_WEB_DIR、COWFARM_BOTS（預設 30）、
COWFARM_HOST（預設 0.0.0.0）、COWFARM_PORT（預設 8787）、COWFARM_PG_DSN（預設讀 ~/.config/cow-farm/pg.env）。
"""

import logging
import os

import uvicorn

from . import logsafe
from .app import create_app
from .config import Config


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    logsafe.install()
    cfg = Config.from_env()
    app = create_app(cfg)
    uvicorn.run(
        app,
        host=os.environ.get("COWFARM_HOST", "0.0.0.0"),
        port=int(os.environ.get("COWFARM_PORT", "8787")),
        workers=1,
        access_log=False,  # WebSocket 的 ?token= 會出現在存取日誌裡，所以不開
        ws_per_message_deflate=False,  # 行情訊息很小，關掉壓縮省記憶體（backend-findings）
        log_level="info",
    )


if __name__ == "__main__":
    main()
