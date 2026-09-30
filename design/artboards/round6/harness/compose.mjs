// R6 拼圖：raw/ → 四張選項圖（左牧場畫面、中側面排排站、右正面排排站）與總覽。01-A 與 02-B 是同一個組合，分別放在兩個項目裡對照。
// 進 git 的是加標籤的圖：單張 DPR 2、總覽 DPR 1.5（ceo 2026-09-30：控制公開 repo 大小）；raw/ 的 PNG 不進 git。
// 用法：node harness/compose.mjs（先跑 capture.mjs）
import { chromium } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { startServer } from './server.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

export const OPTIONS = [
  { v: 'sitSame', item: '01 正面的姿勢', title: '01-A 坐著', file: 'R6-01-正面的姿勢-A-坐著-mobile.png', desc: '正面照 9967 坐著：後腳從身體兩側伸出來，前腳收在肚子前（臉：兩個角度同一張）' },
  { v: 'standSame', item: '01 正面的姿勢', title: '01-B 站著', file: 'R6-01-正面的姿勢-B-站著-mobile.png', desc: '正面站著：前腳在胸口下方，後腳從兩側後面露出來（臉：兩個角度同一張）' },
  { v: 'sitRef', item: '02 臉', title: '02-A 各照參考圖', file: 'R6-02-臉-A-各照參考圖-mobile.png', desc: '側面用 9966 的臉（蛋形、眼距寬、淺橘橫條口鼻），正面用 9967 的臉；牛轉身時臉會變（正面：坐著）' },
  { v: 'sitSame', item: '02 臉', title: '02-B 兩個角度同一張臉', file: 'R6-02-臉-B-兩個角度同一張臉-mobile.png', desc: '側面和正面都用 9967 的臉（寬臉、眼距近、粉紅橢圓口鼻加鼻孔）；轉身時臉不變（正面：坐著）' },
].map((o) => ({ ...o, screen: `r6-${o.v}-mobile`, side: `r6-lineup-side-${o.v}`, front: `r6-lineup-front-${o.v}` }));
const OVERVIEW = 'R6-99-總覽對照.png';
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

async function main() {
  const srv = await startServer(ROOT);
  const browser = await chromium.launch();
  try {
    const M = {};
    for (const o of OPTIONS) for (const j of [o.screen, o.side, o.front]) M[j] = JSON.parse(await readFile(join(ROOT, 'raw', `${j}.json`), 'utf8'));

    for (const o of OPTIONS.filter((x) => x.file)) {
      const label = o.file.replace(/\.png$/, '');
      const W = 36 + 410 + 28 + 720 + 24 + 720 + 36, H = 78 + 900 + 36;
      const html = `<!doctype html><html lang="zh-Hant-TW"><head><meta charset="utf-8"><style>${BASE_CSS}
        .wrap { width: ${W}px; height: ${H}px; position: relative; }
        .label { position: absolute; left: 24px; top: 24px; }
        .row { position: absolute; left: 36px; top: 78px; display: flex; gap: 24px; align-items: flex-start; } .row > .phone { margin-right: 4px; }
      </style></head><body><div class="wrap"><div class="label">${esc(label)}</div>
        <div class="row">${phone(`${srv.base}/raw/${o.screen}.png`)}<img class="panel-img" src="${srv.base}/raw/${o.side}.png" width="720" height="900"><img class="panel-img" src="${srv.base}/raw/${o.front}.png" width="720" height="900"></div></div></body></html>`;
      const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, locale: 'zh-TW', colorScheme: 'light' });
      const page = await ctx.newPage();
      await page.setContent(html, { waitUntil: 'load' });
      await page.evaluate(() => document.fonts.ready);
      await page.screenshot({ path: join(ROOT, o.file) });
      await ctx.close();
      console.log('ok', o.file);
    }

    // 總覽：四格並排（01-A、01-B、02-A、02-B），每格上面側面、下面正面，下面印檔名、白話描述、量測
    const cw = 440, gap = 28, pad = 36;
    const W = pad * 2 + cw * OPTIONS.length + gap * (OPTIONS.length - 1);
    const cells = OPTIONS.map((o) => `<div class="cell"><div class="it">項目 ${esc(o.item)}</div><div class="ct">${esc(o.title)}</div><img class="panel-img" src="${srv.base}/raw/${o.side}.png" width="${cw}"><img class="panel-img" style="margin-top:12px" src="${srv.base}/raw/${o.front}.png" width="${cw}">
      <div class="fn">${esc(o.file)}</div><div class="desc">${esc(o.desc)}</div>
      <div class="ms">${lines(o, M).map((l) => `<div class="m ${l.cls}">${esc(l.t)}</div>`).join('')}</div></div>`).join('');
    const html = `<!doctype html><html lang="zh-Hant-TW"><head><meta charset="utf-8"><style>${BASE_CSS}
      .wrap { width: ${W}px; padding: 24px ${pad}px 36px; }
      .sub { font: 500 14px/20px ${FONT}; color: #5B6270; margin-top: 4px; }
      .rowc { display: flex; gap: ${gap}px; margin-top: 20px; align-items: flex-start; }
      .cell { width: ${cw}px; }
      .it { font: 700 13px/18px ${FONT}; color: #5B6270; margin: 0 0 2px 4px; } .ct { font: 900 17px/24px ${FONT}; margin: 0 0 8px 4px; }
      .fn { font: 600 13px/18px ${MONO}; color: #2B303A; margin-top: 14px; word-break: break-all; }
      .desc { font: 700 16px/22px ${FONT}; margin-top: 6px; }
      .ms { margin-top: 8px; } .m { font: 500 13px/20px ${FONT}; }
      .m.ok { color: #16833F; } .m.bad { color: #D22F2F; font-weight: 700; } .m.note { color: #7A808C; }
      .rej .panel-img { opacity: 0.85; filter: grayscale(0.25); } .rej .desc { color: #9A3B32; } .rej .ct { color: #7A808C; }
    </style></head><body><div class="wrap">
      <div class="label">${esc(OVERVIEW.replace(/\.png$/, ''))}</div>
      <div class="sub">第 6 輪　線條已定為 B 乾淨中線；側面照 9966（身體橫著、臉朝你），正面照 9967（整頭牛面向你）　項目 01 正面的姿勢、項目 02 臉　01-A 與 02-B 是同一個組合　每格：上側面、下正面，各九頭同一比例＋剪影　2026-09-30</div>
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
