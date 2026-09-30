// 版本登記：R10（shapes/r10.js）：各選項的組合見 VARIANTS；共用 data.js 的基因。
// 0 對照（R1-A 的牛）直接用 round2/raw 的原始截圖，不在這裡重畫。
import { genesFor } from './data.js';
import { renderCow, VARIANTS, SIL_DEFS } from './shapes/r10.js';

export { SIL_DEFS, VARIANTS };
export const LABELS = Object.fromEntries(Object.entries(VARIANTS).map(([k, v]) => [k, v.name]));
export const SCENE_SCALE = Object.fromEntries(Object.entries(VARIANTS).map(([k, v]) => [k, v.scene]));

// entry：{ breed, sex?, age?, seed? } 或直接給 genes
export function drawCow(v, entry, opts = {}) {
  const g = entry.genes || genesFor(entry);
  return renderCow(v, g, { pose: entry.pose || 'front', ...opts });
}

// 模型外框換算成畫面座標（給排排站算縮放用）
export function extent(v, entry) {
  const r = drawCow(v, entry, { scale: 1 });
  const b = r.bbox;
  return { x0: b.x0 * r.scale, x1: b.x1 * r.scale, y0: Math.min(b.y0 * r.scale, r.headTop[1]), y1: 0 };
}
