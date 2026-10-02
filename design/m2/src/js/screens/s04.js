// S04 牛的詳細資料
import { frame, btn, badge, tierChip, useChip, sexText, icon, fmt, cowSVG, sheet, toast, empty, BREEDS } from '../kit.js';
import { COWS, cowById, pct, studFee, STUD_RATE, BEST_BULL_KG } from '../fixtures.js';
import { tierOf } from '../../cow/breeds.js';
import { t, dur, cowName, tierName } from '../i18n.js';

export const GRADE_BG = { A: '#FFD45E', B: '#CFE6FF', C: '#FFD9C2' };
export function gradeBar(p) {
  return `<div class="grade-bar">${['A', 'B', 'C'].map((g) => `<i style="width:${p[g] * 100}%;background:${GRADE_BG[g]}"></i>`).join('')}</div>
  <div class="grade-legend">${['A', 'B', 'C'].map((g) => `<span><b class="gchip" style="background:${GRADE_BG[g]}">${g}</b><span class="num">${pct(p[g])}</span></span>`).join('')}</div>`;
}

// c：牛（fixtures 的格式）；o.buttons 覆寫按鈕區；o.note 橘字提醒
export function detailPage(ctx, c, o = {}) {
  const b = BREEDS[c.breed], tier = tierOf(b);
  const chips = [useChip(b.use), `<span class="use">${sexText(c.sex)}</span>`, tierChip(tier)];
  if (c.age === 'calf') chips.push(badge('calf', t('stageCalf')));
  if (c.age === 'old') chips.push(badge('old', t('stageOld')));
  if (c.field != null) chips.push(badge('working', t('badgeWorking')));
  if (c.listed) chips.push(badge('listed', t('badgeListed')));
  if (c.bred) chips.push(badge('bred', t('badgeBred')));
  const cells = [];
  cells.push([t('s04.age'), dur(c.age_)]);
  if (c.age === 'calf') cells.push([t('s04.growIn'), dur(c.grow_)]);
  else if (b.use === 'dairy' && c.sex === 'cow') cells.push([t('g.milk'), `${c.milk} <small>${t('g.perHourMilk')}</small>`]);
  else if (b.use === 'draft') cells.push([t('g.plow'), `${c.rice} <small>${t('g.perHourRice')}</small>`]);
  else cells.push([t('probType'), b.use === 'beef' ? t('s04.useBeef') : t('s04.useBreed')]);
  if (c.age !== 'calf') { cells.push([t('s04.weight'), `${fmt(c.kg)} <small>${t('g.kg')}</small>`]); cells.push([t('s04.value'), `${t('s04.about', { v: fmt(c.value) })} <small>${t('g.coin')}</small>`]); }
  const origin = c.origin === 'start' ? t('s04.originStart') : 'ABC'.includes(c.origin || '-') ? t('s04.originShop', { g: c.origin }) : c.origin === 'breed' ? t('s04.originBreed') : c.origin === 'stud' ? t('s04.originStud') : '';
  const probs = c.age !== 'calf' && c.probs ? `<article class="card">
      <div class="card-head"><span class="card-title">${t('shipGradeTitle')}</span><span class="card-sub">${t('s04.gradeHint')}</span></div>
      <div style="margin-top:8px">${gradeBar(c.probs)}</div></article>` : '';
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${cowName(c.breed, c.id)}</h1><div class="chips" style="margin-top:3px">${chips.join('')}</div></div></div>
    <article class="card hero"><div class="hero-bg"></div>${cowSVG({ breed: c.breed, sex: c.sex, age: c.age === 'calf' ? 'calf' : 'adult', seed: c.seed }, { w: 200, h: 150, pose: 'front', pad: 4 })}
      <span class="origin-tag">${t('origin', { v: origin })}</span>${c.age === 'old' ? `<p class="hint hero-note">${t('s04.oldNote')}</p>` : ''}</article>
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

const shipBtn = (dis) => btn(t('ship'), { kind: 'danger', ic: 'truck', disabled: dis });
const breedBtn = (dis, label = t('pickForBreed')) => btn(label, { kind: 'pink', ic: 'heart', disabled: dis });

full('S04-01', '成年母乳牛', (ctx) => detailPage(ctx, cowById(3), { buttons: `<div class="btn-row">${breedBtn(false)}${shipBtn(false)}</div>` }));
full('S04-02', '肉牛（估值最高）', (ctx) => detailPage(ctx, cowById(11), { buttons: `<div class="btn-row">${breedBtn(false)}${shipBtn(false)}</div>` }));
const freeBull = { ...cowById(5), listed: null };
full('S04-03', '公牛：可以上架借種', (ctx) => detailPage(ctx, freeBull, { buttons: `${btn(t('s04.listStud'), { kind: 'primary', ic: 'tag', block: true })}<div class="btn-row" style="margin-top:12px">${breedBtn(false)}${shipBtn(false)}</div>` }));
// D26：借種費由系統算（公牛現在的體重 × 每公斤價格，四捨五入到 10 幣），主人只決定要不要上架
export function feeBox(kg, tier, best) {
  const fee = studFee(kg, tier);
  return `<div class="fee-box"><div class="fee-top"><span class="k">${t('s04.studFee')}</span><b class="num">${fmt(fee)}</b><span class="u">${t('g.coin')}</span></div>
    <p class="fee-how">${t(kg < best ? 's04.feeHowGrow' : 's04.feeHowMax', { tier: tierName(tier), rate: STUD_RATE[tier], kg: fmt(kg) })}</p></div>`;
}
const FEE5 = studFee(freeBull.kg, 0);
full('S04-04', '上架借種：借種費由系統算', (ctx) => detailPage(ctx, freeBull, {
  buttons: `${btn(t('s04.listStud'), { kind: 'primary', ic: 'tag', block: true })}<div class="btn-row" style="margin-top:12px">${breedBtn(false)}${shipBtn(false)}</div>`,
  overlays: sheet({
    title: t('s04.listTitle', { cow: cowName('angus', 5) }),
    body: `${feeBox(freeBull.kg, 0, BEST_BULL_KG.beef)}
      <p class="hint" style="margin-top:10px">${t('s04.listHint')}</p>
      <div class="btn-row" style="margin-top:14px">${btn(t('cancel'))}${btn(t('s04.listConfirm', { price: fmt(FEE5) }), { kind: 'primary' })}</div>`,
  }),
}));
full('S04-05', '公牛上架中', (ctx) => detailPage(ctx, cowById(5), {
  note: t('unlistFirst', { price: fmt(FEE5) }),
  buttons: `${btn(t('unlist'), { ic: 'tag', block: true })}<div class="btn-row" style="margin-top:12px">${breedBtn(true)}${shipBtn(true)}</div>`,
}));
const idleOx = { ...cowById(2), field: null };
full('S04-06', '耕牛沒下田：派去田裡', (ctx) => detailPage(ctx, idleOx, { buttons: `${btn(t('g.assign'), { kind: 'green', ic: 'sprout', block: true })}<div class="btn-row" style="margin-top:12px">${breedBtn(false)}${shipBtn(false)}</div>` }));
full('S04-07', '耕牛在田裡工作', (ctx) => detailPage(ctx, cowById(2), {
  note: t('recallFirst', { n: 1 }),
  buttons: `${btn(t('s04.recall'), { ic: 'hand', block: true })}<div class="btn-row" style="margin-top:12px">${breedBtn(true)}${shipBtn(true)}</div>`,
}));
full('S04-08', '小牛：長大倒數', (ctx) => detailPage(ctx, cowById(15), { buttons: `<p class="hint" style="text-align:center">${t('s04.calfHint')}</p><div class="btn-row" style="margin-top:8px">${breedBtn(true, t('s04.cantBreedYet'))}${btn(t('shipNotAdult'), { kind: 'danger', disabled: true })}</div>` }));
full('S04-09', '已配種（一輩子一次）', (ctx) => detailPage(ctx, { ...cowById(7), bred: true }, {
  note: t('s04.noteBred'),
  buttons: `<div class="btn-row">${breedBtn(true, t('s04.alreadyBred'))}${shipBtn(false)}</div>`,
}));
part('S04-10', '老牛：標籤與說明', '.content .stack', (ctx) => detailPage(ctx, cowById(8), { buttons: `<div class="btn-row">${breedBtn(true, t('s04.alreadyBred'))}${shipBtn(false)}</div>` }));
full('S04-11', '這頭牛已經不在了', (ctx) => frame(ctx.dev, { tab: 'ranch', content: `<div class="stack">
  <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${t('cowTitle', { id: 3 })}</h1></div></div>
  <article class="card">${empty({ pic: cowSVG({ breed: 'holstein' }, { w: 120, h: 120, sil: true }), t1: t('s04.goneTitle'), t2: t('s04.goneBody'), action: btn(t('s04.backRanch'), { kind: 'primary' }) })}</article></div>` }));
part('S04-12', '斷線：按鈕全部停用', '.detail-actions', (ctx) => detailPage(ctx, cowById(3), { offline: true, buttons: `<div class="btn-row">${breedBtn(true)}${shipBtn(true)}</div>` }));
part('S04-13', '耕牛：沒有空田，派不出去', '.detail-actions', (ctx) => detailPage(ctx, idleOx, { buttons: `${btn(t('g.assign'), { kind: 'green', ic: 'sprout', block: true, disabled: true })}<p class="warn-text" style="margin-top:8px;text-align:center">${t('s04.noField')}</p><div class="btn-row" style="margin-top:10px">${breedBtn(false)}${shipBtn(false)}</div>` }));
// 公耕牛（成年、沒配過種）：可以下田，也可以上架借種，一共 4 個動作。第一排兩顆半寬：派去田裡（或叫回來）、上架借種（或下架）；第二排照舊（缺口清單 2-1）
const oxRow = (a, b) => `<div class="btn-row">${a}${b}</div><div class="btn-row" style="margin-top:12px">`;
const FEE2 = studFee(idleOx.kg, 0);
full('S04-14', '公耕牛：沒下田、沒上架', (ctx) => detailPage(ctx, idleOx, { buttons: `${oxRow(btn(t('g.assign'), { kind: 'green', ic: 'sprout' }), btn(t('s04.listStud'), { kind: 'primary', ic: 'tag' }))}${breedBtn(false)}${shipBtn(false)}</div>` }));
full('S04-15', '公耕牛：在田裡工作', (ctx) => detailPage(ctx, cowById(2), {
  note: t('s04.recallFirstOx', { n: 1 }),
  buttons: `${oxRow(btn(t('s04.recall'), { ic: 'hand' }), btn(t('s04.listStud'), { kind: 'primary', ic: 'tag', disabled: true }))}${breedBtn(true)}${shipBtn(true)}</div>`,
}));
full('S04-16', '公耕牛：上架中', (ctx) => detailPage(ctx, { ...idleOx, listed: FEE2 }, {
  note: t('s04.unlistFirstOx', { price: fmt(FEE2) }),
  buttons: `${oxRow(btn(t('g.assign'), { kind: 'green', ic: 'sprout', disabled: true }), btn(t('unlist'), { ic: 'tag' }))}${breedBtn(true)}${shipBtn(true)}</div>`,
}));

export default { id: 'S04', name: '牛的詳細資料', states: S };
