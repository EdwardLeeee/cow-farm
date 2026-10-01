"""牛怎麼畫的實測腳本 7：字型內建要多大（完整版、常用字子集、可變字型），輸出 results/font-sizes.json。

用法：python3 docs/research/cow-render/fonts.py <下載資料夾>
- 下載官方檔（notofonts/noto-cjk 的 TC 子集 OTF 與可變 OTF、google/fonts 的可變 TTF 與 Noto Sans Thai）。
- 常用字子集 = Big5 第一字面（A140–C67E：符號＋5,401 個常用字）＋三份字串表（design/m2/i18n/*.json）用到的字＋ASCII。
- 子集用 fontTools 的 pyftsubset，保留全部 OpenType 功能（--layout-features='*'）。
- 「壓縮後」用 zlib 第 9 級，近似 APK／IPA 這種 zip 檔裡的大小。
"""

import glob
import json
import subprocess
import sys
import urllib.request
import zlib
from pathlib import Path

from fontTools.ttLib import TTFont

FILES = {
    "NotoSansTC-Regular.otf": "https://github.com/notofonts/noto-cjk/raw/main/Sans/SubsetOTF/TC/NotoSansTC-Regular.otf",
    "NotoSansTC-Bold.otf": "https://github.com/notofonts/noto-cjk/raw/main/Sans/SubsetOTF/TC/NotoSansTC-Bold.otf",
    "NotoSansTC-Black.otf": "https://github.com/notofonts/noto-cjk/raw/main/Sans/SubsetOTF/TC/NotoSansTC-Black.otf",
    "NotoSansTC-VF.otf": "https://github.com/notofonts/noto-cjk/raw/main/Sans/Variable/OTF/Subset/NotoSansTC-VF.otf",
    "NotoSansTC[wght].ttf": "https://github.com/google/fonts/raw/main/ofl/notosanstc/NotoSansTC%5Bwght%5D.ttf",
    "NotoSansThai[wdth,wght].ttf": "https://github.com/google/fonts/raw/main/ofl/notosansthai/NotoSansThai%5Bwdth%2Cwght%5D.ttf",
}
REPO = Path(__file__).resolve().parents[3]


def size(path):
    data = Path(path).read_bytes()
    return {
        "mb": round(len(data) / 1048576, 2),
        "deflate_mb": round(len(zlib.compress(data, 9)) / 1048576, 2),
    }


def subset_chars():
    chars = set(chr(c) for c in range(0x20, 0x7F))
    for p in glob.glob(str(REPO / "design/m2/i18n/*.json")):
        for v in json.load(open(p, encoding="utf-8")).values():
            chars.update(v)
    big5 = set()
    for hi in range(0xA1, 0xC7):
        for lo in list(range(0x40, 0x7F)) + list(range(0xA1, 0xFF)):
            if 0xA140 <= (hi << 8 | lo) <= 0xC67E:
                try:
                    big5.add(bytes([hi, lo]).decode("big5"))
                except UnicodeDecodeError:
                    pass
    used_han = {c for c in chars if 0x3400 <= ord(c) <= 0x9FFF}
    return chars | big5, {
        "big5_level1_and_symbols": len(big5),
        "string_table_han": len(used_han),
        "string_table_han_outside_big5_level1": sorted(used_han - big5),
    }


def main():
    out = Path(sys.argv[1])
    (out / "subset").mkdir(parents=True, exist_ok=True)
    for name, url in FILES.items():
        if not (out / name).exists():
            urllib.request.urlretrieve(url, out / name)
    chars, char_info = subset_chars()
    (out / "subset-chars.txt").write_text("".join(sorted(chars)), encoding="utf-8")
    result = {"subset_chars": len(chars), **char_info, "fonts": {}}
    for name in FILES:
        font = TTFont(out / name, lazy=True)
        info = {
            "version": font["name"].getDebugName(5),
            "outlines": "CFF2" if "CFF2" in font else "CFF" if "CFF " in font else "glyf",
            "axes": [[a.axisTag, a.minValue, a.maxValue] for a in font["fvar"].axes] if "fvar" in font else None,
            "full": size(out / name),
        }
        if "Thai" not in name:
            subprocess.run(
                [
                    "pyftsubset",
                    str(out / name),
                    f"--text-file={out / 'subset-chars.txt'}",
                    "--layout-features=*",
                    f"--output-file={out / 'subset' / name}",
                ],
                check=True,
                stderr=subprocess.DEVNULL,
            )
            info["subset"] = size(out / "subset" / name)
        result["fonts"][name] = info
    dst = Path(__file__).parent / "results" / "font-sizes.json"
    dst.write_text(json.dumps(result, ensure_ascii=False, indent=1))
    print(json.dumps(result, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
