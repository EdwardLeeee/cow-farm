// E 日系手帳線稿：米白底（淡點格紙）、細的單線條（暖深灰）、淡色填色並稍微錯開（像手帳的淡彩與印刷偏移）、清爽留白。
import { pathD } from '../render.js';
import { mix, lum, smoothPath, shade } from '../q.js';

const f = (v) => Math.round(v * 100) / 100;
const LINE = '#5C4B43';
const pale = (c, k = 0.5) => mix(c, '#FFFDF8', k);
const SCENE = {
  sky: '#FBF7EF', sun: '#FBE3A0', cloud: '#FFFFFF', hillFar: '#DCEBCD', trunk: '#D9C2A6', treeCrown: '#CFE5BE',
  meadow: '#EAF3DD', meadowLight: '#F2F8E8', meadowBand: '#E0EDD0', silo: '#E6EDF3', siloBand: LINE, siloDome: '#CADBEA',
  barnWall: '#F4CFC4', barnPlank: '#D9A89A', barnRoof: '#E7AFA2', barnDoor: '#FFFFFF', barnTrim: '#D9A89A', barnWindow: '#FBE3A0',
  rail: '#F3E6D0', post: '#FFFFFF', tuft: '#8DB47C', flower0: '#FFFFFF', flower1: '#FBE3A0', flower2: '#F7CDD6', flowerCenter: '#F0B67A',
  hay: '#F6E2B0', hayEnd: '#FAEDCB', haySwirl: '#C9A86A',
};
const ICON = {
  gold: '#F8DE8E', goldIn: '#FBEAB6', goldDark: '#D6B060', hi: null, main: '#F4B9AA', light: '#FFFFFF', line: LINE,
  milk: '#FFFFFF', label: '#CFE3F2', accent: '#A9CBE6', wood: '#EFD3B2', woodLight: '#F7E6CF', woodLine: LINE, pink: '#F7C3CD',
  green: '#CDE6BD', greenDark: LINE, metal: '#E8EEF4', metalDark: LINE, metalLight: '#FFFFFF', red: '#F4C4B8', redDark: '#E7A596',
  blue: '#CFE1F1', dark: LINE,
};
const NO_LINE = new Set(['sky', 'meadowLight', 'meadowBand', 'blush', 'eyeHi', 'seed', 'flowerCenter', 'pattern', 'earIn', 'label', 'goldIn', 'muzzle', 'hi']);
const OFF = 'translate(1.6,1.2)';

export const style = {
  key: 'e', name: '日系手帳線稿', sceneScale: 0.9,
  globalDefs: () => `<pattern id="nb-grid" width="12" height="12" patternUnits="userSpaceOnUse"><circle cx="6" cy="6" r="0.75" fill="#D9CCBC"/></pattern>`,
  cowColor(role, g) {
    const coat = lum(g.coat) > 0.8 ? '#FFFFFF' : lum(g.coat) < 0.06 ? pale(g.coat, 0.22) : pale(g.coat, 0.42), pat = lum(g.patternColor) < 0.1 ? '#8A807C' : pale(g.patternColor, 0.3);
    const m = {
      coat, pattern: pat, seed: '#FFF3C0', legFar: mix(coat, LINE, 0.12), leg: coat, hoof: '#8A7A70',
      udder: '#F9D3D9', teat: '#F4BEC8', tail: coat, tuft: g.pattern === 'patches' ? pat : pale(shade(g.coat, -0.1), 0.3),
      strap: '#F2A9A0', bell: '#F8DE8E', bellDot: LINE, horn: '#FFFFFF', hornFar: '#F4ECDD', muzzle: pale(g.muzzle, 0.25), muzzleEdge: LINE,
      nostril: LINE, mouth: LINE, ear: g.earColor === 'pattern' ? pat : coat, earFar: g.earColor === 'pattern' ? pat : coat,
      earIn: '#F9D3D9', eye: '#3E322C', eyeHi: '#FFFFFF', eyeRim: pale(shade(g.coat, -0.25), 0.4), fringe: pale(g.coat, 0.5), blush: '#F6B3BF',
      leaf: '#CDE6BD', stem: LINE, cream: '#FFFFFF',
    };
    return m[role];
  },
  sceneColor: (role) => SCENE[role],
  iconColor(role, { active, name }) {
    if (name && name.startsWith('tab-') && !active) return ICON[role] === LINE ? '#A99A90' : ICON[role] ? '#FFFFFF' : ICON[role];
    return ICON[role];
  },
  fill(it, color, ctx, { base } = {}) {
    const d = pathD(it.pts, { smooth: it.smooth !== false });
    if (it.role === 'sky') return `<rect width="390" height="844" fill="${color}"/><rect width="390" height="844" fill="url(#nb-grid)"/>`;
    let s = `<path d="${d}" fill="${color}" transform="${ctx.kind === 'icon' ? 'translate(1,0.8)' : OFF}"/>`;
    if (it.role === 'meadowBand') s = `<path d="${d}" fill="${color}"/>`;
    if (!base && !NO_LINE.has(it.role)) s += ln(d, ctx);
    return s;
  },
  line(it, color, ctx) {
    const d = smoothPath(it.pts, false);
    if (['tail', 'rail', 'strap', 'stem'].includes(it.role)) {
      const w = it.w;
      return `<path d="${d}" fill="none" stroke="${color}" stroke-width="${f(w)}" stroke-linecap="round" transform="${OFF}"/><path d="${d}" fill="none" stroke="${LINE}" stroke-width="${f(ctx.kind === 'icon' ? 1.4 : 1)}" stroke-linecap="round"/>`;
    }
    const w = ['mouth', 'muzzleEdge'].includes(it.role) ? 1 : it.role === 'tuft' ? 1.1 : Math.min(it.w, 1.4);
    return `<path d="${d}" fill="none" stroke="${it.role === 'tuft' ? '#8DB47C' : LINE}" stroke-width="${f(w)}" stroke-linecap="round" stroke-linejoin="round"/>`;
  },
  dot(it, color, ctx) {
    const e = `cx="${f(it.cx)}" cy="${f(it.cy)}" rx="${f(it.rx)}" ry="${f(it.ry)}"${it.rot ? ` transform="rotate(${f((it.rot * 180) / Math.PI)} ${f(it.cx)} ${f(it.cy)})"` : ''}`;
    if (['eye', 'eyeHi', 'nostril', 'bellDot', 'flowerCenter'].includes(it.role)) return `<ellipse ${e} fill="${color}"/>`;
    if (it.role === 'seed') return `<ellipse ${e} fill="${color}" stroke="${LINE}" stroke-width="0.5"/>`;
    if (it.role === 'blush') return `<ellipse ${e} fill="${color}" opacity="0.7"/>`;
    if (it.role === 'meadowLight') return `<ellipse ${e} fill="${color}"/>`;
    if (it.role === 'sun') {
      let rays = '';
      for (let i = 0; i < 12; i++) { const a = (i / 12) * Math.PI * 2; rays += `M${f(it.cx + Math.cos(a) * it.rx * 1.35)},${f(it.cy + Math.sin(a) * it.rx * 1.35)} L${f(it.cx + Math.cos(a) * it.rx * 1.75)},${f(it.cy + Math.sin(a) * it.rx * 1.75)} `; }
      return `<ellipse cx="${it.cx + 2}" cy="${it.cy + 1.5}" rx="${it.rx}" ry="${it.ry}" fill="${color}"/><ellipse ${e} fill="none" stroke="${LINE}" stroke-width="1.1"/><path d="${rays}" stroke="${LINE}" stroke-width="1.1" stroke-linecap="round"/>`;
    }
    return `<ellipse ${e} fill="${color}" transform="${OFF}"/><ellipse ${e} fill="none" stroke="${LINE}" stroke-width="${ctx.kind === 'icon' ? 1.4 : 1}"/>`;
  },
  regionClose(it, color, ctx) {
    if (NO_LINE.has(it.role)) return '';
    if (it.role === 'meadow') return `<path d="${pathD(it.pts, { smooth: false })}" fill="none" stroke="${LINE}" stroke-width="1.1"/>`;
    return ln(pathD(it.pts, { smooth: it.smooth !== false }), ctx);
  },
  cowShadow: ({ cx, cy, rx, ry }) => `<path d="M${f(cx - rx)},${f(cy + 1)} Q${f(cx)},${f(cy + ry * 0.9)} ${f(cx + rx)},${f(cy + 1)}" fill="none" stroke="#B9D3A6" stroke-width="1.4" stroke-dasharray="3 2.5" stroke-linecap="round"/>`,
  sparkle: (x, y, r) => `<path d="M${f(x)},${f(y - r)} V${f(y + r)} M${f(x - r)},${f(y)} H${f(x + r)}" stroke="#E7B75B" stroke-width="1.3" stroke-linecap="round"/>`,
  spark(pts, dir, w, h) {
    const c = dir === 'up' ? '#D2554C' : '#3D8F5A';
    const d = smoothPath(pts, false), e = pts[pts.length - 1];
    return `<path d="${d}L${e[0]},${h}L${pts[0][0]},${h}Z" fill="${mix(c, '#FFFFFF', 0.82)}" transform="translate(1.5,1)"/><path d="${d}" fill="none" stroke="${c}" stroke-width="1.6" stroke-linecap="round"/><circle cx="${e[0]}" cy="${e[1]}" r="2.8" fill="#FFFFFF" stroke="${c}" stroke-width="1.4"/>`;
  },
};

function ln(d, ctx) {
  const w = ctx.kind === 'icon' ? 1.45 : ctx.kind === 'scene' ? 1.05 : 1.15;
  return `<path d="${d}" fill="none" stroke="${LINE}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"/>`;
}
