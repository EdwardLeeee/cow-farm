// M2 共用元件：回傳 HTML 字串。外觀在 css/kit.css。
import { icon, tabIcon } from './icons.js';
import { drawCow, SIL_DEFS } from '../cow/render.js';
import { BREEDS, USE_NAME, TIER_NAME, tierOf } from '../cow/breeds.js';
import { RANCH, xpPct, fmt, compact } from './fixtures.js';

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
export function hud({ ranch = RANCH, coins, level, xp, gear = true, w = 390, dot = false } = {}) {
  const c = coins ?? ranch.coins, lv = level ?? ranch.level, x = xp ?? xpPct(ranch);
  const coinText = compact(c, w < 390 ? 100000 : 1000000);
  return `<header class="hud">
    <div class="profile">
      <div class="avatar">${cowFace({ breed: 'holstein' }, 46)}</div>
      <div class="profile-text">
        <div class="farm-name" data-oneline>${ranch.name}</div>
        <div class="farm-level"><span class="lv num">Lv ${lv}</span><span class="xp" aria-label="經驗 ${x}%"><i style="width:${x}%"></i></span></div>
      </div>
    </div>
    <div class="coins"><span class="coin-icon">${icon('coin', 34)}</span><span class="num num-coins">${coinText}</span></div>
    ${gear ? (dot ? `<button class="gear has-dot" aria-label="設定（還沒備份牧場）">${icon('gear', 24)}<i class="gear-dot"></i></button>` : `<button class="gear" aria-label="設定">${icon('gear', 24)}</button>`) : ''}
  </header>`;
}
export const TABS = [
  { key: 'ranch', label: '牧場' }, { key: 'market', label: '市場' }, { key: 'fields', label: '田地' },
  { key: 'breed', label: '配種' }, { key: 'shop', label: '商店' }, { key: 'records', label: '紀錄' },
];
export function tabbar(active) {
  return `<nav class="tabbar">${TABS.map((t) => `<button class="tab${t.key === active ? ' active' : ''}" ${t.key === active ? 'aria-current="page"' : ''}>
    <span class="tab-icon">${tabIcon(t.key, t.key === active)}</span><span class="tab-label">${t.label}</span></button>`).join('')}</nav>`;
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
    ${o.offline ? `<div class="hud-offline">${icon('offline', 20)}<span>連線中…</span></div>` : ''}
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
export const tierChip = (t) => `<span class="tier tier-${t}">${t === 3 ? icon('sparkle', 12) : ''}${TIER_NAME[t]}</span>`;
export function useChip(use) {
  const ic = use === 'dairy' ? icon('milk', 16) : use === 'draft' ? icon('rice', 16) : icon('beef', 16);
  return `<span class="use">${ic}${USE_NAME[use]}</span>`;
}
export const sexText = (sex) => (sex === 'bull' ? '公' : '母');
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
    <div class="info"><div class="name">${b.name} #${c.id}</div>${chips ? `<div class="chips" style="margin-top:3px">${chips}</div>` : ''}${meta ? `<div class="meta">${meta}</div>` : ''}${extra}</div>
    ${right ? `<div class="right">${right}</div>` : ''}
  </article>`;
}
export { icon, fmt, BREEDS, USE_NAME, TIER_NAME, tierOf };
