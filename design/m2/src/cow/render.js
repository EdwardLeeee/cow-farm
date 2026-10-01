// M2 畫牛的入口：用第 11 輪定案的產生器（複製在 r11.js，新品種需要的畫法另外加），基因來自 breeds.js。
import { genesFor } from './breeds.js';
import { renderCow, SIL_DEFS } from './r11.js';

export { SIL_DEFS };
export const V = 'r11';

// entry：{ breed, sex?, age?, seed?, pose? } 或 { genes }
export function drawCow(entry, opts = {}) {
  const g = entry.genes || genesFor(entry);
  return renderCow(V, g, { pose: entry.pose || 'front', ...opts });
}
