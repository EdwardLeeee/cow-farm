// M4 app 圖示：出草稿說明圖、總覽，以及選定方向的實作檔。
// 用法（在 design/artboards/m4-icon 底下跑；用 design/m2 的 Playwright 和靜態伺服器）：
//   node harness/make.mjs 1           第 1 輪三個方向的說明圖、總覽
//   node harness/make.mjs 2           第 2 輪（照 A 的畫法換品種）的說明圖、總覽
//   node harness/make.mjs export A4   把選定的方向匯出到 design/m4/icon/（D32 選 A4 娟珊）
import { chromium } from '../../../m2/node_modules/playwright/index.mjs';
import { startServer } from '../../../m2/harness/server.mjs';
import { mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = join(dirname(fileURLToPath(import.meta.url)), '..');
const DESIGN = join(HERE, '..', '..');
const ROUNDS = {
  1: { prefix: 'M4-ICON-01', names: { A: '牛臉特寫', B: '山坡上的牛', C: '金幣項圈' } },
  2: { prefix: 'M4-ICON-02', names: { A1: '荷斯坦', A2: '台灣黃牛', A3: '安格斯', A4: '娟珊', A5: '台灣水牛', A6: '高地牛' } },
};
const srv = await startServer(DESIGN);
const browser = await chromium.launch();
const url = (qs) => `${srv.base}/artboards/m4-icon/src/icon.html?${qs}`;
async function shot(qs, path, { w, h, dpr = 1, transparent = false, full = false }) {
  const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: dpr, colorScheme: 'light' });
  const page = await ctx.newPage();
  const errs = [];
  page.on('pageerror', (e) => errs.push(String(e)));
  await page.goto(url(qs));
  await page.waitForFunction(() => window.__ready === true, null, { timeout: 30000 });
  if (full) {
    const box = await page.evaluate(() => { const b = document.querySelector('.board'); return { w: Math.ceil(b.offsetWidth), h: Math.ceil(b.offsetHeight) }; });
    await page.setViewportSize({ width: box.w, height: box.h });
  }
  await page.screenshot({ path, omitBackground: transparent, fullPage: full });
  await ctx.close();
  console.log(`${errs.length ? '!!' : 'ok'} ${path.replace(DESIGN + '/', '')}${errs.length ? ' ' + errs.join('|') : ''}`);
}
try {
  if (process.argv[2] === 'export') {
    // 實作檔：iOS 原圖、Android adaptive icon 兩層、Google Play、網頁版（只給內部試玩的 Flutter 網頁版用）
    const o = process.argv[3];
    if (!o) throw new Error('要指定選項，例如 node harness/make.mjs export A4');
    const out = join(DESIGN, 'm4', 'icon');
    await mkdir(out, { recursive: true });
    const files = [
      [`v=icon&o=${o}`, 'ios-1024.png', 1024],
      [`v=fg&o=${o}`, 'android-前景-432.png', 432, true],
      [`v=bg&o=${o}`, 'android-背景-432.png', 432],
      [`v=icon&o=${o}&px=512`, 'play-512.png', 512],
      [`v=icon&o=${o}&px=32`, 'web-favicon-32.png', 32],
      [`v=icon&o=${o}&px=192`, 'web-192.png', 192],
      [`v=icon&o=${o}&px=512`, 'web-512.png', 512],
      [`v=android&o=${o}&px=192`, 'web-maskable-192.png', 192],
      [`v=android&o=${o}&px=512`, 'web-maskable-512.png', 512],
    ];
    for (const [qs, name, px, transparent = false] of files) await shot(qs, join(out, name), { w: px, h: px, transparent });
  } else {
    const r = +(process.argv[2] || 1), R = ROUNDS[r];
    for (const [o, name] of Object.entries(R.names)) {
      await shot(`v=board&o=${o}`, join(HERE, `${R.prefix}-app圖示-${o}-${name}.png`), { w: 1600, h: 900, dpr: 2, full: true });
    }
    await shot(`v=overview&r=${r}`, join(HERE, `${R.prefix}-app圖示-總覽對照.png`), { w: 1400, h: 900, dpr: 2, full: true });
  }
} finally {
  await browser.close();
  await srv.close();
}
