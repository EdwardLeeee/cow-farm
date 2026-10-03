#!/usr/bin/env python3
# M2 合成：把 raw/ 的 DPR 3 截圖做成加標籤的設計稿（DPR 2），外加每個畫面的「局部狀態表」、總覽與量測摘要。
# 用法：python3 harness/compose.py [畫面前綴，例如 S03]
# 輸出：boards/<畫面>/M2-<頁面 ID>-<畫面名>-<狀態名>-<寬>.png、M2-<畫面>-表-…、M2-<畫面>-00-…-總覽.png；measure/summary.md
import json, os, re, sys, glob
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW, OUT, MEAS = os.path.join(ROOT, 'raw'), os.path.join(ROOT, 'boards'), os.path.join(ROOT, 'measure')
FONT = '/usr/share/fonts/opentype/noto/NotoSansCJK-{}.ttc'
def font(size, w='Bold'): return ImageFont.truetype(FONT.format(w), size, index=3)
INK, MUTED, BG, RED = (75, 51, 38), (138, 111, 96), (255, 249, 239), (229, 72, 77)
NOTE = (194, 84, 27)  # 註解的字（給看圖的人，不是畫面的一部分）
DEVNAME = {430: '430 寬（大手機，例 iPhone 14 Pro Max）', 390: '390 寬（一般手機，例 iPhone 14）'}
SCREEN_ORDER = ['G'] + [f'S{i:02d}' for i in range(1, 22)]

def safe(s):
    s = s.replace('/', '／').replace(':', '：').replace(' ', '')
    return re.sub(r'[\\*?"<>|]', '', s)

def load_meta():
    metas = []
    for j in glob.glob(os.path.join(RAW, '*.json')):
        if os.path.basename(j).startswith('_'): continue
        with open(j, encoding='utf-8') as f: m = json.load(f)
        m['_png'] = j[:-5] + '.png'
        metas.append(m)
    return metas

def rounded(img, r):
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], r, fill=255)
    out = Image.new('RGBA', img.size, (0, 0, 0, 0)); out.paste(img, (0, 0), mask)
    return out

# 設計用的顏色：src/ 的 CSS、JS（圖示、場景、牛、卡車、色表）裡寫死的不透明顏色（#RGB、#RRGGBB、rgb()、alpha 1 的 rgba()）
_DESIGN = None
def design_colors():
    global _DESIGN
    if _DESIGN is None:
        cols = set()
        src = os.path.join(ROOT, 'src')
        for f in glob.glob(os.path.join(src, '**', '*.css'), recursive=True) + glob.glob(os.path.join(src, '**', '*.js'), recursive=True):
            s = open(f, encoding='utf-8').read()
            for m in re.finditer(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b', s):
                h = m.group(1) if len(m.group(1)) == 6 else ''.join(c * 2 for c in m.group(1))
                cols.add(tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)))
            for m in re.finditer(r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)', s):
                if m.group(4) is None or float(m.group(4)) >= 1: cols.add(tuple(int(m.group(i)) for i in (1, 2, 3)))
        _DESIGN = cols
    return _DESIGN

FIX_MIN, FIX_MAX = 6, 160
def nearest(im, pal):
    # 每個像素換成調色盤裡最近的顏色（RGB 距離）。不用 Pillow 的 quantize(palette=…)：它找顏色時精度比較低，平均會差 2
    a = np.asarray(im).reshape(-1, 3)
    keys = (a[:, 0].astype(np.int32) << 16) | (a[:, 1].astype(np.int32) << 8) | a[:, 2]
    uk, inv = np.unique(keys, return_inverse=True)
    uc = np.stack([(uk >> 16) & 255, (uk >> 8) & 255, uk & 255], axis=1).astype(np.int32)
    P = np.array(pal, dtype=np.int32).reshape(-1, 3)
    idx = np.empty(len(uc), dtype=np.uint8)
    for s in range(0, len(uc), 2048):
        d = ((uc[s:s + 2048, None, :] - P[None, :, :]) ** 2).sum(axis=2)
        idx[s:s + 2048] = d.argmin(axis=1)
    q = Image.fromarray(idx[inv].reshape(im.height, im.width), mode='P')
    q.putpalette(list(pal) + list(pal[:3]) * (256 - len(pal) // 3))  # 沒用完的位置重複第一個顏色
    return q

def flat_counts(im):
    # 每種顏色有幾個「整塊」的像素：上下左右斜角 8 個鄰居都是同一個顏色。漸層的一列、反鋸齒的邊碰巧等於某個設計顏色時不算，
    # 不然 CSS 加了新顏色，不相干的設計稿也會因為幾個碰巧同色的像素換調色盤
    a = np.asarray(im).astype(np.int32)
    k = (a[:, :, 0] << 16) | (a[:, :, 1] << 8) | a[:, :, 2]
    c = k[1:-1, 1:-1]
    same = np.ones(c.shape, dtype=bool)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy or dx: same &= k[1 + dy:k.shape[0] - 1 + dy, 1 + dx:k.shape[1] - 1 + dx] == c
    keys, n = np.unique(c[same], return_counts=True)
    return {((int(v) >> 16) & 255, (int(v) >> 8) & 255, int(v) & 255): int(m) for v, m in zip(keys, n)}

def save(im, path):
    # 256 色的 PNG（沒有抖色），檔案小很多。調色盤分兩部分（ceo 2026-10-03 選 B）：
    # 1. 圖上整塊用到的設計顏色（整塊的像素至少 FIX_MIN 個，最多 FIX_MAX 種，用得多的先放）原封不動放進調色盤，
    #    小圖示、彩紙這種小面積的顏色不會被換成相近的顏色（以前 S11-01 的藍、綠彩紙會變成薄荷綠、米色）；
    # 2. 剩下的位置照舊用 median cut 自動挑（漸層、反鋸齒的邊）。
    # 每個像素再換成最近的顏色。跟以前（median cut 256 色）比，每張的平均誤差、差很多的像素都比較少
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im = im.convert('RGB')
    count = flat_counts(im)
    fixed = [c for n, c in sorted(((count[c], c) for c in design_colors() if count.get(c, 0) >= FIX_MIN), reverse=True)[:FIX_MAX]]
    auto = im.quantize(colors=256 - len(fixed), method=Image.Quantize.MEDIANCUT)
    ap = auto.getpalette()
    used = sorted({i for _, i in auto.getcolors(256)})
    pal = [v for c in fixed for v in c] + [v for i in used for v in ap[i * 3:i * 3 + 3]]
    nearest(im, pal).save(path, optimize=True)

def dpr2(png):
    im = Image.open(png).convert('RGB')
    return im.resize((round(im.width * 2 / 3), round(im.height * 2 / 3)), Image.LANCZOS)

NO_START = set('，。、）」：；！？』')  # 這些標點不放在行首
def wrap_text(draw, text, f, width):
    lines, cur = [], ''
    for ch in text:
        if draw.textlength(cur + ch, font=f) > width and cur and ch not in NO_START:
            lines.append(cur); cur = ch
        else:
            cur += ch
    if cur: lines.append(cur)
    return lines

def header(draw, x, y, title, sub, tags=(), maxw=None):
    # maxw：標題加標籤最多這麼寬；太長就把標題的字縮小（最小 24），不讓右邊被切掉
    size = 34
    tagw = (16 + sum(draw.textlength(t, font=font(22)) + 24 for t in tags) + 10 * (len(tags) - 1)) if tags else 0
    if maxw:
        while size > 24 and draw.textlength(title, font=font(size, 'Black')) + tagw > maxw: size -= 2
    draw.text((x, y + (34 - size)), title, font=font(size, 'Black'), fill=INK)
    tx = x + draw.textlength(title, font=font(size, 'Black')) + 16
    for t in tags:
        w = draw.textlength(t, font=font(22)) + 24
        draw.rounded_rectangle([tx, y + 6, tx + w, y + 42], 14, fill=(255, 212, 94), outline=INK, width=3)
        draw.text((tx + 12, y + 9), t, font=font(22), fill=INK)
        tx += w + 10
    draw.text((x, y + 52), sub, font=font(22, 'Regular'), fill=MUTED)

def board_full(m, img, screen_dir):
    pad, head = 32, 110
    ph = rounded(img, 60)
    # 有註解的狀態：標題列下面多一到兩行「註：…」
    notes = wrap_text(ImageDraw.Draw(Image.new('RGB', (10, 10))), '註：' + m['note'], font(20), ph.width) if m.get('note') else []
    if notes: head += 4 + 30 * len(notes)
    W, H = ph.width + pad * 2, head + ph.height + pad
    im = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(im)
    tags = ['長頁'] if m.get('tall') else []
    header(d, pad, 20, f"M2-{m['id']}  {m['name']}", f"{m['screen']} {m['screenName']}　·　{DEVNAME[m['width']]}", tags, maxw=ph.width)
    for j, line in enumerate(notes):
        d.text((pad, 104 + 30 * j), line, font=font(20), fill=NOTE)
    im.paste(ph, (pad, head), ph)
    d.rounded_rectangle([pad - 3, head - 3, pad + ph.width + 2, head + ph.height + 2], 62, outline=INK, width=4)
    name = f"M2-{m['id']}-{safe(m['screenName'])}-{safe(m['name'])}-{m['width']}.png"
    save(im, os.path.join(screen_dir, name))
    return name

def sheet_parts(screen, sname, parts, w, screen_dir, board=None):
    # board：另外成一張的狀態表（例如「按下-狀態表」），檔名和左上角的標籤都是 M2-<畫面>-<board>-<寬>
    if not parts: return None
    pad, gap, head = 32, 28, 110
    tiles = []
    for m in parts:
        img = dpr2(m['_png'])
        cap = f"{m['id']}  {m['name']}"
        tiles.append((m, img, cap))
    colw = max(t[1].width for t in tiles)
    ncol = 2 if colw <= 900 and len(tiles) > 1 else 1
    # 每格的標題太長就換行（一行 34 高），不讓它超出欄寬
    tmp = ImageDraw.Draw(Image.new('RGB', (10, 10)))
    tiles = [(m, img, wrap_text(tmp, cap, font(26), colw), wrap_text(tmp, '註：' + m['note'], font(20), colw) if m.get('note') else []) for m, img, cap in tiles]
    cols = [[] for _ in range(ncol)]; hs = [0] * ncol
    for t in tiles:
        i = hs.index(min(hs)); cols[i].append(t); hs[i] += 60 + 34 * (len(t[2]) - 1) + 28 * len(t[3]) + t[1].height + gap
    W = pad * 2 + ncol * colw + (ncol - 1) * gap
    H = head + max(hs) + pad
    im = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(im)
    if board: header(d, pad, 20, f"M2-{screen}-{board}-{w}", f"{screen} {sname}　·　{DEVNAME[w]}", ['狀態表'])
    else: header(d, pad, 20, f"M2-{screen}  局部狀態表", f"{screen} {sname}　·　{DEVNAME[w]}　·　只差一小塊的狀態並排在一起", ['局部'])
    for ci, col in enumerate(cols):
        x, y = pad + ci * (colw + gap), head
        for m, img, cap, nt in col:
            for j, line in enumerate(cap):
                d.text((x, y + 8 + 34 * j), line, font=font(26), fill=INK)
            for j, line in enumerate(nt):
                d.text((x, y + 10 + 34 * len(cap) + 28 * j), line, font=font(20), fill=NOTE)
            y += 50 + 34 * (len(cap) - 1) + 28 * len(nt)
            im.paste(img, (x, y))
            d.rectangle([x - 2, y - 2, x + img.width + 1, y + img.height + 1], outline=(200, 184, 168), width=2)
            y += img.height + gap
    name = f"M2-{screen}-{safe(board)}-{w}.png" if board else f"M2-{screen}-表-{safe(sname)}-局部狀態-{w}.png"
    save(im, os.path.join(screen_dir, name))
    return name

def overview(screen, sname, fulls, parts, screen_dir):
    # 390 寬的整頁狀態縮圖＋局部狀態縮圖；長頁只取第一個畫面
    tw, cols, gap, pad, head = 300, 4, 26, 32, 110
    tiles = []
    for m in fulls:
        img = Image.open(m['_png']).convert('RGB')
        if m.get('tall'): img = img.crop((0, 0, img.width, round(img.width * 844 / 390)))
        img = img.resize((tw, round(img.height * tw / img.width)), Image.LANCZOS)
        tiles.append((m, img))
    for m in parts:
        img = Image.open(m['_png']).convert('RGB')
        img = img.resize((tw, round(img.height * tw / img.width)), Image.LANCZOS)
        tiles.append((m, img))
    rows = [tiles[i:i + cols] for i in range(0, len(tiles), cols)]
    rh = [max(t[1].height for t in r) + 74 for r in rows]
    W = pad * 2 + cols * tw + (cols - 1) * gap
    H = head + sum(rh) + gap * (len(rows) - 1) + pad
    im = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(im)
    header(d, pad, 20, f"M2-{screen}-00  {sname}　總覽", f"390 寬　·　{len(fulls)} 個整頁狀態、{len(parts)} 個局部狀態（局部的細節看狀態表）")
    y = head
    for r, h in zip(rows, rh):
        x = pad
        for m, img in r:
            label = f"{m['id']}{'（局部）' if m['type'] == 'part' else '（長頁）' if m.get('tall') else ''}"
            d.text((x, y), label, font=font(22), fill=INK)
            nm = m['name'] if len(m['name']) <= 13 else m['name'][:12] + '…'
            d.text((x, y + 30), nm, font=font(20, 'Regular'), fill=MUTED)
            im.paste(img, (x, y + 68))
            d.rectangle([x - 1, y + 67, x + img.width, y + 68 + img.height], outline=(200, 184, 168), width=2)
            x += tw + gap
        y += h + gap
    name = f"M2-{screen}-00-{safe(sname)}-總覽.png"
    save(im, os.path.join(screen_dir, name))
    return name

def index_overview(metas):
    # 全部畫面總覽：每個畫面挑第一個整頁狀態（390 寬），G 用第一張局部
    tw, cols, gap, pad, head = 240, 7, 22, 32, 118
    picks = []
    for sc in SCREEN_ORDER:
        ms = sorted([m for m in metas if m.get('screen') == sc and m.get('width') == 390 and os.path.exists(m['_png'])], key=lambda m: m['id'])
        full = [m for m in ms if m['type'] == 'full'] or ms
        if full: picks.append(full[0])
    tiles = []
    for m in picks:
        img = Image.open(m['_png']).convert('RGB')
        if m.get('tall'): img = img.crop((0, 0, img.width, round(img.width * 844 / 390)))
        img = img.resize((tw, round(img.height * tw / img.width)), Image.LANCZOS)
        tiles.append((m, img))
    rows = [tiles[i:i + cols] for i in range(0, len(tiles), cols)]
    rh = [max(t[1].height for t in r) + 70 for r in rows]
    W = pad * 2 + cols * tw + (cols - 1) * gap
    H = head + sum(rh) + gap * (len(rows) - 1) + pad
    im = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(im)
    header(d, pad, 20, 'M2-00-00  全部畫面總覽', '每個畫面的第一個狀態（390 寬）。各畫面的全部狀態看 boards/<畫面>/ 裡的「總覽」；動畫看 boards/A-動畫/。')
    y = head
    for r, h in zip(rows, rh):
        x = pad
        for m, img in r:
            d.text((x, y), m['screen'], font=font(24, 'Black'), fill=INK)
            d.text((x, y + 32), m['screenName'][:10], font=font(20, 'Regular'), fill=MUTED)
            im.paste(img, (x, y + 64))
            d.rectangle([x - 1, y + 63, x + img.width, y + 64 + img.height], outline=(200, 184, 168), width=2)
            x += tw + gap
        y += h + gap
    name = 'M2-00-00-全部畫面-總覽.png'
    save(im, os.path.join(OUT, name))
    return name

def main(prefix=''):
    metas = [m for m in load_meta() if m['id'].startswith(prefix) or (prefix and m.get('screen') == prefix)]
    made = []
    screens = sorted({m['screen'] for m in metas}, key=lambda s: SCREEN_ORDER.index(s) if s in SCREEN_ORDER else 99)
    for sc in screens:
        ms = [m for m in metas if m['screen'] == sc]
        sname = ms[0]['screenName']
        screen_dir = os.path.join(OUT, f"{sc}-{safe(sname)}")
        for f in glob.glob(os.path.join(screen_dir, '*.png')): os.remove(f)
        key = lambda m: [int(x) if x.isdigit() else x for x in re.split(r'(\d+)', m['id'])]
        for m in sorted([m for m in ms if m.get('type') == 'sheet'], key=key):
            img = Image.open(m['_png']).convert('RGB')
            pad, head = 32, 110
            im = Image.new('RGB', (img.width + pad * 2, img.height + head + pad), BG); d = ImageDraw.Draw(im)
            header(d, pad, 20, f"M2-{m['id']}  {m['name']}", f"{sc} {sname}　·　大張（不是手機畫面）")
            im.paste(img, (pad, head))
            name = f"M2-{m['id']}-{safe(sname)}-{safe(m['name'])}.png"; save(im, os.path.join(screen_dir, name)); made.append(name)
        for w in (430, 390):
            fulls = sorted([m for m in ms if m.get('width') == w and m.get('type') == 'full' and os.path.exists(m['_png'])], key=key)
            parts = sorted([m for m in ms if m.get('width') == w and m.get('type') == 'part' and os.path.exists(m['_png'])], key=key)
            boards = [m for m in parts if m.get('board')]
            parts = [m for m in parts if not m.get('board')]  # 另外成一張的不放進局部狀態表和總覽
            for b in sorted({m['board'] for m in boards}):
                made.append(sheet_parts(sc, sname, [m for m in boards if m['board'] == b], w, screen_dir, board=b))
            for m in fulls: made.append(board_full(m, dpr2(m['_png']), screen_dir))
            n = sheet_parts(sc, sname, parts, w, screen_dir)
            if n: made.append(n)
            if w == 390 and (fulls or parts): made.append(overview(sc, sname, fulls, parts, screen_dir))
    if not prefix: made.append(index_overview(load_meta()))
    print(f'合成 {len(made)} 張')
    return made

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '')
