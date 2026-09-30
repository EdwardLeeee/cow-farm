"""玩家 bot 與情境模擬。

經濟引擎 cowecon 在 2026-09-30 搬到 `backend/cowecon/`（只保留那一份，伺服器與模擬共用）。
這裡把 `backend/` 加進 sys.path，`from cowecon import ...` 才找得到。
"""

import sys
from pathlib import Path

_BACKEND = Path(__file__).resolve().parents[4] / "backend"
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))
