// S05 倉庫（批次、新鮮度）。容量只算牛奶；牛肉、稻米目前不佔容量（企劃書 4.3）。賣出從最舊的一批先賣。
import { frame, btn, bar, icon, fmt, tierChip, mixStar, badge, empty, cowSVG } from '../kit.js';
import { WAREHOUSE, sum } from '../fixtures.js';
import { ranchPage } from './s03.js';
import { GRADE_BG } from './s04.js';
import { t, ago, cowName, tierName } from '../i18n.js';
import { MIX_MULT } from '../../cow/breeds.js';

const MULT = [1.0, 1.3, 1.7, 2.5];
// 雜種牛的批次（v0.3 第 1.1 節；協定 milk_lots／beef_lots 的 hybrid，ceo 2026-10-03）：不放稀有度，改「雜種」標籤；倍數讀 economy.hybrid_mult
const lotChip = (l) => (l.hybrid ? mixStar() : tierChip(l.tier));
const freshIcon = (v) => (v < 0.3 ? 'leafBad' : v < 0.7 ? 'leafOld' : 'leaf');

export function milkLot(l) {
  const bad = l.fresh < 0.3;
  return `<div class="lot${bad ? ' bad' : ''}">
    <div class="lot-top"><span class="lot-ic">${icon('milk', 22)}</span><b class="num lot-q">${fmt(l.qty)}</b><span class="u">${t('unitMilk')}</span>${lotChip(l)}<span class="lot-name">${l.hybrid ? t('s05.mixMilk') : t('s05.milkName', { tier: tierName(l.tier) })} ×${(l.hybrid ? MIX_MULT : MULT[l.tier]).toFixed(1)}</span>${bad ? `<span class="badge full">${t('s05.spoiling')}</span>` : ''}</div>
    <div class="lot-fresh">${icon(freshIcon(l.fresh), 14)}<span class="k">${t('s05.fresh')}</span>${bar(l.fresh * 100, { color: bad ? 'red' : l.fresh < 0.7 ? 'yellow' : 'green' })}<b class="num">${Math.round(l.fresh * 100)}%</b></div>
    <div class="lot-sub">${t('s05.collectedAgo', { ago: ago(l.ago) })}${bad ? t('g.sep') + t('s05.spoilIn', { h: 20 }) : ''}</div>
  </div>`;
}
function beefLot(l) {
  return `<div class="lot"><div class="lot-top"><span class="lot-ic">${icon('beef', 22)}</span><b class="num lot-q">${fmt(l.qty)}</b><span class="u">${t('unitBeef')}</span><b class="gchip" style="background:${GRADE_BG[l.grade]}">${l.grade}</b>${lotChip(l)}<span class="lot-name">${t('s05.stored', { pct: Math.round(l.factor * 100) })}</span></div>
    <div class="lot-sub">${t('s05.shippedFrom', { cow: cowName(l.cow.breed, l.cow.id) })}${t('g.sep')}${ago(l.ago)}</div></div>`;
}
function riceLot(l) {
  return `<div class="lot"><div class="lot-top"><span class="lot-ic">${icon('rice', 22)}</span><b class="num lot-q">${fmt(l.qty)}</b><span class="u">${t('unitRice')}</span><span class="lot-name">${t('s05.stored', { pct: Math.round(l.quality * 100) })}</span></div>
    <div class="lot-sub">${t('s05.collectedAgo', { ago: ago(l.ago) })}</div></div>`;
}

function page(ctx, { milk = WAREHOUSE.milk, beef = WAREHOUSE.beef, rice = WAREHOUSE.rice, cap = WAREHOUSE.cap, tall = true, overlays = '' } = {}) {
  const used = sum(milk), p = Math.round((used / cap) * 100), full = used >= cap;
  // ic 也是商品的 key（milk、beef、rice）
  const section = (ic, lots, fn, emptyText, extra = '') => `<article class="card">
    <div class="card-head"><span class="card-title ${ic === 'milk' ? 'blue' : ic === 'beef' ? 'coral' : 'green'}">${icon(ic, 18)}${t(ic)}</span><span class="card-sub">${lots.length ? t('s05.lotsOldestFirst', { n: lots.length }) : ''}</span></div>
    ${extra}
    ${lots.length ? `<div class="lots">${lots.map(fn).join('')}</div>` : `<p class="hint" style="padding:10px 2px 2px">${emptyText}</p>`}
  </article>`;
  const capBox = `<div class="cap-box${full ? ' full' : ''}"><div class="row" style="justify-content:space-between"><span class="k">${t('s05.milkCap')}</span><span>${t('s05.capLine', { amount: `<b class="num">${fmt(used)} / ${fmt(cap)}</b>`, pct: p })}</span></div>${bar(p, { color: full ? 'red' : p >= 90 ? 'yellow' : '' })}
    ${full ? `<p class="err-text" style="margin-top:6px">${t('s05.full')}</p>` : p >= 90 ? `<p class="warn-text" style="margin-top:6px">${t('s05.nearFull')}</p>` : ''}
    <p class="hint" style="margin-top:4px">${t('s05.capNote')}</p></div>`;
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${t('warehouseTitle')}</h1><div class="sub">${t('g.levelN', { n: WAREHOUSE.level })}</div></div>${btn(t('upWarehouse'), { small: true, kind: full || p >= 90 ? 'primary' : '', ic: 'plus' })}</div>
    ${section('milk', milk, milkLot, t('s05.emptyMilk'), capBox)}
    ${section('beef', beef, beefLot, t('s05.emptyBeef'))}
    ${section('rice', rice, riceLot, t('s05.emptyRice'))}
    ${btn(t('s05.goSell'), { kind: 'primary', block: true, ic: 'coin', disabled: !milk.length && !beef.length && !rice.length })}
    <p class="hint" style="text-align:center">${t('s05.priceNote')}</p>
  </div>`;
  return frame(ctx.dev, { tab: 'ranch', content, tall, overlays });
}

const S = [];
const full = (id, name, render, x = {}) => S.push({ id, name, type: 'full', render, ...x });
const part = (id, name, crop, render, x = {}) => S.push({ id, name, type: 'part', crop, render, ...x });

part('S05-01', '牧場頁的倉庫小卡', '.dock-row', (ctx) => ranchPage(ctx));
full('S05-02', '倉庫詳細：每一批（長頁）', (ctx) => page(ctx), { tall: true });
full('S05-03', '空倉庫', (ctx) => page(ctx, { milk: [], beef: [], rice: [], tall: false }));
full('S05-04', '倉庫滿了（牛奶）', (ctx) => page(ctx, { milk: [{ qty: 120, tier: 0, fresh: 1, ago: { h: 1 } }, { qty: 77, tier: 1, fresh: 0.86, ago: { h: 12 } }, { qty: 28, tier: 3, fresh: 0.7, ago: { h: 26 } }], beef: [], rice: WAREHOUSE.rice.slice(0, 1), tall: false }));
part('S05-05', '有一批牛奶快壞了（新鮮度低於 30%）', '.lot.bad', (ctx) => page(ctx), { tall: true });
// 雜種牛產的奶、出貨的牛肉（v0.3；ceo 2026-10-03）：一批一批照舊，標籤寫「雜種」、牛奶叫「雜種牛奶 ×0.6」
const MIX_MILK = { qty: 18, hybrid: true, fresh: 0.95, ago: { h: 6 } };
const MIX_BEEF = { qty: 412, hybrid: true, grade: 'B', cow: { breed: 'mixBeef', id: 21 }, factor: 1.0, ago: { h: 1 } };
full('S05-06', '有雜種牛的牛奶、牛肉', (ctx) => page(ctx, { milk: [WAREHOUSE.milk[0], MIX_MILK, WAREHOUSE.milk[1]], beef: [MIX_BEEF, WAREHOUSE.beef[0]], rice: WAREHOUSE.rice.slice(0, 1) }), { tall: true });

export default { id: 'S05', name: '倉庫', states: S };
