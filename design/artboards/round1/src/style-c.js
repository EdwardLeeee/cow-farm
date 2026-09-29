// 風格 C「軟萌立體」：柔和漸層、輕陰影，像黏土玩具。牛由 cowgen.js → cowgen-c.js 產生。
import { BREEDS, genesFor } from './data.js';
import { buildCow, rng, smoothPath } from './cowgen.js';
import { cowC, defsC } from './cowgen-c.js';

export const name = 'c';
const W = 390, H = 844;
const SCALE = [0.8, 0.9, 1.0];

// 共用漸層（每個圖示自帶一份，id 相同內容也相同）
const G = {
  gold: `<radialGradient id="ic-gold" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#FFF3B0"/><stop offset="0.45" stop-color="#FFD24D"/><stop offset="1" stop-color="#E59A1F"/></radialGradient>`,
  goldIn: `<radialGradient id="ic-goldin" cx="0.6" cy="0.7" r="0.8"><stop offset="0" stop-color="#FFE58A"/><stop offset="1" stop-color="#F0AE2E"/></radialGradient>`,
  coral: `<linearGradient id="ic-coral" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFB0A3"/><stop offset="1" stop-color="#F0685F"/></linearGradient>`,
  mint: `<linearGradient id="ic-mint" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#B8F0D2"/><stop offset="1" stop-color="#52C08E"/></linearGradient>`,
  pink: `<radialGradient id="ic-pink" cx="0.35" cy="0.3" r="0.85"><stop offset="0" stop-color="#FFD3E0"/><stop offset="0.5" stop-color="#FF8FB1"/><stop offset="1" stop-color="#E8588A"/></radialGradient>`,
  sky: `<linearGradient id="ic-sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#BFE6FF"/><stop offset="1" stop-color="#5BAEF0"/></linearGradient>`,
  wood: `<linearGradient id="ic-wood" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFD3A1"/><stop offset="1" stop-color="#D98E4E"/></linearGradient>`,
  milk: `<linearGradient id="ic-milk" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#FFFFFF"/><stop offset="0.6" stop-color="#F3F6FB"/><stop offset="1" stop-color="#D5DEEB"/></linearGradient>`,
  leaf: `<linearGradient id="ic-leaf" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#B7F09A"/><stop offset="1" stop-color="#4DB55A"/></linearGradient>`,
  metal: `<linearGradient id="ic-metal" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#EEF6FC"/><stop offset="0.35" stop-color="#FFFFFF"/><stop offset="1" stop-color="#A9C3DA"/></linearGradient>`,
  shadow: `<filter id="ic-sh" x="-30%" y="-30%" width="160%" height="170%"><feDropShadow dx="0" dy="1.6" stdDeviation="1.2" flood-color="#5A3C6E" flood-opacity="0.28"/></filter>`,
};
const svg = (vb, w, h, defs, body) => `<svg viewBox="${vb}" width="${w}" height="${h}"><defs>${defs.join('')}</defs><g filter="url(#ic-sh)">${body}</g></svg>`;

const I = {
  coin: () => svg('0 0 36 36', 36, 36, [G.gold, G.goldIn, G.shadow], `<circle cx="18" cy="18" r="15" fill="url(#ic-gold)"/><circle cx="18" cy="18" r="10.5" fill="url(#ic-goldin)"/>
    <path d="M18 10.6c-3.2 0-5 2.4-5 5.4v2.8l-1.6 2.2h13.2l-1.6-2.2V16c0-3-1.8-5.4-5-5.4z" fill="#FFF6D1" opacity="0.95"/><circle cx="18" cy="22.4" r="1.7" fill="#E8A22A"/>
    <ellipse cx="12.5" cy="10.5" rx="4.5" ry="2.4" transform="rotate(-35 12.5 10.5)" fill="#FFFFFF" opacity="0.75"/>`),
  news: () => svg('0 0 28 28', 24, 24, [G.coral, G.shadow], `<path d="M8.6 17.6l1.6 5.2a1.6 1.6 0 0 0 1.6 1.1h1.4l-1.3-6.3z" fill="#FFC9BF"/><path d="M5.2 10.4h4.4l9-5.2a1 1 0 0 1 1.5.9v15.8a1 1 0 0 1-1.5.9l-9-5.2H5.2a2.4 2.4 0 0 1-2.4-2.4v-2.4a2.4 2.4 0 0 1 2.4-2.4z" fill="url(#ic-coral)"/>
    <path d="M22.6 10.2a5.2 5.2 0 0 1 0 7.6" stroke="#F0685F" stroke-width="2.2" stroke-linecap="round" fill="none"/><ellipse cx="7" cy="12" rx="2.6" ry="1.2" fill="#FFFFFF" opacity="0.7"/>`),
  bottle: () => svg('0 0 28 30', 24, 26, [G.milk, G.sky, G.shadow], `<path d="M10.8 5h6.4v3.6l3.3 3.8v12.4a2.8 2.8 0 0 1-2.8 2.8h-7.4a2.8 2.8 0 0 1-2.8-2.8V12.4l3.3-3.8z" fill="url(#ic-milk)"/><rect x="7.5" y="16" width="13" height="6.5" fill="url(#ic-sky)" opacity="0.9"/><circle cx="14" cy="19.2" r="1.9" fill="#FFFFFF"/>
    <rect x="10" y="2" width="8" height="4.2" rx="1.6" fill="url(#ic-sky)"/><path d="M10.2 12.8v9.6" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round"/>`),
  crate: () => svg('0 0 30 30', 25, 25, [G.wood, G.pink, G.shadow], `<rect x="4" y="10.5" width="22" height="16" rx="3" fill="url(#ic-wood)"/><rect x="3" y="7" width="24" height="6" rx="2.6" fill="#FFDDB5"/>
    <path d="M4.5 19h21" stroke="#C07A3E" stroke-width="1.4" opacity="0.5"/><path d="M10.5 16.4c.3-2.4 2.8-3.8 5.4-3.3 2.9.5 4.8 2.5 4.2 5.2-.6 2.6-3.3 3.7-5.8 3.2-2.6-.5-4.1-2.6-3.8-5.1z" fill="url(#ic-pink)"/><ellipse cx="14.2" cy="15.8" rx="2" ry="1" fill="#FFFFFF" opacity="0.8"/>`),
  leaf: () => svg('0 0 16 16', 14, 14, [G.leaf, G.shadow], `<path d="M2.6 13.4C2.4 6.6 7 2.6 13.8 2.4c.2 6.6-3.6 11.2-11.2 11z" fill="url(#ic-leaf)"/><path d="M3.8 12.2l6-6" stroke="#FFFFFF" stroke-width="1.2" stroke-linecap="round" opacity="0.7"/>`),
  up: () => `<svg class="tri" viewBox="0 0 12 12" width="10" height="10"><path d="M6 1.8l4.6 7.6H1.4z" fill="currentColor" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/></svg>`,
  down: () => `<svg class="tri" viewBox="0 0 12 12" width="10" height="10"><path d="M6 10.2l4.6-7.6H1.4z" fill="currentColor" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/></svg>`,
  bubble: () => svg('0 0 24 24', 22, 22, [G.metal, G.shadow], `<path d="M6.5 9.5C6.5 3.6 17.5 3.6 17.5 9.5" fill="none" stroke="#9BB4CB" stroke-width="1.8"/><path d="M4.6 9.6h14.8l-2 10.6a2.4 2.4 0 0 1-2.4 2H9a2.4 2.4 0 0 1-2.4-2z" fill="url(#ic-metal)"/><ellipse cx="12" cy="9.8" rx="7.6" ry="2.2" fill="#FFFFFF"/><ellipse cx="12" cy="9.8" rx="6.2" ry="1.4" fill="#EAF4FD"/>`),
  'tab-ranch': (on) => svg('0 0 34 34', 30, 30, [G.coral, G.shadow], `<path d="M5 15.6L17 6l12 9.6v12.6a2.4 2.4 0 0 1-2.4 2.4H7.4A2.4 2.4 0 0 1 5 28.2z" fill="${on ? 'url(#ic-coral)' : '#CDBFDA'}"/><path d="M3.2 16.2L17 4.8l13.8 11.4" stroke="${on ? '#D4544C' : '#A796B8'}" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
    <rect x="12" y="19.5" width="10" height="11" rx="1.6" fill="#FFFFFF" opacity="0.92"/><circle cx="17" cy="13.4" r="2.4" fill="${on ? '#FFD86B' : '#FFFFFF'}"/>`),
  'tab-market': (on) => svg('0 0 34 34', 30, 30, [G.mint, G.shadow], `<rect x="6" y="14" width="22" height="16" rx="2.6" fill="#FFFFFF"/><path d="M4 9.6l3-5h20l3 5v2.6a3.3 3.3 0 0 1-6.5 0 3.3 3.3 0 0 1-6.5 0 3.3 3.3 0 0 1-6.5 0 3.3 3.3 0 0 1-6.5 0z" fill="${on ? 'url(#ic-mint)' : '#CDBFDA'}"/>
    <path d="M10 26l4-4.4 3 2.6 5-5.6" fill="none" stroke="${on ? '#F0524F' : '#A796B8'}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>`),
  'tab-breed': (on) => svg('0 0 34 34', 30, 30, [G.pink, G.shadow], `<path d="M17 29C8.6 23.5 4.4 18.6 4.4 13.4A6.6 6.6 0 0 1 17 10a6.6 6.6 0 0 1 12.6 3.4c0 5.2-4.2 10.1-12.6 15.6z" fill="${on ? 'url(#ic-pink)' : '#CDBFDA'}"/><ellipse cx="11" cy="12.8" rx="3" ry="1.8" transform="rotate(-30 11 12.8)" fill="#FFFFFF" opacity="0.75"/>`),
  'tab-dex': (on) => svg('0 0 34 34', 30, 30, [G.sky, G.shadow], `<path d="M6.5 7A3 3 0 0 1 9.5 4H27.5v22H9.5a3 3 0 0 0-3 3z" fill="${on ? 'url(#ic-sky)' : '#CDBFDA'}"/><path d="M6.5 29a3 3 0 0 1 3-3h18v4.4h-18a3 3 0 0 1-3-1.4z" fill="#FFFFFF"/>
    <path d="M13 10.5c2-1.6 5-1.2 5.6 1 .6 2.4-2 3.4-3.8 2.8-1.8-.6-3.2-2.4-1.8-3.8zM20 16.5c1.5-.8 3.4 0 3.2 1.6-.2 1.5-2.2 1.9-3.2 1-1-.8-.9-2.1 0-2.6z" fill="#FFFFFF" opacity="0.9"/>`),
  'tab-rank': (on) => svg('0 0 34 34', 30, 30, [G.gold, G.shadow], `<path d="M10 5h14v7.6a7 7 0 0 1-14 0z" fill="${on ? 'url(#ic-gold)' : '#CDBFDA'}"/><path d="M10 7.6H6.4a4.4 4.4 0 0 0 4.6 6.4M24 7.6h3.6a4.4 4.4 0 0 1-4.6 6.4" fill="none" stroke="${on ? '#E8A22A' : '#A796B8'}" stroke-width="2.2" stroke-linecap="round"/>
    <rect x="15.6" y="19" width="2.8" height="5" fill="${on ? '#E8A22A' : '#A796B8'}"/><rect x="10.5" y="23.6" width="13" height="6" rx="2" fill="${on ? '#C98A5A' : '#BBA9CB'}"/><ellipse cx="14" cy="8.6" rx="1.4" ry="2.6" fill="#FFFFFF" opacity="0.8"/>`),
};

export function icon(name, opts = {}) {
  const v = I[name];
  return v ? v(!!opts.active) : '';
}

export function num(text, role, opts = {}) {
  return `<span class="num num-${role}${opts.dir ? ' ' + opts.dir : ''}">${text}</span>`;
}

export function avatar() {
  const M = buildCow({ ...BREEDS.holstein, seed: 7 });
  const b = M.headBox, pad = 5;
  const w = b.x1 - b.x0 + pad * 2, h = b.y1 - b.y0 + pad * 2, s = Math.max(w, h);
  return `<svg viewBox="${b.x0 - pad - (s - w) / 2} ${b.y0 - pad - (s - h) / 2 + 3} ${s} ${s}" width="44" height="44"><defs>${defsC()}</defs>${cowC(M, { id: 'av', headOnly: true })}</svg>`;
}

export function spark(series, dir) {
  const w = 76, h = 32, p = 4;
  const min = Math.min(...series), max = Math.max(...series);
  const pts = series.map((v, i) => [p + (i / (series.length - 1)) * (w - p * 2), p + (1 - (v - min) / (max - min)) * (h - p * 2)]);
  const c = dir === 'up' ? '#F0524F' : '#27A564';
  const id = `sp-${dir}`;
  const line = smoothPath(pts, false);
  const e = pts[pts.length - 1];
  return `<svg viewBox="0 0 ${w} ${h}" width="${w}" height="${h}"><defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${c}" stop-opacity="0.35"/><stop offset="1" stop-color="${c}" stop-opacity="0"/></linearGradient>
    <filter id="${id}-g" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.2"/></filter></defs>
    <path d="${line}L${e[0]},${h}L${pts[0][0]},${h}Z" fill="url(#${id})"/><path d="${line}" fill="none" stroke="${c}" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>
    <circle cx="${e[0]}" cy="${e[1]}" r="6" fill="${c}" opacity="0.45" filter="url(#${id}-g)"/><circle cx="${e[0]}" cy="${e[1]}" r="3.4" fill="#FFFFFF" stroke="${c}" stroke-width="2.2"/></svg>`;
}

export function bucket(pct) {
  const top = 17, bot = 44, lvl = bot - (bot - top) * (pct / 100);
  const body = 'M8 16.5h32l-3.3 25.2a3.2 3.2 0 0 1-3.2 2.8H14.5a3.2 3.2 0 0 1-3.2-2.8z';
  return `<svg viewBox="0 0 48 48" width="48" height="48"><defs>${G.metal}${G.shadow}<clipPath id="c-bk"><path d="${body}"/></clipPath>
    <linearGradient id="c-milk" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#E8EEF6"/></linearGradient></defs>
    <g filter="url(#ic-sh)"><path d="M11.5 17C11.5 5.6 36.5 5.6 36.5 17" fill="none" stroke="#9BB4CB" stroke-width="2.4" stroke-linecap="round"/>
    <path d="${body}" fill="url(#ic-metal)"/>
    <g clip-path="url(#c-bk)"><rect x="0" y="${lvl}" width="48" height="40" fill="#CFE6F8" opacity="0.9"/><path d="M0 ${lvl + 1} q6 -2.4 12 0 t12 0 t12 0 t12 0 V48 H0z" fill="url(#c-milk)"/></g>
    <path d="M13.6 21.5v15" stroke="#FFFFFF" stroke-width="2.6" stroke-linecap="round" opacity="0.9"/>
    <rect x="6.2" y="13.4" width="35.6" height="5.8" rx="2.9" fill="#F6FAFE"/><rect x="6.2" y="16.2" width="35.6" height="3" rx="1.5" fill="#C7D8E8" opacity="0.8"/></g></svg>`;
}

// ---------- 場景 ----------
function cloudC(x, y, s, id) {
  const blobs = [[-22, 4, 13], [-8, -6, 17], [10, -3, 15], [24, 5, 11], [0, 6, 14]];
  const body = blobs.map(([dx, dy, r]) => `<circle cx="${x + dx * s}" cy="${y + dy * s}" r="${r * s}"/>`).join('');
  return `<g><g transform="translate(0,${6 * s})" fill="#6F9CC9" opacity="0.18" filter="url(#sc-blur4)">${body}</g><g fill="url(#sc-cloud)">${body}</g></g>`;
}
function treeC(x, y, r) {
  return `<ellipse cx="${x + 3}" cy="${y + 1}" rx="${r * 0.9}" ry="${r * 0.28}" fill="#3F7A36" opacity="0.25" filter="url(#sc-blur2)"/>
    <rect x="${x - 2.5}" y="${y - 8}" width="5" height="10" rx="2.5" fill="url(#sc-trunk)"/>
    <circle cx="${x}" cy="${y - r - 4}" r="${r}" fill="url(#sc-tree)"/>`;
}
function tuftC(x, y, s) {
  return `<g transform="translate(${x},${y}) scale(${s})"><path d="M-6,0 Q-6,-8 -3,-11 Q-3,-5 -1,0Z M-2,0 Q-1,-12 2,-14 Q2,-6 3,0Z M2,0 Q5,-8 8,-9 Q6,-4 6,0Z" fill="url(#sc-tuft)"/></g>`;
}
function flowerC(x, y, c) {
  return `<ellipse cx="${x}" cy="${y + 3}" rx="4" ry="1.4" fill="#3F7A36" opacity="0.25"/>
    <circle cx="${x}" cy="${y}" r="3.8" fill="${c}"/><circle cx="${x - 1}" cy="${y - 1.2}" r="1.6" fill="#FFFFFF" opacity="0.9"/><circle cx="${x + 0.6}" cy="${y + 0.6}" r="1.4" fill="#FFC53D"/>`;
}
function sparkleC(x, y, r) {
  return `<g><circle cx="${x}" cy="${y}" r="${r * 1.6}" fill="#FFF3A0" opacity="0.55" filter="url(#sc-blur2)"/><path d="M${x},${y - r} Q${x + r * 0.16},${y - r * 0.16} ${x + r},${y} Q${x + r * 0.16},${y + r * 0.16} ${x},${y + r} Q${x - r * 0.16},${y + r * 0.16} ${x - r},${y} Q${x - r * 0.16},${y - r * 0.16} ${x},${y - r}z" fill="#FFFFFF"/></g>`;
}

export function scene(el, herd) {
  const o = [];
  o.push(`<defs>${defsC()}
    <linearGradient id="sc-sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7EC4FF"/><stop offset="0.16" stop-color="#A8D8FF"/><stop offset="0.26" stop-color="#DCEEFF"/><stop offset="0.33" stop-color="#FFF1DE"/></linearGradient>
    <radialGradient id="sc-sun" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#FFFBE0"/><stop offset="0.35" stop-color="#FFEA8A"/><stop offset="0.55" stop-color="#FFE27A" stop-opacity="0.5"/><stop offset="1" stop-color="#FFE27A" stop-opacity="0"/></radialGradient>
    <radialGradient id="sc-cloud" cx="0.4" cy="0.25" r="0.9"><stop offset="0" stop-color="#FFFFFF"/><stop offset="0.6" stop-color="#FAFDFF"/><stop offset="1" stop-color="#D8E8F8"/></radialGradient>
    <linearGradient id="sc-hill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#C8F0AE"/><stop offset="1" stop-color="#96D57E"/></linearGradient>
    <linearGradient id="sc-meadow" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#C2EC96"/><stop offset="0.3" stop-color="#A3DE7E"/><stop offset="1" stop-color="#7CC663"/></linearGradient>
    <radialGradient id="sc-sunlit" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#E6FFB8" stop-opacity="0.7"/><stop offset="1" stop-color="#E6FFB8" stop-opacity="0"/></radialGradient>
    <radialGradient id="sc-tree" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#C6F29E"/><stop offset="0.5" stop-color="#7FCC6A"/><stop offset="1" stop-color="#4A9E4C"/></radialGradient>
    <linearGradient id="sc-trunk" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#D9A071"/><stop offset="1" stop-color="#9C6440"/></linearGradient>
    <linearGradient id="sc-tuft" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9BE07A"/><stop offset="1" stop-color="#4FA84E"/></linearGradient>
    <linearGradient id="sc-wall" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#FFA596"/><stop offset="0.5" stop-color="#FF8C7D"/><stop offset="1" stop-color="#E86A60"/></linearGradient>
    <linearGradient id="sc-roof" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F58277"/><stop offset="1" stop-color="#C9504A"/></linearGradient>
    <linearGradient id="sc-door" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E4675D"/><stop offset="1" stop-color="#C24E47"/></linearGradient>
    <radialGradient id="sc-win" cx="0.4" cy="0.35" r="0.7"><stop offset="0" stop-color="#FFF7C8"/><stop offset="1" stop-color="#FFC53D"/></radialGradient>
    <linearGradient id="sc-silo" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#EEF6FF"/><stop offset="0.35" stop-color="#D2E4F7"/><stop offset="1" stop-color="#99B8DA"/></linearGradient>
    <radialGradient id="sc-dome" cx="0.35" cy="0.35" r="0.8"><stop offset="0" stop-color="#DDEBFF"/><stop offset="1" stop-color="#7FA7D6"/></radialGradient>
    <linearGradient id="sc-post" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#FFFBF2"/><stop offset="0.5" stop-color="#FFEBCB"/><stop offset="1" stop-color="#E8C592"/></linearGradient>
    <linearGradient id="sc-rail" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF6E3"/><stop offset="1" stop-color="#E6C08C"/></linearGradient>
    <linearGradient id="sc-hay" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFE9A6"/><stop offset="1" stop-color="#E9B24C"/></linearGradient>
    <radialGradient id="sc-hayend" cx="0.4" cy="0.4" r="0.7"><stop offset="0" stop-color="#FFF1C4"/><stop offset="1" stop-color="#F0C160"/></radialGradient>
    <linearGradient id="sc-band" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8FD376"/><stop offset="1" stop-color="#77C262"/></linearGradient>
    <filter id="sc-blur2" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2"/></filter>
    <filter id="sc-blur4" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="4"/></filter>
    <filter id="sc-blur8" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="8"/></filter>
    <filter id="sc-far" x="-5%" y="-20%" width="110%" height="140%"><feGaussianBlur stdDeviation="1.4"/></filter>
    <filter id="sc-mid" x="-5%" y="-10%" width="110%" height="120%"><feGaussianBlur stdDeviation="0.6"/></filter>
  </defs>`);
  o.push(`<rect width="${W}" height="${H}" fill="url(#sc-sky)"/>`);
  o.push(`<circle cx="352" cy="170" r="52" fill="url(#sc-sun)"/>`);
  // 遠景（雲、山、樹）稍微失焦，做出小模型微距拍攝的感覺
  o.push(`<g filter="url(#sc-far)">`);
  o.push(cloudC(236, 178, 1.05), cloudC(338, 202, 0.7), cloudC(48, 164, 0.72));
  // 遠山
  o.push(`<path d="M-10,250 C40,214 108,210 170,236 C222,206 300,198 400,232 L400,330 L-10,330Z" fill="url(#sc-hill)"/>`);
  o.push(`<path d="M-10,250 C40,214 108,210 170,236 C222,206 300,198 400,232" fill="none" stroke="#FFFFFF" stroke-width="3" opacity="0.5" filter="url(#sc-blur2)"/>`);
  o.push(treeC(198, 246, 9), treeC(214, 244, 7), treeC(372, 234, 11), treeC(352, 240, 8));
  o.push(`</g>`);
  // 草地
  o.push(`<path d="M-10,264 C110,250 250,248 400,258 L400,${H} L-10,${H}Z" fill="url(#sc-meadow)"/>`);
  o.push(`<path d="M-10,264 C110,250 250,248 400,258" fill="none" stroke="#FFFFFF" stroke-width="4" opacity="0.45" filter="url(#sc-blur2)"/>`);
  o.push(`<ellipse cx="210" cy="430" rx="210" ry="110" fill="url(#sc-sunlit)"/>`);
  o.push(`<path d="M-10,606 C120,586 270,590 400,602 L400,${H} L-10,${H}Z" fill="url(#sc-band)"/>`);
  // 穀倉陰影、筒倉、穀倉（中景，輕微失焦）
  o.push(`<g filter="url(#sc-mid)">`);
  o.push(`<ellipse cx="86" cy="304" rx="84" ry="10" fill="#3F7A36" opacity="0.3" filter="url(#sc-blur4)"/>`);
  o.push(`<rect x="130" y="212" width="31" height="92" rx="8" fill="url(#sc-silo)"/><path d="M131,240h29M131,266h29" stroke="#8FB0D4" stroke-width="2" opacity="0.6"/><path d="M128,215 a17.5,16 0 0 1 35,0 v3 h-35z" fill="url(#sc-dome)"/><ellipse cx="139" cy="206" rx="4" ry="2.4" fill="#FFFFFF" opacity="0.7"/>`);
  o.push(`<path d="M24,240 L72,197 L120,240 L120,296 Q120,302 114,302 L30,302 Q24,302 24,296Z" fill="url(#sc-wall)"/>`);
  o.push(`<path d="M30,254h84M28,268h88M28,282h88" stroke="#C9504A" stroke-width="1.6" opacity="0.25"/>`);
  o.push(`<path d="M24,240 L72,197 L120,240" fill="none" stroke="#2A1030" stroke-width="10" opacity="0.18" filter="url(#sc-blur2)" transform="translate(0,4)"/>`);
  o.push(`<path d="M10,238 Q8,242 12,244 L72,190 L132,244 Q136,242 134,238 L76,184 Q72,180 68,184Z" fill="url(#sc-roof)" stroke="url(#sc-roof)" stroke-width="10" stroke-linejoin="round"/>`);
  o.push(`<path d="M16,236 L72,186 L128,236" fill="none" stroke="#FFB9AE" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" opacity="0.8"/>`);
  o.push(`<rect x="50" y="256" width="44" height="46" rx="6" fill="url(#sc-door)"/><rect x="50" y="256" width="44" height="46" rx="6" fill="none" stroke="#FFF4EA" stroke-width="4"/><path d="M55,261 L89,297 M89,261 L55,297" stroke="#FFF4EA" stroke-width="3.6" stroke-linecap="round" opacity="0.95"/>`);
  o.push(`<circle cx="72" cy="226" r="11.5" fill="#FFF4EA"/><circle cx="72" cy="226" r="8.5" fill="url(#sc-win)"/><circle cx="72" cy="226" r="14" fill="#FFE27A" opacity="0.25" filter="url(#sc-blur2)"/>`);
  o.push(`</g>`);
  // 柵欄
  const fy = 282;
  o.push(`<rect x="-6" y="${fy + 36}" width="${W + 12}" height="8" fill="#3F7A36" opacity="0.18" filter="url(#sc-blur2)"/>`);
  o.push(`<rect x="-6" y="${fy + 8}" width="${W + 12}" height="8" rx="4" fill="url(#sc-rail)"/><rect x="-6" y="${fy + 22}" width="${W + 12}" height="8" rx="4" fill="url(#sc-rail)"/>`);
  let posts = '';
  for (let x = 6; x < W + 20; x += 36) posts += `<rect x="${x - 5.5}" y="${fy - 1}" width="11" height="${38}" rx="5.5" fill="url(#sc-post)"/><ellipse cx="${x - 1.5}" cy="${fy + 4}" rx="2" ry="3" fill="#FFFFFF" opacity="0.8"/>`;
  o.push(posts);
  // 草叢與花
  const r = rng(42);
  const cows = herd.map((c) => ({ x: c.x, y: c.y }));
  const free = (x, y) => cows.every((c) => Math.abs(c.x - x) > 52 || y > c.y + 8 || y < c.y - 70);
  for (let i = 0, n = 0; i < 400 && n < 20; i++) {
    const x = 10 + r() * 370, y = 338 + r() * 200;
    if (!free(x, y)) continue;
    o.push(tuftC(x, y, 0.8 + r() * 0.4)); n++;
  }
  const fc = ['#FFFFFF', '#FFB8CE', '#FFFFFF', '#FFE27A', '#C9B8FF'];
  for (let i = 0, n = 0; i < 400 && n < 12; i++) {
    const x = 12 + r() * 366, y = 344 + r() * 196;
    if (!free(x, y)) continue;
    o.push(flowerC(x, y, fc[n % fc.length])); n++;
  }
  // 乾草捆
  o.push(`<g transform="translate(362,522)"><ellipse cx="-4" cy="2" rx="30" ry="6" fill="#3F7A36" opacity="0.3" filter="url(#sc-blur2)"/><rect x="-26" y="-31" width="42" height="32" rx="12" fill="url(#sc-hay)"/><ellipse cx="16" cy="-15" rx="10.5" ry="16" fill="url(#sc-hayend)"/><path d="M16,-15 m-4,0 a4,5 0 1 1 4,5 a7,9 0 1 1 3,-12" fill="none" stroke="#D9A040" stroke-width="1.6" stroke-linecap="round" opacity="0.8"/></g>`);

  // 牛
  let bubble = null;
  const sorted = [...herd].sort((a, b) => a.depth - b.depth || a.y - b.y);
  sorted.forEach((c, i) => {
    const M = buildCow(genesFor(c));
    const s = SCALE[c.depth];
    o.push(cowC(M, { x: c.x, y: c.y, scale: s, facing: c.facing, id: `c${i}` }));
    const mir = c.facing === 'right' ? -1 : 1;
    const hx = c.x + mir * M.headTop[0] * s * M.unit, hy = c.y + M.headTop[1] * s * M.unit;
    if (c.bubble) bubble = [hx, hy - 6];
    if (BREEDS[c.breed].special) o.push(sparkleC(hx + 24 * s, hy + 6, 5 * s), sparkleC(hx - 20 * s, hy + 14, 3.4 * s));
  });
  el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" width="${W}" height="${H}">${o.join('')}</svg>`;
  return { bubble };
}
