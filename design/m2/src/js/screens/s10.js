// S19 商店抽牛（A／B／C 等級，機率公開）、S10 設施升級、S11 升級與解鎖提示
import { frame, btn, seg, icon, fmt, cowSVG, dialog, toast, tierChip, useChip, badge, hud } from '../kit.js';
import { SHOP, SHOP_TYPE, UPGRADES, RANCH } from '../fixtures.js';
import { TIER_NAME } from '../../cow/breeds.js';
import { ranchPage } from './s03.js';

const GC = { A: '#FFD45E', B: '#CFE6FF', C: '#FFD9C2' };
const p1 = (v) => (v >= 1 ? `${v % 1 ? v.toFixed(1) : v}%` : v >= 0.01 ? `${v}%` : '<0.01%');

function gradeCard(g, { disabled = false, reason = '', loading = false, failed = false } = {}) {
  const body = loading ? `<div class="oc-empty"><span class="spinner"></span><span>正在取得機率…</span></div>`
    : failed ? `<div class="oc-empty"><span class="err-text">${icon('err', 20)} 機率載入失敗</span>${btn('重試', { small: true, ic: 'refresh' })}</div>`
      : `<div class="prob-grid">
        <div class="pg-k">用途</div><div class="pg-v">${['乳牛', '耕牛', '肉牛'].map((n, i) => `<span>${n} <b class="num">${SHOP_TYPE[i]}%</b></span>`).join('')}</div>
        <div class="pg-k">公母</div><div class="pg-v"><span>公 <b class="num">50%</b></span><span>母 <b class="num">50%</b></span></div>
        <div class="pg-k">稀有度</div><div class="pg-v">${g.tier.map((v, i) => `<span>${TIER_NAME[i]} <b class="num">${p1(v)}</b></span>`).join('')}</div></div>`;
  return `<article class="card grade-card">
    <div class="gc-top"><span class="gc-badge" style="background:${GC[g.grade]}">${g.grade}</span><div class="grow"><b class="gc-title">${g.grade} 級</b><div class="hint">${g.grade === 'A' ? '最容易抽到稀有的牛' : g.grade === 'B' ? '有機會抽到稀有的牛' : '便宜，大多是一般的牛'}</div></div>
      ${btn(`${fmt(g.price)} 幣`, { kind: 'primary', small: true, ic: 'coin', disabled: disabled || loading || failed })}</div>
    ${reason ? `<p class="warn-text" style="margin-top:6px">${reason}</p>` : ''}
    ${body}</article>`;
}
function shopPage(ctx, o = {}) {
  const content = `<div class="stack">
    ${seg(['抽牛', '設施'], 0)}
    <p class="rule-line shop-rule">${icon('info', 18)}<span>只挑等級；用途、公母、稀有度是隨機的，機率全部公開。抽到的是小牛。</span></p>
    ${SHOP.map((g) => gradeCard(g, o.cards ? o.cards(g) : {})).join('')}
  </div>`;
  return frame(ctx.dev, { tab: 'shop', content, overlays: o.overlays || '', hud: o.hud || {} });
}

const S19 = [];
const full19 = (id, name, render, x = {}) => S19.push({ id, name, type: 'full', render, ...x });
const part19 = (id, name, crop, render, x = {}) => S19.push({ id, name, type: 'part', crop, render, ...x });
full19('S19-01', 'A、B、C 三個等級與公開機率', (ctx) => shopPage(ctx));
part19('S19-02', '機率載入中、載入失敗', '#crop', (ctx) => frame(ctx.dev, { tab: 'shop', content: `<div id="crop" class="stack">${gradeCard(SHOP[0], { loading: true })}${gradeCard(SHOP[1], { failed: true })}</div>` }));
part19('S19-03', '金幣不夠：按鈕停用並說明', '#crop', (ctx) => frame(ctx.dev, { tab: 'shop', hud: { coins: 1250 }, content: `<div id="crop" class="stack">${gradeCard(SHOP[0], { disabled: true, reason: '金幣不夠，還差 1,950 幣' })}${gradeCard(SHOP[1], { disabled: true, reason: '金幣不夠，還差 450 幣' })}</div>` }));
part19('S19-04', '牛舍滿了：三顆都停用', '#crop', (ctx) => frame(ctx.dev, { tab: 'shop', content: `<div id="crop" class="stack"><p class="warn-text note-line">${icon('warn', 18)}<span>牛舍滿了（12 / 12 格），先擴建或出貨</span></p>${gradeCard(SHOP[2], { disabled: true })}</div>` }));
full19('S19-05', '抽到的結果', (ctx) => shopPage(ctx, {
  hud: { coins: RANCH.coins - 3200 },
  overlays: dialog({
    title: 'A 級抽到了！',
    body: `<div class="draw-pic">${cowSVG({ breed: 'highland', age: 'calf', seed: 97 }, { w: 170, h: 150 })}</div>
      <p class="draw-name">高地牛 #17</p><div class="chips" style="justify-content:center">${useChip('draft')}<span class="use">母</span>${tierChip(1)}${badge('calf', '小牛')}</div>
      <p class="hint" style="text-align:center;margin-top:6px">長大還要 2 小時。長大後可以派去田裡種稻。</p>`,
    buttons: btn('好', { kind: 'primary' }),
  }),
}));

// ---------------- S10 設施升級 ----------------
const U = UPGRADES;
function upRow(key, o = {}) {
  const spec = {
    pen: ['barn', '擴建牛舍', `${U.pen.now} → ${U.pen.next} 格`, U.pen.cost, `擴建過 ${U.pen.level} 次`],
    bucket: ['pail', '加大奶桶', `${U.bucket.now} → ${U.bucket.next} 瓶`, U.bucket.cost, `第 ${U.bucket.level} 級`],
    warehouse: ['box', '加大倉庫', `${U.warehouse.now} → ${U.warehouse.next} 瓶`, U.warehouse.cost, `第 ${U.warehouse.level} 級`],
    fresh: ['leaf', '冷藏設備', `新鮮 100% 的時間 ${U.fresh.now[0]} → ${U.fresh.next[0]} 小時`, U.fresh.cost, `第 ${U.fresh.level} / 4 級`],
  }[key];
  const [ic, name, effect, cost, lv] = o.spec || spec;
  const action = o.maxed ? `<span class="maxed">已滿級</span>` : o.opensIn ? btn(`${o.opensIn}後開放`, { small: true, disabled: true, ic: 'clock' }) : o.busy ? btn('處理中…', { small: true, busy: true }) : btn(`${fmt(cost)} 幣`, { kind: 'primary', small: true, ic: 'coin', disabled: o.disabled });
  return `<article class="card up-card${o.done ? ' done' : ''}"><span class="up-ic">${icon(ic, 30)}</span><div class="grow"><b class="up-name">${name}</b><div class="up-lv">${o.maxed ? '最高級' : lv}</div>
    <div class="up-eff">${o.maxed ? (key === 'fresh' ? '新鮮 100% 的時間 18 小時' : '已經最大了') : effect}</div>${o.reason ? `<div class="warn-text">${o.reason}</div>` : ''}</div>${action}</article>`;
}
function facilityPage(ctx, o = {}) {
  const content = `<div class="stack">
    ${seg(['抽牛', '設施'], 1)}
    ${['pen', 'bucket', 'warehouse', 'fresh'].map((k) => upRow(k, (o.rows || {})[k] || {})).join('')}
    <p class="hint" style="text-align:center">田地在「田地」分頁開新田。</p>
  </div>`;
  return frame(ctx.dev, { tab: 'shop', content, overlays: o.overlays || '', hud: o.hud || {} });
}
const S10 = [];
const full10 = (id, name, render, x = {}) => S10.push({ id, name, type: 'full', render, ...x });
const part10 = (id, name, crop, render, x = {}) => S10.push({ id, name, type: 'part', crop, render, ...x });
full10('S10-01', '升級列表', (ctx) => facilityPage(ctx));
part10('S10-02', '金幣不夠', '#crop', (ctx) => frame(ctx.dev, { tab: 'shop', content: `<div id="crop" class="stack">${upRow('pen', { disabled: true, reason: '金幣不夠，還差 2,150 幣' })}</div>` }));
part10('S10-03', '已滿級', '#crop', (ctx) => frame(ctx.dev, { tab: 'shop', content: `<div id="crop" class="stack">${upRow('fresh', { maxed: true })}</div>` }));
part10('S10-04', '第一次擴建還沒開放（開局第 15 分鐘）', '#crop', (ctx) => frame(ctx.dev, { tab: 'shop', content: `<div id="crop" class="stack">${upRow('pen', { opensIn: '3 分' }).replace(`${U.pen.now} → ${U.pen.next} 格`, '2 → 3 格').replace(`擴建過 ${U.pen.level} 次`, '還沒擴建過').replace(`${fmt(U.pen.cost)} 幣`, '280 幣')}</div>` }));
full10('S10-05', '升級成功', (ctx) => facilityPage(ctx, {
  hud: { coins: RANCH.coins - 310 },
  rows: { bucket: { done: true, spec: ['pail', '加大奶桶', '63 → 94 瓶', 481, '第 2 級'] } },
  overlays: toast('ok', '升級完成：奶桶 42 → 63 瓶'),
}));

// ---------------- S11 升級與解鎖 ----------------
function levelUp(ctx, { lv }) {
  const confetti = Array.from({ length: 26 }, (_, i) => { const x = (i * 37) % 100, y = (i * 53) % 46, c = ['#FFD45E', '#FF9784', '#A9DBFF', '#BDE8A6', '#FFD0DE'][i % 5], r = (i * 29) % 90; return `<i style="left:${x}%;top:${y}%;background:${c};transform:rotate(${r}deg)"></i>`; }).join('');
  const body = `<p class="lv-sub">累積收入到 ${fmt(7500)} 幣了！</p><p class="hint" style="text-align:center">繼續賣牛奶、牛肉、稻米，或出借公牛，等級會往上升。</p>`;
  const card = `<div class="lv-wrap"><div class="confetti">${confetti}</div>
    <section class="lv-card card"><div class="lv-ribbon" data-free>場主升級</div><div class="lv-big"><span>Lv</span><b class="num">${lv}</b></div>${body}
      <div class="btn-row" style="margin-top:14px;width:100%">${btn('好', { kind: 'primary' })}</div></section></div>`;
  return ranchPage(ctx, { hud: { level: lv, xp: 0 }, overlays: `<div class="backdrop"></div>${card}` });
}

const S11 = [];
const full11 = (id, name, render, x = {}) => S11.push({ id, name, type: 'full', render, ...x });
const part11 = (id, name, crop, render, x = {}) => S11.push({ id, name, type: 'part', crop, render, ...x });
full11('S11-01', '場主升級慶祝', (ctx) => levelUp(ctx, { lv: 5 }));
part11('S11-03', '新手引導提示（第 15 分鐘、第 20 分鐘）', '#crop', (ctx) => frame(ctx.dev, { tab: null, hud: false, content: `<div id="crop" class="stack">
  <div class="coach"><span class="coach-ic">${cowSVG({ breed: 'holstein' }, { w: 56, h: 56 })}</span><div class="grow"><b>牛舍可以擴建了！</b><p>多一格就能多養一頭牛。到「商店 › 設施」擴建牛舍（280 幣）。</p></div><span class="coach-go">${btn('去擴建', { small: true, kind: 'primary' })}</span></div>
  <div class="coach"><span class="coach-ic">${cowSVG({ breed: 'yellow', sex: 'bull', seed: 33 }, { w: 56, h: 56 })}</span><div class="grow"><b>小公牛長大了！</b><p>可以跟母牛配種（自己的免費），也可以派去田裡種稻。</p></div><span class="coach-go">${btn('去配種', { small: true, kind: 'pink' })}</span></div></div>` }));
part11('S11-04', '頂列經驗條：快升級、剛升級', '#crop', (ctx) => frame(ctx.dev, { tab: null, hud: false, content: `<div id="crop" class="g-sheet">
  <div class="g-hud">${hud({ level: 4, xp: 96, w: ctx.dev.w })}</div><div class="g-hud">${hud({ level: 5, xp: 0, w: ctx.dev.w })}</div>
  <p class="hint">經驗條＝這一級的累積收入進度（賣出＋借種收入）。Lv4 要 3,500 幣，Lv5 要 7,500 幣。</p></div>` }));

// 升到 Lv2 的慶祝卡關掉以後出現一次（D22；企劃書 4.11）。這時候還沒備份、也沒打開過備份頁，所以頂列的齒輪上有小點。
full11('S11-05', '升到 Lv2 之後：提醒備份牧場（只出現一次）', (ctx) => ranchPage(ctx, {
  herd: [{ id: 1, breed: 'holstein', x: 96, y: 420, facing: 'right', depth: 1, milk: true }, { id: 2, breed: 'yellow', sex: 'bull', x: 268, y: 436, facing: 'left', depth: 1 }],
  pen: { used: 2, slots: 3 },
  hud: { level: 2, xp: 12, coins: 660, dot: true },
  dock: { bucket: { qty: 9.8, cap: 28, perHour: 14 }, milkLots: [{ qty: 18, tier: 0, fresh: 1 }], cap: 150, beef: 0, rice: 22 },
  overlays: dialog({
    title: '把牧場備份起來',
    body: `<div class="bk-pic">${cowSVG({ breed: 'holstein' }, { w: 110, h: 110 })}</div><p style="text-align:center">換手機或手機壞了都找得回來。</p>`,
    buttons: `${btn('之後再說')}${btn('現在備份', { kind: 'primary' })}`,
  }),
}));

export const S10M = { id: 'S10', name: '商店：設施升級', states: S10 };
// D24：第一版沒有等級解鎖，所以原本的 S11-02（升到 Lv3 解鎖 K 線）拿掉；升級只有慶祝和經驗條
export const S11M = { id: 'S11', name: '升級慶祝與提示', states: S11 };
export const S19M = { id: 'S19', name: '商店：抽牛', states: S19 };
