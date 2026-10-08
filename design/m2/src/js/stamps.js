// 小牛的飼料集點卡（v0.3 第 1 節；使用者 2026-10-08 選第 15 輪 01-C「集點卡」，D35 補充 3）：
// 小牛長大前要吃到的飼料（稀有、傳說的品種各指定 1–2 種，伺服器出生時就知道），吃過一種蓋一個章；一般、優良的寫「什麼都可以吃」。不寫機率。
// c.need：要吃的飼料（feed.* 的 key），c.ate：吃過的。用在牛的詳細（stampCard）、牛舍清單（stampLine）、牧場的想吃泡泡（wantBubble）、快長大的提醒卡（growAlert）。
import { icon, cowSVG, calfLook } from './kit.js';
import { t, dur } from './i18n.js';
import { cowName } from './fixtures.js';

export const todo = (c) => (c.need || []).filter((k) => !(c.ate || []).includes(k));
const count = (c) => `${c.need.length - todo(c).length} / ${c.need.length}`;
const feedIc = (k, s) => icon(`feed_${k}`, s);

// 牛的詳細：集點卡。蓋過章的格子是實線圈＋右下角一個紅色「吃過」章，還沒吃的是虛線圈、飼料淡淡的
export function stampCard(c) {
  if (!(c.need || []).length) return `<article class="card stamp-card any"><div class="sc-head"><b>${t('s04.stampTitle')}</b></div><p class="any-line">${icon('ok', 20)}${t('s04.eatAny')}</p></article>`;
  const stamps = c.need.map((k) => { const done = c.ate.includes(k); return `<div class="stamp${done ? ' done' : ''}"><span class="st-ring">${feedIc(k, 34)}${done ? `<i class="st-ink">${t('s04.stamped')}</i>` : ''}</span><b>${t(`feed.${k}`)}</b></div>`; }).join('');
  return `<article class="card stamp-card"><div class="sc-head"><b>${t('s04.stampTitle')}</b><span class="sc-count num">${count(c)}</span></div><div class="stamps">${stamps}</div><p class="hint sc-rule">${t('s04.stampRule')}</p></article>`;
}
// 牛舍清單的小牛那一列：一排小章＋幾個了；都吃過了寫「集滿了」
export function stampLine(c) {
  if (!(c.need || []).length) return `<div class="meta fl-any">${t('s04.eatAny')}</div>`;
  return `<div class="fl-stamps">${c.need.map((k) => `<span class="mini-stamp${c.ate.includes(k) ? ' done' : ''}">${feedIc(k, 18)}</span>`).join('')}<b class="num">${count(c)}</b>${todo(c).length ? '' : `<span class="tr-done">${t('s03.stampsFull')}</span>`}</div>`;
}
// 牧場：小牛頭上的泡泡（還有沒吃的才畫）：第一種還沒吃的飼料＋幾個了。a 是場景裡這頭牛的位置（scene.js 的 anchors）
export function wantBubble(c, a) {
  const w = todo(c);
  if (!w.length) return '';
  return `<div class="want stampy" style="left:${a.head[0]}px;top:${a.head[1]}px">${feedIc(w[0], 22)}<b class="num">${count(c)}</b></div>`;
}
// 牧場：快長大的提醒卡（再 1 小時內長大、還有沒吃的：跳一次，一頭一張，可以關）
export function growAlert(c) {
  return `<div class="grow-alert card"><span class="ga-pic">${cowSVG(calfLook(c), { w: 52, h: 52, pad: 2 })}</span><div class="grow"><b>${t('s03.growSoon', { cow: cowName(c), time: dur(c.grow_) })}</b><p>${t('s03.notEaten')}${todo(c).map((k) => `<span class="ga-feed">${feedIc(k, 18)}${t(`feed.${k}`)}</span>`).join('')}</p></div>
    <button class="btn small primary ga-go"><span>${t('s03.goFeed')}</span></button><button class="bn-close" aria-label="${t('g.close')}">${icon('close', 18)}</button></div>`;
}
