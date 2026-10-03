// v0.3（D35；使用者 2026-10-03 選第 13 輪 02-A）：小牛只有 6 種樣子：用途 × 公母，長大才揭曉品種。
// 長相照用途的一般品種（乳牛荷斯坦、耕牛台灣黃牛、肉牛安格斯）；母的頭上一個粉紅蝴蝶結，公的沒有（產生器原本就把公的畫大一點）。
// 不改牛的產生器（cowcheck 照舊）：蝴蝶結畫在 drawCow 的結果上面。設計稿（kit.js 的 cowSVG、scene.js 的牧場場景）和匯出素材（assetexport.mjs）都用這個檔。
// 注意：這個檔在 node 也會跑（匯出素材），不能引用字串表。
const INK = '#4B3326';
const f2 = (v) => Math.round(v * 100) / 100;

export const CALF_LOOK = { dairy: 'holstein', draft: 'yellow', beef: 'angus' };
// 只有「一頭母小牛」才畫蝴蝶結；沒寫公母的（例如配種頁「可能生出的品種」那種代表品種的小圖）不畫
export const hasBow = (e) => e.age === 'calf' && e.sex === 'cow';

// r：drawCow 的結果（臉的圓 face；座標跟 r.svg 一樣）。蝴蝶結在頭頂偏後腦那一邊，大小跟著臉
// 回傳 { svg, top }：top 是蝴蝶結最上面的 y（算圖的範圍用）
export function calfBow(r, pose = 'side', facing = 'left') {
  const k = pose === 'side' ? { rx: 0.6, ry: 0.81 } : { rx: 0.81, ry: 0.89 };
  const fr = r.face.r, d = facing === 'right' ? -1 : 1;
  const x = r.face.cx + d * k.rx * fr * 0.5, y = r.face.cy - k.ry * fr * 0.9, a = (fr * 0.95) / 2;
  const lw = f2(Math.max(0.8, fr * 0.07));
  const loop = (s) => `M0 0C${f2(s * 0.25 * a)} ${f2(-0.95 * a)} ${f2(s * 1.08 * a)} ${f2(-0.9 * a)} ${f2(s * a)} ${f2(-0.05 * a)}C${f2(s * 1.06 * a)} ${f2(0.78 * a)} ${f2(s * 0.25 * a)} ${f2(0.82 * a)} 0 0Z`;
  const svg = `<g transform="translate(${f2(x)} ${f2(y)}) rotate(${d * -14})">`
    + `<path d="${loop(-1)}" fill="#FF8FB1" stroke="${INK}" stroke-width="${lw}" stroke-linejoin="round"/>`
    + `<path d="${loop(1)}" fill="#FF8FB1" stroke="${INK}" stroke-width="${lw}" stroke-linejoin="round"/>`
    + `<path d="M${f2(-0.72 * a)} ${f2(-0.22 * a)}Q${f2(-0.6 * a)} ${f2(-0.55 * a)} ${f2(-0.3 * a)} ${f2(-0.5 * a)}" stroke="#FFFFFF" stroke-width="${lw}" stroke-linecap="round" fill="none" opacity="0.8"/>`
    + `<ellipse cx="0" cy="0" rx="${f2(0.26 * a)}" ry="${f2(0.32 * a)}" fill="#FF6F9A" stroke="${INK}" stroke-width="${lw}"/></g>`;
  return { svg, top: y - a * 1.05 };
}
