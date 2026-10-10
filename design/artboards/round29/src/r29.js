// 第 29 輪草稿（ceo 2026-10-10 轉達使用者看完第 25–28 輪的回答；D35 補充 10、v0.3 第 2、5、13 節）：
//   01 掃地牛五種（特別牛）：大圖、小牛。B3 照 B1 的風格重畫：四隻腳、吊帶褲畫在身上。
//   02 掃地牛的格式（用 A 當例子，照第 15 輪特殊牛的格式）：圖鑑「其他」、圖鑑詳細（已發現、還沒發現）、牧場裡點牛的名片、牛的詳細。
//   03 掃地牛在牧場清大便（五種各一張＋GIF）：拿掉雇用面板和右上角「打掃中」，牠就是牧場裡的一頭牛。
//   04、05 掃地機：乳牛紋圓盤拿掉表情、兩款拿掉底下的觸鬚、右上角不顯示「掃地中」；耐久值（點機器、購買面板）；壞了重新買（不能修）；價錢待定。
//   06 飼料列：沒有底板、袋子下面不寫公斤數；收起時奶桶跟飼料一起收；吃完頭上跳這次長了幾公斤（隨機）；餓了才出現空碗加問號。
//   07 大便第 10 坨以後：右半邊 9 個位置（ceo 定先鏡射、cow-ui 看過再調；cow-app #200 已經照這個清單做）。
// 元件、字串、假資料、牛的產生器都用 M2 設計稿（design/m2）。畫牛的工具從第 25 輪複製（src/r11h.js 是 M2 產生器的複製，只多選項）。
// 新的字是草稿，直接寫在這裡，沒有進字串表：使用者看過才加 key、翻英文和泰文（D25）。
// 網址：r29.html?b=R29-01；GIF：r29.html?gif=A；?list=1 列出全部說明圖和 GIF。
import { applyDevice, frame, btn, icon, badge, cowSVG, useChip, sheet, toast, bar, seg, tierChip, mixStar, fitTitles, fitOriginTags, placeVersion, placeCowPop, BREEDS } from '../../../m2/src/js/kit.js';
import { loadLang, t, tierName, sexName } from '../../../m2/src/js/i18n.js';
import { FOUND } from '../../../m2/src/js/fixtures.js';
import { HERD, WIDE, ranchScene } from '../../../m2/src/js/scene.js';
import { poopG, POOP_SPOTS } from '../../../m2/src/js/poop.js';
import { FEED_KEYS } from '../../../m2/src/js/feeds.js';
import { MIX_LOOK, genesFor } from '../../../m2/src/cow/breeds.js';
import { calfBow } from '../../../m2/src/cow/calf.js';
import { smoothPath } from '../../../m2/src/cow/q.js';
import { renderCow as renderR } from './r11h.js';

const L = '#4B3326';
const f2 = (v) => Math.round(v * 100) / 100;
const lerp = (a, b, k) => a + (b - a) * k;
const clamp01 = (v) => Math.max(0, Math.min(1, v));
const ease = (u) => { const k = clamp01(u); return k * k * (3 - 2 * k); };
const span = (tt, a, b) => clamp01((tt - a) / (b - a));

// ---------- 草稿用的牛：掃地牛五種、特殊牛三種（只在這一頁加進 BREEDS，名字用草稿字串） ----------
const DRAFT_STR = {};
const realFetch = window.fetch.bind(window);
window.fetch = async (u, o) => {
  if (typeof u !== 'string' || !u.startsWith('../i18n/')) return realFetch(u, o);
  const r = await realFetch(`../../../m2/${u.slice(3)}`, o);
  if (!u.endsWith('zh-Hant.json')) return r;
  return new Response(JSON.stringify({ ...(await r.json()), ...DRAFT_STR }), { headers: { 'Content-Type': 'application/json' } });
};
// 掃地牛（v0.3 第 5.1 節）：造型照第 25 輪；用途照長相（A、C 乳牛，B 系耕牛，ceo 定）。牛的身體、毛色用核准的產生器（breed、seed）
const SWEEP = {
  A: { name: '頭巾掃地牛', use: 'dairy', breed: 'holstein', sex: 'cow', seed: 52, kind: 'stand', tool: 'broom', lean: 2,
    look: '黑白花乳牛、紅色點點頭巾；用後腳站著，兩隻手握掃把', intro: '黑白花的乳牛綁著紅色點點頭巾，用後腳站起來、兩隻手握著掃把，把牧場掃得乾乾淨淨。', act: '掃把左右掃，大便不見、冒星星', calf: '頭上綁頭巾，還不會拿掃把' },
  B1: { name: '背心推車牛', use: 'draft', breed: 'yellow', sex: 'cow', seed: 61, kind: 'side', outfit: 'vest',
    look: '台灣黃牛、橘色工作背心；四隻腳拉小推車', intro: '台灣黃牛穿著橘色的工作背心，拉著小推車，把大便一坨一坨收進車裡。', act: '大便飛進後面的推車', calf: '小背心，還沒有推車' },
  B2: { name: '領巾推車牛', use: 'draft', breed: 'yellow', sex: 'cow', seed: 61, kind: 'side', outfit: 'scarf',
    look: '台灣黃牛、紅色點點領巾、前腳藍白袖套；四隻腳拉小推車', intro: '台灣黃牛圍著紅色點點領巾、前腳套著袖套，拉著小推車收大便。', act: '大便飛進後面的推車', calf: '領巾和袖套，還沒有推車' },
  B3: { name: '吊帶褲推車牛', use: 'draft', breed: 'yellow', sex: 'cow', seed: 61, kind: 'side', outfit: 'overalls',
    look: '台灣黃牛、牛仔吊帶褲畫在身上；四隻腳拉小推車', intro: '台灣黃牛穿著牛仔吊帶褲，後腳是捲起來的褲管，拉著小推車收大便。', act: '大便飛進後面的推車', calf: '小吊帶褲，還沒有推車' },
  C: { name: '草帽鏟子牛', use: 'dairy', breed: 'jersey', sex: 'cow', seed: 73, kind: 'stand', tool: 'shovel', lean: 6,
    look: '娟珊牛、草帽；用後腳站著，兩隻手握鏟子，水桶放在地上', intro: '娟珊牛戴著草帽，用後腳站起來、兩隻手握著鏟子，把大便鏟進水桶。', act: '鏟起來、抬到水桶上面倒進去', calf: '頭上戴草帽，還不會拿鏟子' },
};
const SW = Object.keys(SWEEP);
const swKey = (k) => `sweep${k}`;
const SPECIAL4 = { s1: 1, s2: 1, s3: 1, s4: 1 }; // 只給 tierOf 數到 4（特殊牛 5 顆彩虹星）；不是 A、B、C，不影響長相
for (const [k, o] of Object.entries(SWEEP)) {
  BREEDS[swKey(k)] = { ...BREEDS[o.breed], name: o.name, use: o.use, traits: SPECIAL4, special: true, sweep: k };
  DRAFT_STR[`breed.${swKey(k)}.name`] = o.name;
}
// 特殊牛三種（第 15 輪）：這一輪只畫還沒發現的影子
const MYTH = { zeus: { name: '宙斯牛', use: 'beef', base: 'charolais' }, azure: { name: '青牛', use: 'draft', base: 'yellow' }, holyWhite: { name: '聖白牛', use: 'dairy', base: 'holstein' } };
for (const [k, o] of Object.entries(MYTH)) {
  BREEDS[k] = { ...BREEDS[o.base], name: o.name, use: o.use, traits: SPECIAL4, special: true };
  DRAFT_STR[`breed.${k}.name`] = o.name;
}

const q = new URLSearchParams(location.search);
const W = +(q.get('w') || 390);
const dev = applyDevice(W);
const app = document.getElementById('app');
await loadLang('zh-Hant');
const { ranchPage, dirtyPill } = await import('../../../m2/src/js/screens/s03.js');
const { detailPage } = await import('../../../m2/src/js/screens/s04.js');
const ctx0 = () => ({ dev, w: dev.w, q: new URLSearchParams() });

// ---------- 說明圖的版面（跟第 18 輪一樣） ----------
const PAD = 36, GAP = 40;
const boardWidth = (cols) => PAD * 2 + cols * dev.w + (cols - 1) * GAP;
function board({ id, title, sub = '', top = '', cells = [], cols = cells.length, notes = [], width, body = '' }) {
  const wpx = width || boardWidth(cols);
  const html = `<div class="board" style="width:${wpx}px">
    <div class="b-label">${id}</div>
    <div class="b-title">${title}</div>${sub ? `<div class="b-sub">${sub}</div>` : ''}
    ${top}
    ${cells.length ? `<div class="b-row" style="grid-template-columns:repeat(${cols}, ${dev.w}px)">${cells.map((c) => `<figure class="b-cell"><figcaption><b>${c.cap}</b>${c.note || ''}</figcaption>${c.html}</figure>`).join('')}</div>` : ''}
    ${body}
    ${notes.length ? `<ul class="b-notes">${notes.map((n) => `<li>${n}</li>`).join('')}</ul>` : ''}
  </div>`;
  return { html };
}
const POINTER = (s = 34) => `<svg viewBox="0 0 32 34" width="${s}" height="${Math.round(s * 34 / 32)}" aria-hidden="true"><path d="M11 4.4a2.3 2.3 0 0 1 4.6 0v9.8l1.2-.3a2.1 2.1 0 0 1 2.6 1.5l.1.5 1.1-.2a2.1 2.1 0 0 1 2.5 1.6l.1.5h.8a2.1 2.1 0 0 1 2.2 2.1v4.6c0 4.8-3.3 8.1-7.9 8.1h-1.5c-2.7 0-4.6-1.1-6.2-3.4l-4.8-6.7a2.1 2.1 0 0 1 3.1-2.8l2.1 2.3z" fill="#FFE3D2" stroke="${L}" stroke-width="2" stroke-linejoin="round"/><path d="M15.6 14.2v3.6M19.5 15.4v2.8M23.2 17.1v2" stroke="${L}" stroke-width="1.6" stroke-linecap="round"/></svg>`;
// (x, y)：指尖的位置（手機座標）；press：按下去（縮一點、加一圈）
const finger = (x, y, press = 0, s = 40) => `<div class="gesture" style="left:${f2(x - 13 * s / 32)}px;top:${f2(y - 2)}px;transform:scale(${f2(1 - 0.08 * press)})">${POINTER(s)}</div>${press ? `<span class="r29-tap" style="left:${f2(x - 18)}px;top:${f2(y - 18)}px"></span>` : ''}`;
// 小掃把圖示（M2 的圖示沒有掃把；草稿先畫在這裡）
const broomIc = (s = 16) => `<span class="r29-broom"><svg viewBox="0 0 20 20" width="${s}" height="${s}" aria-hidden="true"><path d="M13.6 2.4L9.2 9.4" stroke="${L}" stroke-width="3.6" stroke-linecap="round"/><path d="M13.6 2.4L9.2 9.4" stroke="#C98E5E" stroke-width="1.8" stroke-linecap="round"/><path d="M8.2 8.2l3.2 2-2.6 7.4q-3.4.2-6.4-3.6z" fill="#F0CD6E" stroke="${L}" stroke-width="1.5" stroke-linejoin="round"/><path d="M7 11.6l-2.6 3M8.6 12.8l-2.4 3.8" stroke="#C99A34" stroke-width="1"/></svg></span>`;

// ================= 掃地牛：核准的牛產生器＋配件（第 25 輪的畫法） =================
const SIDE_S = 0.9; // 場景裡的大小（跟中間那排的牛差不多）
const stick = (x0, y0, x1, y1, w = 3.2) => `<path d="M${f2(x0)} ${f2(y0)}L${f2(x1)} ${f2(y1)}" stroke="${L}" stroke-width="${w + 2.4}" stroke-linecap="round"/><path d="M${f2(x0)} ${f2(y0)}L${f2(x1)} ${f2(y1)}" stroke="#C98E5E" stroke-width="${w}" stroke-linecap="round"/>`;
// 紅色點點頭巾（蓋在頭頂，後面打一個結）。front：正面的頭（站著的掃地牛）；側面的頭（小牛）
function bandana(g, front) {
  const { fx, fy, fr, back } = g;
  const y0 = fy - fr * (front ? 0.35 : 0.15), top = fy - fr * 1.75, w = fr * (front ? 0.92 : 0.98);
  const d = `M${f2(fx - w)} ${f2(y0)}Q${f2(fx)} ${f2(top)} ${f2(fx + w)} ${f2(y0)}Q${f2(fx)} ${f2(y0 - fr * 0.42)} ${f2(fx - w)} ${f2(y0)}Z`;
  const kx = front ? fx + w * 0.92 : fx + back * w * 0.92, ky = y0 - fr * 0.12, kd = front ? 1 : back;
  const knot = `<path d="M${f2(kx)} ${f2(ky)}l${f2(kd * fr * 0.55)} ${f2(-fr * 0.25)}l${f2(-kd * fr * 0.12)} ${f2(fr * 0.42)}Z M${f2(kx)} ${f2(ky)}l${f2(kd * fr * 0.5)} ${f2(fr * 0.3)}l${f2(-kd * fr * 0.28)} ${f2(fr * 0.2)}Z" fill="#E5484D" stroke="${L}" stroke-width="1.6" stroke-linejoin="round"/>`;
  const dots = [[-0.45, 0.3], [0, 0.42], [0.45, 0.3], [-0.2, 0.55], [0.25, 0.55]].map(([u, v]) => `<circle cx="${f2(fx + u * w)}" cy="${f2(y0 - v * (y0 - top) * 0.62)}" r="${f2(fr * 0.07)}" fill="#FFFFFF"/>`).join('');
  return `${knot}<path d="${d}" fill="#E5484D" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/>${dots}`;
}
// 草帽（帽緣橢圓＋帽頂＋紅緞帶）
function strawHat(g) {
  const { fx, fy, fr } = g, by = fy - fr * 0.8;
  return `<ellipse cx="${f2(fx)}" cy="${f2(by)}" rx="${f2(fr * 1.4)}" ry="${f2(fr * 0.34)}" fill="#F2D27A" stroke="${L}" stroke-width="1.8"/>
    <path d="M${f2(fx - fr * 0.7)} ${f2(by)}C${f2(fx - fr * 0.72)} ${f2(by - fr * 0.95)} ${f2(fx + fr * 0.72)} ${f2(by - fr * 0.95)} ${f2(fx + fr * 0.7)} ${f2(by)}Z" fill="#F2D27A" stroke="${L}" stroke-width="1.8"/>
    <path d="M${f2(fx - fr * 0.7)} ${f2(by - fr * 0.06)}C${f2(fx - fr * 0.3)} ${f2(by + fr * 0.06)} ${f2(fx + fr * 0.3)} ${f2(by + fr * 0.06)} ${f2(fx + fr * 0.7)} ${f2(by - fr * 0.06)}L${f2(fx + fr * 0.7)} ${f2(by - fr * 0.26)}C${f2(fx + fr * 0.3)} ${f2(by - fr * 0.16)} ${f2(fx - fr * 0.3)} ${f2(by - fr * 0.16)} ${f2(fx - fr * 0.7)} ${f2(by - fr * 0.26)}Z" fill="#E5484D" stroke="${L}" stroke-width="1.2"/>
    <path d="M${f2(fx - fr * 1.1)} ${f2(by + fr * 0.05)}Q${f2(fx)} ${f2(by + fr * 0.22)} ${f2(fx + fr * 1.1)} ${f2(by + fr * 0.05)}" fill="none" stroke="#D9AE4E" stroke-width="1.2"/>`;
}
// 水桶（裡面有幾坨）
const bucket = (x, y, s, poops = 0) => `<g transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s)})"><path d="M-8 -14Q0 -22 8 -14" fill="none" stroke="${L}" stroke-width="1.6"/>${poops ? poopG(0, -8, 9) : ''}<path d="M-9 -10L9 -10L7 4L-7 4Z" fill="#7FB3E0" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/><path d="M-8.4 -6.4H8.4" stroke="#5B8FD9" stroke-width="1.6"/></g>`;
// 小推車（木箱、一個輪子；裡面是收走的大便）
function cart(x, y, s, n = 0) {
  const poops = [[-9, -14], [4, -15], [-2, -18]].slice(0, n).map(([px, py]) => poopG(px, py, 11)).join('');
  return `<g transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s)})">${poops}<path d="M-20 -14L20 -14L16 4L-16 4Z" fill="#D9A066" stroke="${L}" stroke-width="2" stroke-linejoin="round"/>
    <path d="M-18 -8H18M-17 -2H17" stroke="#B57B45" stroke-width="1.4"/><circle cx="0" cy="8" r="7" fill="#8C6A4A" stroke="${L}" stroke-width="2"/><circle cx="0" cy="8" r="2.4" fill="#F0CD6E" stroke="${L}" stroke-width="1"/></g>`;
}
const hexMix = (a, b, k) => { const p = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)); const A = p(a), B = p(b); return `#${A.map((v, i) => Math.round(v + (B[i] - v) * k).toString(16).padStart(2, '0')).join('')}`; };
const limb = (x0, y0, x1, y1, w, fill) => `<path d="M${f2(x0)} ${f2(y0)}L${f2(x1)} ${f2(y1)}" stroke="${L}" stroke-width="${f2(w + 2.6)}" stroke-linecap="round"/><path d="M${f2(x0)} ${f2(y0)}L${f2(x1)} ${f2(y1)}" stroke="${fill}" stroke-width="${f2(w)}" stroke-linecap="round"/>`;
function headOf(C, s, id) {
  const gn = genesFor({ breed: C.breed, sex: C.sex, seed: C.seed });
  return { gn, r: renderR('r11', gn, { pose: 'front', scale: s, id, headOnly: true }) };
}
function smoothClosedD(pts) {
  const n = pts.length, P = (i) => pts[(i + n) % n];
  let d = `M${f2(pts[0][0])} ${f2(pts[0][1])}`;
  for (let i = 0; i < n; i++) { const p0 = P(i - 1), p1 = P(i), p2 = P(i + 1), p3 = P(i + 2); d += `C${f2(p1[0] + (p2[0] - p0[0]) / 6)} ${f2(p1[1] + (p2[1] - p0[1]) / 6)} ${f2(p2[0] - (p3[0] - p1[0]) / 6)} ${f2(p2[1] - (p3[1] - p1[1]) / 6)} ${f2(p2[0])} ${f2(p2[1])}`; }
  return d + 'Z';
}
const rotP = (p, c, deg) => { const a = (deg * Math.PI) / 180, dx = p[0] - c[0], dy = p[1] - c[1]; return [c[0] + dx * Math.cos(a) - dy * Math.sin(a), c[1] + dx * Math.sin(a) + dy * Math.cos(a)]; };
const addV = (a, b, k = 1) => [a[0] + b[0] * k, a[1] + b[1] * k];
const subV = (a, b) => [a[0] - b[0], a[1] - b[1]];
const lenV = (v) => Math.hypot(v[0], v[1]);
const normV = (v) => { const l = lenV(v) || 1; return [v[0] / l, v[1] / l]; };
const mix2 = (a, b, k) => [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k];
const angOf = (v) => (Math.atan2(v[1], v[0]) * 180) / Math.PI;
const pt = (p) => `${f2(p[0])} ${f2(p[1])}`;
function arm(sh, hd, w, fill, elbow) {
  const c = addV(mix2(sh, hd, 0.5), elbow), d = `M${pt(sh)}Q${pt(c)} ${pt(hd)}`;
  return `<path d="${d}" fill="none" stroke="${L}" stroke-width="${f2(w + 2.6)}" stroke-linecap="round"/><path d="${d}" fill="none" stroke="${fill}" stroke-width="${f2(w)}" stroke-linecap="round"/>`;
}
const shoulderCap = (sh, w, fill) => `<circle cx="${f2(sh[0])}" cy="${f2(sh[1])}" r="${f2(w * 0.5)}" fill="${fill}"/>`;
function hoofHand(p, ang, r) {
  return `<g transform="translate(${pt(p)}) rotate(${f2(ang)})"><path d="M${f2(-r * 0.8)} ${f2(-r * 1.0)}Q${f2(r * 0.95)} ${f2(-r * 1.15)} ${f2(r * 0.85)} 0Q${f2(r * 0.95)} ${f2(r * 1.15)} ${f2(-r * 0.8)} ${f2(r * 1.0)}Q${f2(-r * 1.1)} 0 ${f2(-r * 0.8)} ${f2(-r * 1.0)}Z" fill="#5A4A42" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/>
    <path d="M${f2(r * 0.86)} 0H${f2(r * 0.15)}" stroke="#3A2E28" stroke-width="1.4" stroke-linecap="round"/><path d="M${f2(-r * 0.4)} ${f2(-r * 0.62)}Q${f2(r * 0.1)} ${f2(-r * 0.78)} ${f2(r * 0.42)} ${f2(-r * 0.6)}" fill="none" stroke="#8A7468" stroke-width="1.4" stroke-linecap="round"/></g>`;
}
function standFoot(c, fr, sd) {
  return `<g transform="translate(${pt(c)}) rotate(${f2(sd * 6)})"><path d="M${f2(-0.3 * fr)} ${f2(0.09 * fr)}Q${f2(-0.33 * fr)} ${f2(-0.16 * fr)} 0 ${f2(-0.18 * fr)}Q${f2(0.33 * fr)} ${f2(-0.16 * fr)} ${f2(0.3 * fr)} ${f2(0.09 * fr)}Z" fill="#5A4A42" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/><path d="M0 ${f2(-0.17 * fr)}V${f2(0.08 * fr)}" stroke="#3A2E28" stroke-width="1.4"/><path d="M${f2(-0.18 * fr)} ${f2(-0.1 * fr)}Q${f2(-0.1 * fr)} ${f2(-0.14 * fr)} ${f2(-0.02 * fr)} ${f2(-0.12 * fr)}" fill="none" stroke="#8A7468" stroke-width="1.3" stroke-linecap="round"/></g>`;
}
const stick2 = (a, b, w) => `<path d="M${pt(a)}L${pt(b)}" stroke="${L}" stroke-width="${f2(w + 2.4)}" stroke-linecap="round"/><path d="M${pt(a)}L${pt(b)}" stroke="#C98E5E" stroke-width="${f2(w)}" stroke-linecap="round"/><path d="M${pt(addV(a, normV([-(b[1] - a[1]), b[0] - a[0]]), -w * 0.22))}L${pt(addV(b, normV([-(b[1] - a[1]), b[0] - a[0]]), -w * 0.22))}" stroke="#E5B887" stroke-width="${f2(w * 0.3)}" stroke-linecap="round"/>`;
function broom2(g, v, ground, fr) {
  const n = [-v[1], v[0]], w0 = 0.13 * fr, w1 = 0.42 * fr, bot = [g[0] + v[0] * 0.15 * fr, ground];
  const a = addV(g, n, w0), b = addV(g, n, -w0), c = [bot[0] - w1, ground], d = [bot[0] + w1, ground];
  const left = a[0] < b[0] ? [a, b] : [b, a];
  const poly = `M${pt(left[0])}L${pt(left[1])}L${pt(d)}Q${pt([bot[0], ground + 0.06 * fr])} ${pt(c)}Z`;
  const strands = [0.15, 0.32, 0.5, 0.68, 0.85].map((k) => `M${pt(mix2(left[0], left[1], k))}L${pt([c[0] + (d[0] - c[0]) * k, ground - 0.02 * fr])}`).join('');
  const band = `M${pt(addV(a, v, -0.06 * fr))}L${pt(addV(b, v, -0.06 * fr))}L${pt(addV(b, v, 0.1 * fr))}L${pt(addV(a, v, 0.1 * fr))}Z`;
  return `<path d="${poly}" fill="#F0CD6E" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/><path d="${strands}" stroke="#C99A34" stroke-width="1.2" stroke-linecap="round"/><path d="${band}" fill="#D2553B" stroke="${L}" stroke-width="1.5" stroke-linejoin="round"/>`;
}
function shovel2(e, k, v, fr, tilt = 0, load = false) {
  const ang = angOf(v) + tilt;
  const grip = `<g transform="translate(${pt(e)}) rotate(${f2(angOf(v))})"><path d="M${f2(-0.02 * fr)} ${f2(-0.15 * fr)}Q${f2(-0.26 * fr)} ${f2(-0.15 * fr)} ${f2(-0.26 * fr)} 0Q${f2(-0.26 * fr)} ${f2(0.15 * fr)} ${f2(-0.02 * fr)} ${f2(0.15 * fr)}" fill="none" stroke="${L}" stroke-width="${f2(0.1 * fr + 2.4)}" stroke-linecap="round"/><path d="M${f2(-0.02 * fr)} ${f2(-0.15 * fr)}Q${f2(-0.26 * fr)} ${f2(-0.15 * fr)} ${f2(-0.26 * fr)} 0Q${f2(-0.26 * fr)} ${f2(0.15 * fr)} ${f2(-0.02 * fr)} ${f2(0.15 * fr)}" fill="none" stroke="#C98E5E" stroke-width="${f2(0.1 * fr)}" stroke-linecap="round"/></g>`;
  const blade = `<g transform="translate(${pt(k)}) rotate(${f2(ang)})"><path d="M0 ${f2(-0.06 * fr)}L${f2(0.08 * fr)} ${f2(-0.2 * fr)}Q${f2(0.42 * fr)} ${f2(-0.22 * fr)} ${f2(0.5 * fr)} 0Q${f2(0.42 * fr)} ${f2(0.22 * fr)} ${f2(0.08 * fr)} ${f2(0.2 * fr)}L0 ${f2(0.06 * fr)}Z" fill="#B9C3CC" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/><path d="M${f2(0.14 * fr)} ${f2(-0.12 * fr)}Q${f2(0.34 * fr)} ${f2(-0.14 * fr)} ${f2(0.4 * fr)} ${f2(-0.04 * fr)}" fill="none" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round"/>${load ? poopG(0.3 * fr, -0.02 * fr, 0.42 * fr) : ''}</g>`;
  return grip + stick2(e, k, 0.13 * fr) + blade;
}
// 站著的掃地牛（A 掃地、C 鏟子；第 25 輪定案的畫法，沒有改）。x、y 是兩腳中間的地面
// phase：鏟子牛一次「鏟起來 → 抬到水桶上面 → 倒進去」走到哪（0～1，null＝平常握著貼地）；sweep：掃把左右（-1～1）；step：走路時兩腳輪流抬
function stander(k, { x, y, s = SIDE_S, facing = 'right', sweep = 0, phase = null, carry = 0, bob = 0, step = 0, id = 'st' } = {}) {
  const C = SWEEP[k], dir = facing === 'right' ? 1 : -1;
  const { gn, r } = headOf(C, s * 0.92, id);
  const fr = r.face.r;
  const coat = gn.coat, spots = gn.pattern === 'patches', pat = gn.patternColor;
  const belly = spots ? '#FFFFFF' : hexMix(coat, '#FFFFFF', 0.42), shade = hexMix(coat, '#4B3326', 0.22);
  const yb = y, legH = 0.5 * fr, T = yb - legH - 1.86 * fr - bob;
  const P = (u, v) => [x + u * fr, T + v * fr];
  const hip = [x, T + 1.72 * fr];
  const lean = (C.lean || 0) * dir, Wl = (p) => rotP(p, hip, lean), Wi = (p) => rotP(p, hip, -lean);
  const tD = smoothClosedD([[0, 0], [0.56, 0.07], [0.86, 0.44], [1.0, 1.02], [0.96, 1.52], [0.64, 1.84], [0, 1.94], [-0.64, 1.84], [-0.96, 1.52], [-1.0, 1.02], [-0.86, 0.44], [-0.56, 0.07]].map(([u, v]) => P(u, v)));
  const cid = `tc${id}`;
  const armW = 0.34 * fr, handR = 0.2 * fr;
  let legs = '';
  for (const sd of [-1, 1]) {
    const up = step ? Math.max(0, Math.sin((step + (sd > 0 ? 0.5 : 0)) * 2 * Math.PI)) * 0.16 * fr : 0;
    const lx = x + sd * 0.44 * fr, foot = [lx + sd * 0.05 * fr, yb - up];
    legs += limb(lx, T + 1.6 * fr, foot[0], foot[1] - 0.2 * fr, 0.44 * fr, coat);
    legs += standFoot([foot[0], foot[1] - 0.04 * fr], fr, sd);
  }
  let inner = '';
  if (spots) inner += `<ellipse cx="${f2(P(-0.78, 1.25)[0])}" cy="${f2(P(-0.78, 1.25)[1])}" rx="${f2(0.5 * fr)}" ry="${f2(0.42 * fr)}" fill="${pat}"/><ellipse cx="${f2(P(0.86, 0.62)[0])}" cy="${f2(P(0.86, 0.62)[1])}" rx="${f2(0.34 * fr)}" ry="${f2(0.3 * fr)}" fill="${pat}"/>`;
  inner += `<ellipse cx="${f2(x)}" cy="${f2(P(0, 1.3)[1])}" rx="${f2(0.6 * fr)}" ry="${f2(0.62 * fr)}" fill="${belly}"/><ellipse cx="${f2(x)}" cy="${f2(P(0, 0.55)[1])}" rx="${f2(0.62 * fr)}" ry="${f2(0.2 * fr)}" fill="${shade}" opacity="0.35"/>`;
  const torso = `<defs><clipPath id="${cid}"><path d="${tD}"/></clipPath></defs><path d="${tD}" fill="${coat}"/><g clip-path="url(#${cid})">${inner}</g><path d="${tD}" fill="none" stroke="${L}" stroke-width="2.6"/>`;
  const fcx = x, fcy = T - 0.34 * fr;
  const head = `<g transform="translate(${f2(fcx - r.face.cx)} ${f2(fcy - r.face.cy)})">${r.svg}</g>`;
  const g = { fx: fcx, fy: fcy, fr, dir, back: -dir };
  const shFar = P(-dir * 0.78, 0.44), shNear = P(dir * 0.8, 0.44);
  let behind = '', arms = '', tool = '', hands = '', hat = '';
  const a = {};
  if (C.tool === 'broom') {
    const H1 = P(-dir * 0.16, 0.76), H1w = Wl(H1);
    const G = [x + dir * 2.05 * fr + dir * sweep * 0.3 * fr, yb - 0.56 * fr];
    const v = normV(subV(G, H1w)), E = addV(H1w, v, -0.42 * fr), H2w = mix2(H1w, G, 0.46), H2 = Wi(H2w);
    arms = arm(shFar, H1, armW, coat, [-dir * 0.1 * fr, 0.24 * fr]) + shoulderCap(shFar, armW, coat) + arm(shNear, H2, armW, coat, [dir * 0.24 * fr, 0.02 * fr]) + shoulderCap(shNear, armW, coat);
    tool = stick2(E, G, 0.13 * fr) + broom2(G, v, yb, fr);
    hands = hoofHand(H1w, angOf(v), handR) + hoofHand(H2w, angOf(v), handR);
    hat = bandana(g, true);
    a.tip = [G[0] + v[0] * 0.15 * fr, yb];
  } else {
    const H1 = P(-dir * 0.6, 1.3), H1w = Wl(H1);
    const dig = [x + dir * 2.0 * fr, yb - 0.06 * fr], bkt = [x + dir * 2.95 * fr, yb];
    let B = dig, tilt = 0, load = false;
    if (phase != null) {
      const u = phase;
      if (u < 0.35) B = [dig[0] + dir * 0.12 * fr * (u / 0.35), dig[1]];
      else if (u < 0.75) { const w = (u - 0.35) / 0.4, e = w * w * (3 - 2 * w); B = [lerp(dig[0] + dir * 0.12 * fr, bkt[0] - dir * 0.05 * fr, e), lerp(dig[1], bkt[1] - 1.05 * fr, e) - Math.sin(e * Math.PI) * 0.25 * fr]; load = true; }
      else { const w = (u - 0.75) / 0.25; B = [bkt[0] - dir * 0.05 * fr, bkt[1] - 1.05 * fr]; tilt = dir * 70 * Math.min(1, w * 1.6); load = w < 0.45; }
    }
    const v = normV(subV(B, H1w)), K = addV(B, v, -0.5 * fr), E = addV(H1w, v, -0.24 * fr), H2w = mix2(H1w, K, 0.58), H2 = Wi(H2w);
    arms = arm(shFar, H1, armW, coat, [-dir * 0.22 * fr, 0.02 * fr]) + shoulderCap(shFar, armW, coat) + arm(shNear, H2, armW, coat, [dir * 0.16 * fr, -0.1 * fr]) + shoulderCap(shNear, armW, coat);
    tool = shovel2(E, K, v, fr, tilt, load);
    hands = hoofHand(H1w, angOf(v), handR) + hoofHand(H2w, angOf(v), handR);
    hat = strawHat(g);
    const fall = phase != null && phase > 0.8 ? (phase - 0.8) / 0.2 : 0;
    behind += bucket(bkt[0], bkt[1] - 0.02 * fr, fr * 0.052, carry + (phase != null && phase >= 0.98 ? 1 : 0));
    if (fall > 0 && fall < 1) tool += poopG(bkt[0], lerp(bkt[1] - 0.95 * fr, bkt[1] - 0.55 * fr, fall), 0.42 * fr);
    a.tip = dig; a.bucket = bkt;
  }
  const up = `<g transform="rotate(${f2(lean)} ${pt(hip)})">${torso}${arms}${head}${hat}</g>`;
  const shadow = `<ellipse cx="${f2(x + dir * 0.5 * fr)}" cy="${f2(yb + 1)}" rx="${f2(1.6 * fr)}" ry="${f2(0.26 * fr)}" fill="#3E6B2A" opacity="0.2"/>`;
  const reach = C.tool === 'shovel' ? 3.6 : 2.9;
  const bx = [x - dir * 1.4 * fr, x + dir * reach * fr];
  return { svg: shadow + behind + legs + up + tool + hands, g: { ...g, ground: yb }, a, head: [fcx, fcy - fr * 1.3], box: [Math.min(...bx), fcy - 1.75 * fr, Math.max(...bx), yb + 0.3 * fr] };
}

// ---------- 四隻腳的掃地牛（B 系）：衣服畫在身上（用身體的外框裁切，順著圓筒形的身體）；也用來畫五種的小牛 ----------
// 衣服都在模型座標裡畫（前面是 -x，地面 y = 0），再用 model.tf 轉到畫面
const legD = (pts) => smoothPath(pts);
// 遠側的腿：只留身體、近側腿擋不到的那一段（衣服畫在遠側腿上時用）
const farMask = (M, i, id, lw) => `<mask id="${id}" maskUnits="userSpaceOnUse" x="-4000" y="-4000" width="8000" height="8000"><path d="${legD(M.far[i])}" fill="#FFFFFF"/><path d="${M.bodyD}" fill="#000000" stroke="#000000" stroke-width="${f2(lw * 2.2)}"/>${M.near.map((p) => `<path d="${legD(p)}" fill="#000000" stroke="#000000" stroke-width="${f2(lw * 2.2)}"/>`).join('')}</mask>`;
// 腿上的一段布（袖套、褲管）：腿的外框裁切，從 v0 到 v1（腿高的比例，0 是上面），回傳 svg
function legCloth(pts, v0, v1, fill, id, extra = '') {
  const ys = pts.map((p) => p[1]), top = Math.min(...ys), botm = Math.max(...ys), xs = pts.map((p) => p[0]);
  const y0 = lerp(top, botm, v0), y1 = lerp(top, botm, v1), x0 = Math.min(...xs) - 6, x1 = Math.max(...xs) + 6;
  return `<defs><clipPath id="${id}"><path d="${legD(pts)}"/></clipPath></defs><g clip-path="url(#${id})"><rect x="${f2(x0)}" y="${f2(y0)}" width="${f2(x1 - x0)}" height="${f2(y1 - y0)}" fill="${fill}"/>${extra}</g>`;
}
const legBox = (pts) => { const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]); return { x0: Math.min(...xs), x1: Math.max(...xs), y0: Math.min(...ys), y1: Math.max(...ys) }; };

// B1 工作背心（第 25 輪定案，沒有改）：披在背上、往兩邊垂下來，下擺在身體側面一半的地方
function vestSvg(M, id) {
  const B = M.B;
  const O = '#F08A2E', OD = '#C7621A', OL = '#FFB36B', REF = '#FFE14D';
  const vid = `v${id}`, bid = `b${id}`;
  const X = (u) => B.cx + u * B.rx, Y = (v) => B.cy + v * B.ry, top = B.topY - 0.4 * B.D;
  const fTop = [X(-0.6), top], fBot = [X(-0.7), Y(0.3)], bBot = [X(0.48), Y(0.34)], bTop = [X(0.56), top];
  const region = `M${pt(fTop)}Q${pt([X(-0.76), Y(-0.25)])} ${pt(fBot)}Q${pt([X(-0.1), Y(0.66)])} ${pt(bBot)}Q${pt([X(0.62), Y(-0.1)])} ${pt(bTop)}Z`;
  const hemD = `M${pt(fBot)}Q${pt([X(-0.1), Y(0.66)])} ${pt(bBot)}`;
  const lw = Math.max(1.4, 0.022 * B.D);
  const stripeD = `M${pt([X(-0.8), Y(-0.04)])}Q${pt([X(-0.08), Y(0.24)])} ${pt([X(0.7), Y(0.02)])}`;
  const strapX = X(-0.36), strapTop = Y(0.47), buckle = [strapX, strapTop + 0.1 * B.D];
  const ring = [X(0.6), Y(-0.02)];
  const svg = `<defs><clipPath id="${bid}"><path d="${M.bodyD}"/></clipPath><clipPath id="${vid}"><path d="${region}"/></clipPath></defs>
    <g clip-path="url(#${bid})">
      <path d="M${pt([strapX, strapTop])}L${pt([strapX - 0.02 * B.D, B.bellyY + 0.3 * B.D])}" stroke="${L}" stroke-width="${f2(0.1 * B.D + lw * 2)}"/><path d="M${pt([strapX, strapTop])}L${pt([strapX - 0.02 * B.D, B.bellyY + 0.3 * B.D])}" stroke="${OD}" stroke-width="${f2(0.1 * B.D)}"/>
      <rect x="${f2(buckle[0] - 0.08 * B.D)}" y="${f2(buckle[1] - 0.05 * B.D)}" width="${f2(0.16 * B.D)}" height="${f2(0.1 * B.D)}" rx="${f2(0.02 * B.D)}" fill="none" stroke="${L}" stroke-width="${f2(lw * 2.4)}"/><rect x="${f2(buckle[0] - 0.08 * B.D)}" y="${f2(buckle[1] - 0.05 * B.D)}" width="${f2(0.16 * B.D)}" height="${f2(0.1 * B.D)}" rx="${f2(0.02 * B.D)}" fill="none" stroke="#C9CED6" stroke-width="${f2(lw)}"/>
      <path d="${region}" fill="${O}"/>
      <g clip-path="url(#${vid})">
        <path d="${hemD}" fill="none" stroke="${OD}" stroke-width="${f2(0.16 * B.D)}" opacity="0.5"/>
        <path d="${M.bodyD}" fill="none" stroke="${OL}" stroke-width="${f2(0.1 * B.D)}" opacity="0.75"/>
        <path d="${stripeD}" fill="none" stroke="${L}" stroke-width="${f2(0.11 * B.D + lw * 2)}"/><path d="${stripeD}" fill="none" stroke="${REF}" stroke-width="${f2(0.11 * B.D)}"/><path d="${stripeD}" fill="none" stroke="#FFFFFF" stroke-width="${f2(0.03 * B.D)}" opacity="0.9"/>
        <path d="M${pt([X(-0.58), Y(-0.5)])}q${f2(0.05 * B.D)} ${f2(0.07 * B.D)} ${f2(0.03 * B.D)} ${f2(0.16 * B.D)}M${pt([X(-0.52), Y(0.1)])}q${f2(0.06 * B.D)} ${f2(0.04 * B.D)} ${f2(0.1 * B.D)} ${f2(0.12 * B.D)}M${pt([X(0.32), Y(0.26)])}q${f2(0.03 * B.D)} ${f2(0.05 * B.D)} 0 ${f2(0.11 * B.D)}" fill="none" stroke="${OD}" stroke-width="${f2(lw)}" stroke-linecap="round"/>
        <path d="M${pt([fBot[0] + 0.04 * B.rx, fBot[1] - 0.06 * B.D])}Q${pt([X(-0.1), Y(0.66) - 0.07 * B.D])} ${pt([bBot[0] - 0.03 * B.rx, bBot[1] - 0.06 * B.D])}" fill="none" stroke="#FFD9B0" stroke-width="${f2(lw * 0.8)}" stroke-dasharray="${f2(lw * 2)} ${f2(lw * 1.6)}"/>
      </g>
      <path d="${region}" fill="none" stroke="${L}" stroke-width="${f2(lw * 1.4)}" stroke-linejoin="round"/>
    </g>
    <circle cx="${f2(ring[0])}" cy="${f2(ring[1])}" r="${f2(0.06 * B.D)}" fill="none" stroke="${L}" stroke-width="${f2(lw * 2.4)}"/><circle cx="${f2(ring[0])}" cy="${f2(ring[1])}" r="${f2(0.06 * B.D)}" fill="none" stroke="#C9CED6" stroke-width="${f2(lw)}"/>`;
  return { svg, ring };
}
// B3 吊帶褲（第 29 輪重畫，照 B1 的風格：四隻腳、衣服畫在身上）。
// 想好再畫：四隻腳的牛穿吊帶褲——後半身和兩條後腳是褲子（後腳有捲起來的褲管），前半身露出毛；
// 一條吊帶從褲子的前腰沿著背往前、斜斜繞過肩膀，接到胸前的胸兜（黃扣子）；前腳當手，不穿。褲子用身體外框裁切，上下暗一點看得出身體是圓的。
function overallsSvg(M, id) {
  const B = M.B;
  const DEN = '#5577AE', DEND = '#3B5A8D', DENL = '#7F9DCB', ST = '#A9C0E6', CUFF = '#8FB0E0';
  const lw = Math.max(1.4, 0.022 * B.D);
  const X = (u) => B.cx + u * B.rx, Y = (v) => B.cy + v * B.ry;
  const top = B.topY - 0.5 * B.D, bot = B.bellyY + 0.5 * B.D;
  // 褲子：腰線在身體中間偏後一點，順著圓筒微微往前彎；往後蓋到屁股
  const waistTop = [X(0.12), top], waistMid = [X(0.02), Y(0)], waistBot = [X(-0.04), bot];
  const pantsD = `M${pt(waistTop)}Q${pt(waistMid)} ${pt(waistBot)}L${pt([X(1.6), bot])}L${pt([X(1.6), top])}Z`;
  // 胸兜：胸前、前腳上面那一塊（頭的下面）
  const bibD = `M${pt([X(-1.2), Y(0.34)])}L${pt([X(-0.42), Y(0.34)])}Q${pt([X(-0.34), Y(0.7)])} ${pt([X(-0.4), bot])}L${pt([X(-1.2), bot])}Z`;
  const btnA = [X(-0.44), Y(0.42)];
  // 吊帶：前腰的上面 → 沿著背往前 → 斜過肩膀 → 胸兜的扣子
  const strapD = `M${pt([X(0.1), B.topY + 0.08 * B.D])}Q${pt([X(-0.22), Y(-0.36)])} ${pt(btnA)}`;
  const pocketD = `M${pt([X(0.46), Y(-0.24)])}h${f2(0.3 * B.D)}v${f2(0.26 * B.D)}l${f2(-0.15 * B.D)} ${f2(0.07 * B.D)}l${f2(-0.15 * B.D)} ${f2(-0.07 * B.D)}Z`;
  const ring = [X(0.9), Y(-0.24)];
  const cid = `oc${id}`, pid = `op${id}`, bibId = `ob${id}`;
  const stitch = (d) => `<path d="${d}" fill="none" stroke="${ST}" stroke-width="${f2(lw * 0.8)}" stroke-dasharray="${f2(lw * 2)} ${f2(lw * 1.6)}" stroke-linecap="round"/>`;
  const band = (d, w, col) => `<path d="${d}" fill="none" stroke="${L}" stroke-width="${f2(w + lw * 2)}" stroke-linecap="round"/><path d="${d}" fill="none" stroke="${col}" stroke-width="${f2(w)}" stroke-linecap="round"/>`;
  const body = `<defs><clipPath id="${cid}"><path d="${M.bodyD}"/></clipPath><clipPath id="${pid}"><path d="${pantsD}"/></clipPath><clipPath id="${bibId}"><path d="${bibD}"/></clipPath></defs>
    <g clip-path="url(#${cid})">
      <path d="${pantsD}" fill="${DEN}"/><path d="${bibD}" fill="${DEN}"/>
      <g clip-path="url(#${pid})">
        <path d="${M.bodyD}" fill="none" stroke="${DEND}" stroke-width="${f2(0.22 * B.D)}" opacity="0.55"/>
        <path d="M${pt([X(0.16), B.topY + 0.14 * B.D])}Q${pt([X(0.5), B.topY + 0.04 * B.D])} ${pt([X(0.9), B.topY + 0.16 * B.D])}" fill="none" stroke="${DENL}" stroke-width="${f2(0.07 * B.D)}" stroke-linecap="round" opacity="0.8"/>
        <path d="${pocketD}" fill="${DEND}" fill-opacity="0.35"/>${stitch(pocketD)}
        <path d="M${pt([X(0.66), Y(0.24)])}q${f2(0.04 * B.D)} ${f2(0.12 * B.D)} ${f2(-0.02 * B.D)} ${f2(0.24 * B.D)}M${pt([X(0.2), Y(0.3)])}q${f2(0.08 * B.D)} ${f2(0.05 * B.D)} ${f2(0.12 * B.D)} ${f2(0.16 * B.D)}" fill="none" stroke="${DEND}" stroke-width="${f2(lw)}" stroke-linecap="round"/>
      </g>
      <g clip-path="url(#${bibId})"><path d="${M.bodyD}" fill="none" stroke="${DEND}" stroke-width="${f2(0.2 * B.D)}" opacity="0.5"/>${stitch(`M${pt([X(-0.5), Y(0.42)])}Q${pt([X(-0.44), Y(0.7)])} ${pt([X(-0.5), Y(0.98)])}`)}</g>
      <path d="${bibD}" fill="none" stroke="${L}" stroke-width="${f2(lw * 1.4)}" stroke-linejoin="round"/>
      ${band(`M${pt(waistTop)}Q${pt(waistMid)} ${pt(waistBot)}`, 0.1 * B.D, DEND)}${stitch(`M${pt([waistTop[0] + 0.05 * B.D, waistTop[1]])}Q${pt([waistMid[0] + 0.05 * B.D, waistMid[1]])} ${pt([waistBot[0] + 0.05 * B.D, waistBot[1]])}`)}
      ${band(strapD, 0.12 * B.D, DEN)}${stitch(strapD)}
    </g>
    <circle cx="${f2(btnA[0])}" cy="${f2(btnA[1])}" r="${f2(0.06 * B.D)}" fill="#FFD45E" stroke="${L}" stroke-width="${f2(lw)}"/>
    <circle cx="${f2(ring[0])}" cy="${f2(ring[1])}" r="${f2(0.055 * B.D)}" fill="none" stroke="${L}" stroke-width="${f2(lw * 2.4)}"/><circle cx="${f2(ring[0])}" cy="${f2(ring[1])}" r="${f2(0.055 * B.D)}" fill="none" stroke="#C9CED6" stroke-width="${f2(lw)}"/>`;
  // 褲管：兩條後腳，從身體到腳的 6 成，下面一圈捲起來的褲管（淺一點、粗一點）
  const pantLeg = (pts, far, i) => {
    const bx = legBox(pts), cy = lerp(bx.y0, bx.y1, 0.6), hw = (bx.x1 - bx.x0) / 2 + lw * 1.2, cx = (bx.x0 + bx.x1) / 2;
    const cloth = legCloth(pts, 0, 0.6, far ? DEND : DEN, `${id}pl${i}`, `<path d="M${f2(cx + hw * 0.1)} ${f2(bx.y0 + 2)}V${f2(cy - 2)}" stroke="${far ? '#33507F' : ST}" stroke-width="${f2(lw * 0.8)}" stroke-dasharray="${f2(lw * 2)} ${f2(lw * 1.6)}"/>`);
    const cuff = `<rect x="${f2(cx - hw)}" y="${f2(cy - 0.06 * B.D)}" width="${f2(hw * 2)}" height="${f2(0.1 * B.D)}" rx="${f2(0.04 * B.D)}" fill="${far ? '#6C8BBC' : CUFF}" stroke="${L}" stroke-width="${f2(lw)}"/>`;
    return cloth + cuff;
  };
  const farLeg = `<defs>${farMask(M, 1, `ofm${id}`, lw)}</defs><g mask="url(#ofm${id})">${pantLeg(M.far[1], true, 'f')}</g>`;
  return { svg: farLeg + pantLeg(M.near[1], false, 'n') + body, ring };
}
// B2 領巾加袖套（第 22 輪的造型，使用者沒提、留著；這一輪改成畫在身上：領巾繞在脖子上、袖套套在前腳上，不是浮貼）
function sleevesSvg(M, id) {
  const B = M.B, lw = Math.max(1.4, 0.022 * B.D);
  const sleeve = (pts, far, i) => {
    const bx = legBox(pts), y0 = lerp(bx.y0, bx.y1, 0.1), y1 = lerp(bx.y0, bx.y1, 0.72), hw = (bx.x1 - bx.x0) / 2 + lw * 1.1, cx = (bx.x0 + bx.x1) / 2;
    const blue = far ? '#5E8FC2' : '#7FB3E0', rim = far ? '#8DB2D8' : '#B9D7F2';
    const stripes = [0.36, 0.62].map((k) => `<path d="M${f2(cx - hw)} ${f2(lerp(y0, y1, k))}H${f2(cx + hw)}" stroke="#FFFFFF" stroke-width="${f2(0.07 * B.D)}" opacity="${far ? 0.75 : 1}"/>`).join('');
    const cloth = legCloth(pts, 0.1, 0.72, blue, `${id}sl${i}`, stripes);
    const cuff = (y) => `<rect x="${f2(cx - hw)}" y="${f2(y - 0.035 * B.D)}" width="${f2(hw * 2)}" height="${f2(0.07 * B.D)}" rx="${f2(0.035 * B.D)}" fill="${rim}" stroke="${L}" stroke-width="${f2(lw * 0.9)}"/>`;
    return cloth + cuff(y0 + 0.03 * B.D) + cuff(y1);
  };
  return `<defs>${farMask(M, 0, `sfm${id}`, lw)}</defs><g mask="url(#sfm${id})">${sleeve(M.far[0], true, 'f')}</g>${sleeve(M.near[0], false, 'n')}`;
}
// 領巾：圍在下巴下面的脖子上（側面看，脖子在大頭的後下方，所以畫在頭的上面），三角形的尖角垂在胸前，結打在脖子後面。g：臉的圓（畫面座標）
function scarfSvg(g) {
  const { fx, fy, fr, back } = g, X = (u) => fx + back * u * fr, Y = (v) => fy + v * fr;
  const band = `M${f2(X(-0.18))} ${f2(Y(0.9))}Q${f2(X(0.38))} ${f2(Y(1.12))} ${f2(X(0.98))} ${f2(Y(0.62))}L${f2(X(1.04))} ${f2(Y(0.86))}Q${f2(X(0.42))} ${f2(Y(1.36))} ${f2(X(-0.12))} ${f2(Y(1.13))}Z`;
  const tri = `M${f2(X(-0.12))} ${f2(Y(1.02))}L${f2(X(0.4))} ${f2(Y(1.16))}L${f2(X(0.06))} ${f2(Y(1.5))}Z`;
  const knot = [X(1.02), Y(0.74)];
  const tails = `M${f2(knot[0])} ${f2(knot[1])}l${f2(back * fr * 0.42)} ${f2(-fr * 0.18)}l${f2(-back * fr * 0.06)} ${f2(fr * 0.36)}Z M${f2(knot[0])} ${f2(knot[1])}l${f2(back * fr * 0.38)} ${f2(fr * 0.24)}l${f2(-back * fr * 0.2)} ${f2(fr * 0.2)}Z`;
  const dots = [[0.04, 1.18], [0.2, 1.24], [0.08, 1.36], [0.6, 1.02], [0.82, 0.88]].map(([u, v]) => `<circle cx="${f2(X(u))}" cy="${f2(Y(v))}" r="${f2(fr * 0.06)}" fill="#FFFFFF"/>`).join('');
  return `<path d="${tails}" fill="#E5484D" stroke="${L}" stroke-width="1.6" stroke-linejoin="round"/><path d="${band}" fill="#E5484D" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/><path d="${tri}" fill="#E5484D" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/>${dots}<circle cx="${f2(knot[0])}" cy="${f2(knot[1])}" r="${f2(fr * 0.1)}" fill="#C93A3F" stroke="${L}" stroke-width="1.5"/>`;
}
// 四隻腳的掃地牛（側面）。x、y 是腳底中間；age 'calf'：小牛（沒有推車）；A、C 的小牛是四隻腳的小牛戴頭巾、草帽
function sideCow(k, { x, y, s = SIDE_S, facing = 'left', carry = 0, bob = 0, id = 'sc', age = 'adult', cart: withCart = age === 'adult' } = {}) {
  const C = SWEEP[k];
  const gn = genesFor({ breed: C.breed, sex: C.sex, seed: C.seed, age });
  const r = renderR('r11', gn, { pose: 'side', x, y: y - bob, scale: s, facing, id, split: true });
  const M = r.model, B = M.B, fr = r.face.r;
  const toS = ([mx, my]) => [x + M.sx * mx, y - bob + M.s * my];
  const back = facing === 'right' ? -1 : 1;
  let onBody = '', underHead = '', onHead = '', ring = null;
  if (C.outfit === 'vest') ({ svg: onBody, ring } = vestSvg(M, id));
  else if (C.outfit === 'overalls') ({ svg: onBody, ring } = overallsSvg(M, id));
  const g = { fx: r.face.cx, fy: r.face.cy, fr, dir: -back, back };
  if (C.outfit === 'scarf') { onBody = sleevesSvg(M, id); onHead = scarfSvg(g); ring = [B.xR - 0.1 * B.D, B.topY + 0.3 * B.D]; }
  if (C.tool === 'broom') onHead = bandana(g, false);
  if (C.tool === 'shovel') onHead = strawHat(g);
  // 母小牛的蝴蝶結（照 M2）：頭上有頭巾、草帽的不另外加
  if (age === 'calf' && C.sex === 'cow' && C.kind === 'side') onHead += calfBow(r, 'side', facing).svg;
  let cartSvg = '', rope = '', cartPos = null;
  if (withCart && ring) {
    const ringS = toS(ring);
    const cartAt = toS([B.xR + 0.75 * B.D, 0]);
    cartSvg = cart(cartAt[0], y - 14 * s, s, carry);
    const ropeD = `M${pt(ringS)}Q${pt([(ringS[0] + cartAt[0]) / 2, Math.max(ringS[1], y - 22 * s) + 6])} ${pt([cartAt[0] - back * 18 * s, y - 24 * s])}`;
    rope = `<path d="${ropeD}" fill="none" stroke="${L}" stroke-width="3.6" stroke-linecap="round"/><path d="${ropeD}" fill="none" stroke="#D8A66A" stroke-width="1.8" stroke-linecap="round"/>`;
    cartPos = [cartAt[0], y - 30 * s];
  }
  const shadow = `<ellipse cx="${f2(toS([B.cx, 0])[0])}" cy="${f2(y)}" rx="${f2(B.L * 0.62 * M.s)}" ry="${f2(Math.max(3.5, B.D * 0.12 * M.s))}" fill="#3E6B2A" opacity="0.18"/>`;
  const body = `${r.svgBody}<g transform="${M.tf}">${onBody}${underHead}</g>${r.svgHead}${onHead}`;
  const xs = [toS([B.xF - 0.35 * B.D, 0])[0], toS([B.xR + 0.35 * B.D, 0])[0], r.face.cx - fr * 1.5, r.face.cx + fr * 1.5];
  if (cartPos) xs.push(cartPos[0] - 24 * s, cartPos[0] + 24 * s);
  const top = r.face.cy - fr * (onHead ? 2.0 : 1.7);
  return { svg: shadow + cartSvg + rope + body, g: { ...g, ground: y, h: r.height }, a: { cart: cartPos, tip: [r.face.cx + (-back) * fr * 1.1, y] }, head: [r.face.cx, r.face.cy - fr * 1.2], box: [Math.min(...xs), top, Math.max(...xs), y + 6] };
}
// 一頭掃地牛（場景座標）：x、y 是腳底中間
function cleaner(k, o = {}) {
  const C = SWEEP[k];
  if (o.age === 'calf' || C.kind === 'side') return sideCow(k, { facing: o.facing || 'left', ...o });
  return stander(k, o);
}
// 掃地牛單獨一張圖：cart false 不畫推車（圖鑑格子）；sil 畫成影子（還沒發現）
let artN = 0;
function cleanerArt(k, w, h, { age = 'adult', cart: withCart, sil = false, pad = 4, facing } = {}) {
  const C = SWEEP[k];
  const fc = facing || (C.kind === 'stand' && age !== 'calf' ? 'right' : 'left');
  const c = cleaner(k, { x: 0, y: 0, s: 1, facing: fc, id: `ca${artN++}`, age, ...(withCart === undefined ? {} : { cart: withCart }) });
  const [x0, y0, x1, y1] = c.box;
  const cw = x1 - x0, ch = y1 - y0, k2 = Math.min((w - pad * 2) / cw, (h - pad * 2) / ch);
  const vw = w / k2, vh = h / k2;
  const vb = [(x0 + x1) / 2 - vw / 2, y1 + pad / k2 - vh, vw, vh];
  const fid = `sil${artN++}`;
  const defs = sil ? `<defs><filter id="${fid}"><feFlood flood-color="#4B3A31"/><feComposite in2="SourceAlpha" operator="in"/></filter></defs>` : '';
  return `<svg viewBox="${vb.map(f2).join(' ')}" width="${w}" height="${h}" aria-hidden="true">${defs}${sil ? `<g filter="url(#${fid})">${c.svg}</g>` : c.svg}</svg>`;
}

// ================= 牧場畫面（下方：奶桶面板＋沒有底板的飼料列；倉庫小鈕） =================
const STOCK = { grass: 24, hay: 12, oats: 8, alfalfa: 0, corn: 5, soy: 3 };
const fName = (k) => t(`feed.${k}`);
const fic = (k, s = 22) => icon(`feed_${k}`, s);
const sack = (k, n) => `<span class="sack"><svg viewBox="0 0 54 58" width="54" height="58" aria-hidden="true"><path d="M12 12Q27 6 42 12L46 18Q51 34 47 50Q27 57 7 50Q3 34 8 18Z" fill="${n ? '#E9D3A6' : '#E5DED2'}" stroke="${L}" stroke-width="2.2" stroke-linejoin="round"/><path d="M12 12Q18 4 27 9Q36 4 42 12" fill="none" stroke="${L}" stroke-width="2"/><path d="M14 17Q27 21 40 17" stroke="#C99A34" stroke-width="2.4" fill="none"/></svg><span class="sk-ic">${fic(k, 24)}</span><b class="num sk-n">${n}</b></span>`;
// 飼料列（第 26 輪「沒有底板」）：袋子下面只寫名字（使用者：「飼料底下不用寫加給公斤，這是隨機的」）。o.lift 正在拖的；o.used 用掉一份；o.back 飛回來的
function feedBar(o = {}) {
  const items = FEED_KEYS.map((k) => { const n = STOCK[k] + (o.used === k ? -1 : 0); return `<button class="fb-item${n ? '' : ' none'}${k === o.lift ? ' lift' : ''}${k === o.back ? ' back' : ''}">${sack(k, n)}<span class="fb-name">${fName(k)}</span></button>`; }).join('');
  return `<div class="fbar fbar-b"><div class="fb-track">${items}</div></div>`;
}
const whPill = `<button class="wh-pill">${icon('barn', 18)}<span>倉庫</span></button>`;
// 收起時的頂列：倉庫、位置指示、「展開」（帶奶桶的 %，滿了變藍）
function foldHead(pail = 87) {
  const full = pail >= 100;
  return `<div class="dock-head">${whPill}<span class="pan-ind"><i style="left:0%"></i></span><button class="dock-toggle"><span class="dt-pill${full ? ' r29-full' : ''}"><span class="r29-pail">${icon('pail', 16)}<b class="num">${full ? '滿了' : `${pail}%`}</b></span>${t('s03.expand')}<span class="dt-chev up">${icon('chevron', 14)}</span></span></button></div>`;
}
// 牧場頁。extra：畫在場景裡（場景座標）；fold：'all' 奶桶和飼料一起收（提案）、'bucket' 只收奶桶（另一種）
const HERD29 = HERD.filter((h) => h.id !== 7 && h.id !== 12 && h.id !== 15); // 中間空出來，給掃地牛、掃地機走
function ranch({ herd = HERD29, extra = '', bar: bo = {}, overlays = '', center = '', fold = '', pail = 87, pan = 0 } = {}) {
  let html = ranchPage(ctx0(), { herd, overlays, center, pan });
  html = html.replace(/(<div class="scene">[\s\S]*?)(<\/svg>\s*<\/div>)/, (m, a, b) => a + extra + b);
  if (fold) return html.replace(/<section class="dock">[\s\S]*?<\/section>/, `<section class="dock r29-folded">${foldHead(pail)}${fold === 'bucket' ? feedBar(bo) : ''}</section>`);
  html = html.replace(/<div class="dock-row">[\s\S]*?<\/article>\s*<\/div>\s*<\/section>/, '</section>').replace('<article class="card bucket-card', `${feedBar(bo)}<article class="card bucket-card`);
  return html.replace('<div class="dock-head">', `<div class="dock-head">${whPill}`);
}
const sceneFit = (herd = HERD29) => ranchScene(dev, herd, { wide: true }).fit;
const sparkle = (x, y, r) => `<path d="M${f2(x)} ${f2(y - r)}Q${f2(x + r * 0.2)} ${f2(y - r * 0.2)} ${f2(x + r)} ${f2(y)}Q${f2(x + r * 0.2)} ${f2(y + r * 0.2)} ${f2(x)} ${f2(y + r)}Q${f2(x - r * 0.2)} ${f2(y + r * 0.2)} ${f2(x - r)} ${f2(y)}Q${f2(x - r * 0.2)} ${f2(y - r * 0.2)} ${f2(x)} ${f2(y - r)}Z" fill="#FFFFFF" stroke="#E7B53A" stroke-width="1.2"/>`;
const sparks = (x, y, k = 1) => [[-14, -16, 5], [12, -20, 4], [2, -30, 3.4]].map(([dx, dy, r]) => sparkle(x + dx, y + dy, r * k)).join('');

// ================= 01 掃地牛五種：大圖、小牛 =================
function lineup() {
  const cell = (k) => {
    const C = SWEEP[k];
    return `<div class="r29-lu"><span class="lu-k">${k}</span><div class="lu-big">${cleanerArt(k, 250, 190)}</div>
      <div class="lu-small"><span>${cleanerArt(k, 110, 84, { age: 'calf' })}小牛</span></div>
      <b class="lu-name">${C.name}</b><div class="chips">${useChip(C.use)}${tierChip(4)}${k === 'B3' ? '<span class="lu-new">重畫</span>' : ''}</div>
      <span class="lu-look">${C.look}</span><span class="lu-look">小牛：${C.calf}</span></div>`;
  };
  return `<div class="r29-lineup">${SW.map(cell).join('')}</div>`;
}
function r2901() {
  return board({
    id: 'R29-01-掃地牛-五種-大圖和小牛', title: '01 掃地牛五種：特別牛（圖鑑「其他」、5 顆彩虹星）', width: PAD * 2 + 5 * 300 + 4 * 16 + 36 + 6,
    sub: '使用者：「我們可以有多種掃地牛，b3 怪怪的，可以做成b1那種風格」，再問清楚後：不能再花錢雇打掃牛；掃地牛變成特別牛（跟宙斯牛一樣放在圖鑑「其他」、5 顆彩虹星），只能用抓牛小遊戲抓到，或一般牛配種時很低的機率生出來，商店買不到；養了以後跟一般牛一樣（佔一格牛舍、長大、配種、出貨），另外會在牧場走來走去自動清大便。',
    top: lineup(),
    notes: [
      '造型：A 頭巾掃地、B1 工作背心推車、C 草帽鏟子照第 25 輪定案，沒有改。B3 照 B1 的風格重畫：四隻腳，吊帶褲畫在身上（後半身和兩條後腳是褲子、後腳有捲起來的褲管，胸口一塊胸兜、吊帶從扣子繞過肩膀，前腳當手不穿）。',
      'B2 領巾袖套使用者沒提，造型留著；這一輪只改畫法：領巾繞在脖子上、袖套套在前腳上，用腳的外框裁切（跟 B1 一樣畫在身上），不是浮貼在上面。',
      '用途照長相：A、C 是乳牛，B1、B2、B3 是耕牛（ceo 定）。名字是草稿，使用者看過才加進字串表。',
      '小牛（提案）：一出生就看得出是掃地牛，戴著同一套衣服或帽子，但還不會清大便、手上沒有工具，B 系也還沒有推車；長大才開始清（v0.3 第 5.1 節：長大以後每 30 分鐘清一次）。',
      '公的照產生器畫大一點，衣服一樣（這張只畫母的）。正面坐姿（換頭像、牛舍清單、選牛卡）的衣服等這一輪核准後再補。',
    ],
  });
}

// ================= 02 掃地牛的格式：圖鑑、詳細頁、名片、牛的詳細（用 A 當例子） =================
const USES = ['dairy', 'draft', 'beef'];
// 圖鑑最下面「其他」：雜種牛整排寬＋特殊牛三種（這裡都還沒發現）＋掃地牛五種
function codexOther(found = ['A', 'B1', 'B3', 'C']) {
  const mixTile = `<button class="dex-cell dex-mix-tile"><span class="dm-pics">${USES.map((u) => cowSVG({ breed: MIX_LOOK[u] }, { w: 70, h: 62, pad: 2 })).join('')}</span><span class="dm-text"><span class="dex-name">${t('breed.mix.name')}</span>${mixStar()}<span class="hint">${t('s09.mixBodies')}</span></span></button>`;
  const myth = (k) => `<button class="dex-cell unknown"><span class="dex-pic">${cowSVG({ breed: k }, { w: 74, h: 64, pad: 3, sil: 'dark' })}</span><span class="dex-name">${t('g.unknownBreed')}</span>${tierChip(4)}</button>`;
  const sw = (k) => { const ok = found.includes(k); return `<button class="dex-cell${ok ? '' : ' unknown'}"><span class="dex-pic">${cleanerArt(k, 74, 64, { cart: false, sil: !ok, pad: 3 })}</span><span class="dex-name">${ok ? SWEEP[k].name : t('g.unknownBreed')}</span>${tierChip(4)}</button>`; };
  const content = `<div class="stack">
    ${seg([t('subCodex'), t('subRank')], 0)}
    <article class="card dex-head"><div class="row" style="justify-content:space-between"><span class="card-title">${icon('book', 18)}${t('s09.found')}</span><b class="num dex-count">${FOUND.length} <small>/ 24</small></b></div>
      ${bar((FOUND.length / 24) * 100, { color: 'yellow', thick: true })}<p class="hint" style="margin-top:6px">${t('s09.hint')}</p></article>
    <div class="skip-note">乳牛、耕牛、肉牛 24 格（略）</div>
    <section><h3 class="sec-title"><span class="use">${t('s09.other')}</span><span class="hint">${t('s09.otherHint', { n: 24 })}</span></h3>
      <div class="dex-grid">${mixTile}${Object.keys(MYTH).map(myth).join('')}
        <div class="r29-subhead">${broomIc(16)}掃地牛<span class="hint">會幫忙清大便</span></div>${SW.map(sw).join('')}</div></section>
  </div>`;
  return frame(dev, { tab: 'records', content, tall: true });
}
const cleanCard = (today = null) => `<article class="card"><div class="card-head"><span class="card-title green r29-card-title">${broomIc(16)}會幫忙清大便</span></div>
  <p class="r29-clean">長大以後，每 <b>30 分鐘</b>把牧場的大便全部清掉，沒上線也照樣清。小牛還不會清。</p>${today != null ? `<div class="r29-today"><span>今天清了</span><span><b class="num">${today}</b> 坨</span></div>` : ''}</article>`;
const howCard = () => `<article class="card"><div class="card-head"><span class="card-title orange r29-card-title">${icon('sparkle', 16)}怎麼遇到</span></div>
  <p class="hint" style="margin-top:6px;color:var(--ink)">在抓牛小遊戲遇到，很少出現；一般牛配種的時候，也有很低的機會生出來。商店買不到。</p><p class="hint" style="margin-top:4px">一出現就看得出是掃地牛，不用等長大。</p></article>`;
// 圖鑑的詳細（特殊牛的格式，第 15 輪 04）：沒有配種表（會不會遺傳還沒定），改寫「會幫忙清大便」「怎麼遇到」
function sweepDetail(k, { found = true } = {}) {
  const C = SWEEP[k];
  const pics = found ? `<div class="dex-pics">${cleanerArt(k, 214, 140)}${cleanerArt(k, 96, 80, { age: 'calf' })}</div>` : `<div class="dex-pics">${cleanerArt(k, 214, 140, { sil: true })}</div>`;
  const stats = [];
  if (C.use === 'dairy') stats.push([t('s09.milkCow'), `14 <small>${t('g.perHourMilk')}</small>`]);
  else stats.push([t('g.plow'), `11 <small>${t('g.perHourRice')}</small>`]);
  stats.push([t('s09.bestKg'), `${C.use === 'dairy' ? 250 : 450} <small>${t('g.kg')}</small>`]);
  stats.push([t('s09.mult'), '<span class="r29-tbd">待定</span>']);
  const content = `<div class="stack">
    <div class="page-head"><button class="icon-btn" aria-label="${t('back')}">${icon('back', 22)}</button><div class="grow"><h1>${found ? C.name : t('g.unknownBreed')}</h1><div class="chips" style="margin-top:3px">${useChip(C.use)}${tierChip(4)}${found ? '' : badge('lock', t('s09.notFoundYet'))}</div></div></div>
    <article class="card dex-hero r29-hero"><div class="hero-bg"></div>${pics}</article>
    ${found ? `<p class="dex-intro">${C.intro}</p>
    <div class="kv">${stats.map(([a, v]) => `<div class="cell"><div class="k">${a}</div><div class="v num">${v}</div></div>`).join('')}</div>
    ${cleanCard()}${howCard()}
    <p class="hint">${t('s09.firstFound', { date: t('date.mdOnly', { m: 10, d: 8 }), n: 1 })}</p>` : `${cleanCard()}${howCard()}`}
  </div>`;
  return frame(dev, { tab: 'records', content, tall: found });
}
// 牧場裡的名片：掃地牛被點的時候不轉正面（手上拿著工具），名片照樣跳出來
const SWEEP_COW = { id: 31, breed: swKey('A'), sex: 'cow', age: 'adult', age_: { d: 1, h: 6 }, milk: 14, kg: 236, value: 0, probs: { A: 0.38, B: 0.45, C: 0.17 }, origin: 'game' };
function sweepPop(c) {
  const C = SWEEP[BREEDS[c.breed].sweep];
  return `<div class="name">${C.name} #${c.id}</div><div class="chips" style="margin-top:4px">${useChip(C.use)}<span class="use">${sexName(c.sex)}</span>${tierChip(4)}</div><div class="meta">${t('s03.popMilk', { tier: tierName(4), n: c.milk })}</div><p class="r29-pop-clean">${broomIc(14)}會自己清大便（每 30 分鐘）</p>${btn(t('s03.popDetail'), { small: true, block: true, kind: 'primary' })}`;
}
// 名片（跟 M2 ranchPage 的 pop 一樣的放法；位置照掃地牛的頭）
function popAt([hx, hy], footY, html, cls = '', pw = 208) {
  const left = Math.max(12, Math.min(dev.w - 12 - pw, hx - 43));
  return `<div class="cow-pop${cls ? ` ${cls}` : ''}" data-foot="${f2(footY)}" data-hx="${f2(hx)}" style="left:${f2(left)}px;top:${f2(hy - 14)}px;transform:translateY(-100%)">${html}</div>`;
}
const POOP3 = [3, 1, 4].map((i) => POOP_SPOTS[i]); // 要清的三坨（M2 的大便位置第 3、1、4 個，由左到右）
function ranchCard() {
  const F = sceneFit();
  const pos = [262, 486];
  const c = cleaner('A', { x: pos[0], y: pos[1], facing: 'left', id: 'pcA' });
  const head = F.map(c.head), foot = F.map([pos[0], pos[1]]);
  return ranch({ extra: poopG(...POOP_SPOTS[0], 19) + c.svg, center: dirtyPill(1), overlays: popAt(head, foot[1], sweepPop(SWEEP_COW)) });
}
// 牛的詳細（S04，照 M2 的 detailPage）：大圖換成掃地牛、來源「抓牛小遊戲」、多一張「會幫忙清大便」（今天清了幾坨：提案）
function sweepCowPage() {
  const c = SWEEP_COW;
  let html = detailPage(ctx0(), c, { buttons: `<div class="btn-row">${btn(t('pickForBreed'), { kind: 'pink', ic: 'heart' })}${btn(t('ship'), { kind: 'danger', ic: 'truck' })}</div>` });
  html = html.replace(/(<article class="card hero"><div class="hero-bg"><\/div>)<svg[\s\S]*?<\/svg>/, (m, a) => a + cleanerArt('A', 200, 150));
  html = html.replace(t('origin', { v: '' }), t('origin', { v: '小遊戲' }));
  html = html.replace(`${t('s04.about', { v: '0' })} <small>${t('g.coin')}</small>`, '<span class="r29-tbd">待定</span>');
  return html.replace(/(<article class="card">\s*<div class="card-head"><span class="card-title">)/, `${cleanCard(12)}$1`);
}
function r2902() {
  return board({
    id: 'R29-02-掃地牛-圖鑑名片詳細頁-A-頭巾掃地牛-390', title: '02 掃地牛的格式（用 A 頭巾掃地牛當例子）：圖鑑、詳細頁、名片、牛的詳細',
    sub: '照第 15 輪特殊牛（宙斯牛）的格式：圖鑑最下面「其他」一格一種、5 顆彩虹星；還沒發現是影子加「？？？」。五種的格式都一樣，只換名字、用途、圖。',
    cells: [
      { cap: '1 圖鑑最下面「其他」', note: '雜種牛、宙斯牛等三種特殊牛後面，多一排「掃地牛」五格（這個玩家發現了 4 種）', html: codexOther() },
      { cap: '2 圖鑑詳細（已發現）', note: '大圖＋小牛；沒有配種表，改寫「會幫忙清大便」「怎麼遇到」', html: sweepDetail('A') },
      { cap: '3 圖鑑詳細（還沒發現）', note: 'B2 領巾推車牛還沒遇到：影子＋會做什麼、怎麼遇到', html: sweepDetail('B2', { found: false }) },
      { cap: '4 牧場裡點掃地牛：名片', note: '跟一般牛一樣的名片，多一行「會自己清大便」；被點的時候不轉正面（手上拿著掃把）', html: ranchCard() },
      { cap: '5 牛的詳細（看詳細）', note: '跟一般牛一樣能配種、出貨；來源「小遊戲」（配種生的寫「自己配種」）；多一張「會幫忙清大便」', html: sweepCowPage() },
    ],
    notes: [
      '賣價倍數、出貨估值寫「待定」：機率、倍數、會不會遺傳由 cow-back 試算、ceo 定（v0.3 第 5.1 節）。配種表也等「會不會遺傳」定了再說，這一輪先不放。',
      '「今天清了 12 坨」是提案：玩家看得到這頭牛有在做事（使用者拿掉了右上角的「打掃中」）。要伺服器多記一個數字，不要的話拿掉這一行。',
      '掃地機和掃地牛可以同時有（ceo 定），同時有只是多清幾次，畫面上不用另外說明。',
    ],
  });
}

// ================= 03 掃地牛在牧場清大便（五種各一張＋GIF） =================
// 停在大便旁邊時，牛腳的位置（掃把、鏟子剛好碰到大便；推車牛是頭靠過去）
function standAt(k, [px, py]) {
  const C = SWEEP[k];
  const c = cleaner(k, { x: 0, y: 0, facing: 'right' });
  const dx = c.a.tip ? c.a.tip[0] : 0;
  return [px - dx - (C.kind === 'side' ? 6 : 0), py + 4];
}
const poopsAt = (scales) => POOP3.map(([x, y], i) => ((scales[i] ?? 1) > 0.02 ? poopG(x, y, 19 * (scales[i] ?? 1)) : '')).join('');
const WANDER = [330, 432]; // 平常在這附近散步（掃把、鏟子碰不到大便）
function flyToCart(k, from, c, v) { const [cx, cy] = c.a.cart; return poopG(lerp(from[0], cx, v), lerp(from[1], cy, v) - Math.sin(v * Math.PI) * 40, 14); }
function cleanCells(k) {
  const C = SWEEP[k], cart = C.kind === 'side';
  const cl = (o) => cleaner(k, { id: `c${k}${Math.random().toString(36).slice(2, 7)}`, facing: 'right', ...o });
  const [sx, sy] = standAt(k, POOP3[0]);
  const at = cl({ x: sx, y: sy });
  const p0 = POOP3[0];
  const fly = cart ? `<path d="M${p0[0]} ${p0[1] - 6}Q${(p0[0] + at.a.cart[0]) / 2} ${Math.min(p0[1], at.a.cart[1]) - 46} ${at.a.cart[0]} ${at.a.cart[1]}" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-dasharray="2 7" stroke-linecap="round"/>${flyToCart(k, p0, at, 0.5)}` : '';
  const acting = cl({ x: sx, y: sy, sweep: 0.8, phase: 0.55, carry: 0 });
  return [
    { cap: '1 平常：跟其他牛一起散步', note: '右上角只有大便數（沒有「打掃中」）；牠就是牧場裡的一頭牛', html: ranch({ extra: poopsAt([1, 1, 1]) + cl({ x: WANDER[0], y: WANDER[1], facing: 'left' }).svg, center: dirtyPill(3) }) },
    { cap: '2 每 30 分鐘：走到大便旁邊', note: '一坨一坨走過去清；沒上線也照樣清（回來就是乾淨的）', html: ranch({ extra: poopsAt([1, 1, 1]) + at.svg, center: dirtyPill(3) }) },
    { cap: '3 清掉：大便不見、冒星星', note: `${C.act}；右上角的大便數少 1`, html: ranch({ extra: poopsAt([k === 'C' ? 0 : cart ? 0 : 0.35, 1, 1]) + acting.svg + fly + sparks(p0[0], p0[1]), center: dirtyPill(2) }) },
    { cap: '4 清乾淨了：繼續散步', note: '大便數不見了；牠繼續在牧場走來走去', html: ranch({ extra: cl({ x: WANDER[0] - 30, y: WANDER[1] + 6, facing: 'left', carry: 3 }).svg }) },
  ];
}
const FILE3 = (k) => `R29-03-掃地牛清大便-${k}-${SWEEP[k].name}-390`;
const r2903 = (k) => board({
  id: FILE3(k), title: `03 掃地牛在牧場清大便　${k}：${SWEEP[k].name}`,
  sub: '拿掉雇用面板和右上角「打掃中」：掃地牛是自己養的牛，跟其他牛一起在牧場走來走去；長大以後每 30 分鐘把大便全部清掉（v0.3 第 5.1 節）。',
  cells: cleanCells(k),
  notes: [`動起來的樣子見 GIF：${FILE3(k)}.gif（5 秒，一直循環）。`, '每 30 分鐘清一次是伺服器算的；玩家剛好在看的時候，牠就走過去一坨一坨清給你看。沒在看的時候清掉的，回來就是乾淨的，不補播。'],
});
// GIF：散步 → 清第 1 坨 → 第 2 坨 → 第 3 坨 → 繼續散步（5 秒）
const CT = [[0, 0.7, 'walk', 0], [0.7, 1.4, 'clean', 0], [1.4, 1.9, 'walk', 1], [1.9, 2.6, 'clean', 1], [2.6, 3.1, 'walk', 2], [3.1, 3.8, 'clean', 2], [3.8, 5.0, 'leave', 2]];
function gifCleaner(k, tt) {
  const C = SWEEP[k], cartK = C.kind === 'side';
  const stands = POOP3.map((p) => standAt(k, p));
  const seg2 = CT.find(([a, b]) => tt >= a && tt < b) || CT[CT.length - 1];
  const [a, b, kind, i] = seg2, u = span(tt, a, b);
  let x, y, sweep = 0, bob = 0, facing = 'right';
  if (kind === 'walk') { const from = i === 0 ? WANDER : stands[i - 1]; [x, y] = [lerp(from[0], stands[i][0], ease(u)), lerp(from[1], stands[i][1], ease(u))]; bob = Math.abs(Math.sin(u * Math.PI * 4)) * 2.4; if (stands[i][0] < from[0] && u < 0.97) facing = 'left'; }
  else if (kind === 'leave') { const to = [WANDER[0] + 20, WANDER[1] - 10]; [x, y] = [lerp(stands[2][0], to[0], ease(u)), lerp(stands[2][1], to[1], ease(u))]; bob = u < 1 ? Math.abs(Math.sin(u * Math.PI * 4)) * 2.4 : 0; }
  else [x, y] = stands[i];
  if (kind === 'clean') sweep = Math.sin(u * Math.PI * 4);
  const step = kind === 'walk' || kind === 'leave' ? (u * 3) % 1 : 0, phase = k === 'C' && kind === 'clean' ? u : null;
  const doneN = (j) => j < i || (j === i && kind === 'leave');
  const scales = POOP3.map((_, j) => (doneN(j) ? 0 : j === i && kind === 'clean' ? (k === 'C' ? (u < 0.35 ? 1 : 0) : cartK ? (u < 0.35 ? 1 : 0) : 1 - ease(span(u, 0.45, 0.9))) : 1));
  const left = scales.filter((v) => v > 0.02).length;
  const carry = Math.min(3, POOP3.filter((_, j) => doneN(j) || (j === i && kind === 'clean' && u > 0.92)).length);
  let fx = '';
  if (kind === 'clean' && u > 0.55 && k !== 'C' && !cartK) fx += sparks(POOP3[i][0], POOP3[i][1], 0.6 + 0.6 * span(u, 0.55, 1));
  if (kind === 'clean' && u > 0.35 && u < 0.6 && (k === 'C' || cartK)) fx += sparks(POOP3[i][0], POOP3[i][1], 0.8);
  const c = cleaner(k, { x, y, sweep, bob, step, phase, facing, carry, id: `g${k}` });
  if (cartK && kind === 'clean' && u > 0.35 && u < 0.92) fx += flyToCart(k, POOP3[i], c, span(u, 0.35, 0.92));
  return ranch({ extra: poopsAt(scales) + c.svg + fx, center: left ? dirtyPill(left) : '' });
}

// ================= 04、05 大便掃地機：拿掉表情和觸鬚、耐久值、壞了重新買 =================
// R1 乳牛紋圓盤（基本款）：白色圓盤、黑色乳牛斑點，前面一條粉紅色的保險桿（沒有眼睛）。R2 透明圓頂（耐用款）：看得到吸進去的大便，前面一個笑臉小螢幕。
// 兩款都拿掉底下的觸鬚（旋轉刷）。broken：保險桿變灰、小螢幕變紅 ×；tilt：歪一邊（壞掉卡住）
function robot(k, { x, y, s = 1, dir = -1, full = 0, broken = false, tilt = 0 } = {}) {
  let body;
  if (k === 'R1') {
    const spots = `<ellipse cx="-8" cy="-12" rx="6" ry="3" fill="${L}"/><ellipse cx="9" cy="-14" rx="4" ry="2.2" fill="${L}"/><ellipse cx="2" cy="-8.4" rx="3" ry="1.6" fill="${L}"/>`;
    body = `<ellipse cx="0" cy="0" rx="25" ry="10" fill="#8C8F99" stroke="${L}" stroke-width="2"/><path d="M-25 -6V0A25 10 0 0 0 25 0V-6" fill="#D9DDE6" stroke="${L}" stroke-width="2"/>
      <ellipse cx="0" cy="-6" rx="25" ry="10" fill="#FFFFFF" stroke="${L}" stroke-width="2"/>${spots}<ellipse cx="${f2(dir * 4)}" cy="-6.4" rx="16" ry="6.4" fill="none" stroke="#E7DED2" stroke-width="1.2"/>
      <path d="M${f2(dir * 25)} -4A25 10 0 0 1 ${f2(dir * 12)} 3.4" fill="none" stroke="${broken ? '#B8ADA2' : '#FF9784'}" stroke-width="3" stroke-linecap="round"/>`;
  } else {
    const inside = full ? [[-6, -10], [5, -9], [0, -15]].slice(0, full).map(([px, py]) => poopG(px, py, 9)).join('') : '';
    const sx = dir * 17;
    const face = broken
      ? `<path d="M${f2(sx - 4)} -5.4l2.4 2.4M${f2(sx - 1.6)} -5.4l-2.4 2.4M${f2(sx + 1.6)} -5.4l2.4 2.4M${f2(sx + 4)} -5.4l-2.4 2.4" stroke="#FF8A7A" stroke-width="1.3" stroke-linecap="round"/>`
      : `<path d="M${f2(sx - 3)} -4.4h0M${f2(sx + 3)} -4.4h0" stroke="#7FE0A0" stroke-width="1.8" stroke-linecap="round"/><path d="M${f2(sx - 3)} -2.4Q${f2(sx)} -0.4 ${f2(sx + 3)} -2.4" fill="none" stroke="#7FE0A0" stroke-width="1.2" stroke-linecap="round"/>`;
    body = `<ellipse cx="0" cy="0" rx="24" ry="9.6" fill="#5F7690" stroke="${L}" stroke-width="2"/><path d="M-24 -5V0A24 9.6 0 0 0 24 0V-5" fill="#9DB4CC" stroke="${L}" stroke-width="2"/>
      <ellipse cx="0" cy="-5" rx="24" ry="9.6" fill="#C6D6E6" stroke="${L}" stroke-width="2"/>${inside}
      <path d="M-15 -6C-15 -24 15 -24 15 -6Z" fill="#E6F4FF" fill-opacity="0.55" stroke="${L}" stroke-width="1.8"/><path d="M-9 -15C-7 -19 -3 -20.5 1 -20.5" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round"/>
      <rect x="${f2(sx - 6)}" y="-6.4" width="12" height="7" rx="2.4" fill="${broken ? '#4A2630' : '#2E3A48'}" stroke="${L}" stroke-width="1.2"/>${face}`;
  }
  return `<g transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s)})${tilt ? ` rotate(${f2(tilt)})` : ''}"><ellipse cx="0" cy="3" rx="26" ry="6" fill="#3E6B2A" opacity="0.18"/>${body}</g>`;
}
const chargeDock = (x, y) => `<g transform="translate(${x} ${y})"><path d="M-14 4L-11 -12H11L14 4Z" fill="#E7DED2" stroke="${L}" stroke-width="2" stroke-linejoin="round"/><path d="M-3 -9L-6 -3H0L-3 2" fill="none" stroke="#FFC13B" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></g>`;
const swirl = (x, y, s = 1) => `<g transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s)})" opacity="0.9"><path d="M-10 -6Q-2 -14 6 -6T14 -2M-8 2Q0 -4 8 2" fill="none" stroke="#FFFFFF" stroke-width="2.4" stroke-linecap="round"/></g>`;
const smoke = (x, y, tt = 0) => [0, 1, 2].map((i) => { const k = (tt * 0.7 + i / 3) % 1; return `<circle cx="${f2(x + (i - 1) * 6 + Math.sin((k + i) * 5) * 3)}" cy="${f2(y - 6 - k * 30)}" r="${f2(4 + k * 7)}" fill="#9A9DA6" opacity="${f2(0.6 * (1 - k))}"/>`; }).join('');
const zap = (x, y, s = 1) => `<path transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s)})" d="M2 -9L-5 1H0L-3 9L6 -2H1L4 -9Z" fill="#FFD45E" stroke="${L}" stroke-width="1.4" stroke-linejoin="round"/>`;
const bubbleBox = (x, y, inner, s = 1) => `<g transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s)})"><path d="M-13 -26h26a5 5 0 0 1 5 5v13a5 5 0 0 1-5 5H5l-5 6-5-6h-8a5 5 0 0 1-5-5v-13a5 5 0 0 1 5-5z" fill="#FFFFFF" stroke="${L}" stroke-width="2.2" stroke-linejoin="round"/>${inner}</g>`;
const alertBubble = (x, y, s = 1) => bubbleBox(x, y, `<path d="M0 -21v8" stroke="#E0503C" stroke-width="3.4" stroke-linecap="round"/><circle cx="0" cy="-8" r="2.1" fill="#E0503C"/>`, s);
// 兩款（v0.3 第 5.2 節：耐久值 0–100、隨機扣、扣到 0 就壞、不能修；平均壽命基本款 3 天、耐用款 7 天；價錢待重算）
const MODELS = {
  R1: { tier: '基本款', name: '乳牛紋圓盤', life: 3 },
  R2: { tier: '耐用款', name: '透明圓頂', life: 7 },
};
const durBar = (v) => `<div class="r29-dur${v <= 20 ? ' low' : v <= 50 ? ' mid' : ''}"><span class="r29-bar"><i style="width:${Math.max(0, Math.min(100, v))}%"></i></span><b class="num">耐久 ${v}</b></div>`;
const botPic = (k, w, h, o = {}) => `<svg viewBox="-34 -30 68 44" width="${w}" height="${h}">${robot(k, { x: 0, y: 0, ...o })}</svg>`;
function modelCard(k, { picked = false, owned = null, off = false } = {}) {
  const M = MODELS[k];
  return `<button class="r29-model${picked ? ' picked' : ''}${off ? ' off' : ''}">${owned != null ? '<i class="r29-chip">使用中</i>' : ''}
    <span class="r29-pic">${botPic(k, 112, 72, { full: k === 'R2' ? 2 : 0 })}</span>
    <span class="r29-name"><b>${M.name}</b><i class="r29-tier${k === 'R2' ? ' hi' : ''}">${M.tier}</i></span>
    ${owned != null ? `<span class="r29-ownbar">${durBar(owned)}</span>` : `<span class="r29-price">${icon('coin', 18)}<span class="r29-tbd">價錢待定</span></span>`}
    <span class="r29-spec"><span>${icon('clock', 14)}每 60 分鐘清一次</span><span>${icon('tools', 14)}耐久 100，平均可以用 <b>${M.life} 天</b></span></span>
    ${off ? '<span class="r29-off-note">現在這台壞了才能買</span>' : ''}${picked ? `<span class="r29-check">${icon('ok', 18)}</span>` : ''}
  </button>`;
}
// 選款式的面板。dead：壞掉的那台（重新買）；owned：還能用的那台和耐久（不能買另一款）
function modelSheet({ picked = 'R1', dead = null, owned = null } = {}) {
  const M = MODELS[picked];
  const top = dead ? `<div class="r29-dead"><span class="r29-dpic">${botPic(dead.k, 64, 44, { broken: true, tilt: -6 })}</span><div><b>你的${MODELS[dead.k].name}壞掉了</b><span>用了 ${dead.used}，耐久用完了。不能修，重新買一台（可以換款式）。</span></div></div>`
    : owned ? `<div class="r29-owned"><div class="r29-ohead"><span class="r29-opic">${botPic(owned.k, 52, 34)}</span>你的${MODELS[owned.k].name}還能用</div>${durBar(owned.v)}</div>` : '';
  const cards = ['R1', 'R2'].map((k) => modelCard(k, { picked: !owned && k === picked, owned: owned && owned.k === k ? owned.v : null, off: owned && owned.k !== k })).join('');
  const label = owned ? '還能用，不能買另一台' : `${dead ? '重新買' : '買下'}${M.name}（價錢待定）`;
  return sheet({ cls: 'r29-sheet', title: '大便掃地機', body: `${top}<p class="r29-sub">買一台就會在牧場自己跑，每 60 分鐘把大便吸乾淨。兩款清得一樣快，差在能用多久。</p>
    <div class="r29-models">${cards}</div>
    <ul class="r29-rules"><li>耐久值從 100 開始，用的時候會隨機往下扣；扣到 0 就壞了，不能修，要重新買。</li><li>一次只能有一台：還能用的時候不能買另一款。</li><li>掃地機和掃地牛可以一起用。</li></ul>
    <div class="btn-row">${btn(t('cancel'))}${btn(label, { kind: 'primary', disabled: !!owned })}</div>` });
}
// 牧場：掃地機的位置（場景座標）
const SPOTS = [[196, 452], [256, 440], [314, 456], [146, 436], [232, 470]];
const DOCK = [348, 420];
const RS = 1.4;
const BROKE = [288, 452];
const spotsAt = (scales) => SPOTS.map(([x, y], i) => ((scales[i] ?? 0) > 0.02 ? poopG(x, y, 19 * scales[i]) : '')).join('');
const brokenBot = (k, { tt = 0, fresh = false } = {}) => robot(k, { x: BROKE[0], y: BROKE[1], s: RS, dir: -1, broken: true, tilt: -7, full: k === 'R2' ? 1 : 0 })
  + smoke(BROKE[0] + 8, BROKE[1] - 20, tt) + (fresh ? zap(BROKE[0] - 26, BROKE[1] - 22, 1.2) + zap(BROKE[0] + 30, BROKE[1] - 12, 0.9) : '') + alertBubble(BROKE[0], BROKE[1] - 40, 1.1);
// 點掃地機：耐久值的小卡（跟點牛的名片同一種樣子）
function botPopHtml(k, v) {
  const M = MODELS[k];
  return `<div class="name">${M.name}<i class="r29-tier${k === 'R2' ? ' hi' : ''}">${M.tier}</i></div>${durBar(v)}<div class="meta wrap">平均可以用 ${M.life} 天；耐久扣到 0 就壞，要重新買</div>${v <= 20 ? `<p class="r29-warn-line">${icon('warn', 14)}快壞了</p>` : ''}`;
}
function botPop([sx, sy], k, v) {
  const F = sceneFit(), p = F.map([sx, sy - 18 * RS]), foot = F.map([sx, sy]);
  return popAt(p, foot[1], botPopHtml(k, v), 'r29-bot-pop', 214);
}
const RUN = [SPOTS[2][0] + 8, SPOTS[2][1] + 8];
function robotCells() {
  return [
    { cap: '1 還沒有：選款式', note: '從右上角的大便數或商店打開。拿掉「平均幾天壞一次」，改寫「耐久 100，平均可以用 3 天／7 天」；價錢待定', html: ranch({ extra: spotsAt([1, 1, 1]), center: dirtyPill(3), overlays: modelSheet({ picked: 'R1' }) }) },
    { cap: '2 在牧場自己跑', note: '乳牛紋圓盤沒有表情了，兩款底下都沒有觸鬚；右上角不顯示「掃地中」（只有大便數）', html: ranch({ extra: spotsAt([1, 1, 0.4]) + chargeDock(...DOCK) + robot('R1', { x: RUN[0], y: RUN[1], s: RS }) + swirl(SPOTS[2][0] - 26, SPOTS[2][1] - 8, 1.1), center: dirtyPill(2) }) },
    { cap: '3 點掃地機：看耐久值', note: '跳出一張小卡（跟點牛的名片一樣）：耐久還剩多少、平均可以用幾天', html: ranch({ extra: spotsAt([1, 1]) + chargeDock(...DOCK) + robot('R1', { x: RUN[0], y: RUN[1], s: RS }), center: dirtyPill(2), overlays: botPop(RUN, 'R1', 64) }) },
    { cap: '4 快壞了：耐久 20 以下變紅', note: '小卡多一行「快壞了」；不會自己跳出來提醒（使用者：不需要在畫面上顯示）', html: ranch({ extra: spotsAt([1, 1]) + chargeDock(...DOCK) + robot('R1', { x: RUN[0], y: RUN[1], s: RS }), center: dirtyPill(2), overlays: botPop(RUN, 'R1', 12) }) },
    { cap: '5 還能用的時候打開面板', note: '一次只有一台：上面是你那台的耐久，另一款要等這台壞了才能買', html: ranch({ extra: spotsAt([1, 1]) + chargeDock(...DOCK) + robot('R1', { x: RUN[0], y: RUN[1], s: RS }), center: dirtyPill(2), overlays: modelSheet({ owned: { k: 'R1', v: 64 } }) }) },
  ];
}
let BOT_PHONE = [0, 0], BUY_BTN = [290, 790], R2_CARD = [290, 600];
function brokeCells() {
  return [
    { cap: '1 耐久扣到 0：壞掉的那一刻', note: '停在原地、冒煙、閃電、頭上一個驚嘆號；下面跳一行提示', html: ranch({ extra: spotsAt([1, 1]) + chargeDock(...DOCK) + brokenBot('R1', { tt: 0.2, fresh: true }), center: dirtyPill(2), overlays: toast('warn', '掃地機壞掉了（耐久用完了）') }) },
    { cap: '2 回來才看到', note: '大便積了好幾坨（右上角的大便數變多）；機器還停在那裡', html: ranch({ extra: spotsAt([1, 1, 1, 1, 1]) + chargeDock(...DOCK) + brokenBot('R1', { tt: 0.6 }), center: dirtyPill(5) }) },
    { cap: '3 點壞掉的機器：重新買', note: '不能修（拿掉修理面板）：直接打開選款式，可以換一款', html: ranch({ extra: spotsAt([1, 1, 1, 1, 1]) + chargeDock(...DOCK) + brokenBot('R1', { tt: 0.9 }), center: dirtyPill(5), overlays: modelSheet({ picked: 'R2', dead: { k: 'R1', used: '3 天 2 小時' } }) }) },
    { cap: '4 買好了：新的一台開始動', note: '壞掉的那台收走；新的從充電座出發，耐久 100', html: ranch({ extra: spotsAt([1, 1, 1, 1, 0.4]) + chargeDock(...DOCK) + robot('R2', { x: SPOTS[4][0] + 8, y: SPOTS[4][1] + 8, s: RS, full: 1 }) + swirl(SPOTS[4][0] - 26, SPOTS[4][1] - 8, 1.1), center: dirtyPill(4), overlays: toast('ok', '買好了！透明圓頂開始動') }) },
  ];
}
const SUB_BOT = '使用者看完第 28 輪：「乳牛紋的我覺得不要有表情，此外這兩款都不要有底下那個觸鬚。我覺得不需要在畫面上顯示是否掃地中。壞掉就重新買吧，不用換了。我覺得可以有一個耐久值，這會隨機扣，扣到光就壞了，要重新購買。普通版平均三天壞，高級版七天。」';
// GIF：吸大便 → 點機器看耐久 → 過了一陣子耐久扣光 → 壞掉 → 點機器 → 重新買（換耐用款）→ 新的開始吸
const BT = 9.5;
function gifRobot(tt) {
  let scene = chargeDock(...DOCK), ov = '', n = 2;
  if (tt < 1.2) { const s2 = tt < 0.6 ? 1 : 1 - ease((tt - 0.6) / 0.5); scene += spotsAt([1, 1, s2]) + robot('R1', { x: RUN[0], y: RUN[1], s: RS }) + (tt >= 0.6 ? swirl(SPOTS[2][0] - 26, SPOTS[2][1] - 8, 1.1) : ''); n = tt < 1.0 ? 3 : 2; }
  else if (tt < 2.6) { scene += spotsAt([1, 1]) + robot('R1', { x: RUN[0], y: RUN[1], s: RS }); if (tt >= 1.5) ov += botPop(RUN, 'R1', 64); ov += finger(...BOT_PHONE, tt >= 1.35 && tt < 1.6 ? 1 : 0); }
  else if (tt < 3.6) { const v = Math.round(lerp(64, 0, ease((tt - 2.6) / 0.9))); scene += spotsAt([1, 1]) + robot('R1', { x: RUN[0], y: RUN[1], s: RS }); ov += botPop(RUN, 'R1', v) + '<div class="r29-later">過了幾天…</div>'; }
  else if (tt < 5.0) { scene += spotsAt([1, 1]) + brokenBot('R1', { tt: tt - 3.6, fresh: tt < 4.4 }); if (tt >= 3.8) ov += toast('warn', '掃地機壞掉了（耐久用完了）'); }
  else if (tt < 6.0) { const g = (i) => clamp01((tt - 5.0 - i * 0.3) / 0.25); scene += spotsAt([1, 1, g(0), g(1), g(2)]) + brokenBot('R1', { tt: tt - 3.6 }); n = 2 + (g(0) >= 1) + (g(1) >= 1) + (g(2) >= 1); if (tt >= 5.6) ov += finger(...BOT_PHONE, tt >= 5.75 ? 1 : 0); }
  else if (tt < 7.8) {
    const up = ease((tt - 6.0) / 0.3), picked = tt >= 6.8 ? 'R2' : 'R1';
    scene += spotsAt([1, 1, 1, 1, 1]) + brokenBot('R1', { tt: tt - 3.6 }); n = 5;
    ov += modelSheet({ picked, dead: { k: 'R1', used: '3 天 2 小時' } }).replace('<div class="backdrop"></div>', `<div class="backdrop" style="opacity:${f2(up)}"></div>`).replace('<section class="sheet', `<section style="transform:translateY(${f2((1 - up) * 100)}%)" class="sheet`);
    if (tt >= 6.4 && tt < 7.0) ov += finger(...R2_CARD, tt >= 6.65 ? 1 : 0);
    if (tt >= 7.1) ov += finger(...BUY_BTN, tt >= 7.4 && tt < 7.7 ? 1 : 0);
  } else {
    const u = ease((tt - 7.8) / 0.8), from = [DOCK[0] - 6, DOCK[1] + 14], to = [SPOTS[4][0] + 8, SPOTS[4][1] + 8];
    const s4 = tt < 8.6 ? 1 : 1 - ease((tt - 8.6) / 0.5);
    scene += spotsAt([1, 1, 1, 1, s4]) + robot('R2', { x: lerp(from[0], to[0], u), y: lerp(from[1], to[1], u), s: RS, full: tt >= 9.1 ? 1 : 0 }) + (tt >= 8.6 ? swirl(SPOTS[4][0] - 26, SPOTS[4][1] - 8, 1.1) : '');
    n = tt >= 9.1 ? 4 : 5;
    if (tt < 9.0) ov += toast('ok', '買好了！透明圓頂開始動');
  }
  return ranch({ extra: scene, center: dirtyPill(n), overlays: ov });
}

// ================= 06 飼料列：沒有底板、收起、吃完跳隨機公斤數 =================
// 肚子餓的圖示（第 26 輪 A：空碗加問號，使用者選的）
const bowlBase = (cx, cy, sc = 1) => `<g transform="translate(${cx} ${cy}) scale(${sc})"><path d="M-10 -1h20c0 5.6-4.4 9.6-10 9.6S-10 4.6-10-1z" fill="#F2C489" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/><ellipse cx="0" cy="-1" rx="10" ry="2.6" fill="#E9DCC6" stroke="${L}" stroke-width="1.4"/><path d="M-6.4 3.6q2.4 1.6 4.6 1.4" fill="none" stroke="#FFF1D8" stroke-width="1.4" stroke-linecap="round"/></g>`;
const hungrySvg = () => `<svg viewBox="0 0 40 46" width="38" height="44"><circle cx="20" cy="26" r="17.5" fill="#FFFFFF" stroke="${L}" stroke-width="2"/>${bowlBase(20, 30)}<path d="M15.6 12.4q0-5.2 4.8-5.2 4.8 0 4.8 4.2 0 2.8-2.8 4-2 .9-2 3" fill="none" stroke="${L}" stroke-width="4.8" stroke-linecap="round"/><path d="M15.6 12.4q0-5.2 4.8-5.2 4.8 0 4.8 4.2 0 2.8-2.8 4-2 .9-2 3" fill="none" stroke="#FF9784" stroke-width="2.6" stroke-linecap="round"/><circle cx="20.4" cy="22.6" r="2" fill="#FF9784" stroke="${L}" stroke-width="1.2"/></svg>`;
const hungry = ([x, y], bob = 0) => `<span class="hungry26" style="left:${f2(x)}px;top:${f2(y - 4 - bob)}px">${hungrySvg()}</span>`;
const kgPop = (x, y, txt) => `<span class="kg-pop" style="left:${f2(x)}px;top:${f2(y)}px">${txt}</span>`;
const chew = (x, y) => `<span class="chew" style="left:${f2(x)}px;top:${f2(y)}px">嚼嚼</span>`;
const drag = (k, x, y) => `<span class="drag26" style="left:${f2(x - 18)}px;top:${f2(y - 18)}px">${fic(k, 36)}</span>`;
const feedOnGround = (k, x, y, { s = 1 } = {}) => `<g><ellipse cx="${f2(x)}" cy="${f2(y + 2)}" rx="${f2(13 * s)}" ry="${f2(4 * s)}" fill="#3E6B2A" opacity="0.22"/>${fic(k, Math.round(30 * s)).replace('<svg ', `<svg x="${f2(x - 15 * s)}" y="${f2(y - 28 * s)}" `)}</g>`;
const dust = (x, y, k) => [[-16, -3, 5], [14, -2, 4.5], [-4, -8, 3.6]].map(([dx, dy, r]) => `<circle cx="${f2(x + dx * (0.6 + k))}" cy="${f2(y + dy * (0.6 + k))}" r="${f2(r * (1 + k * 0.6))}" fill="#F4E8D2" opacity="${f2(0.9 * (1 - k))}"/>`).join('');
// 丟飼料的牧場（第 26 輪的樣子：小牛在右下角，中間空出來）
const HERDF = HERD.map((h) => (h.id === 15 ? { ...h, x: 296, y: 486, facing: 'left', depth: 1 } : h)).filter((h) => h.id !== 11);
const D1 = [190, 470];
const FEED = 'corn';
let SLOT = [339, 600]; // 玉米袋的中心（手機座標；measure() 量）
const eatPos = (cow, [dx, dy]) => { const right = dx > cow.x; return { x: dx + (right ? -46 : 46), y: dy + 6, facing: right ? 'right' : 'left' }; };
const herdWith = (id, pos) => HERDF.map((h) => (h.id === id ? { ...h, ...pos } : h));
const anchorsOf = (herd) => ranchScene(dev, herd, { wide: true }).anchors;
const KG_TXT = '+5.6 公斤'; // 這次長了幾公斤（隨機：平均的 0.5–1.5 倍，玉米平均 5）
function throwScene(tt) {
  const F = ranchScene(dev, HERDF, { wide: true }).fit, Dp = F.map(D1);
  let herd = HERDF, extra = '', ov = '', fin = '';
  const bo = { lift: '', used: '' };
  if (tt < 0.5) { bo.lift = FEED; fin = finger(SLOT[0] + 4, SLOT[1] + 4); }
  else if (tt < 1.3) { const e = ease((tt - 0.5) / 0.8); const x = lerp(SLOT[0], Dp[0], e), y = lerp(SLOT[1], Dp[1] - 10, e) - Math.sin(e * Math.PI) * 60; bo.lift = FEED; bo.used = FEED; ov += drag(FEED, x, y); fin = finger(x + 8, y + 18); }
  else bo.used = FEED;
  const cow = HERDF.find((h) => h.id === 12), E = eatPos(cow, D1);
  const we = ease((tt - 2.0) / 1.3);
  if (tt >= 2.0) herd = herdWith(12, { x: lerp(cow.x, E.x, we), y: lerp(cow.y, E.y, we), facing: E.facing });
  const eat = clamp01((tt - 3.4) / 0.8);
  if (tt >= 1.3 && eat < 1) extra += feedOnGround(FEED, D1[0], D1[1], { s: 1 - eat * 0.9 }) + (tt < 1.8 ? dust(D1[0], D1[1], (tt - 1.3) / 0.5) : '');
  const an = anchorsOf(herd);
  if (tt < 3.8) ov += hungry(an[12].head);
  ov += hungry(an[7].head);
  if (tt >= 3.4 && tt < 4.2) ov += chew(an[12].head[0] + 26, an[12].head[1] + 18);
  if (tt >= 3.9 && tt < 5.6) ov += kgPop(an[12].head[0] + 52, an[12].head[1] - 4 - (tt - 3.9) * 12, KG_TXT);
  return ranch({ herd, extra, bar: bo, overlays: ov + fin });
}
function feedCells() {
  const an0 = anchorsOf(HERDF);
  const normal = ranch({ herd: HERDF, overlays: hungry(an0[12].head) + hungry(an0[7].head) });
  return [
    { cap: '1 平常：飼料袋下面只寫名字', note: '拿掉「+5kg」（每次長的公斤數是隨機的）；肚子餓的牛頭上才有空碗加問號', html: normal },
    { cap: '2 按「收起」（提案）：奶桶和飼料一起收', note: '只剩牧場；「展開」那顆帶著奶桶的 %，收起來也看得到奶桶快滿了', html: ranch({ herd: HERDF, fold: 'all', overlays: hungry(an0[12].head) + hungry(an0[7].head) }) },
    { cap: '3 收起時奶桶滿了', note: '「展開」那顆變藍、寫「滿了」（滿了就不會再產奶，要記得收）', html: ranch({ herd: HERDF, fold: 'all', pail: 100 }) },
    { cap: '另一種：收起只收奶桶', note: '飼料袋留著，收起來也能丟飼料；牧場看到的範圍比提案少一排袋子', html: ranch({ herd: HERDF, fold: 'bucket', overlays: hungry(an0[12].head) + hungry(an0[7].head) }) },
    { cap: '4 吃完：頭上跳這次長了幾公斤', note: '每次隨機（平均的 0.5–1.5 倍，玉米平均 5 公斤），所以會跳「+5.6 公斤」這種數字', html: throwScene(4.4) },
  ];
}

// ================= 07 大便第 10 坨以後：右半邊 9 個位置 =================
// cow-ui 2026-10-10 排的（ceo 先定鏡射，cow-app 看到有幾坨落在池塘、石頭上）；cow-app #200 已經換成這個清單
const RIGHT9 = [[544, 398], [700, 360], [430, 404], [648, 412], [506, 366], [740, 412], [576, 338], [418, 448], [756, 356]];
const MIRROR = POOP_SPOTS.map(([x, y]) => [WIDE - x, y]);
function poopBoard() {
  const ALL = [...POOP_SPOTS, ...RIGHT9];
  const label = (x, y, i, col) => `<g><circle cx="${x}" cy="${y - 9}" r="15" fill="none" stroke="${col}" stroke-width="2.4" stroke-dasharray="3 3"/><text x="${x + 13}" y="${y - 21}" font-size="16" font-weight="900" fill="${col}" stroke="#FFFFFF" stroke-width="3.4" paint-order="stroke">${i + 1}</text></g>`;
  const marks = ALL.map(([x, y], i) => poopG(x, y, 19) + label(x, y, i, i < 9 ? '#2F6FB0' : '#E0503C')).join('');
  const sc = ranchScene({ w: WIDE, h: 844 }, HERD, { wide: true, extra: marks });
  const S = 0.9;
  const full = sc.svg.replace(/viewBox="[^"]+" width="\d+" height="\d+"/, `viewBox="0 150 ${WIDE} 420" width="${f2(WIDE * S)}" height="${f2(420 * S)}"`);
  const phone = (pan, idx) => {
    let html = ranch({ herd: HERD, pan, center: dirtyPill(18) });
    const pts = idx.map((i) => ALL[i]);
    return html.replace(/(<div class="scene">[\s\S]*?)(<\/svg>\s*<\/div>)/, (m, a, b) => a + pts.map(([x, y], j) => poopG(x, y, 19) + label(x, y, idx[j], idx[j] < 9 ? '#2F6FB0' : '#E0503C')).join('') + b);
  };
  const rows = ALL.map(([x, y], i) => `<tr><td>${i + 1}</td><td class="${i >= 9 ? 'new' : ''}">${x}, ${y}</td><td>${i < 9 ? '左半邊（M2 原本的）' : `右半邊（鏡射是 ${MIRROR[i - 9].join(', ')}）`}</td></tr>`).join('');
  return board({
    id: 'R29-07-大便-18個位置-390', title: '07 大便第 10 坨以後：右半邊 9 個位置（最多畫 18 坨）', width: PAD * 2 + 1240,
    sub: 'ceo 定：先把左半邊 9 個位置左右鏡射到右半邊。cow-app 照做後，有 3 坨落在池塘水面、1 坨在石頭上、1 坨被黑牛和「收起」擋住；cow-ui 改排右半邊 9 個，cow-app #200 已經換成這個清單。',
    cells: [
      { cap: '往左捲到底：第 1–9 坨', note: '跟 M2 一樣（藍色）', html: phone(0, [0, 1, 2, 3, 4, 5, 6, 7, 8]) },
      { cap: '往右捲到底：第 10–18 坨', note: '新的（紅色）：都在草地上', html: phone(390, [9, 10, 11, 12, 13, 14, 15, 16, 17]) },
    ],
    body: `<div class="r29-pp"><div><div class="r29-pp-cap">整片牧場（兩個螢幕寬，場景座標）<small>藍：M2 原本的 9 個；紅：右半邊新的 9 個（號碼是第幾坨，第 10 坨以後才出現）</small></div><div class="r29-pp-full">${full}</div></div>
      <div><div class="r29-pp-cap">18 個位置（大便的底部中間）<small>跟 poop.js 的 POOP_SPOTS 同一種格式</small></div><table><tr><th>第幾坨</th><th>x, y</th><th>說明</th></tr>${rows}</table></div></div>`,
    notes: [
      '右半邊的 9 個都避開：池塘（含岸邊 14 的範圍）、池塘邊的石頭、水槽、花叢、乾草捲，以及兩頭牛的預設位置（安格斯公牛 x 410、和牛 x 724）。',
      'y 都在 448 以內：原本的面板（「收起」那排從 y 495 開始）和這一輪沒底板的飼料列（從 y 526 開始）都蓋不到。第 18 坨在 x 756，往右捲到底時在手機 x 366，看得到。',
      'M2 的 poop.js 等這一輪看完，跟其他改動一起補上第 10–18 個（現在 app 先照 cow-app #200 的清單）。',
    ],
  });
}

// ================= 總覽 =================
function r2999() {
  const S = 0.5, sw = Math.round(dev.w * S), sh = Math.round(dev.h * S);
  const mini = (html) => `<div class="ov-ph" style="width:${sw}px;height:${sh}px"><div style="transform:scale(${S});transform-origin:0 0">${html}</div></div>`;
  const cell = (cap, inner) => `<div class="ov-cell"><div class="ov-cap"><b>${cap}</b></div>${inner}</div>`;
  const row = (title, cells) => `<div class="ov-row"><div class="ov-title">${title}</div><div class="ov-cells">${cells.join('')}</div></div>`;
  const big = (k) => `<div class="ov-art">${cleanerArt(k, 190, 150)}</div>`;
  const body = row('01、03 掃地牛五種（特別牛）：在牧場清大便', SW.map((k) => cell(`${k}　${SWEEP[k].name}${k === 'B3' ? '（重畫）' : ''}`, big(k) + mini(cleanCells(k)[2].html))))
    + row('02 掃地牛的格式（用 A 當例子）', [cell('圖鑑「其他」', mini(codexOther())), cell('圖鑑詳細', mini(sweepDetail('A'))), cell('牧場裡的名片', mini(ranchCard())), cell('牛的詳細', mini(sweepCowPage()))])
    + row('04、05 掃地機：耐久值、壞了重新買', [cell('選款式', mini(robotCells()[0].html)), cell('點機器看耐久', mini(robotCells()[2].html)), cell('壞掉了', mini(brokeCells()[1].html)), cell('重新買', mini(brokeCells()[2].html))])
    + row('06 飼料列（收起選一種）、07 大便位置', [cell('平常', mini(feedCells()[0].html)), cell('收起（提案）', mini(feedCells()[1].html)), cell('另一種：只收奶桶', mini(feedCells()[3].html)), cell('右半邊 9 個大便', mini(poopBoardPhone()))]);
  return { html: `<div class="board" style="width:${PAD * 2 + 5 * sw + 4 * 28 + 10}px"><div class="b-label">R29-99-總覽對照</div><div class="b-title">第 29 輪：掃地牛（特別牛）、掃地機（耐久值）、飼料列收起、大便 18 個位置</div>
    <div class="b-sub">要使用者選的只有 06「收起」一題（提案：奶桶和飼料一起收；另一種：只收奶桶）。其他照使用者的回答改好，看完說可以或要改哪裡。各自的圖見 R29-01～07，動起來的樣子見 GIF。</div>${body}</div>` };
}
const poopBoardPhone = () => { const ALL = [...POOP_SPOTS, ...RIGHT9]; return ranch({ herd: HERD, pan: 390, center: dirtyPill(18), extra: ALL.slice(9).map(([x, y]) => poopG(x, y, 19)).join('') }); };

// ================= 說明圖、GIF 清單 =================
const BOARDS = [
  { id: 'R29-01', render: r2901 },
  { id: 'R29-02', render: r2902 },
  ...SW.map((k) => ({ id: `R29-03-${k}`, render: () => r2903(k) })),
  { id: 'R29-04', render: () => board({ id: 'R29-04-掃地機-選款式和耐久值-390', title: '04 掃地機：選款式、看耐久值（拿掉表情、觸鬚、「掃地中」）', sub: SUB_BOT, cells: robotCells(),
    notes: ['耐久值放兩個地方（提案）：點機器跳出的小卡、購買面板。牧場上平常不顯示（使用者：不需要在畫面上顯示是否掃地中）。', '價錢等 cow-back 照新規則重算（起點 3,000／12,000），這一輪先寫「價錢待定」。', '透明圓頂的笑臉小螢幕留著（使用者只說乳牛紋的不要表情）。'] }) },
  { id: 'R29-05', render: () => board({ id: 'R29-05-掃地機-壞掉重新買-390', title: '05 掃地機：耐久扣到 0 就壞，重新買（不能修）', sub: SUB_BOT, cells: brokeCells(),
    notes: ['拿掉第 28 輪的修理面板、「已經有一台想換別款」那張：壞了就重新買，買的時候挑款式。', '動起來的樣子：R29-05-掃地機-壞掉到重新買-390.gif（耐久扣光 → 壞掉 → 點機器 → 換耐用款 → 新的開始吸）。'] }) },
  { id: 'R29-06', render: () => board({ id: 'R29-06-飼料列-收起和隨機公斤-390', title: '06 飼料列：沒有底板、收起連奶桶一起收、吃完跳隨機公斤數', cols: 5,
    sub: '使用者看完第 26 輪：飼料列「沒有底板，然後我覺得按收起要連奶桶也收」；肚子餓的圖示「A 空碗問號」；丟飼料可以，但「飼料底下不用寫加給公斤，這是隨機的」（每次長的公斤數改成隨機，吃完才顯示）。',
    cells: feedCells(),
    notes: ['收起要選一種：提案（2、3）奶桶和飼料一起收，牧場看得最多，「展開」那顆帶奶桶的 %；另一種只收奶桶，飼料袋留著，收起來也能丟飼料。', '原本 M2 收起時留一條奶桶（收奶最常按）；使用者說奶桶也要收，所以改成把奶桶的 % 放在「展開」上，滿了變藍。', '動起來的樣子：R29-06-丟飼料-吃完跳隨機公斤-390.gif。核准後 S03 的牧場頁（S03-01 等有下方面板的）和收起（S03-11、S03-12）會跟著改。'] }) },
  { id: 'R29-07', render: poopBoard },
  { id: 'R29-99', render: r2999 },
];
const GIFS = {
  ...Object.fromEntries(SW.map((k) => [k, { fn: (tt) => gifCleaner(k, tt), file: FILE3(k), total: 5 }])),
  BOT: { fn: gifRobot, file: 'R29-05-掃地機-壞掉到重新買-390', total: BT },
  FEED: { fn: throwScene, file: 'R29-06-丟飼料-吃完跳隨機公斤-390', total: 6 },
};

async function settle() {
  await document.fonts.ready;
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
}
// 量：掃地機在手機上的位置、面板裡耐用款那張卡和購買鈕、玉米袋（手指要點在上面）
async function measure() {
  const F = sceneFit();
  BOT_PHONE = F.map([RUN[0], RUN[1] - 8]).map(Math.round);
  app.innerHTML = `<div class="gif-box">${ranch({ overlays: modelSheet({ picked: 'R2', dead: { k: 'R1', used: '3 天 2 小時' } }) })}</div>`;
  await settle();
  const ph = app.querySelector('.phone').getBoundingClientRect();
  const c = (el) => { const b = el.getBoundingClientRect(); return [Math.round(b.left + b.width / 2 - ph.left), Math.round(b.top + b.height / 2 - ph.top)]; };
  BUY_BTN = c([...app.querySelectorAll('.r29-sheet .btn-row .btn')].pop());
  R2_CARD = c(app.querySelectorAll('.r29-model')[1].querySelector('.r29-pic'));
  app.innerHTML = `<div class="gif-box">${ranch({ herd: HERDF })}</div>`;
  await settle();
  const ph2 = app.querySelector('.phone').getBoundingClientRect();
  const sk = app.querySelectorAll('.fb-item')[FEED_KEYS.indexOf(FEED)].querySelector('.sack').getBoundingClientRect();
  SLOT = [Math.round(sk.left + sk.width / 2 - ph2.left), Math.round(sk.top + sk.height / 2 - ph2.top)];
  app.innerHTML = '';
}
if (q.has('art')) { // 除錯用：大圖（成牛、小牛）
  const k = q.get('art');
  app.innerHTML = `<div class="art-dbg" style="display:flex;gap:20px;padding:20px;background:#FFFFFF">${cleanerArt(k, 640, 460)}${cleanerArt(k, 360, 280, { age: 'calf' })}</div>`;
  await settle();
  window.__ready = true;
} else if (q.has('list')) {
  window.__boards = BOARDS.map(({ id }) => ({ id, w: 390 }));
  window.__gifs = Object.keys(GIFS);
  window.__ready = true;
} else if (q.has('gif')) {
  await measure();
  const g = GIFS[q.get('gif')];
  if (!g) throw new Error(`沒有這個 GIF：${q.get('gif')}`);
  window.__frame = async (tt) => { app.innerHTML = `<div class="gif-box"><div class="gif-label">${g.file}</div>${g.fn(tt)}</div>`; await settle(); placeCowPop(app) && (await settle()); };
  window.__gif = { file: g.file, total: g.total };
  await window.__frame(0);
  window.__ready = true;
} else {
  await measure();
  const b = BOARDS.find((x) => x.id === q.get('b'));
  if (!b) throw new Error(`沒有這張：${q.get('b')}`);
  app.innerHTML = b.render().html;
  await settle();
  if (fitTitles(app)) await settle();
  if (fitOriginTags(app) + placeVersion(app)) await settle();
  if (placeCowPop(app)) await settle();
  const el = app.querySelector('.board');
  window.__file = el.querySelector('.b-label').textContent;
  window.__size = { w: Math.ceil(el.offsetWidth), h: Math.ceil(el.offsetHeight) };
  window.__ready = true;
}
