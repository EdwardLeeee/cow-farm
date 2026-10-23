// 牧場頁下方的飼料列和肚子餓的圖示（v0.3 第 2.2 節；D35 補充 10、11）。
// - 飼料列：一排小飼料袋，沒有底板、浮在奶桶面板上方（使用者 2026-10-10 選第 26 輪「沒有底板」）；袋子上寫剩幾份，下面只寫名字
//   （「飼料底下不用寫加給公斤，這是隨機的」）。左右滑看其他的。按住一袋拖到牧場地上就是丟飼料（A-16、A-17）。
// - 肚子餓的圖示：空碗加問號（使用者選第 26 輪 A）。只有肚子餓、現在能吃的牛頭上才有；吃飽冷卻中、長到最壯的都沒有。
// 這個檔在 node 也會跑（素材匯出 parts/feed_sack.svg、parts/feed_sack_empty.svg、parts/hungry.svg），不能引用字串表。
const L = '#4B3326';

// 飼料袋（54×58）：袋口綁起來、一條金色的繩子；沒有了（0 份）袋子換淺灰，整袋再淡掉（.fb-item.none）
// 飼料的圖示放在袋子中間（左上角 (15, 22)、24×24），份數在右上角（見 ui.json 的 about）
export const SACK = { w: 54, h: 58, icon: { x: 15, y: 22, size: 24 } };
export const sackSvg = (empty = false) => `<svg viewBox="0 0 54 58" width="54" height="58" aria-hidden="true"><path d="M12 12Q27 6 42 12L46 18Q51 34 47 50Q27 57 7 50Q3 34 8 18Z" fill="${empty ? '#E5DED2' : '#E9D3A6'}" stroke="${L}" stroke-width="2.2" stroke-linejoin="round"/><path d="M12 12Q18 4 27 9Q36 4 42 12" fill="none" stroke="${L}" stroke-width="2"/><path d="M14 17Q27 21 40 17" stroke="#C99A34" stroke-width="2.4" fill="none"/></svg>`;

// 肚子餓：白色圓底上一個吃空的碗，上面一個紅色問號（38×44；牛頭頂往上一點，底部中間對齊頭頂）
const bowl = (cx, cy) => `<g transform="translate(${cx} ${cy})"><path d="M-10 -1h20c0 5.6-4.4 9.6-10 9.6S-10 4.6-10-1z" fill="#F2C489" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/><ellipse cx="0" cy="-1" rx="10" ry="2.6" fill="#E9DCC6" stroke="${L}" stroke-width="1.4"/><path d="M-6.4 3.6q2.4 1.6 4.6 1.4" fill="none" stroke="#FFF1D8" stroke-width="1.4" stroke-linecap="round"/></g>`;
const Q = 'M15.6 12.4q0-5.2 4.8-5.2 4.8 0 4.8 4.2 0 2.8-2.8 4-2 .9-2 3';
export const HUNGRY = { w: 38, h: 44 };
export const hungrySvg = () => `<svg viewBox="0 0 40 46" width="38" height="44" aria-hidden="true"><circle cx="20" cy="26" r="17.5" fill="#FFFFFF" stroke="${L}" stroke-width="2"/>${bowl(20, 30)}<path d="${Q}" fill="none" stroke="${L}" stroke-width="4.8" stroke-linecap="round"/><path d="${Q}" fill="none" stroke="#FF9784" stroke-width="2.6" stroke-linecap="round"/><circle cx="20.4" cy="22.6" r="2" fill="#FF9784" stroke="${L}" stroke-width="1.2"/></svg>`;
