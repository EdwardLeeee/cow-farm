// R3 牛的幾何模型（五種畫風共用）：基因 → plan.js 體型參數 → 側面造型（延用 R2-C：頭也是側面、口鼻往前）→ 部位清單。
// 部位清單不含任何畫風資訊，只有「角色、形狀、畫的順序、要裁切在哪個區域裡」；五個 renderer 各自決定怎麼畫。
//   { t: 'fill', role, pts, region?, clip? }   閉合形狀；region 宣告一個可被裁切的區域，clip 表示裁在該區域內
//   { t: 'line', role, pts, w }                 開放線條（尾巴、嘴、項圈）
//   { t: 'dot',  role, cx, cy, rx, ry, rot }    橢圓點（眼睛、鼻孔、草莓籽、反光、腮紅）
import { plan } from './plan.js';
import { leaf, blob, bbox, superPts, ellipsePts, scallopPts, taperPts, bezierAt, densify, pointInPoly, rng } from './q.js';

export const PROPS = { L: 0.92, D: 1.0, legLen: 0.8, legW: 1.12, neckLen: 0.7, head: 1.32 };
const lerp = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];

export function cowModel(g) {
  const p0 = plan(g);
  const p = { ...p0, L: p0.L * PROPS.L, D: p0.D * PROPS.D, legLen: p0.legLen * PROPS.legLen, legW: p0.legW * PROPS.legW, neckLen: p0.neckLen * PROPS.neckLen };
  const hr = 14 * p0.head * PROPS.head;
  const { L, D } = p, LL = p.legLen, mus = p.muscle, hip = p.hip;
  const bellyY = -LL, topY = bellyY - D, xF = -L / 2, xR = L / 2;
  const r = rng(g.seed + 404);
  const J = () => r() - 0.5;
  const items = [];
  const fill = (role, pts, extra = {}) => items.push({ t: 'fill', role, pts, ...extra });
  const line = (role, pts, w, extra = {}) => items.push({ t: 'line', role, pts, w, ...extra });
  const dot = (role, cx, cy, rx, ry = rx, rot = 0, extra = {}) => items.push({ t: 'dot', role, cx, cy, rx, ry, rot, ...extra });

  // ---- 頭的位置與輪廓 ----
  const drop = p.calf ? 0.02 : p.build === 'beef' ? 0.3 : p.build === 'dairy' ? -0.02 : p.build === 'low' ? 0.22 : 0.1;
  const H = { x: xF - p.neckLen - hr * 0.1, y: topY + D * drop - (p.calf ? D * 0.12 : 0) };
  const f = p.face, dish = p.dish ? hr * 0.12 : 0;
  const headPts = densify([
    [H.x + hr * 0.55, H.y - hr * 0.8], [H.x - hr * 0.15, H.y - hr * 0.9], [H.x - hr * 0.56, H.y - hr * 0.62 + dish * 0.3],
    [H.x - hr * 0.8 * f, H.y - hr * 0.2 + dish], [H.x - hr * 1.05 * f, H.y + hr * 0.12], [H.x - hr * 1.16 * f, H.y + hr * 0.47],
    [H.x - hr * 1.11 * f, H.y + hr * 0.81], [H.x - hr * 0.87 * f, H.y + hr * 0.96], [H.x - hr * 0.3, H.y + hr * 0.9],
    [H.x + hr * 0.5, H.y + hr * 0.55], [H.x + hr * 0.72, H.y - hr * 0.1],
  ], 5);

  // ---- 身體（含脖子）輪廓 ----
  const pts = [
    [xF + L * 0.16, topY], [xF + L * 0.42, topY + D * (0.02 + 0.07 * p.dip)], [xR - L * 0.2, topY - D * 0.07 * hip],
    [xR - L * 0.05, topY + D * (0.03 - 0.03 * hip)], [xR + D * (0.02 + 0.07 * mus) - D * 0.03 * hip, topY + D * 0.3],
    [xR + D * 0.05 * mus - D * 0.03, topY + D * 0.64], [xR - L * 0.12, bellyY - D * 0.02],
    [xR - L * 0.42, bellyY + D * 0.14 * p.belly], [xF + L * 0.18, bellyY + D * (0.03 + 0.2 * p.chest)],
    [xF - D * (0.03 + 0.05 * mus), topY + D * 0.6],
  ];
  if (p.calf) { // 小牛：身體短而圓
    pts[1][1] = topY + D * 0.02; pts[6] = [xR - L * 0.1, bellyY + D * 0.02]; pts[7] = [xR - L * 0.45, bellyY + D * 0.16]; pts[8] = [xF + L * 0.2, bellyY + D * 0.08];
  }
  const endTop = [H.x + hr * 0.5, H.y - hr * 0.55], endBot = [H.x + hr * 0.45, H.y + hr * 0.7];
  const chestF = pts[pts.length - 1];
  const throat = lerp(chestF, endBot, 0.5); throat[1] += D * 0.07 * (p.neckW - 0.8) + 1;
  const crest = lerp(endTop, [xF + L * 0.06, topY - D * 0.02], 0.5); crest[1] -= D * 0.1 * Math.max(0, p.neckW - 1) + D * 0.02;
  pts.push(throat, endBot, endTop, crest);
  let body = densify(pts, 6);
  if (p.fluffy) body = scallopPts(densify(pts, 2), 0.26, 6);

  // ---- 腿 ----
  const lw = p.legW, legTop = bellyY - D * 0.35, hoofH = Math.min(lw * 0.62, LL * 0.3);
  const chunky = p.calf ? 1 : 0;
  const mkLeg = (x, far, hind) => {
    const b = far ? -1.6 : 0;
    const top = hind ? topY + D * 0.5 : legTop;
    const wt = hind ? lw * 0.9 : lw * 0.56, wk = lw * (chunky ? 0.56 : 0.44), wf = lw * (chunky ? 0.5 : 0.4), wh = lw * 0.48;
    const kneeY = b - LL * 0.46;
    const legPts = [[x - wt, top], [x + wt * (hind ? 0.95 : 1), top], [x + wk + (chunky ? lw * 0.08 : 0), kneeY], [x + wf, b - hoofH - 0.5], [x + wh, b], [x - wh, b], [x - wf, b - hoofH - 0.5], [x - wk - (chunky ? lw * 0.08 : 0), kneeY]];
    const hoof = superPts(x, b - hoofH / 2, wh * 1.04, hoofH / 2, 3.2, 20);
    return { x, far, pts: legPts, hoof };
  };
  const legs = [mkLeg(xF + L * 0.31, true, false), mkLeg(xR - L * 0.24, true, true), mkLeg(xF + L * 0.2, false, false), mkLeg(xR - L * 0.13, false, true)];

  // ---- 側臉細部 ----
  const hornBase = [H.x + hr * 0.12, H.y - hr * 0.8];
  let nearHorn = null, farHorn = null;
  if (g.horns !== 'none') {
    if (g.horns === 'bud' || p.calf) { nearHorn = { bud: true, c: hornBase, r: hr * 0.16 }; farHorn = { bud: true, c: [hornBase[0] + hr * 0.3, hornBase[1] + hr * 0.02], r: hr * 0.13 }; }
    else if (g.horns === 'short') {
      nearHorn = { p0: [hornBase[0], hornBase[1] + 2], p1: [hornBase[0] - hr * 0.05, hornBase[1] - hr * 0.3], p2: [hornBase[0] - hr * 0.3, hornBase[1] - hr * 0.48], w0: hr * 0.3, w1: hr * 0.1 };
      farHorn = { p0: [hornBase[0] + hr * 0.3, hornBase[1] + 2], p1: [hornBase[0] + hr * 0.3, hornBase[1] - hr * 0.28], p2: [hornBase[0] + hr * 0.12, hornBase[1] - hr * 0.44], w0: hr * 0.26, w1: hr * 0.09 };
    } else {
      nearHorn = { p0: [hornBase[0] + hr * 0.1, hornBase[1] + hr * 0.1], p1: [hornBase[0] - hr * 0.9, hornBase[1] + hr * 0.05], p2: [hornBase[0] - hr * 1.15, hornBase[1] - hr * 0.62], w0: hr * 0.34, w1: hr * 0.09 };
      farHorn = { p0: [hornBase[0] + hr * 0.35, hornBase[1] + hr * 0.1], p1: [hornBase[0] + hr * 1.25, hornBase[1] - hr * 0.05], p2: [hornBase[0] + hr * 1.4, hornBase[1] - hr * 0.62], w0: hr * 0.3, w1: hr * 0.08 };
    }
  }
  const hornPts = (h) => (h.bud ? superPts(h.c[0], h.c[1] - h.r * 0.2, h.r, h.r * 0.95, 2.1, 20) : taperPts(h.p0, h.p1, h.p2, h.w0, h.w1, 14));
  const nearEar = { base: [H.x + hr * 0.46, H.y - hr * 0.46], ang: 0.06, len: hr * 0.92, wid: hr * 0.48 };
  const farEar = { base: [H.x + hr * 0.4, H.y - hr * 0.62], ang: -0.16, len: hr * 0.78, wid: hr * 0.4 };
  const eye = { cx: H.x - hr * 0.24, cy: H.y - hr * 0.3, r: hr * (p.eyeBig ? 0.165 : 0.135) };
  const mz = { cx: H.x - hr * 0.95 * f, cy: H.y + hr * 0.5, rx: hr * 0.33, ry: hr * 0.47 };

  // ---- 花紋 ----
  const bodyBlobs = [], headBlobs = [];
  if (g.pattern === 'patches' || g.pattern === 'strawberry') {
    const k = g.pattern === 'strawberry' ? 0.9 : 1;
    [[xF + L * (0.3 + 0.08 * J()), topY + D * (0.25 + 0.15 * J()), D * 0.42 * k], [xR - L * (0.2 + 0.08 * J()), topY + D * (0.28 + 0.2 * J()), D * 0.46 * k],
      [xF + L * (0.62 + 0.06 * J()), bellyY - D * (0.16 + 0.1 * J()), D * 0.28 * k], [(crest[0] + throat[0]) / 2 + 3, (crest[1] + throat[1]) / 2 - D * 0.05, D * 0.26 * k]]
      .forEach(([cx, cy, rr]) => bodyBlobs.push(blob(cx, cy, rr, r, 9, 0.34)));
    headBlobs.push(blob(H.x + hr * 0.45, H.y - hr * 0.1, hr * 0.42, r, 8, 0.3));
  }
  const dots = [];
  if (g.pattern === 'dots') for (let i = 0; i < 12; i++) dots.push([xF + L * (0.1 + 0.8 * r()), topY + D * (0.12 + 0.72 * r())]);
  const seedsIn = (blobs) => {
    const out = [];
    blobs.forEach((b) => {
      const bb = bbox([b]); const sp = Math.max(4.4, (bb.x1 - bb.x0) / 4);
      let row = 0;
      for (let yy = bb.y0 + sp * 0.5; yy < bb.y1; yy += sp * 0.84, row++) for (let xx = bb.x0 + sp * 0.4 + (row % 2) * sp * 0.5; xx < bb.x1; xx += sp) {
        const jx = xx + J() * sp * 0.25, jy = yy + J() * sp * 0.25;
        if ([[0, 0], [0, 2.2], [0, -2.2], [2, 0], [-2, 0]].every(([dx, dy]) => pointInPoly(b, jx + dx, jy + dy))) out.push([jx, jy, J() * 0.7]);
      }
    });
    return out;
  };

  // ---- 依畫的順序輸出部位 ----
  fill('earFar', leaf(farEar.base, farEar.ang, farEar.len, farEar.wid, { round: 0.62 }));
  if (farHorn) fill('hornFar', hornPts(farHorn));
  const tail = { p0: [xR - L * 0.04, topY + D * 0.06], p1: [xR + D * 0.28, topY + D * 0.55], p2: [xR + D * 0.12, Math.min(bellyY + LL * 0.3, bellyY + D * 0.1)] };
  const tailPts = []; for (let i = 0; i <= 8; i++) tailPts.push(bezierAt(tail.p0, tail.p1, tail.p2, i / 8));
  line('tail', tailPts, Math.max(2.2, lw * 0.28));
  const tr = Math.max(3.4, D * 0.12) * (p.fluffy ? 1.3 : 1);
  fill('tuft', scallopPts(ellipsePts(tail.p2[0], tail.p2[1] + tr * 0.9, tr * 0.72, tr * 1.05, 0, 7), 0.42, 5));
  legs.filter((l) => l.far).forEach((l) => { fill('legFar', l.pts); fill('hoof', l.hoof); });
  if (p.udder > 0 && !p.calf) {
    const s = p.udder, ux = xR - L * 0.3, uy = bellyY + 2.2 * s;
    [ux - 2.6 * s, ux + 2.8 * s].forEach((tx) => fill('teat', superPts(tx, uy + 4.6 * s * 0.82, 6.2 * s * 0.2, 4.6 * s * 0.62, 2.4, 14)));
    fill('udder', superPts(ux, uy, 6.2 * s, 4.6 * s, 2.1, 26));
  }
  legs.filter((l) => !l.far).forEach((l) => { fill('leg', l.pts); fill('hoof', l.hoof); });
  fill('coat', body, { region: 'body' });
  bodyBlobs.forEach((b) => fill('pattern', b, { clip: 'body' }));
  dots.forEach(([x, y]) => dot('pattern', x, y, Math.max(2, D * 0.07), Math.max(2, D * 0.07), 0, { clip: 'body' }));
  if (g.pattern === 'strawberry') seedsIn(bodyBlobs).forEach(([x, y, rot]) => dot('seed', x, y, 1.1, 1.55, rot, { clip: 'body' }));
  // 項圈＋牛鈴
  const ca = lerp(endTop, crest, 0.28), cb = lerp(endBot, throat, 0.26), cm = lerp(ca, cb, 0.5);
  const bs = p.calf ? 0.85 : 1.05;
  if (g.collar === 'bell') {
    line('strap', [ca, [cm[0] - 2.5, cm[1]], cb], 4.6 * bs);
    const [x, y] = [cb[0] - 1, cb[1] + 6.2 * bs], s = bs;
    fill('bell', densify([[x - 1.2 * s, y - 5.2 * s], [x + 1.2 * s, y - 5.2 * s], [x + 3.9 * s, y - 3.2 * s], [x + 4.8 * s, y + 1.6 * s], [x + 6.2 * s, y + 4.4 * s], [x, y + 5.2 * s], [x - 6.2 * s, y + 4.4 * s], [x - 4.8 * s, y + 1.6 * s], [x - 3.9 * s, y - 3.2 * s]], 4));
    dot('bellDot', x, y + 4.4 * s, 1.5 * s, 1.3 * s);
  }
  if (nearHorn) fill('horn', hornPts(nearHorn));
  fill('coat', headPts, { region: 'head' });
  headBlobs.forEach((b) => fill('pattern', b, { clip: 'head' }));
  if (g.pattern === 'strawberry') seedsIn(headBlobs).forEach(([x, y, rot]) => dot('seed', x, y, 1.1, 1.55, rot, { clip: 'head' }));
  fill('muzzle', ellipsePts(mz.cx - mz.rx * 0.3, mz.cy, mz.rx * 1.55, mz.ry * 1.02, 0, 30), { clip: 'head' });
  line('muzzleEdge', [[mz.cx + mz.rx * 0.78, mz.cy - mz.ry * 0.95], [mz.cx + mz.rx * 1.22, mz.cy - mz.ry * 0.05], [mz.cx + mz.rx * 0.9, mz.cy + mz.ry * 0.92]], 1.6, { clip: 'head' });
  dot('nostril', mz.cx - mz.rx * 0.32, mz.cy - mz.ry * 0.42, hr * 0.1, hr * 0.062, -0.85);
  dot('nostril', mz.cx + mz.rx * 0.36, mz.cy - mz.ry * 0.5, hr * 0.075, hr * 0.047, -0.55);
  line('mouth', [[mz.cx - mz.rx * 0.4, mz.cy + mz.ry * 0.5], [mz.cx + mz.rx * 0.05, mz.cy + mz.ry * 0.6], [mz.cx + mz.rx * 0.5, mz.cy + mz.ry * 0.48]], 1.4);
  fill('ear', leaf(nearEar.base, nearEar.ang, nearEar.len, nearEar.wid, { round: 0.6 }));
  fill('earIn', leaf([nearEar.base[0] + Math.cos(nearEar.ang) * nearEar.len * 0.2, nearEar.base[1] + Math.sin(nearEar.ang) * nearEar.len * 0.2], nearEar.ang, nearEar.len * 0.62, nearEar.wid * 0.46, { round: 0.6 }));
  if (p.eyeRim) dot('eyeRim', eye.cx, eye.cy, eye.r * 1.6, eye.r * 1.5);
  dot('eye', eye.cx, eye.cy, eye.r, eye.r * 1.08);
  dot('eyeHi', eye.cx - eye.r * 0.3, eye.cy - eye.r * 0.34, eye.r * 0.36, eye.r * 0.36);
  if (p.fluffy) {
    const top = H.y - hr * 0.92;
    fill('fringe', densify([[H.x + hr * 0.55, top + hr * 0.1], [H.x + hr * 0.1, top - hr * 0.12], [H.x - hr * 0.42, top + hr * 0.05], [H.x - hr * 0.62, top + hr * 0.4], [H.x - hr * 0.45, eye.cy + hr * 0.05], [H.x - hr * 0.32, eye.cy - hr * 0.08], [H.x - hr * 0.2, eye.cy + hr * 0.02], [H.x - hr * 0.02, eye.cy - hr * 0.1], [H.x + hr * 0.2, eye.cy + hr * 0.02], [H.x + hr * 0.4, top + hr * 0.45]], 3));
  }
  dot('blush', H.x - hr * 0.4, H.y + hr * 0.14, hr * 0.16, hr * 0.09);
  const topHead = H.y - hr * 0.9;
  if (g.overlay === 'berry') {
    const c = [H.x - hr * 0.05, topHead + 2.5];
    line('stem', [[c[0], c[1] - 1], [c[0] + 1.2, c[1] - 6], [c[0] + 3, c[1] - 9.5]], 2.4);
    [[Math.PI - 0.42, 11.5], [Math.PI - 0.02, 12.5], [Math.PI + 0.62, 7.5], [2 * Math.PI - 0.62, 7.5], [0.02, 12.5], [0.42, 11.5]].forEach(([a, len]) => {
      const l = leaf(c, a, len, len > 10 ? 6.6 : 5.6, { round: 0.8 });
      fill('leaf', l.map(([x, y]) => [x, c[1] + (y - c[1]) * 0.7]));
    });
  } else if (g.overlay === 'cream') {
    const c = [H.x - hr * 0.05 + 1, topHead + 2];
    [[0, -1, 11, 5], [0.8, -6.2, 8, 4.4], [1.6, -10.6, 5, 3.8]].forEach(([dx, dy, rx, ry]) => fill('cream', ellipsePts(c[0] + dx, c[1] + dy, rx, ry, 0, 24)));
    fill('cream', densify([[c[0] - 2.5, c[1] - 12], [c[0] + 1, c[1] - 17], [c[0] + 4, c[1] - 15], [c[0] + 2.5, c[1] - 12]], 3));
  }

  // ---- 錨點 ----
  const all = [body, headPts, ...legs.map((l) => l.pts)];
  if (nearHorn) all.push(hornPts(nearHorn)); if (farHorn) all.push(hornPts(farHorn));
  const bb = bbox(all);
  const hornTop = nearHorn && !nearHorn.bud ? Math.min(...hornPts(nearHorn).map((q) => q[1]), ...(farHorn ? hornPts(farHorn).map((q) => q[1]) : [])) : topHead - hr * 0.15;
  const headTop = Math.min(hornTop, g.overlay !== 'none' ? topHead - 14 : hornTop);
  return {
    g, p, hr, items, H,
    size: p.size,
    bodyBox: bbox([body]), headBox: bbox([headPts]),
    bbox: { x0: bb.x0 - 2, x1: bb.x1 + D * 0.35, y0: Math.min(bb.y0, headTop) - 3, y1: 0 },
    headTop: [H.x - hr * 0.2, headTop],
    shadow: { cx: (xF + xR) / 2, rx: L * 0.62, ry: Math.max(4, D * 0.16) },
    face: { cx: H.x - hr * 0.2, cy: H.y + hr * 0.02, r: hr * 1.25 },
  };
}
