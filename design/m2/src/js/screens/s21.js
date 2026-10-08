// S21 牧場資料（D34；使用者 2026-10-03 選第 12 輪 01-B、02-B，原話見 design/artboards/round12/README.md）
// 點頂列的頭像（右下角小鉛筆）打開「牧場資料」：頭像（點了換頭像）、牧場名（點了進獨立的改名頁）、成就徽章。
// 改名第一次免費、之後每次 1,000 幣，價錢只寫在改名頁的按鈕上；頭像只能選圖鑑裡發現過的牛，換頭像不用錢。
// 成就徽章第一版只展示、沒有獎勵（清單 ceo 2026-10-03 擬）；已解鎖的彩色，還沒解鎖的灰色剪影，有計數的寫進度。
import { frame, btn, icon, fmt, cowFace, toast, sheet, nameWidth } from '../kit.js';
import { tabIcon } from '../icons.js';
import { RANCH, FOUND, COWS, STUD_LOG, WAREHOUSE, RANK, compact } from '../fixtures.js';
import { t, dateText, breedName } from '../i18n.js';
import { CODEX_ORDER, BREEDS, tierOf, MIX_LOOK } from '../../cow/breeds.js';
import { keyboard, KB_H, KB_NOTE } from './s02.js';

const RENAME_PRICE = 1000; // D34：之後每次改名 1,000 幣（使用者選 01-B）
const NEW_NAME = '小花的快樂牧場';

// 頁面框：返回鈕＋標題（跟設定頁一樣，沒有頂列；斷線時「連線中…」放標題右邊，見 S13-20）
const page = (ctx, title, inner, o = {}) => frame(ctx.dev, { tab: null, hud: false, content: `<div class="stack${o.cls ? ` ${o.cls}` : ''}">
  <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${title}</h1></div></div>${inner}</div>`, overlays: o.overlays || '', contentCls: o.contentCls || '' });

// ---------- 成就徽章（ceo 2026-10-03 的清單；狀態照假資料推：發現 10 種、草莓牛是傳說、借過別人的公牛、Lv 4…） ----------
// ic：圖示（icons.js 的名字；'tab:market' 用分頁圖示；'txt:A' 畫字）；bg：已解鎖的底色；tiers：分階段的（銅、銀、金）
const TIER_BG = ['#F2C29B', '#E3E7EE', '#FFD45E']; // 銅、銀、金（跟排行榜的獎牌同色）
const sold = WAREHOUSE.rice.reduce((s, x) => s + x.qty, 0); // 稻米累計收成（假資料：倉庫裡的就是全部收成）
const lent = STUD_LOG.filter((x) => x.dir === 'out').length;
const legend = COWS.some((c) => tierOf(BREEDS[c.breed]) === 3);
export const BADGES = [
  { key: 'firstMilk', ic: 'pail', bg: '#A9DBFF', done: { m: 9, d: 27, time: '10:05' } },
  { key: 'firstSale', ic: 'tab:market', bg: '#BDE8A6', done: { m: 9, d: 27, time: '10:21' } },
  { key: 'firstShip', ic: 'box', bg: '#FFC2B6', done: { m: 9, d: 28, time: '15:40' } },
  { key: 'gradeA', ic: 'txt:A', bg: '#FFC98A', n: 1, of: 10 },
  { key: 'newLife', ic: 'sprout', bg: '#CFEFC4', done: { m: 9, d: 29, time: '13:42' } },
  { key: 'borrow', ic: 'transfer', bg: '#FFD0DE', done: { m: 9, d: 28, time: '20:18' } },
  { key: 'popularBull', ic: 'bull', bg: '#FFD0DE', n: lent, of: 10 },
  { key: 'rice', ic: 'rice', bg: '#BDE8A6', n: sold, of: 1000 },
  { key: 'codex', ic: 'book', tiers: [5, 12, 24], n: FOUND.length, done: [{ m: 9, d: 28, time: '09:30' }] },
  { key: 'legend', ic: 'star', bg: 'linear-gradient(135deg, #FFE27A, #FFC4D6)', done: legend ? { day: 'yesterday', time: '07:30' } : null },
  { key: 'level', ic: 'txt:Lv', tiers: [10, 20], n: RANCH.level },
  { key: 'rich', ic: 'coins', tiers: [100000, 1000000], n: RANK.me.networth.value },
  { key: 'tailwind', ic: 'news', bg: '#FFE98F' },
  { key: 'weekChamp', ic: 'trophy', bg: '#FFD45E' },
  { key: 'pureBreed', ic: 'leaf', bg: '#CFEFC4' }, // 15–18：D35 的新玩法做好以後才有（v0.3），先畫還沒解鎖的樣子
  { key: 'healer', ic: 'heart', bg: '#FFD0DE' },
  { key: 'clean', ic: 'sparkle', bg: '#D5EBFF' },
  { key: 'trucks', ic: 'truck', bg: '#FFC2B6' },
];
// 分階段的：解鎖到第幾階（0＝還沒）；顏色：三階是銅、銀、金，兩階是銀、金
const tierAt = (b) => (b.tiers ? b.tiers.filter((x) => b.n >= x).length : 0);
const tierBg = (b, i) => TIER_BG[b.tiers.length === 2 ? i + 1 : i];
export const unlocked = (b) => (b.tiers ? tierAt(b) > 0 : !!b.done);
// 名稱：分階段的照現在的階段（還沒解鎖的寫第一階）
const bName = (b) => (b.tiers ? t(`ach.${b.key}.name.${Math.max(1, tierAt(b))}`) : t(`ach.${b.key}.name`));
// 進度：有計數、還沒滿的寫「n / 目標」（分階段的寫下一階的目標）
function progress(b) {
  if (b.tiers) { const next = b.tiers[tierAt(b)]; return next ? [b.n, next] : null; }
  return b.of && !b.done ? [b.n, b.of] : null;
}
function badgeArt(b, size = 52) {
  const on = unlocked(b);
  const bg = b.tiers ? tierBg(b, Math.max(0, tierAt(b) - 1)) : b.bg;
  const s = Math.round(size * 0.52);
  const art = b.ic.startsWith('tab:') ? tabIcon(b.ic.slice(4), true) : b.ic.startsWith('txt:') ? `<b class="ach-txt" style="font-size:${Math.round(size * (b.ic.length > 5 ? 0.34 : 0.44))}px">${b.ic.slice(4)}</b>` : icon(b.ic, s);
  return `<span class="ach-b${on ? '' : ' off'}" style="width:${size}px;height:${size}px${on ? `;background:${bg}` : ''}">${art}</span>`;
}
// 格子裡的進度用短的寫法（一萬以上寫「5.8萬」「58.9K」），點開的詳細寫完整的數字
const progText = (p, short = false) => (short ? `${compact(p[0])} / ${compact(p[1])}` : `${fmt(p[0])} / ${fmt(p[1])}`);
function badgeCell(b) {
  const p = progress(b);
  return `<button class="ach${unlocked(b) ? '' : ' off'}">${badgeArt(b)}<span class="ach-name">${bName(b)}</span>${p ? `<span class="ach-p num">${progText(p, true)}</span>` : ''}</button>`;
}
const achCard = () => `<article class="card ach-card"><div class="card-head"><span class="card-title">${icon('medal', 16)}${t('s21.badges')}</span><span class="card-sub">${t('s21.badgeCount', { n: BADGES.filter(unlocked).length, total: BADGES.length })}</span></div>
  <div class="ach-grid">${BADGES.map(badgeCell).join('')}</div></article>`;

// 點一個徽章：名稱、條件、解鎖日期（或還沒解鎖、進度）；分階段的列出每一階
function badgeDetail(b) {
  let status;
  if (b.tiers) {
    const at = tierAt(b);
    status = `<div class="ach-tiers">${b.tiers.map((goal, i) => {
      const ok = i < at;
      return `<div class="ach-tier${ok ? ' ok' : ''}"><span class="ach-tier-dot"${ok ? ` style="background:${tierBg(b, i)}"` : ''}></span><span class="grow"><b>${t(`ach.${b.key}.name.${i + 1}`)}</b><span class="hint">${t(`ach.${b.key}.cond.${i + 1}`)}</span></span>${ok ? `<span class="ach-when">${icon('ok', 18)}${dateText(b.done[i])}</span>` : `<span class="num ach-when">${progText([b.n, goal])}</span>`}</div>`;
    }).join('')}</div>`;
  } else if (b.done) {
    status = `<p class="ach-date">${icon('ok', 20)}<span>${t('s21.badgeDate', { date: dateText(b.done) })}</span></p>`;
  } else {
    const p = progress(b);
    status = `<p class="ach-date off">${icon('lock', 18)}<span>${t('s21.badgeLocked')}</span></p>${p ? `<div class="ach-bar"><div class="bar thick yellow"><i style="width:${Math.round((p[0] / p[1]) * 100)}%"></i></div><span class="num">${progText(p)}</span></div>` : ''}`;
  }
  const cond = b.tiers ? '' : `<p class="ach-cond">${t(`ach.${b.key}.cond`)}</p>`;
  return sheet({ cls: 'ach-sheet', body: `<div class="ach-detail">${badgeArt(b, 88)}<b class="ach-title">${bName(b)}</b>${cond}${status}</div>${btn(t('g.close'), { block: true })}` });
}

// ---------- 牧場資料頁 ----------
// face：頭像（品種）；name：牧場名
function profileCard({ face = 'holstein', name = RANCH.name } = {}) {
  return `<article class="card prof-card">
    <button class="prof-av" aria-label="${t('s21.avatarTitle')}"><span class="avatar xl">${cowFace({ breed: face }, 74)}</span><i class="hud-edit big" aria-hidden="true">${icon('pencil', 15)}</i></button>
    <div class="grow"><button class="prof-name"><b>${name}</b><span class="prof-name-ic">${icon('pencil', 14)}${icon('chevron', 16)}</span></button>
      <span class="hint">${RANCH.tag}${t('g.sep')}${t('level', { lv: RANCH.level })}</span></div>
  </article>`;
}
const profilePage = (ctx, o = {}) => page(ctx, t('s21.title'), `${profileCard(o)}${achCard()}`, { overlays: o.overlays });

// ---------- 換頭像（只能選圖鑑裡發現過的；不用錢，所以不寫價錢） ----------
// 「其他」一排（ceo 2026-10-03，PR 2）：雜種牛（之後的特殊牛也放這排），規則跟 24 種一樣：沒發現是剪影加鎖。頭像用乳牛體型的臉
function avatarSheet({ sel = 'jersey', tapped = '', mixFound = false } = {}) {
  const cell = (k, lock) => {
    const on = k === sel;
    return `<button class="av-cell${on ? ' on' : ''}${lock ? ' locked' : ''}${k === tapped ? ' tapped' : ''}" aria-label="${lock ? t('g.unknownBreed') : breedName(k)}"><span class="av-circle">${cowFace({ breed: k }, 48)}</span>${lock ? `<span class="av-lock">${icon('lock', 12)}</span>` : ''}${on ? `<span class="pick-check">${icon('ok', 20)}</span>` : ''}</button>`;
  };
  const cells = CODEX_ORDER.map((k) => cell(k, !FOUND.includes(k))).join('');
  const other = `<h4 class="av-sub">${t('s09.other')}</h4><div class="av-grid other">${cell(MIX_LOOK.dairy, !mixFound)}</div>`;
  const foot = tapped
    ? `<p class="warn-text av-count">${icon('lock', 14)}<span>${t('s21.avatarLocked', { name: breedName(tapped) })}</span></p>`
    : `<p class="hint av-count">${icon('lock', 14)}<span>${t('s21.avatarCount', { n: FOUND.length, total: CODEX_ORDER.length })}</span></p>`;
  return sheet({ cls: 'av-sheet', title: t('s21.avatarTitle'), body: `
    <div class="av-preview"><span class="av-circle now">${cowFace({ breed: 'holstein' }, 48)}</span>${icon('chevron', 18)}<span class="av-circle">${cowFace({ breed: sel }, 48)}</span><div class="grow"><b>${breedName(sel)}</b><span class="hint">${t('s21.avatarFoundOnly')}</span></div></div>
    <div class="av-grid">${cells}</div>${other}${foot}
    <div class="btn-row">${btn(t('cancel'))}${btn(t('s21.avatarUse'), { kind: 'primary' })}</div>` });
}

// ---------- 改名頁（獨立一頁；名字的規則照 D23，跟 S02 一樣） ----------
// paid：第二次以後（按鈕寫價錢）；short：錢不夠時還差多少；err：名字不能用；kb：鍵盤開著
function renamePage(ctx, { value = NEW_NAME, paid = false, short = 0, err = '', kb = false } = {}) {
  const w = nameWidth(value), ok = !err && !short && w >= 2 && w <= 16;
  const label = paid ? t('s21.renamePaid', { price: fmt(RENAME_PRICE) }) : t('s21.renameFree');
  const inner = `<div class="namer">
    <div class="card name-card">
      <div class="input name-input${err ? ' err' : ''} filled${kb ? ' focus' : ''}"><span class="nv">${value}</span>${kb ? '<span class="caret"></span>' : ''}</div>
      <div class="name-meta"><span class="${err ? 'err-text' : 'hint'}">${err || t('s02.widthRule')}</span><span class="num name-count${w > 16 ? ' over' : ''}">${w} / 16</span></div>
      ${btn(t('s02.suggest'), { ic: 'sparkle', block: true, cls: 'idea-btn' })}
    </div>
    ${short ? `<p class="warn-text rn-warn">${icon('warn', 18)}<span>${t('notEnoughCoins', { n: fmt(short) })}</span></p>` : ''}
    ${btn(label, { kind: 'primary', block: true, disabled: !ok })}
  </div>`;
  const out = page(ctx, t('s21.renameTitle'), inner, { contentCls: kb ? 'with-kb' : '', overlays: kb ? keyboard(ctx.dev.w) : '' });
  return kb ? out.replace('<div class="phone', `<div style="--kb-h:${KB_H[ctx.dev.w] || 292}px" class="phone`) : out;
}

const S = [];
const full = (id, name, render, x = {}) => S.push({ id, name, type: 'full', render, ...x });
const part = (id, name, crop, render, x = {}) => S.push({ id, name, type: 'part', crop, render, ...x });

full('S21-01', '牧場資料：頭像、牧場名、成就徽章（長頁）', (ctx) => profilePage(ctx), { tall: true });
full('S21-02', '換頭像：只能選圖鑑裡發現過的（選了娟珊）', (ctx) => profilePage(ctx, { overlays: avatarSheet() }));
part('S21-03', '換頭像：點了還沒發現的牛', '.sheet', (ctx) => profilePage(ctx, { overlays: avatarSheet({ tapped: 'starry' }) }));
full('S21-04', '改名：第一次（改名（免費））', (ctx) => renamePage(ctx));
full('S21-05', '改名：打字中（鍵盤開著）', (ctx) => renamePage(ctx, { value: '小花的快樂', kb: true }), { note: KB_NOTE });
part('S21-06', '改名：第二次以後（改名（1,000 幣））', '.namer', (ctx) => renamePage(ctx, { paid: true }));
part('S21-07', '改名：金幣不夠', '.namer', (ctx) => renamePage(ctx, { paid: true, short: RENAME_PRICE - 320 }));
part('S21-08', '改名：名字不能用（規則同 S02-05）', '.namer', (ctx) => renamePage(ctx, { value: '小花牧場🐮', err: t('s02.errEmoji') }));
full('S21-09', '改名好了：回到牧場資料，提示下次改名的價錢', (ctx) => profilePage(ctx, { name: NEW_NAME, overlays: toast('ok', t('s21.renamedFirst', { price: fmt(RENAME_PRICE) })) }));
full('S21-10', '頭像換好了', (ctx) => profilePage(ctx, { face: 'jersey', overlays: toast('ok', t('s21.avatarDone')) }));
part('S21-11', '徽章：已解鎖（名稱、條件、解鎖日期）', '.sheet', (ctx) => profilePage(ctx, { overlays: badgeDetail(BADGES[9]) }));
part('S21-12', '徽章：還沒解鎖（條件、進度）', '.sheet', (ctx) => profilePage(ctx, { overlays: badgeDetail(BADGES[6]) }));
part('S21-13', '徽章：分階段（圖鑑新手、達人、大師）', '.sheet', (ctx) => profilePage(ctx, { overlays: badgeDetail(BADGES[8]) }));

export default { id: 'S21', name: '牧場資料', states: S };
