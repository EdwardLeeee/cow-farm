// S02 新手：自己取牧場名（D23，使用者 2026-10-01：「s02 取名機制有問題，應該讓用戶自己取」）
// 打字取名；「幫我想一個」從詞庫隨機組一個填進去，玩家可以再改。長度用顯示寬度算：中文字算 2，英文字母、數字、泰文字算 1，總共 2–16（最多 8 個中文字）。
// 不收 emoji 和控制字元（為了排版）；不做不雅字過濾、檢舉、封鎖（D23）。名字不必唯一，顯示時加「#1234」。
import { frame, btn, cowSVG, icon, dialog, nameWidth } from '../kit.js';

// 系統鍵盤：實作時是手機自己的鍵盤，設計稿畫成灰色色塊（高度照各手機常見的鍵盤高度）
const KB_H = { 430: 300, 390: 292, 360: 280, 320: 254 };
const KB_NOTE = '灰色的方塊是手機自己的鍵盤（系統畫面，不畫）；輸入框、字數和按鈕都要在鍵盤上面看得到。';
function keyboard(w) {
  const rows = [10, 9, 7].map((n, r) => `<div class="kb-row">${Array.from({ length: n }, () => '<i></i>').join('')}</div>`).join('');
  return `<div class="kb" style="height:${KB_H[w] || 292}px"><div class="kb-label">系統鍵盤（不畫）</div>${rows}<div class="kb-row last"><i class="w"></i><i class="sp"></i><i class="w"></i></div></div>`;
}

// value：輸入框的字；err：錯誤提示；kb：鍵盤開著；filled：剛按了「幫我想一個」
function page(ctx, { value = '', err = '', kb = false, filled = false, overlays = '' } = {}) {
  const w = nameWidth(value), ok = !err && w >= 2 && w <= 16;
  const head = kb ? `<div class="namer-head compact"><h1>幫牧場取個名字</h1></div>`
    : `<div class="namer-head">${cowSVG({ breed: 'holstein' }, { w: 84, h: 84, pose: 'front' })}<div><h1>幫牧場取個名字</h1><p class="hint">取一個自己喜歡的名字吧！</p></div></div>`;
  const content = `<div class="namer">
    ${head}
    <div class="card name-card">
      <div class="input name-input${err ? ' err' : ''}${value ? ' filled' : ''}${kb ? ' focus' : ''}">${value ? `<span class="nv">${value}</span>` : '<span class="ph">例如：晨光河畔牧場</span>'}${kb ? '<span class="caret"></span>' : ''}</div>
      <div class="name-meta"><span class="${err ? 'err-text' : 'hint'}">${err || (filled ? '想好了！可以直接用，也可以再改。' : '中文字算 2，英文字母和數字算 1')}</span><span class="num name-count${w > 16 ? ' over' : ''}">${w} / 16</span></div>
      ${btn('幫我想一個', { ic: 'sparkle', block: true, cls: 'idea-btn' })}
    </div>
    ${kb ? '' : '<p class="hint" style="text-align:center">跟別人同名也沒關係，會加上 #編號分辨，例如「晨光河畔牧場 #1234」。</p>'}
    ${btn('就叫這個', { kind: 'primary', block: true, disabled: !ok })}
  </div>`;
  const out = frame(ctx.dev, { tab: null, hud: false, content, contentCls: kb ? 'with-kb' : '', overlays: overlays + (kb ? keyboard(ctx.dev.w) : '') });
  return kb ? out.replace('<div class="phone', `<div style="--kb-h:${KB_H[ctx.dev.w] || 292}px" class="phone`) : out;
}

const S = [];
const full = (id, name, render, x = {}) => S.push({ id, name, type: 'full', render, ...x });
const part = (id, name, crop, render, x = {}) => S.push({ id, name, type: 'part', crop, render, ...x });

full('S02-01', '還沒輸入', (ctx) => page(ctx));
full('S02-02', '取好名字：歡迎卡與開局的牛', (ctx) => page(ctx, {
  value: '小花的快樂牧場',
  overlays: dialog({
    title: '歡迎來到<br>小花的快樂牧場 #1234',
    body: `<p style="text-align:center">先送你這些，開始經營吧！</p>
      <div class="gift-row">
        <div class="gift">${cowSVG({ breed: 'holstein' }, { w: 96, h: 96, pose: 'front' })}<b>荷斯坦 #1</b><span>母・會產奶</span></div>
        <div class="gift">${cowSVG({ breed: 'yellow', sex: 'bull', age: 'calf', seed: 33 }, { w: 96, h: 96, pose: 'front' })}<b>台灣黃牛 #2</b><span>公・20 分後長大</span></div>
      </div>
      <div class="gift-coin">${icon('coin', 26)}<b class="num">100</b> 幣　${icon('pail', 22)}奶桶裡已經有 <b class="num">20</b> 瓶</div>
      <p class="hint" style="text-align:center;margin-top:4px">開局 1 小時產奶 ×5，進去就能收奶、賣奶。</p>`,
    buttons: btn('進牧場', { kind: 'primary', block: true }),
  }),
}));
full('S02-03', '打字中（系統鍵盤開著）', (ctx) => page(ctx, { value: '小花的快樂', kb: true }), { note: KB_NOTE });
full('S02-04', '按了「幫我想一個」：從詞庫填一個，可以再改', (ctx) => page(ctx, { value: '晨光河畔牧場', filled: true }));
part('S02-05', '名字不能用的提示：太短、太長、表情符號', '#crop', (ctx) => frame(ctx.dev, { tab: null, hud: false, content: `<div id="crop" class="g-sheet name-errs">${[
  ['A', '名字至少要 1 個中文字，或 2 個英文字母'],
  ['晨光河畔牧場的小木屋', '名字最多 8 個中文字（或 16 個英文字母）'],
  ['小花牧場🐮', '名字不能用表情符號'],
].map(([v, e]) => `<div class="card name-card"><div class="input name-input err filled"><span class="nv">${v}</span></div><div class="name-meta"><span class="err-text">${e}</span><span class="num name-count${nameWidth(v) > 16 ? ' over' : ''}">${nameWidth(v)} / 16</span></div></div>`).join('')}</div>` }));

export default { id: 'S02', name: '自己取名', states: S };
