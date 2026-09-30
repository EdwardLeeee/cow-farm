// S07 出貨確認（出貨動畫見 A-03）與 S20 出貨評級結果（揭曉動畫見 A-10）
import { frame, btn, icon, fmt, cowSVG, dialog } from '../kit.js';
import { cowById, pct } from '../fixtures.js';
import { detailPage, GRADE_BG } from './s04.js';

const cow = cowById(3);
const baseBtns = `<div class="btn-row"><button class="btn pink"><span>選這頭去配種</span></button><button class="btn danger"><span>出貨</span></button></div>`;
const PRICE = 11.2; // 牛肉市價（幣／公斤）
const GM = { A: 1.25, B: 1.0, C: 0.75 };
const income = (g) => Math.round(cow.kg * PRICE * GM[g]);

function confirmBody({ loading = false, blocker = '', failed = false } = {}) {
  const head = `<div class="ship-head">${cowSVG({ breed: 'holstein' }, { w: 76, h: 76, pad: 3 })}<div><b class="ship-name">荷斯坦 #3</b><div class="hint">約 ${cow.kg} 公斤牛肉<br>牛肉現價 ${PRICE} 幣／公斤</div></div></div>`;
  if (loading) return `${head}<div class="loading-row" style="padding:26px 0 18px"><span class="spinner"></span><span>正在取得評級機率…</span></div>`;
  if (failed) return `${head}<div class="empty" style="padding:14px 0 4px">${icon('err', 30)}<div class="t2">評級機率載入失敗</div>${btn('重試', { small: true, ic: 'refresh' })}</div>`;
  const rows = ['A', 'B', 'C'].map((g) => `<div class="grade-row"><b class="gchip" style="background:${GRADE_BG[g]}">${g}</b><span class="g-name">${g} 級</span><span class="num g-p">${pct(cow.probs[g])}</span><span class="g-v">收入約 <b class="num">${fmt(income(g))}</b> 幣</span></div>`).join('');
  return `${head}
    <div class="grade-rows">${rows}</div>
    <div class="ev-line">期望收入 約 <b class="num">${fmt(cow.value)}</b> 幣</div>
    ${blocker ? `<p class="warn-text note-line" style="margin-top:10px">${icon('warn', 18)}<span>${blocker}</span></p>` : '<p class="hint" style="margin-top:8px">出貨時才會隨機評級。牛肉立刻放進倉庫，要不要賣、什麼時候賣都可以自己決定。</p>'}`;
}
const dlg = (ctx, body, { okDisabled = false, offline = false } = {}) => detailPage(ctx, cow, {
  buttons: baseBtns, offline,
  overlays: dialog({ title: '確定出貨？', body, buttons: `${btn('取消')}${btn('確定出貨', { kind: 'danger', disabled: okDisabled })}` }),
});

const S7 = [];
const full7 = (id, name, render, x = {}) => S7.push({ id, name, type: 'full', render, ...x });
const part7 = (id, name, crop, render, x = {}) => S7.push({ id, name, type: 'part', crop, render, ...x });
full7('S07-01', '取得評級機率中', (ctx) => dlg(ctx, confirmBody({ loading: true }), { okDisabled: true }));
full7('S07-02', '確認：各等級機率與收入', (ctx) => dlg(ctx, confirmBody()));
full7('S07-03', '伺服器說現在不能出貨', (ctx) => dlg(ctx, confirmBody({ blocker: '這頭牛在田裡工作，先叫回來才能出貨' }), { okDisabled: true }));
part7('S07-04', '評級機率載入失敗', '.dialog', (ctx) => dlg(ctx, confirmBody({ failed: true }), { okDisabled: true }));
part7('S07-05', '斷線：「確定出貨」停用', '.dialog', (ctx) => dlg(ctx, confirmBody(), { okDisabled: true, offline: true }));

// ---------- S20 評級結果 ----------
const TIPS = {
  A: '養得剛剛好！A 級賣價 ×1.25。',
  B: '不錯！B 級照市價賣。',
  C: 'C 級賣價 ×0.75。下次養到最佳體重再出貨，拿到 A 級的機會比較高。',
};
function result(ctx, g) {
  const kg = cow.kg;
  const boxes = [0, 1, 2].map((i) => `<span class="gift-box" style="--i:${i}">${icon('beef', 56)}</span>`).join('');
  const body = `<div class="result-wrap">
    <div class="burst g-${g}"></div>
    <div class="result-card card">
      <p class="r-small">荷斯坦 #3 出貨評級</p>
      <div class="grade-big" style="background:${GRADE_BG[g]}"><span class="num">${g}</span><small>級</small></div>
      <div class="boxes">${boxes}</div>
      <p class="r-line"><b class="num">${kg}</b> 公斤牛肉放進倉庫了</p>
      <p class="r-line">現在全部賣掉約 <b class="num">${fmt(income(g))}</b> 幣</p>
      <p class="hint" style="margin-top:6px;text-align:center">${TIPS[g]}</p>
      <div class="btn-row" style="margin-top:14px">${btn('去市場')}${btn('好', { kind: 'primary' })}</div>
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
