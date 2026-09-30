// 共用的「部位清單 → SVG」走訪器。畫風只提供 style.fill／line／dot／regionClose 怎麼畫，
// 走訪器負責順序、區域裁切（花紋裁在身體裡）與區域描邊的時機（先底色、再花紋、最後描邊）。
import { smoothPath, polyPath } from './q.js';

let uid = 0;
export const nextId = (p = 'u') => `${p}${uid++}`;
export function pathD(pts, { smooth = true, closed = true } = {}) {
  return smooth ? smoothPath(pts, closed) : polyPath(pts, closed);
}
// 把平滑外框重新取樣成少數頂點（扁平幾何風用）
export function facet(pts, n) {
  const out = [];
  for (let i = 0; i < n; i++) out.push(pts[Math.floor((i / n) * pts.length)]);
  return out;
}

// items：部位清單；st：畫風；ctx：{ color(role, item) → 顏色或 null（跳過）, idp }
export function renderItems(items, st, ctx) {
  const defs = [], out = [];
  const regions = {};
  let pending = null;
  const flush = () => {
    if (!pending) return;
    const { it, color, cid } = pending;
    if (st.regionClose) out.push(st.regionClose(it, color, ctx, `url(#${cid})`));
    pending = null;
  };
  for (const it of items) {
    const color = ctx.color(it.role, it);
    if (!it.clip || !pending || pending.it.region !== it.clip) flush();
    if (color === null || color === undefined) continue;
    if (it.region) {
      const cid = nextId(`${ctx.idp || 'c'}r`);
      defs.push(`<clipPath id="${cid}"><path d="${st.pathOf ? st.pathOf(it) : pathD(it.pts)}"/></clipPath>`);
      regions[it.region] = cid;
      out.push(st.fill(it, color, ctx, { base: true }));
      pending = { it, color, cid };
      continue;
    }
    let s = it.t === 'fill' ? st.fill(it, color, ctx, {}) : it.t === 'line' ? st.line(it, color, ctx) : st.dot(it, color, ctx);
    if (it.clip && regions[it.clip]) s = `<g clip-path="url(#${regions[it.clip]})">${s}</g>`;
    out.push(s);
  }
  flush();
  return { defs: defs.join(''), body: out.join('') };
}
