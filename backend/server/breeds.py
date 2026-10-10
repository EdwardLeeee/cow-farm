"""24 個品種（企劃書 4.5；協定 1.6 節）：3 種用途 × 8 種特徵組合。

- 品種代號跟設計稿 design/m2/src/cow/breeds.js 的 key 一樣；app 用它查字串表 breed.<代號>.name、.intro。
  tests/test_views.py 會讀 breeds.js 比對用途和特徵。
- 特徵組合 = cowecon.farm.rare_mask：位元 1 = A 長毛、2 = B 淡色、4 = C 光澤；稀有度 = 位元數。
- v0.3（C1）：雜種牛的品種代號是 "hybrid"（圖鑑的「其他」區、頭像；不算 24 種）。牛的基因照舊，畫面只看到 "hybrid"。
  飼料代號跟設計稿 design/m2/src/js/feeds.js 的 FEED_KEYS 一樣，順序 = CareParams.feed_kg 的索引。
"""

from __future__ import annotations

from typing import Dict, List, Tuple

from cowecon import DEFAULT
from cowecon.farm import cow_type, rare_mask
from cowecon.params import FEED_IDS

# BREEDS[用途][特徵組合]；用途 0 乳牛、1 耕牛、2 肉牛（cowecon.farm 的 DAIRY、OX、BEEF）
BREEDS: Tuple[Tuple[str, ...], ...] = (
    ("holstein", "fluffyHolstein", "jersey", "cottonCream", "glossBlack", "velvetBlack", "chocolate", "strawberry"),
    ("yellow", "highland", "milkTea", "cottonCandy", "buffalo", "shaggyBuffalo", "honey", "goldenEar"),
    ("angus", "galloway", "charolais", "whiteFleece", "wagyu", "fluffyWagyu", "whiteWagyu", "starry"),
)
ALL: Tuple[str, ...] = tuple(b for row in BREEDS for b in row)
ORDER: Dict[str, int] = {b: i for i, b in enumerate(ALL)}  # 同一時間發現的，照這個順序排


HYBRID = "hybrid"  # 雜種牛的品種代號（協定 1.6 節）
# 飼料代號（協定 1.6 節）：牧草、乾草、燕麥、苜蓿、玉米、豆粕。cowecon.params.FEED_IDS（模組常數，不在參數指紋裡）
FEED_INDEX: Dict[str, int] = {k: i for i, k in enumerate(FEED_IDS)}
FLOOR_IDS: Tuple[str, ...] = tuple(DEFAULT.care.floor_ids)  # 泥土地、乾草床、青草地、軟墊地
FLOOR_INDEX: Dict[str, int] = {k: i for i, k in enumerate(FLOOR_IDS)}
ROBOT_IDS: Tuple[str, ...] = tuple(DEFAULT.care.robot_ids)  # 大便掃地機：基本款、耐用款
ROBOT_INDEX: Dict[str, int] = {k: i for i, k in enumerate(ROBOT_IDS)}


def breed_id(ctype: int, mask: int) -> str:
    return BREEDS[ctype][mask]


def breed_of_genes(g: int) -> str:
    """基因 → 品種代號（看顯現的特徵，不看只帶一份的隱性基因）。"""
    return BREEDS[cow_type(g)][rare_mask(g)]


def shown_breed(g: int, hybrid: bool) -> str:
    """畫面上的品種：雜種牛一律 "hybrid"（不透露原本會是哪個品種，企劃 v0.3 第 1.1 節）。"""
    return HYBRID if hybrid else breed_of_genes(g)


def feed_ids(mask: int) -> List[str]:
    """飼料位元（Cow.fed）→ 飼料代號，照 FEED_IDS 的順序。"""
    return [k for i, k in enumerate(FEED_IDS) if (mask >> i) & 1]
