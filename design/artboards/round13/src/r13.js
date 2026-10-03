// 第 13 輪草稿（ceo 2026-10-03 交辦）：企劃 v0.3 照顧牧場（D35）的方向，給使用者選。
// 網址：r13.html?b=R13-02-A&w=390 畫一張說明圖；?list=1 列出全部說明圖（harness/make.mjs 用）。
// 元件、字串、假資料、牛的產生器都用 M2 設計稿（design/m2）的。新的字是草稿，直接寫在這裡，沒有進字串表：
// 使用者選完才加 key、翻英文和泰文（D25）。
import { applyDevice, frame, btn, icon, fmt, badge, cowSVG, useChip, sexText, tierChip, bar, seg, fitTitles, fitOriginTags, placeVersion, fitSwipeHint, fitMiniLines, placeCowPop, fitGrade, fitActions, BREEDS } from '../../../m2/src/js/kit.js';
import { loadLang, t, dur, useName, breedName } from '../../../m2/src/js/i18n.js';
import { PEN, NEWS, FOUND, COWS, newsTag, newsText } from '../../../m2/src/js/fixtures.js';
import { CODEX_ORDER, TRAIT_NAME, tierOf } from '../../../m2/src/cow/breeds.js';
import { drawCow } from '../../../m2/src/cow/render.js';
import { ranchScene, HERD } from '../../../m2/src/js/scene.js';

const L = '#4B3326';
const f2 = (v) => Math.round(v * 100) / 100;

// ---------- 草稿用的牛（只在這一頁加進 BREEDS，名字用草稿字串） ----------
// i18n.js 用「../i18n/」載字串表（相對於 m2/src 的頁面）；這一頁在 artboards/round13/src，改指到 m2 的字串表，
// 繁中字串表順便加上草稿牛的名字（breed.<key>.name），這樣 M2 的元件（名字、清單）可以直接用
const DRAFT_STR = {};
const realFetch = window.fetch.bind(window);
window.fetch = async (u, o) => {
  if (typeof u !== 'string' || !u.startsWith('../i18n/')) return realFetch(u, o);
  const r = await realFetch(`../../../m2/${u.slice(3)}`, o);
  if (!u.endsWith('zh-Hant.json')) return r;
  return new Response(JSON.stringify({ ...(await r.json()), ...DRAFT_STR }), { headers: { 'Content-Type': 'application/json' } });
};
const USES = ['dairy', 'draft', 'beef'];
const UK = { dairy: 'Dairy', draft: 'Draft', beef: 'Beef' };
const CALF_NAME = { dairy: '小乳牛', draft: '小耕牛', beef: '小肉牛' };
const BASE_OF = { dairy: 'holstein', draft: 'yellow', beef: 'angus' }; // 每種用途沒有特徵的那一種（一般）
function reg(key, name, o) {
  BREEDS[key] = { traits: {}, pattern: 'solid', earColor: 'coat', ...o, name };
  DRAFT_STR[`breed.${key}.name`] = name;
}
// 02 小牛：A 照用途的一般品種（黑白花、黃褐、炭灰）；B 全部奶油色
const CREAM = '#F5E7D0';
// 03 雜種牛：A 灰褐素色；B 燕麥色加淡淡的咖啡斑
const MIX = {
  A: { coat: '#BDB2A5', muzzle: '#ECE2D7' },
  B: { coat: '#EEE2CE', pattern: 'patches', patternColor: '#BE9A78', muzzle: '#F4E8DA' },
};
USES.forEach((u, i) => {
  reg(`calfA${UK[u]}`, CALF_NAME[u], { ...BREEDS[BASE_OF[u]], traits: {} });
  reg(`calfB${UK[u]}`, CALF_NAME[u], { use: u, coat: CREAM, muzzle: '#F8E4D8', seed: BREEDS[BASE_OF[u]].seed });
  reg(`mixA${UK[u]}`, '雜種牛', { use: u, ...MIX.A, seed: 71 + i * 2 });
  reg(`mixB${UK[u]}`, '雜種牛', { use: u, ...MIX.B, seed: 77 + i * 2 });
});
// 04 病牛（荷斯坦 #3）：A 臉色發青
reg('sickA', '荷斯坦', { ...BREEDS.holstein, faceColor: '#DCEFE0' });
const calfKey = (look, use) => `calf${look}${UK[use]}`;
const mixKey = (look, use) => `mix${look}${UK[use]}`;

const q = new URLSearchParams(location.search);
const W = +(q.get('w') || 390);
const dev = applyDevice(W);
const app = document.getElementById('app');
await loadLang('zh-Hant');
// 畫面模組的常數會用到字串：字串表載好才載入（跟 m2 的 main.js 一樣）
const { dock, cowListRow } = await import('../../../m2/src/js/screens/s03.js');
const { HELPERS, helperSVG, helperInner, helperFace } = await import('./helper.js');

const PAD = 36, GAP = 40;

// ---------- 小圖示（M2 沒有的） ----------
// 頂列的小鉛筆（#135 還沒合併：main 的頂列還沒有；跟第 12 輪一樣補上，合併以後就不用了）
const PENCIL = (s = 12) => `<svg viewBox="0 0 16 16" width="${s}" height="${s}" aria-hidden="true"><path d="M2.6 13.4l.8-3.3 7.2-7.2a1.6 1.6 0 0 1 2.3 0l.2.2a1.6 1.6 0 0 1 0 2.3l-7.2 7.2z" fill="#FFFFFF" stroke="${L}" stroke-width="1.7" stroke-linejoin="round"/><path d="M9.3 4.2l2.5 2.5" stroke="${L}" stroke-width="1.5"/></svg>`;
const addPencil = (root) => root.querySelectorAll('.hud .avatar').forEach((a) => { if (!a.parentElement.querySelector('.hud-edit')) a.insertAdjacentHTML('afterend', `<i class="hud-edit" aria-hidden="true">${PENCIL(13)}</i>`); });

// 四種飼料（v0.3 第 2.1 節）：牧草（沒有對應的特徵）、燕麥（長毛）、苜蓿（淡色）、玉米（光澤）
const sheaf = (paths, light, w = 4.2) => paths.map((d) => `<path d="${d}" stroke="${L}" stroke-width="${w}" stroke-linecap="round" fill="none"/>`).join('') + paths.map((d) => `<path d="${d}" stroke="${light}" stroke-width="${w - 2.2}" stroke-linecap="round" fill="none"/>`).join('');
const FEED_IC = {
  hay: (s = 22) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" aria-hidden="true">${sheaf(['M12 17C10.2 12.8 8 9.6 4.8 7', 'M12 17C11 12.4 9.8 8.6 8 4.6', 'M12 17V3.6', 'M12 17C13 12.4 14.2 8.6 16 4.6', 'M12 17C13.8 12.8 16 9.6 19.2 7', 'M11 18.4L10 21.4', 'M13 18.4L14 21.4'], '#A6DC74')}
    <rect x="8.2" y="14.6" width="7.6" height="4.4" rx="1.6" fill="#E8AE62" stroke="${L}" stroke-width="1.6"/></svg>`,
  oat: (s = 22) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" aria-hidden="true">${sheaf(['M8 21.6C8.6 14.6 10.8 8.4 15.6 3.2'], '#8DBA4E', 3.8)}
    ${[[9.2, 15.4, 13.2, 17.6], [9.4, 12.6, 5.6, 14.2], [10.8, 9.6, 14.8, 11.4], [11.6, 8.2, 8, 9.2], [13.6, 5.6, 17.4, 6.8]].map(([x, y, ex, ey]) => `<path d="M${x} ${y}Q${(x + ex) / 2} ${Math.min(y, ey) - 1.2} ${ex} ${ey}" stroke="${L}" stroke-width="1.3" fill="none"/><ellipse cx="${ex}" cy="${ey + 1.9}" rx="1.9" ry="2.7" fill="#F6DE9C" stroke="${L}" stroke-width="1.3"/>`).join('')}</svg>`,
  alfalfa: (s = 22) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" aria-hidden="true">${sheaf(['M12 21.6V9.4'], '#7CC76A', 3.6)}
    <path d="M12 15.6C9.4 16.6 6.4 16 5 13.6c2.4-1.4 5.4-1 7 2zM12 15.6c2.6 1 5.6.4 7-2-2.4-1.4-5.4-1-7 2zM12 15.6c-1.6-2.2-1.4-5 .2-6.6" fill="#8CD46F" stroke="${L}" stroke-width="1.4" stroke-linejoin="round"/>
    ${[[12, 3.6], [9.4, 5.4], [14.6, 5.4], [10.4, 8.2], [13.6, 8.2], [12, 6.4]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="2.2" fill="#C69AF0" stroke="${L}" stroke-width="1.3"/>`).join('')}<circle cx="11.2" cy="3" r="0.8" fill="#FFFFFF"/></svg>`,
  corn: (s = 22) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" aria-hidden="true"><path d="M12 2.6c3 0 4.6 3.4 4.6 8.2S15 19.6 12 19.6s-4.6-4-4.6-8.8S9 2.6 12 2.6z" fill="#FFD45E" stroke="${L}" stroke-width="1.6"/>
    <path d="M8.4 7.4h7.2M7.9 10.8h8.2M8.3 14.2h7.4M10.2 3.6v15M13.8 3.6v15" stroke="#E2A72E" stroke-width="1.1"/><path d="M9.4 5.8v3.4" stroke="#FFF4CC" stroke-width="1.4" stroke-linecap="round"/>
    <path d="M12 21.6C8 20.6 5 16.8 5.2 11.4c2.4 2.4 4.6 5.6 6.8 10.2zM12 21.6c4-1 7-4.8 6.8-10.2-2.4 2.4-4.6 5.6-6.8 10.2z" fill="#8CD46F" stroke="${L}" stroke-width="1.5" stroke-linejoin="round"/></svg>`,
};
const FEED_NAME = { hay: '牧草', oat: '燕麥', alfalfa: '苜蓿', corn: '玉米' };
const TRAIT_FEED = { A: 'oat', B: 'alfalfa', C: 'corn' };
const FEED_TRAIT = { oat: 'A', alfalfa: 'B', corn: 'C' };
const feedChip = (k, s = 18) => `<span class="feed-chip">${FEED_IC[k](s)}${FEED_NAME[k]}</span>`;
// 溫度計（病牛）
const THERMO = (s = 16) => `<svg viewBox="0 0 20 20" width="${s}" height="${s}" aria-hidden="true"><path d="M8 3.8a2 2 0 0 1 4 0v7.6a3.9 3.9 0 1 1-4 0z" fill="#FFFFFF" stroke="${L}" stroke-width="1.7" stroke-linejoin="round"/><path d="M10 14.6V7.6" stroke="#FF6B6B" stroke-width="2.2" stroke-linecap="round"/><circle cx="10" cy="14.8" r="2.3" fill="#FF6B6B"/></svg>`;
// 指著的手（點、劃的手勢；指尖在 (13, 2)）
const POINTER = (s = 34) => `<svg viewBox="0 0 32 34" width="${s}" height="${Math.round(s * 34 / 32)}" aria-hidden="true"><path d="M11 4.4a2.3 2.3 0 0 1 4.6 0v9.8l1.2-.3a2.1 2.1 0 0 1 2.6 1.5l.1.5 1.1-.2a2.1 2.1 0 0 1 2.5 1.6l.1.5h.8a2.1 2.1 0 0 1 2.2 2.1v4.6c0 4.8-3.3 8.1-7.9 8.1h-1.5c-2.7 0-4.6-1.1-6.2-3.4l-4.8-6.7a2.1 2.1 0 0 1 3.1-2.8l2.1 2.3z" fill="#FFE3D2" stroke="${L}" stroke-width="2" stroke-linejoin="round"/><path d="M15.6 14.2v3.6M19.5 15.4v2.8M23.2 17.1v2" stroke="${L}" stroke-width="1.6" stroke-linecap="round"/></svg>`;

// ---------- 大便（04） ----------
// A 霜淇淋捲：三層一個小尖；B 扁扁的一坨。(x, y) 是底部中間，s 是寬
function poopA(x, y, s = 18) {
  return `<g transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s / 20)})"><ellipse cx="0" cy="0.6" rx="10.4" ry="2.4" fill="#5E8F3E" opacity="0.28"/>
    <path d="M-9.4 0C-11 -1 -10.6 -5.6 -7 -6.2C-7.2 -9.8 -3.6 -11.4 -2 -11.2C-2.2 -14.2 0.4 -16.2 2.6 -17.2C2.4 -15.6 3.8 -14 4.4 -11.8C7.2 -11.4 8.4 -8.6 7.2 -6.4C10.6 -5.8 11 -1.2 9.4 0Z" fill="#B07843" stroke="${L}" stroke-width="1.7" stroke-linejoin="round"/>
    <path d="M-7 -6.2C-3.2 -4.8 3.2 -4.8 7.2 -6.4M-2 -11.2C0.4 -10 2.8 -10.2 4.4 -11.8" fill="none" stroke="${L}" stroke-width="1.4" stroke-linecap="round"/>
    <path d="M-6.8 -2.6C-5.6 -1.8 -4.2 -1.6 -3 -1.8M-3.8 -8.4C-3 -7.8 -2 -7.6 -1.2 -7.8" stroke="#FFFFFF" stroke-width="1.4" stroke-linecap="round" fill="none" opacity="0.75"/></g>`;
}
function poopB(x, y, s = 18) {
  // 扁扁的一坨（像真的牛糞），上面兩條小小的臭味線
  return `<g transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s / 20)})"><ellipse cx="0" cy="0.6" rx="11" ry="2.4" fill="#5E8F3E" opacity="0.28"/>
    <path d="M-10.6 -1.4C-11.4 -4.4 -7.6 -6.6 -4.4 -6.4C-3 -8.6 3.4 -8.8 4.8 -6.4C8.4 -6.6 11.6 -4.2 10.6 -1.4C9.6 0.4 -9.6 0.4 -10.6 -1.4Z" fill="#8E5A34" stroke="${L}" stroke-width="1.7" stroke-linejoin="round"/>
    <path d="M-6 -3.8C-3.6 -2.6 3.4 -2.6 5.8 -3.8M-2.6 -5.8C-1 -5 1.2 -5 2.6 -5.8" fill="none" stroke="${L}" stroke-width="1.3" stroke-linecap="round"/>
    <path d="M-8 -3.2C-7.4 -2.4 -6.6 -2 -5.6 -2" stroke="#FFFFFF" stroke-width="1.4" stroke-linecap="round" fill="none" opacity="0.7"/>
    <path d="M-3 -10.4q1.6-1.6 0-3.2t0-3.2M3 -10.4q1.6-1.6 0-3.2t0-3.2" fill="none" stroke="#7FA86A" stroke-width="1.4" stroke-linecap="round"/></g>`;
}
const POOP = { A: poopA, B: poopB };
const poopIcon = (look, s = 22) => `<svg viewBox="-12 -19 24 22" width="${s}" height="${Math.round(s * 22 / 24)}" aria-hidden="true">${POOP[look](0, 0, 20)}</svg>`;

// ---------- 牛的圖 ----------
let uid = 0;
// 頭的大小（drawCow 回傳的臉是半徑 r；側面的頭蛋形，正面的頭寬一點）
const headOf = (f, pose) => ({ rx: (pose === 'side' ? 0.6 : 0.81) * f.r, ry: (pose === 'side' ? 0.81 : 0.89) * f.r });
// 放得進 w×h 的框的比例（top：頭上留給配件的空間）
function fitK(entry, { w, h, pose = 'front', pad = 4, top = 0 }) {
  const r0 = drawCow({ ...entry, pose }, { scale: 1, facing: 'left' });
  return Math.min((w - pad * 2) / ((r0.bbox.x1 - r0.bbox.x0) * r0.scale), (h - pad * 2 - top) / r0.height);
}
// 把牛畫進 w×h 的框（底部對齊、置中；跟 kit.js 的 cowSVG 一樣）。acc(f, pose, facing)：在牛上面加配件（f 是臉的位置）；
// k：指定比例（排排站時公母用同一個比例，才看得出公的大一點）
function cowArt(entry, { w = 120, h = 110, pose = 'front', facing = 'left', pad = 4, top = 0, acc = null, cls = '', k: kk = null } = {}) {
  const e = { ...entry, pose };
  const r0 = drawCow(e, { scale: 1, facing: 'left' });
  const x0 = r0.bbox.x0 * r0.scale, x1 = r0.bbox.x1 * r0.scale;
  const k = kk ?? fitK(entry, { w, h, pose, pad, top });
  const cx = w / 2 - (facing === 'right' ? -(x0 + x1) / 2 : (x0 + x1) / 2) * k;
  const r = drawCow(e, { x: cx, y: h - pad, scale: k, facing, id: `r13c${uid++}` });
  const f = { cx: r.face.cx, cy: r.face.cy, r: r.face.r, top: r.headTop[1] };
  return `<svg class="${cls}" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" aria-hidden="true">${r.svg}${acc ? acc(f, pose, facing) : ''}</svg>`;
}

// ---------- 小牛的配件（02） ----------
// 母的：頭上一個粉紅蝴蝶結（兩個方向都一樣）；B 另外加一條照用途顏色的領巾
const USE_COLOR = { dairy: '#7CC4F0', draft: '#8CD46F', beef: '#FF9E8A' };
function bow(x, y, s, rot = -14) {
  const a = s / 2, lw = f2(Math.max(1, s * 0.075));
  const loop = (d) => `M0 0C${f2(d * 0.25 * a)} ${f2(-0.95 * a)} ${f2(d * 1.08 * a)} ${f2(-0.9 * a)} ${f2(d * a)} ${f2(-0.05 * a)}C${f2(d * 1.06 * a)} ${f2(0.78 * a)} ${f2(d * 0.25 * a)} ${f2(0.82 * a)} 0 0Z`;
  return `<g transform="translate(${f2(x)} ${f2(y)}) rotate(${rot})"><path d="${loop(-1)}" fill="#FF8FB1" stroke="${L}" stroke-width="${lw}" stroke-linejoin="round"/><path d="${loop(1)}" fill="#FF8FB1" stroke="${L}" stroke-width="${lw}" stroke-linejoin="round"/>
    <path d="M${f2(-0.72 * a)} ${f2(-0.22 * a)}Q${f2(-0.6 * a)} ${f2(-0.55 * a)} ${f2(-0.3 * a)} ${f2(-0.5 * a)}" stroke="#FFFFFF" stroke-width="${lw}" stroke-linecap="round" fill="none" opacity="0.8"/>
    <ellipse cx="0" cy="0" rx="${f2(0.26 * a)}" ry="${f2(0.32 * a)}" fill="#FF6F9A" stroke="${L}" stroke-width="${lw}"/></g>`;
}
function bowOn(f, pose, facing) {
  const { rx, ry } = headOf(f, pose), d = facing === 'right' ? -1 : 1;
  return bow(f.cx + d * rx * 0.5, f.cy - ry * 0.9, f.r * 0.95, d * -14);
}
function scarf(f, pose, color) {
  const { rx, ry } = headOf(f, pose), y = f.cy + ry * 0.86, w = rx * 0.8, r = f.r, lw = f2(Math.max(1, r * 0.075));
  const flap = `M${f2(f.cx - 0.38 * r)} ${f2(y + 0.1 * r)}L${f2(f.cx + 0.38 * r)} ${f2(y + 0.1 * r)}Q${f2(f.cx + 0.16 * r)} ${f2(y + 0.5 * r)} ${f2(f.cx)} ${f2(y + 0.66 * r)}Q${f2(f.cx - 0.16 * r)} ${f2(y + 0.5 * r)} ${f2(f.cx - 0.38 * r)} ${f2(y + 0.1 * r)}Z`;
  const band = `M${f2(f.cx - w)} ${f2(y - 0.1 * r)}Q${f2(f.cx)} ${f2(y + 0.22 * r)} ${f2(f.cx + w)} ${f2(y - 0.1 * r)}L${f2(f.cx + w * 0.97)} ${f2(y + 0.1 * r)}Q${f2(f.cx)} ${f2(y + 0.44 * r)} ${f2(f.cx - w * 0.97)} ${f2(y + 0.1 * r)}Z`;
  return `<path d="${flap}" fill="${color}" stroke="${L}" stroke-width="${lw}" stroke-linejoin="round"/><path d="${band}" fill="${color}" stroke="${L}" stroke-width="${lw}" stroke-linejoin="round"/>
    <circle cx="${f2(f.cx)}" cy="${f2(y + 0.17 * r)}" r="${f2(0.11 * r)}" fill="#FFFFFF" stroke="${L}" stroke-width="${f2(lw * 0.8)}"/>`;
}
const calfAcc = (look, use, sex) => (f, pose, facing) => (look === 'B' ? scarf(f, pose, USE_COLOR[use]) : '') + (sex === 'cow' ? bowOn(f, pose, facing) : '');
// 小牛（照 02 的方向）：c 是 { use, sex, seed? }
const calfArt = (c, look, o = {}) => cowArt({ breed: calfKey(look, c.use), sex: c.sex, age: 'calf', seed: c.seed }, { top: 10, ...o, acc: calfAcc(look, c.use, c.sex) });
const calfName = (c) => `${CALF_NAME[c.use]} #${c.id}`;

// ---------- 病牛的樣子（04） ----------
// A：額頭幾條藍色的線、臉色發青（faceColor）＋頭上的溫度計泡泡；B：發燒：臉頰紅紅、頭上冰袋、一滴汗
function thermoBubble(x, y, r) {
  const k = r / 10;
  return `<g transform="translate(${f2(x)} ${f2(y)})"><path d="M${f2(-6 * k)} ${f2(7.4 * k)}L${f2(-11.4 * k)} ${f2(13.6 * k)}L${f2(-1.4 * k)} ${f2(9.6 * k)}" fill="#FFFFFF" stroke="${L}" stroke-width="${f2(1.6 * k)}" stroke-linejoin="round"/>
    <circle r="${f2(r)}" fill="#FFFFFF" stroke="${L}" stroke-width="${f2(1.8 * k)}"/><path d="M${f2(-5.2 * k)} ${f2(8.2 * k)}L${f2(-1.4 * k)} ${f2(8.6 * k)}" stroke="#FFFFFF" stroke-width="${f2(2.4 * k)}"/>
    <g transform="translate(${f2(-8.6 * k)} ${f2(-9.6 * k)}) scale(${f2(0.86 * k)})">${THERMO(20).replace(/^<svg[^>]*>|<\/svg>$/g, '')}</g></g>`;
}
function sickA(f) {
  const { rx, ry } = headOf(f, 'front'), lw = f2(Math.max(1.2, f.r * 0.075));
  const lines = [-0.36, -0.12, 0.12, 0.36].map((u) => `<path d="M${f2(f.cx + u * rx)} ${f2(f.cy - ry * (0.7 - Math.abs(u) * 0.3))}v${f2(ry * (0.36 - Math.abs(u) * 0.2))}" stroke="#7F9FE6" stroke-width="${lw}" stroke-linecap="round"/>`).join('');
  return lines + thermoBubble(f.cx + rx * 1.15, f.top - f.r * 0.2, f.r * 0.5);
}
function icePack(x, y, s, rot = -16) {
  const k = s / 20;
  return `<g transform="translate(${f2(x)} ${f2(y)}) rotate(${rot}) scale(${f2(k)})"><path d="M-9.6 -1.6c0-4.2 3.2-6.6 9.6-6.6s9.6 2.4 9.6 6.6c0 3.6-3.8 5.4-9.6 5.4s-9.6-1.8-9.6-5.4z" fill="#C4E6FB" stroke="${L}" stroke-width="1.7"/>
    <path d="M7.4 -6.6l3.4-3.2 1.6 1.7-3.4 2.8z" fill="#7CC4F0" stroke="${L}" stroke-width="1.4" stroke-linejoin="round"/><path d="M-6 -4.2q3.2-2 7.4-1.6" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round" fill="none"/></g>`;
}
const drop = (x, y, s) => `<path d="M${f2(x)} ${f2(y - s)}c${f2(s * 0.45)} ${f2(s * 0.7)} ${f2(s * 0.75)} ${f2(s * 1.1)} ${f2(s * 0.75)} ${f2(s * 1.45)}a${f2(s * 0.75)} ${f2(s * 0.75)} 0 0 1 ${f2(-s * 1.5)} 0c0 ${f2(-s * 0.35)} ${f2(s * 0.3)} ${f2(-s * 0.75)} ${f2(s * 0.75)} ${f2(-s * 1.45)}z" fill="#A9DBFF" stroke="${L}" stroke-width="${f2(Math.max(1, s * 0.16))}" stroke-linejoin="round"/>`;
function sickB(f) {
  const { rx, ry } = headOf(f, 'front');
  const lw = f2(Math.max(0.9, f.r * 0.05));
  const cheeks = [-1, 1].map((d) => {
    const x = f.cx + d * rx * 0.56, y = f.cy + ry * 0.16, a = f.r * 0.22;
    return `<ellipse cx="${f2(x)}" cy="${f2(y)}" rx="${f2(a)}" ry="${f2(a * 0.6)}" fill="#FF4F4F" opacity="0.62"/>` + [-0.5, 0, 0.5].map((u) => `<path d="M${f2(x + u * a - a * 0.18)} ${f2(y + a * 0.3)}l${f2(a * 0.36)} ${f2(-a * 0.6)}" stroke="#D93A3A" stroke-width="${lw}" stroke-linecap="round"/>`).join('');
  }).join('');
  return cheeks + icePack(f.cx - rx * 0.1, f.cy - ry * 0.98, f.r * 1.15) + drop(f.cx + rx * 1.05, f.cy - ry * 0.35, f.r * 0.2);
}
const SICK = { A: sickA, B: sickB };

// ---------- 說明圖的版面 ----------
// 左上角印檔名（跟檔名一樣的標籤），下面是標題、說明、上面一塊（排排站）、一排手機、註解
function board({ id, title, sub = '', top = '', cells = [], cols = cells.length, notes = [], width, body = '' }) {
  const wpx = width || PAD * 2 + cols * dev.w + (cols - 1) * GAP;
  const html = `<div class="board" style="width:${wpx}px">
    <div class="b-label">${id}</div>
    <div class="b-title">${title}</div>${sub ? `<div class="b-sub">${sub}</div>` : ''}
    ${top}
    ${cells.length ? `<div class="b-row" style="grid-template-columns:repeat(${cols}, ${dev.w}px)">${cells.map((c) => `<figure class="b-cell"><figcaption><b>${c.cap}</b>${c.note || ''}</figcaption>${c.html}</figure>`).join('')}</div>` : ''}
    ${body}
    ${notes.length ? `<ul class="b-notes">${notes.map((n) => `<li>${n}</li>`).join('')}</ul>` : ''}
  </div>`;
  return { html, after: async (root) => { const figs = root.querySelectorAll('.b-cell'); for (let i = 0; i < cells.length; i++) if (cells[i].after) await cells[i].after(figs[i]); } };
}
const boardWidth = (cols) => PAD * 2 + cols * dev.w + (cols - 1) * GAP;

// ---------- 牧場頁（S03 的 ranchPage，多了：場景裡的東西 extra、牛的位置給上面的泡泡用） ----------
// extra({ anchors, inv, k })：畫在場景裡（場景座標，在牛的上面、在面板下面）；overlays(anchors)：畫在畫面最上層（手機座標）
function ranch(o = {}) {
  const herd = o.herd || HERD, pan = o.pan || 0;
  const s0 = ranchScene(dev, herd, { wide: true, pan });
  const F = s0.fit, inv = ([x, y]) => [(x - F.ox) / F.k + pan, (y - F.oy) / F.k];
  const extra = o.extra ? o.extra({ anchors: s0.anchors, inv, k: F.k, map: F.map }) : '';
  const sc = extra ? ranchScene(dev, herd, { wide: true, pan, extra }) : s0;
  const over = typeof o.overlays === 'function' ? o.overlays(sc.anchors, F.map) : o.overlays || '';
  const pen = o.pen || PEN;
  const body = `
    <div class="ticker"><span class="ticker-icon">${icon('news', 20)}</span><span class="ticker-text" data-marquee>${newsTag(NEWS[0])}${newsText(NEWS[0])}</span></div>
    <button class="pen-pill${pen.used >= pen.slots ? ' full' : ''}">${icon('barn', 22)}${t('cowsTitle')}<span class="num">${pen.used} / ${pen.slots}</span>${icon('chevron', 16)}</button>
    ${o.center || ''}
    ${dock({ ...(o.dock || {}), pan })}`;
  return frame(dev, { tab: 'ranch', scene: sc.svg, body, hud: o.hud || {}, overlays: over });
}
// 場景裡小牛的配件（照 02 的方向）
const calfExtras = (herd, look) => ({ anchors, inv, k }) => herd.filter((h) => h.age === 'calf').map((h) => {
  const a = anchors[h.id], [cx, cy] = inv(a.face), [, top] = inv(a.head);
  return calfAcc(look, BREEDS[h.breed].use, h.sex || 'cow')({ cx, cy, r: a.faceR / k, top }, h.pose || 'side', h.facing);
}).join('');

// ---------- 假資料：小牛（05 也用） ----------
// p：每個特徵長出來的機率（事前機率，v0.3 第 1 節）；ate：小牛時期吃過的特徵飼料
const CALVES = {
  15: { id: 15, use: 'dairy', sex: 'cow', age_: { m: 18 }, grow_: { m: 42 }, origin: 'breed', p: { A: 0.25, B: 0.5, C: 0 }, ate: { B: true } },
  21: { id: 21, use: 'draft', sex: 'bull', age_: { m: 50 }, grow_: { h: 3, m: 10 }, origin: 'breed', p: { A: 0.5, B: 0.25, C: 0.25 }, ate: { A: true } },
  22: { id: 22, use: 'beef', sex: 'cow', age_: { h: 1, m: 5 }, grow_: { h: 2, m: 55 }, origin: 'B', p: { A: 0.3, B: 0.3, C: 0.2 }, ate: { A: true, B: true, C: true } },
  23: { id: 23, use: 'dairy', sex: 'bull', age_: { m: 25 }, grow_: { m: 35 }, origin: 'A', p: { A: 0.2, B: 0.2, C: 0.1 }, ate: {} },
  24: { id: 24, use: 'draft', sex: 'cow', age_: { m: 40 }, grow_: { m: 20 }, origin: 'A', p: { A: 0.2, B: 0.2, C: 0.1 }, ate: {} },
  25: { id: 25, use: 'beef', sex: 'bull', age_: { m: 10 }, grow_: { m: 50 }, origin: 'C', p: { A: 0.1, B: 0.1, C: 0.05 }, ate: {} },
};
// 還沒吃、機率大於 0 的特徵的飼料（想吃泡泡、提醒卡）
const wants = (c) => ['A', 'B', 'C'].filter((k) => c.p[k] > 0 && !c.ate[k]).map((k) => TRAIT_FEED[k]);
const pctTxt = (v) => `${Math.round(v * 100)}%`;
// 牧場裡的小牛：#15 換成基本款，另外加兩頭（#21 公耕牛、#22 母肉牛）
const CALF_SPOTS = [
  { id: 21, x: 236, y: 352, facing: 'left', depth: 0 },
  { id: 22, x: 262, y: 512, facing: 'left', depth: 2 },
];
const PEN13 = { used: 13, slots: 16 }; // 多了 3 頭小牛（跟牛舍清單一樣）
const herdWithCalves = (look) => HERD.map((h) => (h.id === 15 ? { ...h, breed: calfKey(look, 'dairy') } : h))
  .concat(CALF_SPOTS.map((s) => ({ ...s, breed: calfKey(look, CALVES[s.id].use), sex: CALVES[s.id].sex, age: 'calf' })));

// 小牛的詳細（S04-08 的骨架）：名字、標籤不透露品種和稀有度；traits 是 05 的特徵卡
function calfPage(c, look, { traits = '', note = '', heroH = null } = {}) {
  const chips = [useChip(c.use), `<span class="use">${sexText(c.sex)}</span>`, badge('calf', t('stageCalf'))];
  const origin = c.origin === 'breed' ? t('s04.originBreed') : t('s04.originShop', { g: c.origin });
  const cells = [[t('s04.age'), dur(c.age_)], [t('s04.growIn'), dur(c.grow_)]];
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${calfName(c)}</h1><div class="chips" style="margin-top:3px">${chips.join('')}</div></div></div>
    <article class="card hero calf-hero"><div class="hero-bg"></div>${calfArt(c, look, { w: 190, h: heroH ?? (traits ? 104 : 150) })}
      <span class="origin-tag">${t('origin', { v: origin })}</span><p class="hint hero-note">長大才知道是什麼品種</p></article>
    <div class="kv">${cells.map(([k, v]) => `<div class="cell"><div class="k">${k}</div><div class="v num">${v}</div></div>`).join('')}</div>
    ${note}${traits}
  </div>`;
  const buttons = `<button class="btn green block">${FEED_IC.hay(22)}<span>餵食</span></button><div class="btn-row" style="margin-top:12px">${btn(t('s04.cantBreedYet'), { kind: 'pink', ic: 'heart', disabled: true })}${btn(t('shipNotAdult'), { kind: 'danger', disabled: true })}</div>`;
  return frame(dev, { tab: 'ranch', content, contentCls: 'has-actions rows-2', body: `<div class="detail-actions rows-2">${buttons}</div>` });
}
// 牛舍清單的小牛那一列（照 S03 的清單列；extra 是 05 的飼料狀態）
function calfRow(c, look, extra = '') {
  const chips = [useChip(c.use), `<span class="use">${sexText(c.sex)}</span>`, badge('calf', t('stageCalf'))];
  return `<article class="card cow-row"><div class="pic">${calfArt(c, look, { w: 60, h: 60, pad: 3, top: 4 })}</div>
    <div class="info"><div class="name">${calfName(c)}</div><div class="chips" style="margin-top:3px">${chips.join('')}</div><div class="meta">${t('growUp', { v: dur(c.grow_) })}</div>${extra}</div>
    <div class="right"><span class="chev">${icon('chevron', 20)}</span></div></article>`;
}
function listPage(rows, { used = 13 } = {}) {
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${t('cowsTitle')}</h1><div class="sub">${t('penSummary', { used, slots: 16 })}</div></div>${btn(t('s03.expandPen'), { small: true, kind: 'primary', ic: 'plus' })}</div>
    <div class="filter" data-hscroll>${[t('g.all'), useName('dairy'), useName('draft'), useName('beef')].map((f, i) => `<button class="${i === 0 ? 'on' : ''}">${f}</button>`).join('')}</div>
    <div class="list">${rows.join('')}</div></div>`;
  return frame(dev, { tab: 'ranch', content });
}

// ---------- 02 小牛 6 種基本款 ----------
const LOOK2 = {
  A: { name: '照用途的一般品種', file: '照用途的一般品種', title: '乳牛黑白花、耕牛黃褐、肉牛炭灰（像每種用途沒有特徵的那一種）' },
  B: { name: '全部奶油色，領巾分用途', file: '奶油色加領巾', title: '全部奶油色，用領巾的顏色分用途（乳牛藍、耕牛綠、肉牛紅）' },
};
const GROWN = { dairy: ['holstein', 'jersey', 'strawberry'], draft: ['yellow', 'highland', 'goldenEar'], beef: ['angus', 'wagyu', 'starry'] };
// 公母用同一個比例（照公的放進框裡），才看得出公的大一點
const pairK = (key, extra, box) => Math.min(...['cow', 'bull'].map((sex) => fitK({ breed: key, sex, ...extra }, box)));
function calfLineup(look) {
  const cell = (u, sex) => {
    const kf = pairK(calfKey(look, u), { age: 'calf' }, { w: 150, h: 124, top: 10 }), ks = pairK(calfKey(look, u), { age: 'calf' }, { w: 180, h: 112, pose: 'side', top: 10 });
    return `<div class="lu-cell"><div class="lu-pics">${calfArt({ use: u, sex }, look, { w: 150, h: 124, k: kf })}${calfArt({ use: u, sex }, look, { w: 180, h: 112, pose: 'side', k: ks })}</div><b>${useName(u)}・${sexText(sex)}</b><span>${CALF_NAME[u]}${sex === 'cow' ? '（頭上有蝴蝶結）' : '（體型大一點）'}</span></div>`;
  };
  const grown = (u) => `<div class="lu-cell grown"><div class="gr-row">${calfArt({ use: u, sex: 'cow' }, look, { w: 76, h: 70, pad: 2 })}<span class="gr-arrow">${icon('chevron', 22)}</span>${GROWN[u].map((k) => cowArt({ breed: k }, { w: 74, h: 78, pad: 2 })).join('')}</div><span>${GROWN[u].map(breedName).join('、')}……</span></div>`;
  return `<div class="lineup" style="grid-template-columns:repeat(3, 1fr)">
    <div class="lu-head">小時候：6 種<small>正面（點牛、卡片）＋側面（牧場裡）；公母用同一個比例畫</small></div>
    ${['cow', 'bull'].map((sex) => USES.map((u) => cell(u, sex)).join('')).join('')}
    <div class="lu-head">長大那一刻才揭曉品種<small>例：同一種小牛，長大可能是這幾種（還有別的）</small></div>
    ${USES.map(grown).join('')}
  </div>`;
}
function r1302(look) {
  const o = LOOK2[look], herd = herdWithCalves(look);
  const rows = [calfRow(CALVES[15], look), calfRow(CALVES[21], look), calfRow(CALVES[22], look), cowListRow(COWS.find((c) => c.id === 3)), cowListRow(COWS.find((c) => c.id === 7))];
  return board({
    id: `R13-02-小牛-${look}-${o.file}-390`, title: `02 小牛的 6 種樣子　${look}：${o.title}`, width: boardWidth(3),
    sub: '小時候只看得出用途和公母（v0.3 第 1 節）；長毛、淡色、光澤長大才揭曉。公母兩個方向都一樣：母的頭上有蝴蝶結，公的體型大一點（產生器原本就是）。',
    top: calfLineup(look),
    cells: [
      { cap: '牧場裡', note: '中間是母的小乳牛，後排是公的小耕牛，前排右邊是母的小肉牛', html: ranch({ herd, pen: PEN13, extra: calfExtras(herd, look) }) },
      { cap: '小牛的詳細', note: '名字寫「小乳牛 #15」，不寫品種、不放稀有度；長大才換成品種名', html: calfPage(CALVES[15], look, { heroH: 150, traits: `<div class="slot-note">可能長出的特徵、要吃的飼料：見 05</div>` }) },
      { cap: '牛舍清單', note: '60 寬的小圖也看得出用途和公母', html: listPage(rows) },
    ],
    notes: look === 'A' ? [
      '好處：一看就知道是哪種用途，跟現在的小牛差不多；牧場裡小小的也認得出來。',
      '代價：小乳牛長得像荷斯坦，長大變成娟珊、草莓牛時，要靠揭曉動畫說明「長大才知道」。',
    ] : [
      '好處：每頭小牛都長一樣，一看就知道「還沒揭曉」，長大那一刻的變化最大。',
      '代價：用途要看領巾的顏色和體型（乳牛腿長、肉牛矮胖）；牧場裡小小的時候比 A 難分。',
    ],
  });
}

// ---------- 03 雜種牛 ----------
const LOOK3 = {
  A: { name: '灰褐素色', file: '灰褐素色', title: '全身一個顏色：灰褐色（24 種裡沒有灰褐色的牛）', near: ['milkTea', 'jersey', 'charolais', 'buffalo'] },
  B: { name: '燕麥色加淡斑', file: '燕麥色加淡斑', title: '燕麥色的底，加幾塊淡淡的咖啡斑（看起來像混出來的）', near: ['holstein', 'chocolate', 'cottonCream', 'charolais'] },
};
function mixLineup(look) {
  const cell = (u, sex) => {
    const kf = pairK(mixKey(look, u), {}, { w: 150, h: 130 }), ks = pairK(mixKey(look, u), {}, { w: 190, h: 120, pose: 'side' });
    return `<div class="lu-cell"><div class="lu-pics">${cowArt({ breed: mixKey(look, u), sex }, { w: 150, h: 130, k: kf })}${cowArt({ breed: mixKey(look, u), sex }, { w: 190, h: 120, pose: 'side', k: ks })}</div><b>${useName(u)}・${sexText(sex)}</b></div>`;
  };
  const near = `<div class="lu-cell near"><div class="gr-row">${cowArt({ breed: mixKey(look, 'dairy') }, { w: 96, h: 92, pad: 2 })}<span class="vs">對照</span>${LOOK3[look].near.map((k) => `<span class="nb">${cowArt({ breed: k }, { w: 92, h: 92, pad: 2 })}<i>${breedName(k)}</i></span>`).join('')}</div><span>左邊是雜種牛，右邊是 24 種裡顏色最接近的 4 種</span></div>`;
  return `<div class="lineup" style="grid-template-columns:repeat(3, 1fr)">
    <div class="lu-head">三種體型 × 公母<small>正面＋側面；照用途的體型（乳牛最高、肉牛最寬）；公母用同一個比例畫</small></div>
    ${['cow', 'bull'].map((sex) => USES.map((u) => cell(u, sex)).join('')).join('')}
    ${near}
  </div>`;
}
// 圖鑑（S09-01 的骨架，捲到最下面）：24 格照舊，最下面另外一格「雜種牛」
function codexCell(k) {
  const found = FOUND.includes(k);
  return `<button class="dex-cell${found ? '' : ' unknown'}"><span class="dex-pic">${cowSVG({ breed: k }, { w: 74, h: 64, pad: 3, sil: found ? false : 'dark' })}</span><span class="dex-name">${found ? breedName(k) : t('g.unknownBreed')}</span>${tierChip(tierOf(BREEDS[k]))}</button>`;
}
function codexMix(look) {
  const n = FOUND.length;
  const mixTile = `<button class="dex-cell dex-mix-tile"><span class="dm-pics">${USES.map((u) => cowArt({ breed: mixKey(look, u) }, { w: 70, h: 62, pad: 2 })).join('')}</span><span class="dm-text"><span class="dex-name">雜種牛</span><span class="hint">3 種體型</span></span></button>`;
  const content = `<div class="stack">
    ${seg([t('subCodex'), t('subRank')], 0)}
    <article class="card dex-head"><div class="row" style="justify-content:space-between"><span class="card-title">${icon('book', 18)}${t('s09.found')}</span><b class="num dex-count">${n} <small>/ 24</small></b></div>
      ${bar((n / 24) * 100, { color: 'yellow', thick: true })}<p class="hint" style="margin-top:6px">${t('s09.hint')}</p></article>
    <div class="skip-note">乳牛、耕牛 16 格（略）</div>
    ${['beef'].map((u) => `<section><h3 class="sec-title">${useChip(u)}<span class="hint">${t('s09.useCount', { use: useName(u), n: 8 })}</span></h3>
      <div class="dex-grid">${CODEX_ORDER.filter((k) => BREEDS[k].use === u).map(codexCell).join('')}</div></section>`).join('')}
    <section><h3 class="sec-title"><span class="use">其他</span><span class="hint">不算在 24 種裡，也不算完成度</span></h3><div class="dex-grid">${mixTile}</div></section>
  </div>`;
  return { html: frame(dev, { tab: 'records', content }) };
}
// 長大揭曉：變成雜種牛（A-04 改到長大那一刻，這裡畫最後停住的樣子）
function mixReveal(look) {
  const inner = `<div class="disc-title">小乳牛 #15 長大了！</div>
    <div class="card mix-reveal">${cowArt({ breed: mixKey(look, 'dairy') }, { w: 200, h: 150 })}
      <b class="mr-name">雜種牛 #15</b><div class="chips">${useChip('dairy')}<span class="use">${sexText('cow')}</span></div>
      <p class="mr-why">${FEED_IC.corn(22)}<span>沒吃到玉米，長成了雜種牛</span></p>
      <p class="hint mr-hint">牛奶、牛肉、稻米都是一般牛的 0.6 倍。<br>配種的時候，小牛照樣可能長出稀有的品種。</p>
      ${btn(t('ok'), { kind: 'primary', block: true })}</div>`;
  return ranch({ overlays: `<div class="backdrop"></div><div class="reveal">${inner}</div>` });
}
// 雜種牛的詳細（長大以後；S04-01 的骨架）：標籤寫「雜種」、不放稀有度；產奶是 14 × 0.6
function mixDetail(look) {
  const chips = [useChip('dairy'), `<span class="use">${sexText('cow')}</span>`, badge('mix', '雜種')];
  const cells = [[t('s04.age'), dur({ h: 3, m: 20 })], [t('g.milk'), `8.4 <small>${t('g.perHourMilk')}</small>`], [t('s04.weight'), `206 <small>${t('g.kg')}</small>`], [t('s04.value'), `${t('s04.about', { v: fmt(1460) })} <small>${t('g.coin')}</small>`]];
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>雜種牛 #15</h1><div class="chips" style="margin-top:3px">${chips.join('')}</div></div></div>
    <article class="card hero"><div class="hero-bg"></div>${cowArt({ breed: mixKey(look, 'dairy') }, { w: 200, h: 150 })}<span class="origin-tag">${t('origin', { v: t('s04.originBreed') })}</span></article>
    <p class="hint mix-note">${FEED_IC.corn(18)}沒吃到玉米長成的；牛奶、牛肉、稻米 ×0.6</p>
    <div class="kv">${cells.map(([k, v]) => `<div class="cell"><div class="k">${k}</div><div class="v num">${v}</div></div>`).join('')}</div>
  </div>`;
  const buttons = `<div class="btn-row">${btn(t('pickForBreed'), { kind: 'pink', ic: 'heart' })}${btn(t('ship'), { kind: 'danger', ic: 'truck' })}</div>`;
  return frame(dev, { tab: 'ranch', content, contentCls: 'has-actions rows-1', body: `<div class="detail-actions rows-1">${buttons}</div>` });
}
function r1303(look) {
  const o = LOOK3[look], cx = codexMix(look);
  return board({
    id: `R13-03-雜種牛-${look}-${o.file}-390`, title: `03 雜種牛　${look}：${o.title}`, width: boardWidth(3),
    sub: '稀有、傳說的小牛少吃一種飼料，長大就變成雜種牛（v0.3 第 1.1 節）。不是 24 種之一；用同一個產生器、照用途分三種體型。',
    top: mixLineup(look),
    cells: [
      { cap: '圖鑑：最下面另外一格', note: '「已發現 10 / 24」不變；雜種牛第一次長出來以前是剪影', ...cx },
      { cap: '長大揭曉：變成雜種牛', note: '告訴玩家少吃了哪一種，不說原本會是哪個品種', html: mixReveal(look) },
      { cap: '雜種牛的詳細', note: '標籤寫「雜種」，不放稀有度；可以配種、出貨，跟一般牛一樣', html: mixDetail(look) },
    ],
    notes: look === 'A' ? [
      '好處：最素、最像「基本款」；跟 24 種的顏色都分得開（24 種沒有灰色系的淺色牛）。',
      '代價：灰灰的，比較不起眼（雜種牛本來就是失手的結果，不起眼也合理）。',
    ] : [
      '好處：看起來像兩種牛混出來的，一看就懂「雜種」。',
      '代價：有斑，沒有 A 那麼素；跟荷斯坦、巧克力牛一樣是花斑，只是顏色淡很多。',
    ],
  });
}

// ---------- 04 大便、病牛、清大便 ----------
const LOOK4 = {
  A: { name: '霜淇淋捲、臉色發青', file: '霜淇淋捲和臉色發青', title: '大便是霜淇淋捲；病牛臉色發青、頭上溫度計' },
  B: { name: '扁扁一坨、發燒', file: '扁扁一坨和發燒', title: '大便是扁扁的一坨；病牛發燒：臉頰紅通通、頭上冰袋' },
};
// 大便的位置（場景座標；草地上、不擋到牛）
const POOPS = [[236, 398], [252, 452], [38, 498], [214, 482], [284, 472], [362, 448], [204, 338], [132, 412], [332, 490]];
const SICK_ID = 3;
const sickHerd = (look) => HERD.map((h) => (h.id === SICK_ID ? { ...h, breed: look === 'A' ? 'sickA' : 'holstein', pose: 'front' } : h));
function dirtyPill(look, n, bad) {
  return `<div class="dirty${bad ? ' bad' : ''}">${poopIcon(look, 22)}<span>大便 <b class="num">${n}</b></span>${bad ? `<span class="dirty-warn">${icon('warn', 16)}會生病</span>` : ''}</div>`;
}
// gone：清掉的大便（不畫）；poof：剛清掉的位置（畫小星星）
function poopScene(look, { gone = [], poof = [], pop = false, gesture = '' } = {}) {
  const herd = sickHerd(look), left = POOPS.filter((_, i) => !gone.includes(i) && !poof.includes(i));
  const extra = ({ anchors, inv, k }) => {
    const a = anchors[SICK_ID], [cx, cy] = inv(a.face), [, top] = inv(a.head);
    return left.map(([x, y]) => POOP[look](x, y, 19)).join('') + SICK[look]({ cx, cy, r: a.faceR / k, top });
  };
  const overlays = (anchors, map) => {
    let o = poof.map((i) => { const [x, y] = map(POOPS[i]); return `<div class="poof" style="left:${f2(x)}px;top:${f2(y - 8)}px">${icon('sparkle', 16)}${icon('sparkle', 11)}${icon('sparkle', 9)}</div>`; }).join('');
    if (gesture === 'tap') {
      const [x, y] = map(POOPS[poof[0]]);
      o += `<div class="ripple" style="left:${f2(x)}px;top:${f2(y - 8)}px"></div><div class="gesture" style="left:${f2(x - 13)}px;top:${f2(y - 6)}px">${POINTER(38)}</div>`;
    }
    if (gesture === 'swipe') {
      const pts = poof.map((i) => map(POOPS[i]).map((v, j) => (j ? v - 8 : v))).sort((a, b) => a[0] - b[0]);
      const [s0, s1] = [pts[0], pts[pts.length - 1]];
      const start = [s0[0] - 34, s0[1] + 14], end = [s1[0] + 30, s1[1] - 12];
      const d = `M${f2(start[0])} ${f2(start[1])}` + pts.map(([x, y]) => `L${f2(x)} ${f2(y)}`).join('') + `L${f2(end[0])} ${f2(end[1])}`;
      o += `<svg class="swipe-trail" width="${dev.w}" height="${dev.h}" aria-hidden="true"><path d="${d}" fill="none" stroke="#FFFFFF" stroke-width="16" stroke-linecap="round" stroke-linejoin="round" opacity="0.75"/><path d="${d}" fill="none" stroke="${L}" stroke-width="2.4" stroke-dasharray="6 6" stroke-linecap="round" stroke-linejoin="round"/></svg>
        <div class="gesture" style="left:${f2(end[0] - 13)}px;top:${f2(end[1] - 2)}px">${POINTER(38)}</div>`;
    }
    if (pop) {
      const a = anchors[SICK_ID], c = COWS.find((x) => x.id === SICK_ID), b = BREEDS.holstein;
      const chips = [useChip(b.use), `<span class="use">${sexText(c.sex)}</span>`, tierChip(0), `<span class="badge sick">${THERMO(13)}生病了</span>`];
      const left0 = Math.max(12, Math.min(dev.w - 248, a.head[0] - 43));
      o += `<div class="cow-pop sick-pop" data-foot="${a.foot[1]}" data-hx="${a.head[0]}" style="left:${f2(left0)}px;top:${f2(a.head[1] - 14)}px;transform:translateY(-100%)"><div class="name">${breedName('holstein')} #${SICK_ID}</div><div class="chips" style="margin-top:4px">${chips.join('')}</div>
        <div class="meta">不產奶，也不能配種、上架</div><div class="meta">出貨的話，牛肉只剩一成</div>${btn('治療（5,000 幣）', { kind: 'primary', small: true, block: true, ic: 'coin' })}</div>`;
    }
    return o;
  };
  const n = left.length;
  return ranch({ herd, extra, overlays, center: dirtyPill(look, n, n / 10 > 0.5) });
}
function r1304(look) {
  const o = LOOK4[look];
  const tapI = 0, swipeI = [1, 3, 4];
  return board({
    id: `R13-04-大便和病牛-${look}-${o.file}-390`, title: `04 大便、病牛、清大便　${look}：${o.title}`, width: boardWidth(4),
    sub: '每頭牛每 3 小時拉一坨（最多 4 坨），沒上線也會累積；太髒了牛會生病（v0.3 第 5 節）。點一下清一坨，手指劃過去一次清好幾坨。',
    cells: [
      { cap: '牧場裡：9 坨大便、一頭病牛', note: '病牛轉正面看玩家；右上角是還沒清的大便數（提案），髒到會生病時變紅', html: poopScene(look) },
      { cap: '點一下：清掉一坨', note: '冒出小星星；右上角的數字跟著減少', html: poopScene(look, { poof: [tapI], gesture: 'tap' }) },
      { cap: '手指劃過去：一次清好幾坨', note: '劃過的大便全部清掉', html: poopScene(look, { gone: [tapI], poof: swipeI, gesture: 'swipe' }) },
      { cap: '點病牛：治療', note: '名片多一個「生病了」；治療一頭 5,000 幣、馬上好', html: poopScene(look, { gone: [tapI, ...swipeI], pop: true }) },
    ],
    notes: [
      look === 'A' ? '大便：卡通常見的霜淇淋捲，一看就懂。病牛：臉色有一點發青、額頭幾條藍色的線（漫畫裡「不舒服」的畫法）、頭上一個溫度計泡泡。' : '大便：扁扁的一坨（比較像真的牛糞），上面兩條小小的臭味線。病牛：發燒的樣子，臉頰紅通通、頭上一個冰袋、一滴汗。',
      '都是可愛的畫法：沒有蒼蠅，病牛不會倒下、不會流鼻水。',
      '打掃小幫手在牧場裡撿大便的樣子見 01（小幫手的造型選好以後一起畫）。',
    ],
  });
}

// ---------- 05 小牛卡片：可能長出的特徵、要吃的飼料、吃了沒；想吃泡泡；快長大的提醒卡 ----------
const LOOK5 = {
  A: { name: '一個特徵一列', file: '一個特徵一列', title: '卡片一個特徵一列（「長毛 25%・要吃燕麥・還沒吃」）；泡泡寫字「想吃燕麥」' },
  B: { name: '三個飼料格', file: '三個飼料格', title: '卡片三個飼料格（吃過的打勾）；泡泡只畫飼料' },
};
const RULE = '每種吃一次就好；稀有、傳說的少吃一種會變雜種牛';
function traitCard(c, look) {
  if (look === 'A') {
    const rows = ['A', 'B', 'C'].map((k) => {
      const p = c.p[k], fd = TRAIT_FEED[k];
      if (!p) return `<div class="tr-row tr-zero"><span class="tr-name">${TRAIT_NAME[k]}<b class="num tr-p">0%</b></span><span class="grow hint">不會長出來，不用吃${FEED_NAME[fd]}</span></div>`;
      return `<div class="tr-row"><span class="tr-name">${TRAIT_NAME[k]}<b class="num tr-p">${pctTxt(p)}</b></span><span class="grow"><span class="hint">要吃</span>${feedChip(fd)}</span>${c.ate[k] ? `<span class="tr-done">${icon('ok', 18)}吃過了</span>` : '<span class="tr-todo">還沒吃</span>'}</div>`;
    }).join('');
    return `<article class="card trait-card"><div class="card-head"><span class="card-title green">${icon('sparkle', 16)}可能長出的特徵</span><span class="card-sub">長大才揭曉</span></div>${rows}<p class="hint tr-note">${RULE}</p></article>`;
  }
  const slots = ['A', 'B', 'C'].map((k) => {
    const p = c.p[k], fd = TRAIT_FEED[k], st = !p ? 'zero' : c.ate[k] ? 'done' : 'todo';
    return `<div class="fs ${st}">${st === 'done' ? `<span class="fs-mark">${icon('ok', 24)}</span>` : ''}${FEED_IC[fd](34)}<b>${FEED_NAME[fd]}</b><span class="hint">${TRAIT_NAME[k]} <span class="num fs-p">${pctTxt(p)}</span></span>${st === 'done' ? '<span class="tr-done">吃過了</span>' : st === 'todo' ? '<span class="tr-todo">還沒吃</span>' : '<span class="hint">不用吃</span>'}</div>`;
  }).join('');
  return `<article class="card trait-card"><div class="card-head"><span class="card-title green">${icon('sparkle', 16)}長大前要吃的飼料</span><span class="card-sub">可能長出的特徵</span></div><div class="feed-slots">${slots}</div><p class="hint tr-note">${RULE}</p></article>`;
}
// 想吃泡泡：A 寫字（要吃兩種以上時輪流換）；B 只畫飼料（全部一起）
function wantBubble(c, look, a) {
  const w = wants(c);
  if (!w.length) return '';
  const pos = `left:${f2(a.head[0])}px;top:${f2(a.head[1])}px`;
  if (look === 'A') return `<div class="want" style="${pos}">${FEED_IC[w[0]](22)}<span>想吃${FEED_NAME[w[0]]}</span></div>`;
  return `<div class="want think" style="${pos}">${w.map((k) => FEED_IC[k](24)).join('')}</div>`;
}
function growAlert(c, look) {
  const w = wants(c);
  const why = look === 'A' ? `還沒吃${w.map((k) => FEED_NAME[k]).join('、')}（${w.map((k) => `${TRAIT_NAME[FEED_TRAIT[k]]} ${pctTxt(c.p[FEED_TRAIT[k]])}`).join('、')}）`
    : `還沒吃：${w.map((k) => `<span class="ga-feed">${FEED_IC[k](18)}${FEED_NAME[k]}</span>`).join('')}`;
  return `<div class="grow-alert card"><span class="ga-pic">${calfArt(c, 'A', { w: 52, h: 52, pad: 2, top: 3 })}</span><div class="grow"><b>${calfName(c)} 再 ${dur(c.grow_)}就長大</b><p>${why}</p></div>
    <button class="btn small primary ga-go"><span>去餵食</span></button><button class="bn-close" aria-label="${t('g.close')}">${icon('close', 18)}</button></div>`;
}
function feedLine(c, look) {
  const ks = ['A', 'B', 'C'].filter((k) => c.p[k] > 0);
  if (look === 'A') {
    return ks.map((k) => `<div class="meta fl-row">${TRAIT_NAME[k]} ${pctTxt(c.p[k])}・要吃${FEED_NAME[TRAIT_FEED[k]]} ${c.ate[k] ? `<span class="tr-done">${icon('ok', 13)}</span>` : '<span class="tr-todo">還沒吃</span>'}</div>`).join('');
  }
  return `<div class="fl-icons">${ks.map((k) => `<span class="fl-ic${c.ate[k] ? ' done' : ''}">${FEED_IC[TRAIT_FEED[k]](20)}${c.ate[k] ? `<i>${icon('ok', 12)}</i>` : ''}</span>`).join('')}${ks.every((k) => c.ate[k]) ? '<span class="tr-done">都吃過了</span>' : ''}</div>`;
}
const herd05 = () => herdWithCalves('A');
const detail05 = (look) => calfPage(CALVES[15], 'A', { traits: traitCard(CALVES[15], look) });
const bubbles05 = (look) => { const herd = herd05(); return ranch({ herd, pen: PEN13, extra: calfExtras(herd, 'A'), overlays: (an) => [15, 21, 22].map((id) => wantBubble(CALVES[id], look, an[id])).join('') }); };
function r1305(look) {
  const o = LOOK5[look], herd = herd05();
  const rows = [15, 21, 22].map((id) => calfRow(CALVES[id], 'A', feedLine(CALVES[id], look))).concat([cowListRow(COWS.find((c) => c.id === 3))]);
  return board({
    id: `R13-05-小牛卡片-${look}-${o.file}-390`, title: `05 小牛卡片和想吃泡泡　${look}：${o.title}`, width: boardWidth(4),
    sub: '使用者：「要提醒用戶要吃啥」。機率是事前機率（照爸媽的基因或商店公開的機率），不是答案（v0.3 第 1 節）。小牛的樣子先用 02-A，照使用者選的換。',
    cells: [
      { cap: '小牛的詳細', note: '燕麥還沒吃、苜蓿吃過了、光澤 0% 不用吃玉米', html: detail05(look) },
      { cap: '牧場：小牛頭上的泡泡', note: look === 'A' ? '還沒吃、機率大於 0 的飼料；要吃兩種以上時每 3 秒換一種' : '還沒吃、機率大於 0 的飼料，幾種就畫幾個', html: bubbles05(look) },
      { cap: '快長大了：提醒卡', note: '再 1 小時內長大、還有沒吃的飼料：跳一次（一頭一張，可以關）', html: ranch({ herd, pen: PEN13, extra: calfExtras(herd, 'A'), overlays: growAlert(CALVES[15], look) }) },
      { cap: '牛舍清單', note: look === 'A' ? '一個特徵一行（0% 的不寫）' : '一排飼料小圖，吃過的打勾', html: listPage(rows) },
    ],
    notes: [
      '「餵食」按下去選飼料、吃飽冷卻、全部餵一樣的，不在這一輪（使用者選完一起畫進 M2）。',
      '長大倒數照稀有度（一般 1、優良 2、稀有 4、傳說 8 小時），倒數很長的小牛會被猜出是稀有、傳說：要不要讓倒數都一樣，請 ceo 決定。',
    ],
  });
}

// ---------- 01 打掃小幫手 ----------
const LOOK1 = {
  A: { file: '吊帶褲和馬尾', alt: ['阿穗姐', '穗穗姐'], tool: [62, 534], mood: '元氣派：馬尾跟著跑來跑去；吊帶褲是最典型的牧場工作服。', wear: '短袖襯衫加吊帶褲（袖子到手肘）、頭巾、雨鞋、工作手套' },
  B: { file: '圍裙和草帽', alt: ['夏夏姐', '千千姐'], tool: [213, 520], mood: '溫柔派：草帽、圍裙、側邊辮子，像隔壁牧場的大姊姊。', wear: '長袖連身裙（長度過膝）、圍裙、草帽、短靴' },
  C: { file: '連身工作服和帽子', alt: ['葵姐', '葵花姐'], tool: [80, 518], mood: '可靠派：連身工作服、一手叉腰、一手扶著鏟子，做事俐落。', wear: '長袖連身工作服（袖子捲到前臂）、帽子、小領巾、雨鞋' },
};
const HS = 0.21; // 場景裡的大小：身高約 115（成年牛約 70–90）
// 牧場裡：小幫手在前排撿大便；還剩 3 坨，清掉的地方冒小星星；右上角換成「打掃中」（提案）
function helperScene(look) {
  const o = LOOK1[look], left = [[236, 398], [38, 498], [362, 448]], done = [[284, 472], [132, 412]];
  const x0 = 250 - 150 * HS, y0 = 505 - 546 * HS, [tx, ty] = [x0 + o.tool[0] * HS, y0 + o.tool[1] * HS];
  const extra = () => left.map(([x, y]) => poopA(x, y, 19)).join('')
    + `<g transform="translate(${f2(x0)} ${f2(y0)}) scale(${HS})">${helperInner(look, { lineK: 2 })}</g>` + poopA(tx, ty - 1, 12);
  const overlays = (an, map) => done.map(([x, y]) => { const [sx, sy] = map([x, y]); return `<div class="poof" style="left:${f2(sx)}px;top:${f2(sy - 8)}px">${icon('sparkle', 16)}${icon('sparkle', 11)}${icon('sparkle', 9)}</div>`; }).join('');
  const pill = `<div class="dirty helper-pill">${helperFace(look, 30)}<span><b>${HELPERS[look].name}</b> 打掃中</span><span class="hp-left">還有 6 天</span></div>`;
  return ranch({ extra, overlays, center: pill });
}
function rateCard() {
  return `<div class="rate-card">
    <h3>預估的商店年齡分級（只看小幫手）</h3>
    <div class="rate-row"><span class="rate-store">App Store</span><b class="rate-big">4+</b></div>
    <p>年齡分級問卷的「Mature or Suggestive Themes」（性暗示）、「Sexual Content or Nudity」（性內容或裸露）都答「None」→ 4+。<span class="hint">（答 Infrequent 會變 9+、13+）</span></p>
    <div class="rate-row"><span class="rate-store">Google Play</span><b class="rate-big">3 歲以上</b></div>
    <p>IARC 問卷跟性有關的題目（性暗示、裸露）都答「沒有」→ 台灣、泰國顯示「3 歲以上」；美國 ESRB 是 Everyone、歐洲 PEGI 3。</p>
    <p class="hint">整個 app 的分級還要看其他題目（例如商店抽牛），不只看小幫手。</p>
  </div>`;
}
function r1301(look) {
  const o = LOOK1[look], h = HELPERS[look];
  const fig = `<div class="hp-card"><div class="hp-bg"></div>${helperSVG(look, { w: 340, h: 635 })}</div>`;
  const info = `<div class="hp-info">
    <div class="hp-names"><span class="hp-av">${helperFace(look, 64)}</span><div><b>${h.name}</b><span>備選：${o.alt.join('、')}</span></div></div>
    <p class="hp-mood">${o.mood}</p>
    ${rateCard()}
    <ul class="hp-why"><li>成年女性：約 5 頭身、大人的臉和身材，名字用「姐」</li><li>穿著：${o.wear}；沒有露出的衣服</li><li>身材比一般角色豐滿一點；一般站姿，沒有特寫、刻意的角度或晃動的動畫</li></ul>
  </div>`;
  return board({
    id: `R13-01-打掃小幫手-${look}-${o.file}-390`, title: `01 打掃小幫手　${look}：${h.name}（${h.outfit}）`, width: boardWidth(3),
    sub: '成年的牧場大姊姊，日系可愛的畫法；雇用以後在牧場裡走來走去撿大便（v0.3 第 5.1 節）。三個造型共用同一個身體，換髮型、衣服、工具。',
    cells: [
      { cap: '全身', note: '撿大便的工具也一起畫', html: fig },
      { cap: '牧場裡：撿大便', note: '縮小放進場景（身高比成年牛高一點）；右上角換成「打掃中」（提案）', html: helperScene(look) },
      { cap: '名字、分級', note: '名字用「姐」，一看就是大人', html: info },
    ],
    notes: [
      '雇用：一天 800 幣、最多先付 7 天；雇用期間每 30 分鐘清掉全部大便（v0.3 第 5.1 節）。商店的雇用畫面、走路的動畫，使用者選好造型以後再畫。場景裡的大便先用 04-A 的樣子，照使用者選的換。',
      '分級是 cow-ui 照 Apple、Google 現在的問卷估的（2026-10 查過）；送審時照 app 的實際內容回答。再畫得更豐滿很多、加特寫或晃動的動畫，可能被認定有性暗示，分級會變高。',
    ],
  });
}

// ---------- 總覽：五項都要選，每項一排、選項並排 ----------
function r1399() {
  const S = 0.6, sw = Math.round(dev.w * S), sh = Math.round(dev.h * S);
  const mini = (html) => `<div class="ov-ph" style="width:${sw}px;height:${sh}px"><div style="transform:scale(${S});transform-origin:0 0">${html}</div></div>`;
  const cell = (cap, inner, sub = '') => `<div class="ov-cell"><div class="ov-cap"><b>${cap}</b>${sub ? `<span class="ov-sub">${sub}</span>` : ''}</div>${inner}</div>`;
  const grid6 = (keyOf, extra, art) => `<div class="ov-grid">${['cow', 'bull'].map((sex) => USES.map((u) => art(u, sex, pairK(keyOf(u), extra, { w: 110, h: 96, top: 10 }))).join('')).join('')}</div>`;
  const calfGrid = (look) => grid6((u) => calfKey(look, u), { age: 'calf' }, (u, sex, k) => calfArt({ use: u, sex }, look, { w: 110, h: 96, k }));
  const mixGrid = (look) => grid6((u) => mixKey(look, u), {}, (u, sex, k) => cowArt({ breed: mixKey(look, u), sex }, { w: 110, h: 96, top: 10, k }));
  const rows = [
    ['01 打掃小幫手：選一個造型（名字也可以換）', ['A', 'B', 'C'].map((k) => cell(`${k}　${HELPERS[k].name}`, `<div class="ov-fig">${helperSVG(k, { w: 200, h: 373 })}</div>`, HELPERS[k].outfit))],
    ['02 小牛的 6 種樣子（上排母、下排公；左到右乳牛、耕牛、肉牛）', ['A', 'B'].map((k) => cell(`${k}　${LOOK2[k].name}`, calfGrid(k)))],
    ['03 雜種牛（上排母、下排公；左到右乳牛、耕牛、肉牛）', ['A', 'B'].map((k) => cell(`${k}　${LOOK3[k].name}`, mixGrid(k)))],
    ['04 大便、病牛（點一下或劃過去清掉，兩個方向都一樣）', ['A', 'B'].map((k) => cell(`${k}　${LOOK4[k].name}`, mini(poopScene(k))))],
    ['05 小牛卡片、想吃泡泡', ['A', 'B'].map((k) => cell(`${k}　${LOOK5[k].name}`, `<div class="ov-pair">${mini(detail05(k))}${mini(bubbles05(k))}</div>`))],
  ];
  const body = rows.map(([title, cs]) => `<div class="ov-row"><div class="ov-title">${title}</div><div class="ov-cells">${cs.join('')}</div></div>`).join('');
  return { html: `<div class="board" style="width:${PAD * 2 + 4 * sw + 3 * 28 + 28}px"><div class="b-label">R13-99-總覽對照</div><div class="b-title">第 13 輪：照顧牧場（v0.3）要選的五項</div>
    <div class="b-sub">每一項選一個；各自的大圖見 R13-01～05。</div>${body}</div>` };
}

// ---------- 說明圖清單 ----------
const BOARDS = [
  ...['A', 'B', 'C'].map((k) => ({ id: `R13-01-${k}`, w: 390, render: () => r1301(k) })),
  ...['A', 'B'].map((k) => ({ id: `R13-02-${k}`, w: 390, render: () => r1302(k) })),
  ...['A', 'B'].map((k) => ({ id: `R13-03-${k}`, w: 390, render: () => r1303(k) })),
  ...['A', 'B'].map((k) => ({ id: `R13-04-${k}`, w: 390, render: () => r1304(k) })),
  ...['A', 'B'].map((k) => ({ id: `R13-05-${k}`, w: 390, render: () => r1305(k) })),
  { id: 'R13-99', w: 390, render: r1399 },
];

async function settle() {
  await document.fonts.ready;
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
}
if (q.has('list')) {
  window.__boards = BOARDS.map(({ id, w }) => ({ id, w }));
  window.__ready = true;
} else {
  const b = BOARDS.find((x) => x.id === q.get('b'));
  if (!b) throw new Error(`沒有這張：${q.get('b')}`);
  const out = b.render();
  app.innerHTML = out.html;
  addPencil(app);
  await settle();
  if (out.after) await out.after(app);
  await settle();
  // 跟 m2 的 main.js 一樣的調整（繁中 390 都不會變，照樣跑）
  if (fitTitles(app)) await settle();
  if (fitOriginTags(app) + placeVersion(app)) await settle();
  if (fitSwipeHint(app) + fitMiniLines(app)) await settle();
  if (placeCowPop(app)) await settle();
  if (fitGrade(app)) await settle();
  if (fitActions(app)) await settle();
  const el = app.querySelector('.board');
  window.__file = el.querySelector('.b-label').textContent;
  window.__size = { w: Math.ceil(el.offsetWidth), h: Math.ceil(el.offsetHeight) };
  window.__ready = true;
}
