// 開發用：把任一頁拍成圖。node harness/shot.mjs <頁面相對路徑> <輸出.png> [寬] [高] [dpr] [fullPage 0/1]
import { chromium } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { startServer } from './server.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const [page = 'src/gallery.html?style=a', out = 'raw/_dev.png', w = '390', h = '844', dpr = '2', full = '1'] = process.argv.slice(2);
const srv = await startServer(root);
const browser = await chromium.launch();
try {
  const ctx = await browser.newContext({
    viewport: { width: +w, height: +h }, deviceScaleFactor: +dpr, isMobile: true, hasTouch: true,
    locale: 'zh-TW', colorScheme: 'light', reducedMotion: 'reduce',
  });
  const p = await ctx.newPage();
  const errors = [];
  p.on('pageerror', (e) => errors.push(String(e)));
  p.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await p.goto(`${srv.base}/${page}`);
  await p.waitForFunction(() => window.__ready === true, null, { timeout: 15000 }).catch(() => errors.push('timeout waiting __ready'));
  await p.evaluate(() => document.fonts.ready);
  await p.screenshot({ path: out, fullPage: full === '1' });
  if (errors.length) console.log('ERRORS:\n' + errors.join('\n'));
  else console.log('ok', out);
} finally {
  await browser.close();
  await srv.close();
}
