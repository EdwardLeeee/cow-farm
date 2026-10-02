#!/usr/bin/env python3
"""把 app 的截圖跟設計稿 boards 並排（左邊設計稿、右邊 app），給 PR 比對用。

用法（在 app/ 底下）：python3 tool/shots_compare.py build/shots/<PR 編號> [語言，預設全部]
讀 <資料夾>/<語言>/<頁面 ID>-<寬>.png（test/pages/shots_test.dart 拍的），
寫 <資料夾>/compare/<語言>/<頁面 ID>-<寬>.png。
整頁狀態對到 boards 的 M2-<頁面 ID>-…-<寬>.png；局部狀態對到那個畫面的局部狀態表 M2-<畫面>-表-…-<寬>.png。
設計稿只有繁中；英文、泰文的截圖一樣跟繁中的設計稿並排，看版面。
"""
import glob
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOARDS = os.path.join(APP, '..', 'design', 'm2', 'boards')
FONT = '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'  # 跟 design/m2/harness/compose.py 一樣
BG, INK = (255, 249, 239), (75, 51, 38)
PAD, HEAD = 32, 110  # boards 的邊界與標題列高度（compose.py 的 board_full）


def font(size):
    try:
        return ImageFont.truetype(FONT, size, index=3)
    except OSError:
        return ImageFont.load_default()


# 後來加的局部狀態放在另一張狀態表（設計稿 s03.js 的 draft(...)、popDraft(...)：board '新文案-狀態表'、'名片位置-狀態表'）
EXTRA_TABLES = {
    'S03-16': '新文案-狀態表', 'S03-17': '新文案-狀態表', 'S03-18': '新文案-狀態表',
    'S03-20': '名片位置-狀態表', 'S03-21': '名片位置-狀態表',
    'S18-15': '空紀錄-狀態表',
}


def find_board(page_id, width):
    """整頁狀態的設計稿；沒有就用那個畫面的局部狀態表。回傳 (路徑, 是不是整頁)。"""
    full = glob.glob(os.path.join(BOARDS, '*', f'M2-{page_id}-*-{width}.png'))
    if full:
        return full[0], True
    screen = page_id.split('-')[0]
    if page_id in EXTRA_TABLES:
        extra = glob.glob(os.path.join(BOARDS, '*', f'M2-{screen}-{EXTRA_TABLES[page_id]}-{width}.png'))
        if extra:
            return extra[0], False
    table = glob.glob(os.path.join(BOARDS, '*', f'M2-{screen}-表-*-{width}.png'))
    return (table[0], False) if table else (None, False)


def compose(shot_path, out_path, page_id, width, lang):
    shot = Image.open(shot_path).convert('RGB')
    board_path, is_full = find_board(page_id, width)
    if not board_path:
        # 360、320 沒有設計稿（只量測）：只放 app 那張，標題和說明各一行
        W, H = PAD + shot.width + PAD, HEAD + shot.height + PAD
        im = Image.new('RGB', (W, H), BG)
        d = ImageDraw.Draw(im)
        d.text((PAD, 20), f'app  {page_id}  {lang}  {width}', font=font(34), fill=INK)
        d.text((PAD, 72), '沒有設計稿（360、320 只量測）', font=font(20), fill=INK)
        im.paste(shot, (PAD, HEAD))
        d.rectangle([PAD - 2, HEAD - 2, PAD + shot.width + 1, HEAD + shot.height + 1], outline=INK, width=2)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        im.save(out_path, optimize=True)
        return None
    board = Image.open(board_path).convert('RGB')
    bw, bh = board.size
    # 整頁：app 截圖跟設計稿裡的手機畫面底部對齊（設計稿的手機畫面在最下面，下方留 PAD）
    shot_top = bh - PAD - shot.height if is_full and bh - PAD - shot.height >= HEAD else HEAD
    W = bw + PAD + shot.width + PAD
    H = max(bh, shot_top + shot.height + PAD)
    im = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(im)
    im.paste(board, (0, 0))
    x = bw + PAD
    d.text((x, 20), f'app  {page_id}  {lang}', font=font(34), fill=INK)
    d.text((x, 72), os.path.basename(board_path), font=font(20), fill=INK)
    im.paste(shot, (x, shot_top))
    d.rectangle([x - 2, shot_top - 2, x + shot.width + 1, shot_top + shot.height + 1], outline=INK, width=2)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    im.save(out_path, optimize=True)
    return board_path


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    root = sys.argv[1]
    langs = [sys.argv[2]] if len(sys.argv) > 2 else sorted(
        d for d in os.listdir(root) if d != 'compare' and os.path.isdir(os.path.join(root, d)))
    n = 0
    for lang in langs:
        for shot in sorted(glob.glob(os.path.join(root, lang, '*.png'))):
            m = re.fullmatch(r'(.+)-(\d+)\.png', os.path.basename(shot))
            if not m:
                continue
            page_id, width = m[1], m[2]
            board = compose(shot, os.path.join(root, 'compare', lang, os.path.basename(shot)), page_id, width, lang)
            print(f'{lang} {page_id} {width}: {os.path.relpath(board, BOARDS) if board else "沒有設計稿"}')
            n += 1
    print(f'並排了 {n} 張 → {os.path.join(root, "compare")}')


if __name__ == '__main__':
    main()
