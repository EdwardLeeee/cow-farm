// 本機檢查用：九頭牛放大成一張圖（側面或正面），不進設計稿。用法：node harness/bigsheet.mjs <v> <side|front> [k]
import { writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { SIDE_LINEUP, FRONT_LINEUP } from '../src/data.js';
import { drawCow, extent } from '../src/cows.js';
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const [v = 'r11', view = 'side', kk = '3'] = process.argv.slice(2);
const k = +kk;
const LINE = view === 'side' ? SIDE_LINEUP : FRONT_LINEUP;
const ext = LINE.map((e) => extent(v, e));
const maxH = Math.max(...ext.map((e) => e.y1 - e.y0)), maxW = Math.max(...ext.map((e) => e.x1 - e.x0));
const cw = maxW * k + 30, ch = maxH * k + 50;
let o = '';
LINE.forEach((e, i) => {
  const col = i % 3, row = Math.floor(i / 3), b = ext[i];
  const x = col * cw + (cw - (b.x1 - b.x0) * k) / 2 - b.x0 * k, y = row * ch + ch - 30;
  const c = drawCow(v, e, { x, y, scale: k, id: `b${i}` });
  o += `<ellipse cx="${c.shadow.cx}" cy="${y}" rx="${c.shadow.rx}" ry="${c.shadow.ry}" fill="#CDEBC0"/>${c.svg}<text x="${col * cw + cw / 2}" y="${y + 22}" text-anchor="middle" font-family="Noto Sans CJK TC" font-size="16" font-weight="700" fill="#4B3326">${e.label}</text>`;
});
const W = cw * 3, H = ch * Math.ceil(LINE.length / 3);
await writeFile(join(ROOT, 'raw', `big-${view}.svg`), `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}"><rect width="100%" height="100%" fill="#FFFDF8"/>${o}</svg>`);
console.log('ok', view, Math.round(W), Math.round(H));
