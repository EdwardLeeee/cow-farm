// v0.3 第 5 節（使用者 2026-10-03 選第 13 輪 04-A「臉色發青」）：病牛的樣子。病牛一律轉正面看玩家。
// 1. 臉色發青：臉的底色往綠色調（照原本的毛色調，不是整個換掉：深色的牛也看得出是牛自己的臉）。在 render.js 的 drawCow 套用。
// 2. 額頭幾條藍色的線（漫畫裡「不舒服」的畫法）：畫在 drawCow 的結果上面（跟小牛的蝴蝶結一樣）。
// 3. 頭上的溫度計泡泡：設計稿畫在牛的圖上；app 照 sickBubbleAt 的位置另外疊（素材 ui 的 sickBubble）。
// 不改 24 種牛原本的樣子（cowcheck 照舊）：只有 entry.sick 是 true 才會用到。這個檔在 node 也會跑（匯出素材），不能引用字串表。
import { mix, lum } from './q.js';

const INK = '#4B3326';
const f2 = (v) => Math.round(v * 100) / 100;
const GREEN = '#6FCB8C';

// 臉的底色：近黑的毛照產生器的規則先變炭灰（r11.js 的 palette），再往綠色調；淺色的毛調少一點
export function sickFace(coat) {
  const base = lum(coat) < 0.04 ? mix(coat, '#8C8692', 0.36) : coat;
  return mix(base, GREEN, lum(base) > 0.5 ? 0.26 : 0.4);
}

// 正面的頭（臉的圓 r 換算；跟第 13 輪 headOf 一樣）
const head = (f) => ({ rx: 0.81 * f.r, ry: 0.89 * f.r });

// 額頭的藍色線（r：drawCow 的結果，正面）
export function sickLines(r) {
  const f = r.face, { rx, ry } = head(f), lw = f2(Math.max(1.2, f.r * 0.075));
  return [-0.36, -0.12, 0.12, 0.36].map((u) => `<path d="M${f2(f.cx + u * rx)} ${f2(f.cy - ry * (0.7 - Math.abs(u) * 0.3))}v${f2(ry * (0.36 - Math.abs(u) * 0.2))}" stroke="#7F9FE6" stroke-width="${lw}" stroke-linecap="round"/>`).join('');
}

// 溫度計（20×20）
export const THERMO_INNER = `<path d="M8 3.8a2 2 0 0 1 4 0v7.6a3.9 3.9 0 1 1-4 0z" fill="#FFFFFF" stroke="${INK}" stroke-width="1.7" stroke-linejoin="round"/><path d="M10 14.6V7.6" stroke="#FF6B6B" stroke-width="2.2" stroke-linecap="round"/><circle cx="10" cy="14.8" r="2.3" fill="#FF6B6B"/>`;

// 溫度計泡泡的位置和大小：在頭的右上方（照臉的圓算；app 用 cows.json 的 face、headTop 一樣算）
export const sickBubbleAt = (face, headTopY) => ({ cx: face.cx + 0.81 * face.r * 1.15, cy: headTopY - face.r * 0.2, r: face.r * 0.5 });
// 泡泡（中心在 0,0、半徑 10 的版本；尾巴朝左下指向牛頭）
export const SICK_BUBBLE_INNER = `<path d="M-6 7.4L-11.4 13.6L-1.4 9.6" fill="#FFFFFF" stroke="${INK}" stroke-width="1.6" stroke-linejoin="round"/>`
  + `<circle r="10" fill="#FFFFFF" stroke="${INK}" stroke-width="1.8"/><path d="M-5.2 8.2L-1.4 8.6" stroke="#FFFFFF" stroke-width="2.4"/>`
  + `<g transform="translate(-8.6 -9.6) scale(0.86)">${THERMO_INNER}</g>`;
export function sickBubble(r) {
  const b = sickBubbleAt(r.face, r.headTop[1]), k = b.r / 10;
  return { svg: `<g transform="translate(${f2(b.cx)} ${f2(b.cy)}) scale(${f2(k)})">${SICK_BUBBLE_INNER}</g>`, top: b.cy - b.r * 1.0, right: b.cx + b.r * 1.0 };
}
