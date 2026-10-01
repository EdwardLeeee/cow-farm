// 回歸檢查：M2 複製的產生器畫第 11 輪的 12 頭（側面、正面、左右、剪影）和牧場站位，SVG 要跟第 11 輪一個字都不差（D19 定案的外型不能跑掉）。
// 用法：node harness/cowcheck.mjs
import { LINEUP, HERD } from '../../artboards/round11/src/data.js';
import { drawCow as drawR11 } from '../../artboards/round11/src/cows.js';
import { drawCow as drawM2 } from '../src/cow/render.js';

const cases = [];
for (const e of LINEUP) for (const pose of ['side', 'front']) for (const facing of ['left', 'right']) for (const sil of [false, true]) {
  cases.push({ label: `${e.label} ${pose} ${facing}${sil ? ' 剪影' : ''}`, entry: { ...e, pose }, opts: { x: 100, y: 200, scale: 1.2, facing, id: 'k', sil } });
}
for (const h of HERD) cases.push({ label: `站位 ${h.id}`, entry: h, opts: { x: h.x, y: h.y, scale: 0.9, facing: h.facing, id: 'h' } });

let bad = 0;
for (const c of cases) {
  const a = drawR11('r11', c.entry, c.opts), b = drawM2(c.entry, c.opts);
  const same = a.svg === b.svg && ['face', 'headTop', 'shadow', 'bbox', 'height', 'scale'].every((k) => JSON.stringify(a[k]) === JSON.stringify(b[k]));
  if (!same) { bad++; console.log('不同：', c.label); }
}
console.log(`${cases.length - bad}/${cases.length} 相同`);
process.exit(bad ? 1 : 0);
