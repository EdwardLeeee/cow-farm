// 第 28 輪草稿（ceo 2026-10-09 交辦，v0.3 第 5.2、12 節）：大便掃地機的「選款式」「壞掉了」「修理」三個畫面。
// 使用者 2026-10-09 選「兩款」：「兩個都有，掃地機器會壞掉。一次買要花錢」。規則照引擎（backend/cowecon/farm.py 的 buy_robot、repair_robot）：
//   - 基本款＝乳牛紋圓盤：買 3,000 幣，平均 1 天壞一次，修理 750；耐用款＝透明圓頂：買 12,000 幣，平均 3 天壞一次，修理 3,000（起點，引擎重跑模擬再定）。
//   - 兩款都每 60 分鐘把大便清掉一次。一次只有一台：買另一款就換掉，舊的不退錢；已經有的那款不能再買（壞了用修理）。
//   - 什麼時候壞玩家看不到（沒有倒數、沒有耐用度條）；壞了就停在原地，付修理費馬上開始動、重新抽壞掉的時間。
// 造型沿用第 20 輪（robot()、充電座）；牧場下方面板照第 26 輪飼料列 B（原本，有底板）＋倉庫小鈕，等使用者選完有沒有底板再換。
// 新的字是草稿，直接寫在這裡，沒有進字串表：使用者看過才加 key、翻英文和泰文（D25）。
// 網址：r28.html?b=R28-01；GIF：r28.html?gif=G1；?list=1 列出全部說明圖。
import { applyDevice, btn, icon, fmt, sheet, toast, fitTitles, fitOriginTags, placeVersion, placeCowPop } from '../../../m2/src/js/kit.js';
import { loadLang, t } from '../../../m2/src/js/i18n.js';
import { HERD } from '../../../m2/src/js/scene.js';
import { poopG } from '../../../m2/src/js/poop.js';
import { FEED_KEYS } from '../../../m2/src/js/feeds.js';

const L = '#4B3326';
const f2 = (v) => Math.round(v * 100) / 100;
const lerp = (a, b, k) => a + (b - a) * k;
const clamp01 = (v) => Math.max(0, Math.min(1, v));
const ease = (u) => { const k = clamp01(u); return k * k * (3 - 2 * k); };
// 字串表在 design/m2/i18n：loadLang 抓 ../i18n/…（相對於頁面），轉到 m2 的資料夾
const realFetch = window.fetch.bind(window);
window.fetch = (u, o) => realFetch(typeof u === 'string' && u.startsWith('../i18n/') ? `../../../m2/${u.slice(3)}` : u, o);
const q = new URLSearchParams(location.search);
const W = +(q.get('w') || 390);
const dev = applyDevice(W);
const app = document.getElementById('app');
await loadLang('zh-Hant');
const { ranchPage, dirtyPill } = await import('../../../m2/src/js/screens/s03.js');
const ctx0 = () => ({ dev, w: dev.w, q: new URLSearchParams() });

// ---------- 說明圖的版面（跟第 18 輪一樣） ----------
const PAD = 36, GAP = 40;
function board({ id, title, sub = '', cells = [], cols = cells.length, notes = [], width }) {
  const wpx = width || PAD * 2 + cols * dev.w + (cols - 1) * GAP;
  const html = `<div class="board" style="width:${wpx}px">
    <div class="b-label">${id}</div>
    <div class="b-title">${title}</div>${sub ? `<div class="b-sub">${sub}</div>` : ''}
    ${cells.length ? `<div class="b-row" style="grid-template-columns:repeat(${cols}, ${dev.w}px)">${cells.map((c) => `<figure class="b-cell"><figcaption><b>${c.cap}</b>${c.note || ''}</figcaption>${c.html}</figure>`).join('')}</div>` : ''}
    ${notes.length ? `<ul class="b-notes">${notes.map((n) => `<li>${n}</li>`).join('')}</ul>` : ''}
  </div>`;
  return { html };
}
const POINTER = (s = 34) => `<svg viewBox="0 0 32 34" width="${s}" height="${Math.round(s * 34 / 32)}" aria-hidden="true"><path d="M11 4.4a2.3 2.3 0 0 1 4.6 0v9.8l1.2-.3a2.1 2.1 0 0 1 2.6 1.5l.1.5 1.1-.2a2.1 2.1 0 0 1 2.5 1.6l.1.5h.8a2.1 2.1 0 0 1 2.2 2.1v4.6c0 4.8-3.3 8.1-7.9 8.1h-1.5c-2.7 0-4.6-1.1-6.2-3.4l-4.8-6.7a2.1 2.1 0 0 1 3.1-2.8l2.1 2.3z" fill="#FFE3D2" stroke="${L}" stroke-width="2" stroke-linejoin="round"/><path d="M15.6 14.2v3.6M19.5 15.4v2.8M23.2 17.1v2" stroke="${L}" stroke-width="1.6" stroke-linecap="round"/></svg>`;
// (x, y)：指尖的位置（手機座標）；press：按下去（縮一點、加一圈）
const finger = (x, y, press = 0, s = 40) => `<div class="gesture" style="left:${f2(x - 13 * s / 32)}px;top:${f2(y - 2)}px;transform:scale(${f2(1 - 0.08 * press)})">${POINTER(s)}</div>${press ? `<span class="r28-tap" style="left:${f2(x - 18)}px;top:${f2(y - 18)}px"></span>` : ''}`;

// ================= 大便掃地機（第 20 輪的造型，多了「壞掉」的樣子） =================
// R1 乳牛紋圓盤（基本款）：白色圓盤、黑色乳牛斑點、前面兩個小眼睛。R2 透明圓頂（耐用款）：看得到吸進去的大便，前面一個笑臉小螢幕。
// broken：眼睛變成 ×、刷子不轉、小螢幕變紅；tilt：歪一邊（壞掉卡住）
function robot(k, { x, y, s = 1, dir = -1, full = 0, spin = 0, broken = false, tilt = 0 } = {}) {
  const eye = (ex) => (broken
    ? `<path d="M${f2(ex - 1.7)} -10.9l3.4 3.4M${f2(ex + 1.7)} -10.9l-3.4 3.4" stroke="${L}" stroke-width="1.5" stroke-linecap="round"/>`
    : `<ellipse cx="${f2(ex)}" cy="-9" rx="1.7" ry="2.3" fill="${L}"/><circle cx="${f2(ex - 0.5)}" cy="-9.8" r="0.6" fill="#FFFFFF"/>`);
  const ex = dir * 9;
  const brush = (bx) => `<g transform="translate(${f2(bx)} 2) rotate(${f2(broken ? 20 : spin)})">${[0, 60, 120].map((a) => `<path d="M0 0L8 0" stroke="#8C7A6A" stroke-width="1.2" transform="rotate(${a})"/>`).join('')}</g>`;
  let body;
  if (k === 'R1') {
    const spots = `<ellipse cx="-8" cy="-12" rx="6" ry="3" fill="${L}"/><ellipse cx="9" cy="-14" rx="4" ry="2.2" fill="${L}"/><ellipse cx="2" cy="-8.4" rx="3" ry="1.6" fill="${L}"/>`;
    body = `<ellipse cx="0" cy="0" rx="25" ry="10" fill="#8C8F99" stroke="${L}" stroke-width="2"/><path d="M-25 -6V0A25 10 0 0 0 25 0V-6" fill="#D9DDE6" stroke="${L}" stroke-width="2"/>
      <ellipse cx="0" cy="-6" rx="25" ry="10" fill="#FFFFFF" stroke="${L}" stroke-width="2"/>${spots}<ellipse cx="${f2(dir * 4)}" cy="-6.4" rx="16" ry="6.4" fill="none" stroke="#E7DED2" stroke-width="1.2"/>
      <path d="M${f2(dir * 25)} -4A25 10 0 0 1 ${f2(dir * 12)} 3.4" fill="none" stroke="${broken ? '#B8ADA2' : '#FF9784'}" stroke-width="3" stroke-linecap="round"/>${eye(ex - 3.2)}${eye(ex + 3.2)}`;
  } else {
    const inside = full ? [[-6, -10], [5, -9], [0, -15]].slice(0, full).map(([px, py]) => poopG(px, py, 9)).join('') : '';
    const sx = dir * 17;
    const face = broken
      ? `<path d="M${f2(sx - 4)} -5.4l2.4 2.4M${f2(sx - 1.6)} -5.4l-2.4 2.4M${f2(sx + 1.6)} -5.4l2.4 2.4M${f2(sx + 4)} -5.4l-2.4 2.4" stroke="#FF8A7A" stroke-width="1.3" stroke-linecap="round"/>`
      : `<path d="M${f2(sx - 3)} -4.4h0M${f2(sx + 3)} -4.4h0" stroke="#7FE0A0" stroke-width="1.8" stroke-linecap="round"/><path d="M${f2(sx - 3)} -2.4Q${f2(sx)} -0.4 ${f2(sx + 3)} -2.4" fill="none" stroke="#7FE0A0" stroke-width="1.2" stroke-linecap="round"/>`;
    body = `<ellipse cx="0" cy="0" rx="24" ry="9.6" fill="#5F7690" stroke="${L}" stroke-width="2"/><path d="M-24 -5V0A24 9.6 0 0 0 24 0V-5" fill="#9DB4CC" stroke="${L}" stroke-width="2"/>
      <ellipse cx="0" cy="-5" rx="24" ry="9.6" fill="#C6D6E6" stroke="${L}" stroke-width="2"/>${inside}
      <path d="M-15 -6C-15 -24 15 -24 15 -6Z" fill="#E6F4FF" fill-opacity="0.55" stroke="${L}" stroke-width="1.8"/><path d="M-9 -15C-7 -19 -3 -20.5 1 -20.5" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round"/>
      <rect x="${f2(sx - 6)}" y="-6.4" width="12" height="7" rx="2.4" fill="${broken ? '#4A2630' : '#2E3A48'}" stroke="${L}" stroke-width="1.2"/>${face}`;
  }
  return `<g transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s)})${tilt ? ` rotate(${f2(tilt)})` : ''}"><ellipse cx="0" cy="3" rx="26" ry="6" fill="#3E6B2A" opacity="0.18"/>${brush(dir * 18)}${body}</g>`;
}
// 充電座
const chargeDock = (x, y) => `<g transform="translate(${x} ${y})"><path d="M-14 4L-11 -12H11L14 4Z" fill="#E7DED2" stroke="${L}" stroke-width="2" stroke-linejoin="round"/><path d="M-3 -9L-6 -3H0L-3 2" fill="none" stroke="#FFC13B" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></g>`;
// 吸大便的漩渦
const swirl = (x, y, s = 1) => `<g transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s)})" opacity="0.9"><path d="M-10 -6Q-2 -14 6 -6T14 -2M-8 2Q0 -4 8 2" fill="none" stroke="#FFFFFF" stroke-width="2.4" stroke-linecap="round"/></g>`;
// 壞掉：冒灰煙（t 讓煙往上飄）、閃一下電
const smoke = (x, y, t = 0) => [0, 1, 2].map((i) => { const k = (t * 0.7 + i / 3) % 1; return `<circle cx="${f2(x + (i - 1) * 6 + Math.sin((k + i) * 5) * 3)}" cy="${f2(y - 6 - k * 30)}" r="${f2(4 + k * 7)}" fill="#9A9DA6" opacity="${f2(0.6 * (1 - k))}"/>`; }).join('');
const zap = (x, y, s = 1) => `<path transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s)})" d="M2 -9L-5 1H0L-3 9L6 -2H1L4 -9Z" fill="#FFD45E" stroke="${L}" stroke-width="1.4" stroke-linejoin="round"/>`;
// 頭上的泡泡：壞掉那一刻是紅色驚嘆號，之後是扳手（點一下修理）
const bubbleBox = (x, y, inner, s = 1) => `<g transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s)})"><path d="M-13 -26h26a5 5 0 0 1 5 5v13a5 5 0 0 1-5 5H5l-5 6-5-6h-8a5 5 0 0 1-5-5v-13a5 5 0 0 1 5-5z" fill="#FFFFFF" stroke="${L}" stroke-width="2.2" stroke-linejoin="round"/>${inner}</g>`;
const alertBubble = (x, y, s = 1) => bubbleBox(x, y, `<path d="M0 -21v8" stroke="#E0503C" stroke-width="3.4" stroke-linecap="round"/><circle cx="0" cy="-8" r="2.1" fill="#E0503C"/>`, s);
const wrenchBubble = (x, y, s = 1) => bubbleBox(x, y, `<g transform="translate(-9 -23.5) scale(0.75)"><path d="M14.6 4.2a4.6 4.6 0 0 0-5.4 5.9L3.8 15.5a2 2 0 0 0 2.8 2.8l5.4-5.4a4.6 4.6 0 0 0 5.9-5.4l-2.8 2.8-2.6-.4-.4-2.6z" fill="#D5EBFF" stroke="${L}" stroke-width="2.4" stroke-linejoin="round"/></g>`, s);
// 修好：扳手轉一下、冒星星
const sparkle = (x, y, r) => `<path d="M${f2(x)} ${f2(y - r)}Q${f2(x + r * 0.2)} ${f2(y - r * 0.2)} ${f2(x + r)} ${f2(y)}Q${f2(x + r * 0.2)} ${f2(y + r * 0.2)} ${f2(x)} ${f2(y + r)}Q${f2(x - r * 0.2)} ${f2(y + r * 0.2)} ${f2(x - r)} ${f2(y)}Q${f2(x - r * 0.2)} ${f2(y - r * 0.2)} ${f2(x)} ${f2(y - r)}Z" fill="#FFFFFF" stroke="#E7B53A" stroke-width="1.2"/>`;
const sparks = (x, y, k = 1) => [[-26, -22, 6], [24, -30, 5], [2, -44, 4.4], [-30, -2, 3.6]].map(([dx, dy, r]) => sparkle(x + dx * (0.7 + 0.3 * k), y + dy * (0.7 + 0.3 * k), r * k)).join('');
const wrenchSpin = (x, y, a) => `<g transform="translate(${f2(x)} ${f2(y)}) rotate(${f2(a)}) translate(-12 -12)"><path d="M14.6 4.2a4.6 4.6 0 0 0-5.4 5.9L3.8 15.5a2 2 0 0 0 2.8 2.8l5.4-5.4a4.6 4.6 0 0 0 5.9-5.4l-2.8 2.8-2.6-.4-.4-2.6z" fill="#D5EBFF" stroke="${L}" stroke-width="2" stroke-linejoin="round"/></g>`;

// 兩款（v0.3 第 5.2 節、params.py 的 robot_*；數字是起點）
const MODELS = {
  R1: { tier: '基本款', name: '乳牛紋圓盤', price: 3000, mtbf: 1, repair: 750, often: '比較常壞' },
  R2: { tier: '耐用款', name: '透明圓頂', price: 12000, mtbf: 3, repair: 3000, often: '比較少壞' },
};

// ================= 牧場畫面 =================
const HERD20 = HERD.filter((h) => h.id !== 7 && h.id !== 12); // 中間空出來，給掃地機跑
const SPOTS = [[196, 452], [256, 440], [314, 456], [146, 436], [232, 470]]; // 大便（場景座標）；前三坨是平常的，後兩坨是壞掉以後多出來的。比第 20 輪高一點：飼料列比原本的小卡高，面板上緣（倉庫、收起）往上了
const DOCK = [348, 420]; // 充電座
const RS = 1.4; // 掃地機在場景裡的大小
const poopsAt = (scales) => SPOTS.map(([x, y], i) => ((scales[i] ?? 0) > 0.02 ? poopG(x, y, 19 * scales[i]) : '')).join('');
// 飼料列 B（第 26 輪，原本，有底板）
const KG = { grass: 1, hay: 1.5, oats: 2, alfalfa: 3, corn: 5, soy: 8 };
const STOCK = { grass: 24, hay: 12, oats: 8, alfalfa: 0, corn: 5, soy: 3 };
const fic = (k, s = 22) => icon(`feed_${k}`, s);
const sack = (k, n) => `<span class="sack"><svg viewBox="0 0 54 58" width="54" height="58" aria-hidden="true"><path d="M12 12Q27 6 42 12L46 18Q51 34 47 50Q27 57 7 50Q3 34 8 18Z" fill="${n ? '#E9D3A6' : '#E5DED2'}" stroke="${L}" stroke-width="2.2" stroke-linejoin="round"/><path d="M12 12Q18 4 27 9Q36 4 42 12" fill="none" stroke="${L}" stroke-width="2"/><path d="M14 17Q27 21 40 17" stroke="#C99A34" stroke-width="2.4" fill="none"/></svg><span class="sk-ic">${fic(k, 24)}</span><b class="num sk-n">${n}</b></span>`;
const feedBar = () => `<div class="fbar fbar-b"><div class="fb-track">${FEED_KEYS.map((k) => `<button class="fb-item${STOCK[k] ? '' : ' none23'}">${sack(k, STOCK[k])}<span class="fb-name">${t(`feed.${k}`)}<b>+${KG[k]}kg</b></span></button>`).join('')}</div><span class="fb-more">${icon('chevron', 16)}</span></div>`;
const whPill = `<button class="wh-pill">${icon('barn', 18)}<span>倉庫</span></button>`;
// 牧場頁：extra 畫在場景裡（場景座標）；下方面板換成飼料列、倉庫小鈕
function ranch(extra, o = {}) {
  let html = ranchPage(ctx0(), { herd: HERD20, ...o });
  html = html.replace(/(<div class="scene">[\s\S]*?)(<\/svg>\s*<\/div>)/, (m, a, b) => a + extra + b);
  html = html.replace(/<div class="dock-row">[\s\S]*?<\/article>\s*<\/div>\s*<\/section>/, `${feedBar()}</section>`);
  return html.replace('<div class="dock-head">', `<div class="dock-head">${whPill}`);
}

// 右上角：掃地中（綠）／掃地機壞了（紅，帶大便數）
const face = (k, broken = false) => `<span class="cl-face"><svg viewBox="-28 -26 56 40" width="26" height="19">${robot(k, { x: 0, y: 0, broken })}</svg></span>`;
const robotPill = (k) => `<div class="dirty cleaning">${face(k)}<span>掃地中</span></div>`;
const brokenPill = (k, n = 0) => `<div class="dirty r28-broken">${face(k, true)}<span>掃地機壞了</span>${n ? `<span class="r28-bp-n">${icon('poop', 16)}<b class="num">${n}</b></span>` : ''}</div>`;

// ---------- 01 選款式（購買面板） ----------
function modelCard(k, { picked = false, owned = false } = {}) {
  const M = MODELS[k];
  return `<button class="r28-model${picked ? ' picked' : ''}${owned ? ' owned' : ''}">${owned ? '<i class="r28-chip">使用中</i>' : ''}
    <span class="r28-pic"><svg viewBox="-34 -30 68 44" width="112" height="72">${robot(k, { x: 0, y: 0, full: k === 'R2' ? 2 : 0 })}</svg></span>
    <span class="r28-name"><b>${M.name}</b><i class="r28-tier ${k === 'R2' ? 'hi' : ''}">${M.tier}</i></span>
    <span class="r28-price">${owned ? '<span class="r28-have">已經有了</span>' : `${icon('coin', 18)}<b class="num">${fmt(M.price)}</b>`}</span>
    <span class="r28-spec"><span>${icon('clock', 14)}每 60 分鐘清一次</span><span class="${k === 'R1' ? 'r28-often' : ''}">${icon('warn', 14)}平均 <b>${M.mtbf} 天</b>壞一次</span><span>${icon('tools', 14)}修理 <b class="num">${fmt(M.repair)}</b> 幣</span></span>
    ${picked ? `<span class="r28-check">${icon('ok', 18)}</span>` : ''}
  </button>`;
}
function modelSheet({ picked = 'R1', owned = null, coins = 12480 } = {}) {
  const M = MODELS[picked], short = M.price - coins;
  const swap = owned && owned !== picked;
  const warn = swap ? `<p class="r28-warn">${icon('warn', 16)}<span>一次只能有一台：換成${M.name}，你的${MODELS[owned].name}會收走，<b>不退錢</b>。</span></p>` : '';
  const label = short > 0 ? `還差 ${fmt(short)} 幣` : swap ? `換成${M.name}（${fmt(M.price)} 幣）` : `買下${M.name}（${fmt(M.price)} 幣）`;
  return sheet({ cls: 'r28-sheet', title: '大便掃地機', body: `<p class="r28-sub">買一台就會在牧場自己跑，把大便吸乾淨。兩款清得一樣快，差在多常壞。</p>
    <div class="r28-models">${['R1', 'R2'].map((k) => modelCard(k, { picked: k === picked, owned: owned === k })).join('')}</div>
    <ul class="r28-rules"><li>什麼時候會壞看不到；壞了會停在原地，付修理費才會再動。</li><li>一次只能有一台。</li></ul>${warn}
    <div class="btn-row">${btn(t('cancel'))}${btn(label, { kind: 'primary', disabled: short > 0 })}</div>` });
}
// ---------- 03 修理面板 ----------
function repairSheet(k, { coins = 12480 } = {}) {
  const M = MODELS[k], short = M.repair - coins;
  const other = k === 'R1' ? `<button class="r28-link">${icon('chevron', 14)}<span>改買耐用款（${fmt(MODELS.R2.price)} 幣，平均 3 天才壞一次）</span></button>` : '';
  return sheet({ cls: 'r28-sheet', title: '修理掃地機', body: `<div class="r28-hero"><span class="r28-hpic"><svg viewBox="-34 -46 68 60" width="120" height="106">${robot(k, { x: 0, y: 0, broken: true, tilt: -6, full: k === 'R2' ? 3 : 0 })}${smoke(4, -12, 0.4)}</svg></span>
      <div><b class="r28-hname">${M.name}<i class="r28-tier ${k === 'R2' ? 'hi' : ''}">${M.tier}</i></b><p class="r28-hint">壞掉了，停在原地。牧場的大便會越積越多，牛會因為太髒生病。</p></div></div>
    <div class="r28-cost"><span>修理費</span><span class="r28-cv">${icon('coin', 20)}<b class="num">${fmt(M.repair)}</b> 幣</span></div>
    <ul class="r28-rules"><li>修好馬上開始動，每 60 分鐘清一次。</li><li>之後還是會壞：平均 ${M.mtbf} 天一次，什麼時候壞看不到。</li></ul>${other}
    <div class="btn-row">${btn(t('cancel'))}${btn(short > 0 ? `還差 ${fmt(short)} 幣` : `修理（${fmt(M.repair)} 幣）`, { kind: 'primary', ic: short > 0 ? '' : 'tools', disabled: short > 0 })}</div>` });
}

// ---------- 掃地機在牧場的樣子（場景座標） ----------
// 壞掉的位置：吸完右邊那坨、往中間那坨的路上
const BROKE = [288, 452];
const brokenBot = (k, { t = 0, fresh = false } = {}) => robot(k, { x: BROKE[0], y: BROKE[1], s: RS, dir: -1, broken: true, tilt: -7, full: k === 'R2' ? 1 : 0 })
  + smoke(BROKE[0] + 8, BROKE[1] - 20, t) + (fresh ? zap(BROKE[0] - 26, BROKE[1] - 22, 1.2) + zap(BROKE[0] + 30, BROKE[1] - 12, 0.9) + alertBubble(BROKE[0], BROKE[1] - 40, 1.1) : wrenchBubble(BROKE[0], BROKE[1] - 40, 1.1));

function brokeCells(k) {
  const walking = ranch(poopsAt([1, 1, 0.4]) + chargeDock(...DOCK) + robot(k, { x: SPOTS[2][0] + 8, y: SPOTS[2][1] + 8, s: RS, dir: -1, full: k === 'R2' ? 1 : 0, spin: 30 }) + swirl(SPOTS[2][0] - 26, SPOTS[2][1] - 8, 1.1), { center: robotPill(k) });
  const moment = ranch(poopsAt([1, 1]) + chargeDock(...DOCK) + brokenBot(k, { t: 0.2, fresh: true }), { center: brokenPill(k), overlays: toast('warn', '掃地機壞掉了，停在原地') });
  const later = ranch(poopsAt([1, 1, 1, 1, 1]) + chargeDock(...DOCK) + brokenBot(k, { t: 0.6 }), { center: brokenPill(k, 5) });
  const tap = ranch(poopsAt([1, 1, 1, 1, 1]) + chargeDock(...DOCK) + brokenBot(k, { t: 0.9 }), { center: brokenPill(k, 5), overlays: finger(...botPhone(4, 10), 1) });
  return [
    { cap: '1 平常：掃地中', note: '每 60 分鐘出來吸一次；右上角「掃地中」', html: walking },
    { cap: '2 壞掉的那一刻', note: '停在原地、眼睛變 ×、冒煙、閃電；右上角變紅「掃地機壞了」，下面跳一行提示', html: moment },
    { cap: '3 回來才看到', note: '什麼時候壞看不到（沒有倒數）：常常是回來才發現大便積了好幾坨；機器頭上一個扳手', html: later },
    { cap: '4 點機器或右上角', note: '打開修理面板（見 R28-03）', html: tap },
  ];
}
function repairCells() {
  const fixed = (k, u) => ranch(poopsAt([1, 1, 1, 1, 1]) + chargeDock(...DOCK) + robot(k, { x: BROKE[0], y: BROKE[1], s: RS, dir: -1, full: k === 'R2' ? 1 : 0 }) + wrenchSpin(BROKE[0] + 2, BROKE[1] - 44, -40 + u * 80) + sparks(BROKE[0], BROKE[1] - 14, 0.6 + 0.4 * u), { center: robotPill(k), overlays: toast('ok', '修好了！掃地機開始動') });
  const back = (k) => ranch(poopsAt([0.4, 1, 0, 1, 0]) + chargeDock(...DOCK) + robot(k, { x: SPOTS[0][0] + 8, y: SPOTS[0][1] + 8, s: RS, dir: -1, full: k === 'R2' ? 3 : 0, spin: 60 }) + swirl(SPOTS[0][0] - 26, SPOTS[0][1] - 8, 1.1), { center: robotPill(k) });
  const bg = (k, coins = 12480) => ranch(poopsAt([1, 1, 1, 1, 1]) + chargeDock(...DOCK) + brokenBot(k, { t: 0.9 }), { center: brokenPill(k, 5), hud: { coins }, overlays: repairSheet(k, { coins }) });
  return [
    { cap: '1 修理面板（基本款）', note: '修理費 750 幣；修好馬上開始動。下面一行可以改買耐用款（打開選款式）', html: bg('R1') },
    { cap: '2 修理面板（耐用款）', note: '修理費 3,000 幣（都是買價的 1/4）', html: bg('R2') },
    { cap: '3 錢不夠', note: '按鈕停用、寫還差多少', html: bg('R1', 500) },
    { cap: '4 修好了', note: '扳手轉一下、冒星星，右上角變回「掃地中」', html: fixed('R1', 0.6) },
    { cap: '5 回去吸大便', note: '一坨一坨吸乾淨；之後還是會壞，平均 1 天一次（耐用款 3 天）', html: back('R1') },
  ];
}
function modelCells() {
  const bg = (o) => ranch(poopsAt([1, 1, 1]), { center: dirtyPill(3), hud: { coins: o.coins ?? 12480 }, overlays: modelSheet(o) });
  return [
    { cap: '1 還沒有：選基本款', note: '從右上角的「大便」或商店打開（跟雇用打掃牛同一個地方）；兩款並排比', html: bg({ picked: 'R1' }) },
    { cap: '2 選耐用款', note: '貴 4 倍，比較少壞；修理費都是買價的 1/4', html: bg({ picked: 'R2' }) },
    { cap: '3 已經有基本款，想換', note: '一次只能有一台：換別款，舊的收走、不退錢；已經有的那款寫「已經有了」，不能再買', html: bg({ picked: 'R2', owned: 'R1' }) },
    { cap: '4 錢不夠', note: '按鈕停用、寫還差多少', html: bg({ picked: 'R2', coins: 8200 }) },
  ];
}
// 掃地機在手機上的位置（給手指用）：量出來的，見 botPhone()
let BOT_PHONE = [0, 0];
const botPhone = (dx = 0, dy = 0) => [BOT_PHONE[0] + dx, BOT_PHONE[1] + dy];

const SUB = '使用者選「兩款」：「兩個都有，掃地機器會壞掉。一次買要花錢」。基本款（乳牛紋圓盤）3,000 幣、平均 1 天壞一次、修理 750；耐用款（透明圓頂）12,000 幣、平均 3 天壞一次、修理 3,000；兩款都每 60 分鐘清一次（數字是起點，引擎重跑模擬再定）。';
const BOARDS = [
  { id: 'R28-01', render: () => board({ id: 'R28-01-掃地機-選款式-390', title: '01 選款式：基本款、耐用款並排比', sub: SUB, cells: modelCells(), notes: ['什麼時候會壞玩家看不到，所以面板上只寫「平均幾天壞一次」，沒有倒數、沒有耐用度。', '牧場下方面板照第 26 輪飼料列 B（原本，有底板）＋倉庫小鈕；等使用者選完有沒有底板再換。'] }) },
  { id: 'R28-02', render: () => board({ id: 'R28-02-掃地機-壞掉了-390', title: '02 壞掉了：停在原地，大便越積越多', sub: SUB, cells: brokeCells('R1'), notes: ['分鏡用基本款（乳牛紋圓盤）畫；耐用款（透明圓頂）壞掉時一樣：小螢幕變紅、×× 眼睛。', '動起來的樣子：R28-02-掃地機-壞掉到修好-390.gif'] }) },
  { id: 'R28-03', render: () => board({ id: 'R28-03-掃地機-修理-390', title: '03 修理：付修理費，馬上開始動', sub: SUB, cells: repairCells() }) },
  { id: 'R28-99', render: r2899 },
];
function r2899() {
  const S = 0.5, sw = Math.round(dev.w * S), sh = Math.round(dev.h * S);
  const mini = (html) => `<div class="ov-ph" style="width:${sw}px;height:${sh}px"><div style="transform:scale(${S});transform-origin:0 0">${html}</div></div>`;
  const cell = (cap, inner) => `<div class="ov-cell"><div class="ov-cap"><b>${cap}</b></div>${inner}</div>`;
  const row = (title, cells) => `<div class="ov-row"><div class="ov-title">${title}</div><div class="ov-cells">${cells.join('')}</div></div>`;
  const m = modelCells(), b = brokeCells('R1'), r = repairCells();
  const body = row('01 選款式', [cell('還沒有：兩款並排', mini(m[0].html)), cell('已經有基本款，想換', mini(m[2].html))])
    + row('02 壞掉了', [cell('壞掉的那一刻', mini(b[1].html)), cell('回來才看到', mini(b[2].html))])
    + row('03 修理', [cell('修理面板', mini(r[0].html)), cell('修好了', mini(r[3].html))]);
  return { html: `<div class="board" style="width:${PAD * 2 + 2 * sw + 28 + 10}px"><div class="b-label">R28-99-總覽對照</div><div class="b-title">第 28 輪：大便掃地機的選款式、壞掉了、修理</div>
    <div class="b-sub">使用者已經選了「兩款」，這一輪沒有 A／B 要選：看完說可以或要改哪裡。各自的分鏡見 R28-01、02、03；動起來的樣子見 R28-02 的 GIF。</div>${body}</div>` };
}

// ---------- GIF：吸大便 → 壞掉 → 回來看到 → 點機器 → 修理 → 修好 → 繼續吸 ----------
const GT = 9;
function gifFrame(t) {
  const k = 'R1';
  let scene = chargeDock(...DOCK), center = robotPill(k), ov = '';
  const poopsA = [1, 1, 1];
  if (t < 1.6) { // 吸右邊那坨
    const u = ease(t / 1.2), x = lerp(DOCK[0] - 6, SPOTS[2][0] + 8, u), y = lerp(DOCK[1] + 14, SPOTS[2][1] + 8, u);
    const s2 = t < 1.0 ? 1 : 1 - ease((t - 1.0) / 0.5);
    scene += poopsAt([1, 1, s2]) + robot(k, { x, y, s: RS, dir: -1, spin: t * 720 }) + (t >= 1.0 && t < 1.6 ? swirl(SPOTS[2][0] - 26, SPOTS[2][1] - 8, 1.1) : '');
  } else if (t < 2.0) { // 往中間那坨走
    const u = ease((t - 1.6) / 0.4), x = lerp(SPOTS[2][0] + 8, BROKE[0], u), y = lerp(SPOTS[2][1] + 8, BROKE[1], u);
    scene += poopsAt([1, 1]) + robot(k, { x, y, s: RS, dir: -1, spin: t * 720 });
  } else if (t < 3.4) { // 壞掉
    const fresh = t < 2.9;
    scene += poopsAt([1, 1]) + brokenBot(k, { t: t - 2.0, fresh });
    center = brokenPill(k);
    if (t >= 2.2) ov += toast('warn', '掃地機壞掉了，停在原地');
  } else if (t < 4.6) { // 過了一陣子：大便積起來（一坨一坨冒出來）
    const g = (i) => clamp01((t - 3.4 - i * 0.35) / 0.25);
    scene += poopsAt([1, 1, g(0), g(1), g(2)]) + brokenBot(k, { t: t - 2.0 });
    center = brokenPill(k, 2 + (g(0) >= 1) + (g(1) >= 1) + (g(2) >= 1));
    if (t < 4.3) ov += `<div class="r28-later">過了一陣子…</div>`;
    if (t >= 4.3) ov += finger(...botPhone(4, 10), t >= 4.45 ? 1 : 0);
  } else if (t < 6.2) { // 修理面板滑上來、按修理
    const up = ease((t - 4.6) / 0.3);
    scene += poopsAt([1, 1, 1, 1, 1]) + brokenBot(k, { t: t - 2.0 });
    center = brokenPill(k, 5);
    ov += repairSheet(k).replace('<div class="backdrop"></div>', `<div class="backdrop" style="opacity:${f2(up)}"></div>`).replace('<section class="sheet', `<section style="transform:translateY(${f2((1 - up) * 100)}%)" class="sheet`);
    if (t >= 5.3) ov += finger(...REPAIR_BTN, t >= 5.6 && t < 5.9 ? 1 : 0);
  } else if (t < 7.2) { // 修好了
    const u = clamp01((t - 6.2) / 0.6);
    scene += poopsAt([1, 1, 1, 1, 1]) + robot(k, { x: BROKE[0], y: BROKE[1], s: RS, dir: -1 }) + (u < 1 ? wrenchSpin(BROKE[0] + 2, BROKE[1] - 44, -60 + u * 120) : '') + sparks(BROKE[0], BROKE[1] - 14, 0.4 + 0.6 * Math.sin(u * Math.PI));
    ov += toast('ok', '修好了！掃地機開始動');
  } else { // 繼續吸：中間那坨
    const u = ease((t - 7.2) / 0.8), x = lerp(BROKE[0], SPOTS[1][0] + 8, u), y = lerp(BROKE[1], SPOTS[1][1] + 8, u);
    const s1 = t < 8.0 ? 1 : 1 - ease((t - 8.0) / 0.5);
    scene += poopsAt([1, s1, 0, 1, 1]) + robot(k, { x, y, s: RS, dir: -1, spin: t * 720 }) + (t >= 8.0 ? swirl(SPOTS[1][0] - 26, SPOTS[1][1] - 8, 1.1) : '');
  }
  return ranch(scene, { center, overlays: ov });
}
let REPAIR_BTN = [290, 790];
const GIFS = { G1: { fn: gifFrame, file: 'R28-02-掃地機-壞掉到修好-390', total: GT } };

async function settle() {
  await document.fonts.ready;
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
}
// 量掃地機在手機上的位置、修理鈕的位置（手指要點在上面）
async function measure() {
  app.innerHTML = `<div class="gif-box">${ranch(brokenBot('R1', { t: 0 }).replace('<g transform', '<g data-bot="1" transform'), { overlays: repairSheet('R1') })}</div>`;
  await settle();
  const ph = app.querySelector('.phone').getBoundingClientRect();
  const bot = app.querySelector('[data-bot]').getBoundingClientRect();
  BOT_PHONE = [Math.round(bot.left + bot.width / 2 - ph.left), Math.round(bot.top + bot.height / 2 - ph.top)];
  const b = [...app.querySelectorAll('.r28-sheet .btn-row .btn')].pop().getBoundingClientRect();
  REPAIR_BTN = [Math.round(b.left + b.width / 2 - ph.left), Math.round(b.top + b.height / 2 - ph.top)];
  app.innerHTML = '';
}
if (q.has('list')) {
  window.__boards = BOARDS.map(({ id }) => ({ id, w: 390 }));
  window.__ready = true;
} else if (q.has('gif')) {
  await measure();
  const g = GIFS[q.get('gif')];
  window.__frame = async (tt) => { app.innerHTML = `<div class="gif-box"><div class="gif-label">${g.file}</div>${g.fn(tt)}</div>`; await settle(); };
  window.__gif = { file: g.file, total: g.total };
  await window.__frame(0);
  window.__ready = true;
} else {
  await measure();
  const b = BOARDS.find((x) => x.id === q.get('b'));
  if (!b) throw new Error(`沒有這張：${q.get('b')}`);
  app.innerHTML = b.render().html;
  await settle();
  if (fitTitles(app)) await settle();
  if (fitOriginTags(app) + placeVersion(app)) await settle();
  if (placeCowPop(app)) await settle();
  const el = app.querySelector('.board');
  window.__file = el.querySelector('.b-label').textContent;
  window.__size = { w: Math.ceil(el.offsetWidth), h: Math.ceil(el.offsetHeight) };
  window.__ready = true;
}
