"""牛怎麼畫的實測腳本 8：把朝左的 SVG 在向量階段左右翻轉，量「朝右只靠翻轉」跟產生器原生朝右差多少。

用法：python3 docs/research/cow-render/mirror.py <export.mjs 的 svg 資料夾（要有 left、right 兩向）> <輸出資料夾>
- 每張 *_left_* 包一層 scale(-1,1)，viewBox 用同名 *_right_* 的，檔名照朝右的放。
- 之後用 chromium_render.mjs 畫，再用 compare.py 跟原生朝右的 Chromium 圖比（同一個繪圖程式、位置完全對齊，量到的只有真正的差別）。
"""

import re
import sys
from pathlib import Path

src, out = Path(sys.argv[1]), Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
n = 0
for left in sorted(src.glob("*_left_*.svg")):
    right = src / left.name.replace("_left_", "_right_")
    s = left.read_text()
    vb = re.search(r'viewBox="([^"]+)"', right.read_text()).group(1)
    head = re.sub(r'viewBox="[^"]+"', f'viewBox="{vb}"', s[: s.index(">") + 1])
    inner = s[s.index(">") + 1 : s.rindex("</svg>")]
    (out / right.name).write_text(f'{head}<g transform="scale(-1,1)">{inner}</g></svg>')
    n += 1
print("ok", n)
