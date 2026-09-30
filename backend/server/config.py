"""設定：全部來自環境變數；資料庫連線另外可以從 ~/.config/cow-farm/pg.env 讀（scripts/pg.sh 產生，權限 600）。"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Optional

PG_ENV_FILE = Path(os.environ.get("COWFARM_PG_ENV_FILE", str(Path.home() / ".config" / "cow-farm" / "pg.env")))


def read_env_file(path: Path) -> Dict[str, str]:
    out: Dict[str, str] = {}
    if not path.is_file():
        return out
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def default_dsn(database: Optional[str] = None) -> str:
    """COWFARM_PG_DSN；沒有的話讀 pg.env。database 有給時換掉 DSN 裡的資料庫名稱（測試用）。"""
    dsn = os.environ.get("COWFARM_PG_DSN") or read_env_file(PG_ENV_FILE).get("COWFARM_PG_DSN", "")
    if not dsn:
        raise RuntimeError(
            "找不到資料庫連線：請先執行 backend/scripts/pg.sh up（會產生 ~/.config/cow-farm/pg.env），"
            "或設定環境變數 COWFARM_PG_DSN。"
        )
    if database:
        base, _, _old = dsn.rpartition("/")
        dsn = f"{base}/{database}"
    return dsn


def _float_env(name: str, default: Optional[float]) -> Optional[float]:
    v = os.environ.get(name)
    return float(v) if v not in (None, "") else default


@dataclass
class Config:
    time_scale: float = 1.0
    pg_dsn: str = ""
    web_dir: Optional[str] = None
    bots: int = 30
    seed: Optional[str] = None  # 只在第一次建立世界時用；之後以資料庫裡的為準
    game_start: Optional[float] = None  # 第一次建立世界時的遊戲時間（Unix 秒）；預設 = 現在
    ws_push_s: float = 1.0  # 每現實幾秒推一次行情
    online_window_s: float = 30.0  # 最近幾秒（現實）內有請求就算在線
    run_loops: bool = True  # 測試時關掉背景 tick／推播
    extra: dict = field(default_factory=dict)

    @classmethod
    def from_env(cls) -> "Config":
        return cls(
            time_scale=_float_env("COWFARM_TIME_SCALE", 1.0),
            pg_dsn=default_dsn(),
            web_dir=os.environ.get("COWFARM_WEB_DIR") or None,
            bots=int(os.environ.get("COWFARM_BOTS", "30")),
            seed=os.environ.get("COWFARM_SEED") or None,
            game_start=_float_env("COWFARM_GAME_START", None),
        )
