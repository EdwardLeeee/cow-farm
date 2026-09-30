"""牧場名稱：只能從詞庫組合（backend/server/data/ranch_words.json），不開放自由輸入。"""

from __future__ import annotations

import json
import random
from pathlib import Path
from typing import Dict, List

WORDS_FILE = Path(__file__).resolve().parent / "data" / "ranch_words.json"
BOT_PREFIX = "電腦"  # 排行榜上假玩家名字前面的標記


def load_words() -> Dict[str, List[str]]:
    d = json.loads(WORDS_FILE.read_text(encoding="utf-8"))
    return {k: d[k] for k in ("first", "second", "third")}


_WORDS = load_words()


def random_ranch_name(rng: random.Random) -> str:
    return "".join(rng.choice(_WORDS[k]) for k in ("first", "second", "third"))


def display_name(name: str, is_bot: bool) -> str:
    return f"{BOT_PREFIX} {name}" if is_bot else name
