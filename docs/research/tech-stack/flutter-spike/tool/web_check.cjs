// 用 headless Chromium 打開網頁版，確認畫得出來、跑得完，並截圖。
// 注意：這裡量到的是軟體繪圖（SwiftShader）的數字，不是目標量測；目標是 iPhone 實機（TestFlight）。
//
// 用法（Node 18+，需要 Playwright；本機借用 connect4 已安裝的套件，只讀不改）：
//   flutter build web --release --no-wasm-dry-run
//   (cd build/web && python3 -m http.server 8765 --bind <區網 IP>)   # 另一個終端機，結束時用 PID 關掉
//   PLAYWRIGHT_MODULE=~/Desktop/connect4-web2-worktrees/mobile/frontend/node_modules/playwright \
//     node tool/web_check.cjs http://<區網 IP>:8765/ ../flutter-spike-shots
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const fs = require('fs');
const url = process.argv[2];
const shots = process.argv[3];
const t0 = Date.now();
const sec = () => ((Date.now() - t0) / 1000).toFixed(1);
(async () => {
  const browser = await chromium.launch({
    headless: true,
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
  });
  console.log(`[${sec()}] browser ${browser.version()}`);
  const context = await browser.newContext({
    viewport: { width: 430, height: 932 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true, locale: 'zh-TW',
  });
  const page = await context.newPage();
  const lines = [];
  let resolveResult;
  const resultSeen = new Promise((r) => (resolveResult = r));
  page.on('console', (m) => {
    const t = m.text();
    lines.push(`[${sec()}] ${m.type()}: ${t}`);
    if (t.startsWith('COWFARM_SPIKE')) console.log(`[${sec()}] ${t}`);
    if (t.startsWith('COWFARM_SPIKE_RESULT')) resolveResult(t);
  });
  page.on('pageerror', (e) => { lines.push(`[${sec()}] pageerror: ${e.message}`); console.log(`[${sec()}] PAGEERROR ${e.message}`); });
  page.on('requestfailed', (r) => lines.push(`[${sec()}] requestfailed: ${r.url()} ${r.failure() && r.failure().errorText}`));
  const resp = await page.goto(url, { waitUntil: 'load' });
  console.log(`[${sec()}] loaded ${resp.status()}`);
  const webgl = await page.evaluate(() => {
    const c = document.createElement('canvas');
    const gl = c.getContext('webgl2') || c.getContext('webgl');
    if (!gl) return 'no webgl';
    const d = gl.getExtension('WEBGL_debug_renderer_info');
    return d ? gl.getParameter(d.UNMASKED_RENDERER_WEBGL) : 'webgl (renderer hidden)';
  });
  console.log(`[${sec()}] WebGL renderer: ${webgl}`);
  await page.waitForTimeout(14000);
  await page.screenshot({ path: `${shots}/web-running-n30.png` });
  console.log(`[${sec()}] shot running-n30`);
  await page.waitForTimeout(55000);
  await page.screenshot({ path: `${shots}/web-running-n200.png` });
  console.log(`[${sec()}] shot running-n200`);
  const result = await Promise.race([resultSeen, new Promise((r) => setTimeout(() => r(null), 120000))]);
  if (!result) console.log(`[${sec()}] NO RESULT within timeout`);
  await page.waitForTimeout(2500);
  await page.screenshot({ path: `${shots}/web-results.png` });
  console.log(`[${sec()}] shot results`);
  fs.writeFileSync(`${shots}/web-console.log`, lines.join('\n') + '\n');
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
