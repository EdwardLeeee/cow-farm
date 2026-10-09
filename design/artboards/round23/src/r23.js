// 第 23 輪草稿（ceo 2026-10-09 交辦）：使用者看完第 19 輪餵食：
//   01 入口「B比較好，但我希望把飼料丟地上，最靠近的牛會走過來吃。然後我覺得下面那個市場資訊拿掉，庫存也是，但庫存可以想一下要放到哪。」
//   02 選飼料「都不太滿意」；03 冷卻「B比較好，但是圖示可以改進一下。」；04 全部餵「先不要，我覺得讓用戶一頭一頭喂比較好玩」（不做）。
//   這一輪：01 丟飼料（兩個情況＋GIF）、02 飼料列 A／B／C、03 倉庫放哪 A／B／C、04 吃飽冷卻的圖示 A／B／C、R23-99 總覽。
// 元件、字串、假資料、牛的產生器都用 M2 設計稿（design/m2，含 PR 5 的集點卡和飼料圖示）。新的字是草稿，直接寫在這裡，沒有進字串表：
// 使用者選完才加 key、翻英文和泰文（D25）。網址：r23.html?b=R23-02-A；?list=1 列出全部說明圖；GIF：r23.html?gif=G1。
import { applyDevice, frame, btn, icon, fmt, badge, cowSVG, cowFace, useChip, sexText, sheet, toast, fitTitles, fitOriginTags, placeVersion, fitSwipeHint, fitMiniLines, placeCowPop, fitGrade, fitActions, BREEDS } from '../../../m2/src/js/kit.js';
import { loadLang, t, dur, calfName } from '../../../m2/src/js/i18n.js';
import { COWS, CALF_DEMO, cowName } from '../../../m2/src/js/fixtures.js';
import { ranchScene, HERD } from '../../../m2/src/js/scene.js';
import { FEED_KEYS } from '../../../m2/src/js/feeds.js';
import { stampCard, wantBubble } from '../../../m2/src/js/stamps.js';
import { poopG } from '../../../m2/src/js/poop.js';

const L = '#4B3326';
const f2 = (v) => Math.round(v * 100) / 100;
// 字串表在 design/m2/i18n：loadLang 抓 ../i18n/…（相對於頁面），轉到 m2 的資料夾
const realFetch = window.fetch.bind(window);
window.fetch = (u, o) => realFetch(typeof u === 'string' && u.startsWith('../i18n/') ? `../../../m2/${u.slice(3)}` : u, o);
const q = new URLSearchParams(location.search);
const W = +(q.get('w') || 390);
const dev = applyDevice(W);
const app = document.getElementById('app');
await loadLang('zh-Hant');
const { popHtml, ranchPage } = await import('../../../m2/src/js/screens/s03.js');
const { STATES } = await import('../../../m2/src/js/states.js');
const { detailPage } = await import('../../../m2/src/js/screens/s04.js');
const ctx0 = () => ({ dev, w: dev.w, q: new URLSearchParams() });

// ---------- 說明圖的版面（跟第 18 輪一樣） ----------
const PAD = 36, GAP = 40;
function board({ id, title, sub = '', top = '', cells = [], cols = cells.length, notes = [], width, body = '' }) {
  const wpx = width || PAD * 2 + cols * dev.w + (cols - 1) * GAP;
  const html = `<div class="board" style="width:${wpx}px">
    <div class="b-label">${id}</div>
    <div class="b-title">${title}</div>${sub ? `<div class="b-sub">${sub}</div>` : ''}
    ${top}
    ${cells.length ? `<div class="b-row" style="grid-template-columns:repeat(${cols}, ${dev.w}px)">${cells.map((c) => `<figure class="b-cell"><figcaption><b>${c.cap}</b>${c.note || ''}</figcaption>${c.html}</figure>`).join('')}</div>` : ''}
    ${body}
    ${notes.length ? `<ul class="b-notes">${notes.map((n) => `<li>${n}</li>`).join('')}</ul>` : ''}
  </div>`;
  return { html };
}
const boardWidth = (cols) => PAD * 2 + cols * dev.w + (cols - 1) * GAP;
const POINTER = (s = 34) => `<svg viewBox="0 0 32 34" width="${s}" height="${Math.round(s * 34 / 32)}" aria-hidden="true"><path d="M11 4.4a2.3 2.3 0 0 1 4.6 0v9.8l1.2-.3a2.1 2.1 0 0 1 2.6 1.5l.1.5 1.1-.2a2.1 2.1 0 0 1 2.5 1.6l.1.5h.8a2.1 2.1 0 0 1 2.2 2.1v4.6c0 4.8-3.3 8.1-7.9 8.1h-1.5c-2.7 0-4.6-1.1-6.2-3.4l-4.8-6.7a2.1 2.1 0 0 1 3.1-2.8l2.1 2.3z" fill="#FFE3D2" stroke="${L}" stroke-width="2" stroke-linejoin="round"/><path d="M15.6 14.2v3.6M19.5 15.4v2.8M23.2 17.1v2" stroke="${L}" stroke-width="1.6" stroke-linecap="round"/></svg>`;
const finger = (x, y, s = 40) => `<div class="gesture" style="left:${f2(x - 13 * s / 32)}px;top:${f2(y - 2)}px">${POINTER(s)}</div>`;

// ---------- 飼料（v0.3 第 2.1 節；數字是起點） ----------
const KG = { grass: 1, hay: 1.5, oats: 2, alfalfa: 3, corn: 5, soy: 8 };
const STOCK = { grass: 24, hay: 12, oats: 8, alfalfa: 0, corn: 5, soy: 3 };
const fName = (k) => t(`feed.${k}`);
const fic = (k, s = 22) => icon(`feed_${k}`, s);
const kgText = (k) => `+${KG[k]} 公斤`;

// ---------- 假資料：牧場上的牛 ----------
const calf = { ...CALF_DEMO[15] }; // 小牛（黑白花），要吃燕麥、豆粕，吃過燕麥
const calfFull = { ...calf, ate: ['oats', 'soy'] };
const cow12 = COWS.find((c) => c.id === 12); // 草莓牛（乳牛，成年）
const anchors = ranchScene(dev, HERD, { wide: true }).anchors;
const front = (ids) => HERD.map((h) => (ids.includes(h.id) ? { ...h, pose: 'front' } : h));
const ranch = (o = {}) => ranchPage(ctx0(), o);
const calfTitle = calfName('dairy', 15);

// 名片：多一顆「餵食」（01-A）；cool：吃飽了的倒數；row：名片上的一排飼料（02-B）
function popFeed(c, { cool = '', row = false, picked = '', stockOf = STOCK, note = '' } = {}) {
  const base = popHtml(c);
  const head = base.slice(0, base.lastIndexOf('<button'));
  const coolLine = cool ? `<p class="cool-line">${icon('clock', 14)}<span>${cool}</span></p>` : '';
  if (row) {
    const need = c.need || [];
    const cells = FEED_KEYS.map((k) => {
      const n = stockOf[k], wants = need.includes(k) && !(c.ate || []).includes(k);
      return `<button class="pf-cell${n ? '' : ' empty'}${wants ? ' pf-want' : ''}${k === picked ? ' picked' : ''}" aria-label="${fName(k)}">${fic(k, 24)}<span class="num">${n}</span>${wants ? '<i class="pf-tag">要吃</i>' : ''}</button>`;
    }).join('');
    return `${head}${note ? `<p class="pf-note">${note}</p>` : ''}<div class="pf-row">${cells}</div>${btn(t('s03.popDetail'), { small: true, block: true })}`;
  }
  return `${head}${coolLine}<div class="pop-btns">${btn(cool ? '吃飽了' : '餵食', { small: true, kind: 'green', ic: cool ? 'clock' : 'feed_oats', disabled: !!cool })}${btn('看詳細', { small: true, kind: 'primary' })}</div>`;
}

// 選飼料的底部面板（02-A）
function feedSheet(c, { picked = 'soy', stockOf = STOCK } = {}) {
  const need = c.need || [], ate = c.ate || [];
  const cells = FEED_KEYS.map((k) => {
    const n = stockOf[k], wants = need.includes(k) && !ate.includes(k), done = need.includes(k) && ate.includes(k);
    const tag = wants ? '<i class="fs-tag fs-want">要吃</i>' : done ? `<i class="fs-tag fs-done">${icon('ok', 12)}吃過</i>` : '';
    return `<button class="fs-cell${n ? '' : ' empty'}${k === picked ? ' picked' : ''}">${tag}<span class="fs-ic">${fic(k, 34)}</span><b>${fName(k)}</b><span class="fs-kg">${kgText(k)}</span>
      <span class="fs-n">${n ? `倉庫 <b class="num">${n}</b> 份` : '<span class="fs-buy">沒有了・去市場買</span>'}</span>${k === picked ? `<span class="pick-check">${icon('ok', 20)}</span>` : ''}</button>`;
  }).join('');
  const who = c.age === 'calf' ? calfTitle : cowName(c);
  const sub = c.age === 'calf' ? `<p class="fs-sub">這頭小牛要吃：${need.map((k) => `<span class="fs-need${ate.includes(k) ? ' done' : ''}">${fic(k, 18)}${fName(k)}${ate.includes(k) ? icon('ok', 12) : ''}</span>`).join('')}</p>` : `<p class="fs-sub">越貴的飼料越會長肉；長到最壯以前吃的才算。</p>`;
  return sheet({ cls: 'feed-sheet', title: `餵${who}`, body: `${sub}<div class="fs-grid">${cells}</div>
    <div class="btn-row">${btn(t('cancel'))}${btn(`餵一份${fName(picked)}`, { kind: 'green', ic: `feed_${picked}` })}</div>` });
}
const emptySheet = (c) => sheet({ cls: 'feed-sheet', title: `餵${c.age === 'calf' ? calfTitle : cowName(c)}`, body: `<div class="fs-empty">${fic('grass', 44)}<b>倉庫裡沒有飼料</b><p class="hint">飼料在市場的「飼料」分頁買，買來的放倉庫。</p></div>
  <div class="btn-row">${btn(t('cancel'))}${btn('去市場買飼料', { kind: 'primary', ic: 'coins' })}</div>` });

// 吃的時候：飼料飛進嘴裡、「+8 公斤」、蓋章
const flyArc = (x0, y0, x1, y1) => `<svg class="fly-arc" width="${dev.w}" height="${dev.h}" viewBox="0 0 ${dev.w} ${dev.h}"><path d="M${x0} ${y0}Q${(x0 + x1) / 2} ${Math.min(y0, y1) - 120} ${x1} ${y1}" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-dasharray="2 10" stroke-linecap="round"/></svg>`;
const flyIcon = (k, x, y, s = 30) => `<span class="fly-ic" style="left:${f2(x - s / 2 - 6)}px;top:${f2(y - s / 2 - 6)}px">${fic(k, s)}</span>`;
const kgPop = (x, y, txt) => `<span class="kg-pop" style="left:${x}px;top:${y}px">${txt}</span>`; // (x, y)：頭頂；泡泡置中在頭頂上面
const kgOn = (id, txt) => kgPop(head(id)[0], head(id)[1] - 6, txt);
const stampPop = (x, y, k) => `<span class="stamp-pop" style="left:${x}px;top:${y}px">${fic(k, 20)}<b>吃過</b></span>`;
const chew = (x, y) => `<span class="chew" style="left:${x}px;top:${y}px">嚼嚼</span>`;

// 冷卻的小碗（03-B）：頭上一個小碗，外圈是還要等多久
const bowl = (x, y, k = 0.6) => {
  const r = 15, c = 2 * Math.PI * r;
  return `<span class="bowl" style="left:${f2(x - 19)}px;top:${f2(y - 46)}px"><svg viewBox="0 0 38 38" width="38" height="38"><circle cx="19" cy="19" r="17" fill="#FFFFFF" stroke="${L}" stroke-width="2"/><circle cx="19" cy="19" r="${r}" fill="none" stroke="#E7DED2" stroke-width="3"/><circle cx="19" cy="19" r="${r}" fill="none" stroke="#7CC86A" stroke-width="3" stroke-dasharray="${f2(c * k)} ${f2(c)}" transform="rotate(-90 19 19)" stroke-linecap="round"/>
    <path d="M10.5 18.5h17c0 5-3.8 8.5-8.5 8.5s-8.5-3.5-8.5-8.5z" fill="#F2C489" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/><path d="M14 18.2c1-2.2 2.6-3.4 5-3.4s4 1.2 5 3.4" fill="#8CD46F" stroke="${L}" stroke-width="1.4"/></svg></span>`;
};

// 全部餵一樣的（04）
const FEEDABLE = [
  { id: 15, calf: true, look: { breed: CALF_DEMO[15].breed, age: 'calf', sex: 'cow', seed: 31 } },
  { id: 21, calf: true, look: { breed: 'yellow', age: 'calf', sex: 'bull' } },
  { id: 3, look: { breed: 'holstein' } },
  { id: 7, look: { breed: 'jersey' } },
  { id: 11, look: { breed: 'wagyu' } },
  { id: 12, look: { breed: 'strawberry' } },
];
function feedAllSheet(picked = 'oats', n = STOCK[picked]) {
  const chips = FEED_KEYS.map((k) => `<button class="fa-chip${k === picked ? ' picked' : ''}${STOCK[k] ? '' : ' empty'}">${fic(k, 24)}<span>${fName(k)}</span><span class="num">${STOCK[k]}</span></button>`).join('');
  const eat = Math.min(n, FEEDABLE.length);
  const faces = FEEDABLE.map((c, i) => `<span class="fa-face${i < eat ? ' on' : ''}"><span class="av-circle">${cowFace(c.look, 38)}</span>${i < eat ? `<i class="fa-ok">${icon('ok', 12)}</i>` : ''}${c.calf ? '<i class="fa-calf">小牛</i>' : ''}</span>`).join('');
  return sheet({ cls: 'feed-all', title: '全部餵一樣的', body: `<p class="fs-sub">選一種飼料，餵所有現在能吃的牛。</p><div class="fa-chips">${chips}</div>
    <div class="fa-sum card"><div class="fa-line"><span>現在能吃</span><b class="num">${FEEDABLE.length} 頭</b><span class="hint">（小牛 2、成牛 4；吃飽了、過了最壯的不算）</span></div>
      <div class="fa-line"><span>你有</span><b class="num">${STOCK[picked]} 份${fName(picked)}</b></div>
      ${n < FEEDABLE.length ? `<p class="warn-text fa-warn">${icon('warn', 16)}<span>份數不夠：先餵小牛，再照編號，餵 ${eat} 頭</span></p>` : ''}
      <div class="fa-faces">${faces}</div></div>
    <div class="btn-row">${btn(t('cancel'))}${btn(`餵 ${eat} 頭（用掉 ${eat} 份）`, { kind: 'green', ic: `feed_${picked}` })}</div>` });
}
const feedAllPill = '<button class="feed-all-pill">' + icon('feed_oats', 18) + '<span>全部餵</span></button>';
const withDockPill = (html) => html.replace('<div class="dock-head">', `<div class="dock-head">${feedAllPill}`);
const roundFeedBtn = `<button class="feed-all-fab" aria-label="全部餵一樣的">${icon('feed_oats', 28)}<span>全部餵</span></button>`;

// 01-B：牧場下面一排飼料（拖到牛身上）
const tray = (o = {}) => `<div class="feed-tray">${FEED_KEYS.map((k) => `<span class="ft-cell${STOCK[k] ? '' : ' empty'}${k === o.drag ? ' lifted' : ''}">${fic(k, 26)}<span class="num">${k === o.used ? STOCK[k] - 1 : STOCK[k]}</span></span>`).join('')}<span class="ft-close">${icon('close', 14)}</span></div>`;
const trayBtn = '<button class="tray-btn">' + icon('feed_oats', 20) + '<span>飼料</span></button>';

const A = (id) => anchors[id];
const toastOk = (s) => toast('ok', s);


// ================= 第 23 輪 =================
const head = (id, an = anchors) => an[id].head;
// 這一輪的牧場：小牛放到右下角，中間空出來好丟飼料
const HERD23 = HERD.map((h) => (h.id === 15 ? { ...h, x: 296, y: 486, facing: 'left', depth: 1 } : h)).filter((h) => h.id !== 11);
const COWNAME = { 3: '荷斯坦 #3', 7: '娟珊 #7', 12: '草莓牛 #12', 15: '小乳牛 #15' };
// 牧場頁：拿掉「倉庫」「收購價」兩張小卡（使用者：「下面那個市場資訊拿掉，庫存也是」），放進飼料列；extra 畫在場景裡（場景座標）
function ranch23({ herd = HERD23, extra = '', bar = feedBarA(), overlays = '', hudBtn = false, dockPill = '', tab = false, center = '', pop = null } = {}) {
  let html = ranchPage(ctx0(), { herd, overlays, center, pop });
  html = html.replace(/(<div class="scene">[\s\S]*?)(<\/svg>\s*<\/div>)/, (m, a, b) => a + extra + b);
  html = html.replace(/<div class="dock-row">[\s\S]*?<\/article>\s*<\/div>\s*<\/section>/, `${bar}</section>`);
  if (dockPill) html = html.replace('<div class="dock-head">', `<div class="dock-head">${dockPill}`);
  if (hudBtn) html = html.replace('<header class="hud">', '<header class="hud wh">').replace(/<button class="gear/, `<button class="gear wh-btn" aria-label="倉庫">${icon('barn', 22)}</button><button class="gear`);
  if (tab) html = html.replace(/(<nav class="tabbar">[\s\S]*?<\/button>)/, `$1<button class="tab"><span class="tab-icon">${icon('barn', 26)}</span><span class="tab-label">倉庫</span></button>`);
  return html;
}
const sceneOf = (herd) => ranchScene(dev, herd, { wide: true });

// ---------- 02 飼料列：三種樣子（每種都看得到剩幾份、會長幾公斤；小牛想吃的那種有提示） ----------
// o.lift：正在拖的那種（那格浮起來）；o.want：小牛想吃的那種；o.back：飛回來的那種（數字 +1）
function feedBarA(o = {}) {
  return `<div class="fbar fbar-a">${FEED_KEYS.map((k) => {
    const n = STOCK[k] + (o.used === k ? -1 : 0);
    return `<button class="fa-slot${n ? '' : ' none23'}${k === o.lift ? ' lift' : ''}${k === o.want ? ' want23' : ''}${k === o.back ? ' back' : ''}"><span class="fa-ring">${fic(k, 28)}</span><b class="num fa-n">${n}</b><span class="fa-kg">+${KG[k]}kg</span>${k === o.want ? '<i class="want-tag">小牛想吃</i>' : ''}</button>`;
  }).join('')}</div>`;
}
const sack = (k, n, cls = '') => `<span class="sack ${cls}"><svg viewBox="0 0 54 58" width="54" height="58" aria-hidden="true"><path d="M12 12Q27 6 42 12L46 18Q51 34 47 50Q27 57 7 50Q3 34 8 18Z" fill="${n ? '#E9D3A6' : '#E5DED2'}" stroke="${L}" stroke-width="2.2" stroke-linejoin="round"/><path d="M12 12Q18 4 27 9Q36 4 42 12" fill="none" stroke="${L}" stroke-width="2"/><path d="M14 17Q27 21 40 17" stroke="#C99A34" stroke-width="2.4" fill="none"/></svg><span class="sk-ic">${fic(k, 24)}</span><b class="num sk-n">${n}</b></span>`;
function feedBarB(o = {}) {
  return `<div class="fbar fbar-b"><div class="fb-track">${FEED_KEYS.map((k) => {
    const n = STOCK[k] + (o.used === k ? -1 : 0);
    return `<button class="fb-item${n ? '' : ' none23'}${k === o.lift ? ' lift' : ''}${k === o.want ? ' want23' : ''}">${sack(k, n)}<span class="fb-name">${fName(k)}<b>+${KG[k]}kg</b></span>${k === o.want ? '<i class="want-tag">小牛想吃</i>' : ''}</button>`;
  }).join('')}</div><span class="fb-more">${icon('chevron', 16)}</span></div>`;
}
const bin = (k, n) => `<svg viewBox="0 0 44 40" width="44" height="40" aria-hidden="true"><path d="M5 12H39L35 37H9Z" fill="${n ? '#C98E5E' : '#D9CFC3'}" stroke="${L}" stroke-width="2.2" stroke-linejoin="round"/><path d="M8 19H36M9 27H35" stroke="#A86F43" stroke-width="1.6"/><rect x="3" y="8" width="38" height="6" rx="3" fill="${n ? '#8C6A4A' : '#BDB3A6'}" stroke="${L}" stroke-width="2"/></svg>`;
function feedBinsC(o = {}) { // 牧場右邊一排飼料桶（在場景上面，面板裡只剩奶桶）
  return `<div class="fbins">${FEED_KEYS.map((k) => {
    const n = STOCK[k] + (o.used === k ? -1 : 0);
    return `<button class="fc-bin${n ? '' : ' none23'}${k === o.lift ? ' lift' : ''}${k === o.want ? ' want23' : ''}"><span class="fc-feed">${fic(k, 22)}</span>${bin(k, n)}<b class="num fc-n">${n}</b><span class="fc-kg">+${KG[k]}</span></button>`;
  }).join('')}<span class="fc-unit">公斤</span></div>`;
}
const BARS = {
  A: { name: '道具欄的圓格子', file: '道具欄圓格子', fn: feedBarA, intro: '面板下面一排圓格子，像遊戲的道具欄：圖示、剩幾份（粗字）、會長幾公斤。', fun: '六種一次看完，最好找；按住一格拖出去就能丟。' },
  B: { name: '左右滑的一排袋子', file: '左右滑的袋子', fn: feedBarB, intro: '一排小飼料袋，左右滑看其他的；袋子上寫剩幾份，下面寫名字和會長幾公斤。', fun: '比較有農場味；之後飼料變多也放得下（往右滑）。' },
  C: { name: '牧場右邊的飼料桶', file: '邊上的飼料桶', fn: feedBinsC, intro: '飼料桶直直一排放在牧場右邊，從桶子裡拿一份拖到地上。', fun: '面板最小，牧場看得最多；桶子就在草地旁邊，丟起來最順手。' },
};
const barFor = (v, o = {}) => (v === 'C' ? { bar: '', center: feedBinsC(o) } : { bar: BARS[v].fn(o), center: '' });

// ---------- 01 丟飼料 ----------
// 地上的一份飼料（場景座標）：圖示＋影子；blink 閃一下（0–1）
const feedOnGround = (k, x, y, { s = 1, blink = 0 } = {}) => `<g opacity="${f2(1 - blink * 0.7)}"><ellipse cx="${f2(x)}" cy="${f2(y + 2)}" rx="${f2(13 * s)}" ry="${f2(4 * s)}" fill="#3E6B2A" opacity="0.22"/>${fic(k, Math.round(30 * s)).replace('<svg ', `<svg x="${f2(x - 15 * s)}" y="${f2(y - 28 * s)}" `)}</g>`;
const dropRing = (x, y, k = 1) => `<ellipse cx="${f2(x)}" cy="${f2(y + 2)}" rx="${f2(22 + 10 * k)}" ry="${f2(8 + 4 * k)}" fill="none" stroke="#FFFFFF" stroke-width="3" opacity="${f2(1 - k * 0.7)}"/>`;
const distLine = (x0, y0, x1, y1, label, near) => `<path d="M${f2(x0)} ${f2(y0)}L${f2(x1)} ${f2(y1)}" stroke="${near ? '#3E8E2F' : '#FFFFFF'}" stroke-width="2.6" stroke-dasharray="5 6" stroke-linecap="round"/><g transform="translate(${f2((x0 + x1) / 2)} ${f2((y0 + y1) / 2 - 4)})"><rect x="-16" y="-11" width="32" height="18" rx="9" fill="${near ? '#3E8E2F' : '#FFFFFF'}" stroke="${L}" stroke-width="1.4"/><text x="0" y="3" text-anchor="middle" font-size="11" font-weight="900" fill="${near ? '#FFFFFF' : L}">${label}</text></g>`;
const D1 = [190, 470], D2 = [210, 470];
// 牛走到飼料旁邊：牛腳的位置（嘴巴大約在飼料上面）
const eatPos = (cow, [dx, dy]) => { const right = dx > cow.x; return { x: dx + (right ? -46 : 46), y: dy + 6, facing: right ? 'right' : 'left' }; };
const herdWith = (id, pos) => HERD23.map((h) => (h.id === id ? { ...h, ...pos } : h));
const pill23 = (s, cls = '') => `<div class="g-pill23 ${cls}">${s}</div>`;

// ---------- 04 吃飽冷卻：頭上的圖示（三種）。k：還要等多久（1＝剛吃完、0＝可以吃了） ----------
const ring = (k, r = 15, c = 19) => { const C = 2 * Math.PI * r; return `<circle cx="${c}" cy="${c}" r="${r}" fill="none" stroke="#E7DED2" stroke-width="3.2"/><circle cx="${c}" cy="${c}" r="${r}" fill="none" stroke="#7CC86A" stroke-width="3.2" stroke-dasharray="${f2(C * k)} ${f2(C)}" transform="rotate(-90 ${c} ${c})" stroke-linecap="round"/>`; };
const COOL = {
  A: { name: '空碗加倒數圈', file: '空碗倒數圈', intro: '一個吃空的碗，外圈的綠色是還要等多久，繞完就能再吃。',
    svg: (k) => `<svg viewBox="0 0 38 38" width="38" height="38"><circle cx="19" cy="19" r="17.5" fill="#FFFFFF" stroke="${L}" stroke-width="2"/>${ring(k)}<path d="M10 17.5h18c0 5.4-4 9.2-9 9.2s-9-3.8-9-9.2z" fill="#F2C489" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/><ellipse cx="19" cy="17.5" rx="9" ry="2.4" fill="#C98E5E" stroke="${L}" stroke-width="1.4"/><path d="M14 13.6l1-2M19 12.6v-2.2M24 13.6l-1-2" stroke="#A8C890" stroke-width="1.4" stroke-linecap="round"/></svg>` },
  B: { name: '滿足的表情氣泡', file: '滿足表情氣泡', intro: '一個說話泡泡，裡面是吃飽、瞇著眼的笑臉；下面一條小進度條是還要等多久。',
    svg: (k) => `<svg viewBox="0 0 44 44" width="40" height="40"><path d="M6 4h32a5 5 0 0 1 5 5v18a5 5 0 0 1-5 5H26l-4 6-4-6H6a5 5 0 0 1-5-5V9a5 5 0 0 1 5-5z" fill="#FFFFFF" stroke="${L}" stroke-width="2" stroke-linejoin="round"/>
      <circle cx="22" cy="17" r="9.5" fill="#FFE3D2" stroke="${L}" stroke-width="1.6"/><path d="M16.5 15.6q2-2 4 0M23.5 15.6q2-2 4 0" fill="none" stroke="${L}" stroke-width="1.6" stroke-linecap="round"/><path d="M18.5 20q3.5 3 7 0" fill="none" stroke="${L}" stroke-width="1.6" stroke-linecap="round"/><circle cx="16" cy="20" r="1.6" fill="#FF9C9C" opacity="0.8"/><circle cx="28" cy="20" r="1.6" fill="#FF9C9C" opacity="0.8"/>
      <rect x="9" y="27.5" width="26" height="3" rx="1.5" fill="#E7DED2"/><rect x="9" y="27.5" width="${f2(26 * k)}" height="3" rx="1.5" fill="#7CC86A"/></svg>` },
  C: { name: '飼料袋加時鐘', file: '飼料袋加時鐘', intro: '一個小飼料袋，右下角一個小時鐘；時鐘的綠色扇形是還要等多久。',
    svg: (k) => { const a = 2 * Math.PI * k, x = 29 + 8 * Math.sin(a), y = 29 - 8 * Math.cos(a); return `<svg viewBox="0 0 40 40" width="38" height="38"><path d="M9 11Q19 6 29 11L31 15Q35 25 31 33Q19 38 7 33Q3 25 7 15Z" fill="#E9D3A6" stroke="${L}" stroke-width="2" stroke-linejoin="round"/><path d="M9 11Q14 5 19 9Q24 5 29 11" fill="none" stroke="${L}" stroke-width="1.8"/>${fic('oats', 16).replace('<svg ', '<svg x="11" y="15" ')}
      <circle cx="29" cy="29" r="9" fill="#FFFFFF" stroke="${L}" stroke-width="1.8"/>${k > 0.01 ? `<path d="M29 29V21A8 8 0 ${k > 0.5 ? 1 : 0} 1 ${f2(x)} ${f2(y)}Z" fill="#7CC86A"/>` : ''}<path d="M29 29V23.4M29 29l3 2" stroke="${L}" stroke-width="1.5" stroke-linecap="round"/></svg>`; } },
};
const coolIcon = (v, [x, y], k = 0.7) => `<span class="cool23" style="left:${f2(x)}px;top:${f2(y - 4)}px">${COOL[v].svg(k)}</span>`;
const oldTag = ([x, y]) => `<span class="old23" style="left:${f2(x)}px;top:${f2(y - 4)}px">長到最壯了</span>`;
const dots = ([x, y]) => `<span class="dots23" style="left:${f2(x)}px;top:${f2(y - 4)}px">…</span>`;

// ---------- 01 丟飼料的分鏡和 GIF ----------
// 飼料列 A 的豆粕那一格（手機座標）：拖出去、飛回來都從這裡
const SLOT = [347, 726];
const dragIcon = (x, y) => `<span class="drag23" style="left:${f2(x - 21)}px;top:${f2(y - 21)}px">${fic('soy', 30)}</span>`;
function throwScene(t, which) {
  const F = sceneOf(HERD23).fit;
  const D = which === 1 ? D1 : D2, Dp = F.map(D);
  let herd = HERD23, extra = '', ov = '', fin = '', bar = { lift: '', used: '' };
  const coolIds = which === 1 ? [] : [12, 7, 15];
  // 拖：0–1.3 秒從飼料格拖到落點
  if (t < 0.5) { bar.lift = 'soy'; fin = finger(SLOT[0] + 4, SLOT[1] - 6); }
  else if (t < 1.3) { const u = (t - 0.5) / 0.8, e = u * u * (3 - 2 * u); const x = lerp(SLOT[0], Dp[0], e), y = lerp(SLOT[1], Dp[1] - 10, e) - Math.sin(e * Math.PI) * 60; bar.lift = 'soy'; bar.used = 'soy'; ov += dragIcon(x, y); fin = finger(x + 6, y + 14); }
  else bar.used = 'soy';
  if (which === 1) {
    const cow = HERD23.find((h) => h.id === 12), E = eatPos(cow, D);
    const walk = clamp01((t - 2.3) / 1.3), we = walk * walk * (3 - 2 * walk);
    if (t >= 2.3) herd = herdWith(12, { x: lerp(cow.x, E.x, we), y: lerp(cow.y, E.y, we), facing: E.facing });
    const eat = clamp01((t - 3.6) / 0.8);
    if (t >= 1.3 && eat < 1) extra += feedOnGround('soy', D[0], D[1], { s: 1 - eat * 0.9 }) + (t < 1.7 ? dropRing(D[0], D[1], (t - 1.3) / 0.4) : '');
    if (t >= 1.6 && t < 3.0) { const c12 = HERD23.find((h) => h.id === 12), c7 = HERD23.find((h) => h.id === 7); extra += distLine(D[0], D[1], c12.x + 30, c12.y - 30, '近', true) + distLine(D[0], D[1], c7.x - 30, c7.y - 30, '遠', false); }
    const an = sceneOf(herd).anchors;
    if (t >= 3.6 && t < 4.4) ov += chew(an[12].head[0] + 26, an[12].head[1] + 18);
    if (t >= 4.1 && t < 5.4) ov += kgPop(an[12].head[0] + 52, an[12].head[1] - 4 - (t - 4.1) * 14, '+8 公斤');
    if (t >= 4.6) ov += coolIcon('A', an[12].head, 1);
  } else {
    const an = sceneOf(herd).anchors;
    ov += coolIds.map((id) => coolIcon('A', an[id].head, id === 12 ? 0.4 : id === 7 ? 0.8 : 0.6)).join('') + oldTag(an[3].head);
    const back = clamp01((t - 3.6) / 0.8);
    if (t >= 1.3 && t < 3.6) { const blink = t >= 2.6 ? (Math.sin((t - 2.6) * Math.PI * 6) > 0 ? 1 : 0) : 0; extra += feedOnGround('soy', D[0], D[1], { blink }) + (t < 1.7 ? dropRing(D[0], D[1], (t - 1.3) / 0.4) : ''); }
    if (t >= 1.6 && t < 3.6) ov += [12, 7, 15].map((id) => dots(an[id].head)).join('');
    if (t >= 1.8 && t < 3.6) ov += pill23('附近沒有能吃的牛：吃飽了、或長到最壯了');
    if (t >= 3.6 && t < 4.4) { const e = back * back * (3 - 2 * back); const x = lerp(Dp[0], SLOT[0], e), y = lerp(Dp[1] - 10, SLOT[1], e) - Math.sin(e * Math.PI) * 80; ov += dragIcon(x, y); }
    if (t >= 4.4) { bar.used = ''; bar.back = 'soy'; }
    if (t >= 4.4 && t < 6) ov += pill23('飼料放回去了，不會浪費', 'ok');
  }
  return ranch23({ herd, extra, bar: feedBarA(bar), overlays: ov + fin });
}
function throwCells(which) {
  if (which === 1) {
    // 另外兩格：最近的那頭吃飽了換下一頭；小牛要吃的丟在小牛旁邊
    const an0 = sceneOf(HERD23).anchors, c7 = HERD23.find((h) => h.id === 7), E7 = eatPos(c7, D1);
    const skip = ranch23({ herd: herdWith(7, { x: lerp(c7.x, E7.x, 0.55), y: lerp(c7.y, E7.y, 0.55), facing: E7.facing }), extra: feedOnGround('soy', ...D1) + distLine(D1[0], D1[1], 150, 494, '吃飽', false), bar: feedBarA({ used: 'soy' }), overlays: coolIcon('A', an0[12].head, 0.6) });
    const cf = HERD23.find((h) => h.id === 15), DC = [cf.x - 52, cf.y - 4];
    const calfScene = ranch23({ extra: feedOnGround('soy', ...DC), bar: feedBarA({ used: 'soy', want: 'soy' }), overlays: wantBubble(calf, an0[15]) + finger(sceneOf(HERD23).fit.map(DC)[0] + 4, sceneOf(HERD23).fit.map(DC)[1] - 4) });
    return [
      { cap: '1 按住一種飼料', note: '從面板下面的飼料列按住（這裡是豆粕，剩 3 份）', html: throwScene(0.3, 1) },
      { cap: '2 拖到牧場地上放開', note: '飼料掉在草地上，落點有一圈', html: throwScene(1.45, 1) },
      { cap: '3 最近、能吃的那頭走過來', note: '兩頭牛中間：比較近的那頭（草莓牛）走過來', html: throwScene(2.75, 1) },
      { cap: '4 吃掉：+8 公斤', note: '頭上出現吃飽的圖示（樣子見 04）', html: throwScene(4.9, 1) },
      { cap: '5 最近的吃飽了，換下一頭', note: '吃飽冷卻中、過了最壯的牛不會過來，換下一頭最近的', html: skip },
      { cap: '6 小牛要吃指定的飼料', note: '丟在那頭小牛旁邊，牠就過來吃；飼料列那一格有「小牛想吃」', html: calfScene },
    ];
  }
  return [
    { cap: '1 附近的牛都不能吃', note: '頭上有吃飽圖示的在冷卻；「長到最壯了」的不會再吃', html: throwScene(0.3, 2) },
    { cap: '2 丟下去：沒有牛過來', note: '牛頭上「…」，沒有一頭走過來', html: throwScene(2.0, 2) },
    { cap: '3 飼料閃一下', note: '停幾秒、閃幾下', html: throwScene(3.0, 2) },
    { cap: '4 飛回飼料列', note: '份數加回去（3 份），不會浪費', html: throwScene(4.8, 2) },
  ];
}
const SUB23 = '使用者看完第 19 輪：入口「B比較好，但我希望把飼料丟地上，最靠近的牛會走過來吃。然後我覺得下面那個市場資訊拿掉，庫存也是，但庫存可以想一下要放到哪。」；選飼料「都不太滿意」；冷卻「B比較好，但是圖示可以改進一下」；全部餵「先不要」。';

// ---------- 03 倉庫放哪 ----------
const WH = {
  A: { name: '頂列加一顆倉庫鈕', file: '頂列倉庫鈕', o: { hudBtn: true }, spot: () => [302, 74], intro: '頂列齒輪左邊多一顆倉庫鈕，每一頁都按得到。' },
  B: { name: '面板上面的倉庫小鈕', file: '面板倉庫小鈕', o: { dockPill: `<button class="wh-pill">${icon('barn', 18)}<span>倉庫</span></button>` }, spot: () => [52, 556], intro: '牧場面板左上角一顆「倉庫」，跟「收起」同一排，在奶桶旁邊。' },
  C: { name: '底部分頁加「倉庫」', file: '底部分頁', o: { tab: true }, spot: () => [86, 790], intro: '底部分頁多一個「倉庫」（七個分頁），隨時切過去。' },
};
function whCells(v) {
  const W0 = WH[v], s05 = STATES.find((x) => x.id === 'S05-02');
  return [
    { cap: '原本（核准的 S03-01）', note: '下面有「倉庫」「收購價」兩張小卡', html: ranchPage(ctx0()) },
    { cap: '改了：兩張小卡拿掉', note: `面板只剩奶桶和飼料列；${W0.intro}`, html: ranch23({ ...W0.o, overlays: finger(...W0.spot()) }) },
    { cap: '按了：打開倉庫（S05 那一頁）', note: '牛奶、牛肉、稻米、飼料都在這裡', html: s05.render(ctx0()) },
  ];
}

// ---------- 說明圖 ----------
const tbd = '飼料列的樣子見 02（這裡先用 A 畫）；吃飽的圖示見 04（這裡先用 A 畫）。';
const BOARDS = [
  { id: 'R23-01-1', render: () => board({ id: 'R23-01-丟飼料-1-丟在兩頭牛中間-390', title: '01 丟飼料　情況 1：丟在兩頭牛中間，比較近的那頭過來吃', sub: SUB23, cols: 3, width: boardWidth(3), cells: throwCells(1), notes: ['規則（ceo 先定，畫進分鏡）：離落點最近、而且現在能吃的牛走過去吃；吃飽冷卻中的、過了最壯的不會過來，換下一頭最近的。', tbd, '動起來的樣子：R23-01-丟飼料-1-丟在兩頭牛中間-390.gif'] }) },
  { id: 'R23-01-2', render: () => board({ id: 'R23-01-丟飼料-2-沒有牛能吃飛回去-390', title: '01 丟飼料　情況 2：附近沒有能吃的牛，飼料飛回去', sub: SUB23, cells: throwCells(2), notes: ['附近沒有能吃的牛時，飼料在地上停幾秒、閃一下，再飛回飼料列（倉庫），份數加回去，不會浪費。', tbd, '動起來的樣子：R23-01-丟飼料-2-沒有牛能吃飛回去-390.gif'] }) },
  ...Object.keys(BARS).map((v) => ({ id: `R23-02-${v}`, render: () => { const B = BARS[v], an0 = sceneOf(HERD23).anchors;
    const fr = (o, ov = '') => { const b = barFor(v, o); return ranch23({ bar: b.bar, center: b.center, overlays: ov }); };
    return board({ id: `R23-02-飼料列-${v}-${B.file}-390`, title: `02 飼料列　${v}：${B.name}`, sub: SUB23, cells: [
      { cap: '1 平常', note: B.intro, html: fr({}) },
      { cap: '2 按住一種', note: '那一格浮起來，拖出去就是丟飼料（見 01）', html: fr({ lift: 'corn' }) },
      { cap: '3 小牛想吃的那種', note: '小牛頭上冒「想吃」泡泡，飼料列那一種有「小牛想吃」', html: fr({ want: 'soy' }, wantBubble(calf, an0[15])) },
      { cap: '4 沒有了的那種', note: '灰掉（苜蓿 0 份）；按了帶去市場的「飼料」分頁買', html: fr({}, finger(v === 'C' ? 368 : v === 'B' ? 280 : 225, v === 'C' ? 452 : 718)) },
    ], notes: [B.fun, '每一格都看得到：剩幾份、會長幾公斤；小牛想吃的那種有提示。'] }); } })),
  ...Object.keys(WH).map((v) => ({ id: `R23-03-${v}`, render: () => board({ id: `R23-03-倉庫放哪-${v}-${WH[v].file}-390`, title: `03 倉庫放哪　${v}：${WH[v].name}`, sub: '使用者：「下面那個市場資訊拿掉，庫存也是，但庫存可以想一下要放到哪」。牧場頁下面的「倉庫」「收購價」兩張小卡拿掉（核准過的 S03 會變，這是使用者要的）；收購價在市場頁看得到。倉庫放哪裡給三個地方挑。', cells: whCells(v), notes: [WH[v].intro] }) })),
  ...Object.keys(COOL).map((v) => ({ id: `R23-04-${v}`, render: () => { const Cv = COOL[v], an0 = sceneOf(HERD23).anchors;
    const stage = (k, cap) => `<div class="cs-st"><span class="cs-big">${k > 0 ? Cv.svg(k).replace(/width="\d+" height="\d+"/, 'width="96" height="96"') : '<span class="cs-gone">（不見了）</span>'}</span><b>${cap}</b></div>`;
    const close = `<div class="cool-sheet">${stage(1, '剛吃完')}${stage(0.35, '快可以吃了')}${stage(0, '可以吃了')}</div>`;
    const pop = popHtml(cow12).replace(/<button[\s\S]*$/, '') + `<p class="cool-line">${icon('clock', 14)}<span>吃飽了，1:23 後可以再吃</span></p>${btn('看詳細', { small: true, block: true, kind: 'primary' })}`;
    return board({ id: `R23-04-吃飽冷卻-${v}-${Cv.file}-390`, title: `04 吃飽冷卻　${v}：${Cv.name}`, sub: SUB23, cells: [
      { cap: '1 剛吃過的牛，頭上的圖示', note: Cv.intro, html: ranch23({ overlays: coolIcon(v, an0[12].head, 0.85) + coolIcon(v, an0[3].head, 0.45) + coolIcon(v, an0[15].head, 0.2) }) },
      { cap: '2 圖示放大', note: '成牛 4 小時、小牛 45 分鐘（遊戲時間）；時間到了圖示不見', html: close },
      { cap: '3 點牛：名片寫倒數', note: '', html: ranch23({ herd: HERD23.map((h) => (h.id === 12 ? { ...h, pose: 'front' } : h)), pop: { id: 12, html: pop } }) },
    ], notes: ['照第 19 輪的 B（頭上的小碗），圖示重畫三種給使用者挑。'] }); } })),
  { id: 'R23-99', render: r2399 },
];
function r2399() {
  const S = 0.5, sw = Math.round(dev.w * S), sh = Math.round(dev.h * S);
  const mini = (html) => `<div class="ov-ph" style="width:${sw}px;height:${sh}px"><div style="transform:scale(${S});transform-origin:0 0">${html}</div></div>`;
  const cell = (cap, inner) => `<div class="ov-cell"><div class="ov-cap"><b>${cap}</b></div>${inner}</div>`;
  const row = (title, cells) => `<div class="ov-row"><div class="ov-title">${title}</div><div class="ov-cells">${cells.join('')}</div></div>`;
  const an0 = sceneOf(HERD23).anchors;
  const body = row('01 丟飼料', [cell('丟在兩頭牛中間：近的那頭過來', mini(throwScene(2.9, 1))), cell('吃掉、頭上出現吃飽的圖示', mini(throwScene(4.7, 1))), cell('沒有牛能吃：飛回飼料列', mini(throwScene(4.0, 2)))])
    + row('02 飼料列（選一種）', Object.keys(BARS).map((v) => { const b = barFor(v, { want: 'soy' }); return cell(`${v}　${BARS[v].name}`, mini(ranch23({ bar: b.bar, center: b.center, overlays: wantBubble(calf, an0[15]) }))); }))
    + row('03 倉庫放哪（選一種）', Object.keys(WH).map((v) => cell(`${v}　${WH[v].name}`, mini(ranch23({ ...WH[v].o, overlays: finger(...WH[v].spot()) })))))
    + row('04 吃飽的圖示（選一種）', Object.keys(COOL).map((v) => cell(`${v}　${COOL[v].name}`, `<div class="ov-cool">${[1, 0.5, 0.15].map((k) => COOL[v].svg(k).replace(/width="\d+" height="\d+"/, 'width="64" height="64"')).join('')}</div>` + mini(ranch23({ overlays: coolIcon(v, an0[12].head, 0.85) + coolIcon(v, an0[3].head, 0.45) })))));
  return { html: `<div class="board" style="width:${PAD * 2 + 3 * sw + 2 * 28 + 10}px"><div class="b-label">R23-99-總覽對照</div><div class="b-title">第 23 輪：丟飼料、飼料列、倉庫放哪、吃飽的圖示</div>
    <div class="b-sub">02、03、04 每一項選一種；01 是丟飼料的規則（兩個情況）。各自的分鏡見 R23-01～04；丟飼料動起來的樣子見 R23-01 的兩個 GIF。</div>${body}</div>` };
}
const GIFS = {
  G1: { fn: (t) => throwScene(t, 1), file: 'R23-01-丟飼料-1-丟在兩頭牛中間-390', total: 6 },
  G2: { fn: (t) => throwScene(t, 2), file: 'R23-01-丟飼料-2-沒有牛能吃飛回去-390', total: 6 },
};
const lerp = (a, b, k) => a + (b - a) * k;
const clamp01 = (v) => Math.max(0, Math.min(1, v));

async function settle() {
  await document.fonts.ready;
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
}
if (q.has('list')) {
  window.__boards = BOARDS.map(({ id }) => ({ id, w: 390 }));
  window.__ready = true;
} else if (q.has('gif')) {
  const g = GIFS[q.get('gif')];
  window.__frame = async (t) => { app.innerHTML = `<div class="gif-box"><div class="gif-label">${g.file}</div>${g.fn(t)}</div>`; await settle(); };
  window.__gif = { file: g.file, total: g.total };
  await window.__frame(0);
  window.__ready = true;
} else {
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
