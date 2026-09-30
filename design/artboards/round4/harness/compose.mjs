// R4 拼圖：raw/ → 五種外型的單張圖（左牧場畫面、右排排站＋剪影）與總覽。
// 進 git 的是加標籤的圖：單張 DPR 2、總覽 DPR 1.5（ceo 2026-09-30：控制公開 repo 大小）；raw/ 的 PNG 不進 git。
// 用法：node harness/compose.mjs（先跑 capture.mjs）
import { chromium } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { startServer } from './server.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

// 對照兩格（沒有重拍）：r4-00-control-* 是從 round2/raw 複製來的原始截圖與量測
export const OPTIONS = [
  { v: 'r1a', screen: null, lineup: 'r4-00-control-r1a', file: null, ref: '（對照）round2/raw/r2-lineup-0.png', title: '對照 1：R1-A 的牛', desc: '被否決：眼睛是直立的橢圓、粉紅大圓鼻像豬、每一頭同一個身體', rejected: true },
  { v: 'r2c', screen: null, lineup: 'r4-00-control-r2c', file: null, ref: '（對照）round2/raw/r2-lineup-c.png', title: '對照 2：R2-C 側面輪廓', desc: '被否決：身體和腿細長，第 3 輪使用者說「牛的外型怪怪的」', rejected: true },
  { v: 'a', screen: 'r4-01-a-mobile', lineup: 'r4-lineup-a', file: 'R4-01-牛的外型-A-胖胖側面-mobile.png', title: 'A 胖胖側面', desc: '麵包形的胖身體、短腿；頭畫側面，口鼻短短往前；豆豆眼' },
  { v: 'b', screen: 'r4-01-b-mobile', lineup: 'r4-lineup-b', file: 'R4-01-牛的外型-B-轉頭看你-mobile.png', title: 'B 轉頭看你', desc: '身體側面、頭轉過來看你；圓亮眼；寬寬的奶油色口鼻' },
  { v: 'c', screen: 'r4-01-c-mobile', lineup: 'r4-lineup-c', file: 'R4-01-牛的外型-C-圓球糰子-mobile.png', title: 'C 圓球糰子', desc: '身體幾乎是一顆球、腿很短；小側臉貼在身上；笑瞇瞇的彎眼' },
  { v: 'd', screen: 'r4-01-d-mobile', lineup: 'r4-lineup-d', file: 'R4-01-牛的外型-D-斜側四分之三-mobile.png', title: 'D 斜側四分之三', desc: '桶形身體、腿稍長；頭斜 45 度，看得到兩隻眼睛' },
  { v: 'e', screen: 'r4-01-e-mobile', lineup: 'r4-lineup-e', file: 'R4-01-牛的外型-E-軟方塊-mobile.png', title: 'E 軟方塊', desc: '像棉花糖的圓角方塊，頭和身體連成一體；短方腿；杏仁眼加睫毛' },
];
const OVERVIEW = 'R4-99-總覽對照.png';
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
      const W = 36 + 410 + 28 + 720 + 36, H = 78 + 864 + 36;
      const html = `<!doctype html><html lang="zh-Hant-TW"><head><meta charset="utf-8"><style>${BASE_CSS}
        .wrap { width: ${W}px; height: ${H}px; position: relative; }
        .label { position: absolute; left: 24px; top: 24px; }
        .row { position: absolute; left: 36px; top: 78px; display: flex; gap: 28px; align-items: flex-start; }
      </style></head><body><div class="wrap"><div class="label">${esc(label)}</div>
        <div class="row">${phone(`${srv.base}/raw/${o.screen}.png`)}<img class="panel-img" src="${srv.base}/raw/${o.lineup}.png" width="720" height="864"></div></div></body></html>`;
      const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, locale: 'zh-TW', colorScheme: 'light' });
      const page = await ctx.newPage();
      await page.setContent(html, { waitUntil: 'load' });
      await page.evaluate(() => document.fonts.ready);
      await page.screenshot({ path: join(ROOT, o.file) });
      await ctx.close();
      console.log('ok', o.file);
    }

    // 總覽：兩格對照＋A–E 並排，每格放排排站與剪影，下面印檔名、白話描述、量測
    const cw = 340, ch = Math.round((864 / 720) * cw), gap = 24, pad = 36;
    const W = pad * 2 + cw * OPTIONS.length + gap * (OPTIONS.length - 1);
    const cells = OPTIONS.map((o) => `<div class="cell${o.rejected ? ' rej' : ''}"><div class="ct">${esc(o.title)}</div><img class="panel-img" src="${srv.base}/raw/${o.lineup}.png" width="${cw}" height="${ch}">
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
      <div class="sub">第 4 輪　項目 01 牛的外型（畫風已改回 R1-A 圓潤Q版，只換牛；五種都是胖胖可愛的牛）　每格：九頭同一比例＋剪影　2026-09-30</div>
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
