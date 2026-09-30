// 品種排排站：上半七頭放大（同一個比例，分三排），下半七頭剪影一排（塗黑，只看體型）。
import { LINEUP } from './data.js';
import { drawCow, extent, LABELS, SIL_DEFS } from './cows.js';

const v = new URLSearchParams(location.search).get('v') || 'a';
const app = document.getElementById('app');
const ext = LINEUP.map((e) => extent(v, e));
const W = (i) => ext[i].x1 - ext[i].x0, Hh = (i) => ext[i].y1 - ext[i].y0;
const maxH = Math.max(...LINEUP.map((e, i) => Hh(i)));
const INNER = 652; // 區塊內可用寬度（面板 720px）
const ROWS = [[0, 1, 2], [3, 4], [5, 6]];
const kW = Math.min(...ROWS.map((r) => (INNER - 24 * r.length) / r.reduce((a, i) => a + W(i), 0)));
const k = Math.min(kW, 158 / maxH);

const fig = (i, kk, sil, idp) => {
  const e = LINEUP[i], b = ext[i];
  const w = W(i) * kk + (sil ? 8 : 12), h = maxH * kk + 10;
  const cow = drawCow(v, e, { x: 6 - b.x0 * kk, y: h - 5, scale: kk, id: `${idp}${i}`, sil });
  const sh = sil ? '' : `<ellipse cx="${cow.shadow.cx}" cy="${h - 4}" rx="${cow.shadow.rx}" ry="${cow.shadow.ry}" fill="#9DD68A"/>`;
  return `<figure class="fig"><svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${sil ? `<defs>${SIL_DEFS}</defs>` : ''}${sh}${cow.svg}</svg><figcaption class="${sil ? 'sname' : 'name'}">${e.label}</figcaption></figure>`;
};
const rows = ROWS.map((r) => `<div class="row">${r.map((i) => fig(i, k, false, 'lu')).join('')}</div>`).join('');
const ks = Math.min((INNER - 16 * 7) / LINEUP.reduce((a, e, i) => a + W(i), 0), 110 / maxH);
const sils = `<div class="row sil">${LINEUP.map((e, i) => fig(i, ks, true, 'si')).join('')}</div>`;

app.innerHTML = `<div class="panel">
  <section class="sec grow"><div class="sec-head"><span class="sec-title">品種排排站</span><span class="sec-sub">${LABELS[v]}・七頭同一比例</span></div>${rows}</section>
  <section class="sec"><div class="sec-head"><span class="sec-title">剪影</span><span class="sec-sub">全部塗黑、同一比例，只看體型</span></div>${sils}</section>
</div>`;
await document.fonts.ready;
window.__ready = true;
