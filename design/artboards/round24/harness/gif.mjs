// 第 24 輪 GIF：A、C 各一個（8 秒、15 fps、寬 390，DPR 1），影格放 raw/gif-<版>/（不進 git），用 ffmpeg 做成 GIF 存到這個資料夾。
// 用法（在 design/artboards/round24 底下跑，照記憶體規則用 scripts/heavy.sh）：node harness/gif.mjs [A,C]
// ffmpeg：PATH 上的，或 ~/.cache/cow-farm/ffmpeg/bin/ffmpeg（新電腦裝的靜態版）。
import { launchBrowser } from '../../../m2/harness/browser.mjs';
import { startServer } from '../../../m2/harness/server.mjs';
import { mkdir, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';

const HERE = join(dirname(fileURLToPath(import.meta.url)), '..');
const DESIGN = join(HERE, '..', '..');
const FPS = 15;
const which = (process.argv[2] || 'W,L').split(',');
const local = join(homedir(), '.cache/cow-farm/ffmpeg/bin/ffmpeg');
const FFMPEG = existsSync(local) ? local : 'ffmpeg';
const srv = await startServer(DESIGN);
const browser = await launchBrowser();
let bad = 0;
try {
  for (const v of which) {
    const ctx = await browser.newContext({ viewport: { width: 600, height: 1000 }, deviceScaleFactor: 1, colorScheme: 'light', locale: 'zh-TW', reducedMotion: 'reduce' });
    const page = await ctx.newPage();
    const errs = [];
    page.on('pageerror', (e) => errs.push(String(e)));
    page.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });
    await page.goto(`${srv.base}/artboards/round24/src/r24.html?gif=${v}`);
    await page.waitForFunction(() => window.__ready === true, null, { timeout: 60000 });
    const { file, total } = await page.evaluate(() => window.__gif);
    const dir = join(HERE, 'raw', `gif-${v}`);
    await rm(dir, { recursive: true, force: true });
    await mkdir(dir, { recursive: true });
    const n = Math.round(total * FPS);
    for (let i = 0; i < n; i++) {
      await page.evaluate((t) => window.__frame(t), i / FPS);
      await page.locator('.gif-box').screenshot({ path: join(dir, `f${String(i).padStart(3, '0')}.png`) });
    }
    await ctx.close();
    if (errs.length) { bad++; console.log(`!! ${v} 錯誤：${errs.join(' | ')}`); continue; }
    const out = join(HERE, `${file}.gif`);
    const vf = 'split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle';
    execFileSync(FFMPEG, ['-hide_banner', '-loglevel', 'error', '-y', '-framerate', String(FPS), '-i', join(dir, 'f%03d.png'), '-vf', vf, '-loop', '0', out]);
    console.log(`ok ${file}.gif ${n} 格`);
  }
} finally {
  await browser.close();
  await srv.close?.();
}
process.exit(bad ? 1 : 0);
