// C 扁平幾何：沒有描邊，大色塊，曲線改成多邊形切面，配色大膽但協調（桃色天空、深青綠、珊瑚紅、芥末黃）。
import { pathD, facet } from '../render.js';
import { shade, mix, lum, ellipsePts, polyPath } from '../q.js';

const f = (v) => Math.round(v * 100) / 100;
const INK = '#26305A';
const SCENE = {
  sky: '#FFE6CC', sun: '#FF6B4A', cloud: '#FFF7EE', hillFar: '#3AA17E', trunk: '#8A5530', treeCrown: '#1F7A5C',
  meadow: '#86CF6E', meadowLight: '#99D97F', meadowBand: '#6DBE5C', silo: '#EEF0F7', siloBand: '#C9CFE3', siloDome: '#2E86DE',
  barnWall: '#E4572E', barnPlank: '#C9462A', barnRoof: '#8E3322', barnDoor: '#FFF1E0', barnTrim: '#E4572E', barnWindow: '#FFC145',
  rail: '#F7D9A8', post: '#FFF4E4', tuft: '#4E9E4E', flower0: '#FFFFFF', flower1: '#FFC145', flower2: '#FF8FA3', flowerCenter: '#FF6B4A',
  hay: '#F2C14E', hayEnd: '#F9D77E', haySwirl: '#D29A2E',
};
const ICON = {
  gold: '#FFC145', goldIn: '#FFD66E', goldDark: '#D9962B', hi: '#FFFFFF', main: '#FF6B4A', light: '#FFD2C4', line: '#FF6B4A',
  milk: '#FFFFFF', label: '#8FC8F5', accent: '#2E86DE', wood: '#E0A15E', woodLight: '#F2C48C', woodLine: '#B87A3E', pink: '#FF8FA3',
  green: '#4FB06D', greenDark: '#2E7F4A', metal: '#D5DEEA', metalDark: '#8C9BB3', metalLight: '#EEF2F8', red: '#E4572E', redDark: '#8E3322',
  blue: '#2E86DE', dark: '#26305A',
};

export const style = {
  key: 'c', name: '扁平幾何', sceneScale: 0.9,
  globalDefs: () => '',
  cowColor(role, g) {
    const coat = g.coat, pat = g.patternColor, dark = lum(coat) < 0.12;
    const m = {
      coat, pattern: pat, seed: g.seedColor || '#FFE9A8', legFar: shade(coat, dark ? -0.04 : -0.1), leg: coat, hoof: '#3A2A26',
      udder: '#FF9FB0', teat: '#FF7F97', tail: coat, tuft: g.pattern === 'patches' ? pat : shade(coat, dark ? 0.08 : -0.2),
      strap: '#E4572E', bell: '#FFC145', bellDot: INK, horn: '#FFF1D6', hornFar: '#E8D2A8', muzzle: g.muzzle, muzzleEdge: null,
      nostril: '#6B3F31', mouth: '#6B3F31', ear: g.earColor === 'pattern' ? pat : coat, earFar: shade(g.earColor === 'pattern' ? pat : coat, -0.1),
      earIn: '#FF9FB0', eye: '#1E1B2E', eyeHi: '#FFFFFF', eyeRim: shade(coat, -0.18), fringe: shade(coat, 0.07), blush: '#FF8FA3',
      leaf: '#4FB06D', stem: '#2E7F4A', cream: '#FFF6E6',
    };
    return m[role];
  },
  sceneColor: (role) => SCENE[role],
  iconColor(role, { active, name }) {
    if (name && name.startsWith('tab-') && !active) return ICON[role] ? mix(ICON[role], '#C4C9D9', 0.55) : undefined;
    return ICON[role];
  },
  pathOf(it) { return geoPath(it); },
  fill(it, color, ctx) {
    if (it.role === 'cloud' && it.geo) { const { x, y, s } = it.geo; return `<g fill="${color}"><rect x="${f(x - 36 * s)}" y="${f(y - 4 * s)}" width="${f(72 * s)}" height="${f(12 * s)}" rx="${f(6 * s)}"/><circle cx="${f(x - 12 * s)}" cy="${f(y - 4 * s)}" r="${f(13 * s)}"/><circle cx="${f(x + 8 * s)}" cy="${f(y - 8 * s)}" r="${f(15 * s)}"/></g>`; }
    return `<path d="${geoPath(it)}" fill="${color}"/>`;
  },
  line(it, color) {
    return `<path d="${polyPath(it.pts, false)}" fill="none" stroke="${color}" stroke-width="${f(it.w)}" stroke-linecap="round" stroke-linejoin="round"/>`;
  },
  dot(it, color) {
    if (it.role === 'meadowLight') return `<ellipse cx="${it.cx}" cy="${it.cy}" rx="${it.rx}" ry="${it.ry}" fill="${color}"/>`;
    if (it.role === 'treeCrown') return `<circle cx="${f(it.cx)}" cy="${f(it.cy)}" r="${f(it.rx)}" fill="${color}"/><path d="M${f(it.cx)},${f(it.cy - it.rx)} A${f(it.rx)},${f(it.rx)} 0 0 1 ${f(it.cx)},${f(it.cy + it.rx)}Z" fill="${shade(color, -0.07)}"/>`;
    if (it.role === 'sun') return `<circle cx="${it.cx}" cy="${it.cy}" r="${it.rx * 1.9}" fill="#FFC7A8"/><circle cx="${it.cx}" cy="${it.cy}" r="${it.rx * 1.35}" fill="#FF9A74"/><circle cx="${it.cx}" cy="${it.cy}" r="${it.rx}" fill="${color}"/>`;
    return `<ellipse cx="${f(it.cx)}" cy="${f(it.cy)}" rx="${f(it.rx)}" ry="${f(it.ry)}"${it.rot ? ` transform="rotate(${f((it.rot * 180) / Math.PI)} ${f(it.cx)} ${f(it.cy)})"` : ''} fill="${color}"/>`;
  },
  // 大色塊的立體感：區域下方一塊平塗的暗面（不用漸層）
  regionClose(it, color, ctx, clip) {
    if (ctx.kind !== 'cow' || it.role !== 'coat') return '';
    const xs = it.pts.map((p) => p[0]), ys = it.pts.map((p) => p[1]);
    const x0 = Math.min(...xs), x1 = Math.max(...xs), y0 = Math.min(...ys), y1 = Math.max(...ys);
    const cut = y0 + (y1 - y0) * 0.68;
    return `<g clip-path="${clip}"><path d="M${f(x0 - 5)},${f(cut + 4)} L${f(x1 + 5)},${f(cut - 3)} L${f(x1 + 5)},${f(y1 + 5)} L${f(x0 - 5)},${f(y1 + 5)}Z" fill="#1E1B2E" opacity="0.1"/></g>`;
  },
  cowShadow: ({ cx, cy, rx, ry }) => `<ellipse cx="${f(cx)}" cy="${f(cy + 1)}" rx="${f(rx)}" ry="${f(ry)}" fill="#5FB35A"/>`,
  sparkle: (x, y, r) => `<path d="M${f(x)},${f(y - r)} L${f(x + r * 0.3)},${f(y - r * 0.3)} L${f(x + r)},${f(y)} L${f(x + r * 0.3)},${f(y + r * 0.3)} L${f(x)},${f(y + r)} L${f(x - r * 0.3)},${f(y + r * 0.3)} L${f(x - r)},${f(y)} L${f(x - r * 0.3)},${f(y - r * 0.3)}Z" fill="#FFC145"/>`,
  spark(pts, dir, w, h) {
    const c = dir === 'up' ? '#E4372E' : '#1E9A5A';
    const d = polyPath(pts, false);
    const e = pts[pts.length - 1];
    return `<path d="${d}L${e[0]},${h}L${pts[0][0]},${h}Z" fill="${c}" opacity="0.16"/><path d="${d}" fill="none" stroke="${c}" stroke-width="3" stroke-linejoin="miter"/><rect x="${e[0] - 3.5}" y="${e[1] - 3.5}" width="7" height="7" fill="${c}"/>`;
  },
};

// 幾何化：牛與圖示的平滑外框改成切面多邊形；本來就是多邊形的（場景、矩形）照原樣
function geoPath(it) {
  if (it.smooth === false || it.rect) return polyPath(it.pts);
  const n = it.pts.length;
  const target = it.role === 'coat' ? (n > 60 ? 18 : 12) : it.role === 'pattern' ? 7 : Math.min(10, Math.max(5, Math.round(n / 5)));
  return polyPath(facet(it.pts, target));
}
