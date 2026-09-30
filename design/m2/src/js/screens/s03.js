// S03 牧場主畫面
import { frame, btn, bar, toast, badge, tierChip, useChip, sexText, cowRow, icon, fmt, BREEDS } from '../kit.js';
import { ranchScene, HERD } from '../scene.js';
import { RANCH, COWS, PEN, BUCKET, WAREHOUSE, MARKET, NEWS, sum, cowName, compact } from '../fixtures.js';
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
function untilFull(b) { const m = Math.ceil(((b.cap - b.qty) / b.perHour) * 60); return m >= 60 ? `${Math.floor(m / 60)} 小時${m % 60 ? ` ${m % 60} 分` : ''}` : `${m} 分`; }
const oneDec = (v) => (v >= 1000 ? fmt(Math.round(v)) : (Math.round(v * 10) / 10).toFixed(1).replace(/\.0$/, ''));
const freshOf = (lots) => (lots.length ? lots.reduce((m, l) => (l.fresh < m ? l.fresh : m), 1) : null);
const chgHTML = (m) => `<span class="r ${m.chg >= 0 ? 'up' : 'down'}">${icon(m.chg >= 0 ? 'up' : 'down', 10)}<span class="num">${Math.abs(m.chg).toFixed(1)}%</span></span>`;

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
  return `<section class="dock">
    <article class="card bucket-card${full ? ' is-full' : ''}">
      <div class="bk-main">
        <div class="bk-icon">${pailLevel(pct)}</div>
        <div class="bk-info">
          <div class="bk-top"><span class="card-title blue">奶桶</span><span class="num num-pct">${pct}%</span></div>
          ${bar(pct)}
          <div class="bk-count"><span class="num">${oneDec(b.qty)} / ${fmt(b.cap)}</span> 瓶<span class="bk-rate${full ? ' err-text' : ''}">${full ? '滿了，停止產奶' : b.perHour ? `約 ${untilFull(b)}後滿` : '沒有牛在產奶'}</span></div>
        </div>
        ${btn(o.collectLabel || '收奶', { kind: 'blue', small: true, disabled: o.collectDisabled ?? b.qty <= 0, busy: o.collectBusy })}
      </div>
    </article>
    <div class="dock-row">
      <article class="card mini storage">
        <div class="card-head"><span class="card-title">倉庫</span><span class="cap nowrap${whFull ? ' err-text' : ''}">${whFull ? '牛奶滿了' : `牛奶用了 ${Math.round((milk / cap) * 100)}%`}</span></div>
        <div class="mini-line"><span class="ic">${icon('milk', 18)}</span>牛奶<span class="num">${compact(milk)}</span><span class="u">瓶</span>${fresh != null ? `<span class="r${fresh < 0.3 ? ' bad' : ''}">${icon(fresh < 0.3 ? 'leafBad' : fresh < 0.7 ? 'leafOld' : 'leaf', 13)}<span class="num">${Math.round(fresh * 100)}%</span></span>` : ''}</div>
        <div class="mini-line"><span class="ic">${icon('beef', 18)}</span>牛肉<span class="num">${compact(beef)}</span><span class="u">公斤</span></div>
        <div class="mini-line"><span class="ic">${icon('rice', 18)}</span>稻米<span class="num">${compact(rice)}</span><span class="u">公斤</span></div>
      </article>
      <article class="card mini market">
        <div class="card-head"><span class="card-title green">行情</span><span class="cap">幣／單位</span></div>
        ${['milk', 'beef', 'rice'].map((k) => `<div class="mini-line"><span class="ic">${icon(k === 'milk' ? 'milk' : k === 'beef' ? 'beef' : 'rice', 18)}</span>${mk[k].name}<span class="num">${mk[k].price}</span>${chgHTML(mk[k])}</div>`).join('')}
      </article>
    </div>
  </section>`;
}

export function ranchPage(ctx, o = {}) {
  const dev = ctx.dev;
  const herd = o.herd || HERD;
  const sc = ranchScene(dev, herd);
  let over = '';
  if (o.bubble) {
    const a = sc.anchors[o.bubble];
    over += `<div class="bubble" style="left:${a.head[0]}px;top:${a.head[1] - 4}px">${icon('pail', 22)}<span class="bubble-text">奶桶滿了</span></div>`;
  }
  if (o.pop) {
    const a = sc.anchors[o.pop.id];
    const left = Math.max(12, Math.min(dev.w - 220, a.head[0] - 43));
    over += `<div class="cow-pop" style="left:${left}px;top:${a.head[1] - 14}px;transform:translateY(-100%)">${o.pop.html}</div>`;
  }
  const pen = o.pen || PEN;
  const body = `
    <div class="ticker"><span class="ticker-icon">${icon('news', 20)}</span><span class="ticker-text" data-marquee>【${NEWS[0].tag}】${NEWS[0].text}</span></div>
    <button class="pen-pill${pen.used >= pen.slots ? ' full' : ''}">${icon('barn', 22)}我的牛<span class="num">${pen.used} / ${pen.slots}</span>${icon('chevron', 16)}</button>
    ${o.center || ''}
    ${dock(o.dock || {})}`;
  return frame(dev, { tab: 'ranch', scene: sc.svg, body, hud: o.hud || {}, overlays: over + (o.overlays || ''), offline: o.offline });
}

// 牛舍清單的一列
export function cowListRow(c) {
  const b = BREEDS[c.breed], t = tierOf(b);
  const chips = [useChip(b.use), `<span class="use">${sexText(c.sex)}</span>`, tierChip(t)];
  if (c.age === 'calf') chips.push(badge('calf', '小牛'));
  if (c.age === 'old') chips.push(badge('old', '老牛'));
  if (c.field != null) chips.push(badge('working', '工作中'));
  if (c.listed) chips.push(badge('listed', '上架中'));
  if (c.bred) chips.push(badge('bred', '已配種'));
  let meta;
  if (c.age === 'calf') meta = `長大還要 ${c.grow}`;
  else if (c.field != null) meta = `在第 ${c.field + 1} 塊田・稻米 ${c.rice} 公斤／時`;
  else if (c.listed) meta = `借種上架中：${fmt(c.listed)} 幣`;
  else if (b.use === 'dairy' && c.sex === 'cow') meta = `產奶 ${c.milk} 瓶／時・體重 ${c.kg} 公斤`;
  else meta = `體重 ${fmt(c.kg)} 公斤・估值約 ${fmt(c.value)} 幣`;
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
  overlays: toast('ok', '收了 36.4 瓶牛奶，放進倉庫了'),
}));

full('S03-04', '倉庫滿了只收一部分', (ctx) => ranchPage(ctx, {
  dock: { bucket: { qty: 12.4 }, milk: 225, milkLots: [{ qty: 24, tier: 0, fresh: 1 }, ...WAREHOUSE.milk.slice(0, 3)] },
  overlays: `<div class="toast warn action-toast"><span class="t-icon">${icon('warn', 22)}</span><span class="t-text">倉庫滿了，收進 24 瓶，<br>還有 12.4 瓶在奶桶裡</span>${btn('加大倉庫', { small: true, kind: 'primary' })}</div>`,
}));

part('S03-05', '奶桶是 0：收奶鈕停用', '.bucket-card', (ctx) => ranchPage(ctx, { dock: { bucket: { qty: 0 } } }));

full('S03-06', '點一頭牛：轉正面、跳出小名片', (ctx) => {
  const c = COWS.find((x) => x.id === 12);
  return ranchPage(ctx, {
    herd: HERD.map((h) => (h.id === 12 ? { ...h, pose: 'front' } : h)),
    pop: { id: 12, html: `<div class="name">${cowName(c)}</div><div class="chips" style="margin-top:4px">${useChip('dairy')}<span class="use">母</span>${tierChip(3)}</div><div class="meta">產草莓牛奶 14 瓶／時</div>${btn('看詳細', { small: true, block: true, kind: 'primary' })}` },
  });
});

function listPage(ctx, { cows = COWS, pen = PEN, filter = 0, tall = true, note = '' } = {}) {
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="返回">${icon('back', 22)}</button><div class="grow"><h1>我的牛</h1><div class="sub">牛舍 ${pen.used} / ${pen.slots} 格${pen.used >= pen.slots ? '（滿了）' : ''}</div></div>${btn('擴建', { small: true, kind: 'primary', ic: 'plus' })}</div>
    <div class="filter">${['全部', '乳牛', '耕牛', '肉牛'].map((f, i) => `<button class="${i === filter ? 'on' : ''}">${f}</button>`).join('')}</div>
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
  center: `<div class="card empty-ranch" style="position:absolute;left:24px;right:24px;top:calc(var(--safe-top) + 250px);z-index:15">
    <div class="empty"><div class="t1">牛舍裡還沒有牛</div><div class="t2">到商店抽一頭牛，或等配種的小牛出生。</div>${btn('去商店', { kind: 'primary' })}</div></div>`,
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

part('S03-10', '耕牛在田裡：清單顯示「工作中」、場景裡看不到', '#crop', (ctx) => frame(ctx.dev, {
  tab: 'ranch', content: `<div id="crop" class="list" style="padding:4px 0 8px">${COWS.filter((c) => c.field != null).map(cowListRow).join('')}</div>`,
}));

export default { id: 'S03', name: '牧場', states: S };
