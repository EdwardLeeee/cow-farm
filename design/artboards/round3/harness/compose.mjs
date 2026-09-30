// R3 拼圖：raw/ → 五張畫風單張圖（DPR 3，不縮放：左牧場畫面、右七頭排排站）與總覽（DPR 2）。
// 用法：node harness/compose.mjs（先跑 capture.mjs）
import { chromium } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { startServer } from './server.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
export const OPTIONS = [
  { k: '0', screen: 'r3-00-control-mobile', lineup: 'r3-00-control-lineup', lineupW: 720, file: null, ref: '（對照）round2/R2-01-牛的造型-C-側面輪廓-mobile.png', title: '0 現況', desc: 'R2-C 側面輪廓（R1-A 粗描邊畫風）' },
  { k: 'a', file: 'R3-01-美術風格-A-水彩繪本-mobile.png', title: 'A 水彩繪本', desc: '水彩暈染、紙紋、鉛筆線，溫暖柔和' },
  { k: 'b', file: 'R3-01-美術風格-B-剪紙拼貼-mobile.png', title: 'B 剪紙拼貼', desc: '一層層色紙，邊緣不規則、底下有小陰影' },
  { k: 'c', file: 'R3-01-美術風格-C-扁平幾何-mobile.png', title: 'C 扁平幾何', desc: '沒有描邊的大色塊與切面幾何，配色大膽' },
  { k: 'd', file: 'R3-01-美術風格-D-復古農場海報-mobile.png', title: 'D 復古農場海報', desc: '低飽和、網點陰影、放射光芒、明體標題' },
  { k: 'e', file: 'R3-01-美術風格-E-日系手帳線稿-mobile.png', title: 'E 日系手帳線稿', desc: '細線條加淡彩、米白點格紙、紙膠帶' },
].map((o) => ({ screen: `r3-01-${o.k}-mobile`, lineup: `r3-lineup-${o.k}`, lineupW: 640, ...o }));
const OVERVIEW = 'R3-99-總覽對照.png';
const FONT = `"Noto Sans CJK TC", sans-serif`;
const MONO = `"Noto Sans Mono CJK TC", "Noto Sans CJK TC", monospace`;
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const BASE_CSS = `
  * { box-sizing: border-box; } html, body { margin: 0; }
  body { background: #ECEEF1; font-family: ${FONT}; color: #1F2329; }
  .phone { background: #16161A; box-shadow: 0 18px 40px rgba(20, 24, 32, 0.22), inset 0 0 0 2px #2C2C33; }
  .label { font: 700 18px/24px ${FONT}; color: #1F2329; letter-spacing: 0.2px; }
  .panel-img { display: block; border-radius: 22px; box-shadow: 0 14px 32px rgba(20, 24, 32, 0.16); }
`;
function phone(src, scale = 1) {
  const W = 390 * scale, H = 844 * scale, b = 10 * scale;
  return `<div class="phone" style="width:${W + b * 2}px;height:${H + b * 2}px;padding:${b}px;border-radius:${56 * scale}px;flex:none"><img src="${src}" width="${W}" height="${H}" style="display:block;border-radius:${46 * scale}px"></div>`;
}
function lines(o, M) {
  const s = M[o.screen], lu = M[o.lineup], L = [];
  const ok = (good, t) => L.push({ cls: good ? 'ok' : 'bad', t: `${good ? '✓' : '✗'} ${t}` });
  const cut = s.clipped.length + s.outside.length + s.wrapped.length;
  ok(s.minFontSizeText >= 11 && cut === 0, `牧場畫面：最小字級 ${s.minFontSizeText}px、文字被截 ${cut} 處`);
  const bad = lu.outside.length + lu.figOverflow;
  ok(lu.minFontSize >= 11 && bad === 0, `排排站：最小字級 ${lu.minFontSize}px、名字被截 ${bad} 處`);
  if (o.k !== '0') ok(s.minTab.w >= 44 && s.minTab.h >= 44 && s.safeArea.hudBelowStatusbar && s.safeArea.tabsAboveHome && !s.horizontalScroll, `分頁觸控 ${Math.round(s.minTab.w)}×${Math.round(s.minTab.h)}px、避開安全區`);
  else L.push({ cls: 'note', t: '・第 2 輪的量測，這輪沒有重拍' });
  return L;
}

async function main() {
  const srv = await startServer(ROOT);
  const browser = await chromium.launch();
  try {
    const M = {};
    for (const o of OPTIONS) for (const j of [o.screen, o.lineup]) M[j] = JSON.parse(await readFile(join(ROOT, 'raw', `${j}.json`), 'utf8'));
    for (const o of OPTIONS.filter((x) => x.file)) {
      const W = 36 + 410 + 28 + 640 + 36, H = 78 + 864 + 36;
      const html = `<!doctype html><html lang="zh-Hant-TW"><head><meta charset="utf-8"><style>${BASE_CSS}
        .wrap { width: ${W}px; height: ${H}px; position: relative; } .label { position: absolute; left: 24px; top: 24px; }
        .row { position: absolute; left: 36px; top: 78px; display: flex; gap: 28px; align-items: flex-start; }
      </style></head><body><div class="wrap"><div class="label">${esc(o.file.replace(/\.png$/, ''))}</div>
      <div class="row">${phone(`${srv.base}/raw/${o.screen}.png`)}<img class="panel-img" src="${srv.base}/raw/${o.lineup}.png" width="640" height="864"></div></div></body></html>`;
      const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 3, locale: 'zh-TW', colorScheme: 'light' });
      const page = await ctx.newPage();
      await page.setContent(html, { waitUntil: 'load' });
      await page.evaluate(() => document.fonts.ready);
      await page.screenshot({ path: join(ROOT, o.file) });
      await ctx.close();
      console.log('ok', o.file);
    }
    // 總覽：最左邊一格小的 0 現況，接著五種畫風；每格＝縮小的牧場畫面＋七頭排排站，下面印檔名、描述、量測
    const cells = OPTIONS.map((o) => {
      const small = o.k === '0';
      const cw = small ? 250 : 330;
      const ps = small ? 0.5 : 0.62, lw = cw, lh = Math.round((864 / o.lineupW) * lw);
      return `<div class="cell" style="width:${cw}px"><div class="ct">${esc(o.title)}</div>
        <div class="stack">${phone(`${srv.base}/raw/${o.screen}.png`, ps)}<img class="panel-img" src="${srv.base}/raw/${o.lineup}.png" width="${lw}" height="${lh}" style="border-radius:14px"></div>
        <div class="fn">${esc(o.file || o.ref)}</div><div class="desc">${esc(o.desc)}</div>
        <div class="ms">${lines(o, M).map((l) => `<div class="m ${l.cls}">${esc(l.t)}</div>`).join('')}</div></div>`;
    }).join('');
    const W = 36 * 2 + 250 + 330 * 5 + 26 * 5;
    const html = `<!doctype html><html lang="zh-Hant-TW"><head><meta charset="utf-8"><style>${BASE_CSS}
      .wrap { width: ${W}px; padding: 24px 36px 36px; }
      .sub { font: 500 14px/20px ${FONT}; color: #5B6270; margin-top: 4px; }
      .rowc { display: flex; gap: 26px; margin-top: 20px; align-items: flex-start; }
      .ct { font: 900 17px/24px ${FONT}; margin: 0 0 8px 2px; }
      .stack { display: flex; flex-direction: column; align-items: center; gap: 12px; }
      .fn { font: 600 12px/17px ${MONO}; color: #2B303A; margin-top: 12px; word-break: break-all; }
      .desc { font: 700 15px/21px ${FONT}; margin-top: 5px; }
      .ms { margin-top: 6px; } .m { font: 500 12px/19px ${FONT}; }
      .m.ok { color: #16833F; } .m.bad { color: #D22F2F; font-weight: 700; } .m.note { color: #7A808C; }
    </style></head><body><div class="wrap">
      <div class="label">${esc(OVERVIEW.replace(/\.png$/, ''))}</div>
      <div class="sub">第 3 輪　項目 01 美術風格（五種新畫風；牛延用 R2-C 側面造型、小牛比例已修）　每格：牧場畫面＋七頭排排站　2026-09-30</div>
      <div class="rowc">${cells}</div></div></body></html>`;
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
const watchdog = setTimeout(() => { console.error('compose timeout (180s)'); process.exit(2); }, 180000);
main().then(() => clearTimeout(watchdog)).catch((e) => { console.error(e); process.exit(1); });
