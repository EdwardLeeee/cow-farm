// S08 配種（自己的公牛 × 自己的母牛）與 S18 借種市場。每頭牛一輩子只能配種一次（公母都一樣，借出去也算）。
import { frame, btn, seg, badge, tierChip, useChip, icon, fmt, cowSVG, toast, dialog, BREEDS } from '../kit.js';
import { COWS, cowById, STUD, STUD_INCOME, STUD_LOG, FOUND, RANCH, studFee, LONG_NAMES } from '../fixtures.js';
import { tierOf, TIER_NAME } from '../../cow/breeds.js';

// 可能生出的小牛（配種預覽）：還沒發現的品種顯示剪影和「？？？」（企劃書 4.5）
const OUTCOME = [
  { breed: 'holstein', p: 0.5 }, { breed: 'jersey', p: 0.25 }, { breed: 'fluffyHolstein', p: 0.125 },
  { breed: 'cottonCream', p: 0.0625 }, { breed: 'glossBlack', p: 0.0625 },
];
const STUD_OUTCOME = [
  { breed: 'holstein', p: 0.375 }, { breed: 'chocolate', p: 0.25 }, { breed: 'jersey', p: 0.1875 }, { breed: 'glossBlack', p: 0.125 }, { breed: 'strawberry', p: 0.0625 },
];
const GROW = ['1 小時', '2 小時', '4 小時', '8 小時'];

function pickCard(c, { on = false, reason = '' } = {}) {
  const b = BREEDS[c.breed];
  return `<button class="pick${on ? ' on' : ''}${reason ? ' off' : ''}"${reason ? ' disabled' : ''}>
    ${on ? `<span class="pick-check">${icon('ok', 22)}</span>` : ''}
    <span class="pick-pic">${cowSVG({ breed: c.breed, sex: c.sex, age: c.age === 'calf' ? 'calf' : 'adult', seed: c.seed }, { w: 84, h: 76, pad: 3 })}</span>
    <span class="pick-name">${b.name} #${c.id}</span>
    <span class="pick-meta">${reason ? badge(reason === '已配種' ? 'bred' : reason === '工作中' ? 'working' : reason === '上架中' ? 'listed' : 'calf', reason) : tierChip(tierOf(b))}</span>
  </button>`;
}
const BULLS = () => [[cowById(14), ''], [cowById(5), '上架中'], [cowById(8), '已配種'], [cowById(2), '工作中']];
const DAMS = () => [[cowById(3), ''], [cowById(7), ''], [cowById(12), ''], [cowById(11), ''], [cowById(9), '工作中'], [cowById(15), '小牛']];

export function outcomeCard(st, { rows = OUTCOME, fee = '免費（自己的公母）', title = '可能生出的小牛', feeLine = true } = {}) {
  let body;
  if (st === 'none') body = `<div class="oc-empty">${icon('heart', 26)}<span>請選一頭公牛和一頭母牛</span></div>`;
  else if (st === 'quoting') body = `<div class="oc-empty"><span class="spinner"></span><span>計算機率中…</span></div>`;
  else if (st === 'failed') body = `<div class="oc-empty"><span class="err-text">${icon('err', 20)} 機率載入失敗，3 秒後自動再試</span></div>`;
  else if (st === 'offline') body = `<div class="oc-empty">${icon('offline', 22)}<span>連線中…</span></div>`;
  else {
    body = `<div class="oc-rows">${rows.map((r) => {
      const b = BREEDS[r.breed], found = FOUND.includes(r.breed), t = tierOf(b);
      return `<div class="oc-row"><span class="oc-pic">${cowSVG({ breed: r.breed, age: 'calf', seed: 90 + t }, { w: 44, h: 44, pad: 2, sil: !found })}</span>
        <span class="oc-name">${found ? b.name : '？？？'}</span>${tierChip(t)}${found ? '' : '<span class="badge new">沒發現過</span>'}<span class="num oc-p">${(r.p * 100).toFixed(r.p < 0.1 ? 2 : 1).replace(/\.?0+$/, '')}%</span></div>`;
    }).join('')}</div>
    <div class="oc-foot"><span>公牛機率 <b class="num">50%</b></span><span>小牛長大 <b class="num">1–4 小時</b></span></div>`;
  }
  return `<article class="card outcome-card"><div class="card-head"><span class="card-title pink">${icon('heart', 16)}${title}</span>${feeLine ? `<span class="card-sub">費用 ${fee}</span>` : ''}</div>${body}</article>`;
}

function breedPage(ctx, o = {}) {
  const bulls = o.bulls || BULLS(), dams = o.dams || DAMS();
  const row = (list, sel, emptyText) => (list.length ? `<div class="pick-row" data-hscroll>${list.map(([c, reason], i) => pickCard(c, { on: sel === i, reason })).join('')}</div>` : `<div class="pick-empty">${emptyText}</div>`);
  const content = `<div class="stack">
    ${seg(['自己配種', '借種'], 0)}
    <p class="rule-line">${icon('heart', 18)}<span>每頭牛一輩子只能配種一次・自己的公母配種免費</span></p>
    <section><h3 class="sec-title">選公牛</h3>${row(bulls, o.sire ?? -1, `<b>沒有能配種的成年公牛</b><span>到商店抽牛，或等小公牛長大。也可以到「借種」借別人的公牛。</span>`)}</section>
    <section><h3 class="sec-title">選母牛</h3>${row(dams, o.dam ?? -1, `<b>沒有能配種的成年母牛</b><span>到商店抽牛，或等小母牛長大。</span>`)}</section>
    ${outcomeCard(o.st || 'none')}
    ${o.warn ? `<p class="warn-text note-line">${icon('warn', 18)}<span>${o.warn}</span></p>` : ''}
    ${btn(o.btnLabel || '配種（免費）', { kind: 'pink', block: true, ic: 'heart', disabled: o.btnDisabled ?? (o.st !== 'ok') })}
    ${o.after || ''}
  </div>`;
  const out = frame(ctx.dev, { tab: 'breed', content, tall: o.tall, overlays: o.overlays || '', offline: o.offline });
  if (!o.scrollTo) return out;
  return { html: out, after: (root) => { const c = root.querySelector('.content'); const el = root.querySelector(o.scrollTo); if (c && el) c.scrollTop = el.classList.contains('calf-card') ? el.offsetTop + el.offsetHeight - c.clientHeight + 18 : el.offsetTop - 6; } };
}

export function calfCard(name, tier, grow, { breed = 'jersey', seed = 91, pct = 2 } = {}) {
  return `<div class="card calf-card"><div class="calf-pic">${cowSVG({ breed, age: 'calf', seed }, { w: 84, h: 84, pose: 'front' })}</div>
    <div class="grow"><b style="font-size:16px">新小牛 ${name}</b><div class="chips" style="margin:4px 0">${tierChip(tier)}${badge('calf', '小牛')}</div>
    <div class="hint">長大還要 <b class="num">${grow}</b></div><div class="bar yellow" style="margin-top:6px"><i style="width:${pct}%"></i></div></div></div>`;
}

const S = [];
const full = (id, name, render, x = {}) => S.push({ id, name, type: 'full', render, ...x });
const part = (id, name, crop, render, x = {}) => S.push({ id, name, type: 'part', crop, render, ...x });

full('S08-01', '一般：還沒選', (ctx) => breedPage(ctx));
part('S08-02', '沒有成年公牛或母牛', '#crop', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div id="crop" class="stack"><section><h3 class="sec-title">選公牛</h3><div class="pick-empty"><b>沒有能配種的成年公牛</b><span>到商店抽牛，或等小公牛長大。也可以到「借種」借別人的公牛。</span></div></section><section><h3 class="sec-title">選母牛</h3><div class="pick-empty"><b>沒有能配種的成年母牛</b><span>到商店抽牛，或等小母牛長大。</span></div></section></div>` }));
part('S08-03', '有牛不能選：變灰加原因', '.pick-row', (ctx) => breedPage(ctx, { sire: 0 }));
part('S08-04', '機率計算中', '.outcome-card', (ctx) => breedPage(ctx, { sire: 0, dam: 0, st: 'quoting' }));
part('S08-05', '機率計算失敗（3 秒後自動再試）', '.outcome-card', (ctx) => breedPage(ctx, { sire: 0, dam: 0, st: 'failed' }));
full('S08-06', '可能生出的小牛與機率（沒發現過的顯示「？」）', (ctx) => breedPage(ctx, { sire: 0, dam: 0, st: 'ok', scrollTo: '.outcome-card' }));
part('S08-07', '伺服器說不能配：原因、按鈕停用', '#crop', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div id="crop" class="stack">${outcomeCard('ok')}<p class="warn-text note-line">${icon('warn', 18)}<span>荷斯坦 #3 已經配過種了（每頭牛一輩子只能配種一次）</span></p>${btn('配種（免費）', { kind: 'pink', block: true, ic: 'heart', disabled: true })}</div>` }));
part('S08-08', '牛舍滿了', '#crop', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div id="crop" class="stack"><p class="warn-text note-line">${icon('warn', 18)}<span>牛舍滿了，先擴建或出貨，才有位子給小牛</span></p>${btn('配種（免費）', { kind: 'pink', block: true, ic: 'heart', disabled: true })}</div>` }));
full('S08-09', '配種成功：小牛倒數', (ctx) => breedPage(ctx, { sire: 0, dam: 0, st: 'ok', btnDisabled: true, btnLabel: '已配種', after: calfCard('娟珊 #16', 1, '1 小時 58 分'), scrollTo: '.calf-card', overlays: toast('ok', '配種成功！娟珊 #16 出生了') }));
part('S08-11', '斷線：機率卡顯示「連線中…」', '.outcome-card', (ctx) => breedPage(ctx, { sire: 0, dam: 0, st: 'offline', offline: true }));

// ---------------- S18 借種市場 ----------------
function studRow(l, { on = false } = {}) {
  const b = BREEDS[l.breed];
  return `<button class="card stud-row${on ? ' on' : ''}">
    <span class="sr-pic">${cowSVG({ breed: l.breed, sex: 'bull', seed: l.seed }, { w: 60, h: 60, pad: 3 })}</span>
    <span class="sr-info"><span class="sr-name">${b.name}<span class="use"> 公</span></span><span class="chips">${useChip(b.use)}${tierChip(tierOf(b))}</span><span class="sr-owner">主人：${l.bot ? `<span class="bot">電腦</span>${l.owner}` : `${l.owner} ${l.tag}`}</span></span>
    <span class="sr-price"><span class="sr-p">${icon('coin', 22)}<b class="num">${fmt(l.price)}</b></span>${l.growing ? '<span class="sr-grow">還在長</span>' : ''}</span>
    ${on ? `<span class="pick-check">${icon('ok', 22)}</span>` : ''}
  </button>`;
}
function myBulls({ canList = true, listed = true, none = false } = {}) {
  const inner = none ? `<div class="pick-empty"><b>沒有能上架的公牛</b><span>要成年、沒配過種、不在田裡工作。</span></div>` : `
    ${canList ? `<div class="mb-row">${cowSVG({ breed: 'jersey', sex: 'bull', seed: 85 }, { w: 56, h: 56, pad: 3 })}<div class="grow"><b>娟珊 #14</b><div class="chips">${tierChip(1)}<span class="hint">借種費 <b class="num">${fmt(studFee(205, 1))}</b> 幣</span></div></div>${btn('上架', { small: true, kind: 'primary', ic: 'tag' })}</div>` : ''}
    ${listed ? `<div class="mb-row">${cowSVG({ breed: 'angus', sex: 'bull', seed: 5 }, { w: 56, h: 56, pad: 3 })}<div class="grow"><b>安格斯 #5</b><div class="chips">${badge('listed', '上架中')}<span class="hint"><b class="num">${fmt(studFee(790, 0))}</b> 幣</span></div></div>${btn('下架', { small: true })}</div>` : ''}
    <p class="hint mb-note">借種費由系統算：公牛的體重 × 稀有度的每公斤價格，長大會自動漲。</p>`;
  return `<article class="card my-bulls"><div class="card-head"><span class="card-title orange">${icon('tag', 16)}我的公牛出借</span><span class="card-sub">借種收入累計 <b class="num">${fmt(STUD_INCOME)}</b> 幣</span></div>
    ${inner}
    <button class="link-row">${icon('history', 20)}<span>借種紀錄</span>${icon('chevron', 18)}</button></article>`;
}
function studPage(ctx, o = {}) {
  const sel = o.sel ?? -1;
  const market = o.market === 'loading' ? `<div class="oc-empty"><span class="spinner"></span><span>載入中…</span></div>`
    : o.market === 'failed' ? `<div class="oc-empty"><span class="err-text">${icon('err', 20)} 載入失敗</span>${btn('重新整理', { small: true, ic: 'refresh' })}</div>`
      : o.market === 'empty' ? `<div class="oc-empty"><span>目前沒有別人上架的公牛</span></div>`
        : `<div class="list">${STUD.map((l, i) => studRow(l, { on: i === sel })).join('')}</div>`;
  const damPick = sel >= 0 ? `<section><h3 class="sec-title">選自己的母牛</h3><div class="pick-row" data-hscroll>${DAMS().map(([c, r], i) => pickCard(c, { on: o.dam === i, reason: r })).join('')}</div></section>` : '';
  const content = `<div class="stack">
    ${seg(['自己配種', '借種'], 1)}
    ${myBulls(o.my || {})}
    <section class="market-sec"><h3 class="sec-title">借種市場<span class="hint" style="margin-left:auto">下拉重新整理</span></h3>
      <p class="hint">付錢借別人的公牛：錢給主人，小牛歸你。</p>${market}</section>
    ${damPick}
    ${o.outcome ? outcomeCard(o.outcome, { rows: STUD_OUTCOME, fee: `${fmt(STUD[sel].price)} 幣（付給主人）` }) : ''}
    ${o.warn ? `<p class="${o.err ? 'err-text' : 'warn-text'} note-line">${icon(o.err ? 'err' : 'warn', 18)}<span>${o.warn}</span></p>` : ''}
    ${sel >= 0 ? btn(o.btnLabel || `借種（${fmt(STUD[sel].price)} 幣）`, { kind: 'pink', block: true, ic: 'heart', disabled: o.btnDisabled ?? !(o.dam >= 0 && o.outcome === 'ok') }) : ''}
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
part18('S18-05', '市場：載入中、載入失敗、沒有人上架', '#crop', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div id="crop" class="stack">${['loading', 'failed', 'empty'].map((m) => `<article class="card">${m === 'loading' ? `<div class="oc-empty"><span class="spinner"></span><span>載入中…</span></div>` : m === 'failed' ? `<div class="oc-empty"><span class="err-text">${icon('err', 20)} 載入失敗</span>${btn('重新整理', { small: true, ic: 'refresh' })}</div>` : `<div class="oc-empty"><span>目前沒有別人上架的公牛</span></div>`}</article>`).join('')}</div>` }));
full18('S18-06', '選了公牛和母牛：機率、費用、借種', (ctx) => studPage(ctx, { sel: 2, dam: 0, outcome: 'ok', scrollTo: '.outcome-card' }));
part18('S18-07', '還沒選母牛', '#crop', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div id="crop" class="stack">${outcomeCard('none', { fee: '1,820 幣（付給主人）' }).replace('請選一頭公牛和一頭母牛', '先選一頭要借的公牛，再選自己的母牛')}${btn('借種（1,820 幣）', { kind: 'pink', block: true, ic: 'heart', disabled: true })}</div>` }));
part18('S18-08', '金幣不夠、牛舍滿了', '#crop', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div id="crop" class="stack"><p class="warn-text note-line">${icon('warn', 18)}<span>金幣不夠，還差 1,520 幣</span></p><p class="warn-text note-line">${icon('warn', 18)}<span>牛舍滿了，先擴建或出貨，才有位子給小牛</span></p>${btn('借種（1,820 幣）', { kind: 'pink', block: true, ic: 'heart', disabled: true })}</div>` }));
full18('S18-09', '借種成功：小牛倒數', (ctx) => studPage(ctx, { sel: 2, dam: 0, outcome: 'ok', btnDisabled: true, btnLabel: '已借種', hud: { coins: RANCH.coins - 1820 }, after: calfCard('巧克力牛 #16', 2, '3 小時 58 分', { breed: 'chocolate', seed: 93 }), scrollTo: '.calf-card', overlays: toast('ok', '借種成功！付給主人 1,820 幣') }));
part18('S18-10', '借種失敗：公牛已經被借走', '.dialog', (ctx) => studPage(ctx, { sel: 2, dam: 0, outcome: 'ok', scrollTo: '.outcome-card', overlays: dialog({ title: '借不到了', body: `<p style="text-align:center">這頭公牛剛剛被別人借走，或主人下架了。<br>錢沒有扣。</p>`, buttons: btn('重新整理市場', { kind: 'primary', ic: 'refresh' }) }) }));
part18('S18-12', '借種費變了：公牛長大，價格跟剛剛看的不一樣', '.dialog', (ctx) => studPage(ctx, { sel: 3, dam: 0, outcome: 'ok', scrollTo: '.outcome-card', overlays: dialog({ title: '借種費變了', body: `<p style="text-align:center">這頭公牛長大了，借種費從 <b class="num">1,050</b> 幣變成 <b class="num">1,090</b> 幣。<br>要用新的價格借嗎？</p>`, buttons: `${btn('取消')}${btn('用新價格借（1,090 幣）', { kind: 'pink' })}` }) }));
part18('S18-13', '名字最長：8 個中文字、16 個英文字母（量測用）', '.list', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div class="list">${[{ ...STUD[2], owner: LONG_NAMES.cjk, tag: '#5821' }, { ...STUD[4], owner: LONG_NAMES.latin, tag: '#0907' }, { ...STUD[0], owner: LONG_NAMES.cjk }].map((l) => studRow(l)).join('')}</div>` }));
full18('S18-11', '借種紀錄', (ctx) => frame(ctx.dev, { tab: 'breed', content: `<div class="stack">
  <div class="page-head"><button class="icon-btn" aria-label="返回">${icon('back', 22)}</button><div class="grow"><h1>借種紀錄</h1><div class="sub">借出收入累計 ${fmt(STUD_INCOME)} 幣</div></div></div>
  <div class="filter"><button class="on">全部</button><button>借出</button><button>借入</button></div>
  <div class="list">${STUD_LOG.map((r) => `<article class="card log-row"><span class="log-dir ${r.dir}">${r.dir === 'out' ? '借出' : '借入'}</span>
    <div class="grow"><b>${r.cow}${r.dir === 'out' ? ' 借給' : ' 借自'} ${r.who}</b><div class="hint">${r.when}${r.calf ? `・生下 ${r.calf}` : ''}</div></div>
    <span class="log-amt ${r.dir}"><b class="num">${r.dir === 'out' ? '+' : '−'}${fmt(r.price)}</b> 幣</span></article>`).join('')}</div>
  <p class="hint" style="text-align:center">只保留最近 30 天的紀錄。</p></div>` }));

export const S08 = { id: 'S08', name: '配種', states: S };
export const S18 = { id: 'S18', name: '借種市場', states: S2 };
