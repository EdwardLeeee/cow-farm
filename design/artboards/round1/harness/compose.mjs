// R1 拼圖：raw/ 的原始截圖 → 加標籤的選項圖（DPR 3，不縮放）與總覽（DPR 2，格子下印檔名、描述、量測）。
// 用法：node harness/compose.mjs（先跑 capture.mjs）
import { chromium } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { startServer } from './server.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

export const OPTIONS = [
  { job: 'r1-01-a-mobile', file: 'R1-01-美術風格-A-圓潤Q版-mobile.png', desc: '粗圓描邊、扁平粉彩、胖嘟嘟比例' },
  { job: 'r1-01-b-mobile', file: 'R1-01-美術風格-B-像素風-mobile.png', desc: '點陣像素（1 像素＝3px）、自畫像素數字' },
  { job: 'r1-01-c-mobile', file: 'R1-01-美術風格-C-軟萌立體-mobile.png', desc: '柔和漸層、軟陰影、像黏土玩具' },
];
const OVERVIEW = 'R1-99-總覽對照.png';

const FONT = `"Noto Sans CJK TC", sans-serif`;
const MONO = `"Noto Sans Mono CJK TC", "Noto Sans CJK TC", monospace`;
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');

function phone(src, scale = 1) {
  const W = 390 * scale, H = 844 * scale, b = 10 * scale;
  return `<div class="phone" style="width:${W + b * 2}px;height:${H + b * 2}px;padding:${b}px;border-radius:${56 * scale}px">
    <img src="${src}" width="${W}" height="${H}" style="display:block;border-radius:${46 * scale}px"></div>`;
}
const BASE_CSS = `
  * { box-sizing: border-box; } html, body { margin: 0; }
  body { background: #ECEEF1; font-family: ${FONT}; color: #1F2329; }
  .phone { background: #16161A; box-shadow: 0 18px 40px rgba(20, 24, 32, 0.22), inset 0 0 0 2px #2C2C33; }
  .label { font: 700 18px/24px ${FONT}; color: #1F2329; letter-spacing: 0.2px; }
`;

function measureLines(m) {
  const L = [];
  const ok = (good, text) => L.push({ cls: good ? 'ok' : 'bad', text: `${good ? '✓' : '✗'} ${text}` });
  const note = (text) => L.push({ cls: 'note', text: `・${text}` });
  const minText = m.minFontSizeText;
  ok(minText >= 11, `最小字級 ${minText}px（標準 ≥ 11px）${m.minPixelGlyph ? `；像素數字 ${m.minPixelGlyph}px 高` : ''}`);
  const cut = m.clipped.length + m.outside.length;
  ok(cut === 0, cut === 0 ? '文字沒有被截、沒有超出框' : `文字被截或出框 ${cut} 處`);
  ok(m.wrapped.length === 0, m.wrapped.length === 0 ? '單行文字都沒有換行' : `意外換行 ${m.wrapped.length} 處：${m.wrapped.join('、')}`);
  ok(m.minTab.w >= 44 && m.minTab.h >= 44, `分頁觸控最小 ${Math.round(m.minTab.w)}×${Math.round(m.minTab.h)}px（標準 ≥ 44px）`);
  ok(!m.horizontalScroll, m.horizontalScroll ? '有橫向捲動' : '沒有橫向捲動');
  ok(m.safeArea.hudBelowStatusbar && m.safeArea.tabsAboveHome, `內容避開安全區（上 ${m.safeArea.top}px／下 ${m.safeArea.bottom}px）`);
  if (m.pixelImages) ok(m.pixelScales.length === 1 && m.pixelScales[0] === '3x3', `像素格一致：${m.pixelImages} 張像素圖都是 1:3`);
  if (m.pixelImages) note('中文用系統字 Noto Sans CJK TC（沒有像素中文字型）');
  return L;
}

async function main() {
  const srv = await startServer(ROOT);
  const browser = await chromium.launch();
  try {
    const metas = {};
    for (const o of OPTIONS) metas[o.job] = JSON.parse(await readFile(join(ROOT, 'raw', `${o.job}.json`), 'utf8'));

    // 選項圖：一個選項一張，左上角外框留白處印標籤（= 檔名去掉 .png）
    for (const o of OPTIONS) {
      const label = o.file.replace(/\.png$/, '');
      const W = 36 + 410 + 36, H = 78 + 864 + 36;
      const html = `<!doctype html><html lang="zh-Hant-TW"><head><meta charset="utf-8"><style>${BASE_CSS}
        .wrap { width: ${W}px; height: ${H}px; padding: 0 36px; position: relative; }
        .label { position: absolute; left: 24px; top: 24px; }
      </style></head><body><div class="wrap"><div class="label">${esc(label)}</div><div style="padding-top:78px">${phone(`${srv.base}/raw/${o.job}.png`)}</div></div></body></html>`;
      const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 3, locale: 'zh-TW', colorScheme: 'light' });
      const page = await ctx.newPage();
      await page.setContent(html, { waitUntil: 'load' });
      await page.evaluate(() => document.fonts.ready);
      await page.screenshot({ path: join(ROOT, o.file) });
      await ctx.close();
      console.log('ok', o.file);
    }

    // 總覽：三格並排，每格下面印檔名、白話描述、關鍵量測（紅＝有問題、綠＝通過、灰＝說明）
    const cellW = 410, gap = 40, pad = 36;
    const W = pad * 2 + cellW * 3 + gap * 2;
    const cells = OPTIONS.map((o) => {
      const lines = measureLines(metas[o.job]).map((l) => `<div class="m ${l.cls}">${esc(l.text)}</div>`).join('');
      return `<div class="cell">${phone(`${srv.base}/raw/${o.job}.png`)}
        <div class="fn">${esc(o.file)}</div><div class="desc">${esc(o.desc)}</div><div class="ms">${lines}</div></div>`;
    }).join('');
    const html = `<!doctype html><html lang="zh-Hant-TW"><head><meta charset="utf-8"><style>${BASE_CSS}
      .wrap { width: ${W}px; padding: 24px ${pad}px 36px; }
      .sub { font: 500 14px/20px ${FONT}; color: #5B6270; margin-top: 4px; }
      .row { display: flex; gap: ${gap}px; margin-top: 22px; align-items: flex-start; }
      .cell { width: ${cellW}px; }
      .fn { font: 600 13px/18px ${MONO}; color: #2B303A; margin-top: 16px; word-break: break-all; }
      .desc { font: 700 16px/22px ${FONT}; color: #1F2329; margin-top: 6px; }
      .ms { margin-top: 8px; }
      .m { font: 500 13px/20px ${FONT}; }
      .m.ok { color: #16833F; } .m.bad { color: #D22F2F; font-weight: 700; } .m.note { color: #7A808C; }
    </style></head><body><div class="wrap">
      <div class="label">${esc(OVERVIEW.replace(/\.png$/, ''))}</div>
      <div class="sub">第 1 輪　項目 01 美術風格（這一輪只挑畫風）　牧場主畫面　390×844・DPR 3・zh-TW　2026-09-30</div>
      <div class="row">${cells}</div></div></body></html>`;
    const ctx = await browser.newContext({ viewport: { width: W, height: 800 }, deviceScaleFactor: 2, locale: 'zh-TW', colorScheme: 'light' });
    const page = await ctx.newPage();
    await page.setContent(html, { waitUntil: 'load' });
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: join(ROOT, OVERVIEW), fullPage: true });
    await ctx.close();
    console.log('ok', OVERVIEW);
  } finally {
    await browser.close();
    await srv.close();
  }
}

const watchdog = setTimeout(() => { console.error('compose timeout (120s)'); process.exit(2); }, 120000);
main().then(() => clearTimeout(watchdog)).catch((e) => { console.error(e); process.exit(1); });
