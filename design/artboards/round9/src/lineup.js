// 品種排排站（一個角度一塊面板）：?v=組合&view=side|front。上面九頭同一比例（分三排），下面九頭剪影（塗黑，只看體型）。
import { SIDE_LINEUP, FRONT_LINEUP } from './data.js';
import { drawCow, extent, LABELS, SIL_DEFS } from './cows.js';

const app = document.getElementById('app');
const q = new URLSearchParams(location.search);
const v = q.get('v') || 'r9';
const view = q.get('view') || 'side';
const LINE = view === 'side' ? SIDE_LINEUP : FRONT_LINEUP;
// 兩塊面板用同一個比例：外框取兩個角度的最大值
const extAll = [...SIDE_LINEUP, ...FRONT_LINEUP].map((e) => extent(v, e));
const ext = LINE.map((e) => extent(v, e));
const W = (i) => ext[i].x1 - ext[i].x0;
const maxH = Math.max(...extAll.map((e) => e.y1 - e.y0));
const INNER = 652;
const ROWS = [[0, 1, 2], [3, 4, 5], [6, 7, 8]];
const Wall = (i) => extAll[i].x1 - extAll[i].x0;
const rowsAll = [...ROWS, ...ROWS.map((r) => r.map((i) => i + 9))];
const kW = Math.min(...rowsAll.map((r) => (INNER - 24 * r.length) / r.reduce((a, i) => a + Wall(i), 0)));
const k = Math.min(kW, 150 / maxH);

const fig = (i, kk, sil, idp) => {
  const e = LINE[i], b = ext[i];
  const w = W(i) * kk + (sil ? 8 : 12), h = maxH * kk + 10;
  const cow = drawCow(v, e, { x: 6 - b.x0 * kk, y: h - 5, scale: kk, id: `${idp}${i}`, sil });
  const sh = sil ? '' : `<ellipse cx="${cow.shadow.cx}" cy="${h - 4}" rx="${cow.shadow.rx}" ry="${cow.shadow.ry}" fill="#9DD68A"/>`;
  return `<figure class="fig"><svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${sil ? `<defs>${SIL_DEFS}</defs>` : ''}${sh}${cow.svg}</svg><figcaption class="${sil ? 'sname' : 'name'}">${e.label}</figcaption></figure>`;
};
const rows = ROWS.map((r) => `<div class="row">${r.map((i) => fig(i, k, false, `lu${view}`)).join('')}</div>`).join('');
const ks = Math.min((INNER - 14 * LINE.length) / LINE.reduce((a, e, i) => a + W(i), 0), 90 / maxH);
const sils = `<div class="row sil">${LINE.map((e, i) => fig(i, ks, true, `si${view}`)).join('')}</div>`;
const title = view === 'side' ? '側面（牧場上平常走路的樣子，照 9966）' : '正面（停下來、被點到、奶桶滿了，照 9967）';

app.innerHTML = `<div class="panel">
  <section class="sec grow"><div class="sec-head"><span class="sec-title">${title}</span></div><div class="sec-sub2">${LABELS[v]}・九頭同一比例（兩塊面板也同一比例）</div>${rows}</section>
  <section class="sec"><div class="sec-head"><span class="sec-title">剪影</span><span class="sec-sub">塗黑、同一比例，只看體型</span></div>${sils}</section>
</div>`;
const hgt = (e) => drawCow(v, e, { scale: 1 }).height;
window.__meta = { view, calfRatio: Math.round((hgt(LINE[2]) / hgt(LINE[0])) * 1000) / 1000 };
await document.fonts.ready;
window.__ready = true;
