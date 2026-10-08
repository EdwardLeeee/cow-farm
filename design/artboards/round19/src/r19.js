// 第 19 輪草稿（ceo 2026-10-08 交辦，選 A：先畫草稿給使用者挑）：餵食（v0.3 第 2.2 節）。
//   01 餵食的入口、02 選飼料、03 吃飽冷卻、04 全部餵一樣的、05 餵了以後的樣子；每項 2 種畫法（05 只有一種），另加總覽 R19-99。
// 元件、字串、假資料、牛的產生器都用 M2 設計稿（design/m2，含 PR 5 的集點卡和飼料圖示）。新的字是草稿，直接寫在這裡，沒有進字串表：
// 使用者選完才加 key、翻英文和泰文（D25）。網址：r19.html?b=R19-01-A；?list=1 列出全部說明圖。
import { applyDevice, frame, btn, icon, fmt, badge, cowSVG, cowFace, useChip, sexText, sheet, toast, fitTitles, fitOriginTags, placeVersion, fitSwipeHint, fitMiniLines, placeCowPop, fitGrade, fitActions, BREEDS } from '../../../m2/src/js/kit.js';
import { loadLang, t, dur, calfName } from '../../../m2/src/js/i18n.js';
import { COWS, CALF_DEMO, cowName } from '../../../m2/src/js/fixtures.js';
import { ranchScene, HERD } from '../../../m2/src/js/scene.js';
import { FEED_KEYS } from '../../../m2/src/js/feeds.js';
import { stampCard } from '../../../m2/src/js/stamps.js';

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

// ================= 說明圖 =================
const SUB = '使用者 2026-10-03 選「一頭一頭餵」，另外牧場面板有一顆「全部餵一樣的」給牛多的時候省事用（v0.3 第 2.2 節）。這一輪先給使用者挑樣子；飼料的數字（每次長幾公斤、價錢）是起點，模擬再調。';
const feedBtnRow = (label = '餵食', o = {}) => `${btn(label, { kind: 'green', ic: o.ic || 'feed_oats', block: true, disabled: !!o.disabled })}${o.sub ? `<p class="hint cool-sub">${icon('clock', 14)}${o.sub}</p>` : ''}<div class="btn-row" style="margin-top:12px">${btn(t('pickForBreed'), { kind: 'pink', ic: 'heart', disabled: !!o.calf })}${btn(o.calf ? t('shipNotAdult') : t('ship'), { kind: 'danger', ic: o.calf ? '' : 'truck', disabled: !!o.calf })}</div>`;
// 小牛的詳細比一個畫面長：往下捲到集點卡（草稿用：整段內容往上移 px）
const tallify = (html, px = 300) => html.replace('<main class="content', `<main style="--scroll:${px}px" class="content scrolled`);
const head = (id) => A(id).head;
const oldCow = { ...COWS.find((c) => c.id === 3), age: 'old' };

const V = {
  '01-A': { item: '01 餵食的入口', opt: 'A', name: '名片和詳細頁都有「餵食」', file: 'R19-01-餵食的入口-A-名片和詳細頁的按鈕-390',
    cells: () => [
      { cap: '點牛：名片多一顆「餵食」', note: '左邊「餵食」，右邊「看詳細」；按「餵食」跳出選飼料（02）', html: ranch({ herd: front([12]), pop: { id: 12, html: popFeed(cow12) } }) },
      { cap: '牛的詳細：第一排是「餵食」', note: '配種、出貨照舊放第二排', html: detailPage(ctx0(), cow12, { buttons: feedBtnRow() }) },
      { cap: '小牛的詳細：集點卡下面就能餵', note: '（往下捲到集點卡）還沒吃的飼料寫在按鈕上，按了直接選好那一種', html: tallify(detailPage(ctx0(), calf, { buttons: feedBtnRow('餵食（還沒吃：豆粕）', { ic: 'feed_soy', calf: true }) })) },
    ],
    fun: '一頭一頭餵最直接：點牛就看得到「餵食」。牛多的時候用 04 的「全部餵一樣的」。' },
  '01-B': { item: '01 餵食的入口', opt: 'B', name: '拖飼料到牛身上', file: 'R19-01-餵食的入口-B-拖飼料到牛身上-390',
    cells: () => [
      { cap: '按「飼料」：下面跳出一排飼料', note: '每種寫倉庫裡有幾份；沒有的灰掉', html: ranch({ center: tray() }) },
      { cap: '按住一種飼料，拖到牛身上', note: '拖到哪頭牛，那頭牛就亮一圈「放開就餵」', html: ranch({ center: tray({ drag: 'soy' }), overlays: `<span class="drop-ring" style="left:${head(15)[0] - 46}px;top:${head(15)[1] - 30}px"><i>放開就餵</i></span>${flyIcon('soy', head(15)[0] + 30, head(15)[1] + 10, 36)}${finger(head(15)[0] + 36, head(15)[1] + 26)}` }) },
      { cap: '放開：吃掉一份', note: '頭上跳「+8 公斤」；小牛要吃的，集點卡多一個章', html: ranch({ center: tray({ used: 'soy' }), overlays: `${kgOn(15, '+8 公斤')}${stampPop(head(15)[0] - 118, head(15)[1] - 20, 'soy')}` }) },
    ],
    fun: '像在玩：直接把飼料丟給牛，不用開面板。選 B 的話 02「選飼料」就不用選（一排飼料就是選飼料）。' },
  '02-A': { item: '02 選飼料', opt: 'A', name: '底部面板六格', file: 'R19-02-選飼料-A-底部面板六格-390',
    cells: () => [
      { cap: '小牛：要吃的標「要吃」、吃過的打勾', note: '每格寫長幾公斤、倉庫有幾份；選好按「餵一份…」', html: ranch({ herd: front([15]), overlays: feedSheet(calf, { picked: 'soy' }) }) },
      { cap: '成牛：沒有指定，選哪種都可以', note: '越貴長越多肉（牧草 +1 公斤 … 豆粕 +8 公斤）', html: ranch({ herd: front([12]), overlays: feedSheet(cow12, { picked: 'corn' }) }) },
      { cap: '倉庫裡沒有飼料', note: '直接帶去市場的「飼料」分頁', html: ranch({ herd: front([12]), overlays: emptySheet(cow12) }) },
    ],
    fun: '六種一次看完，比較每種長幾公斤、還有幾份；小牛要吃的很明顯。' },
  '02-B': { item: '02 選飼料', opt: 'B', name: '名片上的飼料格', file: 'R19-02-選飼料-B-名片上的飼料格-390',
    cells: () => [
      { cap: '點牛：名片下面就是六種飼料', note: '數字是倉庫裡的份數；小牛要吃的有綠框、「要吃」', html: ranch({ herd: front([15]), pop: { id: 15, cls: 'pf', html: popFeed(calf, { row: true }) } }) },
      { cap: '點一下就餵（不用再按確定）', note: '豆粕 3 → 2 份；頭上跳「+8 公斤」', html: ranch({ herd: front([15]), pop: { id: 15, cls: 'pf', html: popFeed(calfFull, { row: true, picked: 'soy', stockOf: { ...STOCK, soy: 2 } }) }, overlays: kgOn(15, '+8 公斤') }) },
      { cap: '成牛的名片', note: '沒有指定的飼料，六種都可以點', html: ranch({ herd: front([12]), pop: { id: 12, cls: 'pf', html: popFeed(cow12, { row: true }) } }) },
    ],
    fun: '最快：點牛、點飼料，兩下就餵好，不離開牧場。缺點是名片變大，會蓋住後面的牛。' },
  '03-A': { item: '03 吃飽冷卻', opt: 'A', name: '按鈕變灰、寫倒數', file: 'R19-03-吃飽冷卻-A-按鈕變灰寫倒數-390',
    cells: () => [
      { cap: '名片：「吃飽了，1:23 後可以再吃」', note: '成牛 4 小時、小牛 45 分鐘（遊戲時間）', html: ranch({ herd: front([12]), pop: { id: 12, html: popFeed(cow12, { cool: '吃飽了，1:23 後可以再吃' }) } }) },
      { cap: '牛的詳細：同一句寫在按鈕下面', note: '', html: detailPage(ctx0(), cow12, { buttons: feedBtnRow('吃飽了', { ic: 'clock', disabled: true, sub: '1:23 後可以再吃' }) }) },
      { cap: '不能餵的牛', note: '過了最壯、上架借種中的公牛：按鈕不見，寫原因', html: ranch({ herd: front([3]), pop: { id: 3, html: `${popHtml(oldCow).replace(/<button[\s\S]*$/, '')}<p class="cool-line">${icon('info', 14)}<span>長到最壯了，不用再餵</span></p>${btn('看詳細', { small: true, block: true, kind: 'primary' })}` } }) },
    ],
    fun: '只在點牛的時候才看得到，牧場畫面乾淨。' },
  '03-B': { item: '03 吃飽冷卻', opt: 'B', name: '頭上的小碗', file: 'R19-03-吃飽冷卻-B-頭上的小碗-390',
    cells: () => [
      { cap: '剛吃過的牛，頭上一個小碗', note: '外圈的綠色是還要等多久，繞滿一圈就能再吃', html: ranch({ overlays: `${bowl(head(12)[0], head(12)[1], 0.3)}${bowl(head(3)[0], head(3)[1], 0.75)}${bowl(head(15)[0], head(15)[1], 0.55)}` }) },
      { cap: '點牛：名片寫倒數', note: '', html: ranch({ herd: front([12]), pop: { id: 12, html: popFeed(cow12, { cool: '吃飽了，1:23 後可以再吃' }) } }) },
      { cap: '可以吃了：小碗不見', note: '小牛還有要吃的，就回到「想吃」泡泡', html: ranch({ wants: [calf], overlays: bowl(head(3)[0], head(3)[1], 0.92) }) },
    ],
    fun: '一眼看出哪幾頭剛餵過、哪幾頭可以餵。牛多的時候頭上會多很多小碗。' },
  '04-A': { item: '04 全部餵一樣的', opt: 'A', name: '面板上的按鈕', file: 'R19-04-全部餵一樣的-A-面板上的按鈕-390',
    cells: () => [
      { cap: '牧場面板左上角「全部餵」', note: '跟「收起」同一排', html: withDockPill(ranch()) },
      { cap: '選一種飼料，看能餵幾頭', note: '份數不夠：先餵小牛，再照編號（打勾的是會吃到的）', html: withDockPill(ranch({ overlays: feedAllSheet('corn') })) },
      { cap: '餵好了', note: '吃到的牛頭上跳公斤數', html: withDockPill(ranch({ overlays: `${toastOk('餵了 5 頭，用掉 5 份玉米')}${kgOn(15, '+5 公斤')}${kgOn(3, '+5 公斤')}${kgOn(12, '+5 公斤')}${kgOn(7, '+5 公斤')}` })) },
    ],
    fun: '放在本來就有的面板上，不多佔牧場的位置。' },
  '04-B': { item: '04 全部餵一樣的', opt: 'B', name: '牧場上的圓鈕', file: 'R19-04-全部餵一樣的-B-牧場上的圓鈕-390',
    cells: () => [
      { cap: '牧場右邊一顆圓鈕「全部餵」', note: '在面板上面，大拇指按得到', html: ranch({ center: roundFeedBtn }) },
      { cap: '選一種飼料，看能餵幾頭', note: '跟 A 一樣', html: ranch({ center: roundFeedBtn, overlays: feedAllSheet('corn') }) },
      { cap: '餵好了', note: '', html: ranch({ center: roundFeedBtn, overlays: `${toastOk('餵了 5 頭，用掉 5 份玉米')}${kgOn(15, '+5 公斤')}${kgOn(3, '+5 公斤')}${kgOn(12, '+5 公斤')}${kgOn(7, '+5 公斤')}` }) },
    ],
    fun: '最顯眼，牛多的時候一按就餵；會多蓋住一點牧場。' },
  '05-A': { item: '05 餵了以後', opt: 'A', name: '飛進嘴裡、加公斤、蓋章', file: 'R19-05-餵了以後-A-飛進嘴裡加公斤蓋章-390',
    cells: () => [
      { cap: '按「餵一份豆粕」', note: '', html: ranch({ herd: front([15]), overlays: feedSheet(calf, { picked: 'soy' }) + finger(300, dev.h - 72) }) },
      { cap: '飼料飛進嘴裡', note: '0.4 秒，畫一條弧線', html: ranch({ herd: front([15]), overlays: flyArc(300, dev.h - 120, head(15)[0] + 4, head(15)[1] + 26) + flyIcon('soy', 250, head(15)[1] - 40, 34) }) },
      { cap: '嚼一嚼、「+8 公斤」', note: '公斤數往上飄、淡掉', html: ranch({ herd: front([15]), overlays: chew(head(15)[0] + 24, head(15)[1] + 10) + kgOn(15, '+8 公斤') }) },
      { cap: '小牛：集點卡蓋一個章', note: '集滿了，頭上不再冒「想吃」泡泡', html: ranch({ herd: front([15]), overlays: stampPop(head(15)[0] - 30, head(15)[1] - 70, 'soy') + toastOk('集滿了！長大不會變雜種牛') }) },
      { cap: '牛的詳細：集點卡全部蓋滿', note: '（往下捲到集點卡）', html: tallify(detailPage(ctx0(), calfFull, { buttons: feedBtnRow('吃飽了', { ic: 'clock', disabled: true, sub: '44:59 後可以再吃', calf: true }) })) },
    ],
    fun: '每餵一次都看得到長了幾公斤；小牛要吃的會蓋章，跟集點卡連在一起。' },
};
function rBoard(k) {
  const o = V[k];
  return board({ id: o.file, title: `${o.item}　${o.opt}：${o.name}`, sub: SUB, cells: o.cells(), notes: [o.fun] });
}
function r1999() {
  const S = 0.5, sw = Math.round(dev.w * S), sh = Math.round(dev.h * S);
  const mini = (html) => `<div class="ov-ph" style="width:${sw}px;height:${sh}px"><div style="transform:scale(${S});transform-origin:0 0">${html}</div></div>`;
  const pick = { '01-A': [0], '01-B': [1], '02-A': [0], '02-B': [0], '03-A': [0], '03-B': [0], '04-A': [1], '04-B': [0] };
  const items = ['01', '02', '03', '04'];
  const rows = items.map((it) => {
    const cs = ['A', 'B'].map((v) => { const o = V[`${it}-${v}`]; return `<div class="ov-cell"><div class="ov-cap"><b>${v}　${o.name}</b></div>${pick[`${it}-${v}`].map((i) => mini(o.cells()[i].html)).join('')}</div>`; }).join('');
    return `<div class="ov-row"><div class="ov-title">${V[`${it}-A`].item}</div><div class="ov-cells">${cs}</div></div>`;
  }).join('') + `<div class="ov-row"><div class="ov-title">05 餵了以後（只有一種）</div><div class="ov-cells"><div class="ov-cell"><div class="ov-pair">${[1, 2, 3].map((i) => mini(V['05-A'].cells()[i].html)).join('')}</div></div></div></div>`;
  return { html: `<div class="board" style="width:${PAD * 2 + 3 * sw + 2 * 14 + 28}px"><div class="b-label">R19-99-總覽對照</div><div class="b-title">第 19 輪：餵食</div>
    <div class="b-sub">每一項選一種；各自的分鏡見 R19-01～05。01 選 B（拖飼料）的話，02 不用選。</div>${rows}</div>` };
}
const BOARDS = [...Object.keys(V).map((k) => ({ id: `R19-${k}`, render: () => rBoard(k) })), { id: 'R19-99', render: r1999 }];

async function settle() {
  await document.fonts.ready;
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
}
if (q.has('list')) {
  window.__boards = BOARDS.map(({ id }) => ({ id, w: 390 }));
  window.__ready = true;
} else {
  const b = BOARDS.find((x) => x.id === q.get('b'));
  if (!b) throw new Error(`沒有這張：${q.get('b')}`);
  const out = b.render();
  app.innerHTML = out.html;
  await settle();
  if (fitTitles(app)) await settle();
  if (fitOriginTags(app) + placeVersion(app)) await settle();
  if (fitSwipeHint(app) + fitMiniLines(app)) await settle();
  if (placeCowPop(app)) await settle();
  if (fitGrade(app)) await settle();
  if (fitActions(app)) await settle();
  const el = app.querySelector('.board');
  window.__file = el.querySelector('.b-label').textContent;
  window.__size = { w: Math.ceil(el.offsetWidth), h: Math.ceil(el.offsetHeight) };
  window.__ready = true;
}
