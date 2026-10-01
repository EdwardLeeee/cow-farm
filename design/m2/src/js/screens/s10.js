// S19 商店抽牛（A／B／C 等級，機率公開）、S10 設施升級、S11 升級與解鎖提示
import { frame, btn, seg, icon, fmt, cowSVG, dialog, toast, tierChip, useChip, badge, hud } from '../kit.js';
import { SHOP, SHOP_TYPE, UPGRADES, RANCH } from '../fixtures.js';
import { t, dur, cowName, useName, sexName, tierName } from '../i18n.js';
import { ranchPage } from './s03.js';

const GC = { A: '#FFD45E', B: '#CFE6FF', C: '#FFD9C2' };
const p1 = (v) => (v >= 1 ? `${v % 1 ? v.toFixed(1) : v}%` : v >= 0.01 ? `${v}%` : '<0.01%');

function gradeCard(g, { disabled = false, reason = '', loading = false, failed = false } = {}) {
  const body = loading ? `<div class="oc-empty"><span class="spinner"></span><span>${t('loadingShop')}</span></div>`
    : failed ? `<div class="oc-empty"><span class="err-text">${icon('err', 20)} ${t('s19.probFailed')}</span>${btn(t('retry'), { small: true, ic: 'refresh' })}</div>`
      : `<div class="prob-grid">
        <div class="pg-k">${t('probType')}</div><div class="pg-v">${['dairy', 'draft', 'beef'].map((u, i) => `<span>${useName(u)} <b class="num">${SHOP_TYPE[i]}%</b></span>`).join('')}</div>
        <div class="pg-k">${t('probSex')}</div><div class="pg-v"><span>${sexName('bull')} <b class="num">50%</b></span><span>${sexName('cow')} <b class="num">50%</b></span></div>
        <div class="pg-k">${t('probTier')}</div><div class="pg-v">${g.tier.map((v, i) => `<span>${tierName(i)} <b class="num">${p1(v)}</b></span>`).join('')}</div></div>`;
  return `<article class="card grade-card">
    <div class="gc-top"><span class="gc-badge" style="background:${GC[g.grade]}">${g.grade}</span><div class="grow"><b class="gc-title">${t('g.grade', { g: g.grade })}</b><div class="hint">${t(`s19.desc${g.grade}`)}</div></div>
      ${btn(t('costCoins', { v: fmt(g.price) }), { kind: 'primary', small: true, ic: 'coin', disabled: disabled || loading || failed })}</div>
    ${reason ? `<p class="warn-text" style="margin-top:6px">${reason}</p>` : ''}
    ${body}</article>`;
}
function shopPage(ctx, o = {}) {
  const content = `<div class="stack">
    ${seg([t('s19.segDraw'), t('s19.segFacility')], 0)}
    <p class="rule-line shop-rule">${icon('info', 18)}<span>${t('s19.rule')}</span></p>
    ${SHOP.map((g) => gradeCard(g, o.cards ? o.cards(g) : {})).join('')}
  </div>`;
  return frame(ctx.dev, { tab: 'shop', content, overlays: o.overlays || '', hud: o.hud || {} });
}

const S19 = [];
const full19 = (id, name, render, x = {}) => S19.push({ id, name, type: 'full', render, ...x });
const part19 = (id, name, crop, render, x = {}) => S19.push({ id, name, type: 'part', crop, render, ...x });
full19('S19-01', 'A、B、C 三個等級與公開機率', (ctx) => shopPage(ctx));
part19('S19-02', '機率載入中、載入失敗', '#crop', (ctx) => frame(ctx.dev, { tab: 'shop', content: `<div id="crop" class="stack">${gradeCard(SHOP[0], { loading: true })}${gradeCard(SHOP[1], { failed: true })}</div>` }));
part19('S19-03', '金幣不夠：按鈕停用並說明', '#crop', (ctx) => frame(ctx.dev, { tab: 'shop', hud: { coins: 1250 }, content: `<div id="crop" class="stack">${gradeCard(SHOP[0], { disabled: true, reason: t('notEnoughCoins', { n: fmt(1950) }) })}${gradeCard(SHOP[1], { disabled: true, reason: t('notEnoughCoins', { n: fmt(450) }) })}</div>` }));
part19('S19-04', '牛舍滿了：三顆都停用', '#crop', (ctx) => frame(ctx.dev, { tab: 'shop', content: `<div id="crop" class="stack"><p class="warn-text note-line">${icon('warn', 18)}<span>${t('s19.penFull', { used: 12, slots: 12 })}</span></p>${gradeCard(SHOP[2], { disabled: true })}</div>` }));
full19('S19-05', '抽到的結果', (ctx) => shopPage(ctx, {
  hud: { coins: RANCH.coins - 3200 },
  overlays: dialog({
    title: t('drawnTitle', { g: 'A' }),
    body: `<div class="draw-pic">${cowSVG({ breed: 'highland', age: 'calf', seed: 97 }, { w: 170, h: 150 })}</div>
      <p class="draw-name">${cowName('highland', 17)}</p><div class="chips" style="justify-content:center">${useChip('draft')}<span class="use">${sexName('cow')}</span>${tierChip(1)}${badge('calf', t('stageCalf'))}</div>
      <p class="hint" style="text-align:center;margin-top:6px">${t('s19.drawnDraft', { time: dur({ h: 2 }) })}</p>`,
    buttons: btn(t('ok'), { kind: 'primary' }),
  }),
}));

// ---------------- S10 設施升級 ----------------
const U = UPGRADES;
function upRow(key, o = {}) {
  const spec = {
    pen: ['barn', t('upPen'), t('effectPen', { a: U.pen.now, b: U.pen.next }), U.pen.cost, t('s10.penTimes', { n: U.pen.level })],
    bucket: ['pail', t('upBucket'), t('s10.effectBottles', { a: U.bucket.now, b: U.bucket.next }), U.bucket.cost, t('g.levelN', { n: U.bucket.level })],
    warehouse: ['box', t('upWarehouse'), t('s10.effectBottles', { a: U.warehouse.now, b: U.warehouse.next }), U.warehouse.cost, t('g.levelN', { n: U.warehouse.level })],
    fresh: ['leaf', t('upFresh'), t('s10.effectFresh', { a: U.fresh.now[0], b: U.fresh.next[0] }), U.fresh.cost, t('s10.levelOf', { n: U.fresh.level, max: 4 })],
  }[key];
  const [ic, name, effect, cost, lv] = o.spec || spec;
  const action = o.maxed ? `<span class="maxed">${t('maxed')}</span>` : o.opensIn ? btn(t('opensIn', { v: o.opensIn }), { small: true, disabled: true, ic: 'clock' }) : o.busy ? btn(t('g.busy'), { small: true, busy: true }) : btn(t('costCoins', { v: fmt(cost) }), { kind: 'primary', small: true, ic: 'coin', disabled: o.disabled });
  return `<article class="card up-card${o.done ? ' done' : ''}"><span class="up-ic">${icon(ic, 30)}</span><div class="grow"><b class="up-name">${name}</b><div class="up-lv">${o.maxed ? t('s10.maxLevel') : lv}</div>
    <div class="up-eff">${o.maxed ? (key === 'fresh' ? t('s10.freshMax', { h: 18 }) : t('s10.maxedEffect')) : effect}</div>${o.reason ? `<div class="warn-text">${o.reason}</div>` : ''}</div>${action}</article>`;
}
function facilityPage(ctx, o = {}) {
  const content = `<div class="stack">
    ${seg([t('s19.segDraw'), t('s19.segFacility')], 1)}
    ${['pen', 'bucket', 'warehouse', 'fresh'].map((k) => upRow(k, (o.rows || {})[k] || {})).join('')}
    <p class="hint" style="text-align:center">${t('s10.fieldsNote')}</p>
  </div>`;
  return frame(ctx.dev, { tab: 'shop', content, overlays: o.overlays || '', hud: o.hud || {} });
}
const S10 = [];
const full10 = (id, name, render, x = {}) => S10.push({ id, name, type: 'full', render, ...x });
const part10 = (id, name, crop, render, x = {}) => S10.push({ id, name, type: 'part', crop, render, ...x });
full10('S10-01', '升級列表', (ctx) => facilityPage(ctx));
part10('S10-02', '金幣不夠', '#crop', (ctx) => frame(ctx.dev, { tab: 'shop', content: `<div id="crop" class="stack">${upRow('pen', { disabled: true, reason: t('notEnoughCoins', { n: fmt(2150) }) })}</div>` }));
part10('S10-03', '已滿級', '#crop', (ctx) => frame(ctx.dev, { tab: 'shop', content: `<div id="crop" class="stack">${upRow('fresh', { maxed: true })}</div>` }));
part10('S10-04', '第一次擴建還沒開放（開局第 15 分鐘）', '#crop', (ctx) => frame(ctx.dev, { tab: 'shop', content: `<div id="crop" class="stack">${upRow('pen', { opensIn: dur({ m: 3 }), spec: ['barn', t('upPen'), t('effectPen', { a: 2, b: 3 }), 280, t('s10.penNever')] })}</div>` }));
full10('S10-05', '升級成功', (ctx) => facilityPage(ctx, {
  hud: { coins: RANCH.coins - 310 },
  rows: { bucket: { done: true, spec: ['pail', t('upBucket'), t('s10.effectBottles', { a: 63, b: 94 }), 481, t('g.levelN', { n: 2 })] } },
  overlays: toast('ok', t('s10.upgraded', { what: t('bucketTitle'), effect: t('s10.effectBottles', { a: 42, b: 63 }) })),
}));

// ---------------- S11 升級與解鎖 ----------------
function levelUp(ctx, { lv }) {
  const confetti = Array.from({ length: 26 }, (_, i) => { const x = (i * 37) % 100, y = (i * 53) % 46, c = ['#FFD45E', '#FF9784', '#A9DBFF', '#BDE8A6', '#FFD0DE'][i % 5], r = (i * 29) % 90; return `<i style="left:${x}%;top:${y}%;background:${c};transform:rotate(${r}deg)"></i>`; }).join('');
  const body = `<p class="lv-sub">${t('s11.earned', { v: fmt(7500) })}</p><p class="hint" style="text-align:center">${t('s11.hint')}</p>`;
  const card = `<div class="lv-wrap"><div class="confetti">${confetti}</div>
    <section class="lv-card card"><div class="lv-ribbon" data-free>${t('s11.ribbon')}</div><div class="lv-big"><span>${t('s11.lv')}</span><b class="num">${lv}</b></div>${body}
      <div class="btn-row" style="margin-top:14px;width:100%">${btn(t('ok'), { kind: 'primary' })}</div></section></div>`;
  return ranchPage(ctx, { hud: { level: lv, xp: 0 }, overlays: `<div class="backdrop"></div>${card}` });
}

const S11 = [];
const full11 = (id, name, render, x = {}) => S11.push({ id, name, type: 'full', render, ...x });
const part11 = (id, name, crop, render, x = {}) => S11.push({ id, name, type: 'part', crop, render, ...x });
full11('S11-01', '場主升級慶祝', (ctx) => levelUp(ctx, { lv: 5 }));
part11('S11-03', '新手引導提示（第 15 分鐘、第 20 分鐘）', '#crop', (ctx) => frame(ctx.dev, { tab: null, hud: false, content: `<div id="crop" class="stack">
  <div class="coach"><span class="coach-ic">${cowSVG({ breed: 'holstein' }, { w: 56, h: 56 })}</span><div class="grow"><b>${t('s11.coachPenTitle')}</b><p>${t('s11.coachPenBody', { price: 280 })}</p></div><span class="coach-go">${btn(t('s11.coachPenGo'), { small: true, kind: 'primary' })}</span></div>
  <div class="coach"><span class="coach-ic">${cowSVG({ breed: 'yellow', sex: 'bull', seed: 33 }, { w: 56, h: 56 })}</span><div class="grow"><b>${t('s11.coachBullTitle')}</b><p>${t('s11.coachBullBody')}</p></div><span class="coach-go">${btn(t('s11.coachBullGo'), { small: true, kind: 'pink' })}</span></div></div>` }));
part11('S11-04', '頂列經驗條：快升級、剛升級', '#crop', (ctx) => frame(ctx.dev, { tab: null, hud: false, content: `<div id="crop" class="g-sheet">
  <div class="g-hud">${hud({ level: 4, xp: 96, w: ctx.dev.w })}</div><div class="g-hud">${hud({ level: 5, xp: 0, w: ctx.dev.w })}</div>
  <p class="hint" data-note>經驗條＝這一級的累積收入進度（賣出＋借種收入）。Lv4 要 3,500 幣，Lv5 要 7,500 幣。</p></div>` }));

// 升到 Lv2 的慶祝卡關掉以後出現一次（D22；企劃書 4.11）。這時候還沒備份、也沒打開過備份頁，所以頂列的齒輪上有小點。
full11('S11-05', '升到 Lv2 之後：提醒備份牧場（只出現一次）', (ctx) => ranchPage(ctx, {
  herd: [{ id: 1, breed: 'holstein', x: 96, y: 420, facing: 'right', depth: 1, milk: true }, { id: 2, breed: 'yellow', sex: 'bull', x: 268, y: 436, facing: 'left', depth: 1 }],
  pen: { used: 2, slots: 3 },
  hud: { level: 2, xp: 12, coins: 660, dot: true },
  dock: { bucket: { qty: 9.8, cap: 28, perHour: 14 }, milkLots: [{ qty: 18, tier: 0, fresh: 1 }], cap: 150, beef: 0, rice: 22 },
  overlays: dialog({
    title: t('s11.backupTitle'),
    body: `<div class="bk-pic">${cowSVG({ breed: 'holstein' }, { w: 110, h: 110 })}</div><p style="text-align:center">${t('s11.backupBody')}</p>`,
    buttons: `${btn(t('s11.later'))}${btn(t('s11.backupNow'), { kind: 'primary' })}`,
  }),
}));

export const S10M = { id: 'S10', name: '商店：設施升級', states: S10 };
// D24：第一版沒有等級解鎖，所以原本的 S11-02（升到 Lv3 解鎖 K 線）拿掉；升級只有慶祝和經驗條
export const S11M = { id: 'S11', name: '升級慶祝與提示', states: S11 };
export const S19M = { id: 'S19', name: '商店：抽牛', states: S19 };
