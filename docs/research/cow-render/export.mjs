// 牛怎麼畫（docs/research/2026-10-cow-rendering.md）的實測腳本 1：用設計稿的產生器把牛匯出成獨立的 SVG，量數量與大小。
// 不改產生器：直接 import design/m2/src/cow/（D19 定案、cowcheck 103/103 的那一份）。
// 用法：node docs/research/cow-render/export.mjs <輸出資料夾> [變體數，預設 8] [朝向，預設 left,right]
// 輸出：<輸出資料夾>/svg/*.svg、meta.json（每張圖的框、頭頂、臉、影子）；統計印在畫面上，同時寫 stats.json。
// 朝右不是朝左的鏡像：產生器讓高光一律在畫面左上（q.js painter 的 lx），朝右時眼睛反光、口鼻亮點、身體光澤會換邊。
import { mkdir, writeFile } from 'node:fs/promises';
import { writeFileSync } from 'node:fs';
import { deflateRawSync } from 'node:zlib';
import { BREEDS, CODEX_ORDER } from '../../../design/m2/src/cow/breeds.js';
import { drawCow } from '../../../design/m2/src/cow/render.js';

const [out = 'cow-export', nVar = '8', facingArg = 'left,right'] = process.argv.slice(2);
const K = Number(nVar);
const FACINGS = facingArg.split(',');
const PAD = 4; // 跟 kit.js 的 cowSVG 一樣留邊，描邊不會被切掉
const f = (v) => Math.round(v * 100) / 100;

// 變體 0 是品種本身的 seed（圖鑑、設計稿用的那一頭）；其他變體用固定的 seed，重跑結果一樣。
const seedsFor = (breed) => [BREEDS[breed].seed, ...Array.from({ length: K - 1 }, (_, i) => 1000 + i * 37)];

function standalone(entry, id, facing) {
  const r = drawCow(entry, { x: 0, y: 0, scale: 1, facing, id });
  // bbox 是模型座標；朝右時畫面上的範圍左右對調（跟 kit.js cowSVG 一樣）
  const [bx0, bx1] = facing === 'right' ? [-r.bbox.x1, -r.bbox.x0] : [r.bbox.x0, r.bbox.x1];
  const x0 = bx0 * r.scale - PAD, x1 = bx1 * r.scale + PAD;
  const y0 = -r.height - PAD, y1 = PAD;
  const w = f(x1 - x0), h = f(y1 - y0);
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${f(x0)} ${f(y0)} ${w} ${h}" width="${w}" height="${h}">${r.svg}</svg>`;
  return { svg, meta: { w, h, x0: f(x0), y0: f(y0), face: r.face, headTop: r.headTop, shadow: r.shadow, height: r.height } };
}

await mkdir(`${out}/svg`, { recursive: true });
const meta = {};
const seen = new Map(); // svg 內容（去掉 id）→ 第一個檔名
const stats = { combos: 0, unique: 0, rawBytes: 0, deflateBytes: 0, maxBytes: 0, perBreedSeedVaries: {} };
for (const breed of CODEX_ORDER) {
  const seeds = seedsFor(breed);
  const variesBySeed = { side: new Set(), front: new Set() };
  for (const sex of ['cow', 'bull']) for (const age of ['calf', 'adult']) for (const pose of ['side', 'front']) for (const facing of FACINGS) {
    seeds.forEach((seed, vi) => {
      const name = `${breed}_${sex}_${age}_${pose}_${facing}_v${vi}`;
      const { svg, meta: m } = standalone({ breed, sex, age, pose, seed }, 'c', facing);
      stats.combos++;
      if (age === 'adult' && sex === 'cow' && facing === FACINGS[0]) variesBySeed[pose].add(svg);
      if (seen.has(svg)) { meta[name] = { sameAs: seen.get(svg) }; return; }
      seen.set(svg, name);
      meta[name] = m;
      stats.unique++;
      const bytes = Buffer.byteLength(svg);
      stats.rawBytes += bytes;
      stats.deflateBytes += deflateRawSync(svg, { level: 9 }).length;
      stats.maxBytes = Math.max(stats.maxBytes, bytes);
      writeFileSync(`${out}/svg/${name}.svg`, svg);
    });
  }
  // 成年母牛：K 個 seed 畫出幾種不同的樣子（1 代表 seed 不影響外型）
  stats.perBreedSeedVaries[breed] = { side: variesBySeed.side.size, front: variesBySeed.front.size };
}
await writeFile(`${out}/meta.json`, JSON.stringify(meta, null, 1));
await writeFile(`${out}/stats.json`, JSON.stringify({ variants: K, facings: FACINGS, ...stats }, null, 1));
console.log(JSON.stringify({ variants: K, facings: FACINGS.join('+'), combos: stats.combos, unique: stats.unique, rawKB: f(stats.rawBytes / 1024), deflateKB: f(stats.deflateBytes / 1024), maxKB: f(stats.maxBytes / 1024) }));
console.log('seed 影響外型的品種（成年母牛，K 個 seed 畫出幾種）：');
for (const [b, v] of Object.entries(stats.perBreedSeedVaries)) console.log(`  ${b.padEnd(15)} side ${v.side}  front ${v.front}`);
