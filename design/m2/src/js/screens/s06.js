// S06 市場（牛奶、牛肉、稻米）。D20：每種商品只有一個市價，品質用倍數乘上去。Lv3 才開 7 天走勢與 K 線（企劃書 4.9）。
import { frame, btn, seg, icon, fmt, toast } from '../kit.js';
import { MARKET, NEWS, RANCH } from '../fixtures.js';
import { lineChart, candleChart, volumeBars } from '../chart.js';

const IC = { milk: 'milk', beef: 'beef', rice: 'rice' };
// 全服成交量：把走勢切成 24 段（1 天圖一小時一根；1 小時圖、7 天圖同樣切 24 段）
function hourly(s) {
  const n = 24, per = (s.length - 1) / n, out = [];
  for (let i = 0; i < n; i++) {
    const a = s[Math.round(i * per)], b = s[Math.round((i + 1) * per)];
    out.push(900 + Math.abs(b - a) * 4000 + ((i * 53) % 17) * 60 + (i % 6 === 2 ? 700 : 0));
  }
  return out;
}
const X = { h1: ['1 小時前', '30 分前', '現在'], d1: ['24 小時前', '12 小時前', '現在'], d7: ['7 天前', '3 天前', '現在'] };

function priceCard(m, { loading = false } = {}) {
  if (loading) return `<article class="card price-card"><div class="loading-row" style="padding:22px 0"><span class="spinner"></span><span>正在取得行情…</span></div></article>`;
  const up = m.chg >= 0;
  return `<article class="card price-card">
    <div class="pc-top"><span class="pc-ic">${icon(IC[m.key], 30)}</span><div class="grow"><div class="pc-name">${m.name}<span class="hint">（每${m.unit}）</span></div><div class="pc-avg">24 小時均價 <b class="num">${m.ma24}</b></div></div>
      <div class="pc-right"><div class="pc-price"><span class="num">${m.price}</span><small>幣</small></div><div class="pc-chg ${up ? 'up' : 'down'}">${icon(up ? 'up' : 'down', 12)}<span class="num">${Math.abs(m.chg).toFixed(1)}%</span><span class="k">24 小時</span></div></div></div>
  </article>`;
}

function chartCard(ctx, m, { range = 1, kline = false, locked = false, nodata = false } = {}) {
  const w = ctx.dev.w - 54;
  const ranges = [{ label: '1 小時' }, { label: '1 天' }, locked ? { label: '7 天', lock: true, disabled: true } : { label: '7 天' }];
  const kinds = [{ label: '折線' }, locked ? { label: 'K 線', lock: true, disabled: true } : { label: 'K 線' }];
  let chart;
  if (nodata) chart = `<div class="no-chart">${icon('info', 22)}<span>還沒有走勢資料</span></div>`;
  else if (kline) chart = candleChart(range === 2 ? m.k7d : m.k1d, { w, xLabels: range === 2 ? X.d7 : X.d1 });
  else {
    const s = [m.h1, m.d1, m.d7][range];
    chart = lineChart(s, { w, h: 150, xLabels: [X.h1, X.d1, X.d7][range], avg: range === 1 ? m.ma24 : null })
      + volumeBars(hourly(s), { w, h: 36 });
  }
  return `<article class="card chart-card">
    <div class="cc-top">${seg(ranges, range, { small: true, cls: 'range' })}${seg(kinds, kline ? 1 : 0, { small: true, cls: 'kind' })}</div>
    ${locked ? `<div class="lock-note">${icon('lock', 16)}<span>「7 天」和「K 線」到 <b>Lv3</b> 開放（還差 ${fmt(1500 - 740)} 幣收入）</span></div>` : ''}
    <div class="chart-box">${chart}</div>
    ${!nodata ? `<div class="chart-foot"><span>${kline ? '紅K 漲、綠K 跌；下方是全服成交量' : '虛線是 24 小時均價；下方是全服成交量'}</span></div>` : ''}
  </article>`;
}

// 賣出面板。st：'ok' 試算完成｜'quoting' 試算中｜'empty' 沒有庫存｜'failed' 試算失敗｜'big' 一次賣太多｜'offline'
export function sellCard(m, st = 'ok', { qty, avg, total, lots } = {}) {
  const stock = m.stock;
  const q = qty ?? stock;
  const unit = m.unit;
  const mult = m.key === 'milk' ? '市價 × 稀有度 × 新鮮度' : m.key === 'beef' ? '市價 × 評級 × 稀有度 × 存放折價' : '市價 × 存放折價';
  if (st === 'empty') {
    return `<article class="card sell-card"><div class="card-head"><span class="card-title">賣出${m.name}</span><span class="card-sub">庫存 0 ${unit}</span></div>
      <div class="empty" style="padding:12px 0 4px"><div class="t2">倉庫裡沒有${m.name}可以賣</div></div>${btn(`賣出`, { kind: 'primary', block: true, disabled: true })}</article>`;
  }
  const pctQ = Math.round((q / stock) * 100);
  const dis = st === 'quoting' || st === 'failed' || st === 'offline';
  const est = st === 'quoting' ? `<div class="est quoting"><span class="spinner"></span><span>試算中…</span></div>`
    : st === 'failed' ? `<div class="est failed"><span class="err-text">${icon('err', 18)} 試算失敗</span>${btn('重試', { small: true, ic: 'refresh' })}</div>`
      : `<div class="est"><div class="est-row"><span class="k">預估成交均價</span><b class="num">${avg} 幣／${unit}</b></div><div class="est-row"><span class="k">預估總額</span><b class="num big">${fmt(total)} 幣</b></div><div class="est-row"><span class="k">市價</span><span class="num">${m.price} 幣／${unit}</span></div><p class="hint">成交價 ＝ ${mult}</p></div>`;
  return `<article class="card sell-card">
    <div class="card-head"><span class="card-title">賣出${m.name}</span><span class="card-sub">庫存 ${fmt(stock)} ${unit}${lots ? `（${lots} 批）` : ''}</span></div>
    <div class="qty-row"><span class="k">數量</span><b class="num qty-big">${fmt(q)}</b><span class="u">${unit}</span><span class="grow"></span>${['¼', '½', '全部'].map((t, i) => `<button class="chip-btn${(i === 2 && pctQ === 100) || (i === 1 && pctQ === 50) ? ' on' : ''}"${st === 'offline' ? ' disabled' : ''}>${t}</button>`).join('')}</div>
    <div class="slider${st === 'offline' ? ' off' : ''}"><div class="track"><i style="width:${pctQ}%"></i></div><span class="thumb" style="left:${pctQ}%"></span></div>
    <p class="hint" style="margin-top:2px">從最舊的一批先賣。</p>
    ${st === 'big' ? `<div class="big-warn">${icon('warn', 20)}<span>一次賣太多，均價會變差，要不要分批？</span></div>` : ''}
    ${est}
    ${btn(`確認賣出 ${fmt(q)} ${unit}`, { kind: 'primary', block: true, disabled: dis })}
  </article>`;
}

export function newsCard(items = NEWS) {
  return `<article class="card news-card"><div class="card-head"><span class="card-title coral">${icon('news', 18)}新聞</span><span class="card-sub">全部是虛構的</span></div>
    ${items.length ? `<div class="news-list">${items.map((n) => `<div class="news-item">
      <div class="n-tags"><span class="n-tag">【${n.tag}】</span>${n.upcoming ? '<span class="badge new">預告</span>' : ''}<span class="n-dir ${n.dir}">${icon(n.dir === 'up' ? 'up' : 'down', 11)}${n.dir === 'up' ? '看漲' : '看跌'}</span><span class="n-when">${n.when}</span></div>
      <p class="n-text">${n.text}</p></div>`).join('')}</div>` : '<p class="hint" style="padding:10px 2px 2px">目前沒有新聞。</p>'}
  </article>`;
}

const MILK_SELL = { qty: 130, avg: 14.8, total: 1924, lots: 3 };
function marketPage(ctx, o = {}) {
  const m = { ...MARKET[o.key || 'milk'], ...(o.m || {}) };
  const tabs = ['milk', 'beef', 'rice'].map((k) => ({ label: `${MARKET[k].name}` }));
  const content = `<div class="stack">
    ${seg(tabs, ['milk', 'beef', 'rice'].indexOf(m.key))}
    ${priceCard(m, { loading: o.loading })}
    ${o.loading ? '' : chartCard(ctx, m, o.chart || {})}
    ${o.loading ? '' : sellCard(m, o.sell || 'ok', o.sellData || (m.key === 'milk' ? MILK_SELL : m.key === 'beef' ? { qty: 236, avg: 13.9, total: 3280, lots: 2 } : { qty: 184, avg: 5.3, total: 975, lots: 2 }))}
    ${o.loading ? '' : newsCard(o.news)}
  </div>`;
  const out = frame(ctx.dev, { tab: 'market', content, tall: o.tall, overlays: o.overlays || '', offline: o.offline, hud: o.hud || {} });
  if (!o.scrollTo) return out;
  return { html: out, after: (root) => { const c = root.querySelector('.content'); const el = root.querySelector(o.scrollTo); if (c && el) c.scrollTop = el.offsetTop - 6; } };
}

const S = [];
const full = (id, name, render, x = {}) => S.push({ id, name, type: 'full', render, ...x });
const part = (id, name, crop, render, x = {}) => S.push({ id, name, type: 'part', crop, render, ...x });

full('S06-01', '牛奶（漲）：整頁（長頁）', (ctx) => marketPage(ctx, { tall: true }), { tall: true });
full('S06-02', '牛肉（跌）', (ctx) => marketPage(ctx, { key: 'beef' }));
full('S06-03', '稻米', (ctx) => marketPage(ctx, { key: 'rice' }));
full('S06-04', 'Lv3 以上：K 線與全服成交量', (ctx) => marketPage(ctx, { chart: { range: 1, kline: true } }));
part('S06-05', 'Lv1–2：7 天與 K 線鎖住', '.chart-card', (ctx) => marketPage(ctx, { chart: { range: 0, locked: true }, hud: { level: 2, xp: 24 } }));
full('S06-06', '行情載入中', (ctx) => marketPage(ctx, { loading: true }));
part('S06-07', '走勢資料不夠', '.chart-card', (ctx) => marketPage(ctx, { chart: { nodata: true } }));
part('S06-08', '賣出：倉庫是空的', '.sell-card', (ctx) => marketPage(ctx, { sell: 'empty', scrollTo: '.sell-card' }));
part('S06-09', '賣出：試算中', '.sell-card', (ctx) => marketPage(ctx, { sell: 'quoting', scrollTo: '.sell-card' }));
full('S06-10', '賣出：試算完成（往下捲到賣出）', (ctx) => marketPage(ctx, { scrollTo: '.sell-card' }));
full('S06-11', '賣出：一次賣太多', (ctx) => marketPage(ctx, { key: 'beef', sell: 'big', sellData: { qty: 934, avg: 10.4, total: 9714, lots: 2 }, scrollTo: '.sell-card' }));
part('S06-12', '賣出：試算失敗', '.sell-card', (ctx) => marketPage(ctx, { sell: 'failed', scrollTo: '.sell-card' }));
full('S06-13', '賣出成功', (ctx) => marketPage(ctx, { hud: { coins: RANCH.coins + 1924 }, m: { stock: 16 }, sellData: { qty: 16, avg: 11.8, total: 189, lots: 1 }, scrollTo: '.sell-card', overlays: toast('ok', '賣出 130 瓶，均價 14.8，共 1,924 幣') }));
part('S06-14', '新聞：沒有、漲、跌、預告、全部商品', '#crop', (ctx) => frame(ctx.dev, { tab: 'market', content: `<div id="crop" class="stack">${newsCard([])}${newsCard(NEWS)}</div>` }));
part('S06-15', '斷線：滑桿與按鈕停用', '.sell-card', (ctx) => marketPage(ctx, { sell: 'offline', offline: true, scrollTo: '.sell-card' }));
full('S06-16', '數字最長（量測用）', (ctx) => marketPage(ctx, {
  key: 'beef', hud: { coins: 987654 }, m: { price: 20.4, chg: 70.0, ma24: 19.85, stock: 12480 },
  sellData: { qty: 12480, avg: 18.35, total: 229008, lots: 14 }, scrollTo: '.sell-card',
}));

export default { id: 'S06', name: '市場', states: S };
