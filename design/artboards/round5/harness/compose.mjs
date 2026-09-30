// R5 拼圖：raw/ → 三種線條處理的單張圖（左牧場畫面、右排排站＋剪影）與總覽。
// 進 git 的是加標籤的圖：單張 DPR 2、總覽 DPR 1.5（ceo 2026-09-30：控制公開 repo 大小）；raw/ 的 PNG 不進 git。
// 用法：node harness/compose.mjs（先跑 capture.mjs）
import { chromium } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { startServer } from './server.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

// 對照一格（沒有重拍）：r5-00-control-r1a 是從 round2/raw 複製來的原始截圖與量測
export const OPTIONS = [
  { v: 'r1a', screen: null, lineup: 'r5-00-control-r1a', file: null, ref: '（對照）round2/raw/r2-lineup-0.png', title: '對照：R1-A 的牛', desc: '同樣是正面大頭，但眼睛是大的直立橢圓、線很粗、每一頭同一個身體', rejected: true },
  { v: 'a', screen: 'r5-01-a-mobile', lineup: 'r5-lineup-a', file: 'R5-01-牛的線條-A-細手繪線-mobile.png', title: 'A 細手繪線', desc: '細的咖啡色線，輪廓有一點手畫的抖動' },
  { v: 'b', screen: 'r5-01-b-mobile', lineup: 'r5-lineup-b', file: 'R5-01-牛的線條-B-乾淨中線-mobile.png', title: 'B 乾淨中線', desc: '中等粗細的深咖啡色線，輪廓平滑乾淨' },
  { v: 'c', screen: 'r5-01-c-mobile', lineup: 'r5-lineup-c', file: 'R5-01-牛的線條-C-不描邊-mobile.png', title: 'C 不描邊', desc: '沒有外框線，只用色塊分出形狀' },
];
const OVERVIEW = 'R5-99-總覽對照.png';
const FONT = `"Noto Sans CJK TC", sans-serif`;
const MONO = `"Noto Sans Mono CJK TC", "Noto Sans CJK TC", monospace`;
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const BASE_CSS = `
  * { box-sizing: border-box; } html, body { margin: 0; }
  body { background: #ECEEF1; font-family: ${FONT}; color: #1F2329; }
  .phone { background: #16161A; box-shadow: 0 18px 40px rgba(20, 24, 32, 0.22), inset 0 0 0 2px #2C2C33; }
  .label { font: 700 18px/24px ${FONT}; color: #1F2329; letter-spacing: 0.2px; }
  .panel-img { display: block; border-radius: 26px; box-shadow: 0 14px 32px rgba(20, 24, 32, 0.16); }
`;
function phone(src, scale = 1) {
  const W = 390 * scale, H = 844 * scale, b = 10 * scale;
  return `<div class="phone" style="width:${W + b * 2}px;height:${H + b * 2}px;padding:${b}px;border-radius:${56 * scale}px"><img src="${src}" width="${W}" height="${H}" style="display:block;border-radius:${46 * scale}px"></div>`;
}
function lines(o, M) {
  const L = [];
  const ok = (good, t) => L.push({ cls: good ? 'ok' : 'bad', t: `${good ? '✓' : '✗'} ${t}` });
  const note = (t) => L.push({ cls: 'note', t: `・${t}` });
  const lu = M[o.lineup];
  if (o.screen) {
    const s = M[o.screen];
    const cut = s.clipped.length + s.outside.length + s.wrapped.length;
    ok(s.minFontSizeText >= 11 && cut === 0, `牧場畫面：最小字級 ${s.minFontSizeText}px、文字被截 ${cut} 處`);
    ok(s.minTab.w >= 44 && s.minTab.h >= 44 && s.safeArea.hudBelowStatusbar && s.safeArea.tabsAboveHome && !s.horizontalScroll,
      `分頁觸控 ${Math.round(s.minTab.w)}×${Math.round(s.minTab.h)}px、避開安全區、無橫向捲動`);
  } else note('只放牛當對照；量測見第 2 輪');
  if (o.rejected) return L;
  const bad = lu.outside.length + lu.figOverflow + lu.silNameOverlap;
  ok(lu.minFontSize >= 11 && bad === 0, `排排站：最小字級 ${lu.minFontSize}px、名字被截或重疊 ${bad} 處`);
  if (lu.calfRatio) ok(lu.calfRatio >= 0.55 && lu.calfRatio <= 0.6, `小牛身高是成年荷斯坦的 ${Math.round(lu.calfRatio * 100)}%（目標 55–60%）`);
  if (lu.calfRatioSide) ok(lu.calfRatioSide >= 0.55 && lu.calfRatioSide <= 0.6, `側面：小牛身高是成年荷斯坦的 ${Math.round(lu.calfRatioSide * 100)}%`);
  return L;
}

async function main() {
  const srv = await startServer(ROOT);
  const browser = await chromium.launch();
  try {
    const M = {};
    for (const o of OPTIONS) for (const j of [o.screen, o.lineup]) if (j) M[j] = JSON.parse(await readFile(join(ROOT, 'raw', `${j}.json`), 'utf8'));

    for (const o of OPTIONS.filter((x) => x.file)) {
      const label = o.file.replace(/\.png$/, '');
      const W = 36 + 410 + 28 + 720 + 36, H = 78 + 1080 + 36;
      const html = `<!doctype html><html lang="zh-Hant-TW"><head><meta charset="utf-8"><style>${BASE_CSS}
        .wrap { width: ${W}px; height: ${H}px; position: relative; }
        .label { position: absolute; left: 24px; top: 24px; }
        .row { position: absolute; left: 36px; top: 78px; display: flex; gap: 28px; align-items: flex-start; }
      </style></head><body><div class="wrap"><div class="label">${esc(label)}</div>
        <div class="row">${phone(`${srv.base}/raw/${o.screen}.png`)}<img class="panel-img" src="${srv.base}/raw/${o.lineup}.png" width="720" height="1080"></div></div></body></html>`;
      const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, locale: 'zh-TW', colorScheme: 'light' });
      const page = await ctx.newPage();
      await page.setContent(html, { waitUntil: 'load' });
      await page.evaluate(() => document.fonts.ready);
      await page.screenshot({ path: join(ROOT, o.file) });
      await ctx.close();
      console.log('ok', o.file);
    }

    // 總覽：兩格對照＋A–E 並排，每格放排排站與剪影，下面印檔名、白話描述、量測
    const cw = 460, ch = Math.round((864 / 720) * cw), gap = 28, pad = 36;
    const W = pad * 2 + cw * OPTIONS.length + gap * (OPTIONS.length - 1);
    const cells = OPTIONS.map((o) => `<div class="cell${o.rejected ? ' rej' : ''}"><div class="ct">${esc(o.title)}</div><img class="panel-img" src="${srv.base}/raw/${o.lineup}.png" width="${cw}">
      <div class="fn">${esc(o.file || o.ref)}</div><div class="desc">${esc(o.desc)}</div>
      <div class="ms">${lines(o, M).map((l) => `<div class="m ${l.cls}">${esc(l.t)}</div>`).join('')}</div></div>`).join('');
    const html = `<!doctype html><html lang="zh-Hant-TW"><head><meta charset="utf-8"><style>${BASE_CSS}
      .wrap { width: ${W}px; padding: 24px ${pad}px 36px; }
      .sub { font: 500 14px/20px ${FONT}; color: #5B6270; margin-top: 4px; }
      .rowc { display: flex; gap: ${gap}px; margin-top: 20px; align-items: flex-start; }
      .cell { width: ${cw}px; }
      .ct { font: 900 17px/24px ${FONT}; margin: 0 0 8px 4px; }
      .fn { font: 600 13px/18px ${MONO}; color: #2B303A; margin-top: 14px; word-break: break-all; }
      .desc { font: 700 16px/22px ${FONT}; margin-top: 6px; }
      .ms { margin-top: 8px; } .m { font: 500 13px/20px ${FONT}; }
      .m.ok { color: #16833F; } .m.bad { color: #D22F2F; font-weight: 700; } .m.note { color: #7A808C; }
      .rej .panel-img { opacity: 0.85; filter: grayscale(0.25); } .rej .desc { color: #9A3B32; } .rej .ct { color: #7A808C; }
    </style></head><body><div class="wrap">
      <div class="label">${esc(OVERVIEW.replace(/\.png$/, ''))}</div>
      <div class="sub">第 5 輪　項目 01 牛的線條（照參考圖的共同點畫同一隻牛：臉朝你、大頭、小點眼、寬口鼻、大斑、短腿、平塗；三格只差線條）　每格：九頭正面＋四頭側面走路＋剪影　2026-09-30</div>
      <div class="rowc">${cells}</div></div></body></html>`;
    const ctx = await browser.newContext({ viewport: { width: W, height: 800 }, deviceScaleFactor: 1.5, locale: 'zh-TW', colorScheme: 'light' });
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
