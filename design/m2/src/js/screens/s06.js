// S06 市場（牛奶、牛肉、稻米）。D20：每種商品只有一個市價，品質用倍數乘上去。
// D24（使用者 2026-10-01 選「保留，改成一眼看懂」）：不畫走勢圖、K 線、全服成交量，也沒有 1 小時／1 天／7 天的切換；
// 三種商品排成一張卡，一眼看到「現在的收購價」和「比平常高或低幾 %」（平常＝基本價），點一列就切到那種商品的賣出面板。
import { frame, btn, icon, fmt, toast } from '../kit.js';
import { MARKET, NEWS, RANCH, vsBase, newsTag, newsText } from '../fixtures.js';
import { t, tb, ago } from '../i18n.js';

const IC = { milk: 'milk', beef: 'beef', rice: 'rice' };
const KEYS = ['milk', 'beef', 'rice'];
// 比平常高或低：繁中照台灣習慣漲紅跌綠（D25：英文、泰文預設綠漲紅跌，設定可以切換）
export function vsText(m) {
  const v = vsBase(m);
  if (v === 0) return `<span class="vs flat">${t('s06.vsSame')}</span>`;
  return `<span class="vs ${v > 0 ? 'up' : 'down'}">${icon(v > 0 ? 'up' : 'down', 11)}${t(v > 0 ? 's06.vsHigher' : 's06.vsLower', { pct: `<b class="num">${Math.abs(v)}%</b>` })}</span>`;
}
// 三種商品的收購價（選中的那一列有底色）
function pricesCard(sel, mk, { loading = false } = {}) {
  if (loading) return `<article class="card prices-card"><div class="loading-row" style="padding:30px 0"><span class="spinner"></span><span>${t('s06.loading')}</span></div></article>`;
  return `<article class="card prices-card">
    <div class="card-head"><span class="card-title green">${icon('coin', 16)}${t('s06.title')}</span><span class="card-sub">${t('s06.tapToSell')}</span></div>
    <div class="price-rows">${KEYS.map((k) => {
      const m = mk[k];
      return `<button class="price-row${k === sel ? ' on' : ''}"><span class="pr-ic">${icon(IC[k], 26)}</span><span class="pr-name">${m.name}</span>
        <span class="pr-right"><span class="pr-price"><b class="num">${m.price}</b><small>${t('priceUnit', { unit: m.unit })}</small></span>${vsText(m)}</span></button>`;
    }).join('')}</div>
    <p class="hint pr-base">${t('s06.baseLine', { milk: 12, beef: 12, rice: 5 })}</p>
  </article>`;
}
// 選中的商品的最新新聞（一句）
function headline(m) {
  const n = NEWS.find((x) => x.c === m.key) || NEWS.find((x) => x.c === 'all');
  if (!n) return '';
  return `<div class="headline"><span class="hl-ic">${icon('news', 20)}</span><span class="hl-text">${newsTag(n)}${newsText(n)}</span><span class="hl-when">${ago(n.when)}</span></div>`;
}

// 賣出面板。st：'ok' 試算完成｜'quoting' 試算中｜'empty' 沒有庫存｜'failed' 試算失敗｜'big' 一次賣太多｜'offline'
export function sellCard(m, st = 'ok', { qty, avg, total, lots } = {}) {
  const stock = m.stock;
  const q = qty ?? stock;
  const unit = m.unit;
  const mult = t(m.key === 'milk' ? 's06.multMilk' : m.key === 'beef' ? 's06.multBeef' : 's06.multRice');
  if (st === 'empty') {
    return `<article class="card sell-card"><div class="card-head"><span class="card-title">${t('s06.sellTitle', { name: m.name })}</span><span class="card-sub">${t('inventory', { qty: 0, unit })}</span></div>
      <div class="empty" style="padding:12px 0 4px"><div class="t2">${t('nothingToSell', { name: m.name })}</div></div>${btn(t('sellTitle'), { kind: 'primary', block: true, disabled: true })}</article>`;
  }
  const pctQ = Math.round((q / stock) * 100);
  const dis = st === 'quoting' || st === 'failed' || st === 'offline';
  const est = st === 'quoting' ? `<div class="est quoting"><span class="spinner"></span><span>${t('quoting')}</span></div>`
    : st === 'failed' ? `<div class="est failed"><span class="err-text">${icon('err', 18)} ${t('s06.quoteFailed')}</span>${btn(t('retry'), { small: true, ic: 'refresh' })}</div>`
      : `<div class="est"><div class="est-row"><span class="k">${t('estAvgPrice')}</span><b class="num">${t('estAvgValue', { avg, unit })}</b></div><div class="est-row"><span class="k">${t('s06.estTotalLabel')}</span><b class="num big">${t('costCoins', { v: fmt(total) })}</b></div><div class="est-row"><span class="k">${t('s06.marketPrice')}</span><span class="num">${t('g.pricePer', { price: m.price, unit })}</span></div><p class="hint">${t('s06.formula', { mult })}</p></div>`;
  return `<article class="card sell-card">
    <div class="card-head"><span class="card-title">${t('s06.sellTitle', { name: m.name })}</span><span class="card-sub">${t('inventory', { qty: fmt(stock), unit })}${lots ? t('s06.lots', { n: lots }) : ''}</span></div>
    <div class="qty-row"><span class="k">${t('s06.qty')}</span><b class="num qty-big">${fmt(q)}</b><span class="u">${unit}</span><span class="grow"></span>${['¼', '½', t('g.all')].map((lb, i) => `<button class="chip-btn${(i === 2 && pctQ === 100) || (i === 1 && pctQ === 50) ? ' on' : ''}"${st === 'offline' ? ' disabled' : ''}>${lb}</button>`).join('')}</div>
    <div class="slider${st === 'offline' ? ' off' : ''}"><div class="track"><i style="width:${pctQ}%"></i></div><span class="thumb" style="left:${pctQ}%"></span></div>
    <p class="hint" style="margin-top:2px">${t('s06.oldestFirst')}</p>
    ${st === 'big' ? `<div class="big-warn">${icon('warn', 20)}<span>${t('tooMuch')}</span></div>` : ''}
    ${est}
    ${btn(t('sellConfirm', { qty: fmt(q), unit }), { kind: 'primary', block: true, disabled: dis })}
  </article>`;
}

// ---------- D33 超級大事件（tier super，+100%）、超級黑天鵝（tier crash，−90%）：使用者 2026-10-03 選第 12 輪的 04-B ----------
// 進行中（state active）的變成大卡，釘在新聞卡最上面；結束以後回到下面的清單，照時間排（標籤留著）。
export const TIER_CLS = { super: 'sup', crash: 'swan' };
export const tierTag = (n) => (n.tier === 'super' ? `${icon('sparkle', 13)}${t('s06.superTag')}` : `${icon('swan', 15)}${t('s06.swanTag')}`);
const tierBadge = (n) => `<span class="badge ${TIER_CLS[n.tier]}">${tierTag(n)}</span>`;
export const pctText = (n) => `${n.pct > 0 ? '+' : '−'}${Math.round(Math.abs(n.pct) * 100)}%`;
export const newsIcons = (n, cls, one, three) => (n.c === 'all' ? `<span class="${cls} all">${icon('milk', three)}${icon('beef', three)}${icon('rice', three)}</span>` : `<span class="${cls}">${icon(n.c, one)}</span>`);
const UNIT = { milk: 'unitMilk', beef: 'unitBeef', rice: 'unitRice' };
// 超級大事件的大卡右上角的光（放射狀的白色三角形）
const RAYS = `<svg class="np-rays" viewBox="-50 -50 100 100" aria-hidden="true">${Array.from({ length: 16 }, (_, i) => {
  const a = i * 22.5, p = (x) => `${(60 * Math.cos((x * Math.PI) / 180)).toFixed(1)} ${(60 * Math.sin((x * Math.PI) / 180)).toFixed(1)}`;
  return `<path d="M0 0L${p(a - 5.6)}L${p(a + 5.6)}z" fill="#FFFFFF"/>`;
}).join('')}</svg>`;
function newsPin(n) {
  const up = n.dir === 'up';
  const sub = n.c === 'all' ? tb(up ? 's06.pinUpAll' : 's06.pinDownAll')
    : `${t(up ? 's06.pinUp' : 's06.pinDown', { name: t(n.c) })}<br>${t('s06.pinNow', { price: n.price, unit: t(UNIT[n.c]) })}`;
  return `<div class="news-pin ${TIER_CLS[n.tier]}">${n.tier === 'super' ? RAYS : ''}
    <div class="np-top">${tierBadge(n)}<span class="n-tag">${newsTag(n)}</span><span class="n-when">${ago(n.when)}</span></div>
    <div class="np-main">${newsIcons(n, 'np-ic', 34, 22)}<div class="grow"><b class="np-t">${newsText(n)}</b><div class="np-fx"><b class="np-big num">${pctText(n)}</b><p class="np-sub">${sub}</p></div></div></div>
  </div>`;
}
function newsItem(n) {
  return `<div class="news-item">
      <div class="n-tags"><span class="n-tag">${newsTag(n)}</span>${TIER_CLS[n.tier] ? tierBadge(n) : ''}${n.big ? `<span class="badge full">${t('s06.bigNews')}</span>` : ''}<span class="n-dir ${n.dir}">${icon(n.dir === 'up' ? 'up' : 'down', 11)}${t(n.dir === 'up' ? 's06.up' : 's06.down')}</span><span class="n-when">${ago(n.when)}</span></div>
      <p class="n-text">${newsText(n)}</p></div>`;
}
// 清單最多放 3 則最新的（使用者 2026-10-03：「市場那邊留三個新聞就好」）；釘在最上面的超級大卡不算在 3 則裡
const MAX_NEWS = 3;
export function newsCard(items = NEWS) {
  const pins = items.filter((n) => TIER_CLS[n.tier] && n.state !== 'ended'), rest = items.filter((n) => !pins.includes(n)).slice(0, MAX_NEWS);
  return `<article class="card news-card"><div class="card-head"><span class="card-title coral">${icon('news', 18)}${t('newsTitle')}</span></div>
    ${pins.length ? `<div class="news-pins">${pins.map(newsPin).join('')}</div>` : ''}
    ${rest.length ? `<div class="news-list">${rest.map(newsItem).join('')}</div>` : pins.length ? '' : `<p class="hint" style="padding:10px 2px 2px">${t('noNews')}</p>`}
  </article>`;
}

const MILK_SELL = { qty: 130, avg: 14.8, total: 1924, lots: 3 };
function marketPage(ctx, o = {}) {
  const key = o.key || 'milk';
  const mk = { ...MARKET, [key]: { ...MARKET[key], ...(o.m || {}) } };
  const m = mk[key];
  const content = `<div class="stack">
    ${pricesCard(key, mk, { loading: o.loading })}
    ${o.loading ? '' : headline(m)}
    ${o.loading ? '' : sellCard(m, o.sell || 'ok', o.sellData || (key === 'milk' ? MILK_SELL : key === 'beef' ? { qty: 236, avg: 13.9, total: 3280, lots: 2 } : { qty: 184, avg: 5.3, total: 975, lots: 2 }))}
    ${o.loading ? '' : newsCard(o.news)}
  </div>`;
  const out = frame(ctx.dev, { tab: 'market', content, tall: o.tall, overlays: o.overlays || '', offline: o.offline, hud: o.hud || {} });
  if (!o.scrollTo) return out;
  return { html: out, after: (root) => { const c = root.querySelector('.content'); const el = root.querySelector(o.scrollTo); if (c && el) c.scrollTop = el.offsetTop - 6; } };
}

const S = [];
const full = (id, name, render, x = {}) => S.push({ id, name, type: 'full', render, ...x });
const part = (id, name, crop, render, x = {}) => S.push({ id, name, type: 'part', crop, render, ...x });

full('S06-01', '選牛奶（比平常高）：整頁（長頁）', (ctx) => marketPage(ctx, { tall: true }), { tall: true });
full('S06-02', '選牛肉（比平常低）', (ctx) => marketPage(ctx, { key: 'beef' }));
full('S06-03', '選稻米', (ctx) => marketPage(ctx, { key: 'rice' }));
full('S06-06', '收購價載入中', (ctx) => marketPage(ctx, { loading: true }));
part('S06-08', '賣出：倉庫是空的', '.sell-card', (ctx) => marketPage(ctx, { sell: 'empty', scrollTo: '.sell-card' }));
part('S06-09', '賣出：試算中', '.sell-card', (ctx) => marketPage(ctx, { sell: 'quoting', scrollTo: '.sell-card' }));
full('S06-10', '賣出：試算完成（往下捲到賣出）', (ctx) => marketPage(ctx, { scrollTo: '.sell-card' }));
full('S06-11', '賣出：一次賣太多', (ctx) => marketPage(ctx, { key: 'beef', sell: 'big', sellData: { qty: 934, avg: 10.4, total: 9714, lots: 2 }, scrollTo: '.sell-card' }));
part('S06-12', '賣出：試算失敗', '.sell-card', (ctx) => marketPage(ctx, { sell: 'failed', scrollTo: '.sell-card' }));
full('S06-13', '賣出成功', (ctx) => marketPage(ctx, { hud: { coins: RANCH.coins + 1924 }, m: { stock: 16 }, sellData: { qty: 16, avg: 11.8, total: 189, lots: 1 }, scrollTo: '.sell-card', overlays: toast('ok', t('sold', { qty: 130, unit: t('unitMilk'), avg: 14.8, total: fmt(1924) })) }));
// 清單最多 3 則：剛出來的大新聞（牛肉）、利多（牛奶）、利空（全部商品）
part('S06-14', '新聞：沒有、利多、利空、大新聞、全部商品（最多 3 則）', '#crop', (ctx) => frame(ctx.dev, { tab: 'market', content: `<div id="crop" class="stack">${newsCard([])}${newsCard([{ c: 'beef', big: true, dir: 'up', tk: 'news.beef_up.1', when: {} }, NEWS[0], NEWS[2]])}</div>` }));
part('S06-15', '斷線：滑桿與按鈕停用', '.sell-card', (ctx) => marketPage(ctx, { sell: 'offline', offline: true, scrollTo: '.sell-card' }));
full('S06-16', '數字最長（量測用）', (ctx) => marketPage(ctx, {
  key: 'beef', hud: { coins: 987654 }, m: { price: 20.4, stock: 12480 },
  sellData: { qty: 12480, avg: 18.35, total: 229008, lots: 14 }, scrollTo: '.sell-card',
}));
// D33（使用者 2026-10-03 選第 12 輪 04-B）：超級大事件、超級黑天鵝進行中時變成大卡，釘在新聞卡最上面；結束的回到清單（照時間排，標籤留著）。
// 假資料：牛肉 +100%（8 分鐘前）、三種一起 −90%（40 分鐘前）進行中；稻米 +100%（9 小時前）已經結束
const SUPER_NEWS = [
  { c: 'beef', tier: 'super', dir: 'up', pct: 1, price: 24, tk: 'news.beef_super.1', when: { min: 8 } },
  { c: 'all', tier: 'crash', dir: 'down', pct: -0.9, tk: 'news.all_swan.1', when: { min: 40 } },
];
const ENDED_SUPER = { c: 'rice', tier: 'super', state: 'ended', dir: 'up', pct: 1, tk: 'news.rice_super.1', when: { h: 9 } };
// 卡片比較高，不畫分頁列（跟共用元件的局部狀態表一樣），一般新聞只放兩則
part('S06-17', '新聞：超級大事件、超級黑天鵝（進行中）釘在最上面，結束的回到清單', '#crop', (ctx) => frame(ctx.dev, { tab: null, hud: false, bg: '#FFF3DC', content: `<div id="crop" class="g-sheet">${newsCard([...SUPER_NEWS, NEWS[0], NEWS[2], ENDED_SUPER])}</div>` }), { board: '超級事件-狀態表' });

export default { id: 'S06', name: '市場', states: S };
