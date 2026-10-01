"""玩家自己取的牧場名（D23；協定 2.2 節）。伺服器以這裡為準；app 和設計稿的 i18ncheck 用同一套規則。

1. 去掉前後的 Unicode White_Space；中間的空白保留，不做正規化（NFC 等），照送來的字元算。
2. 逐個字元（code point）檢查，回報第一個不能用的：
   - emoji：Unicode 13.0 emoji-data 的 Extended_Pictographic（data/extended_pictographic.json，
     scripts/gen_name_tables.py 產生）、區域指示符（國旗）、膚色、U+FE0F、U+20E3、ZWJ、tag 字元。
   - bad_char：控制字元 Cc、中間的換行／換段分隔、雙向控制字元、私用區 Co、代理字元 Cs、還沒指派的字元 Cn。
     這是為了顯示安全，不是內容過濾（ceo 2026-10-02）。
3. 寬度：Mn、Me、Cf 算 0；East Asian Width 是 W、F 算 2；其他算 1。總共 2–16。
   類別、East Asian Width、「還沒指派」都以 Unicode 13.0（Python 3.10 的 unicodedata）為準。
   W／F 只看已指派的字（Python 3.10 對還沒指派的字會回 F），另外把漢字區塊補到區塊結尾（CJK_BLOCK_ENDS），
   跟 design/m2/src/js/namewidth.js 的 WIDE 完全一樣（tests/test_ranchname.py 逐字比對）。
"""

from __future__ import annotations

import json
import unicodedata
from bisect import bisect_right
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple

MIN_WIDTH = 2
MAX_WIDTH = 16
_MAX_SCAN = 256  # 送來的字太多就不逐字檢查（一定超過 16），避免拿很長的字串來耗伺服器

# Unicode White_Space（PropList.txt）
WHITE_SPACE = frozenset(
    [*range(0x09, 0x0E), 0x20, 0x85, 0xA0, 0x1680, *range(0x2000, 0x200B), 0x2028, 0x2029, 0x202F, 0x205F, 0x3000]
)

# 漢字區塊在 Unicode 13.0 還沒指派、但補到區塊結尾當成寬字的部分（跟 namewidth.js 一樣）
CJK_BLOCK_ENDS: Tuple[Tuple[int, int], ...] = (
    (0x9FFD, 0x9FFF),
    (0x2A6DE, 0x2A6FF),
    (0x2B735, 0x2B73F),
    (0x2B81E, 0x2B81F),
    (0x2CEA2, 0x2CEAF),
    (0x2EBE1, 0x2F7FF),
    (0x2FA1E, 0x2FFFD),
    (0x3134B, 0x3FFFD),
)

# emoji 的組成字元（不在 Extended_Pictographic 裡，但只會出現在 emoji 序列）
EMOJI_PARTS: Tuple[Tuple[int, int], ...] = (
    (0x1F1E6, 0x1F1FF),  # 區域指示符（兩個拼成國旗）
    (0x1F3FB, 0x1F3FF),  # 膚色
    (0xFE0F, 0xFE0F),  # emoji 樣式選擇符
    (0x20E3, 0x20E3),  # 鍵帽（1️⃣）
    (0x200D, 0x200D),  # ZWJ（把幾個 emoji 接成一個）
    (0xE0020, 0xE007F),  # tag 字元（英格蘭、蘇格蘭旗）
)

# 雙向控制字元（類別 Cf，寬度 0，但會讓後面的字倒過來顯示）
BIDI_CONTROLS = frozenset([0x061C, 0x200E, 0x200F, *range(0x202A, 0x202F), *range(0x2066, 0x206A)])

_DATA = Path(__file__).resolve().parent / "data" / "extended_pictographic.json"


def _load_ranges() -> List[Tuple[int, int]]:
    d = json.loads(_DATA.read_text(encoding="utf-8"))
    ranges = [(int(a, 16), int(b, 16)) for a, b in d["ranges"]]
    ranges += list(EMOJI_PARTS)
    ranges.sort()
    return ranges


_EMOJI = _load_ranges()
_EMOJI_STARTS = [a for a, _b in _EMOJI]


def _in(ranges, starts, cp: int) -> bool:
    i = bisect_right(starts, cp) - 1
    return i >= 0 and ranges[i][0] <= cp <= ranges[i][1]


def is_emoji(cp: int) -> bool:
    return _in(_EMOJI, _EMOJI_STARTS, cp)


def is_bad_char(cp: int) -> bool:
    if cp in (0x2028, 0x2029) or cp in BIDI_CONTROLS:
        return True
    return unicodedata.category(chr(cp)) in ("Cc", "Co", "Cs", "Cn")


def is_wide(cp: int) -> bool:
    ch = chr(cp)
    if unicodedata.category(ch) != "Cn":
        return unicodedata.east_asian_width(ch) in ("W", "F")
    return any(a <= cp <= b for a, b in CJK_BLOCK_ENDS)


def char_width(cp: int) -> int:
    if unicodedata.category(chr(cp)) in ("Mn", "Me", "Cf"):
        return 0
    return 2 if is_wide(cp) else 1


def strip_white(s: str) -> str:
    a, b = 0, len(s)
    while a < b and ord(s[a]) in WHITE_SPACE:
        a += 1
    while b > a and ord(s[b - 1]) in WHITE_SPACE:
        b -= 1
    return s[a:b]


def name_width(s: str) -> int:
    return sum(char_width(ord(c)) for c in s)


@dataclass(frozen=True)
class NameCheck:
    name: str  # 去掉前後空白之後
    width: int
    reason: Optional[str]  # None = 可以用；too_short、too_long、emoji、bad_char
    char: Optional[str] = None  # 第一個不能用的字元，例 "U+1F42E"


def check(raw: str) -> NameCheck:
    name = strip_white(raw)
    if len(name) > _MAX_SCAN:
        return NameCheck(name, name_width(name[:_MAX_SCAN]), "too_long")
    for c in name:
        cp = ord(c)
        reason = "emoji" if is_emoji(cp) else "bad_char" if is_bad_char(cp) else None
        if reason:
            return NameCheck(name, name_width(name), reason, f"U+{cp:04X}")
    w = name_width(name)
    if w < MIN_WIDTH:
        return NameCheck(name, w, "too_short")
    if w > MAX_WIDTH:
        return NameCheck(name, w, "too_long")
    return NameCheck(name, w, None)
