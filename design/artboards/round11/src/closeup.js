// 特寫面板：?mode=udder（項目 01：母乳牛正面放大，看粉紅圓乳房＋牧場上的實際大小）
//           ?mode=v02（項目 02：新的耕牛放大＋和牛與安格斯在牧場上的大小）
//           ?mode=dark（和牛與安格斯，第 10 輪用過）
import { drawCow, extent, VARIANTS } from './cows.js';

const q = new URLSearchParams(location.search);
const v = q.get('v') || 'r11';
const mode = q.get('mode') || 'dark';
const app = document.getElementById('app');

const SETS = {
  dark: {
    rows: [
      { title: '和牛與安格斯・側面（放大）', cows: [{ breed: 'angus', pose: 'side', label: '安格斯' }, { breed: 'wagyu', pose: 'side', label: '和牛' }] },
      { title: '和牛與安格斯・正面（放大）', cows: [{ breed: 'angus', pose: 'front', label: '安格斯' }, { breed: 'wagyu', pose: 'front', label: '和牛' }] },
    ],
    small: [{ breed: 'angus', pose: 'side', label: '安格斯・側面' }, { breed: 'wagyu', pose: 'side', label: '和牛・側面' }, { breed: 'angus', pose: 'front', label: '安格斯・正面' }, { breed: 'wagyu', pose: 'front', label: '和牛・正面' }],
  },
  udder: {
    rows: [
      { title: '母乳牛正面・乳房特寫（放大）', cows: [{ breed: 'holstein', pose: 'front', label: '荷斯坦' }, { breed: 'jersey', pose: 'front', label: '娟珊' }] },
      { title: '母乳牛正面・乳房特寫（放大）', cows: [{ breed: 'chocolate', pose: 'front', label: '巧克力牛' }, { breed: 'strawberry', pose: 'front', label: '草莓牛' }] },
    ],
    small: [{ breed: 'holstein', pose: 'front', label: '荷斯坦' }, { breed: 'jersey', pose: 'front', label: '娟珊' }, { breed: 'chocolate', pose: 'front', label: '巧克力牛' }, { breed: 'strawberry', pose: 'front', label: '草莓牛' }],
  },
  v02: {
    rows: [
      { title: '新的耕牛・側面（放大）', cows: [{ breed: 'yellow', pose: 'side', label: '台灣黃牛' }, { breed: 'buffalo', pose: 'side', label: '台灣水牛' }] },
      { title: '新的耕牛・正面（放大）', cows: [{ breed: 'yellow', pose: 'front', label: '台灣黃牛' }, { breed: 'buffalo', pose: 'front', label: '台灣水牛' }] },
    ],
    smallTitle: '和牛（黑亮加短角）與安格斯（炭灰）・牧場上的大小',
    small: [{ breed: 'angus', pose: 'side', label: '安格斯・側面' }, { breed: 'wagyu', pose: 'side', label: '和牛・側面' }, { breed: 'angus', pose: 'front', label: '安格斯・正面' }, { breed: 'wagyu', pose: 'front', label: '和牛・正面' }],
  },
};
const S = SETS[mode];
const big = S.rows.flatMap((r) => r.cows);
const extB = big.map((e) => extent(v, e));
const maxH = Math.max(...extB.map((b) => b.y1 - b.y0));
const k = Math.min(290 / Math.max(...extB.map((b) => b.x1 - b.x0)), 215 / maxH);

const fig = (e, kk, id, label, mh) => {
  const b = extent(v, e);
  const w = (b.x1 - b.x0) * kk + 12, h = mh * kk + 10;
  const cow = drawCow(v, e, { x: 6 - b.x0 * kk, y: h - 5, scale: kk, id });
  return `<figure class="fig"><svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><ellipse cx="${cow.shadow.cx}" cy="${h - 4}" rx="${cow.shadow.rx}" ry="${cow.shadow.ry}" fill="#9DD68A"/>${cow.svg}</svg><figcaption class="name">${label ?? e.label}</figcaption></figure>`;
};
// 牧場上的大小：和牧場主畫面同一個比例（中間那排的深度）
const ks = VARIANTS[v].scene * 0.9;
const maxS = Math.max(...S.small.map((e) => { const b = extent(v, e); return b.y1 - b.y0; }));
const small = S.small.map((e, i) => fig(e, ks, `sm${i}`, e.label, maxS)).join('');
const rows = S.rows.map((r, ri) => `<section class="sec grow"><div class="sec-head"><span class="sec-title">${r.title}</span></div>${ri === 0 ? `<div class="sec-sub2">${VARIANTS[v].name}</div>` : ''}<div class="row">${r.cows.map((e, i) => fig(e, k, `b${ri}${i}`, undefined, maxH)).join('')}</div></section>`).join('');

app.innerHTML = `<div class="panel panel-closeup">${rows}
  <section class="sec"><div class="sec-head"><span class="sec-title">${S.smallTitle || '牧場上的實際大小'}</span><span class="sec-sub">${mode === 'udder' ? '牧場上看得到的樣子' : '看一眼分不分得出來'}</span></div><div class="row">${small}</div></section>
</div>`;
window.__meta = { view: `closeup-${mode}` };
await document.fonts.ready;
window.__ready = true;
