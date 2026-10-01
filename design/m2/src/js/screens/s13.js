// S13 設定（含「備份牧場」：綁定 Apple／Google 帳號，D22）、S14 找回牧場、S15 連線中與斷線、S16 伺服器維護與錯誤
import { frame, btn, icon, cowSVG, cowFace, toast, fmt, dialog, badge } from '../kit.js';
import { RANCH } from '../fixtures.js';
import { ranchPage } from './s03.js';
import { GAME_NAME } from './s01.js';

const page = (ctx, title, inner, o = {}) => frame(ctx.dev, { tab: null, hud: false, content: `<div class="stack">
  <div class="page-head">${o.noBack ? '' : `<button class="icon-btn" aria-label="返回">${icon('back', 22)}</button>`}<div class="grow"><h1>${title}</h1></div></div>${inner}</div>`, overlays: o.overlays || '' });
const row = (ic, label, right = icon('chevron', 18), cls = '') => `<button class="set-row ${cls}"><span class="set-ic">${icon(ic, 22)}</span><span class="set-label">${label}</span><span class="set-right">${right}</span></button>`;
const ext = `<span class="ext">網頁 ${icon('chevron', 16)}</span>`;

// ---------- 登入按鈕（D22；企劃書 4.11） ----------
// 照官方樣式：Apple 黑底白字、Google 白底細外框，兩顆一樣大、Apple 在上，不套我們的按鈕樣式。
// 標誌不自己畫：左邊的虛線方塊是標誌的位置；實作時用 Apple／Google 官方的登入按鈕，字和標誌以官方的為準。
// Apple、Google 自己跳出來的登入視窗是系統畫面，不畫。
const SSO_NOTE = '按鈕左邊的虛線方塊是標誌的位置；實作時用 Apple／Google 官方的登入按鈕。';
const SSO_NAME = { apple: 'Apple', google: 'Google' };
const sso = (k) => `<button class="sso ${k}"><span class="sso-mark" aria-hidden="true"></span><span class="sso-text">使用 ${SSO_NAME[k]} 登入</span></button>`;
const ssoGroup = (kinds) => `<div class="sso-group">${kinds.map(sso).join('')}</div>`;
const PRIVACY = '<p class="hint sso-privacy">只用來找回牧場，不會拿你的 email 和姓名。</p>';
const busyCard = (text) => `<div class="card sso-busy"><span class="spinner"></span><span>${text}</span></div>`;
const ST_NO = badge('listed', '還沒備份'), ST_OK = badge('working', '已備份');
// 牧場卡：頭像、名字、#編號、等級，右邊可以放備份狀態
const ranchCard = (r, right = '') => `<article class="card me-card"><span class="avatar sm">${cowFace({ breed: 'holstein' }, 40)}</span><div class="grow"><b>${r.name}</b><span class="hint">${r.tag}・Lv ${r.level}</span></div>${right}</article>`;
// S13-08、S13-09 的情境：玩家在新手機先按了「開新牧場」（青草小丘農莊 #5678），後來才到設定登入、想換回舊牧場（晨光河畔牧場 #1234）
const NEW_RANCH = { name: '青草小丘農莊', tag: '#5678', level: 1 };

function settings(ctx, { backed = false, overlays = '' } = {}) {
  return page(ctx, '設定', `
    ${ranchCard(RANCH)}
    <article class="card set-group">${row('sound', '音效', `<span class="toggle on"><i></i></span>`)}</article>
    <article class="card set-group acct">${row('backup', '備份牧場<small>換手機或手機壞了都能找回</small>', `${backed ? ST_OK : ST_NO}${icon('chevron', 18)}`, 'has-status')}${row('trash', '刪除我的牧場', icon('chevron', 18), 'danger')}</article>
    <article class="card set-group">${row('shield', '隱私權政策', ext)}${row('info', '版本', '<span class="hint">1.0.0</span>')}</article>
    <p class="hint" style="text-align:center">${GAME_NAME}　・　所有帳都在伺服器計算</p>`, { overlays });
}

// 備份牧場。bound：已經綁定的帳號（'apple'、'google'）；android：Android 版（沒有 Apple 登入；綁過 Apple 才顯示 Apple 那一列）
function backupPage(ctx, { bound = [], android = false, busy = false, ranch = RANCH, overlays = '' } = {}) {
  const todo = (android ? ['google'] : ['apple', 'google']).filter((k) => !bound.includes(k));
  const intro = bound.length
    ? `<p class="bk-lead">牧場已經備份了。換手機或重裝後，用綁定的帳號登入就能找回。</p>`
    : `<p class="bk-lead">備份以後，換手機或手機壞了，都能找回牧場。</p><p class="warn-text note-line">${icon('warn', 18)}<span>沒有備份的牧場，手機壞了就找不回來。</span></p>`;
  const rows = bound.length ? `<article class="card bind-list">${bound.map((k) => `<div class="bind-row"><span class="set-ic">${icon('ok', 22)}</span><span class="set-label">${SSO_NAME[k]} 帳號<small>已綁定・2026/10/01</small></span>${btn('解除', { small: true })}</div>`).join('')}</article>` : '';
  const more = !android && bound.length === 1 && bound[0] === 'apple' ? `<p class="hint">以後可能換 Android 手機的話，再綁一個 Google 帳號。</p>` : '';
  const area = busy ? `<div class="sso-area">${busyCard('綁定中…')}</div>` : todo.length ? `<div class="sso-area">${ssoGroup(todo)}${PRIVACY}</div>` : '';
  const before = !bound.length && !busy ? `<p class="rule-line shop-rule">${icon('info', 18)}<span>之前備份過？用同一個帳號登入，就能換回舊牧場。</span></p>` : '';
  return page(ctx, '備份牧場', `${ranchCard(ranch, bound.length ? ST_OK : ST_NO)}<div class="bk-body">${intro}${rows}${more}${area}${before}</div>`, { overlays });
}
function deletePage(ctx, typed = '') {
  const ok = typed === '刪除';
  return page(ctx, '刪除我的牧場', `
    <article class="card del-card"><div class="del-pic">${cowSVG({ breed: 'holstein' }, { w: 96, h: 96 })}</div>
      <p class="del-t">刪除後不能復原</p>
      <ul class="del-list"><li>牧場「${RANCH.name}」、所有的牛、金幣、倉庫會全部刪掉。</li><li>排行榜上的紀錄也會刪掉。</li><li>綁定的 Apple／Google 帳號會解除，之後可以再綁新的牧場。</li><li>這支手機會回到第一次打開的畫面。</li></ul></article>
    <label class="field-label">請輸入「刪除」兩個字確認</label>
    <div class="input${ok ? ' filled' : ''}">${typed || '<span class="ph">刪除</span>'}${ok ? '<span class="caret"></span>' : ''}</div>
    ${btn('刪除我的牧場', { kind: 'danger', block: true, ic: 'trash', disabled: !ok })}
    ${btn('取消', { block: true })}`);
}
// 把 toast 排成一張表（局部狀態用）
const toastSheet = (ctx, list) => frame(ctx.dev, { tab: null, hud: false, content: `<div id="crop" class="g-sheet">${list.map(([k, t]) => `<div class="g-toast">${toast(k, t)}</div>`).join('')}</div>` });

const S13 = [];
const f13 = (id, name, render, x = {}) => S13.push({ id, name, type: 'full', render, ...x });
const p13 = (id, name, crop, render, x = {}) => S13.push({ id, name, type: 'part', crop, render, ...x });
f13('S13-01', '設定主頁（還沒備份）', (ctx) => settings(ctx));
f13('S13-02', '備份牧場：還沒綁定（iPhone）', (ctx) => backupPage(ctx), { note: SSO_NOTE });
f13('S13-03', '刪除牧場：說明後果、還沒輸入', (ctx) => deletePage(ctx));
f13('S13-04', '刪除完成', (ctx) => frame(ctx.dev, { tab: null, hud: false, body: `<div class="splash"><div class="splash-title"><span class="t">${GAME_NAME}</span></div>
  <div class="splash-box" style="top:calc(var(--H) * 0.2 + 100px)"><article class="card" style="text-align:center"><div style="line-height:0">${cowSVG({ breed: 'holstein' }, { w: 120, h: 120 })}</div><b style="font-size:18px">牧場已經刪除了</b><p class="hint" style="margin-top:4px">謝謝你這段時間的照顧。</p><div style="margin-top:12px">${btn('開新牧場', { kind: 'primary', block: true })}</div></article></div></div>` }));
p13('S13-05', '刪除失敗', '#crop', (ctx) => toastSheet(ctx, [['err', '刪除失敗：網路不穩，請稍後再試']]));
p13('S13-06', '刪除牧場：輸入「刪除」後按鈕才能按', '#crop', (ctx) => deletePage(ctx, '刪除').replace('<label class="field-label">', '<div id="crop"><label class="field-label">').replace(/(<button class="btn block"><span>取消<\/span><\/button>)/, '$1</div>'));
f13('S13-07', '備份牧場：已經綁定（iPhone，只綁了 Apple）', (ctx) => backupPage(ctx, { bound: ['apple'] }), { note: SSO_NOTE });
const otherRanch = `<div class="other-ranch"><span class="avatar sm">${cowFace({ breed: 'holstein' }, 40)}</span><div class="grow"><b>${RANCH.name} ${RANCH.tag}</b><span class="hint">Lv ${RANCH.level}</span></div></div>`;
f13('S13-08', '這個帳號已經備份了另一個牧場', (ctx) => backupPage(ctx, { ranch: NEW_RANCH, overlays: dialog({
  title: '這個帳號已經備份了另一個牧場',
  body: `${otherRanch}<p>一個帳號只能備份一個牧場。要換回那個牧場嗎？</p><div class="dlg-stack">${btn('換回那個牧場', { kind: 'primary', block: true })}${btn('取消', { block: true })}</div>`,
}) }), { note: SSO_NOTE });
f13('S13-09', '換回前再確認：現在的牧場會刪除', (ctx) => backupPage(ctx, { ranch: NEW_RANCH, overlays: dialog({
  title: '確定要換回嗎？',
  body: `<p class="err-text note-line danger-line">${icon('warn', 20)}<span>這支手機現在的牧場「${NEW_RANCH.name} ${NEW_RANCH.tag}」會刪除，不能復原。</span></p><p style="margin-top:8px">換回以後，這支手機會回到「${RANCH.name} ${RANCH.tag}」。</p><div class="dlg-stack">${btn('換回，並刪除現在的牧場', { kind: 'danger', block: true })}${btn('取消', { block: true })}</div>`,
}) }), { note: SSO_NOTE });
p13('S13-10', '設定主頁：已備份', '.acct', (ctx) => settings(ctx, { backed: true }));
p13('S13-11', 'Android 版：只有 Google 一顆（還沒綁定）', '.sso-area', (ctx) => backupPage(ctx, { android: true }), { note: SSO_NOTE });
p13('S13-12', '提示：綁定成功、取消登入、登入失敗、已解除', '#crop', (ctx) => toastSheet(ctx, [['ok', '備份好了！已綁定 Apple 帳號'], ['info', '已取消登入'], ['err', '登入失敗，請再試一次'], ['ok', '已解除 Apple 帳號的綁定']]));
p13('S13-13', '解除綁定的確認（唯一綁定的帳號多一句提醒）', '.dialog', (ctx) => backupPage(ctx, { bound: ['apple'], overlays: dialog({
  title: '解除 Apple 帳號的綁定？',
  body: `<p>解除以後，就不能用這個帳號找回牧場。</p><p class="warn-text" style="margin-top:6px">這是唯一綁定的帳號，解除後這個牧場就沒有備份了。</p>`,
  buttons: `${btn('取消')}${btn('解除', { kind: 'danger' })}`,
}) }));
p13('S13-14', '兩種帳號都綁了：各一列，沒有登入按鈕', '.bk-body', (ctx) => backupPage(ctx, { bound: ['apple', 'google'] }));
p13('S13-15', '綁定中…（登入視窗關掉後，等伺服器回覆）', '.sso-area', (ctx) => backupPage(ctx, { busy: true }));
p13('S13-16', 'Android 版：只綁了 Google 時，沒有 Apple 那一列也沒有 Apple 登入按鈕', '.bk-body', (ctx) => backupPage(ctx, { android: true, bound: ['google'] }));

// ---------------- S14 找回牧場（新手機或重裝後，用綁定的帳號登入） ----------------
function firstOpen(ctx) {
  return frame(ctx.dev, { tab: null, hud: false, body: `<div class="splash"><div class="splash-sun"></div><div class="splash-title"><span class="t">${GAME_NAME}</span></div>
    <div class="splash-cows">${cowSVG({ breed: 'holstein' }, { w: 150, h: 150 })}${cowSVG({ breed: 'yellow', sex: 'bull', age: 'calf', seed: 33 }, { w: 96, h: 96, facing: 'right' })}</div><div class="splash-ground"></div>
    <div class="splash-box">${btn('開新牧場', { kind: 'primary', block: true })}<div style="height:12px"></div>${btn('找回我的牧場', { block: true, ic: 'transfer' })}</div></div>` });
}
// st：''（登入按鈕）｜'busy'（登入中…）｜'none'（這個帳號沒有備份過牧場）
function recoverPage(ctx, { android = false, st = '', overlays = '' } = {}) {
  const kinds = android ? ['google'] : ['apple', 'google'];
  const area = st === 'busy' ? `<div class="sso-area">${busyCard('登入中…')}</div>`
    : st === 'none' ? `<article class="card no-ranch"><div class="empty"><div class="t1">這個帳號沒有備份過牧場</div><div class="t2">可能是用另一個帳號備份的。<br>沒有備份過的牧場找不回來，只能開新牧場。</div></div><div class="btn-row">${btn('換一個帳號')}${btn('開新牧場', { kind: 'primary' })}</div></article>`
      : `<div class="sso-area">${ssoGroup(kinds)}${android ? '<p class="hint">之前用 iPhone、只綁了 Apple 帳號？請先在 iPhone 的設定裡再綁一個 Google 帳號。</p>' : ''}${PRIVACY}</div>`;
  return page(ctx, '找回我的牧場', `
    <article class="card rec-hero"><div style="line-height:0">${cowSVG({ breed: 'holstein', pose: 'side' }, { w: 150, h: 110, pose: 'side' })}</div><p class="rec-lead">用之前備份牧場的帳號登入</p><p class="hint">登入以後，牧場就會回到這支手機。</p></article>
    ${area}`, { overlays });
}
const S14 = [];
const f14 = (id, name, render, x = {}) => S14.push({ id, name, type: 'full', render, ...x });
const p14 = (id, name, crop, render, x = {}) => S14.push({ id, name, type: 'part', crop, render, ...x });
f14('S14-01', '第一次打開：開新牧場或找回我的牧場', (ctx) => firstOpen(ctx));
f14('S14-02', '找回我的牧場（iPhone）', (ctx) => recoverPage(ctx), { note: SSO_NOTE });
p14('S14-03', '這個帳號沒有備份過牧場', '.no-ranch', (ctx) => recoverPage(ctx, { st: 'none' }));
f14('S14-04', '找回成功：歡迎回來', (ctx) => page(ctx, '歡迎回來！', `
  <article class="card welcome"><span class="avatar">${cowFace({ breed: 'holstein' }, 46)}</span><div class="grow"><b>${RANCH.name}</b><span class="hint">${RANCH.tag}</span></div></article>
  <div class="kv"><div class="cell"><div class="k">等級</div><div class="v num">Lv ${RANCH.level}</div></div><div class="cell"><div class="k">金幣</div><div class="v num">${fmt(RANCH.coins)}</div></div><div class="cell"><div class="k">牛</div><div class="v num">10 <small>頭</small></div></div><div class="cell"><div class="k">圖鑑</div><div class="v num">10 <small>/ 24</small></div></div></div>
  <p class="hint">牧場已經回到這支手機，舊手機已經登出。</p>${btn('進牧場', { kind: 'primary', block: true })}`, { noBack: true }));
f14('S14-05', '舊手機：牧場已經在另一支手機登入', (ctx) => page(ctx, '牧場已經在另一支手機登入', `
  <article class="card" style="text-align:center"><div style="line-height:0">${cowSVG({ breed: 'holstein', pose: 'side' }, { w: 150, h: 110, pose: 'side', facing: 'right' })}</div>
  <p style="font-size:16px;font-weight:900;margin-top:6px">「${RANCH.name}」現在在另一支手機上</p><p class="hint" style="margin-top:4px">一個牧場同一時間只能在一支手機上玩。<br>在這支手機再登入一次，就能拿回來。</p>
  <p class="hint" style="margin-top:8px">如果不是你做的，請先檢查那個 Apple 或 Google 帳號的安全，再登入拿回牧場。</p></article>
  ${btn('找回我的牧場', { kind: 'primary', block: true, ic: 'transfer' })}${btn('開新牧場', { block: true })}`, { noBack: true }));
p14('S14-06', '登入中…（登入視窗關掉後，等伺服器回覆）', '.sso-area', (ctx) => recoverPage(ctx, { st: 'busy' }));
p14('S14-07', 'Android 版：只有 Google 一顆，多一句提醒', '.sso-area', (ctx) => recoverPage(ctx, { android: true }), { note: SSO_NOTE });
p14('S14-08', '提示：取消登入、登入失敗', '#crop', (ctx) => toastSheet(ctx, [['info', '已取消登入'], ['err', '登入失敗，請再試一次']]));

// ---------------- S15 連線中與斷線 ----------------
const S15 = [];
const f15 = (id, name, render, x = {}) => S15.push({ id, name, type: 'full', render, ...x });
const p15 = (id, name, crop, render, x = {}) => S15.push({ id, name, type: 'part', crop, render, ...x });
f15('S15-01', '斷線、重連中：保留畫面、按鈕停用', (ctx) => ranchPage(ctx, { offline: true, dock: { collectDisabled: true } }));
p15('S15-02', '重新連上', '.toast', (ctx) => ranchPage(ctx, { overlays: toast('ok', '已重新連線，資料更新了') }));
f15('S15-03', '帳號失效', (ctx) => page(ctx, '這支手機的牧場資料失效了', `
  <article class="card" style="text-align:center"><div style="line-height:0">${cowSVG({ breed: 'holstein' }, { w: 110, h: 110, sil: 'dark' })}</div>
  <p class="hint" style="margin-top:6px">這支手機存的登入資料不能用了。<br>備份過的牧場，用備份的帳號登入就能找回來。</p></article>
  ${btn('找回我的牧場', { kind: 'primary', block: true, ic: 'transfer' })}${btn('開新牧場', { block: true })}`, { noBack: true }));
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
export const S14M = { id: 'S14', name: '找回牧場', states: S14 };
export const S15M = { id: 'S15', name: '連線與斷線', states: S15 };
export const S16M = { id: 'S16', name: '維護與錯誤', states: S16 };
