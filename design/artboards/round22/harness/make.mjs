// 第 22 輪草稿：出說明圖。原始截圖放 raw/（不進 git），再用 harness/compose.py 存到這個資料夾（全彩）。
// 單張 DPR 2；總覽 R22-99 用 DPR 1.5（ceo 2026-10-03：控制 repo 大小）。
// 用法（在 design/artboards/round22 底下跑；用 design/m2 的 Playwright 和靜態伺服器）：
//   node harness/make.mjs          全部
//   node harness/make.mjs R22-01   只出 id 開頭是 R22-01 的
// 照記憶體規則：free -m 可用少於 1000 MB 就先等，用 systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 包起來。
import { launchBrowser } from '../../../m2/harness/browser.mjs'; // 字型要齊、灰階反鋸齒（跟 M2 的出圖一樣）
import { startServer } from '../../../m2/harness/server.mjs';
import { mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = join(dirname(fileURLToPath(import.meta.url)), '..');
const DESIGN = join(HERE, '..', '..');
const RAW = join(HERE, 'raw');
const only = process.argv[2] || '';
await mkdir(RAW, { recursive: true });
const srv = await startServer(DESIGN);
const browser = await launchBrowser();
const url = (qs) => `${srv.base}/artboards/round22/src/r22.html?${qs}`;

async function open(qs, dpr = 1) {
  // 視窗先開大一點（寬 1600、高 1000）：手機寬 390、430 都不會碰到 m2 的窄手機、矮手機規則
  const ctx = await browser.newContext({ viewport: { width: 1600, height: 1000 }, deviceScaleFactor: dpr, colorScheme: 'light', locale: 'zh-TW', reducedMotion: 'reduce' });
  const page = await ctx.newPage();
  const errs = [];
  page.on('pageerror', (e) => errs.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });
  page.on('requestfailed', (r) => errs.push(`載不到 ${r.url()}`));
  await page.goto(url(qs));
  await page.waitForFunction(() => window.__ready === true, null, { timeout: 60000 });
  return { ctx, page, errs };
}

let bad = 0;
try {
  const l = await open('list=1');
  const boards = (await l.page.evaluate(() => window.__boards)).filter((b) => b.id.startsWith(only));
  await l.ctx.close();
  for (const b of boards) {
    const o = await open(`b=${b.id}&w=${b.w}`, b.id === 'R22-99' ? 1.5 : 2);
    const { file, size, over } = await o.page.evaluate(() => {
      // 量測：手機裡一行放不下、被切掉的字（white-space: nowrap 又超出自己的框）
      const over = [];
      document.querySelectorAll('.phone *').forEach((e) => {
        const cs = getComputedStyle(e);
        if (cs.whiteSpace === 'nowrap' && e.scrollWidth > e.clientWidth + 1 && e.clientWidth > 0 && cs.overflow !== 'visible') over.push(`${e.className}：${e.textContent.trim().slice(0, 20)}`);
      });
      return { file: window.__file, size: window.__size, over };
    });
    if (size.w > 1600 || size.h > 1000) await o.page.setViewportSize({ width: Math.max(1600, size.w), height: Math.max(1000, size.h) });
    await o.page.locator('.board').screenshot({ path: join(RAW, `${file}.png`) });
    await o.ctx.close();
    const errs = [...o.errs, ...over.map((x) => `放不下：${x}`)];
    if (errs.length) bad++;
    console.log(`${errs.length ? '!!' : 'ok'} ${file}.png ${size.w}×${size.h}${errs.length ? '\n   ' + errs.join('\n   ') : ''}`);
  }
} finally {
  await browser.close();
  await srv.close();
}
process.exitCode = bad ? 1 : 0;
