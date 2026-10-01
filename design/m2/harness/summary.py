#!/usr/bin/env python3
# M2 量測摘要：讀 raw/*__<寬>.json，寫 measure/summary.md 與 summary.json。
# 430、390 送核准；360、320 只量測（窄手機的問題列出來，交給實作時處理）。
# 英文、泰文：python3 harness/summary.py en（或 th）讀 raw/<語言>/，寫 measure/summary-<語言>.md／.json，
# 另外列出缺翻譯的 key（畫面用繁中顯示）和泰文換行的檢查（Intl.Segmenter、用詞表）。
import json, glob, os, sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANG = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] != 'zh-Hant' else ''
LANG_NAME = {'en': '英文', 'th': '泰文'}
RAW, OUT = os.path.join(ROOT, 'raw', LANG) if LANG else os.path.join(ROOT, 'raw'), os.path.join(ROOT, 'measure')
SUFFIX = f'-{LANG}' if LANG else ''
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
    lines = [f"# M2 設計稿量測摘要{'（' + LANG_NAME.get(LANG, LANG) + '）' if LANG else ''}", '',
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
    if LANG: lines += lang_sections(data, key)
    with open(os.path.join(OUT, f'summary{SUFFIX}.md'), 'w', encoding='utf-8') as f: f.write('\n'.join(lines) + '\n')
    with open(os.path.join(OUT, f'summary{SUFFIX}.json'), 'w', encoding='utf-8') as f: json.dump(summary, f, ensure_ascii=False, indent=1)
    for w, s in summary.items(): print(w, s['states'], '最小字', s['minFont'], '有問題', len(s['bad']))

def lang_sections(data, key):
    # 缺翻譯的 key：哪些 key、出現在哪些狀態
    miss = defaultdict(set)
    for w, ms in data.items():
        for m in ms:
            for k in m.get('i18nMissing') or []: miss[k].add(m['id'])
    out = ['## 缺翻譯的 key（畫面用繁中顯示）', '']
    if not miss: out += ['沒有缺。', '']
    else:
        out += [f'共 {len(miss)} 個。', '', '| key | 出現在 |', '|---|---|']
        out += [f"| `{k}` | {'、'.join(sorted(v)[:8])}{'…' if len(v) > 8 else ''} |" for k, v in sorted(miss.items())]
        out.append('')
    if LANG != 'th': return out
    # 泰文換行：⏎ 是實際換行的地方，| 是 Intl.Segmenter 切的詞界
    out += ['## 泰文換行（Intl.Segmenter、用詞表）', '',
            '- 每個換了行、含泰文的字都檢查。⏎ 是實際換行的地方，| 是 Intl.Segmenter 切的詞界。',
            '- 換在詞中間：一定要改。',
            '- 用詞表裡的詞被拆到兩行：要人看。複合詞拆在詞界上可以（例 ตลาด⏎พ่อพันธุ์）；外來字、品種名不行（例 ออฟ⏎ไลน์），要改寫或改版面。', '']
    mid, split, allw = [], [], {}
    for w in (430, 390, 360, 320):
        for m in sorted(data.get(w, []), key=key):
            for x in m.get('thaiBreaks') or []:
                allw.setdefault(x['text'], x)
                if x.get('midWord'): mid.append((m['id'], w, x))
                if x.get('splitTerms'): split.append((m['id'], w, x))
    out += ['### 換在詞中間', '']
    out += ['沒有。', ''] if not mid else ['| 狀態 | 寬度 | 實際換行（⏎） | 幾處 |', '|---|---|---|---|'] + [f"| {s} | {w} | {x['breaksAt']} | {x['midWord']} |" for s, w, x in mid] + ['']
    out += ['### 用詞表的詞被拆到兩行（要人看）', '']
    out += ['沒有。', ''] if not split else ['| 狀態 | 寬度 | 被拆開的詞 | 實際換行（⏎） |', '|---|---|---|---|'] + [f"| {s} | {w} | {'、'.join(x['splitTerms'])} | {x['breaksAt']} |" for s, w, x in split] + ['']
    out += [f'<details><summary>所有換了行的泰文（{len(allw)} 句，給校對看斷詞）</summary>', '', '| 實際換行（⏎） | Intl.Segmenter 斷詞（\|） |', '|---|---|']
    pipe = ' \\| '  # 表格裡的 | 要跳脫
    out += [f"| {x['breaksAt']} | {pipe.join(x['words'].split('|'))} |" for x in allw.values()]
    out += ['', '</details>', '']
    return out

if __name__ == '__main__':
    main()
