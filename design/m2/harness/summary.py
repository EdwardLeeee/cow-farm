#!/usr/bin/env python3
# M2 量測摘要：讀 raw/*__<寬>.json，寫 measure/summary.md 與 summary.json。
# 430、390 送核准；360、320 只量測（窄手機的問題列出來，交給實作時處理）。
import json, glob, os
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW, OUT = os.path.join(ROOT, 'raw'), os.path.join(ROOT, 'measure')
CATS = [('clipped', '文字被切掉'), ('outside', '文字超出框'), ('wrapped', '不該換行卻換行'), ('overlaps', '文字互相重疊或被按鈕蓋住'),
        ('smallTargets', '按鈕小於 44×44'), ('unsafe', '進到狀態列或 Home 指示條'), ('errors', '頁面錯誤')]
SIZE = {430: '430×932', 390: '390×844', 360: '360×800', 320: '320×568'}

def main():
    os.makedirs(OUT, exist_ok=True)
    data = defaultdict(list)
    for j in glob.glob(os.path.join(RAW, '*__*.json')):
        b = os.path.basename(j)
        if b.startswith('_') or '__sheet' in b: continue
        with open(j, encoding='utf-8') as f: m = json.load(f)
        # 「局部在畫面外」只是截圖的註記（320 高度太矮），不是頁面錯誤
        m['notes'] = [e for e in m.get('errors', []) if e.startswith('局部在畫面外')]
        m['errors'] = [e for e in m.get('errors', []) if not e.startswith('局部在畫面外')]
        data[m['width']].append(m)
    key = lambda m: (m['id'].split('-')[0].replace('G', 'A'), m['id'])
    lines = ['# M2 設計稿量測摘要', '',
             '- 工具：`design/m2/harness/capture.mjs`（Chromium，行動裝置模式）。每個狀態在四種寬度各量一次。',
             '- 430、390 是送核准的尺寸；360、320 只量測，問題列在下面，實作時處理。',
             '- 量的項目：最小字級、文字被切掉、文字超出所屬的框、不該換行卻換行、文字互相重疊或被按鈕蓋住、按鈕小於 44×44、進到狀態列或 Home 指示條、橫向捲動、頁面錯誤。',
             '- 不算問題、另外記的：跑馬燈和橫向捲動列本來就會切到；太長的名字刻意截成「…」；內容區要往下捲才看得到的部分。', '']
    summary = {}
    lines += ['## 總表', '', '| 寬度 | 狀態數 | 最小字級 | 有問題的狀態 | 橫向捲動 | 刻意截成「…」 | 要往下捲的狀態 |', '|---|---|---|---|---|---|---|']
    for w in (430, 390, 360, 320):
        ms = sorted(data.get(w, []), key=key)
        if not ms: continue
        bad = [m for m in ms if any(m.get(c) for c, _ in CATS) or m.get('horizontalScroll')]
        mins = [m['minFontSize'] for m in ms if m.get('minFontSize')]
        trunc = sum(1 for m in ms if m.get('truncated'))
        fold = sum(1 for m in ms if m.get('belowFold'))
        summary[w] = {'states': len(ms), 'minFont': min(mins) if mins else None, 'bad': [m['id'] for m in bad], 'hscroll': [m['id'] for m in ms if m.get('horizontalScroll')]}
        lines.append(f"| {SIZE[w]} | {len(ms)} | {min(mins) if mins else '—'} px | {len(bad)} | {len(summary[w]['hscroll'])} | {trunc} | {fold} |")
    lines.append('')
    for w in (430, 390, 360, 320):
        ms = sorted(data.get(w, []), key=key)
        bad = [m for m in ms if any(m.get(c) for c, _ in CATS) or m.get('horizontalScroll')]
        lines += [f'## {SIZE[w]}', '']
        if not bad:
            lines += ['沒有問題。', '']
            continue
        for m in bad:
            items = []
            for c, label in CATS:
                v = m.get(c) or []
                if not v: continue
                ex = []
                for x in v[:3]:
                    if isinstance(x, dict): ex.append(x.get('text') or x.get('name') or json.dumps(x, ensure_ascii=False))
                    elif isinstance(x, list): ex.append('／'.join(x))
                    else: ex.append(str(x))
                items.append(f"{label} {len(v)}（例：{'；'.join(e[:24] for e in ex)}）")
            if m.get('horizontalScroll'): items.append('橫向捲動')
            lines.append(f"- **{m['id']} {m['name']}**：{'、'.join(items)}")
        lines.append('')
    with open(os.path.join(OUT, 'summary.md'), 'w', encoding='utf-8') as f: f.write('\n'.join(lines) + '\n')
    with open(os.path.join(OUT, 'summary.json'), 'w', encoding='utf-8') as f: json.dump(summary, f, ensure_ascii=False, indent=1)
    for w, s in summary.items(): print(w, s['states'], '最小字', s['minFont'], '有問題', len(s['bad']))

if __name__ == '__main__':
    main()
