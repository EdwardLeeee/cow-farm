// 六種飼料的圖示（v0.3 第 2.1 節，D35 補充 3；第 15 輪畫的，使用者 2026-10-08 選 01-C 集點卡）：牧草、乾草、燕麥、苜蓿、玉米、豆粕。
// key 跟字串表的 feed.* 一樣（grass、hay、oats、alfalfa、corn、soy）；素材匯出成 icons/feed_<key>.svg（icons.js）。
// 24×24 的格子，線條跟其他圖示一樣用 #4B3326。這個檔在 node 也會跑（素材匯出），不能引用字串表。
const L = '#4B3326';
const sheaf = (paths, light, w = 4.2) => paths.map((d) => `<path d="${d}" stroke="${L}" stroke-width="${w}" stroke-linecap="round" fill="none"/>`).join('') + paths.map((d) => `<path d="${d}" stroke="${light}" stroke-width="${w - 2.2}" stroke-linecap="round" fill="none"/>`).join('');
const svg = (s, inner) => `<svg class="feed-ic" viewBox="0 0 24 24" width="${s}" height="${s}" aria-hidden="true">${inner}</svg>`;

export const FEED_IC = {
  // 牧草：一把綠色的草（第 13 輪）
  grass: (s = 22) => svg(s, `${sheaf(['M12 17C10.2 12.8 8 9.6 4.8 7', 'M12 17C11 12.4 9.8 8.6 8 4.6', 'M12 17V3.6', 'M12 17C13 12.4 14.2 8.6 16 4.6', 'M12 17C13.8 12.8 16 9.6 19.2 7', 'M11 18.4L10 21.4', 'M13 18.4L14 21.4'], '#A6DC74')}
    <rect x="8.2" y="14.6" width="7.6" height="4.4" rx="1.6" fill="#E8AE62" stroke="${L}" stroke-width="1.6"/>`),
  // 乾草：一捆曬乾的草，兩條紅繩綁著（新畫）
  hay: (s = 22) => svg(s, `<path d="M3.4 9.2c0-1.6 1.2-2.8 2.8-2.8h11.6c1.6 0 2.8 1.2 2.8 2.8v8c0 1.6-1.2 2.8-2.8 2.8H6.2c-1.6 0-2.8-1.2-2.8-2.8z" fill="#F0CD6E" stroke="${L}" stroke-width="1.6"/>
    <path d="M5.6 10.2h4.2M12.8 9.8h5.2M6.4 13.4h3.4M13.4 13.6h4.4M5.8 16.6h4M13 16.8h4.6" stroke="#C99A34" stroke-width="1.2" stroke-linecap="round"/>
    <path d="M10.6 6.4v13.6M14.2 6.4v13.6" stroke="#D2553B" stroke-width="1.8"/>
    <path d="M4.4 6.6l-1-1.6M7.2 6.4l-.4-1.8M17.2 6.4l.6-1.8M20 7.2l1.2-1.2" stroke="${L}" stroke-width="1.3" stroke-linecap="round"/><path d="M5.4 8.4h3" stroke="#FFF4CC" stroke-width="1.4" stroke-linecap="round"/>`),
  // 燕麥（第 13 輪）
  oats: (s = 22) => svg(s, `${sheaf(['M8 21.6C8.6 14.6 10.8 8.4 15.6 3.2'], '#8DBA4E', 3.8)}
    ${[[9.2, 15.4, 13.2, 17.6], [9.4, 12.6, 5.6, 14.2], [10.8, 9.6, 14.8, 11.4], [11.6, 8.2, 8, 9.2], [13.6, 5.6, 17.4, 6.8]].map(([x, y, ex, ey]) => `<path d="M${x} ${y}Q${(x + ex) / 2} ${Math.min(y, ey) - 1.2} ${ex} ${ey}" stroke="${L}" stroke-width="1.3" fill="none"/><ellipse cx="${ex}" cy="${ey + 1.9}" rx="1.9" ry="2.7" fill="#F6DE9C" stroke="${L}" stroke-width="1.3"/>`).join('')}`),
  // 苜蓿（第 13 輪）
  alfalfa: (s = 22) => svg(s, `${sheaf(['M12 21.6V9.4'], '#7CC76A', 3.6)}
    <path d="M12 15.6C9.4 16.6 6.4 16 5 13.6c2.4-1.4 5.4-1 7 2zM12 15.6c2.6 1 5.6.4 7-2-2.4-1.4-5.4-1-7 2zM12 15.6c-1.6-2.2-1.4-5 .2-6.6" fill="#8CD46F" stroke="${L}" stroke-width="1.4" stroke-linejoin="round"/>
    ${[[12, 3.6], [9.4, 5.4], [14.6, 5.4], [10.4, 8.2], [13.6, 8.2], [12, 6.4]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="2.2" fill="#C69AF0" stroke="${L}" stroke-width="1.3"/>`).join('')}<circle cx="11.2" cy="3" r="0.8" fill="#FFFFFF"/>`),
  // 玉米（第 13 輪）
  corn: (s = 22) => svg(s, `<path d="M12 2.6c3 0 4.6 3.4 4.6 8.2S15 19.6 12 19.6s-4.6-4-4.6-8.8S9 2.6 12 2.6z" fill="#FFD45E" stroke="${L}" stroke-width="1.6"/>
    <path d="M8.4 7.4h7.2M7.9 10.8h8.2M8.3 14.2h7.4M10.2 3.6v15M13.8 3.6v15" stroke="#E2A72E" stroke-width="1.1"/><path d="M9.4 5.8v3.4" stroke="#FFF4CC" stroke-width="1.4" stroke-linecap="round"/>
    <path d="M12 21.6C8 20.6 5 16.8 5.2 11.4c2.4 2.4 4.6 5.6 6.8 10.2zM12 21.6c4-1 7-4.8 6.8-10.2-2.4 2.4-4.6 5.6-6.8 10.2z" fill="#8CD46F" stroke="${L}" stroke-width="1.5" stroke-linejoin="round"/>`),
  // 豆粕：一小袋，袋口露出黃色的豆子，前面滾出兩顆（新畫）
  soy: (s = 22) => svg(s, `<path d="M6.4 8.6c-1.6 2.6-2.4 6-1.8 9.4.4 2 2 3 4 3h6.8c2 0 3.6-1 4-3 .6-3.4-.2-6.8-1.8-9.4z" fill="#E9D3A6" stroke="${L}" stroke-width="1.6" stroke-linejoin="round"/>
    <path d="M6.2 8.8c1.4-1 3.6-1.6 5.8-1.6s4.4.6 5.8 1.6" fill="none" stroke="${L}" stroke-width="1.6" stroke-linecap="round"/>
    <circle cx="9.4" cy="6.8" r="1.9" fill="#F5D26B" stroke="${L}" stroke-width="1.2"/><circle cx="12.4" cy="5.8" r="1.9" fill="#F5D26B" stroke="${L}" stroke-width="1.2"/><circle cx="15" cy="6.9" r="1.9" fill="#F5D26B" stroke="${L}" stroke-width="1.2"/>
    <path d="M7.6 12.6c1.2.8 2.6.9 3.8.5" stroke="#C9A86A" stroke-width="1.2" stroke-linecap="round" fill="none"/><path d="M6.8 14.2c.2 1.6.6 2.8 1.2 3.6" stroke="#FFFFFF" stroke-width="1.3" stroke-linecap="round" fill="none" opacity="0.8"/>
    <ellipse cx="19.6" cy="20" rx="1.8" ry="1.5" fill="#F5D26B" stroke="${L}" stroke-width="1.2"/>`),
};
export const FEED_KEYS = ['grass', 'hay', 'oats', 'alfalfa', 'corn', 'soy'];
