// 快速預覽（不開瀏覽器）：用 node 產生排排站 SVG，交給 harness/svg2png.py（librsvg）轉 PNG。
// 用法：node harness/preview.mjs [a|b|c|d|e ...]  → raw/preview-<v>.svg
import { writeFile, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { LINEUP as FRONT, SIDE_LINEUP } from '../src/data.js';
const LINEUP = [...FRONT, ...SIDE_LINEUP];
import { drawCow, extent, LABELS, SIL_DEFS } from '../src/cows.js';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'raw');
await mkdir(OUT, { recursive: true });
const vs = process.argv.slice(2).length ? process.argv.slice(2) : ['a', 'b', 'c'];
for (const v of vs) {
  const ext = LINEUP.map((e) => extent(v, e));
  const maxH = Math.max(...ext.map((e) => e.y1 - e.y0));
  const W = 860, cellW = 210, cellH = 200, k = Math.min(150 / maxH, 1.9);
  let o = `<rect width="${W}" height="${cellH * 4 + 190}" fill="#FFF9EF"/><text x="16" y="28" font-family="Noto Sans CJK TC" font-size="18" font-weight="700" fill="#4B3326">${LABELS[v]}</text>`;
  const hs = [];
  LINEUP.forEach((e, i) => {
    const col = i < 9 ? i % 3 : i - 9, row = i < 9 ? Math.floor(i / 3) : 3;
    const b = ext[i], w = (b.x1 - b.x0) * k;
    const x = 15 + col * cellW + (cellW - w) / 2 - b.x0 * k, y = 40 + row * cellH + cellH - 30;
    const cow = drawCow(v, e, { x, y, scale: k, id: `p${v}${i}` });
    hs.push(cow.height * k / cow.scale * cow.scale);
    o += `<ellipse cx="${cow.shadow.cx}" cy="${y}" rx="${cow.shadow.rx}" ry="${cow.shadow.ry}" fill="#BFE6A8"/>${cow.svg}`;
    o += `<text x="${15 + col * cellW + cellW / 2}" y="${y + 22}" text-anchor="middle" font-family="Noto Sans CJK TC" font-size="14" font-weight="700" fill="#4B3326">${e.label}</text>`;
  });
  // 剪影列
  const ks = k * 0.42;
  let sx = 16;
  const sy = 40 + cellH * 4 + 110;
  FRONT.forEach((e, i) => {
    const b = ext[i];
    const cow = drawCow(v, e, { x: sx - b.x0 * ks, y: sy, scale: ks, id: `s${v}${i}`, sil: true });
    o += cow.svg;
    sx += (b.x1 - b.x0) * ks + 8;
  });
  // 量測：小牛身高 ÷ 成年荷斯坦身高
  const hh = (e) => { const r = drawCow(v, e, { scale: 1 }); return r.height; };
  const ratio = hh(LINEUP[2]) / hh(LINEUP[0]);
  o += `<text x="16" y="${sy + 34}" font-family="Noto Sans CJK TC" font-size="13" fill="#4B3326">小牛／成年荷斯坦身高 ${ratio.toFixed(2)}</text>`;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${cellH * 4 + 190}" viewBox="0 0 ${W} ${cellH * 4 + 190}"><defs>${SIL_DEFS}</defs>${o}</svg>`;
  await writeFile(join(OUT, `preview-${v}.svg`), svg);
  console.log(v, 'calf ratio', ratio.toFixed(3));
}
