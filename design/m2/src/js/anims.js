// M2 動畫 A-01～A-10：每個動畫是「底圖＋frame(t)」，t 是秒。frame 只依 t 決定畫面（可以停在任何一格截圖）。
// 揭曉類（A-04、A-06、A-09、A-10）控制在 1.5 秒內，點一下可以跳過。減少動態（手機系統設定）時各自的替代做法寫在 reduced。
import { frame, btn, icon, fmt, cowSVG, toast, tierChip, badge, dialog } from './kit.js';
import { ranchPage, dock } from './screens/s03.js';
import { HERD, fit, ranchScene } from './scene.js';
import { drawCow } from '../cow/render.js';
import { RANCH, WAREHOUSE, sum, FIELDS, cowById } from './fixtures.js';
import { GRADE_BG } from './screens/s04.js';

// ---------- 小工具 ----------
const clamp = (v) => Math.max(0, Math.min(1, v));
const seg = (t, a, b) => clamp((t - a) / (b - a));
const outCubic = (x) => 1 - (1 - x) ** 3;
const inOut = (x) => (x < 0.5 ? 4 * x * x * x : 1 - (-2 * x + 2) ** 3 / 2);
const outBack = (x) => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2; };
const lerp = (a, b, k) => a + (b - a) * k;
function rel(root, el) { const p = root.querySelector('.phone').getBoundingClientRect(), r = el.getBoundingClientRect(); return { x: r.left - p.left, y: r.top - p.top, w: r.width, h: r.height, cx: r.left - p.left + r.width / 2, cy: r.top - p.top + r.height / 2 }; }
function layer(root) { let l = root.querySelector('.fx'); if (!l) { root.querySelector('.phone').insertAdjacentHTML('beforeend', '<div class="fx"></div>'); l = root.querySelector('.fx'); } return l; }
// 沿著拋物線從 a 飛到 b（k：0–1），回傳位置
function arc(a, b, k, lift = 80) { const x = lerp(a.x, b.x, k), y = lerp(a.y, b.y, k) - Math.sin(Math.PI * k) * lift; return { x, y }; }
function place(el, x, y, { s = 1, r = 0, o = 1 } = {}) { el.style.transform = `translate(${x}px, ${y}px) translate(-50%, -50%) scale(${s}) rotate(${r}deg)`; el.style.opacity = o; }
function skipHint(on) { return on ? `<div class="skip-hint">點一下跳過</div>` : ''; }

// ---------- A-01 收奶 ----------
const A01 = {
  id: 'A-01', name: '收奶', dur: 1.4, where: 'S03 牧場',
  keys: [[0, '按下「收奶」'], [0.35, '奶瓶從奶桶飛出，奶桶的水位往下降'], [0.7, '奶瓶飛進倉庫卡，牛奶數字往上跳'], [1.05, '奶桶歸零，倉庫 +36 瓶'], [1.4, '提示「收了 36.4 瓶牛奶」']],
  reduced: '不飛奶瓶、數字不跳動：按下後奶桶直接變 0、倉庫直接變 166 瓶，提示淡入（0.2 秒）。',
  base: (ctx) => ranchPage(ctx),
  frame(root, t) {
    const L = layer(root);
    if (!L.children.length) L.innerHTML = [0, 1, 2, 3, 4].map(() => `<span class="fly">${icon('milk', 28)}</span>`).join('') + toast('ok', '收了 36.4 瓶牛奶，放進倉庫了', { style: 'opacity:0' });
    const bk = root.querySelector('.bucket-card'), from = rel(root, root.querySelector('.bk-icon')), to = rel(root, root.querySelector('.storage .mini-line'));
    const btnEl = bk.querySelector('.btn'); btnEl.style.transform = `scale(${t < 0.15 ? 1 - 0.06 * Math.sin(Math.PI * seg(t, 0, 0.15)) : 1})`;
    [...L.querySelectorAll('.fly')].forEach((el, i) => {
      const k = seg(t, 0.1 + i * 0.08, 0.6 + i * 0.08);
      const p = arc({ x: from.cx, y: from.cy }, { x: to.x + 20, y: to.cy }, outCubic(k), 90);
      place(el, p.x, p.y, { s: 0.7 + 0.5 * Math.sin(Math.PI * k), r: -20 + 40 * k, o: k > 0 && k < 1 ? 1 : 0 });
    });
    const drain = inOut(seg(t, 0.1, 0.85)), pct = Math.round(87 * (1 - drain)), qty = 36.4 * (1 - drain);
    bk.querySelector('.num-pct').textContent = `${pct}%`;
    bk.querySelector('.bar i').style.width = `${pct}%`;
    bk.querySelector('.bk-count .num').textContent = `${qty < 0.05 ? 0 : qty.toFixed(1)} / 42`;
    bk.querySelector('.bk-rate').textContent = drain >= 1 ? '約 1 小時後滿' : '約 9 分後滿';
    const gain = outCubic(seg(t, 0.55, 1.05));
    root.querySelector('.storage .mini-line .num').textContent = `${Math.round(130 + 36.4 * gain)}`;
    const tk = seg(t, 1.0, 1.2), ts = L.querySelector('.toast'); ts.style.opacity = tk; ts.style.transform = `translateY(${(1 - outCubic(tk)) * 14}px)`;
  },
};

// ---------- A-02 成交 ----------
import { sellCard } from './screens/s06.js';
const A02 = {
  id: 'A-02', name: '成交', dur: 1.4, where: 'S06 市場',
  keys: [[0, '按下「確認賣出 130 瓶」'], [0.4, '金幣從按鈕飛向頂列'], [0.8, '頂列金幣數字往上跳'], [1.1, '庫存扣掉，提示成交結果'], [1.4, '結束']],
  reduced: '不飛金幣、數字不跳動：頂列金幣直接變成 14,404，提示淡入（0.2 秒）。',
  base: (ctx) => {
    const html = frame(ctx.dev, { tab: 'market', content: `<div class="stack">${sellCard({ key: 'milk', name: '牛奶', unit: '瓶', price: 13.4, stock: 146 }, 'ok', { qty: 130, avg: 14.8, total: 1924, lots: 3 })}</div>` });
    return html;
  },
  frame(root, t) {
    const L = layer(root);
    if (!L.children.length) L.innerHTML = [0, 1, 2, 3, 4, 5].map(() => `<span class="fly">${icon('coin', 30)}</span>`).join('') + toast('ok', '賣出 130 瓶，均價 14.8，共 1,924 幣', { style: 'opacity:0' });
    const b = root.querySelector('.sell-card .btn.block'), from = rel(root, b), to = rel(root, root.querySelector('.coins'));
    b.style.transform = `scale(${t < 0.15 ? 1 - 0.05 * Math.sin(Math.PI * seg(t, 0, 0.15)) : 1})`;
    [...L.querySelectorAll('.fly')].forEach((el, i) => {
      const k = seg(t, 0.1 + i * 0.07, 0.65 + i * 0.07);
      const p = arc({ x: from.cx + (i - 2.5) * 16, y: from.cy }, { x: to.x + 6, y: to.cy }, outCubic(k), 60);
      place(el, p.x, p.y, { s: 1 - 0.3 * k, o: k > 0 && k < 1 ? 1 : 0 });
    });
    const g = outCubic(seg(t, 0.5, 1.05));
    root.querySelector('.num-coins').textContent = fmt(Math.round(RANCH.coins + 1924 * g));
    const pulse = Math.sin(Math.PI * seg(t, 0.55, 1.05));
    root.querySelector('.coins').style.transform = `scale(${1 + 0.08 * pulse})`;
    const q = seg(t, 1.0, 1.15);
    root.querySelector('.sell-card .card-sub').textContent = `庫存 ${q > 0 ? 16 : 146} 瓶${q > 0 ? '（1 批）' : '（3 批）'}`;
    const ts = L.querySelector('.toast'); ts.style.opacity = seg(t, 1.0, 1.2); ts.style.transform = `translateY(${(1 - outCubic(seg(t, 1.0, 1.2))) * 14}px)`;
  },
};

// ---------- A-03 出貨卡車 ----------
const TRUCK = `<svg viewBox="0 0 210 130" width="210" height="130" aria-hidden="true">
  <path d="M8 60h122v44H8z" fill="#A9DBFF" stroke="#4B3326" stroke-width="4" stroke-linejoin="round"/>
  <path d="M8 60h122" stroke="#4B3326" stroke-width="4"/><path d="M14 72h110" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" opacity=".7"/>
  <path d="M130 50h40l28 32v22h-68z" fill="#FFD45E" stroke="#4B3326" stroke-width="4" stroke-linejoin="round"/>
  <path d="M142 58h24l18 22h-42z" fill="#E6F3FC" stroke="#4B3326" stroke-width="3" stroke-linejoin="round"/>
  <rect x="186" y="88" width="14" height="8" rx="3" fill="#FFF1B8" stroke="#4B3326" stroke-width="2.5"/>
  <circle cx="44" cy="108" r="15" fill="#FFFFFF" stroke="#4B3326" stroke-width="4"/><circle cx="44" cy="108" r="5" fill="#4B3326"/>
  <circle cx="164" cy="108" r="15" fill="#FFFFFF" stroke="#4B3326" stroke-width="4"/><circle cx="164" cy="108" r="5" fill="#4B3326"/>
  <path d="M40 84h60" stroke="#4B3326" stroke-width="3" stroke-linecap="round"/><text x="70" y="98" text-anchor="middle" font-family="Noto Sans CJK TC" font-weight="900" font-size="13" fill="#4B3326">晨光河畔牧場</text></svg>`;
function cutscene(ctx, inner) {
  // 背景用牧場場景（沒有牛），前面加一條路
  const bg = ranchScene(ctx.dev, []).svg;
  return frame(ctx.dev, { tab: null, hud: false, scene: bg, body: `<div class="cut"><div class="cut-road"></div>${inner}</div>` });
}
const A03 = {
  id: 'A-03', name: '出貨卡車', dur: 2.6, where: 'S07 出貨確認 → S20 評級結果',
  keys: [[0, '按下「確定出貨」後切到這一幕'], [0.55, '小卡車開進來'], [0.95, '牛跳上卡車'], [1.4, '牛揮手：「謝謝你的照顧！」'], [2.1, '卡車開走'], [2.6, '白光轉場，接著揭曉評級（A-10）']],
  reduced: '不播卡車：按下「確定出貨」後直接顯示評級結果（S20），不播揭曉動畫。',
  base: (ctx) => cutscene(ctx, `<div class="cut-cow">${cowSVG({ breed: 'holstein' }, { w: 120, h: 120 })}</div><div class="cut-truck">${TRUCK}</div><div class="cut-say">謝謝你的照顧！</div><div class="cut-puffs"><i></i><i></i><i></i></div><div class="cut-flash"></div>`),
  frame(root, t, ctx) {
    const W = ctx.dev.w, H = ctx.dev.h, groundY = H * 0.74, TS = 1.15;
    const truck = root.querySelector('.cut-truck'), cow = root.querySelector('.cut-cow'), say = root.querySelector('.cut-say');
    // 卡車：0–0.55 從右邊開進來，停在畫面右半邊；1.6–2.3 往左開走
    const inK = outCubic(seg(t, 0, 0.55)), outK = inOut(seg(t, 1.6, 2.3));
    const stopX = W - 210 * TS - 8;
    const tx = lerp(W + 40, stopX, inK) - outK * (W + 280);
    const bounce = Math.sin(t * 28) * (t < 0.55 || (t > 1.6 && t < 2.3) ? 1.5 : 0);
    const ty = groundY - 128 * TS + bounce;
    truck.style.transform = `translate(${tx}px, ${ty}px) scale(${TS})`; truck.style.transformOrigin = '0 0';
    // 牛：站在左邊；0.6–0.95 跳上車斗，之後跟著卡車
    const jumpK = seg(t, 0.6, 0.95);
    const cx0 = W * 0.06, cy0 = groundY - 116;
    const bedX = tx + 14 * TS, bedY = ty + 60 * TS - 104;
    let cx = lerp(cx0, bedX, outCubic(jumpK)), cy = lerp(cy0, bedY, jumpK) - Math.sin(Math.PI * jumpK) * 80;
    if (t > 0.95) { cx = bedX; cy = bedY; }
    const wave = t > 1.0 && t < 1.6 ? Math.sin((t - 1.0) * 18) * 5 : 0;
    cow.style.transform = `translate(${cx}px, ${cy}px) rotate(${wave}deg)`;
    const sk = seg(t, 1.0, 1.15);
    say.style.opacity = t < 1.95 ? sk : 1 - seg(t, 1.95, 2.1);
    say.style.transform = `translate(${cx + 40}px, ${cy - 40}px) scale(${0.6 + 0.4 * outBack(sk)})`;
    [...root.querySelectorAll('.cut-puffs i')].forEach((p, i) => {
      const k = seg(t, 1.65 + i * 0.12, 2.1 + i * 0.12);
      p.style.opacity = k > 0 && k < 1 ? 1 - k : 0;
      p.style.transform = `translate(${tx + 210 * TS + k * 30}px, ${groundY - 24 - k * 16}px) scale(${0.5 + k})`;
    });
    root.querySelector('.cut-flash').style.opacity = seg(t, 2.3, 2.6);
  },
};

// ---------- 揭曉用的中央卡 ----------
function revealLayer(ctx, pageHTML, inner) {
  return pageHTML.replace('<div class="overlays">', `<div class="overlays"><div class="backdrop"></div><div class="reveal">${inner}</div>`);
}

// ---------- A-04 小牛出生 ----------
const A04 = {
  id: 'A-04', name: '小牛出生（揭曉）', dur: 1.5, where: 'S08 配種、S18 借種',
  keys: [[0, '配種成功，出現蓋著布的草窩'], [0.35, '布動來動去'], [0.6, '布飛走，露出小牛的剪影'], [0.9, '剪影變成彩色小牛'], [1.2, '跳出名字和稀有度'], [1.5, '結束，接著顯示小牛倒數卡']],
  reduced: '不播動畫：直接顯示小牛、名字和稀有度（淡入 0.2 秒），再顯示小牛倒數卡。',
  base: (ctx) => revealLayer(ctx, frame(ctx.dev, { tab: 'breed', content: '<div></div>' }), `
    <div class="nest"><div class="calf-sil">${cowSVG({ breed: 'jersey', age: 'calf', seed: 91 }, { w: 170, h: 150, sil: 'dark' })}</div><div class="calf-col">${cowSVG({ breed: 'jersey', age: 'calf', seed: 91 }, { w: 170, h: 150 })}</div>
      <div class="hay"></div><div class="cloth">${icon('heart', 34)}</div></div>
    <div class="reveal-name"><b>娟珊 #16</b><div class="chips">${tierChip(1)}${badge('calf', '小牛')}</div></div>
    <div class="burst-hearts">${[0, 1, 2, 3, 4, 5].map(() => `<i>${icon('heart', 22)}</i>`).join('')}</div>${skipHint(true)}`),
  frame(root, t) {
    const cloth = root.querySelector('.cloth'), sil = root.querySelector('.calf-sil'), col = root.querySelector('.calf-col'), nm = root.querySelector('.reveal-name');
    const wig = t < 0.4 ? Math.sin(t * 40) * 7 * seg(t, 0, 0.1) : 0;
    const off = seg(t, 0.4, 0.7);
    cloth.style.transform = `translate(-50%, ${-off * 120}px) rotate(${wig + off * -35}deg)`;
    cloth.style.opacity = 1 - seg(t, 0.55, 0.7);
    const up = outBack(seg(t, 0.5, 0.85));
    [sil, col].forEach((e) => { e.style.transform = `translateX(-50%) scale(${0.55 + 0.45 * up})`; });
    sil.style.opacity = t < 0.5 ? 0 : 1 - seg(t, 0.75, 1.0);
    col.style.opacity = seg(t, 0.75, 1.0);
    const nk = seg(t, 1.0, 1.25);
    nm.style.opacity = nk; nm.style.transform = `scale(${0.7 + 0.3 * outBack(nk)})`;
    [...root.querySelectorAll('.burst-hearts i')].forEach((h, i) => {
      const k = seg(t, 1.0 + i * 0.03, 1.45);
      const a = (i / 6) * Math.PI * 2 - Math.PI / 2;
      h.style.opacity = k > 0 && k < 1 ? 1 - k * 0.8 : 0;
      h.style.transform = `translate(${Math.cos(a) * 110 * outCubic(k)}px, ${Math.sin(a) * 90 * outCubic(k)}px) scale(${0.6 + 0.6 * k})`;
    });
  },
};

// ---------- A-05 升級 ----------
const A05 = {
  id: 'A-05', name: '升級（場主升級、設施升級）', dur: 1.3, where: 'S11 升級、S10 設施',
  keys: [[0, '累積收入跨過門檻'], [0.25, '升級卡彈出來'], [0.55, '等級數字從 4 翻成 5'], [0.9, '彩帶落下'], [1.3, '停住，按「好」關掉']],
  reduced: '不彈、不翻、沒有彩帶：升級卡直接出現（淡入 0.2 秒），等級直接是 5。設施升級：那一列直接換成新的數字。',
  base: (ctx) => ranchPage(ctx, { hud: { level: 4, xp: 100 }, overlays: `<div class="backdrop"></div><div class="lv-wrap"><div class="confetti">${Array.from({ length: 26 }, (_, i) => { const c = ['#FFD45E', '#FF9784', '#A9DBFF', '#BDE8A6', '#FFD0DE'][i % 5]; return `<i style="left:${(i * 37) % 100}%;background:${c}"></i>`; }).join('')}</div>
    <section class="lv-card card"><div class="lv-ribbon" data-free>場主升級</div><div class="lv-big"><span>Lv</span><span class="lv-roll"><b class="num old">4</b><b class="num new">5</b></span></div><p class="lv-sub">累積收入到 7,500 幣了！</p><p class="hint" style="text-align:center">繼續賣牛奶、牛肉、稻米，或出借公牛，等級會往上升。</p><div class="btn-row" style="margin-top:14px;width:100%">${btn('好', { kind: 'primary' })}</div></section></div>` }),
  frame(root, t) {
    const bd = root.querySelector('.backdrop'), card = root.querySelector('.lv-card');
    bd.style.opacity = seg(t, 0, 0.2);
    const k = seg(t, 0.05, 0.35);
    card.style.transform = `scale(${t < 0.05 ? 0.4 : 0.4 + 0.6 * outBack(k)})`; card.style.opacity = seg(t, 0.05, 0.15);
    const f = inOut(seg(t, 0.4, 0.65));
    root.querySelector('.hud .lv').textContent = f >= 0.5 ? 'Lv 5' : 'Lv 4';
    root.querySelector('.hud .xp i').style.width = f >= 0.5 ? '0%' : '100%';
    root.querySelector('.lv-roll .old').style.transform = `translateY(${-f * 90}px)`;
    root.querySelector('.lv-roll .new').style.transform = `translateY(${(1 - f) * 90}px)`;
    [...root.querySelectorAll('.confetti i')].forEach((c, i) => {
      const d = seg(t, 0.35 + (i % 7) * 0.04, 1.3);
      c.style.top = `${-10 + d * (40 + (i * 53) % 46)}%`;
      c.style.opacity = t < 0.35 ? 0 : 1;
      c.style.transform = `rotate(${(i * 29) % 90 + d * 240}deg)`;
    });
  },
};

// ---------- A-06 發現新品種 ----------
const A06 = {
  id: 'A-06', name: '發現新品種（揭曉）', dur: 1.5, where: '小牛出生（A-04）之後',
  keys: [[0, '「發現新品種！」卡片，先是剪影'], [0.4, '卡片翻面'], [0.75, '翻過來是彩色的新品種'], [1.1, '圖鑑數字 +1'], [1.5, '停住']],
  reduced: '不翻面：直接顯示彩色的品種卡和「已發現 11 / 24」（淡入 0.2 秒）。',
  base: (ctx) => revealLayer(ctx, frame(ctx.dev, { tab: 'breed', content: '<div></div>' }), `
    <div class="disc-title">發現新品種！</div>
    <div class="disc-card"><div class="disc-face back">${cowSVG({ breed: 'chocolate', age: 'calf', seed: 93 }, { w: 150, h: 140, sil: 'dark' })}<b>？？？</b></div>
      <div class="disc-face front">${cowSVG({ breed: 'chocolate', age: 'calf', seed: 93 }, { w: 150, h: 140 })}<b>巧克力牛</b><div class="chips">${tierChip(2)}</div></div></div>
    <div class="disc-count">${icon('book', 22)}圖鑑 已發現 <b class="num"><span class="c-old">10</span><span class="c-new">11</span></b> / 24</div>
    <div class="sparkles">${[0, 1, 2, 3, 4].map(() => `<i>${icon('sparkle', 24)}</i>`).join('')}</div>${skipHint(true)}`),
  frame(root, t) {
    const title = root.querySelector('.disc-title'), card = root.querySelector('.disc-card');
    title.style.opacity = seg(t, 0, 0.15); title.style.transform = `scale(${0.8 + 0.2 * outBack(seg(t, 0, 0.25))})`;
    const f = inOut(seg(t, 0.3, 0.8)), deg = f * 180;
    card.style.transform = `rotateY(${deg}deg)`;
    root.querySelector('.disc-face.back').style.opacity = deg < 90 ? 1 : 0;
    root.querySelector('.disc-face.front').style.opacity = deg >= 90 ? 1 : 0;
    const c = seg(t, 1.0, 1.2);
    root.querySelector('.c-old').style.display = c > 0.5 ? 'none' : 'inline';
    root.querySelector('.c-new').style.display = c > 0.5 ? 'inline' : 'none';
    root.querySelector('.disc-count').style.transform = `scale(${1 + 0.12 * Math.sin(Math.PI * c)})`;
    [...root.querySelectorAll('.sparkles i')].forEach((s, i) => {
      const k = seg(t, 0.8 + i * 0.05, 1.4);
      s.style.opacity = k > 0 && k < 1 ? Math.sin(Math.PI * k) : 0;
      s.style.transform = `translate(${[-120, 120, -90, 100, 0][i]}px, ${[-110, -80, 40, 60, -150][i]}px) scale(${0.5 + k})`;
    });
  },
};

// ---------- A-07 轉身（側面 ↔ 正面，含換臉） ----------
const A07 = {
  id: 'A-07', name: '轉身（側面 ↔ 正面）', dur: 0.5, where: 'S03 牧場（奶桶滿了、點到牛）',
  keys: [[0, '側面走路（9966 的臉）'], [0.15, '身體往中間收窄'], [0.25, '換成正面（9967 的臉）'], [0.38, '正面展開、輕輕跳一下'], [0.5, '坐好']],
  reduced: '不轉：直接換成另一個角度。',
  base: (ctx) => {
    const herd = HERD.filter((c) => c.id !== 12);
    const html = ranchPage(ctx, { herd });
    const F = fit(ctx.dev), c = HERD.find((h) => h.id === 12), s = 1.0 * 1.04;
    const side = drawCow({ breed: 'strawberry', pose: 'side' }, { x: c.x, y: c.y, scale: s, facing: c.facing, id: 'a7s' });
    const front = drawCow({ breed: 'strawberry', pose: 'front' }, { x: c.x, y: c.y, scale: s, facing: c.facing, id: 'a7f' });
    const vb = [-F.ox / F.k, -F.oy / F.k, ctx.dev.w / F.k, ctx.dev.h / F.k].join(' ');
    const ov = `<svg class="turn" viewBox="${vb}" width="${ctx.dev.w}" height="${ctx.dev.h}" data-x="${c.x}" data-y="${c.y}"><ellipse cx="${c.x}" cy="${c.y + 1}" rx="${front.shadow.rx}" ry="${front.shadow.ry}" fill="#86CC70"/><g class="t-side">${side.svg}</g><g class="t-front">${front.svg}</g></svg>`;
    return html.replace('</svg></div>', `</svg>${ov}</div>`); // 疊在場景上面、介面下面
  },
  frame(root, t) {
    const svg = root.querySelector('.turn'), x = +svg.dataset.x, y = +svg.dataset.y;
    const a = seg(t, 0, 0.22), b = seg(t, 0.22, 0.44);
    const sx1 = 1 - inOut(a), sx2 = outBack(b);
    const hop = Math.sin(Math.PI * seg(t, 0.22, 0.5)) * 8;
    const tr = (sx, dy) => `translate(${x} ${y - dy}) scale(${Math.max(0.001, sx)} 1) translate(${-x} ${-y})`;
    const side = svg.querySelector('.t-side'), front = svg.querySelector('.t-front');
    side.setAttribute('transform', tr(sx1, 0)); side.style.opacity = t < 0.22 ? 1 : 0;
    front.setAttribute('transform', tr(sx2, hop)); front.style.opacity = t >= 0.22 ? 1 : 0;
  },
};

// ---------- A-08 收成稻米 ----------
import { fieldScene } from './screens/s17.js';
import S17 from './screens/s17.js';
const A08 = {
  id: 'A-08', name: '收成稻米', dur: 1.3, where: 'S17 田地',
  keys: [[0, '按下「收成」'], [0.35, '稻穗從田裡飛出，田裡的稻子變矮'], [0.7, '稻穗飛進倉庫，稻米數字往上跳'], [1.0, '田裡的稻米歸零，重新開始長'], [1.3, '提示「收成了 177 公斤稻米」']],
  reduced: '不飛稻穗：田裡的稻子直接變短，倉庫稻米直接變 361 公斤，提示淡入（0.2 秒）。',
  base: (ctx) => S17.states.find((x) => x.id === 'S17-01').render({ ...ctx }).replace('class="phone tall', 'class="phone').replace(' tall"', '"'),
  frame(root, t, ctx) {
    const L = layer(root);
    if (!L.children.length) L.innerHTML = Array.from({ length: 8 }, () => `<span class="fly">${icon('rice', 30)}</span>`).join('') + toast('ok', '收成了 177 公斤稻米，放進倉庫了', { style: 'opacity:0' });
    const sc = root.querySelector('.field-scene'), cell = root.querySelectorAll('.kv3 .cell')[1], dst = rel(root, cell), src = rel(root, sc);
    const drain = inOut(seg(t, 0.15, 0.8));
    sc.innerHTML = fieldScene(ctx.dev.w - 30, FIELDS.map((f) => (f.cow ? { ...f, rice: f.rice * (1 - drain) + 0.001 } : f)));
    root.querySelectorAll('.field-card').forEach((c) => {
      const f = FIELDS.find((x) => c.textContent.includes(`第 ${x.index + 1} 塊田`)); if (!f || !f.cow) return;
      const r = f.rice * (1 - drain), i = c.querySelector('.bar i'), n = c.querySelector('.fc-bar .num');
      if (i) i.style.width = `${(r / f.cap) * 100}%`; if (n) n.textContent = `${fmt(r, 1)} / ${fmt(f.cap, 1)}`;
    });
    const b = root.querySelector('.content .stack > .btn'); b.style.transform = `scale(${t < 0.15 ? 1 - 0.05 * Math.sin(Math.PI * seg(t, 0, 0.15)) : 1})`;
    [...L.querySelectorAll('.fly')].forEach((el, i) => {
      const k = seg(t, 0.12 + i * 0.06, 0.62 + i * 0.06);
      const from = { x: src.x + src.w * (i % 2 ? 0.8 : 0.2), y: src.y + src.h * 0.6 };
      const p = arc(from, { x: dst.cx, y: dst.cy }, outCubic(k), 50);
      place(el, p.x, p.y, { s: 0.8 + 0.3 * Math.sin(Math.PI * k), r: k * 90, o: k > 0 && k < 1 ? 1 : 0 });
    });
    cell.querySelector('.v').innerHTML = `${Math.round(184 + 177 * outCubic(seg(t, 0.5, 1.0)))} <small>公斤</small>`;
    const ts = L.querySelector('.toast'); ts.style.opacity = seg(t, 0.95, 1.15); ts.style.transform = `translateY(${(1 - outCubic(seg(t, 0.95, 1.15))) * 14}px)`;
  },
};

// ---------- A-09 商店抽牛開獎 ----------
const A09 = {
  id: 'A-09', name: '商店抽牛開獎（揭曉）', dur: 1.5, where: 'S19 商店抽牛',
  keys: [[0, '按下「A 級」：出現金色禮盒'], [0.3, '禮盒搖晃、發光'], [0.55, '蓋子彈開，光線放射'], [0.85, '小牛從盒子裡升起（剪影 → 彩色）'], [1.15, '跳出名字與稀有度'], [1.5, '接著顯示抽到的結果（S19-05）']],
  reduced: '不播動畫：直接顯示抽到的結果（S19-05）。',
  base: (ctx) => revealLayer(ctx, frame(ctx.dev, { tab: 'shop', content: '<div></div>' }), `
    <div class="rays"></div>
    <div class="gbox"><div class="gb-calf sil">${cowSVG({ breed: 'highland', age: 'calf', seed: 97 }, { w: 150, h: 130, sil: 'dark' })}</div><div class="gb-calf col">${cowSVG({ breed: 'highland', age: 'calf', seed: 97 }, { w: 150, h: 130 })}</div>
      <div class="gb-body"><span class="gb-grade">A</span></div><div class="gb-lid"></div></div>
    <div class="reveal-name"><b>高地牛 #17</b><div class="chips">${tierChip(1)}${badge('calf', '小牛')}</div></div>${skipHint(true)}`),
  frame(root, t) {
    const box = root.querySelector('.gbox'), lid = root.querySelector('.gb-lid'), rays = root.querySelector('.rays');
    const shake = t < 0.5 ? Math.sin(t * 46) * 8 * seg(t, 0.05, 0.3) : 0;
    box.style.transform = `translateX(-50%) rotate(${shake}deg) scale(${0.9 + 0.1 * outBack(seg(t, 0, 0.2))})`;
    const pop = seg(t, 0.45, 0.7);
    lid.style.transform = `translate(${pop * 40}px, ${-pop * 110}px) rotate(${pop * 50}deg)`; lid.style.opacity = 1 - seg(t, 0.6, 0.75);
    rays.style.opacity = seg(t, 0.45, 0.6) * (1 - 0.4 * seg(t, 1.2, 1.5));
    rays.style.transform = `translate(-50%, -50%) scale(${0.3 + 0.9 * outCubic(seg(t, 0.45, 0.9))}) rotate(${t * 40}deg)`;
    const up = outBack(seg(t, 0.55, 0.95));
    root.querySelectorAll('.gb-calf').forEach((c) => { c.style.transform = `translate(-50%, ${-up * 118}px) scale(${0.5 + 0.5 * up})`; });
    root.querySelector('.gb-calf.sil').style.opacity = t < 0.55 ? 0 : 1 - seg(t, 0.85, 1.05);
    root.querySelector('.gb-calf.col').style.opacity = seg(t, 0.85, 1.05);
    const nm = root.querySelector('.reveal-name'), nk = seg(t, 1.05, 1.3);
    nm.style.opacity = nk; nm.style.transform = `scale(${0.7 + 0.3 * outBack(nk)})`;
  },
};

// ---------- A-10 出貨評級揭曉 ----------
import { S20M } from './screens/s07.js';
const A10 = {
  id: 'A-10', name: '出貨評級揭曉（揭曉）', dur: 1.5, where: 'S20 出貨評級結果',
  keys: [[0, '卡車開走後，評級框出現'], [0.3, 'A、B、C 快速輪流'], [0.6, '越轉越慢'], [0.9, '停在 A，光線放射'], [1.2, '禮盒掉進來'], [1.5, '顯示收入，按「好」']],
  reduced: '不輪流、不放射：直接顯示評級結果（S20）。',
  base: (ctx) => S20M.states[0].render(ctx).replace('<div class="overlays">', `<div class="overlays">${skipHint(true)}`),
  frame(root, t) {
    const big = root.querySelector('.grade-big'), n = big.querySelector('.num');
    const order = ['B', 'C', 'A'];
    // 前 0.9 秒：A/B/C 輪流，越來越慢；0.9 秒停在 A
    const ticks = [0, 0.08, 0.16, 0.25, 0.35, 0.47, 0.61, 0.76, 0.9];
    let idx = ticks.filter((x) => t >= x).length - 1;
    const g = t >= 0.9 ? 'A' : order[idx % 3];
    n.textContent = g; big.style.background = GRADE_BG[g];
    const land = seg(t, 0.9, 1.05);
    big.style.transform = `scale(${t < 0.9 ? 0.92 : 1 + 0.18 * Math.sin(Math.PI * land)})`;
    const burst = root.querySelector('.burst');
    burst.style.opacity = seg(t, 0.9, 1.05);
    burst.style.transform = `scale(${0.4 + 0.6 * outCubic(seg(t, 0.9, 1.3))}) rotate(${t * 20}deg)`;
    [...root.querySelectorAll('.gift-box')].forEach((b, i) => {
      const k = seg(t, 1.0 + i * 0.08, 1.3 + i * 0.08);
      b.style.opacity = k > 0 ? 1 : 0;
      b.style.transform = `translateY(${(1 - outBack(k)) * -80}px) rotate(${(i - 1) * 6}deg)`;
    });
    root.querySelectorAll('.r-line, .result-card .hint, .result-card .btn-row').forEach((e) => { e.style.opacity = seg(t, 1.2, 1.45); });
  },
};

export const ANIMS = [A01, A02, A03, A04, A05, A06, A07, A08, A09, A10];
