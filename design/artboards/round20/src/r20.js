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
  const dots = [[-0.45, 0.62], [0, 0.42], [0.45, 0.62], [-0.2, 0.9], [0.25, 0.92]].map(([u, v]) => `<circle cx="${f2(fx + u * w)}" cy="${f2(y0 - v * (y0 - top) * 0.62)}" r="${f2(fr * 0.07)}" fill="#FFFFFF"/>`).join('');
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
const CLEANERS = {
  A: { name: '頭巾掃把牛', file: '頭巾掃把牛', breed: 'holstein', sex: 'cow', seed: 52, acc: accA, intro: '紅色點點頭巾、嘴裡咬著掃把，看到大便就掃掉。', fun: '最好懂：一看就知道牠在打掃；黑白花配紅頭巾很顯眼。' },
  B: { name: '圍裙推車牛', file: '圍裙推車牛', breed: 'yellow', sex: 'cow', seed: 61, acc: accB, intro: '藍色圍裙、後面拉一台小推車，把大便一坨一坨裝走。', fun: '推車裡的大便會越裝越多，看得出牠今天清了幾坨；黃牛配藍圍裙很親切。' },
  C: { name: '草帽鏟子牛', file: '草帽鏟子牛', breed: 'jersey', sex: 'cow', seed: 73, acc: accC, intro: '戴草帽、脖子掛小水桶，用小鏟子把大便鏟進桶子。', fun: '最有農場味：草帽、小鏟子、小水桶；動作是「鏟一下、倒進桶子」。' },
};
// 一頭打掃牛（場景座標）：x、y 是腳底中間
function cleaner(k, { x, y, s = SIDE_S, facing = 'left', pose = 'side', sweep = 0, carry = 0, bob = 0, id = 'cl' } = {}) {
  const C = CLEANERS[k];
  const r = drawCow({ breed: C.breed, sex: C.sex, seed: C.seed, pose }, { x, y, scale: s, facing, id });
  const g = geo(r, y);
  const a = C.acc(r, g, { pose, sweep, carry });
  const shadow = `<ellipse cx="${f2(r.shadow.cx)}" cy="${f2(y)}" rx="${f2(r.shadow.rx)}" ry="${f2(r.shadow.ry)}" fill="#3E6B2A" opacity="0.18"/>`;
  return { svg: `${shadow}<g transform="translate(0 ${f2(-bob)})">${a.back}${r.svg}${a.front}</g>`, r, g, a };
}
// 打掃牛單獨一張圖（雇用面板、右上角）：crop 'head' 只要頭
function cleanerArt(k, w, h, crop = 'full') {
  const c = cleaner(k, { x: 0, y: 0, s: 1, pose: 'front', id: `ca${k}${crop}` });
  const { fx, fy, fr } = c.g;
  const vb = crop === 'head' ? [fx - fr * 1.6, fy - fr * 1.9, fr * 3.2, fr * 3.2] : [-fr * 3.4, fy - fr * 2.1, fr * 6.8, -(fy - fr * 2.1) + 6];
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
  const flyB = k === 'B' ? (() => { const c = cleaner(k, { x: sx, y: sy, facing: 'right' }); const [cx, cy] = c.a.cart; return `<path d="M${p0[0]} ${p0[1] - 6}Q${(p0[0] + cx) / 2} ${Math.min(p0[1], cy) - 46} ${cx} ${cy}" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-dasharray="2 7" stroke-linecap="round"/>${poopG((p0[0] + cx) / 2, Math.min(p0[1], cy) - 30, 14)}`; })() : '';
  return [
    { cap: '雇用面板', note: '從右上角的大便數、或商店打開；一天 2,000 幣，最多一次付 7 天', html: ranchWith(poopsAt(), { center: dirtyPill(3), overlays: hireSheet(k) }) },
    { cap: '雇好了：右上角變成「打掃中」', note: '打掃牛從牧場旁邊走進來（還有幾天寫在旁邊）', html: ranchWith(poopsAt() + cl({ x: 30, y: 500, bob: 2 }), { center: cleanPill(k) }) },
    { cap: '走到大便旁邊', note: '', html: ranchWith(poopsAt() + cl({ x: sx, y: sy }), { center: cleanPill(k) }) },
    { cap: '清掉：大便不見、冒星星', note: k === 'B' ? '大便飛進後面的推車，推車裡多一坨' : k === 'C' ? '鏟一下，倒進脖子上的水桶' : '掃把左右掃一下', html: ranchWith(poopsAt([0.35, 1, 1]) + cl({ x: sx, y: sy, sweep: 6, carry: 1 }) + flyB + sparks(p0[0], p0[1]), { center: cleanPill(k) }) },
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
const SUB20 = '使用者看完雅兒貝德比對圖：「你改做成打掃牛，有一隻牛會來打掃。還有作一個大便掃地機給我看看。」打掃牛用核准的牛產生器加配件；原創，不像其他遊戲的吉祥物。雇用規則照 v0.3 第 5.1 節：一天 2,000 幣，最多一次付 7 天，雇用期間每 30 分鐘把大便全部清掉。';
const SUB20R = '使用者想先看看「大便掃地機」：像掃地機器人，在牧場自己跑、把大便吸走。價錢、規則先寫「待定」；是取代打掃牛還是另外一個東西，看完圖再問使用者。';
const BOARDS = [
  ...Object.keys(CLEANERS).map((k) => ({ id: `R20-01-${k}`, render: () => board({ id: `R20-01-打掃牛-${k}-${CLEANERS[k].file}-390`, title: `01 打掃牛　${k}：${CLEANERS[k].name}`, sub: SUB20, cells: cleanerCells(k), notes: [CLEANERS[k].fun, `動起來的樣子見 GIF：R20-01-打掃牛-${k}-${CLEANERS[k].file}-390.gif`] }) })),
  ...Object.keys(ROBOTS).map((k) => ({ id: `R20-02-${ROBOTS[k].opt}`, render: () => board({ id: `R20-02-大便掃地機-${ROBOTS[k].opt}-${ROBOTS[k].file}-390`, title: `02 大便掃地機　${ROBOTS[k].opt}：${ROBOTS[k].name}`, sub: SUB20R, cells: robotCells(k), notes: [ROBOTS[k].fun, `動起來的樣子見 GIF：R20-02-大便掃地機-${ROBOTS[k].opt}-${ROBOTS[k].file}-390.gif`] }) })),
  { id: 'R20-99', render: r2099 },
];
function r2099() {
  const S = 0.5, sw = Math.round(dev.w * S), sh = Math.round(dev.h * S);
  const mini = (html) => `<div class="ov-ph" style="width:${sw}px;height:${sh}px"><div style="transform:scale(${S});transform-origin:0 0">${html}</div></div>`;
  const cell = (cap, inner) => `<div class="ov-cell"><div class="ov-cap"><b>${cap}</b></div>${inner}</div>`;
  const row = (title, cells) => `<div class="ov-row"><div class="ov-title">${title}</div><div class="ov-cells">${cells.join('')}</div></div>`;
  const ks = Object.keys(CLEANERS);
  const body = row('01 打掃牛：清大便的樣子', ks.map((k) => cell(`${k}　${CLEANERS[k].name}`, mini(cleanerCells(k)[3].html))))
    + row('01 打掃牛：雇用面板', ks.map((k) => cell(`${k}　${CLEANERS[k].name}`, mini(cleanerCells(k)[0].html))))
    + row('02 大便掃地機：吸大便的樣子', Object.keys(ROBOTS).map((k) => cell(`${ROBOTS[k].opt}　${ROBOTS[k].name}`, mini(robotCells(k)[2].html))))
    + row('02 大便掃地機：購買面板（價錢、規則待定）', Object.keys(ROBOTS).map((k) => cell(`${ROBOTS[k].opt}　${ROBOTS[k].name}`, mini(robotCells(k)[0].html))));
  return { html: `<div class="board" style="width:${PAD * 2 + 3 * sw + 2 * 28 + 10}px"><div class="b-label">R20-99-總覽對照</div><div class="b-title">第 20 輪：打掃牛、大便掃地機</div>
    <div class="b-sub">打掃牛選一種；大便掃地機先看樣子。各自的分鏡見 R20-01、R20-02，動起來的樣子見同名的 GIF。</div>${body}</div>` };
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
  if (kind === 'clean') sweep = Math.sin(u * Math.PI * 4) * 7;
  const scales = SPOTS.map((_, j) => (j < i || (j === i && kind === 'idle') ? 0 : j === i && kind === 'clean' ? 1 - ease(span(u, 0.45, 0.9)) : 1));
  const carry = SPOTS.filter((_, j) => scales[j] === 0).length + (kind === 'clean' && u > 0.9 ? 1 : 0);
  let fx = '';
  if (kind === 'clean' && u > 0.55) fx += sparks(SPOTS[i][0], SPOTS[i][1], 0.6 + 0.6 * span(u, 0.55, 1));
  if (k === 'B' && kind === 'clean' && u > 0.35 && u < 0.92) { // 推車牛：大便沿弧線飛進推車
    const c = cleaner(k, { x, y, facing: 'right' }); const [cx, cy] = c.a.cart, p = SPOTS[i], v = span(u, 0.35, 0.92);
    fx += poopG(lerp(p[0], cx, v), lerp(p[1], cy, v) - Math.sin(v * Math.PI) * 40, 14);
  }
  const c = cleaner(k, { x, y, sweep, bob, facing: 'right', carry: Math.min(3, carry), id: `g${k}` }).svg;
  return ranchWith(poopsAt(scales.map((s, j) => (k === 'B' && j === i && kind === 'clean' && u > 0.35 ? 0 : s))) + c + fx, { center: cleanPill(k) });
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
const GIFS = {
  ...Object.fromEntries(Object.keys(CLEANERS).map((k) => [k, { fn: (t) => gifCleaner(k, t), file: `R20-01-打掃牛-${k}-${CLEANERS[k].file}-390` }])),
  ...Object.fromEntries(Object.keys(ROBOTS).map((k) => [k, { fn: (t) => gifRobot(k, t), file: `R20-02-大便掃地機-${ROBOTS[k].opt}-${ROBOTS[k].file}-390` }])),
};

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
