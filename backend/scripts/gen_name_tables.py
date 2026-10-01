"""產生牧場名規則用的 emoji 區間表：backend/server/data/extended_pictographic.json（協定 2.2 節）。

- 來源：Unicode 13.0 的 emoji-data.txt，取 Extended_Pictographic。跟伺服器 Python 3.10 的 unicodedata（Unicode 13.0）
  同一版。Extended_Pictographic 含官方替未來 emoji 保留的區段，所以之後新增的 emoji 也擋得到。
- 用法（在 backend/ 下）：
    .venv/bin/python scripts/gen_name_tables.py                 # 從 unicode.org 下載
    .venv/bin/python scripts/gen_name_tables.py emoji-data.txt  # 用已下載的檔案
  檔案的 SHA-256 必須跟 EXPECTED_SHA256 一樣，不一樣就停下來（避免拿到別的版本）。
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path

URL = "https://www.unicode.org/Public/13.0.0/ucd/emoji/emoji-data.txt"
EXPECTED_SHA256 = "d2686f400a638c80775d7c662556fb8fa8dd3bbe4aa548d9d31624264c6e1bb1"
OUT = Path(__file__).resolve().parents[1] / "server" / "data" / "extended_pictographic.json"
LINE = re.compile(r"^([0-9A-F]{4,6})(?:\.\.([0-9A-F]{4,6}))?\s*;\s*Extended_Pictographic\b")


def main() -> int:
    if len(sys.argv) > 1:
        raw = Path(sys.argv[1]).read_bytes()
    else:
        with urllib.request.urlopen(URL, timeout=60) as r:  # 固定的 https 網址
            raw = r.read()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != EXPECTED_SHA256:
        print(f"SHA-256 不符：{digest}（預期 {EXPECTED_SHA256}）", file=sys.stderr)
        return 1
    ranges = []
    for line in raw.decode("utf-8").splitlines():
        m = LINE.match(line)
        if not m:
            continue
        a = int(m.group(1), 16)
        b = int(m.group(2) or m.group(1), 16)
        if ranges and a == ranges[-1][1] + 1:
            ranges[-1][1] = b
        else:
            ranges.append([a, b])
    head = {"unicode": "13.0", "property": "Extended_Pictographic", "source": URL, "sha256": EXPECTED_SHA256}
    rows = ",\n  ".join(json.dumps([f"{a:04X}", f"{b:04X}"]) for a, b in ranges)  # 一段一行，好讀也好審
    text = json.dumps(head, ensure_ascii=False, indent=1)[:-2] + ',\n "ranges": [\n  ' + rows + "\n ]\n}\n"
    json.loads(text)  # 確認產出的是合法 JSON
    OUT.write_text(text, encoding="utf-8")
    print(f"{OUT}：{len(ranges)} 段，{sum(b - a + 1 for a, b in ranges)} 個字元")
    return 0


if __name__ == "__main__":
    sys.exit(main())
