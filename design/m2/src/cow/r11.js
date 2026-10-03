// M2 牛產生器：第 11 輪 r11.js（D19 定案）的複製。第 11 輪的 10 種畫法完全不動（harness/cowcheck.mjs 檢查），
// 只加新品種用的畫法：星星斑（stars）、稻穗紋（rice）、頭頂稻穗（overlay rice）、肉牛捲毛（curly）、淺色毛的光澤（lightShine）。
// ---- 以下是第 11 輪原本的說明 ----
// R11 牛產生器：以第 10 輪（r10.js）為底，套用第 10 輪的選擇與企劃書 v0.2 的新名單。
// 第 10 輪選擇（原話）：01「不如就肚子中間劃一圈沒有框的粉紅色就代表乳房，你試試看」、02「C 黑亮加短角」、03「B 毛改炭灰」
//   乳房：正面肚子中間一塊沒有外框的粉紅圓（不畫奶頭），只畫在成年母乳牛身上（v0.2）；大小給三種：udderSize＝圓的直徑÷身體寬
//   和牛：黑亮（白色亮光）加短角——角由基因推：肉牛＋C 有短角（D18）
//   黑牛：近黑的毛改炭灰、線條改 #1C1311（深色的毛都用這個更深的線）
//   v0.2：兼用改耕牛（draft）；耕牛沒有 A、C 的有肩上小肩峰（台灣黃牛系）；耕牛＋C 是向後彎的水牛角
//   其他照第 10 輪：側面不畫乳房、正面臉長 A（1.1）、C 光澤＝一道白色亮光、身體曲線、短尾巴、線條 B、著作權底線（D13）。
import {
  painter, leaf, blob, bbox, topYAt, pointInPoly, tail as drawTail, leg as drawLeg, horn as drawHorn, overlay as drawOverlay,
  makePattern, paintPattern, superPts, scallopPts, densify, smoothPath, rng, shade, mix, lum, INK,
} from './q.js';

const mk = (key, name, o) => ({ key, name, faceR: 1.1, scene: 1.04, udderSize: 0.28, ...o });
export const VARIANTS = {
  r11: mk('r11', '第 11 輪：依意見修改（乳房中）', {}),
  udderM: mk('udderM', '乳房：中（直徑約身體寬的 28%）', { udderSize: 0.28 }),
  udderS: mk('udderS', '乳房：小（直徑約身體寬的 20%）', { udderSize: 0.2 }),
  udderL: mk('udderL', '乳房：大（直徑約身體寬的 36%）', { udderSize: 0.36 }),
};
const LW = 2.4; // B 乾淨中線

const BASE = { L: 74, D: 42, leg: 11, legW: 8.4, hh: 36, FW: 54, FH: 46 };
// 用途的相對體型（三種都是胖身材）：乳牛最高、腿最長；肉牛最寬、最深、腿最短；耕牛中間
const BUILD = {
  dairy: { L: 0.97, D: 0.9, leg: 1.12, legW: 0.9, udder: 1, head: 0.97, FW: 0.88, FH: 1.06 },
  draft: { L: 1.0, D: 1.0, leg: 1.0, legW: 1.0, udder: 0, head: 1.0, FW: 1.0, FH: 1.0 },
  beef: { L: 1.1, D: 1.16, leg: 0.74, legW: 1.3, udder: 0, head: 1.05, FW: 1.2, FH: 1.02 },
};

export function plan(g) {
  const b = BUILD[g.use] || BUILD.draft;
  const t = g.traits || {};
  const bull = g.sex === 'bull', calf = g.age === 'calf';
  const p = {
    use: g.use, bull, calf, size: 1,
    L: BASE.L * b.L, D: BASE.D * b.D, leg: BASE.leg * b.leg, legW: BASE.legW * b.legW, hh: BASE.hh * b.head,
    FW: BASE.FW * b.FW, FH: BASE.FH * b.FH,
    udder: b.udder, hump: 0, crest: 0, muscle: g.use === 'beef' ? 1 : 0,
    fluffy: !!t.A && !g.legendFluff, lightFluff: !!g.legendFluff, eyeBig: !!t.B, shortFace: !!t.B, gloss: !!t.C,
  };
  if (g.use === 'draft' && !t.A && !t.C) p.hump = 1; // 台灣黃牛系：肩上小肩峰（像瘤牛那樣圓圓的一塊）
  if (p.fluffy) { p.L *= 1.06; p.D *= 1.06; p.leg *= 0.78; p.FW *= 1.08; } // 長毛：更低、更寬
  if (t.B) { p.size *= 0.9; p.hh *= 1.02; } // 淡色：骨架小一號、臉短、眼大
  if (t.C) p.muscle += 0.4;
  if (bull) { p.size *= 1.3; p.crest = 1; p.hh *= 1.04; p.udder = 0; p.FW *= 1.06; } // 公牛更大（約母牛的 1.2 倍）、肩頸隆起
  if (!bull && !calf) { p.size *= 1.08; p.FW *= 1.12; p.FH *= 1.1; } // 成年母牛放大一點
  if (calf) { p.size *= 0.63; p.L *= 0.82; p.leg *= 0.9; p.legW *= 1.15; p.hh *= 1.12; p.FH *= 1.08; p.udder = 0; p.hump *= 0.4; p.crest = 0; p.muscle *= 0.3; }
  return p;
}

function palette(g, faceKind) {
  let coat = g.coat;
  const dark = lum(coat) < 0.12;
  // 黑牛（第 10 輪 03-B）：近黑的毛改成炭灰；深色的毛線條都改更深，線和毛分得開
  let line = INK;
  if (dark) { if (lum(coat) < 0.04) coat = mix(coat, '#8C8692', 0.36); line = '#1C1311'; }
  return {
    coat, dark, line, pat: g.patternColor || coat,
    far: shade(coat, dark ? 0.06 : -0.08),
    face: g.faceColor || coat,
    ear: g.earColor === 'pattern' ? g.patternColor : coat,
    earIn: dark ? '#C99A94' : '#F6BDB4',
    // 9966 是淺橘色橫條口鼻；9967 是粉紅橢圓口鼻
    muzzle: faceKind === '66' ? (dark ? '#D1ABA3' : '#F7CDB5') : (dark ? '#D4A5A8' : '#F7C3C6'),
    nostril: dark ? '#8E5F63' : '#C98088',
    eye: dark ? '#140D0D' : '#2E1D19',
    hoof: dark ? '#1C1414' : '#5A4038', hoofHi: dark ? '#1C1414' : '#5A4038',
    horn: g.hornColor || (g.horns === 'buffalo' ? '#C9BEB2' : '#FFF1CF'), hornTip: g.hornTip || (g.horns === 'buffalo' ? '#857A6F' : '#E6C98F'),
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
    [-0.45, -0.97 - 0.12 * p.crest - 0.08 * p.hump], // 鬐甲（公牛的肩頸隆起）
    [-0.34, -0.99 - 0.22 * p.hump - 0.16 * p.crest], // 台灣黃牛系的肩峰：頭後面一塊圓圓的隆起（寬、頂端圓）
    [-0.22, -1.0 - 0.34 * p.hump - 0.08 * p.crest],
    [-0.09, -0.97 - 0.26 * p.hump],
    [0.02, -0.93 - 0.08 * p.hump],
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
    [0.48 * sh, -0.99], [0.62 * sh, -0.84], [0.66 * sh, -0.5], [0.68 * Math.max(1, sh * 0.96), -0.15], // 肩膀、身體兩側（梯形，不要像斗篷）
    [0.78 * hs, 0.2], [0.93 * hs, 0.5], [0.97 * hs, 0.78], [0.87 * hs, 0.98], // 坐下鼓起的大腿
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
// C 光澤：一道乾淨的白色亮光（ceo 2026-09-30 決定）；淺色的毛看不出來就不畫
function shineSide(P, B, halo = null) {
  const { cx, topY, rx, D } = B, lx = P.lx;
  const a1 = [[cx + lx * rx * 0.42, topY + D * 0.2], [cx + lx * rx * 0.12, topY + D * 0.11], [cx - lx * rx * 0.24, topY + D * 0.12]];
  const a2 = [[cx - lx * rx * 0.4, topY + D * 0.15], [cx - lx * rx * 0.52, topY + D * 0.22]];
  if (halo) { P.arc(a1, halo, D * 0.07 + D * 0.05, 1); P.arc(a2, halo, D * 0.06 + D * 0.05, 1); }
  P.arc(a1, '#FFFFFF', D * 0.07, halo ? 1 : 0.9);
  P.arc(a2, '#FFFFFF', D * 0.06, halo ? 1 : 0.9);
}
// 正面：亮光在額頭左上（頭是正面最大、最明顯的一塊）
function shineFront(P, H, halo = null) {
  const lx = P.lx;
  const a1 = [[H.cx + lx * H.rx * 0.66, H.cy - H.ry * 0.3], [H.cx + lx * H.rx * 0.52, H.cy - H.ry * 0.62], [H.cx + lx * H.rx * 0.22, H.cy - H.ry * 0.82]];
  const a2 = [[H.cx + lx * H.rx * 0.02, H.cy - H.ry * 0.86], [H.cx - lx * H.rx * 0.12, H.cy - H.ry * 0.86]];
  if (halo) { P.arc(a1, halo, H.hw * 0.065 + H.hw * 0.045, 1); P.arc(a2, halo, H.hw * 0.06 + H.hw * 0.045, 1); }
  P.arc(a1, '#FFFFFF', H.hw * 0.065, halo ? 1 : 0.9);
  P.arc(a2, '#FFFFFF', H.hw * 0.06, halo ? 1 : 0.9);
}
// ---------- 乳房（只畫在成年母乳牛的正面） ----------
// 正面坐著：肚子中間一塊沒有外框的粉紅圓，代表乳房（第 10 輪使用者提議）；不畫奶頭
function udderPink(P, C, cx, cy, W, size) {
  const r = (W * size) / 2;
  P.ellipse(cx, cy, r, r * 0.86, C.udder);
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
  // 水牛角（耕牛＋C）：又粗又大，往外長再往上、往後彎回來，像兩個大月牙
  if (g.horns === 'buffalo') { const L = kind === '67' ? 1.25 : 1; return drawHorn(P, hc, { p0: [bx - dir * hr * 0.12, by + hr * 0.14], p1: [bx + dir * hr * 1.45 * L, by + hr * 0.1], p2: [bx + dir * hr * 0.95 * L, by - hr * 0.62 * L], w0: hr * 0.46, w1: hr * 0.09, tipFrom: 0.72 }); }
}
function hornHeight(g, p, hr, kind) {
  const kk = p.bull ? 1.3 : 1;
  if (g.horns === 'long') return hr * 0.55 * (kind === '67' ? 1.6 : 1);
  if (g.horns === 'buffalo') return hr * 0.62 * (kind === '67' ? 1.25 : 1);
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
  if (g.pattern === 'bolt') { // 第 15 輪草稿 宙斯牛：額頭一道小閃電
    const k = H.kind === '66' ? H.hh : H.hw;
    bolt(P, H.cx, H.cy - H.ry * (H.kind === '66' ? 0.46 : 0.5), k * 0.3, 0.2, g.patternColor, g.patternEdge || shade(g.patternColor, -0.25));
  }
  if (g.pattern === 'stars') { // M2 星空牛：額頭一顆小星星（在亮光的另一邊）
    const k = H.kind === '66' ? H.hh : H.hw;
    star(P, H.cx - P.lx * H.rx * 0.36, H.cy - H.ry * (H.kind === '66' ? 0.5 : 0.52), k * 0.1, g.patternColor);
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
  if (g.overlay === 'rice') riceSprig(P, H.cx, H.top + 1, ((H.kind === '66' ? H.hh : H.hw) / 40) * 1.35);
  return { hornH: hornHeight(g, p, hr, H.kind), ear: earReach(H) };
}

// ---------- M2 新品種的畫法 ----------
// 五角星（圓角）：星空牛的斑點
function star(P, cx, cy, r, color) {
  const pts = [];
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 5, rr = i % 2 ? r * 0.46 : r;
    pts.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]);
  }
  const d = `M${pts.map(([x, y]) => `${Math.round(x * 100) / 100},${Math.round(y * 100) / 100}`).join('L')}Z`;
  P.raw(`<path d="${d}" fill="${color}" stroke="${color}" stroke-width="${Math.round(r * 0.28 * 100) / 100}" stroke-linejoin="round"/>`);
}
// 四角小亮點
function twinkle(P, cx, cy, r, color) {
  const f = (v) => Math.round(v * 100) / 100, q = r * 0.2;
  P.raw(`<path d="M${f(cx)},${f(cy - r)}Q${f(cx + q)},${f(cy - q)} ${f(cx + r)},${f(cy)}Q${f(cx + q)},${f(cy + q)} ${f(cx)},${f(cy + r)}Q${f(cx - q)},${f(cy + q)} ${f(cx - r)},${f(cy)}Q${f(cx - q)},${f(cy - q)} ${f(cx)},${f(cy - r)}Z" fill="${color}"/>`);
}
// 一串稻穗（身上的稻穗紋）：稈子往上長再往一邊垂下，穀粒沿著垂下那段兩邊交錯
function riceEar(P, p0, p1, p2, size, color, stemW) {
  const at = (t) => [(1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]];
  const stem = []; for (let i = 0; i <= 10; i++) stem.push(at(i / 10));
  P.arc(stem, color, stemW, 1);
  for (let i = 0, t = 0.42; t <= 1.001; i++, t += 0.095) {
    const [x, y] = at(t), [x2, y2] = at(Math.min(1, t + 0.02)), ang = Math.atan2(y2 - y, x2 - x), sd = i % 2 ? 1 : -1;
    const a = ang + sd * 0.62;
    P.ellipse(x + Math.cos(a) * size * 0.7, y + Math.sin(a) * size * 0.7, size * 0.95, size * 0.52, color, { rot: a });
  }
  const [tx, ty] = at(1);
  P.ellipse(tx, ty, size * 0.8, size * 0.5, color, { rot: Math.atan2(p2[1] - p1[1], p2[0] - p1[0]) });
}
// 頭頂一小束稻穗（金穗牛）：三根綠稈、垂下的金黃穀粒，有描邊
function riceSprig(P, cx, top, s = 1) {
  const base = [cx, top + 2 * s];
  const ears = [[-1, 9, 0.9], [0.15, 13, 1], [1, 9.5, 0.9]];
  ears.forEach(([dir, h, k]) => {
    const p0 = [base[0] + dir * 1.2 * s, base[1]], p1 = [base[0] + dir * 3.5 * s, base[1] - h * s], p2 = [base[0] + dir * 8.5 * s + (dir >= 0 ? 3 : -3) * s, base[1] - h * s * 0.55];
    const at = (t) => [(1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]];
    const stem = []; for (let i = 0; i <= 8; i++) stem.push(at(i / 8));
    P.line(stem, '#8DBA4E', 1.7 * s);
    for (let i = 0, t = 0.5; t <= 1.001; i++, t += 0.125) {
      const [x, y] = at(t), [x2, y2] = at(Math.min(1, t + 0.02)), ang = Math.atan2(y2 - y, x2 - x), a = ang + (i % 2 ? 1 : -1) * 0.7;
      P.ellipse(x + Math.cos(a) * 1.5 * s * k, y + Math.sin(a) * 1.5 * s * k, 2.1 * s * k, 1.3 * s * k, '#FFD35C', { rot: a, line: true, w: 0.45 });
    }
  });
}
// 捲毛（肉牛長毛）：身上一個個小捲，深色毛用淺一點的線、淺色毛用深一點的線
function curls(P, C, r, B, pose) {
  const col = C.dark ? shade(C.coat, 0.2) : shade(C.coat, -0.13);
  const f = (v) => Math.round(v * 100) / 100;
  const size = pose === 'side' ? B.D * 0.07 : B.W * 0.055, w = size * 0.42;
  const us = pose === 'side' ? [-0.62, -0.36, -0.1, 0.16, 0.42, 0.68] : [-0.6, -0.3, 0, 0.3, 0.6];
  const vs = pose === 'side' ? [-0.62, -0.18, 0.26, 0.66] : [-0.66, -0.3, 0.06, 0.42, 0.74];
  vs.forEach((v, j) => us.forEach((u) => {
    const x = (pose === 'side' ? B.cx + (u + (j % 2) * 0.13) * B.rx : (u + (j % 2) * 0.15) * B.rx) + (r() - 0.5) * size;
    const y = B.cy + v * B.ry + (r() - 0.5) * size;
    if (![[0, 0], [size * 1.6, 0], [-size * 1.6, 0], [0, size * 1.6], [0, -size * 1.6]].every(([dx, dy]) => pointInPoly(B.pts, x + dx, y + dy))) return;
    P.raw(`<path d="M${f(x - size * 0.9)},${f(y + size * 0.1)}a${f(size * 0.62)},${f(size * 0.62)} 0 1 1 ${f(size * 1.05)},${f(size * 0.45)}" fill="none" stroke="${col}" stroke-width="${f(w)}" stroke-linecap="round"/>`);
  }));
}
// ---------- 第 15 輪草稿：特殊牛的花紋（v0.3 第 13.3 節；使用者還沒核准，24 種和雜種牛都不會用到） ----------
// 不畫任何宗教符號：閃電（宙斯牛）、祥雲只當裝飾（青牛）、金色捲紋（聖白牛，額頭不加記號）
const r2 = (v) => Math.round(v * 100) / 100;
// 一道閃電（Z 字形）：(x, y) 中心、s 長度、rot 轉幾度（弧度）
function bolt(P, x, y, s, rot, color, edge) {
  const pts = [[-0.2, -0.5], [0.18, -0.5], [0.03, -0.1], [0.24, -0.1], [-0.16, 0.5], [-0.03, 0.05], [-0.24, 0.05]];
  const c = Math.cos(rot), sn = Math.sin(rot);
  const d = `M${pts.map(([u, v]) => `${r2(x + (u * c - v * sn) * s)},${r2(y + (u * sn + v * c) * s)}`).join('L')}Z`;
  P.raw(`<path d="${d}" fill="${color}" stroke="${edge}" stroke-width="${r2(s * 0.05)}" stroke-linejoin="round"/>`);
}
// 祥雲：三個圓鼓起來、底部平，右邊捲一圈；dir 1 往右捲、-1 往左
function cloudMark(P, x, y, s, dir, fill, line) {
  P.raw(`<g transform="translate(${r2(x)} ${r2(y)}) scale(${r2(dir * s)} ${r2(s)})">`
    + `<path d="M-0.9 0.2C-1.08 0.2 -1.12 -0.1 -0.86 -0.18C-0.86 -0.46 -0.5 -0.56 -0.32 -0.38C-0.25 -0.74 0.26 -0.76 0.34 -0.4C0.56 -0.56 0.93 -0.38 0.86 -0.05C1.06 0 1.03 0.2 0.85 0.2Z" fill="${fill}"/>`
    + `<path d="M0.85 0.2C1.28 0.22 1.34 -0.26 1.06 -0.32C0.88 -0.36 0.8 -0.14 0.97 -0.07" fill="none" stroke="${fill}" stroke-width="0.14" stroke-linecap="round"/>`
    + `<path d="M-0.56 -0.04C-0.42 -0.22 -0.2 -0.2 -0.12 -0.04M0.1 -0.12C0.26 -0.32 0.52 -0.26 0.56 -0.04" fill="none" stroke="${line}" stroke-width="0.08" stroke-linecap="round"/></g>`);
}
// 金色捲紋：一條 S 形的藤，兩頭捲起來，中間兩片小葉子
function goldScroll(P, x, y, s, dir, color) {
  P.raw(`<g transform="translate(${r2(x)} ${r2(y)}) scale(${r2(dir * s)} ${r2(s)})" fill="none" stroke="${color}" stroke-linecap="round">`
    + `<path d="M-1 0.12C-0.62 -0.52 -0.02 0.52 0.5 -0.08C0.76 -0.4 1.08 -0.2 0.98 0.06C0.9 0.24 0.68 0.16 0.72 0.02" stroke-width="0.13"/>`
    + `<path d="M-1 0.12C-1.12 0.32 -0.86 0.42 -0.8 0.26" stroke-width="0.11"/>`
    + `<path d="M-0.36 -0.1C-0.34 -0.36 -0.14 -0.42 -0.06 -0.36C-0.12 -0.18 -0.24 -0.1 -0.36 -0.1Z" fill="${color}" stroke-width="0.04"/>`
    + `<path d="M0.2 0.14C0.3 0.38 0.5 0.4 0.56 0.32C0.46 0.16 0.32 0.12 0.2 0.14Z" fill="${color}" stroke-width="0.04"/></g>`);
}
function paintSpecial(P, g, pose, B) {
  const side = pose === 'side', col = g.patternColor, edge = g.patternEdge || shade(col, -0.25);
  if (g.pattern === 'bolt') {
    if (side) {
      const { cx, cy, rx, ry, D } = B;
      bolt(P, cx + rx * 0.08, cy - ry * 0.05, D * 0.62, -0.32, col, edge);
      bolt(P, cx + rx * 0.62, cy + ry * 0.12, D * 0.42, -0.22, col, edge);
      bolt(P, cx - rx * 0.5, cy + ry * 0.2, D * 0.36, -0.42, col, edge);
    } else bolt(P, B.rx * 0.34, B.cy + B.ry * 0.05, B.W * 0.36, -0.28, col, edge);
  }
  if (g.pattern === 'cloud') {
    if (side) {
      const { cx, cy, rx, ry, D } = B;
      cloudMark(P, cx - rx * 0.22, cy - ry * 0.18, D * 0.3, 1, col, edge);
      cloudMark(P, cx + rx * 0.55, cy + ry * 0.28, D * 0.24, -1, col, edge);
      cloudMark(P, cx + rx * 0.12, cy + ry * 0.62, D * 0.16, 1, col, edge);
    } else {
      cloudMark(P, -B.rx * 0.34, B.cy + B.ry * 0.08, B.W * 0.17, 1, col, edge);
      cloudMark(P, B.rx * 0.4, B.cy + B.ry * 0.42, B.W * 0.13, -1, col, edge);
    }
  }
  if (g.pattern === 'gold') {
    if (side) {
      const { cx, cy, rx, ry, D } = B;
      goldScroll(P, cx + rx * 0.05, cy + ry * 0.05, D * 0.34, 1, col);
      goldScroll(P, cx + rx * 0.62, cy - ry * 0.25, D * 0.2, -1, col);
      goldScroll(P, cx - rx * 0.55, cy + ry * 0.35, D * 0.18, -1, col);
    } else {
      goldScroll(P, -B.rx * 0.32, B.cy + B.ry * 0.25, B.W * 0.16, 1, col);
      goldScroll(P, B.rx * 0.36, B.cy - B.ry * 0.05, B.W * 0.13, -1, col);
    }
  }
}
// 在身體的裁切範圍裡畫新花紋（只有新品種會進來，第 11 輪的 10 種不會呼叫到任何東西）
function paintExtras(P, C, g, r, pose, B) {
  if (g.curly) curls(P, C, r, B, pose);
  if (g.pattern === 'bolt' || g.pattern === 'cloud' || g.pattern === 'gold') paintSpecial(P, g, pose, B);
  if (g.pattern === 'stars') {
    const side = pose === 'side';
    const S = side
      ? [[0.12, -0.42, 0.13], [0.66, 0.04, 0.11], [-0.3, 0.36, 0.1], [0.38, 0.46, 0.06], [-0.05, -0.02, 0.05], [0.84, -0.46, 0.05], [-0.58, -0.28, 0.05]]
      : [[0.26, -0.2, 0.12], [-0.3, 0.14, 0.11], [0.12, 0.36, 0.06], [-0.1, -0.44, 0.05], [0.44, 0.4, 0.06], [-0.5, -0.3, 0.05]];
    S.forEach(([u, v, k], i) => {
      const J = () => (r() - 0.5) * 0.06;
      const x = side ? B.cx + (u + J()) * B.rx : (u + J()) * B.rx, y = B.cy + (v + J()) * B.ry, rr = (side ? B.D : B.W) * k;
      if (k >= 0.1) star(P, x, y, rr, g.patternColor);
      else if (i % 2) twinkle(P, x, y, rr * 1.3, g.seedColor || g.patternColor);
      else P.ellipse(x, y, rr * 0.55, rr * 0.55, g.patternColor);
    });
  }
  if (g.pattern === 'rice') {
    const side = pose === 'side', col = g.patternColor;
    if (side) {
      const { cx, cy, rx, ry, D } = B;
      riceEar(P, [cx - rx * 0.05, cy + ry * 0.75], [cx + rx * 0.02, cy - ry * 0.55], [cx + rx * 0.4, cy - ry * 0.2], D * 0.055, col, D * 0.028);
      riceEar(P, [cx + rx * 0.5, cy + ry * 0.8], [cx + rx * 0.56, cy - ry * 0.3], [cx + rx * 0.86, cy + ry * 0.02], D * 0.05, col, D * 0.026);
      riceEar(P, [cx - rx * 0.52, cy + ry * 0.85], [cx - rx * 0.5, cy - ry * 0.1], [cx - rx * 0.24, cy + ry * 0.18], D * 0.045, col, D * 0.024);
    } else {
      const { cy, rx, ry, W } = B;
      riceEar(P, [rx * 0.18, cy + ry * 0.7], [rx * 0.22, cy - ry * 0.55], [rx * 0.56, cy - ry * 0.18], W * 0.04, col, W * 0.02);
      riceEar(P, [-rx * 0.42, cy + ry * 0.75], [-rx * 0.4, cy - ry * 0.2], [-rx * 0.7, cy + ry * 0.1], W * 0.036, col, W * 0.018);
    }
  }
}

// ---------- 組裝 ----------
export function renderCow(vkey, g, { x = 0, y = 0, scale = 1, facing = 'left', id = 'cow', sil = false, pose = 'front' } = {}) {
  const V = VARIANTS[vkey];
  const p = plan(g);
  const side = pose === 'side';
  const faceKind = side ? '66' : '67';
  const C = palette(g, faceKind);
  const showShine = p.gloss && (lum(C.coat) < 0.3 || !!g.lightShine);
  const halo = g.lightShine ? shade(C.coat, -0.16) : null; // M2：淺色毛的亮光外面加一圈深一點的毛色
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
    // 側面不畫乳房（第 9 輪裁示：「側面把胸部拿掉」）
    // 身體＋近側腿：先畫兩倍粗的外框，再蓋上填色，只留外緣一圈線（腿和身體之間沒有分界線）
    P.raw(`<path d="${smoothPath(B.pts)}" fill="${C.coat}" stroke="${INK}" stroke-width="${f(LW * 2)}" stroke-linejoin="round"/>`);
    near.forEach((l) => P.raw(`<path d="${smoothPath(l.pts)}" fill="${C.coat}" stroke="${INK}" stroke-width="${f(LW * 2)}" stroke-linejoin="round"/>`));
    const cb = P.clip(B.pts);
    P.raw(`<path d="${smoothPath(B.pts)}" fill="${C.coat}"/><g clip-path="${cb}">`);
    paintPattern(P, C, makePattern(g, r, sideSpots(g, B, r), B.pts));
    paintExtras(P, C, g, r, 'side', B);
    if (showShine) shineSide(P, B, halo);
    P.raw('</g>');
    near.forEach((l) => {
      const c = P.clip(l.pts);
      P.raw(`<path d="${smoothPath(l.pts)}" fill="${C.coat}"/><g clip-path="${c}"><rect x="${f(l.x - w)}" y="${f(l.bottom - l.hoof)}" width="${f(w * 2)}" height="${f(l.hoof + 4)}" fill="${C.hoof}"/></g>`);
    });
    legPts = [...far, ...near].map((l) => l.pts);
    pts = B.pts;
  } else {
    const hasUdder = p.udder > 0;
    const B = frontBody(p, 0.12);
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
    P.region(B.pts, C.coat, () => {
      paintPattern(P, C, roundPattern(g, r, frontSpots(g, B, r), B.pts));
      paintExtras(P, C, g, r, 'front', B);
    }, { w: 1 });
    // 大腿和肚子的分界：兩條往外彎的弧線
    [-1, 1].forEach((sd) => P.arc([[sd * B.rx * 0.68, B.cy + B.ry * 0.36], [sd * B.rx * 0.58, B.cy + B.ry * 0.62], [sd * B.rx * 0.66, B.cy + B.ry * 0.9]], INK, LW * 0.8, 1));
    // 胸前兩隻細細的小短腳，腳尖是深色的蹄
    [-1, 1].forEach((sd) => {
      const xt = sd * B.W * 0.12, xb = sd * B.W * 0.13, t0 = B.topY + B.H * (hasUdder ? 0.33 : 0.42), b0 = B.topY + B.H * (hasUdder ? 0.52 : 0.64), lw2 = B.W * 0.048;
      const lp = [[xt - lw2, t0], [xt + lw2, t0], [xb + lw2 * 0.95, b0 - lw2 * 0.3], [xb + lw2 * 0.85, b0], [xb - lw2 * 0.85, b0], [xb - lw2 * 0.95, b0 - lw2 * 0.3]];
      drawLeg(P, C, { x: xb, far: false, bottom: b0, hoof: lw2 * 0.9, pts: lp, fill: C.coat });
    });
    // 乳房：肚子中間（小短腳下方）一塊沒有外框的粉紅圓
    if (hasUdder) udderPink(P, C, 0, B.topY + B.H * 0.71, B.W, V.udderSize);
    pts = B.pts;
  }
  const hd = drawHead(P, C, g, p, H, r);
  if (showShine && !side) shineFront(P, H, halo);

  let svg = P.svg({ x, y, scale: s });
  if (C.line !== INK) svg = svg.split(INK).join(C.line);
  if (sil) svg = `<g filter="url(#sil)">${svg}</g>`;
  const toScreen = (pt) => [x + (mirror ? -1 : 1) * pt[0] * s, y + pt[1] * s];
  const ht = Math.min(H.top - hd.hornH, hd.ear.y - 2, g.overlay && g.overlay !== 'none' ? H.top - (H.kind === '66' ? H.hh : H.hw) * 0.32 : Infinity);
  const bb = bbox([pts, H.pts, ...legPts]);
  const hr = H.kind === '66' ? H.hh * 0.5 : H.hw * 0.38;
  const hornX = g.horns === 'long' ? H.rx * 0.34 + hr * 1.2 * (H.kind === '67' ? 1.6 : 1) : g.horns === 'buffalo' ? H.rx * 0.34 + hr * 1.5 * (H.kind === '67' ? 1.25 : 1) : 0;
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
