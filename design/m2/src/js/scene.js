// 牧場場景（沿用 R1-A 的背景：天空、遠山、穀倉、柵欄、草地），牛換成 M2 假資料裡的牛。
// 場景畫在 390×844 的座標裡，依手機大小等比例放大、置中裁切（430×932 的比例幾乎一樣，只是放大 1.1 倍）。
import { drawCow } from '../cow/render.js';
import { rng } from '../cow/r1/cowgen.js';
import { BREEDS } from '../cow/breeds.js';

const L = '#4B3326';
const SW = 390, SH = 844;
const SCALE = [0.8, 0.9, 1.0];
const SCENE_SCALE = 1.04;

// 牧場裡的牛（耕牛去田裡工作，不在牧場裡）
export const HERD = [
  { id: 5, breed: 'angus', sex: 'bull', x: 204, y: 334, facing: 'right', depth: 0 },
  { id: 8, breed: 'holstein', sex: 'bull', seed: 23, x: 318, y: 338, facing: 'left', depth: 0 },
  { id: 14, breed: 'jersey', sex: 'bull', seed: 85, x: 104, y: 344, facing: 'right', depth: 0 },
  { id: 3, breed: 'holstein', x: 70, y: 420, facing: 'right', depth: 1, milk: true },
  { id: 15, breed: 'holstein', age: 'calf', seed: 31, x: 186, y: 424, facing: 'right', depth: 1 },
  { id: 7, breed: 'jersey', x: 310, y: 422, facing: 'left', depth: 1, milk: true },
  { id: 12, breed: 'strawberry', x: 122, y: 522, facing: 'right', depth: 2, milk: true },
  { id: 11, breed: 'wagyu', x: 276, y: 500, facing: 'left', depth: 2 },
];

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
export function sparkle(x, y, r) {
  return `<path d="M${x},${y - r} Q${x + r * 0.18},${y - r * 0.18} ${x + r},${y} Q${x + r * 0.18},${y + r * 0.18} ${x},${y + r} Q${x - r * 0.18},${y + r * 0.18} ${x - r},${y} Q${x - r * 0.18},${y - r * 0.18} ${x},${y - r}z" fill="#FFE27A" stroke="${L}" stroke-width="1.6" stroke-linejoin="round"/>`;
}

// 背景（不含牛）
function backdrop(herd) {
  const o = [];
  o.push(`<defs><linearGradient id="a-sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#94D3FF"/><stop offset="0.5" stop-color="#C4E9FF"/><stop offset="1" stop-color="#E4F6FF"/></linearGradient></defs>`);
  o.push(`<rect x="-200" y="-200" width="${SW + 400}" height="${SH + 400}" fill="url(#a-sky)"/>`);
  o.push(`<circle cx="356" cy="168" r="17" fill="#FFE58A" stroke="${L}" stroke-width="2.4"/><circle cx="356" cy="168" r="24" fill="#FFE58A" opacity="0.35"/>`);
  o.push(cloud(232, 176, 1.05), cloud(330, 196, 0.75), cloud(52, 162, 0.7));
  o.push(`<path d="M-60,246 C40,214 108,210 170,236 C222,206 300,198 450,232 L450,320 L-60,320Z" fill="#C6ECAB" stroke="#8CC77E" stroke-width="2.6"/>`);
  o.push(tree(196, 238, 9, '#9EDC8F'), tree(212, 236, 7, '#B2E6A0'), tree(372, 226, 11), tree(352, 232, 8, '#A6E196'));
  o.push(`<path d="M-60,266 C110,252 250,250 450,260 L450,${SH + 200} L-60,${SH + 200}Z" fill="#AEE594" stroke="${L}" stroke-width="2.8"/>`);
  o.push(`<ellipse cx="220" cy="440" rx="200" ry="100" fill="#BDEBA4" opacity="0.8"/>`);
  o.push(`<path d="M-60,600 C120,580 270,584 450,596 L450,${SH + 200} L-60,${SH + 200}Z" fill="#9FDC86"/>`);
  o.push(`<rect x="130" y="210" width="30" height="92" rx="4" fill="#C4DDF3" stroke="${L}" stroke-width="2.8"/><path d="M130,236h30M130,262h30" stroke="#9FC3E4" stroke-width="2.4"/><path d="M128,212 a17,15 0 0 1 34,0z" fill="#97BFE5" stroke="${L}" stroke-width="2.8" stroke-linejoin="round"/><path d="M136,222v64" stroke="#FFFFFF" stroke-width="2.4" stroke-linecap="round" opacity="0.8"/>`);
  o.push(`<path d="M22,238 L72,194 L122,238 L122,302 L22,302Z" fill="#FF9A86" stroke="${L}" stroke-width="3" stroke-linejoin="round"/>`);
  o.push(`<path d="M30,250h84M26,264h92M26,278h92" stroke="#F4806D" stroke-width="1.8"/>`);
  o.push(`<path d="M8,236 L72,178 L136,236 L128,244 L72,194 L16,244Z" fill="#E86A5E" stroke="${L}" stroke-width="3" stroke-linejoin="round"/><path d="M20,236 L72,189 L124,236" fill="none" stroke="#FF9E8E" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>`);
  o.push(`<rect x="50" y="256" width="44" height="46" rx="2" fill="#E86A5E" stroke="${L}" stroke-width="2.8"/><rect x="53.5" y="259.5" width="37" height="39" fill="none" stroke="#FFF4EA" stroke-width="3"/><path d="M55,261 L89,297 M89,261 L55,297 M72,259 V299" stroke="#FFF4EA" stroke-width="3"/>`);
  o.push(`<circle cx="72" cy="226" r="10" fill="#FFD36B" stroke="#FFF4EA" stroke-width="3"/><circle cx="72" cy="226" r="11.6" fill="none" stroke="${L}" stroke-width="2.2"/><path d="M66,226h12M68,222h8M68,230h8" stroke="#E8A93A" stroke-width="1.6"/>`);
  const fenceY = 282;
  let posts = '';
  for (let x = -30; x < SW + 60; x += 36) posts += `<path d="M${x - 5},${fenceY + 36} V${fenceY + 4} a5,5 0 0 1 10,0 V${fenceY + 36}Z" fill="#FFF4DE" stroke="${L}" stroke-width="2.6" stroke-linejoin="round"/>`;
  o.push(`<rect x="-60" y="${fenceY + 8}" width="${SW + 120}" height="7" rx="3.5" fill="#FFE9C4" stroke="${L}" stroke-width="2.4"/><rect x="-60" y="${fenceY + 22}" width="${SW + 120}" height="7" rx="3.5" fill="#FFE9C4" stroke="${L}" stroke-width="2.4"/>`);
  o.push(posts);
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
  o.push(`<g transform="translate(366,524)"><rect x="-24" y="-30" width="40" height="30" rx="10" fill="#FFD77E" stroke="${L}" stroke-width="2.8"/><ellipse cx="16" cy="-15" rx="10" ry="15" fill="#FFE7A6" stroke="${L}" stroke-width="2.8"/><path d="M16,-15 m-4,0 a4,5 0 1 1 4,5 a7,9 0 1 1 3,-12" fill="none" stroke="#E0A93E" stroke-width="1.8" stroke-linecap="round"/><path d="M-18,-22h22M-18,-12h22" stroke="#E7B24C" stroke-width="1.8" stroke-linecap="round"/></g>`);
  return o.join('');
}

// 場景 → 手機座標的換算（等比例放大、置中裁切）
export function fit(dev) {
  const k = Math.max(dev.w / SW, dev.h / SH);
  const ox = (dev.w - SW * k) / 2, oy = (dev.h - SH * k) / 2;
  return { k, ox, oy, map: ([x, y]) => [x * k + ox, y * k + oy] };
}

// herd：每頭牛 { …, pose?: 'side'|'front' }；front 的牛轉正面（D11）
export function ranchScene(dev, herd = HERD, { extra = '' } = {}) {
  const F = fit(dev);
  const o = [backdrop(herd)];
  const anchors = {};
  const sorted = [...herd].sort((a, b) => a.depth - b.depth || a.y - b.y);
  sorted.forEach((c, i) => {
    const s = SCALE[c.depth] * SCENE_SCALE;
    const cow = drawCow({ breed: c.breed, sex: c.sex, age: c.age, seed: c.seed, pose: c.pose || 'side' }, { x: c.x, y: c.y, scale: s, facing: c.facing, id: `rs${i}` });
    o.push(`<ellipse cx="${cow.shadow.cx}" cy="${c.y + 1}" rx="${cow.shadow.rx}" ry="${cow.shadow.ry}" fill="#86CC70"/>`);
    o.push(`<g data-cow="${c.id}">${cow.svg}</g>`);
    const [hx, hy] = cow.headTop;
    if (BREEDS[c.breed].legend) o.push(sparkle(hx + 24 * s, hy + 8, 5.5 * s), sparkle(hx - 22 * s, hy + 16, 3.6 * s));
    anchors[c.id] = { head: F.map([hx, hy]), face: F.map([cow.face.cx, cow.face.cy]), faceR: cow.face.r * F.k, foot: F.map([c.x, c.y]), scale: s * F.k };
  });
  o.push(extra);
  const vb = [-F.ox / F.k, -F.oy / F.k, dev.w / F.k, dev.h / F.k].map((v) => Math.round(v * 100) / 100).join(' ');
  return { svg: `<svg viewBox="${vb}" width="${dev.w}" height="${dev.h}" aria-hidden="true">${o.join('')}</svg>`, anchors, fit: F };
}
