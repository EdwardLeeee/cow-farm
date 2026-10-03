// 第 15 輪草稿（ceo 2026-10-03 交辦）：v0.3 第 1、2.1、13 節（D35 補充 3、4）給使用者挑的五項。
// 網址：r15.html?b=R15-01-A 畫一張說明圖；?list=1 列出全部說明圖（harness/make.mjs 用）。
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
    ${[0, 1, 2, 3].map((n) => `<div class="lu-cell"><span class="big">${starChip(n, v, 16)}</span><b>${tierName(n)}</b><span>${n + 1} 顆星</span></div>`).join('')}
    <div class="lu-cell"><span class="big">${badge('mix', t('badgeMix'))}</span><b>雜種牛</b><span>不給星星，照舊寫「雜種」</span></div>
    <div class="lu-cell"><span class="big">${spMark()}</span><b>特殊牛</b><span>寶石記號（提案），不跟星星混</span></div>
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
  const herd = HERD.map((h) => (h.id === 7 ? { id: 30, breed: 'zeus', sex: 'bull', x: 300, y: 430, facing: 'left', depth: 1, pose: 'front' } : h));
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
const SKY = { day: ['#BFE6FF', '#EAF7FF'], dusk: ['#46336E', '#F3A27C'], night: ['#18224A', '#4D3F80'] };
const GRASS = { day: ['#A8E08A', '#84CB6C'], dusk: ['#93C47C', '#6EA25F'], night: ['#5B8E5C', '#477649'] };
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
const gameFrame = (mood, inner, body, overlays = '') => frame(dev, { tab: null, hud: false, scene: field(mood, inner), body, overlays, dark: mood !== 'day' });
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
  const c1 = critter(calfE('draft', 'bull'), 112, 600, 0.95, 'right'), c2 = critter(calfE('dairy', 'cow'), 300, 700, 0.9, 'left'), c3 = critter(calfE('beef', 'cow'), 82, 450, 0.85, 'right');
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
    const inPen = critter(calfE('draft', 'bull'), 290, 480, 0.85, 'right');
    return gameFrame('day', base + inPen.svg + c2.svg + c3.svg, gameTop(title, { time: '0:09', meter: 45 }), catchCard('表現：很好（8 秒就趕進去）'));
  }
  const sp = critter({ breed: 'zeus', sex: 'bull', age: 'calf' }, 140, 640, 1, 'right');
  return gameFrame('day', glowDefs + base + c3.svg + glow(140 - 6, 610, 92) + speed(70, 640, -1) + sp.svg + sparkles([[96, 560, 9], [196, 576, 7], [70, 610, 6], [210, 640, 6]]) + c2.svg, gameTop(title, { time: '0:20', meter: 100 }) + spBanner('zeus'));
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
    const c = critter(sp ? { breed: 'azure', sex: 'cow', age: 'calf' } : calfE(u, sx), x, y, i > 2 ? 0.72 : 0.9, i % 2 ? 'left' : 'right');
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
  const herd = [critter(calfE('beef', 'bull'), 80, 640, 0.95, 'right'), critter(calfE('dairy', 'cow'), 300, 600, 0.9, 'left'), critter(calfE('draft', 'cow'), 220, 740, 0.95, 'left')];
  if (step === 1) return gameFrame('night', stars() + herd.map((c) => c.svg).join('') + ufo(195, 330), gameTop(title, { left: 3 }), startCard(title, ['左右拖動小飛碟，對準一頭小牛。', '按住放出光束，把小牛吸上來；小牛會掙扎，光束要一直對準。', '掙扎得特別厲害的小牛，比較可能長成稀有以上。'], `<svg viewBox="0 0 120 80" width="200" height="133">${beam(60, 28, 72, 10, 26)}${ufo(60, 22, 0.6)}</svg>`));
  if (step === 2) return gameFrame('night', stars() + herd.map((c) => c.svg).join('') + ufo(150, 330) + `<path d="M84 400h-40M216 400h40" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/><path d="M52 388l-14 12 14 12M248 388l14 12-14 12" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>`,
    gameTop(title, { time: '0:25' }) + hintPill('左右拖動小飛碟'), finger(150, 420));
  if (step === 3) {
    const lifted = critter(calfE('dairy', 'cow'), 300, 500, 0.9, 'left');
    return gameFrame('night', stars() + herd[0].svg + herd[2].svg + beam(300, 350, 610, 30, 64) + `<path d="M246 440q-8 8 0 16M354 440q8 8 0 16M240 470q-8 8 0 16M360 470q8 8 0 16" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round"/>` + lifted.svg + ufo(300, 330),
      gameTop(title, { time: '0:18', meter: 62 }) + hintPill('按住不放：小牛在掙扎，跟著左右移'), finger(300, 420));
  }
  if (step === 4) return gameFrame('night', stars() + herd[0].svg + herd[2].svg + ufo(300, 330), gameTop(title, { time: '0:15', meter: 100 }), catchCard('表現：很好（一次就吸上來）'));
  const sp = critter({ breed: 'holyWhite', sex: 'cow', age: 'calf' }, 196, 640, 1, 'right');
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
    ['02 稀有度星星（一般、優良、稀有、傳說）', Object.keys(V2).map((v) => cell(`${v}　${V2[v].name}`, `${legend(v)}${mini(swapTiers(stateHtml('S03-06'), v))}`))],
    ['03 圖鑑的配種表', Object.keys(V3).map((v) => cell(`${v}　${V3[v].name}`, mini(codexDetail(v, { top: false }))))],
    ['04 特殊牛 3 種（不用選，看樣子）', [cell('宙斯牛、青牛、聖白牛', `<div class="ov-sp">${SP_KEYS.map((k) => `<span>${cowSVG({ breed: k }, { w: 150, h: 140 })}<b>${SPECIAL[k].name}</b></span>`).join('')}</div>`)]],
    ['05 抓牛小遊戲（選一個方向）', Object.keys(V5).map((v) => cell(`${v}　${V5[v].name}`, `<div class="ov-pair">${mini(V5[v].fn(3))}${mini(V5[v].fn(4))}</div>`))],
  ];
  const body = rows.map(([title, cs]) => `<div class="ov-row"><div class="ov-title">${title}</div><div class="ov-cells">${cs.join('')}</div></div>`).join('');
  return { html: `<div class="board" style="width:${PAD * 2 + 8 * sw + 7 * 28 + 4 * 14}px"><div class="b-label">R15-99-總覽對照</div><div class="b-title">第 15 輪：小牛卡片、星星、配種表、特殊牛、抓牛小遊戲</div>
    <div class="b-sub">01、02、03、05 各選一個；04 是特殊牛的樣子。各自的大圖見 R15-01～05。</div>${body}</div>` };
}

// ---------- 說明圖清單 ----------
const BOARDS = [
  ...Object.keys(V1).map((v) => ({ id: `R15-01-${v}`, render: () => r1501(v) })),
  ...Object.keys(V2).map((v) => ({ id: `R15-02-${v}`, render: () => r1502(v) })),
  ...Object.keys(V3).map((v) => ({ id: `R15-03-${v}`, render: () => r1503(v) })),
  { id: 'R15-04-A', render: r1504 },
  ...Object.keys(V5).map((v) => ({ id: `R15-05-${v}`, render: () => r1505(v) })),
  { id: 'R15-99', render: r1599 },
];

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
