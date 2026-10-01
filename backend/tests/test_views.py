"""協定 v2 的代碼對照（不需要資料庫）：新聞代碼、電腦牧場名的詞庫編號、公營種牛站。

伺服器只送代碼，app 用字串表 design/m2/i18n/zh-Hant.json 依語言顯示（D25），所以代碼要跟字串表的 key 對得上。
"""

from __future__ import annotations

import json
import random
from pathlib import Path

import pytest

from cowecon.market import MarketEvent
from cowecon.params import HEADLINES
from server.names import GROUPS, load_words, name_words, random_ranch_name, station_words
from server.views import news_code

ZH = Path(__file__).resolve().parents[2] / "design" / "m2" / "i18n" / "zh-Hant.json"


def _event(targets, factor, headline):
    return MarketEvent(1, targets, factor, 0.0, 0.0, 900.0, 7200.0, 6.0, headline)


def test_news_codes_match_string_table():
    """每則標題都有唯一的代碼，字串表的 news.<代碼> 就是同一則標題（繁中）。"""
    if not ZH.exists():
        pytest.skip(f"找不到 {ZH}")
    zh = json.loads(ZH.read_text(encoding="utf-8"))
    codes = set()
    for key, titles in HEADLINES.items():
        commodity, up = key[:-1], key[-1] == "+"
        targets = ("milk", "beef", "rice") if commodity == "all" else (commodity,)
        for title in titles:
            code = news_code(_event(targets, 1.2 if up else 0.8, title))
            assert code is not None and code not in codes, (key, title)
            codes.add(code)
            assert zh[f"news.{code}"] == title
    assert len(codes) == sum(len(t) for t in HEADLINES.values())
    assert news_code(_event(("milk",), 1.2, "（測試事件）")) is None  # 不在 HEADLINES 的標題沒有代碼


def test_name_words_roundtrip():
    """電腦牧場名 → 三組詞的編號 → 照 namegen.pattern（繁中 {first}{second}{third}）組回同一個名字。"""
    words = load_words()
    rng = random.Random(7)
    for _ in range(200):
        name = random_ranch_name(rng)
        w = name_words(name)
        assert w is not None and all(0 <= i < 12 for i in w)
        assert "".join(words[g][i] for g, i in zip(GROUPS, w)) == name
    assert name_words("小花的快樂牧場") is None  # 真人自己取的名字不是詞庫組的


def test_station_words_stable():
    """公營種牛站的名字由（世界種子, 上架編號）決定：重啟後一樣，不同上架通常不同。"""
    assert station_words("seed", 1) == station_words("seed", 1)
    names = {tuple(station_words("seed", lid)) for lid in range(1, 40)}
    assert len(names) > 30 and all(all(0 <= i < 12 for i in w) for w in names)
