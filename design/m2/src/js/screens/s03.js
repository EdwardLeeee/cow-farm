// S03 牧場主畫面
import { frame, btn, bar, toast, badge, tierChip, useChip, sexText, cowRow, icon, fmt, cowSVG, BREEDS } from '../kit.js';
import { ranchScene, HERD, WIDE } from '../scene.js';
import { RANCH, COWS, PEN, BUCKET, WAREHOUSE, MARKET, NEWS, sum, cowName, compact, vsBase, newsTag, newsText, MIX_COW } from '../fixtures.js';
import { t, tb, dur, useName, sexName, tierName, calfName, feedList } from '../i18n.js';
import { tierOf, MIX_MULT } from '../../cow/breeds.js';
import { TIER_CLS, tierTag, pctText, newsIcons } from './s06.js';

const L = '#4B3326';
// R1-A 的奶桶圖示（水位跟著百分比）
export function pailLevel(pct, size = 44) {
  const top = 17, bot = 44.5, lvl = bot - (bot - top) * (Math.min(100, pct) / 100);
  const body = 'M8 16.5h32l-3.4 25.4a3 3 0 0 1-3 2.6H14.4a3 3 0 0 1-3-2.6z';
  const id = `bk${Math.round(pct * 10)}${size}`;
  return `<svg viewBox="0 0 48 48" width="${size}" height="${size}" aria-hidden="true"><defs><clipPath id="${id}"><path d="${body}"/></clipPath></defs>
    <path d="M11 17C11 5.5 37 5.5 37 17" fill="none" stroke="${L}" stroke-width="2.6"/><path d="${body}" fill="#D6ECFA"/>
    <g clip-path="url(#${id})"><path d="M0 ${lvl} q6 -2.6 12 0 t12 0 t12 0 t12 0 V48 H0z" fill="#FFFFFF"/><path d="M0 ${lvl} q6 -2.6 12 0 t12 0 t12 0 t12 0" fill="none" stroke="#B9DDF5" stroke-width="1.6"/></g>
    <path d="${body}" fill="none" stroke="${L}" stroke-width="2.6" stroke-linejoin="round"/><path d="M13.5 22v15" stroke="#FFFFFF" stroke-width="2.4" stroke-linecap="round" opacity="0.9"/>
    <rect x="6.4" y="13.6" width="35.2" height="5.4" rx="2.7" fill="#EAF5FC" stroke="${L}" stroke-width="2.4"/></svg>`;
}

// 奶桶還要多久滿（真實時間）
function untilFull(b) { const m = Math.ceil(((b.cap - b.qty) / b.perHour) * 60); return dur({ h: Math.floor(m / 60), m: m % 60 }); }
const oneDec = (v) => (v >= 1000 ? fmt(Math.round(v)) : (Math.round(v * 10) / 10).toFixed(1).replace(/\.0$/, ''));
const freshOf = (lots) => (lots.length ? lots.reduce((m, l) => (l.fresh < m ? l.fresh : m), 1) : null);
// 比平常（基本價）高或低幾 %（D24）
const chgHTML = (m) => { const v = vsBase(m); return v === 0 ? `<span class="r flat">${t('s03.normal')}</span>` : `<span class="r ${v > 0 ? 'up' : 'down'}">${icon(v > 0 ? 'up' : 'down', 10)}<span class="num">${Math.abs(v)}%</span></span>`; };

export function dock(o = {}) {
  const b = { ...BUCKET, ...(o.bucket || {}) };
  const pct = Math.round((b.qty / b.cap) * 100);
  const full = pct >= 100;
  const milkLots = o.milkLots || WAREHOUSE.milk.slice(0, 3);
  const milk = o.milk ?? sum(milkLots), cap = o.cap ?? WAREHOUSE.cap;
  const fresh = freshOf(milkLots);
  const beef = o.beef ?? sum(WAREHOUSE.beef), rice = o.rice ?? sum(WAREHOUSE.rice);
  const mk = o.market || MARKET;
  const whFull = milk >= cap;
  // 頂端那一列：中間是場景位置指示（場景兩個螢幕寬，滑塊佔一半），右邊是收起／展開
  const panPct = Math.max(0, Math.min(50, ((o.pan || 0) / (WIDE - 390)) * 50));
  const head = `<div class="dock-head"><span class="pan-ind" aria-label="${t('s03.panAria')}"><i style="left:${panPct}%"></i></span>
      <button class="dock-toggle" aria-label="${o.collapsed ? t('s03.expandAria') : t('s03.collapseAria')}"><span class="dt-pill">${o.collapsed ? t('s03.expand') : t('s03.collapse')}<span class="dt-chev${o.collapsed ? ' up' : ''}">${icon('chevron', 14)}</span></span></button></div>`;
  const collectBtn = btn(o.collectLabel || t('collect'), { kind: 'blue', small: true, disabled: o.collectDisabled ?? b.qty <= 0, busy: o.collectBusy });
  if (o.collapsed) {
    // 收起來：只剩一條奶桶（收奶是最常按的，所以留著）；倉庫、收購價藏起來
    return `<section class="dock collapsed">${head}
    <article class="card bucket-slim${full ? ' is-full' : ''}">
      <span class="bs-icon">${pailLevel(pct, 34)}</span>
      <span class="bs-info"><span class="bs-top"><span class="bs-name">${t('bucketTitle')}</span><span class="num bs-pct">${pct}%</span>${full ? `<span class="bs-full">${t('s03.full')}</span>` : ''}</span>${bar(pct)}</span>
      ${collectBtn}
    </article>
  </section>`;
  }
  return `<section class="dock">${head}
    <article class="card bucket-card${full ? ' is-full' : ''}">
      <div class="bk-main">
        <div class="bk-icon">${pailLevel(pct)}</div>
        <div class="bk-info">
          <div class="bk-top"><span class="card-title blue">${t('bucketTitle')}</span><span class="num num-pct">${pct}%</span></div>
          ${bar(pct)}
          <div class="bk-count">${t('s03.bucketCount', { amount: `<span class="num">${oneDec(b.qty)} / ${fmt(b.cap)}</span>` })}<span class="bk-rate${full ? ' err-text' : ''}">${full ? t('s03.fullStopped') : b.perHour ? t('s03.fullIn', { time: untilFull(b) }) : t('s03.noMilkers')}</span></div>
        </div>
        ${collectBtn}
      </div>
    </article>
    <div class="dock-row">
      <article class="card mini storage">
        <div class="card-head"><span class="card-title">${t('warehouseTitle')}</span><span class="cap nowrap">${whFull ? t('s03.milkFull') : t('s03.milkUsed', { pct: Math.round((milk / cap) * 100) })}</span></div>
        <div class="mini-line"><span class="ic">${icon('milk', 18)}</span>${t('milk')}<span class="num">${compact(milk)}</span><span class="u">${t('unitMilk')}</span>${fresh != null ? `<span class="r${fresh < 0.3 ? ' bad' : ''}">${icon(fresh < 0.3 ? 'leafBad' : fresh < 0.7 ? 'leafOld' : 'leaf', 13)}<span class="num">${Math.round(fresh * 100)}%</span></span>` : ''}</div>
        <div class="mini-line"><span class="ic">${icon('beef', 18)}</span>${t('beef')}<span class="num">${compact(beef)}</span><span class="u">${t('unitBeef')}</span></div>
        <div class="mini-line"><span class="ic">${icon('rice', 18)}</span>${t('rice')}<span class="num">${compact(rice)}</span><span class="u">${t('unitRice')}</span></div>
      </article>
      <article class="card mini market">
        <div class="card-head"><span class="card-title green">${t('s03.prices')}</span><span class="cap">${t('s03.vsNormal')}</span></div>
        ${['milk', 'beef', 'rice'].map((k) => `<div class="mini-line"><span class="ic">${icon(k === 'milk' ? 'milk' : k === 'beef' ? 'beef' : 'rice', 18)}</span>${mk[k].name}<span class="num">${mk[k].price}</span>${chgHTML(mk[k])}</div>`).join('')}
      </article>
    </div>
  </section>`;
}

// o.pan：場景往右捲了多少（0–390）；o.collapsed：奶桶、倉庫、行情收起來；o.swipeHint：第一次打開牧場時的滑動提示
export function ranchPage(ctx, o = {}) {
  const dev = ctx.dev;
  const herd = o.herd || HERD;
  const sc = ranchScene(dev, herd, { wide: true, pan: o.pan || 0 });
  let over = '';
  if (o.bubble) {
    const a = sc.anchors[o.bubble];
    over += `<div class="bubble" style="left:${a.head[0]}px;top:${a.head[1] - 4}px">${icon('pail', 22)}<span class="bubble-text">${t('s03.bubbleFull')}</span></div>`;
  }
  if (o.pop) {
    const a = sc.anchors[o.pop.id];
    const left = Math.max(12, Math.min(dev.w - 220, a.head[0] - 43));
    // data-foot：牛腳的位置；上面放不下時名片放到牛的下面（kit.js 的 placeCowPop）
    over += `<div class="cow-pop" data-foot="${a.foot[1]}" data-hx="${a.head[0]}"${o.pop.noflip ? ' data-noflip' : ''} style="left:${left}px;top:${a.head[1] - 14}px;transform:translateY(-100%)">${o.pop.html}</div>`;
  }
  const pen = o.pen || PEN;
  const body = `
    <div class="ticker"><span class="ticker-icon">${icon('news', 20)}</span><span class="ticker-text" data-marquee>${newsTag(NEWS[0])}${newsText(NEWS[0])}</span></div>
    <button class="pen-pill${pen.used >= pen.slots ? ' full' : ''}">${icon('barn', 22)}${t('cowsTitle')}<span class="num">${pen.used} / ${pen.slots}</span>${icon('chevron', 16)}</button>
    ${o.center || ''}
    ${o.swipeHint ? `<div class="swipe-hint"><span class="sh-arrow">${icon('back', 18)}</span>${icon('hand', 24)}<span>${t('s03.swipeHint')}</span><span class="sh-arrow r">${icon('chevron', 18)}</span></div>` : ''}
    ${dock({ ...(o.dock || {}), pan: o.pan || 0, collapsed: !!o.collapsed })}`;
  return frame(dev, { tab: 'ranch', scene: sc.svg, body, hud: o.hud || {}, overlays: over + (o.overlays || ''), offline: o.offline });
}

// 牛的狀態標籤：小牛、老牛、工作中、上架中、已配種（牛舍清單和點牛的名片都用這個）
export function statusChips(c) {
  const out = [];
  if (c.age === 'calf') out.push(badge('calf', t('stageCalf')));
  if (c.age === 'old') out.push(badge('old', t('stageOld')));
  if (c.field != null) out.push(badge('working', t('badgeWorking')));
  if (c.listed) out.push(badge('listed', t('badgeListed')));
  if (c.bred) out.push(badge('bred', t('badgeBred')));
  return out;
}

// 牛舍清單的一列
export function cowListRow(c) {
  const b = BREEDS[c.breed], tier = tierOf(b), sep = t('g.sep');
  const chips = [useChip(b.use), `<span class="use">${sexText(c.sex)}</span>`, ...(c.age === 'calf' ? [] : [tierChip(tier)]), ...statusChips(c)];
  let meta;
  if (c.age === 'calf') meta = t('growUp', { v: dur(c.grow_) });
  else if (c.field != null) meta = t('s03.metaField', { n: c.field + 1, rate: c.rice });
  else if (c.listed) meta = t('s03.metaListed', { price: fmt(c.listed) });
  else if (b.use === 'dairy' && c.sex === 'cow') meta = t('milkRate', { v: c.milk }) + sep + t('weight', { v: c.kg });
  else meta = t('weight', { v: fmt(c.kg) }) + sep + t('s03.metaValue', { v: fmt(c.value) });
  return cowRow(c, { chips: chips.join(''), meta, right: `<span class="chev">${icon('chevron', 20)}</span>` });
}

const S = [];
const full = (id, name, render, x = {}) => S.push({ id, name, type: 'full', render, ...x });
const part = (id, name, crop, render, x = {}) => S.push({ id, name, type: 'part', crop, render, ...x });

full('S03-01', '一般', (ctx) => ranchPage(ctx));

full('S03-02', '奶桶滿了', (ctx) => ranchPage(ctx, {
  herd: HERD.map((c) => (c.milk ? { ...c, pose: 'front' } : c)),
  bubble: 3,
  dock: { bucket: { qty: 42 } },
}));

full('S03-03', '收奶成功', (ctx) => ranchPage(ctx, {
  dock: { bucket: { qty: 0 }, milkLots: [{ qty: 36.4, tier: 0, fresh: 1 }, ...WAREHOUSE.milk.slice(0, 3)] },
  overlays: toast('ok', t('collected', { v: 36.4 })),
}));

full('S03-04', '倉庫滿了只收一部分', (ctx) => ranchPage(ctx, {
  dock: { bucket: { qty: 12.4 }, milk: 225, milkLots: [{ qty: 24, tier: 0, fresh: 1 }, ...WAREHOUSE.milk.slice(0, 3)] },
  overlays: `<div class="toast warn action-toast"><span class="t-icon">${icon('warn', 22)}</span><span class="t-text">${tb('s03.partial', { n: 24, left: 12.4 })}</span>${btn(t('upWarehouse'), { small: true, kind: 'primary' })}</div>`,
}));

part('S03-05', '奶桶是 0：收奶鈕停用', '.bucket-card', (ctx) => ranchPage(ctx, { dock: { bucket: { qty: 0 } } }));

// 點牛的小名片：品種＋編號、用途、公母、稀有度、狀態標籤（scope.md S03-06；ceo 2026-10-02 補狀態）。
// 下面那一行：產奶的母乳牛寫產奶，小牛寫長大還要，其他寫體重
export function popHtml(c) {
  const b = BREEDS[c.breed], tier = tierOf(b);
  const chips = [useChip(b.use), `<span class="use">${sexName(c.sex)}</span>`, ...(c.age === 'calf' ? [] : [tierChip(tier)]), ...statusChips(c)];
  const meta = c.age === 'calf' ? t('growUp', { v: dur(c.grow_) }) : b.use === 'dairy' && c.sex === 'cow' ? t('s03.popMilk', { tier: tierName(tier), n: c.milk }) : t('weight', { v: c.kg });
  return `<div class="name">${cowName(c)}</div><div class="chips" style="margin-top:4px">${chips.join('')}</div><div class="meta">${meta}</div>${btn(t('s03.popDetail'), { small: true, block: true, kind: 'primary' })}`;
}
full('S03-06', '點一頭牛：轉正面、跳出小名片', (ctx) => ranchPage(ctx, {
  herd: HERD.map((h) => (h.id === 12 ? { ...h, pose: 'front' } : h)),
  pop: { id: 12, html: popHtml(COWS.find((x) => x.id === 12)) },
}));

// ---------- 點後排的牛：名片的位置（使用者 2026-10-02 核准「放到牛的下面」；合成時另外出一張「名片位置-狀態表」） ----------
// 名片平常在頭頂上方 14、尖角朝下；上面放不下（名片上緣會碰到頂列：頂列下緣再留 6）就放到牛的下面（腳下 14）、尖角朝上
const tapBack = (ctx, id, noflip = false) => ranchPage(ctx, { herd: HERD.map((h) => (h.id === id ? { ...h, pose: 'front' } : h)), pop: { id, html: popHtml(COWS.find((x) => x.id === id)), noflip } });
const popDraft = (id, name, render, x = {}) => part(id, name, '.phone', render, { board: '名片位置-狀態表', ...x });
// S03-19 只是對照（舊的放法），留在狀態表上；只有繁中，不列進 scope.md 的頁面表格
popDraft('S03-19', '點後排的牛：照原本的放法（頭頂上方），會蓋到頂列、跑馬燈和牛欄膠囊（只是對照）', (ctx) => tapBack(ctx, 14, true), { zhOnly: true });
popDraft('S03-20', '點後排的牛：上面放不下，名片放到牛的下面、尖角朝上', (ctx) => tapBack(ctx, 14));
popDraft('S03-21', '點後排的牛（右邊那頭）：一樣放到牛的下面', (ctx) => tapBack(ctx, 8));

function listPage(ctx, { cows = COWS, pen = PEN, filter = 0, tall = true, note = '' } = {}) {
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${t('cowsTitle')}</h1><div class="sub">${t('penSummary', { used: pen.used, slots: pen.slots })}${pen.used >= pen.slots ? t('s03.penFullSuffix') : ''}</div></div>${btn(t('s03.expandPen'), { small: true, kind: 'primary', ic: 'plus' })}</div>
    <div class="filter" data-hscroll>${[t('g.all'), useName('dairy'), useName('draft'), useName('beef')].map((f, i) => `<button class="${i === filter ? 'on' : ''}">${f}</button>`).join('')}</div>
    ${note}
    <div class="list">${cows.map(cowListRow).join('')}</div>
  </div>`;
  return frame(ctx.dev, { tab: 'ranch', content, tall });
}

full('S03-07', '牛舍清單（長頁）', (ctx) => listPage(ctx), { tall: true });

full('S03-08', '一頭牛都沒有', (ctx) => ranchPage(ctx, {
  herd: [],
  pen: { used: 0, slots: 10 },
  dock: { bucket: { qty: 0, perHour: 0 } },
  center: `<div class="card empty-ranch" style="position:absolute;left:24px;right:24px;top:calc(var(--safe-top) + var(--hud-h) + 112px);z-index:15">
    <div class="empty"><div class="t1">${t('noCows')}</div><div class="t2">${t('s03.emptyHint')}</div>${btn(t('s03.goShop'), { kind: 'primary' })}</div></div>`,
}));

full('S03-09', '數字最大、牛舍滿（量測用）', (ctx) => ranchPage(ctx, {
  hud: { coins: 1234567, level: 14, xp: 96 },
  pen: { used: 40, slots: 40 },
  dock: {
    bucket: { qty: 12261, cap: 12261, perHour: 1680 }, milk: 43786, cap: 43786, milkLots: [{ qty: 43786, fresh: 0.99 }],
    beef: 12480, rice: 9860,
    market: { milk: { ...MARKET.milk, price: 20.4, chg: 70.0 }, beef: { ...MARKET.beef, price: 7.2, chg: -40.0 }, rice: { ...MARKET.rice, price: 8.5, chg: 70.0 } },
  },
}));

// D24：大新聞（幅度 ±20% 以上）時跳出一次；按「去市場看看」到市場頁、選好那種商品
part('S03-15', '大新聞提示：收購價大漲（只跳出一次）', '.big-news', (ctx) => ranchPage(ctx, {
  dock: { market: { ...MARKET, beef: { ...MARKET.beef, price: 15.0 } } },
  overlays: `<div class="big-news card"><button class="bn-close" aria-label="${t('g.close')}">${icon('close', 18)}</button><span class="bn-tag">${t('s06.bigNews')}</span>
    <div class="bn-main"><span class="bn-ic">${icon('beef', 34)}</span><div class="grow"><b>${t('news.beef_up.1')}</b><p>${t('s03.bigNewsBody', { name: t('beef'), chg: '<b class="up-text">+25%</b>', price: 15, unit: t('unitBeef') })}</p></div></div>
    ${btn(t('s03.bigNewsGo'), { kind: 'primary', block: true, ic: 'coin' })}</div>`,
}));
// ---------- 新文案（使用者 2026-10-02 核准；合成時另外出一張「新文案-狀態表」，原本的 S03 局部狀態表不變） ----------
// 全部商品一起漲跌 20% 以上（新聞的 commodity 是 null、targets 有三種；漲跌幅 pct 只有一個）：
// 說明句改成「全部商品的收購價 +22%」，不寫單一商品的名字和價格；圖示放三種商品。
const bigNewsAll = (ctx, up) => ranchPage(ctx, {
  overlays: `<div class="big-news card"><button class="bn-close" aria-label="${t('g.close')}">${icon('close', 18)}</button><span class="bn-tag">${t('s06.bigNews')}</span>
    <div class="bn-main"><span class="bn-ic all">${icon('milk', 22)}${icon('beef', 22)}${icon('rice', 22)}</span><div class="grow"><b>${t(up ? 'news.all_up.1' : 'news.all_down.1')}</b><p>${t('s03.bigNewsAll', { chg: up ? '<b class="up-text">+22%</b>' : '<b class="down-text">−21%</b>' })}</p></div></div>
    ${btn(t('s03.bigNewsGo'), { kind: 'primary', block: true, ic: 'coin' })}</div>`,
});
const draft = (id, name, crop, render) => part(id, name, crop, render, { board: '新文案-狀態表' });
// ---------- D33 超級大事件、超級黑天鵝的提示（使用者 2026-10-03 選第 12 輪 05-A；另外出一張「超級事件-狀態表」） ----------
// 位置、大小、只跳一次、按鈕都跟大新聞提示（S03-15～17）一樣；換成金色（超級大事件）、深色（超級黑天鵝），標籤換掉，幅度的字放大。
// 標題用專屬標題（news.<商品>_super／_swan）
const superNews = (ctx, n, mk = MARKET) => ranchPage(ctx, {
  dock: { market: mk },
  overlays: `<div class="big-news card ${TIER_CLS[n.tier]}">${n.tier === 'super' ? `<span class="bn-spark" style="left:146px;top:8px">${icon('sparkle', 16)}</span><span class="bn-spark" style="left:168px;top:22px">${icon('sparkle', 10)}</span>` : ''}<button class="bn-close" aria-label="${t('g.close')}">${icon('close', 18)}</button><span class="bn-tag">${tierTag(n)}</span>
    <div class="bn-main">${newsIcons(n, 'bn-ic', 34, 22)}<div class="grow"><b>${t(n.tk)}</b><p>${n.c === 'all' ? t('s03.bigNewsAll', { chg: `<b class="${n.dir}-text">${pctText(n)}</b>` }) : t('s03.bigNewsBody', { name: t(n.c), chg: `<b class="${n.dir}-text">${pctText(n)}</b>`, price: n.price, unit: t(n.c === 'milk' ? 'unitMilk' : n.c === 'beef' ? 'unitBeef' : 'unitRice') })}</p></div></div>
    ${btn(t('s03.bigNewsGo'), { kind: 'primary', block: true, ic: 'coin' })}</div>`,
});
const superPart = (id, name, render) => part(id, name, '.big-news', render, { board: '超級事件-狀態表' });
superPart('S03-22', '超級大事件提示：牛肉收購價 +100%', (ctx) => superNews(ctx, { c: 'beef', tier: 'super', dir: 'up', pct: 1, price: 24, tk: 'news.beef_super.1' }, { ...MARKET, beef: { ...MARKET.beef, price: 24 } }));
superPart('S03-23', '超級黑天鵝提示：牛奶收購價 −90%', (ctx) => superNews(ctx, { c: 'milk', tier: 'crash', dir: 'down', pct: -0.9, price: 1.2, tk: 'news.milk_swan.1' }, { ...MARKET, milk: { ...MARKET.milk, price: 1.2 } }));
superPart('S03-24', '超級大事件提示：全部商品一起 +100%', (ctx) => superNews(ctx, { c: 'all', tier: 'super', dir: 'up', pct: 1, tk: 'news.all_super.1' }, { milk: { ...MARKET.milk, price: 24 }, beef: { ...MARKET.beef, price: 24 }, rice: { ...MARKET.rice, price: 10 } }));
draft('S03-16', '大新聞提示：全部商品一起大漲（新文案）', '.big-news', (ctx) => bigNewsAll(ctx, true));
draft('S03-17', '大新聞提示：全部商品一起大跌（新文案）', '.big-news', (ctx) => bigNewsAll(ctx, false));
// 收奶時順便丟掉倉庫裡壞掉的牛奶（協定收奶回應的 spoiled 大於 0）
draft('S03-18', '收奶成功，順便丟掉壞掉的牛奶（新文案）', '.toast', (ctx) => ranchPage(ctx, {
  dock: { bucket: { qty: 0 }, milkLots: [{ qty: 36.4, tier: 0, fresh: 1 }, ...WAREHOUSE.milk.slice(0, 3)] },
  overlays: toast('ok', t('collectedSpoiled', { v: 36.4, n: 2 })),
}));

full('S03-11', '收起來：奶桶、倉庫、收購價收成一條（收奶鈕留著）', (ctx) => ranchPage(ctx, { collapsed: true }));
part('S03-12', '收起來的那一條：奶桶滿了、奶桶是 0', '#crop', (ctx) => frame(ctx.dev, { tab: null, hud: false, content: `<div id="crop" class="g-sheet slim-sheet">${dock({ collapsed: true, bucket: { qty: 42 } })}${dock({ collapsed: true, bucket: { qty: 0 } })}</div>` }));
full('S03-13', '往右滑：牧場的另一邊（池塘、大樹）', (ctx) => ranchPage(ctx, { pan: WIDE - 390 }));
full('S03-14', '第一次打開牧場：提示可以左右滑動（只出現一次）', (ctx) => ranchPage(ctx, { swipeHint: true }));
// 小牛長大揭曉、變成雜種牛（v0.3 第 1.1 節；使用者 2026-10-03 選第 13 輪 03-A）：A-13 播到最後停住的樣子。
// 長大的樣子是雜種牛、名字換成「雜種牛 #20」、「雜種」標籤代替稀有度；橘字說少吃了哪幾種（不說原本會是哪個品種）、
// 說明倍數和配種照樣可能長出稀有的品種；要按「好」才關（一般的長大揭曉點一下就關）。不接 A-06
function mixGrown(ctx) {
  const c = MIX_COW;
  const inner = `<div class="disc-title gs-title mix-title">${t('anim.grownUp', { cow: calfName('dairy', c.id) })}</div>
    <div class="grow-stage mix-stage"><div class="gs-adult on">${cowSVG({ breed: c.breed, sex: c.sex }, { w: 180, h: 158 })}</div></div>
    <div class="reveal-name gs-name mix-end"><b>${cowName(c)}</b><div class="chips">${useChip('dairy')}<span class="use">${sexName(c.sex)}</span>${badge('mix', t('badgeMix'))}</div>
      <p class="warn-text mr-why">${t('anim.mixGrown', { feeds: feedList(c.missed) })}</p>
      <p class="hint mr-hint">${t('anim.mixHint', { mult: MIX_MULT })}</p>
      ${btn(t('ok'), { kind: 'primary', block: true })}</div>`;
  return ranchPage(ctx).replace('<div class="overlays">', `<div class="overlays"><div class="backdrop"></div><div class="reveal">${inner}</div>`);
}
full('S03-25', '小牛長大揭曉：變成雜種牛（A-13 的結尾）', (ctx) => mixGrown(ctx));
part('S03-10', '耕牛在田裡：清單顯示「工作中」、場景裡看不到', '#crop', (ctx) => frame(ctx.dev, {
  tab: 'ranch', content: `<div id="crop" class="list" style="padding:4px 0 8px">${COWS.filter((c) => c.field != null).map(cowListRow).join('')}</div>`,
}));

export default { id: 'S03', name: '牧場', states: S };
