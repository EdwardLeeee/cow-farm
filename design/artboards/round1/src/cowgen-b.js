// 風格 B「像素風」renderer：把 cowgen.js 的幾何模型直接點陣化成小精靈圖（sprite）。
// 1 美術像素 = 3 CSS px（畫面上用 image-rendering: pixelated 放大），所以不縮放 sprite，
// 大小不同（小牛）是用較小的 ppu（每單位幾像素）重新點陣化，不是把圖縮小。
import { shade, mix, lum, pointInPoly, taperPts, bezierAt, ellipsePts, superPts } from './cowgen.js';

export const PX = 3; // 1 美術像素 = 3 CSS px
export const B_LINE = '#3A2733';
export const PPU = 0.27; // 成牛：每 1 單位 = 0.27 美術像素

// 色階：高光、本色、陰影、深陰影
export function ramp(c) {
  const L = lum(c);
  if (L > 0.8) return [mix(c, '#FFFFFF', 0.6), c, shade(c, -0.13), shade(c, -0.25)];
  if (L < 0.05) return [shade(c, 0.1), c, shade(c, -0.07), shade(c, -0.12)];
  return [shade(c, 0.09), c, shade(c, -0.11), shade(c, -0.21)];
}

export function paletteB(M) {
  const g = M.genes;
  return {
    coat: ramp(g.coat),
    pat: ramp(g.patternColor),
    ear: ramp(g.earColor === 'pattern' ? g.patternColor : g.coat),
    earIn: mix(g.muzzle, '#FFFFFF', 0.2),
    muzzle: ramp(g.muzzle),
    nostril: mix(g.muzzle, '#4A1E2A', 0.55),
    hoof: lum(g.coat) < 0.05 ? '#1C1216' : '#5C3B35',
    horn: ['#FFFBEA', '#F3E4C2', '#D6B98C', '#A98A62'],
    tuft: g.pattern === 'patches' ? ramp(g.patternColor) : ramp(shade(g.coat, lum(g.coat) < 0.05 ? -0.03 : -0.14)),
    fringe: ramp(shade(g.coat, 0.06)),
    eye: '#21161B',
    cheek: '#FF8FA6',
    seed: '#FFF19A',
    line: B_LINE,
  };
}

// 建立一張 sprite：回傳 { canvas, w, h, footX, footY, headTop:[x,y] }（皆為美術像素）
export function spriteB(M, { facing = 'left', ppu = PPU } = {}) {
  const P = paletteB(M);
  const k = ppu * M.unit;
  const mirror = facing === 'right';
  const b = M.bbox;
  const pad = 2;
  const X0 = mirror ? -b.x1 : b.x0;
  const w = Math.ceil((b.x1 - b.x0) * k) + pad * 2;
  const h = Math.ceil((b.y1 - b.y0) * k) + pad * 2 + 1;
  const ox = -X0 * k + pad, oy = -b.y0 * k + pad;
  const tx = (x) => (mirror ? -x : x) * k + ox;
  const ty = (y) => y * k + oy;
  const toPx = (pts) => pts.map(([x, y]) => [tx(x), ty(y)]);

  const col = new Array(w * h).fill(null);
  const idx = (x, y) => y * w + x;
  const inb = (x, y) => x >= 0 && y >= 0 && x < w && y < h;

  function mask(ptsPx) {
    const m = new Uint8Array(w * h);
    let x0 = w, y0 = h, x1 = 0, y1 = 0;
    for (const [x, y] of ptsPx) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
    for (let y = Math.max(0, Math.floor(y0)); y <= Math.min(h - 1, Math.ceil(y1)); y++) {
      for (let x = Math.max(0, Math.floor(x0)); x <= Math.min(w - 1, Math.ceil(x1)); x++) {
        if (pointInPoly(ptsPx, x + 0.5, y + 0.5)) m[idx(x, y)] = 1;
      }
    }
    return m;
  }
  function ring(m) {
    const r = new Uint8Array(w * h);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      if (m[idx(x, y)]) continue;
      if ((inb(x - 1, y) && m[idx(x - 1, y)]) || (inb(x + 1, y) && m[idx(x + 1, y)]) || (inb(x, y - 1) && m[idx(x, y - 1)]) || (inb(x, y + 1) && m[idx(x, y + 1)])) r[idx(x, y)] = 1;
    }
    return r;
  }
  // 依光線（左上）決定色階：0 高光、1 本色、2 陰影、3 深陰影
  function lightLevel(m, x, y, bb) {
    const u = (x + 0.5 - bb.cx) / bb.rx, v = (y + 0.5 - bb.cy) / bb.ry;
    const edgeTL = (!m[idx(x, y - 1)] || !m[idx(x - 1, y)]) && u * -0.55 + v * -0.85 > 0.35;
    if (edgeTL) return 0;
    if (v > 0.62 || u * 0.35 + v * 0.95 > 0.78) return v > 0.84 ? 3 : 2;
    return 1;
  }
  function bboxOf(m) {
    let x0 = w, y0 = h, x1 = -1, y1 = -1;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (m[idx(x, y)]) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
    return { cx: (x0 + x1 + 1) / 2, cy: (y0 + y1 + 1) / 2, rx: Math.max(1, (x1 - x0 + 1) / 2), ry: Math.max(1, (y1 - y0 + 1) / 2) };
  }
  function paint(ptsModel, fill, { line = P.line, shadeRamp = null, extra = null } = {}) {
    const m = mask(toPx(ptsModel));
    if (line) { const r = ring(m); for (let i = 0; i < r.length; i++) if (r[i]) col[i] = line; }
    const bb = bboxOf(m);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      if (!m[idx(x, y)]) continue;
      if (shadeRamp) {
        const lv = lightLevel(m, x, y, bb);
        const rampHere = extra ? extra(x, y) || shadeRamp : shadeRamp;
        col[idx(x, y)] = rampHere[lv];
      } else col[idx(x, y)] = fill;
    }
    return m;
  }

  // 花紋遮罩（在身體或頭的遮罩內）
  const blobMasks = (list) => list.map((pts) => mask(toPx(pts)));
  const bodyBlobs = blobMasks(M.pattern.body);
  const headBlobs = blobMasks(M.pattern.head);
  const dots = M.pattern.dots.map((d) => ({ ...d, m: mask(toPx(ellipsePts(d.cx, d.cy, Math.max(d.r, 3.2 / k / 3), Math.max(d.r, 3.2 / k / 3), 0, 12))) }));
  const patAt = (where) => (x, y) => {
    const i = idx(x, y);
    const blobs = where === 'body' ? bodyBlobs : headBlobs;
    if (blobs.some((bm) => bm[i])) return P.pat;
    if (dots.some((d) => d.where === where && d.m[i])) return P.pat;
    return null;
  };

  // 腿（全部在身體後面）
  M.legs.forEach((L) => {
    const lm = paint(L.pts, null, { shadeRamp: L.far ? [P.coat[2], P.coat[2], P.coat[3], P.coat[3]] : P.coat });
    const hoofTop = ty(L.bottom - L.hoof);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (lm[idx(x, y)] && y + 0.5 > hoofTop) col[idx(x, y)] = P.hoof;
  });
  // 尾巴：1 像素的線＋尾巴毛
  {
    const t = M.tail;
    for (let i = 0; i <= 24; i++) {
      const [x, y] = bezierAt(t.p0, t.p1, t.p2, i / 24);
      const px = Math.floor(tx(x)), py = Math.floor(ty(y));
      if (inb(px, py)) col[idx(px, py)] = P.line;
    }
    paint(t.tuft.pts, null, { shadeRamp: P.tuft });
  }
  // 身體
  const bodyM = paint(M.body.pts, null, { shadeRamp: P.coat, extra: (x, y) => { const c = patAt('body')(x, y); return c ? P.pat : null; } });
  // 草莓籽
  M.pattern.seeds.forEach((sd) => {
    const x = Math.floor(tx(sd.cx)), y = Math.floor(ty(sd.cy));
    if (inb(x, y) && (sd.where === 'body' ? bodyM[idx(x, y)] : true)) sd._px = [x, y];
  });
  const taken = [];
  const placeSeeds = (where, m) => M.pattern.seeds.filter((s) => s.where === where && s._px).forEach((s) => {
    const [x, y] = s._px;
    if (taken.some(([a, b]) => Math.abs(a - x) + Math.abs(b - y) < 3)) return;
    if (m[idx(x, y)] && col[idx(x, y)] !== P.line && !(m[idx(x, y + 1)] === 0)) { col[idx(x, y)] = P.seed; taken.push([x, y]); }
  });
  placeSeeds('body', bodyM);

  // 角、耳朵、頭
  M.horns.forEach((hn) => {
    const hm = paint(hn.pts, null, { shadeRamp: P.horn });
    const tip = toPx([bezierAt(hn.p0, hn.p1, hn.p2, hn.tipFrom)])[0];
    const base = toPx([hn.p0])[0];
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      if (!hm[idx(x, y)]) continue;
      const dt = Math.hypot(x + 0.5 - base[0], y + 0.5 - base[1]), dtip = Math.hypot(tip[0] - base[0], tip[1] - base[1]);
      if (dt >= dtip) col[idx(x, y)] = P.horn[2];
    }
  });
  M.ears.forEach((e) => {
    paint(e.pts, null, { shadeRamp: P.ear });
    const im = mask(toPx(e.inner));
    let any = false;
    for (let i = 0; i < im.length; i++) if (im[i] && col[i] !== P.line) { col[i] = P.earIn; any = true; }
    if (!any) {
      const c = toPx([[e.cx + e.side * 1.5, e.cy]])[0];
      const x = Math.floor(c[0]), y = Math.floor(c[1]);
      if (inb(x, y) && col[idx(x, y)] && col[idx(x, y)] !== P.line) col[idx(x, y)] = P.earIn;
    }
  });
  const headM = paint(M.head.pts, null, { shadeRamp: P.coat, extra: (x, y) => { const c = patAt('head')(x, y); return c ? P.pat : null; } });
  placeSeeds('head', headM);

  // 瀏海
  if (M.fringe) {
    const before = col.slice();
    const fm = paint(M.fringe.pts, null, { shadeRamp: P.fringe });
    const fb = bboxOf(fm);
    for (let i = 0; i < col.length; i++) {
      if (col[i] === P.line && before[i] && before[i] !== P.line && Math.floor(i / w) + 0.5 > fb.cy) col[i] = P.fringe[3];
    }
  }
  // 口鼻
  const mzM = paint(M.muzzle.pts, null, { shadeRamp: P.muzzle });
  M.nostrils.forEach((n) => {
    const c = toPx([[n.cx, n.cy]])[0];
    const x = Math.floor(c[0]), y = Math.floor(c[1]);
    if (inb(x, y) && mzM[idx(x, y)]) col[idx(x, y)] = P.nostril;
  });
  // 眼睛（直接蓋章，確保每頭牛的眼睛都清楚）：一般 2×3、大眼 2×4 加第二個亮點；高光永遠在左上
  const darkCoat = lum(M.genes.coat) < 0.06;
  const eyeStamp = (e) => {
    const c = toPx([[e.cx, e.cy]])[0];
    const big = e.big;
    const W = 2, Hh = big ? 4 : 3;
    const x0 = Math.round(c[0] - 1), y0 = Math.round(c[1] - Hh / 2) - 1; // 往上 1 格，和口鼻留一點空隙
    if (darkCoat) {
      // 深色毛：眼睛外圍加一圈淺色，免得黑眼睛融進毛色
      for (let y = -1; y <= Hh; y++) for (let x = -1; x <= W; x++) {
        if ((x === -1 || x === W) && (y === -1 || y === Hh)) continue;
        if (inb(x0 + x, y0 + y) && col[idx(x0 + x, y0 + y)] && col[idx(x0 + x, y0 + y)] !== P.line) col[idx(x0 + x, y0 + y)] = P.coat[0];
      }
    }
    for (let y = 0; y < Hh; y++) for (let x = 0; x < W; x++) if (inb(x0 + x, y0 + y)) col[idx(x0 + x, y0 + y)] = P.eye;
    // 白色臉上白色亮點會和臉連在一起、眼睛看起來缺角，改用淡藍色反光
    const lightFace = lum(M.genes.coat) > 0.7;
    if (inb(x0, y0)) col[idx(x0, y0)] = lightFace ? '#8FC3EE' : '#FFFFFF';
    if (big && inb(x0 + 1, y0 + 2)) col[idx(x0 + 1, y0 + 2)] = lightFace ? '#5E6F8C' : '#E9E4F0';
    return [x0, y0];
  };
  M.eyes.forEach(eyeStamp);
  // 腮紅
  M.cheeks.forEach((ch) => {
    const c = toPx([[ch.cx, ch.cy]])[0];
    const x = Math.round(c[0] - 1), y = Math.round(c[1]);
    for (let d = 0; d < 2; d++) if (inb(x + d, y) && headM[idx(x + d, y)] && col[idx(x + d, y)] !== P.line) col[idx(x + d, y)] = P.cheek;
  });
  // 特殊疊層：像素版用手繪小圖章，位置由模型決定
  const stamp = (rows, map, cx, top) => {
    const x0 = Math.round(cx - rows[0].length / 2);
    rows.forEach((row, y) => [...row].forEach((ch, x) => {
      if (ch === '.' || !inb(x0 + x, top + y)) return;
      col[idx(x0 + x, top + y)] = map[ch];
    }));
  };
  if (M.overlay) {
    const hc = toPx([[M.head.cx, M.head.cy - M.head.ry]])[0];
    if (M.overlay.type === 'berry') {
      stamp(['....o....', '...oso...', '.oogGgoo.', 'oGGgggGGo', '.oo.o.oo.'],
        { o: P.line, s: '#6B8E3A', g: '#5DBB57', G: '#8EDB6E' }, hc[0], Math.round(hc[1]) - 3);
    } else if (M.overlay.type === 'cream') {
      stamp(['...o...', '..owo..', '.owwco.', 'owwwwco', 'ocwwccо'.replace('о', 'o'), '.ooooo.'],
        { o: P.line, w: '#FFF8EA', c: '#E9D2AC' }, hc[0] + 0.5, Math.round(hc[1]) - 5);
    }
  }

  const canvas = document.createElement('canvas');
  canvas.width = w; canvas.height = h;
  const ctx = canvas.getContext('2d');
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const c = col[idx(x, y)];
    if (c) { ctx.fillStyle = c; ctx.fillRect(x, y, 1, 1); }
  }
  const ht = toPx([M.headTop])[0];
  return { canvas, w, h, footX: tx(0), footY: ty(0), headTop: [ht[0], ht[1]], headC: [tx(M.head.cx), ty(M.head.cy)], shadowRx: M.shadow.rx * k, bodyCx: tx(M.body.cx) };
}

// 圖庫用
export function renderCell(M, { size = 150, facing = 'left' } = {}) {
  const S = spriteB(M, { facing });
  const scale = PX;
  const wrap = document.createElement('div');
  wrap.style.cssText = `width:${size}px;height:${size}px;display:flex;align-items:flex-end;justify-content:center;margin:0 auto;`;
  const cv = document.createElement('canvas');
  const W = S.w + 8, Hh = S.h + 3;
  cv.width = W; cv.height = Hh;
  const ctx = cv.getContext('2d');
  ctx.fillStyle = 'rgba(40,70,30,0.18)';
  const sx = Math.round(S.footX + 4), sy = Hh - 3;
  for (let x = -Math.round(S.shadowRx * 0.8); x <= Math.round(S.shadowRx * 0.8); x++) ctx.fillRect(sx + x, sy - 1, 1, 2);
  ctx.drawImage(S.canvas, 4, Hh - 2 - Math.round(S.footY));
  cv.style.cssText = `width:${W * scale}px;height:${Hh * scale}px;image-rendering:pixelated;`;
  wrap.appendChild(cv);
  return wrap;
}
