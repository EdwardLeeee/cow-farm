"""圖鑑的配種表（企劃 v0.3 第 13.2 節；設計稿 S09-03、S09-08；協定 2.7 節）。

- 一列 = 爸爸的品種 ♂ × 媽媽的品種 ♀ → 生出的品種。爸爸、媽媽分開算（設計稿的假資料把「荷斯坦♂×娟珊♀」和
  「娟珊♂×荷斯坦♀」列成兩列），反過來配是另一列。
- 代表配法：每個品種列 REPRESENTATIVE 組，照「這一對品種配出這個品種的機率」從高排到低。爸媽身上沒顯現的特徵，
  照商店 B 級的隱性基因比例 q 推算帶一份隱性的機會（2q ÷ (1 + q)）。遺傳上兩個方向的機率一樣，同分時
  同品種配同品種在前，再來是爸媽稀有度低的、照品種代號表（協定 1.6 節：先用途、再特徵組合，breeds.ORDER）排前面的
  那一對；同一對的兩個方向排在一起，代號表在前的當爸爸那一列先。機率只用來挑和排，不送給 app（玩家的牛真正的基因
  看不到，這不是保證）。
- 玩家的紀錄（Player.pairs）：「爸爸品種,媽媽品種,小牛品種」→ [第一次長大的時間, 配出過幾次]。畫面上的品種，
  雜種牛的爸媽記 "hybrid"；長成雜種牛的小牛不算。
- 參數（q）改了，表就跟著變；tests/test_pairings.py 鎖住幾個例子。
"""

from __future__ import annotations

from itertools import product
from typing import Dict, List, Tuple

from cowecon import DEFAULT

from .breeds import ALL, BREEDS, ORDER

REPRESENTATIVE = 4
_INFO: Dict[str, Tuple[int, int]] = {b: (t, m) for t, row in enumerate(BREEDS) for m, b in enumerate(row)}


def _child_type_probs(ts: int, td: int) -> List[float]:
    """用途：乳 MM、耕 MF、肉 FF（用途座的兩個等位基因，爸媽各給一個）。"""
    alleles = {0: (0, 0), 1: (0, 1), 2: (1, 1)}
    out = [0.0, 0.0, 0.0]
    for a in alleles[ts]:
        for b in alleles[td]:
            out[a + b] += 0.25
    return out


def pair_prob(sire: str, dam: str, child: str, q: float) -> float:
    """品種 sire × 品種 dam 生出 child 的機率（估計）：顯現的特徵一定給隱性；沒顯現的給隱性的機會 q ÷ (1 + q)。"""
    ts, ms = _INFO[sire]
    td, md = _INFO[dam]
    tc, mc = _INFO[child]
    p = _child_type_probs(ts, td)[tc]
    for i in range(3):
        ps = 1.0 if (ms >> i) & 1 else q / (1.0 + q)
        pd = 1.0 if (md >> i) & 1 else q / (1.0 + q)
        e = ps * pd
        p *= e if (mc >> i) & 1 else 1.0 - e
    return p


def _rarity(b: str) -> int:
    return bin(_INFO[b][1]).count("1")


def build(
    q: float = DEFAULT.farm.shop_grade_recessive_freq[1], n: int = REPRESENTATIVE
) -> Dict[str, List[Tuple[str, str]]]:
    """每個品種的代表配法：[(爸爸的品種, 媽媽的品種)]。"""
    out: Dict[str, List[Tuple[str, str]]] = {}
    for child in ALL:
        cands = []
        for sire, dam in product(ALL, ALL):
            p = pair_prob(sire, dam, child, q)
            if p <= 0.0:
                continue
            lo, hi = sorted((ORDER[sire], ORDER[dam]))
            cands.append((-round(p, 12), sire != dam, _rarity(sire) + _rarity(dam), lo, hi, ORDER[sire], sire, dam))
        cands.sort()
        out[child] = [(c[6], c[7]) for c in cands[:n]]
    return out


TABLE: Dict[str, List[Tuple[str, str]]] = build()


def record_key(sire: str, dam: str, child: str) -> str:
    """Player.pairs 的 key：「爸爸品種,媽媽品種,小牛品種」。"""
    return ",".join((sire, dam, child))


def record(pairs: Dict[str, List[float]], sire: str, dam: str, child: str, t: float) -> None:
    """記一次配出來（長大揭曉那一刻 t）：第一次的時間取早的，次數 +1。"""
    k = record_key(sire, dam, child)
    old = pairs.get(k)
    pairs[k] = [t, 1] if old is None else [min(old[0], t), old[1] + 1]


def load(pairs: Dict[str, object]) -> Dict[str, List[float]]:
    """存檔讀回來：值是 [時間, 次數]；C1a 的存檔只有時間（數字），當成 1 次。"""
    return {k: [float(v), 1] if isinstance(v, (int, float)) else [float(v[0]), int(v[1])] for k, v in pairs.items()}


def view() -> Dict[str, List[dict]]:
    """GET /v1/codex/pairings 的 pairings：24 種（品種代號表的順序），每種 {sire, dam} 照機率高到低；雜種牛沒有配種表。"""
    return {child: [{"sire": s, "dam": d} for s, d in TABLE[child]] for child in ALL}
