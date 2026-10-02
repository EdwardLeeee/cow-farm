// S03 牧場主畫面
import { frame, btn, bar, toast, badge, tierChip, useChip, sexText, cowRow, icon, fmt, BREEDS } from '../kit.js';
import { ranchScene, HERD, WIDE } from '../scene.js';
import { RANCH, COWS, PEN, BUCKET, WAREHOUSE, MARKET, NEWS, sum, cowName, compact, vsBase, newsTag, newsText } from '../fixtures.js';
import { t, tb, dur, useName, sexName, tierName } from '../i18n.js';
import { tierOf } from '../../cow/breeds.js';

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
    over += `<div class="cow-pop" style="left:${left}px;top:${a.head[1] - 14}px;transform:translateY(-100%)">${o.pop.html}</div>`;
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

// 牛舍清單的一列
export function cowListRow(c) {
  const b = BREEDS[c.breed], tier = tierOf(b), sep = t('g.sep');
  const chips = [useChip(b.use), `<span class="use">${sexText(c.sex)}</span>`, tierChip(tier)];
  if (c.age === 'calf') chips.push(badge('calf', t('stageCalf')));
  if (c.age === 'old') chips.push(badge('old', t('stageOld')));
  if (c.field != null) chips.push(badge('working', t('badgeWorking')));
  if (c.listed) chips.push(badge('listed', t('badgeListed')));
  if (c.bred) chips.push(badge('bred', t('badgeBred')));
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

full('S03-06', '點一頭牛：轉正面、跳出小名片', (ctx) => {
  const c = COWS.find((x) => x.id === 12);
  return ranchPage(ctx, {
    herd: HERD.map((h) => (h.id === 12 ? { ...h, pose: 'front' } : h)),
    pop: { id: 12, html: `<div class="name">${cowName(c)}</div><div class="chips" style="margin-top:4px">${useChip('dairy')}<span class="use">${sexName('cow')}</span>${tierChip(3)}</div><div class="meta">${t('s03.popMilk', { tier: tierName(3), n: 14 })}</div>${btn(t('s03.popDetail'), { small: true, block: true, kind: 'primary' })}` },
  });
});

function listPage(ctx, { cows = COWS, pen = PEN, filter = 0, tall = true, note = '' } = {}) {
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${t('cowsTitle')}</h1><div class="sub">${t('penSummary', { used: pen.used, slots: pen.slots })}${pen.used >= pen.slots ? t('s03.penFullSuffix') : ''}</div></div>${btn(t('s03.expandPen'), { small: true, kind: 'primary', ic: 'plus' })}</div>
    <div class="filter">${[t('g.all'), useName('dairy'), useName('draft'), useName('beef')].map((f, i) => `<button class="${i === filter ? 'on' : ''}">${f}</button>`).join('')}</div>
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
full('S03-11', '收起來：奶桶、倉庫、收購價收成一條（收奶鈕留著）', (ctx) => ranchPage(ctx, { collapsed: true }));
part('S03-12', '收起來的那一條：奶桶滿了、奶桶是 0', '#crop', (ctx) => frame(ctx.dev, { tab: null, hud: false, content: `<div id="crop" class="g-sheet slim-sheet">${dock({ collapsed: true, bucket: { qty: 42 } })}${dock({ collapsed: true, bucket: { qty: 0 } })}</div>` }));
full('S03-13', '往右滑：牧場的另一邊（池塘、大樹）', (ctx) => ranchPage(ctx, { pan: WIDE - 390 }));
full('S03-14', '第一次打開牧場：提示可以左右滑動（只出現一次）', (ctx) => ranchPage(ctx, { swipeHint: true }));
part('S03-10', '耕牛在田裡：清單顯示「工作中」、場景裡看不到', '#crop', (ctx) => frame(ctx.dev, {
  tab: 'ranch', content: `<div id="crop" class="list" style="padding:4px 0 8px">${COWS.filter((c) => c.field != null).map(cowListRow).join('')}</div>`,
}));

export default { id: 'S03', name: '牧場', states: S };
