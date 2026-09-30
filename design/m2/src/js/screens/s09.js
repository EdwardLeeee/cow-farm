// S09 圖鑑（24 格）與 S12 排行榜（紀錄分頁）
import { frame, btn, seg, icon, fmt, cowSVG, bar, tierChip, useChip, badge, BREEDS } from '../kit.js';
import { FOUND, RANK, RANCH } from '../fixtures.js';
import { CODEX_ORDER, INTRO, NEW_IN_M2, TIER_NAME, TRAIT_NAME, USE_NAME, tierOf } from '../../cow/breeds.js';

const USES = [['dairy', '乳牛'], ['draft', '耕牛'], ['beef', '肉牛']];
const MULT = [1.0, 1.3, 1.7, 2.5];
const BEST = { dairy: 250, draft: 450, beef: 800 };

function cell(k, found) {
  const b = BREEDS[k], t = tierOf(b);
  return `<button class="dex-cell${found ? '' : ' unknown'}">
    <span class="dex-pic">${cowSVG({ breed: k }, { w: 74, h: 64, pad: 3, sil: found ? false : 'dark' })}</span>
    <span class="dex-name">${found ? b.name : '？？？'}</span>${tierChip(t)}</button>`;
}
function codexPage(ctx, { found = FOUND, tall = true } = {}) {
  const n = found.length;
  const all = n === 24;
  const content = `<div class="stack">
    ${seg(['圖鑑', '排行榜'], 0)}
    <article class="card dex-head${all ? ' done' : ''}">
      <div class="row" style="justify-content:space-between"><span class="card-title">${icon('book', 18)}已發現</span><b class="num dex-count">${n} <small>/ 24</small></b></div>
      ${bar((n / 24) * 100, { color: 'yellow', thick: true })}
      <p class="hint" style="margin-top:6px">${all ? '24 種全部發現了！圖鑑榜上會顯示你完成了。' : '小牛出生、抽到或借種生下新品種，就會記在這裡。'}</p>
    </article>
    ${USES.map(([u, name]) => `<section><h3 class="sec-title">${useChip(u)}<span class="hint">${USE_NAME[u]} 8 種</span></h3>
      <div class="dex-grid">${CODEX_ORDER.filter((k) => BREEDS[k].use === u).map((k) => cell(k, found.includes(k))).join('')}</div></section>`).join('')}
  </div>`;
  return frame(ctx.dev, { tab: 'records', content, tall });
}

function hintFor(b) {
  const t = Object.keys(b.traits || {}).filter((k) => b.traits[k]);
  const use = b.use === 'dairy' ? '爸媽都是乳牛' : b.use === 'beef' ? '爸媽都是肉牛' : '一邊乳牛、一邊肉牛（或兩頭耕牛）';
  if (!t.length) return `${use}，而且沒有顯現任何特徵。`;
  return `${use}，而且爸媽都要帶「${t.map((x) => TRAIT_NAME[x]).join('、')}」的基因（看起來沒有也可能帶著）。`;
}
function detailPage(ctx, k, { found = true } = {}) {
  const b = BREEDS[k], t = tierOf(b);
  const stats = [];
  if (b.use === 'dairy') stats.push(['產奶（母牛）', '14 <small>瓶／時</small>']);
  if (b.use === 'draft') stats.push(['耕田', `${(11 * MULT[t]).toFixed(1).replace(/\.0$/, '')} <small>公斤稻米／時</small>`]);
  stats.push(['最佳體重', `${BEST[b.use]} <small>公斤</small>`]);
  stats.push(['賣價倍數', `×${MULT[t].toFixed(1)} <small>${b.use === 'draft' ? '（牛肉）' : ''}</small>`]);
  stats.push(['小牛長大', `${[1, 2, 4, 8][t]} <small>小時</small>`]);
  const pics = found
    ? `<div class="dex-pics">${cowSVG({ breed: k, pose: 'side' }, { w: 160, h: 130, pose: 'side' })}${cowSVG({ breed: k }, { w: 130, h: 130 })}</div>`
    : `<div class="dex-pics">${cowSVG({ breed: k, pose: 'side' }, { w: 160, h: 130, pose: 'side', sil: 'dark' })}</div>`;
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="返回">${icon('back', 22)}</button><div class="grow"><h1>${found ? b.name : '？？？'}</h1><div class="chips" style="margin-top:3px">${useChip(b.use)}${tierChip(t)}${found ? '' : badge('lock', '還沒發現')}</div></div><span class="dex-no">No.${String(CODEX_ORDER.indexOf(k) + 1).padStart(2, '0')}</span></div>
    <article class="card dex-hero"><div class="hero-bg"></div>${pics}</article>
    ${found ? `<p class="dex-intro">${INTRO[k]}</p>
    <div class="kv">${stats.map(([a, v]) => `<div class="cell"><div class="k">${a}</div><div class="v num">${v}</div></div>`).join('')}</div>
    <article class="card"><div class="card-head"><span class="card-title pink">${icon('heart', 16)}怎麼配出來</span></div><p class="hint" style="margin-top:6px;color:var(--ink)">${hintFor(b)}</p></article>
    <p class="hint">第一次發現：9 月 30 日　・　目前有 ${k === 'holstein' ? 3 : 1} 頭</p>`
      : `<article class="card"><div class="empty"><div class="t1">還沒發現這個品種</div><div class="t2">${USE_NAME[b.use]}・${TIER_NAME[t]}。多試試不同的牛配種，或到商店抽抽看。</div></div></article>`}
  </div>`;
  return frame(ctx.dev, { tab: 'records', content });
}

// 24 種全圖（給使用者核准外型）：側面＋正面，一排一種用途
function allSheet() {
  const box = (k) => {
    const b = BREEDS[k], t = tierOf(b), isNew = NEW_IN_M2.includes(k);
    return `<figure class="all-fig">${isNew ? '<span class="all-new">M2 新畫</span>' : ''}
      <div class="all-pics">${cowSVG({ breed: k, pose: 'side' }, { w: 150, h: 118, pose: 'side' })}${cowSVG({ breed: k }, { w: 104, h: 118 })}</div>
      <figcaption><b>${String(CODEX_ORDER.indexOf(k) + 1).padStart(2, '0')} ${b.name}</b><span>${USE_NAME[b.use]}・${TIER_NAME[t]}・${Object.keys(b.traits).filter((x) => b.traits[x]).map((x) => TRAIT_NAME[x]).join('＋') || '沒有特徵'}</span></figcaption></figure>`;
  };
  return `<div class="all-sheet">
    <header><h1>圖鑑 24 種（側面＋正面）</h1><p>標「M2 新畫」的 14 種是這次新畫的，其他 10 種是第 11 輪定案的外型，沒有改。角照規則：肉牛沒有光澤的無角、肉牛＋光澤短角；耕牛＋光澤是水牛角、耕牛＋長毛是長角；其他短角。</p></header>
    ${USES.map(([u, name]) => `<section><h2>${name}</h2><div class="all-grid">${CODEX_ORDER.filter((k) => BREEDS[k].use === u).map(box).join('')}</div></section>`).join('')}
  </div>`;
}

const S = [];
const full = (id, name, render, x = {}) => S.push({ id, name, type: 'full', render, ...x });
full('S09-01', '列表：24 格（長頁）', (ctx) => codexPage(ctx), { tall: true });
full('S09-02', '全部發現', (ctx) => codexPage(ctx, { found: CODEX_ORDER, tall: false }));
full('S09-03', '品種詳細（已發現）', (ctx) => detailPage(ctx, 'jersey'));
full('S09-04', '品種詳細（還沒發現）', (ctx) => detailPage(ctx, 'goldenEar', { found: false }));
S.push({ id: 'S09-05', name: '24 種全圖（核准外型）', type: 'sheet', viewport: { w: 1320, h: 1400 }, render: () => allSheet() });

// ---------------- S12 排行榜 ----------------
const KINDS = [['networth', '總資產', '幣'], ['collection', '圖鑑', '種'], ['weekly', '本週收入', '幣']];
function rankRow(r, unit, me = false) {
  const medal = r.rank <= 3 ? `<span class="medal m${r.rank}">${r.rank}</span>` : `<span class="rk num">${r.rank}</span>`;
  return `<div class="rank-row${me ? ' me' : ''}">${medal}<div class="grow"><div class="rn">${r.bot ? '<span class="bot">電腦</span>' : ''}${r.name}<span class="tag">${r.tag}</span></div><div class="rl"><span class="lv num">Lv ${r.level}</span>${me ? '<span class="badge new">我</span>' : ''}</div></div><b class="num rv">${fmt(r.value)}<small>${unit}</small></b></div>`;
}
function rankPage(ctx, { kind = 0, me = null, state = '', rows = null, tall = false } = {}) {
  const [key, label, unit] = KINDS[kind];
  let list = rows || RANK[key];
  if (me && me.rank <= list.length) list = list.map((r) => (r.rank === me.rank ? { ...me } : r));
  const body = state === 'loading' ? `<div class="oc-empty" style="min-height:160px"><span class="spinner"></span><span>載入中…</span></div>`
    : state === 'failed' ? `<div class="oc-empty" style="min-height:160px;flex-direction:column"><span class="err-text">${icon('err', 20)} 載入失敗</span>${btn('重試', { small: true, ic: 'refresh' })}</div>`
      : `<div class="rank-list">${list.map((r) => rankRow(r, unit, me && r.rank === me.rank)).join('')}</div>`;
  const myVal = me ? me : RANK.me[key];
  const content = `<div class="stack">
    ${seg(['圖鑑', '排行榜'], 1)}
    ${seg(KINDS.map((k) => k[1]), kind, { small: true })}
    <p class="hint">${key === 'weekly' ? '每週一 00:00（台灣時間）重新計算。' : key === 'networth' ? '金幣＋庫存照市價估＋牛的估值。' : '發現的品種數，最多 24 種。'}下拉可以重新整理。</p>
    <article class="card rank-card">${body}</article>
  </div>`;
  const my = `<div class="my-rank"><span class="k">我的名次</span><b class="num">${state ? '—' : myVal && myVal.rank ? `第 ${myVal.rank} 名` : '未上榜'}</b><span class="grow"></span>${myVal && myVal.value != null && !state ? `<b class="num">${fmt(myVal.value)}</b><small>${unit}</small>` : ''}</div>`;
  return frame(ctx.dev, { tab: 'records', content, body: my, tall, contentCls: 'has-myrank' });
}
const S2 = [];
const full12 = (id, name, render, x = {}) => S2.push({ id, name, type: 'full', render, ...x });
const part12 = (id, name, crop, render, x = {}) => S2.push({ id, name, type: 'part', crop, render, ...x });
const ME = { rank: 8, name: RANCH.name, tag: RANCH.tag, level: RANCH.level, value: 58920 };
full12('S12-01', '總資產（自己在榜內）', (ctx) => rankPage(ctx, { kind: 0, me: ME }));
full12('S12-02', '圖鑑榜', (ctx) => rankPage(ctx, { kind: 1 }));
full12('S12-03', '本週收入', (ctx) => rankPage(ctx, { kind: 2 }));
part12('S12-04', '自己沒上榜', '.my-rank', (ctx) => rankPage(ctx, { kind: 2, me: { rank: null, value: null } }));
part12('S12-05', '載入中', '.rank-card', (ctx) => rankPage(ctx, { kind: 0, state: 'loading' }));
part12('S12-06', '載入失敗', '.rank-card', (ctx) => rankPage(ctx, { kind: 0, state: 'failed' }));
full12('S12-07', '電腦玩家、名字最長、數字最大（量測用）', (ctx) => rankPage(ctx, { kind: 0, me: { rank: 12, name: RANCH.name, tag: RANCH.tag, level: 14, value: 98765432 }, rows: RANK.networth.map((r, i) => ({ ...r, name: ['彩虹溪谷牧場', '星河花田乳坊', '麥浪森林牧舍', '月牙石橋莊園', '山嵐原野農莊', '楓葉湖邊家園', '露珠竹林田園', '暖陽坡地牧野', '白雲谷地小屋', '青草松林牧園', '微風河畔牛舍', '晨光小丘農場'][i], level: 15 - Math.floor(i / 4), value: 999999999 - i * 12345678, bot: i % 3 === 1 })) }));

export const S09 = { id: 'S09', name: '圖鑑', states: S };
export const S12 = { id: 'S12', name: '排行榜', states: S2 };
