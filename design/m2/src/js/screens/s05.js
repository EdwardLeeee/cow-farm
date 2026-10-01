// S05 倉庫（批次、新鮮度）。容量只算牛奶；牛肉、稻米目前不佔容量（企劃書 4.3）。賣出從最舊的一批先賣。
import { frame, btn, bar, icon, fmt, tierChip, empty, cowSVG } from '../kit.js';
import { WAREHOUSE, sum } from '../fixtures.js';
import { ranchPage } from './s03.js';
import { GRADE_BG } from './s04.js';

const MILK_NAME = ['一般牛奶', '優良牛奶', '稀有牛奶', '傳說牛奶'];
const MULT = [1.0, 1.3, 1.7, 2.5];
const freshIcon = (v) => (v < 0.3 ? 'leafBad' : v < 0.7 ? 'leafOld' : 'leaf');

export function milkLot(l) {
  const bad = l.fresh < 0.3;
  return `<div class="lot${bad ? ' bad' : ''}">
    <div class="lot-top"><span class="lot-ic">${icon('milk', 22)}</span><b class="num lot-q">${fmt(l.qty)}</b><span class="u">瓶</span>${tierChip(l.tier)}<span class="lot-name">${MILK_NAME[l.tier]} ×${MULT[l.tier].toFixed(1)}</span>${bad ? '<span class="badge full">快壞了</span>' : ''}</div>
    <div class="lot-fresh">${icon(freshIcon(l.fresh), 14)}<span class="k">新鮮度</span>${bar(l.fresh * 100, { color: bad ? 'red' : l.fresh < 0.7 ? 'yellow' : 'green' })}<b class="num">${Math.round(l.fresh * 100)}%</b></div>
    <div class="lot-sub">${l.age}${bad ? '・大約 20 小時後壞掉，壞掉的會丟掉' : ''}</div>
  </div>`;
}
function beefLot(l) {
  return `<div class="lot"><div class="lot-top"><span class="lot-ic">${icon('beef', 22)}</span><b class="num lot-q">${fmt(l.qty)}</b><span class="u">公斤</span><b class="gchip" style="background:${GRADE_BG[l.grade]}">${l.grade}</b>${tierChip(l.tier)}<span class="lot-name">存放 ${Math.round(l.factor * 100)}%</span></div>
    <div class="lot-sub">${l.cow} 出貨・${l.age}</div></div>`;
}
function riceLot(l) {
  return `<div class="lot"><div class="lot-top"><span class="lot-ic">${icon('rice', 22)}</span><b class="num lot-q">${fmt(l.qty)}</b><span class="u">公斤</span><span class="lot-name">存放 ${Math.round(l.quality * 100)}%</span></div>
    <div class="lot-sub">${l.age}</div></div>`;
}

function page(ctx, { milk = WAREHOUSE.milk, beef = WAREHOUSE.beef, rice = WAREHOUSE.rice, cap = WAREHOUSE.cap, tall = true, overlays = '' } = {}) {
  const used = sum(milk), p = Math.round((used / cap) * 100), full = used >= cap;
  const section = (title, ic, lots, fn, emptyText, extra = '') => `<article class="card">
    <div class="card-head"><span class="card-title ${title === '牛奶' ? 'blue' : title === '牛肉' ? 'coral' : 'green'}">${icon(ic, 18)}${title}</span><span class="card-sub">${lots.length ? `${lots.length} 批・從最舊的先賣` : ''}</span></div>
    ${extra}
    ${lots.length ? `<div class="lots">${lots.map(fn).join('')}</div>` : `<p class="hint" style="padding:10px 2px 2px">${emptyText}</p>`}
  </article>`;
  const capBox = `<div class="cap-box${full ? ' full' : ''}"><div class="row" style="justify-content:space-between"><span class="k">牛奶容量</span><span><b class="num">${fmt(used)} / ${fmt(cap)}</b> 瓶（${p}%）</span></div>${bar(p, { color: full ? 'red' : p >= 90 ? 'yellow' : '' })}
    ${full ? '<p class="err-text" style="margin-top:6px">倉庫滿了：收奶只收得進一部分，奶桶滿了就會停止產奶。</p>' : p >= 90 ? '<p class="warn-text" style="margin-top:6px">倉庫快滿了，記得去賣或加大倉庫。</p>' : ''}
    <p class="hint" style="margin-top:4px">牛肉、稻米不佔倉庫容量。</p></div>`;
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="返回">${icon('back', 22)}</button><div class="grow"><h1>倉庫</h1><div class="sub">第 ${WAREHOUSE.level} 級</div></div>${btn('加大倉庫', { small: true, kind: full || p >= 90 ? 'primary' : '', ic: 'plus' })}</div>
    ${section('牛奶', 'milk', milk, milkLot, '倉庫裡沒有牛奶。到牧場收奶吧。', capBox)}
    ${section('牛肉', 'beef', beef, beefLot, '還沒有牛肉。成年的牛可以出貨。')}
    ${section('稻米', 'rice', rice, riceLot, '還沒有稻米。派耕牛到田裡種稻。')}
    ${btn('去市場賣', { kind: 'primary', block: true, ic: 'coin', disabled: !milk.length && !beef.length && !rice.length })}
    <p class="hint" style="text-align:center">成交價 ＝ 市價 × 倍數：牛奶乘稀有度和新鮮度，牛肉乘評級、稀有度和存放折價，稻米乘存放折價。</p>
  </div>`;
  return frame(ctx.dev, { tab: 'ranch', content, tall, overlays });
}

const S = [];
const full = (id, name, render, x = {}) => S.push({ id, name, type: 'full', render, ...x });
const part = (id, name, crop, render, x = {}) => S.push({ id, name, type: 'part', crop, render, ...x });

part('S05-01', '牧場頁的倉庫小卡', '.dock-row', (ctx) => ranchPage(ctx));
full('S05-02', '倉庫詳細：每一批（長頁）', (ctx) => page(ctx), { tall: true });
full('S05-03', '空倉庫', (ctx) => page(ctx, { milk: [], beef: [], rice: [], tall: false }));
full('S05-04', '倉庫滿了（牛奶）', (ctx) => page(ctx, { milk: [{ qty: 120, tier: 0, fresh: 1, age: '1 小時前收' }, { qty: 77, tier: 1, fresh: 0.86, age: '12 小時前收' }, { qty: 28, tier: 3, fresh: 0.7, age: '26 小時前收' }], beef: [], rice: WAREHOUSE.rice.slice(0, 1), tall: false }));
part('S05-05', '有一批牛奶快壞了（新鮮度低於 30%）', '.lot.bad', (ctx) => page(ctx), { tall: true });

export default { id: 'S05', name: '倉庫', states: S };
