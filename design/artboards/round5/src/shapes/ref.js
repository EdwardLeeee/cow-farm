// R5 牛產生器：照使用者參考圖的共同點畫「同一隻牛」，三個選項只差線條處理。
// 參考圖是有浮水印的圖庫圖片，只參考風格、不描圖（見 design/spec.md 第 4 輪）。共同點：
//   臉朝玩家、頭很大且跟身體連成一體（沒有脖子）、小點眼、下半臉一整條寬口鼻、少數大斑、短腿、
//   平塗沒有陰影亮面、線比 R1-A 細、沒有牛鈴。
// 流程：基因（data.js）→ plan() 體型參數（用途、特徵、公母、小牛；規則同企劃書 4.5）→ 幾何 → 畫筆（q.js）。
//   a 細手繪線：細的咖啡色線、輪廓帶一點手繪的抖動
//   b 乾淨中線：中等粗細、乾淨平滑的咖啡色線
//   c 不描邊：只有色塊，沒有外框線
// 兩個角度（D11）：pose 'front' 臉朝玩家（停下來、被點到、奶桶滿了、詳細資料、圖鑑、出生）；
//   pose 'side' 側面走路（牧場上平常的樣子）。兩個角度共用身體、斑點位置、口鼻顏色與點眼，看得出是同一頭。
import {
  painter, leaf, blob, bbox, topYAt, tail as drawTail, leg as drawLeg, horn as drawHorn, overlay as drawOverlay,
  makePattern, paintPattern, superPts, scallopPts, smoothPath, rng, shade, mix, lum, INK,
} from './q.js';

export const VARIANTS = {
  a: { key: 'a', name: '細手繪線', lw: 1.3, wobble: 0.6, line: '#6A4435', scene: 1.12 },
  b: { key: 'b', name: '乾淨中線', lw: 2.4, wobble: 0, line: '#4B3326', scene: 1.12 },
  c: { key: 'c', name: '不描邊', lw: 0, wobble: 0, line: null, scene: 1.12 },
};

// 共同的基準尺寸（兼用成牛、單位約等於 CSS px）
const BASE = { L: 70, D: 42, leg: 11, legW: 9.5, hh: 38 };
// 用途的相對體型（三種都是胖身材）：乳用最高、腿最長；肉用最寬、最深、腿最短
const BUILD = {
  dairy: { L: 0.97, D: 0.9, leg: 1.45, legW: 0.88, udder: 1, head: 0.97 },
  dual: { L: 1.0, D: 1.0, leg: 1.0, legW: 1.0, udder: 0.8, head: 1.0 },
  beef: { L: 1.1, D: 1.18, leg: 0.72, legW: 1.3, udder: 0.3, head: 1.05 },
};
const bell = (u, c, w) => Math.exp(-(((u - c) / w) ** 2));

export function plan(g) {
  const b = BUILD[g.use] || BUILD.dual;
  const t = g.traits || {};
  const bull = g.sex === 'bull', calf = g.age === 'calf';
  const p = {
    use: g.use, bull, calf, size: 1,
    L: BASE.L * b.L, D: BASE.D * b.D, leg: BASE.leg * b.leg, legW: BASE.legW * b.legW, hh: BASE.hh * b.head,
    udder: b.udder, hump: 0, muscle: g.use === 'beef' ? 1 : 0,
    fluffy: !!t.A && !g.legendFluff, lightFluff: !!g.legendFluff, eyeBig: !!t.B, shortFace: !!t.B, marble: !!t.C && g.use === 'beef',
  };
  if (p.fluffy) { p.L *= 1.06; p.D *= 1.06; p.leg *= 0.78; } // 長毛：毛蓋住上半截腿，看起來更低、更寬
  if (t.B) { p.size *= 0.9; p.hh *= 1.02; } // 淡色：骨架小一號、臉短、眼大
  if (t.C) p.muscle += 0.4;
  if (bull) { p.size *= 1.1; p.hump = 1; p.hh *= 1.04; p.udder = 0; }
  if (calf) { p.size *= 0.6; p.L *= 0.82; p.leg *= 0.9; p.legW *= 1.15; p.hh *= 1.12; p.udder = 0; p.hump = 0; p.muscle *= 0.3; }
  return p;
}

// 手繪抖動：沿法線方向加平滑的起伏（固定亂數，重拍結果相同）
function wobble(pts, amp, seed) {
  if (!amp) return pts;
  const n = pts.length;
  return pts.map(([x, y], i) => {
    const a = pts[(i - 1 + n) % n], c = pts[(i + 1) % n];
    const tx = c[0] - a[0], ty = c[1] - a[1], len = Math.hypot(tx, ty) || 1;
    const k = amp * (0.6 * Math.sin(i * 0.83 + seed) + 0.4 * Math.sin(i * 2.1 + seed * 1.7));
    return [x - (ty / len) * k, y + (tx / len) * k];
  });
}

function palette(g) {
  const coat = g.coat;
  const dark = lum(coat) < 0.12;
  const pat = g.patternColor || coat;
  return {
    coat, pat, dark,
    far: shade(coat, dark ? 0.06 : -0.08),
    face: g.faceColor || coat,
    ear: g.earColor === 'pattern' ? pat : coat,
    earIn: dark ? '#C99A94' : '#F6BDB4',
    muzzle: dark ? '#D1ABA3' : g.muzzleRef || '#F7CDB5',
    nostril: dark ? '#9C6F68' : '#D9967F',
    eye: dark ? '#140D0D' : '#3A241D',
    hoof: dark ? '#1C1414' : g.hoof || '#5A4038', hoofHi: dark ? '#1C1414' : g.hoof || '#5A4038',
    horn: '#FFF1CF', hornTip: '#E6C98F',
    tuft: g.pattern === 'patches' ? pat : shade(coat, dark ? 0.08 : -0.18),
    fringe: mix(coat, '#FFFFFF', dark ? 0.1 : 0.14),
    udder: '#F8C3C3', seed: g.seedColor || '#FFE9A8',
  };
}

// ---------- 幾何 ----------
function geometry(g, p, pose) {
  const { L, D } = p;
  const cx = 0, cy = -p.leg - D / 2, rx = L / 2, ry = D / 2;
  const mod = ([x, y]) => {
    const u = (x - cx) / rx, v = (y - cy) / ry;
    let dy = 0, dx = 0;
    if (v < 0) dy -= p.hump * D * 0.14 * bell(u, -0.35, 0.2) * -v; // 公牛肩峰
    else dy += D * 0.05 * bell(u, 0.1, 0.5) * v; // 圓肚子
    if (u > 0.55) dx += p.muscle * D * 0.03 * bell(v, -0.1, 0.5);
    return [x + dx, y + dy];
  };
  const body = p.fluffy ? scallopPts(superPts(cx, cy, rx, ry, 2.6, 20).map(mod), 0.26, 6) : superPts(cx, cy, rx, ry, 2.6, 72).map(mod);
  const B = { pts: body, cx, cy, rx, ry, L, D, topY: cy - ry, bellyY: cy + ry, xF: cx - rx, xR: cx + rx };

  // 頭：正面、比身體略窄、下巴稍寬；頂端略高過背、下緣在肚子上方
  const hh = p.hh, hw = hh * (p.shortFace ? 0.8 : 0.76);
  const hy = B.topY + hh * 0.42 - (p.calf ? hh * 0.08 : 0) + (p.bull ? D * 0.06 : 0);
  const hx = B.xF + hw * 0.18;
  const hry = hh / 2 * (p.shortFace ? 0.94 : 1), hrx = hw / 2;
  const head = superPts(hx, hy, hrx, hry, 2.35, 64).map(([x, y]) => {
    const v = (y - hy) / hry;
    return [hx + (x - hx) * (1 + 0.09 * Math.max(0, v) - 0.04 * Math.max(0, -v)), y];
  });
  let H = { type: 'front', pts: head, cx: hx, cy: hy, rx: hrx, ry: hry, top: hy - hry, hh, hw };
  if (pose === 'side') {
    // 側臉：額頭圓、口鼻往前稍微下垂；長度約等於正面的頭高
    const rx2 = hh * (p.shortFace ? 0.47 : 0.52), ry2 = hh * 0.44;
    const cx2 = B.xF - hh * 0.02, cy2 = B.topY + hh * 0.36 - (p.calf ? hh * 0.02 : 0) + (p.bull ? D * 0.06 : 0);
    const pts = superPts(cx2, cy2, rx2, ry2, 2.5, 64).map(([x, y]) => {
      const u = (x - cx2) / rx2;
      return [x, y + (u < 0 ? Math.pow(-u, 1.6) * hh * 0.07 : 0)];
    });
    H = { type: 'side', pts, cx: cx2, cy: cy2, rx: rx2, ry: ry2, top: topYAt(pts, cx2 + rx2 * 0.1), hh, hw: rx2 * 2 };
  }

  // 腿：短、直、蹄有顏色
  const top = B.bellyY - D * 0.3, w = p.legW, hoof = Math.min(w * 0.5, p.leg * 0.4 + 1.5);
  // 側面走路：前後腿一前一後張開（蹄往外錯開），正面站著時腿是直的
  const st = pose === 'side' ? Math.max(1.6, p.leg * 0.3) : 0;
  const mk = (x, far, dx = 0) => {
    const b = far ? -1.4 : 0, w0 = w * 0.52, w1 = w * 0.5, xb = x + dx;
    return { x: xb, far, bottom: b, hoof, pts: [[x - w0, top], [x + w0, top], [xb + w1, b - w1 * 0.25], [xb + w1 * 0.95, b], [xb - w1 * 0.95, b], [xb - w1, b - w1 * 0.25]] };
  };
  const legs = [mk(B.xF + L * 0.32, true, st * 0.8), mk(B.xR - L * 0.24, true, -st * 0.8), mk(B.xF + L * 0.2, false, -st), mk(B.xR - L * 0.13, false, st)];
  return { B, H, legs };
}

// ---------- 組裝 ----------
export function renderCow(vkey, g, { x = 0, y = 0, scale = 1, facing = 'left', id = 'cow', sil = false, pose = 'front' } = {}) {
  const V = VARIANTS[vkey];
  const p = plan(g);
  const { B, H, legs } = geometry(g, p, pose);
  const side = H.type === 'side';
  const C = palette(g);
  const mirror = facing === 'right';
  const lw = V.lw;
  const P = painter({ id, mirror, lw });
  const r = rng(g.seed + 505);
  const s = scale * p.size;
  const wob = (pts, k = 1) => wobble(pts, V.wobble * k, g.seed * 0.37 + pts.length);
  const f = (v) => Math.round(v * 100) / 100;
  const noLine = lw === 0;

  // 尾巴：細線＋末端一撮毛
  const tEnd = Math.min(B.bellyY + p.leg * 0.2, B.topY + B.D * 1.02);
  // 不描邊時，淺色牛的細尾巴會融進背景：尾巴改用深一點的同色系
  const tailColor = noLine && lum(C.coat) > 0.6 ? shade(C.coat, -0.2) : C.coat;
  drawTail(P, C, { p0: [B.xR - B.L * 0.03, B.topY + B.D * 0.16], p1: [B.xR + B.D * 0.26, B.topY + B.D * 0.35], p2: [B.xR + B.D * 0.2, tEnd], w: Math.max(1.8, p.legW * 0.2), tuftR: Math.max(3, B.D * 0.09) * (p.fluffy || p.lightFluff ? 1.35 : 1), color: tailColor });
  // 腿（遠側顏色深一點）、小乳房
  const legW = (l) => ({ ...l, pts: wob(l.pts, 0.4), fill: l.far ? C.far : C.coat });
  legs.filter((l) => l.far).forEach((l) => drawLeg(P, C, legW(l)));
  if (p.udder > 0) { const u = p.udder, ux = B.xR - B.L * 0.32; P.shape(wob(superPts(ux, B.bellyY + 1.2 * u, 5 * u, 3.6 * u, 2.2, 24), 0.4), C.udder, { w: 0.8 }); }
  legs.filter((l) => !l.far).forEach((l) => drawLeg(P, C, legW(l)));

  // 身體和頭連成一體：先畫兩倍粗的外框，再蓋上填色，只留外緣一圈線
  const body = wob(B.pts), head = wob(H.pts);
  if (!noLine) {
    P.raw(`<path d="${smoothPath(body)}" fill="${C.coat}" stroke="${INK}" stroke-width="${f(lw * 2)}" stroke-linejoin="round"/>`);
    P.raw(`<path d="${smoothPath(head)}" fill="${C.face}" stroke="${INK}" stroke-width="${f(lw * 2)}" stroke-linejoin="round"/>`);
  }
  const cb = P.clip(body);
  P.raw(`<path d="${smoothPath(body)}" fill="${C.coat}"/><g clip-path="${cb}">`);
  paintPattern(P, C, makePattern(g, r, bodySpots(g, B, r), body));
  if (p.marble) marbling(P, B, g.marbleColor || '#C9A7A0');
  P.raw('</g>');

  // 耳朵（在頭後面）、角
  const hr = H.hh * 0.5;
  const earShape = (e, fill) => {
    P.shape(wob(leaf(e.base, e.ang, e.len, e.wid, { round: 0.6 }), 0.3), fill, { w: 1 });
    P.shape(leaf([e.base[0] + Math.cos(e.ang) * e.len * 0.22, e.base[1] + Math.sin(e.ang) * e.len * 0.22], e.ang, e.len * 0.6, e.wid * 0.5, { round: 0.6 }), C.earIn, { line: false });
  };
  const hornAt = (bx, by, dir, k, hc) => {
    const kk = k * (p.bull ? 1.3 : 1);
    if (g.horns === 'bud') drawHorn(P, hc, { type: 'bud', base: [bx, by], r: hr * 0.13 * k });
    else if (g.horns === 'short') drawHorn(P, hc, { p0: [bx, by + 1.5], p1: [bx + dir * hr * 0.04, by - hr * 0.22 * kk], p2: [bx + dir * hr * 0.16 * kk, by - hr * 0.34 * kk], w0: hr * 0.24 * kk, w1: hr * 0.1 });
    else if (g.horns === 'long') drawHorn(P, hc, { p0: [bx - dir * hr * 0.1, by + hr * 0.1], p1: [bx + dir * hr * 0.95 * k, by + hr * 0.02], p2: [bx + dir * hr * 1.15 * k, by - hr * 0.55 * k], w0: hr * 0.28 * k, w1: hr * 0.08, tipFrom: 0.7 });
  };
  if (side) {
    // 遠側的耳朵與角（在頭後面、顏色深一點）
    earShape({ base: [H.cx + H.rx * 0.4, H.cy - H.ry * 0.72], ang: -1.05, len: H.hh * 0.24, wid: H.hh * 0.17 }, shade(C.ear, -0.1));
    hornAt(H.cx + H.rx * 0.34, topYAt(head, H.cx + H.rx * 0.34) + 1.5, 1, 0.85, { ...C, horn: shade(C.horn, -0.08) });
  } else {
  const ears = [-1, 1].map((sd) => ({ base: [H.cx + sd * H.rx * 0.78, H.cy - H.ry * 0.62], ang: sd < 0 ? Math.PI + 0.42 : -0.42, len: H.hh * 0.3, wid: H.hh * 0.2 }));
  ears.forEach((e) => {
    P.shape(wob(leaf(e.base, e.ang, e.len, e.wid, { round: 0.6 }), 0.3), C.ear, { w: 1 });
    P.shape(leaf([e.base[0] + Math.cos(e.ang) * e.len * 0.22, e.base[1] + Math.sin(e.ang) * e.len * 0.22], e.ang, e.len * 0.6, e.wid * 0.5, { round: 0.6 }), C.earIn, { line: false });
  });
  [-1, 1].forEach((sd) => { const bx = H.cx + sd * H.rx * 0.36; hornAt(bx, topYAt(head, bx) + 1.5, sd, 1, C); });
  }

  // 頭（填色與臉）
  const ch = P.clip(head);
  P.raw(`<path d="${smoothPath(head)}" fill="${C.face}"/><g clip-path="${ch}">`);
  // 頭上的斑：正面在畫面右上（牛的左臉），側面看到的也是左臉，所以斑在頭後半、耳朵下
  const patchAt = side ? [H.cx + H.rx * 0.55, H.cy - H.ry * 0.35] : [H.cx + H.rx * 0.62, H.cy - H.ry * 0.62];
  if (g.pattern === 'patches' || g.pattern === 'strawberry') paintPattern(P, C, makePattern(g, r, [{ cx: patchAt[0], cy: patchAt[1], r: H.hh * 0.24 }], head));
  // 口鼻：正面是下半臉一整條寬口鼻（上緣一道淺弧）；側面是臉前端一塊，顏色相同
  const my = H.cy + H.ry * 0.3;
  const mpts = side ? superPts(H.cx - H.rx * 0.95, H.cy + H.ry * 0.36, H.rx * 0.62, H.ry * 0.82, 2.2, 48)
    : superPts(H.cx, my + H.ry * 0.62, H.rx * 1.3, H.ry * 0.68, 2.2, 48);
  P.raw(`<path d="${smoothPath(wob(mpts, 0.5))}" fill="${C.muzzle}"${noLine ? '' : ` stroke="${INK}" stroke-width="${f(lw * 0.9)}"`}/>`);
  P.raw('</g>');
  if (!noLine) P.raw(`<path d="${smoothPath(head)}" fill="none" stroke="${INK}" stroke-width="${f(lw)}" stroke-linejoin="round"/>`);

  // 臉：小點眼、小點鼻孔（正面兩眼分開；側面一隻眼、一個鼻孔）
  const er = H.hh * (p.eyeBig ? 0.058 : 0.048) * (p.calf ? 1.08 : 1);
  const eyesAt = side ? [[H.cx - H.rx * 0.14, H.cy - H.ry * 0.14]] : [-1, 1].map((sd) => [H.cx + sd * H.rx * 0.46, H.cy - H.ry * 0.06]);
  eyesAt.forEach(([ex, ey]) => {
    P.ellipse(ex, ey, er, er * 1.1, C.eye);
    if (C.dark) P.ellipse(ex + P.lx * er * 0.3, ey - er * 0.35, er * 0.32, er * 0.32, '#FFFFFF', { opacity: 0.85 });
  });
  if (side) P.ellipse(H.cx - H.rx * 0.84, H.cy + H.ry * 0.16, H.hh * 0.024, H.hh * 0.032, C.nostril, { rot: -0.4 });
  else [-1, 1].forEach((sd) => P.ellipse(H.cx + sd * H.rx * 0.3, H.cy + H.ry * 0.58, H.hh * 0.022, H.hh * 0.028, C.nostril));
  if (side) {
    // 近側的耳朵往後、角
    earShape({ base: [H.cx + H.rx * 0.46, H.cy - H.ry * 0.52], ang: -0.3, len: H.hh * 0.3, wid: H.hh * 0.2 }, C.ear);
    hornAt(H.cx + H.rx * 0.12, topYAt(head, H.cx + H.rx * 0.12) + 1.5, -1, 1, C);
  }

  // 長毛瀏海：高地牛是一片蓬毛垂到眼睛上，眼睛從毛下露出來；傳說牛只有頭頂三小撮
  if (p.fluffy && side) {
    // 側面的瀏海：從頭頂往前垂到眼睛上
    const t = H.top - 1.2, ey = H.cy - H.ry * 0.14;
    const pts = [[H.cx + H.rx * 0.55, t + H.ry * 0.3], [H.cx + H.rx * 0.2, t - 0.5], [H.cx - H.rx * 0.3, t + H.ry * 0.08], [H.cx - H.rx * 0.62, t + H.ry * 0.45],
      [H.cx - H.rx * 0.5, ey + H.ry * 0.02], [H.cx - H.rx * 0.36, ey - H.ry * 0.08], [H.cx - H.rx * 0.22, ey + H.ry * 0.06], [H.cx - H.rx * 0.04, ey - H.ry * 0.1], [H.cx + H.rx * 0.14, ey + H.ry * 0.02], [H.cx + H.rx * 0.3, t + H.ry * 0.62]];
    P.shape(wob(pts, 0.3), C.fringe, { w: 0.85 });
  } else if (p.fluffy) {
    const t = H.top - 1.2, bt = H.cy - H.ry * 0.12, w = H.rx * 0.98;
    const pts = [[H.cx + w, bt - H.ry * 0.25]];
    for (let i = 0; i <= 10; i++) { const a = (i / 10) * Math.PI; pts.push([H.cx + Math.cos(a) * w, t + H.ry * 0.25 - Math.sin(a) * H.ry * 0.3]); }
    pts.push([H.cx - w, bt - H.ry * 0.25]);
    const n = 6;
    for (let i = 0; i < n; i++) {
      const xa = H.cx - w + (2 * w * i) / n, xb = H.cx - w + (2 * w * (i + 1)) / n, m = (xa + xb) / 2;
      const drop = (i === 0 || i === n - 1 ? 0.35 : 1) * H.ry * 0.16;
      pts.push([m, bt + drop], [xb, bt - H.ry * 0.05]);
    }
    P.shape(wob(pts, 0.3), C.fringe, { w: 0.85 });
  } else if (p.lightFluff) {
    [-1, 0, 1].forEach((k) => {
      const bx = H.cx + (side ? H.rx * 0.05 : 0) + k * H.rx * (side ? 0.16 : 0.22), by = topYAt(head, H.cx + (side ? H.rx * 0.05 : 0)) + 2.5;
      P.shape(wob(leaf([bx, by], -Math.PI / 2 + k * 0.5, H.hh * 0.16, H.hh * 0.11, { round: 0.7 }), 0.2), C.fringe, { w: 0.8 });
    });
  }
  drawOverlay(P, C, g, H.cx + (side ? H.rx * 0.05 : 0), H.top + 1, H.hh / 40);

  let svg = P.svg({ x, y, scale: s });
  if (V.line) svg = svg.replaceAll(INK, V.line);
  if (sil) svg = `<g filter="url(#sil)">${svg}</g>`;
  const toScreen = (pt) => [x + (mirror ? -1 : 1) * pt[0] * s, y + pt[1] * s];
  const hornTopY = g.horns === 'long' ? H.top - hr * 0.55 : g.horns === 'short' ? H.top - hr * 0.34 * (p.bull ? 1.3 : 1) : H.top - 2;
  const earTop = side ? H.cy - H.ry * 0.72 - H.hh * 0.24 * Math.sin(1.05) - 2 : H.cy - H.ry * 0.62 - H.hh * 0.3 * Math.sin(0.42) - 3;
  const ht = Math.min(hornTopY, earTop, g.overlay && g.overlay !== 'none' ? H.top - H.hh * 0.32 : Infinity);
  const bb = bbox([body, head, ...legs.map((l) => l.pts)]);
  const earX = side ? H.rx : H.rx * 0.78 + H.hh * 0.3 * Math.cos(0.42);
  const hornX = g.horns === 'long' ? (side ? -H.rx * 0.12 + hr * 1.2 : H.rx * 0.36 + hr * 1.2) : 0;
  const fc = toScreen([H.cx, H.cy]);
  return {
    svg, p,
    face: { cx: fc[0], cy: fc[1], r: H.hh * 0.62 * s },
    headTop: toScreen([H.cx, ht]),
    shadow: { cx: toScreen([B.cx, 0])[0], rx: (B.L * 0.62) * s, ry: Math.max(3.5, B.D * 0.12) * s },
    bbox: { x0: Math.min(bb.x0, H.cx - Math.max(earX, hornX)) - 2, x1: Math.max(bb.x1, B.xR + B.D * 0.34), y0: ht - 2, y1: 0 },
    height: -ht * s,
    scale: s,
  };
}

function bodySpots(g, B, r) {
  if (g.pattern !== 'patches' && g.pattern !== 'strawberry') return [];
  const J = () => r() - 0.5;
  const { cx, cy, rx, ry, D } = B;
  const k = g.pattern === 'strawberry' ? 0.85 : 1;
  return [
    { cx: cx - rx * (0.05 + 0.08 * J()), cy: cy - ry * (0.42 + 0.1 * J()), r: D * 0.38 * k },
    { cx: cx + rx * (0.62 + 0.05 * J()), cy: cy + ry * (0.1 + 0.1 * J()), r: D * 0.3 * k },
    { cx: cx + rx * (0.1 + 0.08 * J()), cy: cy + ry * (0.62 + 0.08 * J()), r: D * 0.2 * k },
  ];
}

function marbling(P, B, color) {
  const { cx, cy, rx, ry } = B;
  [[-0.55, -0.35], [-0.4, -0.02], [-0.2, 0.28], [-0.1, -0.42]].forEach(([u, v], i) => {
    const x = cx + u * rx, y = cy + v * ry, w = rx * 0.18;
    P.arc([[x - w, y], [x - w * 0.4, y - 2], [x + w * 0.2, y + 1.1], [x + w * 0.8, y - 1.5]], color, 1.1, 0.85 - i * 0.05);
  });
}

// 剪影濾鏡（塗黑）
export const SIL_DEFS = `<filter id="sil" x="-10%" y="-10%" width="120%" height="120%"><feFlood flood-color="#2A1E1A"/><feComposite in2="SourceAlpha" operator="in"/></filter>`;
