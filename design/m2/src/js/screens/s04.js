// S04 牛的詳細資料
import { frame, btn, badge, tierChip, useChip, sexText, icon, fmt, cowSVG, sheet, toast, empty, BREEDS, TIER_NAME } from '../kit.js';
import { COWS, cowById, pct, studFee, STUD_RATE, BEST_BULL_KG } from '../fixtures.js';
import { tierOf } from '../../cow/breeds.js';

export const GRADE_BG = { A: '#FFD45E', B: '#CFE6FF', C: '#FFD9C2' };
export function gradeBar(p) {
  return `<div class="grade-bar">${['A', 'B', 'C'].map((g) => `<i style="width:${p[g] * 100}%;background:${GRADE_BG[g]}"></i>`).join('')}</div>
  <div class="grade-legend">${['A', 'B', 'C'].map((g) => `<span><b class="gchip" style="background:${GRADE_BG[g]}">${g}</b><span class="num">${pct(p[g])}</span></span>`).join('')}</div>`;
}

// c：牛（fixtures 的格式）；o.buttons 覆寫按鈕區；o.note 橘字提醒
export function detailPage(ctx, c, o = {}) {
  const b = BREEDS[c.breed], t = tierOf(b);
  const chips = [useChip(b.use), `<span class="use">${sexText(c.sex)}</span>`, tierChip(t)];
  if (c.age === 'calf') chips.push(badge('calf', '小牛'));
  if (c.age === 'old') chips.push(badge('old', '老牛'));
  if (c.field != null) chips.push(badge('working', '工作中'));
  if (c.listed) chips.push(badge('listed', '上架中'));
  if (c.bred) chips.push(badge('bred', '已配種'));
  const cells = [];
  cells.push(['年齡', c.ageText]);
  if (c.age === 'calf') cells.push(['長大還要', c.grow]);
  else if (b.use === 'dairy' && c.sex === 'cow') cells.push(['產奶', `${c.milk} <small>瓶／時</small>`]);
  else if (b.use === 'draft') cells.push(['耕田', `${c.rice} <small>公斤稻米／時</small>`]);
  else cells.push(['用途', b.use === 'beef' ? '出貨牛肉最多' : '配種']);
  if (c.age !== 'calf') { cells.push(['體重', `${fmt(c.kg)} <small>公斤</small>`]); cells.push(['出貨估值', `約 ${fmt(c.value)} <small>幣</small>`]); }
  const origin = { start: '開局', A: '商店 A 級', B: '商店 B 級', C: '商店 C 級', breed: '自己配種', stud: '借種' }[c.origin] || '';
  const probs = c.age !== 'calf' && c.probs ? `<article class="card">
      <div class="card-head"><span class="card-title">出貨評級機率</span><span class="card-sub">養到最佳體重，A 級機會最高</span></div>
      <div style="margin-top:8px">${gradeBar(c.probs)}</div></article>` : '';
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="返回">${icon('back', 22)}</button><div class="grow"><h1>${b.name} #${c.id}</h1><div class="chips" style="margin-top:3px">${chips.join('')}</div></div></div>
    <article class="card hero"><div class="hero-bg"></div>${cowSVG({ breed: c.breed, sex: c.sex, age: c.age === 'calf' ? 'calf' : 'adult', seed: c.seed }, { w: 200, h: 150, pose: 'front', pad: 4 })}
      <span class="origin-tag">來源：${origin}</span>${c.age === 'old' ? '<p class="hint hero-note">老牛：過了壯年，產出和肉質會慢慢下降</p>' : ''}</article>
    ${o.note ? `<p class="warn-text note-line">${icon('warn', 18)}<span>${o.note}</span></p>` : ''}
    <div class="kv">${cells.map(([k, v]) => `<div class="cell"><div class="k">${k}</div><div class="v num">${v}</div></div>`).join('')}</div>
    ${probs}
  </div>`;
  const rows = (o.buttons.match(/class="btn-row"/g) || []).length + (o.buttons.includes('block') ? 1 : 0) + (o.buttons.includes('<p') ? 1 : 0);
  return frame(ctx.dev, { tab: 'ranch', content, contentCls: `has-actions rows-${Math.max(1, rows)}`, body: `<div class="detail-actions rows-${Math.max(1, rows)}">${o.buttons}</div>`, overlays: o.overlays || '', offline: o.offline });
}

const S = [];
const full = (id, name, render, x = {}) => S.push({ id, name, type: 'full', render, ...x });
const part = (id, name, crop, render, x = {}) => S.push({ id, name, type: 'part', crop, render, ...x });

const shipBtn = (dis) => btn('出貨', { kind: 'danger', ic: 'truck', disabled: dis });
const breedBtn = (dis, label = '選這頭去配種') => btn(label, { kind: 'pink', ic: 'heart', disabled: dis });

full('S04-01', '成年母乳牛', (ctx) => detailPage(ctx, cowById(3), { buttons: `<div class="btn-row">${breedBtn(false)}${shipBtn(false)}</div>` }));
full('S04-02', '肉牛（估值最高）', (ctx) => detailPage(ctx, cowById(11), { buttons: `<div class="btn-row">${breedBtn(false)}${shipBtn(false)}</div>` }));
const freeBull = { ...cowById(5), listed: null };
full('S04-03', '公牛：可以上架借種', (ctx) => detailPage(ctx, freeBull, { buttons: `${btn('上架借種', { kind: 'primary', ic: 'tag', block: true })}<div class="btn-row" style="margin-top:12px">${breedBtn(false)}${shipBtn(false)}</div>` }));
// D26：借種費由系統算（公牛現在的體重 × 每公斤價格，四捨五入到 10 幣），主人只決定要不要上架
export function feeBox(kg, tier, best) {
  const fee = studFee(kg, tier);
  return `<div class="fee-box"><div class="fee-top"><span class="k">借種費</span><b class="num">${fmt(fee)}</b><span class="u">幣</span></div>
    <p class="fee-how">${TIER_NAME[tier]}（每公斤 ${STUD_RATE[tier]} 幣）× ${fmt(kg)} 公斤${kg < best ? '，長大後會再漲' : '，已經長到最壯'}</p></div>`;
}
const FEE5 = studFee(freeBull.kg, 0);
full('S04-04', '上架借種：借種費由系統算', (ctx) => detailPage(ctx, freeBull, {
  buttons: `${btn('上架借種', { kind: 'primary', ic: 'tag', block: true })}<div class="btn-row" style="margin-top:12px">${breedBtn(false)}${shipBtn(false)}</div>`,
  overlays: sheet({
    title: '安格斯 #5 上架借種',
    body: `${feeBox(freeBull.kg, 0, BEST_BULL_KG.beef)}
      <p class="hint" style="margin-top:10px">別人付這個錢借你的公牛配種；錢給你，小牛歸對方。借出去就算這頭公牛這輩子的那一次配種。</p>
      <div class="btn-row" style="margin-top:14px">${btn('取消')}${btn(`上架（${fmt(FEE5)} 幣）`, { kind: 'primary' })}</div>`,
  }),
}));
full('S04-05', '公牛上架中', (ctx) => detailPage(ctx, cowById(5), {
  note: `上架借種中（${fmt(FEE5)} 幣，跟著體重自動漲），先下架才能出貨或配種`,
  buttons: `${btn('下架', { ic: 'tag', block: true })}<div class="btn-row" style="margin-top:12px">${breedBtn(true)}${shipBtn(true)}</div>`,
}));
const idleOx = { ...cowById(2), field: null };
full('S04-06', '耕牛沒下田：派去田裡', (ctx) => detailPage(ctx, idleOx, { buttons: `${btn('派去田裡', { kind: 'green', ic: 'sprout', block: true })}<div class="btn-row" style="margin-top:12px">${breedBtn(false)}${shipBtn(false)}</div>` }));
full('S04-07', '耕牛在田裡工作', (ctx) => detailPage(ctx, cowById(2), {
  note: '在第 1 塊田工作，先叫回來才能出貨或配種',
  buttons: `${btn('叫回來', { ic: 'hand', block: true })}<div class="btn-row" style="margin-top:12px">${breedBtn(true)}${shipBtn(true)}</div>`,
}));
full('S04-08', '小牛：長大倒數', (ctx) => detailPage(ctx, cowById(15), { buttons: `<p class="hint" style="text-align:center">小牛長大以後才能配種、出貨。</p><div class="btn-row" style="margin-top:8px">${breedBtn(true, '還不能配種')}${btn('小牛還不能出貨', { kind: 'danger', disabled: true })}</div>` }));
full('S04-09', '已配種（一輩子一次）', (ctx) => detailPage(ctx, { ...cowById(7), bred: true }, {
  note: '已配種：每頭牛一輩子只能配種一次',
  buttons: `<div class="btn-row">${breedBtn(true, '已配過種')}${shipBtn(false)}</div>`,
}));
part('S04-10', '老牛：標籤與說明', '.content .stack', (ctx) => detailPage(ctx, cowById(8), { buttons: `<div class="btn-row">${breedBtn(true, '已配過種')}${shipBtn(false)}</div>` }));
full('S04-11', '這頭牛已經不在了', (ctx) => frame(ctx.dev, { tab: 'ranch', content: `<div class="stack">
  <div class="page-head"><button class="icon-btn" aria-label="返回">${icon('back', 22)}</button><div class="grow"><h1>牛 #3</h1></div></div>
  <article class="card">${empty({ pic: cowSVG({ breed: 'holstein' }, { w: 120, h: 120, sil: true }), t1: '找不到這頭牛', t2: '可能已經出貨了，或在另一支手機上處理過。', action: btn('回牧場', { kind: 'primary' }) })}</article></div>` }));
part('S04-12', '斷線：按鈕全部停用', '.detail-actions', (ctx) => detailPage(ctx, cowById(3), { offline: true, buttons: `<div class="btn-row">${breedBtn(true)}${shipBtn(true)}</div>` }));
part('S04-13', '耕牛：沒有空田，派不出去', '.detail-actions', (ctx) => detailPage(ctx, idleOx, { buttons: `${btn('派去田裡', { kind: 'green', ic: 'sprout', block: true, disabled: true })}<p class="warn-text" style="margin-top:8px;text-align:center">沒有空田：先開新田，或叫回別的耕牛</p><div class="btn-row" style="margin-top:10px">${breedBtn(false)}${shipBtn(false)}</div>` }));

export default { id: 'S04', name: '牛的詳細資料', states: S };
