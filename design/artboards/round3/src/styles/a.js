// A 水彩繪本：水彩暈染（turbulence＋displacement 讓邊緣不規則、邊緣顏料堆積較深、顆粒感）、
// 手繪鉛筆線（抖動的細線）、紙張紋理；暖色、柔和。
import { pathD } from '../render.js';
import { shade, mix, lum, polyPath, smoothPath } from '../q.js';

const f = (v) => Math.round(v * 100) / 100;
const PEN = '#4A3B33';
const SCENE = {
  sky: '#B3D6EE', sun: '#F6D58A', cloud: '#FFFFFF', hillFar: '#A6CE8C', trunk: '#A07A5A', treeCrown: '#86B96E',
  meadow: '#B6D98C', meadowLight: '#C9E4A2', meadowBand: '#A0CA7A', silo: '#D5E1EA', siloBand: '#AFC3D3', siloDome: '#93B2CB',
  barnWall: '#DD8269', barnPlank: '#C9745F', barnRoof: '#B35E50', barnDoor: '#F4E7D4', barnTrim: '#D97C66', barnWindow: '#F1C86F',
  rail: '#E3C9A0', post: '#F0DFC2', tuft: '#8DB86F', flower0: '#FFFFFF', flower1: '#F3CF6A', flower2: '#F2A7B5', flowerCenter: '#E99A4A',
  hay: '#EBCB82', hayEnd: '#F2DBA0', haySwirl: '#C99A4C',
};
const ICON = {
  gold: '#F0C862', goldIn: '#F6D98E', goldDark: '#C9953A', hi: '#FFFFFF', main: '#E7917A', light: '#F6D4C8', line: '#B96A55',
  milk: '#FFFFFF', label: '#A9CDE8', accent: '#6FA2CC', wood: '#DDAE7C', woodLight: '#EFCFA4', woodLine: '#B08050', pink: '#F2A2AE',
  green: '#8DC27A', greenDark: '#5E9150', metal: '#DCE4EC', metalDark: '#8E9CAC', metalLight: '#F1F4F8', red: '#E3917B', redDark: '#B35E50',
  blue: '#8FB6D8', dark: '#5A4A42',
};
const NO_PEN = new Set(['sky', 'meadowLight', 'meadowBand', 'blush', 'eyeHi', 'seed', 'flowerCenter', 'meadow', 'hillFar', 'cloud', 'sun', 'muzzle', 'pattern', 'earIn', 'label', 'milk', 'hi', 'goldIn']);

export const style = {
  key: 'a', name: '水彩繪本', sceneScale: 0.9,
  globalDefs: () => `
    <filter id="wa-wash" x="-8%" y="-8%" width="116%" height="116%" color-interpolation-filters="sRGB">
      <feTurbulence type="fractalNoise" baseFrequency="0.045" numOctaves="3" seed="4" result="n"/>
      <feDisplacementMap in="SourceGraphic" in2="n" scale="4.5" xChannelSelector="R" yChannelSelector="G" result="d"/>
      <feGaussianBlur in="d" stdDeviation="0.55" result="b"/>
      <feMorphology in="b" operator="erode" radius="1.3" result="er"/>
      <feComposite in="b" in2="er" operator="out" result="edge"/>
      <feColorMatrix in="edge" type="matrix" values="0.72 0 0 0 0  0 0.7 0 0 0  0 0 0.72 0 0  0 0 0 0.75 0" result="edgeDark"/>
      <feTurbulence type="fractalNoise" baseFrequency="0.8" numOctaves="2" seed="9" result="g"/>
      <feColorMatrix in="g" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1.4 -0.55" result="ga"/>
      <feFlood flood-color="#3A2A20" flood-opacity="0.22"/>
      <feComposite in2="ga" operator="in" result="speck"/>
      <feComposite in="speck" in2="b" operator="in" result="speckIn"/>
      <feMerge><feMergeNode in="b"/><feMergeNode in="speckIn"/><feMergeNode in="edgeDark"/></feMerge>
    </filter>
    <filter id="wa-big" x="-3%" y="-3%" width="106%" height="106%" color-interpolation-filters="sRGB">
      <feTurbulence type="fractalNoise" baseFrequency="0.012" numOctaves="3" seed="2" result="n"/>
      <feDisplacementMap in="SourceGraphic" in2="n" scale="12" xChannelSelector="R" yChannelSelector="G" result="d"/>
      <feTurbulence type="fractalNoise" baseFrequency="0.02" numOctaves="2" seed="5" result="blot"/>
      <feColorMatrix in="blot" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -0.65 1.45" result="ba"/>
      <feComposite in="d" in2="ba" operator="in" result="wash"/>
      <feGaussianBlur in="wash" stdDeviation="1.2"/>
    </filter>
    <filter id="wa-pencil" x="-5%" y="-5%" width="110%" height="110%">
      <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="1" seed="3" result="n"/>
      <feDisplacementMap in="SourceGraphic" in2="n" scale="1.4" xChannelSelector="R" yChannelSelector="G"/>
    </filter>
    <filter id="wa-paper" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="3" seed="11" result="n"/>
      <feColorMatrix in="n" type="matrix" values="0 0 0 0 0.45  0 0 0 0 0.36  0 0 0 0 0.26  0 0 0 0.16 -0.02"/>
    </filter>`,
  cowColor(role, g) {
    const wash = (c) => mix(c, '#FFF8EE', 0.12);
    const coat = wash(g.coat), pat = wash(g.patternColor), dark = lum(coat) < 0.12;
    const m = {
      coat, pattern: pat, seed: '#FFF1B8', legFar: shade(coat, dark ? -0.03 : -0.08), leg: coat, hoof: '#5E4A40',
      udder: '#F4B6BE', teat: '#EB9EAA', tail: coat, tuft: g.pattern === 'patches' ? pat : shade(coat, dark ? 0.1 : -0.18),
      strap: '#D9695A', bell: '#F0C862', bellDot: PEN, horn: '#F6ECD8', hornFar: '#E5D4B6', muzzle: g.muzzle, muzzleEdge: '#8B7466',
      nostril: '#6B4B3E', mouth: '#6B4B3E', ear: g.earColor === 'pattern' ? pat : coat, earFar: shade(g.earColor === 'pattern' ? pat : coat, -0.1),
      earIn: '#F4B8B8', eye: '#2F2420', eyeHi: '#FFFFFF', eyeRim: shade(coat, -0.14), fringe: shade(coat, 0.06), blush: '#F29AA6',
      leaf: '#86C06F', stem: '#5E9150', cream: '#FFF6E6',
    };
    return m[role];
  },
  sceneColor: (role) => SCENE[role],
  iconColor(role, { active, name }) {
    if (name && name.startsWith('tab-') && !active) return ICON[role] ? mix(ICON[role], '#E8E0D4', 0.55) : undefined;
    return ICON[role];
  },
  fill(it, color, ctx, { base } = {}) {
    const d = pathD(it.pts, { smooth: it.smooth !== false });
    const big = ['sky', 'meadow', 'hillFar', 'meadowBand'].includes(it.role);
    const filt = big ? 'wa-big' : 'wa-wash';
    const op = it.role === 'meadowLight' ? 0.7 : ctx.kind === 'cow' ? 1 : 0.94;
    let s = `<path d="${d}" fill="${color}" opacity="${op}" filter="url(#${filt})"/>`;
    if (it.role === 'sky') s = `<rect width="390" height="844" fill="#FBF6EC"/>` + s.replace(`opacity="${op}"`, 'opacity="0.95"');
    if (!base && !NO_PEN.has(it.role)) s += pen(d, ctx);
    return s;
  },
  line(it, color, ctx) {
    const d = smoothPath(it.pts, false);
    if (['tail', 'rail', 'strap', 'stem'].includes(it.role)) {
      return `<path d="${d}" fill="none" stroke="${PEN}" stroke-width="${f(it.w + 1.6)}" stroke-linecap="round" opacity="0.7" filter="url(#wa-pencil)"/><path d="${d}" fill="none" stroke="${color}" stroke-width="${f(it.w)}" stroke-linecap="round" filter="url(#wa-wash)"/>`;
    }
    return `<path d="${d}" fill="none" stroke="${color}" stroke-width="${f(it.w * 0.9)}" stroke-linecap="round" opacity="0.85" filter="url(#wa-pencil)"/>`;
  },
  dot(it, color, ctx) {
    const e = `cx="${f(it.cx)}" cy="${f(it.cy)}" rx="${f(it.rx)}" ry="${f(it.ry)}"${it.rot ? ` transform="rotate(${f((it.rot * 180) / Math.PI)} ${f(it.cx)} ${f(it.cy)})"` : ''}`;
    if (it.role === 'eye' || it.role === 'eyeHi' || it.role === 'nostril' || it.role === 'bellDot') return `<ellipse ${e} fill="${color}"/>`;
    if (it.role === 'blush') return `<ellipse ${e} fill="${color}" opacity="0.55" filter="url(#wa-wash)"/>`;
    if (it.role === 'sun') return `<circle cx="${it.cx}" cy="${it.cy}" r="${it.rx * 1.8}" fill="#FBE7B0" opacity="0.6" filter="url(#wa-wash)"/><ellipse ${e} fill="${color}" filter="url(#wa-wash)"/>`;
    if (it.role === 'meadowLight') return `<ellipse ${e} fill="${color}" opacity="0.65" filter="url(#wa-big)"/>`;
    const withPen = ['treeCrown', 'barnWindow', 'hayEnd', 'flower0', 'flower1', 'flower2'].includes(it.role);
    return `<ellipse ${e} fill="${color}" opacity="0.94" filter="url(#wa-wash)"/>${withPen ? `<ellipse ${e} fill="none" stroke="${PEN}" stroke-width="0.9" opacity="0.7" filter="url(#wa-pencil)"/>` : ''}`;
  },
  regionClose(it, color, ctx, clip) {
    const d = pathD(it.pts, { smooth: it.smooth !== false });
    let s = '';
    if (ctx.kind === 'cow' && it.role === 'coat') {
      const xs = it.pts.map((p) => p[0]), ys = it.pts.map((p) => p[1]);
      const cx = (Math.min(...xs) + Math.max(...xs)) / 2, y1 = Math.max(...ys), h = y1 - Math.min(...ys);
      s += `<g clip-path="${clip}"><ellipse cx="${f(cx)}" cy="${f(y1)}" rx="${f((Math.max(...xs) - Math.min(...xs)) * 0.62)}" ry="${f(h * 0.38)}" fill="${shade(color, -0.2)}" opacity="0.35" filter="url(#wa-wash)"/></g>`;
    }
    if (!NO_PEN.has(it.role)) s += pen(d, ctx);
    return s;
  },
  cowShadow: ({ cx, cy, rx, ry }) => `<ellipse cx="${f(cx)}" cy="${f(cy + 1)}" rx="${f(rx)}" ry="${f(ry)}" fill="#8FB374" opacity="0.55" filter="url(#wa-wash)"/>`,
  sparkle: (x, y, r) => `<path d="M${f(x)},${f(y - r)} Q${f(x + r * 0.2)},${f(y - r * 0.2)} ${f(x + r)},${f(y)} Q${f(x + r * 0.2)},${f(y + r * 0.2)} ${f(x)},${f(y + r)} Q${f(x - r * 0.2)},${f(y + r * 0.2)} ${f(x - r)},${f(y)} Q${f(x - r * 0.2)},${f(y - r * 0.2)} ${f(x)},${f(y - r)}z" fill="#F4CF6A" stroke="${PEN}" stroke-width="0.8" filter="url(#wa-pencil)"/>`,
  spark(pts, dir, w, h) {
    const c = dir === 'up' ? '#D6534A' : '#3E9A5E';
    const d = smoothPath(pts, false), e = pts[pts.length - 1];
    return `<path d="${d}L${e[0]},${h}L${pts[0][0]},${h}Z" fill="${c}" opacity="0.2" filter="url(#wa-wash)"/><path d="${d}" fill="none" stroke="${c}" stroke-width="2.4" stroke-linecap="round" filter="url(#wa-pencil)"/><circle cx="${e[0]}" cy="${e[1]}" r="3.4" fill="${c}" filter="url(#wa-wash)"/>`;
  },
  wrapScene: (svg) => `${svg}<rect width="390" height="844" filter="url(#wa-paper)" style="mix-blend-mode:multiply"/>`,
};

function pen(d, ctx) {
  const w = ctx.kind === 'icon' ? 1.6 : ctx.kind === 'scene' ? 1.1 : 1.25;
  return `<path d="${d}" fill="none" stroke="${PEN}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round" opacity="0.78" filter="url(#wa-pencil)"/>`;
}
