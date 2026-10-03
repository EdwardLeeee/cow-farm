// M2 動畫出圖：每個動畫依 t 截圖。GIF 用的影格（DPR 1、每秒 15 格）、分鏡的關鍵影格（DPR 2）、減少動態的前後兩張（DPR 2）。
// 用法：node harness/anim.mjs [A-01,A-02…] [語言]；之後跑 python3 harness/compose_anim.py 做 GIF、分鏡圖、減少動態圖。
// 語言是 en 或 th 時只拍分鏡的關鍵影格（存到 raw/<語言>/anim/），並在最後一格跑 capture.mjs 的量測（泰文也檢查換行：斷在詞中間、拆開用詞表的詞；不做 GIF，不送核准，D25）。
// 記憶體：跑之前先看 free -m（available 少於 1000 MB 就先等，使用者 2026-10-03），用 systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 包起來。
import { chromium } from '@playwright/test';
import { mkdir, writeFile, rm } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { startServer } from './server.mjs';
import { measure, glossaryTerms } from './capture.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const LANG = process.argv[3] || 'zh-Hant';
const OUT = LANG === 'zh-Hant' ? join(ROOT, 'raw', 'anim') : join(ROOT, 'raw', LANG, 'anim');
const LQ = LANG === 'zh-Hant' ? '' : `&lang=${LANG}`;
const LOCALE = { 'zh-Hant': 'zh-TW', en: 'en-US', th: 'th-TH' }[LANG] || 'zh-TW';
const TERMS = LANG === 'th' ? glossaryTerms() : []; // 泰文：跟 capture.mjs 一樣檢查用詞表的詞有沒有被拆到兩行
const FPS = 15;
// 減少動態：前後兩張（t0／tEnd 是動畫本身的第一格、最後一格；其他是狀態的頁面 ID）
const REDUCED = {
  'A-01': ['t0', 'tEnd'], 'A-02': ['t0', 'tEnd'], 'A-03': ['S07-02', 'S20-01'], 'A-04': ['S08-06', 'tEnd'], 'A-05': ['S03-01', 'tEnd'],
  'A-06': ['t0', 'tEnd'], 'A-07': ['t0', 'tEnd'], 'A-08': ['t0', 'tEnd'], 'A-09': ['S19-01', 'S19-05'], 'A-10': ['S07-02', 'S20-01'],
  'A-11': ['S03-01', 'S03-01'], 'A-12': ['S03-01', 'S03-13'], 'A-13': ['S03-01', 'tEnd'],
  'A-14': ['S03-27', 'tEnd'], 'A-15': ['S03-27', 'tEnd'],
};

async function run(filter) {
  await mkdir(OUT, { recursive: true });
  const srv = await startServer(ROOT);
  const browser = await chromium.launch();
  try {
    const lp = await (await browser.newContext()).newPage();
    await lp.goto(`${srv.base}/src/index.html?list=1`);
    await lp.waitForFunction(() => window.__ready === true, null, { timeout: 20000 });
    const anims = (await lp.evaluate(() => window.__anims)).filter((a) => !filter || filter.split(',').includes(a.id));
    await lp.context().close();
    for (const a of anims) {
      const dir = join(OUT, a.id);
      await rm(dir, { recursive: true, force: true });
      await mkdir(dir, { recursive: true });
      // GIF 預設 DPR 1；動畫自己可以指定 gifDpr（例如 A-03 用 2，畫面比較細）
      for (const [dpr, what] of (LANG === 'zh-Hant' ? [[a.gifDpr || 1, 'gif'], [2, 'keys']] : [[2, 'keys']])) {
        const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: dpr, isMobile: true, hasTouch: true, locale: LOCALE, colorScheme: 'light' });
        const page = await ctx.newPage();
        const errors = [];
        page.on('pageerror', (e) => errors.push(String(e)));
        page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
        await page.goto(`${srv.base}/src/index.html?anim=${a.id}&w=390${LQ}`, { waitUntil: 'load' });
        await page.waitForFunction(() => window.__ready === true, null, { timeout: 20000 });
        if (what === 'gif') {
          // 循環的動畫：最後一格就是第一格，不重複拍
          const n = Math.round(a.dur * FPS) - (a.loop ? 1 : 0);
          for (let i = 0; i <= n; i++) {
            await page.evaluate((t) => window.__frame(t), i / FPS);
            await page.screenshot({ path: join(dir, `f${String(i).padStart(3, '0')}.png`) });
          }
        } else {
          for (let i = 0; i < a.keys.length; i++) {
            await page.evaluate((t) => window.__frame(t), a.keys[i][0]);
            await page.screenshot({ path: join(dir, `k${i}.png`) });
          }
          // 英文、泰文：量最後一個關鍵影格（動畫停住的樣子），不拍減少動態
          if (LANG !== 'zh-Hant') {
            const m = await page.evaluate(measure, TERMS).catch((e) => ({ error: String(e) }));
            await writeFile(join(dir, 'meta.json'), JSON.stringify({ id: a.id, name: a.name, uiLang: LANG, keys: a.keys, errors, ...m }, null, 1));
            const n = ['clipped', 'outside', 'wrapped', 'overlaps'].map((k) => (m[k] || []).length);
            const thBad = (m.thaiBreaks || []).filter((x) => x.midWord).length, thSplit = (m.thaiBreaks || []).filter((x) => x.splitTerms.length).length;
            console.log(`${n.some((x) => x) || errors.length || thBad ? '!!' : 'ok'} ${a.id} ${LANG}  缺字串${(m.i18nMissing || []).length}${thBad ? `  泰文斷在詞中間${thBad}` : ''}${thSplit ? `  拆開用詞表的詞${thSplit}（要人看）` : ''}  截${n[0]} 出框${n[1]} 換行${n[2]} 疊${n[3]}${errors.length ? ' 錯誤:' + errors.join('|') : ''}`);
            await ctx.close();
            continue;
          }
          const [r0, r1] = REDUCED[a.id];
          for (const [j, r] of [[0, r0], [1, r1]]) {
            if (r === 't0' || r === 'tEnd') {
              await page.evaluate((t) => window.__frame(t), r === 't0' ? 0 : a.dur);
              await page.screenshot({ path: join(dir, `r${j}.png`) });
            } else {
              const p2 = await ctx.newPage();
              await p2.goto(`${srv.base}/src/index.html?id=${r}&w=390`, { waitUntil: 'load' });
              await p2.waitForFunction(() => window.__ready === true, null, { timeout: 20000 });
              await p2.screenshot({ path: join(dir, `r${j}.png`) });
              await p2.close();
            }
          }
          await writeFile(join(dir, 'meta.json'), JSON.stringify({ ...a, fps: FPS, reducedFrom: r0, reducedTo: r1, errors }, null, 1));
        }
        console.log(`${errors.length ? '!!' : 'ok'} ${a.id} ${what}${errors.length ? ' ' + errors.join('|') : ''}`);
        await ctx.close();
      }
    }
  } finally {
    await browser.close();
    await srv.close();
  }
}

const isMain = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isMain) {
  const watchdog = setTimeout(() => { console.error('anim timeout (15 分)'); process.exit(2); }, 15 * 60 * 1000);
  run(process.argv[2] || '').then(() => clearTimeout(watchdog)).catch((e) => { console.error(e); process.exit(1); });
}
