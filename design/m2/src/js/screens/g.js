// G 全 app 共用元件
import { frame, hud, tabbar, TABS, btn, badge, tierChip, useChip, toast, icon, cowSVG, bar, fmt } from '../kit.js';
import { RANCH, LONG_NAMES } from '../fixtures.js';

const S = [];
const part = (id, name, crop, render, x = {}) => S.push({ id, name, type: 'part', crop, render, ...x });
const sheet = (ctx, inner) => frame(ctx.dev, { tab: null, hud: false, content: `<div id="crop" class="g-sheet">${inner}</div>`, bg: '#FFF3DC' });

part('G-01', '底部分頁列：6 個分頁各自選中', '#crop', (ctx) => sheet(ctx, TABS.map((t) => `<div class="g-tab-wrap">${tabbar(t.key)}</div>`).join('')));

part('G-02', '頂列：牧場名、等級、經驗條、金幣、設定', '#crop', (ctx) => sheet(ctx, `<div class="g-hud">${hud()}</div>`));

// D23：牧場名玩家自己取，最長 8 個中文字或 16 個英文字母；頂列放不下時字縮小，再放不下就用「…」截短
part('G-03', '頂列：金幣很多、等級兩位數、剛開局、名字最長（量測用）', '#crop', (ctx) => sheet(ctx, [{ coins: 999999, level: 14, xp: 96 }, { coins: 9876543, level: 14, xp: 3 }, { coins: 100, level: 1, xp: 0 }, { coins: 12480, ranch: { ...RANCH, name: LONG_NAMES.cjk } }, { coins: 12480, ranch: { ...RANCH, name: LONG_NAMES.latin } }].map((h) => `<div class="g-hud">${hud({ ...h, w: ctx.dev.w })}</div>`).join('')));

part('G-04', '操作結果：成功、伺服器拒絕、網路不穩', '#crop', (ctx) => sheet(ctx, `
  <div class="g-toast">${toast('ok', '升級完成：奶桶 42 → 63 瓶')}</div>
  <div class="g-toast">${toast('err', '金幣不夠，還差 1,210 幣')}</div>
  <div class="g-toast">${toast('warn', '網路不穩，請稍後再試')}</div>`));

part('G-05', '伺服器通知：有人借了你的公牛', '#crop', (ctx) => sheet(ctx, `<div class="g-notice"><div class="notice">${icon('coin', 30)}<div class="grow"><b>有人借了你的公牛</b><span>安格斯 #5 借給 星河松林牧舍 #3310，收到 <b class="num">870</b> 幣</span></div></div></div>`));

part('G-06', '處理中：按下的按鈕轉圈，其他按鈕停用', '#crop', (ctx) => sheet(ctx, `<div class="card g-busy">
  <div class="card-head" style="margin-bottom:10px"><span class="card-title">升級</span><span class="card-sub">送出後等伺服器回覆</span></div>
  <div class="up-row"><span class="grow"><b>加大奶桶</b><br><span class="hint">42 → 63 瓶</span></span>${btn('處理中…', { small: true, busy: true })}</div>
  <div class="up-row"><span class="grow"><b>加大倉庫</b><br><span class="hint">225 → 337 瓶</span></span>${btn('480 幣', { small: true, kind: 'primary', disabled: true })}</div>
  <div class="up-row"><span class="grow"><b>冷藏設備</b><br><span class="hint">保鮮 9 → 12 小時</span></span>${btn('4,000 幣', { small: true, kind: 'primary', disabled: true })}</div></div>`));

part('G-07', '牛的標籤：用途、稀有度、狀態', '#crop', (ctx) => sheet(ctx, `<div class="card g-badges">
  <div class="g-line"><span class="g-k">用途</span>${useChip('dairy')}${useChip('draft')}${useChip('beef')}<span class="use">公</span><span class="use">母</span></div>
  <div class="g-line"><span class="g-k">稀有度</span>${tierChip(0)}${tierChip(1)}${tierChip(2)}${tierChip(3)}</div>
  <div class="g-line"><span class="g-k">狀態</span>${badge('calf', '小牛')}${badge('old', '老牛')}${badge('working', '工作中')}${badge('listed', '上架中')}${badge('bred', '已配種')}</div></div>`));

part('G-08', '小牛長大倒數卡（配種、借種共用）', '#crop', (ctx) => sheet(ctx, `<div class="card calf-card">
  <div class="calf-pic">${cowSVG({ breed: 'strawberry', age: 'calf', seed: 91 }, { w: 84, h: 84, pose: 'front' })}</div>
  <div class="grow"><div class="row" style="gap:6px"><b style="font-size:16px">新小牛 草莓牛 #16</b></div><div class="chips" style="margin:4px 0">${tierChip(3)}${badge('calf', '小牛')}</div>
  <div class="hint">長大還要 <b class="num">7 小時 42 分</b></div>${bar(4, { color: 'yellow' })}</div></div>`));

part('G-09', '下拉重新整理', '#crop', (ctx) => sheet(ctx, `<div class="g-pull"><div class="pull-ind"><span class="spinner"></span>重新整理中…</div>
  <div class="card" style="opacity:.9"><div class="row" style="gap:8px">${cowSVG({ breed: 'chocolate', sex: 'bull', seed: 75 }, { w: 56, h: 56 })}<div><b>巧克力牛 公</b><div class="hint">稀有・2,000 幣</div></div></div></div></div>`));

part('G-10', '頂列齒輪的小點：還沒備份牧場、也還沒打開過「備份牧場」頁', '#crop', (ctx) => sheet(ctx, `<div class="g-hud">${hud({ dot: true, w: ctx.dev.w })}</div>`));

export default { id: 'G', name: '共用元件', states: S };
