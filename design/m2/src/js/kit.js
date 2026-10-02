// M2 共用元件：回傳 HTML 字串。外觀在 css/kit.css。
import { icon, tabIcon } from './icons.js';
import { drawCow, SIL_DEFS } from '../cow/render.js';
import { BREEDS, USE_NAME, TIER_NAME, tierOf } from '../cow/breeds.js';
import { RANCH, xpPct, fmt, compact } from './fixtures.js';
import { t, tierName, useName, sexName, cowName } from './i18n.js';
import { nameWidth } from './namewidth.js';

// ---------- 裝置 ----------
export const DEVICES = {
  430: { w: 430, h: 932, top: 59, bottom: 34, kind: 'island' },
  390: { w: 390, h: 844, top: 47, bottom: 34, kind: 'notch' },
  360: { w: 360, h: 800, top: 28, bottom: 24, kind: 'android' },
  320: { w: 320, h: 568, top: 20, bottom: 0, kind: 'classic' },
};
export function applyDevice(w) {
  const d = DEVICES[w] || DEVICES[390];
  const r = document.documentElement.style;
  r.setProperty('--W', `${d.w}px`); r.setProperty('--H', `${d.h}px`);
  r.setProperty('--safe-top', `${d.top}px`); r.setProperty('--safe-bottom', `${d.bottom}px`);
  return d;
}

// 大標題（開場的遊戲名、維護中…，.splash-title .t）一行放不下就整個等比例縮小到放得下（ceo 2026-10-02）：
// 字、外框、陰影、左右內距一起縮，上緣不動、左右置中，跟 app 的 FittedBox(fit: BoxFit.scaleDown) 一樣（cow-app #61）。
// 繁中放得下，什麼都不改。畫完、字型載好之後才量（main.js）。
export function fitTitles(root) {
  let n = 0;
  root.querySelectorAll('.splash-title').forEach((box) => {
    const el = box.querySelector('.t');
    if (!el) return;
    const b = box.getBoundingClientRect(), r = el.getBoundingClientRect();
    if (r.width <= b.width + 0.5) return;
    const k = b.width / r.width, dx = b.left + b.width / 2 - (r.left + r.width / 2);
    el.style.transformOrigin = '50% 0';
    el.style.transform = `translateX(${dx}px) scale(${k})`;
    n++;
  });
  return n;
}

// 牛的大圖（S04，200×150、正面）左上角的來源標籤不能蓋到牛頭（ceo 2026-10-02）：
// 24 種牛（公母、成年小牛）量過，牛頭最靠左的地方離牛圖左緣：一行標籤的高度內 42 px、兩行的高度內 38 px。
// 1. 一行：右緣最多到「牛圖左緣 + 42 - 6」，放得下就不動（繁中 430、390 都放得下）。
// 2. 放不下：在「來源：」後面換行（第一行「來源：」，第二行是值，不從詞的中間斷），右緣最多到「牛圖左緣 + 38 - 6」。
// 3. 還是放不下：改放到圖的下面，一行、靠左。
export const HERO_HEAD = { one: 42, two: 38, gap: 6 };
export function fitOriginTags(root) {
  let n = 0;
  const pre = t('origin', { v: '\u0001' }).split('\u0001')[0]; // 「來源：」「From: 」「ที่มา: 」
  root.querySelectorAll('.hero').forEach((hero) => {
    const tag = hero.querySelector('.origin-tag'), pic = hero.querySelector(':scope > svg');
    if (!tag || !pic) return;
    const pl = pic.getBoundingClientRect().left, text = tag.textContent;
    if (tag.getBoundingClientRect().right <= pl + HERO_HEAD.one - HERO_HEAD.gap + 0.5) return;
    n++;
    if (pre && text.startsWith(pre) && text.length > pre.length) {
      tag.replaceChildren(pre.trim(), document.createElement('br'), text.slice(pre.length));
      if (tag.getBoundingClientRect().right <= pl + HERO_HEAD.two - HERO_HEAD.gap + 0.5) return;
      tag.replaceChildren(text);
    }
    tag.classList.add('below');
  });
  return n;
}

// 牧場第一次打開的滑動提示（S03-14）最寬到「畫面寬 − 32」；放不下一行（英文的窄手機）就把字換行、置中，
// 提示的寬度就是「畫面寬 − 32」（跟 app 一樣，ceo 2026-10-02）。繁中放得下，不變。
export function fitSwipeHint(root) {
  const h = root.querySelector('.swipe-hint'), ph = root.querySelector('.phone');
  if (!h || !ph) return 0;
  const max = ph.getBoundingClientRect().width - 32;
  if (h.getBoundingClientRect().width <= max + 0.5) return 0;
  h.style.width = `${max}px`; h.style.whiteSpace = 'normal';
  const txt = [...h.children].find((e) => e.tagName === 'SPAN' && !e.classList.contains('sh-arrow'));
  if (txt) { txt.style.flex = '1 1 auto'; txt.style.minWidth = '0'; txt.style.textAlign = 'center'; }
  return 1;
}

// 牧場面板小卡的一行（.mini-line）不換行；真的放不下（例：泰文 360 的最大數字）就把左邊那組（圖示、名稱、數字、單位）
// 整組靠左縮小到放得下，右邊的欄位不動（跟 app 的 FittedBox(scaleDown) 一樣，ceo 2026-10-02）。
// 超出 3 px 以內不動：核准的繁中 390「S03-09 數字最大（量測用）」那一行本來就超出 3 px，不能讓核准的圖變了。
export function fitMiniLines(root) {
  let n = 0;
  root.querySelectorAll('.mini-line').forEach((line) => {
    if (line.scrollWidth <= line.clientWidth + 3.5) return;
    const right = line.querySelector(':scope > .r');
    const g = document.createElement('span');
    g.className = 'ml-fit';
    [...line.childNodes].filter((c) => c !== right).forEach((c) => g.appendChild(c));
    line.insertBefore(g, right);
    const gap = parseFloat(getComputedStyle(line).columnGap) || 0;
    const avail = line.clientWidth - (right ? right.getBoundingClientRect().width + gap : 0);
    g.style.zoom = String(Math.floor((avail / g.getBoundingClientRect().width) * 1000) / 1000);
    n++;
  });
  return n;
}

// 牧場點牛的小名片（.cow-pop）平常在頭頂上方 14、尖角朝下；上面放不下（名片上緣會碰到頂列：頂列下緣再留 6）
// 就放到牛的下面（腳下 14）、尖角朝上（2026-10-02 草稿，cow-app #70）。前排的牛放得下，不變。
export function placeCowPop(root) {
  let n = 0;
  const hud = root.querySelector('.hud');
  if (!hud) return 0;
  const limit = hud.getBoundingClientRect().bottom + 6;
  root.querySelectorAll('.cow-pop[data-foot]').forEach((p) => {
    // 名片被擋在畫面裡（靠右的牛）時，尖角跟著牛頭移動；沒被擋住時本來就對準（左 34 px），不改
    const tip = Math.max(18, Math.min(p.offsetWidth - 36, +p.dataset.hx - p.offsetLeft - 9));
    if (Math.abs(tip - 34) > 0.5) { p.style.setProperty('--tip', `${tip}px`); n++; }
    if (p.hasAttribute('data-noflip') || p.getBoundingClientRect().top >= limit - 0.5) return;
    p.style.top = `${+p.dataset.foot + 14}px`; p.style.transform = 'none'; p.classList.add('below');
    n++;
  });
  return n;
}

// 開場（S01）的版本號一律在框的下面（ceo 2026-10-02，跟 app #61 一樣）：平常在最下面（安全區上面 12 px）；
// 框太高、版本號會被蓋住時，接在框下面 12 px，整頁變長、可以往下捲，多出來的部分是草地。
export function placeVersion(root) {
  const sp = root.querySelector('.splash'), box = sp && sp.querySelector('.splash-box'), ver = sp && sp.querySelector('.splash-ver');
  if (!box || !ver) return 0;
  const s = sp.getBoundingClientRect(), b = box.getBoundingClientRect(), v = ver.getBoundingClientRect();
  if (v.top >= b.bottom + 12 - 0.5) return 0;
  const top = b.bottom + 12 - s.top, safeBottom = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--safe-bottom')) || 0;
  const extra = top + v.height + 12 + safeBottom - s.height; // 整頁比畫面長多少
  ver.style.top = `${top}px`; ver.style.bottom = 'auto';
  if (extra > 0) {
    sp.style.overflowX = 'hidden'; sp.style.overflowY = 'auto'; sp.dataset.scroll = ''; // 量測把它當捲動區
    // 草地一直鋪到整頁的最下面；花草圖（原本固定 400 高）剛好切在整頁的底，不多出可以捲的空白
    const g = sp.querySelector('.splash-ground'); if (g) g.style.bottom = `${-extra}px`;
    const d = sp.querySelector('.splash-deco');
    if (d) { d.setAttribute('preserveAspectRatio', 'xMidYMin slice'); d.style.height = `${s.height + extra - (d.getBoundingClientRect().top - s.top)}px`; }
  }
  return 1;
}

const SB_ICONS = (c = '#111114') => `
<svg width="18" height="12" viewBox="0 0 18 12" aria-hidden="true"><g fill="${c}"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></g></svg>
<svg width="16" height="12" viewBox="0 0 16 12" aria-hidden="true"><g fill="none" stroke="${c}" stroke-width="2" stroke-linecap="round"><path d="M1.5 4.2a9.5 9.5 0 0 1 13 0"/><path d="M4.2 7a5.6 5.6 0 0 1 7.6 0"/></g><circle cx="8" cy="10" r="1.6" fill="${c}"/></svg>
<svg width="27" height="13" viewBox="0 0 27 13" aria-hidden="true"><rect x="0.8" y="0.8" width="22.4" height="11.4" rx="3.4" fill="none" stroke="${c}" stroke-opacity="0.45" stroke-width="1.2"/><rect x="2.6" y="2.6" width="18.8" height="7.8" rx="2" fill="${c}"/><path d="M24.6 4.4v4.2a2.1 2.1 0 0 0 0-4.2z" fill="${c}" fill-opacity="0.5"/></svg>`;

export function chrome(dev, { dark = false } = {}) {
  const c = dark ? '#FFFFFF' : '#111114';
  return `<div class="sim-statusbar ${dev.kind}${dark ? ' dark' : ''}" aria-hidden="true"><span class="sb-time">9:41</span><span class="sb-icons">${SB_ICONS(c)}</span></div>
  ${dev.bottom ? `<div class="sim-home-indicator${dev.kind === 'android' ? ' android' : ''}${dark ? ' dark' : ''}" aria-hidden="true"></div>` : ''}`;
}

// ---------- 牛的圖 ----------
let uid = 0;
// 把牛畫進 w×h 的框：底部對齊、水平置中。回傳 <svg>
// sil：'dark' 深色剪影（圖鑑的全身剪影）、true／'light' 淺色剪影加「？」（還沒發現的品種，小圖用）
const SIL_LIGHT = `<filter id="silL" x="-10%" y="-10%" width="120%" height="120%"><feFlood flood-color="#C2B3A6"/><feComposite in2="SourceAlpha" operator="in"/></filter>`;
export function cowSVG(entry, { w = 80, h = 80, pose = 'front', facing = 'left', sil = false, pad = 4, cls = '' } = {}) {
  const e = { ...entry, pose };
  const r0 = drawCow(e, { scale: 1, facing: 'left' });
  const x0 = r0.bbox.x0 * r0.scale, x1 = r0.bbox.x1 * r0.scale, ch = r0.height;
  const k = Math.min((w - pad * 2) / (x1 - x0), (h - pad * 2) / ch);
  const cx = w / 2 - (facing === 'right' ? -(x0 + x1) / 2 : (x0 + x1) / 2) * k;
  const id = `cw${uid++}`;
  const r = drawCow(e, { x: cx, y: h - pad, scale: k, facing, id, sil: !!sil });
  if (sil && sil !== 'dark') {
    const q = `<text x="${w / 2}" y="${h * 0.62}" text-anchor="middle" font-family="Noto Sans CJK TC" font-weight="900" font-size="${Math.round(h * 0.42)}" fill="#FFFFFF" stroke="#8A6F60" stroke-width="${Math.max(1.5, h * 0.03)}" paint-order="stroke">？</text>`;
    return `<svg class="${cls}" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" aria-hidden="true"><defs>${SIL_LIGHT}</defs>${r.svg.replace('url(#sil)', 'url(#silL)')}${q}</svg>`;
  }
  return `<svg class="${cls}" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" aria-hidden="true">${sil ? `<defs>${SIL_DEFS}</defs>` : ''}${r.svg}</svg>`;
}
// 只取臉（頭像）
export function cowFace(entry, size = 46) {
  const id = `cf${uid++}`;
  const r = drawCow({ ...entry, pose: 'front' }, { id });
  const f = r.face;
  return `<svg viewBox="${f.cx - f.r} ${f.cy - f.r} ${f.r * 2} ${f.r * 2}" width="${size}" height="${size}" aria-hidden="true">${r.svg}</svg>`;
}

// ---------- 頂列、分頁 ----------
// 金幣：一百萬以上寫成「萬」；窄手機（寬度小於 390）十萬以上就寫成「萬」
// dot：齒輪上的小點（還沒備份牧場、也還沒打開過「備份牧場」頁；企劃書 4.11）
// 名字的顯示寬度（D23）：中文等全形字算 2，英文字母、數字、泰文字算 1
// 名字的顯示寬度（D23）：算法在 namewidth.js，伺服器、app、i18ncheck 都用同一套
export { nameWidth };
export function hud({ ranch = RANCH, coins, level, xp, gear = true, w = 390, dot = false } = {}) {
  const c = coins ?? ranch.coins, lv = level ?? ranch.level, x = xp ?? xpPct(ranch);
  const coinText = compact(c, w < 390 ? 100000 : 1000000);
  return `<header class="hud">
    <div class="profile">
      <div class="avatar">${cowFace({ breed: 'holstein' }, 46)}</div>
      <div class="profile-text">
        <div class="farm-name${nameWidth(ranch.name) > 12 ? ' long' : ''}" data-oneline>${ranch.name}</div>
        <div class="farm-level"><span class="lv num">${t('level', { lv })}</span><span class="xp" aria-label="${t('hud.xp', { pct: x })}"><i style="width:${x}%"></i></span></div>
      </div>
    </div>
    <div class="coins"><span class="coin-icon">${icon('coin', 34)}</span><span class="num num-coins">${coinText}</span></div>
    ${gear ? (dot ? `<button class="gear has-dot" aria-label="${t('hud.settingsNotBacked')}">${icon('gear', 24)}<i class="gear-dot"></i></button>` : `<button class="gear" aria-label="${t('hud.settings')}">${icon('gear', 24)}</button>`) : ''}
  </header>`;
}
// 分頁：label 用 strings.dart 的 key（tabRanch…tabRecords）
export const TABS = [
  { key: 'ranch', lk: 'tabRanch' }, { key: 'market', lk: 'tabMarket' }, { key: 'fields', lk: 'tabFields' },
  { key: 'breed', lk: 'tabBreed' }, { key: 'shop', lk: 'tabShop' }, { key: 'records', lk: 'tabRecords' },
];
export function tabbar(active) {
  return `<nav class="tabbar">${TABS.map((tb) => `<button class="tab${tb.key === active ? ' active' : ''}" ${tb.key === active ? 'aria-current="page"' : ''}>
    <span class="tab-icon">${tabIcon(tb.key, tb.key === active)}</span><span class="tab-label">${t(tb.lk)}</span></button>`).join('')}</nav>`;
}
export function seg(items, on, { small = false, cls = '' } = {}) {
  return `<div class="seg${small ? ' small' : ''} ${cls}">${items.map((it, i) => {
    const o = typeof it === 'string' ? { label: it } : it;
    return `<button class="${i === on ? 'on' : ''}"${o.disabled ? ' disabled' : ''}>${o.lock ? icon('lock', 14) : ''}${o.label}</button>`;
  }).join('')}</div>`;
}

// ---------- 版面 ----------
// opts：tab（分頁 key 或 null）、hud（true／false／hud 參數）、content、scene（整頁背景的 HTML）、overlays、cls、offline、dark
export function frame(dev, o = {}) {
  const hasTab = o.tab !== null && o.tab !== undefined;
  const hasHud = o.hud !== false;
  const cls = ['phone', o.cls || '', hasTab ? '' : 'no-tab', hasHud ? '' : 'no-hud', o.tall ? 'tall' : ''].filter(Boolean).join(' ');
  return `<div class="${cls}">
    ${o.scene ? `<div class="scene">${o.scene}</div>` : `<div class="page-bg"${o.bg ? ` style="background:${o.bg}"` : ''}></div>`}
    ${o.content !== undefined ? `<main class="content${o.contentCls ? ' ' + o.contentCls : ''}">${o.content}</main>` : ''}
    ${o.body || ''}
    ${hasHud ? hud({ ...(typeof o.hud === 'object' ? o.hud : {}), w: dev.w }) : ''}
    ${o.offline ? `<div class="hud-offline">${icon('offline', 20)}<span>${t('connecting')}</span></div>` : ''}
    ${hasTab ? tabbar(o.tab) : ''}
    <div class="overlays">${o.overlays || ''}</div>
    ${chrome(dev, { dark: !!o.dark })}
  </div>`;
}

// ---------- 小元件 ----------
export function btn(label, { kind = '', small = false, block = false, disabled = false, busy = false, ic = '', cls = '', sub = '' } = {}) {
  const c = ['btn', kind, small ? 'small' : '', block ? 'block' : '', busy ? 'busy' : '', cls].filter(Boolean).join(' ');
  const inner = busy ? `<span class="spinner"></span><span>${label}</span>` : `${ic ? icon(ic, small ? 18 : 22) : ''}<span>${label}</span>${sub ? `<span class="sub">${sub}</span>` : ''}`;
  return `<button class="${c}"${disabled || busy ? ' disabled' : ''}>${inner}</button>`;
}
export const badge = (kind, text) => `<span class="badge ${kind}">${text}</span>`;
export const tierChip = (n) => `<span class="tier tier-${n}">${n === 3 ? icon('sparkle', 12) : ''}${tierName(n)}</span>`;
export function useChip(use) {
  const ic = use === 'dairy' ? icon('milk', 16) : use === 'draft' ? icon('rice', 16) : icon('beef', 16);
  return `<span class="use">${ic}${useName(use)}</span>`;
}
export const sexText = (sex) => sexName(sex);
export function bar(p, { color = '', thick = false, label = '' } = {}) {
  const v = Math.max(0, Math.min(100, p));
  return `<div class="bar ${color}${thick ? ' thick' : ''}${v >= 100 ? ' full' : ''}"${label ? ` aria-label="${label}"` : ''}><i style="width:${v}%"></i></div>`;
}
export function toast(kind, text, { style = '' } = {}) {
  const ic = { ok: 'ok', err: 'err', warn: 'warn', info: 'info' }[kind];
  return `<div class="toast ${kind}"${style ? ` style="${style}"` : ''}><span class="t-icon">${icon(ic, 22)}</span><span class="t-text">${text}</span></div>`;
}
export function dialog({ title = '', body = '', buttons = '', cls = '', style = '' } = {}) {
  return `<div class="backdrop"></div><section class="dialog ${cls}" role="dialog"${style ? ` style="${style}"` : ''}>${title ? `<h2>${title}</h2>` : ''}<div class="body">${body}</div>${buttons ? `<div class="btn-row">${buttons}</div>` : ''}</section>`;
}
export function sheet({ title = '', body = '', cls = '' } = {}) {
  return `<div class="backdrop"></div><section class="sheet ${cls}" role="dialog"><div class="grab"></div>${title ? `<h2>${title}</h2>` : ''}${body}</section>`;
}
export function empty({ pic = '', t1 = '', t2 = '', action = '' } = {}) {
  return `<div class="empty">${pic ? `<div class="pic">${pic}</div>` : ''}${t1 ? `<div class="t1">${t1}</div>` : ''}${t2 ? `<div class="t2">${t2}</div>` : ''}${action}</div>`;
}
export function cowRow(c, { right = '', meta = '', chips = '', dim = false, pic = true, extra = '', cls = '' } = {}) {
  const b = BREEDS[c.breed];
  return `<article class="card cow-row${dim ? ' dim' : ''} ${cls}">
    ${pic ? `<div class="pic">${cowSVG({ breed: c.breed, sex: c.sex, age: c.age === 'old' ? 'adult' : c.age, seed: c.seed }, { w: 60, h: 60, pad: 3 })}</div>` : ''}
    <div class="info"><div class="name">${cowName(c.breed, c.id)}</div>${chips ? `<div class="chips" style="margin-top:3px">${chips}</div>` : ''}${meta ? `<div class="meta">${meta}</div>` : ''}${extra}</div>
    ${right ? `<div class="right">${right}</div>` : ''}
  </article>`;
}
export { icon, fmt, BREEDS, USE_NAME, TIER_NAME, tierOf };
