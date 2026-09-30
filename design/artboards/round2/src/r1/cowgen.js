// 牛的參數化產生器（核心）：基因 → 幾何與配色模型。
// 模型不管畫風，只描述「哪個部位在哪裡、多大、什麼顏色、花紋落在哪」。
// 三種畫風的 renderer（cowgen-a/b/c.js）讀同一個模型各自畫。
//
// 座標：面向左（頭在左）、腳底 y=0、身體大約置中於 x=0；1 單位 ≈ 成牛在前排時的 1 CSS px。

// ---------- 小工具 ----------
export function rng(seed) {
  let a = (seed * 2654435761) >>> 0 || 1;
  return () => {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function hexToRgb(hex) {
  const h = hex.replace('#', '');
  const v = h.length === 3 ? h.split('').map((c) => c + c).join('') : h;
  return [parseInt(v.slice(0, 2), 16), parseInt(v.slice(2, 4), 16), parseInt(v.slice(4, 6), 16)];
}
export function rgbToHex([r, g, b]) {
  const c = (x) => Math.max(0, Math.min(255, Math.round(x))).toString(16).padStart(2, '0');
  return `#${c(r)}${c(g)}${c(b)}`;
}
export function rgbToHsl([r, g, b]) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  let h = 0, s = 0; const l = (max + min) / 2;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max === r) h = (g - b) / d + (g < b ? 6 : 0);
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h *= 60;
  }
  return [h, s, l];
}
export function hslToRgb([h, s, l]) {
  h = ((h % 360) + 360) % 360;
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l - c / 2;
  let r = 0, g = 0, b = 0;
  if (h < 60) [r, g, b] = [c, x, 0];
  else if (h < 120) [r, g, b] = [x, c, 0];
  else if (h < 180) [r, g, b] = [0, c, x];
  else if (h < 240) [r, g, b] = [0, x, c];
  else if (h < 300) [r, g, b] = [x, 0, c];
  else [r, g, b] = [c, 0, x];
  return [(r + m) * 255, (g + m) * 255, (b + m) * 255];
}
// 調亮暗：dl 為亮度差（-1..1）。變暗時色相往冷色偏、變亮時往暖色偏（像素畫常用的 hue shift）。
export function shade(hex, dl, { hue = 1, sat = 0 } = {}) {
  const rgb = hexToRgb(hex);
  let [h, s, l] = rgbToHsl(rgb);
  // 接近白或黑時 HSL 的飽和度不可靠（#FFFEFD 會算成 100%），改用彩度判斷是不是中性色
  const neutral = (Math.max(...rgb) - Math.min(...rgb)) / 255 < 0.08;
  if (neutral) s = Math.min(s, 0.08);
  const target = dl < 0 ? 245 : 55;
  let dh = ((target - h + 540) % 360) - 180;
  const amt = Math.min(1, Math.abs(dl) * 0.9) * hue * (neutral ? 0.0 : 1);
  h += dh * amt * 0.35;
  if (neutral && dl < 0) { h = 235; s = Math.max(s, 0.16 * hue); } // 白、灰的陰影帶一點藍紫
  s = Math.max(0, Math.min(1, s + sat));
  l = Math.max(0, Math.min(1, l + dl));
  return rgbToHex(hslToRgb([h, s, l]));
}
export function mix(a, b, t) {
  const A = hexToRgb(a), B = hexToRgb(b);
  return rgbToHex(A.map((v, i) => v + (B[i] - v) * t));
}
export function lum(hex) {
  const [r, g, b] = hexToRgb(hex).map((v) => {
    v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

const f = (n) => (Math.round(n * 100) / 100).toString();

// 閉合或開放的平滑曲線（Catmull-Rom → Bézier）
export function smoothPath(pts, closed = true) {
  const n = pts.length;
  if (n < 2) return '';
  const P = (i) => (closed ? pts[(i + n) % n] : pts[Math.max(0, Math.min(n - 1, i))]);
  let d = `M${f(pts[0][0])},${f(pts[0][1])}`;
  const segs = closed ? n : n - 1;
  for (let i = 0; i < segs; i++) {
    const p0 = P(i - 1), p1 = P(i), p2 = P(i + 1), p3 = P(i + 2);
    const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
    const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
    d += `C${f(c1[0])},${f(c1[1])} ${f(c2[0])},${f(c2[1])} ${f(p2[0])},${f(p2[1])}`;
  }
  return d + (closed ? 'Z' : '');
}
export function polyPath(pts, closed = true) {
  return pts.map((p, i) => `${i ? 'L' : 'M'}${f(p[0])},${f(p[1])}`).join('') + (closed ? 'Z' : '');
}
// 由 Catmull-Rom 取樣出密集點（給像素畫做點內判斷）
export function densify(pts, per = 6, closed = true) {
  const n = pts.length, out = [];
  const P = (i) => (closed ? pts[(i + n) % n] : pts[Math.max(0, Math.min(n - 1, i))]);
  const segs = closed ? n : n - 1;
  for (let i = 0; i < segs; i++) {
    const p0 = P(i - 1), p1 = P(i), p2 = P(i + 1), p3 = P(i + 2);
    for (let k = 0; k < per; k++) {
      const t = k / per, t2 = t * t, t3 = t2 * t;
      const q = (a, b, c, d) => 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3);
      out.push([q(p0[0], p1[0], p2[0], p3[0]), q(p0[1], p1[1], p2[1], p3[1])]);
    }
  }
  if (!closed) out.push(pts[n - 1]);
  return out;
}

export function superPts(cx, cy, rx, ry, n = 2, count = 48, rot = 0) {
  const pts = [], cr = Math.cos(rot), sr = Math.sin(rot);
  for (let i = 0; i < count; i++) {
    const t = (i / count) * Math.PI * 2;
    const c = Math.cos(t), s = Math.sin(t);
    const x = rx * Math.sign(c) * Math.abs(c) ** (2 / n);
    const y = ry * Math.sign(s) * Math.abs(s) ** (2 / n);
    pts.push([cx + x * cr - y * sr, cy + x * sr + y * cr]);
  }
  return pts;
}
export function ellipsePts(cx, cy, rx, ry, rot = 0, count = 32) {
  return superPts(cx, cy, rx, ry, 2, count, rot);
}
export function roundRectPts(x, y, w, h, r, count = 8) {
  r = Math.min(r, w / 2, h / 2);
  const pts = [];
  const corner = (cx, cy, a0) => {
    for (let i = 0; i <= count; i++) {
      const a = a0 + (i / count) * (Math.PI / 2);
      pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]);
    }
  };
  corner(x + w - r, y + r, -Math.PI / 2);
  corner(x + w - r, y + h - r, 0);
  corner(x + r, y + h - r, Math.PI / 2);
  corner(x + r, y + r, Math.PI);
  return pts;
}
export function pointInPoly(pts, x, y) {
  let inside = false;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const [xi, yi] = pts[i], [xj, yj] = pts[j];
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}
// 扇貝邊（蓬鬆毛）：沿著外框，每段往外鼓成一小段圓弧
export function scallopPts(base, bulge = 0.55, per = 6) {
  const n = base.length, out = [];
  let cx = 0, cy = 0;
  base.forEach((p) => { cx += p[0]; cy += p[1]; });
  cx /= n; cy /= n;
  for (let i = 0; i < n; i++) {
    const a = base[i], b = base[(i + 1) % n];
    const mx = (a[0] + b[0]) / 2, my = (a[1] + b[1]) / 2;
    let nx = mx - cx, ny = my - cy;
    const nl = Math.hypot(nx, ny) || 1; nx /= nl; ny /= nl;
    const chord = Math.hypot(b[0] - a[0], b[1] - a[1]);
    const h = chord * bulge;
    for (let k = 0; k < per; k++) {
      const t = k / per;
      const bump = Math.sin(Math.PI * t) * h;
      out.push([a[0] + (b[0] - a[0]) * t + nx * bump, a[1] + (b[1] - a[1]) * t + ny * bump]);
    }
  }
  return out;
}
// 錐形曲線（角）：二次貝茲，寬度從 w0 漸細到 w1
export function taperPts(p0, p1, p2, w0, w1, count = 14) {
  const L = [], R = [];
  for (let i = 0; i <= count; i++) {
    const t = i / count, u = 1 - t;
    const x = u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0];
    const y = u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1];
    const dx = 2 * u * (p1[0] - p0[0]) + 2 * t * (p2[0] - p1[0]);
    const dy = 2 * u * (p1[1] - p0[1]) + 2 * t * (p2[1] - p1[1]);
    const dl = Math.hypot(dx, dy) || 1;
    const w = (w0 + (w1 - w0) * t ** 0.9) / 2;
    L.push([x - (dy / dl) * w, y + (dx / dl) * w]);
    R.push([x + (dy / dl) * w, y - (dx / dl) * w]);
  }
  return [...L, ...R.reverse()];
}
export function bezierAt(p0, p1, p2, t) {
  const u = 1 - t;
  return [u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0], u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]];
}

function blobPts(cx, cy, r, rnd, count = 9, wobble = 0.38) {
  const raw = [];
  const phase = rnd() * Math.PI * 2;
  const squash = 0.78 + rnd() * 0.3;
  for (let i = 0; i < count; i++) {
    const a = phase + (i / count) * Math.PI * 2;
    const rr = r * (1 - wobble / 2 + wobble * rnd());
    raw.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr * squash]);
  }
  return raw;
}

// ---------- 基因 ----------
export const GENE_DEFAULTS = {
  coat: '#FFFFFF', pattern: 'solid', patternColor: '#2E2A33', horns: 'none', build: 'normal',
  fur: 'smooth', overlay: 'none', eyes: 'normal', age: 'adult', muzzle: '#FFB3BF', earColor: 'coat', seed: 1,
};
export const GENE_OPTIONS = {
  pattern: ['patches', 'dots', 'solid', 'strawberry'],
  horns: ['none', 'short', 'long'],
  build: ['stocky', 'normal'],
  fur: ['smooth', 'fluffy'],
  overlay: ['none', 'berry', 'cream'],
  eyes: ['normal', 'big'],
  age: ['adult', 'calf'],
};

// 隨機基因（給「幾十種品種」的量產示範用）
export function randomGenes(seed) {
  const r = rng(seed * 31 + 7);
  const pick = (arr) => arr[Math.floor(r() * arr.length)];
  const hue = Math.floor(r() * 360);
  const coats = [
    () => '#FFFFFF', () => '#F6EBDD', () => rgbToHex(hslToRgb([20 + r() * 25, 0.45 + r() * 0.3, 0.45 + r() * 0.2])),
    () => rgbToHex(hslToRgb([15 + r() * 20, 0.25 + r() * 0.2, 0.18 + r() * 0.12])),
    () => rgbToHex(hslToRgb([hue, 0.55 + r() * 0.3, 0.72 + r() * 0.1])),
    () => rgbToHex(hslToRgb([30 + r() * 20, 0.7, 0.55 + r() * 0.1])),
    () => rgbToHex(hslToRgb([0, 0, 0.35 + r() * 0.4])),
  ];
  const coat = pick(coats)();
  const pattern = pick(GENE_OPTIONS.pattern);
  const dark = lum(coat) < 0.25;
  const patternColor = pattern === 'strawberry' ? '#FFF2A6'
    : dark ? pick(['#FFFFFF', '#FFE7C2', '#F4D6A8'])
      : pick(['#2E2A33', '#5A3A28', '#8A5634', rgbToHex(hslToRgb([(hue + 180) % 360, 0.45, 0.62])), '#FFFFFF']);
  return {
    coat, pattern, patternColor,
    horns: pick(GENE_OPTIONS.horns), build: pick(GENE_OPTIONS.build), fur: r() < 0.25 ? 'fluffy' : 'smooth',
    overlay: r() < 0.72 ? 'none' : pick(['berry', 'cream']), eyes: pick(GENE_OPTIONS.eyes),
    age: r() < 0.2 ? 'calf' : 'adult',
    muzzle: dark ? '#E0A2A8' : pick(['#FFB3BF', '#F4DCC4', '#FF9DB3', '#F3B79B']),
    earColor: pattern === 'patches' && r() < 0.5 ? 'pattern' : 'coat',
    seed: Math.floor(r() * 1e6),
  };
}

// ---------- 模型 ----------
export function buildCow(genesIn) {
  const g = { ...GENE_DEFAULTS, ...genesIn };
  const calf = g.age === 'calf';
  const stocky = g.build === 'stocky' && !calf;
  const fluffy = g.fur === 'fluffy';
  const rnd = rng(g.seed + 101);
  const M = { genes: g, calf, stocky, fluffy, unit: calf ? 0.74 : 1 };

  // 身體
  M.body = calf
    ? { cx: 7, cy: -30, rx: 29, ry: 21, n: 2.5 }
    : stocky
      ? { cx: 10, cy: -39.5, rx: 44, ry: 29.5, n: 2.9 }
      : { cx: 9, cy: -38, rx: 39.5, ry: 27, n: 2.6 };
  const B = M.body;
  let bodyPts = superPts(B.cx, B.cy, B.rx, B.ry, B.n, 56);
  if (stocky) {
    // 和牛：肩部肌肉隆起（前上方鼓起）
    bodyPts = bodyPts.map(([x, y]) => {
      const nx = (x - B.cx) / B.rx, ny = (y - B.cy) / B.ry;
      const w = Math.max(0, -ny) * Math.max(0, 1 - Math.abs(nx + 0.35) * 1.6);
      return [x, y - w * 6];
    });
  }
  if (fluffy) bodyPts = scallopPts(superPts(B.cx, B.cy, B.rx + 1, B.ry + 1, B.n, 20), 0.34, 7);
  M.body.pts = bodyPts;

  // 頭
  M.head = calf
    ? { cx: -24, cy: -49, rx: 24, ry: 21, n: 2.3 }
    : { cx: -32, cy: stocky ? -55 : -56, rx: stocky ? 27 : 26, ry: 22.5, n: 2.35 };
  const H = M.head;
  let headPts = superPts(H.cx, H.cy, H.rx, H.ry, H.n, 48);
  // 頭頂略寬、下巴略收
  headPts = headPts.map(([x, y]) => {
    const ny = (y - H.cy) / H.ry;
    return [H.cx + (x - H.cx) * (1 - 0.06 * ny), y];
  });
  M.head.pts = headPts;

  // 口鼻
  M.muzzle = { cx: H.cx, cy: H.cy + H.ry * 0.72, rx: H.rx * 0.74, ry: H.ry * 0.52 };
  M.muzzle.pts = superPts(M.muzzle.cx, M.muzzle.cy, M.muzzle.rx, M.muzzle.ry, 2.25, 40);
  M.nostrils = [-1, 1].map((s) => ({
    cx: M.muzzle.cx + s * M.muzzle.rx * 0.36, cy: M.muzzle.cy - M.muzzle.ry * 0.08,
    rx: calf ? 1.5 : 1.75, ry: calf ? 2.0 : 2.35, rot: s * 0.3,
  }));
  M.mouth = { cx: M.muzzle.cx, cy: M.muzzle.cy + M.muzzle.ry * 0.5, w: calf ? 3.2 : 3.8 };

  // 眼睛
  const big = g.eyes === 'big';
  const eRx = calf ? 4.7 : big ? 5.7 : 4.2;
  const eRy = calf ? 5.8 : big ? 7.1 : 5.3;
  M.eyes = [-1, 1].map((s) => ({
    cx: H.cx + s * (calf ? 9.8 : big ? 11.2 : 10.6), cy: H.cy - (big || calf ? 2 : 2.5), rx: eRx, ry: eRy, big: big || calf, side: s,
  }));
  M.lashes = big && !calf;
  M.cheeks = [-1, 1].map((s) => ({ cx: H.cx + s * H.rx * 0.7, cy: H.cy + H.ry * 0.26, rx: calf ? 4.4 : 5, ry: calf ? 2.8 : 3.1 }));

  // 耳朵
  const earLen = calf ? 11 : 12.5, earW = calf ? 5.8 : 6.2;
  M.ears = [-1, 1].map((s) => {
    const ang = s < 0 ? Math.PI - 0.22 : 0.22;
    const bx = H.cx + s * H.rx * 0.8, by = H.cy - H.ry * 0.4;
    const cx = bx + Math.cos(ang) * earLen * 0.55, cy = by + Math.sin(ang) * earLen * 0.55;
    return {
      cx, cy, rx: earLen * 0.62, ry: earW * 0.72, rot: ang, side: s,
      pts: ellipsePts(cx, cy, earLen * 0.62, earW * 0.72, ang, 28),
      inner: ellipsePts(cx + Math.cos(ang) * 1.3, cy + Math.sin(ang) * 1.3, earLen * 0.4, earW * 0.38, ang, 24),
    };
  });

  // 角
  M.horns = [];
  if (g.horns !== 'none' && !calf) {
    for (const s of [-1, 1]) {
      if (g.horns === 'short') {
        const p0 = [H.cx + s * H.rx * 0.44, H.cy - H.ry * 0.82];
        const p2 = [p0[0] + s * 6.5, p0[1] - 9.5];
        const p1 = [p0[0] + s * 1, p0[1] - 6];
        M.horns.push({ side: s, p0, p1, p2, pts: taperPts(p0, p1, p2, 7.5, 2.6, 10), tipFrom: 0.62 });
      } else {
        const p0 = [H.cx + s * H.rx * 0.58, H.cy - H.ry * 0.74];
        const p1 = [p0[0] + s * 30, p0[1] + 3];
        const p2 = [p0[0] + s * 37, p0[1] - 19];
        M.horns.push({ side: s, p0, p1, p2, pts: taperPts(p0, p1, p2, 8.5, 2.4, 18), tipFrom: 0.72 });
      }
    }
  }

  // 瀏海（蓬鬆毛）：蓋住額頭，下緣幾撮毛剛好碰到眼睛上緣
  M.fringe = null;
  if (fluffy) {
    const R = H.rx + 2, top = [];
    const yb = H.cy - H.ry * 0.36;
    for (let i = 0; i <= 16; i++) {
      const a = Math.PI + 0.12 + (i / 16) * (Math.PI - 0.24);
      top.push([H.cx + Math.cos(a) * R, yb + 1 + Math.sin(a) * (H.ry * 0.72 + 2)]);
    }
    const tufts = 4, bottom = [];
    const xr = top[top.length - 1][0], xl = top[0][0];
    for (let i = 0; i < tufts; i++) {
      const xa = xr - ((xr - xl) * i) / tufts, xb = xr - ((xr - xl) * (i + 1)) / tufts;
      const mid = (xa + xb) / 2;
      const dip = (i === 1 || i === 2 ? H.ry * 0.3 : H.ry * 0.2) + (rnd() - 0.5) * 1.2;
      bottom.push([xa, yb + (i === 0 ? 0 : -1.2)], [mid + 1.2, yb + dip], [mid - 1.2, yb + dip - 0.6]);
    }
    M.fringe = { pts: [...top, ...bottom] };
  }

  // 腿
  const lw = calf ? 10.5 : stocky ? 15 : 13;
  const legTop = B.cy;
  const xs = calf ? [-14, -4, 16, 26] : stocky ? [-21, -8, 30, 43] : [-18, -6, 26, 38];
  M.legs = xs.map((x, i) => {
    const far = i === 1 || i === 2;
    const bottom = far ? -1.6 : 0;
    const h = bottom - legTop;
    return {
      x, w: lw, top: legTop, bottom, far, hoof: calf ? 4.2 : 5.2,
      pts: roundRectPts(x - lw / 2, legTop, lw, h, lw * 0.42, 6),
    };
  });

  // 尾巴
  const tb = [B.cx + B.rx * 0.9, B.cy - B.ry * 0.35];
  const tc = [tb[0] + 13, tb[1] + 4];
  const te = [tb[0] + 9, B.cy + B.ry * 0.62];
  M.tail = { p0: tb, p1: tc, p2: te, w: calf ? 2.6 : 3.2, tuft: { cx: te[0] + 0.5, cy: te[1] + 3, rx: calf ? 3.4 : 4.2, ry: calf ? 4.6 : 5.8 } };
  M.tail.tuft.pts = ellipsePts(M.tail.tuft.cx, M.tail.tuft.cy, M.tail.tuft.rx, M.tail.tuft.ry, 0.25, 24);
  if (fluffy) M.tail.tuft.pts = scallopPts(ellipsePts(M.tail.tuft.cx, M.tail.tuft.cy, M.tail.tuft.rx + 0.8, M.tail.tuft.ry + 0.8, 0.25, 8), 0.4, 5);

  M.udder = null;

  // 花紋
  M.pattern = { type: g.pattern, body: [], head: [], dots: [], seeds: [] };
  const insideBody = (x, y) => pointInPoly(bodyPts, x, y);
  const insideHead = (x, y) => pointInPoly(headPts, x, y);
  const nearFace = (x, y, pad = 2) =>
    pointInPoly(M.muzzle.pts, x, y) ||
    M.eyes.some((e) => ((x - e.cx) / (e.rx + pad)) ** 2 + ((y - e.cy) / (e.ry + pad)) ** 2 < 1);
  if (g.pattern === 'patches') {
    const zones = [-0.62, 0.02, 0.64];
    zones.forEach((z, i) => {
      const cx = B.cx + B.rx * (z + (rnd() - 0.5) * 0.22);
      const cy = B.cy + B.ry * (i === 1 ? -0.55 - rnd() * 0.35 : -0.15 + (rnd() - 0.5) * 0.9);
      const r = B.rx * (0.3 + rnd() * 0.14);
      M.pattern.body.push(densify(blobPts(cx, cy, r, rnd), 5));
    });
    if (rnd() < 0.7) {
      const cx = B.cx + B.rx * (rnd() - 0.5) * 1.2, cy = B.cy + B.ry * (0.55 + rnd() * 0.3);
      M.pattern.body.push(densify(blobPts(cx, cy, B.rx * 0.16, rnd, 7), 5));
    }
    const s = rnd() < 0.5 ? -1 : 1;
    M.pattern.head.push(densify(blobPts(H.cx + s * H.rx * 0.78, H.cy - H.ry * 0.78, H.rx * 0.44, rnd, 8, 0.3), 5));
    M.pattern.headSide = s;
  } else if (g.pattern === 'dots') {
    const tries = 400, placed = [];
    for (let t = 0; t < tries && placed.length < 13; t++) {
      const x = B.cx + (rnd() * 2 - 1) * B.rx, y = B.cy + (rnd() * 2 - 1) * B.ry;
      if (!insideBody(x, y)) continue;
      const r = 2.4 + rnd() * 1.6;
      if (placed.some((p) => Math.hypot(p.cx - x, p.cy - y) < p.r + r + 5)) continue;
      placed.push({ cx: x, cy: y, r, where: 'body' });
    }
    for (let t = 0; t < tries && placed.filter((p) => p.where === 'head').length < 3; t++) {
      const x = H.cx + (rnd() * 2 - 1) * H.rx, y = H.cy + (rnd() * 2 - 1) * H.ry;
      if (!insideHead(x, y) || nearFace(x, y, 3)) continue;
      const r = 2 + rnd() * 1.2;
      if (placed.some((p) => Math.hypot(p.cx - x, p.cy - y) < p.r + r + 5)) continue;
      placed.push({ cx: x, cy: y, r, where: 'head' });
    }
    M.pattern.dots = placed;
  } else if (g.pattern === 'strawberry') {
    const sp = calf ? 9 : 10.5;
    let row = 0;
    for (let y = B.cy - B.ry - 2; y < B.cy + B.ry + 2; y += sp * 0.86, row++) {
      for (let x = B.cx - B.rx - 2 + (row % 2) * sp * 0.5; x < B.cx + B.rx + 2; x += sp) {
        const jx = x + (rnd() - 0.5) * 2.2, jy = y + (rnd() - 0.5) * 2.2;
        if (insideBody(jx, jy)) M.pattern.seeds.push({ cx: jx, cy: jy, rot: (rnd() - 0.5) * 0.8, where: 'body' });
      }
    }
    row = 0;
    for (let y = H.cy - H.ry; y < H.cy + H.ry; y += sp * 0.86, row++) {
      for (let x = H.cx - H.rx + (row % 2) * sp * 0.5; x < H.cx + H.rx; x += sp) {
        const jx = x + (rnd() - 0.5) * 2, jy = y + (rnd() - 0.5) * 2;
        if (insideHead(jx, jy) && !nearFace(jx, jy, 3.5)) M.pattern.seeds.push({ cx: jx, cy: jy, rot: (rnd() - 0.5) * 0.8, where: 'head' });
      }
    }
  }

  // 特殊疊層
  M.overlay = null;
  const topY = H.cy - H.ry * (fluffy ? 1.08 : 0.98);
  if (g.overlay === 'berry') {
    // 草莓蒂頭：葉子往左右攤開、微微下垂，中間兩片較短（從側面看的星形）
    const c = [H.cx, topY + 2.5];
    const spec = [[Math.PI - 0.42, 11.5], [Math.PI - 0.02, 12.5], [Math.PI + 0.62, 7.5], [2 * Math.PI - 0.62, 7.5], [0.02, 12.5], [0.42, 11.5]];
    const leaves = spec.map(([a, len]) => {
      const tip = [c[0] + Math.cos(a) * len, c[1] + Math.sin(a) * len * 0.62];
      const mid = [(c[0] + tip[0]) / 2, (c[1] + tip[1]) / 2];
      const nx = -Math.sin(a), ny = Math.cos(a);
      const wd = len > 10 ? 3.3 : 2.8;
      return [c, [mid[0] + nx * wd, mid[1] + ny * wd], tip, [mid[0] - nx * wd, mid[1] - ny * wd]];
    });
    M.overlay = { type: 'berry', c, leaves, stem: [[c[0], c[1] - 2], [c[0] + 2, c[1] - 10]] };
  } else if (g.overlay === 'cream') {
    const c = [H.cx + 1, topY + 2];
    const tiers = [
      { cx: c[0], cy: c[1] - 1, rx: 11, ry: 5 },
      { cx: c[0] + 0.8, cy: c[1] - 6.2, rx: 8, ry: 4.4 },
      { cx: c[0] + 1.6, cy: c[1] - 10.6, rx: 5, ry: 3.8 },
    ];
    M.overlay = { type: 'cream', c, tiers, tip: [c[0] + 3.6, c[1] - 16] };
  }

  // 錨點與外框
  const all = [...bodyPts, ...headPts, ...M.muzzle.pts, ...M.ears.flatMap((e) => e.pts), ...M.horns.flatMap((h) => h.pts),
    ...M.tail.tuft.pts, ...M.legs.flatMap((l) => l.pts), ...(M.fringe ? M.fringe.pts : [])];
  if (M.overlay) all.push([H.cx - 12, topY - 18], [H.cx + 12, topY - 18]);
  const xs2 = all.map((p) => p[0]), ys2 = all.map((p) => p[1]);
  M.bbox = { x0: Math.min(...xs2), y0: Math.min(...ys2), x1: Math.max(...xs2), y1: Math.max(...ys2, 0) };
  M.headTop = [H.cx, Math.min(topY - (M.overlay ? 14 : 0), ...M.horns.map((h) => Math.min(...h.pts.map((p) => p[1]))), H.cy - H.ry)];
  M.shadow = { cx: B.cx - 2, rx: B.rx + 12, ry: calf ? 5 : 7 };
  const hx = [...headPts, ...M.ears.flatMap((e) => e.pts), ...M.horns.flatMap((h) => h.pts), ...M.muzzle.pts];
  M.headBox = {
    x0: Math.min(...hx.map((p) => p[0])), x1: Math.max(...hx.map((p) => p[0])),
    y0: Math.min(...hx.map((p) => p[1]), M.headTop[1]), y1: Math.max(...hx.map((p) => p[1])),
  };
  return M;
}

// 鏡像：renderer 用 transform 翻轉，這裡只提供 x 座標翻轉工具
export const flipX = (x, mirror) => (mirror ? -x : x);
