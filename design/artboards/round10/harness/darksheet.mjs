// 本機檢查用：安格斯與和牛（側面、正面）放大，比較各選項。用法：node harness/darksheet.mjs <v1> <v2> ... → raw/dark-<v>.svg
import { writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { drawCow, extent, VARIANTS } from '../src/cows.js';
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const vs = process.argv.slice(2);
for (const v of vs) {
  const list = [{ breed: 'angus', pose: 'side', label: '安格斯・側面' }, { breed: 'wagyu', pose: 'side', label: '和牛・側面' }, { breed: 'angus', pose: 'front', label: '安格斯・正面' }, { breed: 'wagyu', pose: 'front', label: '和牛・正面' }];
  const k = 3.2, cw = 420, ch = 380;
  let o = `<rect width="${cw * 4}" height="${ch + 40}" fill="#EEF6E6"/><text x="12" y="26" font-family="Noto Sans CJK TC" font-size="20" font-weight="700" fill="#4B3326">${VARIANTS[v].name}</text>`;
  list.forEach((e, i) => {
    const b = extent(v, e);
    const x = i * cw + (cw - (b.x1 - b.x0) * k) / 2 - b.x0 * k, y = ch;
    const c = drawCow(v, e, { x, y, scale: k, id: `d${i}` });
    o += `<ellipse cx="${c.shadow.cx}" cy="${y}" rx="${c.shadow.rx}" ry="${c.shadow.ry}" fill="#BFE3A8"/>${c.svg}<text x="${i * cw + cw / 2}" y="${y + 28}" text-anchor="middle" font-family="Noto Sans CJK TC" font-size="16" font-weight="700" fill="#4B3326">${e.label}</text>`;
  });
  await writeFile(join(ROOT, 'raw', `dark-${v}.svg`), `<svg xmlns="http://www.w3.org/2000/svg" width="${cw * 4}" height="${ch + 40}">${o}</svg>`);
}
console.log('ok', vs.join(','));
