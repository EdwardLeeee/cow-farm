// G 全 app 共用元件
import { frame, hud, tabbar, TABS, btn, badge, tierChip, useChip, toast, icon, cowSVG, bar, fmt } from '../kit.js';
import { RANCH, LONG_NAMES, MARKET } from '../fixtures.js';
import { t, dur, cowName, breedName, sexName, tierName, useName } from '../i18n.js';
import { vsText } from './s06.js';

const S = [];
const part = (id, name, crop, render, x = {}) => S.push({ id, name, type: 'part', crop, render, ...x });
const sheet = (ctx, inner) => frame(ctx.dev, { tab: null, hud: false, content: `<div id="crop" class="g-sheet">${inner}</div>`, bg: '#FFF3DC' });

part('G-01', '底部分頁列：6 個分頁各自選中', '#crop', (ctx) => sheet(ctx, TABS.map((t) => `<div class="g-tab-wrap">${tabbar(t.key)}</div>`).join('')));

part('G-02', '頂列：牧場名、等級、經驗條、金幣、設定', '#crop', (ctx) => sheet(ctx, `<div class="g-hud">${hud()}</div>`));

// D23：牧場名玩家自己取，最長 8 個中文字或 16 個英文字母；頂列放不下時字縮小，再放不下就用「…」截短
part('G-03', '頂列：金幣很多、等級兩位數、剛開局、名字最長（量測用）', '#crop', (ctx) => sheet(ctx, [{ coins: 999999, level: 14, xp: 96 }, { coins: 9876543, level: 14, xp: 3 }, { coins: 100, level: 1, xp: 0 }, { coins: 12480, ranch: { ...RANCH, name: LONG_NAMES.cjk } }, { coins: 12480, ranch: { ...RANCH, name: LONG_NAMES.latin } }].map((h) => `<div class="g-hud">${hud({ ...h, w: ctx.dev.w })}</div>`).join('')));

part('G-04', '操作結果：成功、伺服器拒絕、網路不穩', '#crop', (ctx) => sheet(ctx, `
  <div class="g-toast">${toast('ok', t('s10.upgraded', { what: t('bucketTitle'), effect: t('s10.effectBottles', { a: 42, b: 63 }) }))}</div>
  <div class="g-toast">${toast('err', t('notEnoughCoins', { n: fmt(1210) }))}</div>
  <div class="g-toast">${toast('warn', t('networkError'))}</div>`));

part('G-05', '伺服器通知：有人借了你的公牛', '#crop', (ctx) => sheet(ctx, `<div class="g-notice"><div class="notice">${icon('coin', 30)}<div class="grow"><b>${t('g.studNoticeTitle')}</b><span>${t('g.studNoticeBody', { cow: cowName('angus', 5), ranch: '星河松林牧舍 #3310', price: '<b class="num">870</b>' })}</span></div></div></div>`));

part('G-06', '處理中：按下的按鈕轉圈，其他按鈕停用', '#crop', (ctx) => sheet(ctx, `<div class="card g-busy">
  <div class="card-head" style="margin-bottom:10px"><span class="card-title">${t('upgradesTitle')}</span><span class="card-sub">${t('g.busySub')}</span></div>
  <div class="up-row"><span class="grow"><b>${t('upBucket')}</b><br><span class="hint">${t('s10.effectBottles', { a: 42, b: 63 })}</span></span>${btn(t('g.busy'), { small: true, busy: true })}</div>
  <div class="up-row"><span class="grow"><b>${t('upWarehouse')}</b><br><span class="hint">${t('s10.effectBottles', { a: 225, b: 337 })}</span></span>${btn(t('costCoins', { v: fmt(480) }), { small: true, kind: 'primary', disabled: true })}</div>
  <div class="up-row"><span class="grow"><b>${t('upFresh')}</b><br><span class="hint">${t('effectFresh', { a: 9, b: 12 })}</span></span>${btn(t('costCoins', { v: fmt(4000) }), { small: true, kind: 'primary', disabled: true })}</div></div>`));

part('G-07', '牛的標籤：用途、稀有度、狀態', '#crop', (ctx) => sheet(ctx, `<div class="card g-badges">
  <div class="g-line"><span class="g-k" data-note>用途</span>${useChip('dairy')}${useChip('draft')}${useChip('beef')}<span class="use">${sexName('bull')}</span><span class="use">${sexName('cow')}</span></div>
  <div class="g-line"><span class="g-k" data-note>稀有度</span>${tierChip(0)}${tierChip(1)}${tierChip(2)}${tierChip(3)}</div>
  <div class="g-line"><span class="g-k" data-note>狀態</span>${badge('calf', t('stageCalf'))}${badge('old', t('stageOld'))}${badge('working', t('badgeWorking'))}${badge('listed', t('badgeListed'))}${badge('bred', t('badgeBred'))}</div></div>`));

part('G-08', '小牛長大倒數卡（配種、借種共用）', '#crop', (ctx) => sheet(ctx, `<div class="card calf-card">
  <div class="calf-pic">${cowSVG({ breed: 'strawberry', age: 'calf', seed: 91 }, { w: 84, h: 84, pose: 'front' })}</div>
  <div class="grow"><div class="row" style="gap:6px"><b style="font-size:16px">${t('g.newCalf', { cow: cowName('strawberry', 16) })}</b></div><div class="chips" style="margin:4px 0">${tierChip(3)}${badge('calf', t('stageCalf'))}</div>
  <div class="hint">${t('growUp', { v: `<b class="num">${dur({ h: 7, m: 42 })}</b>` })}</div>${bar(4, { color: 'yellow' })}</div></div>`));

part('G-09', '下拉重新整理', '#crop', (ctx) => sheet(ctx, `<div class="g-pull"><div class="pull-ind"><span class="spinner"></span>${t('g.refreshing')}</div>
  <div class="card" style="opacity:.9"><div class="row" style="gap:8px">${cowSVG({ breed: 'chocolate', sex: 'bull', seed: 75 }, { w: 56, h: 56 })}<div><b>${t('g.breedSex', { breed: breedName('chocolate'), sex: sexName('bull') })}</b><div class="hint">${tierName(2)}${t('g.sep')}${t('costCoins', { v: fmt(2000) })}</div></div></div></div></div>`));

part('G-10', '頂列齒輪的小點：還沒備份牧場、也還沒打開過「備份牧場」頁', '#crop', (ctx) => sheet(ctx, `<div class="g-hud">${hud({ dot: true, w: ctx.dev.w })}</div>`));

// ---------- 按下（G-11～G-13；2026-10-02 草稿，使用者核准前不算數） ----------
// 每一種可以按的元件畫：平常、按下、減少動態時按下、停用（不會停用的在標題寫明）。樣式在 screens.css 最後一段。
// 只有繁中（zhOnly：英文、泰文不量）；合成時另外出一張「M2-G-按下-狀態表-<寬>.png」（board），不放進共用元件的局部狀態表。
const PR = { n: '平常', p: '按下', rm: '減少動態・按下', off: '停用' };
const pcell = (cap, html, full = false) => `<div class="press-cell${full ? ' full' : ''}"><span class="press-cap" data-note>${cap}</span>${html}</div>`;
const pkind = (title, sub, cells) => `<section class="press-kind"><div class="press-title" data-note>${title}${sub ? `<small>${sub}</small>` : ''}</div><div class="press-row">${cells.join('')}</div></section>`;
// 平常、按下、減少動態（、停用）四格；f(cls) 畫一個元件，off 是停用的樣子（沒有就不畫）
const four = (f, off, full = false) => [pcell(PR.n, f(''), full), pcell(PR.p, f('is-pressed'), full), pcell(PR.rm, f('is-pressed-rm'), full), ...(off ? [pcell(PR.off, off, full)] : [])];
const pressSheet = (ctx, inner) => frame(ctx.dev, { tab: null, hud: false, content: `<div id="crop" class="g-sheet press-sheet">${inner}</div>`, bg: '#FFF3DC', tall: true });
const pstate = (id, name, render) => part(id, name, '#crop', render, { tall: true, zhOnly: true, board: '按下-狀態表' });

const BIG = [['', 'cancel'], ['primary', 'ok'], ['blue', 'collect'], ['green', 'g.assign'], ['pink', 'tabBreed'], ['danger', 'ship']];
const zoomStage = (cls) => `<div class="pz-stage"><div class="pz-scale">${btn(t('ok'), { kind: 'primary', cls })}</div><i class="pz-line" style="top:0"></i><i class="pz-line" style="top:104px"></i></div>`;
pstate('G-11', '按下：大按鈕、整排寬的按鈕', (ctx) => pressSheet(ctx, [
  pkind('規則', '浮起的元件（有實心下陰影）：手指一碰到就往下移，下陰影變薄成 1px，底邊停在原來的位置；放開 0.1 秒彈回。平的元件：蓋一層淡淡的可可色。減少動態：都不移動，只蓋顏色，放開立刻回去。停用、處理中（轉圈）的按了不會變。', []),
  pkind('放大 2 倍看大按鈕', '按下時往下 3px，下陰影 4px → 1px；虛線是原來的上緣和底邊', [pcell(PR.n, zoomStage('')), pcell(PR.p, zoomStage('is-pressed'))]),
  pkind('大按鈕（白、黃、藍、綠、粉紅、紅）', '停用每種顏色都一樣', [
    ...['', 'is-pressed', 'is-pressed-rm'].map((c, i) => pcell([PR.n, PR.p, PR.rm][i], `<div class="press-stack">${BIG.map(([k, l]) => btn(t(l), { kind: k, cls: c })).join('')}</div>`)),
    pcell(PR.off, btn(t('ok'), { kind: 'primary', disabled: true })),
  ]),
  pkind('整排寬的按鈕', '', four((c) => btn(t('s14.newRanch'), { kind: 'primary', block: true, cls: c }), btn(t('s14.newRanch'), { kind: 'primary', block: true, disabled: true }), true)),
].join('')));

const tabWith = (cls) => { let i = -1; return `<div class="g-tab-wrap">${tabbar('ranch').replace(/<button class="tab/g, (m) => (++i === 1 && cls ? `${m} ${cls}` : m))}</div>`; };
pstate('G-12', '按下：小按鈕、圓形鈕、膠囊、分頁、篩選、數量鈕', (ctx) => pressSheet(ctx, [
  pkind('小按鈕', '', four((c) => `<div class="press-stack">${btn(t('collect'), { kind: 'blue', small: true, cls: c })}${btn(t('retry'), { small: true, ic: 'refresh', cls: c })}</div>`, btn(t('collect'), { kind: 'blue', small: true, disabled: true }))),
  pkind('圓形鈕（返回、頂列齒輪）', '不會停用', four((c) => `<div class="press-stack row">${`<button class="icon-btn ${c}">${icon('back', 22)}</button>`}${`<button class="gear ${c}">${icon('gear', 24)}</button>`}</div>`)),
  pkind('牛欄膠囊、牧場面板的收起鈕', '不會停用', four((c) => `<div class="press-stack">${`<button class="pen-pill ${c}">${icon('barn', 22)}${t('cowsTitle')}<span class="num">3 / 8</span>${icon('chevron', 16)}</button>`}${`<button class="dock-toggle ${c}"><span class="dt-pill">${t('s03.collapse')}<span class="dt-chev">${icon('chevron', 14)}</span></span></button>`}</div>`)),
  pkind('第二層分頁', '按的是沒選中的「設施」', four((c) => `<div class="seg press-seg"><button class="on">${t('s19.segDraw')}</button><button class="${c}">${t('s19.segFacility')}</button></div>`, `<div class="seg press-seg"><button class="on">${t('s19.segDraw')}</button><button disabled>${t('s19.segFacility')}</button></div>`)),
  pkind('篩選、數量鈕', '篩選不會停用', four((c) => `<div class="press-stack row"><div class="filter"><button class="${c}">${useName('dairy')}</button></div><button class="chip-btn ${c}">½</button></div>`, `<button class="chip-btn" disabled>½</button>`)),
  pkind('底部分頁', '按的是「市場」；不會停用', four((c) => tabWith(c), null, true)),
].join('')));

const prow = (c) => { const m = MARKET.milk; return `<div class="price-rows"><button class="price-row ${c}"><span class="pr-ic">${icon('milk', 26)}</span><span class="pr-name">${m.name}</span><span class="pr-right"><span class="pr-price"><b class="num">${m.price}</b><small>${t('priceUnit', { unit: m.unit })}</small></span>${vsText(m)}</span></button></div>`; };
const oxOpt = (c, { on = false, off = false } = {}) => `<button class="card ox-opt${on ? ' on' : ''}${off ? ' off' : ''} ${c}"${off ? ' disabled' : ''}>${cowSVG({ breed: off ? 'yellow' : 'milkTea', sex: 'bull', seed: off ? 17 : 101 }, { w: 56, h: 56, pad: 2 })}<div class="grow"><b>${off ? cowName('yellow', 2) : cowName('milkTea', 18)}</b><div class="chips">${off ? badge('working', t('s17.inField', { n: 1 })) : `${tierChip(1)}<span class="hint">${t('fieldRate', { v: 14.3 })}</span>`}</div></div></button>`;
const pick = (c, off = false) => `<button class="pick${off ? ' off' : ''} ${c}"${off ? ' disabled' : ''}><span class="pick-pic">${cowSVG({ breed: 'jersey', seed: 7, age: off ? 'calf' : 'adult' }, { w: 84, h: 76, pad: 3 })}</span><span class="pick-name">${cowName('jersey', 7)}</span><span class="pick-meta">${off ? badge('calf', t('stageCalf')) : tierChip(1)}</span></button>`;
const dex = (c) => `<div class="press-dex"><button class="dex-cell ${c}"><span class="dex-pic">${cowSVG({ breed: 'jersey' }, { w: 74, h: 64, pad: 3 })}</span><span class="dex-name">${breedName('jersey')}</span>${tierChip(1)}</button></div>`;
pstate('G-13', '按下：清單列、可點的卡片、關閉鈕', (ctx) => pressSheet(ctx, [
  pkind('市場的商品列', '不會停用', four((c) => prow(c), null, true)),
  pkind('設定列、卡片裡的連結列', '不會停用', four((c) => `<article class="card set-group"><button class="set-row ${c}"><span class="set-ic">${icon('backup', 22)}</span><span class="set-label">${t('s13.backup.title')}</span><span class="set-right">${icon('chevron', 18)}</span></button></article><article class="card press-link"><button class="link-row ${c}">${icon('history', 20)}<span>${t('s18.logTitle')}</span>${icon('chevron', 18)}</button></article>`, null, true)),
  pkind('可點的卡片（選耕牛、選配種的牛…）', '按的是沒選中的卡；選中的外圈留著', four((c) => oxOpt(c), oxOpt('', { off: true }), true)),
  pkind('選牛的小卡、圖鑑格子', '圖鑑格子不會停用', four((c) => `<div class="press-stack row">${pick(c)}${dex(c)}</div>`, pick('', true))),
  pkind('大新聞的關閉鈕', '不會停用', four((c) => `<div class="press-bn"><button class="bn-close ${c}">${icon('close', 18)}</button></div>`)),
].join('')));

export default { id: 'G', name: '共用元件', states: S };
