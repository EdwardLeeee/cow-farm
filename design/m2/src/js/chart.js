// 行情圖：折線（R1-A 小走勢圖的畫法放大）、K 線與全服成交量。台灣慣例漲紅跌綠。
import { smoothPath } from '../cow/r1/cowgen.js';

const UP = '#E5484D', DOWN = '#1E9A5A', INK = '#4B3326', GRID = '#EADCC8', MUTED = '#8A6F60';
const f = (v) => Math.round(v * 10) / 10;
const lbl = (x, y, t, anchor = 'start') => `<text x="${f(x)}" y="${f(y)}" font-family="Noto Sans CJK TC" font-size="12" font-weight="700" fill="${MUTED}" text-anchor="${anchor}">${t}</text>`;

function yScale(min, max, top, h) {
  const pad = (max - min) * 0.12 || 0.1;
  const lo = min - pad, hi = max + pad;
  return { lo, hi, y: (v) => top + (1 - (v - lo) / (hi - lo)) * h };
}
const dec = (v) => (v < 10 ? v.toFixed(2) : v.toFixed(1));

// series：價格陣列；xLabels：[左, 中, 右]；avg：24 小時均價（虛線）
export function lineChart(series, { w = 340, h = 170, xLabels = ['', '', '現在'], avg = null } = {}) {
  const padL = 4, padR = 40, top = 10, ch = h - 34;
  const min = Math.min(...series), max = Math.max(...series);
  const S = yScale(min, max, top, ch);
  const dir = series[series.length - 1] >= series[0] ? 'up' : 'down';
  const c = dir === 'up' ? UP : DOWN;
  const pts = series.map((v, i) => [padL + (i / (series.length - 1)) * (w - padL - padR), S.y(v)]);
  const line = smoothPath(pts, false);
  const area = `${line}L${f(pts[pts.length - 1][0])},${top + ch}L${f(pts[0][0])},${top + ch}Z`;
  const e = pts[pts.length - 1];
  const grid = [0, 0.5, 1].map((k) => { const v = S.lo + (S.hi - S.lo) * (1 - k); const y = top + k * ch; return `<path d="M${padL},${f(y)}H${w - padR + 4}" stroke="${GRID}" stroke-width="1.5"/>${lbl(w - padR + 8, y + 4, dec(v))}`; }).join('');
  const avgLine = avg ? `<path d="M${padL},${f(S.y(avg))}H${w - padR}" stroke="${MUTED}" stroke-width="1.6" stroke-dasharray="4 4"/>` : '';
  const xl = xLabels.map((t, i) => lbl(padL + (i / 2) * (w - padL - padR), h - 6, t, i === 0 ? 'start' : i === 1 ? 'middle' : 'end')).join('');
  return `<svg viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" class="chart" aria-hidden="true">${grid}${avgLine}<path d="${area}" fill="${c}" opacity="0.13"/><path d="${line}" fill="none" stroke="${c}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/><circle cx="${f(e[0])}" cy="${f(e[1])}" r="5" fill="#FFFFFF" stroke="${c}" stroke-width="3"/>${xl}</svg>`;
}

// candles：[{o,c,hi,lo,vol}]；下方 40px 畫全服成交量
export function candleChart(candles, { w = 340, h = 210, xLabels = ['', '', '現在'] } = {}) {
  const padL = 4, padR = 40, top = 10, ch = h - 34 - 48, vTop = top + ch + 8, vh = 36;
  const min = Math.min(...candles.map((k) => k.lo)), max = Math.max(...candles.map((k) => k.hi));
  const S = yScale(min, max, top, ch);
  const n = candles.length, step = (w - padL - padR) / n, bw = Math.max(3, step * 0.62);
  const vmax = Math.max(...candles.map((k) => k.vol));
  const grid = [0, 0.5, 1].map((k) => { const v = S.lo + (S.hi - S.lo) * (1 - k); const y = top + k * ch; return `<path d="M${padL},${f(y)}H${w - padR + 4}" stroke="${GRID}" stroke-width="1.5"/>${lbl(w - padR + 8, y + 4, dec(v))}`; }).join('');
  const body = candles.map((k, i) => {
    const x = padL + step * i + step / 2, up = k.c >= k.o, c = up ? UP : DOWN;
    const y1 = S.y(Math.max(k.o, k.c)), y2 = S.y(Math.min(k.o, k.c));
    const vy = vTop + vh - (k.vol / vmax) * vh;
    return `<path d="M${f(x)},${f(S.y(k.hi))}V${f(S.y(k.lo))}" stroke="${c}" stroke-width="1.6"/><rect x="${f(x - bw / 2)}" y="${f(y1)}" width="${f(bw)}" height="${f(Math.max(1.6, y2 - y1))}" rx="1" fill="${up ? c : c}" stroke="${c}" stroke-width="1"/>
      <rect x="${f(x - bw / 2)}" y="${f(vy)}" width="${f(bw)}" height="${f(vTop + vh - vy)}" fill="${up ? '#F4A7A9' : '#9ED6B8'}"/>`;
  }).join('');
  const volLbl = lbl(w - padR + 8, vTop + 12, '量');
  const xl = xLabels.map((t, i) => lbl(padL + (i / 2) * (w - padL - padR), h - 6, t, i === 0 ? 'start' : i === 1 ? 'middle' : 'end')).join('');
  return `<svg viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" class="chart" aria-hidden="true">${grid}<path d="M${padL},${vTop + vh}H${w - padR}" stroke="${GRID}" stroke-width="1.5"/>${body}${volLbl}${xl}</svg>`;
}

// 全服成交量（折線模式下，圖下方一排小柱）
export function volumeBars(vols, { w = 340, h = 40 } = {}) {
  const padL = 4, padR = 40, n = vols.length, step = (w - padL - padR) / n, vmax = Math.max(...vols);
  return `<svg viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" class="chart" aria-hidden="true">${vols.map((v, i) => { const bh = (v / vmax) * (h - 6); return `<rect x="${f(padL + step * i + step * 0.2)}" y="${f(h - bh)}" width="${f(step * 0.6)}" height="${f(bh)}" rx="1" fill="#C9B8A6"/>`; }).join('')}${lbl(w - padR + 8, h - 4, '量')}</svg>`;
}
