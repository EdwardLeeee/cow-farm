// S13 設定（含「備份牧場」：綁定 Apple／Google 帳號，D22）、S14 找回牧場、S15 連線中與斷線、S16 伺服器維護與錯誤
import { frame, btn, icon, cowSVG, cowFace, toast, fmt, dialog, badge, sheet } from '../kit.js';
import { RANCH } from '../fixtures.js';
import { ranchPage } from './s03.js';
import { gameName } from './s01.js';
import { t, tb, dur, LANG } from '../i18n.js';

const page = (ctx, title, inner, o = {}) => frame(ctx.dev, { tab: null, hud: false, content: `<div class="stack">
  <div class="page-head">${o.noBack ? '' : `<button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button>`}<div class="grow"><h1>${title}</h1></div></div>${inner}</div>`, overlays: o.overlays || '' });
const row = (ic, label, right = icon('chevron', 18), cls = '') => `<button class="set-row ${cls}"><span class="set-ic">${icon(ic, 22)}</span><span class="set-label">${label}</span><span class="set-right">${right}</span></button>`;
const ext = () => `<span class="ext">${t('s13.web')} ${icon('chevron', 16)}</span>`;

// ---------- 登入按鈕（D22；企劃書 4.11） ----------
// 照官方樣式：Apple 黑底白字、Google 白底細外框，兩顆一樣大、Apple 在上，不套我們的按鈕樣式。
// 標誌不自己畫：左邊的虛線方塊是標誌的位置；實作時用 Apple／Google 官方的登入按鈕，字和標誌以官方的為準。
// Apple、Google 自己跳出來的登入視窗是系統畫面，不畫。
const SSO_NOTE = '按鈕左邊的虛線方塊是標誌的位置；實作時用 Apple／Google 官方的登入按鈕。';
const SSO_NAME = { apple: 'Apple', google: 'Google' };
const sso = (k) => `<button class="sso ${k}"><span class="sso-mark" aria-hidden="true"></span><span class="sso-text">${t('s13.ssoSignIn', { name: SSO_NAME[k] })}</span></button>`;
const ssoGroup = (kinds) => `<div class="sso-group">${kinds.map(sso).join('')}</div>`;
const privacy = () => `<p class="hint sso-privacy">${t('s13.privacy')}</p>`;
const busyCard = (text) => `<div class="card sso-busy"><span class="spinner"></span><span>${text}</span></div>`;
const stNo = () => badge('listed', t('s13.notBacked')), stOk = () => badge('working', t('s13.backed'));
// 牧場卡：頭像、名字、#編號、等級，右邊可以放備份狀態
const ranchCard = (r, right = '') => `<article class="card me-card"><span class="avatar sm">${cowFace({ breed: 'holstein' }, 40)}</span><div class="grow"><b>${r.name}</b><span class="hint">${r.tag}${t('g.sep')}${t('level', { lv: r.level })}</span></div>${right}</article>`;
// S13-08、S13-09 的情境：玩家在新手機先按了「開新牧場」（青草小丘農莊 #5678），後來才到設定登入、想換回舊牧場（晨光河畔牧場 #1234）
const NEW_RANCH = { name: '青草小丘農莊', tag: '#5678', level: 1 };

function settings(ctx, { backed = false, overlays = '' } = {}) {
  return page(ctx, t('s13.title'), `
    ${ranchCard(RANCH)}
    <article class="card set-group">${row('sound', t('s13.sound'), `<span class="toggle on"><i></i></span>`)}${row('globe', t('s13.language'), `<span class="hint" data-keep>${langName()}</span>${icon('chevron', 18)}`, 'has-status')}${row('updown', t('s13.updown'), `<span class="ud-sample"><span class="up">▲${t('s13.up')}</span><span class="down">▼${t('s13.down')}</span></span>${icon('chevron', 18)}`, 'has-status')}</article>
    <article class="card set-group acct">${row('backup', `${t('s13.backup.title')}<small>${t('s13.backup.sub')}</small>`, `${backed ? stOk() : stNo()}${icon('chevron', 18)}`, 'has-status')}${row('trash', t('s13.delete'), icon('chevron', 18), 'danger')}</article>
    <article class="card set-group">${row('shield', t('s13.privacyPolicy'), ext())}${row('info', t('s13.version'), '<span class="hint">1.0.0</span>')}</article>
    <p class="hint" style="text-align:center">${t('s13.footer', { game: gameName() })}</p>`, { overlays });
}

// 備份牧場。bound：已經綁定的帳號（'apple'、'google'）；android：Android 版（沒有 Apple 登入；綁過 Apple 才顯示 Apple 那一列）
function backupPage(ctx, { bound = [], android = false, busy = false, ranch = RANCH, overlays = '' } = {}) {
  const todo = (android ? ['google'] : ['apple', 'google']).filter((k) => !bound.includes(k));
  const intro = bound.length
    ? `<p class="bk-lead">${t('s13.backup.done')}</p>`
    : `<p class="bk-lead">${t('s13.backup.lead')}</p><p class="warn-text note-line">${icon('warn', 18)}<span>${t('s13.backup.warn')}</span></p>`;
  const rows = bound.length ? `<article class="card bind-list">${bound.map((k) => `<div class="bind-row"><span class="set-ic">${icon('ok', 22)}</span><span class="set-label">${t('s13.backup.account', { name: SSO_NAME[k] })}<small>${t('s13.backup.boundOn', { date: t('date.ymd', { y: 2026, m: '10', d: '01' }) })}</small></span>${btn(t('s13.unbind'), { small: true })}</div>`).join('')}</article>` : '';
  // 只綁了 Apple：iPhone 提醒以後換 Android 要再綁 Google；Android 本來就沒有 Apple 登入，提醒找回要用 Google（缺口清單 2-4）
  const onlyApple = bound.length === 1 && bound[0] === 'apple';
  const more = onlyApple ? `<p class="hint">${t(android ? 's13.backup.addGoogleAndroid' : 's13.backup.addGoogle')}</p>` : '';
  const area = busy ? `<div class="sso-area">${busyCard(t('s13.binding'))}</div>` : todo.length ? `<div class="sso-area">${ssoGroup(todo)}${privacy()}</div>` : '';
  const before = !bound.length && !busy ? `<p class="rule-line shop-rule">${icon('info', 18)}<span>${t('s13.backup.before')}</span></p>` : '';
  return page(ctx, t('s13.backup.title'), `${ranchCard(ranch, bound.length ? stOk() : stNo())}<div class="bk-body">${intro}${rows}${more}${area}${before}</div>`, { overlays });
}
function deletePage(ctx, typed = '') {
  const word = t('s13.del.word'), ok = typed === word;
  return page(ctx, t('s13.delete'), `
    <article class="card del-card"><div class="del-pic">${cowSVG({ breed: 'holstein' }, { w: 96, h: 96 })}</div>
      <p class="del-t">${t('s13.del.title')}</p>
      <ul class="del-list"><li>${t('s13.del.item1', { name: RANCH.name })}</li><li>${t('s13.del.item2')}</li><li>${t('s13.del.item3')}</li><li>${t('s13.del.item4')}</li></ul></article>
    <label class="field-label">${t('s13.del.prompt', { word })}</label>
    <div class="input${ok ? ' filled' : ''}">${typed || `<span class="ph">${word}</span>`}${ok ? '<span class="caret"></span>' : ''}</div>
    ${btn(t('s13.delete'), { kind: 'danger', block: true, ic: 'trash', disabled: !ok })}
    ${btn(t('cancel'), { block: true })}`);
}
// 把 toast 排成一張表（局部狀態用）
const toastSheet = (ctx, list) => frame(ctx.dev, { tab: null, hud: false, content: `<div id="crop" class="g-sheet">${list.map(([k, s]) => `<div class="g-toast">${toast(k, s)}</div>`).join('')}</div>` });

const S13 = [];
const f13 = (id, name, render, x = {}) => S13.push({ id, name, type: 'full', render, ...x });
const p13 = (id, name, crop, render, x = {}) => S13.push({ id, name, type: 'part', crop, render, ...x });
f13('S13-01', '設定主頁（還沒備份）', (ctx) => settings(ctx));
f13('S13-02', '備份牧場：還沒綁定（iPhone）', (ctx) => backupPage(ctx), { note: SSO_NOTE });
f13('S13-03', '刪除牧場：說明後果、還沒輸入', (ctx) => deletePage(ctx));
f13('S13-04', '刪除完成', (ctx) => frame(ctx.dev, { tab: null, hud: false, body: `<div class="splash"><div class="splash-title"><span class="t">${gameName()}</span></div>
  <div class="splash-box" style="top:calc(var(--H) * 0.2 + 100px)"><article class="card" style="text-align:center"><div style="line-height:0">${cowSVG({ breed: 'holstein' }, { w: 120, h: 120 })}</div><b style="font-size:18px">${t('s13.deleted')}</b><p class="hint" style="margin-top:4px">${t('s13.thanks')}</p><div style="margin-top:12px">${btn(t('s14.newRanch'), { kind: 'primary', block: true })}</div></article></div></div>` }));
p13('S13-05', '刪除失敗', '#crop', (ctx) => toastSheet(ctx, [['err', t('s13.del.failed')]]));
p13('S13-06', '刪除牧場：輸入「刪除」後按鈕才能按', '#crop', (ctx) => { const c = `<button class="btn block"><span>${t('cancel')}</span></button>`; return deletePage(ctx, t('s13.del.word')).replace('<label class="field-label">', '<div id="crop"><label class="field-label">').replace(c, `${c}</div>`); });
f13('S13-07', '備份牧場：已經綁定（iPhone，只綁了 Apple）', (ctx) => backupPage(ctx, { bound: ['apple'] }), { note: SSO_NOTE });
// 頭像在載入時就畫好（跟原本一樣先佔一個 SVG 編號），字在用的時候才查字串表
const otherFace = cowFace({ breed: 'holstein' }, 40);
const otherRanch = () => `<div class="other-ranch"><span class="avatar sm">${otherFace}</span><div class="grow"><b>${RANCH.name} ${RANCH.tag}</b><span class="hint">${t('level', { lv: RANCH.level })}</span></div></div>`;
f13('S13-08', '這個帳號已經備份了另一個牧場', (ctx) => backupPage(ctx, { ranch: NEW_RANCH, overlays: dialog({
  title: t('s13.other.title'),
  body: `${otherRanch()}<p>${t('s13.other.body')}</p><div class="dlg-stack">${btn(t('s13.other.switch'), { kind: 'primary', block: true })}${btn(t('cancel'), { block: true })}</div>`,
}) }), { note: SSO_NOTE });
f13('S13-09', '換回前再確認：現在的牧場會刪除', (ctx) => backupPage(ctx, { ranch: NEW_RANCH, overlays: dialog({
  title: t('s13.switch.title'),
  body: `<p class="err-text note-line danger-line">${icon('warn', 20)}<span>${t('s13.switch.warn', { name: `${NEW_RANCH.name} ${NEW_RANCH.tag}` })}</span></p><p style="margin-top:8px">${t('s13.switch.after', { name: `${RANCH.name} ${RANCH.tag}` })}</p><div class="dlg-stack">${btn(t('s13.switch.confirm'), { kind: 'danger', block: true })}${btn(t('cancel'), { block: true })}</div>`,
}) }), { note: SSO_NOTE });
p13('S13-10', '設定主頁：已備份', '.acct', (ctx) => settings(ctx, { backed: true }));
p13('S13-11', 'Android 版：只有 Google 一顆（還沒綁定）', '.sso-area', (ctx) => backupPage(ctx, { android: true }), { note: SSO_NOTE });
p13('S13-12', '提示：綁定成功、取消登入、登入失敗、已解除', '#crop', (ctx) => toastSheet(ctx, [['ok', t('s13.toast.bound', { name: 'Apple' })], ['info', t('s13.toast.cancelled')], ['err', t('s13.toast.failed')], ['ok', t('s13.toast.unbound', { name: 'Apple' })]]));
p13('S13-13', '解除綁定的確認（唯一綁定的帳號多一句提醒）', '.dialog', (ctx) => backupPage(ctx, { bound: ['apple'], overlays: dialog({
  title: t('s13.unbindTitle', { name: 'Apple' }),
  body: `<p>${t('s13.unbindBody')}</p><p class="warn-text" style="margin-top:6px">${t('s13.unbindLast')}</p>`,
  buttons: `${btn(t('cancel'))}${btn(t('s13.unbind'), { kind: 'danger' })}`,
}) }));
p13('S13-14', '兩種帳號都綁了：各一列，沒有登入按鈕', '.bk-body', (ctx) => backupPage(ctx, { bound: ['apple', 'google'] }));
p13('S13-15', '綁定中…（登入視窗關掉後，等伺服器回覆）', '.sso-area', (ctx) => backupPage(ctx, { busy: true }));
p13('S13-16', 'Android 版：只綁了 Google 時，沒有 Apple 那一列也沒有 Apple 登入按鈕', '.bk-body', (ctx) => backupPage(ctx, { android: true, bound: ['google'] }));
p13('S13-19', 'Android 版：只綁了 Apple，提醒再綁 Google', '.bk-body', (ctx) => backupPage(ctx, { android: true, bound: ['apple'] }), { board: '只綁Apple-狀態表' });

// ---------- 語言、漲跌顏色（D25） ----------
// 選單用各自的文字寫；第一次打開跟著手機的語言（中文 → 繁中、泰文 → 泰文、其他 → 英文）
// 語言名稱不翻譯（每種語言都用自己的文字寫），所以標 data-keep；打勾的是現在的語言
const LANGS = [['繁體中文', 'zh', 'zh-Hant'], ['English', 'en', 'en'], ['ไทย', 'th', 'th']];
function langName() { return (LANGS.find((x) => x[2] === LANG) || LANGS[0])[0]; }
f13('S13-17', '語言：繁體中文、English、ไทย', (ctx) => page(ctx, t('s13.language'), `
  <article class="card set-group lang-list">${LANGS.map(([name, k, code]) => `<button class="set-row lang-opt"><span class="set-label ${k}" data-keep>${name}</span><span class="set-right">${code === (LANGS.some((x) => x[2] === LANG) ? LANG : 'zh-Hant') ? icon('ok', 24) : ''}</span></button>`).join('')}</article>
  <p class="hint">${t('s13.langHint')}</p>`));
p13('S13-18', '漲跌顏色：漲紅跌綠（繁中預設）或綠漲紅跌（英文、泰文預設）', '.sheet', (ctx) => settings(ctx, { overlays: sheet({ title: t('s13.updown'), body: `<div class="list">
  <button class="card ud-opt on"><span class="grow"><b>${t('s13.redUp')}</b><span class="hint">${t('s13.redUpHint')}</span></span><span class="ud-sample big"><span class="up">▲ ${t('s06.vsHigher', { pct: '12%' })}</span><span class="down">▼ ${t('s06.vsLower', { pct: '7%' })}</span></span><span class="pick-check static">${icon('ok', 24)}</span></button>
  <button class="card ud-opt"><span class="grow"><b>${t('s13.greenUp')}</b><span class="hint">${t('s13.greenUpHint')}</span></span><span class="ud-sample big intl"><span class="up">▲ ${t('s06.vsHigher', { pct: '12%' })}</span><span class="down">▼ ${t('s06.vsLower', { pct: '7%' })}</span></span></button></div>
  <p class="hint" style="margin-top:10px">${t('s13.udNote')}</p>` }) }));

// ---------------- S14 找回牧場（新手機或重裝後，用綁定的帳號登入） ----------------
function firstOpen(ctx) {
  return frame(ctx.dev, { tab: null, hud: false, body: `<div class="splash"><div class="splash-sun"></div><div class="splash-title"><span class="t">${gameName()}</span></div>
    <div class="splash-cows">${cowSVG({ breed: 'holstein' }, { w: 150, h: 150 })}${cowSVG({ breed: 'yellow', sex: 'bull', age: 'calf', seed: 33 }, { w: 96, h: 96, facing: 'right' })}</div><div class="splash-ground"></div>
    <div class="splash-box">${btn(t('s14.newRanch'), { kind: 'primary', block: true })}<div style="height:12px"></div>${btn(t('s14.recover'), { block: true, ic: 'transfer' })}</div></div>` });
}
// st：''（登入按鈕）｜'busy'（登入中…）｜'none'（這個帳號沒有備份過牧場）
function recoverPage(ctx, { android = false, st = '', overlays = '' } = {}) {
  const kinds = android ? ['google'] : ['apple', 'google'];
  const area = st === 'busy' ? `<div class="sso-area">${busyCard(t('s14.signingIn'))}</div>`
    : st === 'none' ? `<article class="card no-ranch"><div class="empty"><div class="t1">${t('s14.noneTitle')}</div><div class="t2">${tb('s14.noneBody')}</div></div><div class="btn-row">${btn(t('s14.otherAccount'))}${btn(t('s14.newRanch'), { kind: 'primary' })}</div></article>`
      : `<div class="sso-area">${ssoGroup(kinds)}${android ? `<p class="hint">${t('s14.androidHint')}</p>` : ''}${privacy()}</div>`;
  return page(ctx, t('s14.recover'), `
    <article class="card rec-hero"><div style="line-height:0">${cowSVG({ breed: 'holstein', pose: 'side' }, { w: 150, h: 110, pose: 'side' })}</div><p class="rec-lead">${t('s14.lead')}</p><p class="hint">${t('s14.leadHint')}</p></article>
    ${area}`, { overlays });
}
const S14 = [];
const f14 = (id, name, render, x = {}) => S14.push({ id, name, type: 'full', render, ...x });
const p14 = (id, name, crop, render, x = {}) => S14.push({ id, name, type: 'part', crop, render, ...x });
f14('S14-01', '第一次打開：開新牧場或找回我的牧場', (ctx) => firstOpen(ctx));
f14('S14-02', '找回我的牧場（iPhone）', (ctx) => recoverPage(ctx), { note: SSO_NOTE });
p14('S14-03', '這個帳號沒有備份過牧場', '.no-ranch', (ctx) => recoverPage(ctx, { st: 'none' }));
f14('S14-04', '找回成功：歡迎回來', (ctx) => page(ctx, t('s14.welcome'), `
  <article class="card welcome"><span class="avatar">${cowFace({ breed: 'holstein' }, 46)}</span><div class="grow"><b>${RANCH.name}</b><span class="hint">${RANCH.tag}</span></div></article>
  <div class="kv"><div class="cell"><div class="k">${t('s14.level')}</div><div class="v num">${t('level', { lv: RANCH.level })}</div></div><div class="cell"><div class="k">${t('s14.coins')}</div><div class="v num">${fmt(RANCH.coins)}</div></div><div class="cell"><div class="k">${t('s14.cows')}</div><div class="v num">10 <small>${t('s14.head')}</small></div></div><div class="cell"><div class="k">${t('subCodex')}</div><div class="v num">10 <small>/ 24</small></div></div></div>
  <p class="hint">${t('s14.welcomeHint')}</p>${btn(t('g.enterRanch'), { kind: 'primary', block: true })}`, { noBack: true }));
f14('S14-05', '舊手機：牧場已經在另一支手機登入', (ctx) => page(ctx, t('s14.elsewhereTitle'), `
  <article class="card" style="text-align:center"><div style="line-height:0">${cowSVG({ breed: 'holstein', pose: 'side' }, { w: 150, h: 110, pose: 'side', facing: 'right' })}</div>
  <p style="font-size:16px;font-weight:900;margin-top:6px">${t('s14.elsewhereLead', { name: RANCH.name })}</p><p class="hint" style="margin-top:4px">${tb('s14.elsewhereBody')}</p>
  <p class="hint" style="margin-top:8px">${t('s14.elsewhereSecurity')}</p></article>
  ${btn(t('s14.recover'), { kind: 'primary', block: true, ic: 'transfer' })}${btn(t('s14.newRanch'), { block: true })}`, { noBack: true }));
p14('S14-06', '登入中…（登入視窗關掉後，等伺服器回覆）', '.sso-area', (ctx) => recoverPage(ctx, { st: 'busy' }));
p14('S14-07', 'Android 版：只有 Google 一顆，多一句提醒', '.sso-area', (ctx) => recoverPage(ctx, { android: true }), { note: SSO_NOTE });
p14('S14-08', '提示：取消登入、登入失敗', '#crop', (ctx) => toastSheet(ctx, [['info', t('s13.toast.cancelled')], ['err', t('s13.toast.failed')]]));

// ---------------- S15 連線中與斷線 ----------------
const S15 = [];
const f15 = (id, name, render, x = {}) => S15.push({ id, name, type: 'full', render, ...x });
const p15 = (id, name, crop, render, x = {}) => S15.push({ id, name, type: 'part', crop, render, ...x });
f15('S15-01', '斷線、重連中：保留畫面、按鈕停用', (ctx) => ranchPage(ctx, { offline: true, dock: { collectDisabled: true } }));
p15('S15-02', '重新連上', '.toast', (ctx) => ranchPage(ctx, { overlays: toast('ok', t('s15.reconnected')) }));
f15('S15-03', '帳號失效', (ctx) => page(ctx, t('s15.invalidTitle'), `
  <article class="card" style="text-align:center"><div style="line-height:0">${cowSVG({ breed: 'holstein' }, { w: 110, h: 110, sil: 'dark' })}</div>
  <p class="hint" style="margin-top:6px">${tb('s15.invalidBody')}</p></article>
  ${btn(t('s14.recover'), { kind: 'primary', block: true, ic: 'transfer' })}${btn(t('s14.newRanch'), { block: true })}`, { noBack: true }));
p15('S15-04', '斷線超過 60 秒：請檢查網路', '.long-off', (ctx) => ranchPage(ctx, { offline: true, dock: { collectDisabled: true }, overlays: `<div class="long-off card">${icon('offline', 28)}<div class="grow"><b>${t('s15.longOffTitle', { n: 1 })}</b><p class="hint">${t('s15.longOffBody')}</p></div>${btn(t('retry'), { small: true, ic: 'refresh' })}</div>` }));

// ---------------- S16 伺服器維護、錯誤 ----------------
// 錯誤碼 → 字串表的 key（scope.md 第 7 節）。第一欄是錯誤碼（設計稿的標示，不是 app 的字）
const ERRORS = [
  ['not_enough_coins', 'err', 'notEnoughCoins', { n: 1210 }],
  ['not_enough_stock', 'err', 'err.not_enough_stock'],
  ['pen_full', 'warn', 'penFull'],
  ['cow_not_found', 'err', 'err.cow_not_found'],
  ['cow_not_adult', 'warn', 'err.cow_not_adult'],
  ['already_bred', 'warn', 'err.already_bred'],
  ['cow_in_field', 'warn', 'err.cow_in_field'],
  ['cow_listed', 'warn', 'err.cow_listed'],
  ['cow_not_in_field', 'err', 'err.cow_not_in_field'],
  ['no_free_field', 'warn', 'err.no_free_field'],
  ['field_occupied', 'err', 'err.field_occupied'],
  ['field_not_found', 'err', 'err.field_not_found'],
  ['listing_not_found / listing_gone', 'err', 'err.listing_gone'],
  ['max_level', 'info', 'err.max_level'],
  ['not_yet_available', 'info', 'err.not_yet_available', { m: 3 }],
  ['internal（500）', 'err', 'err.internal'],
  ['網路失敗（重試 3 次）', 'warn', 'networkError'],
  ['其他碰不到的錯誤碼', 'err', 'unknownError'],
];
const errText = (key, p = {}) => t(key, { ...(p.n != null ? { n: fmt(p.n) } : {}), ...(p.m != null ? { time: dur({ m: p.m }) } : {}) });
const S16 = [];
const f16 = (id, name, render, x = {}) => S16.push({ id, name, type: 'full', render, ...x });
const p16 = (id, name, crop, render, x = {}) => S16.push({ id, name, type: 'part', crop, render, ...x });
// 維護中。eta：預計恢復的那一行（缺口清單 2-3：時間過了換成 s16.late；沒有時間就不顯示）
const etaLine = (text) => `<p class="maint-time">${icon('clock', 18)}${text}</p>`;
const maint = (ctx, eta) => frame(ctx.dev, { tab: null, hud: false, body: `<div class="splash"><div class="splash-title" style="top:calc(var(--H) * 0.12)"><span class="t" style="font-size:36px">${t('s16.title')}</span></div>
  <div class="splash-cows" style="top:calc(var(--H) * 0.12 + 70px)">${cowSVG({ breed: 'holstein' }, { w: 140, h: 140 })}<span class="tool-badge">${icon('tools', 44)}</span></div><div class="splash-ground" style="top:calc(var(--H) * 0.12 + 202px)"></div>
  <div class="splash-box" style="top:calc(var(--H) * 0.12 + 236px)"><article class="card" style="text-align:center"><b style="font-size:18px">${t('s16.lead')}</b>
  ${eta}<p class="hint">${t('s16.body')}</p><div style="margin-top:12px">${btn(t('reload'), { kind: 'primary', block: true, ic: 'refresh' })}</div></article></div></div>` });
f16('S16-01', '伺服器維護中', (ctx) => maint(ctx, etaLine(t('s16.eta', { date: t('date.mdw', { m: 10, d: 2, w: t('weekday.4'), time: '03:00' }) }))));
p16('S16-02', '操作時伺服器錯誤（500）', '.toast', (ctx) => ranchPage(ctx, { overlays: toast('err', t('err.internal')) }));
p16('S16-03', '錯誤文案總表（依錯誤碼）', '#crop', (ctx) => frame(ctx.dev, { tab: null, hud: false, content: `<div id="crop" class="err-table">${ERRORS.map(([code, k, key, p]) => `<div class="err-item"><code data-note>${code}</code><div class="g-toast">${toast(k, errText(key, p))}</div></div>`).join('')}</div>`, tall: true }), { tall: true });
p16('S16-04', '維護超過預計的時間', '.splash-box', (ctx) => maint(ctx, etaLine(t('s16.late'))), { board: '預計時間-狀態表' });
p16('S16-05', '沒有預計恢復的時間', '.splash-box', (ctx) => maint(ctx, ''), { board: '預計時間-狀態表' });

export const S13M = { id: 'S13', name: '設定', states: S13 };
export const S14M = { id: 'S14', name: '找回牧場', states: S14 };
export const S15M = { id: 'S15', name: '連線與斷線', states: S15 };
export const S16M = { id: 'S16', name: '維護與錯誤', states: S16 };
