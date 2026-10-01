#!/usr/bin/env python3
# M2 動畫合成：raw/anim/<A-xx>/ 的影格 → GIF（ffmpeg）、分鏡圖、減少動態圖，放到 boards/A-動畫/。
# 用法：python3 harness/compose_anim.py [A-01,A-02…]
import json, os, subprocess, sys, glob
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose import font, header, save, safe, INK, MUTED, BG

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, 'raw', 'anim')
OUT = os.path.join(ROOT, 'boards', 'A-動畫')
REVEAL = {'A-04', 'A-06', 'A-09', 'A-10'}

NO_START = set('，。、）」：；！？』）')  # 這些標點不放在行首（跟著前一行）
def wrap(d, text, f, width):
    lines, cur = [], ''
    for ch in text:
        if d.textlength(cur + ch, font=f) > width and cur and ch not in NO_START:
            lines.append(cur); cur = ch
        else:
            cur += ch
    if cur: lines.append(cur)
    return lines

def gif(a, src, dst):
    # 一般的動畫：開頭停 0.5 秒、結尾停 1.4 秒；一直循環的（loop）不停，接起來才順
    pad = '' if a.get('loop') else 'tpad=start_duration=0.5:start_mode=clone:stop_duration=1.4:stop_mode=clone,'
    vf = (pad + 'split[a][b];[a]palettegen=max_colors=160:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle')
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-framerate', str(a['fps']), '-i', os.path.join(src, 'f%03d.png'),
                    '-vf', vf, '-loop', '0', dst], check=True)

def storyboard(a, src, dst):
    pw, gap, pad, head = 300, 22, 32, 150
    frames = [Image.open(os.path.join(src, f'k{i}.png')).convert('RGB') for i in range(len(a['keys']))]
    frames = [f.resize((pw, round(f.height * pw / f.width)), Image.LANCZOS) for f in frames]
    fh = frames[0].height
    tmp = ImageDraw.Draw(Image.new('RGB', (10, 10)))
    caps = [wrap(tmp, k[1], font(22, 'Regular'), pw) for k in a['keys']]
    capH = 44 + 32 * max(len(c) for c in caps)
    W = pad * 2 + len(frames) * pw + (len(frames) - 1) * gap
    H = head + fh + capH + pad
    im = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(im)
    tags = ['分鏡'] + (['揭曉・1.5 秒內・點一下跳過'] if a['id'] in REVEAL else []) + (['一直循環'] if a.get('loop') else [])
    header(d, pad, 20, f"M2-{a['id']}  {a['name']}", f"出現在：{a['where']}　·　長度 {a['dur']} 秒　·　390 寬　·　動起來的樣子看同名的 GIF", tags)
    d.text((pad, 102), '時間是從動畫開始算的秒數；每一格下面寫這時候畫面上在發生什麼。', font=font(20, 'Regular'), fill=MUTED)
    for i, (f, (t, _), c) in enumerate(zip(frames, a['keys'], caps)):
        x = pad + i * (pw + gap)
        im.paste(f, (x, head))
        d.rectangle([x - 2, head - 2, x + pw + 1, head + fh + 1], outline=INK, width=3)
        d.rounded_rectangle([x, head + fh + 10, x + 96, head + fh + 42], 12, fill=(255, 212, 94), outline=INK, width=3)
        d.text((x + 12, head + fh + 12), f'{t:.2f} 秒', font=font(20), fill=INK)
        for j, line in enumerate(c):
            d.text((x, head + fh + 50 + j * 32), line, font=font(22, 'Regular'), fill=INK)
    save(im, dst)

def reduced(a, src, dst):
    pw, gap, pad, head = 360, 90, 32, 190
    if a['reducedFrom'] == a['reducedTo']:
        return reduced_single(a, src, dst)
    frames = [Image.open(os.path.join(src, f'r{i}.png')).convert('RGB') for i in range(2)]
    frames = [f.resize((pw, round(f.height * pw / f.width)), Image.LANCZOS) for f in frames]
    fh = frames[0].height
    W = pad * 2 + 2 * pw + gap
    im = Image.new('RGB', (W, head + fh + 70 + pad), BG); d = ImageDraw.Draw(im)
    header(d, pad, 20, f"M2-{a['id']}  {a['name']}", '手機開了「減少動態」時的做法（跟著系統設定，不另外放開關）', ['減少動態'])
    for j, line in enumerate(wrap(d, a['reduced'], font(24), W - pad * 2)):
        d.text((pad, 104 + j * 36), line, font=font(24), fill=INK)
    for i, f in enumerate(frames):
        x = pad + i * (pw + gap)
        im.paste(f, (x, head))
        d.rectangle([x - 2, head - 2, x + pw + 1, head + fh + 1], outline=INK, width=3)
        lab = a['reducedFrom'] if i == 0 else a['reducedTo']
        name = {'t0': '動畫開始前', 'tEnd': '直接變成結束的樣子'}.get(lab, f'{lab}（整頁狀態）')
        d.text((x, head + fh + 16), ('之前：' if i == 0 else '之後：') + name, font=font(22), fill=INK)
    ax, ay = pad + pw + 16, head + fh // 2
    d.polygon([(ax, ay - 26), (ax + 58, ay), (ax, ay + 26)], fill=(255, 212, 94), outline=INK, width=4)
    save(im, dst)

def reduced_single(a, src, dst):
    # 減少動態時畫面不動：只放一張
    pw, pad, head = 360, 32, 190
    f = Image.open(os.path.join(src, 'r0.png')).convert('RGB')
    f = f.resize((pw, round(f.height * pw / f.width)), Image.LANCZOS)
    W = max(pad * 2 + pw, 760)
    im = Image.new('RGB', (W, head + f.height + 70 + pad), BG); d = ImageDraw.Draw(im)
    header(d, pad, 20, f"M2-{a['id']}  {a['name']}", '手機開了「減少動態」時的做法（跟著系統設定，不另外放開關）', ['減少動態'])
    for j, line in enumerate(wrap(d, a['reduced'], font(24), W - pad * 2)):
        d.text((pad, 104 + j * 36), line, font=font(24), fill=INK)
    im.paste(f, (pad, head))
    d.rectangle([pad - 2, head - 2, pad + pw + 1, head + f.height + 1], outline=INK, width=3)
    d.text((pad, head + f.height + 16), f"畫面不動：{a['reducedFrom']}（整頁狀態）", font=font(22), fill=INK)
    save(im, dst)

def main(which=''):
    os.makedirs(OUT, exist_ok=True)
    ids = sorted(os.listdir(RAW)) if not which else which.split(',')
    for aid in ids:
        src = os.path.join(RAW, aid)
        with open(os.path.join(src, 'meta.json'), encoding='utf-8') as f: a = json.load(f)
        base = f"M2-{aid}-{safe(a['name'])}"
        for old in glob.glob(os.path.join(OUT, f'M2-{aid}-*')): os.remove(old)
        gif(a, src, os.path.join(OUT, f'{base}-390.gif'))
        storyboard(a, src, os.path.join(OUT, f'{base}-分鏡-390.png'))
        reduced(a, src, os.path.join(OUT, f'{base}-減少動態-390.png'))
        print('ok', aid)

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '')
