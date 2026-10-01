"""24 個品種（企劃書 4.5；協定 1.6 節）：3 種用途 × 8 種特徵組合。

- 品種代號跟設計稿 design/m2/src/cow/breeds.js 的 key 一樣；app 用它查字串表 breed.<代號>.name、.intro。
  tests/test_views.py 會讀 breeds.js 比對用途和特徵。
- 特徵組合 = cowecon.farm.rare_mask：位元 1 = A 長毛、2 = B 淡色、4 = C 光澤；稀有度 = 位元數。
"""

from __future__ import annotations

from typing import Dict, Tuple

from cowecon.farm import cow_type, rare_mask

# BREEDS[用途][特徵組合]；用途 0 乳牛、1 耕牛、2 肉牛（cowecon.farm 的 DAIRY、OX、BEEF）
BREEDS: Tuple[Tuple[str, ...], ...] = (
    ("holstein", "fluffyHolstein", "jersey", "cottonCream", "glossBlack", "velvetBlack", "chocolate", "strawberry"),
    ("yellow", "highland", "milkTea", "cottonCandy", "buffalo", "shaggyBuffalo", "honey", "goldenEar"),
    ("angus", "galloway", "charolais", "whiteFleece", "wagyu", "fluffyWagyu", "whiteWagyu", "starry"),
)
ALL: Tuple[str, ...] = tuple(b for row in BREEDS for b in row)
ORDER: Dict[str, int] = {b: i for i, b in enumerate(ALL)}  # 同一時間發現的，照這個順序排


def breed_id(ctype: int, mask: int) -> str:
    return BREEDS[ctype][mask]


def breed_of_genes(g: int) -> str:
    """基因 → 品種代號（看顯現的特徵，不看只帶一份的隱性基因）。"""
    return BREEDS[cow_type(g)][rare_mask(g)]
