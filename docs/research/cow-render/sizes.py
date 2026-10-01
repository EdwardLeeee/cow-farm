"""牛怎麼畫的實測腳本 9：各方案要放進 app 的牛有幾張、多大，輸出 results/cow-asset-sizes.json。

用法：python3 docs/research/cow-render/sizes.py <vec 資料夾 K=1> <K=4> <K=8>
- 資料夾是 vector_graphics_compiler（關掉三個最佳化）編好的 .vec，來源是 export.mjs 的兩個朝向。
- 「需要朝右的品種」是 mirror.py＋compare.py 量到翻轉後跟原生朝右不一樣的 12 種；其他 12 種朝右直接翻轉朝左的圖。
- MB 是原始大小（iPhone 安裝後解開放的大小）；deflate 是壓縮後（下載大小、Android APK 裡的大小）。
"""

import json
import sys
import zlib
from pathlib import Path

NEED_RIGHT = {
    "starry",
    "honey",
    "goldenEar",
    "buffalo",
    "wagyu",
    "velvetBlack",
    "shaggyBuffalo",
    "fluffyWagyu",
    "glossBlack",
    "chocolate",
    "whiteWagyu",
    "angus",
}


def tally(files):
    return {
        "files": len(files),
        "mb": round(sum(f.stat().st_size for f in files) / 1048576, 2),
        "deflate_mb": round(sum(len(zlib.compress(f.read_bytes(), 9)) for f in files) / 1048576, 2),
    }


result = {}
for k, d in zip((1, 4, 8), sys.argv[1:4]):
    files = sorted(Path(d).glob("*.vec"))
    left = [f for f in files if "_left_" in f.name]
    right_needed = [f for f in files if "_right_" in f.name and f.name.split("_")[0] in NEED_RIGHT]
    result[f"K={k}"] = {
        "left_only": tally(left),
        "left_plus_needed_right": tally(left + right_needed),
        "both": tally(files),
    }
dst = Path(__file__).parent / "results" / "cow-asset-sizes.json"
dst.write_text(json.dumps({"need_right": sorted(NEED_RIGHT), **result}, ensure_ascii=False, indent=1))
print(json.dumps(result, ensure_ascii=False, indent=1))
