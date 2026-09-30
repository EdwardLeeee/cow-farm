// 快速預覽牧場場景（不開瀏覽器）：node harness/preview-scene.mjs [a|b|c|d|e ...] → raw/scene-<v>.svg
import { writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const vs = process.argv.slice(2).length ? process.argv.slice(2) : ['sitSame', 'standSame', 'sitRef'];
for (const v of vs) {
  globalThis.location = { search: `?v=${v}` };
  const mod = await import(`../src/style-a.js?v=${v}`);
  const { HERD } = await import('../src/data.js');
  const el = {};
  mod.scene(el, HERD);
  const svg = el.innerHTML.replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" ');
  await writeFile(join(ROOT, 'raw', `scene-${v}.svg`), svg);
}
console.log('ok', vs.join(','));
