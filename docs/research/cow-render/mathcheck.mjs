// 牛怎麼畫的實測腳本 5：把產生器移植成 Dart 時，數學函式和數字轉字串能不能跟 JavaScript 一模一樣。
// 產生器（design/m2/src/cow/）用到 Math.sin、cos、atan2、hypot、round，座標輸出是 Math.round(v * 100) / 100 再轉字串。
// 用法：node docs/research/cow-render/mathcheck.mjs <輸出.json> [筆數，預設 200000]
// 輸入用固定 seed 的亂數（跟產生器同一個 rng），範圍照產生器常見的值：角度 ±4π、座標 ±600。
// 對照的 Dart 程式在 spike/tool/mathcheck.dart。
import { writeFileSync } from 'node:fs';
import { rng } from '../../../design/m2/src/cow/r1/cowgen.js';

const [out = 'mathcheck.json', nArg = '200000'] = process.argv.slice(2);
const N = Number(nArg);
const r = rng(20261002);
const buf = new DataView(new ArrayBuffer(8));
const hex = (v) => { buf.setFloat64(0, v); return buf.getBigUint64(0).toString(16).padStart(16, '0'); };
const f = (v) => Math.round(v * 100) / 100;
const rows = [];
for (let i = 0; i < N; i++) {
  const a = (r() - 0.5) * 8 * Math.PI, x = (r() - 0.5) * 1200, y = (r() - 0.5) * 1200;
  rows.push([hex(a), hex(x), hex(y), hex(Math.sin(a)), hex(Math.cos(a)), hex(Math.atan2(y, x)), hex(Math.hypot(x, y)), `${f(x)}`, `${f(x * Math.cos(a) + y * Math.sin(a))}`]);
}
writeFileSync(out, JSON.stringify(rows));
console.log('ok', N);
