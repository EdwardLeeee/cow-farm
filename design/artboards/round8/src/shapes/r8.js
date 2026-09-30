// R8 牛產生器：線條 B 乾淨中線；側面照 9966、正面照 9967 坐著，兩個角度的臉各照參考圖。
// 第 8 輪依第 7 輪意見修改（原話：「牛身體應該要有曲線，不是橢圓形。正面的臉應該是垂直方向比較長。
//   母牛正面應該有牛奶頭才看得出來是母牛。而且尾巴太長。母牛側面的奶頭很不明顯看不出來世什麼，要嘛拿掉 要嘛讓人看出來是啥」）：
//   身體不再是橢圓：側面由控制點連成有曲線的外框（背微凹、乳用腰角、圓屁股接後腿、肚子在前後腿之間往上收、胸口接前腿），
//     近側兩條腿和身體連成同一條外框（先畫兩倍粗的外框再蓋上填色，只留外緣一圈線）；
//   正面坐著：肩膀、身體兩側、底部兩邊坐下時鼓起的大腿，兩腿中間往上收，露出乳房；
//   正面的臉高大於寬（faceR＝高÷寬，第 8 輪給 1.1／1.25／1.4 三種）；
//   成年母牛兩個角度都看得到粉紅乳房和奶頭（公牛、小牛沒有；肉用小一點）；尾巴短到身體一半高。
// 著作權底線（D13）：只貼近參考圖的比例與特徵；斑點排列、角和耳朵的確切形狀、細部比例是我們自己的，不描圖。
//   我們自己的：正面月牙角、圓頭微垂的耳朵、圓形耳標、斑點排列（沿用第 7 輪，使用者沒有提出修改）。
import {
  painter, leaf, blob, bbox, topYAt, pointInPoly, tail as drawTail, leg as drawLeg, horn as drawHorn, overlay as drawOverlay,
  makePattern, paintPattern, superPts, scallopPts, densify, smoothPath, rng, shade, lum, INK,
} from './q.js';

export const VARIANTS = {
  r8: { key: 'r8', name: '第 8 輪：依意見修改（臉長 B）', faceR: 1.25, scene: 1.1 },
  faceA: { key: 'faceA', name: '正面臉的長度 A 稍長（高÷寬 1.1）', faceR: 1.1, scene: 1.1 },
  faceB: { key: 'faceB', name: '正面臉的長度 B 長（高÷寬 1.25）', faceR: 1.25, scene: 1.1 },
  faceC: { key: 'faceC', name: '正面臉的長度 C 更長（高÷寬 1.4）', faceR: 1.4, scene: 1.1 },
};
const LW = 2.4; // B 乾淨中線

const BASE = { L: 74, D: 42, leg: 11, legW: 8.4, hh: 36, FW: 54, FH: 46 };
// 用途的相對體型（三種都是胖身材）：乳用最高、腿最長；肉用最寬、最深、腿最短
const BUILD = {
  dairy: { L: 0.97, D: 0.9, leg: 1.12, legW: 0.9, udder: 1, head: 0.97, FW: 0.88, FH: 1.06 },
  dual: { L: 1.0, D: 1.0, leg: 1.0, legW: 1.0, udder: 0.85, head: 1.0, FW: 1.0, FH: 1.0 },
  beef: { L: 1.1, D: 1.16, leg: 0.74, legW: 1.3, udder: 0.68, head: 1.05, FW: 1.2, FH: 1.02 },
};

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
  if (calf) { p.size *= 0.585; p.L *= 0.82; p.leg *= 0.9; p.legW *= 1.15; p.hh *= 1.12; p.FH *= 0.92; p.udder = 0; p.hump = 0; p.muscle *= 0.3; }
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
    // 乳房：粉紅袋子＋深一點的奶頭，黑牛也用粉紅，才看得出來
    udder: '#F7B9C0', teat: '#EE97A4', seed: g.seedColor || '#FFE9A8',
  };
}

// 外框下緣在 x 位置的 y（給腿接到身體用）
function bottomYAt(pts, x) {
  let best = null;
  for (let i = 0; i < pts.length; i++) {
    const a = pts[i], b = pts[(i + 1) % pts.length];
    if ((a[0] - x) * (b[0] - x) <= 0 && a[0] !== b[0]) {
      const y = a[1] + ((b[1] - a[1]) * (x - a[0])) / (b[0] - a[0]);
      if (best === null || y > best) best = y;
    }
  }
  return best;
}

// ---------- 頭 ----------
function head66(cx, cy, p) { // 9966：蛋形、上窄下寬；約身體深的 0.84
  const hh = p.hh * 1.2, hw = hh * (p.shortFace ? 0.8 : 0.74), rx = hw / 2, ry = (hh / 2) * (p.shortFace ? 0.95 : 1);
  const pts = superPts(cx, cy, rx, ry, 2.3, 64).map(([x, y]) => { const v = (y - cy) / ry; return [cx + (x - cx) * (1 + 0.11 * Math.max(0, v) - 0.08 * Math.max(0, -v)), y]; });
  return { kind: '66', pts, cx, cy, rx, ry, hh, hw, top: cy - ry, bottom: cy + ry };
}
function head67(cx, cy, p, faceR) { // 9967：高大於寬（faceR＝高÷寬），往下巴收窄；寬度和第 7 輪相同，只加高
  const hw = p.hh * 1.04 * (p.shortFace ? 1.04 : 1), hh = hw * faceR * (p.shortFace ? 0.94 : 1);
  const rx = hw / 2, ry = hh / 2;
  const pts = superPts(cx, cy, rx, ry, 2.6, 64).map(([x, y]) => { const v = (y - cy) / ry; return [cx + (x - cx) * (1 - 0.2 * Math.max(0, v)), y]; });
  return { kind: '67', pts, cx, cy, rx, ry, hh, hw, top: cy - ry, bottom: cy + ry };
}

// ---------- 側面身體（9966）：控制點連成有曲線的外框 ----------
function sideBody(p) {
  const L = p.L * 0.94, D = p.D * 1.22;
  const cx = 0, cy = -p.leg - D / 2, rx = L / 2, ry = D / 2;
  const beef = p.use === 'beef', dairy = p.use === 'dairy';
  const bl = beef ? 0.07 : dairy ? -0.03 : 0; // 肚子：肉用低、乳用收
  const U = [
    [-0.8, -0.9], // 鬐甲前（被頭擋住）
    [-0.45, -0.97 - 0.22 * p.hump], // 鬐甲（公牛肩峰）
    [0.05, -0.92], // 背微凹
    [0.52, -1.0 - (dairy ? 0.07 : 0.01)], // 腰角（乳用明顯）
    [0.84, -0.9], // 尾根
    [0.99 + 0.03 * p.muscle, -0.55], // 屁股
    [1.02 + 0.03 * p.muscle, -0.05], // 大腿後緣
    [0.94, 0.45],
    [0.8, 0.86], // 接到後腿後緣
    [0.58, 1.02], // 後腿前緣上方
    [0.36, 0.86 + bl], // 肚子往上收
    [0.0, 0.9 + bl],
    [-0.36, 0.94 + bl],
    [-0.56, 1.04], // 前腿後緣上方
    [-0.84 - 0.03 * p.muscle, 0.82], // 胸口
    [-1.0 - 0.03 * p.muscle, 0.35],
    [-0.98, -0.3], // 脖子前（被頭擋住）
    [-0.92, -0.72],
  ];
  const ctrl = U.map(([u, v]) => [cx + u * rx, cy + v * ry]);
  const pts = p.fluffy ? scallopPts(densify(ctrl, 2), 0.24, 5) : densify(ctrl, 5);
  return { pts, cx, cy, rx, ry, L, D, topY: cy - ry, bellyY: cy + ry, xF: cx - rx, xR: cx + rx };
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

// ---------- 正面身體（9967 坐著）：肩膀、兩側、底部坐下鼓起的大腿，兩腿中間往上收 ----------
function frontBody(p, arch) {
  const W = p.FW * 1.06, Hb = p.FH * 0.96;
  const bottom = -1, cy = bottom - Hb / 2, rx = W / 2, ry = Hb / 2;
  const sh = p.bull ? 1.16 : p.use === 'beef' ? 1.08 : 1; // 肩膀寬
  const hs = p.use === 'beef' ? 1.04 : p.use === 'dairy' ? 0.97 : 1; // 大腿
  const R = [
    [0.36 * sh, -0.99], [0.56 * sh, -0.86], [0.62 * sh, -0.55], [0.64 * Math.max(1, sh * 0.96), -0.2], // 肩膀、身體兩側
    [0.74 * hs, 0.18], [0.92 * hs, 0.5], [0.97 * hs, 0.78], [0.87 * hs, 0.98], // 坐下鼓起的大腿
    [0.52, 1.0], [0.3, 1.0 - arch * 0.55], // 兩腿中間往上收
  ];
  const right = [[0, -1.0], ...R, [0, 1.0 - arch]];
  const left = R.slice().reverse().map(([u, v]) => [-u, v]);
  const ctrl = [...right, ...left].map(([u, v]) => [u * rx, cy + v * ry]);
  const pts = p.fluffy ? scallopPts(densify(ctrl, 2), 0.24, 5) : densify(ctrl, 5);
  return { pts, cx: 0, cy, rx, ry, W, H: Hb, topY: cy - ry, bottomY: cy + ry, hs };
}
function frontSpots(g, B, r) {
  // 我們自己的排列（沿用第 7 輪）：右上大、左下中、中間上方小、右下被身體邊切掉、下方一顆小的
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

// ---------- 乳房（兩個角度都要看得出來是母牛） ----------
// 側面：粉紅乳房掛在肚子下、後腿前面，兩個看得到的奶頭往下
function udderSide(P, C, cx, top, s) {
  const w = 15 * s, h = 10.5 * s;
  const bag = superPts(cx, top + h * 0.5, w / 2, h / 2, 2.2, 36);
  [-1, 1].forEach((sd) => {
    const tx = cx + sd * w * 0.26, ty = top + h * 0.86;
    P.shape(superPts(tx, ty + 3 * s, 1.9 * s, 3.5 * s, 2.3, 18), C.teat, { w: 0.75 });
  });
  P.shape(bag, C.udder, { w: 0.85 });
  P.arc([[cx - w * 0.3, top + h * 0.36], [cx - w * 0.12, top + h * 0.22]], '#FFFFFF', 1.4 * s, 0.8);
}
// 正面坐著：粉紅乳房在兩條大腿中間，四個奶頭往下，上半被肚子擋住
function udderFront(P, C, cx, top, bottom, s) {
  const w = 20 * s, h = (bottom - top) * 1.05;
  const bag = superPts(cx, top + h * 0.45, w / 2, h / 2, 2.2, 36);
  [[-0.34, 1], [-0.12, 0.9], [0.12, 0.9], [0.34, 1]].forEach(([k, len]) => {
    const tx = cx + k * w, ty = top + h * 0.82;
    P.shape(superPts(tx, ty + 2.6 * s * len, 1.6 * s, 2.9 * s * len, 2.3, 18), C.teat, { w: 0.7 });
  });
  P.shape(bag, C.udder, { w: 0.85 });
  P.arc([[cx - w * 0.28, top + h * 0.3], [cx - w * 0.08, top + h * 0.18]], '#FFFFFF', 1.4 * s, 0.8);
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
function earSpec(H) {
  if (H.kind === '66') return [-1, 1].map((sd) => ({ base: [H.cx + sd * H.rx * 0.78, H.cy - H.ry * 0.62], ang: sd < 0 ? Math.PI + 0.42 : -0.42, len: H.hh * 0.3, wid: H.hh * 0.2 }));
  // 正面：圓頭、微微下垂（我們自己的形狀）
  return [-1, 1].map((sd) => ({ base: [H.cx + sd * H.rx * 0.9, H.cy - H.ry * 0.46], ang: sd < 0 ? Math.PI - 0.22 : 0.22, len: H.hw * 0.33, wid: H.hw * 0.21 }));
}
function drawEars(P, C, H) {
  earSpec(H).forEach((e) => {
    P.shape(leaf(e.base, e.ang, e.len, e.wid, { round: 0.6 }), C.ear, { w: 1 });
    P.shape(leaf([e.base[0] + Math.cos(e.ang) * e.len * 0.22, e.base[1] + Math.sin(e.ang) * e.len * 0.22], e.ang, e.len * 0.6, e.wid * 0.5, { round: 0.6 }), C.earIn, { line: false });
  });
}
function earReach(H) {
  const [, e] = earSpec(H);
  const tip = [e.base[0] + Math.cos(e.ang) * e.len, e.base[1] + Math.sin(e.ang) * e.len];
  return { x: tip[0] - H.cx + 2, y: Math.min(tip[1], e.base[1]) - e.wid * 0.5 };
}
// 圓形耳標（我們自己的樣子）：掛在畫面右邊那隻耳朵下緣
function earTag(P, H) {
  const [, e] = earSpec(H);
  const bx = e.base[0] + Math.cos(e.ang) * e.len * 0.42, by = e.base[1] + Math.sin(e.ang) * e.len * 0.42 + e.wid * 0.36;
  const rr = H.hw * 0.058;
  P.line([[bx, by - rr * 0.9], [bx, by - rr * 0.5]], '#E9B949', H.hw * 0.024);
  P.ellipse(bx, by + rr * 0.3, rr, rr * 1.05, '#FFD45E', { line: true, w: 0.75 });
  P.ellipse(bx, by + rr * 0.3, rr * 0.34, rr * 0.34, '#E9B949');
}

function drawHead(P, C, g, p, H, r) {
  const hr = H.kind === '66' ? H.hh * 0.5 : H.hw * 0.38;
  drawEars(P, C, H);
  const hx = H.kind === '66' ? 0.36 : 0.32;
  [-1, 1].forEach((sd) => { const bx = H.cx + sd * H.rx * hx; hornAt(P, C, g, p, bx, topYAt(H.pts, bx) + 1.5, sd, hr, H.kind); });
  const ch = P.clip(H.pts);
  P.raw(`<path d="${smoothPath(H.pts)}" fill="${C.face}"/><g clip-path="${ch}">`);
  if (H.kind === '66' && (g.pattern === 'patches' || g.pattern === 'strawberry')) {
    paintPattern(P, C, makePattern(g, r, [{ cx: H.cx + H.rx * 0.66, cy: H.cy - H.ry * 0.66, r: H.hh * 0.2 }], H.pts));
  }
  if (H.kind === '67' && (g.pattern === 'patches' || g.pattern === 'strawberry')) {
    paintPattern(P, C, makePattern(g, r, [{ cx: H.cx + H.rx * 0.8, cy: H.cy - H.ry * 0.55, r: H.hw * 0.2 }], H.pts));
  }
  if (H.kind === '66') {
    // 9966：口鼻只換顏色，沒有深色分界線
    const mpts = superPts(H.cx, H.cy + H.ry * 0.98, H.rx * 1.3, H.ry * 0.62, 2.2, 48);
    P.raw(`<path d="${smoothPath(mpts)}" fill="${C.muzzle}"/>`);
  }
  P.raw('</g>');
  P.raw(`<path d="${smoothPath(H.pts)}" fill="none" stroke="${INK}" stroke-width="${LW}" stroke-linejoin="round"/>`);
  const er = (H.kind === '66' ? H.hh * 0.046 : H.hw * 0.042) * (p.eyeBig ? 1.2 : 1) * (p.calf ? 1.08 : 1);
  const eyes = H.kind === '66' ? [-1, 1].map((sd) => [H.cx + sd * H.rx * 0.44, H.cy - H.ry * 0.2]) : [-1, 1].map((sd) => [H.cx + sd * H.rx * 0.24, H.cy - H.ry * 0.14]);
  eyes.forEach(([ex, ey]) => {
    P.ellipse(ex, ey, er, er * 1.1, C.eye);
    if (C.dark) P.ellipse(ex + P.lx * er * 0.3, ey - er * 0.35, er * 0.32, er * 0.32, '#FFFFFF', { opacity: 0.85 });
  });
  if (H.kind === '67') {
    // 粉紅橢圓口鼻：在臉的下半、快到下巴；兩個小點鼻孔
    const m = { cx: H.cx, cy: H.cy + H.ry * 0.56, rx: H.rx * 0.7, ry: H.ry * 0.36 };
    P.shape(superPts(m.cx, m.cy, m.rx, m.ry, 2.15, 48), C.muzzle, { w: 0.95 });
    [-1, 1].forEach((sd) => P.ellipse(m.cx + sd * m.rx * 0.34, m.cy - m.ry * 0.1, H.hw * 0.028, H.hw * 0.034, C.nostril));
  }
  // 瀏海：高地牛一片蓬毛垂到眼睛上；傳說牛頭頂三小撮
  if (p.fluffy) {
    const t = H.top - 1.2, ey = eyes[0][1], bt = ey - er * 0.6, w = H.rx * 0.98;
    const pts = [[H.cx + w, bt - H.ry * 0.2]];
    for (let i = 0; i <= 10; i++) { const a = (i / 10) * Math.PI; pts.push([H.cx + Math.cos(a) * w, t + H.ry * 0.25 - Math.sin(a) * H.ry * 0.3]); }
    pts.push([H.cx - w, bt - H.ry * 0.2]);
    for (let i = 0; i < 6; i++) {
      const xa = H.cx - w + (2 * w * i) / 6, xb = H.cx - w + (2 * w * (i + 1)) / 6, m = (xa + xb) / 2;
      pts.push([m, bt + (i === 0 || i === 5 ? 0.35 : 1) * H.ry * 0.12], [xb, bt - H.ry * 0.04]);
    }
    P.shape(pts, C.fringe, { w: 0.85 });
  } else if (p.lightFluff) {
    const s = H.kind === '66' ? H.hh : H.hw;
    [-1, 0, 1].forEach((k) => P.shape(leaf([H.cx + k * H.rx * 0.2, H.top + 2.5], -Math.PI / 2 + k * 0.5, s * 0.16, s * 0.11, { round: 0.7 }), C.fringe, { w: 0.8 }));
  }
  if (H.kind === '67') earTag(P, H);
  drawOverlay(P, C, g, H.cx, H.top + 1, (H.kind === '66' ? H.hh : H.hw) / 40);
  return { hornH: hornHeight(g, p, hr, H.kind), ear: earReach(H) };
}

// ---------- 組裝 ----------
export function renderCow(vkey, g, { x = 0, y = 0, scale = 1, facing = 'left', id = 'cow', sil = false, pose = 'front' } = {}) {
  const V = VARIANTS[vkey];
  const p = plan(g);
  const side = pose === 'side';
  const faceKind = side ? '66' : '67';
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
    H = head66(B.xF + p.hh * 0.2, B.topY + p.hh * 1.2 * 0.36 - (p.calf ? p.hh * 0.06 : 0) + (p.bull ? p.D * 0.06 : 0), p);
    // 尾巴：短，末端大約在身體一半高
    const tEnd = B.topY + B.D * 0.56;
    drawTail(P, C, { p0: [B.xR - B.L * 0.07, B.topY + B.D * 0.08], p1: [B.xR + B.D * 0.22, B.topY + B.D * 0.14], p2: [B.xR + B.D * 0.17, tEnd], w: Math.max(1.8, p.legW * 0.22), tuftR: Math.max(2.8, B.D * 0.075) * (p.fluffy || p.lightFluff ? 1.3 : 1), color: C.coat });
    // 腿：遠側兩條在後面（顏色深一點）；近側兩條和身體連成同一條外框
    const w = p.legW * 1.12, hoof = Math.min(w * 0.55, p.leg * 0.4 + 1.5);
    const legAt = (u, far) => {
      const xc = B.cx + u * B.rx, bot = far ? -1.4 : 0;
      const top = (bottomYAt(B.pts, xc) ?? B.bellyY) - 3;
      return { x: xc, far, bottom: bot, hoof, pts: [[xc - w * 0.5, top], [xc + w * 0.5, top], [xc + w * 0.48, bot - w * 0.3], [xc + w * 0.44, bot], [xc - w * 0.44, bot], [xc - w * 0.48, bot - w * 0.3]] };
    };
    const far = [legAt(-0.42, true), legAt(0.42, true)], near = [legAt(-0.66, false), legAt(0.66, false)];
    far.forEach((l) => drawLeg(P, C, { ...l, fill: C.far }));
    if (p.udder > 0) udderSide(P, C, B.cx + B.rx * 0.3, (bottomYAt(B.pts, B.cx + B.rx * 0.3) ?? B.bellyY) - 4.5, 0.72 + 0.32 * p.udder);
    // 身體＋近側腿：先畫兩倍粗的外框，再蓋上填色，只留外緣一圈線（腿和身體之間沒有分界線）
    P.raw(`<path d="${smoothPath(B.pts)}" fill="${C.coat}" stroke="${INK}" stroke-width="${f(LW * 2)}" stroke-linejoin="round"/>`);
    near.forEach((l) => P.raw(`<path d="${smoothPath(l.pts)}" fill="${C.coat}" stroke="${INK}" stroke-width="${f(LW * 2)}" stroke-linejoin="round"/>`));
    const cb = P.clip(B.pts);
    P.raw(`<path d="${smoothPath(B.pts)}" fill="${C.coat}"/><g clip-path="${cb}">`);
    paintPattern(P, C, makePattern(g, r, sideSpots(g, B, r), B.pts));
    if (p.marble) marbling(P, B.cx, B.cy, B.rx, B.ry);
    P.raw('</g>');
    near.forEach((l) => {
      const c = P.clip(l.pts);
      P.raw(`<path d="${smoothPath(l.pts)}" fill="${C.coat}"/><g clip-path="${c}"><rect x="${f(l.x - w)}" y="${f(l.bottom - l.hoof)}" width="${f(w * 2)}" height="${f(l.hoof + 4)}" fill="${C.hoof}"/></g>`);
    });
    legPts = [...far, ...near].map((l) => l.pts);
    pts = B.pts;
  } else {
    const hasUdder = p.udder > 0;
    const B = frontBody(p, hasUdder ? 0.34 : 0.12);
    bodyInfo = B;
    H = head67(0, 0, p, V.faceR);
    H = head67(0, B.topY - H.ry * 0.4 - (p.calf ? p.hh * 0.04 : 0), p, V.faceR);
    // 坐著：後腳從大腿底部往外伸，腳尖是深色的蹄（在身體後面先畫）
    [-1, 1].forEach((sd) => {
      const fx = sd * B.W * 0.47 * B.hs, fy = -B.H * 0.05, frx = B.W * 0.13, fry = B.H * 0.06;
      const foot = superPts(fx, fy, frx, fry, 2.3, 28);
      const c = P.clip(foot);
      P.raw(`<path d="${smoothPath(foot)}" fill="${C.coat}"/><g clip-path="${c}"><rect x="${f(sd > 0 ? fx + frx * 0.45 : fx - frx * 1.45)}" y="${f(fy - fry * 2)}" width="${f(frx)}" height="${f(fry * 4)}" fill="${C.hoof}"/></g>`);
      P.outline(foot, { w: 0.9 });
      legPts.push(foot);
    });
    // 乳房：在兩條大腿中間，上半被肚子擋住
    if (hasUdder) udderFront(P, C, 0, B.bottomY - B.H * 0.2, B.bottomY + 0.5, 0.72 + 0.32 * p.udder);
    P.region(B.pts, C.coat, () => {
      paintPattern(P, C, roundPattern(g, r, frontSpots(g, B, r), B.pts));
      if (p.marble) marbling(P, 0, B.cy, B.rx * 0.9, B.ry);
    }, { w: 1 });
    // 大腿和肚子的分界：兩條往外彎的弧線
    [-1, 1].forEach((sd) => P.arc([[sd * B.rx * 0.68, B.cy + B.ry * 0.36], [sd * B.rx * 0.58, B.cy + B.ry * 0.62], [sd * B.rx * 0.66, B.cy + B.ry * 0.9]], INK, LW * 0.8, 1));
    // 胸前兩隻細細的小短腳，下端往內收，腳尖是深色的蹄
    [-1, 1].forEach((sd) => {
      const xt = sd * B.W * 0.13, xb = sd * B.W * 0.11, t0 = B.topY + B.H * 0.42, b0 = B.topY + B.H * 0.7, lw2 = B.W * 0.045;
      const lp = [[xt - lw2, t0], [xt + lw2, t0], [xb + lw2 * 0.95, b0 - lw2 * 0.3], [xb + lw2 * 0.85, b0], [xb - lw2 * 0.85, b0], [xb - lw2 * 0.95, b0 - lw2 * 0.3]];
      drawLeg(P, C, { x: xb, far: false, bottom: b0, hoof: lw2 * 0.9, pts: lp, fill: C.coat });
    });
    pts = B.pts;
  }
  const hd = drawHead(P, C, g, p, H, r);

  let svg = P.svg({ x, y, scale: s });
  if (sil) svg = `<g filter="url(#sil)">${svg}</g>`;
  const toScreen = (pt) => [x + (mirror ? -1 : 1) * pt[0] * s, y + pt[1] * s];
  const ht = Math.min(H.top - hd.hornH, hd.ear.y - 2, g.overlay && g.overlay !== 'none' ? H.top - (H.kind === '66' ? H.hh : H.hw) * 0.32 : Infinity);
  const bb = bbox([pts, H.pts, ...legPts]);
  const hr = H.kind === '66' ? H.hh * 0.5 : H.hw * 0.38;
  const hornX = g.horns === 'long' ? H.rx * 0.34 + hr * 1.2 * (H.kind === '67' ? 1.6 : 1) : 0;
  const reach = Math.max(hd.ear.x, hornX);
  const fc = toScreen([H.cx, H.cy]);
  const x0 = Math.min(bb.x0, H.cx - reach) - 2;
  const x1 = side ? Math.max(bb.x1, bodyInfo.xR + bodyInfo.D * 0.3) : Math.max(bb.x1, H.cx + reach + 2);
  return {
    svg, p,
    face: { cx: fc[0], cy: fc[1], r: (H.kind === '66' ? H.hh : H.hw) * 0.62 * s },
    headTop: toScreen([H.cx, ht]),
    shadow: { cx: toScreen([side ? bodyInfo.cx : 0, 0])[0], rx: (side ? bodyInfo.L * 0.62 : bodyInfo.W * 0.62) * s, ry: Math.max(3.5, (side ? bodyInfo.D : bodyInfo.H) * 0.12) * s },
    bbox: { x0, x1, y0: ht - 2, y1: 0 },
    height: -ht * s,
    scale: s,
  };
}

// 剪影濾鏡（塗黑）
export const SIL_DEFS = `<filter id="sil" x="-10%" y="-10%" width="120%" height="120%"><feFlood flood-color="#2A1E1A"/><feComposite in2="SourceAlpha" operator="in"/></filter>`;
