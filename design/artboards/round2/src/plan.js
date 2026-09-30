// 基因 → 體型參數（body plan）。三個版本都從這裡拿體型，所以「體型由基因決定」在每個版本都成立；
// 各版本只再套自己的比例（例如 A 把腿縮短、頭放大），不會把品種差異抹平。
import { rng, hslToRgb, rgbToHex, lum } from './r1/cowgen.js';

// 以「兼用（dual）」為 1 的倍率。單位：側面身體 L 長、D 深、legLen 腿長、legW 腿粗……
export const BUILDS = {
  //         身長   身深   腿長    腿粗   脖子長  脖子粗  腰角  背凹   胸深  肚子  乳房   頭    臉長   肌肉  整體
  dairy:  { L: 1.04, D: 0.84, legLen: 1.28, legW: 0.84, neckLen: 1.2, neckW: 0.82, hip: 1.0, dip: 0.08, chest: 0.0, belly: 0.3, udder: 1.45, head: 1.0, face: 1.12, muscle: 0.0, size: 1.0 },
  petite: { L: 0.94, D: 0.9, legLen: 1.14, legW: 0.7, neckLen: 1.0, neckW: 0.78, hip: 0.7, dip: 0.18, chest: 0.0, belly: 0.45, udder: 1.0, head: 0.94, face: 0.8, muscle: 0.0, size: 0.84 },
  beef:   { L: 1.03, D: 1.24, legLen: 0.74, legW: 1.34, neckLen: 0.72, neckW: 1.5, hip: 0.0, dip: 0.0, chest: 0.6, belly: 0.1, udder: 0.35, head: 1.06, face: 0.94, muscle: 1.0, size: 1.02 },
  low:    { L: 1.02, D: 1.06, legLen: 0.6, legW: 1.14, neckLen: 0.78, neckW: 1.2, hip: 0.2, dip: 0.15, chest: 0.3, belly: 0.3, udder: 0.6, head: 1.0, face: 0.95, muscle: 0.3, size: 1.0 },
  round:  { L: 0.9, D: 1.12, legLen: 0.9, legW: 1.02, neckLen: 0.88, neckW: 1.02, hip: 0.1, dip: 0.28, chest: 0.1, belly: 0.9, udder: 0.8, head: 1.02, face: 0.94, muscle: 0.2, size: 0.96 },
  dual:   { L: 1.0, D: 1.02, legLen: 0.98, legW: 1.08, neckLen: 0.95, neckW: 1.12, hip: 0.45, dip: 0.12, chest: 0.25, belly: 0.4, udder: 0.85, head: 1.0, face: 1.0, muscle: 0.5, size: 1.0 },
};

// 兼用成牛的基準尺寸（B 繪本自然的比例；單位約等於 CSS px）
const BASE = { L: 80, D: 36, legLen: 30, legW: 9.5, neckLen: 18, neckW: 1, headR: 14 };

export function plan(g) {
  const b = { ...(BUILDS[g.build] || BUILDS.dual) };
  // 隨機基因可以帶連續的微調（jitter），讓同一種體型也有個體差異
  if (g.jitter) for (const k of Object.keys(g.jitter)) if (k in b) b[k] *= g.jitter[k];
  const calf = g.age === 'calf';
  const p = {
    build: g.build, calf, fluffy: g.fur === 'fluffy',
    size: b.size * (calf ? 0.7 : 1),
    L: BASE.L * b.L * (calf ? 0.7 : 1),
    D: BASE.D * b.D * (calf ? 0.8 : 1),
    legLen: BASE.legLen * b.legLen * (calf ? 1.12 : 1), // 小牛腿相對長
    legW: BASE.legW * b.legW * (calf ? 0.72 : 1),
    neckLen: BASE.neckLen * b.neckLen * (calf ? 0.8 : 1),
    neckW: b.neckW,
    hip: b.hip, dip: b.dip, chest: b.chest, belly: b.belly * (calf ? 0.3 : 1),
    udder: calf ? 0 : b.udder, muscle: b.muscle,
    head: b.head * (calf ? 1.22 : 1), // 小牛頭大
    face: b.face * (g.face === 'short' ? 0.86 : 1) * (calf ? 0.86 : 1),
    dish: g.face === 'short' ? 1 : 0,
    eyeBig: g.eyes === 'big' || calf,
    eyeRim: !!g.eyeRim,
    f: { L: b.L, D: b.D, legLen: b.legLen, legW: b.legW }, // 原始體型倍率（A 版用來誇大差異）
  };
  return p;
}

// 隨機基因（圖庫用）：體型、毛質、年齡、花紋、角都隨機，再加連續微調
export function randomGenes(seed) {
  const r = rng(seed * 131 + 17);
  const pick = (arr) => arr[Math.floor(r() * arr.length)];
  const hue = Math.floor(r() * 360);
  const coats = [
    () => '#FFFFFF', () => '#F6EBDD', () => rgbToHex(hslToRgb([22 + r() * 20, 0.45 + r() * 0.3, 0.5 + r() * 0.15])),
    () => rgbToHex(hslToRgb([15 + r() * 20, 0.25 + r() * 0.2, 0.18 + r() * 0.1])),
    () => rgbToHex(hslToRgb([hue, 0.45 + r() * 0.3, 0.78 + r() * 0.08])),
    () => rgbToHex(hslToRgb([30 + r() * 15, 0.72, 0.55 + r() * 0.1])), () => rgbToHex(hslToRgb([0, 0, 0.4 + r() * 0.35])),
  ];
  const coat = pick(coats)();
  const dark = lum(coat) < 0.2;
  const pattern = pick(['patches', 'patches', 'dots', 'solid', 'strawberry']);
  const patternColor = pattern === 'strawberry' ? pick(['#EE4F63', '#E8475A', '#F06A7A'])
    : dark ? pick(['#FFFFFF', '#FFE7C2', '#F1D2A2']) : pick(['#2E2A33', '#5A3A28', '#8A5634', '#FFFFFF', rgbToHex(hslToRgb([(hue + 180) % 360, 0.4, 0.6]))]);
  const build = pick(Object.keys(BUILDS));
  const jit = () => 0.9 + r() * 0.2;
  return {
    coat: pattern === 'strawberry' ? '#FFF6E6' : coat, pattern, patternColor, seedColor: '#FFE9A8',
    horns: pick(['bud', 'short', 'short', 'long', 'none']), build, fur: r() < 0.22 ? 'fluffy' : 'smooth',
    eyes: r() < 0.3 ? 'big' : 'normal', eyeRim: r() < 0.2, face: r() < 0.25 ? 'short' : 'normal',
    age: r() < 0.18 ? 'calf' : 'adult', overlay: pattern === 'strawberry' ? 'berry' : r() < 0.12 ? 'cream' : 'none',
    muzzle: pick(['#F4E1D6', '#F2E3CB', '#E5D2C0', '#F3DCC0', '#F9DCD9']), earColor: pattern === 'patches' && r() < 0.5 ? 'pattern' : 'coat',
    collar: 'bell', seed: Math.floor(r() * 1e6),
    jitter: { L: jit(), D: jit(), legLen: jit(), legW: jit(), neckW: jit(), head: jit() },
  };
}
