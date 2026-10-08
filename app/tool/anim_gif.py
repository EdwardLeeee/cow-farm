#!/usr/bin/env python3
"""把 test/pages/anim_shots_test.dart 拍的逐格截圖組成 GIF，並挑出設計稿分鏡的時間點跟分鏡圖上下對照。

用法（在 app/ 底下）：python3 tool/anim_gif.py build/shots/<PR 編號>
- 讀 <資料夾>/anim/<動畫 ID>/000.png、001.png…（每格 50 毫秒、390 寬每點 2 像素）。
- 寫 <資料夾>/anim/<動畫 ID>.gif（縮成每點 1 像素，一直重播）。
- 寫 <資料夾>/anim/<動畫 ID>-分鏡對照.png：上面是設計稿的分鏡圖（design/m2/boards/A-動畫/），下面是 app 在同樣時間點的畫面。
- 「…-左半」「…-右半」兩個都有的話，另外寫 <資料夾>/anim/<名字>-左右並排.gif（同一時間的左半、右半並排）。
"""
import glob
import os
import sys

from PIL import Image, ImageDraw

FRAME_S = 0.05
# 設計稿 anims.js 的 keys（秒）；A-11 的 app 截圖從第 4 秒拍起，跟設計稿的 0 秒是同一個姿勢
KEYS = {
    'A-11': [0, 0.8, 1.6, 2.4, 3.2, 4.0],
    'A-07': [0, 0.15, 0.25, 0.38, 0.5],
    'A-10': [0, 0.3, 0.6, 0.9, 1.2, 1.5],
    'A-03': [0, 0.58, 1.1, 1.42, 1.9, 2.3, 3.05, 3.6],
    'A-01': [0, 0.35, 0.7, 1.05, 1.4],
    'A-02': [0, 0.4, 0.8, 1.1, 1.4],
    'A-05': [0, 0.25, 0.55, 0.9, 1.3],
}
BOARDS = os.path.join(os.path.dirname(__file__), '..', '..', 'design', 'm2', 'boards', 'A-動畫')


def side_by_side(root):
    for left in sorted(glob.glob(os.path.join(root, 'anim', '*-左半'))):
        name = os.path.basename(left)[:-len('-左半')]
        right = os.path.join(root, 'anim', f'{name}-右半')
        if not os.path.isdir(left) or not os.path.isdir(right):
            continue
        pairs = zip(sorted(glob.glob(os.path.join(left, '*.png'))), sorted(glob.glob(os.path.join(right, '*.png'))))
        frames = []
        for a, b in pairs:
            a, b = (Image.open(f).convert('RGB') for f in (a, b))
            a, b = (f.resize((f.width // 2, f.height // 2), Image.LANCZOS) for f in (a, b))
            out = Image.new('RGB', (a.width * 2 + 8, a.height), 'white')
            out.paste(a, (0, 0))
            out.paste(b, (a.width + 8, 0))
            frames.append(out)
        if frames:
            gif = os.path.join(root, 'anim', f'{name}-左右並排.gif')
            frames[0].save(gif, save_all=True, append_images=frames[1:], duration=int(FRAME_S * 1000), loop=0)
            print(f'{name}: 左右並排 {len(frames)} 格 → {gif}')


def main(root):
    for d in sorted(glob.glob(os.path.join(root, 'anim', '*'))):
        if not os.path.isdir(d):
            continue
        anim = os.path.basename(d)
        frames = [Image.open(f).convert('RGB') for f in sorted(glob.glob(os.path.join(d, '*.png')))]
        if not frames:
            continue
        small = [f.resize((f.width // 2, f.height // 2), Image.LANCZOS) for f in frames]
        gif = os.path.join(root, 'anim', f'{anim}.gif')
        small[0].save(gif, save_all=True, append_images=small[1:], duration=int(FRAME_S * 1000), loop=0)
        print(f'{anim}: {len(frames)} 格 → {gif}')
        keys = KEYS.get(anim)
        if not keys:
            continue
        picks = [small[min(len(small) - 1, round(t / FRAME_S))] for t in keys]
        w, h = picks[0].size
        gap, label = 12, 28
        strip = Image.new('RGB', (len(picks) * (w + gap) - gap, h + label), 'white')
        draw = ImageDraw.Draw(strip)
        for i, (t, im) in enumerate(zip(keys, picks)):
            x = i * (w + gap)
            strip.paste(im, (x, label))
            draw.text((x + 4, 6), f'app t={t:g}s', fill='black')
        board = glob.glob(os.path.join(BOARDS, f'M2-{anim}-*-分鏡-390.png'))
        if board:
            b = Image.open(board[0]).convert('RGB')
            b = b.resize((strip.width, round(b.height * strip.width / b.width)), Image.LANCZOS)
            out = Image.new('RGB', (strip.width, b.height + 16 + strip.height), 'white')
            out.paste(b, (0, 0))
            out.paste(strip, (0, b.height + 16))
        else:
            out = strip
        path = os.path.join(root, 'anim', f'{anim}-分鏡對照.png')
        out.save(path)
        print(f'{anim}: 分鏡對照 → {path}')
    side_by_side(root)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('用法：python3 tool/anim_gif.py <截圖資料夾>')
    main(sys.argv[1])
