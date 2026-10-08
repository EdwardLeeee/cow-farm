// M2 畫牛的入口：用第 11 輪定案的產生器（複製在 r11.js，新品種需要的畫法另外加），基因來自 breeds.js。
import { genesFor } from './breeds.js';
import { renderCow, SIL_DEFS } from './r11.js';
import { sickFace } from './sick.js';

export { SIL_DEFS };
export const V = 'r11';

// entry：{ breed, sex?, age?, seed?, pose? } 或 { genes }
// entry.sick：病牛（v0.3 第 5 節）臉色發青，見 sick.js
export function drawCow(entry, opts = {}) {
  let g = entry.genes || genesFor(entry);
  if (entry.sick) g = { ...g, faceColor: sickFace(g.coat) };
  return renderCow(V, g, { pose: entry.pose || 'front', ...opts });
}
