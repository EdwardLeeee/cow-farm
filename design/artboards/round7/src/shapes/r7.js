// R7 牛產生器：線條 B 乾淨中線；側面照 9966、正面照 9967 坐著，兩個角度的臉各照參考圖（第 6 輪裁示）。
// 第 7 輪兩個角度都更貼近參考圖（使用者：「正面我希望你畫的跟9967一樣」「而且側面也不夠像9966」）。
// 著作權底線（D13）：只貼近參考圖的比例與特徵；斑點排列與形狀、角和耳朵的確切形狀、細部比例是我們自己的，不描圖。
//   側面（9966）：身體深而方（深約長的 0.74）、頭大（約身體深的 0.84）、頭頂略高過背、下緣約在身體 72% 深；
//     小點眼在臉的上半、兩眼分開；下半臉淺橘色口鼻（只換顏色、沒有深色分界線、不畫鼻孔）；四條細腿直直站著。
//   正面（9967 坐著）：高的梯形身體（上窄下寬、兩側微鼓）、寬臉在上；小點眼靠近、位置偏高；大的粉紅橢圓口鼻加兩個鼻孔；
//     胸前兩隻小短腳、後腳從底部兩側往外伸；一隻耳朵掛圓形耳標。我們自己的：角是往外再往內彎的月牙、耳朵圓頭微垂、
//     斑點排列（右上大、左下中、中間小、右下被邊切掉）與稍微不規則的圓形。
import {
  painter, leaf, blob, bbox, topYAt, pointInPoly, tail as drawTail, leg as drawLeg, horn as drawHorn, overlay as drawOverlay,
  makePattern, paintPattern, superPts, scallopPts, smoothPath, rng, shade, lum, INK,
} from './q.js';

export const VARIANTS = {
  r7: { key: 'r7', name: '第 7 輪：側面更像 9966、正面更像 9967', frontPose: 'sit', face: 'ref', scene: 1.1 },
};
const LW = 2.4; // B 乾淨中線

const BASE = { L: 74, D: 42, leg: 11, legW: 8.4, hh: 36, FW: 54, FH: 46 };
// 用途的相對體型（三種都是胖身材）：乳用最高、腿最長；肉用最寬、最深、腿最短
const BUILD = {
  dairy: { L: 0.97, D: 0.9, leg: 1.12, legW: 0.9, udder: 1, head: 0.97, FW: 0.88, FH: 1.06 },
  dual: { L: 1.0, D: 1.0, leg: 1.0, legW: 1.0, udder: 0.8, head: 1.0, FW: 1.0, FH: 1.0 },
  beef: { L: 1.1, D: 1.16, leg: 0.74, legW: 1.3, udder: 0.3, head: 1.05, FW: 1.2, FH: 1.02 },
};
const bell = (u, c, w) => Math.exp(-(((u - c) / w) ** 2));

export function plan(g) {
  const b = BUILD[g.use] || BUILD.dual;
  const t = g.traits || {};
  const bull = g.sex === 'bull', calf = g.age === 'calf';
  const p = {
    use: g.use, bull, calf, size: 1,
    L: BASE.L * b.L, D: BASE.D * b.D, leg: BASE.leg * b.leg, legW: BASE.legW * b.legW, hh: BASE.hh * b.head,
    FW: BASE.FW * b.FW, FH: BASE.FH * b.FH,
    udder: b.udder, hump: 0, muscle: g.use === 'beef' ? 1 : 0,
    fluffy: !!t.A && !g.legendFluff, lightFluff: !!g.legendFluff, eyeBig: !!t.B, shortFace: !!t.B, marble: !!t.C && g.use === 'beef',
  };
  if (p.fluffy) { p.L *= 1.06; p.D *= 1.06; p.leg *= 0.78; p.FW *= 1.08; } // 長毛：更低、更寬
  if (t.B) { p.size *= 0.9; p.hh *= 1.02; } // 淡色：骨架小一號、臉短、眼大
  if (t.C) p.muscle += 0.4;
  if (bull) { p.size *= 1.1; p.hump = 1; p.hh *= 1.04; p.udder = 0; p.FW *= 1.06; }
  if (calf) { p.size *= 0.6; p.L *= 0.82; p.leg *= 0.9; p.legW *= 1.15; p.hh *= 1.12; p.FH *= 0.92; p.udder = 0; p.hump = 0; p.muscle *= 0.3; }
  return p;
}

function palette(g, faceKind) {
  const coat = g.coat;
  const dark = lum(coat) < 0.12;
  return {
    coat, dark, pat: g.patternColor || coat,
    far: shade(coat, dark ? 0.06 : -0.08),
    face: g.faceColor || coat,
    ear: g.earColor === 'pattern' ? g.patternColor : coat,
    earIn: dark ? '#C99A94' : '#F6BDB4',
    // 9966 是淺橘色橫條口鼻；9967 是粉紅橢圓口鼻
    muzzle: faceKind === '66' ? (dark ? '#D1ABA3' : '#F7CDB5') : (dark ? '#D4A5A8' : '#F7C3C6'),
    nostril: dark ? '#8E5F63' : '#C98088',
    eye: dark ? '#140D0D' : '#2E1D19',
    hoof: dark ? '#1C1414' : '#5A4038', hoofHi: dark ? '#1C1414' : '#5A4038',
    horn: '#FFF1CF', hornTip: '#E6C98F',
    tuft: g.pattern === 'patches' ? g.patternColor : shade(coat, dark ? 0.08 : -0.18),
    fringe: shade(coat, dark ? 0.1 : 0.06),
    udder: '#F8C3C3', seed: g.seedColor || '#FFE9A8',
  };
}

// ---------- 頭的形狀 ----------
function head66(cx, cy, p) { // 9966：蛋形、上窄下寬、比身體窄；頭大（約身體深的 0.84）
  const hh = p.hh * 1.2, hw = hh * (p.shortFace ? 0.8 : 0.74), rx = hw / 2, ry = (hh / 2) * (p.shortFace ? 0.95 : 1);
  const pts = superPts(cx, cy, rx, ry, 2.3, 64).map(([x, y]) => { const v = (y - cy) / ry; return [cx + (x - cx) * (1 + 0.11 * Math.max(0, v) - 0.08 * Math.max(0, -v)), y]; });
  return { kind: '66', pts, cx, cy, rx, ry, hh, top: cy - ry, bottom: cy + ry };
}
function head67(cx, cy, p) { // 9967：寬臉（寬約高的 1.3 倍）、頭頂較平、下巴收窄
  const hh = p.hh * 0.8, hw = hh * (p.shortFace ? 1.36 : 1.3), rx = hw / 2, ry = (hh / 2) * (p.shortFace ? 0.95 : 1);
  const pts = superPts(cx, cy, rx, ry, 2.8, 64).map(([x, y]) => { const v = (y - cy) / ry; return [cx + (x - cx) * (1 - 0.15 * Math.max(0, v)), y]; });
  return { kind: '67', pts, cx, cy, rx, ry, hh, top: cy - ry, bottom: cy + ry };
}

// ---------- 身體：側面（9966）與正面（9967） ----------
function sideBody(p) {
  const L = p.L * 0.94, D = p.D * 1.22; // 9966 的身體深而方
  const cx = 0, cy = -p.leg - D / 2, rx = L / 2, ry = D / 2;
  const mod = ([x, y]) => {
    const u = (x - cx) / rx, v = (y - cy) / ry;
    let dy = 0, dx = 0;
    if (v < 0) {
      dy -= p.hump * D * 0.14 * bell(u, -0.35, 0.2) * -v; // 公牛肩峰
      dy += D * 0.035 * Math.max(0, u) * -v; // 背往屁股稍微往下
    } else dy += D * 0.04 * bell(u, 0.1, 0.5) * v; // 圓肚子
    if (u > 0.55) dx += p.muscle * D * 0.03 * bell(v, -0.1, 0.5);
    return [x + dx, y + dy];
  };
  const pts = p.fluffy ? scallopPts(superPts(cx, cy, rx, ry, 2.7, 20).map(mod), 0.26, 6) : superPts(cx, cy, rx, ry, 2.7, 72).map(mod);
  return { pts, cx, cy, rx, ry, L, D, topY: cy - ry, bellyY: cy + ry, xF: cx - rx, xR: cx + rx };
}
function frontBody(p, sit) {
  // 9967 坐姿：高的梯形身體，上窄下寬、兩側微鼓；公牛肩膀寬
  const W = p.FW * 1.06, Hb = p.FH * 1.18;
  const bottom = sit ? -1 : -p.leg * 0.85;
  const cy = bottom - Hb / 2, rx = W / 2, ry = Hb / 2;
  const topRatio = p.bull ? 0.74 : p.use === 'beef' ? 0.66 : 0.58;
  const mod = ([x, y]) => { const v = (y - cy) / ry; const t = Math.pow((v + 1) / 2, 0.9); return [x * (topRatio + (1 - topRatio) * t), y]; };
  const pts = p.fluffy ? scallopPts(superPts(0, cy, rx, ry, 3.0, 22).map(mod), 0.26, 6) : superPts(0, cy, rx, ry, 3.0, 80).map(mod);
  return { pts, cx: 0, cy, rx, ry, W, H: Hb, topY: cy - ry, bottomY: cy + ry };
}

function sideSpots(g, B, r) {
  if (g.pattern !== 'patches' && g.pattern !== 'strawberry') return [];
  const J = () => r() - 0.5, { cx, cy, rx, ry, D } = B, k = g.pattern === 'strawberry' ? 0.85 : 1;
  return [
    { cx: cx + rx * (0.05 + 0.06 * J()), cy: cy - ry * (0.42 + 0.08 * J()), r: D * 0.33 * k },
    { cx: cx + rx * (0.7 + 0.05 * J()), cy: cy + ry * (0.12 + 0.1 * J()), r: D * 0.25 * k },
    { cx: cx - rx * (0.35 + 0.05 * J()), cy: cy + ry * (0.5 + 0.08 * J()), r: D * 0.17 * k },
  ];
}
function frontSpots(g, B, r) {
  // 我們自己的排列：右上大、左下中、中間上方小、右下被身體邊切掉、下方一顆小的
  if (g.pattern !== 'patches' && g.pattern !== 'strawberry') return [];
  const J = () => r() - 0.5, { cy, W, H } = B, k = g.pattern === 'strawberry' ? 0.9 : 1;
  return [
    { cx: W * (0.2 + 0.03 * J()), cy: cy - H * (0.1 + 0.03 * J()), r: W * 0.19 * k },
    { cx: -W * (0.26 + 0.03 * J()), cy: cy + H * (0.2 + 0.03 * J()), r: W * 0.14 * k },
    { cx: -W * (0.04 + 0.02 * J()), cy: cy - H * 0.33, r: W * 0.065 * k },
    { cx: W * 0.48, cy: cy + H * (0.36 + 0.02 * J()), r: W * 0.13 * k },
    { cx: W * (0.1 + 0.02 * J()), cy: cy + H * 0.4, r: W * 0.05 * k },
  ];
}
// 稍微不規則的圓點斑（草莓牛另加淡色籽點）
function roundPattern(g, r, spots, region) {
  const pat = { blobs: spots.map((sp) => blob(sp.cx, sp.cy, sp.r, r, 11, 0.12, 0.92 + r() * 0.12)), dots: [], seeds: [] };
  if (g.pattern === 'strawberry') {
    pat.blobs.forEach((b) => {
      const bb = bbox([b]), sp = Math.max(4, (bb.x1 - bb.x0) / 4.2);
      let row = 0;
      for (let y = bb.y0 + sp * 0.5; y < bb.y1; y += sp * 0.82, row++) {
        for (let x = bb.x0 + sp * 0.4 + (row % 2) * sp * 0.5; x < bb.x1; x += sp) {
          if (pointInPoly(b, x, y) && pointInPoly(b, x, y + 2) && pointInPoly(b, x, y - 2) && (!region || pointInPoly(region, x, y))) pat.seeds.push({ cx: x, cy: y, r: 1.5, rot: (r() - 0.5) * 0.7 });
        }
      }
    });
  }
  return pat;
}
function marbling(P, cx, cy, rx, ry) {
  [[-0.55, -0.35], [-0.4, -0.02], [-0.2, 0.28], [-0.1, -0.42]].forEach(([u, v], i) => {
    const x = cx + u * rx, y = cy + v * ry, w = rx * 0.18;
    P.arc([[x - w, y], [x - w * 0.4, y - 2], [x + w * 0.2, y + 1.1], [x + w * 0.8, y - 1.5]], '#C9A7A0', 1.1, 0.85 - i * 0.05);
  });
}

// ---------- 臉 ----------
function hornAt(P, C, g, p, bx, by, dir, hr, kind, hc = C) {
  const kk = p.bull ? 1.3 : 1;
  if (g.horns === 'bud') return drawHorn(P, hc, { type: 'bud', base: [bx, by], r: hr * 0.13 });
  if (g.horns === 'short') {
    // 正面：往外再往內彎的月牙角（我們自己的形狀）
    if (kind === '67') return drawHorn(P, hc, { p0: [bx, by + 1.5], p1: [bx + dir * hr * 0.34 * kk, by - hr * 0.26 * kk], p2: [bx + dir * hr * 0.14 * kk, by - hr * 0.58 * kk], w0: hr * 0.22 * kk, w1: hr * 0.07 });
    return drawHorn(P, hc, { p0: [bx, by + 1.5], p1: [bx + dir * hr * 0.04, by - hr * 0.22 * kk], p2: [bx + dir * hr * 0.16 * kk, by - hr * 0.34 * kk], w0: hr * 0.24 * kk, w1: hr * 0.1 });
  }
  if (g.horns === 'long') { const L = kind === '67' ? 1.6 : 1; return drawHorn(P, hc, { p0: [bx - dir * hr * 0.1, by + hr * 0.1], p1: [bx + dir * hr * 0.95 * L, by + hr * 0.02], p2: [bx + dir * hr * 1.15 * L, by - hr * 0.55 * L], w0: hr * 0.3, w1: hr * 0.08, tipFrom: 0.7 }); }
}
function hornHeight(g, p, hr, kind) {
  const kk = p.bull ? 1.3 : 1;
  if (g.horns === 'long') return hr * 0.55 * (kind === '67' ? 1.6 : 1);
  if (g.horns === 'short') return kind === '67' ? hr * 0.58 * kk : hr * 0.34 * kk;
  if (g.horns === 'bud') return hr * 0.2;
  return 0;
}
function drawEars(P, C, H, p) {
  const ear = (e) => {
    P.shape(leaf(e.base, e.ang, e.len, e.wid, { round: 0.6 }), C.ear, { w: 1 });
    P.shape(leaf([e.base[0] + Math.cos(e.ang) * e.len * 0.22, e.base[1] + Math.sin(e.ang) * e.len * 0.22], e.ang, e.len * 0.6, e.wid * 0.5, { round: 0.6 }), C.earIn, { line: false });
  };
  if (H.kind === '66') [-1, 1].forEach((sd) => ear({ base: [H.cx + sd * H.rx * 0.78, H.cy - H.ry * 0.62], ang: sd < 0 ? Math.PI + 0.42 : -0.42, len: H.hh * 0.3, wid: H.hh * 0.2 }));
  else [-1, 1].forEach((sd) => ear({ base: [H.cx + sd * H.rx * 0.88, H.cy - H.ry * 0.3], ang: sd < 0 ? Math.PI - 0.22 : 0.22, len: H.hh * 0.42, wid: H.hh * 0.27 }));
}
function earReach(H) { return H.kind === '66' ? { x: H.rx * 0.78 + H.hh * 0.3 * Math.cos(0.42), y: H.cy - H.ry * 0.62 - H.hh * 0.3 * Math.sin(0.42) } : { x: H.rx * 0.88 + H.hh * 0.42, y: H.cy - H.ry * 0.42 }; }
// 圓形耳標（我們自己的樣子）：掛在畫面右邊那隻耳朵下緣
function earTag(P, H) {
  const a = 0.22, L = H.hh * 0.42, bx = H.cx + H.rx * 0.88 + Math.cos(a) * L * 0.42, by = H.cy - H.ry * 0.3 + Math.sin(a) * L * 0.42 + H.hh * 0.09;
  const rr = H.hh * 0.075;
  P.line([[bx, by - H.hh * 0.06], [bx, by - rr * 0.6]], '#E9B949', H.hh * 0.03);
  P.ellipse(bx, by + rr * 0.3, rr, rr * 1.05, '#FFD45E', { line: true, w: 0.75 });
  P.ellipse(bx, by + rr * 0.3, rr * 0.34, rr * 0.34, '#E9B949');
}

function drawHead(P, C, g, p, H, r) {
  const hr = H.hh * 0.5;
  drawEars(P, C, H, p);
  const hx = H.kind === '66' ? 0.36 : 0.32;
  [-1, 1].forEach((sd) => { const bx = H.cx + sd * H.rx * hx; hornAt(P, C, g, p, bx, topYAt(H.pts, bx) + 1.5, sd, hr, H.kind); });
  const ch = P.clip(H.pts);
  P.raw(`<path d="${smoothPath(H.pts)}" fill="${C.face}"/><g clip-path="${ch}">`);
  if (g.pattern === 'patches' || g.pattern === 'strawberry') {
    const at = H.kind === '66' ? [H.cx + H.rx * 0.66, H.cy - H.ry * 0.66, H.hh * 0.2] : [H.cx + H.rx * 0.78, H.cy - H.ry * 0.55, H.hh * 0.24];
    paintPattern(P, C, makePattern(g, r, [{ cx: at[0], cy: at[1], r: at[2] }], H.pts));
  }
  if (H.kind === '66') {
    // 下半臉一整條淺橘色寬口鼻，上緣一道淺弧，沒有鼻孔
    // 9966：口鼻只換顏色，沒有深色分界線
    const mpts = superPts(H.cx, H.cy + H.ry * 0.98, H.rx * 1.3, H.ry * 0.62, 2.2, 48);
    P.raw(`<path d="${smoothPath(mpts)}" fill="${C.muzzle}"/>`);
  }
  P.raw('</g>');
  P.raw(`<path d="${smoothPath(H.pts)}" fill="none" stroke="${INK}" stroke-width="${LW}" stroke-linejoin="round"/>`);
  const er = H.hh * (H.kind === '66' ? 0.046 : 0.042) * (p.eyeBig ? 1.2 : 1) * (p.calf ? 1.08 : 1);
  const eyes = H.kind === '66' ? [-1, 1].map((sd) => [H.cx + sd * H.rx * 0.44, H.cy - H.ry * 0.2]) : [-1, 1].map((sd) => [H.cx + sd * H.rx * 0.22, H.cy - H.ry * 0.22]);
  eyes.forEach(([ex, ey]) => {
    P.ellipse(ex, ey, er, er * 1.1, C.eye);
    if (C.dark) P.ellipse(ex + P.lx * er * 0.3, ey - er * 0.35, er * 0.32, er * 0.32, '#FFFFFF', { opacity: 0.85 });
  });
  if (H.kind === '67') {
    // 粉紅橢圓口鼻：在臉的下半、下緣稍微超出下巴；兩個小點鼻孔
    const m = { cx: H.cx, cy: H.cy + H.ry * 0.5, rx: H.rx * 0.66, ry: H.ry * 0.48 };
    P.shape(superPts(m.cx, m.cy, m.rx, m.ry, 2.15, 48), C.muzzle, { w: 0.95 });
    [-1, 1].forEach((sd) => P.ellipse(m.cx + sd * m.rx * 0.34, m.cy - m.ry * 0.12, H.hh * 0.028, H.hh * 0.034, C.nostril));
  }
  // 瀏海：高地牛一片蓬毛垂到眼睛上；傳說牛頭頂三小撮
  if (p.fluffy) {
    const t = H.top - 1.2, ey = eyes[0][1], bt = ey - er * 0.6, w = H.rx * 0.98;
    const pts = [[H.cx + w, bt - H.ry * 0.2]];
    for (let i = 0; i <= 10; i++) { const a = (i / 10) * Math.PI; pts.push([H.cx + Math.cos(a) * w, t + H.ry * 0.25 - Math.sin(a) * H.ry * 0.3]); }
    pts.push([H.cx - w, bt - H.ry * 0.2]);
    for (let i = 0; i < 6; i++) {
      const xa = H.cx - w + (2 * w * i) / 6, xb = H.cx - w + (2 * w * (i + 1)) / 6, m = (xa + xb) / 2;
      pts.push([m, bt + (i === 0 || i === 5 ? 0.35 : 1) * H.ry * 0.14], [xb, bt - H.ry * 0.04]);
    }
    P.shape(pts, C.fringe, { w: 0.85 });
  } else if (p.lightFluff) {
    [-1, 0, 1].forEach((k) => P.shape(leaf([H.cx + k * H.rx * 0.2, H.top + 2.5], -Math.PI / 2 + k * 0.5, H.hh * 0.16, H.hh * 0.11, { round: 0.7 }), C.fringe, { w: 0.8 }));
  }
  if (H.kind === '67') earTag(P, H);
  drawOverlay(P, C, g, H.cx, H.top + 1, H.hh / 40);
  return { hornH: hornHeight(g, p, hr, H.kind), ear: earReach(H) };
}

// ---------- 組裝 ----------
export function renderCow(vkey, g, { x = 0, y = 0, scale = 1, facing = 'left', id = 'cow', sil = false, pose = 'front' } = {}) {
  const V = VARIANTS[vkey];
  const p = plan(g);
  const side = pose === 'side';
  const faceKind = side && V.face === 'ref' ? '66' : '67';
  const C = palette(g, faceKind);
  const mirror = facing === 'right';
  const P = painter({ id, mirror, lw: LW });
  const r = rng(g.seed + 505);
  const s = scale * p.size;
  const f = (v) => Math.round(v * 100) / 100;
  let H, pts, bodyInfo, legPts = [];

  if (side) {
    const B = sideBody(p);
    bodyInfo = B;
    // 頭立在身體前端：9966 的頭頂略高過背、下緣約在身體 70–75% 深
    H = faceKind === '66'
      ? head66(B.xF + p.hh * 0.2, B.topY + p.hh * 1.2 * 0.36 - (p.calf ? p.hh * 0.06 : 0) + (p.bull ? p.D * 0.06 : 0), p)
      : head67(B.xF + p.hh * 0.3, B.topY + p.hh * 0.24 - (p.calf ? p.hh * 0.06 : 0) + (p.bull ? p.D * 0.06 : 0), p);
    // 尾巴
    const tEnd = Math.min(B.bellyY + p.leg * 0.2, B.topY + B.D * 1.02);
    drawTail(P, C, { p0: [B.xR - B.L * 0.03, B.topY + B.D * 0.2], p1: [B.xR + B.D * 0.3, B.topY + B.D * 0.3], p2: [B.xR + B.D * 0.24, tEnd], w: Math.max(1.8, p.legW * 0.22), tuftR: Math.max(3, B.D * 0.09) * (p.fluffy || p.lightFluff ? 1.35 : 1), color: C.coat });
    // 腿：兩對、細、直直站著（走路的動作之後做動畫）
    const top = B.bellyY - B.D * 0.3, w = p.legW * 1.1, hoof = Math.min(w * 0.55, p.leg * 0.4 + 1.5), st = 0;
    const mk = (x0, far, dx) => {
      const b = far ? -1.4 : 0, w0 = w * 0.52, w1 = w * 0.48, xb = x0 + dx;
      return { x: xb, far, bottom: b, hoof, pts: [[x0 - w0, top], [x0 + w0, top], [xb + w1, b - w1 * 0.25], [xb + w1 * 0.95, b], [xb - w1 * 0.95, b], [xb - w1, b - w1 * 0.25]] };
    };
    const legs = [mk(B.xF + B.L * 0.31, true, st * 0.7), mk(B.xR - B.L * 0.27, true, -st * 0.7), mk(B.xF + B.L * 0.19, false, -st), mk(B.xR - B.L * 0.15, false, st)];
    legs.filter((l) => l.far).forEach((l) => drawLeg(P, C, { ...l, fill: C.far }));
    if (p.udder > 0) { const u = p.udder, ux = B.xR - B.L * 0.32; P.shape(superPts(ux, B.bellyY + 1.2 * u, 5 * u, 3.6 * u, 2.2, 24), C.udder, { w: 0.8 }); }
    legs.filter((l) => !l.far).forEach((l) => drawLeg(P, C, { ...l, fill: C.coat }));
    legPts = legs.map((l) => l.pts);
    // 身體
    P.region(B.pts, C.coat, () => {
      paintPattern(P, C, makePattern(g, r, sideSpots(g, B, r), B.pts));
      if (p.marble) marbling(P, B.cx, B.cy, B.rx, B.ry);
    }, { w: 1 });
    pts = B.pts;
  } else {
    const sit = V.frontPose === 'sit';
    const B = frontBody(p, sit);
    bodyInfo = B;
    H = head67(0, B.topY - p.hh * 0.8 * 0.22 - (p.calf ? p.hh * 0.04 : 0), p);
    const w = p.legW * 1.05, hoof = Math.min(w * 0.55, 5);
    if (!sit) {
      // 站著：後腿在兩側後面（顏色深一點）、前腿在胸口下方
      const top = B.bottomY - B.H * 0.25;
      const mk = (x0, far) => { const b = far ? -1.2 : 0, w0 = w * 0.52, w1 = w * 0.5; return { x: x0, far, bottom: b, hoof, pts: [[x0 - w0, top], [x0 + w0, top], [x0 + w1, b - w1 * 0.25], [x0 + w1 * 0.95, b], [x0 - w1 * 0.95, b], [x0 - w1, b - w1 * 0.25]] }; };
      const hind = [mk(-B.W * 0.36, true), mk(B.W * 0.36, true)], fore = [mk(-B.W * 0.16, false), mk(B.W * 0.16, false)];
      hind.forEach((l) => drawLeg(P, C, { ...l, fill: C.far }));
      fore.forEach((l) => drawLeg(P, C, { ...l, fill: C.coat }));
      legPts = [...hind, ...fore].map((l) => l.pts);
    } else {
      // 坐著：後腳從身體底部兩側往外伸，腳尖是深色的蹄
      [-1, 1].forEach((sd) => {
        const fx = sd * B.W * 0.47, fy = -B.H * 0.05, frx = B.W * 0.13, fry = B.H * 0.06;
        const foot = superPts(fx, fy, frx, fry, 2.3, 28);
        const c = P.clip(foot);
        P.raw(`<path d="${smoothPath(foot)}" fill="${C.coat}"/><g clip-path="${c}"><rect x="${sd > 0 ? fx + frx * 0.45 : fx - frx * 1.45}" y="${fy - fry * 2}" width="${frx}" height="${fry * 4}" fill="${C.hoof}"/></g>`);
        P.outline(foot, { w: 0.9 });
        legPts.push(foot);
      });
    }
    P.region(B.pts, C.coat, () => {
      paintPattern(P, C, roundPattern(g, r, frontSpots(g, B, r), B.pts));
      if (p.marble) marbling(P, 0, B.cy, B.rx * 0.9, B.ry);
    }, { w: 1 });
    if (sit) {
      // 坐著的前腳：胸前兩隻細細的小短腳，下端往內收，腳尖是深色的蹄
      [-1, 1].forEach((sd) => {
        const xt = sd * B.W * 0.13, xb = sd * B.W * 0.11, t0 = B.topY + B.H * 0.4, b0 = B.topY + B.H * 0.66, lw2 = B.W * 0.045;
        const leg = [[xt - lw2, t0], [xt + lw2, t0], [xb + lw2 * 0.95, b0 - lw2 * 0.3], [xb + lw2 * 0.85, b0], [xb - lw2 * 0.85, b0], [xb - lw2 * 0.95, b0 - lw2 * 0.3]];
        drawLeg(P, C, { x: xb, far: false, bottom: b0, hoof: lw2 * 0.9, pts: leg, fill: C.coat });
      });
    }
    pts = B.pts;
  }
  const hd = drawHead(P, C, g, p, H, r);

  let svg = P.svg({ x, y, scale: s });
  if (sil) svg = `<g filter="url(#sil)">${svg}</g>`;
  const toScreen = (pt) => [x + (mirror ? -1 : 1) * pt[0] * s, y + pt[1] * s];
  const ht = Math.min(H.top - hd.hornH, hd.ear.y - 2, g.overlay && g.overlay !== 'none' ? H.top - H.hh * 0.32 : Infinity);
  const bb = bbox([pts, H.pts, ...legPts]);
  const hornX = g.horns === 'long' ? H.rx * 0.34 + H.hh * 0.5 * 1.2 * (H.kind === '67' ? 1.6 : 1) : 0;
  const reach = Math.max(hd.ear.x, hornX);
  const fc = toScreen([H.cx, H.cy]);
  const x0 = Math.min(bb.x0, H.cx - reach) - 2;
  const x1 = side ? Math.max(bb.x1, bodyInfo.xR + bodyInfo.D * 0.36) : Math.max(bb.x1, H.cx + reach + 2);
  return {
    svg, p,
    face: { cx: fc[0], cy: fc[1], r: H.hh * 0.62 * s },
    headTop: toScreen([H.cx, ht]),
    shadow: { cx: toScreen([side ? bodyInfo.cx : 0, 0])[0], rx: (side ? bodyInfo.L * 0.62 : bodyInfo.W * 0.62) * s, ry: Math.max(3.5, (side ? bodyInfo.D : bodyInfo.H) * 0.12) * s },
    bbox: { x0, x1, y0: ht - 2, y1: 0 },
    height: -ht * s,
    scale: s,
  };
}

// 剪影濾鏡（塗黑）
export const SIL_DEFS = `<filter id="sil" x="-10%" y="-10%" width="120%" height="120%"><feFlood flood-color="#2A1E1A"/><feComposite in2="SourceAlpha" operator="in"/></filter>`;
