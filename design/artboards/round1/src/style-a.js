// 風格 A「圓潤Q版」：場景、圖示、數字與小圖表。牛一律由 cowgen.js → cowgen-a.js 產生。
import { BREEDS, genesFor } from './data.js';
import { buildCow, rng, smoothPath } from './cowgen.js';
import { cowA, A_OUTLINE as L } from './cowgen-a.js';

export const name = 'a';
const W = 390, H = 844;
const SCALE = [0.8, 0.9, 1.0];

// ---------- 圖示 ----------
const I = {
  coin: `<svg viewBox="0 0 34 34" width="34" height="34"><circle cx="17" cy="17.8" r="14.6" fill="#E7A93A" stroke="${L}" stroke-width="2.6"/><circle cx="17" cy="16.2" r="13" fill="#FFD45E"/><circle cx="17" cy="16.2" r="9.6" fill="#FFC53D" stroke="#E9A22D" stroke-width="1.4"/>
    <path d="M17 9.6c-3.1 0-4.8 2.3-4.8 5.2v2.7l-1.5 2.1h12.6l-1.5-2.1v-2.7c0-2.9-1.7-5.2-4.8-5.2z" fill="#FFF4CC" stroke="#B87818" stroke-width="1.4" stroke-linejoin="round"/><circle cx="17" cy="21.2" r="1.6" fill="#B87818"/><path d="M16.2 9.5v-1.5h1.6v1.5" fill="none" stroke="#B87818" stroke-width="1.3"/>
    <path d="M7.6 12.4a10 10 0 0 1 5.2-5" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" fill="none"/><circle cx="17" cy="17.8" r="14.6" fill="none" stroke="${L}" stroke-width="2.6"/></svg>`,
  news: `<svg viewBox="0 0 28 28" width="22" height="22"><path d="M8.5 17.5l1.6 5.2h3.4l-1.2-5.2" fill="#FFE3DD" stroke="${L}" stroke-width="2.1" stroke-linejoin="round"/><path d="M5 10.5h4.2l9.3-5.2v17.4l-9.3-5.2H5a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2z" fill="#FF8C7C" stroke="${L}" stroke-width="2.2" stroke-linejoin="round"/><path d="M22 10a5.4 5.4 0 0 1 0 8" stroke="${L}" stroke-width="2.2" stroke-linecap="round" fill="none"/><path d="M6 12.4h2.4" stroke="#FFFFFF" stroke-width="1.8" stroke-linecap="round"/></svg>`,
  bottle: `<svg viewBox="0 0 28 30" width="24" height="26"><path d="M10.8 5h6.4v3.6l3.3 3.8v12.4a2.8 2.8 0 0 1-2.8 2.8h-7.4a2.8 2.8 0 0 1-2.8-2.8V12.4l3.3-3.8z" fill="#FFFFFF" stroke="${L}" stroke-width="2.1" stroke-linejoin="round"/><path d="M7.5 16.5h13v6h-13z" fill="#A9DBFF"/><circle cx="14" cy="19.5" r="2" fill="#FFFFFF"/><path d="M10.8 5h6.4v3.6l3.3 3.8v12.4a2.8 2.8 0 0 1-2.8 2.8h-7.4a2.8 2.8 0 0 1-2.8-2.8V12.4l3.3-3.8z" fill="none" stroke="${L}" stroke-width="2.1" stroke-linejoin="round"/><rect x="10" y="2.2" width="8" height="4" rx="1.4" fill="#6FBDF0" stroke="${L}" stroke-width="1.9"/><path d="M10.2 13v9" stroke="#E3F1FB" stroke-width="1.8" stroke-linecap="round"/></svg>`,
  crate: `<svg viewBox="0 0 30 30" width="25" height="25"><path d="M4 11.5h22v12.3a2.5 2.5 0 0 1-2.5 2.5h-17A2.5 2.5 0 0 1 4 23.8z" fill="#F5BD83" stroke="${L}" stroke-width="2.1" stroke-linejoin="round"/><path d="M4 18.5h22" stroke="#C98B52" stroke-width="1.6"/><path d="M2.8 11.5l3-5.3h18.4l3 5.3z" fill="#FFD6A6" stroke="${L}" stroke-width="2.1" stroke-linejoin="round"/>
    <path d="M10.5 15.6c.3-2.4 2.8-3.8 5.4-3.3 2.9.5 4.8 2.5 4.2 5.2-.6 2.6-3.3 3.7-5.8 3.2-2.6-.5-4.1-2.6-3.8-5.1z" fill="#FF8D9C" stroke="${L}" stroke-width="1.6"/><path d="M13 16.6c.3-1.3 1.8-2 3.2-1.6" stroke="#FFFFFF" stroke-width="1.5" stroke-linecap="round" fill="none"/></svg>`,
  leaf: `<svg viewBox="0 0 16 16" width="14" height="14"><path d="M2.6 13.4C2.4 6.6 7 2.6 13.8 2.4c.2 6.6-3.6 11.2-11.2 11z" fill="#86DB7E" stroke="${L}" stroke-width="1.6" stroke-linejoin="round"/><path d="M3.6 12.4l6.2-6.2" stroke="${L}" stroke-width="1.3" stroke-linecap="round"/></svg>`,
  up: `<svg class="tri" viewBox="0 0 12 12" width="11" height="11"><path d="M6 1.6l4.8 8H1.2z" fill="currentColor" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"/></svg>`,
  down: `<svg class="tri" viewBox="0 0 12 12" width="11" height="11"><path d="M6 10.4l4.8-8H1.2z" fill="currentColor" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"/></svg>`,
  bubble: `<svg viewBox="0 0 24 24" width="22" height="22"><path d="M6.5 9C6.5 3.5 17.5 3.5 17.5 9" fill="none" stroke="${L}" stroke-width="2"/><path d="M4.5 9h15l-2 11a2.2 2.2 0 0 1-2.2 1.8H8.7A2.2 2.2 0 0 1 6.5 20z" fill="#FFFFFF" stroke="${L}" stroke-width="2" stroke-linejoin="round"/><path d="M5.2 12.2h13.6" stroke="#A9DBFF" stroke-width="2.2"/><rect x="3.5" y="7.6" width="17" height="3.4" rx="1.7" fill="#E6F3FC" stroke="${L}" stroke-width="1.8"/></svg>`,
  'tab-ranch': (on) => `<svg viewBox="0 0 34 34" width="30" height="30"><path d="M4 15.5L17 5l13 10.5v13.2a1.8 1.8 0 0 1-1.8 1.8H5.8A1.8 1.8 0 0 1 4 28.7z" fill="${on ? '#FF9784' : '#FFD2C8'}" stroke="${L}" stroke-width="2.4" stroke-linejoin="round"/><path d="M2.6 16.2L17 4.4l14.4 11.8" fill="none" stroke="${L}" stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round"/><path d="M2.6 16.2L17 4.4l14.4 11.8" fill="none" stroke="${on ? '#E8665A' : '#F4A89C'}" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/><rect x="11.5" y="19" width="11" height="11.5" fill="#FFFFFF" stroke="${L}" stroke-width="2"/><path d="M11.5 19l11 11.5M22.5 19l-11 11.5" stroke="${on ? '#FF9784' : '#FFD2C8'}" stroke-width="1.8"/><circle cx="17" cy="13" r="2.4" fill="#FFD36B" stroke="${L}" stroke-width="1.6"/></svg>`,
  'tab-market': (on) => `<svg viewBox="0 0 34 34" width="30" height="30"><rect x="6" y="15" width="22" height="15" rx="1.8" fill="#FFF6E6" stroke="${L}" stroke-width="2.3"/><path d="M4 9.5l3-5h20l3 5v2.8a3.3 3.3 0 0 1-6.5 0 3.3 3.3 0 0 1-6.5 0 3.3 3.3 0 0 1-6.5 0 3.3 3.3 0 0 1-6.5 0z" fill="${on ? '#8EDDB6' : '#CDEFDD'}" stroke="${L}" stroke-width="2.3" stroke-linejoin="round"/><path d="M10.5 9.5v2.8M17 9.5v2.8M23.5 9.5v2.8" stroke="${L}" stroke-width="1.6"/><path d="M10 26l4-4.5 3 2.6 5-5.6" fill="none" stroke="#FF6B6B" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  'tab-breed': (on) => `<svg viewBox="0 0 34 34" width="30" height="30"><path d="M17 29.2C8.5 23.6 4.2 18.6 4.2 13.2A6.8 6.8 0 0 1 17 9.8a6.8 6.8 0 0 1 12.8 3.4c0 5.4-4.3 10.4-12.8 16z" fill="${on ? '#FF8FB1' : '#FFD0DE'}" stroke="${L}" stroke-width="2.4" stroke-linejoin="round"/><path d="M9 12.6a3.4 3.4 0 0 1 3.4-2.6" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" fill="none"/><path d="M26.5 3.5l1 2.6 2.6 1-2.6 1-1 2.6-1-2.6-2.6-1 2.6-1z" fill="#FFD36B" stroke="${L}" stroke-width="1.3" stroke-linejoin="round"/></svg>`,
  'tab-dex': (on) => `<svg viewBox="0 0 34 34" width="30" height="30"><path d="M6 6.5A2.5 2.5 0 0 1 8.5 4H27v22H8.5A2.5 2.5 0 0 0 6 28.5z" fill="${on ? '#9FD2FF' : '#D5EBFF'}" stroke="${L}" stroke-width="2.3" stroke-linejoin="round"/><path d="M6 28.5A2.5 2.5 0 0 1 8.5 26H27v4H8.5A2.5 2.5 0 0 1 6 28.5z" fill="#FFFFFF" stroke="${L}" stroke-width="2.3" stroke-linejoin="round"/><path d="M13 10.5c2-1.6 5-1.2 5.6 1 .6 2.4-2 3.4-3.8 2.8-1.8-.6-3.2-2.4-1.8-3.8zM20 16.5c1.5-.8 3.4 0 3.2 1.6-.2 1.5-2.2 1.9-3.2 1-1-.8-.9-2.1 0-2.6z" fill="${L}"/></svg>`,
  'tab-rank': (on) => `<svg viewBox="0 0 34 34" width="30" height="30"><path d="M10 5h14v7.5a7 7 0 0 1-14 0z" fill="${on ? '#FFD45E' : '#FFEAB0'}" stroke="${L}" stroke-width="2.3" stroke-linejoin="round"/><path d="M10 7.5H6.2a4.5 4.5 0 0 0 4.6 6.5M24 7.5h3.8a4.5 4.5 0 0 1-4.6 6.5" fill="none" stroke="${L}" stroke-width="2.2" stroke-linecap="round"/><path d="M17 19.5v4.5" stroke="${L}" stroke-width="2.6"/><rect x="10.5" y="24" width="13" height="5.5" rx="1.6" fill="#F5BD83" stroke="${L}" stroke-width="2.2"/><path d="M13.4 8.2v4" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round"/></svg>`,
};

export function icon(name, opts = {}) {
  const v = I[name];
  return typeof v === 'function' ? v(!!opts.active) : v || '';
}

export function num(text, role, opts = {}) {
  return `<span class="num num-${role}${opts.dir ? ' ' + opts.dir : ''}">${text}</span>`;
}

export function avatar() {
  const M = buildCow({ ...BREEDS.holstein, seed: 7 });
  const b = M.headBox, pad = 6;
  const w = b.x1 - b.x0 + pad * 2, h = b.y1 - b.y0 + pad * 2, s = Math.max(w, h);
  return `<svg viewBox="${b.x0 - pad - (s - w) / 2} ${b.y0 - pad - (s - h) / 2 + 3} ${s} ${s}" width="46" height="46">${cowA(M, { id: 'av', headOnly: true, lineW: 3.6 })}</svg>`;
}

export function spark(series, dir) {
  const w = 74, h = 30, p = 4;
  const min = Math.min(...series), max = Math.max(...series);
  const pts = series.map((v, i) => [p + (i / (series.length - 1)) * (w - p * 2), p + (1 - (v - min) / (max - min)) * (h - p * 2)]);
  const c = dir === 'up' ? '#F0524F' : '#2FA866';
  const line = smoothPath(pts, false);
  const area = `${line}L${pts[pts.length - 1][0]},${h}L${pts[0][0]},${h}Z`;
  const e = pts[pts.length - 1];
  return `<svg viewBox="0 0 ${w} ${h}" width="${w}" height="${h}"><path d="${area}" fill="${c}" opacity="0.14"/><path d="${line}" fill="none" stroke="${c}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/><circle cx="${e[0]}" cy="${e[1]}" r="3.6" fill="#FFFFFF" stroke="${c}" stroke-width="2.4"/></svg>`;
}

export function bucket(pct) {
  const top = 17, bot = 44.5, lvl = bot - (bot - top) * (pct / 100);
  const body = 'M8 16.5h32l-3.4 25.4a3 3 0 0 1-3 2.6H14.4a3 3 0 0 1-3-2.6z';
  return `<svg viewBox="0 0 48 48" width="48" height="48"><defs><clipPath id="a-bk"><path d="${body}"/></clipPath></defs>
    <path d="M11 17C11 5.5 37 5.5 37 17" fill="none" stroke="${L}" stroke-width="2.6"/>
    <path d="${body}" fill="#D6ECFA"/>
    <g clip-path="url(#a-bk)"><path d="M0 ${lvl} q6 -2.6 12 0 t12 0 t12 0 t12 0 V48 H0z" fill="#FFFFFF"/><path d="M0 ${lvl} q6 -2.6 12 0 t12 0 t12 0 t12 0" fill="none" stroke="#B9DDF5" stroke-width="1.6"/></g>
    <path d="${body}" fill="none" stroke="${L}" stroke-width="2.6" stroke-linejoin="round"/>
    <path d="M13.5 22v15" stroke="#FFFFFF" stroke-width="2.4" stroke-linecap="round" opacity="0.9"/>
    <rect x="6.4" y="13.6" width="35.2" height="5.4" rx="2.7" fill="#EAF5FC" stroke="${L}" stroke-width="2.4"/></svg>`;
}

// ---------- 場景 ----------
function cloud(x, y, s) {
  const d = `M${x - 30 * s},${y + 8 * s} a${12 * s},${12 * s} 0 0 1 ${6 * s},${-18 * s} a${15 * s},${15 * s} 0 0 1 ${26 * s},${-8 * s} a${13 * s},${13 * s} 0 0 1 ${22 * s},${6 * s} a${10 * s},${10 * s} 0 0 1 ${6 * s},${20 * s} z`;
  return `<path d="${d}" fill="#FFFFFF"/><path d="M${x - 26 * s},${y + 6 * s} h${54 * s}" stroke="#DCEFFC" stroke-width="${5 * s}" stroke-linecap="round"/>`;
}
function tree(x, y, r, c = '#8FD68A') {
  return `<rect x="${x - 3}" y="${y - 4}" width="6" height="14" rx="2" fill="#C98E5E" stroke="${L}" stroke-width="2.2"/><circle cx="${x}" cy="${y - r}" r="${r}" fill="${c}" stroke="${L}" stroke-width="2.4"/><path d="M${x - r * 0.55},${y - r * 1.3} a${r * 0.6},${r * 0.6} 0 0 1 ${r * 0.5},${-r * 0.35}" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" fill="none" opacity="0.8"/>`;
}
function tuft(x, y, s = 1) {
  return `<path d="M${x - 6 * s},${y} q${2 * s},${-6 * s} ${3 * s},${-7 * s} q${1 * s},${4 * s} ${3 * s},${7 * s} q${1.5 * s},${-5 * s} ${3 * s},${-8 * s} q${1 * s},${5 * s} ${3 * s},${8 * s}" fill="none" stroke="#6FBF5E" stroke-width="${2.2 * s}" stroke-linecap="round" stroke-linejoin="round"/>`;
}
function flower(x, y, c) {
  let petals = '';
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * Math.PI * 2 - Math.PI / 2;
    petals += `<circle cx="${x + Math.cos(a) * 3.3}" cy="${y + Math.sin(a) * 3.3}" r="2.6" fill="${c}" stroke="${L}" stroke-width="1.2"/>`;
  }
  return `${petals}<circle cx="${x}" cy="${y}" r="2.2" fill="#FFD04D" stroke="${L}" stroke-width="1.1"/>`;
}
function sparkle(x, y, r) {
  return `<path d="M${x},${y - r} Q${x + r * 0.18},${y - r * 0.18} ${x + r},${y} Q${x + r * 0.18},${y + r * 0.18} ${x},${y + r} Q${x - r * 0.18},${y + r * 0.18} ${x - r},${y} Q${x - r * 0.18},${y - r * 0.18} ${x},${y - r}z" fill="#FFE27A" stroke="${L}" stroke-width="1.6" stroke-linejoin="round"/>`;
}

export function scene(el, herd) {
  const o = [];
  o.push(`<defs><linearGradient id="a-sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#94D3FF"/><stop offset="0.5" stop-color="#C4E9FF"/><stop offset="1" stop-color="#E4F6FF"/></linearGradient></defs>`);
  o.push(`<rect width="${W}" height="${H}" fill="url(#a-sky)"/>`);
  // 太陽與雲
  o.push(`<circle cx="356" cy="168" r="17" fill="#FFE58A" stroke="${L}" stroke-width="2.4"/><circle cx="356" cy="168" r="24" fill="#FFE58A" opacity="0.35"/>`);
  o.push(cloud(232, 176, 1.05), cloud(330, 196, 0.75), cloud(52, 162, 0.7));
  // 遠山
  o.push(`<path d="M-10,246 C40,214 108,210 170,236 C222,206 300,198 400,232 L400,320 L-10,320Z" fill="#C6ECAB" stroke="#8CC77E" stroke-width="2.6"/>`);
  o.push(tree(196, 238, 9, '#9EDC8F'), tree(212, 236, 7, '#B2E6A0'), tree(372, 226, 11), tree(352, 232, 8, '#A6E196'));
  // 草地
  o.push(`<path d="M-10,266 C110,252 250,250 400,260 L400,${H} L-10,${H}Z" fill="#AEE594" stroke="${L}" stroke-width="2.8"/>`);
  o.push(`<ellipse cx="220" cy="440" rx="200" ry="100" fill="#BDEBA4" opacity="0.8"/>`);
  o.push(`<path d="M-10,600 C120,580 270,584 400,596 L400,${H} L-10,${H}Z" fill="#9FDC86"/>`);
  // 穀倉與筒倉
  o.push(`<rect x="130" y="210" width="30" height="92" rx="4" fill="#C4DDF3" stroke="${L}" stroke-width="2.8"/><path d="M130,236h30M130,262h30" stroke="#9FC3E4" stroke-width="2.4"/><path d="M128,212 a17,15 0 0 1 34,0z" fill="#97BFE5" stroke="${L}" stroke-width="2.8" stroke-linejoin="round"/><path d="M136,222v64" stroke="#FFFFFF" stroke-width="2.4" stroke-linecap="round" opacity="0.8"/>`);
  o.push(`<path d="M22,238 L72,194 L122,238 L122,302 L22,302Z" fill="#FF9A86" stroke="${L}" stroke-width="3" stroke-linejoin="round"/>`);
  o.push(`<path d="M30,250h84M26,264h92M26,278h92" stroke="#F4806D" stroke-width="1.8"/>`);
  o.push(`<path d="M8,236 L72,178 L136,236 L128,244 L72,194 L16,244Z" fill="#E86A5E" stroke="${L}" stroke-width="3" stroke-linejoin="round"/><path d="M20,236 L72,189 L124,236" fill="none" stroke="#FF9E8E" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>`);
  o.push(`<rect x="50" y="256" width="44" height="46" rx="2" fill="#E86A5E" stroke="${L}" stroke-width="2.8"/><rect x="53.5" y="259.5" width="37" height="39" fill="none" stroke="#FFF4EA" stroke-width="3"/><path d="M55,261 L89,297 M89,261 L55,297 M72,259 V299" stroke="#FFF4EA" stroke-width="3"/>`);
  o.push(`<circle cx="72" cy="226" r="10" fill="#FFD36B" stroke="#FFF4EA" stroke-width="3"/><circle cx="72" cy="226" r="11.6" fill="none" stroke="${L}" stroke-width="2.2"/><path d="M66,226h12M68,222h8M68,230h8" stroke="#E8A93A" stroke-width="1.6"/>`);
  // 柵欄
  const fenceY = 282;
  let posts = '';
  for (let x = 6; x < W + 20; x += 36) posts += `<path d="M${x - 5},${fenceY + 36} V${fenceY + 4} a5,5 0 0 1 10,0 V${fenceY + 36}Z" fill="#FFF4DE" stroke="${L}" stroke-width="2.6" stroke-linejoin="round"/>`;
  o.push(`<rect x="-6" y="${fenceY + 8}" width="${W + 12}" height="7" rx="3.5" fill="#FFE9C4" stroke="${L}" stroke-width="2.4"/><rect x="-6" y="${fenceY + 22}" width="${W + 12}" height="7" rx="3.5" fill="#FFE9C4" stroke="${L}" stroke-width="2.4"/>`);
  o.push(posts);
  // 草叢與花
  const r = rng(42);
  const cows = herd.map((c) => ({ x: c.x, y: c.y }));
  const free = (x, y) => cows.every((c) => Math.abs(c.x - x) > 52 || y > c.y + 6 || y < c.y - 70);
  for (let i = 0, n = 0; i < 400 && n < 22; i++) {
    const x = 10 + r() * 370, y = 336 + r() * 200;
    if (!free(x, y)) continue;
    o.push(tuft(x, y, 0.8 + r() * 0.4)); n++;
  }
  const fc = ['#FFFFFF', '#FFC2D4', '#FFFFFF', '#FFE08A'];
  for (let i = 0, n = 0; i < 400 && n < 11; i++) {
    const x = 12 + r() * 366, y = 344 + r() * 196;
    if (!free(x, y)) continue;
    o.push(flower(x, y, fc[n % fc.length])); n++;
  }
  // 乾草捆
  o.push(`<g transform="translate(366,524)"><rect x="-24" y="-30" width="40" height="30" rx="10" fill="#FFD77E" stroke="${L}" stroke-width="2.8"/><ellipse cx="16" cy="-15" rx="10" ry="15" fill="#FFE7A6" stroke="${L}" stroke-width="2.8"/><path d="M16,-15 m-4,0 a4,5 0 1 1 4,5 a7,9 0 1 1 3,-12" fill="none" stroke="#E0A93E" stroke-width="1.8" stroke-linecap="round"/><path d="M-18,-22h22M-18,-12h22" stroke="#E7B24C" stroke-width="1.8" stroke-linecap="round"/></g>`);

  // 牛（依深度由後往前）
  let bubble = null;
  const sorted = [...herd].sort((a, b) => a.depth - b.depth || a.y - b.y);
  sorted.forEach((c, i) => {
    const M = buildCow(genesFor(c));
    const s = SCALE[c.depth];
    o.push(`<ellipse cx="${c.x + (c.facing === 'right' ? -1 : 1) * M.shadow.cx * s * M.unit}" cy="${c.y + 1}" rx="${M.shadow.rx * s * M.unit}" ry="${M.shadow.ry * s * M.unit}" fill="#86CC70"/>`);
    o.push(cowA(M, { x: c.x, y: c.y, scale: s, facing: c.facing, id: `a${i}` }));
    const mir = c.facing === 'right' ? -1 : 1;
    const hx = c.x + mir * M.headTop[0] * s * M.unit, hy = c.y + M.headTop[1] * s * M.unit;
    if (c.bubble) bubble = [hx, hy - 6];
    if (BREEDS[c.breed].special) o.push(sparkle(hx + 24 * s, hy + 6, 5.5 * s), sparkle(hx - 20 * s, hy + 14, 3.6 * s));
  });
  el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" width="${W}" height="${H}">${o.join('')}</svg>`;
  return { bubble };
}
