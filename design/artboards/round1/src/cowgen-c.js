// 風格 C「軟萌立體」renderer：柔和漸層、輕陰影、像黏土玩具。讀 cowgen.js 的模型，輸出 SVG 字串。
// 形狀先上平塗的底色與花紋，再疊一層共用的「光照」漸層（左上亮、右下暗），花紋就會跟著身體一起有立體感。
import { smoothPath, polyPath, shade, mix, lum, taperPts, bezierAt } from './cowgen.js';

const sp = (pts) => smoothPath(pts);

// 整個場景只需要一份的共用 defs
export function defsC() {
  const lit = (id, cx) => `<radialGradient id="${id}" cx="${cx}" cy="0.26" r="0.86" fx="${cx}" fy="0.2">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.62"/>
      <stop offset="0.36" stop-color="#FFFFFF" stop-opacity="0.08"/>
      <stop offset="0.62" stop-color="#000000" stop-opacity="0"/>
      <stop offset="1" stop-color="#241E3C" stop-opacity="0.3"/>
    </radialGradient>`;
  const eye = (id, cx) => `<radialGradient id="${id}" cx="${cx}" cy="0.75" r="0.75">
      <stop offset="0" stop-color="#5B4D6B"/><stop offset="0.55" stop-color="#2A2230"/><stop offset="1" stop-color="#15101A"/>
    </radialGradient>`;
  const blush = `<radialGradient id="c-blush"><stop offset="0" stop-color="#FF7F98" stop-opacity="0.75"/><stop offset="1" stop-color="#FF7F98" stop-opacity="0"/></radialGradient>`;
  const spec = `<radialGradient id="c-spec"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.95"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>`;
  const legL = (id, flip) => `<linearGradient id="${id}" x1="${flip ? 1 : 0}" y1="0" x2="${flip ? 0 : 1}" y2="0">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.35"/><stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="1" stop-color="#241E3C" stop-opacity="0.28"/></linearGradient>`;
  const blur = (id, sd) => `<filter id="${id}" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="${sd}"/></filter>`;
  return `${lit('c-lit', 0.36)}${lit('c-lit-m', 0.64)}${eye('c-eye', 0.62)}${eye('c-eye-m', 0.38)}${blush}${spec}${legL('c-leg', false)}${legL('c-leg-m', true)}${blur('c-blur1', 1)}${blur('c-blur2', 2)}${blur('c-blur3', 3.2)}${blur('c-blur5', 5)}`;
}

function soft(c) { return mix(c, '#FFF3EC', 0.05); }

export function paletteC(M) {
  const g = M.genes;
  const coat = soft(g.coat);
  const dark = lum(coat) < 0.1;
  return {
    coat, dark,
    pat: soft(g.patternColor),
    far: shade(coat, dark ? -0.04 : -0.1),
    ear: g.earColor === 'pattern' ? soft(g.patternColor) : coat,
    earIn: mix(g.muzzle, '#FF9FB0', 0.35),
    muzzle: g.muzzle,
    nostril: mix(g.muzzle, '#5A2233', 0.5),
    hoof: dark ? '#221619' : '#6B4A40',
    horn0: '#FFF8E6', horn1: '#D9BC8E',
    tuft: g.pattern === 'patches' ? soft(g.patternColor) : shade(coat, dark ? -0.03 : -0.15),
    fringe: shade(coat, 0.06),
    seed: '#FFEFA0',
    edge: lum(coat) > 0.75 ? '#8E97B8' : shade(coat, dark ? -0.02 : -0.3),
  };
}

export function cowC(M, { x = 0, y = 0, scale = 1, facing = 'left', id = 'cow', headOnly = false, shadow = true } = {}) {
  const P = paletteC(M);
  const mirror = facing === 'right';
  const s = scale * M.unit;
  const lx = mirror ? 1 : -1;
  const LIT = mirror ? 'url(#c-lit-m)' : 'url(#c-lit)';
  const LEG = mirror ? 'url(#c-leg-m)' : 'url(#c-leg)';
  const EYE = mirror ? 'url(#c-eye-m)' : 'url(#c-eye)';
  const o = [], defs = [];
  const clip = (name, d) => { defs.push(`<clipPath id="${id}-${name}"><path d="${d}"/></clipPath>`); return `url(#${id}-${name})`; };
  const edge = (d, c = P.edge, op = 0.35, w = 1.1) => `<path d="${d}" fill="none" stroke="${c}" stroke-opacity="${op}" stroke-width="${w}"/>`;

  if (shadow && !headOnly) {
    o.push(`<ellipse cx="${M.shadow.cx}" cy="1" rx="${M.shadow.rx}" ry="${M.shadow.ry + 1.5}" fill="#2F5A1E" opacity="0.28" filter="url(#c-blur3)"/>`);
  }
  if (!headOnly) {
    // 腿
    M.legs.forEach((L) => {
      const d = sp(L.pts);
      const lc = clip(`leg${L.x}`, d);
      o.push(`<path d="${d}" fill="${L.far ? P.far : P.coat}"/>`);
      o.push(`<rect x="${L.x - L.w}" y="${L.bottom - L.hoof}" width="${L.w * 2}" height="${L.hoof + 2}" fill="${P.hoof}" clip-path="${lc}"/>`);
      o.push(`<path d="${d}" fill="${LEG}"/>`);
      if (L.far) o.push(`<path d="${d}" fill="#2A1030" opacity="0.1"/>`);
    });
    // 身體壓在腿上的柔和陰影
    { const B = M.body; o.push(`<ellipse cx="${B.cx}" cy="${B.cy + B.ry * 0.86}" rx="${B.rx * 0.82}" ry="${B.ry * 0.34}" fill="#2A1030" opacity="0.3" filter="url(#c-blur2)"/>`); }
    // 尾巴
    const t = M.tail;
    const td = `M${t.p0[0]},${t.p0[1]} Q${t.p1[0]},${t.p1[1]} ${t.p2[0]},${t.p2[1]}`;
    o.push(`<path d="${td}" fill="none" stroke="${shade(P.coat, P.dark ? 0 : -0.08)}" stroke-width="${t.w + 0.6}" stroke-linecap="round"/>`);
    const tu = sp(t.tuft.pts);
    o.push(`<path d="${tu}" fill="${P.tuft}"/><path d="${tu}" fill="${LIT}"/>`);
    // 身體
    const bd = sp(M.body.pts);
    const bc = clip('body', bd);
    o.push(`<path d="${bd}" fill="${P.coat}"/>`);
    o.push(`<g clip-path="${bc}">`);
    M.pattern.body.forEach((b) => o.push(`<path d="${sp(b)}" fill="${P.pat}"/>`));
    M.pattern.dots.filter((d) => d.where === 'body').forEach((d) => o.push(`<circle cx="${d.cx}" cy="${d.cy}" r="${d.r}" fill="${P.pat}"/>`));
    M.pattern.seeds.filter((d) => d.where === 'body').forEach((d) => o.push(seedC(d, P)));
    // 頭投在身體上的柔和陰影
    o.push(`<path d="${sp(M.head.pts)}" transform="translate(${-lx * 3},6)" fill="#2A1030" opacity="0.22" filter="url(#c-blur3)"/>`);
    o.push(`</g>`);
    o.push(`<path d="${bd}" fill="${LIT}"/>`);
    const B = M.body;
    o.push(`<ellipse cx="${B.cx + lx * B.rx * 0.28}" cy="${B.cy - B.ry * 0.58}" rx="${B.rx * 0.34}" ry="${B.ry * 0.16}" fill="url(#c-spec)" opacity="${P.dark ? 0.45 : 0.85}"/>`);
    o.push(edge(bd));
  }

  const H = M.head;
  // 角
  M.horns.forEach((h, i) => {
    const d = polyPath(h.pts);
    const tipPts = taperPts(bezierAt(h.p0, h.p1, h.p2, h.tipFrom), bezierAt(h.p0, h.p1, h.p2, (1 + h.tipFrom) / 2), h.p2, 9, 1, 8);
    const hc = clip(`horn${i}`, d);
    o.push(`<path d="${d}" fill="${P.horn0}"/>`);
    o.push(`<path d="${polyPath(tipPts)}" fill="${P.horn1}" clip-path="${hc}" filter="url(#c-blur1)"/>`);
    o.push(`<path d="${d}" fill="${LIT}"/>`);
    o.push(edge(d, '#9A7A55', 0.35, 0.9));
  });
  // 耳朵
  M.ears.forEach((e) => {
    const d = sp(e.pts);
    o.push(`<path d="${d}" fill="${P.ear}"/>`);
    o.push(`<path d="${sp(e.inner)}" fill="${P.earIn}"/>`);
    o.push(`<path d="${d}" fill="${LIT}"/>`);
    o.push(edge(d, shade(P.ear, P.dark ? 0 : -0.3), 0.3));
  });
  // 頭
  const hd = sp(H.pts);
  const hc = clip('head', hd);
  o.push(`<path d="${hd}" fill="${P.coat}"/>`);
  o.push(`<g clip-path="${hc}">`);
  M.pattern.head.forEach((b) => o.push(`<path d="${sp(b)}" fill="${P.pat}"/>`));
  M.pattern.dots.filter((d) => d.where === 'head').forEach((d) => o.push(`<circle cx="${d.cx}" cy="${d.cy}" r="${d.r}" fill="${P.pat}"/>`));
  M.pattern.seeds.filter((d) => d.where === 'head').forEach((d) => o.push(seedC(d, P)));
  // 口鼻在臉上的陰影
  o.push(`<path d="${sp(M.muzzle.pts)}" transform="translate(0,3)" fill="#2A1030" opacity="0.18" filter="url(#c-blur2)"/>`);
  if (M.fringe) o.push(`<path d="${sp(M.fringe.pts)}" transform="translate(0,3.5)" fill="#2A1030" opacity="0.25" filter="url(#c-blur2)"/>`);
  o.push(`</g>`);
  o.push(`<path d="${hd}" fill="${LIT}"/>`);
  o.push(`<ellipse cx="${H.cx + lx * H.rx * 0.36}" cy="${H.cy - H.ry * 0.6}" rx="${H.rx * 0.3}" ry="${H.ry * 0.17}" fill="url(#c-spec)" opacity="${P.dark ? 0.5 : 0.9}"/>`);
  o.push(edge(hd));
  // 眼睛
  M.eyes.forEach((e) => {
    o.push(`<ellipse cx="${e.cx}" cy="${e.cy + 0.6}" rx="${e.rx + 0.6}" ry="${e.ry + 0.6}" fill="#2A1030" opacity="0.18" filter="url(#c-blur1)"/>`);
    o.push(`<ellipse cx="${e.cx}" cy="${e.cy}" rx="${e.rx}" ry="${e.ry}" fill="${EYE}"/>`);
    o.push(`<ellipse cx="${e.cx + lx * e.rx * 0.3}" cy="${e.cy - e.ry * 0.36}" rx="${e.rx * 0.42}" ry="${e.ry * 0.36}" fill="#FFFFFF"/>`);
    o.push(`<circle cx="${e.cx - lx * e.rx * 0.36}" cy="${e.cy + e.ry * 0.42}" r="${e.rx * 0.17}" fill="#FFFFFF" opacity="0.9"/>`);
    if (M.lashes) {
      const sd = e.side, x0 = e.cx + sd * e.rx * 0.78, y0 = e.cy - e.ry * 0.6;
      o.push(`<path d="M${x0},${y0} l${sd * 2.8},-2.4 M${x0 - sd * 1.6},${y0 - 1.5} l${sd * 1.8},-3" stroke="#2A2230" stroke-width="1.4" stroke-linecap="round" fill="none"/>`);
    }
  });
  // 瀏海
  if (M.fringe) {
    const d = sp(M.fringe.pts);
    o.push(`<path d="${d}" fill="${P.fringe}"/><path d="${d}" fill="${LIT}"/>`);
    o.push(`<ellipse cx="${H.cx + lx * H.rx * 0.3}" cy="${H.cy - H.ry * 0.72}" rx="${H.rx * 0.34}" ry="${H.ry * 0.12}" fill="url(#c-spec)" opacity="0.7"/>`);
    o.push(edge(d, shade(P.fringe, -0.3), 0.3));
  }
  // 腮紅
  M.cheeks.forEach((c) => o.push(`<ellipse cx="${c.cx}" cy="${c.cy}" rx="${c.rx * 1.35}" ry="${c.ry * 1.35}" fill="url(#c-blush)"/>`));
  // 口鼻
  const Mz = M.muzzle;
  const md = sp(Mz.pts);
  o.push(`<path d="${md}" fill="${P.muzzle}"/>`);
  o.push(`<path d="${md}" fill="${LIT}"/>`);
  o.push(`<ellipse cx="${Mz.cx + lx * Mz.rx * 0.36}" cy="${Mz.cy - Mz.ry * 0.46}" rx="${Mz.rx * 0.34}" ry="${Mz.ry * 0.2}" fill="url(#c-spec)" opacity="0.9"/>`);
  o.push(edge(md, shade(P.muzzle, -0.3), 0.3));
  M.nostrils.forEach((n) => {
    const rot = `rotate(${(n.rot * 180) / Math.PI} ${n.cx} ${n.cy})`;
    o.push(`<ellipse cx="${n.cx}" cy="${n.cy}" rx="${n.rx}" ry="${n.ry}" transform="${rot}" fill="${P.nostril}"/>`);
    o.push(`<ellipse cx="${n.cx}" cy="${n.cy + n.ry * 0.55}" rx="${n.rx * 0.8}" ry="${n.ry * 0.35}" transform="${rot}" fill="#FFFFFF" opacity="0.35"/>`);
  });
  const m = M.mouth;
  o.push(`<path d="M${m.cx - m.w},${m.cy - 0.6} q${m.w / 2},${m.w * 0.75} ${m.w},0 q${m.w / 2},${m.w * 0.75} ${m.w},0" fill="none" stroke="${shade(P.muzzle, -0.45)}" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/>`);
  if (M.overlay) o.push(overlayC(M, LIT, lx));

  const sx = mirror ? -s : s;
  return `<g transform="translate(${x},${y}) scale(${sx},${s})"><defs>${defs.join('')}</defs>${o.join('')}</g>`;
}

function seedC(d, P) {
  const r = 1.55, rot = `rotate(${(d.rot * 180) / Math.PI} ${d.cx} ${d.cy})`;
  return `<ellipse cx="${d.cx}" cy="${d.cy + 0.5}" rx="${r}" ry="${r * 1.5}" transform="${rot}" fill="#C2566F" opacity="0.35"/>`
    + `<ellipse cx="${d.cx}" cy="${d.cy}" rx="${r}" ry="${r * 1.5}" transform="${rot}" fill="${P.seed}"/>`;
}

function overlayC(M, LIT, lx) {
  const ov = M.overlay, out = [];
  if (ov.type === 'berry') {
    const [a, b] = ov.stem;
    out.push(`<path d="M${a[0]},${a[1]} Q${a[0] - 1},${(a[1] + b[1]) / 2} ${b[0]},${b[1]}" stroke="#5E9E48" stroke-width="2.8" stroke-linecap="round" fill="none"/>`);
    ov.leaves.forEach((L) => {
      const d = smoothPath(L);
      out.push(`<path d="${d}" fill="#5CBF5E"/><path d="${d}" fill="${LIT}"/>`);
    });
    out.push(`<circle cx="${ov.c[0]}" cy="${ov.c[1]}" r="2.6" fill="#3F9A48"/>`);
  } else if (ov.type === 'cream') {
    out.push(`<ellipse cx="${ov.c[0]}" cy="${ov.c[1] + 2}" rx="11" ry="4" fill="#2A1030" opacity="0.2" filter="url(#c-blur2)"/>`);
    ov.tiers.forEach((t) => {
      out.push(`<ellipse cx="${t.cx}" cy="${t.cy}" rx="${t.rx}" ry="${t.ry}" fill="#FFF7EA"/>`);
      out.push(`<ellipse cx="${t.cx}" cy="${t.cy}" rx="${t.rx}" ry="${t.ry}" fill="${LIT}"/>`);
    });
    const tp = ov.tip, t3 = ov.tiers[2];
    const d = `M${t3.cx - 3},${t3.cy - 2} Q${tp[0] - 3},${tp[1] + 2} ${tp[0]},${tp[1]} Q${tp[0] + 0.5},${tp[1] + 4} ${t3.cx + 3.5},${t3.cy - 2}Z`;
    out.push(`<path d="${d}" fill="#FFF7EA"/><path d="${d}" fill="${LIT}"/>`);
    out.push(`<ellipse cx="${ov.c[0] + lx * 3}" cy="${ov.c[1] - 7}" rx="3" ry="1.5" fill="#FFFFFF" opacity="0.9"/>`);
    out.push(`<rect x="${ov.c[0] - 6}" y="${ov.c[1] - 3}" width="3" height="2.2" rx="0.9" fill="#6B3D24" transform="rotate(-20 ${ov.c[0] - 5} ${ov.c[1] - 2})"/>`);
    out.push(`<rect x="${ov.c[0] + 4}" y="${ov.c[1] - 7}" width="3" height="2.2" rx="0.9" fill="#7A4A2D" transform="rotate(25 ${ov.c[0] + 5} ${ov.c[1] - 6})"/>`);
  }
  return out.join('');
}

// 圖庫用
export function renderCell(M, { id = 'cell', size = 150 } = {}) {
  const b = M.bbox, pad = 8;
  const w = (b.x1 - b.x0) * M.unit + pad * 2, h = (b.y1 - b.y0) * M.unit + pad * 2;
  const s = Math.max(w, h);
  return `<svg viewBox="${b.x0 * M.unit - pad - (s - w) / 2} ${b.y0 * M.unit - pad - (s - h)} ${s} ${s}" width="${size}" height="${size}"><defs>${defsC()}</defs>`
    + cowC(M, { id }) + `</svg>`;
}
