"""協定 v2 的代碼對照（不需要資料庫）：新聞代碼、電腦牧場名的詞庫編號、公營種牛站。

伺服器只送代碼，app 用字串表 design/m2/i18n/zh-Hant.json 依語言顯示（D25），所以代碼要跟字串表的 key 對得上。
"""

from __future__ import annotations

import json
import random
import re
from pathlib import Path

import pytest

from cowecon.farm import make_genotype
from cowecon.market import MarketEvent
from cowecon.params import HEADLINES
from server.breeds import ALL, BREEDS, breed_of_genes
from server.names import GROUPS, compose_name, load_words, name_words, random_name_words, station_words
from server.views import news_code

DESIGN = Path(__file__).resolve().parents[2] / "design" / "m2"
ZH = DESIGN / "i18n" / "zh-Hant.json"
BREEDS_JS = DESIGN / "src" / "cow" / "breeds.js"


def test_breed_table_matches_design():
    """24 品種代號跟設計稿 breeds.js 一樣：每個 key 的用途和特徵組合對上伺服器的表；字串表有每種的名字和介紹。"""
    if not BREEDS_JS.exists() or not ZH.exists():
        pytest.skip("找不到設計稿")
    src = BREEDS_JS.read_text(encoding="utf-8")
    use_idx = {"dairy": 0, "draft": 1, "beef": 2}
    found = {}
    for m in re.finditer(
        r"^\s+(\w+):\s*\{(?:\s*//[^\n]*)?\s*name:\s*'[^']*',\s*use:\s*'(\w+)',\s*traits:\s*\{([^}]*)\}", src, re.M
    ):
        key, use, traits = m.groups()
        mask = sum(1 << "ABC".index(t) for t in re.findall(r"([ABC]):\s*true", traits))
        found[key] = (use_idx[use], mask)
    assert len(found) == 24 and set(found) == set(ALL)
    for key, (t, mask) in found.items():
        assert BREEDS[t][mask] == key, key
    zh = json.loads(ZH.read_text(encoding="utf-8"))
    assert all(zh.get(f"breed.{b}.name") and zh.get(f"breed.{b}.intro") for b in ALL)


def test_breed_of_genes_uses_expressed_traits():
    """只看顯現的特徵（兩份隱性基因）：只帶一份的牛還是一般品種。位元 1 = A 長毛、2 = B 淡色、4 = C 光澤。"""
    assert breed_of_genes(make_genotype(0, [(0, 0), (0, 0), (0, 0)])) == "holstein"
    assert breed_of_genes(make_genotype(0, [(1, 0), (1, 0), (1, 0)])) == "holstein"  # 只帶一份
    assert breed_of_genes(make_genotype(0, [(1, 1), (0, 0), (0, 0)])) == "fluffyHolstein"  # A
    assert breed_of_genes(make_genotype(1, [(0, 0), (1, 1), (0, 0)])) == "milkTea"  # 耕牛 B
    assert breed_of_genes(make_genotype(2, [(0, 0), (0, 0), (1, 1)])) == "wagyu"  # 肉牛 C
    assert breed_of_genes(make_genotype(2, [(1, 1), (1, 1), (1, 1)])) == "starry"  # 肉牛 A＋B＋C


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
        name = compose_name(random_name_words(rng))
        w = name_words(name)
        assert w is not None and all(0 <= i < 12 for i in w)
        assert "".join(words[g][i] for g, i in zip(GROUPS, w)) == name
    assert name_words("小花的快樂牧場") is None  # 真人自己取的名字不是詞庫組的


def test_station_words_stable():
    """公營種牛站的名字由（世界種子, 上架編號）決定：重啟後一樣，不同上架通常不同。"""
    assert station_words("seed", 1) == station_words("seed", 1)
    names = {tuple(station_words("seed", lid)) for lid in range(1, 40)}
    assert len(names) > 30 and all(all(0 <= i < 12 for i in w) for w in names)
