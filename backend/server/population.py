"""玩家上線時段：每天 4–8 次短時段，偏重台灣晚上。

照 docs/research/economy/sim/population.py 移植（數字與抽樣順序完全相同），另外加上給伺服器用的
day_sessions_with()：每位假玩家每天用各自的亂數，伺服器重啟後同一天的排程不變。
"""

from __future__ import annotations

import bisect
import random
from typing import List, Tuple

from cowecon.params import DAY, MINUTE, TZ_OFFSET_S

# 台灣時間每小時的上線權重（晚上 19–23 點最多，凌晨最少）
HOURLY_WEIGHT = (
    0.6, 0.3, 0.15, 0.1, 0.1, 0.15, 0.4, 0.9, 1.0, 0.7, 0.6, 0.8,
    1.3, 1.1, 0.7, 0.7, 0.8, 1.0, 1.3, 1.8, 2.2, 2.4, 2.2, 1.4,
)

MIN_GAP_S = 30 * MINUTE
SESSION_MIN_S = 3 * MINUTE
SESSION_MAX_S = 10 * MINUTE
TUTORIAL_S = 30 * MINUTE


def _minute_cdf() -> List[float]:
    w = []
    for m in range(1440):
        h = m / 60.0
        i = int(h) % 24
        j = (i + 1) % 24
        frac = h - int(h)
        w.append(HOURLY_WEIGHT[i] * (1 - frac) + HOURLY_WEIGHT[j] * frac)
    total = sum(w)
    cdf, acc = [], 0.0
    for x in w:
        acc += x / total
        cdf.append(acc)
    return cdf


_CDF = _minute_cdf()


def sample_local_minute(rng: random.Random) -> float:
    """依權重抽一個台灣時間的分鐘（0–1440，含小數）。"""
    i = bisect.bisect_left(_CDF, rng.random())
    return min(i, 1439) + rng.random()


def day_sessions_with(r: random.Random, per_day: int, shift_min: float, day_start_utc: float, keep_prob: float = 1.0) -> List[Tuple[float, float]]:
    """某一天（台灣時間 00:00 起）的 (開始, 長度)。和 Schedule.day_sessions 同一個算法。"""
    mins = sorted((sample_local_minute(r) + shift_min) % 1440.0 for _ in range(per_day))
    out: List[Tuple[float, float]] = []
    last = -1e9
    for m in mins:
        t = day_start_utc + m * MINUTE
        if t < last + MIN_GAP_S:
            t = last + MIN_GAP_S
        if t >= day_start_utc + DAY:
            break
        dur = r.uniform(SESSION_MIN_S, SESSION_MAX_S)
        keep = r.random() < keep_prob
        if keep:
            out.append((t, dur))
        last = t
    return out


class Schedule:
    """一位玩家的上線習慣（模擬用：同一個亂數一路抽下去）。"""

    __slots__ = ("per_day", "shift_min", "rng")

    def __init__(self, rng: random.Random):
        self.rng = rng
        self.per_day = rng.randint(4, 8)
        self.shift_min = rng.uniform(-60.0, 60.0)  # 個人作息偏移

    def day_sessions(self, day_start_utc: float, keep_prob: float = 1.0) -> List[Tuple[float, float]]:
        return day_sessions_with(self.rng, self.per_day, self.shift_min, day_start_utc, keep_prob)


def local_midnight_utc(t: float) -> float:
    """t 所在那天台灣時間 00:00 的 Unix 時間。"""
    return ((t + TZ_OFFSET_S) // DAY) * DAY - TZ_OFFSET_S
