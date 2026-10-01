"""產生 app 的牧場名規則表（lib/util/name_tables.g.dart），讓 app 跟伺服器算得一樣（協定 2.2 節、D23）。

用法（在 app/ 下）：python3 tool/gen_name_tables.py
- 一定要用 Python 3.10：內建的 unicodedata 是 Unicode 13.0，跟伺服器一樣。版本不對就停下來。
- 不自己重寫規則：直接 import 伺服器的 backend/server/ranchname.py，把 0–U+10FFFF 每個字元丟進它的函式，
  整理成四張區間表（寬度 0、寬度 2、emoji、不能用的字元），連同 White_Space 和長度上限一起寫成 Dart。
- 驗證：test/ranch_name_test.dart 拿伺服器的測試向量（backend/server/data/name_cases.json）逐筆比。
"""

import sys
import unicodedata
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(APP.parent / "backend"))

from server import ranchname  # noqa: E402

OUT = APP / "lib" / "util" / "name_tables.g.dart"


def ranges(pred):
    """0–U+10FFFF 裡 pred 為真的字元，合併成 (起, 迄) 區間。"""
    out = []
    start = None
    for cp in range(0x110000):
        if pred(cp):
            if start is None:
                start = cp
        elif start is not None:
            out.append((start, cp - 1))
            start = None
    if start is not None:
        out.append((start, 0x10FFFF))
    return out


def dart_ranges(name, doc, rs):
    body = ",\n".join(f"  0x{a:04X}, 0x{b:04X}" for a, b in rs)
    return f"/// {doc}（{len(rs)} 段，兩個數字一組：起、迄）。\nconst {name} = <int>[\n{body},\n];\n"


def main():
    if sys.version_info[:2] != (3, 10) or unicodedata.unidata_version != "13.0.0":
        sys.exit(
            f"要用 Python 3.10（Unicode 13.0），現在是 {sys.version.split()[0]}（Unicode {unicodedata.unidata_version}）"
        )
    tables = [
        (
            "kZeroWidth",
            "寬度 0：類別 Mn、Me、Cf（例：泰文的上下標記號）",
            ranges(lambda c: ranchname.char_width(c) == 0),
        ),
        (
            "kDoubleWidth",
            "寬度 2：East Asian Width 是 W、F，加上漢字區塊補到結尾",
            ranges(lambda c: ranchname.char_width(c) == 2),
        ),
        ("kEmoji", "emoji：Extended_Pictographic 和 emoji 序列的組成字元", ranges(ranchname.is_emoji)),
        ("kBadChar", "不能用的字元：Cc、Co、Cs、Cn、中間的換行換段、雙向控制字元", ranges(ranchname.is_bad_char)),
    ]
    white = sorted(ranchname.WHITE_SPACE)
    lines = [
        "// dart format off",
        "// 由 tool/gen_name_tables.py 用伺服器的 backend/server/ranchname.py 逐字產生（Python 3.10、Unicode 13.0），不要手改。",
        "// 規則改了以後，在 app/ 跑 `python3 tool/gen_name_tables.py`。",
        "",
        "/// 名字的顯示寬度下限、上限（協定 2.2 節）。",
        f"const kNameMinWidth = {ranchname.MIN_WIDTH};",
        f"const kNameMaxWidth = {ranchname.MAX_WIDTH};",
        "",
        "/// 去掉前後空白後超過這麼多字元，就不逐字檢查、直接算太長（伺服器的 _MAX_SCAN）。",
        f"const kNameMaxScan = {ranchname._MAX_SCAN};",
        "",
        "/// 前後要去掉的空白：Unicode 的 White_Space。",
        "const kWhiteSpace = <int>{" + ", ".join(f"0x{c:04X}" for c in white) + "};",
        "",
    ]
    for name, doc, rs in tables:
        lines.append(dart_ranges(name, doc, rs))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines))
    print(f"產生 {OUT.relative_to(APP)}：" + "、".join(f"{n} {len(rs)} 段" for n, _d, rs in tables))


if __name__ == "__main__":
    main()
