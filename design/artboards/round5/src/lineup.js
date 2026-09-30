// 品種排排站：上面九頭正面（同一個比例，分三排），中間四頭側面走路（D11），下面九頭正面剪影（塗黑，只看體型）。
import { LINEUP, SIDE_LINEUP } from './data.js';
import { drawCow, extent, LABELS, SIL_DEFS } from './cows.js';

const v = new URLSearchParams(location.search).get('v') || 'a';
const app = document.getElementById('app');
const ALL = [...LINEUP, ...SIDE_LINEUP];
const ext = ALL.map((e) => extent(v, e));
const W = (i) => ext[i].x1 - ext[i].x0, Hh = (i) => ext[i].y1 - ext[i].y0;
const maxH = Math.max(...ALL.map((e, i) => Hh(i)));
const INNER = 652; // 區塊內可用寬度（面板 720px）
const ROWS = [[0, 1, 2], [3, 4, 5], [6, 7, 8]];
const SIDE = [[9, 10, 11, 12]];
const kW = Math.min(...[...ROWS, ...SIDE].map((r) => (INNER - 20 * r.length) / r.reduce((a, i) => a + W(i), 0)));
const k = Math.min(kW, 146 / maxH);

const fig = (i, kk, sil, idp) => {
  const e = ALL[i], b = ext[i];
  const w = W(i) * kk + (sil ? 8 : 12), h = maxH * kk + 10;
  const cow = drawCow(v, e, { x: 6 - b.x0 * kk, y: h - 5, scale: kk, id: `${idp}${i}`, sil });
  const sh = sil ? '' : `<ellipse cx="${cow.shadow.cx}" cy="${h - 4}" rx="${cow.shadow.rx}" ry="${cow.shadow.ry}" fill="#9DD68A"/>`;
  return `<figure class="fig"><svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${sil ? `<defs>${SIL_DEFS}</defs>` : ''}${sh}${cow.svg}</svg><figcaption class="${sil ? 'sname' : 'name'}">${e.label}</figcaption></figure>`;
};
const rows = ROWS.map((r) => `<div class="row">${r.map((i) => fig(i, k, false, 'lu')).join('')}</div>`).join('');
const siderow = SIDE.map((r) => `<div class="row">${r.map((i) => fig(i, k, false, 'sd')).join('')}</div>`).join('');
const ks = Math.min((INNER - 14 * LINEUP.length) / LINEUP.reduce((a, e, i) => a + W(i), 0), 90 / maxH);
const sils = `<div class="row sil">${LINEUP.map((e, i) => fig(i, ks, true, 'si')).join('')}</div>`;

app.innerHTML = `<div class="panel">
  <section class="sec grow"><div class="sec-head"><span class="sec-title">品種排排站・正面</span><span class="sec-sub">${LABELS[v]}・九頭同一比例・停下來或被點到時的樣子</span></div>${rows}</section>
  <section class="sec"><div class="sec-head"><span class="sec-title">側面走路</span><span class="sec-sub">牧場上平常的樣子・同一比例</span></div>${siderow}</section>
  <section class="sec"><div class="sec-head"><span class="sec-title">剪影</span><span class="sec-sub">正面九頭塗黑、同一比例，只看體型</span></div>${sils}</section>
</div>`;
// 量測：小牛身高 ÷ 成年荷斯坦身高（同一個比例，含角）
const hgt = (e) => drawCow(v, e, { scale: 1 }).height;
window.__meta = { calfRatio: Math.round((hgt(LINEUP[2]) / hgt(LINEUP[0])) * 1000) / 1000, calfRatioSide: Math.round((hgt(SIDE_LINEUP[3]) / hgt(SIDE_LINEUP[0])) * 1000) / 1000 };
await document.fonts.ready;
window.__ready = true;
