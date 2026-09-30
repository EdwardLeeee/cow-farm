// R11 拼圖：raw/ → 項目 01 三張（牧場畫面＋正面 12 頭＋乳房特寫）、項目 02 一張（側面 12 頭＋正面 12 頭＋新耕牛特寫）、總覽。
// 01-A（乳房中）也是項目 02 那張用的組合。
// 進 git 的是加標籤的圖：單張 DPR 2、總覽 DPR 1.5（ceo 2026-09-30：控制公開 repo 大小）；raw/ 的 PNG 不進 git。
// 用法：node harness/compose.mjs（先跑 capture.mjs）
import { chromium } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { startServer } from './server.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

const CONTROL = { title: '0 現況：第 10 輪（01-A 奶頭畫在乳房上）', udder: 'r11-00-r10-udder', side: 'r11-00-r10-side', front: 'r11-00-r10-front', ref: '（對照）round10 的 R10-01-奶頭-A-畫在乳房上',
  desc: '使用者：「不如就肚子中間劃一圈沒有框的粉紅色就代表乳房，你試試看」' };
export const ITEM1 = [
  { title: '01-A 中（直徑約身體寬的 28%）', file: 'R11-01-乳房-A-中-mobile.png', screen: 'r11-r11-mobile', front: 'r11-lineup-front-r11', udder: 'r11-closeup-udder-udderM',
    desc: '肚子中間一塊沒有外框的粉紅圓，大小中等；只有成年母乳牛有（荷斯坦、娟珊、巧克力牛、草莓牛）' },
  { title: '01-B 小（直徑約身體寬的 20%）', file: 'R11-01-乳房-B-小-mobile.png', screen: 'r11-udderS-mobile', front: 'r11-lineup-front-udderS', udder: 'r11-closeup-udder-udderS',
    desc: '一樣的粉紅圓，小一點，比較不搶眼' },
  { title: '01-C 大（直徑約身體寬的 36%）', file: 'R11-01-乳房-C-大-mobile.png', screen: 'r11-udderL-mobile', front: 'r11-lineup-front-udderL', udder: 'r11-closeup-udder-udderL',
    desc: '一樣的粉紅圓，大一點，遠遠就看得出是母乳牛' },
];
export const ITEM2 = { title: '02 新名單（只有一個版本）', file: 'R11-02-新名單-A-乳牛耕牛肉牛-mobile.png', side: 'r11-lineup-side-r11', front: 'r11-lineup-front-r11', closeup: 'r11-closeup-v02-r11',
  desc: '12 頭：乳牛（荷斯坦母、公、小牛、娟珊、巧克力牛、草莓牛）、耕牛（台灣黃牛有肩峰、高地牛、台灣水牛有水牛角）、肉牛（安格斯炭灰、和牛黑亮加短角、夏洛來）' };
const OVERVIEW = 'R11-99-總覽對照.png';
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

function mLines(ids, M, withScreen) {
  const L = [];
  const ok = (good, t) => L.push({ cls: good ? 'ok' : 'bad', t: `${good ? '✓' : '✗'} ${t}` });
  if (withScreen) {
    const s = M[withScreen];
    const cut = s.clipped.length + s.outside.length + s.wrapped.length;
    ok(s.minFontSizeText >= 11 && cut === 0, `牧場畫面：最小字級 ${s.minFontSizeText}px、文字被截 ${cut} 處`);
    ok(s.minTab.w >= 44 && s.minTab.h >= 44 && s.safeArea.hudBelowStatusbar && s.safeArea.tabsAboveHome && !s.horizontalScroll,
      `分頁觸控 ${Math.round(s.minTab.w)}×${Math.round(s.minTab.h)}px、避開安全區、無橫向捲動`);
  }
  for (const [name, j] of ids) {
    const lu = M[j];
    const bad = lu.outside.length + lu.figOverflow + lu.silNameOverlap;
    const calf = lu.calfRatio ? `、小牛是成牛的 ${Math.round(lu.calfRatio * 100)}%` : '';
    ok(lu.minFontSize >= 11 && bad === 0 && (!lu.calfRatio || (lu.calfRatio >= 0.55 && lu.calfRatio <= 0.6)), `${name}：最小字級 ${lu.minFontSize}px、名字被截或重疊 ${bad} 處${calf}`);
  }
  return L;
}
async function shot(browser, html, W, H, dpr, path, full = false) {
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: dpr, locale: 'zh-TW', colorScheme: 'light' });
  const page = await ctx.newPage();
  await page.setContent(html, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path, fullPage: full });
  await ctx.close();
}
const labelPage = (W, H, label, body) => `<!doctype html><html lang="zh-Hant-TW"><head><meta charset="utf-8"><style>${BASE_CSS}
  .wrap { width: ${W}px; height: ${H}px; position: relative; } .label { position: absolute; left: 24px; top: 24px; }
  .row { position: absolute; left: 36px; top: 78px; display: flex; gap: 24px; align-items: flex-start; } .row > .phone { margin-right: 4px; }
</style></head><body><div class="wrap"><div class="label">${esc(label)}</div><div class="row">${body}</div></div></body></html>`;


async function main() {
  const srv = await startServer(ROOT);
  const browser = await chromium.launch();
  const img = (j, w, h) => `<img class="panel-img" src="${srv.base}/raw/${j}.png" width="${w}"${h ? ` height="${h}"` : ''}>`;
  try {
    const M = {};
    const need = new Set([CONTROL.udder, CONTROL.side, CONTROL.front, ...ITEM1.flatMap((o) => [o.screen, o.front, o.udder]), ITEM2.side, ITEM2.front, ITEM2.closeup]);
    for (const j of need) M[j] = JSON.parse(await readFile(join(ROOT, 'raw', `${j}.json`), 'utf8'));

    for (const o of ITEM1) {
      const W = 36 + 410 + 28 + 720 + 24 + 720 + 36, H = 78 + 1080 + 36;
      await shot(browser, labelPage(W, H, o.file.replace(/\.png$/, ''), `${phone(`${srv.base}/raw/${o.screen}.png`)}${img(o.front, 720, 1080)}${img(o.udder, 720, 900)}`), W, H, 2, join(ROOT, o.file));
      console.log('ok', o.file);
    }
    {
      const o = ITEM2, W = 36 + 720 + 24 + 720 + 24 + 720 + 36, H = 78 + 1080 + 36;
      await shot(browser, labelPage(W, H, o.file.replace(/\.png$/, ''), `${img(o.side, 720, 1080)}${img(o.front, 720, 1080)}${img(o.closeup, 720, 900)}`), W, H, 2, join(ROOT, o.file));
      console.log('ok', o.file);
    }

    // 總覽
    const cw = 560, gap = 28, pad = 36;
    const W = pad * 2 + cw * 4 + gap * 3;
    const cell = (title, body, fn, desc, ms, rej = false) => `<div class="cell${rej ? ' rej' : ''}"><div class="ct">${esc(title)}</div>${body}
      <div class="fn">${esc(fn)}</div><div class="desc">${esc(desc)}</div><div class="ms">${ms.map((l) => `<div class="m ${l.cls}">${esc(l.t)}</div>`).join('')}</div></div>`;
    const sec1 = [
      cell(CONTROL.title, img(CONTROL.udder, cw), CONTROL.ref, CONTROL.desc, [], true),
      ...ITEM1.map((o) => cell(o.title, img(o.udder, cw), o.file, o.desc, mLines([['正面排排站', o.front], ['乳房特寫', o.udder]], M, o.screen))),
    ].join('');
    const sec2 = [
      cell('0 現況：第 10 輪・側面', img(CONTROL.side, cw), CONTROL.ref, '舊名單（西門塔爾是兼用）', [], true),
      cell('第 11 輪・側面 12 頭', img(ITEM2.side, cw), ITEM2.file, '乳牛、耕牛、肉牛各一排；側面不畫乳房', mLines([['側面排排站', ITEM2.side]], M)),
      cell('第 11 輪・正面 12 頭', img(ITEM2.front, cw), ITEM2.file, '正面只有成年母乳牛有粉紅圓乳房（這裡是中）', mLines([['正面排排站', ITEM2.front]], M)),
      cell('新耕牛特寫', img(ITEM2.closeup, cw), ITEM2.file, '台灣黃牛：肩上圓圓的肩峰；台灣水牛：石板灰、白色亮光、向後彎的大水牛角；下面是和牛與安格斯在牧場上的大小', mLines([['特寫', ITEM2.closeup]], M)),
    ].join('');
    const html = `<!doctype html><html lang="zh-Hant-TW"><head><meta charset="utf-8"><style>${BASE_CSS}
      .wrap { width: ${W}px; padding: 24px ${pad}px 36px; }
      .sub { font: 500 14px/20px ${FONT}; color: #5B6270; margin-top: 4px; }
      .h2 { font: 900 18px/26px ${FONT}; margin-top: 34px; } .h2 small { font: 600 13px/20px ${FONT}; color: #5B6270; margin-left: 8px; }
      .rowc { display: flex; gap: ${gap}px; margin-top: 12px; align-items: flex-start; }
      .cell { width: ${cw}px; }
      .ct { font: 900 16px/24px ${FONT}; margin: 0 0 8px 4px; }
      .fn { font: 600 12px/17px ${MONO}; color: #2B303A; margin-top: 12px; word-break: break-all; }
      .desc { font: 700 15px/21px ${FONT}; margin-top: 6px; }
      .ms { margin-top: 8px; } .m { font: 500 12.5px/19px ${FONT}; }
      .m.ok { color: #16833F; } .m.bad { color: #D22F2F; font-weight: 700; } .m.note { color: #7A808C; }
      .rej .panel-img { opacity: 0.85; filter: grayscale(0.25); } .rej .desc { color: #9A3B32; } .rej .ct { color: #7A808C; }
    </style></head><body><div class="wrap">
      <div class="label">${esc(OVERVIEW.replace(/\.png$/, ''))}</div>
      <div class="sub">第 11 輪　依第 10 輪選擇：乳房改沒有外框的粉紅圓（試畫三種大小）、和牛黑亮加短角、黑牛毛改炭灰；企劃書 v0.2 新名單（乳牛、耕牛、肉牛，只有成年母乳牛有乳房）　線條 B　2026-09-30</div>
      <div class="h2">項目 01 乳房（沒有外框的粉紅圓）<small>乳房特寫；01-A 也是項目 02 用的大小</small></div><div class="rowc">${sec1}</div>
      <div class="h2">項目 02 新名單<small>只有一個版本；台灣黃牛的肩峰、台灣水牛的角是新設計</small></div><div class="rowc">${sec2}</div>
    </div></body></html>`;
    await shot(browser, html, W, 800, 1.5, join(ROOT, OVERVIEW), true);
    console.log('ok', OVERVIEW);
  } finally {
    await browser.close();
    await srv.close();
  }
}

const watchdog = setTimeout(() => { console.error('compose timeout (180s)'); process.exit(2); }, 180000);
main().then(() => clearTimeout(watchdog)).catch((e) => { console.error(e); process.exit(1); });
