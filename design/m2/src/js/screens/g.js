// G 全 app 共用元件
import { frame, hud, tabbar, TABS, btn, badge, tierChip, useChip, toast, icon, cowSVG, bar, fmt } from '../kit.js';
import { RANCH, LONG_NAMES } from '../fixtures.js';
import { t, dur, cowName, breedName, sexName, tierName } from '../i18n.js';

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

export default { id: 'G', name: '共用元件', states: S };
