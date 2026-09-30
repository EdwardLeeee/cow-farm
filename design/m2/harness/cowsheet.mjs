// 不開瀏覽器的品種預覽：24 種（或指定品種）各畫側面和正面 → SVG，再交給 svg2png.py（librsvg）轉 PNG。
// 用法：node harness/cowsheet.mjs <輸出.svg> [new|all|品種鍵,品種鍵…] [side|front|both]
import { writeFile } from 'node:fs/promises';
import { BREEDS, CODEX_ORDER, NEW_IN_M2, USE_NAME, TIER_NAME, tierOf } from '../src/cow/breeds.js';
import { drawCow } from '../src/cow/render.js';

const [out = 'cowsheet.svg', which = 'all', poses = 'both'] = process.argv.slice(2);
const keys = which === 'all' ? CODEX_ORDER : which === 'new' ? NEW_IN_M2 : which.split(',');
const P = poses === 'both' ? ['side', 'front'] : [poses];
const cellW = 190, cellH = 200, cols = 6;
const rows = Math.ceil((keys.length * P.length) / cols);
const W = cellW * cols + 40, H = cellH * rows + 60;
let o = `<rect width="${W}" height="${H}" fill="#FFF9EF"/>`;
const items = keys.flatMap((k) => P.map((pose) => ({ breed: k, pose })));
const ext = items.map((e) => { const r = drawCow(e, { scale: 1 }); return { x0: r.bbox.x0 * r.scale, x1: r.bbox.x1 * r.scale, h: r.height }; });
const k = Math.min(130 / Math.max(...ext.map((e) => e.h)), 1.9);
items.forEach((e, i) => {
  const col = i % cols, row = Math.floor(i / cols), b = ext[i];
  const x = 20 + col * cellW + cellW / 2 - ((b.x0 + b.x1) / 2) * k, y = 40 + row * cellH + cellH - 44;
  const cow = drawCow(e, { x, y, scale: k, id: `c${i}` });
  const br = BREEDS[e.breed];
  o += `<ellipse cx="${cow.shadow.cx}" cy="${y}" rx="${cow.shadow.rx}" ry="${cow.shadow.ry}" fill="#BFE6A8"/>${cow.svg}`;
  o += `<text x="${20 + col * cellW + cellW / 2}" y="${y + 22}" text-anchor="middle" font-family="Noto Sans CJK TC" font-size="14" font-weight="700" fill="#4B3326">${br.name}</text>`;
  o += `<text x="${20 + col * cellW + cellW / 2}" y="${y + 38}" text-anchor="middle" font-family="Noto Sans CJK TC" font-size="11" fill="#8A6F60">${USE_NAME[br.use]}・${TIER_NAME[tierOf(br)]}・${e.pose === 'side' ? '側面' : '正面'}</text>`;
});
await writeFile(out, `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${o}</svg>`);
console.log('ok', out, items.length);
