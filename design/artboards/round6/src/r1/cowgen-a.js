// 風格 A「圓潤Q版」renderer：粗圓描邊、扁平粉彩。讀 cowgen.js 的模型，輸出 SVG 字串。
import { smoothPath, polyPath, shade, mix, lum, taperPts, bezierAt } from './cowgen.js';

export const A_OUTLINE = '#4B3326';
const sp = (pts) => smoothPath(pts);

function pastel(c) { return mix(c, '#FFF7EE', 0.1); }

export function paletteA(M) {
  const g = M.genes;
  const coat = pastel(g.coat);
  const pat = pastel(g.patternColor);
  const dark = lum(coat) < 0.12;
  return {
    coat, pat, dark,
    far: shade(coat, dark ? -0.05 : -0.09),
    farPat: shade(pat, -0.08),
    ear: g.earColor === 'pattern' ? pat : coat,
    earIn: mix(g.muzzle, '#FFFFFF', 0.25),
    muzzle: pastel(g.muzzle),
    nostril: mix(g.muzzle, '#5A2A33', 0.5),
    hoof: dark ? '#231815' : '#6A4A3B',
    horn: '#FFF4DA', hornTip: '#D8B889',
    tuft: g.pattern === 'patches' ? pat : shade(coat, dark ? -0.04 : -0.16),
    fringe: shade(coat, 0.07),
    eye: '#2B1D1A',
    cheek: '#FF8DA1',
    udder: '#FFC0CB',
    line: A_OUTLINE,
  };
}

// 回傳一頭牛的 <g>（含 defs）。x、y 為腳底中心在畫面上的位置。
export function cowA(M, { x = 0, y = 0, scale = 1, facing = 'left', id = 'cow', headOnly = false, lineW = 3.2 } = {}) {
  const P = paletteA(M);
  const mirror = facing === 'right';
  const s = scale * M.unit;
  const lx = mirror ? 1 : -1; // 高光在模型座標的哪一側（翻轉後永遠在畫面左上）
  const sw = lineW;
  const o = [];
  const defs = [];
  const clip = (name, pts) => { defs.push(`<clipPath id="${id}-${name}"><path d="${sp(pts)}"/></clipPath>`); return `url(#${id}-${name})`; };

  const leg = (L) => {
    const fill = L.far ? P.far : P.coat;
    const cid = clip(`leg${L.x}`, L.pts);
    o.push(`<path d="${sp(L.pts)}" fill="${fill}"/>`);
    o.push(`<rect x="${L.x - L.w}" y="${L.bottom - L.hoof}" width="${L.w * 2}" height="${L.hoof + 2}" fill="${P.hoof}" clip-path="${cid}"/>`);
    o.push(`<path d="${sp(L.pts)}" fill="none" stroke="${P.line}" stroke-width="${sw * 0.9}" stroke-linejoin="round"/>`);
  };

  if (!headOnly) {
    // 腿全部畫在身體後面，只露出下半截（短短胖胖）
    M.legs.filter((L) => L.far).forEach(leg);
    M.legs.filter((L) => !L.far).forEach(leg);
    // 尾巴
    const t = M.tail;
    const td = `M${t.p0[0]},${t.p0[1]} Q${t.p1[0]},${t.p1[1]} ${t.p2[0]},${t.p2[1]}`;
    o.push(`<path d="${td}" fill="none" stroke="${P.line}" stroke-width="${t.w + sw * 1.6}" stroke-linecap="round"/>`);
    o.push(`<path d="${td}" fill="none" stroke="${P.coat}" stroke-width="${t.w}" stroke-linecap="round"/>`);
    o.push(`<path d="${sp(t.tuft.pts)}" fill="${P.tuft}" stroke="${P.line}" stroke-width="${sw * 0.85}" stroke-linejoin="round"/>`);
    // 乳房
    if (M.udder) o.push(`<path d="${sp(M.udder.pts)}" fill="${P.udder}" stroke="${P.line}" stroke-width="${sw * 0.8}"/>`);
    // 身體
    const bc = clip('body', M.body.pts);
    o.push(`<path d="${sp(M.body.pts)}" fill="${P.coat}"/>`);
    o.push(`<g clip-path="${bc}">`);
    M.pattern.body.forEach((b) => o.push(`<path d="${sp(b)}" fill="${P.pat}"/>`));
    M.pattern.dots.filter((d) => d.where === 'body').forEach((d) => o.push(`<circle cx="${d.cx}" cy="${d.cy}" r="${d.r}" fill="${P.pat}"/>`));
    M.pattern.seeds.filter((d) => d.where === 'body').forEach((d) => o.push(seedA(d, P)));
    const B = M.body;
    // 扁平的肚子陰影（一塊半透明深色）
    o.push(`<ellipse cx="${B.cx + 4}" cy="${B.cy + B.ry * 1.02}" rx="${B.rx * 1.15}" ry="${B.ry * 0.52}" fill="${P.line}" opacity="0.11"/>`);
    // 背上的高光
    o.push(`<path d="M${B.cx + lx * B.rx * 0.2},${B.cy - B.ry * 0.62} Q${B.cx + lx * B.rx * 0.5},${B.cy - B.ry * 0.78} ${B.cx + lx * B.rx * 0.66},${B.cy - B.ry * 0.5}" fill="none" stroke="#FFFFFF" stroke-width="${sw * 1.1}" stroke-linecap="round" opacity="${P.dark ? 0.35 : 0.8}"/>`);
    o.push(`</g>`);
    o.push(`<path d="${sp(M.body.pts)}" fill="none" stroke="${P.line}" stroke-width="${sw}" stroke-linejoin="round"/>`);
  }

  const H = M.head;
  // 角（在頭後面）
  M.horns.forEach((h, i) => {
    const hc = clip(`horn${i}`, h.pts);
    const tipPts = taperPts(bezierAt(h.p0, h.p1, h.p2, h.tipFrom), bezierAt(h.p0, h.p1, h.p2, (1 + h.tipFrom) / 2), h.p2, 8, 1, 8);
    o.push(`<path d="${polyPath(h.pts)}" fill="${P.horn}"/>`);
    o.push(`<path d="${polyPath(tipPts)}" fill="${P.hornTip}" clip-path="${hc}"/>`);
    o.push(`<path d="${polyPath(h.pts)}" fill="none" stroke="${P.line}" stroke-width="${sw * 0.85}" stroke-linejoin="round"/>`);
  });
  // 耳朵
  M.ears.forEach((e) => {
    o.push(`<path d="${sp(e.pts)}" fill="${P.ear}" stroke="${P.line}" stroke-width="${sw * 0.9}" stroke-linejoin="round"/>`);
    o.push(`<path d="${sp(e.inner)}" fill="${P.earIn}"/>`);
  });
  // 頭
  const hc = clip('head', H.pts);
  o.push(`<path d="${sp(H.pts)}" fill="${P.coat}"/>`);
  o.push(`<g clip-path="${hc}">`);
  M.pattern.head.forEach((b) => o.push(`<path d="${sp(b)}" fill="${P.pat}"/>`));
  M.pattern.dots.filter((d) => d.where === 'head').forEach((d) => o.push(`<circle cx="${d.cx}" cy="${d.cy}" r="${d.r}" fill="${P.pat}"/>`));
  M.pattern.seeds.filter((d) => d.where === 'head').forEach((d) => o.push(seedA(d, P)));
  o.push(`</g>`);
  o.push(`<path d="${sp(H.pts)}" fill="none" stroke="${P.line}" stroke-width="${sw}" stroke-linejoin="round"/>`);
  // 頭頂高光
  o.push(`<path d="M${H.cx + lx * H.rx * 0.25},${H.cy - H.ry * 0.78} Q${H.cx + lx * H.rx * 0.62},${H.cy - H.ry * 0.74} ${H.cx + lx * H.rx * 0.74},${H.cy - H.ry * 0.38}" fill="none" stroke="#FFFFFF" stroke-width="${sw * 1.05}" stroke-linecap="round" opacity="${P.dark ? 0.4 : 0.85}"/>`);
  // 眼睛
  M.eyes.forEach((e) => {
    o.push(`<ellipse cx="${e.cx}" cy="${e.cy}" rx="${e.rx}" ry="${e.ry}" fill="${P.eye}"/>`);
    o.push(`<circle cx="${e.cx + lx * e.rx * 0.32}" cy="${e.cy - e.ry * 0.36}" r="${e.rx * 0.46}" fill="#FFFFFF"/>`);
    o.push(`<circle cx="${e.cx - lx * e.rx * 0.34}" cy="${e.cy + e.ry * 0.42}" r="${e.rx * 0.2}" fill="#FFFFFF"/>`);
    if (M.lashes) {
      const s = e.side;
      const x0 = e.cx + s * e.rx * 0.75, y0 = e.cy - e.ry * 0.62;
      o.push(`<path d="M${x0},${y0} l${s * 3},-2.6 M${x0 - s * 1.6},${y0 - 1.6} l${s * 1.9},-3.2" stroke="${P.eye}" stroke-width="1.6" stroke-linecap="round" fill="none"/>`);
    }
  });
  // 瀏海
  if (M.fringe) {
    o.push(`<path d="${sp(M.fringe.pts)}" fill="${P.fringe}" stroke="${P.line}" stroke-width="${sw * 0.9}" stroke-linejoin="round"/>`);
    const fx = H.cx + lx * H.rx * 0.45, fy = H.cy - H.ry * 0.62;
    o.push(`<path d="M${fx},${fy} q${-lx * 3},-4 ${-lx * 8},-4" fill="none" stroke="#FFFFFF" stroke-width="${sw * 0.9}" stroke-linecap="round" opacity="0.7"/>`);
  }
  // 腮紅
  M.cheeks.forEach((c) => o.push(`<ellipse cx="${c.cx}" cy="${c.cy}" rx="${c.rx}" ry="${c.ry}" fill="${P.cheek}" opacity="${P.dark ? 0.8 : 0.6}"/>`));
  // 口鼻
  const Mz = M.muzzle;
  o.push(`<path d="${sp(Mz.pts)}" fill="${P.muzzle}" stroke="${P.line}" stroke-width="${sw}" stroke-linejoin="round"/>`);
  o.push(`<ellipse cx="${Mz.cx + lx * Mz.rx * 0.42}" cy="${Mz.cy - Mz.ry * 0.5}" rx="${Mz.rx * 0.22}" ry="${Mz.ry * 0.16}" fill="#FFFFFF" opacity="0.75"/>`);
  M.nostrils.forEach((n) => o.push(`<ellipse cx="${n.cx}" cy="${n.cy}" rx="${n.rx}" ry="${n.ry}" transform="rotate(${(n.rot * 180) / Math.PI} ${n.cx} ${n.cy})" fill="${P.nostril}"/>`));
  const m = M.mouth;
  o.push(`<path d="M${m.cx - m.w},${m.cy - 0.6} q${m.w / 2},${m.w * 0.75} ${m.w},0 q${m.w / 2},${m.w * 0.75} ${m.w},0" fill="none" stroke="${P.line}" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>`);
  // 特殊疊層
  if (M.overlay) o.push(overlayA(M, P, sw, lx));

  const sx = mirror ? -s : s;
  return `<g transform="translate(${x},${y}) scale(${sx},${s})"><defs>${defs.join('')}</defs>${o.join('')}</g>`;
}

function seedA(d, P) {
  const r = 1.55;
  return `<ellipse cx="${d.cx}" cy="${d.cy}" rx="${r}" ry="${r * 1.5}" transform="rotate(${(d.rot * 180) / Math.PI} ${d.cx} ${d.cy})" fill="${P.pat}"/>`;
}

function overlayA(M, P, sw, lx) {
  const ov = M.overlay;
  const out = [];
  if (ov.type === 'berry') {
    const [a, b] = ov.stem;
    out.push(`<path d="M${a[0]},${a[1]} Q${a[0] - 1},${(a[1] + b[1]) / 2} ${b[0]},${b[1]}" stroke="${P.line}" stroke-width="${2.6 + sw}" stroke-linecap="round" fill="none"/>`);
    out.push(`<path d="M${a[0]},${a[1]} Q${a[0] - 1},${(a[1] + b[1]) / 2} ${b[0]},${b[1]}" stroke="#5FA84E" stroke-width="2.6" stroke-linecap="round" fill="none"/>`);
    ov.leaves.forEach((L) => out.push(`<path d="${smoothPath(L)}" fill="#69C267" stroke="${P.line}" stroke-width="${sw * 0.8}" stroke-linejoin="round"/>`));
    out.push(`<circle cx="${ov.c[0]}" cy="${ov.c[1]}" r="2.6" fill="#4FA24E"/>`);
  } else if (ov.type === 'cream') {
    [...ov.tiers].forEach((t, i) => {
      out.push(`<ellipse cx="${t.cx}" cy="${t.cy}" rx="${t.rx}" ry="${t.ry}" fill="#FFF6E6" stroke="${P.line}" stroke-width="${sw * 0.85}"/>`);
      out.push(`<path d="M${t.cx + lx * t.rx * 0.55},${t.cy - t.ry * 0.1} q${-lx * 2},-2.4 ${-lx * 5},-2.6" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round" fill="none"/>`);
      if (i === 0) out.push(`<path d="M${t.cx - t.rx * 0.7},${t.cy + t.ry * 0.2} q${t.rx * 0.7},${t.ry * 0.7} ${t.rx * 1.4},0" stroke="#E8CFA6" stroke-width="1.6" fill="none" stroke-linecap="round"/>`);
    });
    const tp = ov.tip, t3 = ov.tiers[2];
    out.push(`<path d="M${t3.cx - 3},${t3.cy - 2} Q${tp[0] - 3},${tp[1] + 2} ${tp[0]},${tp[1]} Q${tp[0] + 0.5},${tp[1] + 4} ${t3.cx + 3.5},${t3.cy - 2}" fill="#FFF6E6" stroke="${P.line}" stroke-width="${sw * 0.8}" stroke-linejoin="round"/>`);
    // 巧克力碎片
    out.push(`<rect x="${ov.c[0] - 6}" y="${ov.c[1] - 3}" width="3" height="2.2" rx="0.8" fill="#6B3D24" transform="rotate(-20 ${ov.c[0] - 5} ${ov.c[1] - 2})"/>`);
    out.push(`<rect x="${ov.c[0] + 4}" y="${ov.c[1] - 7}" width="3" height="2.2" rx="0.8" fill="#6B3D24" transform="rotate(25 ${ov.c[0] + 5} ${ov.c[1] - 6})"/>`);
  }
  return out.join('');
}

// 圖庫用：單獨一頭牛的 SVG
export function renderCell(M, { id = 'cell', size = 150 } = {}) {
  const b = M.bbox, pad = 8;
  const w = (b.x1 - b.x0) * M.unit + pad * 2, h = (b.y1 - b.y0) * M.unit + pad * 2;
  const vb = `${b.x0 * M.unit - pad} ${b.y0 * M.unit - pad} ${w} ${h}`;
  const s = Math.max(w, h);
  return `<svg viewBox="${b.x0 * M.unit - pad - (s - w) / 2} ${b.y0 * M.unit - pad - (s - h)} ${s} ${s}" width="${size}" height="${size}">`
    + `<ellipse cx="${M.shadow.cx * M.unit}" cy="0" rx="${M.shadow.rx * M.unit}" ry="${M.shadow.ry * M.unit}" fill="#000" opacity="0.08"/>`
    + cowA(M, { id }) + `</svg>`;
}
