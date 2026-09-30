// 版本登記：0 現況（R1-A 原封不動的產生器與基因）、a／b／c（R2 新產生器，同一組 R2 基因）。
import { genesFor } from './data.js';
import { renderCow, VERSIONS, SIL_DEFS } from './shapes/cow.js';
import { buildCow } from './r1/cowgen.js';
import { cowA } from './r1/cowgen-a.js';
import { genesFor as genesForR1 } from './r1/data.js';

export { SIL_DEFS };
export const LABELS = { 0: '0 現況', a: 'A 大頭寶寶', b: 'B 繪本自然', c: 'C 側面輪廓' };
export const SCENE_SCALE = { 0: 1, a: VERSIONS.a.scene, b: VERSIONS.b.scene, c: VERSIONS.c.scene };

// entry：{ breed, age?, seed? } 或直接給 genes（圖庫用）
export function drawCow(v, entry, opts = {}) {
  const { x = 0, y = 0, scale = 1, facing = 'left', id = 'cow', sil = false } = opts;
  if (String(v) === '0') {
    const M = buildCow(entry.genes || genesForR1(entry));
    const s = scale * M.unit;
    let svg = cowA(M, { x, y, scale, facing, id });
    if (sil) svg = `<g filter="url(#sil)">${svg}</g>`;
    const mir = facing === 'right' ? -1 : 1;
    return {
      svg,
      headTop: [x + mir * M.headTop[0] * s, y + M.headTop[1] * s],
      shadow: { cx: x + mir * M.shadow.cx * s, rx: M.shadow.rx * s, ry: M.shadow.ry * s },
      bbox: M.bbox, scale: s,
    };
  }
  const g = entry.genes || genesFor(entry);
  return renderCow(v, g, { x, y, scale, facing, id, sil });
}

// 螢幕座標的外框（給排排站算縮放用）
export function extent(v, entry) {
  const r = drawCow(v, entry, { scale: 1 });
  const b = r.bbox;
  if (String(v) === '0') { const M = buildCow(genesForR1(entry)); return { x0: b.x0 * M.unit, x1: b.x1 * M.unit, y0: b.y0 * M.unit, y1: 0 }; }
  return { x0: b.x0 * r.scale, x1: b.x1 * r.scale, y0: Math.min(b.y0 * r.scale, r.headTop[1]), y1: 0 };
}
