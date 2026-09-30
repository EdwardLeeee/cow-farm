// R10 拼圖：raw/ → 項目 01 兩張（牧場畫面＋側面＋正面＋乳房特寫）、項目 02 三張與項目 03 兩張（和牛與安格斯特寫）、總覽。
// 02-A 與 03-A 是同一個組合（黑亮＋線條改淺），分別放在兩個項目裡對照；01-A 也用這個組合。
// 進 git 的是加標籤的圖：單張 DPR 2、總覽 DPR 1.5（ceo 2026-09-30：控制公開 repo 大小）；raw/ 的 PNG 不進 git。
// 用法：node harness/compose.mjs（先跑 capture.mjs）
import { chromium } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { startServer } from './server.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

const CONTROL = { title: '0 現況：第 9 輪', screen: 'r10-00-r9-mobile', side: 'r10-00-r9-side', front: 'r10-00-r9-front', ref: '（對照）round9 的 R9-01-乳房在肚子上-A-母牛放大公牛更大',
  desc: '奶頭從乳房下緣垂下來；使用者：「乳頭就是在你那個正面粉粉的牛胸部上」' };
export const ITEM1 = [
  { title: '01-A 四個奶頭畫在乳房上', file: 'R10-01-奶頭-A-畫在乳房上-mobile.png', screen: 'r10-r10-mobile', side: 'r10-lineup-side-r10', front: 'r10-lineup-front-r10', udder: 'r10-closeup-udder-teatsOn4',
    desc: '乳房照第 9 輪在肚子上；四個玫瑰色奶頭畫在粉紅乳房的下半部，不再垂下來。這張也看得到其他改動：側面拿掉乳房、臉長 A、和牛黑亮、黑牛線條改淺' },
  { title: '01-B 四個奶頭貼在乳房下緣', file: 'R10-01-奶頭-B-貼在乳房下緣-mobile.png', screen: 'r10-teatsEdge4-mobile', side: 'r10-lineup-side-r10', front: 'r10-lineup-front-teatsEdge4', udder: 'r10-closeup-udder-teatsEdge4',
    desc: '四個短短的奶頭貼在乳房下緣：上半截在乳房上、下半截稍微露出來；其他和 01-A 一樣' },
];
export const ITEM2 = [
  { title: '02-A 黑亮', file: 'R10-02-和牛-A-黑亮-mobile.png', closeup: 'r10-closeup-wagyuShine', desc: '和牛是全黑，背上和肩膀有一道乾淨的白色亮光；安格斯是沒有亮光的黑' },
  { title: '02-B 深紅棕亮毛', file: 'R10-02-和牛-B-深紅棕亮毛-mobile.png', closeup: 'r10-closeup-wagyuRed', desc: '和牛改成深紅棕色（像褐毛和牛），一樣有白色亮光；選這個要改企劃書的和牛毛色' },
  { title: '02-C 黑亮加短角', file: 'R10-02-和牛-C-黑亮加短角-mobile.png', closeup: 'r10-closeup-wagyuHorns', desc: '和牛黑亮，再加一對短角（真的和牛有角）；選這個要把「肉用一律無角」改成「和牛系例外，有短角」' },
];
export const ITEM3 = [
  { title: '03-A 毛不變、線條改淺', file: 'R10-03-黑牛的線條-A-線條改淺-mobile.png', closeup: 'r10-closeup-wagyuShine', desc: '黑牛還是全黑，外框和身上的線改成淺一點的灰棕色，線條看得清楚（01 用這個）' },
  { title: '03-B 毛改炭灰、線條更深', file: 'R10-03-黑牛的線條-B-毛改炭灰-mobile.png', closeup: 'r10-closeup-darkCharcoal', desc: '黑牛的毛改成炭灰色，線條改成更深的黑，線條看得清楚，但牛看起來偏灰' },
];
const OVERVIEW = 'R10-99-總覽對照.png';
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
    const need = new Set([CONTROL.screen, CONTROL.side, CONTROL.front, ...ITEM1.flatMap((o) => [o.screen, o.side, o.front, o.udder]), ...ITEM2.map((o) => o.closeup), ...ITEM3.map((o) => o.closeup)]);
    for (const j of need) M[j] = JSON.parse(await readFile(join(ROOT, 'raw', `${j}.json`), 'utf8'));

    for (const o of ITEM1) {
      const W = 36 + 410 + 28 + 720 + 24 + 720 + 24 + 720 + 36, H = 78 + 900 + 36;
      await shot(browser, labelPage(W, H, o.file.replace(/\.png$/, ''), `${phone(`${srv.base}/raw/${o.screen}.png`)}${img(o.side, 720, 900)}${img(o.front, 720, 900)}${img(o.udder, 720, 900)}`), W, H, 2, join(ROOT, o.file));
      console.log('ok', o.file);
    }
    for (const o of [...ITEM2, ...ITEM3]) {
      const W = 36 + 720 + 36, H = 78 + 900 + 36;
      await shot(browser, labelPage(W, H, o.file.replace(/\.png$/, ''), img(o.closeup, 720, 900)), W, H, 2, join(ROOT, o.file));
      console.log('ok', o.file);
    }

    // 總覽
    const cw = 560, gap = 28, pad = 36;
    const W = pad * 2 + cw * 3 + gap * 2;
    const cell = (title, body, fn, desc, ms, rej = false) => `<div class="cell${rej ? ' rej' : ''}"><div class="ct">${esc(title)}</div>${body}
      <div class="fn">${esc(fn)}</div><div class="desc">${esc(desc)}</div><div class="ms">${ms.map((l) => `<div class="m ${l.cls}">${esc(l.t)}</div>`).join('')}</div></div>`;
    const sec1 = [
      cell(CONTROL.title, img(CONTROL.front, cw), CONTROL.ref, CONTROL.desc, [], true),
      ...ITEM1.map((o) => cell(o.title, img(o.udder, cw), o.file, o.desc, mLines([['正面排排站', o.front], ['乳房特寫', o.udder]], M, o.screen))),
    ].join('');
    const sec1b = [
      cell('0 現況：第 9 輪・側面', img(CONTROL.side, cw), CONTROL.ref, '側面有乳房', [], true),
      cell('第 10 輪・側面（01-A、01-B 都一樣）', img(ITEM1[0].side, cw), ITEM1[0].file, '側面拿掉乳房；黑牛線條改淺；和牛黑亮', mLines([['側面排排站', ITEM1[0].side]], M)),
    ].join('');
    const sec2 = ITEM2.map((o) => cell(o.title, img(o.closeup, cw), o.file, o.desc, mLines([['特寫', o.closeup]], M))).join('');
    const sec3 = ITEM3.map((o) => cell(o.title, img(o.closeup, cw), o.file, o.desc, mLines([['特寫', o.closeup]], M))).join('');
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
      <div class="sub">第 10 輪　依第 9 輪意見與澄清：奶頭畫在正面的粉紅乳房上、和牛重新設計、側面拿掉乳房、正面臉長 A、黑牛線條　線條 B　2026-09-30</div>
      <div class="h2">項目 01 奶頭畫在乳房上<small>0 現況是第 9 輪的正面；01-A、01-B 是乳房特寫；01-A 的組合也用在 02-A、03-A</small></div><div class="rowc">${sec1}</div>
      <div class="h2">側面<small>所有選項都一樣：拿掉乳房</small></div><div class="rowc">${sec1b}</div>
      <div class="h2">項目 02 和牛<small>上：放大；下：牧場上的實際大小</small></div><div class="rowc">${sec2}</div>
      <div class="h2">項目 03 黑牛的線條<small>03-A 就是 02-A 那張</small></div><div class="rowc">${sec3}</div>
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
