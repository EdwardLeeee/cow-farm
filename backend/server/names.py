"""牧場名稱（協定 1.6 節）。

- 真人：玩家自己取（D23）。
- 電腦假玩家：從詞庫組（backend/server/data/ranch_words.json，3 組 × 12 詞）。協定只送三組詞的編號（name_words），
  app 用字串表的 namegen.* 依玩家的語言組；繁中詞庫跟 design/m2/i18n/zh-Hant.json 的 namegen.* 一樣（i18ncheck 會檢查）。
- 公營種牛站（電腦系統上架、沒有主人的公牛）：每筆上架一組編號，由世界種子和上架編號導出，重啟後不變。
"""

from __future__ import annotations

import json
import random
from pathlib import Path
from typing import Dict, List, Optional, Tuple

WORDS_FILE = Path(__file__).resolve().parent / "data" / "ranch_words.json"
GROUPS = ("first", "second", "third")


def load_words() -> Dict[str, List[str]]:
    d = json.loads(WORDS_FILE.read_text(encoding="utf-8"))
    return {k: d[k] for k in GROUPS}


_WORDS = load_words()
# 詞庫組得出來的每個名字 → 三組詞的編號（12 × 12 × 12 = 1,728 個）
_BY_NAME: Dict[str, Tuple[int, int, int]] = {
    a + b + c: (i, j, k)
    for i, a in enumerate(_WORDS["first"])
    for j, b in enumerate(_WORDS["second"])
    for k, c in enumerate(_WORDS["third"])
}


def random_name_words(rng: random.Random) -> List[int]:
    """電腦牧場名：三組詞各挑一個（亂數用量跟以前的 rng.choice 一樣，電腦玩家的其他設定不會因此改變）。"""
    return [rng.randrange(len(_WORDS[g])) for g in GROUPS]


def compose_name(words: List[int]) -> str:
    """三組詞的編號 → 繁中名字（只給日誌和除錯看；app 用字串表依玩家的語言組）。"""
    return "".join(_WORDS[g][i] for g, i in zip(GROUPS, words))


def name_words(name: str) -> Optional[List[int]]:
    """詞庫組出來的名字 → 三組詞的編號（各 0–11）；不是詞庫組的回傳 None。"""
    w = _BY_NAME.get(name)
    return list(w) if w is not None else None


def station_words(seed: str, listing_id: int) -> List[int]:
    """公營種牛站第 listing_id 筆上架的名字（三組詞的編號）。"""
    r = random.Random(f"{seed}:station:{listing_id}")
    return [r.randrange(len(_WORDS[g])) for g in GROUPS]
