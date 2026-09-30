// R2 共用的 Q 版畫筆：沿用 R1-A 的畫法（3.2 單位可可色粗描邊、扁平粉彩），三種新造型都用這一套部位畫法，
// 所以造型不同、畫風一致。幾何由各造型模型（baby／mochi／book）決定。
import {
  smoothPath, polyPath, densify, superPts, ellipsePts, pointInPoly, scallopPts, taperPts, bezierAt, rng, shade, mix, lum, roundRectPts,
} from './r1/cowgen.js';

export { smoothPath, polyPath, densify, superPts, ellipsePts, pointInPoly, scallopPts, taperPts, bezierAt, rng, shade, mix, lum, roundRectPts };
export const INK = '#4B3326';

// ---------- 幾何小工具 ----------
export function blob(cx, cy, r, rnd, count = 9, wobble = 0.36, squash = null) {
  const raw = [];
  const phase = rnd() * Math.PI * 2;
  const sq = squash ?? 0.78 + rnd() * 0.3;
  for (let i = 0; i < count; i++) {
    const a = phase + (i / count) * Math.PI * 2;
    const rr = r * (1 - wobble / 2 + wobble * rnd());
    raw.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr * sq]);
  }
  return densify(raw, 5);
}
// 葉形（耳朵、蒂頭葉子）：從 base 往 ang 方向長 len，最寬 wid
export function leaf(base, ang, len, wid, { round = 0.7, n = 14 } = {}) {
  const dx = Math.cos(ang), dy = Math.sin(ang), nx = -dy, ny = dx;
  const up = [], lo = [];
  for (let i = 0; i <= n; i++) {
    const t = i / n;
    const w = (wid / 2) * Math.sin(Math.PI * Math.min(1, t ** round)) ** 0.9;
    const px = base[0] + dx * len * t, py = base[1] + dy * len * t;
    up.push([px + nx * w, py + ny * w]);
    lo.push([px - nx * w, py - ny * w]);
  }
  return [...up, ...lo.reverse().slice(1, -1)];
}
export function roundedRect(cx, cy, rx, ry, n = 2.8, count = 40) { return superPts(cx, cy, rx, ry, n, count); }
// 超橢圓上 x 位置的頂端 y（用來把角芽放在輪廓上）
export function topYAt(pts, x) {
  let best = null;
  for (let i = 0; i < pts.length; i++) {
    const a = pts[i], b = pts[(i + 1) % pts.length];
    if ((a[0] - x) * (b[0] - x) <= 0 && a[0] !== b[0]) {
      const t = (x - a[0]) / (b[0] - a[0]);
      const y = a[1] + (b[1] - a[1]) * t;
      if (best === null || y < best) best = y;
    }
  }
  return best;
}
export function bbox(ptsList) {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const pts of ptsList) for (const [x, y] of pts) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  return { x0, y0, x1, y1 };
}

// ---------- 配色 ----------
function pastel(c) { return mix(c, '#FFF7EE', 0.1); }
export function paletteQ(g) {
  const coat = pastel(g.coat);
  const pat = pastel(g.patternColor);
  const dark = lum(coat) < 0.12;
  return {
    coat, pat, dark,
    far: shade(coat, dark ? -0.05 : -0.09),
    ear: g.earColor === 'pattern' ? pat : coat,
    earIn: '#FFCDCB',
    muzzle: g.muzzle, muzzleHi: '#FFFFFF',
    nostril: mix(g.muzzle, '#5B3629', 0.62),
    mouth: mix(g.muzzle, '#5B3629', 0.7),
    hoof: '#4E3830', hoofHi: '#7A5A4C',
    horn: '#FFF4DA', hornTip: '#D8B889',
    tuft: g.pattern === 'patches' ? pat : dark ? '#2A1D19' : shade(coat, -0.2),
    fringe: shade(coat, 0.06),
    forelock: g.pattern === 'patches' && g.patternColor ? pat : shade(coat, dark ? 0.05 : -0.06),
    eye: '#2B1D1A',
    cheek: '#FF93A6',
    udder: '#FFC3CB', teat: '#FFA9B6',
    strap: '#F2705F', strapHi: '#FF9E8E', bell: '#FFD45E', bellRim: '#E6A33A', bellHi: '#FFF3C4',
    seed: g.seedColor || '#FFE9A8',
    line: INK,
  };
}

// ---------- 畫筆 ----------
export function painter({ id, mirror = false, lw = 3.2 }) {
  const defs = [], out = [];
  let k = 0;
  const lx = mirror ? 1 : -1; // 模型座標裡「畫面左邊」的方向：高光一律在畫面左上
  const f = (v) => Math.round(v * 100) / 100;
  const P = {
    lx, lw, out,
    d(pts, smooth = true) { return smooth ? smoothPath(pts) : polyPath(pts); },
    clip(pts, smooth = true) {
      const cid = `${id}-k${k++}`;
      defs.push(`<clipPath id="${cid}"><path d="${P.d(pts, smooth)}"/></clipPath>`);
      return `url(#${cid})`;
    },
    shape(pts, fill, { line = true, w = 1, smooth = true, opacity = null } = {}) {
      out.push(`<path d="${P.d(pts, smooth)}" fill="${fill}"${line ? ` stroke="${INK}" stroke-width="${f(lw * w)}" stroke-linejoin="round"` : ''}${opacity != null ? ` opacity="${opacity}"` : ''}/>`);
    },
    outline(pts, { w = 1, smooth = true } = {}) {
      out.push(`<path d="${P.d(pts, smooth)}" fill="none" stroke="${INK}" stroke-width="${f(lw * w)}" stroke-linejoin="round"/>`);
    },
    // 底色＋裁切在形狀內的花紋／陰影＋最上層描邊
    region(pts, fill, inside, { w = 1, smooth = true } = {}) {
      const c = P.clip(pts, smooth);
      out.push(`<path d="${P.d(pts, smooth)}" fill="${fill}"/>`);
      out.push(`<g clip-path="${c}">`);
      if (inside) inside();
      out.push(`</g>`);
      P.outline(pts, { w, smooth });
    },
    line(pts, color, width, { outline = true, smooth = true } = {}) {
      const d = smooth ? smoothPath(pts, false) : polyPath(pts, false);
      if (outline) out.push(`<path d="${d}" fill="none" stroke="${INK}" stroke-width="${f(width + lw * 1.7)}" stroke-linecap="round" stroke-linejoin="round"/>`);
      out.push(`<path d="${d}" fill="none" stroke="${color}" stroke-width="${f(width)}" stroke-linecap="round" stroke-linejoin="round"/>`);
    },
    ellipse(cx, cy, rx, ry, fill, { rot = 0, line = false, w = 1, opacity = null } = {}) {
      out.push(`<ellipse cx="${f(cx)}" cy="${f(cy)}" rx="${f(rx)}" ry="${f(ry)}"${rot ? ` transform="rotate(${f((rot * 180) / Math.PI)} ${f(cx)} ${f(cy)})"` : ''} fill="${fill}"${line ? ` stroke="${INK}" stroke-width="${f(lw * w)}"` : ''}${opacity != null ? ` opacity="${opacity}"` : ''}/>`);
    },
    arc(pts, color, width, opacity = 1) {
      out.push(`<path d="${smoothPath(pts, false)}" fill="none" stroke="${color}" stroke-width="${f(width)}" stroke-linecap="round" stroke-linejoin="round" opacity="${opacity}"/>`);
    },
    raw(s) { out.push(s); },
    svg({ x = 0, y = 0, scale = 1 } = {}) {
      const sx = mirror ? -scale : scale;
      return `<g transform="translate(${f(x)},${f(y)}) scale(${f(sx)},${f(scale)})"><defs>${defs.join('')}</defs>${out.join('')}</g>`;
    },
  };
  return P;
}

// ---------- 部位 ----------
// 眼睛：big 大眼雙反光、normal 一般、dot 豆豆眼
export function eye(P, C, e, style = 'normal') {
  P.ellipse(e.cx, e.cy, e.rx, e.ry, C.eye);
  const lx = P.lx;
  if (style === 'dot') {
    P.ellipse(e.cx + lx * e.rx * 0.28, e.cy - e.ry * 0.34, e.rx * 0.34, e.rx * 0.34, '#FFFFFF');
    return;
  }
  P.ellipse(e.cx + lx * e.rx * 0.3, e.cy - e.ry * 0.34, e.rx * (style === 'big' ? 0.44 : 0.42), e.rx * (style === 'big' ? 0.44 : 0.42), '#FFFFFF');
  P.ellipse(e.cx - lx * e.rx * 0.34, e.cy + e.ry * 0.4, e.rx * 0.19, e.rx * 0.19, '#FFFFFF');
  if (style === 'big') P.arc([[e.cx - e.rx * 0.55, e.cy + e.ry * 0.62], [e.cx, e.cy + e.ry * 0.82], [e.cx + e.rx * 0.55, e.cy + e.ry * 0.62]], '#6B5A63', e.rx * 0.28, 0.9);
}
// 口鼻：寬扁的圓角長方形，上緣兩個小鼻孔，下面一條小微笑
export function muzzle(P, C, m) {
  const pts = roundedRect(m.cx, m.cy, m.rx, m.ry, m.n ?? 2.9, 44);
  P.shape(pts, C.muzzle);
  const lx = P.lx;
  P.ellipse(m.cx + lx * m.rx * 0.5, m.cy - m.ry * 0.46, m.rx * 0.2, m.ry * 0.17, '#FFFFFF', { opacity: 0.8 });
  const nr = m.nostril ?? Math.max(1.4, m.rx * 0.11);
  for (const s of [-1, 1]) {
    P.ellipse(m.cx + s * m.rx * 0.4, m.cy - m.ry * 0.2, nr * 1.25, nr * 0.78, C.nostril, { rot: s * 0.55 });
  }
  const mw = m.rx * 0.2, my = m.cy + m.ry * 0.42;
  P.arc([[m.cx - mw, my - mw * 0.2], [m.cx, my + mw * 0.32], [m.cx + mw, my - mw * 0.2]], C.mouth, Math.max(1.3, m.rx * 0.085));
}
export function ear(P, C, e) {
  const pts = leaf(e.base, e.ang, e.len, e.wid, { round: 0.62 });
  P.shape(pts, C.ear, { w: 0.9 });
  const inner = leaf([e.base[0] + Math.cos(e.ang) * e.len * 0.18, e.base[1] + Math.sin(e.ang) * e.len * 0.18], e.ang, e.len * 0.66, e.wid * 0.5, { round: 0.62 });
  P.shape(inner, C.earIn, { line: false });
}
export function horn(P, C, h) {
  if (h.type === 'bud') {
    const pts = superPts(h.base[0], h.base[1], h.r, h.r * 0.9, 2.2, 20).filter((p) => p[1] <= h.base[1] + 0.5);
    pts.push([h.base[0] + h.r, h.base[1] + 1.5], [h.base[0] - h.r, h.base[1] + 1.5]);
    const bud = superPts(h.base[0], h.base[1] - h.r * 0.1, h.r, h.r * 0.95, 2.1, 22);
    const c = P.clip(bud);
    P.raw(`<path d="${smoothPath(bud)}" fill="${C.horn}"/>`);
    P.raw(`<g clip-path="${c}"><ellipse cx="${h.base[0]}" cy="${h.base[1] - h.r * 1.2}" rx="${h.r * 1.1}" ry="${h.r * 0.7}" fill="${C.hornTip}" opacity="0.55"/></g>`);
    P.outline(bud, { w: 0.85 });
    return;
  }
  const pts = taperPts(h.p0, h.p1, h.p2, h.w0, h.w1, 16);
  const tip = taperPts(bezierAt(h.p0, h.p1, h.p2, h.tipFrom ?? 0.62), bezierAt(h.p0, h.p1, h.p2, ((h.tipFrom ?? 0.62) + 1) / 2), h.p2, h.w0 * 1.1, 1, 8);
  const c = P.clip(pts, false);
  P.raw(`<path d="${polyPath(pts)}" fill="${C.horn}"/><path d="${polyPath(tip)}" fill="${C.hornTip}" clip-path="${c}"/>`);
  P.outline(pts, { w: 0.85, smooth: false });
}
// 牛鈴：strap 是項圈帶子的路徑（開放曲線），bell 是鈴鐺中心與大小
export function collar(P, C, strapPts, bellAt, s = 1) {
  if (strapPts) {
    P.line(strapPts, C.strap, 4.6 * s);
    P.arc(strapPts.map(([x, y]) => [x, y - 1.1 * s]), C.strapHi, 1.3 * s, 0.9);
  }
  const [x, y] = bellAt;
  const bell = [
    [x - 1.2 * s, y - 5.2 * s], [x + 1.2 * s, y - 5.2 * s], [x + 3.9 * s, y - 3.2 * s], [x + 4.8 * s, y + 1.6 * s], [x + 6.2 * s, y + 4.4 * s],
    [x, y + 5.2 * s], [x - 6.2 * s, y + 4.4 * s], [x - 4.8 * s, y + 1.6 * s], [x - 3.9 * s, y - 3.2 * s],
  ];
  P.ellipse(x, y - 6 * s, 1.8 * s, 1.5 * s, C.bellRim, { line: true, w: 0.55 });
  const c = P.clip(bell);
  P.raw(`<path d="${smoothPath(bell)}" fill="${C.bell}"/><g clip-path="${c}"><rect x="${x - 8 * s}" y="${y + 2.6 * s}" width="${16 * s}" height="${4 * s}" fill="${C.bellRim}"/></g>`);
  P.outline(bell, { w: 0.7 });
  P.ellipse(x, y + 4.6 * s, 1.5 * s, 1.3 * s, INK);
  P.arc([[x + P.lx * 2.6 * s, y - 2.6 * s], [x + P.lx * 3.4 * s, y + 0.8 * s]], C.bellHi, 1.2 * s, 0.95);
}
export function udder(P, C, u) {
  const body = superPts(u.cx, u.cy, u.rx, u.ry, 2.1, 26);
  for (const tx of u.teats) {
    const t = superPts(tx, u.cy + u.ry * 0.82, u.rx * 0.2, u.ry * 0.62, 2.4, 14);
    P.shape(t, C.teat, { w: 0.6 });
  }
  P.shape(body, C.udder, { w: 0.8 });
  P.ellipse(u.cx + P.lx * u.rx * 0.35, u.cy - u.ry * 0.25, u.rx * 0.25, u.ry * 0.18, '#FFFFFF', { opacity: 0.8 });
}
// 尾巴：一條細尾巴＋末端一撮毛
export function tail(P, C, t) {
  const pts = [];
  for (let i = 0; i <= 8; i++) pts.push(bezierAt(t.p0, t.p1, t.p2, i / 8));
  P.line(pts, t.color ?? C.coat, t.w);
  const [ex, ey] = t.p2;
  const base = ellipsePts(ex + (t.tuftDx ?? 0), ey + t.tuftR * 0.9, t.tuftR * 0.72, t.tuftR * 1.05, t.tuftRot ?? 0, 7);
  P.shape(scallopPts(base, 0.42, 5), C.tuft, { w: 0.85 });
}
// 腿：腿身＋深色蹄
export function leg(P, C, L) {
  const c = P.clip(L.pts);
  P.raw(`<path d="${smoothPath(L.pts)}" fill="${L.fill}"/>`);
  P.raw(`<g clip-path="${c}"><rect x="${L.x - 30}" y="${L.bottom - L.hoof}" width="60" height="${L.hoof + 4}" fill="${C.hoof}"/><rect x="${L.x - 30}" y="${L.bottom - L.hoof}" width="60" height="${Math.max(1, L.hoof * 0.22)}" fill="${C.hoofHi}"/></g>`);
  P.outline(L.pts, { w: 0.9 });
}
export function blush(P, C, c) {
  P.ellipse(c.cx, c.cy, c.rx, c.ry, C.cheek, { opacity: C.dark ? 0.8 : 0.58 });
}
// 花紋：在 region 內畫（呼叫端已經設好裁切）
export function paintPattern(P, C, pat) {
  pat.blobs.forEach((b) => P.shape(b, C.pat, { line: false }));
  pat.dots.forEach((d) => P.ellipse(d.cx, d.cy, d.r, d.r, C.pat));
  pat.seeds.forEach((s) => P.ellipse(s.cx, s.cy, s.r * 0.72, s.r, C.seed, { rot: s.rot }));
}
// 產生花紋：centers 由造型給（避開臉），這裡負責形狀與草莓籽
export function makePattern(g, rnd, spots, region) {
  const pat = { blobs: [], dots: [], seeds: [] };
  if (g.pattern === 'patches' || g.pattern === 'strawberry') {
    spots.forEach((s) => pat.blobs.push(blob(s.cx, s.cy, s.r, rnd, 9, 0.34, s.squash)));
    if (g.pattern === 'strawberry') {
      pat.blobs.forEach((b) => {
        const bb = bbox([b]);
        const sp = Math.max(4.2, (bb.x1 - bb.x0) / 4.2);
        let row = 0;
        for (let y = bb.y0 + sp * 0.5; y < bb.y1; y += sp * 0.82, row++) {
          for (let x = bb.x0 + sp * 0.4 + (row % 2) * sp * 0.5; x < bb.x1; x += sp) {
            const jx = x + (rnd() - 0.5) * sp * 0.25, jy = y + (rnd() - 0.5) * sp * 0.25;
            if (pointInPoly(b, jx, jy) && pointInPoly(b, jx, jy + 2) && pointInPoly(b, jx, jy - 2) && (!region || pointInPoly(region, jx, jy))) {
              pat.seeds.push({ cx: jx, cy: jy, r: 1.55, rot: (rnd() - 0.5) * 0.7 });
            }
          }
        }
      });
    }
  } else if (g.pattern === 'dots') {
    spots.forEach((s) => pat.dots.push({ cx: s.cx, cy: s.cy, r: Math.max(2.2, s.r * 0.25) }));
  }
  return pat;
}
// 蓬鬆瀏海（高地牛）：蓋住額頭，下緣幾撮毛剛好到眼睛上緣
export function fringe(P, C, cx, top, bottom, halfW, rnd) {
  const pts = [];
  for (let i = 0; i <= 14; i++) {
    const a = Math.PI + 0.15 + (i / 14) * (Math.PI - 0.3);
    pts.push([cx + Math.cos(a) * halfW, bottom - 2 + Math.sin(a) * (bottom - top)]);
  }
  const xr = pts[pts.length - 1][0], xl = pts[0][0];
  const tufts = 4;
  for (let i = 0; i < tufts; i++) {
    const xa = xr - ((xr - xl) * i) / tufts, xb = xr - ((xr - xl) * (i + 1)) / tufts, mid = (xa + xb) / 2;
    const dip = (i === 1 || i === 2 ? 5.5 : 3.5) + (rnd() - 0.5);
    pts.push([xa, bottom - (i === 0 ? 2 : 0.5)], [mid + 1.4, bottom + dip], [mid - 1.2, bottom + dip - 0.6]);
  }
  P.shape(pts, C.fringe, { w: 0.9 });
  P.arc([[cx + P.lx * halfW * 0.5, top + (bottom - top) * 0.35], [cx + P.lx * halfW * 0.15, top + (bottom - top) * 0.18]], '#FFFFFF', P.lw * 0.8, 0.7);
}
// 前額一小撮毛
export function forelock(P, C, cx, y, w) {
  const pts = [[cx - w, y + 1.5], [cx - w * 0.7, y - w * 0.55], [cx - w * 0.15, y - w * 0.2], [cx + w * 0.1, y - w * 0.95], [cx + w * 0.55, y - w * 0.3], [cx + w, y + 1.5]];
  P.shape(pts, C.forelock, { w: 0.8 });
}
// 草莓蒂頭／奶油旋
export function overlay(P, C, g, cx, top, s = 1) {
  if (g.overlay === 'berry') {
    const c = [cx, top + 2.5 * s];
    P.line([[c[0], c[1] - 1], [c[0] + 1.2 * s, c[1] - 6 * s], [c[0] + 3 * s, c[1] - 9.5 * s]], '#5FA84E', 2.4 * s);
    const spec = [[Math.PI - 0.42, 11.5], [Math.PI - 0.02, 12.5], [Math.PI + 0.62, 7.5], [2 * Math.PI - 0.62, 7.5], [0.02, 12.5], [0.42, 11.5]];
    spec.forEach(([a, len]) => {
      const l = leaf(c, a, len * s, (len > 10 ? 6.6 : 5.6) * s, { round: 0.8 });
      P.shape(l.map(([x, y]) => [x, c[1] + (y - c[1]) * 0.7]), '#69C267', { w: 0.75 });
    });
    P.ellipse(c[0], c[1], 2.6 * s, 2.2 * s, '#4FA24E');
  } else if (g.overlay === 'cream') {
    const c = [cx + 1 * s, top + 2 * s];
    const tiers = [[0, -1, 11, 5], [0.8, -6.2, 8, 4.4], [1.6, -10.6, 5, 3.8]];
    tiers.forEach(([dx, dy, rx, ry], i) => {
      P.ellipse(c[0] + dx * s, c[1] + dy * s, rx * s, ry * s, '#FFF6E6', { line: true, w: 0.8 });
      P.arc([[c[0] + dx * s + P.lx * rx * s * 0.55, c[1] + dy * s], [c[0] + dx * s + P.lx * rx * s * 0.1, c[1] + dy * s - ry * s * 0.55]], '#FFFFFF', 1.5 * s, 1);
    });
    P.line([[c[0] - 2 * s, c[1] - 13 * s], [c[0] + 2 * s, c[1] - 16 * s], [c[0] + 3.8 * s, c[1] - 15 * s]], '#FFF6E6', 2.4 * s);
    P.raw(`<rect x="${c[0] - 6 * s}" y="${c[1] - 3 * s}" width="${3 * s}" height="${2.2 * s}" rx="${0.8 * s}" fill="#6B3D24"/><rect x="${c[0] + 4 * s}" y="${c[1] - 7 * s}" width="${3 * s}" height="${2.2 * s}" rx="${0.8 * s}" fill="#6B3D24"/>`);
  }
}
