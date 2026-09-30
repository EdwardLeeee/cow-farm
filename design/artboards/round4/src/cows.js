// 版本登記：a–e 是 R4 的五種外型（shapes/chub.js），共用 data.js 的基因。
// 0 現況（R1-A 的牛）與 R2-C 的對照直接用 round2/raw 的原始截圖，不在這裡重畫。
import { genesFor } from './data.js';
import { renderCow, VARIANTS, SIL_DEFS } from './shapes/chub.js';

export { SIL_DEFS, VARIANTS };
export const LABELS = Object.fromEntries(Object.entries(VARIANTS).map(([k, v]) => [k, `${k.toUpperCase()} ${v.name}`]));
export const SCENE_SCALE = Object.fromEntries(Object.entries(VARIANTS).map(([k, v]) => [k, v.scene]));

// entry：{ breed, sex?, age?, seed? } 或直接給 genes
export function drawCow(v, entry, opts = {}) {
  const g = entry.genes || genesFor(entry);
  return renderCow(v, g, opts);
}

// 模型外框換算成畫面座標（給排排站算縮放用）
export function extent(v, entry) {
  const r = drawCow(v, entry, { scale: 1 });
  const b = r.bbox;
  return { x0: b.x0 * r.scale, x1: b.x1 * r.scale, y0: Math.min(b.y0 * r.scale, r.headTop[1]), y1: 0 };
}
