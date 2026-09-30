// 快速預覽（不開瀏覽器）：node 產生側面九頭＋正面九頭的 SVG，交給 harness/svg2png.py（librsvg）轉 PNG。
// 用法：node harness/preview.mjs [sitSame|standSame|sitRef ...]  → raw/preview-<v>.svg
import { writeFile, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { SIDE_LINEUP, FRONT_LINEUP } from '../src/data.js';
import { drawCow, extent, LABELS } from '../src/cows.js';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'raw');
await mkdir(OUT, { recursive: true });
const vs = process.argv.slice(2).length ? process.argv.slice(2) : ['r11'];
for (const v of vs) {
  const cellW = 200, cellH = 190, W = cellW * 6 + 60, Hh = cellH * 3 + 90;
  let o = `<rect width="${W}" height="${Hh}" fill="#FFF9EF"/><text x="16" y="28" font-family="Noto Sans CJK TC" font-size="18" font-weight="700" fill="#4B3326">${LABELS[v]}　左：側面（9966）　右：正面（9967）</text>`;
  const all = [...SIDE_LINEUP, ...FRONT_LINEUP];
  const ext = all.map((e) => extent(v, e));
  const maxH = Math.max(...ext.map((e) => e.y1 - e.y0));
  const k = Math.min(140 / maxH, 1.9);
  all.forEach((e, i) => {
    const blk = i < 9 ? 0 : 1, j = i % 9, col = j % 3 + blk * 3, row = Math.floor(j / 3);
    const b = ext[i], w = (b.x1 - b.x0) * k;
    const x0 = 20 + col * cellW + blk * 20 + (cellW - w) / 2 - b.x0 * k, y = 40 + row * cellH + cellH - 30;
    const cow = drawCow(v, e, { x: x0, y, scale: k, id: `p${v}${i}` });
    o += `<ellipse cx="${cow.shadow.cx}" cy="${y}" rx="${cow.shadow.rx}" ry="${cow.shadow.ry}" fill="#BFE6A8"/>${cow.svg}`;
    o += `<text x="${20 + col * cellW + blk * 20 + cellW / 2}" y="${y + 20}" text-anchor="middle" font-family="Noto Sans CJK TC" font-size="13" font-weight="700" fill="#4B3326">${e.label}</text>`;
  });
  const hh = (e) => drawCow(v, e, { scale: 1 }).height;
  const rs = hh(SIDE_LINEUP[2]) / hh(SIDE_LINEUP[0]), rf = hh(FRONT_LINEUP[2]) / hh(FRONT_LINEUP[0]);
  o += `<text x="16" y="${Hh - 16}" font-family="Noto Sans CJK TC" font-size="13" fill="#4B3326">小牛／成年荷斯坦身高：側面 ${rs.toFixed(2)}、正面 ${rf.toFixed(2)}</text>`;
  await writeFile(join(OUT, `preview-${v}.svg`), `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${Hh}" viewBox="0 0 ${W} ${Hh}">${o}</svg>`);
  console.log(v, 'calf side', rs.toFixed(3), 'front', rf.toFixed(3));
}
