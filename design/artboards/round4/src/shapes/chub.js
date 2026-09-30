// R4 牛產生器：五種胖胖可愛的外型，畫法沿用 R1-A（3.2 單位可可色粗描邊、扁平粉彩，畫筆在 q.js）。
// 流程：基因（data.js）→ plan() 體型參數（用途、特徵、公母、小牛）→ 外型比例 → 幾何 → Q 版畫筆。
// 五種外型差在：頭朝哪邊、身體輪廓、頭身比例、腿長、眼睛畫法。
//   a 胖胖側面：麵包形身體，頭是側面、口鼻短短往前，豆豆眼
//   b 轉頭看你：麵包形身體，頭轉正面看玩家，圓亮眼，寬寬的奶油色口鼻
//   c 圓球糰子：幾乎是圓球的身體、腿很短，小側臉貼在身上，笑瞇瞇的彎眼
//   d 斜側四分之三：桶形身體、腿稍長，頭斜 45 度、看得到兩隻眼
//   e 軟方塊：像棉花糖的圓角方塊身體、腿短而方，頭也是圓角方塊、跟身體連成一體不畫分界線，側臉，杏仁眼加睫毛
// 所有外型都避開被否決的畫法：直立橢圓眼、粉紅大圓鼻（像豬）、兩頭身大頭、細長腿。
import {
  painter, paletteQ, leaf, blob, bbox, topYAt, udder as drawUdder, tail as drawTail, leg as drawLeg, collar as drawCollar,
  blush as drawBlush, horn as drawHorn, forelock as drawForelock, overlay as drawOverlay, fringe as drawFringe,
  eye as drawEye, muzzle as drawMuzzle, makePattern, paintPattern,
  superPts, scallopPts, densify, smoothPath, rng, shade, mix, INK,
} from './q.js';

export const VARIANTS = {
  a: { key: 'a', name: '胖胖側面', head: 'profile', n: 2.7, L: 84, D: 46, leg: 17, legW: 10.5, hr: 19.5, snout: 0.62, eye: 'dot', scene: 0.96 },
  b: { key: 'b', name: '轉頭看你', head: 'front', n: 2.7, L: 80, D: 45, leg: 15, legW: 11, hr: 19.5, eye: 'round', scene: 0.96 },
  c: { key: 'c', name: '圓球糰子', head: 'profile', n: 2.12, L: 72, D: 58, leg: 8.5, legW: 11.5, hr: 15.5, snout: 0.5, eye: 'smile', scene: 0.96, legIn: 0.06 },
  d: { key: 'd', name: '斜側四分之三', head: 'three', n: 2.4, L: 86, D: 45, leg: 20, legW: 10, hr: 21, eye: 'round', scene: 0.94 },
  e: { key: 'e', name: '軟方塊', head: 'merged', n: 4.2, hn: 3.4, L: 84, D: 46, leg: 13, legW: 12, hr: 20, snout: 0.5, eye: 'almond', scene: 0.96 },
};

// 用途的相對體型（三種都是胖身材）：乳用最高、腿最長、有乳房；肉用最寬、最深、腿最短
const BUILD = {
  dairy: { L: 0.98, D: 0.9, leg: 1.32, legW: 0.9, udder: 1.25, hip: 1, chest: 0, muscle: 0, head: 0.97 },
  dual: { L: 1.0, D: 1.0, leg: 1.0, legW: 1.0, udder: 0.85, hip: 0.4, chest: 0.25, muscle: 0.35, head: 1.0 },
  beef: { L: 1.07, D: 1.17, leg: 0.74, legW: 1.3, udder: 0.35, hip: 0, chest: 0.7, muscle: 1, head: 1.04 },
};

const bell = (u, c, w) => Math.exp(-(((u - c) / w) ** 2));

export function plan(g, V) {
  const b = BUILD[g.use] || BUILD.dual;
  const t = g.traits || {};
  const bull = g.sex === 'bull', calf = g.age === 'calf';
  const p = {
    use: g.use, bull, calf, size: 1,
    L: V.L * b.L, D: V.D * b.D, leg: V.leg * b.leg, legW: V.legW * b.legW, hr: V.hr * b.head,
    udder: b.udder, hip: b.hip, chest: b.chest, muscle: b.muscle, hump: 0, neckW: 1,
    fluffy: !!t.A && !g.legendFluff, lightFluff: !!g.legendFluff, eyeBig: !!t.B, shortFace: !!t.B, gloss: !!t.C, marble: !!t.C && g.use === 'beef',
  };
  if (t.A && !g.legendFluff) { p.L *= 1.05; p.D *= 1.05; p.leg *= 0.8; } // 長毛：毛蓋住上半截腿，看起來更低、更寬
  if (t.B) { p.size *= 0.9; p.hr *= 1.03; } // 淡色：骨架小一號、臉短、眼大
  if (t.C) p.muscle += 0.4; // 光澤：肌肉多一點
  if (bull) { p.size *= 1.1; p.hump = 1; p.neckW = 1.3; p.hr *= 1.04; p.udder = 0; }
  if (calf) {
    // 小牛：約成牛 55–60% 高、身體短而圓、腿有肉、頭稍大但不大過身體
    p.size *= 0.6; p.L *= 0.8; p.D *= 1.0; p.leg *= 0.95; p.legW *= 1.15; p.hr *= 1.14;
    p.udder = 0; p.hip = 0; p.hump = 0; p.muscle *= 0.3; p.eyeBig = true;
  }
  return p;
}

// ---------- 身體 ----------
function body(V, p) {
  const { L, D } = p;
  const cx = 0, cy = -p.leg - D / 2, rx = L / 2, ry = D / 2;
  const mod = ([x, y]) => {
    const u = (x - cx) / rx, v = (y - cy) / ry;
    let dx = 0, dy = 0;
    if (v < 0) {
      dy -= p.hump * D * 0.14 * bell(u, -0.46, 0.2) * -v; // 公牛肩峰
      dy -= p.hip * D * 0.05 * bell(u, 0.6, 0.14) * -v; // 乳用腰角
      dy += D * 0.02 * bell(u, 0.1, 0.3) * -v; // 背微凹
    } else {
      dy += D * 0.06 * bell(u, 0.05, 0.45) * v; // 圓肚子
      dy += p.chest * D * 0.05 * bell(u, -0.6, 0.2) * v; // 胸深
    }
    if (u > 0.55) dx += p.muscle * D * 0.035 * bell(v, -0.1, 0.5);
    if (u < -0.55) dx -= p.chest * D * 0.03 * bell(v, 0.2, 0.5);
    return [x + dx, y + dy];
  };
  let pts;
  if (p.fluffy) pts = scallopPts(superPts(cx, cy, rx, ry, V.n, 20).map(mod), 0.28, 6);
  else pts = superPts(cx, cy, rx, ry, V.n, 72).map(mod);
  return { pts, cx, cy, rx, ry, L, D, topY: cy - ry, bellyY: cy + ry, xF: cx - rx, xR: cx + rx };
}

function legs(V, p, B) {
  const inset = V.legIn || 0;
  const top = B.bellyY - B.D * 0.3;
  const w = p.legW;
  const hoof = Math.min(w * 0.55, p.leg * 0.42 + 2);
  const mk = (x, far) => {
    const b = far ? -1.6 : 0;
    const sq = V.key === 'e'; // 軟方塊：腿也方方的
    const w0 = w * 0.55, w1 = w * (sq ? 0.56 : 0.5);
    const pts = [[x - w0, top], [x + w0, top], [x + w1, b - w1 * (sq ? 0.2 : 0.4)], [x + w1 * (sq ? 0.97 : 0.9), b], [x - w1 * (sq ? 0.97 : 0.9), b], [x - w1, b - w1 * (sq ? 0.2 : 0.4)]];
    return { x, far, bottom: b, hoof, pts };
  };
  const { xF, xR, L } = B;
  return [mk(xF + L * (0.31 + inset), true), mk(xR - L * (0.29 + inset), true), mk(xF + L * (0.2 + inset), false), mk(xR - L * (0.17 + inset), false)];
}

function bodySpots(g, B, r) {
  const J = () => r() - 0.5;
  const { cx, cy, rx, ry, D } = B;
  if (g.pattern !== 'patches' && g.pattern !== 'strawberry') return [];
  const k = g.pattern === 'strawberry' ? 0.85 : 1;
  return [
    { cx: cx - rx * (0.18 + 0.08 * J()), cy: cy - ry * (0.38 + 0.1 * J()), r: D * 0.4 * k },
    { cx: cx + rx * (0.5 + 0.06 * J()), cy: cy - ry * (0.15 + 0.12 * J()), r: D * 0.42 * k },
    { cx: cx + rx * (0.08 + 0.08 * J()), cy: cy + ry * (0.55 + 0.1 * J()), r: D * 0.28 * k },
  ];
}

function marbling(P, B, color) {
  // 和牛的霜降：肩頸幾條淡色細紋
  const { cx, cy, rx, ry } = B;
  const lines = [[-0.72, -0.35], [-0.6, -0.05], [-0.45, 0.25], [-0.3, -0.42], [-0.15, -0.12]];
  lines.forEach(([u, v], i) => {
    const x = cx + u * rx, y = cy + v * ry, w = rx * 0.2;
    P.arc([[x - w, y], [x - w * 0.4, y - 2.2], [x + w * 0.2, y + 1.2], [x + w * 0.8, y - 1.6]], color, 1.2, 0.85 - i * 0.05);
  });
}

// ---------- 眼睛 ----------
function eyes(P, C, p, list, style) {
  list.forEach((e) => {
    const r = e.r * (p.eyeBig ? 1.2 : 1);
    if (e.rim) P.ellipse(e.cx, e.cy, r * 1.45 * (e.sx || 1), r * 1.4, shade(C.coat, -0.3), { opacity: 0.55 });
    if (style === 'dot') drawEye(P, C, { cx: e.cx, cy: e.cy, rx: r * (e.sx || 1), ry: r * 1.02 }, 'dot');
    else if (style === 'round') drawEye(P, C, { cx: e.cx, cy: e.cy, rx: r * (e.sx || 1), ry: r }, p.eyeBig ? 'big' : 'normal');
    else if (style === 'smile') {
      // 笑瞇瞇：向上彎的弧線；大眼的品種弧線長一點、加一根睫毛
      const w = r * 1.25;
      P.arc([[e.cx - w, e.cy + r * 0.35], [e.cx, e.cy - r * 0.55], [e.cx + w, e.cy + r * 0.35]], C.eye, Math.max(1.8, r * 0.52));
      if (p.eyeBig) P.arc([[e.cx + w * 0.9, e.cy + r * 0.05], [e.cx + w * 1.4, e.cy - r * 0.35]], C.eye, Math.max(1.2, r * 0.3));
    } else if (style === 'almond') {
      // 杏仁眼：上緣弧度大、下緣平；一個反光；母牛與大眼的品種後眼角兩根睫毛
      const a = r * 1.25, bb = r * 0.95;
      const inner = [e.cx - a, e.cy + bb * 0.1], outer = [e.cx + a, e.cy - bb * 0.05];
      P.raw(`<path d="M${inner[0]},${inner[1]} Q${e.cx},${e.cy - bb * 1.9} ${outer[0]},${outer[1]} Q${e.cx},${e.cy + bb * 1.25} ${inner[0]},${inner[1]}Z" fill="${C.eye}"/>`);
      P.ellipse(e.cx + P.lx * a * 0.2, e.cy - bb * 0.35, bb * 0.42, bb * 0.42, '#FFFFFF');
      P.raw(`<path d="M${inner[0]},${inner[1]} Q${e.cx},${e.cy - bb * 1.9} ${outer[0]},${outer[1]}" fill="none" stroke="${INK}" stroke-width="${Math.max(1.3, bb * 0.36)}" stroke-linecap="round"/>`);
      if (!p.bull) P.raw(`<path d="M${outer[0] - 0.5},${outer[1] - bb * 0.2} l${bb * 0.95},${-bb * 0.5} M${outer[0] - a * 0.35},${e.cy - bb * 0.8} l${bb * 0.6},${-bb * 0.8}" stroke="${INK}" stroke-width="${Math.max(1.1, bb * 0.28)}" stroke-linecap="round" fill="none"/>`);
    }
  });
}

// ---------- 角 ----------
function hornSpec(g, p, base, side, hr, dir = -1) {
  // dir：-1 往畫面左前（近側）、+1 往右後（遠側）；side 只影響長角的方向
  if (g.horns === 'none') return null;
  const k = p.bull ? 1.35 : 1;
  if (g.horns === 'bud') return { type: 'bud', base: [base[0], base[1] + 1], r: hr * 0.15 };
  if (g.horns === 'short') return { p0: [base[0], base[1] + 2], p1: [base[0] + dir * hr * 0.05, base[1] - hr * 0.3 * k], p2: [base[0] + dir * hr * 0.3 * k, base[1] - hr * 0.46 * k], w0: hr * 0.3 * k, w1: hr * 0.1 };
  return { p0: [base[0] - dir * hr * 0.1, base[1] + hr * 0.12], p1: [base[0] + dir * hr * 1.0 * k, base[1] + hr * 0.05], p2: [base[0] + dir * hr * 1.3 * k, base[1] - hr * 0.62 * k], w0: hr * 0.34, w1: hr * 0.09, tipFrom: 0.7 };
}
function hornTop(g, p, top, hr) {
  const k = p.bull ? 1.35 : 1;
  if (g.horns === 'long') return top - hr * 0.62 * k;
  if (g.horns === 'short') return top - hr * 0.48 * k;
  if (g.horns === 'bud') return top - hr * 0.15;
  return top;
}

// ---------- 頭：側面（a、c、e） ----------
function profileHead(V, g, p, B) {
  const hr = p.hr;
  const pos = { a: [0.25, 0.1], c: [0.8, 0.26], e: [0.05, 0.14] }[V.key];
  const H = { x: B.xF + hr * pos[0], y: B.topY + B.D * pos[1] + (p.bull ? B.D * 0.08 : 0) + (p.calf ? B.D * 0.02 : 0) };
  const sn = V.snout * (p.shortFace ? 0.78 : 1);
  const rx = hr * (1 + sn * 0.42), ry = hr * 0.9;
  const cx = H.x - hr * sn * 0.36, cy = H.y;
  const droopAt = (x) => { const u = (x - cx) / rx; return u < 0 ? Math.pow(-u, 1.5) * hr * 0.16 : 0; };
  const pts = superPts(cx, cy, rx, ry, V.hn || 2.35, 64).map(([x, y]) => [x, y + droopAt(x) * (V.hn ? 0.4 : 1)]);
  const top = topYAt(pts, cx + rx * 0.2);
  return {
    type: 'profile', pts, cx, cy, rx, ry, hr, droopAt, top,
    eye: { cx: cx + rx * 0.06, cy: cy - ry * 0.2, r: hr * (V.key === 'c' ? 0.16 : 0.15) },
    muzzle: { cx: cx - rx * 0.66, cy: cy + ry * 0.26 + droopAt(cx - rx * 0.66), rx: rx * 0.5, ry: ry * 0.66 },
    nearEar: { base: [cx + rx * 0.6, cy - ry * 0.36], ang: 0.3, len: hr * 0.8, wid: hr * 0.44 },
    farEar: { base: [cx + rx * 0.52, cy - ry * 0.55], ang: -0.14, len: hr * 0.66, wid: hr * 0.38 },
    hornNear: [cx + rx * 0.22, topYAt(pts, cx + rx * 0.22) + 1],
    hornFar: [cx + rx * 0.48, topYAt(pts, cx + rx * 0.48) + 1],
    collar: { strap: [[cx - rx * 0.05, cy + ry * 0.72], [cx + rx * 0.3, cy + ry * 1.04], [cx + rx * 0.68, cy + ry * 0.62]], bell: [cx + rx * 0.3, cy + ry * 1.04 + 6] },
    face: { cx: cx - rx * 0.1, cy: cy + ry * 0.05, r: rx * 1.05 },
  };
}
function drawProfileFace(P, C, g, p, V, h, r) {
  const m = h.muzzle;
  // 口鼻：奶油色，蓋住圓圓的鼻頭；分界線在內側
  P.ellipse(m.cx - m.rx * 0.2, m.cy, m.rx * 1.3, m.ry, C.muzzle);
  P.arc([[m.cx + m.rx * 0.7, m.cy - m.ry * 0.9], [m.cx + m.rx * 1.08, m.cy - m.ry * 0.05], [m.cx + m.rx * 0.78, m.cy + m.ry * 0.85]], INK, 1.8, 0.8);
}
function profileFaceTop(P, C, g, p, V, h, r) {
  const m = h.muzzle;
  P.ellipse(m.cx - m.rx * 0.36, m.cy - m.ry * 0.32, h.hr * 0.085, h.hr * 0.055, C.nostril, { rot: -0.8 });
  P.arc([[m.cx - m.rx * 0.55, m.cy + m.ry * 0.5], [m.cx - m.rx * 0.1, m.cy + m.ry * 0.62], [m.cx + m.rx * 0.3, m.cy + m.ry * 0.5]], C.mouth, 1.5, 1);
  drawBlush(P, C, { cx: h.cx - h.rx * 0.18, cy: h.cy + h.ry * 0.3, rx: h.hr * 0.16, ry: h.hr * 0.09 });
}

// ---------- 頭：正面（b） ----------
function frontHead(V, g, p, B) {
  const hr = p.hr;
  const H = { x: B.xF + hr * 0.42, y: B.topY + B.D * 0.06 + (p.bull ? B.D * 0.06 : 0) };
  const rx = hr * 1.12, ry = hr * 0.94 * (p.shortFace ? 0.93 : 1);
  const pts = superPts(H.x, H.y, rx, ry, 2.3, 64).map(([x, y]) => { const v = (y - H.y) / ry; return [H.x + (x - H.x) * (1 - 0.07 * Math.max(0, v)), y]; });
  const top = H.y - ry;
  return {
    type: 'front', pts, cx: H.x, cy: H.y, rx, ry, hr, top,
    ears: [-1, 1].map((s) => ({ base: [H.x + s * rx * 0.9, H.y - ry * 0.3], ang: s < 0 ? Math.PI - 0.32 : 0.32, len: hr * 0.72, wid: hr * 0.42 })),
    horns: [-1, 1].map((s) => [H.x + s * rx * 0.42, topYAt(pts, H.x + s * rx * 0.42) + 1]),
    collar: { strap: [[H.x - rx * 0.6, H.y + ry * 0.8], [H.x, H.y + ry * 1.08], [H.x + rx * 0.6, H.y + ry * 0.8]], bell: [H.x, H.y + ry + 9] },
    face: { cx: H.x, cy: H.y + ry * 0.05, r: rx * 1.08 },
  };
}

// ---------- 頭：斜側四分之三（d） ----------
function threeHead(V, g, p, B) {
  const hr = p.hr;
  const H = { x: B.xF + hr * 0.12, y: B.topY + B.D * 0.1 + (p.bull ? B.D * 0.07 : 0) };
  const rx = hr * 1.0, ry = hr * 0.95 * (p.shortFace ? 0.94 : 1);
  const pts = superPts(H.x, H.y, rx, ry, 2.25, 64).map(([x, y]) => {
    const u = (x - H.x) / rx, v = (y - H.y) / ry;
    const k = 1 + 0.3 * Math.max(0, -u) * Math.min(1, Math.max(0, (v + 0.25) / 0.8)) * (p.shortFace ? 0.75 : 1);
    return [H.x + (x - H.x) * k, H.y + (y - H.y) * (1 + 0.1 * Math.max(0, -u) * Math.max(0, v))];
  });
  const top = H.y - ry;
  return {
    type: 'three', pts, cx: H.x, cy: H.y, rx, ry, hr, top,
    eyes: [{ cx: H.x + rx * 0.22, cy: H.y - ry * 0.12, r: hr * 0.155 }, { cx: H.x - rx * 0.4, cy: H.y - ry * 0.16, r: hr * 0.14, sx: 0.84 }],
    muzzle: { cx: H.x - rx * 0.5, cy: H.y + ry * 0.52, rx: rx * 0.64, ry: ry * 0.44 },
    nearEar: { base: [H.x + rx * 0.86, H.y - ry * 0.32], ang: 0.3, len: hr * 0.8, wid: hr * 0.44 },
    farEar: { base: [H.x - rx * 0.66, H.y - ry * 0.62], ang: Math.PI + 0.62, len: hr * 0.56, wid: hr * 0.36 },
    hornNear: [H.x + rx * 0.3, topYAt(pts, H.x + rx * 0.3) + 1],
    hornFar: [H.x - rx * 0.3, topYAt(pts, H.x - rx * 0.3) + 1],
    collar: { strap: [[H.x - rx * 0.1, H.y + ry * 0.86], [H.x + rx * 0.3, H.y + ry * 1.1], [H.x + rx * 0.72, H.y + ry * 0.7]], bell: [H.x + rx * 0.3, H.y + ry * 1.1 + 6] },
    face: { cx: H.x - rx * 0.05, cy: H.y + ry * 0.08, r: rx * 1.15 },
  };
}

// 頭上的花紋（荷斯坦的黑斑、草莓牛的紅斑）
function headPatch(P, C, g, h, r) {
  if (g.pattern !== 'patches' && g.pattern !== 'strawberry') return;
  const at = h.type === 'front' ? [h.cx + h.rx * 0.52, h.cy - h.ry * 0.55] : h.type === 'three' ? [h.cx + h.rx * 0.55, h.cy - h.ry * 0.4] : [h.cx + h.rx * 0.55, h.cy - h.ry * 0.3];
  const pat = makePattern(g, r, [{ cx: at[0], cy: at[1], r: h.hr * 0.46 }], h.pts);
  paintPattern(P, C, pat);
}

function headFringe(P, C, g, p, h, r) {
  if (!(p.fluffy || p.lightFluff)) return false;
  const fc = p.lightFluff ? { ...C, fringe: shade(C.coat, -0.04) } : C;
  if (h.type === 'front') { drawFringe(P, fc, h.cx, h.top - 2, h.cy - h.ry * 0.12, h.rx * (p.lightFluff ? 0.7 : 0.98), r); return true; }
  const ex = h.type === 'three' ? h.eyes[0] : h.eye;
  const t = h.top, hr = h.hr, x0 = h.type === 'three' ? h.cx : h.cx + h.rx * 0.1;
  const w = p.lightFluff ? 0.7 : 1;
  const pts = [[x0 + hr * 0.6 * w, t + hr * 0.12], [x0 + hr * 0.1, t - hr * 0.14], [x0 - hr * 0.5 * w, t + hr * 0.04], [x0 - hr * 0.72 * w, t + hr * 0.42],
    [x0 - hr * 0.5 * w, ex.cy - hr * 0.02], [x0 - hr * 0.34 * w, ex.cy - hr * 0.16], [x0 - hr * 0.18, ex.cy - hr * 0.04], [x0, ex.cy - hr * 0.2], [x0 + hr * 0.22, ex.cy - hr * 0.08], [x0 + hr * 0.42 * w, t + hr * 0.5]];
  P.shape(pts, fc.fringe, { w: 0.9 });
  P.arc([[x0 - hr * 0.2, t + hr * 0.12], [x0 + hr * 0.25, t + hr * 0.02]], '#FFFFFF', 2.2, 0.6);
  return true;
}

// ---------- 組裝 ----------
export function renderCow(vkey, g, { x = 0, y = 0, scale = 1, facing = 'left', id = 'cow', sil = false } = {}) {
  const V = VARIANTS[vkey];
  const p = plan(g, V);
  const B = body(V, p);
  const LG = legs(V, p, B);
  const C = paletteQ(g);
  const faceFill = g.faceColor || C.coat;
  const mirror = facing === 'right';
  const P = painter({ id, mirror, lw: 3.2 });
  const r = rng(g.seed + 505);
  const s = scale * p.size;
  const h = V.head === 'front' ? frontHead(V, g, p, B) : V.head === 'three' ? threeHead(V, g, p, B) : profileHead(V, g, p, B);

  // 尾巴
  const tailEnd = Math.min(B.bellyY + p.leg * 0.25, B.topY + Math.min(B.D * 1.08, 52));
  const tail = { p0: [B.xR - B.L * 0.04, B.topY + B.D * 0.14], p1: [B.xR + B.D * 0.3, B.topY + (tailEnd - B.topY) * 0.45], p2: [B.xR + B.D * 0.14, tailEnd] };
  drawTail(P, C, { ...tail, w: Math.max(2.2, p.legW * 0.26), tuftR: Math.max(3.4, B.D * 0.1) * (p.fluffy || p.lightFluff ? 1.4 : 1), color: C.coat });
  // 遠側的腿、乳房、近側的腿
  LG.filter((l) => l.far).forEach((l) => drawLeg(P, C, { ...l, fill: C.far }));
  if (p.udder > 0) {
    const u = p.udder, ux = B.xR - B.L * 0.3;
    drawUdder(P, C, { cx: ux, cy: B.bellyY + 1 + 2.4 * u, rx: 6.2 * u, ry: 4.6 * u, teats: [ux - 2.6 * u, ux + 2.8 * u] });
  }
  LG.filter((l) => !l.far).forEach((l) => drawLeg(P, C, { ...l, fill: C.coat }));

  // 身體（e：頭和身體合成一個花生形，只描外框）
  const pat = makePattern(g, r, bodySpots(g, B, r), B.pts);
  const bodyInside = () => {
    paintPattern(P, C, pat);
    if (p.marble) marbling(P, B, g.marbleColor || '#C9A7A0');
    P.ellipse(B.cx + 4, B.bellyY + B.D * 0.08, B.L * 0.6, B.D * 0.34, INK, { opacity: 0.1 });
    const lx = P.lx, hx = B.cx + lx * B.L * 0.05;
    P.arc([[hx, B.topY + B.D * 0.2], [hx + lx * B.L * 0.17, B.topY + B.D * 0.1], [hx + lx * B.L * 0.3, B.topY + B.D * 0.18]], '#FFFFFF', 3.4, C.dark ? (p.gloss ? 0.5 : 0.3) : 0.75);
    if (p.gloss) P.arc([[B.cx - lx * B.L * 0.3, B.topY + B.D * 0.3], [B.cx - lx * B.L * 0.4, B.topY + B.D * 0.45]], '#FFFFFF', 2.6, C.dark ? 0.45 : 0.7);
  };
  const merged = V.head === 'merged';
  if (merged) {
    const f = (v) => Math.round(v * 100) / 100;
    P.raw(`<path d="${smoothPath(B.pts)}" fill="${C.coat}" stroke="${INK}" stroke-width="${f(P.lw * 2)}" stroke-linejoin="round"/>`);
    P.raw(`<path d="${smoothPath(h.pts)}" fill="${faceFill}" stroke="${INK}" stroke-width="${f(P.lw * 2)}" stroke-linejoin="round"/>`);
    const cb = P.clip(B.pts);
    P.raw(`<path d="${smoothPath(B.pts)}" fill="${C.coat}"/><g clip-path="${cb}">`);
    bodyInside();
    P.raw('</g>');
  } else {
    P.region(B.pts, C.coat, bodyInside);
  }

  // 項圈＋牛鈴
  const cs = p.calf ? 0.85 : 1;
  drawCollar(P, C, h.collar.strap, h.collar.bell, 1.05 * cs);

  // 遠側的耳朵與角（在頭後面）
  const earBehind = (e) => P.shape(leaf(e.base, e.ang, e.len, e.wid, { round: 0.62 }), shade(C.ear, -0.1), { w: 0.85 });
  const earFront = (e) => {
    P.shape(leaf(e.base, e.ang, e.len, e.wid, { round: 0.6 }), C.ear, { w: 0.9 });
    P.shape(leaf([e.base[0] + Math.cos(e.ang) * e.len * 0.2, e.base[1] + Math.sin(e.ang) * e.len * 0.2], e.ang, e.len * 0.62, e.wid * 0.46, { round: 0.6 }), C.earIn, { line: false });
  };
  const farC = { ...C, horn: shade(C.horn, -0.08) };
  if (h.type === 'front') {
    h.ears.forEach(earFront);
    h.horns.forEach((b, i) => { const hs = hornSpec(g, p, b, i ? 1 : -1, h.hr, i ? 1 : -1); if (hs) drawHorn(P, C, hs); });
  } else {
    earBehind(h.farEar);
    const hf = hornSpec(g, p, h.hornFar, 1, h.hr * 0.9, 1);
    if (hf) drawHorn(P, farC, hf);
  }

  // 頭
  if (merged) {
    const ch = P.clip(h.pts);
    P.raw(`<path d="${smoothPath(h.pts)}" fill="${faceFill}"/><g clip-path="${ch}">`);
    headPatch(P, C, g, h, r);
    drawProfileFace(P, C, g, p, V, h, r);
    P.raw('</g>');
  } else {
    P.region(h.pts, faceFill, () => {
      headPatch(P, C, g, h, r);
      if (h.type === 'profile') drawProfileFace(P, C, g, p, V, h, r);
      if (h.type === 'three') {
        const m = h.muzzle;
        P.ellipse(m.cx, m.cy, m.rx, m.ry, C.muzzle, { rot: -0.28 });
      }
    });
  }
  const lx = P.lx;
  P.arc([[h.cx + lx * h.rx * 0.28, h.top + h.ry * 0.16], [h.cx + lx * h.rx * 0.6, h.top + h.ry * 0.34]], '#FFFFFF', 2.8, C.dark ? 0.35 : 0.8);

  // 臉
  if (h.type === 'front') {
    const er = h.hr * 0.15;
    eyes(P, C, p, [-1, 1].map((sd) => ({ cx: h.cx + sd * h.rx * 0.4, cy: h.cy - h.ry * 0.06, r: er, rim: g.eyeRim })), 'round');
    [-1, 1].forEach((sd) => drawBlush(P, C, { cx: h.cx + sd * h.rx * 0.66, cy: h.cy + h.ry * 0.22, rx: h.hr * 0.16, ry: h.hr * 0.09 }));
    drawMuzzle(P, C, { cx: h.cx, cy: h.cy + h.ry * 0.5, rx: h.rx * 0.54, ry: h.ry * 0.3, n: 2.5 });
  } else if (h.type === 'three') {
    const m = h.muzzle;
    P.ellipse(m.cx + m.rx * 0.28, m.cy - m.ry * 0.3, h.hr * 0.085, h.hr * 0.055, C.nostril, { rot: -0.5 });
    P.ellipse(m.cx - m.rx * 0.48, m.cy - m.ry * 0.36, h.hr * 0.065, h.hr * 0.045, C.nostril, { rot: -1.0 });
    P.arc([[m.cx - m.rx * 0.35, m.cy + m.ry * 0.42], [m.cx, m.cy + m.ry * 0.55], [m.cx + m.rx * 0.35, m.cy + m.ry * 0.38]], C.mouth, 1.5, 1);
    eyes(P, C, p, h.eyes.map((e) => ({ ...e, rim: g.eyeRim })), 'round');
    drawBlush(P, C, { cx: h.cx + h.rx * 0.32, cy: h.cy + h.ry * 0.3, rx: h.hr * 0.16, ry: h.hr * 0.09 });
  } else {
    profileFaceTop(P, C, g, p, V, h, r);
    eyes(P, C, p, [{ ...h.eye, rim: g.eyeRim }], V.eye);
  }
  // 近側耳朵與角
  if (h.type !== 'front') {
    earFront(h.nearEar);
    const hn = hornSpec(g, p, h.hornNear, -1, h.hr, -1);
    if (hn) drawHorn(P, C, hn);
  }
  // 瀏海或一小撮毛、特殊疊層
  if (!headFringe(P, C, g, p, h, r) && g.horns !== 'long') {
    const fx = h.type === 'front' ? h.cx : h.cx + h.rx * 0.12;
    drawForelock(P, C, fx, topYAt(h.pts, fx) + h.hr * 0.06, h.hr * 0.24);
  }
  drawOverlay(P, C, g, h.type === 'front' ? h.cx : h.cx + h.rx * 0.1, h.top, h.hr / 24);

  let svg = P.svg({ x, y, scale: s });
  if (sil) svg = `<g filter="url(#sil)">${svg}</g>`;
  const toScreen = (pt) => [x + (mirror ? -1 : 1) * pt[0] * s, y + pt[1] * s];
  const ht = Math.min(hornTop(g, p, h.top, h.hr), g.overlay !== 'none' ? h.top - (14 * h.hr) / 24 : Infinity);
  const bb = bbox([B.pts, h.pts, ...LG.map((l) => l.pts)]);
  const hornX = g.horns === 'long' ? h.hr * 1.4 * (p.bull ? 1.35 : 1) : 0;
  const fc = toScreen([h.face.cx, h.face.cy]);
  return {
    svg, p, B,
    face: { cx: fc[0], cy: fc[1], r: h.face.r * s },
    headTop: toScreen([h.cx, ht]),
    shadow: { cx: toScreen([B.cx, 0])[0], rx: (B.L * 0.6) * s, ry: Math.max(4, B.D * 0.14) * s },
    bbox: { x0: Math.min(bb.x0, h.cx - hornX) - 2, x1: Math.max(bb.x1, B.xR + B.D * 0.38), y0: ht - 3, y1: 0 },
    height: -ht * s,
    scale: s,
  };
}

// 剪影濾鏡（塗黑）：整頭牛的 alpha 直接變成深色
export const SIL_DEFS = `<filter id="sil" x="-10%" y="-10%" width="120%" height="120%"><feFlood flood-color="#2A1E1A"/><feComposite in2="SourceAlpha" operator="in"/></filter>`;
