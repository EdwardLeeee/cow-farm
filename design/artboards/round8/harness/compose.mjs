// R8 拼圖：raw/ → 項目 01 一張選項圖（左牧場畫面、中側面、右正面）、項目 02 三張正面臉長度圖（只有正面排排站），與總覽。
// 總覽：上排 0 現況（第 7 輪）與第 8 輪；下排項目 02 的三種臉長。02-B 就是 01 用的臉長。
// 進 git 的是加標籤的圖：單張 DPR 2、總覽 DPR 1.5（ceo 2026-09-30：控制公開 repo 大小）；raw/ 的 PNG 不進 git。
// 用法：node harness/compose.mjs（先跑 capture.mjs）
import { chromium } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { startServer } from './server.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

export const OPTIONS = [
  { v: 'r7', item: '0 現況', title: '0 現況：第 7 輪', file: null, ref: '（對照）round7 的 R7-01-更像參考圖-A-側面9966正面9967', rejected: true,
    desc: '使用者要修：身體要有曲線、正面臉要長、母牛正面要有奶頭、尾巴太長、側面乳房看不出來',
    screen: 'r8-00-r7-mobile', side: 'r8-00-r7-side', front: 'r8-00-r7-front' },
  { v: 'r8', item: '01 依意見修改', title: '01-A 五處都改', file: 'R8-01-依意見修改-A-五處都改-mobile.png',
    desc: '身體有曲線（腿和身體連成一條外框）、正面臉變長（02-B）、母牛正面底部露出乳房、尾巴短到身體一半高、側面乳房畫清楚',
    screen: 'r8-r8-mobile', side: 'r8-lineup-side-r8', front: 'r8-lineup-front-r8' },
];
export const FACES = [
  { v: 'faceA', title: '02-A 稍長（臉高÷寬 1.1）', file: 'R8-02-正面臉的長度-A-稍長-mobile.png', front: 'r8-lineup-front-faceA' },
  { v: 'faceB', title: '02-B 長（臉高÷寬 1.25，01 用這個）', file: 'R8-02-正面臉的長度-B-長-mobile.png', front: 'r8-lineup-front-r8' },
  { v: 'faceC', title: '02-C 更長（臉高÷寬 1.4）', file: 'R8-02-正面臉的長度-C-更長-mobile.png', front: 'r8-lineup-front-faceC' },
];
const OVERVIEW = 'R8-99-總覽對照.png';
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
  if (o.screen) {
    const s = M[o.screen];
    const cut = s.clipped.length + s.outside.length + s.wrapped.length;
    ok(s.minFontSizeText >= 11 && cut === 0, `牧場畫面：最小字級 ${s.minFontSizeText}px、文字被截 ${cut} 處`);
    ok(s.minTab.w >= 44 && s.minTab.h >= 44 && s.safeArea.hudBelowStatusbar && s.safeArea.tabsAboveHome && !s.horizontalScroll,
      `分頁觸控 ${Math.round(s.minTab.w)}×${Math.round(s.minTab.h)}px、避開安全區、無橫向捲動`);
  }
  for (const [name, j] of [['側面', o.side], ['正面', o.front]]) {
    const lu = M[j];
    const bad = lu.outside.length + lu.figOverflow + lu.silNameOverlap;
    ok(lu.minFontSize >= 11 && bad === 0 && lu.calfRatio >= 0.55 && lu.calfRatio <= 0.6,
      `${name}排排站：最小字級 ${lu.minFontSize}px、名字被截或重疊 ${bad} 處、小牛是成牛的 ${Math.round(lu.calfRatio * 100)}%`);
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

async function main() {
  const srv = await startServer(ROOT);
  const browser = await chromium.launch();
  try {
    const M = {};
    for (const o of OPTIONS) for (const j of [o.screen, o.side, o.front]) M[j] = JSON.parse(await readFile(join(ROOT, 'raw', `${j}.json`), 'utf8'));
    for (const fc of FACES) M[fc.front] = JSON.parse(await readFile(join(ROOT, 'raw', `${fc.front}.json`), 'utf8'));

    // 項目 01：牧場畫面＋側面＋正面
    for (const o of OPTIONS.filter((x) => x.file)) {
      const label = o.file.replace(/\.png$/, '');
      const W = 36 + 410 + 28 + 720 + 24 + 720 + 36, H = 78 + 900 + 36;
      const html = `<!doctype html><html lang="zh-Hant-TW"><head><meta charset="utf-8"><style>${BASE_CSS}
        .wrap { width: ${W}px; height: ${H}px; position: relative; }
        .label { position: absolute; left: 24px; top: 24px; }
        .row { position: absolute; left: 36px; top: 78px; display: flex; gap: 24px; align-items: flex-start; } .row > .phone { margin-right: 4px; }
      </style></head><body><div class="wrap"><div class="label">${esc(label)}</div>
        <div class="row">${phone(`${srv.base}/raw/${o.screen}.png`)}<img class="panel-img" src="${srv.base}/raw/${o.side}.png" width="720" height="900"><img class="panel-img" src="${srv.base}/raw/${o.front}.png" width="720" height="900"></div></div></body></html>`;
      await shot(browser, html, W, H, 2, join(ROOT, o.file));
      console.log('ok', o.file);
    }
    // 項目 02：三種臉長，各一張正面排排站
    for (const fc of FACES) {
      const label = fc.file.replace(/\.png$/, '');
      const W = 36 + 720 + 36, H = 78 + 900 + 36;
      const html = `<!doctype html><html lang="zh-Hant-TW"><head><meta charset="utf-8"><style>${BASE_CSS}
        .wrap { width: ${W}px; height: ${H}px; position: relative; }
        .label { position: absolute; left: 24px; top: 24px; }
        .row { position: absolute; left: 36px; top: 78px; }
      </style></head><body><div class="wrap"><div class="label">${esc(label)}</div>
        <div class="row"><img class="panel-img" src="${srv.base}/raw/${fc.front}.png" width="720" height="900"></div></div></body></html>`;
      await shot(browser, html, W, H, 2, join(ROOT, fc.file));
      console.log('ok', fc.file);
    }

    // 總覽
    const cw = 900, gap = 36, pad = 36;
    const W = pad * 2 + cw * 2 + gap;
    const cells = OPTIONS.map((o) => `<div class="cell${o.rejected ? ' rej' : ''}"><div class="it">項目 ${esc(o.item)}</div><div class="ct">${esc(o.title)}</div><div style="display:flex;gap:12px"><img class="panel-img" src="${srv.base}/raw/${o.side}.png" width="${(cw - 12) / 2}"><img class="panel-img" src="${srv.base}/raw/${o.front}.png" width="${(cw - 12) / 2}"></div>
      <div class="fn">${esc(o.file || o.ref)}</div><div class="desc">${esc(o.desc)}</div>
      <div class="ms">${lines(o, M).map((l) => `<div class="m ${l.cls}">${esc(l.t)}</div>`).join('')}</div></div>`).join('');
    const fw = Math.floor((W - pad * 2 - 30 * 2) / 3);
    const faces = FACES.map((fc) => { const lu = M[fc.front]; return `<div class="cell" style="width:${fw}px"><div class="ct">${esc(fc.title)}</div><img class="panel-img" src="${srv.base}/raw/${fc.front}.png" width="${fw}">
      <div class="fn">${esc(fc.file)}</div><div class="ms"><div class="m ${lu.calfRatio >= 0.55 && lu.calfRatio <= 0.6 ? 'ok' : 'bad'}">${lu.calfRatio >= 0.55 && lu.calfRatio <= 0.6 ? '✓' : '✗'} 正面排排站：最小字級 ${lu.minFontSize}px、小牛是成牛的 ${Math.round(lu.calfRatio * 100)}%</div></div></div>`; }).join('');
    const html = `<!doctype html><html lang="zh-Hant-TW"><head><meta charset="utf-8"><style>${BASE_CSS}
      .wrap { width: ${W}px; padding: 24px ${pad}px 36px; }
      .sub { font: 500 14px/20px ${FONT}; color: #5B6270; margin-top: 4px; }
      .rowc { display: flex; gap: ${gap}px; margin-top: 20px; align-items: flex-start; }
      .rowf { display: flex; gap: 30px; margin-top: 12px; align-items: flex-start; }
      .h2 { font: 900 17px/24px ${FONT}; margin-top: 30px; }
      .cell { width: ${cw}px; }
      .it { font: 700 13px/18px ${FONT}; color: #5B6270; margin: 0 0 2px 4px; } .ct { font: 900 17px/24px ${FONT}; margin: 0 0 8px 4px; }
      .fn { font: 600 13px/18px ${MONO}; color: #2B303A; margin-top: 14px; word-break: break-all; }
      .desc { font: 700 16px/22px ${FONT}; margin-top: 6px; }
      .ms { margin-top: 8px; } .m { font: 500 13px/20px ${FONT}; }
      .m.ok { color: #16833F; } .m.bad { color: #D22F2F; font-weight: 700; } .m.note { color: #7A808C; }
      .rej .panel-img { opacity: 0.85; filter: grayscale(0.25); } .rej .desc { color: #9A3B32; } .rej .ct { color: #7A808C; }
    </style></head><body><div class="wrap">
      <div class="label">${esc(OVERVIEW.replace(/\.png$/, ''))}</div>
      <div class="sub">第 8 輪　依第 7 輪意見修改：身體要有曲線、正面臉要長、母牛正面要有奶頭、尾巴改短、側面乳房畫清楚　線條 B　每格：左側面、右正面，各九頭同一比例＋剪影　2026-09-30</div>
      <div class="rowc">${cells}</div>
      <div class="h2">項目 02 正面臉的長度（只看正面；02-B 就是上面 01 用的）</div>
      <div class="rowf">${faces}</div></div></body></html>`;
    await shot(browser, html, W, 800, 1.5, join(ROOT, OVERVIEW), true);
    console.log('ok', OVERVIEW);
  } finally {
    await browser.close();
    await srv.close();
  }
}

const watchdog = setTimeout(() => { console.error('compose timeout (180s)'); process.exit(2); }, 180000);
main().then(() => clearTimeout(watchdog)).catch((e) => { console.error(e); process.exit(1); });
