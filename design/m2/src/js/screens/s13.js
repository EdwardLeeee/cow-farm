// S13 設定、S14 移轉碼（新手機）、S15 連線中與斷線、S16 伺服器維護與錯誤
import { frame, btn, icon, cowSVG, cowFace, toast, fmt } from '../kit.js';
import { RANCH } from '../fixtures.js';
import { ranchPage } from './s03.js';
import { GAME_NAME } from './s01.js';

const page = (ctx, title, inner, o = {}) => frame(ctx.dev, { tab: null, hud: false, content: `<div class="stack">
  <div class="page-head">${o.noBack ? '' : `<button class="icon-btn" aria-label="返回">${icon('back', 22)}</button>`}<div class="grow"><h1>${title}</h1></div></div>${inner}</div>`, overlays: o.overlays || '' });
const row = (ic, label, right = icon('chevron', 18), cls = '') => `<button class="set-row ${cls}"><span class="set-ic">${icon(ic, 22)}</span><span class="set-label">${label}</span><span class="set-right">${right}</span></button>`;
const ext = `<span class="ext">網頁 ${icon('chevron', 16)}</span>`;

function settings(ctx, { overlays = '' } = {}) {
  return page(ctx, '設定', `
    <article class="card me-card"><span class="avatar sm">${cowFace({ breed: 'holstein' }, 40)}</span><div class="grow"><b>${RANCH.name}</b><span class="hint">${RANCH.tag}・Lv ${RANCH.level}</span></div></article>
    <article class="card set-group">${row('sound', '音效', `<span class="toggle on"><i></i></span>`)}</article>
    <article class="card set-group">${row('transfer', '產生移轉碼<small>換手機時把牧場搬過去</small>')}${row('trash', '刪除我的牧場', icon('chevron', 18), 'danger')}</article>
    <article class="card set-group">${row('shield', '隱私權政策', ext)}${row('info', '版本', '<span class="hint">1.0.0</span>')}</article>
    <p class="hint" style="text-align:center">${GAME_NAME}　・　所有帳都在伺服器計算</p>`, { overlays });
}
function transferCode(ctx, { overlays = '' } = {}) {
  return page(ctx, '移轉碼', `
    <article class="card code-card"><p class="hint" style="text-align:center">在新手機輸入這組碼</p><div class="code num">7KQ2-9XMB</div>
      <p class="code-exp">${icon('clock', 16)}24 小時內有效（到 10 月 2 日 09:41）</p>${btn('複製', { block: true, ic: 'history' })}</article>
    <article class="card"><ol class="steps"><li>在新手機打開${GAME_NAME}，選「我有移轉碼」。</li><li>輸入上面這組碼。</li><li>搬過去以後，這支手機會自動登出。</li></ol></article>
    <p class="warn-text note-line">${icon('warn', 18)}<span>不要把碼給別人：拿到碼的人可以把牧場搬走。</span></p>
    ${btn('產生新的碼', { ic: 'refresh', block: true })}<p class="hint" style="text-align:center">產生新的碼，舊的碼就不能用了。</p>`, { overlays });
}
function deletePage(ctx, typed = '') {
  const ok = typed === '刪除';
  return page(ctx, '刪除我的牧場', `
    <article class="card del-card"><div class="del-pic">${cowSVG({ breed: 'holstein' }, { w: 96, h: 96 })}</div>
      <p class="del-t">刪除後不能復原</p>
      <ul class="del-list"><li>牧場「${RANCH.name}」、所有的牛、金幣、倉庫會全部刪掉。</li><li>排行榜上的紀錄也會刪掉。</li><li>這支手機會回到第一次打開的畫面。</li></ul></article>
    <label class="field-label">請輸入「刪除」兩個字確認</label>
    <div class="input${ok ? ' filled' : ''}">${typed || '<span class="ph">刪除</span>'}${ok ? '<span class="caret"></span>' : ''}</div>
    ${btn('刪除我的牧場', { kind: 'danger', block: true, ic: 'trash', disabled: !ok })}
    ${btn('取消', { block: true })}`);
}

const S13 = [];
const f13 = (id, name, render, x = {}) => S13.push({ id, name, type: 'full', render, ...x });
const p13 = (id, name, crop, render, x = {}) => S13.push({ id, name, type: 'part', crop, render, ...x });
f13('S13-01', '設定主頁', (ctx) => settings(ctx));
f13('S13-02', '產生移轉碼', (ctx) => transferCode(ctx));
f13('S13-03', '刪除牧場：說明後果、還沒輸入', (ctx) => deletePage(ctx));
f13('S13-04', '刪除完成', (ctx) => frame(ctx.dev, { tab: null, hud: false, body: `<div class="splash"><div class="splash-title"><span class="t">${GAME_NAME}</span></div>
  <div class="splash-box" style="top:calc(var(--H) * 0.2 + 100px)"><article class="card" style="text-align:center"><div style="line-height:0">${cowSVG({ breed: 'holstein' }, { w: 120, h: 120 })}</div><b style="font-size:18px">牧場已經刪除了</b><p class="hint" style="margin-top:4px">謝謝你這段時間的照顧。</p><div style="margin-top:12px">${btn('開新牧場', { kind: 'primary', block: true })}</div></article></div></div>` }));
p13('S13-05', '刪除或產生移轉碼失敗', '#crop', (ctx) => frame(ctx.dev, { tab: null, hud: false, content: `<div id="crop" class="g-sheet"><div class="g-toast">${toast('err', '刪除失敗：網路不穩，請稍後再試')}</div><div class="g-toast">${toast('err', '移轉碼產生失敗，請稍後再試')}</div></div>` }));
p13('S13-06', '刪除牧場：輸入「刪除」後按鈕才能按', '#crop', (ctx) => deletePage(ctx, '刪除').replace('<label class="field-label">', '<div id="crop"><label class="field-label">').replace(/(<button class="btn block"><span>取消<\/span><\/button>)/, '$1</div>'));

// ---------------- S14 新手機輸入移轉碼 ----------------
function firstOpen(ctx) {
  return frame(ctx.dev, { tab: null, hud: false, body: `<div class="splash"><div class="splash-sun"></div><div class="splash-title"><span class="t">${GAME_NAME}</span></div>
    <div class="splash-cows">${cowSVG({ breed: 'holstein' }, { w: 150, h: 150 })}${cowSVG({ breed: 'yellow', sex: 'bull', age: 'calf', seed: 33 }, { w: 96, h: 96, facing: 'right' })}</div><div class="splash-ground"></div>
    <div class="splash-box">${btn('開新牧場', { kind: 'primary', block: true })}<div style="height:12px"></div>${btn('我有移轉碼', { block: true, ic: 'transfer', sub: '（從舊手機搬過來）' })}</div></div>` });
}
function codeInput(ctx, { value = '', err = false } = {}) {
  return page(ctx, '輸入移轉碼', `
    <p class="hint">在舊手機的「設定 › 產生移轉碼」拿到一組 8 個字的碼，24 小時內有效。</p>
    <div class="input code-input${err ? ' err' : ''}${value ? ' filled' : ''}">${value || '<span class="ph">例如 7KQ2-9XMB</span>'}</div>
    ${err ? `<p class="err-text">${icon('err', 16)} 移轉碼不對，或已經過期（24 小時內有效）</p>` : ''}
    ${btn('搬過來', { kind: 'primary', block: true, disabled: !value })}
    <p class="hint">搬過來以後，舊手機會自動登出。這支手機原本的牧場（如果有）會被換掉。</p>`);
}
const S14 = [];
const f14 = (id, name, render, x = {}) => S14.push({ id, name, type: 'full', render, ...x });
const p14 = (id, name, crop, render, x = {}) => S14.push({ id, name, type: 'part', crop, render, ...x });
f14('S14-01', '第一次打開：開新牧場或輸入移轉碼', (ctx) => firstOpen(ctx));
f14('S14-02', '輸入移轉碼', (ctx) => codeInput(ctx, { value: '7KQ2-9XMB' }));
p14('S14-03', '碼錯了或過期', '#crop', (ctx) => codeInput(ctx, { value: '7KQ2-9XMP', err: true }).replace('<div class="input code-input', '<div id="crop"><div class="input code-input').replace(/(<p class="err-text">.*?<\/p>)/s, '$1</div>'));
f14('S14-04', '搬家成功：歡迎回來', (ctx) => page(ctx, '歡迎回來！', `
  <article class="card welcome"><span class="avatar">${cowFace({ breed: 'holstein' }, 46)}</span><div class="grow"><b>${RANCH.name}</b><span class="hint">${RANCH.tag}</span></div></article>
  <div class="kv"><div class="cell"><div class="k">等級</div><div class="v num">Lv ${RANCH.level}</div></div><div class="cell"><div class="k">金幣</div><div class="v num">${fmt(RANCH.coins)}</div></div><div class="cell"><div class="k">牛</div><div class="v num">10 <small>頭</small></div></div><div class="cell"><div class="k">圖鑑</div><div class="v num">10 <small>/ 24</small></div></div></div>
  <p class="hint">牧場已經搬到這支手機，舊手機已經登出。</p>${btn('進牧場', { kind: 'primary', block: true })}`, { noBack: true }));
f14('S14-05', '舊手機：牧場已經搬走', (ctx) => page(ctx, '牧場已經搬走了', `
  <article class="card" style="text-align:center"><div style="line-height:0">${cowSVG({ breed: 'holstein', pose: 'side' }, { w: 150, h: 110, pose: 'side', facing: 'right' })}</div>
  <p style="font-size:16px;font-weight:900;margin-top:6px">「${RANCH.name}」已經搬到另一支手機</p><p class="hint" style="margin-top:4px">有人在另一支手機輸入了這個牧場的移轉碼。<br>如果不是你做的，請聯絡我們。</p></article>
  ${btn('我有移轉碼', { block: true, ic: 'transfer' })}${btn('開新牧場', { kind: 'primary', block: true })}`, { noBack: true }));

// ---------------- S15 連線中與斷線 ----------------
const S15 = [];
const f15 = (id, name, render, x = {}) => S15.push({ id, name, type: 'full', render, ...x });
const p15 = (id, name, crop, render, x = {}) => S15.push({ id, name, type: 'part', crop, render, ...x });
f15('S15-01', '斷線、重連中：保留畫面、按鈕停用', (ctx) => ranchPage(ctx, { offline: true, dock: { collectDisabled: true } }));
p15('S15-02', '重新連上', '.toast', (ctx) => ranchPage(ctx, { overlays: toast('ok', '已重新連線，資料更新了') }));
f15('S15-03', '帳號失效', (ctx) => page(ctx, '這支手機的牧場資料失效了', `
  <article class="card" style="text-align:center"><div style="line-height:0">${cowSVG({ breed: 'holstein' }, { w: 110, h: 110, sil: 'dark' })}</div>
  <p class="hint" style="margin-top:6px">可能是牧場在另一支手機用了移轉碼，或伺服器重新整理過。<br>你的牧場沒有被刪除以前，都可以用移轉碼搬回來。</p></article>
  ${btn('我有移轉碼', { block: true, ic: 'transfer' })}${btn('開新牧場', { kind: 'primary', block: true })}`, { noBack: true }));
p15('S15-04', '斷線超過 60 秒：請檢查網路', '.long-off', (ctx) => ranchPage(ctx, { offline: true, dock: { collectDisabled: true }, overlays: `<div class="long-off card">${icon('offline', 28)}<div class="grow"><b>連不上伺服器，已經超過 1 分鐘</b><p class="hint">請檢查網路。連上以後會自動更新。</p></div>${btn('重試', { small: true, ic: 'refresh' })}</div>` }));

// ---------------- S16 伺服器維護、錯誤 ----------------
const ERRORS = [
  ['not_enough_coins', 'err', '金幣不夠，還差 1,210 幣'],
  ['not_enough_stock', 'err', '倉庫裡的數量不夠了，請重新選數量'],
  ['pen_full', 'warn', '牛舍滿了，先擴建或出貨'],
  ['cow_not_found', 'err', '找不到這頭牛，可能已經出貨了'],
  ['cow_not_adult', 'warn', '小牛還沒長大'],
  ['already_bred', 'warn', '這頭牛已經配過種了（每頭牛一輩子只能配種一次）'],
  ['cow_in_field', 'warn', '這頭牛在田裡工作，先叫回來'],
  ['cow_listed', 'warn', '這頭公牛在借種市場上架中，先下架'],
  ['cow_not_in_field', 'err', '這頭牛已經不在田裡了'],
  ['no_free_field', 'warn', '沒有空田，先開新田或叫回別的耕牛'],
  ['field_occupied', 'err', '這塊田已經有牛了'],
  ['field_not_found', 'err', '找不到這塊田，請重新整理'],
  ['listing_not_found / listing_gone', 'err', '這頭公牛已經被借走或下架了'],
  ['max_level', 'info', '已經是最高級了'],
  ['not_yet_available', 'info', '還沒開放，3 分後再來'],
  ['internal（500）', 'err', '伺服器出了點問題，請稍後再試'],
  ['網路失敗（重試 3 次）', 'warn', '網路不穩，請稍後再試'],
  ['其他碰不到的錯誤碼', 'err', '操作失敗，請再試一次'],
];
const S16 = [];
const f16 = (id, name, render, x = {}) => S16.push({ id, name, type: 'full', render, ...x });
const p16 = (id, name, crop, render, x = {}) => S16.push({ id, name, type: 'part', crop, render, ...x });
f16('S16-01', '伺服器維護中', (ctx) => frame(ctx.dev, { tab: null, hud: false, body: `<div class="splash"><div class="splash-title" style="top:calc(var(--H) * 0.12)"><span class="t" style="font-size:36px">維護中</span></div>
  <div class="splash-cows" style="top:calc(var(--H) * 0.12 + 70px)">${cowSVG({ breed: 'holstein' }, { w: 140, h: 140 })}<span class="tool-badge">${icon('tools', 44)}</span></div><div class="splash-ground" style="top:calc(var(--H) * 0.12 + 202px)"></div>
  <div class="splash-box" style="top:calc(var(--H) * 0.12 + 236px)"><article class="card" style="text-align:center"><b style="font-size:18px">伺服器正在維護</b>
  <p class="maint-time">${icon('clock', 18)}預計 10 月 2 日（四）03:00 恢復</p><p class="hint">維護完成後就能繼續玩。牧場的資料都保存在伺服器上。</p><div style="margin-top:12px">${btn('重新整理', { kind: 'primary', block: true, ic: 'refresh' })}</div></article></div></div>` }));
p16('S16-02', '操作時伺服器錯誤（500）', '.toast', (ctx) => ranchPage(ctx, { overlays: toast('err', '伺服器出了點問題，請稍後再試') }));
p16('S16-03', '錯誤文案總表（依錯誤碼）', '#crop', (ctx) => frame(ctx.dev, { tab: null, hud: false, content: `<div id="crop" class="err-table">${ERRORS.map(([code, k, text]) => `<div class="err-item"><code>${code}</code><div class="g-toast">${toast(k, text)}</div></div>`).join('')}</div>`, tall: true }), { tall: true });

export const S13M = { id: 'S13', name: '設定', states: S13 };
export const S14M = { id: 'S14', name: '移轉碼（新手機）', states: S14 };
export const S15M = { id: 'S15', name: '連線與斷線', states: S15 };
export const S16M = { id: 'S16', name: '維護與錯誤', states: S16 };
