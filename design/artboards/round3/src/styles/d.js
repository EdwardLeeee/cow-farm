// D 復古農場海報：1950 年代美式農場海報。低飽和配色（鐵鏽紅、芥末黃、深青綠、橄欖綠、奶油紙）、
// 墨線略粗糙、暗面用網點（halftone）、色塊和墨線有一點套印偏移、天空放射狀光芒、明體標題。
import { pathD } from '../render.js';
import { shade, mix, lum, smoothPath } from '../q.js';

const f = (v) => Math.round(v * 100) / 100;
const INK = '#2F2A24';
const SCENE = {
  sky: '#EAD7AA', sun: '#D9772B', cloud: '#F5EBD3', hillFar: '#5E877A', trunk: '#6B4A32', treeCrown: '#3E6B60',
  meadow: '#A9AE5E', meadowLight: '#B8BC6C', meadowBand: '#8F9848', silo: '#D3CBB0', siloBand: '#A69C7C', siloDome: '#4F7D73',
  barnWall: '#B5452B', barnPlank: '#963823', barnRoof: '#6E2F24', barnDoor: '#F2E6CC', barnTrim: '#B5452B', barnWindow: '#E0A93B',
  rail: '#EADBB8', post: '#F2E6CC', tuft: '#6F7A36', flower0: '#F5EBD3', flower1: '#E0A93B', flower2: '#D9826E', flowerCenter: '#B5452B',
  hay: '#D9A23B', hayEnd: '#E6BC62', haySwirl: '#A7741F',
};
const ICON = {
  gold: '#E0A93B', goldIn: '#EAC06A', goldDark: '#A7741F', hi: '#F5EBD3', main: '#B5452B', light: '#EBC9AE', line: '#B5452B',
  milk: '#F5EBD3', label: '#8FB1B0', accent: '#4F7D73', wood: '#C98E55', woodLight: '#DDB07E', woodLine: '#8E5E2E', pink: '#D9826E',
  green: '#7E8B3D', greenDark: '#56612A', metal: '#CFC9B8', metalDark: '#7D7563', metalLight: '#EDE6D2', red: '#B5452B', redDark: '#6E2F24',
  blue: '#4F7D73', dark: INK,
};
const NO_INK = new Set(['sky', 'meadowLight', 'meadowBand', 'blush', 'eyeHi', 'seed', 'flowerCenter', 'meadow', 'cloud', 'pattern', 'earIn', 'label', 'hi', 'goldIn', 'muzzle']);

const muted = (c) => {
  const m = mix(c, '#E9DCC0', 0.14);
  return lum(m) > 0.75 ? mix(m, '#F2E6CC', 0.45) : m;
};

export const style = {
  key: 'd', name: '復古農場海報', sceneScale: 0.9,
  globalDefs: () => `
    <pattern id="rp-ht" width="3.4" height="3.4" patternUnits="userSpaceOnUse" patternTransform="rotate(28)"><circle cx="1.7" cy="1.7" r="0.85" fill="${INK}"/></pattern>
    <pattern id="rp-ht2" width="5" height="5" patternUnits="userSpaceOnUse" patternTransform="rotate(28)"><circle cx="2.5" cy="2.5" r="1.25" fill="${INK}"/></pattern>
    <filter id="rp-ink" x="-5%" y="-5%" width="110%" height="110%">
      <feTurbulence type="fractalNoise" baseFrequency="0.6" numOctaves="1" seed="6" result="n"/>
      <feDisplacementMap in="SourceGraphic" in2="n" scale="1.3" xChannelSelector="R" yChannelSelector="G"/>
    </filter>
    <filter id="rp-paper" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency="0.6" numOctaves="3" seed="21" result="n"/>
      <feColorMatrix in="n" type="matrix" values="0 0 0 0 0.3  0 0 0 0 0.24  0 0 0 0 0.16  0 0 0 0.2 -0.03"/>
    </filter>`,
  cowColor(role, g) {
    const coat = muted(g.coat), pat = muted(g.patternColor), dark = lum(coat) < 0.12;
    const m = {
      coat, pattern: pat, seed: '#F2E0A8', legFar: shade(coat, dark ? -0.03 : -0.08), leg: coat, hoof: INK,
      udder: '#DFA79C', teat: '#CF8C80', tail: coat, tuft: g.pattern === 'patches' ? pat : shade(coat, dark ? 0.1 : -0.2),
      strap: '#B5452B', bell: '#E0A93B', bellDot: INK, horn: '#F2E6CC', hornFar: '#DCCBA6', muzzle: muted(g.muzzle), muzzleEdge: INK,
      nostril: INK, mouth: INK, ear: g.earColor === 'pattern' ? pat : coat, earFar: shade(g.earColor === 'pattern' ? pat : coat, -0.1),
      earIn: '#DFA79C', eye: INK, eyeHi: '#F5EBD3', eyeRim: shade(coat, -0.15), fringe: shade(coat, 0.05), blush: '#D98C80',
      leaf: '#7E8B3D', stem: '#56612A', cream: '#F5EBD3',
    };
    return m[role];
  },
  sceneColor: (role) => SCENE[role],
  iconColor(role, { active, name }) {
    if (name && name.startsWith('tab-') && !active) return ICON[role] ? mix(ICON[role], '#DCD2BC', 0.5) : undefined;
    return ICON[role];
  },
  fill(it, color, ctx, { base } = {}) {
    const d = pathD(it.pts, { smooth: it.smooth !== false });
    if (it.role === 'sky') return `<rect width="390" height="844" fill="${color}"/>${sunburst(352, 170)}`;
    const mis = ctx.kind === 'icon' ? '0.5,0.4' : '1,0.8';
    let s = `<path d="${d}" fill="${color}" transform="translate(${mis})"/>`;
    if (!base && !NO_INK.has(it.role)) s += ink(d, ctx);
    return s;
  },
  line(it, color, ctx) {
    const d = smoothPath(it.pts, false);
    if (['tail', 'rail', 'strap', 'stem'].includes(it.role)) {
      return `<path d="${d}" fill="none" stroke="${INK}" stroke-width="${f(it.w + 2.2)}" stroke-linecap="round" filter="url(#rp-ink)"/><path d="${d}" fill="none" stroke="${color}" stroke-width="${f(it.w)}" stroke-linecap="round"/>`;
    }
    return `<path d="${d}" fill="none" stroke="${color}" stroke-width="${f(it.w)}" stroke-linecap="round" filter="url(#rp-ink)"/>`;
  },
  dot(it, color, ctx) {
    const e = `cx="${f(it.cx)}" cy="${f(it.cy)}" rx="${f(it.rx)}" ry="${f(it.ry)}"${it.rot ? ` transform="rotate(${f((it.rot * 180) / Math.PI)} ${f(it.cx)} ${f(it.cy)})"` : ''}`;
    if (['eye', 'eyeHi', 'nostril', 'seed', 'bellDot', 'flowerCenter'].includes(it.role)) return `<ellipse ${e} fill="${color}"/>`;
    if (it.role === 'blush') return `<ellipse ${e} fill="url(#rp-ht)" opacity="0.5"/>`;
    if (it.role === 'meadowLight') return `<ellipse ${e} fill="${color}"/>`;
    if (it.role === 'sun') return `<ellipse ${e} fill="${color}"/><ellipse ${e} fill="none" stroke="${INK}" stroke-width="1.6" filter="url(#rp-ink)"/>`;
    const lw = ctx.kind === 'icon' ? 1.8 : 1.3;
    const shadeDots = it.role === 'treeCrown' ? `<ellipse cx="${f(it.cx + it.rx * 0.25)}" cy="${f(it.cy + it.ry * 0.3)}" rx="${f(it.rx * 0.75)}" ry="${f(it.ry * 0.65)}" fill="url(#rp-ht)" opacity="0.45"/>` : '';
    return `<ellipse ${e} fill="${color}"/>${shadeDots}<ellipse ${e} fill="none" stroke="${INK}" stroke-width="${lw}" filter="url(#rp-ink)"/>`;
  },
  regionClose(it, color, ctx, clip) {
    const d = pathD(it.pts, { smooth: it.smooth !== false });
    let s = '';
    const xs = it.pts.map((p) => p[0]), ys = it.pts.map((p) => p[1]);
    const x0 = Math.min(...xs), x1 = Math.max(...xs), y0 = Math.min(...ys), y1 = Math.max(...ys);
    if (ctx.kind === 'cow' || ctx.kind === 'icon') {
      const cut = y0 + (y1 - y0) * 0.6;
      s += `<g clip-path="${clip}"><path d="M${f(x0 - 4)},${f(cut + 3)} Q${f((x0 + x1) / 2)},${f(cut - 3)} ${f(x1 + 4)},${f(cut)} L${f(x1 + 4)},${f(y1 + 4)} L${f(x0 - 4)},${f(y1 + 4)}Z" fill="url(#rp-ht)" opacity="${lum(color) < 0.12 ? 0.25 : 0.42}"/></g>`;
    }
    if (it.role === 'meadow') s += `<g clip-path="${clip}"><rect x="0" y="560" width="390" height="300" fill="url(#rp-ht2)" opacity="0.18"/></g><path d="${d}" fill="none" stroke="${INK}" stroke-width="1.6" filter="url(#rp-ink)"/>`;
    if (!NO_INK.has(it.role)) s += ink(d, ctx);
    return s;
  },
  cowShadow: ({ cx, cy, rx, ry }) => `<ellipse cx="${f(cx)}" cy="${f(cy + 1)}" rx="${f(rx)}" ry="${f(ry)}" fill="url(#rp-ht)" opacity="0.55"/>`,
  sparkle: (x, y, r) => `<path d="M${f(x)},${f(y - r)} L${f(x + r * 0.28)},${f(y - r * 0.28)} L${f(x + r)},${f(y)} L${f(x + r * 0.28)},${f(y + r * 0.28)} L${f(x)},${f(y + r)} L${f(x - r * 0.28)},${f(y + r * 0.28)} L${f(x - r)},${f(y)} L${f(x - r * 0.28)},${f(y - r * 0.28)}Z" fill="#F5EBD3" stroke="${INK}" stroke-width="1"/>`,
  spark(pts, dir, w, h) {
    const c = dir === 'up' ? '#B5452B' : '#3F6E4E';
    const d = smoothPath(pts, false), e = pts[pts.length - 1];
    return `<path d="${d}L${e[0]},${h}L${pts[0][0]},${h}Z" fill="url(#rp-ht)" opacity="0.35"/><path d="${d}" fill="none" stroke="${c}" stroke-width="2.6" stroke-linecap="round"/><circle cx="${e[0]}" cy="${e[1]}" r="3.2" fill="${c}" stroke="${INK}" stroke-width="1"/>`;
  },
  wrapScene: (svg) => `${svg}<rect width="390" height="844" filter="url(#rp-paper)" style="mix-blend-mode:multiply"/>`,
};

function ink(d, ctx) {
  const w = ctx.kind === 'icon' ? 1.9 : ctx.kind === 'scene' ? 1.5 : 1.7;
  return `<path d="${d}" fill="none" stroke="${INK}" stroke-width="${w}" stroke-linejoin="round" filter="url(#rp-ink)"/>`;
}
// 1950 年代海報常見的放射光芒
function sunburst(cx, cy) {
  const n = 28, R = 900;
  let s = '';
  for (let i = 0; i < n; i += 2) {
    const a0 = (i / n) * Math.PI * 2, a1 = ((i + 1) / n) * Math.PI * 2;
    s += `M${cx},${cy} L${f(cx + Math.cos(a0) * R)},${f(cy + Math.sin(a0) * R)} L${f(cx + Math.cos(a1) * R)},${f(cy + Math.sin(a1) * R)}Z `;
  }
  return `<path d="${s}" fill="#E2C993" opacity="0.75"/>`;
}
