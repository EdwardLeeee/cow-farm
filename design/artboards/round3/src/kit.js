// 把一個畫風（style）包成 ui.js 需要的 kit：場景、牛、圖示、數字、頭像、小走勢線、牛奶桶。
// 畫風只要提供：cowColor／sceneColor／iconColor（角色 → 顏色）、fill／line／dot／regionClose（怎麼畫）、
// globalDefs（濾鏡、圖樣）、以及可選的 wrapCow／wrapScene／sceneAfterSky／cowShadow／sparkle／spark。
import { BREEDS, genesFor } from './data.js';
import { cowModel } from './cowgeo.js';
import { sceneItems, W, H } from './scenegeo.js';
import { ICONS, bucketItems } from './icongeo.js';
import { renderItems, nextId } from './render.js';
import { smoothPath } from './q.js';

const f2 = (v) => Math.round(v * 100) / 100;

export function drawCow(st, entry, { x = 0, y = 0, scale = 1, facing = 'left', idp = nextId('cw') } = {}) {
  const g = entry.genes || genesFor(entry);
  const M = cowModel(g);
  const s = scale * M.size, mirror = facing === 'right', m = mirror ? -1 : 1;
  const ctx = { idp, mirror, lx: mirror ? 1 : -1, scale: s, kind: 'cow', model: M, g, color: (role, it) => st.cowColor(role, g, it, M) };
  const { defs, body } = renderItems(M.items, st, ctx);
  const inner = `<defs>${defs}</defs>${body}`;
  const svg = `<g transform="translate(${f2(x)},${f2(y)}) scale(${f2(m * s)},${f2(s)})">${st.wrapCow ? st.wrapCow(inner, ctx) : inner}</g>`;
  const P = (pt) => [x + m * pt[0] * s, y + pt[1] * s];
  const sh = P([M.shadow.cx, 0]);
  const fc = P([M.face.cx, M.face.cy]);
  const b = M.bbox;
  const xs = [P([b.x0, 0])[0], P([b.x1, 0])[0]];
  return {
    svg, M, scale: s, headTop: P(M.headTop),
    shadow: { cx: sh[0], cy: y, rx: M.shadow.rx * s, ry: M.shadow.ry * s },
    face: { cx: fc[0], cy: fc[1], r: M.face.r * s },
    box: { x0: Math.min(...xs), x1: Math.max(...xs), y0: y + b.y0 * s, y1: y },
  };
}

export function iconSVG(st, name, { active = false, size = 28, cls = '' } = {}) {
  if (name === 'up' || name === 'down') {
    const d = name === 'up' ? 'M6 1.8l4.6 7.6H1.4z' : 'M6 10.2l4.6-7.6H1.4z';
    return `<svg class="tri" viewBox="0 0 12 12" width="11" height="11"><path d="${d}" fill="currentColor" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"/></svg>`;
  }
  const items = name === 'bucket' ? bucketItems(active) : ICONS[name]();
  const ctx = { idp: nextId('ic'), lx: -1, scale: size / 32, kind: 'icon', name, active, color: (role) => st.iconColor(role, { active, name }) };
  const { defs, body } = renderItems(items, st, ctx);
  const inner = `<defs>${defs}</defs>${body}`;
  return `<svg class="ic ${cls}" viewBox="-2 -2 36 36" width="${size}" height="${size}">${st.wrapIcon ? st.wrapIcon(inner, ctx) : inner}</svg>`;
}

export function makeKit(st) {
  return {
    name: st.key,
    icon: (name, opts = {}) => {
      const sizes = { coin: 32, news: 22, bottle: 24, crate: 25, leaf: 14, bubble: 22 };
      const size = name.startsWith('tab-') ? 30 : opts.small ? 22 : sizes[name] || 24;
      return iconSVG(st, name, { active: !!opts.active, size });
    },
    num: (text, role, opts = {}) => `<span class="num num-${role}${opts.dir ? ' ' + opts.dir : ''}">${text}</span>`,
    bucket: (pct) => iconSVG(st, 'bucket', { active: pct, size: 46, cls: 'bucket-ic' }),
    avatar: () => {
      const c = drawCow(st, { breed: 'holstein' }, { idp: 'av' });
      const r = c.face.r;
      return `<svg viewBox="${f2(c.face.cx - r)} ${f2(c.face.cy - r)} ${f2(r * 2)} ${f2(r * 2)}" width="46" height="46">${c.svg}</svg>`;
    },
    spark: (series, dir) => {
      const w = 74, h = 30, p = 4;
      const min = Math.min(...series), max = Math.max(...series);
      const pts = series.map((v, i) => [p + (i / (series.length - 1)) * (w - p * 2), p + (1 - (v - min) / (max - min)) * (h - p * 2)]);
      return `<svg viewBox="0 0 ${w} ${h}" width="${w}" height="${h}">${st.spark(pts, dir, w, h)}</svg>`;
    },
    scene: (el, herd) => {
      const ctx = { idp: 'sc', lx: -1, scale: 1, kind: 'scene', color: (role, it) => st.sceneColor(role, it) };
      const { defs, body } = renderItems(sceneItems(herd), st, ctx);
      const o = [];
      let bubble = null;
      const nudge = st.nudge || { wagyu: -14, highland: 10, jersey: 6 };
      const sorted = herd.map((c) => ({ ...c, x: c.x + (nudge[c.id] || 0) })).sort((a, b) => a.depth - b.depth || a.y - b.y);
      sorted.forEach((c, i) => {
        const s = [0.8, 0.9, 1.0][c.depth] * (st.sceneScale || 0.9);
        const cow = drawCow(st, c, { x: c.x, y: c.y, scale: s, facing: c.facing, idp: `h${i}` });
        o.push(st.cowShadow(cow.shadow));
        o.push(cow.svg);
        if (c.bubble) bubble = [cow.headTop[0], cow.headTop[1] - 6];
        if (BREEDS[c.breed].special && st.sparkle) o.push(st.sparkle(cow.headTop[0] + 20 * s, cow.headTop[1] + 8, 5.5 * s), st.sparkle(cow.headTop[0] - 22 * s, cow.headTop[1] + 16, 3.6 * s));
      });
      const svg = `<defs>${defs}</defs>${body}${o.join('')}`;
      el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" width="${W}" height="${H}">${st.wrapScene ? st.wrapScene(svg) : svg}</svg>`;
      return { bubble };
    },
    after: (root) => {
      root.insertAdjacentHTML('afterbegin', `<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs>${st.globalDefs()}</defs></svg>`);
      if (st.after) st.after(root);
    },
  };
}

// 排排站：荷斯坦與小牛並排，其他五個品種（同一比例）
export const LINEUP_ROWS = [
  [{ breed: 'holstein', label: '荷斯坦' }, { breed: 'holstein', age: 'calf', seed: 31, label: '荷斯坦小牛' }, { breed: 'jersey', label: '娟珊' }],
  [{ breed: 'wagyu', label: '和牛' }, { breed: 'highland', label: '高地牛' }],
  [{ breed: 'strawberry', label: '草莓牛' }, { breed: 'chocolate', label: '巧克力牛' }],
];
export { smoothPath };
