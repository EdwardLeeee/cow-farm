// 第 20 輪草稿（ceo 2026-10-09 交辦）：使用者看完雅兒貝德比對圖：「你改做成打掃牛，有一隻牛會來打掃。還有作一個大便掃地機給我看看。」
//   01 打掃牛 A／B／C（核准的牛產生器＋配件）：牧場裡走來走去清大便、雇用面板（一天 2,000）、右上角「打掃中」。
//   02 大便掃地機 A／B：在牧場自己跑、把大便吸走；購買面板（價錢、規則待定）。每個都有分鏡和 GIF，另加總覽 R20-99。
// 元件、字串、假資料、牛的產生器都用 M2 設計稿（design/m2，含 PR 5 的集點卡和飼料圖示）。新的字是草稿，直接寫在這裡，沒有進字串表：
// 使用者選完才加 key、翻英文和泰文（D25）。網址：r20.html?b=R20-01-A；GIF：r20.html?gif=A；?list=1 列出全部說明圖。
import { applyDevice, frame, btn, icon, fmt, badge, cowSVG, cowFace, useChip, sexText, sheet, toast, fitTitles, fitOriginTags, placeVersion, fitSwipeHint, fitMiniLines, placeCowPop, fitGrade, fitActions, BREEDS } from '../../../m2/src/js/kit.js';
import { loadLang, t, dur, calfName } from '../../../m2/src/js/i18n.js';
import { PEN } from '../../../m2/src/js/fixtures.js';
import { ranchScene, HERD } from '../../../m2/src/js/scene.js';
import { drawCow } from '../../../m2/src/cow/render.js';
import { poopG } from '../../../m2/src/js/poop.js';
import { genesFor } from '../../../m2/src/cow/breeds.js';
import { renderCow as renderHead } from './r11h.js';

const L = '#4B3326';
const f2 = (v) => Math.round(v * 100) / 100;
// 字串表在 design/m2/i18n：loadLang 抓 ../i18n/…（相對於頁面），轉到 m2 的資料夾
const realFetch = window.fetch.bind(window);
window.fetch = (u, o) => realFetch(typeof u === 'string' && u.startsWith('../i18n/') ? `../../../m2/${u.slice(3)}` : u, o);
const q = new URLSearchParams(location.search);
const W = +(q.get('w') || 390);
const dev = applyDevice(W);
const app = document.getElementById('app');
await loadLang('zh-Hant');
const { ranchPage, dirtyPill } = await import('../../../m2/src/js/screens/s03.js');
const ctx0 = () => ({ dev, w: dev.w, q: new URLSearchParams() });

// ---------- 說明圖的版面（跟第 18 輪一樣） ----------
const PAD = 36, GAP = 40;
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
  return { html };
}
const POINTER = (s = 34) => `<svg viewBox="0 0 32 34" width="${s}" height="${Math.round(s * 34 / 32)}" aria-hidden="true"><path d="M11 4.4a2.3 2.3 0 0 1 4.6 0v9.8l1.2-.3a2.1 2.1 0 0 1 2.6 1.5l.1.5 1.1-.2a2.1 2.1 0 0 1 2.5 1.6l.1.5h.8a2.1 2.1 0 0 1 2.2 2.1v4.6c0 4.8-3.3 8.1-7.9 8.1h-1.5c-2.7 0-4.6-1.1-6.2-3.4l-4.8-6.7a2.1 2.1 0 0 1 3.1-2.8l2.1 2.3z" fill="#FFE3D2" stroke="${L}" stroke-width="2" stroke-linejoin="round"/><path d="M15.6 14.2v3.6M19.5 15.4v2.8M23.2 17.1v2" stroke="${L}" stroke-width="1.6" stroke-linecap="round"/></svg>`;
const finger = (x, y, s = 40) => `<div class="gesture" style="left:${f2(x - 13 * s / 32)}px;top:${f2(y - 2)}px">${POINTER(s)}</div>`;

// ---------- 飼料（v0.3 第 2.1 節；數字是起點） ----------
const KG = { grass: 1, hay: 1.5, oats: 2, alfalfa: 3, corn: 5, soy: 8 };
const STOCK = { grass: 24, hay: 12, oats: 8, alfalfa: 0, corn: 5, soy: 3 };
const fName = (k) => t(`feed.${k}`);
const fic = (k, s = 22) => icon(`feed_${k}`, s);
const kgText = (k) => `+${KG[k]} 公斤`;

// ================= 打掃牛：核准的牛產生器（第 11 輪畫風）＋配件 =================
// 原創：不是任何遊戲的吉祥物；配件只有頭巾、掃把、圍裙、推車、草帽、鏟子、水桶這些農場用品。
const SIDE_S = 0.9; // 場景裡的大小（跟中間那排的牛差不多）
const geo = (r, ground) => {
  const fx = r.face.cx, fy = r.face.cy, fr = r.face.r;
  const dir = Math.sign(fx - r.shadow.cx) || -1; // 頭朝哪邊（側面）
  return { fx, fy, fr, dir, back: -dir, bodyCx: r.shadow.cx, bodyHalf: r.shadow.rx / 1.24, h: r.height, ground };
};
const stick = (x0, y0, x1, y1, w = 3.2) => `<path d="M${f2(x0)} ${f2(y0)}L${f2(x1)} ${f2(y1)}" stroke="${L}" stroke-width="${w + 2.4}" stroke-linecap="round"/><path d="M${f2(x0)} ${f2(y0)}L${f2(x1)} ${f2(y1)}" stroke="#C98E5E" stroke-width="${w}" stroke-linecap="round"/>`;
// 掃把頭：在 (x, y) 往下展開的一把乾草（a：掃把的角度）
const broomHead = (x, y, s, a = 0) => `<g transform="translate(${f2(x)} ${f2(y)}) rotate(${f2(a)}) scale(${f2(s)})"><path d="M-4 -6L4 -6L12 10L-12 10Z" fill="#F0CD6E" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/><path d="M-6 -1L-9 9M-2 -1L-3 9M2 -1L3 9M6 -1L9 9" stroke="#C99A34" stroke-width="1.1"/><rect x="-5" y="-8.5" width="10" height="4" rx="1.5" fill="#D2553B" stroke="${L}" stroke-width="1.4"/></g>`;
// 紅色點點頭巾（蓋在頭頂，後面打一個結）
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
// 水桶（掛在脖子上）
const bucket = (x, y, s, poops = 0) => `<g transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s)})"><path d="M-8 -14Q0 -22 8 -14" fill="none" stroke="${L}" stroke-width="1.6"/>${poops ? poopG(0, -8, 9) : ''}<path d="M-9 -10L9 -10L7 4L-7 4Z" fill="#7FB3E0" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/><path d="M-8.4 -6.4H8.4" stroke="#5B8FD9" stroke-width="1.6"/></g>`;
// 小推車（木箱、一個輪子；裡面是收走的大便）
function cart(x, y, s, n = 0) {
  const poops = [[-9, -14], [4, -15], [-2, -18]].slice(0, n).map(([px, py]) => poopG(px, py, 11)).join('');
  return `<g transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s)})">${poops}<path d="M-20 -14L20 -14L16 4L-16 4Z" fill="#D9A066" stroke="${L}" stroke-width="2" stroke-linejoin="round"/>
    <path d="M-18 -8H18M-17 -2H17" stroke="#B57B45" stroke-width="1.4"/><circle cx="0" cy="8" r="7" fill="#8C6A4A" stroke="${L}" stroke-width="2"/><circle cx="0" cy="8" r="2.4" fill="#F0CD6E" stroke="${L}" stroke-width="1"/></g>`;
}
// 配件：back 畫在牛後面、front 畫在牛前面。sweep：掃把／鏟子的角度（動畫）；carry：推車、水桶裡有幾坨
function accA(r, g, { pose, sweep = 0 }) {
  if (pose === 'front') return { back: stick(g.fx + g.fr * 1.75, g.fy + g.fr * 0.1, g.fx + g.fr * 2.0, g.ground - 10) + broomHead(g.fx + g.fr * 2.0, g.ground - 8, 1.1), front: bandana(g, true) };
  const mx = g.fx + g.dir * g.fr * 0.72, my = g.fy + g.fr * 0.5;
  const tx = g.fx + g.dir * g.fr * 2.5 + sweep * g.dir, ty = g.ground - 6;
  return { back: '', front: stick(mx, my, tx, ty) + broomHead(tx, ty, 1, g.dir * -28 + sweep * 2) + bandana(g, false), tip: [tx, ty] };
}
function accB(r, g, { pose, carry = 0 }) {
  const { fx, fy, fr, dir, back } = g;
  if (pose === 'front') {
    const top = fy + fr * 0.95, bot = fy + fr * 2.3, w = fr * 0.8;
    return { back: '', front: `<path d="M${f2(fx - w * 0.7)} ${f2(top)}Q${f2(fx)} ${f2(top - fr * 0.9)} ${f2(fx + w * 0.7)} ${f2(top)}" fill="none" stroke="#FFFFFF" stroke-width="3"/><path d="M${f2(fx - w)} ${f2(top)}L${f2(fx + w)} ${f2(top)}L${f2(fx + w * 0.9)} ${f2(bot)}Q${f2(fx)} ${f2(bot + fr * 0.2)} ${f2(fx - w * 0.9)} ${f2(bot)}Z" fill="#5B8FD9" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/>
      <rect x="${f2(fx - w * 0.45)}" y="${f2(top + fr * 0.5)}" width="${f2(w * 0.9)}" height="${f2(fr * 0.45)}" rx="${f2(fr * 0.1)}" fill="#8FB8EE" stroke="${L}" stroke-width="1.4"/>` };
  }
  // 側面：圍裙像圍兜一樣從脖子垂下來，蓋住頭下面的胸口
  const top = fy + fr * 0.85, bot = g.ground - g.h * 0.2, x0 = fx + back * fr * 0.05, x1 = fx + back * fr * 0.85;
  const apron = `<path d="M${f2(x0)} ${f2(top)}L${f2(x1)} ${f2(top)}L${f2(x1 + back * fr * 0.08)} ${f2(bot)}Q${f2((x0 + x1) / 2)} ${f2(bot + fr * 0.22)} ${f2(x0 - back * fr * 0.08)} ${f2(bot)}Z" fill="#5B8FD9" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/>
    <rect x="${f2(Math.min(x0, x1) + fr * 0.17)}" y="${f2(top + (bot - top) * 0.45)}" width="${f2(fr * 0.46)}" height="${f2(fr * 0.36)}" rx="${f2(fr * 0.08)}" fill="#8FB8EE" stroke="${L}" stroke-width="1.3"/>`;
  const cx = g.bodyCx + back * (g.bodyHalf + 30), cy = g.ground - 14;
  const rope = `<path d="M${f2(g.bodyCx + back * g.bodyHalf * 0.85)} ${f2(g.ground - g.h * 0.48)}Q${f2(cx - back * 14)} ${f2(cy - 22)} ${f2(cx - back * 18)} ${f2(cy - 10)}" fill="none" stroke="${L}" stroke-width="3.6" stroke-linecap="round"/><path d="M${f2(g.bodyCx + back * g.bodyHalf * 0.85)} ${f2(g.ground - g.h * 0.48)}Q${f2(cx - back * 14)} ${f2(cy - 22)} ${f2(cx - back * 18)} ${f2(cy - 10)}" fill="none" stroke="#D8A66A" stroke-width="1.8" stroke-linecap="round"/>`;
  return { back: cart(cx, cy, 1, carry) + rope, front: apron, cart: [cx, cy - 16] };
}
function accC(r, g, { pose, sweep = 0, carry = 0 }) {
  const { fx, fy, fr, dir, back } = g;
  if (pose === 'front') return { back: stick(fx + fr * 1.7, fy + fr * 0.2, fx + fr * 1.9, g.ground - 12) + `<path d="M${f2(fx + fr * 1.9 - 8)} ${f2(g.ground - 14)}h16l-2 12h-12z" fill="#B9C3CC" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/>`, front: bucket(fx, fy + fr * 2.1, 1.1, carry) + strawHat(g) };
  const mx = fx + dir * fr * 0.7, my = fy + fr * 0.5, tx = fx + dir * fr * 2.2 + sweep * dir, ty = g.ground - 6 - Math.abs(sweep) * 0.4;
  const blade = `<g transform="translate(${f2(tx)} ${f2(ty)}) rotate(${f2(dir * -20)})"><path d="M-8 -6h16l-1 9q-7 4 -14 0z" fill="#B9C3CC" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/></g>`;
  // 水桶掛在脖子上、垂在胸口前面
  const rope = `<path d="M${f2(fx + back * fr * 0.15)} ${f2(fy + fr * 0.75)}L${f2(fx + back * fr * 0.45)} ${f2(fy + fr * 1.15)}" stroke="${L}" stroke-width="1.6"/>`;
  return { back: '', front: rope + bucket(fx + back * fr * 0.5, fy + fr * 1.75, 0.95, carry) + stick(mx, my, tx, ty) + blade + strawHat(g), tip: [tx, ty] };
}
// ================= 第 25 輪：打掃牛重畫（ceo 2026-10-09 轉達，使用者：「a的手看起來超怪，你多花時間慢慢畫畫，想好在畫，人掃地也是兩隻手」「b1 的牛你該重新設計，衣服是畫在身上，不是這樣浮貼在身上」「b3 跟c 是可以，但可以調整一下」） =================
// 先想好姿勢再畫（參考人掃地、鏟東西、推推車的樣子，自己看懂後重畫，沒有描圖）：
//   掃地：掃把斜斜擋在身體前面；上面的手握在掃把柄的上端（胸口、另一邊），下面的手握在柄的中間（腰邊、掃把那一邊）；掃把頭在腳旁邊的地上。掃的時候上面的手不動、下面的手跟著掃把走。
//   鏟：兩隻手都握在鏟柄上：後面的手握在柄尾（另一邊的腰），前面的手握在柄的中間；身體往前傾一點，鏟頭貼著地。水桶放在地上，鏟起來倒進去。
//   推推車：兩隻手各握一根把手（腰的高度）；身體往推車那邊傾；遠的那隻手大部分被身體擋住，只露出前臂和手。
//   衣服：用身體的外框裁切、順著身體的曲線（腰線往下彎、兩邊暗一點看得出圓）、有縫線和皺褶；手臂畫在衣服上面，擋得到的地方就擋住。
const hexMix = (a, b, k) => { const p = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)); const A = p(a), B = p(b); return `#${A.map((v, i) => Math.round(v + (B[i] - v) * k).toString(16).padStart(2, '0')).join('')}`; };
const limb = (x0, y0, x1, y1, w, fill) => `<path d="M${f2(x0)} ${f2(y0)}L${f2(x1)} ${f2(y1)}" stroke="${L}" stroke-width="${f2(w + 2.6)}" stroke-linecap="round"/><path d="M${f2(x0)} ${f2(y0)}L${f2(x1)} ${f2(y1)}" stroke="${fill}" stroke-width="${f2(w)}" stroke-linecap="round"/>`;
function headOf(C, s, id) {
  const gn = genesFor({ breed: C.breed, sex: C.sex, seed: C.seed });
  return { gn, r: renderHead('r11', gn, { pose: 'front', scale: s, id, headOnly: true }) };
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
// 手臂：肩膀 → 手，手肘往 elbow 那邊彎（elbow：從中點往外推多少，畫面座標的向量）
function arm(sh, hd, w, fill, elbow) {
  const c = addV(mix2(sh, hd, 0.5), elbow), d = `M${pt(sh)}Q${pt(c)} ${pt(hd)}`;
  return `<path d="${d}" fill="none" stroke="${L}" stroke-width="${f2(w + 2.6)}" stroke-linecap="round"/><path d="${d}" fill="none" stroke="${fill}" stroke-width="${f2(w)}" stroke-linecap="round"/>`;
}
// 肩膀接起來：在手臂的起點蓋一個同毛色的圓，手臂看起來是從身體長出來的（沒有一圈線）
const shoulderCap = (sh, w, fill) => `<circle cx="${f2(sh[0])}" cy="${f2(sh[1])}" r="${f2(w * 0.5)}" fill="${fill}"/>`;
// 蹄當手：握著棍子（ang：棍子的方向）。手跨在棍子上，兩瓣中間一條縫
function hoofHand(p, ang, r) {
  return `<g transform="translate(${pt(p)}) rotate(${f2(ang)})"><path d="M${f2(-r * 0.8)} ${f2(-r * 1.0)}Q${f2(r * 0.95)} ${f2(-r * 1.15)} ${f2(r * 0.85)} 0Q${f2(r * 0.95)} ${f2(r * 1.15)} ${f2(-r * 0.8)} ${f2(r * 1.0)}Q${f2(-r * 1.1)} 0 ${f2(-r * 0.8)} ${f2(-r * 1.0)}Z" fill="#5A4A42" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/>
    <path d="M${f2(r * 0.86)} 0H${f2(r * 0.15)}" stroke="#3A2E28" stroke-width="1.4" stroke-linecap="round"/><path d="M${f2(-r * 0.4)} ${f2(-r * 0.62)}Q${f2(r * 0.1)} ${f2(-r * 0.78)} ${f2(r * 0.42)} ${f2(-r * 0.6)}" fill="none" stroke="#8A7468" stroke-width="1.4" stroke-linecap="round"/></g>`;
}
// 站著的腳：短短的、腳底平平踩在地上
function standFoot(c, fr, sd) {
  return `<g transform="translate(${pt(c)}) rotate(${f2(sd * 6)})"><path d="M${f2(-0.3 * fr)} ${f2(0.09 * fr)}Q${f2(-0.33 * fr)} ${f2(-0.16 * fr)} 0 ${f2(-0.18 * fr)}Q${f2(0.33 * fr)} ${f2(-0.16 * fr)} ${f2(0.3 * fr)} ${f2(0.09 * fr)}Z" fill="#5A4A42" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/><path d="M0 ${f2(-0.17 * fr)}V${f2(0.08 * fr)}" stroke="#3A2E28" stroke-width="1.4"/><path d="M${f2(-0.18 * fr)} ${f2(-0.1 * fr)}Q${f2(-0.1 * fr)} ${f2(-0.14 * fr)} ${f2(-0.02 * fr)} ${f2(-0.12 * fr)}" fill="none" stroke="#8A7468" stroke-width="1.3" stroke-linecap="round"/></g>`;
}
const stick2 = (a, b, w) => `<path d="M${pt(a)}L${pt(b)}" stroke="${L}" stroke-width="${f2(w + 2.4)}" stroke-linecap="round"/><path d="M${pt(a)}L${pt(b)}" stroke="#C98E5E" stroke-width="${f2(w)}" stroke-linecap="round"/><path d="M${pt(addV(a, normV([-(b[1] - a[1]), b[0] - a[0]]), -w * 0.22))}L${pt(addV(b, normV([-(b[1] - a[1]), b[0] - a[0]]), -w * 0.22))}" stroke="#E5B887" stroke-width="${f2(w * 0.3)}" stroke-linecap="round"/>`;
// 掃把頭：綁帶在 g（柄的末端），草一束一束往下張開，碰到地面
function broom2(g, v, ground, fr) {
  const n = [-v[1], v[0]], w0 = 0.13 * fr, w1 = 0.42 * fr, bot = [g[0] + v[0] * 0.15 * fr, ground];
  const a = addV(g, n, w0), b = addV(g, n, -w0), c = [bot[0] - w1, ground], d = [bot[0] + w1, ground];
  const left = a[0] < b[0] ? [a, b] : [b, a];
  const poly = `M${pt(left[0])}L${pt(left[1])}L${pt(d)}Q${pt([bot[0], ground + 0.06 * fr])} ${pt(c)}Z`;
  const strands = [0.15, 0.32, 0.5, 0.68, 0.85].map((k) => `M${pt(mix2(left[0], left[1], k))}L${pt([c[0] + (d[0] - c[0]) * k, ground - 0.02 * fr])}`).join('');
  const band = `M${pt(addV(a, v, -0.06 * fr))}L${pt(addV(b, v, -0.06 * fr))}L${pt(addV(b, v, 0.1 * fr))}L${pt(addV(a, v, 0.1 * fr))}Z`;
  return `<path d="${poly}" fill="#F0CD6E" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/><path d="${strands}" stroke="#C99A34" stroke-width="1.2" stroke-linecap="round"/><path d="${band}" fill="#D2553B" stroke="${L}" stroke-width="1.5" stroke-linejoin="round"/>`;
}
// 鏟子：柄尾一個 D 形握把；鏟頭在柄的前端，尖端 tip（tilt：鏟頭往上翻幾度，倒東西用）
function shovel2(e, k, v, fr, tilt = 0, load = false) {
  const ang = angOf(v) + tilt, n = [-v[1], v[0]];
  const grip = `<g transform="translate(${pt(e)}) rotate(${f2(angOf(v))})"><path d="M${f2(-0.02 * fr)} ${f2(-0.15 * fr)}Q${f2(-0.26 * fr)} ${f2(-0.15 * fr)} ${f2(-0.26 * fr)} 0Q${f2(-0.26 * fr)} ${f2(0.15 * fr)} ${f2(-0.02 * fr)} ${f2(0.15 * fr)}" fill="none" stroke="${L}" stroke-width="${f2(0.1 * fr + 2.4)}" stroke-linecap="round"/><path d="M${f2(-0.02 * fr)} ${f2(-0.15 * fr)}Q${f2(-0.26 * fr)} ${f2(-0.15 * fr)} ${f2(-0.26 * fr)} 0Q${f2(-0.26 * fr)} ${f2(0.15 * fr)} ${f2(-0.02 * fr)} ${f2(0.15 * fr)}" fill="none" stroke="#C98E5E" stroke-width="${f2(0.1 * fr)}" stroke-linecap="round"/></g>`;
  const blade = `<g transform="translate(${pt(k)}) rotate(${f2(ang)})"><path d="M0 ${f2(-0.06 * fr)}L${f2(0.08 * fr)} ${f2(-0.2 * fr)}Q${f2(0.42 * fr)} ${f2(-0.22 * fr)} ${f2(0.5 * fr)} 0Q${f2(0.42 * fr)} ${f2(0.22 * fr)} ${f2(0.08 * fr)} ${f2(0.2 * fr)}L0 ${f2(0.06 * fr)}Z" fill="#B9C3CC" stroke="${L}" stroke-width="1.8" stroke-linejoin="round"/><path d="M${f2(0.14 * fr)} ${f2(-0.12 * fr)}Q${f2(0.34 * fr)} ${f2(-0.14 * fr)} ${f2(0.4 * fr)} ${f2(-0.04 * fr)}" fill="none" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round"/>${load ? poopG(0.3 * fr, -0.02 * fr, 0.42 * fr) : ''}</g>`;
  return grip + stick2(e, k, 0.13 * fr) + blade;
}
// 推車（側面）：車斗、前面一個輪子、後面一隻腳；兩根把手往後伸到手上
function barrow(x0, dir, ground, fr, n, hn, hf) {
  const X = (u) => x0 + dir * u * fr, top = ground - 1.05 * fr, bot = ground - 0.5 * fr;
  const tray = `M${pt([X(0), top])}L${pt([X(1.95), top - 0.04 * fr])}L${pt([X(1.7), bot])}L${pt([X(0.28), bot])}Z`;
  const load = [[0.6, -0.02], [1.0, -0.06], [1.35, -0.02]].slice(0, n).map(([u, dv]) => poopG(X(u), top + dv * fr + 0.02 * fr, 0.5 * fr)).join('');
  const wheel = [X(1.62), ground - 0.3 * fr];
  const handleTo = (h, k) => { const s0 = [X(0.18), bot - 0.04 * fr + k * 0.06 * fr]; return stick2(s0, h, 0.12 * fr); };
  return `${handleTo(hf, -1)}<path d="M${pt([X(0.42), bot])}L${pt([X(0.36), ground - 0.02 * fr])}" stroke="${L}" stroke-width="${f2(0.1 * fr + 2.4)}" stroke-linecap="round"/><path d="M${pt([X(0.42), bot])}L${pt([X(0.36), ground - 0.02 * fr])}" stroke="#8C6A4A" stroke-width="${f2(0.1 * fr)}" stroke-linecap="round"/>
    <circle cx="${f2(wheel[0])}" cy="${f2(wheel[1])}" r="${f2(0.3 * fr)}" fill="#8C6A4A" stroke="${L}" stroke-width="2"/><circle cx="${f2(wheel[0])}" cy="${f2(wheel[1])}" r="${f2(0.1 * fr)}" fill="#F0CD6E" stroke="${L}" stroke-width="1.2"/>
    ${load}<path d="${tray}" fill="#D9A066" stroke="${L}" stroke-width="2" stroke-linejoin="round"/><path d="M${pt([X(0.16), top + 0.22 * fr])}L${pt([X(1.86), top + 0.2 * fr])}M${pt([X(0.24), top + 0.4 * fr])}L${pt([X(1.78), top + 0.38 * fr])}" stroke="#B57B45" stroke-width="1.4"/>${handleTo(hn, 1)}`;
}
// 吊帶褲：畫在身體上（身體的 clipPath 裡面）。P(u, v)：身體上的位置（fr 為單位）
function overalls(P, fr, gid) {
  const denim = '#5577AE', denimD = '#3B5A8D', stitch = '#A9C0E6';
  const grad = `<defs><linearGradient id="${gid}" x1="0" x2="1" y1="0" y2="0"><stop offset="0" stop-color="${denimD}"/><stop offset="0.24" stop-color="${denim}"/><stop offset="0.7" stop-color="${denim}"/><stop offset="1" stop-color="${denimD}"/></linearGradient></defs>`;
  const pants = `M${pt(P(-1.2, 1.0))}Q${pt(P(0, 1.3))} ${pt(P(1.2, 1.0))}L${pt(P(1.2, 2.3))}L${pt(P(-1.2, 2.3))}Z`;
  const bib = `M${pt(P(-0.5, 1.16))}Q${pt(P(-0.58, 0.86))} ${pt(P(-0.46, 0.58))}Q${pt(P(0, 0.64))} ${pt(P(0.46, 0.58))}Q${pt(P(0.58, 0.86))} ${pt(P(0.5, 1.16))}Z`;
  const bibStitch = `M${pt(P(-0.42, 1.12))}Q${pt(P(-0.5, 0.86))} ${pt(P(-0.4, 0.66))}Q${pt(P(0, 0.71))} ${pt(P(0.4, 0.66))}Q${pt(P(0.5, 0.86))} ${pt(P(0.42, 1.12))}`;
  const waistStitch = `M${pt(P(-1.2, 1.08))}Q${pt(P(0, 1.38))} ${pt(P(1.2, 1.08))}`;
  const strap = (sd) => `M${pt(P(sd * 0.4, 0.62))}Q${pt(P(sd * 0.56, 0.3))} ${pt(P(sd * 0.66, -0.05))}`;
  const pocket = `M${pt(P(-0.22, 0.78))}h${f2(0.44 * fr)}v${f2(0.22 * fr)}q0 ${f2(0.08 * fr)} ${f2(-0.08 * fr)} ${f2(0.08 * fr)}h${f2(-0.28 * fr)}q${f2(-0.08 * fr)} 0 ${f2(-0.08 * fr)} ${f2(-0.08 * fr)}Z`;
  const folds = `M${pt(P(0, 1.6))}Q${pt(P(0.03, 1.78))} ${pt(P(0, 1.98))}M${pt(P(-0.62, 1.4))}q${f2(0.1 * fr)} ${f2(0.04 * fr)} ${f2(0.16 * fr)} ${f2(0.12 * fr)}M${pt(P(0.62, 1.4))}q${f2(-0.1 * fr)} ${f2(0.04 * fr)} ${f2(-0.16 * fr)} ${f2(0.12 * fr)}M${pt(P(-0.3, 1.2))}q${f2(0.06 * fr)} ${f2(0.06 * fr)} ${f2(0.04 * fr)} ${f2(0.16 * fr)}`;
  return grad + [-1, 1].map((sd) => `<path d="${strap(sd)}" fill="none" stroke="${L}" stroke-width="${f2(0.18 * fr + 2.4)}" stroke-linecap="round"/><path d="${strap(sd)}" fill="none" stroke="${denim}" stroke-width="${f2(0.18 * fr)}" stroke-linecap="round"/>`).join('')
    + `<path d="${pants}" fill="url(#${gid})" stroke="${L}" stroke-width="1.6"/><path d="${bib}" fill="url(#${gid})" stroke="${L}" stroke-width="1.6" stroke-linejoin="round"/>`
    + `<path d="${bibStitch}" fill="none" stroke="${stitch}" stroke-width="1.1" stroke-dasharray="2.4 2.2"/><path d="${waistStitch}" fill="none" stroke="${stitch}" stroke-width="1.1" stroke-dasharray="2.4 2.2"/>`
    + `<path d="${pocket}" fill="${denimD}" fill-opacity="0.35" stroke="${stitch}" stroke-width="1.1" stroke-dasharray="2.2 2"/><path d="${folds}" fill="none" stroke="${denimD}" stroke-width="1.5" stroke-linecap="round"/>`
    + [-1, 1].map((sd) => `<circle cx="${f2(P(sd * 0.4, 0.62)[0])}" cy="${f2(P(sd * 0.4, 0.62)[1])}" r="${f2(0.075 * fr)}" fill="#FFD45E" stroke="${L}" stroke-width="1.3"/>`).join('');
}
// 站著的打掃牛（場景座標；x、y 是兩腳中間的地面）
// phase：鏟子牛一次「鏟起來 → 抬到水桶上面 → 倒進去」走到哪（0～1，null＝平常握著貼地）；sweep：掃把左右（-1～1）；step：走路時兩腳輪流抬
function stander25(k, { x, y, s = SIDE_S, facing = 'right', sweep = 0, phase = null, carry = 0, bob = 0, step = 0, id = 'st' } = {}) {
  const C = CLEANERS[k], dir = facing === 'right' ? 1 : -1;
  const { gn, r } = headOf(C, s * 0.92, id);
  const fr = r.face.r;
  const coat = gn.coat, spots = gn.pattern === 'patches', pat = gn.patternColor;
  const belly = spots ? '#FFFFFF' : hexMix(coat, '#FFFFFF', 0.42), shade = hexMix(coat, '#4B3326', 0.22);
  const yb = y, legH = 0.5 * fr, T = yb - legH - 1.86 * fr - bob;
  const P = (u, v) => [x + u * fr, T + v * fr];
  const hip = [x, T + 1.72 * fr];
  const lean = (C.lean || 0) * dir, Wl = (p) => rotP(p, hip, lean), Wi = (p) => rotP(p, hip, -lean);
  const tD = smoothClosedD([[0, 0], [0.56, 0.07], [0.86, 0.44], [1.0, 1.02], [0.96, 1.52], [0.64, 1.84], [0, 1.94], [-0.64, 1.84], [-0.96, 1.52], [-1.0, 1.02], [-0.86, 0.44], [-0.56, 0.07]].map(([u, v]) => P(u, v)));
  const cid = `tc${id}`, pants = C.tool === 'cart';
  const armW = 0.34 * fr, handR = 0.2 * fr;
  // 腳（不跟著身體傾斜）
  let legs = '';
  for (const sd of [-1, 1]) {
    const up = step ? Math.max(0, Math.sin((step + (sd > 0 ? 0.5 : 0)) * 2 * Math.PI)) * 0.16 * fr : 0;
    const lx = x + sd * 0.44 * fr, foot = [lx + sd * 0.05 * fr, yb - up];
    legs += limb(lx, T + 1.6 * fr, foot[0], foot[1] - 0.2 * fr, 0.44 * fr, pants ? '#5577AE' : coat);
    if (pants) legs += `<path d="M${f2(foot[0] - 0.25 * fr)} ${f2(foot[1] - 0.26 * fr)}h${f2(0.5 * fr)}" stroke="${L}" stroke-width="${f2(0.13 * fr + 2.2)}" stroke-linecap="round"/><path d="M${f2(foot[0] - 0.25 * fr)} ${f2(foot[1] - 0.26 * fr)}h${f2(0.5 * fr)}" stroke="#8FB0E0" stroke-width="${f2(0.13 * fr)}" stroke-linecap="round"/>`;
    legs += standFoot([foot[0], foot[1] - 0.04 * fr], fr, sd);
  }
  // 身體：毛色、花紋、淺色的肚子、下巴下面一點陰影；吊帶褲畫在身體裡面
  let inner = '';
  if (spots) inner += `<ellipse cx="${f2(P(-0.78, 1.25)[0])}" cy="${f2(P(-0.78, 1.25)[1])}" rx="${f2(0.5 * fr)}" ry="${f2(0.42 * fr)}" fill="${pat}"/><ellipse cx="${f2(P(0.86, 0.62)[0])}" cy="${f2(P(0.86, 0.62)[1])}" rx="${f2(0.34 * fr)}" ry="${f2(0.3 * fr)}" fill="${pat}"/>`;
  inner += `<ellipse cx="${f2(x)}" cy="${f2(P(0, 1.3)[1])}" rx="${f2(0.6 * fr)}" ry="${f2(0.62 * fr)}" fill="${belly}"/><ellipse cx="${f2(x)}" cy="${f2(P(0, 0.55)[1])}" rx="${f2(0.62 * fr)}" ry="${f2(0.2 * fr)}" fill="${shade}" opacity="0.35"/>`;
  if (pants) inner += overalls(P, fr, `og${id}`);
  const torso = `<defs><clipPath id="${cid}"><path d="${tD}"/></clipPath></defs><path d="${tD}" fill="${coat}"/><g clip-path="url(#${cid})">${inner}</g><path d="${tD}" fill="none" stroke="${L}" stroke-width="2.6"/>`;
  const fcx = x, fcy = T - 0.34 * fr;
  const head = `<g transform="translate(${f2(fcx - r.face.cx)} ${f2(fcy - r.face.cy)})">${r.svg}</g>`;
  const g = { fx: fcx, fy: fcy, fr, dir, back: -dir };
  const shFar = P(-dir * 0.78, 0.44), shNear = P(dir * 0.8, 0.44);
  let behind = '', arms = '', tool = '', hands = '', hat = '', a = {};
  if (C.tool === 'broom') {
    const H1 = P(-dir * 0.16, 0.76), H1w = Wl(H1);
    const G = [x + dir * 2.05 * fr + dir * sweep * 0.3 * fr, yb - 0.56 * fr];
    const v = normV(subV(G, H1w)), E = addV(H1w, v, -0.42 * fr), H2w = mix2(H1w, G, 0.46), H2 = Wi(H2w);
    arms = arm(shFar, H1, armW, coat, [-dir * 0.1 * fr, 0.24 * fr]) + shoulderCap(shFar, armW, spots ? coat : coat) + arm(shNear, H2, armW, coat, [dir * 0.24 * fr, 0.02 * fr]) + shoulderCap(shNear, armW, coat);
    tool = stick2(E, G, 0.13 * fr) + broom2(G, v, yb, fr);
    hands = hoofHand(H1w, angOf(v), handR) + hoofHand(H2w, angOf(v), handR);
    hat = bandana(g, true);
    a.tip = [G[0] + v[0] * 0.15 * fr, yb];
  } else if (C.tool === 'shovel') {
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
  } else { // cart
    const Hn = [x + dir * 1.46 * fr, yb - 0.96 * fr], Hf = [x + dir * 1.2 * fr, yb - 1.36 * fr];
    behind += arm(P(dir * 0.32, 0.52), Wi(Hf), armW, coat, [0, 0.2 * fr]); // 遠的那隻手：從身體後面伸出來（被身體擋住）
    arms = arm(shNear, Wi(Hn), armW, coat, [dir * 0.02 * fr, 0.22 * fr]) + shoulderCap(shNear, armW, coat);
    tool = barrow(x + dir * 1.62 * fr, dir, yb, fr, carry, Hn, Hf);
    hands = hoofHand(Hf, dir > 0 ? 200 : -20, handR) + hoofHand(Hn, dir > 0 ? 200 : -20, handR);
    a.tip = [x + dir * 2.9 * fr, yb]; a.cart = [x + dir * 2.6 * fr, yb - 1.1 * fr];
  }
  const up = `<g transform="rotate(${f2(lean)} ${pt(hip)})">${behind && C.tool === 'cart' ? behind : ''}${torso}${arms}${head}${hat}</g>`;
  const ground = C.tool === 'shovel' ? behind : '';
  const shadow = `<ellipse cx="${f2(x + dir * 0.5 * fr)}" cy="${f2(yb + 1)}" rx="${f2(1.6 * fr)}" ry="${f2(0.26 * fr)}" fill="#3E6B2A" opacity="0.2"/>`;
  const reach = C.tool === 'cart' ? 4.0 : C.tool === 'shovel' ? 3.6 : 2.9;
  const bx = [x - dir * 1.4 * fr, x + dir * reach * fr];
  return { svg: shadow + ground + legs + up + tool + hands, g: { fx: fcx, fy: fcy, fr, dir, back: -dir, ground: yb, h: yb - (fcy - fr * 1.3) }, a, box: [Math.min(...bx), fcy - 1.5 * fr, Math.max(...bx), yb + 0.3 * fr] };
}

// ---------- B1：四隻腳拉推車，背心畫在身上（用身體外框裁切、順著圓筒形的身體） ----------
function vestCow(k, { x, y, s = SIDE_S, facing = 'left', carry = 0, bob = 0, id = 'vc' } = {}) {
  const C = CLEANERS[k];
  const gn = genesFor({ breed: C.breed, sex: C.sex, seed: C.seed });
  const r = renderHead('r11', gn, { pose: 'side', x, y: y - bob, scale: s, facing, id, split: true });
  const M = r.model, B = M.B, fr = r.face.r;
  const O = '#F08A2E', OD = '#C7621A', OL = '#FFB36B', REF = '#FFE14D';
  const vid = `v${id}`, bid = `b${id}`;
  // 背心（模型座標，前面是 -x）：像工作犬穿的背心，披在背上、往兩邊垂下來。前緣在肩膀後面、後緣在腰，下擺在身體側面一半的地方，往下彎（圓筒形的身體），下面看得到毛
  const X = (u) => B.cx + u * B.rx, Y = (v) => B.cy + v * B.ry, top = B.topY - 0.4 * B.D;
  const fTop = [X(-0.6), top], fBot = [X(-0.7), Y(0.3)], bBot = [X(0.48), Y(0.34)], bTop = [X(0.56), top];
  const region = `M${pt(fTop)}Q${pt([X(-0.76), Y(-0.25)])} ${pt(fBot)}Q${pt([X(-0.1), Y(0.66)])} ${pt(bBot)}Q${pt([X(0.62), Y(-0.1)])} ${pt(bTop)}Z`;
  const hemD = `M${pt(fBot)}Q${pt([X(-0.1), Y(0.66)])} ${pt(bBot)}`;
  const lw = Math.max(1.4, 0.022 * B.D);
  const stripeD = `M${pt([X(-0.8), Y(-0.04)])}Q${pt([X(-0.08), Y(0.24)])} ${pt([X(0.7), Y(0.02)])}`;
  const strapX = X(-0.36), strapTop = Y(0.47), buckle = [strapX, strapTop + 0.1 * B.D];
  const ring = [X(0.6), Y(-0.02)];
  const vest = `<defs><clipPath id="${bid}"><path d="${M.bodyD}"/></clipPath><clipPath id="${vid}"><path d="${region}"/></clipPath></defs>
    <g clip-path="url(#${bid})">
      <path d="M${pt([strapX, strapTop])}L${pt([strapX - 0.02 * B.D, B.bellyY + 0.3 * B.D])}" stroke="${L}" stroke-width="${f2(0.1 * B.D + lw * 2)}"/><path d="M${pt([strapX, strapTop])}L${pt([strapX - 0.02 * B.D, B.bellyY + 0.3 * B.D])}" stroke="${OD}" stroke-width="${f2(0.1 * B.D)}"/>
      <rect x="${f2(buckle[0] - 0.08 * B.D)}" y="${f2(buckle[1] - 0.05 * B.D)}" width="${f2(0.16 * B.D)}" height="${f2(0.1 * B.D)}" rx="${f2(0.02 * B.D)}" fill="none" stroke="${L}" stroke-width="${f2(lw * 2.4)}"/><rect x="${f2(buckle[0] - 0.08 * B.D)}" y="${f2(buckle[1] - 0.05 * B.D)}" width="${f2(0.16 * B.D)}" height="${f2(0.1 * B.D)}" rx="${f2(0.02 * B.D)}" fill="none" stroke="#C9CED6" stroke-width="${f2(lw)}"/>
      <path d="${region}" fill="${O}"/>
      <g clip-path="url(#${vid})">
        <path d="${hemD}" fill="none" stroke="${OD}" stroke-width="${f2(0.16 * B.D)}" opacity="0.5"/>
        <path d="${M.bodyD}" fill="none" stroke="${OL}" stroke-width="${f2(0.1 * B.D)}" opacity="0.75"/>
        <path d="${stripeD}" fill="none" stroke="${L}" stroke-width="${f2(0.11 * B.D + lw * 2)}"/><path d="${stripeD}" fill="none" stroke="${REF}" stroke-width="${f2(0.11 * B.D)}"/><path d="${stripeD}" fill="none" stroke="#FFFFFF" stroke-width="${f2(0.03 * B.D)}" opacity="0.9"/>
        <path d="M${pt([X(-0.58), Y(-0.5)])}q${f2(0.05 * B.D)} ${f2(0.07 * B.D)} ${f2(0.03 * B.D)} ${f2(0.16 * B.D)}M${pt([X(-0.52), Y(0.1)])}q${f2(0.06 * B.D)} ${f2(0.04 * B.D)} ${f2(0.1 * B.D)} ${f2(0.12 * B.D)}M${pt([X(0.32), Y(0.26)])}q${f2(0.03 * B.D)} ${f2(0.05 * B.D)} ${f2(0)} ${f2(0.11 * B.D)}" fill="none" stroke="${OD}" stroke-width="${f2(lw)}" stroke-linecap="round"/>
        <path d="M${pt([fBot[0] + 0.04 * B.rx, fBot[1] - 0.06 * B.D])}Q${pt([X(-0.1), Y(0.66) - 0.07 * B.D])} ${pt([bBot[0] - 0.03 * B.rx, bBot[1] - 0.06 * B.D])}" fill="none" stroke="#FFD9B0" stroke-width="${f2(lw * 0.8)}" stroke-dasharray="${f2(lw * 2)} ${f2(lw * 1.6)}"/>
      </g>
      <path d="${region}" fill="none" stroke="${L}" stroke-width="${f2(lw * 1.4)}" stroke-linejoin="round"/>
    </g>
    <circle cx="${f2(ring[0])}" cy="${f2(ring[1])}" r="${f2(0.06 * B.D)}" fill="none" stroke="${L}" stroke-width="${f2(lw * 2.4)}"/><circle cx="${f2(ring[0])}" cy="${f2(ring[1])}" r="${f2(0.06 * B.D)}" fill="none" stroke="#C9CED6" stroke-width="${f2(lw)}"/>`;
  const toS = ([mx, my]) => [x + M.sx * mx, y - bob + M.s * my];
  const ringS = toS(ring), back = facing === 'right' ? -1 : 1;
  const cartAt = toS([B.xR + 0.75 * B.D, 0]);
  const cartSvg = cart(cartAt[0], y - 14 * s, s, carry);
  const ropeD = `M${pt(ringS)}Q${pt([(ringS[0] + cartAt[0]) / 2, Math.max(ringS[1], y - 22 * s) + 6])} ${pt([cartAt[0] - back * 18 * s, y - 24 * s])}`;
  const rope = `<path d="${ropeD}" fill="none" stroke="${L}" stroke-width="3.6" stroke-linecap="round"/><path d="${ropeD}" fill="none" stroke="#D8A66A" stroke-width="1.8" stroke-linecap="round"/>`;
  const shadow = `<ellipse cx="${f2(toS([B.cx, 0])[0])}" cy="${f2(y)}" rx="${f2(B.L * 0.62 * M.s)}" ry="${f2(Math.max(3.5, B.D * 0.12 * M.s))}" fill="#3E6B2A" opacity="0.18"/>`;
  const body = `${r.svgBody}<g transform="${M.tf}">${vest}</g>${r.svgHead}`;
  const g = { fx: r.face.cx, fy: r.face.cy, fr, dir: facing === 'right' ? 1 : -1, back, bodyCx: toS([B.cx, 0])[0], bodyHalf: B.L * 0.5 * M.s, ground: y, h: r.height };
  return { svg: shadow + cartSvg + rope + body, g, a: { cart: [cartAt[0], y - 30 * s] }, box: [Math.min(cartAt[0], toS([B.xF, 0])[0]) - 30 * s, r.face.cy - fr * 2, Math.max(cartAt[0], toS([B.xF, 0])[0]) + 30 * s, y + 6] };
}
const CLEANERS = {
  A: { kind: 'stand', tool: 'broom', lean: 2, name: '站著掃地的頭巾牛', file: '站著掃地', breed: 'holstein', sex: 'cow', seed: 52, intro: '紅色點點頭巾，用後腳站著，兩隻前腳握著掃把：上面的手握柄的上端，下面的手握柄的中間。', fun: '最像在打掃：兩隻手握掃把左右掃；黑白花配紅頭巾很顯眼。', act: '下面的手帶著掃把左右掃，上面的手不動' },
  B1: { kind: 'vest', cart: true, name: '工作背心推車牛（重新設計）', file: '工作背心', breed: 'yellow', sex: 'cow', seed: 61, intro: '四隻腳拉推車；橘色工作背心像工作犬的背心，披在背上、往兩邊垂下來，有反光條、肚帶扣環，後面一個環掛推車的繩子。', fun: '像在牧場上班的工作牛；背心是穿在身上的，順著身體的曲線。', act: '大便飛進後面的推車' },
  B3: { kind: 'stand', tool: 'cart', lean: 8, cart: true, name: '吊帶褲推車牛（站起來）', file: '吊帶褲站著推車', breed: 'yellow', sex: 'cow', seed: 61, intro: '穿牛仔吊帶褲，用後腳站著，兩隻手各握一根把手推推車；身體往推車那邊傾。', fun: '最像一個小農夫：兩隻手推著推車，推車裡的大便越裝越多。', act: '大便跳進前面的推車' },
  C: { kind: 'stand', tool: 'shovel', lean: 6, name: '站著鏟大便的草帽牛', file: '站著鏟大便', breed: 'jersey', sex: 'cow', seed: 73, intro: '戴草帽，用後腳站著，兩隻手都握在鏟子上：後面的手握柄尾，前面的手握柄的中間；水桶放在地上。', fun: '最有農場味：鏟起來、抬到水桶上面、倒進去，水桶越裝越滿。', act: '鏟起來、抬到水桶上面倒進去' },
};
// 一頭打掃牛（場景座標）：x、y 是腳底中間
function cleaner(k, o = {}) {
  const C = CLEANERS[k];
  if (C.kind === 'stand') return stander25(k, o);
  return vestCow(k, o);
}
// 打掃牛單獨一張圖（雇用面板、右上角、大圖）：crop 'head' 只要頭
function cleanerArt(k, w, h, crop = 'full', extra = {}) {
  const c = cleaner(k, { x: 0, y: 0, s: 1, facing: 'right', id: `ca${k}${crop}${w}`, ...extra });
  const { fx, fy, fr } = c.g;
  let vb;
  if (crop === 'head') vb = [fx - fr * 1.6, fy - fr * 1.9, fr * 3.2, fr * 3.2];
  else { const [x0, y0, x1, y1] = c.box; const cw = x1 - x0, ch = y1 - y0, side = Math.max(cw, ch * (w / h)); vb = [(x0 + x1) / 2 - side / 2, y1 - side * (h / w), side, side * (h / w)]; }
  return `<svg viewBox="${vb.map(f2).join(' ')}" width="${w}" height="${h}" aria-hidden="true">${c.svg}</svg>`;
}

// ================= 大便掃地機（像掃地機器人，原創造型） =================
// A 乳牛紋圓盤：白色圓盤、黑色乳牛斑點、前面兩個小眼睛。B 透明圓頂：看得到裡面吸進去的大便，前面一個笑臉小螢幕
function robot(k, { x, y, s = 1, dir = -1, full = 0, spin = 0 } = {}) {
  const eye = (ex) => `<ellipse cx="${f2(ex)}" cy="-9" rx="1.7" ry="2.3" fill="${L}"/><circle cx="${f2(ex - 0.5)}" cy="-9.8" r="0.6" fill="#FFFFFF"/>`;
  const ex = dir * 9;
  const brush = (bx) => `<g transform="translate(${f2(bx)} 2) rotate(${f2(spin)})">${[0, 60, 120].map((a) => `<path d="M0 0L8 0" stroke="#8C7A6A" stroke-width="1.2" transform="rotate(${a})"/>`).join('')}</g>`;
  let body;
  if (k === 'R1') {
    const spots = `<ellipse cx="-8" cy="-12" rx="6" ry="3" fill="${L}"/><ellipse cx="9" cy="-14" rx="4" ry="2.2" fill="${L}"/><ellipse cx="2" cy="-8.4" rx="3" ry="1.6" fill="${L}"/>`;
    body = `<ellipse cx="0" cy="0" rx="25" ry="10" fill="#8C8F99" stroke="${L}" stroke-width="2"/><path d="M-25 -6V0A25 10 0 0 0 25 0V-6" fill="#D9DDE6" stroke="${L}" stroke-width="2"/>
      <ellipse cx="0" cy="-6" rx="25" ry="10" fill="#FFFFFF" stroke="${L}" stroke-width="2"/>${spots}<ellipse cx="${f2(dir * 4)}" cy="-6.4" rx="16" ry="6.4" fill="none" stroke="#E7DED2" stroke-width="1.2"/>
      <path d="M${f2(dir * 25)} -4A25 10 0 0 1 ${f2(dir * 12)} 3.4" fill="none" stroke="#FF9784" stroke-width="3" stroke-linecap="round"/>${eye(ex - 3.2)}${eye(ex + 3.2)}`;
  } else {
    const inside = full ? [[-6, -10], [5, -9], [0, -15]].slice(0, full).map(([px, py]) => poopG(px, py, 9)).join('') : '';
    body = `<ellipse cx="0" cy="0" rx="24" ry="9.6" fill="#5F7690" stroke="${L}" stroke-width="2"/><path d="M-24 -5V0A24 9.6 0 0 0 24 0V-5" fill="#9DB4CC" stroke="${L}" stroke-width="2"/>
      <ellipse cx="0" cy="-5" rx="24" ry="9.6" fill="#C6D6E6" stroke="${L}" stroke-width="2"/>${inside}
      <path d="M-15 -6C-15 -24 15 -24 15 -6Z" fill="#E6F4FF" fill-opacity="0.55" stroke="${L}" stroke-width="1.8"/><path d="M-9 -15C-7 -19 -3 -20.5 1 -20.5" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round"/>
      <rect x="${f2(dir * 17 - 6)}" y="-6.4" width="12" height="7" rx="2.4" fill="#2E3A48" stroke="${L}" stroke-width="1.2"/><path d="M${f2(dir * 17 - 3)} -4.4h0M${f2(dir * 17 + 3)} -4.4h0" stroke="#7FE0A0" stroke-width="1.8" stroke-linecap="round"/><path d="M${f2(dir * 17 - 3)} -2.4Q${f2(dir * 17)} -0.4 ${f2(dir * 17 + 3)} -2.4" fill="none" stroke="#7FE0A0" stroke-width="1.2" stroke-linecap="round"/>`;
  }
  return `<g transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s)})"><ellipse cx="0" cy="3" rx="26" ry="6" fill="#3E6B2A" opacity="0.18"/>${brush(dir * 18)}${body}</g>`;
}
// 充電座
const dock = (x, y) => `<g transform="translate(${x} ${y})"><path d="M-14 4L-11 -12H11L14 4Z" fill="#E7DED2" stroke="${L}" stroke-width="2" stroke-linejoin="round"/><path d="M-3 -9L-6 -3H0L-3 2" fill="none" stroke="#FFC13B" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></g>`;
// 吸大便的漩渦
const swirl = (x, y, s = 1) => `<g transform="translate(${f2(x)} ${f2(y)}) scale(${f2(s)})" opacity="0.9"><path d="M-10 -6Q-2 -14 6 -6T14 -2M-8 2Q0 -4 8 2" fill="none" stroke="#FFFFFF" stroke-width="2.4" stroke-linecap="round"/></g>`;
const ROBOTS = {
  R1: { opt: 'A', name: '乳牛紋圓盤', file: '乳牛紋圓盤', intro: '白色圓盤上有乳牛的黑色斑點，前面兩個小眼睛，自己在牧場跑、把大便吸走。', fun: '跟牧場最搭：看起來像一頭會跑的小乳牛。' },
  R2: { opt: 'B', name: '透明圓頂', file: '透明圓頂', intro: '上面一個透明圓頂，看得到吸進去的大便越裝越多；前面一個笑臉小螢幕。', fun: '吸了幾坨一看就知道；像一台小小的科技產品。' },
};

// ================= 牧場畫面 =================
const HERD20 = HERD.filter((h) => h.id !== 7 && h.id !== 12); // 中間空出來，給打掃牛和掃地機走
const SPOTS = [[196, 488], [256, 474], [314, 490]]; // 要清的三坨（場景座標，由左到右）
const DOCK = [344, 452]; // 掃地機的充電座
const RS = 1.4; // 掃地機在場景裡的大小
const poopsAt = (scales = [1, 1, 1]) => SPOTS.map(([x, y], i) => (scales[i] > 0.02 ? poopG(x, y, 19 * scales[i]) : '')).join('');
const sparks = (x, y, k = 1) => [[-14, -16, 5], [12, -20, 4], [2, -30, 3.4]].map(([dx, dy, r]) => `<path d="M${x + dx} ${y + dy - r * k}Q${x + dx + r * 0.2 * k} ${y + dy - r * 0.2 * k} ${x + dx + r * k} ${y + dy}Q${x + dx + r * 0.2 * k} ${y + dy + r * 0.2 * k} ${x + dx} ${y + dy + r * k}Q${x + dx - r * 0.2 * k} ${y + dy + r * 0.2 * k} ${x + dx - r * k} ${y + dy}Q${x + dx - r * 0.2 * k} ${y + dy - r * 0.2 * k} ${x + dx} ${y + dy - r * k}Z" fill="#FFFFFF" stroke="#E7B53A" stroke-width="1.2"/>`).join('');
function ranchWith(extra, o = {}) {
  const html = ranchPage(ctx0(), { herd: HERD20, ...o });
  return html.replace(/(<div class="scene">[\s\S]*?)(<\/svg>\s*<\/div>)/, (m, a, b) => a + extra + b);
}
const cleanPill = (k, left = '還有 3 天') => `<div class="dirty cleaning"><span class="cl-face">${cleanerArt(k, 26, 26, 'head')}</span><span>打掃中</span><span class="cl-left">${left}</span></div>`;
const robotPill = (k) => `<div class="dirty cleaning"><span class="cl-face">${`<svg viewBox="-28 -26 56 40" width="26" height="19">${robot(k, { x: 0, y: 0 })}</svg>`}</span><span>掃地中</span></div>`;

// 打掃牛停在大便旁邊時，牛腳的位置（讓掃把、鏟子剛好碰到大便；推車牛是頭靠過去）
function standAt(k, [px, py], facing = 'right') {
  const c = cleaner(k, { x: 0, y: 0, facing });
  const dx = c.a.tip ? c.a.tip[0] : c.g.fx + c.g.dir * c.g.fr * 1.1;
  return [px - dx, py + 4];
}

// ---------- 雇用面板（一天 2,000 幣，最多一次 7 天；v0.3 第 5.1 節） ----------
function hireSheet(k, days = 3) {
  const C = CLEANERS[k];
  const opts = [1, 3, 7].map((d) => `<button class="hd-opt${d === days ? ' on' : ''}"><b>${d} 天</b><span class="num">${fmt(2000 * d)} 幣</span></button>`).join('');
  return sheet({ cls: 'hire-sheet', title: '雇用打掃牛', body: `<div class="hire-hero"><span class="hh-pic">${cleanerArt(k, 120, 120)}</span><div><b class="hh-name">${C.name}</b><p class="hint">${C.intro}</p></div></div>
    <ul class="hire-rules"><li>雇用期間每 30 分鐘把大便全部清掉，牛不會因為大便生病。</li><li>沒上線也照樣打掃。</li><li>一天 2,000 幣，最多一次付 7 天。</li></ul>
    <div class="hire-days">${opts}</div>
    <div class="btn-row">${btn(t('cancel'))}${btn(`雇用 ${days} 天（${fmt(2000 * days)} 幣）`, { kind: 'primary' })}</div>` });
}
function robotSheet(k) {
  const R = ROBOTS[k];
  return sheet({ cls: 'hire-sheet', title: '大便掃地機', body: `<div class="hire-hero"><span class="hh-pic robot"><svg viewBox="-34 -34 68 48" width="120" height="85">${robot(k, { x: 0, y: 0, full: 2 })}</svg></span><div><b class="hh-name">${R.name}</b><p class="hint">${R.intro}</p></div></div>
    <ul class="hire-rules tbd"><li>價錢：<b>待定</b></li><li>買下來還是用租的：<b>待定</b></li><li>多久清一次、跟打掃牛的關係：<b>待定</b></li></ul>
    <div class="btn-row">${btn(t('cancel'))}${btn('買下（價錢待定）', { kind: 'primary', disabled: true })}</div>` });
}

// ---------- 打掃牛的分鏡（5 格） ----------
function cleanerCells(k) {
  const [sx, sy] = standAt(k, SPOTS[0]);
  const cl = (o) => cleaner(k, { id: `c${k}${Math.random().toString(36).slice(2, 7)}`, facing: 'right', ...o }).svg;
  const p0 = SPOTS[0];
  const flyB = CLEANERS[k].cart ? (() => { const c = cleaner(k, { x: sx, y: sy, facing: 'right' }); const [cx, cy] = c.a.cart; return `<path d="M${p0[0]} ${p0[1] - 6}Q${(p0[0] + cx) / 2} ${Math.min(p0[1], cy) - 46} ${cx} ${cy}" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-dasharray="2 7" stroke-linecap="round"/>${poopG((p0[0] + cx) / 2, Math.min(p0[1], cy) - 30, 14)}`; })() : '';
  return [
    { cap: '雇用面板', note: '從右上角的大便數、或商店打開；一天 2,000 幣，最多一次付 7 天', html: ranchWith(poopsAt(), { center: dirtyPill(3), overlays: hireSheet(k) }) },
    { cap: '雇好了：右上角變成「打掃中」', note: '打掃牛從牧場旁邊走進來（還有幾天寫在旁邊）', html: ranchWith(poopsAt() + cl({ x: 30, y: 500, bob: 2, step: 0.25 }), { center: cleanPill(k) }) },
    { cap: '走到大便旁邊', note: '', html: ranchWith(poopsAt() + cl({ x: sx, y: sy }), { center: cleanPill(k) }) },
    { cap: '清掉：大便不見、冒星星', note: CLEANERS[k].act, html: ranchWith(poopsAt([k === 'C' ? 0 : 0.35, 1, 1]) + cl({ x: sx, y: sy, sweep: 0.8, phase: 0.55, carry: 0 }) + flyB + sparks(p0[0], p0[1]), { center: cleanPill(k) }) },
    { cap: '清乾淨了：在旁邊散步', note: '雇用期間每 30 分鐘清一次，所以牧場一直很乾淨', html: ranchWith(cl({ x: 268, y: 500, facing: 'left', carry: 3 }), { center: cleanPill(k) }) },
  ];
}
function robotCells(k) {
  const D = DOCK;
  const path = `<path d="M${D[0]} ${D[1]}L${SPOTS[2][0]} ${SPOTS[2][1]}L${SPOTS[1][0]} ${SPOTS[1][1]}L${SPOTS[0][0]} ${SPOTS[0][1]}" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-dasharray="4 8" stroke-linecap="round"/>`;
  return [
    { cap: '購買面板', note: '價錢、規則都還沒定，先看樣子', html: ranchWith(poopsAt() + dock(...DOCK), { center: dirtyPill(3), overlays: robotSheet(k) }) },
    { cap: '在牧場自己跑', note: '虛線是牠等一下要跑的路，一坨一坨吸過去', html: ranchWith(poopsAt() + dock(...D) + path + robot(k, { x: D[0] - 14, y: D[1] + 18, s: RS, dir: -1 }), { center: robotPill(k) }) },
    { cap: '吸大便', note: '跑到大便上面，大便轉一圈被吸進去', html: ranchWith(poopsAt([1, 0.4, 0]) + dock(...D) + robot(k, { x: SPOTS[1][0] + 6, y: SPOTS[1][1] + 8, s: RS, dir: -1, full: 1 }) + swirl(SPOTS[1][0] - 30, SPOTS[1][1] - 8, 1.2), { center: robotPill(k) }) },
    { cap: '吸完回去充電', note: '牧場乾淨了；回到充電座', html: ranchWith(dock(...D) + robot(k, { x: D[0] - 4, y: D[1] + 10, s: RS, dir: 1, full: 3 }), { center: robotPill(k) }) },
  ];
}
const SUB25 = '使用者看完第 22 輪：「b3 跟c 是可以，但可以調整一下 你現在畫圖看起來怪怪的。a的手看起來超怪，你多花時間慢慢畫畫，想好在畫，人掃地也是兩隻手。b1 的牛你該重新設計，衣服是畫在身上，不是這樣浮貼在身上」。先想好姿勢（人掃地、鏟東西、推推車）再畫：兩隻手握在工具的不同位置、手臂從肩膀長出來、腳踩在地上；衣服用身體的外框裁切、順著身體的曲線，手臂擋得到的地方就擋住。';
// 大圖檢查（ceo：每個先畫一張大的站姿單獨圖，自己逐項檢查：手、肩、衣服貼身、腳踩地。都對了再做 GIF 和牧場裡的樣子）
const CHECK = {
  A: ['手：上面的手握掃把柄的上端（胸口），下面的手握柄的中間（腰邊），兩隻手都包著柄', '肩：兩隻手臂從肩膀長出來，手肘往外彎', '衣服：頭巾綁在頭上', '腳：兩隻腳平平踩在地上，掃把頭也碰到地'],
  B1: ['衣服：像工作犬的背心，披在背上、往兩邊垂下來；用身體的外框裁切，不會超出身體', '下擺在身體側面一半的地方，順著圓筒形的身體往下彎，下面看得到毛；下擺暗一點、背上一道亮光', '反光條跟著身體彎；肚帶和扣環從下擺繞到肚子下面；縫線、皺褶', '推車的繩子掛在背心後面的環上；頭擋在背心前面'],
  B3: ['手：兩隻手各握一根把手（腰的高度）；遠的那隻手大部分被身體擋住', '肩：近的手臂從肩膀長出來', '衣服：吊帶褲裁在身體裡；腰線往下彎、兩邊暗一點；吊帶繞過肩膀；口袋、縫線、皺褶；手臂蓋在吊帶上面', '腳：牛仔褲管、反摺，腳踩在地上；身體往推車那邊傾'],
  C: ['手：後面的手握鏟柄的尾巴（D 形握把，在另一邊的腰），前面的手握柄的中間', '肩：兩隻手臂從肩膀長出來', '衣服：草帽戴在頭上', '腳：踩在地上；鏟頭貼著地；水桶放在地上'],
};
function r2500() {
  const ks = Object.keys(CLEANERS);
  const cells = ks.map((k) => `<div class="ck-cell"><div class="ck-cap"><b>${k}　${CLEANERS[k].name}</b></div><div class="ck-art">${cleanerArt(k, 400, 400)}</div><ul class="ck-list">${CHECK[k].map((x) => `<li>${x}</li>`).join('')}</ul></div>`).join('');
  return { html: `<div class="board" style="width:${PAD * 2 + 4 * 400 + 3 * 28}px"><div class="b-label">R25-00-打掃牛-大圖檢查</div><div class="b-title">先畫一張大的站姿單獨圖，逐項檢查</div><div class="b-sub">${SUB25}</div><div class="ck-row">${cells}</div></div>` };
}
const BOARDS = [
  { id: 'R25-00', render: r2500 },
  ...Object.keys(CLEANERS).map((k) => ({ id: `R25-01-${k}`, render: () => board({ id: `R25-01-打掃牛-${k}-${CLEANERS[k].file}-390`, title: `01 打掃牛　${k}：${CLEANERS[k].name}`, sub: SUB25, cells: cleanerCells(k), notes: [CLEANERS[k].fun, `動起來的樣子見 GIF：R25-01-打掃牛-${k}-${CLEANERS[k].file}-390.gif`] }) })),
  { id: 'R25-99', render: r2599 },
];
function r2599() {
  const S = 0.5, sw = Math.round(dev.w * S), sh = Math.round(dev.h * S);
  const mini = (html) => `<div class="ov-ph" style="width:${sw}px;height:${sh}px"><div style="transform:scale(${S});transform-origin:0 0">${html}</div></div>`;
  const cell = (cap, inner) => `<div class="ov-cell"><div class="ov-cap"><b>${cap}</b></div>${inner}</div>`;
  const row = (title, cells) => `<div class="ov-row"><div class="ov-title">${title}</div><div class="ov-cells">${cells.join('')}</div></div>`;
  const big = (k) => `<div class="ov-art">${cleanerArt(k, 190, 150)}</div>`;
  const body = row('站起來的打掃牛（A 兩隻手重畫、C 畫得更自然）', ['A', 'C'].map((k) => cell(`${k}　${CLEANERS[k].name}`, big(k) + mini(cleanerCells(k)[3].html))))
    + row('推車牛（B1 重新設計、B3 畫得更自然）', ['B1', 'B3'].map((k) => cell(`${k}　${CLEANERS[k].name}`, big(k) + mini(cleanerCells(k)[3].html))));
  return { html: `<div class="board" style="width:${PAD * 2 + 3 * sw + 2 * 28 + 10}px"><div class="b-label">R25-99-總覽對照</div><div class="b-title">第 25 輪：打掃牛重畫</div>
    <div class="b-sub">A、C、B1、B3 選一種（B2 領巾加袖套使用者沒提，維持第 22 輪的樣子）。大圖檢查見 R25-00，各自的分鏡見 R25-01，動起來的樣子見同名的 GIF。</div>${body}</div>` };
}

// ================= GIF（每個 5 秒、15 fps、寬 390） =================
const clamp01 = (v) => Math.max(0, Math.min(1, v));
const lerp = (a, b, k) => a + (b - a) * k;
const ease = (k) => k * k * (3 - 2 * k);
const span = (t, a, b) => clamp01((t - a) / (b - a));
// 打掃牛：從右邊走進來 → 清第 1 坨 → 走到第 2 坨 → 清 → 第 3 坨 → 清 → 停一下
const CT = [[0, 1.0, 'walk', 0], [1.0, 1.7, 'clean', 0], [1.7, 2.3, 'walk', 1], [2.3, 3.0, 'clean', 1], [3.0, 3.6, 'walk', 2], [3.6, 4.3, 'clean', 2], [4.3, 5.0, 'idle', 2]];
function gifCleaner(k, t) {
  const stands = SPOTS.map((p) => standAt(k, p));
  const seg = CT.find(([a, b]) => t >= a && t < b) || CT[CT.length - 1];
  const [a, b, kind, i] = seg, u = span(t, a, b);
  let x, y, sweep = 0, bob = 0;
  if (kind === 'walk') { const from = i === 0 ? [-80, 500] : stands[i - 1]; [x, y] = [lerp(from[0], stands[i][0], ease(u)), lerp(from[1], stands[i][1], ease(u))]; bob = Math.abs(Math.sin(u * Math.PI * 4)) * 2.4; }
  else { [x, y] = stands[i]; }
  if (kind === 'clean') sweep = Math.sin(u * Math.PI * 4);
  const step = kind === 'walk' ? (u * 3) % 1 : 0, phase = k === 'C' && kind === 'clean' ? u : null;
  const scales = SPOTS.map((_, j) => (j < i || (j === i && kind === 'idle') ? 0 : j === i && kind === 'clean' ? (k === 'C' ? (u < 0.35 ? 1 : 0) : 1 - ease(span(u, 0.45, 0.9))) : 1));
  const done = SPOTS.filter((_, j) => j < i || (j === i && kind === 'idle')).length;
  const carry = k === 'C' ? done : SPOTS.filter((_, j) => scales[j] === 0).length + (kind === 'clean' && u > 0.9 ? 1 : 0);
  let fx = '';
  if (kind === 'clean' && u > 0.55 && k !== 'C') fx += sparks(SPOTS[i][0], SPOTS[i][1], 0.6 + 0.6 * span(u, 0.55, 1));
  if (kind === 'clean' && u > 0.35 && u < 0.6 && k === 'C') fx += sparks(SPOTS[i][0], SPOTS[i][1], 0.8);
  if (CLEANERS[k].cart && kind === 'clean' && u > 0.35 && u < 0.92) { // 推車牛：大便沿弧線飛進推車
    const c = cleaner(k, { x, y, facing: 'right' }); const [cx, cy] = c.a.cart, p = SPOTS[i], v = span(u, 0.35, 0.92);
    fx += poopG(lerp(p[0], cx, v), lerp(p[1], cy, v) - Math.sin(v * Math.PI) * 40, 14);
  }
  const c = cleaner(k, { x, y, sweep, bob, step, phase, facing: 'right', carry: Math.min(3, carry), id: `g${k}` }).svg;
  return ranchWith(poopsAt(scales.map((s, j) => (CLEANERS[k].cart && j === i && kind === 'clean' && u > 0.35 ? 0 : s))) + c + fx, { center: cleanPill(k) });
}
// 掃地機：從充電座出發 → 一坨一坨吸 → 回去
const RT = [[0, 0.8, 'move', 0], [0.8, 1.3, 'suck', 0], [1.3, 1.9, 'move', 1], [1.9, 2.4, 'suck', 1], [2.4, 3.0, 'move', 2], [3.0, 3.5, 'suck', 2], [3.5, 4.6, 'home', 2], [4.6, 5.0, 'idle', 2]];
function gifRobot(k, t) {
  const D = [DOCK[0] - 4, DOCK[1] + 10], P = [2, 1, 0].map((j) => [SPOTS[j][0] + 6, SPOTS[j][1] + 8]), order = [2, 1, 0];
  const seg = RT.find(([a, b]) => t >= a && t < b) || RT[RT.length - 1];
  const [a, b, kind, i] = seg, u = span(t, a, b);
  let pos, dir = -1;
  if (kind === 'move') { const from = i === 0 ? D : P[i - 1]; pos = [lerp(from[0], P[i][0], ease(u)), lerp(from[1], P[i][1], ease(u))]; }
  else if (kind === 'home') { pos = [lerp(P[2][0], D[0], ease(u)), lerp(P[2][1], D[1], ease(u))]; dir = 1; }
  else if (kind === 'idle') { pos = D; dir = 1; }
  else pos = P[i];
  const done = (n) => n < i || (n === i && (kind === 'home' || kind === 'idle'));
  const scales = SPOTS.map((_, j) => { const n = order.indexOf(j); return done(n) ? 0 : n === i && kind === 'suck' ? 1 - ease(u) : 1; });
  const full = scales.filter((v) => v === 0).length;
  const sp = SPOTS[order[i]];
  const fx = kind === 'suck' ? swirl(sp[0] - 30, sp[1] - 8, 1 + 0.4 * Math.sin(u * Math.PI)) : '';
  return ranchWith(poopsAt(scales) + dock(...DOCK) + robot(k, { x: pos[0], y: pos[1], s: RS, dir, full, spin: t * 720 }) + fx, { center: robotPill(k) });
}
const GIFS = Object.fromEntries(Object.keys(CLEANERS).map((k) => [k, { fn: (t) => gifCleaner(k, t), file: `R25-01-打掃牛-${k}-${CLEANERS[k].file}-390` }]));

async function settle() {
  await document.fonts.ready;
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
}
if (q.has('list')) {
  window.__boards = BOARDS.map(({ id }) => ({ id, w: 390 }));
  window.__ready = true;
} else if (q.has('gif')) {
  const g = GIFS[q.get('gif')];
  window.__frame = async (t) => { app.innerHTML = `<div class="gif-box"><div class="gif-label">${g.file}</div>${g.fn(t)}</div>`; await settle(); };
  window.__gif = { file: g.file, total: 5 };
  await window.__frame(0);
  window.__ready = true;
} else {
  const b = BOARDS.find((x) => x.id === q.get('b'));
  if (!b) throw new Error(`沒有這張：${q.get('b')}`);
  app.innerHTML = b.render().html;
  await settle();
  if (fitTitles(app)) await settle();
  if (placeVersion(app)) await settle();
  const el = app.querySelector('.board');
  window.__file = el.querySelector('.b-label').textContent;
  window.__size = { w: Math.ceil(el.offsetWidth), h: Math.ceil(el.offsetHeight) };
  window.__ready = true;
}
