// M2 動畫 A-01～A-10：每個動畫是「底圖＋frame(t)」，t 是秒。frame 只依 t 決定畫面（可以停在任何一格截圖）。
// 揭曉類（A-04、A-06、A-09、A-10）控制在 1.5 秒內，點一下可以跳過。減少動態（手機系統設定）時各自的替代做法寫在 reduced。
import { frame, btn, icon, fmt, cowSVG, toast, tierChip, badge, dialog, useChip } from './kit.js';
import { ranchPage, dock, FEED_DROP, EAT_AT, FEED_HERD } from './screens/s03.js';
import { HERD, fit, ranchScene, WIDE } from './scene.js';
import { drawCow } from '../cow/render.js';
import { RANCH, WAREHOUSE, sum, FIELDS, cowById } from './fixtures.js';
import { GRADE_BG } from './screens/s04.js';
// 字串表的 t() 在這個檔叫 T()，因為 frame(root, t) 的 t 是時間
import { t as T, dur, cowName, calfName, breedName, sexName } from './i18n.js';
// 出貨卡車（A-03）的畫法在 truck.js：素材匯出（harness/assetexport.mjs）也用同一份
import { TK, truckBack, truckFront, A03_HERD } from './truck.js';
import { POOP_SPOTS } from './poop.js';

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
function skipHint(on) { return on ? `<div class="skip-hint">${T('anim.skip')}</div>` : ''; }

// ---------- A-01 收奶 ----------
const A01 = {
  id: 'A-01', name: '收奶', dur: 1.4, where: 'S03 牧場',
  keys: [[0, '按下「收奶」'], [0.35, '奶瓶從奶桶飛出，奶桶的水位往下降'], [0.7, '奶瓶飛進左上角的「倉庫」小鈕，小鈕跳一下'], [1.05, '奶桶歸零'], [1.4, '提示「收了 36.4 瓶牛奶」']],
  // v0.3：倉庫卡拿掉了（第 23 輪 03-B），奶瓶改成飛進頂列左邊的「倉庫」小鈕
  reduced: '不飛奶瓶：按下後奶桶直接變 0，提示淡入（0.2 秒）；「倉庫」小鈕不跳。',
  base: (ctx) => ranchPage(ctx),
  frame(root, t) {
    const L = layer(root);
    if (!L.children.length) L.innerHTML = [0, 1, 2, 3, 4].map(() => `<span class="fly">${icon('milk', 28)}</span>`).join('') + toast('ok', T('collected', { v: 36.4 }), { style: 'opacity:0' });
    const bk = root.querySelector('.bucket-card'), from = rel(root, root.querySelector('.bk-icon')), to = rel(root, root.querySelector('.wh-pill'));
    const btnEl = bk.querySelector('.btn'); btnEl.style.transform = `scale(${t < 0.15 ? 1 - 0.06 * Math.sin(Math.PI * seg(t, 0, 0.15)) : 1})`;
    [...L.querySelectorAll('.fly')].forEach((el, i) => {
      const k = seg(t, 0.1 + i * 0.08, 0.6 + i * 0.08);
      const p = arc({ x: from.cx, y: from.cy }, { x: to.cx, y: to.cy }, outCubic(k), 90);
      place(el, p.x, p.y, { s: 0.7 + 0.5 * Math.sin(Math.PI * k), r: -20 + 40 * k, o: k > 0 && k < 1 ? 1 : 0 });
    });
    const drain = inOut(seg(t, 0.1, 0.85)), pct = Math.round(87 * (1 - drain)), qty = 36.4 * (1 - drain);
    bk.querySelector('.num-pct').textContent = `${pct}%`;
    bk.querySelector('.bar i').style.width = `${pct}%`;
    bk.querySelector('.bk-count .num').textContent = `${qty < 0.05 ? 0 : qty.toFixed(1)} / 42`;
    bk.querySelector('.bk-rate').textContent = T('s03.fullIn', { time: drain >= 1 ? dur({ h: 1 }) : dur({ m: 9 }) });
    const hop = seg(t, 0.55, 1.05), wh = root.querySelector('.wh-pill');
    wh.style.transform = `scale(${(1 + 0.12 * Math.sin(Math.PI * hop)).toFixed(3)})`;
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
    const html = frame(ctx.dev, { tab: 'market', content: `<div class="stack">${sellCard({ key: 'milk', name: T('milk'), unit: T('unitMilk'), price: 13.4, stock: 146 }, 'ok', { qty: 130, avg: 14.8, total: 1924, lots: 3 })}</div>` });
    return html;
  },
  frame(root, t) {
    const L = layer(root);
    if (!L.children.length) L.innerHTML = [0, 1, 2, 3, 4, 5].map(() => `<span class="fly">${icon('coin', 30)}</span>`).join('') + toast('ok', T('sold', { qty: 130, unit: T('unitMilk'), avg: 14.8, total: fmt(1924) }), { style: 'opacity:0' });
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
    root.querySelector('.sell-card .card-sub').textContent = T('inventory', { qty: q > 0 ? 16 : 146, unit: T('unitMilk') }) + T('s06.lots', { n: q > 0 ? 1 : 3 });
    const ts = L.querySelector('.toast'); ts.style.opacity = seg(t, 1.0, 1.2); ts.style.transform = `translateY(${(1 - outCubic(seg(t, 1.0, 1.2))) * 14}px)`;
  },
};

// ---------- A-03 出貨卡車 ----------
// 使用者 2026-10-01：「a03出貨卡車要更精細，而且倒車接牛是對的，但是應該是往前載走不是繼續倒車」
// 卡車的畫法（車身兩層、輪子、擋板）在 truck.js。
// 用固定的模型比例畫一頭牛（腳底在框的下緣中間）；側面、正面用同一個比例，換姿勢時大小不會跳
function cowFixed(entry, { w, h, scale, facing = 'left', pad = 3 }) {
  const r = drawCow(entry, { x: w / 2, y: h - pad, scale, facing, id: `fx${entry.pose}${facing}` });
  return `<svg viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" aria-hidden="true" style="overflow:visible">${r.svg}</svg>`;
}
function cutscene(ctx, inner, herd = []) {
  // 背景用牧場場景，前面加一條路
  const bg = ranchScene(ctx.dev, herd).svg;
  return frame(ctx.dev, { tab: null, hud: false, scene: bg, body: `<div class="cut"><div class="cut-road"></div>${inner}</div>` });
}
const A03 = {
  id: 'A-03', name: '出貨卡車', dur: 3.6, where: 'S07 出貨確認 → S20 評級結果', gifDpr: 2,
  keys: [[0, '按下「確定出貨」後切到這一幕：牛在路邊等'], [0.58, '小卡車倒車進來：車尾朝牛，倒車燈閃、「嗶嗶」'], [1.1, '停好，車尾的擋板放下來變成斜坡'], [1.42, '牛跳上車斗'], [1.9, '擋板關上，牛轉過來面向玩家'], [2.3, '牛揮手：「謝謝你的照顧！」'], [3.05, '卡車往前開走（車頭在前）'], [3.6, '白光轉場，接著揭曉評級（A-10）']],
  reduced: '不播卡車：按下「確定出貨」後直接顯示評級結果（S20），不播揭曉動畫。',
  base: (ctx) => cutscene(ctx, `
    <div class="tk tk-back">${truckBack()}</div>
    <div class="cut-cow c-side">${cowFixed({ breed: 'holstein', pose: 'side' }, { w: 108, h: 96, scale: 1.04, facing: 'right' })}</div>
    <div class="cut-cow c-front">${cowFixed({ breed: 'holstein', pose: 'front' }, { w: 100, h: 100, scale: 1.04 })}</div>
    <div class="tk tk-front">${truckFront(RANCH.name)}</div>
    <div class="cut-beep">${T('anim.beep')}</div><div class="cut-beep b2">${T('anim.beep')}</div>
    <div class="cut-say">${T('anim.thanks')}</div>
    <div class="cut-hearts">${[0, 1, 2].map(() => `<i>${icon('heart', 20)}</i>`).join('')}</div>
    <div class="cut-puffs"><i></i><i></i><i></i><i></i></div>
    <div class="cut-flash"></div>${skipHint(true)}`, A03_HERD),
  frame(root, t, ctx) {
    const W = ctx.dev.w, H = ctx.dev.h, TS = 0.86;
    const road = H * 0.74, wheelY = road + 14, cowGround = road + 6; // 輪子底、牛站的地方（都在路上）
    const q = (sel) => root.querySelector(sel), qa = (sel) => [...root.querySelectorAll(sel)];
    const back = q('.tk-back'), front = q('.tk-front'), side = q('.c-side'), fr = q('.c-front'), say = q('.cut-say');
    // 卡車的位置：tx 是車尾那一邊的左緣。0.1–0.85 倒車進來（往左，車尾在前）；2.75–3.45 往前開走（往右，車頭在前）
    const stopX = W - 4 - TK.w * TS;
    const inK = outCubic(seg(t, 0.1, 0.85)), outK = seg(t, 2.75, 3.45) ** 2.2;
    const tx = lerp(W + 30, stopX, inK) + outK * (W + 90 - stopX);
    const moving = (t > 0.1 && t < 0.85) || t > 2.75;
    const dip = 4 * Math.sin(Math.PI * seg(t, 1.66, 1.9));                    // 牛落在車斗上，車身沉一下
    const rev = t > 2.62 && t < 2.75 ? Math.sin((t - 2.62) * 90) * 1.2 : 0;   // 出發前抖一下
    const ty = wheelY - TK.h * TS + 6 * TS + (moving ? Math.sin(t * 30) * 1.2 : 0) + dip + rev;
    [back, front].forEach((el) => { el.style.transform = `translate(${tx}px, ${ty}px) scale(${TS})`; });
    // 輪子轉動（跟移動距離成正比）
    const ang = ((tx - stopX) / (TK.wheelR * TS)) * (180 / Math.PI);
    qa('.tk-wheel').forEach((g) => g.setAttribute('transform', `rotate(${ang} ${g.dataset.cx} ${g.dataset.cy})`));
    // 倒車燈和「嗶嗶」：倒車時一閃一閃
    const blink = t > 0.1 && t < 0.85 && Math.floor(t * 7) % 2 === 0;
    q('#tk-rev').setAttribute('fill', blink ? '#FFE27A' : '#FFF7D6');
    qa('.cut-beep').forEach((b, i) => { b.style.opacity = blink ? 1 : 0; b.style.transform = `translate(${tx - 26 + i * 22}px, ${ty + 14 - i * 20}px) rotate(${-10 + i * 8}deg)`; });
    // 擋板：0.9–1.12 放下來，1.72–1.92 關上
    const gate = q('#tk-gate'), open = inOut(seg(t, 0.9, 1.12)) - inOut(seg(t, 1.72, 1.92));
    gate.setAttribute('transform', `rotate(${-145 * open} ${gate.dataset.hx} ${gate.dataset.hy})`);
    // 牛：先在路邊等（側面、朝著卡車）；1.15–1.7 跳兩下上車斗；落地後轉成正面，之後跟著卡車
    const p = seg(t, 1.15, 1.7), onBoard = t >= 1.7;
    const sx0 = 14, bedX = tx + TK.bedCx * TS, bedY = ty + TK.floor * TS;
    const cxm = lerp(sx0 + 54, bedX, inOut(p));
    const cym = lerp(cowGround, bedY, p * p * (3 - 2 * p)) - Math.abs(Math.sin(Math.PI * 2 * p)) * 34;
    const idle = t < 1.15 ? Math.abs(Math.sin(t * 5)) * 3 : 0;
    const showFront = p >= 0.86;
    const sq = showFront ? 1 + 0.12 * Math.sin(Math.PI * seg(t, 1.62, 1.82)) : 1;  // 轉身時擠一下
    side.style.opacity = showFront ? 0 : 1; fr.style.opacity = showFront ? 1 : 0;
    side.style.transform = `translate(${cxm - 54}px, ${cym - 96 - idle}px)`;
    const wave = t > 2.0 && t < 2.75 ? Math.sin((t - 2.0) * 17) * 6 : 0;
    const fx = onBoard ? bedX : cxm, fy = onBoard ? bedY : cym;
    fr.style.transform = `translate(${fx - 50}px, ${fy - 100}px) rotate(${wave}deg) scale(${2 - sq}, ${sq})`;
    // 對話泡泡、愛心
    const sk = seg(t, 2.0, 2.15), sOut = seg(t, 2.95, 3.1);
    say.style.opacity = sk * (1 - sOut);
    say.style.transform = `translate(${Math.min(fx - 150, W - 172)}px, ${fy - 142}px) scale(${0.6 + 0.4 * outBack(sk)})`;
    qa('.cut-hearts i').forEach((h, i) => {
      const k = seg(t, 2.1 + i * 0.18, 2.9 + i * 0.18);
      h.style.opacity = k > 0 && k < 1 ? Math.sin(Math.PI * k) : 0;
      h.style.transform = `translate(${fx + 22 + i * 16 - 10}px, ${fy - 96 - k * 46 - i * 6}px) scale(${0.7 + 0.5 * k})`;
    });
    // 往前開走時，車尾揚起的煙
    qa('.cut-puffs i').forEach((pf, i) => {
      const k = seg(t, 2.78 + i * 0.13, 3.3 + i * 0.13);
      pf.style.opacity = k > 0 && k < 1 ? 0.95 * (1 - k) : 0;
      pf.style.transform = `translate(${tx - 22 - k * 34 - i * 4}px, ${wheelY - 30 - k * 22}px) scale(${0.45 + k * 0.9})`;
    });
    q('.cut-flash').style.opacity = seg(t, 3.38, 3.6);
  },
};

// ---------- 揭曉用的中央卡 ----------
function revealLayer(ctx, pageHTML, inner) {
  return pageHTML.replace('<div class="overlays">', `<div class="overlays"><div class="backdrop"></div><div class="reveal">${inner}</div>`);
}

// ---------- A-04 小牛出生 ----------
const A04 = {
  // v0.3（第 13 輪 02-A）：出生時還不知道品種，只看得出用途和公母；品種長大才揭曉（A-13）
  id: 'A-04', name: '小牛出生', dur: 1.5, where: 'S08 配種、S18 借種',
  keys: [[0, '配種成功，出現蓋著布的草窩'], [0.35, '布動來動去'], [0.6, '布飛走，露出小牛的剪影'], [0.9, '剪影變成彩色小牛（照用途的一般品種畫，母的有蝴蝶結）'], [1.2, '跳出名字（小乳牛 #16）、用途和公母'], [1.5, '結束，接著顯示小牛倒數卡']],
  reduced: '不播動畫：直接顯示小牛、名字、用途和公母（淡入 0.2 秒），再顯示小牛倒數卡。',
  base: (ctx) => revealLayer(ctx, frame(ctx.dev, { tab: 'breed', content: '<div></div>' }), `
    <div class="nest"><div class="calf-sil">${cowSVG({ breed: 'holstein', sex: 'cow', age: 'calf', seed: 91 }, { w: 170, h: 150, sil: 'dark' })}</div><div class="calf-col">${cowSVG({ breed: 'holstein', sex: 'cow', age: 'calf', seed: 91 }, { w: 170, h: 150 })}</div>
      <div class="hay"></div><div class="cloth">${icon('heart', 34)}</div></div>
    <div class="reveal-name"><b>${calfName('dairy', 16)}</b><div class="chips">${useChip('dairy')}<span class="use">${sexName('cow')}</span>${badge('calf', T('stageCalf'))}</div></div>
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
    <section class="lv-card card"><div class="lv-ribbon" data-free>${T('s11.ribbon')}</div><div class="lv-big"><span>${T('s11.lv')}</span><span class="lv-roll"><b class="num size" aria-hidden="true">5</b><b class="num old">4</b><b class="num new">5</b></span></div><p class="lv-sub">${T('s11.earned', { v: fmt(7500) })}</p><p class="hint" style="text-align:center">${T('s11.hint')}</p><div class="btn-row" style="margin-top:14px;width:100%">${btn(T('ok'), { kind: 'primary' })}</div></section></div>` }),
  frame(root, t) {
    const bd = root.querySelector('.backdrop'), card = root.querySelector('.lv-card');
    bd.style.opacity = seg(t, 0, 0.2);
    const k = seg(t, 0.05, 0.35);
    card.style.transform = `scale(${t < 0.05 ? 0.4 : 0.4 + 0.6 * outBack(k)})`; card.style.opacity = seg(t, 0.05, 0.15);
    const f = inOut(seg(t, 0.4, 0.65));
    root.querySelector('.hud .lv').textContent = f >= 0.5 ? 'Lv 5' : 'Lv 4';
    root.querySelector('.hud .xp i').style.width = f >= 0.5 ? '0%' : '100%';
    root.querySelector('.lv-roll .old').style.transform = `translateY(${-f * 90}px)`;
    root.querySelector('.lv-roll .old').style.visibility = f >= 1 ? 'hidden' : ''; // 翻完就藏起來（clip-path 已經切掉看不到，但量測會把它算成超出卡片）
    root.querySelector('.lv-roll .new').style.transform = `translateY(${(1 - f) * 90}px)`;
    // 彩紙從上面落下，最後停在 S11-01 的位置和角度（top = y%、rotate(r)，跟 s10.js 的 levelUp 一樣；2026-10-08 cow-app 量到以前停得比 S11-01 低約 100）
    [...root.querySelectorAll('.confetti i')].forEach((c, i) => {
      const d = seg(t, 0.35 + (i % 7) * 0.04, 1.3), y = (i * 53) % 46, r = (i * 29) % 90;
      c.style.top = `${y - 60 * (1 - d)}%`;
      c.style.opacity = t < 0.35 ? 0 : 1;
      c.style.transform = `rotate(${r + (1 - d) * 240}deg)`;
    });
  },
};

// ---------- A-06 發現新品種 ----------
const A06 = {
  // v0.3（第 13 輪 02-A）：長大揭曉（A-13）那一刻才算發現，卡片上是長大的樣子
  id: 'A-06', name: '發現新品種（揭曉）', dur: 1.5, where: '小牛長大揭曉（A-13）之後',
  keys: [[0, '「發現新品種！」卡片，先是剪影'], [0.4, '卡片翻面'], [0.75, '翻過來是彩色的新品種'], [1.1, '圖鑑數字 +1'], [1.5, '停住']],
  reduced: '不翻面：直接顯示彩色的品種卡和「已發現 11 / 24」（淡入 0.2 秒）。',
  base: (ctx) => revealLayer(ctx, frame(ctx.dev, { tab: 'breed', content: '<div></div>' }), `
    <div class="disc-title">${T('anim.newBreed')}</div>
    <div class="disc-card"><div class="disc-face back">${cowSVG({ breed: 'chocolate', seed: 93 }, { w: 150, h: 140, sil: 'dark' })}<b>？？？</b></div>
      <div class="disc-face front">${cowSVG({ breed: 'chocolate', seed: 93 }, { w: 150, h: 140 })}<b>${breedName('chocolate')}</b><div class="chips">${tierChip(2)}</div></div></div>
    <div class="disc-count">${icon('book', 22)}${T('anim.dexCount', { n: '<b class="num"><span class="c-old">10</span><span class="c-new">11</span></b>', total: 24 })}</div>
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

// ---------- A-13 小牛長大（揭曉品種；v0.3，第 13 輪 02-A） ----------
// 在牧場頁播：小牛（照用途的一般品種畫）發光、白光一閃，變成長大的樣子；名字換成品種名、跳出稀有度。第一次長出這個品種，接著 A-06
const A13 = {
  id: 'A-13', name: '小牛長大（揭曉品種）', dur: 1.6, where: 'S03 牧場（小牛長大的那一刻；不在 app 裡的話，下次打開牧場頁時一頭一頭播）',
  keys: [[0, '牧場頁變暗，中間是長大前的小牛（小乳牛 #16）'], [0.3, '小牛發光、一閃一閃'], [0.65, '白光一閃，變成長大的樣子'], [1.0, '名字換成品種名（娟珊 #16），跳出稀有度'], [1.6, '停住；第一次長出這個品種，接著 A-06 發現新品種']],
  reduced: '不播動畫：直接顯示長大的牛、品種名和稀有度（淡入 0.2 秒）；第一次長出這個品種，接著顯示「發現新品種」卡。',
  base: (ctx) => revealLayer(ctx, ranchPage(ctx), `
    <div class="disc-title gs-title">${T('anim.grownUp', { cow: calfName('dairy', 16) })}</div>
    <div class="grow-stage"><div class="gs-glow"></div><div class="gs-calf">${cowSVG({ breed: 'holstein', sex: 'cow', age: 'calf', seed: 91 }, { w: 170, h: 150 })}</div><div class="gs-adult">${cowSVG({ breed: 'jersey', sex: 'cow', seed: 91 }, { w: 200, h: 176 })}</div><div class="gs-flash"></div></div>
    <div class="reveal-name gs-name"><div class="gs-old"><b>${calfName('dairy', 16)}</b></div><div class="gs-new"><b>${cowName('jersey', 16)}</b><div class="chips">${useChip('dairy')}<span class="use">${sexName('cow')}</span>${tierChip(1)}</div></div></div>
    <div class="sparkles">${[0, 1, 2, 3, 4].map(() => `<i>${icon('sparkle', 24)}</i>`).join('')}</div>${skipHint(true)}`),
  frame(root, t) {
    const q = (s) => root.querySelector(s);
    q('.gs-title').style.opacity = seg(t, 0, 0.15);
    const glow = seg(t, 0.15, 0.65), pulse = 0.5 + 0.5 * Math.sin(glow * Math.PI * 5);
    q('.gs-glow').style.opacity = t < 0.15 ? 0 : t < 0.65 ? 0.35 + 0.5 * pulse * glow : 1 - seg(t, 0.85, 1.1);
    q('.gs-glow').style.transform = `translate(-50%, -50%) scale(${0.7 + 0.5 * glow})`;
    const fl = seg(t, 0.55, 0.7), fo = seg(t, 0.75, 1.0);
    q('.gs-flash').style.opacity = t < 0.75 ? fl : 1 - fo;
    q('.gs-flash').style.transform = `translate(-50%, -50%) scale(${0.3 + 1.1 * outCubic(fl)})`;
    const swapped = t >= 0.7;
    q('.gs-calf').style.opacity = swapped ? 0 : 1;
    q('.gs-calf').style.transform = `translateX(-50%) translateY(${-Math.abs(Math.sin(t * 18)) * 6 * seg(t, 0.15, 0.3) * (1 - seg(t, 0.55, 0.7))}px)`;
    q('.gs-adult').style.opacity = swapped ? 1 : 0;
    q('.gs-adult').style.transform = `translateX(-50%) scale(${0.8 + 0.2 * outBack(seg(t, 0.7, 1.0))})`;
    const nk = seg(t, 1.0, 1.25);
    q('.gs-old').style.opacity = 1 - seg(t, 0.95, 1.05); q('.gs-old').style.visibility = t >= 1.05 ? 'hidden' : 'visible';
    q('.gs-new').style.opacity = nk; q('.gs-new').style.transform = `scale(${0.7 + 0.3 * outBack(nk)})`;
    [...root.querySelectorAll('.sparkles i')].forEach((s, i) => {
      const k = seg(t, 0.75 + i * 0.05, 1.4);
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
    if (!L.children.length) L.innerHTML = Array.from({ length: 8 }, () => `<span class="fly">${icon('rice', 30)}</span>`).join('') + toast('ok', T('harvested', { kg: 177 }), { style: 'opacity:0' });
    const sc = root.querySelector('.field-scene'), cell = root.querySelectorAll('.kv3 .cell')[1], dst = rel(root, cell), src = rel(root, sc);
    const drain = inOut(seg(t, 0.15, 0.8));
    sc.innerHTML = fieldScene(ctx.dev.w - 30, FIELDS.map((f) => (f.cow ? { ...f, rice: f.rice * (1 - drain) + 0.001 } : f)));
    root.querySelectorAll('.field-card').forEach((c) => {
      const f = FIELDS.find((x) => c.textContent.includes(T('fieldName', { n: x.index + 1 }))); if (!f || !f.cow) return;
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
    cell.querySelector('.v').innerHTML = `${Math.round(184 + 177 * outCubic(seg(t, 0.5, 1.0)))} <small>${T('g.kg')}</small>`;
    const ts = L.querySelector('.toast'); ts.style.opacity = seg(t, 0.95, 1.15); ts.style.transform = `translateY(${(1 - outCubic(seg(t, 0.95, 1.15))) * 14}px)`;
  },
};

// ---------- A-09 商店抽牛開獎 ----------
const A09 = {
  id: 'A-09', name: '商店抽牛開獎（揭曉）', dur: 1.5, where: 'S19 商店抽牛',
  // v0.3（ceo 2026-10-03 定）：抽到的也是小牛、長大才揭曉品種（A-13）：只看得出用途和公母
  keys: [[0, '按下「A 級」：出現金色禮盒'], [0.3, '禮盒搖晃、發光'], [0.55, '蓋子彈開，光線放射'], [0.85, '小牛從盒子裡升起（剪影 → 彩色；照用途的一般品種畫）'], [1.15, '跳出名字（小耕牛 #17）、用途和公母'], [1.5, '接著顯示抽到的結果（S19-05）']],
  reduced: '不播動畫：直接顯示抽到的結果（S19-05）。',
  base: (ctx) => revealLayer(ctx, frame(ctx.dev, { tab: 'shop', content: '<div></div>' }), `
    <div class="rays"></div>
    <div class="gbox"><div class="gb-calf sil">${cowSVG({ breed: 'yellow', sex: 'cow', age: 'calf', seed: 97 }, { w: 150, h: 130, sil: 'dark' })}</div><div class="gb-calf col">${cowSVG({ breed: 'yellow', sex: 'cow', age: 'calf', seed: 97 }, { w: 150, h: 130 })}</div>
      <div class="gb-body"><span class="gb-grade">A</span></div><div class="gb-lid"></div></div>
    <div class="reveal-name"><b>${calfName('draft', 17)}</b><div class="chips">${useChip('draft')}<span class="use">${sexName('cow')}</span>${badge('calf', T('stageCalf'))}</div></div>${skipHint(true)}`),
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
    // 光線一條 20°（.burst 的 repeating-conic-gradient）：最後一格轉到 40°（整數條），停下來跟 S20-01 一樣（2026-10-09 cow-app 量到以前停在 30°，差半條）
    burst.style.transform = `scale(${0.4 + 0.6 * outCubic(seg(t, 0.9, 1.3))}) rotate(${(t / 1.5) * 40}deg)`;
    [...root.querySelectorAll('.gift-box')].forEach((b, i) => {
      const k = seg(t, 1.0 + i * 0.08, 1.3 + i * 0.08);
      b.style.opacity = k > 0 ? 1 : 0;
      b.style.transform = `translateY(${(1 - outBack(k)) * -80}px) rotate(${(i - 1) * 6}deg)`;
    });
    root.querySelectorAll('.r-line, .result-card .hint, .result-card .btn-row').forEach((e) => { e.style.opacity = seg(t, 1.2, 1.45); });
  },
};

// ---------- A-11 牛在牧場走動（使用者 2026-10-01：「牛在牧場要會動吧」） ----------
// 只移動整頭牛（位置、一搖一搖、轉身），不改定案的牛產生器。4 秒一輪、一直循環；每頭牛的節奏錯開。
// 每頭：往前走 1.4 秒 → 停 0.6 秒 → 轉身往回走 1.4 秒 → 停 0.6 秒，回到原位。小牛用跳的。
const WALK = { // 牛的編號 → [走多遠（場景座標）, 節奏錯開幾秒]
  14: [16, 0.2], 8: [12, 1.6], 3: [18, 0.9], 15: [26, 0.0], 7: [16, 2.6], 12: [16, 3.3], 5: [12, 1.1], 11: [18, 2.0],
};
function walkPose(t, dist, phase, T = 4, calf = false) {
  const u = (((t + phase) % T) + T) % T / T;
  let x, moving, back, k;
  if (u < 0.35) { k = u / 0.35; x = inOut(k) * dist; moving = true; back = false; }
  else if (u < 0.5) { x = dist; moving = false; back = false; k = 0; }
  else if (u < 0.85) { k = (u - 0.5) / 0.35; x = dist * (1 - inOut(k)); moving = true; back = true; }
  else { x = 0; moving = false; back = false; k = 0; }
  const steps = calf ? 5 : 4;
  const wave = moving ? Math.sin(k * Math.PI * steps) : 0;
  const bob = moving ? Math.abs(wave) * (calf ? 6 : 2.4) : 0;
  const tilt = moving ? wave * (calf ? 4 : 2.2) : 0;
  return { x, back, bob, tilt };
}
function walkFrame(root, t) {
  root.querySelectorAll('.herd-cow').forEach((g) => {
    const id = +g.dataset.cow, w = WALK[id];
    if (!w || g.dataset.pose !== 'side') return;
    const dir = g.dataset.facing === 'right' ? 1 : -1, cx = +g.dataset.x, cy = +g.dataset.y;
    const p = walkPose(t, w[0], w[1], 4, g.dataset.calf === '1');
    g.setAttribute('transform', `translate(${(dir * p.x).toFixed(2)} 0)`);
    // 往回走時以腳底中間為軸左右翻過來；走路時以腳底為軸左右搖、上下彈
    const flip = p.back ? -1 : 1;
    g.querySelector('.cow-body').setAttribute('transform', `translate(${cx} ${(cy - p.bob).toFixed(2)}) rotate(${(p.tilt * dir * flip).toFixed(2)}) scale(${flip} 1) translate(${-cx} ${-cy})`);
  });
}
const A11 = {
  id: 'A-11', name: '牛在牧場走動', dur: 4, loop: true, gifDpr: 2, where: 'S03 牧場（一直循環）',
  keys: [[0, '大家在草地上'], [0.8, '牛慢慢往前走，身體一搖一搖'], [1.6, '走一段就停下來；小牛用跳的'], [2.4, '轉身往回走'], [3.2, '每頭牛的節奏錯開，不會一起動'], [4, '回到原位，一直循環']],
  reduced: '牛站著不動（跟一般的牧場畫面一樣）；轉身、跳都不播。',
  base: (ctx) => ranchPage(ctx),
  frame(root, t) { walkFrame(root, t); },
};

// ---------- A-12 左右滑動牧場（使用者 2026-10-01：「畫面應該可以左右滑動」） ----------
// 示意手指拖動場景：場景兩個螢幕寬，上面的頂列、下面的奶桶和分頁列不動。放開手指後會滑一小段再停（慣性）。
const A12 = {
  id: 'A-12', name: '左右滑動牧場（示意）', dur: 3.2, gifDpr: 2, where: 'S03 牧場',
  keys: [[0, '牧場的左邊（穀倉）'], [0.7, '手指往左拖，場景跟著移動'], [1.25, '放開後滑一小段停下：牧場的右邊（池塘）'], [2.1, '手指往右拖'], [3.2, '回到左邊；下方的小滑塊跟著移動']],
  reduced: '手指拖多少就移多少；放開以後不滑行、不回彈。',
  base: (ctx) => ranchPage(ctx).replace('<div class="overlays">', `<div class="overlays"><div class="finger">${icon('hand', 40)}</div>`),
  frame(root, t, ctx) {
    const svg = root.querySelector('.scene > svg'), vb = svg.getAttribute('viewBox').split(' ').map(Number);
    if (!svg.dataset.x0) svg.dataset.x0 = vb[0];
    const x0 = +svg.dataset.x0, max = WIDE - 390;
    // 0.25–1.25 往右捲到底（手指往左拖），2.0–3.0 捲回來
    const k = outCubic(seg(t, 0.25, 1.25)) - outCubic(seg(t, 2.0, 3.0));
    const pan = max * k;
    svg.setAttribute('viewBox', [x0 + pan, vb[1], vb[2], vb[3]].join(' '));
    root.querySelector('.pan-ind i').style.left = `${(pan / max) * 50}%`;
    // 手指：按下 → 拖 → 放開（淡出）
    const f = root.querySelector('.finger'), W = ctx.dev.w, y = ctx.dev.h * 0.48;
    const drag1 = seg(t, 0.25, 0.95), drag2 = seg(t, 2.0, 2.7);
    let fx, op;
    if (t < 1.25) { fx = lerp(W * 0.72, W * 0.28, inOut(drag1)); op = t < 0.1 ? seg(t, 0, 0.1) : 1 - seg(t, 0.95, 1.15); }
    else { fx = lerp(W * 0.28, W * 0.72, inOut(drag2)); op = t < 2.0 ? seg(t, 1.8, 1.95) : 1 - seg(t, 2.7, 2.9); }
    f.style.opacity = op; f.style.transform = `translate(${fx - 20}px, ${y}px) scale(${(t > 0.2 && t < 0.95) || (t > 1.95 && t < 2.7) ? 0.92 : 1})`;
  },
};

// ---------- A-14、A-15 清大便（v0.3 第 5 節；第 13 輪 04-A） ----------
// 指著的手（指尖在 (13, 2)）
const POINTER = (s = 38) => `<svg viewBox="0 0 32 34" width="${s}" height="${Math.round(s * 34 / 32)}" aria-hidden="true"><path d="M11 4.4a2.3 2.3 0 0 1 4.6 0v9.8l1.2-.3a2.1 2.1 0 0 1 2.6 1.5l.1.5 1.1-.2a2.1 2.1 0 0 1 2.5 1.6l.1.5h.8a2.1 2.1 0 0 1 2.2 2.1v4.6c0 4.8-3.3 8.1-7.9 8.1h-1.5c-2.7 0-4.6-1.1-6.2-3.4l-4.8-6.7a2.1 2.1 0 0 1 3.1-2.8l2.1 2.3z" fill="#FFE3D2" stroke="#4B3326" stroke-width="2" stroke-linejoin="round"/><path d="M15.6 14.2v3.6M19.5 15.4v2.8M23.2 17.1v2" stroke="#4B3326" stroke-width="1.6" stroke-linecap="round"/></svg>`;
const POOPS_ALL = [0, 1, 2, 3, 4, 5, 6, 7, 8];
// 大便在手機畫面上的位置（場景座標換到畫面；頭尖往上一點，點的是大便的中間）
const poopAt = (ctx, i) => { const [x, y] = ranchScene(ctx.dev, HERD, { wide: true }).fit.map(POOP_SPOTS[i]); return [x, y - 8]; };
const poofHtml = (x, y, i) => `<div class="poof" data-i="${i}" style="left:${x}px;top:${y}px;opacity:0">${['16', '11', '9'].map((s) => `<i>${icon('sparkle', +s)}</i>`).join('')}</div>`;
function poofFrame(el, k) { el.style.opacity = k > 0 && k < 1 ? Math.sin(Math.PI * k) : 0; el.style.transform = `translateY(${-10 * k}px) scale(${0.7 + 0.5 * k})`; }
function poopFade(root, i, k) { const g = root.querySelector(`.poop[data-p="${i}"]`); if (g) g.style.opacity = 1 - k; }
function setCount(root, n, bump) { const el = root.querySelector('.dirty .dp-n'); el.textContent = n; root.querySelector('.dirty').style.transform = `scale(${1 + 0.1 * Math.sin(Math.PI * bump)})`; }
const A14 = {
  id: 'A-14', name: '清大便：點一下', dur: 0.9, where: 'S03 牧場（場景裡有大便）',
  keys: [[0, '牧場有 9 坨大便，右上角「大便 9」'], [0.25, '手指點一坨大便，冒出一圈波紋'], [0.45, '大便縮小不見，冒出小星星'], [0.6, '右上角變成「大便 8」'], [0.9, '停住']],
  reduced: '不播動畫：點到的大便直接消失，右上角的數字直接變少（沒有波紋和星星）。',
  base: (ctx) => {
    const [x, y] = poopAt(ctx, 0);
    return ranchPage(ctx, { poops: POOPS_ALL, overlays: `<div class="ripple" style="left:${x}px;top:${y}px;opacity:0"></div>${poofHtml(x, y, 0)}<div class="finger" style="left:${x - 13}px;top:${y - 2}px;opacity:0">${POINTER()}</div>` });
  },
  frame(root, t) {
    const f = root.querySelector('.finger');
    f.style.opacity = t < 0.5 ? seg(t, 0, 0.12) : 1 - seg(t, 0.5, 0.65);
    f.style.transform = `translateY(${t < 0.25 ? 14 * (1 - seg(t, 0, 0.25)) : 6 * seg(t, 0.4, 0.6)}px) scale(${t >= 0.22 && t < 0.32 ? 0.92 : 1})`;
    const rk = seg(t, 0.25, 0.55), rp = root.querySelector('.ripple');
    rp.style.opacity = rk > 0 && rk < 1 ? 1 - rk : 0; rp.style.transform = `scale(${0.4 + rk})`;
    poopFade(root, 0, seg(t, 0.3, 0.45));
    const g = root.querySelector('.poop[data-p="0"]'); if (g) g.style.transform = '';
    poofFrame(root.querySelector('.poof'), seg(t, 0.32, 0.72));
    setCount(root, t >= 0.55 ? 8 : 9, seg(t, 0.55, 0.7));
  },
};
// 劃過去：手指沿著一條線劃過三坨大便，經過的就清掉
const SWIPE = [1, 3, 4];
const A15 = {
  id: 'A-15', name: '清大便：手指劃過去', dur: 1.2, where: 'S03 牧場（場景裡有大便）',
  keys: [[0, '牧場有 9 坨大便'], [0.15, '手指按下，往右劃'], [0.45, '劃過的大便一坨一坨冒星星不見'], [0.85, '劃完，一共清掉 3 坨'], [1.2, '右上角「大便 6」']],
  reduced: '不播動畫：劃過的大便直接消失，右上角的數字直接變少（不畫劃過的線和星星）。',
  base: (ctx) => {
    const pts = SWIPE.map((i) => [...poopAt(ctx, i), i]).sort((a, b) => a[0] - b[0]);
    const start = [pts[0][0] - 34, pts[0][1] + 14], end = [pts[pts.length - 1][0] + 30, pts[pts.length - 1][1] - 12];
    const path = [start, ...pts.map(([x, y]) => [x, y]), end];
    const d = `M${path.map(([x, y]) => `${x.toFixed(1)} ${y.toFixed(1)}`).join('L')}`;
    return ranchPage(ctx, { poops: POOPS_ALL, overlays: `<svg class="swipe-trail" width="${ctx.dev.w}" height="${ctx.dev.h}" aria-hidden="true"><path class="st-glow" d="${d}" fill="none" stroke="#FFFFFF" stroke-width="16" stroke-linecap="round" stroke-linejoin="round" opacity="0"/></svg>
      ${pts.map(([x, y, i]) => poofHtml(x, y, i)).join('')}<div class="finger" data-path='${JSON.stringify(path.map(([x, y]) => [+x.toFixed(1), +y.toFixed(1)]))}' data-order='${JSON.stringify(pts.map((p) => p[2]))}' style="opacity:0">${POINTER()}</div>` });
  },
  frame(root, t) {
    const f = root.querySelector('.finger'), path = JSON.parse(f.dataset.path), order = JSON.parse(f.dataset.order);
    const seglen = path.slice(1).map((p, i) => Math.hypot(p[0] - path[i][0], p[1] - path[i][1])), total = seglen.reduce((a, b) => a + b, 0);
    const k = inOut(seg(t, 0.15, 0.85)), dist = k * total;
    let acc = 0, pos = path[0];
    for (let i = 0; i < seglen.length; i++) { if (dist <= acc + seglen[i]) { const u = (dist - acc) / seglen[i]; pos = [lerp(path[i][0], path[i + 1][0], u), lerp(path[i][1], path[i + 1][1], u)]; break; } acc += seglen[i]; pos = path[i + 1]; }
    f.style.opacity = t < 0.85 ? seg(t, 0.05, 0.15) : 1 - seg(t, 0.85, 1.0);
    f.style.transform = `translate(${pos[0] - 13}px, ${pos[1] - 2}px)`;
    // 手指劃過的地方留一道白色的軌跡，劃完慢慢淡掉
    const tr = root.querySelector('.st-glow');
    tr.style.strokeDasharray = `${total} ${total}`; tr.style.strokeDashoffset = `${total - dist}`;
    tr.style.opacity = t < 0.15 ? 0 : 0.75 * (1 - seg(t, 0.9, 1.15));
    let cleared = 0;
    order.forEach((pi, j) => {
      // 經過這一坨的時間（照路線上的距離）
      const at = seglen.slice(0, j + 1).reduce((a, b) => a + b, 0) / total, tk = 0.15 + 0.7 * at;
      poopFade(root, pi, seg(t, tk, tk + 0.1));
      poofFrame(root.querySelector(`.poof[data-i="${pi}"]`), seg(t, tk, tk + 0.35));
      if (t >= tk + 0.05) cleared++;
    });
    setCount(root, 9 - cleared, seg(t, 0.85, 1.0));
  },
};

// ---------- A-16、A-17 丟飼料（v0.3 第 2.2 節；使用者 2026-10-09～10 看第 23、26、29 輪，D35 補充 10、11） ----------
// 按住飼料列的一袋、拖到牧場地上放開。最近、現在能吃的那頭走過來吃，吃完頭上跳這次長了幾公斤（隨機）；沒有牛能吃，飼料飛回飼料列。
// 拖著的只有飼料本身（不要圓圈底），落地揚起一點灰塵；不畫遠近（第 26 輪）。
const FEED_K = 'corn';
const dropOverlays = (ctx, extra = '') => {
  const [dx, dy] = ranchScene(ctx.dev, HERD, { wide: true }).fit.map(FEED_DROP);
  return `<span class="drag-feed" style="left:0;top:0;opacity:0">${icon(`feed_${FEED_K}`, 36)}</span>
    <span class="ground-feed" data-x="${dx}" data-y="${dy}" style="left:${dx}px;top:${dy}px;opacity:0">${icon(`feed_${FEED_K}`, 30)}</span>
    <span class="dust" style="left:${dx}px;top:${dy}px"><i></i><i></i><i></i></span>${extra}<div class="finger" style="opacity:0">${POINTER()}</div>`;
};
const sackOf = (root) => root.querySelector(`.fb-item[data-feed="${FEED_K}"]`);
// 按住 → 拖出去 → 放開（0–1.3 秒，兩個動畫一樣）
function dragFrame(root, t) {
  const item = sackOf(root), s = rel(root, item.querySelector('.sack')), g = root.querySelector('.ground-feed');
  const a = { x: s.cx, y: s.cy }, b = { x: +g.dataset.x, y: +g.dataset.y - 14 };
  item.classList.toggle('lift', t >= 0.25 && t < 1.0);
  const k = inOut(seg(t, 0.35, 1.0)), p = arc(a, b, k, 60);
  const df = root.querySelector('.drag-feed');
  place(df, p.x, p.y, { o: t >= 0.35 && t < 1.02 ? 1 : 0 });
  const f = root.querySelector('.finger');
  f.style.opacity = t < 0.15 ? seg(t, 0, 0.15) : 1 - seg(t, 1.0, 1.2);
  const fp = t < 0.35 ? a : p;
  f.style.transform = `translate(${(fp.x + 4 - 13).toFixed(2)}px, ${(fp.y + 14 - 2).toFixed(2)}px) scale(${t >= 0.18 && t < 1.0 ? 0.92 : 1})`;
  const land = seg(t, 1.0, 1.15);
  g.style.opacity = land; g.style.transform = `translate(-50%, -100%) scale(${0.6 + 0.4 * outBack(land)})`;
  const dk = seg(t, 1.0, 1.5);
  root.querySelectorAll('.dust i').forEach((el, i) => { const dir = [-1, 1, -0.2][i]; el.style.opacity = dk > 0 && dk < 1 ? 0.9 * (1 - dk) : 0; el.style.transform = `translate(${dir * (6 + 14 * dk)}px, ${-4 - 6 * dk * (i === 2 ? 1.6 : 1)}px) scale(${0.8 + 0.8 * dk})`; });
  return { item, g, a };
}
function setStock(item, n, back = false) { item.querySelector('.sk-n').textContent = n; item.classList.toggle('back', back); }
const A16 = {
  id: 'A-16', name: '丟飼料：最近、肚子餓的牛走過來吃', dur: 4.6, where: 'S03 牧場（按住飼料列的一袋，拖到牧場地上放開）',
  keys: [[0, '肚子餓的牛頭上有空碗加問號（草莓牛、娟珊）'], [0.3, '按住玉米：袋子浮起來、轉一下'], [0.7, '拖到牧場的草地上（拖著的只有飼料本身）'], [1.15, '放開：飼料落地，揚起一點灰塵；玉米少一份'], [2.1, '最近、肚子餓的草莓牛走過來'], [3.1, '低頭吃，「嚼嚼」'], [3.7, '吃完：頭上的空碗不見，跳「+5.6 公斤」（每次隨機）'], [4.6, '停住']],
  reduced: '不播拖曳、走路的動畫：放開後飼料直接在地上，那頭牛直接出現在飼料旁邊，飼料不見；頭上的空碗消失，「+5.6 公斤」淡入 0.2 秒。',
  base: (ctx) => {
    const a = ranchScene(ctx.dev, FEED_HERD.map((h) => (h.id === 12 ? { ...h, ...EAT_AT } : h)), { wide: true }).anchors[12];
    const k = ranchScene(ctx.dev, HERD, { wide: true }).fit.k;
    return ranchPage(ctx, { herd: FEED_HERD, hungry: [12, 7], overlays: dropOverlays(ctx, `<span class="chew" style="left:${a.head[0] + 34}px;top:${a.head[1] + 30}px;opacity:0">${T('anim.chew')}</span><span class="kg-pop" data-k="${k}" style="left:${a.head[0] + 20}px;top:${a.head[1] - 8}px;opacity:0">${T('s03.kgGain', { kg: '5.6' })}</span>`) });
  },
  frame(root, t) {
    const { item, g } = dragFrame(root, t);
    setStock(item, t >= 0.35 ? 4 : 5);
    // 草莓牛（#12）走過去：整頭牛移動（場景座標），一搖一搖；頭上的空碗跟著走（畫面座標 × k）
    const cow = root.querySelector('.herd-cow[data-cow="12"]'), cx = +cow.dataset.x, cy = +cow.dataset.y;
    const w = seg(t, 1.4, 2.8), e = inOut(w), dx = (EAT_AT.x - cx) * e, dy = (EAT_AT.y - cy) * e;
    cow.setAttribute('transform', `translate(${dx.toFixed(2)} ${dy.toFixed(2)})`);
    const wave = w > 0 && w < 1 ? Math.sin(w * Math.PI * 6) : 0, eatK = seg(t, 2.85, 3.45);
    const nod = eatK > 0 && eatK < 1 ? Math.sin(eatK * Math.PI * 4) * 4 : 0;
    cow.querySelector('.cow-body').setAttribute('transform', `translate(${cx} ${(cy - Math.abs(wave) * 2.4).toFixed(2)}) rotate(${(wave * 2.2 + nod).toFixed(2)}) translate(${-cx} ${-cy})`);
    const kk = +root.querySelector('.kg-pop').dataset.k, hg = root.querySelectorAll('.hungry')[0];
    hg.style.transform = `translate(-50%, -100%) translate(${(dx * kk).toFixed(2)}px, ${(dy * kk).toFixed(2)}px)`;
    hg.style.opacity = 1 - seg(t, 3.4, 3.55);
    // 吃：地上的飼料越來越小；「嚼嚼」
    if (t >= 2.9) { const s2 = 1 - seg(t, 2.9, 3.4); g.style.transform = `translate(-50%, -100%) scale(${s2.toFixed(3)})`; g.style.opacity = s2 > 0.02 ? 1 : 0; }
    const ch = root.querySelector('.chew'); ch.style.opacity = t >= 2.85 && t < 3.5 ? 1 : 0; ch.style.transform = `rotate(-6deg) translateY(${-3 * Math.abs(Math.sin(t * 12))}px)`;
    // 吃完：頭上跳這次長了幾公斤，往上飄一點
    const kp = root.querySelector('.kg-pop'), ku = seg(t, 3.5, 3.65);
    kp.style.opacity = ku; kp.style.transform = `translate(-50%, -100%) translateY(${(-14 * seg(t, 3.5, 4.4)).toFixed(2)}px) scale(${(0.8 + 0.2 * outBack(ku)).toFixed(3)})`;
  },
};
const A17 = {
  id: 'A-17', name: '丟飼料：沒有牛能吃，飼料飛回去', dur: 3.4, where: 'S03 牧場（丟出去的時候，沒有一頭牛現在能吃）',
  keys: [[0, '牛都吃飽了（頭上沒有空碗）'], [0.6, '按住玉米拖到牧場上'], [1.15, '放開：飼料落地'], [2.1, '等一下沒有牛過來，飼料閃兩下'], [2.7, '飛回飼料列'], [3.1, '玉米的份數加回去（數字變綠一下），跳一行「現在沒有肚子餓的牛，飼料放回去了」'], [3.4, '停住']],
  reduced: '放開後飼料直接回到飼料列（份數不變、數字變綠一下），跳一行「現在沒有肚子餓的牛，飼料放回去了」。',
  base: (ctx) => ranchPage(ctx, { herd: FEED_HERD, overlays: dropOverlays(ctx, toast('info', T('s03.noHungry'), { style: 'opacity:0' })) }),
  frame(root, t) {
    const { item, g, a } = dragFrame(root, t);
    setStock(item, t >= 0.35 && t < 3.0 ? 4 : 5, t >= 3.0);
    if (t >= 2.0) {
      const blink = t < 2.4 ? (Math.sin((t - 2.0) * Math.PI * 10) > 0 ? 0.35 : 1) : 1;
      const k = inOut(seg(t, 2.4, 3.0)), b = { x: +g.dataset.x, y: +g.dataset.y - 14 }, p = arc(b, a, k, 90);
      g.style.opacity = t < 3.0 ? blink : 0;
      g.style.transform = t < 2.4 ? 'translate(-50%, -100%)' : `translate(${(p.x - b.x).toFixed(2)}px, ${(p.y - b.y).toFixed(2)}px) translate(-50%, -100%) scale(${(1 - 0.4 * k).toFixed(3)})`;
    }
    const ts = root.querySelector('.toast'); ts.style.opacity = seg(t, 3.0, 3.2);
  },
};

export const ANIMS = [A01, A02, A03, A04, A05, A06, A07, A08, A09, A10, A11, A12, A13, A14, A15, A16, A17];
