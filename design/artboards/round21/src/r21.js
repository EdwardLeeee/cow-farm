// 第 21 輪草稿（ceo 2026-10-09 交辦）：牛仔套索 A 照使用者的三點改（見檔尾「第 21 輪」）。程式從第 18 輪複製，前面各輪的說明留著。
// 第 18 輪草稿（ceo 2026-10-08 交辦）：牛仔套索重新設計 4 版。以下第 17 輪的說明留著：
// 第 17 輪草稿（ceo 2026-10-08 交辦）：牛仔套索改成在原野上套牛（使用者看第 16 輪後：「我希望牛在原野上跑來跑去，我們要用一個牛仔的繩索套住一隻牛」）。
//   牛仔的繩索兩種畫法給使用者挑：A 前景畫出牛仔的背影在甩繩；B 第一人稱，只看到手和繩圈。操作照第 16 輪（按住甩圈、拖動瞄準、量尺到「剛好」放開）。
// 程式從第 16 輪複製（r16.js）。網址：r17.html?b=R17-01-A；?list=1 列出全部說明圖。
// 元件、字串、假資料、牛的產生器都用 M2 設計稿（design/m2，已含小牛基本款和雜種牛）。新的字是草稿，直接寫在這裡，沒有進字串表：
// 使用者選完才加 key、翻英文和泰文（D25）。
import { applyDevice, frame, btn, icon, fmt, badge, cowSVG, cowFace, useChip, sexText, bar, seg, fitTitles, fitOriginTags, placeVersion, fitSwipeHint, fitMiniLines, placeCowPop, fitGrade, fitActions, BREEDS } from '../../../m2/src/js/kit.js';
import { loadLang, t, dur, useName, breedName, calfName, tierName, feedList } from '../../../m2/src/js/i18n.js';
import { PEN, NEWS, FOUND, COWS, newsTag, newsText } from '../../../m2/src/js/fixtures.js';
import { CODEX_ORDER, MIX_LOOK, tierOf } from '../../../m2/src/cow/breeds.js';
import { CALF_LOOK, calfBow, hasBow } from '../../../m2/src/cow/calf.js';
import { drawCow } from '../../../m2/src/cow/render.js';
import { ranchScene, HERD } from '../../../m2/src/js/scene.js';
import { FEED_IC, FEED_KEYS, FEED_INFO } from './feeds.js';

const L = '#4B3326';
const f2 = (v) => Math.round(v * 100) / 100;
const USES = ['dairy', 'draft', 'beef'];

// ---------- 草稿用的牛：特殊牛 3 種（v0.3 第 13.3 節；只在這一頁加進 BREEDS，名字用草稿字串） ----------
// 花紋（閃電、祥雲、金色捲紋）和金色的角加在 M2 的產生器（src/cow/r11.js 的 paintSpecial），24 種牛完全不受影響（cowcheck 103/103）
const DRAFT_STR = {};
const realFetch = window.fetch.bind(window);
window.fetch = async (u, o) => {
  if (typeof u !== 'string' || !u.startsWith('../i18n/')) return realFetch(u, o);
  const r = await realFetch(`../../../m2/${u.slice(3)}`, o);
  if (!u.endsWith('zh-Hant.json')) return r;
  return new Response(JSON.stringify({ ...(await r.json()), ...DRAFT_STR }), { headers: { 'Content-Type': 'application/json' } });
};
const SPECIAL = {
  zeus: { name: '宙斯牛', use: 'beef', coat: '#FBF8F1', pattern: 'bolt', patternColor: '#F7C744', patternEdge: '#C98A1A', hornColor: '#F7C744', hornTip: '#D9961F', horns: 'long', muzzle: '#F4DCD0', seed: 81,
    intro: '雪白的身上有金色的閃電紋，頭上一對金色的角。', look: '白色、金色的角、身上閃電紋' },
  azure: { name: '青牛', use: 'draft', coat: '#8FAAB5', pattern: 'cloud', patternColor: '#F1F8FA', patternEdge: '#6E8C98', horns: 'long', muzzle: '#D8E3E6', seed: 83,
    intro: '青灰色的毛上飄著白色的祥雲紋，慢慢走也很有派頭。', look: '青灰色、身上白色祥雲紋' },
  holyWhite: { name: '聖白牛', use: 'dairy', coat: '#FFFFFF', pattern: 'gold', patternColor: '#E7B53A', hornColor: '#F3CF6A', hornTip: '#D9A537', muzzle: '#F8E4DC', seed: 85,
    intro: '全身純白，身上有金色的捲紋，走過的地方好像會發光。', look: '純白、身上金色捲紋' },
};
const SP_KEYS = Object.keys(SPECIAL);
for (const [k, o] of Object.entries(SPECIAL)) {
  BREEDS[k] = { traits: {}, earColor: 'coat', special: true, ...o };
  DRAFT_STR[`breed.${k}.name`] = o.name;
}

const q = new URLSearchParams(location.search);
const W = +(q.get('w') || 390);
const dev = applyDevice(W);
const app = document.getElementById('app');
await loadLang('zh-Hant');
// 畫面模組的常數會用到字串：字串表載好才載入（跟 m2 的 main.js 一樣）
const { dock, cowListRow, popHtml, ranchPage } = await import('../../../m2/src/js/screens/s03.js');
const { detailPage } = await import('../../../m2/src/js/screens/s04.js');
const { STATES } = await import('../../../m2/src/js/states.js');

// ---------- 小圖示 ----------
// 指著的手（點、劃的手勢；指尖在 (13, 2)）
const POINTER = (s = 34) => `<svg viewBox="0 0 32 34" width="${s}" height="${Math.round(s * 34 / 32)}" aria-hidden="true"><path d="M11 4.4a2.3 2.3 0 0 1 4.6 0v9.8l1.2-.3a2.1 2.1 0 0 1 2.6 1.5l.1.5 1.1-.2a2.1 2.1 0 0 1 2.5 1.6l.1.5h.8a2.1 2.1 0 0 1 2.2 2.1v4.6c0 4.8-3.3 8.1-7.9 8.1h-1.5c-2.7 0-4.6-1.1-6.2-3.4l-4.8-6.7a2.1 2.1 0 0 1 3.1-2.8l2.1 2.3z" fill="#FFE3D2" stroke="${L}" stroke-width="2" stroke-linejoin="round"/><path d="M15.6 14.2v3.6M19.5 15.4v2.8M23.2 17.1v2" stroke="${L}" stroke-width="1.6" stroke-linecap="round"/></svg>`;
// 星星（02）、寶石（特殊牛的記號）
const STAR = (s, fill = '#FFC93C', stroke = L) => `<svg class="st" viewBox="0 0 20 20" width="${s}" height="${s}" aria-hidden="true"><path d="M10 1.9l2.45 5.1 5.6.75-4.1 3.85 1.05 5.55L10 14.45l-5 2.7 1.05-5.55-4.1-3.85 5.6-.75z" fill="${fill}" stroke="${stroke}" stroke-width="1.7" stroke-linejoin="round"/></svg>`;
const GEM = (s = 14) => `<svg class="gem" viewBox="0 0 20 20" width="${s}" height="${s}" aria-hidden="true"><path d="M5.4 3h9.2l3.6 4.6L10 17.4 1.8 7.6z" fill="#7FE0F0" stroke="${L}" stroke-width="1.6" stroke-linejoin="round"/><path d="M1.8 7.6h16.4M7 3l-1.4 4.6L10 17.4l4.4-9.8L13 3" fill="none" stroke="${L}" stroke-width="1.1" stroke-linejoin="round"/><path d="M4.6 6.4l1.6-2" stroke="#FFFFFF" stroke-width="1.4" stroke-linecap="round"/></svg>`;
// 特殊牛的記號（提案）：金色膠囊＋寶石＋「特殊」。不用 ceo 舉例的「金色光圈」：光圈很像宗教畫裡的光環
const spMark = (small = false) => `<span class="sp-mark${small ? ' small' : ''}">${GEM(small ? 12 : 14)}特殊</span>`;

// ---------- 說明圖的版面（跟第 13 輪一樣） ----------
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

// ---------- 牧場頁（S03 的 ranchPage，多了：場景裡的東西、牛頭上的泡泡） ----------
function ranch(o = {}) {
  const herd = o.herd || HERD, pan = o.pan || 0;
  const sc = ranchScene(dev, herd, { wide: true, pan });
  const F = sc.fit;
  const over = typeof o.overlays === 'function' ? o.overlays(sc.anchors, F.map) : o.overlays || '';
  const pen = o.pen || PEN;
  const body = `
    <div class="ticker"><span class="ticker-icon">${icon('news', 20)}</span><span class="ticker-text" data-marquee>${newsTag(NEWS[0])}${newsText(NEWS[0])}</span></div>
    <button class="pen-pill${pen.used >= pen.slots ? ' full' : ''}">${icon('barn', 22)}${t('cowsTitle')}<span class="num">${pen.used} / ${pen.slots}</span>${icon('chevron', 16)}</button>
    ${o.center || ''}
    ${dock({ ...(o.dock || {}), pan })}`;
  return frame(dev, { tab: 'ranch', scene: sc.svg, body, hud: o.hud || {}, overlays: over });
}

// ---------- 01 小牛卡片：直接寫要吃哪幾種飼料、吃了沒 ----------
// 小牛的假資料：need 是這頭小牛長大前要吃到的飼料（照「長大會是哪個品種」，D35 補充 3 的表；伺服器出生時就知道），ate 是吃過的
const CALVES = {
  15: { id: 15, use: 'dairy', sex: 'cow', seed: 31, age_: { h: 2, m: 18 }, grow_: { m: 42 }, origin: 'breed', need: ['oats', 'soy'], ate: ['oats'] },
  21: { id: 21, use: 'draft', sex: 'bull', age_: { m: 50 }, grow_: { h: 2, m: 10 }, origin: 'breed', need: ['oats'], ate: [] },
  22: { id: 22, use: 'beef', sex: 'cow', age_: { h: 1, m: 30 }, grow_: { h: 1, m: 30 }, origin: 'B', need: ['corn', 'soy'], ate: ['corn', 'soy'] },
  23: { id: 23, use: 'dairy', sex: 'bull', age_: { m: 20 }, grow_: { h: 2, m: 40 }, origin: 'C', need: [], ate: [] },
};
const todo = (c) => c.need.filter((k) => !c.ate.includes(k));
const fname = (k) => t(`feed.${k}`);
const calfArt = (c, o = {}) => cowSVG({ breed: CALF_LOOK[c.use], sex: c.sex, age: 'calf', seed: c.seed }, o);
const cName = (c) => calfName(c.use, c.id);
// 牧場裡：#15 原本就在；另外放 #21（後排）、#22（前排右邊）、#23（中間右邊）
const CALF_SPOTS = [
  { id: 21, x: 236, y: 352, facing: 'left', depth: 0 },
  { id: 22, x: 262, y: 512, facing: 'left', depth: 2 },
  { id: 23, x: 362, y: 470, facing: 'left', depth: 2 },
];
const PEN15 = { used: 13, slots: 16 };
const HERD15 = HERD.concat(CALF_SPOTS.map((s) => ({ ...s, breed: CALF_LOOK[CALVES[s.id].use], sex: CALVES[s.id].sex, age: 'calf' })));
const RULE = '每種吃一次就好；少吃一種，長大會變成雜種牛';
const ANY = '什麼都可以吃';

const V1 = {
  A: { name: '飼料格', file: '飼料格', title: '一種飼料一格（大圖示），吃過的打勾；泡泡寫「想吃豆粕」' },
  B: { name: '打勾清單', file: '打勾清單', title: '一種飼料一行，前面一個勾選框；泡泡只畫飼料' },
  C: { name: '集點卡', file: '集點卡', title: '像集點卡：吃過一種蓋一個章；泡泡寫「1 / 2」' },
  D: { name: '放在大圖上', file: '放在大圖上', title: '飼料直接貼在小牛大圖的旁邊，不另外放一張卡；泡泡是圓的飼料圖示' },
};
// 小牛詳細裡的那一塊
function needBlock(c, v) {
  const left = todo(c);
  if (v === 'A') {
    if (!c.need.length) return `<article class="card need-card"><div class="card-head"><span class="card-title green">${FEED_IC.grass(16)}長大前要吃的飼料</span></div><p class="any-line">${icon('ok', 20)}${ANY}<span class="hint">　不會變成雜種牛</span></p></article>`;
    const slots = c.need.map((k) => { const done = c.ate.includes(k); return `<div class="fs ${done ? 'done' : 'todo'}">${done ? `<span class="fs-mark">${icon('ok', 24)}</span>` : ''}${FEED_IC[k](36)}<b>${fname(k)}</b>${done ? '<span class="tr-done">吃過了</span>' : '<span class="tr-todo">還沒吃</span>'}</div>`; }).join('');
    return `<article class="card need-card"><div class="card-head"><span class="card-title green">${FEED_IC.grass(16)}長大前要吃的飼料</span><span class="card-sub">${c.need.length - left.length} / ${c.need.length}</span></div><div class="feed-slots n${c.need.length}">${slots}</div><p class="hint tr-note">${RULE}</p></article>`;
  }
  if (v === 'B') {
    if (!c.need.length) return `<article class="card need-card"><div class="card-head"><span class="card-title green">${FEED_IC.grass(16)}長大前要吃</span></div><p class="any-line">${icon('ok', 20)}${ANY}</p></article>`;
    const rows = c.need.map((k) => { const done = c.ate.includes(k); return `<div class="ck-row${done ? ' done' : ''}"><span class="ck-box">${done ? icon('ok', 18) : ''}</span>${FEED_IC[k](26)}<b>${fname(k)}</b><span class="grow"></span>${done ? '<span class="tr-done">吃過了</span>' : '<span class="tr-todo">還沒吃</span>'}</div>`; }).join('');
    return `<article class="card need-card"><div class="card-head"><span class="card-title green">${FEED_IC.grass(16)}長大前要吃</span></div>${rows}<p class="hint tr-note">${RULE}</p></article>`;
  }
  if (v === 'C') {
    if (!c.need.length) return `<article class="card stamp-card any"><div class="sc-head"><b>飼料集點卡</b></div><p class="any-line">${icon('ok', 20)}${ANY}</p></article>`;
    const stamps = c.need.map((k) => { const done = c.ate.includes(k); return `<div class="stamp${done ? ' done' : ''}"><span class="st-ring">${FEED_IC[k](34)}${done ? '<i class="st-ink">吃過</i>' : ''}</span><b>${fname(k)}</b></div>`; }).join('');
    return `<article class="card stamp-card"><div class="sc-head"><b>飼料集點卡</b><span class="sc-count num">${c.need.length - left.length} / ${c.need.length}</span></div><div class="stamps">${stamps}</div><p class="hint tr-note">集滿再長大，才不會變成雜種牛</p></article>`;
  }
  return '';
}
// D：貼在大圖上的飼料（右邊直排）
function heroFeeds(c) {
  if (!c.need.length) return `<div class="hf any"><span class="hf-any">${icon('ok', 16)}${ANY}</span></div>`;
  return `<div class="hf"><span class="hf-t">長大前要吃</span>${c.need.map((k) => { const done = c.ate.includes(k); return `<span class="hf-i${done ? ' done' : ''}">${FEED_IC[k](30)}<b>${fname(k)}</b>${done ? `<i>${icon('ok', 16)}</i>` : ''}</span>`; }).join('')}</div>`;
}
function calfPage(c, v) {
  const chips = [useChip(c.use), `<span class="use">${sexText(c.sex)}</span>`, badge('calf', t('stageCalf'))];
  const origin = c.origin === 'breed' ? t('s04.originBreed') : t('s04.originShop', { g: c.origin });
  const cells = [[t('s04.age'), dur(c.age_)], [t('s04.growIn'), dur(c.grow_)]];
  const heroNote = v === 'D' && c.need.length ? `<p class="hint hero-note">${RULE}</p>` : `<p class="hint hero-note">${t('s04.calfUnknown')}</p>`;
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${cName(c)}</h1><div class="chips" style="margin-top:3px">${chips.join('')}</div></div></div>
    <article class="card hero calf-hero${v === 'D' ? ' with-feeds' : ''}"><div class="hero-bg"></div>${calfArt(c, { w: v === 'D' ? 170 : 200, h: v === 'D' ? 140 : 132, pad: 4 })}${v === 'D' ? heroFeeds(c) : ''}
      <span class="origin-tag">${t('origin', { v: origin })}</span>${heroNote}</article>
    <div class="kv">${cells.map(([k, val]) => `<div class="cell"><div class="k">${k}</div><div class="v num">${val}</div></div>`).join('')}</div>
    ${needBlock(c, v)}
  </div>`;
  const buttons = `<button class="btn green block">${FEED_IC.grass(22)}<span>餵食</span></button><div class="btn-row" style="margin-top:12px">${btn(t('s04.cantBreedYet'), { kind: 'pink', ic: 'heart', disabled: true })}${btn(t('shipNotAdult'), { kind: 'danger', disabled: true })}</div>`;
  return frame(dev, { tab: 'ranch', content, contentCls: 'has-actions rows-2', body: `<div class="detail-actions rows-2">${buttons}</div>` });
}
// 牧場：小牛頭上的泡泡（只畫指定、還沒吃過的飼料；什麼都可以吃、都吃過了的不畫）
function wantBubble(c, v, a) {
  const w = todo(c);
  if (!w.length) return '';
  const pos = `left:${f2(a.head[0])}px;top:${f2(a.head[1])}px`;
  if (v === 'A') return `<div class="want" style="${pos}">${FEED_IC[w[0]](22)}<span>想吃${fname(w[0])}</span></div>`;
  if (v === 'B') return `<div class="want think" style="${pos}">${w.map((k) => FEED_IC[k](24)).join('')}</div>`;
  if (v === 'C') return `<div class="want stampy" style="${pos}">${FEED_IC[w[0]](22)}<b class="num">${c.need.length - w.length} / ${c.need.length}</b></div>`;
  return `<div class="want round" style="${pos}">${FEED_IC[w[0]](26)}</div>`;
}
const bubbles = (v) => ranch({ herd: HERD15, pen: PEN15, overlays: (an) => [15, 21, 22, 23].map((id) => wantBubble(CALVES[id], v, an[id])).join('') });
// 快長大的提醒卡（再 1 小時內長大、還有指定的飼料沒吃過：跳一次，一頭一張，可以關）
function growAlert(c, v) {
  const w = todo(c);
  const why = v === 'B' ? `還沒吃${w.map(fname).join('、')}：沒吃到會變成雜種牛`
    : `還沒吃：${w.map((k) => `<span class="ga-feed">${FEED_IC[k](18)}${fname(k)}</span>`).join('')}`;
  return `<div class="grow-alert card"><span class="ga-pic">${calfArt(c, { w: 52, h: 52, pad: 2 })}</span><div class="grow"><b>${cName(c)} 再 ${dur(c.grow_)}就長大</b><p>${why}</p></div>
    <button class="btn small primary ga-go"><span>去餵食</span></button><button class="bn-close" aria-label="${t('g.close')}">${icon('close', 18)}</button></div>`;
}
// 牛舍清單的小牛那一列
function feedLine(c, v) {
  if (!c.need.length) return `<div class="meta fl-any">${ANY}</div>`;
  const all = !todo(c).length;
  if (v === 'A') return `<div class="fl-chips">${c.need.map((k) => { const d = c.ate.includes(k); return `<span class="fl-chip${d ? ' done' : ''}">${FEED_IC[k](18)}${fname(k)}${d ? icon('ok', 14) : ''}</span>`; }).join('')}</div>`;
  if (v === 'B') return `<div class="meta fl-text">要吃：${c.need.map((k) => (c.ate.includes(k) ? `<span class="tr-done">${fname(k)}${icon('ok', 13)}</span>` : `<span class="tr-todo">${fname(k)}</span>`)).join('、')}</div>`;
  if (v === 'C') return `<div class="fl-stamps">${c.need.map((k) => `<span class="mini-stamp${c.ate.includes(k) ? ' done' : ''}">${FEED_IC[k](18)}</span>`).join('')}<b class="num">${c.need.length - todo(c).length} / ${c.need.length}</b>${all ? '<span class="tr-done">集滿了</span>' : ''}</div>`;
  return '';
}
function calfRow(c, v) {
  const chips = [useChip(c.use), `<span class="use">${sexText(c.sex)}</span>`, badge('calf', t('stageCalf'))];
  const right = v === 'D' ? `<div class="right row-feeds">${c.need.length ? c.need.map((k) => `<span class="hf-i mini${c.ate.includes(k) ? ' done' : ''}">${FEED_IC[k](22)}${c.ate.includes(k) ? `<i>${icon('ok', 12)}</i>` : ''}</span>`).join('') : `<span class="hf-any mini">${ANY}</span>`}</div>`
    : `<div class="right"><span class="chev">${icon('chevron', 20)}</span></div>`;
  return `<article class="card cow-row"><div class="pic">${calfArt(c, { w: 60, h: 60, pad: 3 })}</div>
    <div class="info"><div class="name">${cName(c)}</div><div class="chips" style="margin-top:3px">${chips.join('')}</div><div class="meta">${t('growUp', { v: dur(c.grow_) })}</div>${v === 'D' ? '' : feedLine(c, v)}</div>${right}</article>`;
}
function listPage(rows, { used = 13 } = {}) {
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${t('cowsTitle')}</h1><div class="sub">${t('penSummary', { used, slots: 16 })}</div></div>${btn(t('s03.expandPen'), { small: true, kind: 'primary', ic: 'plus' })}</div>
    <div class="filter" data-hscroll>${[t('g.all'), useName('dairy'), useName('draft'), useName('beef')].map((f, i) => `<button class="${i === 0 ? 'on' : ''}">${f}</button>`).join('')}</div>
    <div class="list">${rows.join('')}</div></div>`;
  return frame(dev, { tab: 'ranch', content });
}
// 六種飼料排排站（每張 01 的上面）
function feedLineup() {
  return `<div class="lineup feeds6">
    <div class="lu-head">六種飼料的圖示<small>v0.3 第 2.1 節；越貴長越多肉。牧草、燕麥、苜蓿、玉米沿用第 13 輪，乾草、豆粕新畫</small></div>
    ${FEED_KEYS.map((k) => `<div class="lu-cell">${FEED_IC[k](64)}<b>${fname(k)}</b><span>長肉 ${FEED_INFO[k][0]}・${FEED_INFO[k][1]} 幣</span><span class="lu-small">${FEED_IC[k](22)}${FEED_IC[k](18)}</span></div>`).join('')}
  </div>`;
}
const rows01 = (v) => [15, 21, 22, 23].map((id) => calfRow(CALVES[id], v)).concat([cowListRow(COWS.find((c) => c.id === 3))]);
function r1501(v) {
  const o = V1[v];
  return board({
    id: `R15-01-小牛卡片-${v}-${o.file}-390`, title: `01 小牛卡片：直接寫要吃哪幾種　${v}：${o.title}`, width: boardWidth(5),
    sub: '使用者選「C 直接寫這頭要吃哪幾種」（D35 補充 3）。稀有、傳說的小牛各指定 1–2 種，一般、優良寫「什麼都可以吃」；不寫機率。四個版本只差在怎麼排。',
    top: feedLineup(),
    cells: [
      { cap: '小牛的詳細：要吃兩種、吃過一種', note: '小乳牛 #15：燕麥吃過了、豆粕還沒吃', html: calfPage(CALVES[15], v) },
      { cap: '小牛的詳細：什麼都可以吃', note: '一般、優良的小牛沒有指定，不會變成雜種牛', html: calfPage(CALVES[23], v) },
      { cap: '牧場：小牛頭上的泡泡', note: '只畫指定、還沒吃過的；都吃過了、什麼都可以吃的不畫', html: bubbles(v) },
      { cap: '快長大了：提醒卡', note: '再 1 小時內長大、還有沒吃的：跳一次（一頭一張，可以關）', html: ranch({ herd: HERD15, pen: PEN15, overlays: growAlert(CALVES[15], v) }) },
      { cap: '牛舍清單', note: '由上到下：吃了一半、一種都還沒吃、都吃過了、什麼都可以吃', html: listPage(rows01(v)) },
    ],
    notes: [
      { A: '好處：一眼看到要吃什麼、吃了沒，圖示大、好認。代價：要吃兩種時卡片比較高。',
        B: '好處：最省空間，跟待辦清單一樣好懂。代價：圖示小一點；牧場的泡泡沒有字，要認得圖示。',
        C: '好處：「集滿再長大」有收集的樂趣，跟圖鑑、成就的感覺一致。代價：卡片多一層「集點」的說法，要多看一眼。',
        D: '好處：不用往下捲，大圖旁邊就看得到；牛舍清單直接在右邊放圖示。代價：大圖右邊變擠，小牛圖要縮小一點。' }[v],
      '「餵食」按下去選飼料、吃飽冷卻、全部餵一樣的不在這一輪：版本選好以後一起收進 M2。',
    ],
  });
}

// ---------- 02 稀有度星星（v0.3 第 13.1 節）：一般 ★、優良 ★★、稀有 ★★★、傳說 ★★★★ ----------
const V2 = {
  A: { name: '只有星星', file: '只有星星', title: '放稀有度的地方只放星星，底色照原本的稀有度顏色' },
  B: { name: '星星加字', file: '星星加字', title: '星星後面加稀有度的名字（「★★ 優良」）' },
  C: { name: '四格星星', file: '四格星星', title: '固定 4 格，亮幾顆就是幾級（沒亮的是淡色），不加底色' },
};
function starChip(n, v, size = 11) {
  const k = n + 1;
  if (v === 'A') return `<span class="tier tier-${n} stars" aria-label="${tierName(n)}">${STAR(size).repeat(k)}</span>`;
  if (v === 'B') return `<span class="tier tier-${n} stars">${STAR(size).repeat(k)}<span class="st-t">${tierName(n)}</span></span>`;
  return `<span class="stars4 s${n}" aria-label="${tierName(n)}">${Array.from({ length: 4 }, (_, i) => (i < k ? STAR(size + 1) : STAR(size + 1, '#F3ECE2', '#CDBFAE'))).join('')}</span>`;
}
// 把 M2 畫面裡的稀有度標籤換成星星（tierChip 的樣子：<span class="tier tier-N">[傳說的小亮點]名字</span>）
const swapTiers = (html, v) => html.replace(/<span class="tier tier-(\d)">[\s\S]*?<\/span>/g, (m, n) => starChip(+n, v));
// 商店的機率是純文字（「一般 70%」）：換成星星
const TIER_ZH = ['一般', '優良', '稀有', '傳說'];
const swapShop = (html, v) => html.replace(/<span>(一般|優良|稀有|傳說) <b class="num">/g, (m, name) => `<span class="pg-star">${starChip(TIER_ZH.indexOf(name), v, 10)} <b class="num">`);
const ctx0 = () => ({ dev, w: dev.w, q: new URLSearchParams() });
const stateHtml = (id) => { const r = STATES.find((s) => s.id === id).render(ctx0()); return typeof r === 'string' ? r : r.html; };
const COW12 = COWS.find((c) => c.id === 12);
function starLegend(v) {
  return `<div class="lineup legend">
    <div class="lu-head">四種稀有度，加上雜種牛、特殊牛<small>使用者：「一般、優良、稀有、傳說可以用星星來代表」</small></div>
    ${[0, 1, 2, 3].map((n) => `<div class="lu-cell"><div class="big">${starChip(n, v, 16)}</div><b>${tierName(n)}</b><span>${n + 1} 顆星</span></div>`).join('')}
    <div class="lu-cell"><div class="big">${badge('mix', t('badgeMix'))}</div><b>雜種牛</b><span>不給星星，照舊寫「雜種」</span></div>
    <div class="lu-cell"><div class="big">${spMark()}</div><b>特殊牛</b><span>寶石記號（提案），不跟星星混</span></div>
  </div>`;
}
function r1502(v) {
  const o = V2[v];
  return board({
    id: `R15-02-稀有度星星-${v}-${o.file}-390`, title: `02 稀有度改用星星　${v}：${o.title}`, width: boardWidth(4),
    sub: '選好以後整套設計稿一起換（v0.3 第 13.1 節）。下面四個畫面是 M2 現在的畫面，只把稀有度換成星星。',
    top: starLegend(v),
    cells: [
      { cap: '點牛的名片', note: '草莓牛 #12（傳說）', html: swapTiers(stateHtml('S03-06'), v) },
      { cap: '牛的詳細', note: '名字下面那一排', html: swapTiers(detailPage(ctx0(), COW12, { buttons: `<div class="btn-row">${btn(t('pickForBreed'), { kind: 'pink', ic: 'heart' })}${btn(t('ship'), { kind: 'danger', ic: 'truck' })}</div>` }), v) },
      { cap: '圖鑑的格子', note: '格子最窄的地方（360、320 一排 3 格）', html: swapTiers(stateHtml('S09-02'), v) },
      { cap: '商店的機率', note: '「稀有度」那一行', html: swapShop(stateHtml('S19-01'), v) },
    ],
    notes: [
      { A: '好處：最乾淨，一看星星數就懂。代價：第一次玩的人要自己猜「4 顆是傳說」；稀有度的名字只在圖鑑說明、商店說明裡出現。',
        B: '好處：星星和名字都在，最不會看錯。代價：標籤最長，圖鑑格子、名片那一排比較擠（傳說那格要縮小字）。',
        C: '好處：一看就知道「最多 4 顆」，現在是第幾級。代價：沒有底色，跟其他標籤（用途、公母）比起來比較不顯眼。' }[v],
      '雜種牛照舊寫「雜種」（灰色標籤）。特殊牛 cow-ui 提案用金色膠囊＋寶石：ceo 舉例的「金色光圈」很像宗教畫裡的光環，所以沒用。',
    ],
  });
}

// ---------- 03 圖鑑的配種表（v0.3 第 13.2 節） ----------
const V3 = {
  A: { name: '卡片格子', file: '卡片格子', title: '一對爸媽一張小卡，兩張一排；沒解鎖的是影子' },
  B: { name: '一對一列', file: '一對一列', title: '一對爸媽一列：爸爸 × 媽媽、配出過幾次；沒解鎖的是影子' },
};
// 假資料：蓬蓬荷斯坦的代表配法（伺服器的資料表定；這裡是例子）。got：用這一對配出過幾次（0 是還沒解鎖）
const T_BREED = 'fluffyHolstein';
const PAIRS = [
  { dad: 'fluffyHolstein', mom: 'fluffyHolstein', got: 2 },
  { dad: 'fluffyHolstein', mom: 'holstein', got: 0 },
  { dad: 'holstein', mom: 'fluffyHolstein', got: 1 },
  { dad: 'cottonCream', mom: 'holstein', got: 0 },
];
const EXTRA = [{ dad: 'velvetBlack', mom: 'holstein', got: 1, extra: true }];
const parent = (k, sex, lock, s = 58) => cowSVG({ breed: k, sex }, { w: s, h: Math.round(s * 0.9), pad: 2, sil: lock ? 'dark' : false });
function pairCard(p, v) {
  const lock = !p.got;
  const dn = lock ? t('g.unknownBreed') : breedName(p.dad), mn = lock ? t('g.unknownBreed') : breedName(p.mom);
  const got = lock ? '還沒配出過' : `配出過 ${p.got} 次`;
  if (v === 'A') return `<div class="bp-card${lock ? ' locked' : ''}${p.extra ? ' extra' : ''}">${p.extra ? '<span class="bp-new">表上沒有的配法</span>' : ''}
    <div class="bp-pics">${parent(p.dad, 'bull', lock)}<span class="bp-x">×</span>${parent(p.mom, 'cow', lock)}</div>
    <div class="bp-names"><span><i class="sx m">♂</i>${dn}</span><span><i class="sx f">♀</i>${mn}</span></div><div class="bp-n">${got}</div></div>`;
  return `<div class="bp-row${lock ? ' locked' : ''}${p.extra ? ' extra' : ''}"><span class="bp-pic">${parent(p.dad, 'bull', lock, 50)}</span><span class="bp-x">×</span><span class="bp-pic">${parent(p.mom, 'cow', lock, 50)}</span>
    <div class="grow"><b><i class="sx m">♂</i>${dn}</b><b><i class="sx f">♀</i>${mn}</b><span class="hint">${got}${p.extra ? '・表上沒有的配法' : ''}</span></div></div>`;
}
function pairTable(v, { pairs = PAIRS, extra = EXTRA } = {}) {
  const all = pairs.concat(extra), n = all.filter((p) => p.got).length;
  return `<article class="card bp-table"><div class="card-head"><span class="card-title pink">${icon('heart', 16)}配種表</span><span class="card-sub">解鎖 ${n} / ${all.length}</span></div>
    <p class="hint" style="margin-top:4px">用這一對爸媽的品種配出${breedName(T_BREED)}（長大揭曉那一刻），就會亮起來</p>
    <div class="bp-list ${v}">${all.map((p) => pairCard(p, v)).join('')}</div></article>`;
}
// 品種詳細（S09-03 的樣子，換成蓬蓬荷斯坦），下面加配種表
function codexDetail(v, { top = true, pairs, extra } = {}) {
  const k = T_BREED, b = BREEDS[k];
  const head = `<div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${breedName(k)}</h1><div class="chips" style="margin-top:3px">${useChip(b.use)}${starChip(tierOf(b), 'A')}</div></div><span class="dex-no">${t('s09.no', { n: String(CODEX_ORDER.indexOf(k) + 1).padStart(2, '0') })}</span></div>`;
  const upper = top ? `<article class="card dex-hero"><div class="hero-bg"></div><div class="dex-pics">${cowSVG({ breed: k, pose: 'side' }, { w: 150, h: 120, pose: 'side' })}${cowSVG({ breed: k }, { w: 120, h: 120 })}</div></article>
    <p class="dex-intro">${t(`breed.${k}.intro`)}</p>
    <article class="card"><div class="card-head"><span class="card-title pink">${icon('heart', 16)}${t('s09.howTitle')}</span></div><p class="hint" style="margin-top:6px;color:var(--ink)">${t('s09.howTraits', { use: t('s09.howDairy'), traits: t('trait.A') })}</p></article>`
    : '<div class="skip-note">上面是大圖、介紹、數值、怎麼配出來（略）</div>';
  const content = `<div class="stack">${head}${upper}${pairTable(v, { pairs, extra })}</div>`;
  return frame(dev, { tab: 'records', content, tall: top });
}
function r1503(v) {
  const o = V3[v];
  const none = PAIRS.map((p) => ({ ...p, got: 0 }));
  return board({
    id: `R15-03-圖鑑配種表-${v}-${o.file}-390`, title: `03 圖鑑的配種表　${v}：${o.title}`, width: boardWidth(2),
    sub: '使用者：「點圖鑑的頭像進去會有配種表，如果沒有解鎖這種配法就是影子」。每個品種列 3–4 個代表配法（伺服器的資料表定；這裡是假資料），配出過就畫出爸媽兩頭牛；用表上沒有的配法配出來的，加在最後面。',
    cells: [
      { cap: '品種詳細：解鎖 2 種＋多 1 種', note: '蓬蓬荷斯坦；最後一張是表上沒有、自己配出來的', html: codexDetail(v) },
      { cap: '一種都還沒解鎖', note: '商店抽到、小遊戲抓到的沒有爸媽，不算；借種配出來的算', html: codexDetail(v, { top: false, pairs: none, extra: [] }) },
    ],
    notes: [
      v === 'A' ? '好處：爸媽兩頭牛畫得大，收集的感覺最強。代價：一張卡比較高，配法多了要捲比較久。' : '好處：一列一對，配法多了也排得下，比較省空間。代價：牛畫得小一點。',
      '爸爸寫在左邊（♂）、媽媽在右邊（♀），跟配種頁選牛的順序一樣。特殊牛沒有配種表，改寫「在抓牛小遊戲遇到」（見 04）。',
      '名字下面的稀有度先用 02-A 的星星畫，照使用者選的換。',
    ],
  });
}

// ---------- 04 特殊牛 3 種（v0.3 第 13.3 節） ----------
function specialLineup() {
  const cell = (k) => {
    const o = SPECIAL[k];
    return `<div class="lu-cell sp"><div class="lu-pics">${cowSVG({ breed: k }, { w: 132, h: 128 })}${cowSVG({ breed: k, pose: 'side' }, { w: 176, h: 128, pose: 'side' })}</div>
      <div class="lu-pics small">${cowSVG({ breed: k, sex: 'bull' }, { w: 96, h: 96 })}${cowSVG({ breed: k, age: 'calf', sex: 'cow' }, { w: 76, h: 72 })}${cowSVG({ breed: k, age: 'calf', sex: 'bull', pose: 'side' }, { w: 96, h: 72, pose: 'side' })}</div>
      <b>${o.name}　${spMark(true)}</b><span>${useName(o.use)}・${o.look}</span></div>`;
  };
  return `<div class="lineup" style="grid-template-columns:repeat(3, 1fr)">
    <div class="lu-head">三種特殊牛<small>上排母牛正面＋側面；下排公牛、母小牛、公小牛。同一個產生器加花紋和金色的角，名字、長相都原創</small></div>
    ${SP_KEYS.map(cell).join('')}
  </div>`;
}
// 圖鑑「其他」區：雜種牛（整排寬）＋特殊牛 3 格（發現了宙斯牛）
function codexOther(foundSp = ['zeus']) {
  const spCell = (k) => {
    const found = foundSp.includes(k);
    return `<button class="dex-cell${found ? '' : ' unknown'}"><span class="dex-pic">${cowSVG({ breed: k }, { w: 74, h: 64, pad: 3, sil: found ? false : 'dark' })}</span><span class="dex-name">${found ? breedName(k) : t('g.unknownBreed')}</span>${spMark(true)}</button>`;
  };
  const mixTile = `<button class="dex-cell dex-mix-tile"><span class="dm-pics">${USES.map((u) => cowSVG({ breed: MIX_LOOK[u] }, { w: 70, h: 62, pad: 2 })).join('')}</span><span class="dm-text"><span class="dex-name">${breedName(MIX_LOOK.dairy)}</span><span class="hint">${t('s09.mixBodies')}</span></span></button>`;
  const content = `<div class="stack">
    ${seg([t('subCodex'), t('subRank')], 0)}
    <article class="card dex-head"><div class="row" style="justify-content:space-between"><span class="card-title">${icon('book', 18)}${t('s09.found')}</span><b class="num dex-count">${FOUND.length} <small>/ 24</small></b></div>
      ${bar((FOUND.length / 24) * 100, { color: 'yellow', thick: true })}<p class="hint" style="margin-top:6px">${t('s09.hint')}</p></article>
    <div class="skip-note">乳牛、耕牛、肉牛 24 格（略）</div>
    <section><h3 class="sec-title"><span class="use">${t('s09.other')}</span><span class="hint">${t('s09.otherHint', { n: 24 })}</span></h3>
      <div class="dex-grid">${mixTile}${SP_KEYS.map(spCell).join('')}</div></section>
  </div>`;
  return frame(dev, { tab: 'records', content });
}
// 特殊牛的詳細：沒有配種表，改寫「在抓牛小遊戲遇到」；倍數 4.0（起點）
function spDetail(k, { found = true } = {}) {
  const o = SPECIAL[k];
  const pics = `<div class="dex-pics">${cowSVG({ breed: k, pose: 'side' }, { w: 160, h: 130, pose: 'side', sil: found ? false : 'dark' })}${found ? cowSVG({ breed: k }, { w: 130, h: 130 }) : ''}</div>`;
  const stats = [[t('s09.bestKg'), `${{ dairy: 250, draft: 450, beef: 800 }[o.use]} <small>${t('g.kg')}</small>`], [t('s09.mult'), '×4.0']];
  const how = `<article class="card"><div class="card-head"><span class="card-title orange">${GEM(16)}怎麼遇到</span></div><p class="hint" style="margin-top:6px;color:var(--ink)">在抓牛小遊戲遇到，很少出現。一出現就看得出來，不用等長大。</p>
    <p class="hint" style="margin-top:4px">特殊牛生的小牛照一般的遺傳，不會是特殊牛，所以沒有配種表。</p></article>`;
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${found ? o.name : t('g.unknownBreed')}</h1><div class="chips" style="margin-top:3px">${useChip(o.use)}${spMark()}${found ? '' : badge('lock', t('s09.notFoundYet'))}</div></div></div>
    <article class="card dex-hero sp-hero"><div class="hero-bg"></div>${pics}</article>
    ${found ? `<p class="dex-intro">${o.intro}</p><div class="kv">${stats.map(([a, val]) => `<div class="cell"><div class="k">${a}</div><div class="v num">${val}</div></div>`).join('')}</div>${how}
      <p class="hint">${t('s09.firstFound', { date: t('date.mdOnly', { m: 10, d: 4 }), n: 1 })}</p>` : how}
  </div>`;
  return frame(dev, { tab: 'records', content });
}
// 牧場裡：宙斯牛（公）在中間，點了跳出名片：稀有度的地方換成特殊牛的記號
function spRanch() {
  const zeus = { id: 30, breed: 'zeus', sex: 'bull', age: 'adult', kg: 812 };
  const herd = HERD.map((h) => (h.id === 7 ? { id: 30, breed: 'zeus', sex: 'bull', x: 296, y: 528, facing: 'left', depth: 2, pose: 'front' } : h));
  const html = popHtml(zeus).replace(/<span class="tier tier-\d">[\s\S]*?<\/span>/, spMark(true));
  return ranchPage0(herd, { id: 30, html });
}
const ranchPage0 = (herd, pop) => ranchPage(ctx0(), { herd, pop });
function r1504() {
  return board({
    id: 'R15-04-特殊牛-A-宙斯牛青牛聖白牛-390', title: '04 特殊牛 3 種：宙斯牛、青牛、聖白牛', width: boardWidth(4),
    sub: '只能在抓牛小遊戲遇到，抓到就知道是特殊牛；用途各一種，可以出貨、最值錢（倍數起點 4.0）。跟雜種牛一樣放在圖鑑最下面的「其他」，不算在 24 種裡（v0.3 第 13.3 節）。',
    top: specialLineup(),
    cells: [
      { cap: '圖鑑最下面「其他」', note: '雜種牛整排寬；特殊牛一格一種，發現以前是影子', html: codexOther() },
      { cap: '特殊牛的詳細（已發現）', note: '沒有配種表，改寫「在抓牛小遊戲遇到」', html: spDetail('zeus') },
      { cap: '特殊牛的詳細（還沒發現）', note: '影子＋怎麼遇到', html: spDetail('azure', { found: false }) },
      { cap: '牧場裡、點牛的名片', note: '宙斯牛（公）；稀有度的地方換成特殊牛的記號', html: spRanch() },
    ],
    notes: [
      '不畫任何宗教符號：宙斯牛是閃電紋、青牛的祥雲只當花紋、聖白牛是金色捲紋（額頭不加記號），也不畫光環、蓮花、太極這類圖案。名字照 ceo 和使用者定的。',
      '特殊牛的小牛（下排右邊兩頭）也是自己的花紋，一出現就看得出來；一般的小牛照舊是基本款，長大才揭曉。',
      '換頭像的「其他」那一排也放特殊牛（發現以後才能選）。',
    ],
  });
}

// ---------- 05 抓牛小遊戲（v0.3 第 13.4 節）：三個方向的分鏡 ----------
// 規則（起點）：每天免費 3 次（台灣時間 0 點重算）、牛舍要有空位；玩一次最多抓 1 頭；抓到的一般牛是小牛（長大才揭曉），
// 表現越好越可能是稀有以上；特殊牛很少出現（起點每次 0.5%），一出現就看得出來
let gid = 0;
// 場景裡的一頭牛（側面；母小牛加蝴蝶結）。回傳 svg 和臉、頭頂的位置
function critter(entry, x, y, s, facing = 'left') {
  const e = { pose: 'side', ...entry };
  const r = drawCow(e, { x, y, scale: s, facing, id: `g${gid++}` });
  return { svg: r.svg + (hasBow(e) ? calfBow(r, e.pose, facing).svg : ''), r };
}
const calfE = (use, sex) => ({ breed: CALF_LOOK[use], sex, age: 'calf' });
const SKY = { day: ['#BFE6FF', '#EAF7FF'], dusk: ['#46336E', '#F3A27C'], night: ['#18224A', '#4D3F80'], pm: ['#8FD0FF', '#FFF0C8'] };
const GRASS = { day: ['#A8E08A', '#84CB6C'], dusk: ['#93C47C', '#6EA25F'], night: ['#5B8E5C', '#477649'], pm: ['#B9E28C', '#8FCB66'] };
function field(mood, inner = '', horizon = 300) {
  const [s0, s1] = SKY[mood], [g0, g1] = GRASS[mood], w = dev.w, h = dev.h;
  const tufts = [[40, 420], [120, 560], [300, 470], [350, 640], [70, 700], [210, 760], [260, 380], [160, 470]].map(([x, y]) => `<path d="M${x - 6} ${y}q3-9 6 0q3-11 6 0" fill="none" stroke="${GRASS[mood][1]}" stroke-width="2.4" stroke-linecap="round"/>`).join('');
  return `<svg viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" aria-hidden="true"><defs><linearGradient id="gsky-${mood}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${s0}"/><stop offset="1" stop-color="${s1}"/></linearGradient><linearGradient id="ggr-${mood}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${g0}"/><stop offset="1" stop-color="${g1}"/></linearGradient></defs>
    <rect width="${w}" height="${horizon + 10}" fill="url(#gsky-${mood})"/><path d="M0 ${horizon}Q${w * 0.3} ${horizon - 26} ${w * 0.62} ${horizon - 8}T${w} ${horizon - 14}V${h}H0z" fill="url(#ggr-${mood})" stroke="${L}" stroke-width="2.4"/>${tufts}${inner}</svg>`;
}
// 上面那一條：關掉、遊戲名、今天還能玩幾次、倒數
function gameTop(title, { left = 2, time = '', meter = null } = {}) {
  return `<div class="g-top"><button class="icon-btn g-close" aria-label="關掉">${icon('close', 20)}</button><div class="g-title"><b>${title}</b><span>今天還能玩 ${left} 次</span></div>${time ? `<span class="g-time num">${icon('clock', 16)}${time}</span>` : ''}</div>
    ${meter != null ? `<div class="g-meter">${bar(meter, { color: 'yellow', thick: true })}</div>` : ''}`;
}
const gameFrame = (mood, inner, body, overlays = '') => frame(dev, { tab: null, hud: false, scene: field(mood, inner), body, overlays, dark: mood !== 'day' && mood !== 'pm' });
const hintPill = (s) => `<div class="g-hint">${s}</div>`;
// 開始前的說明卡
const startCard = (title, lines, pic) => `<div class="backdrop"></div><div class="reveal"><div class="card g-start"><div class="gs-pic">${pic}</div><b class="gs-name">${title}</b>
  <ul>${lines.map((s) => `<li>${s}</li>`).join('')}</ul><p class="hint">每天免費 3 次；牛舍要有空位才能開始</p>${btn('開始（今天還能玩 3 次）', { kind: 'primary', block: true })}</div></div>`;
// 抓到的結果
const CATCH = { id: 26, use: 'draft', sex: 'bull' };
const catchCard = (perf) => `<div class="backdrop"></div><div class="reveal"><div class="disc-title">抓到了！</div><div class="card catch-card">${cowSVG({ breed: CALF_LOOK[CATCH.use], sex: CATCH.sex, age: 'calf' }, { w: 170, h: 130 })}
  <b class="cc-name">${calfName(CATCH.use, CATCH.id)}</b><div class="chips">${useChip(CATCH.use)}<span class="use">${sexText(CATCH.sex)}</span>${badge('calf', t('stageCalf'))}</div>
  <p class="hint">${t('s04.calfUnknown')}</p><p class="cc-perf">${icon('sparkle', 16)}${perf}<br><span class="hint">表現越好，越可能長成稀有以上</span></p>${btn('帶回牧場', { kind: 'primary', block: true })}</div></div>`;
// 特殊牛出現（很少）：上面的橫幅
const spBanner = (k) => `<div class="sp-banner">${GEM(22)}<b>特殊牛出現了！</b><span>${SPECIAL[k].name}・${useName(SPECIAL[k].use)}</span></div>`;
const glow = (x, y, r) => `<circle cx="${x}" cy="${y}" r="${r}" fill="url(#spglow)"/>`;
const glowDefs = '<defs><radialGradient id="spglow"><stop offset="0" stop-color="#FFF6B8" stop-opacity="0.95"/><stop offset="0.55" stop-color="#FFE27A" stop-opacity="0.55"/><stop offset="1" stop-color="#FFE27A" stop-opacity="0"/></radialGradient></defs>';
const sparkles = (pts) => pts.map(([x, y, s]) => `<path d="M${x} ${y - s}Q${x + s * 0.2} ${y - s * 0.2} ${x + s} ${y}Q${x + s * 0.2} ${y + s * 0.2} ${x} ${y + s}Q${x - s * 0.2} ${y + s * 0.2} ${x - s} ${y}Q${x - s * 0.2} ${y - s * 0.2} ${x} ${y - s}Z" fill="#FFFFFF" stroke="#E7B53A" stroke-width="1.4"/>`).join('');
const dust = (x, y, d = 1) => `<g opacity="0.85"><circle cx="${x + d * 14}" cy="${y - 4}" r="6" fill="#F4E8D2"/><circle cx="${x + d * 24}" cy="${y - 8}" r="4.5" fill="#F4E8D2"/><circle cx="${x + d * 31}" cy="${y - 2}" r="3" fill="#F4E8D2"/></g>`;
const speed = (x, y, d = 1) => `<path d="M${x + d * 8} ${y - 30}h${d * 22}M${x + d * 4} ${y - 20}h${d * 30}M${x + d * 10} ${y - 10}h${d * 18}" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" opacity="0.9"/>`;
const finger = (x, y, s = 40) => `<div class="gesture" style="left:${f2(x - 13 * s / 32)}px;top:${f2(y - 2)}px">${POINTER(s)}</div>`;

// A 趕牛進柵欄：手指畫路線，把亂跑的牛趕進柵欄；越稀有的牛跑越快
function pen(x, y, w, h) {
  const posts = [];
  for (let i = 0; i <= 5; i++) posts.push([x + (w * i) / 5, y]);
  for (let i = 1; i <= 4; i++) posts.push([x + w, y + (h * i) / 4]);
  for (let i = 0; i <= 5; i++) posts.push([x + (w * i) / 5, y + h]);
  const rail = (y0) => `<path d="M${x} ${y0}H${x + w}" stroke="${L}" stroke-width="7" stroke-linecap="round"/><path d="M${x} ${y0}H${x + w}" stroke="#E2A56A" stroke-width="3.6" stroke-linecap="round"/>`;
  const side = (y0) => `<path d="M${x + w} ${y0}V${y0 + h}" stroke="${L}" stroke-width="7" stroke-linecap="round"/><path d="M${x + w} ${y0}V${y0 + h}" stroke="#E2A56A" stroke-width="3.6" stroke-linecap="round"/>`;
  return `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#C9E7A6" opacity="0.7"/>${rail(y - 14)}${rail(y)}${rail(y + h - 14)}${rail(y + h)}${side(-14 + y)}
    ${posts.map(([px, py]) => `<rect x="${px - 4}" y="${py - 24}" width="8" height="28" rx="3" fill="#C98E5E" stroke="${L}" stroke-width="2.2"/>`).join('')}
    <path d="M${x - 16} ${y + 26}l14 -10M${x - 16} ${y + h - 30}l14 10" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/>`;
}
const PEN_A = [206, 360, 160, 150];
function gameA(step) {
  const c1 = critter(calfE('draft', 'bull'), 112, 600, 1.2, 'right'), c2 = critter(calfE('dairy', 'cow'), 300, 700, 1.15, 'left'), c3 = critter(calfE('beef', 'cow'), 82, 450, 1.1, 'right');
  const base = pen(...PEN_A);
  const title = '趕牛進柵欄';
  if (step === 1) return gameFrame('day', base + c1.svg + c2.svg + c3.svg, gameTop(title, { left: 3 }), startCard(title, ['用手指在草地上畫一條路，把一頭小牛趕進柵欄。', '越快趕進去，表現越好。', '跑得特別快的小牛，比較可能長成稀有以上。'], `<svg viewBox="0 0 120 70" width="200" height="117">${pen(58, 18, 54, 44)}<path d="M14 58Q30 30 54 40" stroke="#FFFFFF" stroke-width="7" fill="none" stroke-linecap="round"/><path d="M14 58Q30 30 54 40" stroke="${L}" stroke-width="2" fill="none" stroke-dasharray="4 4"/></svg>`));
  if (step === 2) return gameFrame('day', base + dust(60, 452, -1) + c3.svg + dust(170, 602) + c1.svg + speed(312, 700) + dust(320, 702, 1) + c2.svg + sparkles([[352, 640, 7], [372, 668, 5]]), gameTop(title, { time: '0:17', meter: 85 }) + hintPill('牛會亂跑；閃閃發亮、跑很快的那頭比較可能是稀有'));
  if (step === 3) {
    const path = `M116 602C150 560 160 500 196 470S236 440 252 432`;
    return gameFrame('day', base + c3.svg + c2.svg + `<path d="${path}" stroke="#FFFFFF" stroke-width="18" fill="none" stroke-linecap="round" opacity="0.8"/><path d="${path}" stroke="${L}" stroke-width="3" fill="none" stroke-dasharray="8 7" stroke-linecap="round"/>` + c1.svg + `<path d="M246 418l14 12-17 6" fill="none" stroke="${L}" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/>`,
      gameTop(title, { time: '0:12', meter: 60 }) + hintPill('畫一條路：小牛會沿著路跑'), finger(252, 432));
  }
  if (step === 4) {
    const inPen = critter(calfE('draft', 'bull'), 290, 480, 1.05, 'right');
    return gameFrame('day', base + inPen.svg + c2.svg + c3.svg, gameTop(title, { time: '0:09', meter: 45 }), catchCard('表現：很好（8 秒就趕進去）'));
  }
  const sp = critter({ breed: 'zeus', sex: 'bull', age: 'calf' }, 140, 640, 1.3, 'right');
  return gameFrame('day', glowDefs + base + c3.svg + glow(140 - 6, 600, 104) + speed(70, 640, -1) + sp.svg + sparkles([[96, 560, 9], [196, 576, 7], [70, 610, 6], [210, 640, 6]]) + c2.svg, gameTop(title, { time: '0:20', meter: 100 }) + spBanner('zeus'));
}
// B 套圈圈：夜市套圈圈的玩法。小牛站在一個個草墊上不動，從下面往後拉、放開把圈圈丟出去（不是追著跑的牛甩繩子）
const MATS = [[86, 470, 'dairy', 'cow'], [196, 452, 'beef', 'bull'], [306, 470, 'draft', 'cow'], [140, 380, 'draft', 'bull'], [262, 376, 'dairy', 'bull']];
function lights() {
  const pts = [], bulbs = [];
  for (let i = 0; i <= 24; i++) { const x = (dev.w * i) / 24, y = 150 + 26 * Math.sin((Math.PI * i) / 12) ** 2; pts.push(`${f2(x)},${f2(y)}`); if (i % 2) bulbs.push([x, y + 8]); }
  const col = ['#FF8FB1', '#FFD45E', '#7CC4F0', '#8CD46F'];
  return `<path d="M${pts.join('L')}" stroke="#2A1F3D" stroke-width="2" fill="none"/>${bulbs.map(([x, y], i) => `<circle cx="${f2(x)}" cy="${f2(y)}" r="6" fill="${col[i % 4]}" stroke="#2A1F3D" stroke-width="1.6"/><circle cx="${f2(x)}" cy="${f2(y)}" r="12" fill="${col[i % 4]}" opacity="0.25"/>`).join('')}`;
}
const mat = (x, y, s = 1, gold = false) => `<ellipse cx="${x}" cy="${y + 4}" rx="${46 * s}" ry="${13 * s}" fill="${gold ? '#FFD45E' : '#F2CF73'}" stroke="${L}" stroke-width="2.4"/><ellipse cx="${x}" cy="${y + 2}" rx="${34 * s}" ry="${8 * s}" fill="none" stroke="${gold ? '#E7A93A' : '#D9A944'}" stroke-width="2"/>`;
const ring = (x, y, rx, ry, rot = 0) => `<g transform="rotate(${rot} ${x} ${y})"><ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="none" stroke="${L}" stroke-width="${f2(rx * 0.3)}"/><ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="none" stroke="#FF6B6B" stroke-width="${f2(rx * 0.2)}"/><ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="none" stroke="#FFFFFF" stroke-width="${f2(rx * 0.2)}" stroke-dasharray="${f2(rx * 0.5)} ${f2(rx * 0.5)}"/></g>`;
function matsScene(skip = -1, special = false) {
  return MATS.map(([x, y, u, sx], i) => {
    if (i === skip) return mat(x, y, i > 2 ? 0.8 : 1);
    const sp = special && i === 4;
    const c = critter(sp ? { breed: 'azure', sex: 'cow', age: 'calf' } : calfE(u, sx), x, y, i > 2 ? 0.92 : 1.15, i % 2 ? 'left' : 'right');
    return (sp ? glow(x, y - 30, 70) : '') + mat(x, y, i > 2 ? 0.8 : 1, sp) + c.svg;
  }).join('');
}
const ringsLeft = (n) => `<div class="g-rings">${[0, 1, 2].map((i) => `<svg viewBox="0 0 40 24" width="40" height="24" class="${i < n ? '' : 'used'}">${ring(20, 12, 15, 8)}</svg>`).join('')}</div>`;
function gameB(step) {
  const title = '套圈圈';
  const throwLine = `<path d="M30 690H360" stroke="#FFFFFF" stroke-width="4" stroke-dasharray="12 10" stroke-linecap="round" opacity="0.8"/>`;
  if (step === 1) return gameFrame('dusk', lights() + matsScene() + throwLine, gameTop(title, { left: 3 }), startCard(title, ['從下面的圈圈往後拉，放開就丟出去；拉越長丟越遠。', '圈圈套住小牛就抓到了。一次有 3 個圈圈。', '後排的小牛比較遠、比較難套，比較可能長成稀有以上。'], `<svg viewBox="0 0 120 70" width="200" height="117"><ellipse cx="60" cy="52" rx="30" ry="8" fill="#F2CF73" stroke="${L}" stroke-width="2"/>${ring(60, 34, 24, 9, -6)}<path d="M60 24V6" stroke="${L}" stroke-width="2" stroke-dasharray="3 3"/></svg>`));
  if (step === 2) {
    const arc = 'M195 730Q200 520 262 392';
    return gameFrame('dusk', lights() + matsScene() + throwLine + `<path d="${arc}" stroke="#FFFFFF" stroke-width="4" fill="none" stroke-dasharray="2 12" stroke-linecap="round"/>` + `<circle cx="262" cy="384" r="30" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-dasharray="6 6"/>` + ring(195, 760, 34, 14) + `<path d="M195 744V700" stroke="#FFFFFF" stroke-width="3" stroke-dasharray="4 5"/>`,
      gameTop(title, { time: '0:25' }) + ringsLeft(3) + hintPill('往下拉：虛線是會丟到哪裡'), finger(214, 772));
  }
  if (step === 3) return gameFrame('dusk', lights() + matsScene() + throwLine + `<path d="M195 730Q200 520 236 450" stroke="#FFFFFF" stroke-width="6" fill="none" stroke-linecap="round" opacity="0.5"/>` + ring(240, 452, 26, 10, -10), gameTop(title, { time: '0:23' }) + ringsLeft(2) + hintPill('放開：圈圈飛出去'));
  if (step === 4) return gameFrame('dusk', lights() + matsScene() + ring(262, 344, 20, 7, -8), gameTop(title, { time: '0:22' }) + ringsLeft(2), catchCard('表現：很好（後排、第 1 個圈圈就套中）'));
  return gameFrame('dusk', glowDefs + lights() + matsScene(-1, true) + throwLine + sparkles([[230, 300, 8], [300, 316, 6], [250, 340, 5]]) + ring(195, 760, 34, 14), gameTop(title, { time: '0:30' }) + ringsLeft(3) + spBanner('azure'));
}
// C UFO 光束：左右拖動小飛碟，按住放出光束把小牛吸上來；小牛會掙扎，光束要一直對準
function ufo(x, y, s = 1) {
  const k = (v) => f2(v * s);
  return `<g transform="translate(${x} ${y})"><ellipse cx="0" cy="${k(-10)}" rx="${k(26)}" ry="${k(22)}" fill="#C9F0FF" stroke="${L}" stroke-width="2.6" opacity="0.95"/><path d="M${k(-12)} ${k(-20)}q${k(6)}-${k(8)} ${k(14)}-${k(6)}" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" fill="none"/>
    <ellipse cx="0" cy="${k(6)}" rx="${k(62)}" ry="${k(18)}" fill="#D7DEEA" stroke="${L}" stroke-width="2.6"/><ellipse cx="0" cy="${k(2)}" rx="${k(44)}" ry="${k(8)}" fill="#EEF2F8"/>
    ${[-40, -20, 0, 20, 40].map((dx, i) => `<circle cx="${k(dx)}" cy="${k(12)}" r="${k(4.6)}" fill="${['#FFD45E', '#FF8FB1', '#8CD46F', '#7CC4F0', '#FFD45E'][i]}" stroke="${L}" stroke-width="1.6"/>`).join('')}</g>`;
}
const stars = () => [[30, 60], [90, 110], [160, 50], [240, 90], [330, 60], [360, 140], [60, 200], [300, 210], [200, 160]].map(([x, y], i) => `<circle cx="${x}" cy="${y}" r="${i % 3 ? 1.6 : 2.4}" fill="#FFFFFF" opacity="0.85"/>`).join('') + `<circle cx="330" cy="250" r="22" fill="#FFF3C4"/><circle cx="340" cy="244" r="20" fill="#4D3F80"/>`;
const beam = (x, y0, y1, w0, w1) => `<path d="M${x - w0} ${y0}L${x + w0} ${y0}L${x + w1} ${y1}L${x - w1} ${y1}Z" fill="#FFF3A6" opacity="0.55"/><ellipse cx="${x}" cy="${y1}" rx="${w1}" ry="${w1 * 0.22}" fill="#FFF3A6" opacity="0.7"/>`;
function gameC(step) {
  const title = 'UFO 吸牛';
  const herd = [critter(calfE('beef', 'bull'), 80, 640, 1.2, 'right'), critter(calfE('dairy', 'cow'), 300, 600, 1.15, 'left'), critter(calfE('draft', 'cow'), 220, 740, 1.2, 'left')];
  if (step === 1) return gameFrame('night', stars() + herd.map((c) => c.svg).join('') + ufo(195, 330), gameTop(title, { left: 3 }), startCard(title, ['左右拖動小飛碟，對準一頭小牛。', '按住放出光束，把小牛吸上來；小牛會掙扎，光束要一直對準。', '掙扎得特別厲害的小牛，比較可能長成稀有以上。'], `<svg viewBox="0 0 120 80" width="200" height="133">${beam(60, 28, 72, 10, 26)}${ufo(60, 22, 0.6)}</svg>`));
  if (step === 2) return gameFrame('night', stars() + herd.map((c) => c.svg).join('') + ufo(150, 330) + `<path d="M84 400h-40M216 400h40" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/><path d="M52 388l-14 12 14 12M248 388l14 12-14 12" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>`,
    gameTop(title, { time: '0:25' }) + hintPill('左右拖動小飛碟'), finger(150, 420));
  if (step === 3) {
    const lifted = critter(calfE('dairy', 'cow'), 300, 510, 1.15, 'left');
    return gameFrame('night', stars() + herd[0].svg + herd[2].svg + beam(300, 350, 610, 30, 64) + `<path d="M246 440q-8 8 0 16M354 440q8 8 0 16M240 470q-8 8 0 16M360 470q8 8 0 16" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round"/>` + lifted.svg + ufo(300, 330),
      gameTop(title, { time: '0:18', meter: 62 }) + hintPill('按住不放：小牛在掙扎，跟著左右移'), finger(300, 772));
  }
  if (step === 4) return gameFrame('night', stars() + herd[0].svg + herd[2].svg + ufo(300, 330), gameTop(title, { time: '0:15', meter: 100 }), catchCard('表現：很好（一次就吸上來）'));
  const sp = critter({ breed: 'holyWhite', sex: 'cow', age: 'calf' }, 196, 640, 1.3, 'right');
  return gameFrame('night', glowDefs + stars() + herd[0].svg + glow(196, 610, 90) + sp.svg + sparkles([[150, 560, 8], [250, 572, 7], [130, 620, 5], [262, 620, 6]]) + herd[2].svg + ufo(196, 330), gameTop(title, { time: '0:30' }) + spBanner('holyWhite'));
}
const V5 = {
  A: { name: '趕牛進柵欄', file: '趕牛進柵欄', title: '手指畫路線，把亂跑的小牛趕進柵欄', fn: gameA, mood: '白天的草地；畫路線的手感像畫畫，最直覺。', diff: '' },
  B: { name: '套圈圈', file: '套圈圈', title: '夜市套圈圈：往後拉、放開丟圈圈，套住站著的小牛', fn: gameB, mood: '黃昏的夜市，上面一串彩色燈泡。', diff: '跟別的遊戲甩繩子套「追著跑的動物」不一樣：小牛站在草墊上不動，比的是瞄準和力道（往後拉的長度），畫面是台灣夜市的套圈圈攤位（Apple 4.1）。' },
  C: { name: 'UFO 光束', file: 'UFO光束', title: '開小飛碟，按住光束把小牛吸上來', fn: gameC, mood: '晚上的牧場，星星和月亮。', diff: '' },
};
const STEP = [
  ['1 開始前的說明', '一張卡說明玩法；按「開始」才扣次數'],
  ['2 玩的時候', ''],
  ['3 關鍵的操作', ''],
  ['4 抓到了', '抓到的是小牛，長大才揭曉；表現越好，越可能是稀有以上'],
  ['5 很少：特殊牛出現', '起點每次 0.5%；一出現就看得出來（金光、橫幅）'],
];
const STEP_NOTE = {
  A: ['', '小牛在草地上亂跑；閃閃發亮、跑很快的比較可能是稀有', '手指畫一條路，小牛沿著路跑進柵欄', '', ''],
  B: ['', '往下拉圈圈：虛線是會丟到哪裡、圓圈是落點', '放開：圈圈沿著弧線飛出去', '', ''],
  C: ['', '左右拖動小飛碟對準', '按住放光束；小牛掙扎左右跑，要跟著移；上面的條是吸力', '', ''],
};
function r1505(v) {
  const o = V5[v];
  return board({
    id: `R15-05-抓牛小遊戲-${v}-${o.file}-390`, title: `05 抓牛小遊戲　${v}：${o.title}`, width: boardWidth(5),
    sub: '商店以外抓牛的地方（v0.3 第 13.4 節）。每天免費 3 次、牛舍要有空位；玩一次最多抓 1 頭；很少會出現特殊牛。下面是分鏡（一格一個時間點）。',
    cells: STEP.map(([cap, note], i) => ({ cap, note: STEP_NOTE[v][i] || note, html: o.fn(i + 1) })),
    notes: [
      `畫面：${o.mood}${o.diff ? ` ${o.diff}` : ''}`,
      '一局約 20–30 秒。入口放哪裡（商店的分頁或牧場頁的按鈕）、時間到沒抓到的畫面、動畫，選好方向以後再畫。',
    ],
  });
}

// ---------- 總覽：五項都要選，每項一排、選項並排 ----------
function r1599() {
  const S = 0.5, sw = Math.round(dev.w * S), sh = Math.round(dev.h * S);
  const mini = (html) => `<div class="ov-ph" style="width:${sw}px;height:${sh}px"><div style="transform:scale(${S});transform-origin:0 0">${html}</div></div>`;
  const cell = (cap, inner, sub = '') => `<div class="ov-cell"><div class="ov-cap"><b>${cap}</b>${sub ? `<span class="ov-sub">${sub}</span>` : ''}</div>${inner}</div>`;
  const legend = (v) => `<div class="ov-legend">${[0, 1, 2, 3].map((n) => `<span>${starChip(n, v, 14)}</span>`).join('')}</div>`;
  const rows = [
    ['01 小牛卡片：直接寫要吃哪幾種（選一個版面）', Object.keys(V1).map((v) => cell(`${v}　${V1[v].name}`, `<div class="ov-pair">${mini(calfPage(CALVES[15], v))}${mini(listPage(rows01(v)))}</div>`))],
    ['02 稀有度星星（一般、優良、稀有、傳說）', Object.keys(V2).map((v) => cell(`${v}　${V2[v].name}`, `${legend(v)}${mini(swapTiers(stateHtml('S09-02'), v))}`))],
    ['03 圖鑑的配種表', Object.keys(V3).map((v) => cell(`${v}　${V3[v].name}`, mini(codexDetail(v, { top: false }))))],
    ['04 特殊牛 3 種（不用選，看樣子）', [cell('宙斯牛、青牛、聖白牛', `<div class="ov-sp">${SP_KEYS.map((k) => `<span>${cowSVG({ breed: k }, { w: 150, h: 140 })}<b>${SPECIAL[k].name}</b></span>`).join('')}</div>`)]],
    ['05 抓牛小遊戲（選一個方向）', Object.keys(V5).map((v) => cell(`${v}　${V5[v].name}`, `<div class="ov-pair">${mini(V5[v].fn(3))}${mini(V5[v].fn(4))}</div>`))],
  ];
  const body = rows.map(([title, cs]) => `<div class="ov-row"><div class="ov-title">${title}</div><div class="ov-cells">${cs.join('')}</div></div>`).join('');
  return { html: `<div class="board" style="width:${PAD * 2 + 8 * sw + 7 * 28 + 4 * 14}px"><div class="b-label">R15-99-總覽對照</div><div class="b-title">第 15 輪：小牛卡片、星星、配種表、特殊牛、抓牛小遊戲</div>
    <div class="b-sub">01、02、03、05 各選一個；04 是特殊牛的樣子。各自的大圖見 R15-01～05。</div>${body}</div>` };
}

// ================= 第 17 輪 =================
// 原野：下午的開闊草原，遠處的山丘和樹；小牛往不同方向自由跑（會轉彎、停一下、再跑）
function prairie(inner = '') {
  const hills = `<path d="M-10 318Q70 268 150 300T320 286T420 300V340H-10Z" fill="#A7D88A" stroke="${L}" stroke-width="2"/><path d="M-10 330Q110 300 220 326T420 318V360H-10Z" fill="#9CD37E" opacity="0.9"/>`;
  const treeAt = (x, y, r) => `<rect x="${x - 3}" y="${y - 2}" width="6" height="14" rx="2" fill="#C98E5E" stroke="${L}" stroke-width="2"/><circle cx="${x}" cy="${y - r}" r="${r}" fill="#7CC86A" stroke="${L}" stroke-width="2.2"/>`;
  const sun = `<circle cx="340" cy="262" r="28" fill="#FFE07A" opacity="0.55"/><circle cx="340" cy="262" r="18" fill="#FFD45E" stroke="${L}" stroke-width="2.2"/>`;
  const flowers = [[60, 470], [312, 430], [150, 560], [348, 600], [40, 650], [250, 690]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="3.4" fill="#FFFFFF" stroke="${L}" stroke-width="1.2"/><circle cx="${x}" cy="${y}" r="1.4" fill="#FFD45E"/>`).join('');
  return sun + hills + treeAt(40, 300, 16) + treeAt(78, 306, 11) + treeAt(356, 296, 14) + flowers + inner;
}
// 小牛跑過的路（虛線，會轉彎）＋前面的方向箭頭；pts 由舊到新
function trail(pts) {
  const d = `M${pts.map(([x, y]) => `${x} ${y}`).join('L')}`;
  const [x1, y1] = pts[pts.length - 1], [x0, y0] = pts[pts.length - 2], a = Math.atan2(y1 - y0, x1 - x0);
  const ah = (k) => [x1 + 9 * Math.cos(a + k), y1 + 9 * Math.sin(a + k)];
  return `<path d="${d}" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-dasharray="2 8" stroke-linecap="round" stroke-linejoin="round" opacity="0.95"/><path d="M${ah(2.5).map(f2).join(' ')}L${x1} ${y1}L${ah(-2.5).map(f2).join(' ')}" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>`;
}
// 四頭小牛：目標（小耕牛 #26）往右跑、乳牛往左轉彎、肉牛停下來、另一頭乳牛往前跑
const TARGET = [262, 520];
function roamers({ target = true } = {}) {
  const items = [
    { e: calfE('dairy', 'cow'), x: 96, y: 448, s: 0.9, f: 'left', trail: [[200, 470], [170, 440], [130, 452]] },
    { e: calfE(CATCH.use, CATCH.sex), x: TARGET[0], y: TARGET[1], s: 1.1, f: 'right', trail: [[150, 560], [190, 520], [228, 528]], dust: true },
    { e: calfE('beef', 'cow'), x: 300, y: 418, s: 0.85, f: 'left', pause: true },
    { e: calfE('dairy', 'bull'), x: 118, y: 600, s: 1.15, f: 'right', trail: [[40, 640], [70, 600], [92, 612]] },
  ];
  return items.map((it, i) => {
    if (!target && i === 1) return '';
    const c = critter(it.e, it.x, it.y, it.s, it.f);
    const pause = it.pause ? `<g transform="translate(${it.x + 24} ${it.y - 74})"><circle r="11" fill="#FFFFFF" stroke="${L}" stroke-width="2"/><circle cx="-4.5" r="1.8" fill="${L}"/><circle r="1.8" fill="${L}"/><circle cx="4.5" r="1.8" fill="${L}"/></g>` : '';
    return (it.trail ? trail(it.trail) : '') + (it.dust ? dust(it.x - 40, it.y + 2, -1) : '') + c.svg + pause;
  }).join('');
}
// 手套（皮革色），(x, y) 是手掌中心；rot 轉幾度
const glove = (x, y, s = 1, rot = 0) => `<g transform="translate(${x} ${y}) rotate(${rot}) scale(${s})"><path d="M-14 6C-16 -6 -14 -16 -6 -18C-2 -26 8 -24 9 -16C16 -16 18 -6 16 2C15 12 8 16 -2 16C-9 16 -13 12 -14 6Z" fill="#D9A066" stroke="${L}" stroke-width="2.4" stroke-linejoin="round"/><path d="M-6 -18C-6 -10 -4 -6 0 -4M9 -16C6 -10 4 -8 2 -6" fill="none" stroke="${L}" stroke-width="1.8" stroke-linecap="round"/><rect x="-14" y="12" width="26" height="10" rx="4" fill="#B5733A" stroke="${L}" stroke-width="2.2"/></g>`;
// 繩子（兩層線）
const rope = (d, w = 3.4) => `<path d="${d}" fill="none" stroke="${L}" stroke-width="${w + 2.6}" stroke-linecap="round" stroke-linejoin="round"/><path d="${d}" fill="none" stroke="#D8A66A" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`;
const loopAt = (x, y, r, spin = true) => {
  const d = `M${f2(x - r)} ${f2(y)}a${f2(r)} ${f2(r * 0.36)} 0 1 0 ${f2(2 * r)} 0a${f2(r)} ${f2(r * 0.36)} 0 1 0 ${f2(-2 * r)} 0`;
  const arcs = spin ? `<path d="M${f2(x - r - 12)} ${f2(y - 6)}q${f2(r * 0.4)} ${f2(-r * 0.46)} ${f2(r)} ${f2(-r * 0.44)}M${f2(x + r + 12)} ${f2(y + 6)}q${f2(-r * 0.4)} ${f2(r * 0.46)} ${f2(-r)} ${f2(r * 0.44)}" fill="none" stroke="#FFFFFF" stroke-width="3.2" stroke-linecap="round" opacity="0.95"/>` : '';
  return rope(d, 3.6) + arcs;
};
// 圈的大小：一條橫的量尺，中間綠色是「剛好」（第 16 輪）
const sizeMeter = (k, label = '圈的大小') => `<div class="lz-meter"><span>${label}</span><div class="lz-bar"><i class="lz-ok"></i><b style="left:${f2(k * 100)}%"></b></div><div class="lz-ticks"><em>太小</em><em>剛好</em><em>太大</em></div></div>`;
const lzMeter = (k) => sizeMeter(k).replace('class="lz-meter"', 'class="lz-meter top"');
const hintLow = (s) => hintPill(s).replace('class="g-hint"', 'class="g-hint low"');
// ================= 第 18 輪：牛仔套索重新設計（只有繩索，不畫人、不畫手） =================
// 使用者看第 17 輪：「連手都不要，只要繩索。不過你在重新設計幾版 這一款我不是很滿意」。4 版的看法、丟法、小牛怎麼跑、套到以後都不一樣。
const meter = (k, label, ticks, cls = '') => `<div class="lz-meter ${cls}"><span>${label}</span><div class="lz-bar"><i class="lz-ok"></i><b style="left:${f2(k * 100)}%"></b></div><div class="lz-ticks">${ticks.map((x) => `<em>${x}</em>`).join('')}</div></div>`;
const pullBar = (k, label) => `<div class="pull-bar"><span>${label}</span><div class="pb"><i style="width:${Math.round(k * 100)}%"></i></div><b class="num">${Math.round(k * 100)}%</b></div>`;
const bigCue = (txt, cls = '') => `<div class="big-cue ${cls}">${txt}</div>`;
const sceneFrame = (svg, body, overlays = '') => frame(dev, { tab: null, hud: false, scene: `<svg viewBox="0 0 ${dev.w} ${dev.h}" width="${dev.w}" height="${dev.h}" aria-hidden="true">${svg}</svg>`, body, overlays });
// 繩子從畫面下緣（看不到的人手上）拉出來，接到一個繩圈
const ropeFrom = (x0, y0, x1, y1, bend = 40) => rope(`M${x0} ${y0}Q${(x0 + x1) / 2 + bend} ${(y0 + y1) / 2} ${x1} ${y1}`);
const loopOn = (x, y, r) => loopAt(x, y, r, false);
// 一頭小牛被套住：繩圈在脖子上、繩子拉緊
const lassoed = (x, y, r, from) => loopOn(x, y, r) + ropeFrom(from[0], from[1], x + r * 0.8, y + r * 0.2, 0);
// 地面（從上往下看）：整片草地、深淺不同的草塊、小花、一條小土路
function meadow(inner = '', tint = ['#B6E08C', '#9CD27A']) {
  const patches = [[60, 300, 70, 40], [300, 380, 90, 46], [120, 560, 110, 50], [330, 650, 70, 36], [60, 760, 80, 40]].map(([x, y, rx, ry]) => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="${tint[1]}" opacity="0.7"/>`).join('');
  const tufts = [[40, 420], [120, 330], [300, 470], [350, 560], [70, 650], [210, 760], [260, 300], [180, 470], [330, 760]].map(([x, y]) => `<path d="M${x - 6} ${y}q3-9 6 0q3-11 6 0" fill="none" stroke="#7DB85E" stroke-width="2.4" stroke-linecap="round"/>`).join('');
  const flowers = [[90, 380], [250, 420], [320, 300], [150, 690], [280, 720], [40, 560]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="3.4" fill="#FFFFFF" stroke="${L}" stroke-width="1.2"/><circle cx="${x}" cy="${y}" r="1.4" fill="#FFD45E"/>`).join('');
  return `<rect width="${dev.w}" height="${dev.h}" fill="${tint[0]}"/>${patches}<path d="M-10 880C80 700 300 650 420 520" fill="none" stroke="#E6CC92" stroke-width="30" stroke-linecap="round" opacity="0.8"/>${tufts}${flowers}${inner}`;
}
// 側面（橫向）：天空、遠山、一排遠處的柵欄、地面
function sideField(inner = '', scroll = true) {
  const sky = `<rect width="${dev.w}" height="${dev.h}" fill="#BFE6FF"/><rect y="380" width="${dev.w}" height="${dev.h - 380}" fill="#B6E08C"/>`;
  const hills = `<path d="M-10 380Q60 330 140 360T300 344T420 362V390H-10Z" fill="#A7D88A" stroke="${L}" stroke-width="2"/>`;
  const fence = Array.from({ length: 9 }, (_, i) => `<rect x="${i * 50 + 6}" y="392" width="6" height="26" rx="2" fill="#C98E5E" stroke="${L}" stroke-width="1.6"/>`).join('') + `<path d="M0 400H390M0 410H390" stroke="#C98E5E" stroke-width="4"/>`;
  const ground = `<path d="M0 640H390" stroke="#9CD27A" stroke-width="40" opacity="0.6"/>` + [[30, 600], [120, 660], [220, 610], [330, 670], [80, 720], [280, 740]].map(([x, y]) => `<path d="M${x - 6} ${y}q3-9 6 0q3-11 6 0" fill="none" stroke="#7DB85E" stroke-width="2.4" stroke-linecap="round"/>`).join('');
  const arrows = scroll ? `<g opacity="0.85">${[[40, 560], [150, 545], [260, 560]].map(([x, y]) => `<path d="M${x} ${y}h40M${x + 30} ${y - 8}l10 8-10 8" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>`).join('')}</g>` : '';
  return sky + `<circle cx="330" cy="250" r="22" fill="#FFD45E" stroke="${L}" stroke-width="2.2"/>` + hills + fence + ground + arrows + inner;
}
// 往前看（透視）：地平線在上面，草地往遠處收窄；遠處的牛小、近處的牛大
function perspective(inner = '') {
  const horizon = 330;
  const rays = [-260, -150, -60, 30, 120, 210, 300, 420, 540, 650].map((x) => `<path d="M195 ${horizon}L${x} ${dev.h}" stroke="#A8D884" stroke-width="2" opacity="0.8"/>`).join('');
  const bands = [380, 440, 520, 620, 740].map((y) => `<path d="M0 ${y}H390" stroke="#A8D884" stroke-width="2" opacity="0.6"/>`).join('');
  const tree = (x, y, r) => `<rect x="${x - 2}" y="${y - 2}" width="4" height="10" rx="2" fill="#C98E5E" stroke="${L}" stroke-width="1.4"/><circle cx="${x}" cy="${y - r}" r="${r}" fill="#7CC86A" stroke="${L}" stroke-width="1.8"/>`;
  return `<rect width="${dev.w}" height="${horizon}" fill="#BFE6FF"/><circle cx="300" cy="220" r="20" fill="#FFD45E" stroke="${L}" stroke-width="2.2"/><path d="M-10 ${horizon}Q100 ${horizon - 24} 200 ${horizon - 8}T420 ${horizon - 10}V${horizon + 8}H-10Z" fill="#A7D88A" stroke="${L}" stroke-width="2"/>
    <rect y="${horizon}" width="${dev.w}" height="${dev.h - horizon}" fill="#B6E08C"/>${rays}${bands}${tree(60, horizon - 6, 9)}${tree(340, horizon - 4, 8)}${inner}`;
}
// 草叢（從上往下看的高草）：一叢一叢，被小牛擋住時會搖
function grassClump(x, y, s = 1, shake = false) {
  const blades = [-28, -16, -4, 8, 20, 30].map((dx, i) => `<path d="M${x + dx * s} ${y}q${(i % 2 ? 6 : -6) * s} ${-34 * s} ${(i % 2 ? 10 : -4) * s} ${(-58 - (i % 3) * 8) * s}" fill="none" stroke="${L}" stroke-width="${5.4 * s}" stroke-linecap="round"/><path d="M${x + dx * s} ${y}q${(i % 2 ? 6 : -6) * s} ${-34 * s} ${(i % 2 ? 10 : -4) * s} ${(-58 - (i % 3) * 8) * s}" fill="none" stroke="${i % 2 ? '#7CC86A' : '#94D876'}" stroke-width="${3 * s}" stroke-linecap="round"/>`).join('');
  const marks = shake ? `<path d="M${x - 42 * s} ${y - 56 * s}q-9 9 0 18M${x - 52 * s} ${y - 62 * s}q-12 15 0 30M${x + 44 * s} ${y - 56 * s}q9 9 0 18M${x + 54 * s} ${y - 62 * s}q12 15 0 30" fill="none" stroke="#FFFFFF" stroke-width="3.4" stroke-linecap="round"/>` : '';
  return `<ellipse cx="${x}" cy="${y + 2}" rx="${40 * s}" ry="${8 * s}" fill="#7DB85E" opacity="0.5"/>${blades}${marks}`;
}
// 手指往上滑的軌跡（白色漸細的線＋箭頭）
const swipe = (x0, y0, x1, y1) => `<path d="M${x0} ${y0}L${x1} ${y1}" stroke="#FFFFFF" stroke-width="14" stroke-linecap="round" opacity="0.55"/><path d="M${x0} ${y0}L${x1} ${y1}" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/><path d="M${x1 - 12} ${y1 + 6}L${x1} ${y1}L${x1 - 2} ${y1 + 13}" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>`;
const tapRings = (x, y) => `<div class="ripple" style="left:${x}px;top:${y}px"></div><div class="ripple r2" style="left:${x}px;top:${y}px"></div>`;
const T18 = '牛仔套索';

// ---------- A 從上往下看：一群小牛一起跑，手指一滑丟出去，套到以後連點拔河 ----------
function herd(dx = 0, shiny = false) {
  const pos = [[150, 430, 'dairy', 'cow', 1], [210, 470, 'beef', 'bull', 1.05], [118, 500, 'draft', 'cow', 0.95], [250, 410, 'dairy', 'bull', 0.95], [184, 540, 'beef', 'cow', 1], [280, 500, CATCH.use, CATCH.sex, 1.1]];
  return dust(110 + dx, 520, -1) + dust(130 + dx, 455, -1) + pos.map(([x, y, u, sx, s]) => critter(calfE(u, sx), x + dx, y, s, 'right').svg).join('') + speed(80 + dx, 470, -1) + speed(96 + dx, 530, -1) + (shiny ? sparkles([[318 + dx, 452, 7], [336 + dx, 486, 5], [252 + dx, 470, 5]]) : '');
}
function lzA(step) {
  const target = [304, 470];
  if (step === 1) return sceneFrame(meadow(herd(-40)) + loopOn(195, 790, 30), gameTop(T18, { left: 3 }), startCard(T18, ['一群小牛在草地上一起跑。', '手指從下面的繩圈往一頭小牛的方向一滑，繩圈就飛出去；小牛會往前跑，要往牠前面一點丟。', '套到以後連點畫面拉繩子，拉滿就抓到了。'], `<svg viewBox="0 0 120 70" width="200" height="117"><rect width="120" height="70" fill="#B6E08C"/>${swipe(60, 64, 88, 20)}<g transform="translate(-10 -10) scale(0.5)">${loopOn(120, 130, 26)}</g></svg>`));
  if (step === 2) return sceneFrame(meadow(herd(0, true)) + loopOn(195, 790, 30), gameTop(T18, { time: '0:24' }) + hintPill('閃閃發亮的那頭比較可能是稀有'));
  if (step === 3) return sceneFrame(meadow(herd(16, true) + swipe(195, 780, 300, 520)) + loopOn(326, 452, 30) + ropeFrom(195, 860, 312, 470, -30), gameTop(T18, { time: '0:22' }) + hintPill('往小牛的方向一滑，繩圈飛出去'), finger(300, 520));
  if (step === 4) return sceneFrame(meadow(critter(calfE(CATCH.use, CATCH.sex), target[0], target[1] + 30, 1.25, 'right').svg + dust(target[0] + 40, target[1] + 30, 1) + lassoed(target[0] - 2, target[1] - 38, 22, [195, 860])), gameTop(T18, { time: '0:20' }) + pullBar(0.62, '拉繩子') + bigCue('連點！'), tapRings(195, 700) + finger(190, 704));
  return sceneFrame(meadow(lassoed(target[0] - 2, target[1] - 8, 22, [195, 860])), gameTop(T18, { time: '0:19' }), catchCard('表現：很好（3 秒就拉上來）'));
}

// ---------- B 側面、畫面往右捲：小牛一頭一頭從右邊衝過去，甩圈、在記號上放開，套到以後左右拉 ----------
function lzB(step) {
  const mark = `<g transform="translate(195 470)"><path d="M0 -28V-6" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/><path d="M-9 -14L0 -4 9 -14" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/></g>`;
  const runner = (x, s = 1.15) => critter(calfE(CATCH.use, CATCH.sex), x, 640, s, 'left').svg + dust(x + 42, 640, 1) + speed(x + 46, 610, 1);
  const spin = (r) => loopAt(150, 300, r) + rope(`M-10 220Q60 250 ${150 - r * 0.8} 304`);
  if (step === 1) return sceneFrame(sideField(critter(calfE('dairy', 'cow'), 300, 640, 1.1, 'left').svg) + spin(34), gameTop(T18, { left: 3 }), startCard(T18, ['畫面一直往右捲，小牛一頭一頭從右邊衝過來。', '按住甩繩圈；小牛跑到中間的白色記號下面時放開，繩圈就落下去。', '套到以後小牛會往左往右拉，手指往反方向拖，讓指針停在綠色。'], `<svg viewBox="0 0 120 70" width="200" height="117"><rect width="120" height="70" fill="#BFE6FF"/><rect y="40" width="120" height="30" fill="#B6E08C"/><g transform="translate(0 -20) scale(0.4)">${loopAt(150, 160, 30)}</g><path d="M60 26v10" stroke="#FFFFFF" stroke-width="3"/></svg>`));
  if (step === 2) return sceneFrame(sideField(runner(330) + mark) + spin(34), gameTop(T18, { time: '0:24' }) + hintPill('按住甩繩圈；小牛衝過來了'), finger(330, 790));
  if (step === 3) return sceneFrame(sideField(runner(200) + mark + `<path d="M150 330Q180 420 195 560" fill="none" stroke="#FFFFFF" stroke-width="3.4" stroke-dasharray="3 10" stroke-linecap="round"/>`) + loopAt(195, 560, 30, false) + rope('M-10 220Q120 300 172 566'), gameTop(T18, { time: '0:21' }) + hintPill('小牛到記號下面：放開！'));
  if (step === 4) return sceneFrame(sideField(critter(calfE(CATCH.use, CATCH.sex), 270, 640, 1.2, 'left').svg + dust(312, 640, 1) + lassoed(250, 598, 22, [-10, 300]), false), gameTop(T18, { time: '0:19' }) + meter(0.68, '繩子', ['往左拉', '剛好', '往右拉'], 'tug') + bigCue('⟵ 往左拉', 'left'), `<svg class="drag-hint" style="left:110px;top:716px" width="150" height="40" viewBox="0 0 150 40"><path d="M140 20H14M28 8L12 20l16 12" fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/></svg>` + finger(140, 760));
  return sceneFrame(sideField(lassoed(250, 610, 22, [-10, 300]), false), gameTop(T18, { time: '0:18' }), catchCard('表現：很好（第 1 頭就套中）'));
}

// ---------- C 往前看（透視）：小牛從遠處衝向你，經過地上的圈時往上滑，套到以後跟著節奏往下拉 ----------
function lzC(step) {
  const ring = `<ellipse cx="195" cy="560" rx="96" ry="26" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-dasharray="10 8"/>`;
  const far = critter(calfE('dairy', 'cow'), 150, 380, 0.45, 'right').svg + critter(calfE('beef', 'bull'), 250, 400, 0.55, 'left').svg;
  if (step === 1) return sceneFrame(perspective(far + ring) + loopOn(195, 790, 30), gameTop(T18, { left: 3 }), startCard(T18, ['小牛從遠處朝你衝過來，越來越大。', '牠的腳踩進地上的白色圈圈時，手指往上一滑，繩圈就丟出去；太早牠還很遠，太晚就衝過去了。', '套到以後照著畫面的「拉！」往下拉，停的時候不要拉。'], `<svg viewBox="0 0 120 70" width="200" height="117"><rect width="120" height="30" fill="#BFE6FF"/><rect y="30" width="120" height="40" fill="#B6E08C"/><path d="M60 30L10 70M60 30L110 70" stroke="#A8D884" stroke-width="1.4"/><ellipse cx="60" cy="52" rx="22" ry="6" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-dasharray="4 3"/></svg>`));
  if (step === 2) return sceneFrame(perspective(far + ring + frontCalf(195, 470, 0.7) + dust(170, 470, -1)) + loopOn(195, 790, 30), gameTop(T18, { time: '0:24' }) + hintPill('小牛衝過來了！踩進圈圈時往上滑'));
  if (step === 3) return sceneFrame(perspective(far + ring + frontCalf(195, 572, 0.95) + swipe(150, 790, 150, 650)) + loopOn(195, 520, 34) + ropeFrom(195, 860, 222, 528, 10), gameTop(T18, { time: '0:22' }) + hintPill('踩進圈圈了：往上滑！'), finger(151, 660));
  if (step === 4) return sceneFrame(perspective(far + frontCalf(195, 600, 1.05) + lassoed(195, 530, 26, [195, 860])), gameTop(T18, { time: '0:20' }) + pullBar(0.5, '拉近') + `<div class="beat"><i class="on"></i><i class="on"></i><i></i><i></i></div>` + bigCue('拉！⬇'), finger(196, 760));
  return sceneFrame(perspective(lassoed(195, 560, 26, [195, 860])), gameTop(T18, { time: '0:19' }), catchCard('表現：很好（一圈就套中）'));
}
// 正面的小牛（往前看的版本；正面朝著玩家跑過來）
const frontCalf = (x, y, s) => critter({ ...calfE(CATCH.use, CATCH.sex), pose: 'front' }, x, y, s, 'left').svg;

// ---------- D 從上往下看：小牛躲在草叢後面再冒出來，手指在冒出來的小牛周圍畫一圈，繩圈就落下去（不拔河） ----------
const CLUMPS = [[90, 420], [290, 400], [190, 540], [80, 640], [300, 660]];
function hideField({ pop = null, shake = [] } = {}) {
  return CLUMPS.map(([x, y], i) => {
    const c = pop === i ? critter(calfE(CATCH.use, CATCH.sex), x + 30, y + 6, 1.05, 'right').svg : '';
    const ears = i === 1 && pop !== 1 ? `<g transform="translate(${x + 4} ${y - 52})"><path d="M-12 0q-10-8-4-16q8 4 10 14z" fill="#C7813F" stroke="${L}" stroke-width="2"/><path d="M12 0q10-8 4-16q-8 4-10 14z" fill="#C7813F" stroke="${L}" stroke-width="2"/></g>` : '';
    return ears + grassClump(x, y, 1, shake.includes(i)) + c;
  }).join('');
}
function lzD(step) {
  const circle = (x, y) => `<ellipse cx="${x}" cy="${y}" rx="62" ry="44" fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" stroke-dasharray="320 60" opacity="0.95"/>`;
  if (step === 1) return sceneFrame(meadow(hideField({ shake: [0, 2] })), gameTop(T18, { left: 3 }), startCard(T18, ['小牛躲在草叢後面，草叢會搖、會露出耳朵。', '小牛冒出來的時候，用手指在牠周圍畫一圈，繩圈就飛過去套住。', '畫的圈要把小牛整個圍起來；牠一下子就會躲回去。'], `<svg viewBox="0 0 120 70" width="200" height="117"><rect width="120" height="70" fill="#B6E08C"/><g transform="translate(-30 -40) scale(0.5)">${grassClump(170, 150, 0.9)}</g><ellipse cx="80" cy="36" rx="22" ry="16" fill="none" stroke="#FFFFFF" stroke-width="2.4" stroke-dasharray="80 18"/></svg>`));
  if (step === 2) return sceneFrame(meadow(hideField({ shake: [0, 2] })), gameTop(T18, { time: '0:24' }) + hintPill('草叢在搖，露出耳朵：小牛躲在後面'));
  if (step === 3) return sceneFrame(meadow(hideField({ pop: 2 }) + circle(222, 520)), gameTop(T18, { time: '0:22' }) + hintPill('冒出來了！在牠周圍畫一圈'), finger(258, 486));
  if (step === 4) return sceneFrame(meadow(hideField({ pop: 2 }) + loopOn(222, 500, 40) + ropeFrom(195, 860, 254, 508, -20) + sparkles([[170, 470, 7], [280, 470, 6], [222, 430, 5]])), gameTop(T18, { time: '0:21' }) + bigCue('套住了！'));
  return sceneFrame(meadow(hideField({}) + lassoed(222, 520, 24, [195, 860])), gameTop(T18, { time: '0:20' }), catchCard('表現：很好（一冒出來就套中）'));
}

const V18 = {
  A: { name: '從上往下看、一群一起跑', file: '一群一起跑', fn: lzA,
    title: '從上往下看：一群小牛一起跑，手指一滑丟出去，套到以後連點拔河',
    fun: '好玩在哪裡：從一群裡挑出跑最快、閃閃發亮的那頭，還要算好往牠前面一點丟（像打移動靶）；最後連點拔河很過癮。',
    feel: '手感：一滑就丟，很直覺；連點的時候小牛會往外扯，數字一格一格往上跳。' },
  B: { name: '側面捲動、一頭一頭衝過來', file: '側面衝過來', fn: lzB,
    title: '側面、畫面往右捲：小牛一頭一頭從右邊衝過來，甩圈、在記號上放開，套到以後左右拉',
    fun: '好玩在哪裡：像節奏遊戲，小牛一頭一頭來、速度不一樣，抓準牠跑到記號下面的那一刻；拔河時要跟著牠左右換方向。',
    feel: '手感：按住甩圈、放開落下；拔河是左右拖，讓指針停在綠色，比較需要專心。' },
  C: { name: '往前看、從遠處衝向你', file: '往前看衝過來', fn: lzC,
    title: '往前看（透視）：小牛從遠處衝向你，踩進地上的圈時往上滑，套到以後跟著節奏往下拉',
    fun: '好玩在哪裡：小牛越衝越大，很有臨場感；太早丟牠還很遠、太晚牠就衝過去，抓那一瞬間很刺激。',
    feel: '手感：往上一滑丟出去；拔河是跟著畫面的「拉！」往下拉、停的時候放手，像打拍子。' },
  D: { name: '草叢捉迷藏、畫一圈', file: '草叢畫一圈', fn: lzD,
    title: '從上往下看：小牛躲在草叢後面再冒出來，手指在牠周圍畫一圈，繩圈飛過去套住（不拔河）',
    fun: '好玩在哪裡：像打地鼠加畫畫：看草叢在搖、露出耳朵，猜下一頭從哪裡冒出來；畫一圈就套到，最輕鬆。',
    feel: '手感：用手指畫圈，不用算力道；沒有拔河，一局最短，適合想快點玩完的時候。' },
};
const STEP18 = [
  ['1 開始前的說明', '一張卡說明玩法；按「開始」才扣次數'],
  ['2 玩的時候', ''],
  ['3 丟出去', ''],
  ['4 套到以後', ''],
  ['5 抓到了', '抓到的是小牛，長大才揭曉；表現越好，越可能是稀有以上'],
];
const NOTE18 = {
  A: ['', '六頭小牛一起往右跑；閃閃發亮的那頭比較可能是稀有；下面是繩圈', '手指往小牛前面一點滑，繩圈沿著滑的方向飛出去，繩子拖在後面', '套到了：連點畫面拉繩子，上面的條拉滿就抓到；小牛會往外扯', ''],
  B: ['', '畫面一直往右捲（白色箭頭）；繩圈在上面甩，中間的白色記號是落點', '小牛跑到記號下面時放開，繩圈沿虛線落下', '套到了：小牛往右拉，手指往左拖，讓指針停在綠色「剛好」', ''],
  C: ['', '小牛從遠處衝過來，越來越大；地上的白色虛線圈是丟的時機', '小牛的腳踩進圈圈時往上滑', '套到了：照著「拉！」往下拉（上面的點是節奏），停的時候放手', ''],
  D: ['', '草叢在搖、露出耳朵：小牛躲在後面', '小牛冒出來，手指在牠周圍畫一圈', '繩圈照著畫的圈飛過去套住，不用拔河', ''],
};
function r1801(v) {
  const o = V18[v];
  return board({
    id: `R18-01-抓牛小遊戲-${v}-${o.file}-390`, title: `01 牛仔套索　${v}：${o.title}`, width: boardWidth(5),
    sub: '使用者看第 17 輪：「連手都不要，只要繩索。不過你在重新設計幾版 這一款我不是很滿意」。畫面上只有繩索，不畫人、不畫手；4 版的看法、丟法、小牛怎麼跑、套到以後都不一樣。開闊的原野、白天，跟夜市套圈圈（黃昏）、UFO 光束（晚上）分開。',
    cells: STEP18.map(([cap, note], i) => ({ cap, note: NOTE18[v][i] || note, html: o.fn(i + 1) })),
    notes: [o.fun, o.feel, '四版都一樣：每天 3 次、一局抓 1 頭；很少會出現特殊牛（起點每次 0.5%），一出現就金光加橫幅（見總覽）。'],
  });
}
function r1899() {
  const S = 0.5, sw = Math.round(dev.w * S), sh = Math.round(dev.h * S);
  const mini = (html) => `<div class="ov-ph" style="width:${sw}px;height:${sh}px"><div style="transform:scale(${S});transform-origin:0 0">${html}</div></div>`;
  const cell = (cap, inner, sub = '') => `<div class="ov-cell"><div class="ov-cap"><b>${cap}</b>${sub ? `<span class="ov-sub">${sub}</span>` : ''}</div>${inner}</div>`;
  const rows = Object.keys(V18).map((v) => [`${v}　${V18[v].name}`, [cell('玩的時候 → 丟出去 → 套到以後', `<div class="ov-pair">${mini(V18[v].fn(2))}${mini(V18[v].fn(3))}${mini(V18[v].fn(4))}</div>`)]]);
  const sp = critter({ breed: 'zeus', sex: 'bull', age: 'calf' }, 280, 500, 1.3, 'right');
  const special = sceneFrame(glowDefs + meadow(herd(-60) + glow(280, 470, 96) + sp.svg + sparkles([[230, 400, 8], [330, 410, 7], [216, 450, 5]])) + loopOn(195, 790, 30), gameTop(T18, { time: '0:30' }) + spBanner('zeus'));
  rows.push(['四版都一樣：很少會出現特殊牛（金光、橫幅）', [cell('例：A 的畫面', mini(special))]]);
  const body = rows.map(([title, cs]) => `<div class="ov-row"><div class="ov-title">${title}</div><div class="ov-cells">${cs.join('')}</div></div>`).join('');
  return { html: `<div class="board" style="width:${PAD * 2 + 3 * sw + 2 * 14 + 28}px"><div class="b-label">R18-99-總覽對照</div><div class="b-title">第 18 輪：牛仔套索 4 個新版本（只有繩索）</div>
    <div class="b-sub">選一版；各自的 5 格分鏡見 R18-01-A～D。</div>${body}</div>` };
}

// ================= 第 18 輪 GIF：使用者喜歡 A 和 C，「i like A AND c,so you can show me gif」（ceo 2026-10-08 轉達） =================
// 兩個 GIF 用同一條時間線（8 秒、15 fps），方便比較：
//   0–2 秒小牛跑 → 1.8–2.2 手指滑 → 2.2–2.7 繩圈飛出去 → 2.9–6.1 拔河／拉 → 6.1–8 抓到了
const GT = { total: 8, swipe0: 1.8, swipe1: 2.2, land: 2.7, tug0: 2.9, tug1: 6.1 };
const clamp01 = (v) => Math.max(0, Math.min(1, v));
const lerp = (a, b, k) => a + (b - a) * k;
const easeOut = (k) => 1 - (1 - k) ** 2;
const easeIn = (k) => k * k;
const tseg = (t, a, b) => clamp01((t - a) / (b - a));
const clock = (t) => `0:${String(30 - Math.floor(t)).padStart(2, '0')}`;
// 跑的時候上下跳、身體微微晃（四隻腳不會動，用跳和晃表現在跑）
const runner = (entry, x, y, s, facing, t, ph = 0, amp = 4) => {
  const hop = Math.abs(Math.sin((t * 3.2 + ph) * Math.PI)) * amp * s;
  const tilt = Math.sin((t * 3.2 + ph) * Math.PI * 2) * 3 * (facing === 'right' ? 1 : -1);
  return `<g transform="translate(0 ${f2(-hop)}) rotate(${f2(tilt)} ${f2(x)} ${f2(y)})">${critter(entry, x, y, s, facing).svg}</g>`;
};
const puff = (x, y, t, ph, d = -1) => { const k = ((t * 2.5 + ph) % 1); return `<g opacity="${f2(0.9 * (1 - k))}"><circle cx="${f2(x + d * (10 + 26 * k))}" cy="${f2(y - 4 - 6 * k)}" r="${f2(4 + 5 * k)}" fill="#F4E8D2"/></g>`; };
const twinkle = (x, y, t) => sparkles([[x + 38, y - 48, 5 + 3 * Math.abs(Math.sin(t * 5))], [x + 54, y - 14, 3 + 3 * Math.abs(Math.sin(t * 5 + 1.3))], [x - 30, y - 36, 3 + 2 * Math.abs(Math.sin(t * 5 + 2.1))]]);
const fingerAt = (x, y, press = 0) => `<div class="gesture" style="left:${f2(x - 16)}px;top:${f2(y - 2 + press * 4)}px;transform:scale(${f2(1 - press * 0.08)})">${POINTER(40)}</div>`;
const swipeTrail = (x0, y0, x1, y1, k, fade = 1) => (k <= 0 || fade <= 0 ? '' : `<g opacity="${f2(fade)}">${swipe(x0, y0, lerp(x0, x1, k), lerp(y0, y1, k)).replace(/<path d="M[^"]*L[^"]*" fill="none"[^>]*\/>$/, '')}</g>`);
const pop = (t, t0) => { const k = tseg(t, t0, t0 + 0.32); const s = k < 0.7 ? lerp(0.6, 1.06, k / 0.7) : lerp(1.06, 1, (k - 0.7) / 0.3); return { s, o: clamp01(k * 2.5) }; };
function caught(t, perf) {
  if (t < GT.tug1) return '';
  const p = pop(t, GT.tug1 + 0.1);
  return catchCard(perf).replace('<div class="backdrop"></div>', `<div class="backdrop" style="opacity:${f2(clamp01((t - GT.tug1) / 0.25))}"></div>`)
    .replace('<div class="reveal">', `<div class="reveal" style="opacity:${f2(p.o)};transform:scale(${f2(p.s)})">`);
}
// 拉的進度：每一下連點（A）或每一拍（C）往上加，中間小牛會扯回去一點
const tapTimes = Array.from({ length: 15 }, (_, i) => GT.tug0 + 0.2 + i * 0.2);

// ---------- A 從上往下看：一群一起跑 ----------
function gifA(t) {
  const dx = -170 + 78 * Math.min(t, GT.land); // 一群往右跑
  const others = [[150, 430, 'dairy', 'cow', 1, 0.1], [210, 470, 'beef', 'bull', 1.05, 0.5], [118, 500, 'draft', 'cow', 0.95, 0.3], [250, 410, 'dairy', 'bull', 0.95, 0.8], [184, 540, 'beef', 'cow', 1, 0.65]];
  const after = Math.max(0, t - GT.land) * 150; // 套到以後其他小牛嚇得跑走
  let svg = others.map(([x, y, u, sx, s, ph]) => puff(x + dx + after - 30, y, t, ph) + runner(calfE(u, sx), x + dx + after, y, s, 'right', t, ph)).join('');
  // 目標：閃閃發亮的那頭（耕牛公小牛）
  const tx0 = 280 + dx, ty0 = 500;
  const tug = tseg(t, GT.tug0, GT.tug1 - 0.2);
  let n = tapTimes.filter((x) => x <= t).length, p = Math.min(1, n / 15);
  const since = n ? t - tapTimes[n - 1] : 0;
  if (n && n < 15) p = Math.max(0, p - Math.min(0.03, since * 0.15));
  const lassoedNow = t >= GT.land;
  const tx = lassoedNow ? lerp(tx0, 236, easeOut(p)) + (p < 1 ? Math.sin(t * 22) * 4 : 0) : tx0;
  const ty = lassoedNow ? lerp(ty0, 650, easeOut(p)) : ty0;
  const ts = lassoedNow ? lerp(1.05, 1.2, p) : 1.05;
  if (!lassoedNow) svg += puff(tx - 30, ty, t, 0.2) + runner(calfE(CATCH.use, CATCH.sex), tx, ty, ts, 'right', t, 0.2) + twinkle(tx, ty, t);
  else svg += (p < 1 ? puff(tx + 34, ty, t, 0.4, 1) + puff(tx + 30, ty - 8, t, 0.9, 1) : '') + runner(calfE(CATCH.use, CATCH.sex), tx, ty, ts, 'right', p < 1 ? t * 1.6 : 0, 0.2, p < 1 ? 2 : 0) + (p < 1 ? twinkle(tx, ty, t) : '');
  // 繩圈：下面等著 → 手指往小牛前面一點滑 → 飛出去 → 套在脖子上
  const aim = [280 + (-170 + 78 * GT.land) - 4, ty0 - 34];
  const fly = tseg(t, GT.swipe1, GT.land);
  let rope = '';
  if (t < GT.swipe1) rope = loopOn(195, 790, 30);
  else if (t < GT.land) {
    const k = easeOut(fly), x = lerp(195, aim[0], k), y = lerp(790, aim[1], k) - Math.sin(k * Math.PI) * 40;
    rope = loopAt(x, y, lerp(26, 24, k)) + ropeFrom(195, 860, x - 10, y + 6, -30 * (1 - k));
  } else rope = lassoed(tx - 2, ty - 36 * ts, 21 * ts, [195, 860]);
  const sw = tseg(t, GT.swipe0, GT.swipe1);
  const swipeFx = swipeTrail(195, 780, aim[0] - 30, aim[1] + 60, easeOut(sw), t < GT.swipe1 ? 1 : 1 - tseg(t, GT.swipe1, GT.swipe1 + 0.4));
  // 手指
  let fin = '';
  if (t >= 1.2 && t < GT.swipe0) fin = fingerAt(195, 800);
  else if (t >= GT.swipe0 && t < GT.swipe1 + 0.15) { const k = easeOut(sw); fin = fingerAt(lerp(195, aim[0] - 30, k), lerp(800, aim[1] + 70, k)); }
  else if (t >= GT.tug0 && t < GT.tug1) {
    const press = tapTimes.some((x) => t >= x && t < x + 0.08) ? 1 : 0;
    const rip = tapTimes.filter((x) => t >= x && t < x + 0.18).map(() => tapRings(195, 700)).join('');
    fin = rip + fingerAt(190, 704, press);
  }
  const hint = t < 1.7 ? hintPill('閃閃發亮的那頭比較可能是稀有') : t < GT.land ? hintPill('往牠前面一點滑') : '';
  const cueK = t >= GT.tug0 && t < GT.tug1 ? 1 + 0.08 * Math.abs(Math.sin(t * 10)) : 0;
  const tugUi = t >= GT.land ? pullBar(p, '拉繩子') + (cueK ? bigCue('連點！').replace('class="big-cue "', `class="big-cue" style="transform:translateX(-50%) rotate(-4deg) scale(${f2(cueK)})"`) : '') : '';
  return sceneFrame(meadow(svg + swipeFx) + rope, gameTop(T18, { time: clock(t) }) + hint + tugUi, fin + caught(t, '表現：很好（3 秒就拉上來）'));
}

// ---------- C 往前看：從遠處衝向你 ----------
function gifC(t) {
  const far = runner(calfE('dairy', 'cow'), 120 + 30 * Math.sin(t * 0.7), 380, 0.42, 'right', t, 0.3, 3) + runner(calfE('beef', 'bull'), 270 - 24 * Math.sin(t * 0.6), 400, 0.5, 'left', t, 0.7, 3);
  // 衝過來：越來越大（越靠近越快）
  const run = easeIn(tseg(t, 0, 2.05));
  let n = tapTimes.length ? 0 : 0;
  // C 的拉：一拍 0.4 秒，亮兩拍拉、暗一拍停（0.8 秒拉、0.4 秒停）
  const cyc = 1.2, inTug = t >= GT.tug0 && t < GT.tug1, ct = (t - GT.tug0) % cyc;
  const pulling = inTug && ct < 0.8;
  const pulled = (() => { if (t < GT.tug0) return 0; const tt = Math.min(t, GT.tug1 - 0.1) - GT.tug0; const full = Math.floor(tt / cyc), rem = tt % cyc; return Math.min(1, (full * 0.8 + Math.min(rem, 0.8)) / 2.3); })();
  const p = pulled;
  const landY = 596, landS = 1.0;
  const cy = t < GT.land ? lerp(368, landY, run < 1 ? run : 1) + (t > 2.05 ? (t - 2.05) * 30 : 0) : lerp(landY + 20, 690, easeOut(p));
  const cs = t < GT.land ? lerp(0.3, landS, Math.min(1, run)) + (t > 2.05 ? (t - 2.05) * 0.05 : 0) : lerp(1.03, 1.3, easeOut(p));
  const strain = t >= GT.land && p < 1 ? Math.sin(t * 18) * 3 : 0;
  const calf = `<g transform="translate(${f2(strain)} 0)">${runner({ ...calfE(CATCH.use, CATCH.sex), pose: 'front' }, 195, cy, cs, 'left', t < GT.land ? t * 1.3 : (pulling ? t * 2 : 0), 0, t < GT.land ? 5 : 1.5)}</g>`;
  const inRing = t >= 1.6 && t < GT.swipe1 + 0.1;
  const ring = t < GT.land ? `<ellipse cx="195" cy="560" rx="96" ry="26" fill="${inRing ? 'rgba(255,226,122,0.35)' : 'none'}" stroke="${inRing ? '#FFD45E' : '#FFFFFF'}" stroke-width="${inRing ? 6 : 4}" stroke-dasharray="10 8"/>` : '';
  const dust = t < GT.land ? puff(170, cy, t, 0.1, -1) + puff(220, cy, t, 0.6, 1) : (pulling && p < 1 ? puff(160, cy, t, 0.3, -1) + puff(230, cy, t, 0.8, 1) : '');
  // 繩圈
  const fly = tseg(t, GT.swipe1, GT.land);
  const headY = (y, s) => y - 22 * s; // 脖子的位置：繩圈套在脖子上（套在頭上看起來像光環）
  let rope = '';
  if (t < GT.swipe1) rope = loopOn(195, 790, 30);
  else if (t < GT.land) { const k = easeOut(fly), y = lerp(790, headY(landY, landS), k) - Math.sin(k * Math.PI) * 60; rope = loopAt(195, y, lerp(32, 26, k)) + ropeFrom(195, 860, 205, y + 6, 20 * (1 - k)); }
  else rope = lassoed(195 + strain, headY(cy, cs) + 4, 24 * cs, [195, 860]);
  // 手指：踩進圈圈時往上滑；拉的時候亮燈就往下拖、暗燈放開
  const sw = tseg(t, GT.swipe0, GT.swipe1);
  const swipeFx = swipeTrail(195, 800, 195, 660, easeOut(sw), t < GT.swipe1 ? 1 : 1 - tseg(t, GT.swipe1, GT.swipe1 + 0.4));
  let fin = '';
  if (t >= 1.2 && t < GT.swipe0) fin = fingerAt(196, 806);
  else if (t >= GT.swipe0 && t < GT.swipe1 + 0.15) fin = fingerAt(196, lerp(806, 670, easeOut(sw)));
  else if (inTug) { const k = pulling ? ct / 0.8 : 0; fin = `${pulling ? `<svg class="drag-hint" style="left:166px;top:700px" width="60" height="120" viewBox="0 0 60 120"><path d="M30 6V104M16 90l14 16 14-16" fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" opacity="0.85"/></svg>` : ''}${fingerAt(196, pulling ? lerp(720, 790, k) : 760, pulling ? 1 : 0)}`; }
  const hint = t < 1.6 ? hintPill('小牛衝過來了！') : t < GT.land ? hintPill('踩進圈圈了：往上滑！') : '';
  let tugUi = '';
  if (t >= GT.land) {
    const beat = inTug ? Math.floor(ct / 0.4) : -1;
    tugUi = pullBar(p, '拉近') + (inTug ? `<div class="beat">${[0, 1, 2].map((i) => `<i class="${i === beat ? 'on' : ''}${i === 2 ? ' rest' : ''}"></i>`).join('')}</div>` + bigCue(pulling ? '拉！⬇' : '停 ✋', pulling ? '' : 'stop') : '');
  }
  return sceneFrame(perspective(far + ring + dust + calf + swipeFx) + rope, gameTop(T18, { time: clock(t) }) + hint + tugUi, fin + caught(t, '表現：很好（一圈就套中）'));
}

// ================= 第 21 輪：使用者選 A，照三點改（ceo 2026-10-09 轉達） =================
// 使用者：「a比較好，但是我覺得牛要分開跑來跑去，要讓玩家有可能抓不到。然後套到牛後繩子要看起來是綁在牛身上」
// 1. 小牛各自往不同方向跑，會轉彎、會突然改方向、會停一下，彼此分得開。
// 2. 真的可能抓不到：一局 3 個繩圈；丟偏了落空、繩圈飛到之前小牛轉彎閃掉，都用掉一個；套到以後條沒拉滿，小牛就掙脫跑掉。
// 3. 套到以後繩圈縮緊成一圈綁在脖子上，繩子從脖子拉到畫面下緣；拔河時繩子拉直、繃緊，跟著小牛動。
const ease21 = (k) => k * k * (3 - 2 * k);
const range21 = (a, b, d) => { const o = []; for (let v = a; v <= b + 1e-6; v += d) o.push(Math.round(v * 1000) / 1000); return o; };
// 路線：[[秒, x, y], …]；回傳那一刻的位置、朝向、有沒有在跑
function along21(path, t) {
  let i = 0;
  while (i < path.length - 2 && t > path[i + 1][0]) i++;
  const [t0, x0, y0] = path[i], [t1, x1, y1] = path[i + 1];
  const u = ease21(clamp01((t - t0) / (t1 - t0)));
  let j = i, dx = x1 - x0;
  while (Math.abs(dx) < 1 && j > 0) { j--; dx = path[j + 1][1] - path[j][1]; }
  return { x: lerp(x0, x1, u), y: lerp(y0, y1, u), facing: dx >= 0 ? 'right' : 'left', moving: Math.hypot(x1 - x0, y1 - y0) > 1 && t < t1 && t > t0 };
}
// 一頭小牛（跑的時候上下跳）；neck：脖子的位置（繩圈綁在這裡）
function calfAt21(entry, x, y, s, facing, t, ph = 0, amp = 4) {
  const hop = Math.abs(Math.sin((t * 3.2 + ph) * Math.PI)) * amp * s;
  const c = critter(entry, x, y, s, facing);
  const f = c.r.face, hd = facing === 'right' ? 1 : -1;
  return { svg: `<g transform="translate(0 ${f2(-hop)})">${c.svg}</g>`, neck: [f.cx - hd * f.r * 0.55, f.cy + f.r * 0.75 - hop], hd };
}
const BOTTOM21 = [195, 860], REST21 = [195, 790];
// 繩子：鬆的（彎）、繃緊的（直、粗一點，中間兩條白色的緊繃記號）
const slackRope21 = (x, y, bend = -24) => ropeFrom(BOTTOM21[0], BOTTOM21[1], x, y, bend);
const tautRope21 = (x, y) => {
  const mx = (BOTTOM21[0] + x) / 2, my = (BOTTOM21[1] + y) / 2, a = Math.atan2(y - BOTTOM21[1], x - BOTTOM21[0]), nx = -Math.sin(a) * 9, ny = Math.cos(a) * 9;
  return rope(`M${BOTTOM21[0]} ${BOTTOM21[1]}L${f2(x)} ${f2(y)}`, 4.2) + [0.38, 0.62].map((k) => { const px = lerp(BOTTOM21[0], x, k), py = lerp(BOTTOM21[1], y, k); return `<path d="M${f2(px - nx)} ${f2(py - ny)}L${f2(px - nx * 0.4)} ${f2(py - ny * 0.4)}M${f2(px + nx * 0.4)} ${f2(py + ny * 0.4)}L${f2(px + nx)} ${f2(py + ny)}" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round"/>`; }).join('') + (mx && my ? '' : '');
};
// 綁在脖子上的繩圈：從張開的圈（俯看的橢圓）縮成一圈套在脖子上（側面看是直的橢圓），加一個結
function collar21(x, y, k, hd = 1) {
  const rx = lerp(22, 7.5, k), ry = lerp(8, 15, k), rot = lerp(0, hd * 14, k);
  const d = `M${f2(x - rx)} ${f2(y)}a${f2(rx)} ${f2(ry)} 0 1 0 ${f2(2 * rx)} 0a${f2(rx)} ${f2(ry)} 0 1 0 ${f2(-2 * rx)} 0`;
  return `<g transform="rotate(${f2(rot)} ${f2(x)} ${f2(y)})">${rope(d, 3.4)}</g><circle cx="${f2(x)}" cy="${f2(y + ry * 0.9)}" r="${f2(lerp(0, 3.6, k))}" fill="#D8A66A" stroke="${L}" stroke-width="1.6"/>`;
}
// 右上角的繩圈：一局 3 個，用掉的變淡
const ringIc21 = (used) => `<svg class="${used ? 'used' : ''}" viewBox="0 0 28 16" width="28" height="16"><ellipse cx="14" cy="8" rx="11" ry="5" fill="none" stroke="${L}" stroke-width="5"/><ellipse cx="14" cy="8" rx="11" ry="5" fill="none" stroke="#D8A66A" stroke-width="2.6"/></svg>`;
const rings21 = (left) => `<div class="g-rings r21"><span>繩圈</span>${[0, 1, 2].map((i) => ringIc21(i >= left)).join('')}</div>`;
const missPill21 = (s) => `<div class="g-hint miss">${s}</div>`;
// 跑掉了（3 個繩圈用完、或掙脫）
const missCard21 = () => `<div class="backdrop"></div><div class="reveal"><div class="disc-title">跑掉了…</div><div class="card catch-card miss">${cowSVG({ breed: CALF_LOOK[CATCH.use], sex: CATCH.sex, age: 'calf', pose: 'side' }, { w: 170, h: 110, pose: 'side', facing: 'right' })}
  <b class="cc-name">小牛掙脫跑掉了</b><p class="hint">3 個繩圈都用完了，這一局沒抓到。</p><p class="cc-perf">今天還能玩 2 次</p>${btn('再玩一次', { kind: 'primary', block: true })}${btn('回牧場', { block: true })}</div></div>`;
const popIn21 = (html, t, t0) => { const p = pop(t, t0); return html.replace('<div class="backdrop"></div>', `<div class="backdrop" style="opacity:${f2(clamp01((t - t0) / 0.25))}"></div>`).replace('<div class="reveal">', `<div class="reveal" style="opacity:${f2(p.o)};transform:scale(${f2(p.s)})">`); };
// 拉的進度：連點一下加 step，小牛一直往回扯（drain／秒）
function pullCurve21(taps, step, drain, t0) {
  const dt = 1 / 120, out = []; let p = 0, k = 0;
  for (let t = t0; t <= t0 + 8; t += dt) { while (k < taps.length && taps[k] <= t) { p = Math.min(1, p + step); k++; } if (p >= 1) { out.push(1); break; } p = Math.max(0, p - drain * dt); out.push(p); }
  return (t) => (t < t0 ? 0 : out[Math.min(out.length - 1, Math.floor((t - t0) / dt))]);
}

// 其他四頭小牛：各跑各的，會轉彎、停一下
const OTHERS21 = [
  { e: calfE('dairy', 'cow'), ph: 0.1, path: [[0, 70, 300], [1.4, 150, 335], [2.2, 150, 335], [3.0, 90, 385], [4.6, 175, 420], [6.0, 110, 360], [7.4, 60, 330], [9.2, 140, 300], [12, 80, 340]] },
  { e: calfE('beef', 'bull'), ph: 0.5, path: [[0, 335, 300], [1.2, 265, 325], [2.4, 325, 385], [3.4, 345, 345], [5.0, 255, 300], [7.0, 330, 285], [9.0, 255, 330], [12, 330, 350]] },
  { e: calfE('draft', 'cow'), ph: 0.3, path: [[0, 90, 625], [1.6, 165, 665], [2.8, 95, 695], [4.0, 60, 625], [6.0, 145, 645], [7.6, 145, 645], [9.4, 70, 600], [12, 130, 660]] },
  { e: calfE('dairy', 'bull'), ph: 0.8, path: [[0, 330, 650], [1.3, 280, 695], [2.5, 345, 705], [4.0, 305, 645], [6, 352, 605], [8, 290, 665], [10, 340, 690], [12, 300, 640]] },
];
// 要抓的那頭（閃閃發亮）：抓得到的那局、抓不到的那局路線不一樣（抓不到的那局在 3.9 秒突然轉彎）
const T21 = calfE(CATCH.use, CATCH.sex);
const SCN21 = {
  win: {
    total: 9, path: [[0, 235, 470], [0.9, 285, 515], [1.7, 255, 560], [2.8, 190, 520], [4, 160, 480]],
    throws: [{ s0: 2.0, s1: 2.3, land: 2.8, hit: true }],
    tug: { t0: 3.0, taps: range21(3.1, 6.2, 0.18), step: 0.085, drain: 0.12 }, end: 'catch',
  },
  lose: {
    total: 13, path: [[0, 240, 470], [1.0, 290, 520], [1.8, 262, 570], [2.6, 205, 560], [3.4, 172, 522], [3.85, 165, 512], [4.35, 268, 466], [5.2, 295, 500], [6.0, 262, 540], [8, 240, 520], [13, 240, 520]],
    throws: [
      { s0: 1.6, s1: 1.9, land: 2.4, hit: false, aim: [305, 468], msg: '沒套到：丟偏了（還有 2 個繩圈）', back: [2.75, 3.2] },
      { s0: 3.3, s1: 3.6, land: 4.1, hit: false, aim: [148, 500], msg: '被牠閃掉了！（還有 1 個繩圈）', back: [4.45, 4.9] },
      { s0: 5.2, s1: 5.5, land: 6.0, hit: true },
    ],
    tug: { t0: 6.2, taps: range21(6.35, 7.6, 0.32), step: 0.22, drain: 0.28 }, end: 'escape',
  },
};
for (const sc of Object.values(SCN21)) {
  sc.pull = pullCurve21(sc.tug.taps, sc.tug.step, sc.tug.drain, sc.tug.t0);
  // 抓到：條拉滿的那一刻；掙脫：拉起來以後又掉回 0 的那一刻
  let peak = 0;
  for (let t = sc.tug.t0; t < sc.total; t += 1 / 60) { const p = sc.pull(t); peak = Math.max(peak, p); if (sc.end === 'catch' && p >= 1) { sc.doneT = t; break; } if (sc.end === 'escape' && peak > 0.15 && p <= 0.001 && t > sc.tug.taps[sc.tug.taps.length - 1]) { sc.doneT = t; break; } }
  if (sc.doneT === undefined) throw new Error(`第 21 輪：${sc.end} 的結束時間算不出來`);
}
const hitThrow21 = (sc) => sc.throws.find((th) => th.hit);
function frame21(key, t) {
  const sc = SCN21[key], hit = hitThrow21(sc);
  let svg = '', ui = '', ov = '';
  // 其他小牛
  for (const o of OTHERS21) { const p = along21(o.path, t); svg += (p.moving ? puff(p.x - (p.facing === 'right' ? 26 : -26), p.y, t, o.ph, p.facing === 'right' ? -1 : 1) : '') + calfAt21(o.e, p.x, p.y, 0.95, p.facing, t, o.ph, p.moving ? 4 : 0).svg; }
  // 要抓的那頭
  const tied = t >= hit.land && !(sc.doneT && sc.end === 'escape' && t >= sc.doneT);
  const p0 = along21(sc.path, Math.min(t, hit.land));
  let tx = p0.x, ty = p0.y, tf = p0.facing, moving = p0.moving && t < hit.land;
  const pull = sc.pull(t);
  if (tied) {
    // 被套住：一直想往外跑（往上），被拉回來；越拉越靠近畫面下面
    const B = along21(sc.path, hit.land), endP = [195, 690];
    const k = sc.end === 'catch' && sc.doneT && t >= sc.doneT ? 1 : pull;
    tx = lerp(B.x, endP[0], easeOut(k)) + Math.sin(t * 9) * 4 * (1 - k);
    ty = lerp(B.y, endP[1], easeOut(k)) - Math.abs(Math.sin(t * 4)) * 10 * (1 - k);
    tf = B.facing; moving = k < 1;
  }
  let escaped = false;
  if (sc.end === 'escape' && sc.doneT && t >= sc.doneT) { // 掙脫：往上衝出畫面
    const B = along21(sc.path, hit.land), u = clamp01((t - sc.doneT) / 1.0);
    tx = lerp(B.x, -60, easeIn(u)); ty = lerp(B.y, 300, easeIn(u)); tf = 'left'; moving = true; escaped = true;
  }
  const T = calfAt21(T21, tx, ty, 1.05, tf, t * (tied ? 1.6 : 1), 0.2, moving ? (tied ? 2 : 4) : 0);
  svg += (moving ? puff(tx + (tf === 'right' ? -30 : 30), ty, t, 0.4, tf === 'right' ? -1 : 1) : '') + (escaped ? speed(tx + 40, ty - 6, 1) : '') + T.svg + (tied || escaped ? '' : twinkle(tx, ty, t));
  // 繩圈和繩子
  let used = 0, ropeSvg = '', fin = '', hint = '';
  const cur = sc.throws.find((th) => t >= th.s0 && t < (th.hit ? sc.total : th.back[1]));
  for (const th of sc.throws) if (t >= th.s1) used++;
  if (!cur) {
    if (used < sc.throws.length && !(t >= hit.land)) ropeSvg = loopOn(...REST21, 30);
  } else {
    const aim = cur.hit ? (() => { const B = along21(sc.path, cur.land); return calfAt21(T21, B.x, B.y, 1.05, B.facing, cur.land, 0.2, 0).neck; })() : cur.aim;
    const sw = tseg(t, cur.s0, cur.s1), fly = tseg(t, cur.s1, cur.land);
    const swEnd = [lerp(REST21[0], aim[0], 0.45), lerp(REST21[1], aim[1], 0.45)];
    if (t < cur.s1 + 0.4) svg += swipeTrail(REST21[0], REST21[1] - 10, swEnd[0], swEnd[1], easeOut(sw), t < cur.s1 ? 1 : 1 - tseg(t, cur.s1, cur.s1 + 0.4));
    if (t < cur.s1 + 0.12) fin = fingerAt(lerp(REST21[0], swEnd[0], easeOut(sw)), lerp(REST21[1] + 10, swEnd[1] + 10, easeOut(sw)));
    if (t < cur.s1) ropeSvg = loopOn(...REST21, 30);
    else if (t < cur.land) { const k = easeOut(fly), x = lerp(REST21[0], aim[0], k), y = lerp(REST21[1], aim[1], k) - Math.sin(k * Math.PI) * 40; ropeSvg = loopAt(x, y, lerp(26, 22, k)) + slackRope21(x - 12, y + 4, -20 * (1 - k)); }
    else if (!cur.hit) { // 落空：圈掉在草地上，停一下，再拉回來
      const bk = tseg(t, cur.back[0], cur.back[1]), x = lerp(aim[0], REST21[0], easeIn(bk)), y = lerp(aim[1], REST21[1], easeIn(bk));
      ropeSvg = loopOn(x, y, 22) + slackRope21(x - 12, y + 4, -30);
      if (t < cur.back[0] + 0.2) hint = missPill21(cur.msg);
    } else if (!(sc.end === 'escape' && sc.doneT && t >= sc.doneT)) { // 套到：縮緊、綁在脖子上；拔河時繩子拉直
      const k = easeOut(tseg(t, cur.land, cur.land + 0.25)), [nx, ny] = T.neck;
      ropeSvg = (t < sc.tug.t0 ? slackRope21(nx, ny + 10, -16 * (1 - k)) : tautRope21(nx, ny + 10)) + collar21(nx, ny, k, T.hd);
    } else { // 掙脫：圈鬆開掉在草地上，繩子變鬆
      const B = along21(sc.path, hit.land), drop = [B.x, B.y + 4];
      ropeSvg = loopOn(...drop, 22) + slackRope21(drop[0] - 12, drop[1] + 4, -34);
    }
  }
  // 提示、拔河的介面
  const tugOn = t >= sc.tug.t0 && !(sc.doneT && t >= sc.doneT);
  if (!hint) {
    if (t < (sc.throws[0].s0 - 0.1)) hint = hintPill('小牛各跑各的，會轉彎；往牠前面一點滑');
    else if (t >= hit.land && t < sc.tug.t0) hint = hintPill('套到了！繩圈綁在脖子上');
  }
  if (tugOn || (sc.doneT && t >= sc.doneT && t < sc.doneT + 0.8)) ui += pullBar(sc.end === 'catch' && sc.doneT && t >= sc.doneT ? 1 : pull, '拉繩子');
  if (tugOn) {
    ui += bigCue('連點！', 'r21');
    const press = sc.tug.taps.some((x) => t >= x && t < x + 0.08) ? 1 : 0;
    fin = sc.tug.taps.filter((x) => t >= x && t < x + 0.18).map(() => tapRings(195, 760)).join('') + fingerAt(190, 764, press);
  }
  if (sc.end === 'escape' && sc.doneT && t >= sc.doneT && t < sc.doneT + 1.4) ui += bigCue('掙脫了！', 'r21 bad');
  // 結尾的卡片
  if (sc.doneT) {
    if (sc.end === 'catch' && t >= sc.doneT + 0.3) ov = popIn21(catchCard('表現：好（第 1 個繩圈就套中）'), t, sc.doneT + 0.3);
    if (sc.end === 'escape' && t >= sc.doneT + 1.5) ov = popIn21(missCard21(), t, sc.doneT + 1.5);
  }
  return sceneFrame(meadow(svg + ropeSvg), gameTop(T18, { time: clock(t) }) + rings21(3 - used) + hint + ui, fin + ov);
}
const GIFS = {
  W: { fn: (t) => frame21('win', t), file: 'R21-01-抓牛小遊戲-A-分開跑-390', total: SCN21.win.total },
  L: { fn: (t) => frame21('lose', t), file: 'R21-01-抓牛小遊戲-A-分開跑-抓不到-390', total: SCN21.lose.total },
};
function r2101() {
  const W = SCN21.win, Lz = SCN21.lose;
  const cells = [
    { cap: '1 小牛各跑各的', note: '每頭往不同方向跑，會轉彎、突然改方向、停一下；閃閃發亮的那頭比較可能是稀有', html: frame21('win', 1.2) },
    { cap: '2 丟出去', note: '往小牛前面一點滑；右上角是這一局還剩幾個繩圈（一局 3 個）', html: frame21('win', 2.15) },
    { cap: '3 套到：繩圈縮緊綁在脖子上', note: '繩子從小牛的脖子拉到畫面下緣', html: frame21('win', 2.98) },
    { cap: '4 拔河：繩子拉直、繃緊', note: '連點把小牛拉過來；小牛一直往外扯，條會往回掉；繩子跟著小牛動', html: frame21('win', 4.6) },
    { cap: '5 抓到了', note: '條拉滿才算抓到', html: frame21('win', W.doneT + 1.2) },
    { cap: '抓不到 ①：丟偏了', note: '繩圈落在草地上，拉回來，用掉一個繩圈', html: frame21('lose', 2.55) },
    { cap: '抓不到 ②：被牠閃掉', note: '繩圈還在飛，小牛突然轉彎跑開', html: frame21('lose', 4.2) },
    { cap: '抓不到 ③：沒拉滿就掙脫', note: '條掉回 0，繩圈鬆開，小牛衝出去', html: frame21('lose', Lz.doneT + 0.35) },
    { cap: '跑掉了', note: '3 個繩圈都用完；這一局用掉一次機會', html: frame21('lose', Lz.doneT + 2.4) },
  ];
  return board({
    id: 'R21-01-抓牛小遊戲-A-分開跑-390', title: '01 牛仔套索　A：從上往下看（照使用者的三點改）', cols: 5, width: boardWidth(5), cells,
    sub: '使用者看完 A、C 的 GIF：「a比較好，但是我覺得牛要分開跑來跑去，要讓玩家有可能抓不到。然後套到牛後繩子要看起來是綁在牛身上」。上面一排是抓到的一局，下面一排是抓不到的三種情況。',
    notes: ['一局 3 個繩圈（提案）：丟偏了落空、被小牛閃掉都用掉一個；套到以後要在小牛掙脫以前把條拉滿。每天 3 次照舊。', '動起來的樣子：R21-01-抓牛小遊戲-A-分開跑-390.gif（抓到）、R21-01-抓牛小遊戲-A-分開跑-抓不到-390.gif（抓不到）。'],
  });
}
const BOARDS = [{ id: 'R21-01', render: r2101 }];

async function settle() {
  await document.fonts.ready;
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
}
if (q.has('list')) {
  window.__boards = BOARDS.map(({ id }) => ({ id, w: 390 }));
  window.__ready = true;
} else if (q.has('gif')) {
  // GIF：一次載入，harness/gif.mjs 一格一格呼叫 __frame(t)，截 .gif-box
  const g = GIFS[q.get('gif')];
  window.__frame = async (t) => { app.innerHTML = `<div class="gif-box"><div class="gif-label">${g.file}</div>${g.fn(t)}</div>`; await settle(); };
  window.__gif = { file: g.file, total: g.total || GT.total };
  await window.__frame(0);
  window.__ready = true;
} else {
  const b = BOARDS.find((x) => x.id === q.get('b'));
  if (!b) throw new Error(`沒有這張：${q.get('b')}`);
  const out = b.render();
  app.innerHTML = out.html;
  await settle();
  // 跟 m2 的 main.js 一樣的調整（繁中 390 都不會變，照樣跑）
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
