// S07 出貨確認（出貨動畫見 A-03）與 S20 出貨評級結果（揭曉動畫見 A-10）
import { frame, btn, icon, fmt, cowSVG, dialog, sickBadge } from '../kit.js';
import { cowById, pct, sickOf, SICK_BEEF } from '../fixtures.js';
import { detailPage, GRADE_BG } from './s04.js';
import { t, cowName } from '../i18n.js';
// 評級的字（s20.gradeFormat）：{grade} 前後的字用小字，字母用大字。繁中「A 級」，英文、泰文「Grade A」「เกรด A」（ceo 2026-10-02）
function gradeLabel(g) {
  const [pre, post] = t('s20.gradeFormat').split('{grade}').map((s) => s.trim());
  return `${pre ? `<small class="pre">${pre}</small>` : ''}<span class="num">${g}</span>${post ? `<small>${post}</small>` : ''}`;
}

const cow = cowById(3);
const baseBtns = () => `<div class="btn-row"><button class="btn pink"><span>${t('pickForBreed')}</span></button><button class="btn danger"><span>${t('ship')}</span></button></div>`;
const PRICE = 11.2; // 牛肉市價（幣／公斤）
const GM = { A: 1.25, B: 1.0, C: 0.75 };
const income = (g, sick = false) => Math.round(cow.kg * PRICE * GM[g] * (sick ? SICK_BEEF : 1));

// sick：病牛出貨（v0.3 第 5 節）：牛肉只剩一成，每一級的收入、期望收入都乘一成；名字旁邊「生病了」、下面橘字說先治療再出貨能賣多少
function confirmBody({ loading = false, blocker = '', failed = false, sick = false } = {}) {
  const head = `<div class="ship-head${sick ? ' sick' : ''}">${cowSVG({ breed: 'holstein', sick }, { w: 76, h: 76, pad: 3 })}<div><b class="ship-name">${cowName('holstein', 3)}</b>${sick ? sickBadge() : ''}<div class="hint">${t('s07.kgBeef', { kg: cow.kg })}<br>${t('s07.beefPrice', { price: PRICE })}</div></div></div>`;
  if (loading) return `${head}<div class="loading-row" style="padding:26px 0 18px"><span class="spinner"></span><span>${t('loadingPreview')}</span></div>`;
  if (failed) return `${head}<div class="empty" style="padding:14px 0 4px">${icon('err', 30)}<div class="t2">${t('s07.probFailed')}</div>${btn(t('retry'), { small: true, ic: 'refresh' })}</div>`;
  const rows = ['A', 'B', 'C'].map((g) => `<div class="grade-row"><b class="gchip" style="background:${GRADE_BG[g]}">${g}</b><span class="g-name">${t('g.grade', { g })}</span><span class="num g-p">${pct(cow.probs[g])}</span><span class="g-v">${t('s07.income', { v: `<b class="num">${fmt(income(g, sick))}</b>` })}</span></div>`).join('');
  const note = sick ? `<p class="warn-text note-line" style="margin-top:10px">${icon('warn', 18)}<span>${t('s07.sickNote', { v: fmt(cow.value) })}</span></p>`
    : blocker ? `<p class="warn-text note-line" style="margin-top:10px">${icon('warn', 18)}<span>${blocker}</span></p>` : `<p class="hint" style="margin-top:8px">${t('s07.note')}</p>`;
  return `${head}
    <div class="grade-rows">${rows}</div>
    <div class="ev-line">${t('expectedValue', { v: `<b class="num">${fmt(sick ? Math.round(cow.value * SICK_BEEF) : cow.value)}</b>` })}</div>
    ${note}`;
}
const dlg = (ctx, body, { okDisabled = false, offline = false, sick = false } = {}) => detailPage(ctx, sick ? sickOf(cow) : cow, {
  buttons: baseBtns(), offline,
  overlays: dialog({ title: t('shipConfirmTitle'), body, buttons: `${btn(t('cancel'))}${btn(t('s07.confirm'), { kind: 'danger', disabled: okDisabled })}` }),
});

const S7 = [];
const full7 = (id, name, render, x = {}) => S7.push({ id, name, type: 'full', render, ...x });
const part7 = (id, name, crop, render, x = {}) => S7.push({ id, name, type: 'part', crop, render, ...x });
full7('S07-01', '取得評級機率中', (ctx) => dlg(ctx, confirmBody({ loading: true }), { okDisabled: true }));
full7('S07-02', '確認：各等級機率與收入', (ctx) => dlg(ctx, confirmBody()));
full7('S07-03', '伺服器說現在不能出貨', (ctx) => dlg(ctx, confirmBody({ blocker: t('s07.blockWorking') }), { okDisabled: true }));
part7('S07-04', '評級機率載入失敗', '.dialog', (ctx) => dlg(ctx, confirmBody({ failed: true }), { okDisabled: true }));
part7('S07-05', '斷線：「確定出貨」停用', '.dialog', (ctx) => dlg(ctx, confirmBody(), { okDisabled: true, offline: true }));
part7('S07-06', '病牛出貨：牛肉只剩一成', '.dialog', (ctx) => dlg(ctx, confirmBody({ sick: true }), { sick: true }));

// ---------- S20 評級結果 ----------
const TIPS = { A: 's20.tipA', B: 's20.tipB', C: 's20.tipC' };
function result(ctx, g) {
  const kg = cow.kg;
  const boxes = [0, 1, 2].map((i) => `<span class="gift-box" style="--i:${i}">${icon('beef', 56)}</span>`).join('');
  const body = `<div class="result-wrap">
    <div class="burst g-${g}"></div>
    <div class="result-card card">
      <p class="r-small">${t('s20.title', { cow: cowName('holstein', 3) })}</p>
      <div class="grade-big" style="background:${GRADE_BG[g]}">${gradeLabel(g)}</div>
      <div class="boxes">${boxes}</div>
      <p class="r-line">${t('s20.kgIn', { kg: `<b class="num">${kg}</b>` })}</p>
      <p class="r-line">${t('s20.sellAll', { v: `<b class="num">${fmt(income(g))}</b>` })}</p>
      <p class="hint" style="margin-top:6px;text-align:center">${t(TIPS[g])}</p>
      <div class="btn-row" style="margin-top:14px">${btn(t('s20.goMarket'))}${btn(t('ok'), { kind: 'primary' })}</div>
    </div></div>`;
  return frame(ctx.dev, { tab: null, hud: false, body, bg: '#FFF3DC' });
}
const S20 = [];
const full20 = (id, name, render, x = {}) => S20.push({ id, name, type: 'full', render, ...x });
full20('S20-01', '評級 A', (ctx) => result(ctx, 'A'));
full20('S20-02', '評級 B', (ctx) => result(ctx, 'B'));
full20('S20-03', '評級 C', (ctx) => result(ctx, 'C'));

export const S07 = { id: 'S07', name: '出貨確認', states: S7 };
export const S20M = { id: 'S20', name: '出貨評級結果', states: S20 };
