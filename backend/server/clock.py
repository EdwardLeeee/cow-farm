"""遊戲時鐘：遊戲時間 = 開服遊戲時間 + (現實時間 − 開服現實時間) × 倍率。

「開服」指這次伺服器啟動。伺服器關著的那段（runtime.resume_game_time）：
- 倍率 1（正式版）照真實時間走，關機那段也算（ceo 2026-10-02）。
- 試玩倍率暫停：重啟後從上次存下的遊戲時間接著走，晚上關機，隔天牧場不會一下子老好幾天。
現實時間用 time.monotonic() 量，主機校時不會讓遊戲時間跳動；回應裡的 real_time 則是 time.time()。
"""

from __future__ import annotations

import time


class GameClock:
    def __init__(self, game_anchor: float, scale: float):
        if scale <= 0:
            raise ValueError("time_scale 要大於 0")
        self.scale = float(scale)
        self.game_anchor = float(game_anchor)
        self.mono_anchor = time.monotonic()
        self.real_anchor = time.time()

    def now(self) -> float:
        return self.game_anchor + (time.monotonic() - self.mono_anchor) * self.scale

    def real_seconds_until(self, game_t: float) -> float:
        return (game_t - self.now()) / self.scale


class ManualClock:
    """測試用：時間只在呼叫 advance() 時前進。"""

    def __init__(self, game_anchor: float, scale: float = 1.0):
        self.scale = float(scale)
        self.t = float(game_anchor)
        self.real_anchor = time.time()

    def now(self) -> float:
        return self.t

    def advance(self, dt: float) -> float:
        self.t += dt
        return self.t

    def real_seconds_until(self, game_t: float) -> float:
        return (game_t - self.t) / self.scale
