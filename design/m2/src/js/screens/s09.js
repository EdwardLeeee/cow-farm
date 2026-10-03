// S09 圖鑑（24 格）與 S12 排行榜（紀錄分頁）
import { frame, btn, seg, icon, fmt, cowSVG, bar, tierChip, useChip, badge, BREEDS } from '../kit.js';
import { FOUND, RANK, RANCH, compactBig, LONG_NAMES } from '../fixtures.js';
import { CODEX_ORDER, NEW_IN_M2, TIER_NAME, TRAIT_NAME, USE_NAME, tierOf } from '../../cow/breeds.js';
import { t, LANG, breedName, breedIntro, useName, tierName } from '../i18n.js';

const USES = [['dairy', '乳牛'], ['draft', '耕牛'], ['beef', '肉牛']];
const MULT = [1.0, 1.3, 1.7, 2.5];
const BEST = { dairy: 250, draft: 450, beef: 800 };

function cell(k, found) {
  const b = BREEDS[k], tier = tierOf(b);
  return `<button class="dex-cell${found ? '' : ' unknown'}">
    <span class="dex-pic">${cowSVG({ breed: k }, { w: 74, h: 64, pad: 3, sil: found ? false : 'dark' })}</span>
    <span class="dex-name">${found ? breedName(k) : t('g.unknownBreed')}</span>${tierChip(tier)}</button>`;
}
function codexPage(ctx, { found = FOUND, tall = true } = {}) {
  const n = found.length;
  const all = n === 24;
  const content = `<div class="stack">
    ${seg([t('subCodex'), t('subRank')], 0)}
    <article class="card dex-head${all ? ' done' : ''}">
      <div class="row" style="justify-content:space-between"><span class="card-title">${icon('book', 18)}${t('s09.found')}</span><b class="num dex-count">${n} <small>/ 24</small></b></div>
      ${bar((n / 24) * 100, { color: 'yellow', thick: true })}
      <p class="hint" style="margin-top:6px">${all ? t('s09.allFound', { n: 24 }) : t('s09.hint')}</p>
    </article>
    ${USES.map(([u]) => `<section><h3 class="sec-title">${useChip(u)}<span class="hint">${t('s09.useCount', { use: useName(u), n: 8 })}</span></h3>
      <div class="dex-grid">${CODEX_ORDER.filter((k) => BREEDS[k].use === u).map((k) => cell(k, found.includes(k))).join('')}</div></section>`).join('')}
  </div>`;
  return frame(ctx.dev, { tab: 'records', content, tall });
}

function hintFor(b) {
  const tr = Object.keys(b.traits || {}).filter((k) => b.traits[k]);
  const use = t(b.use === 'dairy' ? 's09.howDairy' : b.use === 'beef' ? 's09.howBeef' : 's09.howDraft');
  if (!tr.length) return t('s09.howNoTrait', { use });
  return t('s09.howTraits', { use, traits: tr.map((x) => t(`trait.${x}`)).join(t('g.listSep')) });
}
function detailPage(ctx, k, { found = true } = {}) {
  const b = BREEDS[k], tier = tierOf(b);
  const stats = [];
  if (b.use === 'dairy') stats.push([t('s09.milkCow'), `14 <small>${t('g.perHourMilk')}</small>`]);
  if (b.use === 'draft') stats.push([t('g.plow'), `${(11 * MULT[tier]).toFixed(1).replace(/\.0$/, '')} <small>${t('g.perHourRice')}</small>`]);
  stats.push([t('s09.bestKg'), `${BEST[b.use]} <small>${t('g.kg')}</small>`]);
  stats.push([t('s09.mult'), `×${MULT[tier].toFixed(1)} <small>${b.use === 'draft' ? t('s09.multBeef') : ''}</small>`]);
  const pics = found
    ? `<div class="dex-pics">${cowSVG({ breed: k, pose: 'side' }, { w: 160, h: 130, pose: 'side' })}${cowSVG({ breed: k }, { w: 130, h: 130 })}</div>`
    : `<div class="dex-pics">${cowSVG({ breed: k, pose: 'side' }, { w: 160, h: 130, pose: 'side', sil: 'dark' })}</div>`;
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${found ? breedName(k) : t('g.unknownBreed')}</h1><div class="chips" style="margin-top:3px">${useChip(b.use)}${tierChip(tier)}${found ? '' : badge('lock', t('s09.notFoundYet'))}</div></div><span class="dex-no">${t('s09.no', { n: String(CODEX_ORDER.indexOf(k) + 1).padStart(2, '0') })}</span></div>
    <article class="card dex-hero"><div class="hero-bg"></div>${pics}</article>
    ${found ? `<p class="dex-intro">${breedIntro(k)}</p>
    <div class="kv">${stats.map(([a, v]) => `<div class="cell"><div class="k">${a}</div><div class="v num">${v}</div></div>`).join('')}</div>
    <article class="card"><div class="card-head"><span class="card-title pink">${icon('heart', 16)}${t('s09.howTitle')}</span></div><p class="hint" style="margin-top:6px;color:var(--ink)">${hintFor(b)}</p></article>
    <p class="hint">${t('s09.firstFound', { date: t('date.mdOnly', { m: 9, d: 30 }), n: k === 'holstein' ? 3 : 1 })}</p>`
      : `<article class="card"><div class="empty"><div class="t1">${t('s09.unknownTitle')}</div><div class="t2">${t('s09.unknownBody', { use: useName(b.use), tier: tierName(tier) })}</div></div></article>`}
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
  return `<div class="all-sheet" data-note>
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
// 每週排行榜在台灣時間週一 00:00 重新計算（D25），畫面換成手機當地的時間（ceo 2026-10-02）。星期用全名 weekdayFull（縮寫 weekday 留給 date.mdw）。
// 設計稿的假資料：繁中當作在台灣（UTC+8，週一 00:00）、泰文在泰國（UTC+7，週日 23:00）、英文在美國西岸夏令時間（UTC−7，週日 09:00）。
const MOCK_UTC_OFFSET = { 'zh-Hant': 8, th: 7, en: -7 };
function weeklyReset() {
  const week = 7 * 1440, utc = 16 * 60; // 台灣週一 00:00 ＝ UTC 週日 16:00（從週日 00:00 起算的分鐘）
  const local = (((utc + (MOCK_UTC_OFFSET[LANG] ?? 8) * 60) % week) + week) % week;
  const hm = local % 1440;
  return { w: t(`weekdayFull.${Math.floor(local / 1440)}`), time: `${String(Math.floor(hm / 60)).padStart(2, '0')}:${String(hm % 60).padStart(2, '0')}` };
}
// 排行榜的種類：key、名稱的 key、單位的 key
const KINDS = [['networth', 'rankNetworth', 'g.coin'], ['collection', 'rankCollection', 's12.kinds'], ['weekly', 'rankWeekly', 'g.coin']];
// 圖鑑榜發現 24 種的：分數前面加綠色「完成」，下面「我的名次」那一條也有（企劃書 4.6；缺口清單 2-6，使用者 2026-10-02 核准，D31）
const DONE_AT = 24;
const doneBadge = () => `<span class="badge done">${icon('ok', 12)}<span class="bt">${t('s12.complete')}</span></span>`;
function rankRow(r, unit, me = false, done = false) {
  const medal = r.rank <= 3 ? `<span class="medal m${r.rank}">${r.rank}</span>` : `<span class="rk num">${r.rank}</span>`;
  return `<div class="rank-row${me ? ' me' : ''}">${medal}<div class="grow"><div class="rn">${r.bot ? `<span class="bot">${t('botPrefix')}</span>` : ''}<span class="rn-name">${r.name}</span><span class="tag">${r.tag}</span></div><div class="rl"><span class="lv num">${t('level', { lv: r.level })}</span>${me ? `<span class="badge new">${t('s12.me')}</span>` : ''}</div></div>${done && r.value >= DONE_AT ? doneBadge() : ''}<b class="num rv">${compactBig(r.value)}<small>${unit}</small></b></div>`;
}
function rankPage(ctx, { kind = 0, me = null, state = '', rows = null, tall = false } = {}) {
  const [key, , uk] = KINDS[kind], unit = t(uk), done = key === 'collection';
  let list = rows || RANK[key];
  if (me && me.rank <= list.length) list = list.map((r) => (r.rank === me.rank ? { ...me } : r));
  const body = state === 'loading' ? `<div class="oc-empty" style="min-height:160px"><span class="spinner"></span><span>${t('g.loading')}</span></div>`
    : state === 'failed' ? `<div class="oc-empty" style="min-height:160px;flex-direction:column"><span class="err-text">${icon('err', 20)} ${t('loadFailed')}</span>${btn(t('retry'), { small: true, ic: 'refresh' })}</div>`
      : `<div class="rank-list">${list.map((r) => rankRow(r, unit, me && r.rank === me.rank, done)).join('')}</div>`;
  const myVal = me ? me : RANK.me[key];
  const content = `<div class="stack">
    ${seg([t('subCodex'), t('subRank')], 1)}
    ${seg(KINDS.map((k) => t(k[1])), kind, { small: true })}
    <p class="hint">${key === 'weekly' ? t('s12.weeklyHint', weeklyReset()) : t(key === 'networth' ? 's12.networthHint' : 's12.collectionHint', { n: 24 })}${t('s12.pullHint')}</p>
    <article class="card rank-card">${body}</article>
  </div>`;
  const my = `<div class="my-rank"><span class="k">${t('s12.myRank')}</span><b class="num">${state ? '—' : myVal && myVal.rank ? t('s12.rankN', { n: myVal.rank }) : t('notRanked')}</b><span class="grow"></span>${myVal && myVal.value != null && !state ? `${done && myVal.value >= DONE_AT ? doneBadge() : ''}<b class="num">${compactBig(myVal.value)}</b><small>${unit}</small>` : ''}</div>`;
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
full12('S12-07', '電腦玩家、名字最長（8 個中文字、16 個英文字母）、數字最大（量測用）', (ctx) => rankPage(ctx, { kind: 0, me: { rank: 12, name: RANCH.name, tag: RANCH.tag, level: 14, value: 98765432 }, rows: RANK.networth.map((r, i) => ({ ...r, name: [LONG_NAMES.cjk, LONG_NAMES.latin, '麥浪森林牧舍', '月牙石橋莊園', LONG_NAMES.cjk, '楓葉湖邊家園', LONG_NAMES.latin, '暖陽坡地牧野', '白雲谷地小屋', '青草松林牧園', '微風河畔牛舍', '晨光小丘農場'][i], level: 15 - Math.floor(i / 4), value: 999999999 - i * 12345678, bot: i % 3 === 1 })) }));

// 圖鑑榜：發現 24 種的列和下面「我的名次」那一條，分數前面加「完成」。自己第 2 名、24 種
full12('S12-08', '圖鑑榜：發現 24 種的加「完成」', (ctx) => rankPage(ctx, { kind: 1, me: { rank: 2, name: RANCH.name, tag: RANCH.tag, level: RANCH.level, value: 24 } }));

export const S09 = { id: 'S09', name: '圖鑑', states: S };
export const S12 = { id: 'S12', name: '排行榜', states: S2 };
