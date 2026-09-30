// B 剪紙拼貼：一層一層的色紙，邊緣略不規則（displacement），每層有小陰影，紙面有纖維紋理；沒有描邊。
import { pathD } from '../render.js';
import { shade, mix, lum, smoothPath } from '../q.js';

const f = (v) => Math.round(v * 100) / 100;
const SCENE = {
  sky: '#9FD3E8', sun: '#F7C548', cloud: '#FFFDF6', hillFar: '#7DB26A', trunk: '#8C5A3C', treeCrown: '#4F9A5B',
  meadow: '#A9CB5B', meadowLight: '#B9D66E', meadowBand: '#8FB84C', silo: '#E6E2D6', siloBand: '#B9C4CE', siloDome: '#5E8FB5',
  barnWall: '#D1495B', barnPlank: '#B53B4C', barnRoof: '#7E2A36', barnDoor: '#F5E9D2', barnTrim: '#D1495B', barnWindow: '#F7C548',
  rail: '#EBD3A8', post: '#F6E7CB', tuft: '#6E9F3B', flower0: '#FFFFFF', flower1: '#F7C548', flower2: '#F28BA6', flowerCenter: '#E0662F',
  hay: '#E9B44C', hayEnd: '#F2CB75', haySwirl: '#C98E2B',
};
const ICON = {
  gold: '#F2B93B', goldIn: '#F7CD5E', goldDark: '#C98E2B', hi: '#FFF6DC', main: '#E05A47', light: '#F7D8C8', line: '#C23F2F',
  milk: '#FFFFFF', label: '#8CC0E3', accent: '#3E7CB1', wood: '#D69A5C', woodLight: '#EBBD82', woodLine: '#A86B32', pink: '#F28BA6',
  green: '#6BAF4F', greenDark: '#3F7F34', metal: '#D8DEE6', metalDark: '#7C8A9C', metalLight: '#F2F4F7', red: '#D1495B', redDark: '#7E2A36',
  blue: '#5E8FB5', dark: '#3A2E2A',
};

export const style = {
  key: 'b', name: '剪紙拼貼', sceneScale: 0.9,
  globalDefs: () => `
    <filter id="pc" x="-10%" y="-10%" width="125%" height="130%" color-interpolation-filters="sRGB">
      <feTurbulence type="fractalNoise" baseFrequency="0.09" numOctaves="2" seed="7" result="t"/>
      <feDisplacementMap in="SourceGraphic" in2="t" scale="2.6" xChannelSelector="R" yChannelSelector="G" result="rough"/>
      <feTurbulence type="fractalNoise" baseFrequency="1.1" numOctaves="2" seed="2" result="fib"/>
      <feColorMatrix in="fib" type="matrix" values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 -0.9 0.55" result="fibA"/>
      <feComposite in="fibA" in2="rough" operator="in" result="fibIn"/>
      <feGaussianBlur in="rough" stdDeviation="1.1" result="sb"/>
      <feOffset in="sb" dx="0.7" dy="1.5" result="so"/>
      <feFlood flood-color="#2E2014" flood-opacity="0.38"/>
      <feComposite in2="so" operator="in" result="shadow"/>
      <feMerge><feMergeNode in="shadow"/><feMergeNode in="rough"/><feMergeNode in="fibIn"/></feMerge>
    </filter>
    <filter id="pc-big" x="-2%" y="-2%" width="104%" height="106%" color-interpolation-filters="sRGB">
      <feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="2" seed="5" result="t"/>
      <feDisplacementMap in="SourceGraphic" in2="t" scale="5" xChannelSelector="R" yChannelSelector="G" result="rough"/>
      <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="3" seed="8" result="fib"/>
      <feColorMatrix in="fib" type="matrix" values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 -0.8 0.48" result="fibA"/>
      <feComposite in="fibA" in2="rough" operator="in" result="fibIn"/>
      <feGaussianBlur in="rough" stdDeviation="2" result="sb"/>
      <feOffset in="sb" dx="0" dy="2.5" result="so"/>
      <feFlood flood-color="#2E2014" flood-opacity="0.3"/>
      <feComposite in2="so" operator="in" result="shadow"/>
      <feMerge><feMergeNode in="shadow"/><feMergeNode in="rough"/><feMergeNode in="fibIn"/></feMerge>
    </filter>
    <filter id="pc-grain" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency="0.7" numOctaves="3" seed="12"/>
      <feColorMatrix type="matrix" values="0 0 0 0 0.35  0 0 0 0 0.27  0 0 0 0 0.18  0 0 0 0.14 -0.01"/>
    </filter>
    <filter id="pc-flat" x="-10%" y="-10%" width="120%" height="120%">
      <feTurbulence type="fractalNoise" baseFrequency="0.09" numOctaves="2" seed="7" result="t"/>
      <feDisplacementMap in="SourceGraphic" in2="t" scale="2" xChannelSelector="R" yChannelSelector="G"/>
    </filter>`,
  cowColor(role, g) {
    const coat = mix(g.coat, '#F3E9D6', lum(g.coat) > 0.8 ? 0.35 : 0.08), pat = mix(g.patternColor, '#F3E9D6', 0.06), dark = lum(coat) < 0.12;
    const m = {
      coat, pattern: pat, seed: '#FFF3C2', legFar: shade(coat, dark ? -0.04 : -0.1), leg: coat, hoof: '#3A2E2A',
      udder: '#F4A7B6', teat: '#E7879C', tail: coat, tuft: g.pattern === 'patches' ? pat : shade(coat, dark ? 0.1 : -0.2),
      strap: '#D1495B', bell: '#F2B93B', bellDot: '#3A2E2A', horn: '#F7ECD6', hornFar: '#E3D0AC', muzzle: g.muzzle, muzzleEdge: null,
      nostril: '#5B3A2E', mouth: '#5B3A2E', ear: g.earColor === 'pattern' ? pat : coat, earFar: shade(g.earColor === 'pattern' ? pat : coat, -0.12),
      earIn: '#F4A7B6', eye: '#2A201C', eyeHi: '#FFFFFF', eyeRim: shade(coat, -0.18), fringe: shade(coat, 0.08), blush: '#F28BA6',
      leaf: '#6BAF4F', stem: '#3F7F34', cream: '#FFF6E6',
    };
    return m[role];
  },
  sceneColor: (role) => SCENE[role],
  iconColor(role, { active, name }) {
    if (name && name.startsWith('tab-') && !active) return ICON[role] ? mix(ICON[role], '#D9CFC0', 0.5) : undefined;
    return ICON[role];
  },
  fill(it, color) {
    const d = pathD(it.pts, { smooth: it.smooth !== false });
    if (it.role === 'sky') return `<rect width="390" height="844" fill="${color}"/>`;
    const big = ['meadow', 'hillFar', 'meadowBand'].includes(it.role);
    return `<path d="${d}" fill="${color}" filter="url(#${big ? 'pc-big' : 'pc'})"/>`;
  },
  line(it, color) {
    const d = smoothPath(it.pts, false);
    const flt = ['rail', 'tail', 'strap', 'stem', 'haySwirl', 'barnPlank', 'siloBand', 'barnTrim', 'tuft'].includes(it.role) ? 'pc' : 'pc-flat';
    return `<path d="${d}" fill="none" stroke="${color}" stroke-width="${f(it.w * (it.role === 'mouth' ? 0.9 : 1))}" stroke-linecap="round" stroke-linejoin="round" filter="url(#${flt})"/>`;
  },
  dot(it, color) {
    const e = `cx="${f(it.cx)}" cy="${f(it.cy)}" rx="${f(it.rx)}" ry="${f(it.ry)}"${it.rot ? ` transform="rotate(${f((it.rot * 180) / Math.PI)} ${f(it.cx)} ${f(it.cy)})"` : ''}`;
    if (['eyeHi', 'nostril', 'seed', 'bellDot'].includes(it.role)) return `<ellipse ${e} fill="${color}"/>`;
    if (it.role === 'sun') return `<circle cx="${it.cx}" cy="${it.cy}" r="${it.rx * 1.55}" fill="#FBDD8A" filter="url(#pc)"/><ellipse ${e} fill="${color}" filter="url(#pc)"/>`;
    if (it.role === 'blush') return `<ellipse ${e} fill="${color}" opacity="0.8" filter="url(#pc-flat)"/>`;
    return `<ellipse ${e} fill="${color}" filter="url(#${it.role === 'meadowLight' ? 'pc-big' : 'pc'})"/>`;
  },
  regionClose(it, color, ctx, clip) {
    if (ctx.kind !== 'cow' || it.role !== 'coat') return '';
    const xs = it.pts.map((p) => p[0]), ys = it.pts.map((p) => p[1]);
    const x0 = Math.min(...xs), x1 = Math.max(...xs), y1 = Math.max(...ys), h = y1 - Math.min(...ys);
    // 肚子下面多貼一片深一點的紙
    return `<g clip-path="${clip}"><path d="M${f(x0 - 4)},${f(y1 - h * 0.22)} Q${f((x0 + x1) / 2)},${f(y1 - h * 0.34)} ${f(x1 + 4)},${f(y1 - h * 0.2)} L${f(x1 + 4)},${f(y1 + 4)} L${f(x0 - 4)},${f(y1 + 4)}Z" fill="${shade(color, lum(color) < 0.12 ? -0.04 : -0.1)}" filter="url(#pc)"/></g>`;
  },
  cowShadow: ({ cx, cy, rx, ry }) => `<ellipse cx="${f(cx)}" cy="${f(cy + 1)}" rx="${f(rx)}" ry="${f(ry)}" fill="#7FA23F" filter="url(#pc-flat)"/>`,
  sparkle: (x, y, r) => `<path d="M${f(x)},${f(y - r)} L${f(x + r * 0.3)},${f(y - r * 0.3)} L${f(x + r)},${f(y)} L${f(x + r * 0.3)},${f(y + r * 0.3)} L${f(x)},${f(y + r)} L${f(x - r * 0.3)},${f(y + r * 0.3)} L${f(x - r)},${f(y)} L${f(x - r * 0.3)},${f(y - r * 0.3)}Z" fill="#FFF3C2" filter="url(#pc)"/>`,
  spark(pts, dir, w, h) {
    const c = dir === 'up' ? '#D6453A' : '#2E8B57';
    const d = smoothPath(pts, false), e = pts[pts.length - 1];
    return `<path d="${d}L${e[0]},${h}L${pts[0][0]},${h}Z" fill="${mix(c, '#FFFFFF', 0.72)}" filter="url(#pc)"/><path d="${d}" fill="none" stroke="${c}" stroke-width="3.2" stroke-linecap="round" filter="url(#pc)"/>`;
  },
  wrapScene: (svg) => `${svg}<rect width="390" height="844" filter="url(#pc-grain)" style="mix-blend-mode:multiply"/>`,
};
