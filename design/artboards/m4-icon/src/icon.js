// M4 app 圖示草稿：3 個方向，用第 11 輪定案的牛（design/m2/src/cow）。圖示上不放字（D21 遊戲名稱還沒定）。
// 路由：?v=icon&o=A（1024 原圖，不透明）｜?v=bg、?v=fg（Android 背景、前景，432）｜?v=android（背景＋前景，108dp 整張畫布）｜&px=尺寸
//       ?v=board&o=A（說明圖）｜?v=overview&r=1｜2（總覽，第幾輪）
// 同一份圖：iOS 用 0–1024 的範圍；Android 的畫布是 108dp、看得到的是中間 72dp，所以把 1024 對到中間 72dp，畫布外圍多畫一圈（-256–1280）。
import { drawCow } from '../../../m2/src/cow/render.js';

const INK = '#4B3326';
const q = new URLSearchParams(location.search);
const app = document.getElementById('app');

// 把牛放到「臉的中心在 (X, Y)、臉的半徑 R」的位置
function cowAt(entry, X, Y, R, id) {
  const r1 = drawCow(entry, { id: `${id}0` });
  const k = R / r1.face.r;
  return drawCow(entry, { x: X - r1.face.cx * k, y: Y - r1.face.cy * k, scale: k, id }).svg;
}
// 牛腳放在 (X, Y)、整頭高 H（全身）
function cowStand(entry, X, Y, H, id) {
  const r1 = drawCow(entry, { id: `${id}0` });
  const k = H / r1.height;
  const cx = (r1.bbox.x0 + r1.bbox.x1) / 2 * r1.scale;
  return drawCow(entry, { x: X - cx * k, y: Y, scale: k, id }).svg;
}

const sky = (id, top = '#8ED0FF', bot = '#E2F5FF') => `<defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${top}"/><stop offset="1" stop-color="${bot}"/></linearGradient></defs><rect x="-256" y="-256" width="1536" height="1536" fill="url(#${id})"/>`;
const hill = (y, { fill = '#AEE594', bump = 70 } = {}) => `<path d="M-256,${y + 40} C100,${y - bump} 924,${y - bump} 1280,${y + 40} L1280,1280 L-256,1280 Z" fill="${fill}" stroke="${INK}" stroke-width="12" stroke-linejoin="round"/>`;
const grass = (pts) => pts.map(([x, y, s = 1]) => `<path d="M${x - 14 * s},${y} l${7 * s},${-18 * s} l${7 * s},${14 * s} l${7 * s},${-18 * s} l${7 * s},${22 * s}" fill="none" stroke="#7CC76A" stroke-width="${6 * s}" stroke-linecap="round" stroke-linejoin="round"/>`).join('');
const flower = (x, y, c = '#FFFFFF', s = 1) => `<g transform="translate(${x},${y}) scale(${s})">${[0, 72, 144, 216, 288].map((a) => `<circle cx="${14 * Math.cos((a * Math.PI) / 180)}" cy="${14 * Math.sin((a * Math.PI) / 180)}" r="11" fill="${c}" stroke="${INK}" stroke-width="4"/>`).join('')}<circle r="8" fill="#FFD45E" stroke="${INK}" stroke-width="4"/></g>`;
const sun = (x, y, r) => `<circle cx="${x}" cy="${y}" r="${r * 1.45}" fill="#FFF6C9" opacity="0.75"/><circle cx="${x}" cy="${y}" r="${r}" fill="#FFE58A" stroke="${INK}" stroke-width="10"/>`;

// 金幣：可可色粗外框、內圈、亮點、中間一顆星（不放字）
function coin(x, y, r) {
  const star = [...Array(10)].map((_, i) => { const a = -Math.PI / 2 + (i * Math.PI) / 5, rr = i % 2 ? r * 0.24 : r * 0.52; return `${x + rr * Math.cos(a)},${y + rr * Math.sin(a)}`; }).join(' ');
  return `<circle cx="${x}" cy="${y}" r="${r}" fill="#FFD45E" stroke="${INK}" stroke-width="${r * 0.11}"/>
    <circle cx="${x}" cy="${y}" r="${r * 0.74}" fill="none" stroke="#E0AE3C" stroke-width="${r * 0.08}"/>
    <polygon points="${star}" fill="#FFE99A" stroke="#C98F21" stroke-width="${r * 0.06}" stroke-linejoin="round"/>
    <path d="M${x - r * 0.62},${y - r * 0.3} A${r * 0.7},${r * 0.7} 0 0 1 ${x - r * 0.2},${y - r * 0.66}" fill="none" stroke="#FFFFFF" stroke-width="${r * 0.1}" stroke-linecap="round" opacity="0.9"/>`;
}

// 三個方向：bg 是背景層（滿版、外圍多畫一圈），fg 是前景層（牛，透明底）
export const OPTIONS = {
  A: {
    round: 1, name: '牛臉特寫', desc: '荷斯坦的大臉，縮到最小也認得出是牛。天空、草地照牧場的配色。',
    bg: () => `${sky('skyA')}${sun(850, 170, 70)}${hill(790, { bump: 60 })}${grass([[150, 930], [880, 960], [700, 1010, 0.8]])}`,
    fg: () => cowAt({ breed: 'holstein' }, 512, 560, 345, 'ca'),
  },
  B: {
    round: 1, name: '山坡上的牛', desc: '跟啟動畫面同一個場景：太陽、山坡、荷斯坦坐在草地上。',
    bg: () => `${sky('skyB')}${sun(790, 230, 92)}${hill(700)}${grass([[160, 860], [860, 880], [300, 990, 0.8], [760, 1000, 0.8]])}${flower(150, 960, '#FFFFFF', 1.3)}${flower(880, 930, '#FFC2D6', 1.3)}`,
    fg: () => cowStand({ breed: 'holstein' }, 512, 930, 780, 'cb'),
  },
  C: {
    round: 1, name: '金幣項圈', desc: '牛的脖子上掛一枚金幣，帶出「賣牛奶、賺金幣」的玩法。',
    bg: () => `<defs><radialGradient id="mintC" cx="0.5" cy="0.42" r="0.75"><stop offset="0" stop-color="#E6F8D8"/><stop offset="1" stop-color="#9FDC84"/></radialGradient></defs><rect x="-256" y="-256" width="1536" height="1536" fill="url(#mintC)"/>`,
    fg: () => `${cowAt({ breed: 'holstein' }, 512, 410, 250, 'cc')}
      <path d="M330,690 Q512,790 694,690" fill="none" stroke="${INK}" stroke-width="46" stroke-linecap="round"/><path d="M330,690 Q512,790 694,690" fill="none" stroke="#E5484D" stroke-width="28" stroke-linecap="round"/>
      ${coin(512, 830, 150)}`,
  },
};

// 第二輪（使用者 2026-10-02：「a版的最好，但有沒有黃牛版的？我覺得黃牛也很可愛」）：照 A 的畫法換品種。
// 背景一樣是 A 的天空、太陽、草地；牛臉的中心和大小都跟 A 一樣，方便比較
const FACE = { x: 512, y: 560, r: 345 };
const R2 = [
  ['A1', 'holstein', '荷斯坦', '現在的 A，當對照：黑白花斑的招牌乳牛。'],
  ['A2', 'yellow', '台灣黃牛', '黃褐色的耕牛，啟動畫面那頭小牛也是黃牛。'],
  ['A3', 'angus', '安格斯', '炭灰黑、沒有角的肉牛。'],
  ['A4', 'jersey', '娟珊', '淺褐色的乳牛，臉短短、眼睛又大又亮。'],
  ['A5', 'buffalo', '台灣水牛', '深灰色的耕牛，一對往後彎的大角。'],
  ['A6', 'highland', '高地牛', '薑黃色長毛蓋住眼睛，頭上一對長長的角。'],
];
for (const [o, breed, name, desc] of R2) OPTIONS[o] = { round: 2, name, desc, bg: OPTIONS.A.bg, fg: () => cowAt({ breed }, FACE.x, FACE.y, FACE.r, `c${o}`) };
const PREFIX = { 1: 'M4-ICON-01', 2: 'M4-ICON-02' };

// 一張圖的 SVG。view：'icon'（0–1024，不透明）｜'android'（-256–1280：背景＋前景）｜'bg'｜'fg'
export function iconSVG(o, view = 'icon', px = 1024) {
  const O = OPTIONS[o];
  const vb = view === 'icon' ? '0 0 1024 1024' : '-256 -256 1536 1536';
  const body = view === 'bg' ? O.bg() : view === 'fg' ? O.fg() : O.bg() + O.fg();
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vb}" width="${px}" height="${px}">${body}</svg>`;
}
const dataUrl = (svg) => `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;

// ---------- 版面 ----------
const CSS = `
body { margin: 0; background: #FFF9EF; font-family: "Noto Sans CJK TC", sans-serif; color: ${INK}; }
.board { padding: 28px 32px 32px; width: max-content; }
.label { font-size: 34px; font-weight: 900; }
.sub { margin-top: 6px; font-size: 20px; color: #8A6F60; }
.note { font-size: 18px; color: #C2541B; margin-top: 4px; }
.row { display: flex; gap: 28px; margin-top: 22px; align-items: flex-start; }
.box { background: #FFFFFF; border: 3px solid #E5D6C6; border-radius: 18px; padding: 16px 18px; }
.box h3 { margin: 0 0 10px; font-size: 22px; font-weight: 900; }
.cap { font-size: 16px; color: #8A6F60; margin-top: 8px; }
.wall { border-radius: 26px; padding: 22px 20px 18px; width: 300px; }
.wall.light { background: linear-gradient(160deg, #EEF3F9, #D8E3EF); }
.wall.dark { background: linear-gradient(160deg, #2A3142, #11141C); }
.wall .t { font-size: 15px; font-weight: 700; margin-bottom: 12px; }
.wall.dark .t { color: #E8E8EE; }
.grid { display: grid; grid-template-columns: repeat(4, 60px); justify-content: space-between; row-gap: 6px; }
.slot { display: flex; flex-direction: column; align-items: center; gap: 6px; }
.slot .ph { width: 60px; height: 60px; border-radius: 13.4px; }
.slot .nm { width: 40px; height: 7px; border-radius: 4px; background: rgba(0,0,0,0.18); }
.wall.dark .slot .nm { background: rgba(255,255,255,0.35); }
.ios60 { width: 60px; height: 60px; border-radius: 13.4px; overflow: hidden; }
.ios60 img, .ios29 img { width: 100%; height: 100%; display: block; }
.list { margin-top: 18px; border-radius: 12px; padding: 8px 10px; display: flex; flex-direction: column; gap: 8px; }
.wall.light .list { background: #FFFFFF; }
.wall.dark .list { background: #1F232D; }
.li { display: flex; align-items: center; gap: 10px; }
.ios29 { width: 29px; height: 29px; border-radius: 6.5px; overflow: hidden; flex: none; }
.li .bar { height: 8px; border-radius: 4px; background: rgba(0,0,0,0.16); }
.wall.dark .li .bar { background: rgba(255,255,255,0.3); }
.li .ph29 { width: 29px; height: 29px; border-radius: 6.5px; flex: none; }
.and { display: grid; grid-template-columns: repeat(2, 150px); gap: 14px 18px; }
.layer { width: 150px; height: 150px; border-radius: 8px; overflow: hidden; position: relative; }
.layer.checker { background: repeating-conic-gradient(#E9E2DA 0 25%, #FFFFFF 0 50%) 0 0 / 20px 20px; }
.layer img { width: 100%; height: 100%; display: block; }
.safe { position: absolute; left: 50%; top: 50%; width: ${(66 / 108) * 150}px; height: ${(66 / 108) * 150}px; transform: translate(-50%, -50%); border: 2px dashed #E5484D; border-radius: 50%; }
.vis { position: absolute; left: 50%; top: 50%; width: ${(72 / 108) * 150}px; height: ${(72 / 108) * 150}px; transform: translate(-50%, -50%); border: 2px dashed #3C7FD6; }
.masks { display: flex; gap: 14px; align-items: center; padding: 12px; border-radius: 14px; }
.masks.light { background: #E9EEF5; } .masks.dark { background: #161A22; }
.mask { width: 72px; height: 72px; overflow: hidden; }
.mask img { width: 150%; height: 150%; margin: -25%; display: block; }
.mask.circle { border-radius: 50%; } .mask.squircle { border-radius: 30%; } .mask.square { border-radius: 14%; }
.ov { display: flex; gap: 36px; margin-top: 22px; }
.ov-col { width: 400px; }
.ov.ov2 { display: grid; grid-template-columns: repeat(3, 400px); gap: 36px 36px; }
.ov-col h2 { margin: 0 0 12px; font-size: 28px; font-weight: 900; }
.big { width: 300px; height: 300px; border-radius: 67px; overflow: hidden; box-shadow: 0 6px 0 rgba(75,51,38,0.18); }
.big img { width: 100%; height: 100%; display: block; }
.strip { display: flex; gap: 16px; align-items: center; padding: 14px 16px; border-radius: 16px; margin-top: 12px; }
.strip.light { background: linear-gradient(160deg, #EEF3F9, #D8E3EF); }
.strip.dark { background: linear-gradient(160deg, #2A3142, #11141C); }
`;

const PH_L = ['#C9D3DE', '#B9C6D4', '#D4DDE7'], PH_D = ['#3A4252', '#4A5366', '#323949'];
function wall(o, kind) {
  const src = dataUrl(iconSVG(o));
  const ph = kind === 'light' ? PH_L : PH_D;
  return `<div class="wall ${kind}"><div class="t">${kind === 'light' ? '淺色桌布' : '深色桌布'}・桌面 60pt</div>
    <div class="grid"><div class="slot"><div class="ios60"><img src="${src}"></div><div class="nm"></div></div>${ph.map((c) => `<div class="slot"><div class="ph" style="background:${c}"></div><div class="nm"></div></div>`).join('')}</div>
    <div class="t" style="margin-top:16px">設定、搜尋 29pt</div>
    <div class="list"><div class="li"><div class="ios29"><img src="${src}"></div><div class="bar" style="width:120px"></div></div><div class="li"><div class="ph29" style="background:${ph[0]}"></div><div class="bar" style="width:90px"></div></div></div></div>`;
}
function board(o) {
  const O = OPTIONS[o], label = `${PREFIX[O.round]}-app圖示-${o}-${O.name}`;
  const bg = dataUrl(iconSVG(o, 'bg', 432)), fg = dataUrl(iconSVG(o, 'fg', 432)), all = dataUrl(iconSVG(o, 'android', 432));
  return `<div class="board"><div class="label">${label}</div>
    <div class="sub">${O.round === 2 ? `app 圖示草稿第 2 輪・照 A（牛臉特寫）的畫法換品種 ${o}「${O.name}」` : `app 圖示草稿・方向 ${o}「${O.name}」`}：${O.desc}</div>
    <div class="note">註：圖示上不放字（遊戲名稱還沒定，D21）。桌布上的灰色方塊和灰條是別的 app 和名字的位置，不是設計的一部分。圓角是系統切的，這裡是示意。</div>
    <div class="row">
      <div class="box"><h3>1024×1024 原圖</h3><img src="${dataUrl(iconSVG(o))}" width="420" height="420" style="display:block;border:1px solid #E5D6C6"><div class="cap">iOS：不透明、方角，圓角由系統切</div></div>
      <div class="box"><h3>iPhone 桌面</h3><div style="display:flex;gap:18px">${wall(o, 'light')}${wall(o, 'dark')}</div></div>
      <div class="box"><h3>Android adaptive icon</h3>
        <div class="and"><div><div class="layer"><img src="${bg}"></div><div class="cap">背景層（不透明）</div></div>
          <div><div class="layer checker"><img src="${fg}"><span class="vis"></span><span class="safe"></span></div><div class="cap">前景層（透明底）<br>藍框：看得到的 72dp<br>紅圈：一定不會被切的 66dp</div></div></div>
        <div class="cap" style="margin-top:12px">各家手機切成不同的形狀：</div>
        <div class="masks light">${['circle', 'squircle', 'square'].map((m) => `<div class="mask ${m}"><img src="${all}"></div>`).join('')}</div>
        <div class="masks dark" style="margin-top:10px">${['circle', 'squircle', 'square'].map((m) => `<div class="mask ${m}"><img src="${all}"></div>`).join('')}</div>
      </div>
    </div></div>`;
}
function overview(r = 1) {
  const sub = r === 2 ? 'app 圖示草稿第 2 輪：照 A（牛臉特寫）的畫法換 6 個品種，臉的大小和位置都一樣。上面是 iPhone 切好圓角的樣子，下面是縮到桌面 60pt、設定 29pt，放在淺色、深色桌布上' : 'app 圖示草稿 3 個方向：上面是 iPhone 切好圓角的樣子，下面是縮到桌面 60pt、設定 29pt，放在淺色、深色桌布上';
  return `<div class="board"><div class="label">${PREFIX[r]}-app圖示-總覽對照</div>
    <div class="sub">${sub}</div>
    <div class="ov${r === 2 ? ' ov2' : ''}">${Object.entries(OPTIONS).filter(([, O]) => O.round === r).map(([o, O]) => { const src = dataUrl(iconSVG(o)); return `<div class="ov-col"><h2>${o}　${O.name}</h2><div class="big"><img src="${src}"></div>
      ${['light', 'dark'].map((k) => `<div class="strip ${k}"><div class="ios60"><img src="${src}"></div><div class="ios29"><img src="${src}"></div><span style="font-size:15px;font-weight:700;color:${k === 'light' ? INK : '#E8E8EE'}">${k === 'light' ? '淺色桌布' : '深色桌布'}</span></div>`).join('')}
      <div class="cap" style="font-size:17px">${O.desc}</div></div>`; }).join('')}</div></div>`;
}

const v = q.get('v') || 'overview', o = q.get('o') || 'A';
if (v === 'board' || v === 'overview') {
  const st = document.createElement('style'); st.textContent = CSS; document.head.appendChild(st);
  app.innerHTML = v === 'board' ? board(o) : overview(+(q.get('r') || 1));
} else {
  document.body.style.margin = '0';
  const px = +(q.get('px') || (v === 'icon' ? 1024 : 432));
  app.innerHTML = iconSVG(o, v === 'icon' ? 'icon' : v, px);
  app.firstElementChild.style.display = 'block';
}
await document.fonts.ready;
await Promise.all([...document.images].map((im) => (im.complete ? 0 : new Promise((r) => { im.onload = im.onerror = r; }))));
window.__ready = true;
