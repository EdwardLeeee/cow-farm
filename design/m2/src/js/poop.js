// v0.3 第 5 節（使用者 2026-10-03 選第 13 輪 04-A「霜淇淋捲」）：牧場場景裡的大便。每頭牛每 3 小時一坨，最多 4 坨；點一下或劃過去清掉。
// 這個檔在 node 也會跑（素材匯出的圖示 poop），不能引用字串表。
const L = '#4B3326';
const f2 = (v) => Math.round(v * 100) / 100;
// 一坨大便：(x, y) 是底部中間，s 是寬（第 13 輪 04-A 的 poopA）
export function poopG(x, y, s = 18, attrs = '') {
  return `<g transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s / 20)})"${attrs}><ellipse cx="0" cy="0.6" rx="10.4" ry="2.4" fill="#5E8F3E" opacity="0.28"/>
    <path d="M-9.4 0C-11 -1 -10.6 -5.6 -7 -6.2C-7.2 -9.8 -3.6 -11.4 -2 -11.2C-2.2 -14.2 0.4 -16.2 2.6 -17.2C2.4 -15.6 3.8 -14 4.4 -11.8C7.2 -11.4 8.4 -8.6 7.2 -6.4C10.6 -5.8 11 -1.2 9.4 0Z" fill="#B07843" stroke="${L}" stroke-width="1.7" stroke-linejoin="round"/>
    <path d="M-7 -6.2C-3.2 -4.8 3.2 -4.8 7.2 -6.4M-2 -11.2C0.4 -10 2.8 -10.2 4.4 -11.8" fill="none" stroke="${L}" stroke-width="1.4" stroke-linecap="round"/>
    <path d="M-6.8 -2.6C-5.6 -1.8 -4.2 -1.6 -3 -1.8M-3.8 -8.4C-3 -7.8 -2 -7.6 -1.2 -7.8" stroke="#FFFFFF" stroke-width="1.4" stroke-linecap="round" fill="none" opacity="0.75"/></g>`;
}
// 牧場場景裡大便的位置（場景座標；草地上、不擋到牛）。照順序放，最多畫 18 坨：
//   第 1–9 坨在左半邊（第 13 輪 04-A）；第 10–18 坨在右半邊（cow-ui 2026-10-10 排、第 29 輪 R29-07；避開池塘、石頭、水槽、花叢、乾草捲和兩頭牛的預設位置，y 都在 448 以內，下方面板蓋不到）
export const POOP_SPOTS = [[236, 398], [252, 452], [38, 498], [214, 482], [284, 472], [362, 448], [204, 338], [132, 412], [332, 490],
  [544, 398], [700, 360], [430, 404], [648, 412], [506, 366], [740, 412], [576, 338], [418, 448], [756, 356]];
export const POOP_W = 19; // 場景裡的寬
// 場景裡的大便（每一坨一個 <g class="poop" data-p="i">，動畫 A-14、A-15 用來一坨一坨清掉）
export const poopsSvg = (idx) => idx.map((i) => poopG(POOP_SPOTS[i][0], POOP_SPOTS[i][1], POOP_W, ` class="poop" data-p="${i}"`)).join('');
