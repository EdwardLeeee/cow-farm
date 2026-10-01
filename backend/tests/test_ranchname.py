"""牧場名的規則（D23；協定 2.2 節；不需要資料庫）。

- 雙寬的範圍跟設計稿 design/m2/src/js/namewidth.js 逐字比對（app、i18ncheck 用同一套）。
- 測試向量 backend/server/data/name_cases.json 給 app 和 i18ncheck 拿去跑，確認三邊算得一樣。
  規則改了要重產：COWFARM_WRITE_NAME_CASES=1 .venv/bin/python -m pytest tests/test_ranchname.py
"""

from __future__ import annotations

import json
import os
import re
import unicodedata
from pathlib import Path

import pytest

from server import ranchname as R

CASES_FILE = Path(R.__file__).resolve().parent / "data" / "name_cases.json"
NAMEWIDTH_JS = Path(__file__).resolve().parents[2] / "design" / "m2" / "src" / "js" / "namewidth.js"

# (名字, 說明)；答案由 R.check 算，寫進 name_cases.json
CASES = [
    ("晨光河畔牧場", "中文 6 個字，寬度 12"),
    ("晨光河畔牧場小屋", "8 個中文字，剛好 16"),
    ("晨光河畔牧場小屋X", "17，太長"),
    ("牛", "1 個中文字 = 2，最短"),
    ("A", "1，太短"),
    ("", "空的"),
    ("   ", "全是空白：去掉後是空的"),
    ("\u3000牛\u3000", "前後的全形空白也會去掉"),
    (" 小花 ", "前後空白去掉，存「小花」"),
    ("MorningRiverFarm", "16 個英文字母"),
    ("Morning River", "中間的空白保留"),
    ("Morning River Farm", "18，太長"),
    ("ฟาร์ม", "泰文：์ 是 Mn 算 0，寬度 4"),
    ("น้ำใจฟาร์ม", "泰文聲調記號算 0"),
    ("ฟาร์มสุขใจ", "泰文 8"),
    ("ＡＢ", "全形英文字母各算 2"),
    ("カフェ牧場", "日文假名算 2"),
    ("한글목장", "韓文算 2"),
    ("e\u0301e\u0301", "組合用的重音符號（Mn）算 0；不做正規化"),
    ("Ünïcödé", "預先組好的字母算 1"),
    ("#1牧場", "# 和數字可以用"),
    ("☆牧場", "☆（U+2606）不在 Extended_Pictographic，可以用"),
    ("★牧場", "★（U+2605）在 Extended_Pictographic，算 emoji"),
    ("♪牧場", "♪（U+266A）也在 Extended_Pictographic，算 emoji"),
    ("©牧場", "© 也算 emoji"),
    ("小花牧場🐮", "emoji"),
    ("1️⃣牧場", "鍵帽 emoji：數字可以用，但 U+FE0F、U+20E3 不行"),
    ("🇹🇼牧場", "國旗：區域指示符"),
    ("牧\u200d場", "ZWJ 只用在 emoji 序列，算 emoji"),
    ("牧\u200b場", "零寬空白是 Cf，算 0，可以用"),
    ("牧場\ufe0e", "U+FE0E（文字樣式）是 Mn，算 0，可以用"),
    ("牧\u202e場", "雙向控制字元 RLO：會讓後面的 #編號倒過來"),
    ("牧\n場", "換行（Cc）"),
    ("牧\u2028場", "中間的行分隔字元"),
    ("\ue000牧場", "私用區（Co）"),
    ("\u0378牧場", "Unicode 13.0 還沒指派的字元（Cn）"),
    ("\ud800牧場", "代理字元（Cs；只會從 JSON 的 \\ud800 跳脫來）"),
]


def _json_str(s: str) -> str:
    """JSON 字串；看不見的字元寫成 \\uXXXX，其他照原樣（中文、泰文好讀）。"""
    out = ['"']
    for ch in s:
        cp = ord(ch)
        cat = unicodedata.category(ch)
        if ch in '"\\':
            out.append("\\" + ch)
        elif cat in ("Cc", "Cf", "Zl", "Zp", "Co", "Cs", "Cn") or (cat == "Zs" and ch != " ") or cp in (0xFE0E, 0xFE0F):
            if cp > 0xFFFF:
                v = cp - 0x10000
                out.append(f"\\u{0xD800 + (v >> 10):04x}\\u{0xDC00 + (v & 0x3FF):04x}")
            else:
                out.append(f"\\u{cp:04x}")
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def _expected():
    rows = []
    for name, note in CASES:
        k = R.check(name)
        rows.append({"name": name, "ok": k.reason is None, "reason": k.reason, "width": k.width, "note": note})
    return rows


def _write_cases_file(rows) -> None:
    lines = []
    for r in rows:
        reason = json.dumps(r["reason"])
        ok = "true" if r["ok"] else "false"
        lines.append(
            f'  {{"name": {_json_str(r["name"])}, "ok": {ok}, "reason": {reason}, "width": {r["width"]}, '
            f'"note": {json.dumps(r["note"], ensure_ascii=False)}}}'
        )
    head = (
        '{\n "_說明": "牧場名規則的測試向量（協定 2.2 節）。name 送進規則，ok、reason、width 是伺服器的答案；'
        'app 和設計稿的 i18ncheck 照同一套規則算，應該得到一樣的結果。由 backend/tests/test_ranchname.py 產生。",\n'
        ' "unicode": "13.0",\n "cases": [\n'
    )
    CASES_FILE.write_text(head + ",\n".join(lines) + "\n ]\n}\n", encoding="utf-8")


def test_name_cases_file():
    rows = _expected()
    if os.environ.get("COWFARM_WRITE_NAME_CASES") == "1":
        _write_cases_file(rows)
    data = json.loads(CASES_FILE.read_text(encoding="utf-8"))
    assert data["cases"] == rows, "規則或案例改了：用 COWFARM_WRITE_NAME_CASES=1 重產 name_cases.json"


@pytest.mark.parametrize(
    "name,reason,width,char,stored",
    [
        ("晨光河畔牧場", None, 12, None, "晨光河畔牧場"),
        ("\u3000牛\u3000", None, 2, None, "牛"),
        ("A", "too_short", 1, None, "A"),
        ("Morning River Farm", "too_long", 18, None, "Morning River Farm"),
        ("小花牧場🐮", "emoji", 10, "U+1F42E", "小花牧場🐮"),
        ("1️⃣牧場", "emoji", 5, "U+FE0F", "1️⃣牧場"),
        ("牧\u202e場", "bad_char", 4, "U+202E", "牧\u202e場"),
        ("A🐮", "emoji", 3, "U+1F42E", "A🐮"),  # 先查字元再查長度：太短也回報 emoji
    ],
)
def test_check(name, reason, width, char, stored):
    k = R.check(name)
    assert (k.reason, k.width, k.char, k.name) == (reason, width, char, stored)


def test_huge_input_is_too_long_without_scanning_all():
    k = R.check("牛" * 100_000)
    assert k.reason == "too_long"


def test_wide_matches_namewidth_js():
    """雙寬的範圍跟設計稿 namewidth.js 的 WIDE 逐字相同（0–U+10FFFF 全部比）。"""
    if not NAMEWIDTH_JS.exists():
        pytest.skip(f"找不到 {NAMEWIDTH_JS}")
    src = NAMEWIDTH_JS.read_text(encoding="utf-8")
    body = src[src.index("const WIDE") : src.index("']', 'u')")]
    js = set()
    for a, b in re.findall(r"\\u\{([0-9A-F]+)\}(?:-\\u\{([0-9A-F]+)\})?", body):
        js.update(range(int(a, 16), int(b or a, 16) + 1))
    diff = [cp for cp in range(0x110000) if R.is_wide(cp) != (cp in js)]
    assert not diff, [f"U+{cp:04X}" for cp in diff[:20]]


def test_wide_is_unicode13_plus_cjk_block_ends():
    """已指派的字照 Unicode 13.0 的 East Asian Width（W、F）；還沒指派的只有漢字區塊的結尾算寬。"""
    assert unicodedata.unidata_version == "13.0.0"  # 換 Python 版本會變：要跟 app、namewidth.js 一起改
    for cp in range(0x110000):
        ch = chr(cp)
        if unicodedata.category(ch) != "Cn":
            assert R.is_wide(cp) == (unicodedata.east_asian_width(ch) in ("W", "F")), f"U+{cp:04X}"
        else:
            assert R.is_wide(cp) == any(a <= cp <= b for a, b in R.CJK_BLOCK_ENDS), f"U+{cp:04X}"


def test_emoji_table():
    data = json.loads((Path(R.__file__).resolve().parent / "data" / "extended_pictographic.json").read_text())
    assert data["unicode"] == "13.0" and data["property"] == "Extended_Pictographic"
    assert R.is_emoji(0x1F42E) and R.is_emoji(0x00A9) and R.is_emoji(0x1FC00)  # 🐮、©、替未來保留的區段
    assert not R.is_emoji(0x2606) and not R.is_emoji(ord("#")) and not R.is_emoji(ord("1"))  # ☆、#、數字


def test_strip_white_only_unicode_white_space():
    assert R.strip_white("\t\u00a0\u3000 牛 \u2003\n") == "牛"
    assert R.strip_white("\u200b牛\u200b") == "\u200b牛\u200b"  # 零寬空白不是 White_Space，不會去掉
    assert R.strip_white("\x1c牛") == "\x1c牛"  # Python 的 str.strip() 會去掉 \x1c，這裡不會（它是控制字元，會被擋）
