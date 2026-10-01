// 牛怎麼畫的實測腳本 3：用 Chromium（設計稿出圖用的同一個瀏覽器）把同一批 SVG 畫成 PNG，當比對的標準。
// 尺寸跟 spike/test/render_test.dart 一樣：ceil(SVG 寬高 × SCALE)，SVG 放大 SCALE 倍、從左上角畫起，背景透明。
// 用法（playwright-core 1.62.0，對應 ~/.cache/ms-playwright 的 chromium 1234；套件裝在 repo 外）：
//   PLAYWRIGHT_CORE=<…/node_modules/playwright-core/index.mjs> node docs/research/cow-render/chromium_render.mjs <svg 資料夾> <輸出> [SCALE=3]
import { readdir, readFile, mkdir } from 'node:fs/promises';

const { chromium } = await import(process.env.PLAYWRIGHT_CORE || 'playwright-core');
const [dir, out, scaleArg = '3'] = process.argv.slice(2);
const S = Number(scaleArg);
await mkdir(out, { recursive: true });
const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 1 });
const files = (await readdir(dir)).filter((f) => f.endsWith('.svg')).sort();
for (const file of files) {
  const svg = await readFile(`${dir}/${file}`, 'utf8');
  const w = Number(svg.match(/ width="([\d.]+)"/)[1]), h = Number(svg.match(/ height="([\d.]+)"/)[1]);
  const W = Math.ceil(w * S), H = Math.ceil(h * S);
  const big = svg.replace(/ width="[\d.]+" height="[\d.]+"/, ` width="${w * S}" height="${h * S}"`);
  await page.setViewportSize({ width: W, height: H });
  await page.setContent(`<!doctype html><style>html,body{margin:0;background:transparent}svg{display:block}</style>${big}`);
  await page.screenshot({ path: `${out}/${file.replace('.svg', '.png')}`, omitBackground: true, clip: { x: 0, y: 0, width: W, height: H } });
}
await browser.close();
console.log('ok', files.length);
