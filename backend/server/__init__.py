"""cow-farm M1 伺服器：FastAPI + PostgreSQL，經濟規則全部來自 backend/cowecon/。

- game.py：服務層。真人（API）和電腦假玩家走同一組函式，所以對市場的影響一樣。
- bots.py：假玩家策略 S1–S5（照 docs/research/economy/sim/bots.py 移植，改成呼叫服務層）。
- store.py：PostgreSQL 存取；app.py：HTTP／WebSocket 端點與遊戲時鐘。
"""

import sys
from pathlib import Path

_BACKEND = Path(__file__).resolve().parent.parent
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))
