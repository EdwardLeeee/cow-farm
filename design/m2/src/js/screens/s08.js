// S08 配種（自己的公牛 × 自己的母牛）與 S18 借種市場。每頭牛一輩子只能配種一次（公母都一樣，借出去也算）。
import { frame, btn, seg, badge, tierChip, useChip, icon, fmt, cowSVG, toast, dialog, calfLook, BREEDS } from '../kit.js';
import { COWS, cowById, STUD, STUD_INCOME, STUD_LOG, FOUND, RANCH, studFee, LONG_NAMES } from '../fixtures.js';
import { tierOf } from '../../cow/breeds.js';
import { CALF_LOOK } from '../../cow/calf.js';
import { t, tb, dur, dateText, cowName, calfName, breedName, sexName, LANG } from '../i18n.js';

// 可能生出的小牛（配種預覽）：還沒發現的品種顯示剪影和「？？？」（企劃書 4.5）
const OUTCOME = [
  { breed: 'holstein', p: 0.5 }, { breed: 'jersey', p: 0.25 }, { breed: 'fluffyHolstein', p: 0.125 },
  { breed: 'cottonCream', p: 0.0625 }, { breed: 'glossBlack', p: 0.0625 },
];
const STUD_OUTCOME = [
  { breed: 'holstein', p: 0.375 }, { breed: 'chocolate', p: 0.25 }, { breed: 'jersey', p: 0.1875 }, { breed: 'glossBlack', p: 0.125 }, { breed: 'strawberry', p: 0.0625 },
];
// 不能選的原因（badge 的種類 → 字串表的 key）
const REASON = { bred: 'badgeBred', working: 'badgeWorking', listed: 'badgeListed', calf: 'stageCalf' };

function pickCard(c, { on = false, reason = '' } = {}) {
  const b = BREEDS[c.breed];
  return `<button class="pick${on ? ' on' : ''}${reason ? ' off' : ''}"${reason ? ' disabled' : ''}>
    ${on ? `<span class="pick-check">${icon('ok', 22)}</span>` : ''}
    <span class="pick-pic">${cowSVG(calfLook(c), { w: 84, h: 76, pad: 3 })}</span>
    <span class="pick-name">${c.age === 'calf' ? t(`calf.${b.use}`) : breedName(c.breed)}<span class="pid"> #${c.id}</span></span>
    <span class="pick-meta">${reason ? badge(reason, t(REASON[reason])) : tierChip(tierOf(b))}</span>
  </button>`;
}
const BULLS = () => [[cowById(14), ''], [cowById(5), 'listed'], [cowById(8), 'bred'], [cowById(2), 'working']];
const DAMS = () => [[cowById(3), ''], [cowById(7), ''], [cowById(12), ''], [cowById(11), ''], [cowById(9), 'working'], [cowById(15), 'calf']];

// fee：卡片右上角整句費用（自己配種是 breedFree；借種是 s18.feeLine）；none：還沒選好時的提示
// 小牛長大要幾小時：v0.3 所有小牛一樣（ceo 2026-10-03 定；數字等模擬，約 2–4 小時，設計稿的例子用 3 小時；開局送的小牛照舊很快長大）。
// 以前照稀有度 1／2／4／8 小時，會讓玩家從倒數猜出稀有度
export const CALF_GROW_H = 3;
const growRange = () => t('hours', { h: CALF_GROW_H });
export function outcomeCard(st, { rows = OUTCOME, fee = t('breedFree'), title = t('s08.outcomeTitle'), feeLine = true, none = t('pickBoth') } = {}) {
  let body;
  if (st === 'none') body = `<div class="oc-empty">${icon('heart', 26)}<span>${none}</span></div>`;
  else if (st === 'quoting') body = `<div class="oc-empty"><span class="spinner"></span><span>${t('s08.calculating')}</span></div>`;
  else if (st === 'failed') body = `<div class="oc-empty"><span class="err-text">${icon('err', 20)} ${t('s08.probFailedRetry', { n: 3 })}</span></div>`;
  else if (st === 'offline') body = `<div class="oc-empty">${icon('offline', 22)}<span>${t('connecting')}</span></div>`;
  else {
    body = `<div class="oc-rows">${rows.map((r) => {
      const b = BREEDS[r.breed], found = FOUND.includes(r.breed), tier = tierOf(b);
      return `<div class="oc-row"><span class="oc-pic">${cowSVG({ breed: r.breed, age: 'calf', seed: 90 + tier }, { w: 44, h: 44, pad: 2, sil: !found })}</span>
        <span class="oc-name">${found ? breedName(r.breed) : t('g.unknownBreed')}</span>${tierChip(tier)}${found ? '' : `<span class="badge new">${t('s08.notFound')}</span>`}<span class="num oc-p">${(r.p * 100).toFixed(r.p < 0.1 ? 2 : 1).replace(/\.?0+$/, '')}%</span></div>`;
    }).join('')}</div>
    <div class="oc-foot"><span>${t('bullProbLine', { v: '<b class="num">50%</b>' })}</span><span>${t('s08.growRange', { v: `<b class="num">${growRange(rows)}</b>` })}</span></div>`;
  }
  return `<article class="card outcome-card"><div class="card-head"><span class="card-title pink">${icon('heart', 16)}${title}</span>${feeLine ? `<span class="card-sub">${fee}</span>` : ''}</div>${body}</article>`;
}

function breedPage(ctx, o = {}) {
  const bulls = o.bulls || BULLS(), dams = o.dams || DAMS();
  const row = (list, sel, emptyText) => (list.length ? `<div class="pick-row" data-hscroll>${list.map(([c, reason], i) => pickCard(c, { on: sel === i, reason })).join('')}</div>` : `<div class="pick-empty">${emptyText}</div>`);
  const content = `<div class="stack">
    ${seg([t('subOwnBreed'), t('subStud')], 0)}
    <p class="rule-line">${icon('heart', 18)}<span>${t('s08.rule')}</span></p>
    <section><h3 class="sec-title">${t('pickSire')}</h3>${row(bulls, o.sire ?? -1, `<b>${t('noSire')}</b><span>${t('s08.noSireHint')}</span>`)}</section>
    <section><h3 class="sec-title">${t('pickDam')}</h3>${row(dams, o.dam ?? -1, `<b>${t('noDam')}</b><span>${t('s08.noDamHint')}</span>`)}</section>
    ${outcomeCard(o.st || 'none')}
    ${o.warn ? `<p class="warn-text note-line">${icon('warn', 18)}<span>${o.warn}</span></p>` : ''}
    ${btn(o.btnLabel || t('s08.breedBtnFree'), { kind: 'pink', block: true, ic: 'heart', disabled: o.btnDisabled ?? (o.st !== 'ok') })}
    ${o.after || ''}
  </div>`;
  const out = frame(ctx.dev, { tab: 'breed', content, tall: o.tall, overlays: o.overlays || '', offline: o.offline });
  if (!o.scrollTo) return out;
  return { html: out, after: (root) => { const c = root.querySelector('.content'); const el = root.querySelector(o.scrollTo); if (c && el) c.scrollTop = el.classList.contains('calf-card') ? el.offsetTop + el.offsetHeight - c.clientHeight + 18 : el.offsetTop - 6; } };
}

// name：小牛的名字（品種＋編號）；grow：長大還要多久
// 長大的進度：已經過的時間 ÷ 這個稀有度要長的時間（left 是還要多久，{ h, m }）
export const growPct = (left) => { const all = CALF_GROW_H * 60; return ((all - ((left.h || 0) * 60 + (left.m || 0))) / all) * 100; };
// 小牛倒數卡：剛出生的小牛還不知道品種（v0.3，第 13 輪 02-A）：照用途的一般品種畫、叫「小乳牛 #編號」，不放稀有度
export function calfCard(use, id, sex, grow, { seed = 91, pct = 2 } = {}) {
  return `<div class="card calf-card"><div class="calf-pic">${cowSVG({ breed: CALF_LOOK[use], sex, age: 'calf', seed }, { w: 84, h: 84, pose: 'front' })}</div>
    <div class="grow"><b style="font-size:16px">${t('g.newCalf', { cow: calfName(use, id) })}</b><div class="chips" style="margin:4px 0">${useChip(use)}<span class="use">${sexName(sex)}</span>${badge('calf', t('stageCalf'))}</div>
    <div class="hint">${t('growUp', { v: `<b class="num">${grow}</b>` })}</div><div class="bar yellow" style="margin-top:6px"><i style="width:${pct}%"></i></div></div></div>`;
}

const S = [];
const full = (id, name, render, x = {}) => S.push({ id, name, type: 'full', render, ...x });
const part = (id, name, crop, render, x = {}) => S.push({ id, name, type: 'part', crop, render, ...x });

full('S08-01', '一般：還沒選', (ctx) => breedPage(ctx));
part('S08-02', '沒有成年公牛或母牛', '#crop', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div id="crop" class="stack"><section><h3 class="sec-title">${t('pickSire')}</h3><div class="pick-empty"><b>${t('noSire')}</b><span>${t('s08.noSireHint')}</span></div></section><section><h3 class="sec-title">${t('pickDam')}</h3><div class="pick-empty"><b>${t('noDam')}</b><span>${t('s08.noDamHint')}</span></div></section></div>` }));
part('S08-03', '有牛不能選：變灰加原因', '.pick-row', (ctx) => breedPage(ctx, { sire: 0 }));
part('S08-04', '機率計算中', '.outcome-card', (ctx) => breedPage(ctx, { sire: 0, dam: 0, st: 'quoting' }));
part('S08-05', '機率計算失敗（3 秒後自動再試）', '.outcome-card', (ctx) => breedPage(ctx, { sire: 0, dam: 0, st: 'failed' }));
full('S08-06', '可能生出的小牛與機率（沒發現過的顯示「？」）', (ctx) => breedPage(ctx, { sire: 0, dam: 0, st: 'ok', scrollTo: '.outcome-card' }));
part('S08-07', '伺服器說不能配：原因、按鈕停用', '#crop', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div id="crop" class="stack">${outcomeCard('ok')}<p class="warn-text note-line">${icon('warn', 18)}<span>${t('s08.alreadyBred', { cow: cowName('holstein', 3) })}</span></p>${btn(t('s08.breedBtnFree'), { kind: 'pink', block: true, ic: 'heart', disabled: true })}</div>` }));
part('S08-08', '牛舍滿了', '#crop', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div id="crop" class="stack"><p class="warn-text note-line">${icon('warn', 18)}<span>${t('s08.penFull')}</span></p>${btn(t('s08.breedBtnFree'), { kind: 'pink', block: true, ic: 'heart', disabled: true })}</div>` }));
full('S08-09', '配種成功：小牛倒數', (ctx) => breedPage(ctx, { sire: 0, dam: 0, st: 'ok', btnDisabled: true, btnLabel: t('s08.bredBtn'), after: calfCard('dairy', 16, 'cow', dur({ h: 2, m: 58 }), { pct: growPct({ h: 2, m: 58 }) }), scrollTo: '.calf-card', overlays: toast('ok', t('breedDone', { cow: calfName('dairy', 16) })) }));
part('S08-11', '斷線：機率卡顯示「連線中…」', '.outcome-card', (ctx) => breedPage(ctx, { sire: 0, dam: 0, st: 'offline', offline: true }));

// ---------------- S18 借種市場 ----------------
function studRow(l, { on = false } = {}) {
  const b = BREEDS[l.breed];
  return `<button class="card stud-row${on ? ' on' : ''}">
    <span class="sr-pic">${cowSVG({ breed: l.breed, sex: 'bull', seed: l.seed }, { w: 60, h: 60, pad: 3 })}</span>
    <span class="sr-info"><span class="sr-name">${breedName(l.breed)}${LANG === 'zh-Hant' ? '' : ' '}<span class="use">${sexName('bull')}</span></span><span class="chips">${useChip(b.use)}${tierChip(tierOf(b))}</span><span class="sr-owner"><span class="so-k">${t('s18.ownerLabel')}</span>${l.bot ? `<span class="bot">${t('botPrefix')}</span>` : ''}<span class="so-name">${l.owner}</span>${l.bot ? '' : `<span class="so-tag">${l.tag}</span>`}</span></span>
    <span class="sr-price"><span class="sr-p">${icon('coin', 22)}<b class="num">${fmt(l.price)}</b></span>${l.growing ? `<span class="sr-grow">${t('s18.growing')}</span>` : ''}</span>
    ${on ? `<span class="pick-check">${icon('ok', 22)}</span>` : ''}
  </button>`;
}
function myBulls({ canList = true, listed = true, none = false } = {}) {
  const inner = none ? `<div class="pick-empty"><b>${t('s18.noBullTitle')}</b><span>${t('s18.noBullHint')}</span></div>` : `
    ${canList ? `<div class="mb-row">${cowSVG({ breed: 'jersey', sex: 'bull', seed: 85 }, { w: 56, h: 56, pad: 3 })}<div class="grow"><b>${cowName('jersey', 14)}</b><div class="chips">${tierChip(1)}<span class="hint">${t('s18.feeLabel', { price: `<b class="num">${fmt(studFee(205, 1))}</b>` })}</span></div></div>${btn(t('list'), { small: true, kind: 'primary', ic: 'tag' })}</div>` : ''}
    ${listed ? `<div class="mb-row">${cowSVG({ breed: 'angus', sex: 'bull', seed: 5 }, { w: 56, h: 56, pad: 3 })}<div class="grow"><b>${cowName('angus', 5)}</b><div class="chips">${badge('listed', t('badgeListed'))}<span class="hint">${t('costCoins', { v: `<b class="num">${fmt(studFee(790, 0))}</b>` })}</span></div></div>${btn(t('unlist'), { small: true })}</div>` : ''}
    <p class="hint mb-note">${t('s18.feeNote')}</p>`;
  return `<article class="card my-bulls"><div class="card-head"><span class="card-title orange">${icon('tag', 16)}${t('studMineTitle')}</span><span class="card-sub">${t('studIncome', { v: `<b class="num">${fmt(STUD_INCOME)}</b>` })}</span></div>
    ${inner}
    <button class="link-row">${icon('history', 20)}<span>${t('s18.logTitle')}</span>${icon('chevron', 18)}</button></article>`;
}
function studPage(ctx, o = {}) {
  const sel = o.sel ?? -1;
  const market = o.market === 'loading' ? `<div class="oc-empty"><span class="spinner"></span><span>${t('g.loading')}</span></div>`
    : o.market === 'failed' ? `<div class="oc-empty"><span class="err-text">${icon('err', 20)} ${t('loadFailed')}</span>${btn(t('reload'), { small: true, ic: 'refresh' })}</div>`
      : o.market === 'empty' ? `<div class="oc-empty"><span>${t('studEmpty')}</span></div>`
        : `<div class="list">${STUD.map((l, i) => studRow(l, { on: i === sel })).join('')}</div>`;
  const damPick = sel >= 0 ? `<section><h3 class="sec-title">${t('pickDamForStud')}</h3><div class="pick-row" data-hscroll>${DAMS().map(([c, r], i) => pickCard(c, { on: o.dam === i, reason: r })).join('')}</div></section>` : '';
  const content = `<div class="stack">
    ${seg([t('subOwnBreed'), t('subStud')], 1)}
    ${myBulls(o.my || {})}
    <section class="market-sec"><h3 class="sec-title">${t('studMarketTitle')}<span class="hint" style="margin-left:auto">${t('s18.pullHint')}</span></h3>
      <p class="hint">${t('s18.marketHint')}</p>${market}</section>
    ${damPick}
    ${o.outcome ? outcomeCard(o.outcome, { rows: STUD_OUTCOME, fee: t('s18.feeLine', { price: fmt(STUD[sel].price) }) }) : ''}
    ${o.warn ? `<p class="${o.err ? 'err-text' : 'warn-text'} note-line">${icon(o.err ? 'err' : 'warn', 18)}<span>${o.warn}</span></p>` : ''}
    ${sel >= 0 ? btn(o.btnLabel || t('borrow', { price: fmt(STUD[sel].price) }), { kind: 'pink', block: true, ic: 'heart', disabled: o.btnDisabled ?? !(o.dam >= 0 && o.outcome === 'ok') }) : ''}
    ${o.after || ''}
  </div>`;
  const out = frame(ctx.dev, { tab: 'breed', content, tall: o.tall, overlays: o.overlays || '', hud: o.hud || {} });
  if (!o.scrollTo) return out;
  return { html: out, after: (root) => { const c = root.querySelector('.content'); const el = root.querySelector(o.scrollTo); if (c && el) c.scrollTop = el.classList.contains('calf-card') ? el.offsetTop + el.offsetHeight - c.clientHeight + 18 : el.offsetTop - 6; } };
}

const S2 = [];
const full18 = (id, name, render, x = {}) => S2.push({ id, name, type: 'full', render, ...x });
const part18 = (id, name, crop, render, x = {}) => S2.push({ id, name, type: 'part', crop, render, ...x });
full18('S18-01', '我的公牛：上架、下架、收入', (ctx) => studPage(ctx));
part18('S18-02', '我的公牛：沒有能上架的', '.my-bulls', (ctx) => studPage(ctx, { my: { none: true } }));
part18('S18-03', '我的公牛：上架中＋下架', '.my-bulls', (ctx) => studPage(ctx, { my: { canList: false } }));
full18('S18-04', '借種市場列表', (ctx) => studPage(ctx, { scrollTo: '.market-sec' }));
part18('S18-05', '市場：載入中、載入失敗、沒有人上架', '#crop', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div id="crop" class="stack">${['loading', 'failed', 'empty'].map((m) => `<article class="card">${m === 'loading' ? `<div class="oc-empty"><span class="spinner"></span><span>${t('g.loading')}</span></div>` : m === 'failed' ? `<div class="oc-empty"><span class="err-text">${icon('err', 20)} ${t('loadFailed')}</span>${btn(t('reload'), { small: true, ic: 'refresh' })}</div>` : `<div class="oc-empty"><span>${t('studEmpty')}</span></div>`}</article>`).join('')}</div>` }));
full18('S18-06', '選了公牛和母牛：機率、費用、借種', (ctx) => studPage(ctx, { sel: 2, dam: 0, outcome: 'ok', scrollTo: '.outcome-card' }));
part18('S18-07', '還沒選母牛', '#crop', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div id="crop" class="stack">${outcomeCard('none', { fee: t('s18.feeLine', { price: fmt(1820) }), none: t('pickListing') })}${btn(t('borrow', { price: fmt(1820) }), { kind: 'pink', block: true, ic: 'heart', disabled: true })}</div>` }));
part18('S18-08', '金幣不夠、牛舍滿了', '#crop', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div id="crop" class="stack"><p class="warn-text note-line">${icon('warn', 18)}<span>${t('notEnoughCoins', { n: fmt(1520) })}</span></p><p class="warn-text note-line">${icon('warn', 18)}<span>${t('s08.penFull')}</span></p>${btn(t('borrow', { price: fmt(1820) }), { kind: 'pink', block: true, ic: 'heart', disabled: true })}</div>` }));
full18('S18-09', '借種成功：小牛倒數', (ctx) => studPage(ctx, { sel: 2, dam: 0, outcome: 'ok', btnDisabled: true, btnLabel: t('s18.borrowedBtn'), hud: { coins: RANCH.coins - 1820 }, after: calfCard('dairy', 16, 'cow', dur({ h: 2, m: 58 }), { seed: 93, pct: growPct({ h: 2, m: 58 }) }), scrollTo: '.calf-card', overlays: toast('ok', t('borrowed', { price: fmt(1820) })) }));
part18('S18-10', '借種失敗：公牛已經被借走', '.dialog', (ctx) => studPage(ctx, { sel: 2, dam: 0, outcome: 'ok', scrollTo: '.outcome-card', overlays: dialog({ title: t('s18.goneTitle'), body: `<p style="text-align:center">${tb('s18.goneBody')}</p>`, buttons: btn(t('s18.reloadMarket'), { kind: 'primary', ic: 'refresh' }) }) }));
part18('S18-12', '借種費變了：公牛長大，價格跟剛剛看的不一樣', '.dialog', (ctx) => studPage(ctx, { sel: 3, dam: 0, outcome: 'ok', scrollTo: '.outcome-card', overlays: dialog({ title: t('s18.feeChangedTitle'), body: `<p style="text-align:center">${tb('s18.feeChangedBody', { old: `<b class="num">${fmt(1050)}</b>`, now: `<b class="num">${fmt(1090)}</b>` })}</p>`, buttons: `${btn(t('cancel'))}${btn(t('s18.borrowNew', { price: fmt(1090) }), { kind: 'pink' })}` }) }));
part18('S18-13', '名字最長：8 個中文字、16 個英文字母（量測用）', '.list', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div class="list">${[{ ...STUD[2], owner: LONG_NAMES.cjk, tag: '#5821' }, { ...STUD[4], owner: LONG_NAMES.latin, tag: '#0907' }, { ...STUD[0], owner: LONG_NAMES.cjk }].map((l) => studRow(l)).join('')}</div>` }));
// 對方的牧場刪除了：借出、借入各一列（量長度用；借種費照 D26：娟珊公牛 233 公斤 × 2.75、夏洛來 440 公斤 × 2.75）
part18('S18-14', '借種紀錄：對方的牧場刪除了（名字顯示「已刪除的牧場」）', '.list', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div class="list">${[
  { dir: 'out', when: { m: 9, d: 27, time: '18:30' }, gone: true, cow: { breed: 'jersey', id: 9 }, price: 640 },
  { dir: 'in', when: { m: 9, d: 26, time: '07:45' }, gone: true, cow: { breed: 'charolais' }, price: 1210, calf: { breed: 'charolais', id: 7 } },
].map(logRow).join('')}</div>` }));
full18('S18-11', '借種紀錄', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div class="stack">
  <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${t('s18.logTitle')}</h1><div class="sub">${t('s18.logIncome', { v: fmt(STUD_INCOME) })}</div></div></div>
  <div class="filter" data-hscroll><button class="on">${t('g.all')}</button><button>${t('s18.out')}</button><button>${t('s18.in')}</button></div>
  <div class="list">${STUD_LOG.map(logRow).join('')}</div>
  <p class="hint" style="text-align:center">${t('s18.logKeep', { n: 30 })}</p></div>` }));
// 借種紀錄是空的（缺口清單 2-2）：剛開始玩一定是空的；按「借出」「借入」篩選也可能沒有。樣子跟 S18-05 的空狀態一樣，三種篩選只差一句
const LOG_EMPTY = [[0, 's18.logEmpty'], [1, 's18.logEmptyOut'], [2, 's18.logEmptyIn']];
part18('S18-15', '借種紀錄是空的（全部、借出、借入）', '#crop', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div id="crop" class="stack">
  <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${t('s18.logTitle')}</h1><div class="sub">${t('s18.logIncome', { v: 0 })}</div></div></div>
  ${LOG_EMPTY.map(([on, key]) => `<div class="filter" data-hscroll>${[t('g.all'), t('s18.out'), t('s18.in')].map((s, i) => `<button${i === on ? ' class="on"' : ''}>${s}</button>`).join('')}</div>
  <article class="card"><div class="oc-empty"><span>${t(key)}</span></div></article>`).join('')}
  <p class="hint" style="text-align:center">${t('s18.logKeep', { n: 30 })}</p></div>` }), { board: '空紀錄-狀態表' });

// 借種紀錄的一列。gone：對方的牧場刪除了，紀錄照樣保留，對方的名字顯示「已刪除的牧場」（ceo 2026-10-02）
function logRow(r) {
  const ranch = r.gone ? t('s18.deletedRanch') : r.bot ? `${t('botPrefix')} ${r.who}` : r.who;
  return `<article class="card log-row"><span class="log-dir ${r.dir}">${t(r.dir === 'out' ? 's18.out' : 's18.in')}</span>
    <div class="grow"><b>${t(r.dir === 'out' ? 's18.lentTo' : 's18.borrowedFrom', { cow: logCow(r.cow), ranch })}</b><div class="hint">${dateText(r.when)}${r.calf ? t('g.sep') + t('s18.calfBorn', { cow: logCow(r.calf) }) : ''}</div></div>
    <span class="log-amt ${r.dir}">${t('costCoins', { v: `<b class="num">${r.dir === 'out' ? '+' : '−'}${fmt(r.price)}</b>` })}</span></article>`;
}
// 借種紀錄裡的牛：品種＋編號，跟其他畫面一樣（借入的公牛沒有編號）。紀錄裡的一定是公牛，不另外加「公牛」（ceo 2026-10-02）
function logCow(c) {
  return c.id ? `${breedName(c.breed)} #${c.id}` : breedName(c.breed);
}

export const S08 = { id: 'S08', name: '配種', states: S };
export const S18 = { id: 'S18', name: '借種市場', states: S2 };
