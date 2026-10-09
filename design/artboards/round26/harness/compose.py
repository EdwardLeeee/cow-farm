# 第 26 輪草稿：raw/ 的截圖（make.mjs 出的，單張 DPR 2、總覽 DPR 1.5）存到 round26/（進 git 的圖）。
# 存全彩（RGB），不轉 256 色：轉 256 色時小圖示會變色（第 12 輪發現的：牛奶瓶蓋從藍色變綠），會看錯顏色。
# 用法（在 design/artboards/round26 底下跑）：python3 harness/compose.py
import glob
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

files = sorted(glob.glob(os.path.join(HERE, 'raw', 'R26-*.png')))
if not files:
    sys.exit('raw/ 裡沒有截圖：先跑 node harness/make.mjs')
for f in files:
    out = os.path.join(HERE, os.path.basename(f))
    Image.open(f).convert('RGB').save(out, optimize=True)
    im = Image.open(out)
    print(f'{os.path.basename(out)}  {im.width}×{im.height}  {os.path.getsize(out) // 1024} KB')
