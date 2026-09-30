// R2 牛產生器：基因 → plan.js 體型參數 → 版本比例 → 幾何 → Q 版畫筆（沿用 R1-A 的粗描邊、扁平粉彩）。
// 三個版本共用身體幾何（所以品種體型差異在每個版本都保留），差在比例、頭的畫法與眼睛：
//   a 大頭寶寶：正面大頭、兩頭身，大圓亮面眼＋兩個反光
//   b 繪本自然：接近真牛比例、有脖子，正面稍側的臉，杏仁眼＋一個反光，母牛短睫毛
//   c 側面輪廓：頭也是側面、口鼻往前伸，豆豆眼＋小反光
import { plan } from '../plan.js';
import {
  painter, paletteQ, leaf, blob, bbox, udder as drawUdder, tail as drawTail, leg as drawLeg, collar as drawCollar,
  blush as drawBlush, paintPattern, horn as drawHorn, forelock as drawForelock, overlay as drawOverlay,
  superPts, scallopPts, ellipsePts, smoothPath, polyPath, pointInPoly, rng, shade, mix, lum, densify, INK,
} from './q.js';

// 各版本在 plan 之上的比例
export const VERSIONS = {
  a: { key: 'a', name: '大頭寶寶', L: 0.8, D: 0.92, legLen: 0.46, legW: 1.3, neckLen: 0, head: 1.62, scene: 0.95 },
  b: { key: 'b', name: '繪本自然', L: 1.0, D: 1.0, legLen: 1.0, legW: 1.0, neckLen: 1.0, head: 1.38, scene: 0.84 },
  c: { key: 'c', name: '側面輪廓', L: 0.92, D: 1.0, legLen: 0.8, legW: 1.12, neckLen: 0.7, head: 1.32, scene: 0.88 },
};

const lerp = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];

// ---------- 身體幾何 ----------
export function geometry(vkey, g) {
  const V = VERSIONS[vkey];
  const p0 = plan(g);
  // A 是 Q 版比例，品種差異容易被大頭蓋掉，所以把體型倍率再誇大一點（倍率的 1.7 次方）
  const amp = (k) => (vkey === 'a' ? Math.pow(p0.f[k], 0.7) : 1);
  const p = { ...p0, L: p0.L * V.L * amp('L'), D: p0.D * V.D * amp('D'), legLen: p0.legLen * V.legLen * amp('legLen'), legW: p0.legW * V.legW * amp('legW'), neckLen: p0.neckLen * V.neckLen };
  const hr = 14 * p0.head * V.head; // 頭的基準半徑
  const { L, D } = p;
  const LL = p.legLen;
  const bellyY = -LL, topY = bellyY - D, xF = -L / 2, xR = L / 2;
  const mus = p.muscle, hip = p.hip;
  const G = { v: vkey, p, hr, L, D, LL, bellyY, topY, xF, xR };

  // 頭的位置
  if (vkey === 'a') {
    G.head = { x: xF - hr * 0.05, y: topY + D * 0.42 - hr * 0.86 };
  } else {
    const drop = p.build === 'beef' ? 0.3 : p.build === 'dairy' ? -0.02 : p.build === 'low' ? 0.22 : 0.1;
    const hx = xF - p.neckLen - (vkey === 'c' ? hr * 0.1 : hr * 0.55);
    G.head = { x: hx, y: topY + D * drop - (p.calf ? D * 0.2 : 0) };
  }
  const H = G.head;

  // 身體輪廓（面向左、順時針）
  const withers = [xF + L * 0.16, topY];
  const pts = [
    withers,
    [xF + L * 0.42, topY + D * (0.02 + 0.07 * p.dip)],
    [xR - L * 0.2, topY - D * 0.07 * hip],
    [xR - L * 0.05, topY + D * (0.03 - 0.03 * hip)],
    [xR + D * (0.02 + 0.07 * mus) - D * 0.03 * hip, topY + D * 0.3],
    [xR + D * (0.05 * mus) - D * 0.03, topY + D * 0.64],
    [xR - L * 0.12, bellyY - D * 0.02],
    [xR - L * 0.42, bellyY + D * 0.14 * p.belly],
    [xF + L * 0.18, bellyY + D * (0.03 + 0.2 * p.chest)],
    [xF - D * (0.03 + 0.05 * mus), topY + D * 0.6],
  ];
  if (vkey === 'a') {
    pts.push([xF - D * 0.02, topY + D * 0.22]);
  } else {
    // 脖子：底線（喉嚨、垂皮）與頂線（鬐甲往前到頭後）
    const nw = p.neckW;
    const endTop = [H.x + hr * 0.5, H.y - hr * (vkey === 'c' ? 0.55 : 0.5)];
    const endBot = [H.x + hr * (vkey === 'c' ? 0.45 : 0.3), H.y + hr * 0.7];
    const chestF = pts[pts.length - 1];
    const throat = lerp(chestF, endBot, 0.5);
    throat[1] += D * 0.07 * (nw - 0.8) + 1;
    const crest = lerp(endTop, [xF + L * 0.06, topY - D * 0.02], 0.5);
    crest[1] -= D * 0.1 * Math.max(0, nw - 1) + D * 0.02;
    pts.push(throat, endBot, endTop, crest);
    G.neck = { endTop, endBot, throat, crest };
  }
  let bodyPts = densify(pts, 6);
  if (p.fluffy) {
    const coarse = densify(pts, 2);
    bodyPts = scallopPts(coarse, 0.26, 6);
  }
  G.body = bodyPts;

  // 腿
  const lw = p.legW;
  const legTop = bellyY - D * 0.35;
  const hoofH = Math.min(lw * 0.62, LL * 0.3);
  const mkFront = (x, far) => {
    const b = far ? -1.6 : 0;
    const w0 = lw * 0.56, w1 = lw * 0.44, w2 = lw * 0.4, wh = lw * 0.47;
    const pts2 = [[x - w0, legTop], [x + w0, legTop], [x + w1, b - LL * 0.45], [x + w2, b - hoofH - 0.5], [x + wh, b], [x - wh, b], [x - w2, b - hoofH - 0.5], [x - w1, b - LL * 0.45]];
    return { x, far, bottom: b, hoof: hoofH, pts: pts2 };
  };
  const mkHind = (x, far) => {
    const b = far ? -1.6 : 0;
    const bend = vkey === 'b' ? lw * 0.35 : 0;
    const top = topY + D * 0.5;
    const pts2 = [[x - lw * 0.95, top], [x + lw * 0.85, top], [x + lw * 0.62 + bend, b - LL * 0.48], [x + lw * 0.4, b - hoofH - 0.5], [x + lw * 0.47, b], [x - lw * 0.47, b], [x - lw * 0.4, b - hoofH - 0.5], [x - lw * 0.48 + bend * 0.4, b - LL * 0.5]];
    return { x, far, bottom: b, hoof: hoofH, pts: pts2 };
  };
  const fN = xF + L * 0.2, fF = xF + L * 0.31, hF = xR - L * 0.24, hN = xR - L * 0.13;
  G.legs = [mkFront(fF, true), mkHind(hF, true), mkFront(fN, false), mkHind(hN, false)];

  // 乳房、尾巴
  if (p.udder > 0) {
    const s = p.udder;
    const ux = xR - L * 0.3;
    G.udder = { cx: ux, cy: bellyY + 2.2 * s, rx: 6.2 * s, ry: 4.6 * s, teats: [ux - 2.6 * s, ux + 2.8 * s] };
  }
  const t0 = [xR - L * 0.04, topY + D * 0.06];
  G.tail = { p0: t0, p1: [xR + D * 0.28, topY + D * 0.55], p2: [xR + D * 0.12, Math.min(bellyY + LL * 0.3, bellyY + D * 0.1)], w: Math.max(2.2, lw * 0.28) };

  // 花紋的位置（身體座標）
  const r = rng(g.seed + 404);
  const J = () => (r() - 0.5);
  G.spots = [];
  if (g.pattern === 'patches' || g.pattern === 'strawberry') {
    const k = g.pattern === 'strawberry' ? 0.9 : 1;
    G.spots.push(
      { cx: xF + L * (0.3 + 0.08 * J()), cy: topY + D * (0.25 + 0.15 * J()), r: D * 0.42 * k },
      { cx: xR - L * (0.2 + 0.08 * J()), cy: topY + D * (0.28 + 0.2 * J()), r: D * 0.46 * k },
      { cx: xF + L * (0.62 + 0.06 * J()), cy: bellyY - D * (0.16 + 0.1 * J()), r: D * 0.28 * k },
    );
    if (G.neck) G.spots.push({ cx: (G.neck.crest[0] + G.neck.throat[0]) / 2 + 3, cy: (G.neck.crest[1] + G.neck.throat[1]) / 2 - D * 0.05, r: D * 0.26 * k });
  } else if (g.pattern === 'dots') {
    for (let i = 0; i < 12; i++) G.spots.push({ cx: xF + L * (0.1 + 0.8 * r()), cy: topY + D * (0.12 + 0.72 * r()), r: D * 0.2 });
  }
  return G;
}

// ---------- 眼睛（三種新畫法） ----------
function eyeRound(P, C, cx, cy, r) {
  // 大圓亮面眼：深褐外圈、黑瞳、兩個反光（R1 是直的黑橢圓，這裡改成正圓有虹膜）
  P.ellipse(cx, cy, r, r * 1.04, '#3B241C');
  P.ellipse(cx, cy + r * 0.12, r * 0.7, r * 0.72, '#150C0A');
  P.arc([[cx - r * 0.62, cy + r * 0.5], [cx, cy + r * 0.8], [cx + r * 0.62, cy + r * 0.5]], '#8A5A44', r * 0.22, 0.95);
  P.ellipse(cx + P.lx * r * 0.34, cy - r * 0.36, r * 0.36, r * 0.32, '#FFFFFF');
  P.ellipse(cx - P.lx * r * 0.38, cy + r * 0.34, r * 0.15, r * 0.15, '#FFFFFF');
}
function eyeAlmond(P, C, cx, cy, a, b, side, lashes, rim) {
  // 溫和的杏仁眼：上緣弧度大、下緣平，外眼角略低；一個反光；母牛外側兩根短睫毛
  const o = side; // -1 左眼、+1 右眼（外側方向）
  const inner = [cx - o * a, cy - b * 0.12], outer = [cx + o * a, cy + b * 0.12];
  const d = `M${inner[0]},${inner[1]} Q${cx},${cy - b * 2.1} ${outer[0]},${outer[1]} Q${cx},${cy + b * 1.35} ${inner[0]},${inner[1]}Z`;
  if (rim) P.raw(`<path d="${d}" fill="none" stroke="${rim}" stroke-width="${b * 1.3}" stroke-linejoin="round" opacity="0.9"/>`);
  P.raw(`<path d="${d}" fill="#2B1A15"/>`);
  P.ellipse(cx + P.lx * a * 0.18, cy - b * 0.38, b * 0.36, b * 0.36, '#FFFFFF');
  P.raw(`<path d="M${inner[0]},${inner[1]} Q${cx},${cy - b * 2.1} ${outer[0]},${outer[1]}" fill="none" stroke="${INK}" stroke-width="${Math.max(1.3, b * 0.34)}" stroke-linecap="round"/>`);
  if (lashes) {
    const lx0 = outer[0] - o * a * 0.2, ly0 = cy - b * 0.72;
    P.raw(`<path d="M${outer[0]},${outer[1] - b * 0.1} l${o * b * 0.9},${-b * 0.55} M${lx0},${ly0} l${o * b * 0.55},${-b * 0.8}" stroke="${INK}" stroke-width="${Math.max(1.1, b * 0.28)}" stroke-linecap="round" fill="none"/>`);
  }
}
function eyeDot(P, cx, cy, r) {
  P.ellipse(cx, cy, r, r * 1.08, '#1E1411');
  P.ellipse(cx + P.lx * r * 0.32, cy - r * 0.34, r * 0.34, r * 0.34, '#FFFFFF');
}

// 正面口鼻（A、B）：小一點、寬扁的奶油色橢圓，上緣兩個小鼻孔
function muzzleFront(P, C, cx, cy, rx, ry) {
  const pts = superPts(cx, cy, rx, ry, 2.5, 40);
  P.shape(pts, C.muzzle, { w: 0.9 });
  P.ellipse(cx + P.lx * rx * 0.52, cy - ry * 0.42, rx * 0.18, ry * 0.16, '#FFFFFF', { opacity: 0.85 });
  const nr = Math.max(1.1, rx * 0.105);
  for (const s of [-1, 1]) P.ellipse(cx + s * rx * 0.42, cy - ry * 0.34, nr * 1.35, nr * 0.72, C.nostril, { rot: s * 0.35 });
  const mw = rx * 0.24, my = cy + ry * 0.36;
  P.arc([[cx - mw, my - mw * 0.15], [cx, my + mw * 0.3], [cx + mw, my - mw * 0.15]], C.mouth, Math.max(1.2, rx * 0.075));
}

function hornsFront(P, C, g, hx, topAt, spread, hr, calf) {
  if (g.horns === 'none') return;
  for (const s of [-1, 1]) {
    const bx = hx + s * spread;
    const by = topAt(bx);
    if (g.horns === 'bud' || calf) drawHorn(P, C, { type: 'bud', base: [bx, by + 1], r: hr * 0.16 });
    else if (g.horns === 'short') drawHorn(P, C, { p0: [bx, by + 2], p1: [bx + s * hr * 0.05, by - hr * 0.28], p2: [bx + s * hr * 0.28, by - hr * 0.44], w0: hr * 0.3, w1: hr * 0.1 });
    else drawHorn(P, C, { p0: [bx - s * hr * 0.1, by + hr * 0.12], p1: [bx + s * hr * 1.05, by + hr * 0.05], p2: [bx + s * hr * 1.35, by - hr * 0.62], w0: hr * 0.34, w1: hr * 0.09, tipFrom: 0.7 });
  }
}

function headPattern(g, r, cx, cy, rx, ry, side) {
  if (g.pattern !== 'patches' && g.pattern !== 'strawberry') return [];
  return [blob(cx + side * rx * 0.75, cy - ry * 0.72, rx * 0.46, r, 8, 0.3)];
}

// 蓬鬆瀏海：長到快遮住眼睛
function shaggyFringe(P, C, cx, top, bottom, halfW, r) {
  const pts = [];
  for (let i = 0; i <= 14; i++) {
    const a = Math.PI + 0.12 + (i / 14) * (Math.PI - 0.24);
    pts.push([cx + Math.cos(a) * halfW, bottom - 2 + Math.sin(a) * (bottom - top)]);
  }
  const xr = pts[pts.length - 1][0], xl = pts[0][0], n = 5;
  for (let i = 0; i < n; i++) {
    const xa = xr - ((xr - xl) * i) / n, xb = xr - ((xr - xl) * (i + 1)) / n, mid = (xa + xb) / 2;
    const dip = (i === 1 || i === 3 ? 0.55 : i === 2 ? 0.35 : 0.3) * (bottom - top) * 0.45 + (r() - 0.5);
    pts.push([xa, bottom - (i === 0 ? 2 : 0.5)], [mid + (xa - xb) * 0.12, bottom + dip], [mid - (xa - xb) * 0.1, bottom + dip * 0.8]);
  }
  P.shape(pts, C.fringe, { w: 0.9 });
  P.arc([[cx + P.lx * halfW * 0.55, top + (bottom - top) * 0.45], [cx + P.lx * halfW * 0.2, top + (bottom - top) * 0.22]], '#FFFFFF', P.lw * 0.8, 0.65);
}

// ---------- 組裝 ----------
export function renderCow(vkey, g, { x = 0, y = 0, scale = 1, facing = 'left', id = 'cow', sil = false } = {}) {
  const G = geometry(vkey, g);
  const p = G.p, hr = G.hr, H = G.head;
  const C = paletteQ(g);
  const mirror = facing === 'right';
  const P = painter({ id, mirror, lw: 3.2 });
  const r = rng(g.seed + 505);
  const adult = !p.calf;
  const s = scale * p.size;

  // 側面頭：遠側的耳朵與角先畫（在脖子後面）
  const profile = vkey === 'c';
  let prof = null;
  if (profile) prof = profileHead(G, g);
  if (profile) {
    const e = prof.farEar;
    P.shape(leaf(e.base, e.ang, e.len, e.wid, { round: 0.62 }), shade(C.ear, -0.1), { w: 0.85 });
    if (prof.farHorn) drawHorn(P, { ...C, horn: shade(C.horn, -0.08) }, prof.farHorn);
  }
  // 尾巴
  drawTail(P, C, { p0: G.tail.p0, p1: G.tail.p1, p2: G.tail.p2, w: G.tail.w, tuftR: Math.max(3.4, G.D * 0.12) * (p.fluffy ? 1.3 : 1), color: C.coat });
  // 遠側的腿、乳房、近側的腿
  const legFill = (L) => (L.far ? C.far : C.coat);
  G.legs.filter((L) => L.far).forEach((L) => drawLeg(P, C, { ...L, fill: legFill(L) }));
  if (G.udder && adult) drawUdder(P, C, G.udder);
  G.legs.filter((L) => !L.far).forEach((L) => drawLeg(P, C, { ...L, fill: legFill(L) }));
  // 身體（含脖子）＋花紋
  const pat = makeBodyPattern(g, r, G);
  P.region(G.body, C.coat, () => {
    paintPattern(P, C, pat);
    P.ellipse((G.xF + G.xR) / 2 + 4, G.bellyY + G.D * 0.1, G.L * 0.6, G.D * 0.36, INK, { opacity: 0.1 });
    const lx = P.lx;
    P.arc([[(G.xF + G.xR) / 2 + lx * G.L * 0.05, G.topY + G.D * 0.2], [(G.xF + G.xR) / 2 + lx * G.L * 0.22, G.topY + G.D * 0.1], [(G.xF + G.xR) / 2 + lx * G.L * 0.34, G.topY + G.D * 0.18]], '#FFFFFF', 3.4, C.dark ? 0.3 : 0.75);
  });

  // 項圈＋牛鈴
  if (g.collar === 'bell') {
    if (vkey === 'a') {
      const cy = H.y + hr * 0.84 * p.face + 3;
      drawCollar(P, C, [[H.x - hr * 0.5, cy - 3], [H.x, cy + 1.5], [H.x + hr * 0.5, cy - 3]], [H.x - 1, cy + 6.5], (hr / 24) * (p.calf ? 0.9 : 1));
    } else {
      const n = G.neck;
      const a = lerp(n.endTop, n.crest, 0.28), b = lerp(n.endBot, n.throat, 0.26);
      const mid = lerp(a, b, 0.5);
      const strap = [a, [mid[0] - 2.5, mid[1]], b];
      drawCollar(P, C, strap, [b[0] - 1, b[1] + 6.2 * (p.calf ? 0.85 : 1)], 1.05 * (p.calf ? 0.85 : 1));
    }
  }

  // 頭
  let headTop;
  if (vkey === 'a') headTop = headA(P, C, g, G, r);
  else if (vkey === 'b') headTop = headB(P, C, g, G, r);
  else headTop = headC(P, C, g, G, r, prof);

  let svg = P.svg({ x, y, scale: s });
  if (sil) svg = `<g filter="url(#sil)">${svg}</g>`;
  const toScreen = (pt) => [x + (mirror ? -1 : 1) * pt[0] * s, y + pt[1] * s];
  const bodyC = toScreen([(G.xF + G.xR) / 2, 0]);
  const bb = bbox([G.body, ...G.legs.map((l) => l.pts)]);
  const fc = vkey === 'a' ? [H.x, H.y + hr * 0.08, hr * 1.22] : vkey === 'b' ? [H.x, H.y + hr * 0.12, hr * 1.42] : [H.x - hr * 0.2, H.y + hr * 0.02, hr * 1.25];
  const fcs = toScreen([fc[0], fc[1]]);
  return {
    svg, G,
    face: { cx: fcs[0], cy: fcs[1], r: fc[2] * s },
    headTop: toScreen([H.x + (profile ? -hr * 0.2 : 0), headTop]),
    shadow: { cx: bodyC[0], rx: (G.L * 0.62 + (vkey === 'a' ? hr * 0.3 : 0)) * s, ry: Math.max(4, G.D * 0.16) * s },
    bbox: { x0: Math.min(bb.x0, H.x - hr * 1.6), x1: bb.x1 + G.D * 0.35, y0: headTop - 4, y1: 0 },
    scale: s,
  };
}

function makeBodyPattern(g, r, G) {
  const pat = { blobs: [], dots: [], seeds: [] };
  if (g.pattern === 'dots') {
    G.spots.forEach((sp) => pat.dots.push({ cx: sp.cx, cy: sp.cy, r: Math.max(2, G.D * 0.07) }));
    return pat;
  }
  G.spots.forEach((sp) => pat.blobs.push(blob(sp.cx, sp.cy, sp.r, r, 9, 0.34)));
  if (g.pattern === 'strawberry') addSeeds(pat, r);
  return pat;
}
function addSeeds(pat, r) {
  pat.blobs.forEach((b) => {
    const bb = bbox([b]);
    const sp = Math.max(4.4, (bb.x1 - bb.x0) / 4);
    let row = 0;
    for (let yy = bb.y0 + sp * 0.5; yy < bb.y1; yy += sp * 0.84, row++) {
      for (let xx = bb.x0 + sp * 0.4 + (row % 2) * sp * 0.5; xx < bb.x1; xx += sp) {
        const jx = xx + (r() - 0.5) * sp * 0.25, jy = yy + (r() - 0.5) * sp * 0.25;
        if (pointInPoly(b, jx, jy) && pointInPoly(b, jx, jy + 2.2) && pointInPoly(b, jx, jy - 2.2) && pointInPoly(b, jx + 2, jy) && pointInPoly(b, jx - 2, jy)) {
          pat.seeds.push({ cx: jx, cy: jy, r: 1.5, rot: (r() - 0.5) * 0.7 });
        }
      }
    }
  });
}

// A：正面大頭
function headA(P, C, g, G, r) {
  const p = G.p, hr = G.hr, H = G.head;
  const rx = hr, ry = hr * 0.86 * (0.9 + 0.1 * p.face);
  let pts = superPts(H.x, H.y, rx, ry, 2.25, 56).map(([x, y]) => { const ny = (y - H.y) / ry; return [H.x + (x - H.x) * (1 - 0.05 * ny), y]; });
  const topAt = (x) => H.y - ry * Math.pow(Math.max(0, 1 - Math.abs((x - H.x) / rx) ** 2.25), 1 / 2.25);
  hornsFront(P, C, g, H.x, topAt, rx * 0.44, hr * 0.62, p.calf);
  // 耳朵往兩側伸、微垂
  for (const s of [-1, 1]) {
    const base = [H.x + s * rx * 0.86, H.y - ry * 0.2];
    const ang = s < 0 ? Math.PI - 0.3 : 0.3;
    const e = { base, ang, len: hr * 0.66, wid: hr * 0.4 };
    P.shape(leaf(e.base, e.ang, e.len, e.wid, { round: 0.6 }), C.ear, { w: 0.9 });
    P.shape(leaf([base[0] + Math.cos(ang) * e.len * 0.2, base[1] + Math.sin(ang) * e.len * 0.2], ang, e.len * 0.62, e.wid * 0.48, { round: 0.6 }), C.earIn, { line: false });
  }
  const side = r() < 0.5 ? -1 : 1;
  P.region(pts, C.coat, () => {
    headPattern(g, r, H.x, H.y, rx, ry, side).forEach((b) => P.shape(b, C.pat, { line: false }));
    if (g.pattern === 'strawberry') {
      const pat = { blobs: headPattern(g, r, H.x, H.y, rx, ry, side), dots: [], seeds: [] }; addSeeds(pat, r);
      pat.seeds.forEach((sd) => P.ellipse(sd.cx, sd.cy, sd.r * 0.72, sd.r, C.seed, { rot: sd.rot }));
    }
  });
  P.arc([[H.x + P.lx * rx * 0.3, H.y - ry * 0.8], [H.x + P.lx * rx * 0.62, H.y - ry * 0.68], [H.x + P.lx * rx * 0.76, H.y - ry * 0.36]], '#FFFFFF', 3.2, C.dark ? 0.35 : 0.85);
  // 臉：眼睛在中線稍下、間距寬；口鼻縮小放在下方
  const er = hr * (p.eyeBig ? 0.25 : 0.215);
  const ey = H.y + ry * 0.02, ex = rx * 0.4;
  if (p.eyeRim) for (const s of [-1, 1]) P.ellipse(H.x + s * ex, ey, er * 1.22, er * 1.25, shade(C.coat, -0.13));
  for (const s of [-1, 1]) eyeRound(P, C, H.x + s * ex, ey, er);
  if (p.fluffy) shaggyFringe(P, C, H.x, H.y - ry - 2, ey - er * 0.35, rx * 0.98, r);
  else drawForelock(P, C, H.x, H.y - ry * 0.93, hr * 0.26);
  for (const s of [-1, 1]) drawBlush(P, C, { cx: H.x + s * rx * 0.68, cy: ey + er * 1.25, rx: hr * 0.17, ry: hr * 0.1 });
  muzzleFront(P, C, H.x, H.y + ry * 0.66, rx * 0.44, ry * 0.25);
  const top = H.y - ry;
  drawOverlay(P, C, g, H.x, top, hr / 26);
  const hornTop = g.horns === 'long' ? top - hr * 0.65 : g.horns === 'short' && !p.calf ? top - hr * 0.45 : top - hr * 0.12;
  return Math.min(hornTop, g.overlay !== 'none' ? top - 14 * hr / 26 : hornTop);
}

// B：接近真牛比例，臉正面稍側、臉比較長
function headB(P, C, g, G, r) {
  const p = G.p, hr = G.hr, H = G.head;
  const rx = hr * 0.92, ry = hr * 1.06 * p.face;
  let pts = superPts(H.x, H.y, rx, ry, 2.3, 56).map(([x, y]) => { const ny = (y - H.y) / ry; return [H.x + (x - H.x) * (1 - 0.2 * Math.max(0, ny) + 0.04 * Math.min(0, ny)), y]; });
  const topAt = (x) => H.y - ry * Math.pow(Math.max(0, 1 - Math.abs((x - H.x) / rx) ** 2.3), 1 / 2.3);
  hornsFront(P, C, g, H.x, topAt, rx * 0.5, hr, p.calf);
  for (const s of [-1, 1]) {
    const base = [H.x + s * rx * 0.82, H.y - ry * 0.3];
    const ang = s < 0 ? Math.PI - 0.16 : 0.16;
    const len = hr * 1.0, wid = hr * 0.52;
    P.shape(leaf(base, ang, len, wid, { round: 0.6 }), C.ear, { w: 0.9 });
    P.shape(leaf([base[0] + Math.cos(ang) * len * 0.2, base[1] + Math.sin(ang) * len * 0.2], ang, len * 0.62, wid * 0.48, { round: 0.6 }), C.earIn, { line: false });
  }
  const side = r() < 0.5 ? -1 : 1;
  P.region(pts, C.coat, () => {
    const hb = headPattern(g, r, H.x, H.y, rx, ry, side);
    hb.forEach((b) => P.shape(b, C.pat, { line: false }));
    if (g.pattern === 'strawberry') { const pat = { blobs: hb, dots: [], seeds: [] }; addSeeds(pat, r); pat.seeds.forEach((sd) => P.ellipse(sd.cx, sd.cy, sd.r * 0.72, sd.r, C.seed, { rot: sd.rot })); }
    if (p.dish) P.arc([[H.x - rx * 0.28, H.y + ry * 0.08], [H.x, H.y + ry * 0.16], [H.x + rx * 0.28, H.y + ry * 0.08]], shade(C.coat, -0.12), 1.6, 0.8);
  });
  P.arc([[H.x + P.lx * rx * 0.25, H.y - ry * 0.82], [H.x + P.lx * rx * 0.6, H.y - ry * 0.66]], '#FFFFFF', 2.8, C.dark ? 0.35 : 0.8);
  const a = hr * (p.eyeBig ? 0.27 : 0.23), b = hr * (p.eyeBig ? 0.17 : 0.14);
  const ey = H.y - ry * 0.12;
  for (const s of [-1, 1]) eyeAlmond(P, C, H.x + s * rx * 0.46, ey, a, b, s, !p.calf, p.eyeRim ? shade(C.coat, -0.16) : null);
  if (p.fluffy) shaggyFringe(P, C, H.x, H.y - ry - 2, ey - b * 0.4, rx * 1.02, r);
  else drawForelock(P, C, H.x, H.y - ry * 0.95, hr * 0.26);
  for (const s of [-1, 1]) drawBlush(P, C, { cx: H.x + s * rx * 0.62, cy: ey + b * 2.4, rx: hr * 0.15, ry: hr * 0.08 });
  muzzleFront(P, C, H.x, H.y + ry * 0.72, rx * 0.62, ry * 0.3);
  const top = H.y - ry;
  drawOverlay(P, C, g, H.x, top, hr / 22);
  const hornTop = g.horns === 'long' && !p.calf ? top - hr * 0.62 : g.horns === 'short' && !p.calf ? top - hr * 0.44 : top - hr * 0.15;
  return Math.min(hornTop, g.overlay !== 'none' ? top - 14 * hr / 22 : hornTop);
}

// C：側面頭的幾何（口鼻往前）
function profileHead(G, g) {
  const p = G.p, hr = G.hr, H = G.head;
  const f = p.face;
  const dish = p.dish ? hr * 0.12 : 0;
  // 牛的側臉：額頭寬平、鼻樑直（娟珊略凹）、口鼻方而鈍、下顎深
  const pts = [
    [H.x + hr * 0.55, H.y - hr * 0.8],
    [H.x - hr * 0.15, H.y - hr * 0.9],
    [H.x - hr * 0.56, H.y - hr * 0.62 + dish * 0.3],
    [H.x - hr * 0.8 * f, H.y - hr * 0.2 + dish],
    [H.x - hr * 1.05 * f, H.y + hr * 0.12],
    [H.x - hr * 1.16 * f, H.y + hr * 0.47],
    [H.x - hr * 1.11 * f, H.y + hr * 0.81],
    [H.x - hr * 0.87 * f, H.y + hr * 0.96],
    [H.x - hr * 0.3, H.y + hr * 0.9],
    [H.x + hr * 0.5, H.y + hr * 0.55],
    [H.x + hr * 0.72, H.y - hr * 0.1],
  ];
  const hornBase = [H.x + hr * 0.12, H.y - hr * 0.8];
  let nearHorn = null, farHorn = null;
  if (g.horns !== 'none') {
    if (g.horns === 'bud' || p.calf) { nearHorn = { type: 'bud', base: hornBase, r: hr * 0.17 }; farHorn = { type: 'bud', base: [hornBase[0] + hr * 0.3, hornBase[1] + hr * 0.02], r: hr * 0.14 }; }
    else if (g.horns === 'short') {
      nearHorn = { p0: [hornBase[0], hornBase[1] + 2], p1: [hornBase[0] - hr * 0.05, hornBase[1] - hr * 0.3], p2: [hornBase[0] - hr * 0.3, hornBase[1] - hr * 0.48], w0: hr * 0.3, w1: hr * 0.1 };
      farHorn = { p0: [hornBase[0] + hr * 0.3, hornBase[1] + 2], p1: [hornBase[0] + hr * 0.3, hornBase[1] - hr * 0.28], p2: [hornBase[0] + hr * 0.12, hornBase[1] - hr * 0.44], w0: hr * 0.26, w1: hr * 0.09 };
    } else {
      nearHorn = { p0: [hornBase[0] + hr * 0.1, hornBase[1] + hr * 0.1], p1: [hornBase[0] - hr * 0.9, hornBase[1] + hr * 0.05], p2: [hornBase[0] - hr * 1.15, hornBase[1] - hr * 0.62], w0: hr * 0.34, w1: hr * 0.09, tipFrom: 0.7 };
      farHorn = { p0: [hornBase[0] + hr * 0.35, hornBase[1] + hr * 0.1], p1: [hornBase[0] + hr * 1.25, hornBase[1] - hr * 0.05], p2: [hornBase[0] + hr * 1.4, hornBase[1] - hr * 0.62], w0: hr * 0.3, w1: hr * 0.08, tipFrom: 0.7 };
    }
  }
  return {
    pts: densify(pts, 5), f,
    nearEar: { base: [H.x + hr * 0.46, H.y - hr * 0.46], ang: 0.06, len: hr * 0.92, wid: hr * 0.48 },
    farEar: { base: [H.x + hr * 0.4, H.y - hr * 0.62], ang: -0.16, len: hr * 0.78, wid: hr * 0.4 },
    nearHorn, farHorn,
    eye: { cx: H.x - hr * 0.24, cy: H.y - hr * 0.3, r: hr * (p.eyeBig ? 0.165 : 0.135) },
    muzzle: { cx: H.x - hr * 0.95 * f, cy: H.y + hr * 0.5, rx: hr * 0.33, ry: hr * 0.47 },
    top: H.y - hr * 0.9,
  };
}
function headC(P, C, g, G, r, prof) {
  const p = G.p, hr = G.hr, H = G.head;
  if (prof.nearHorn) drawHorn(P, C, prof.nearHorn);
  const side = 1;
  P.region(prof.pts, C.coat, () => {
    if (g.pattern === 'patches' || g.pattern === 'strawberry') {
      const hb = [blob(H.x + hr * 0.45, H.y - hr * 0.1, hr * 0.42, r, 8, 0.3)];
      hb.forEach((b) => P.shape(b, C.pat, { line: false }));
      if (g.pattern === 'strawberry') { const pat = { blobs: hb, dots: [], seeds: [] }; addSeeds(pat, r); pat.seeds.forEach((sd) => P.ellipse(sd.cx, sd.cy, sd.r * 0.72, sd.r, C.seed, { rot: sd.rot })); }
    }
    // 口鼻：奶油色，蓋住方方的鼻頭；分界線在內側
    const m = prof.muzzle;
    P.ellipse(m.cx - m.rx * 0.3, m.cy, m.rx * 1.55, m.ry * 1.02, C.muzzle);
    P.arc([[m.cx + m.rx * 0.78, m.cy - m.ry * 0.95], [m.cx + m.rx * 1.22, m.cy - m.ry * 0.05], [m.cx + m.rx * 0.9, m.cy + m.ry * 0.92]], INK, 1.8, 0.85);
    if (p.dish) P.arc([[H.x - hr * 0.62, H.y - hr * 0.46], [H.x - hr * 0.44, H.y - hr * 0.36]], shade(C.coat, -0.14), 1.4, 0.8);
  }, { smooth: true });
  P.arc([[H.x + hr * 0.1, H.y - hr * 0.76], [H.x - hr * 0.45, H.y - hr * 0.66]], '#FFFFFF', 2.6, C.dark ? 0.35 : 0.8);
  // 鼻孔：上緣兩個（前面的大、後面的小），嘴在下面、畫在臉裡面
  const m = prof.muzzle;
  P.ellipse(m.cx - m.rx * 0.32, m.cy - m.ry * 0.42, hr * 0.1, hr * 0.062, C.nostril, { rot: -0.85 });
  P.ellipse(m.cx + m.rx * 0.36, m.cy - m.ry * 0.5, hr * 0.075, hr * 0.047, C.nostril, { rot: -0.55 });
  P.arc([[m.cx - m.rx * 0.4, m.cy + m.ry * 0.5], [m.cx + m.rx * 0.05, m.cy + m.ry * 0.6], [m.cx + m.rx * 0.5, m.cy + m.ry * 0.48]], C.mouth, 1.5, 1);
  // 近側耳朵（往後橫伸）
  const e = prof.nearEar;
  P.shape(leaf(e.base, e.ang, e.len, e.wid, { round: 0.6 }), C.ear, { w: 0.9 });
  P.shape(leaf([e.base[0] + Math.cos(e.ang) * e.len * 0.2, e.base[1] + Math.sin(e.ang) * e.len * 0.2], e.ang, e.len * 0.62, e.wid * 0.46, { round: 0.6 }), C.earIn, { line: false });
  // 眼睛
  if (p.eyeRim) P.ellipse(prof.eye.cx, prof.eye.cy, prof.eye.r * 1.7, prof.eye.r * 1.6, shade(C.coat, -0.25));
  eyeDot(P, prof.eye.cx, prof.eye.cy, prof.eye.r);
  if (p.fluffy) {
    const top = H.y - hr * 0.92;
    const pts = [[H.x + hr * 0.55, top + hr * 0.1], [H.x + hr * 0.1, top - hr * 0.12], [H.x - hr * 0.42, top + hr * 0.05], [H.x - hr * 0.62, top + hr * 0.4], [H.x - hr * 0.45, prof.eye.cy + hr * 0.05], [H.x - hr * 0.32, prof.eye.cy - hr * 0.08], [H.x - hr * 0.2, prof.eye.cy + hr * 0.02], [H.x - hr * 0.02, prof.eye.cy - hr * 0.1], [H.x + hr * 0.2, prof.eye.cy + hr * 0.02], [H.x + hr * 0.4, top + hr * 0.45]];
    P.shape(pts, C.fringe, { w: 0.9 });
  }
  drawBlush(P, C, { cx: H.x - hr * 0.4, cy: H.y + hr * 0.14, rx: hr * 0.16, ry: hr * 0.09 });
  drawOverlay(P, C, g, H.x - hr * 0.05, prof.top, hr / 24);
  const hornTop = g.horns === 'long' && !p.calf ? prof.top - hr * 0.62 : g.horns === 'short' && !p.calf ? prof.top - hr * 0.5 : prof.top - hr * 0.15;
  return Math.min(hornTop, g.overlay !== 'none' ? prof.top - 14 * hr / 24 : hornTop);
}

// 剪影濾鏡（塗黑）：整頭牛的 alpha 直接變成深色
export const SIL_DEFS = `<filter id="sil" x="-10%" y="-10%" width="120%" height="120%"><feFlood flood-color="#2A1E1A"/><feComposite in2="SourceAlpha" operator="in"/></filter>`;
