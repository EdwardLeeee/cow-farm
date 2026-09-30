"""情境定義（純資料，v0.2）。M1 伺服器測試可以直接 import 這份清單，照同樣的 seed 跑出同樣的數字。

策略比例預設六種各 1/6（D 乳牛、B 肉牛、F 耕田、C 配種收集、T 抓時機、L 出借公牛）；大戶 W 另外加一位。

時間都以「開服後幾小時」表示；開服 = 2026-10-05（週一）00:00 台灣時間。
第 20 天 21:00 = 20×24+21 = 501 小時（晚上尖峰）。
"""

from __future__ import annotations

from typing import Dict, List

DAYS = 30
DUMP_H = 20 * 24 + 21  # 大戶倒貨：第 21 天（day index 20）晚上 21:00
EVENT_H = 20 * 24 + 20  # 大利多：第 21 天晚上 20:00
LOW_DAY = 15  # 線上很少的那一天（day index 15 = 第 16 天，週二）

# 各人數跑幾個 seed（人少的情境隨機性大，多跑幾個）
POP_SEEDS = {10: [1, 2, 3, 4, 5], 100: [1, 2, 3], 1000: [1, 2], 10000: [1]}


def base(players: int, seed: int, tick_s: int = 60) -> dict:
    return {"name": f"base_{players}_s{seed}" + ("" if tick_s == 60 else f"_tick{tick_s}"), "group": "base", "players": players, "days": DAYS, "tick_s": tick_s, "seed": seed}


def whale(players: int, mode: str, cows: int, seed: int = 1) -> dict:
    """mode：dump 一次倒出、batch 分 8 批每 3 小時賣一次（約一天賣完，白天晚上都有）、hold 一直囤（對照組）。

    分批間隔 3 小時：玩家「最近賣出量」以 1 小時時間常數衰減，3 小時後只剩 5%，每批幾乎從零開始算滑價。
    """
    return {
        "name": f"whale_{players}_{cows}cows_{mode}_s{seed}", "group": "whale", "players": players, "days": 23, "tick_s": 60, "seed": seed,
        "whale": {"cows": cows, "mode": mode, "hoard_from_h": DUMP_H - 48, "dump_at_h": DUMP_H if mode != "hold" else 10 ** 6, "batches": 8, "batch_gap_h": 3.0},
    }


def panic(players: int, with_panic: bool, seed: int = 1) -> dict:
    sc = {
        "name": f"event_{players}_{'panic' if with_panic else 'calm'}_s{seed}", "group": "event", "players": players, "days": 23, "tick_s": 60, "seed": seed,
        "inject_events": [{"targets": ["milk", "beef", "rice"], "factor": 1.4, "at_h": EVENT_H, "half_life_h": 4.0, "headline": "（情境）全國農牧節：鮮奶、牛肉、稻米收購價大漲"}],
    }
    if with_panic:
        sc["panic"] = {"at_h": EVENT_H + 0.25, "share": 0.6, "window_min": 30}
    return sc


def low_online(players: int, seed: int = 1) -> dict:
    return {"name": f"low_{players}_s{seed}", "group": "low", "players": players, "days": 20, "tick_s": 60, "seed": seed, "low_online_days": {LOW_DAY: 0.2}}


def all_scenarios() -> List[dict]:
    out: List[dict] = []
    for n, seeds in POP_SEEDS.items():
        for s in seeds:
            out.append(base(n, s))
    out.append(base(1000, 1, tick_s=300))  # tick 大小比較
    out.append(base(1000, 2, tick_s=300))
    for n in (10, 100, 1000):
        for mode in ("hold", "dump", "batch"):
            out.append(whale(n, mode, 100))
    for mode in ("hold", "dump", "batch"):
        out.append(whale(100, mode, 1000))  # 超級大戶：一個人比全服其他人加起來還大
        out.append(whale(1000, mode, 1000))  # 大戶約佔全服 5%
    for n in (100, 1000):
        out.append(panic(n, False))
        out.append(panic(n, True))
    for n in (100, 1000):
        out.append(low_online(n))
        out.append({**low_online(n), "name": f"low_{n}_s1_ref", "low_online_days": {}})
    return out


def by_name() -> Dict[str, dict]:
    return {s["name"]: s for s in all_scenarios()}
