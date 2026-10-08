"""牧場資料的成就（S21，D34）：18 個，key 和順序跟設計稿 design/m2/src/js/screens/s21.js 的 BADGES 一樣
（tests/test_views.py 會比對）。第一版只展示、沒有獎勵；伺服器記解鎖的遊戲時間和有計數的進度，目標數字由伺服器給。

三種：
- 一般：做到一次就解鎖（unlocked_at）。
- 有計數：累計到目標就解鎖（progress／goal）。
- 分階段：每一階一個目標（tiers[{goal, unlocked_at}]）。

字串表 ach.<key>.name、ach.<key>.cond（分階段的是 .name.<階>、.cond.<階>）由 app 查。
"""

from __future__ import annotations

from typing import Dict, Optional, Tuple, Union

from cowecon import DEFAULT

# (key, 目標)：None = 一般；數字 = 有計數；tuple = 分階段
ACHIEVEMENTS: Tuple[Tuple[str, Union[None, int, Tuple[int, ...]]], ...] = (
    ("firstMilk", None),  # 第一次收奶
    ("firstSale", None),  # 第一次在市場賣出東西
    ("firstShip", None),  # 第一次出貨
    ("gradeA", 10),  # 出貨評到 A 級 10 次
    ("newLife", None),  # 第一次配種生出小牛（自己配或借種都算）
    ("borrow", None),  # 第一次借到別人的公牛
    ("popularBull", 10),  # 自己的公牛被借走 10 次
    ("rice", 1000),  # 累計收成 1,000 公斤稻米
    ("codex", (5, 12, 24)),  # 發現 5／12／24 種牛（解鎖時間 = 第 N 種的 codex.found_at）
    ("legend", None),  # 擁有一頭傳說牛
    ("level", (10, 20)),  # 升到 Lv 10／20
    ("rich", (100_000, 1_000_000)),  # 總資產（= 排行榜的 networth）到 10 萬／100 萬幣
    ("tailwind", None),  # 在超級大事件期間賣出東西（那種商品正在超級大事件裡）
    ("weekChamp", None),  # 某一週收入排行榜第 1 名（那一週結束、週一 00:00 重算時記）
    ("pureBreed", None),  # 15–18：D35 的新玩法（v0.3）做好以後才有，先一律還沒解鎖
    ("healer", None),
    ("clean", None),
    ("trucks", None),
)
GOALS: Dict[str, Union[None, int, Tuple[int, ...]]] = dict(ACHIEVEMENTS)
NOT_YET = frozenset({"pureBreed", "healer", "clean", "trucks"})  # v0.3 才接上

RENAME_PRICE = int(
    DEFAULT.care.rename_price
)  # 第二次起改名的價錢（幣，D34）；第一次免費。v0.3 起在 cowecon/params（CareParams）


def tier_key(key: str, i: int) -> str:
    """分階段成就第 i 階（從 1 開始）在 Player.ach 裡的 key，例 level.1。"""
    return f"{key}.{i}"


def goal_of(key: str) -> Optional[int]:
    g = GOALS[key]
    return g if isinstance(g, int) else None
