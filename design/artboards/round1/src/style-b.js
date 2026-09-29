// 風格 B「像素風」：1 美術像素 = 3 CSS px。場景、圖示、數字都畫在低解析度 canvas 上，
// 再用 image-rendering: pixelated 放大 3 倍。牛由 cowgen.js → cowgen-b.js 點陣化。
import { BREEDS, genesFor } from './data.js';
import { buildCow, rng } from './cowgen.js';
import { spriteB, PX } from './cowgen-b.js';

export const name = 'b';
const AW = 130, AH = 282; // 場景美術像素尺寸（390×846 CSS px）

// ---------- 像素小工具 ----------
function makeCanvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  return c;
}
function toImg(canvas, cls = '', extra = '') {
  return `<img class="px-img ${cls}" src="${canvas.toDataURL()}" width="${canvas.width * PX}" height="${canvas.height * PX}" alt="" ${extra}>`;
}
const PAL = {
  o: '#2B1D2E', w: '#FFFFFF', c: '#FFF1D0', C: '#F2D9A8', y: '#FFD23F', Y: '#FFEC8A', d: '#D9962B',
  r: '#E0414B', R: '#FF7A7A', D: '#A8313C', p: '#FF8FAB', P: '#FFC4D3', q: '#D9537A',
  b: '#4E9BE0', B: '#A9DBFF', g: '#58B85A', G: '#9BE07A', v: '#2F7A3E', n: '#C27A45', N: '#E6A96A', k: '#7A4428',
  l: '#D6E6F2', s: '#9FB4C8', m: '#FFFFFF', e: '#CFE3F2',
};
function stamp(rows, pal = PAL) {
  const h = rows.length, w = rows[0].length;
  rows.forEach((r, i) => { if (r.length !== w) throw new Error(`stamp row ${i} width ${r.length} != ${w}: ${r}`); });
  const c = makeCanvas(w, h), ctx = c.getContext('2d');
  rows.forEach((r, y) => [...r].forEach((ch, x) => {
    if (ch === '.') return;
    ctx.fillStyle = pal[ch] || ch; ctx.fillRect(x, y, 1, 1);
  }));
  return c;
}

// ---------- 像素字（自己畫的 3×5 與 5×7 數字字形） ----------
const F3 = {
  0: ['###', '#.#', '#.#', '#.#', '###'], 1: ['.#.', '##.', '.#.', '.#.', '###'], 2: ['###', '..#', '###', '#..', '###'],
  3: ['###', '..#', '.##', '..#', '###'], 4: ['#.#', '#.#', '###', '..#', '..#'], 5: ['###', '#..', '###', '..#', '###'],
  6: ['###', '#..', '###', '#.#', '###'], 7: ['###', '..#', '..#', '.#.', '.#.'], 8: ['###', '#.#', '###', '#.#', '###'],
  9: ['###', '#.#', '###', '..#', '###'], '.': ['.', '.', '.', '.', '#'], ',': ['.', '.', '.', '#', '#'],
  '%': ['##..#', '##.#.', '..#..', '.#.##', '#..##'], '/': ['..#', '..#', '.#.', '#..', '#..'], L: ['#..', '#..', '#..', '#..', '###'],
  v: ['...', '...', '#.#', '#.#', '.#.'], '▲': ['.....', '..#..', '.###.', '#####', '.....'], '▼': ['.....', '#####', '.###.', '..#..', '.....'],
  ' ': ['..', '..', '..', '..', '..'],
};
const F5 = {
  0: ['.###.', '#...#', '#..##', '#.#.#', '##..#', '#...#', '.###.'], 1: ['..#..', '.##..', '#.#..', '..#..', '..#..', '..#..', '#####'],
  2: ['.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####'], 3: ['####.', '....#', '....#', '.###.', '....#', '....#', '####.'],
  4: ['...#.', '..##.', '.#.#.', '#..#.', '#####', '...#.', '...#.'], 5: ['#####', '#....', '####.', '....#', '....#', '#...#', '.###.'],
  6: ['.###.', '#....', '#....', '####.', '#...#', '#...#', '.###.'], 7: ['#####', '....#', '...#.', '..#..', '.#...', '.#...', '.#...'],
  8: ['.###.', '#...#', '#...#', '.###.', '#...#', '#...#', '.###.'], 9: ['.###.', '#...#', '#...#', '.####', '....#', '....#', '.###.'],
  '.': ['..', '..', '..', '..', '..', '##', '##'], ',': ['..', '..', '..', '..', '..', '.#', '#.'],
  '%': ['##...', '##..#', '...#.', '..#..', '.#...', '#..##', '...##'], ' ': ['...', '...', '...', '...', '...', '...', '...'],
};
function pxText(text, { big = false, color = '#2B1D2E', shadow = null } = {}) {
  const F = big ? F5 : F3, gh = big ? 7 : 5;
  const glyphs = [...text].map((ch) => F[ch] || F[' ']);
  const w = glyphs.reduce((a, g) => a + g[0].length, 0) + glyphs.length - 1 + (shadow ? 1 : 0);
  const c = makeCanvas(Math.max(1, w), gh + (shadow ? 1 : 0)), ctx = c.getContext('2d');
  const draw = (ox, oy, col) => {
    let x = ox;
    ctx.fillStyle = col;
    glyphs.forEach((g) => {
      g.forEach((row, yy) => [...row].forEach((ch, xx) => { if (ch === '#') ctx.fillRect(x + xx, oy + yy, 1, 1); }));
      x += g[0].length + 1;
    });
  };
  if (shadow) draw(1, 1, shadow);
  draw(0, 0, color);
  return c;
}

// ---------- 圖示 ----------
const ICON_ROWS = {
  news: ['......oo...', '....ooRRo..', '.ooorRRRo.o', 'owwwrRRRo..', 'owwwrRRRo.o', '.ooorRRRo..', '....ooRRo.o', '......oo...'],
  bottle: ['..oooo..', '..obbo..', '..oooo..', '..owwo..', '.owwwlo.', 'owwwwwlo', 'owBBBBlo', 'owBwwBlo', 'owBBBBlo', 'owwwwwlo', 'owwwwwlo', '.oooooo.'],
  crate: ['.ooooooooo.', 'oNNNNNNNNNo', 'ooooooooooo', 'onnnpppnnno', 'onnpPPppnno', 'onnppppPnno', 'onnnpppnnno', 'okkkkkkkkko', 'onnnnnnnnno', '.ooooooooo.'],
  'bottle-sm': ['.oooo.', '.obbo.', '.owwo.', 'owwwlo', 'owBBlo', 'owBBlo', 'owwwlo', 'owwwlo', '.oooo.'],
  'crate-sm': ['.oooooo.', 'oNNNNNNo', 'oooooooo', 'onnppnno', 'onpPppno', 'okkkkkko', '.oooooo.'],
  leaf: ['...oooo', '..oGGgo', '.oGGgvo', 'oGGgvgo', 'oGgvgo.', 'ogvoo..', 'oo.....'],
  bubble: ['..ooooo..', '.o.....o.', 'ooooooooo', 'olmmmmmlo', '.olmmmlo.', '.olllllo.', '.ossssso.', '..ooooo..'],
  'tab-ranch': ['....ooo....', '...oDDDo...', '..oDDyDDo..', '.oDDDDDDDo.', 'ooooooooooo', '.orrwwwrro.', '.orrwDwrro.', '.orrwDwrro.', '.orrwDwrro.', '.orrwwwrro.', '.ooooooooo.'],
  'tab-market': ['ooooooooooo', 'occcccccRco', 'occcccRRcco', 'occRccRcccO'.replace('O', 'o'), 'ocRcRRccccO'.replace('O', 'o'), 'oRcccccccco', 'occcccccccO'.replace('O', 'o'), 'ooooooooooo', '....ono....', '...ooooo...', '...........'],
  'tab-breed': ['..ooo.ooo..', '.oPPpopppo.', 'oPPpppppppo', 'oPppppppppo', 'oppppppppqo', '.oppppppqo.', '..oppppqo..', '...oppqo...', '....oqo....', '.....o.....', '...........'],
  'tab-dex': ['.oooooooooo', 'obwwwwwwwwo', 'obwoowwwwwo', 'obwooowwwwo', 'obwwowwoowo', 'obwwwwwoowo', 'obwwwwwwwwo', 'obwwwwwwwwo', 'obBBBBBBBBo', 'obllllllllo', '.oooooooooo'],
  'tab-rank': ['..ooooooo..', 'oooYyyydooo', 'o.oYyyydo.o', 'o.oYyyydo.o', '.ooYyyydoo.', '...oyyyo...', '....oyo....', '....odo....', '...ooooo...', '..onNNNno..', '..ooooooo..'],
};
const iconCache = {};
function iconCanvas(name) {
  if (!iconCache[name]) iconCache[name] = stamp(ICON_ROWS[name]);
  return iconCache[name];
}
function coinCanvas() {
  const S = 13, c = makeCanvas(S, S), ctx = c.getContext('2d');
  const r = 6.3, cx = 6.5, cy = 6.5;
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const d = Math.hypot(x + 0.5 - cx, y + 0.5 - cy);
    if (d > r) continue;
    let col = PAL.y;
    if (d > r - 1.1) col = PAL.o;
    else if (x + y < 9 && d > r - 2.3) col = PAL.Y;
    else if (x + y > 15 && d > r - 2.3) col = PAL.d;
    ctx.fillStyle = col; ctx.fillRect(x, y, 1, 1);
  }
  const bell = ['..d..', '.ddd.', '.ddd.', 'ddddd', '..d..'];
  bell.forEach((row, y) => [...row].forEach((ch, x) => { if (ch === 'd') { ctx.fillStyle = PAL.d; ctx.fillRect(4 + x, 4 + y, 1, 1); } }));
  ctx.fillStyle = PAL.w; ctx.fillRect(3, 3, 1, 1);
  return c;
}

export function icon(name, opts = {}) {
  if (name === 'up' || name === 'down') return '';
  if (name === 'coin') return toImg(coinCanvas(), 'ic-coin');
  const key = opts.small && ICON_ROWS[`${name}-sm`] ? `${name}-sm` : name;
  const cv = iconCanvas(key);
  return cv ? toImg(cv, `ic-${key}${opts.active ? ' on' : ''}`) : '';
}

const ROLE = {
  coins: { big: true, color: '#2B1D2E' }, price: { big: true, color: '#2B1D2E' }, pct: { big: true, color: '#1F5FA6' },
  lv: { color: '#FFFFFF', shadow: '#1F3F7A' }, count: { color: '#2B1D2E' }, qty: { color: '#2B1D2E' }, fresh: { color: '#2F7A3E' },
};
export function num(text, role, opts = {}) {
  let t = text, cfg = ROLE[role] || {};
  if (role === 'chg') { t = (opts.dir === 'up' ? '▲' : '▼') + text; cfg = { color: opts.dir === 'up' ? '#D8323E' : '#23884A' }; }
  const cv = pxText(t, cfg);
  const pxSize = (cfg.big ? 7 : 5) * PX;
  return `<span class="num num-${role}${opts.dir ? ' ' + opts.dir : ''}" data-px-size="${pxSize}" aria-label="${text}">${toImg(cv, 'pxtext')}</span>`;
}

export function avatar() {
  const M = buildCow({ ...BREEDS.holstein, seed: 7 });
  const S = spriteB(M, { facing: 'right' });
  const W = 15, Hh = 15, c = makeCanvas(W, Hh), ctx = c.getContext('2d');
  ctx.fillStyle = '#9AD8FC'; ctx.fillRect(0, 0, W, Hh);
  ctx.fillStyle = '#B8E4FD'; ctx.fillRect(0, 0, W, 5);
  ctx.fillStyle = '#7ACB5F'; ctx.fillRect(0, 12, W, 3);
  ctx.drawImage(S.canvas, Math.round(7.5 - S.headC[0]), Math.round(8 - S.headC[1]));
  return toImg(c, 'av');
}

export function spark(series, dir) {
  const w = 24, h = 10, c = makeCanvas(w, h), ctx = c.getContext('2d');
  const min = Math.min(...series), max = Math.max(...series);
  const pts = series.map((v, i) => [Math.round((i / (series.length - 1)) * (w - 2)), Math.round(1 + (1 - (v - min) / (max - min)) * (h - 3))]);
  const col = dir === 'up' ? '#D8323E' : '#23884A', fill = dir === 'up' ? '#FFD9DC' : '#CDEFD8';
  const line = [];
  for (let i = 0; i < pts.length - 1; i++) {
    let [x0, y0] = pts[i]; const [x1, y1] = pts[i + 1];
    const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
    let err = dx + dy;
    for (;;) {
      line.push([x0, y0]);
      if (x0 === x1 && y0 === y1) break;
      const e2 = 2 * err;
      if (e2 >= dy) { err += dy; x0 += sx; }
      if (e2 <= dx) { err += dx; y0 += sy; }
    }
  }
  const top = {};
  line.forEach(([x, y]) => { top[x] = Math.min(top[x] ?? 99, y); });
  ctx.fillStyle = fill;
  Object.entries(top).forEach(([x, y]) => { for (let yy = y + 1; yy < h; yy++) if ((+x + yy) % 2 === 0 || yy > y + 2) ctx.fillRect(+x, yy, 1, 1); });
  ctx.fillStyle = col;
  line.forEach(([x, y]) => ctx.fillRect(x, y, 1, 1));
  const [ex, ey] = pts[pts.length - 1];
  ctx.fillRect(ex - 1, ey - 1, 2, 2); ctx.fillRect(ex, ey - 1, 2, 2);
  return toImg(c, 'spark');
}

export function bucket(pct) {
  const W = 16, Hh = 16, c = makeCanvas(W, Hh), ctx = c.getContext('2d');
  const put = (x, y, col) => { ctx.fillStyle = col; ctx.fillRect(x, y, 1, 1); };
  // 把手
  ['.....oooooo.....', '...oo......oo...', '..o..........o..', '..o..........o..'].forEach((r, y) => [...r].forEach((ch, x) => { if (ch === 'o') put(x, y, PAL.o); }));
  // 桶身
  const top = 5, bot = 15, level = Math.round(bot - (bot - top - 1) * (pct / 100));
  for (let y = top; y <= bot; y++) {
    const inset = Math.floor((y - top) * 0.28);
    const x0 = 1 + inset, x1 = 14 - inset;
    for (let x = x0; x <= x1; x++) {
      let col;
      if (x === x0 || x === x1 || y === bot) col = PAL.o;
      else if (y >= level) col = x === x0 + 1 ? PAL.l : PAL.m;
      else col = x === x0 + 1 ? PAL.w : PAL.e;
      put(x, y, col);
    }
    if (y === level) for (let x = x0 + 1; x < x1; x++) if ((x + y) % 3 === 0) put(x, y, PAL.l);
  }
  // 桶口
  for (let x = 0; x < 16; x++) { put(x, 4, PAL.o); put(x, 6, PAL.o); put(x, 5, x === 0 || x === 15 ? PAL.o : x < 3 ? PAL.w : PAL.s); }
  return toImg(c, 'bucket');
}

// ---------- 場景 ----------
export function scene(el, herd) {
  const cv = makeCanvas(AW, AH), ctx = cv.getContext('2d');
  const put = (x, y, col) => { ctx.fillStyle = col; ctx.fillRect(x, y, 1, 1); };
  const rect = (x, y, w, h, col) => { ctx.fillStyle = col; ctx.fillRect(x, y, w, h); };
  const r = rng(11);

  // 天空：色帶＋棋盤格混色
  const sky = ['#5DB9F5', '#78C7F9', '#95D5FB', '#B3E2FD', '#D0EEFE'];
  const bands = [0, 34, 52, 66, 78];
  for (let y = 0; y < 96; y++) {
    let i = 0; while (i < bands.length - 1 && y >= bands[i + 1]) i++;
    for (let x = 0; x < AW; x++) {
      let col = sky[i];
      const next = bands[i + 1];
      if (next !== undefined && y >= next - 2) col = (x + y) % 2 === 0 ? sky[i + 1] : sky[i];
      if (next !== undefined && y === next - 3 && x % 4 === (y % 2) * 2) col = sky[i + 1];
      put(x, y, col);
    }
  }
  // 太陽
  for (let y = 44; y < 70; y++) for (let x = 104; x < 130; x++) {
    const d = Math.hypot(x + 0.5 - 119, y + 0.5 - 56);
    if (d <= 5.6) put(x, y, d < 3.2 ? '#FFF6BF' : '#FFE066');
    else if (d <= 7.6 && (x + y) % 2 === 0) put(x, y, '#FFF1A6');
  }
  // 雲
  const cloud = (cx, cy, s) => {
    const discs = [[-9, 2, 5], [-3, -2, 6.5], [4, -1, 5.5], [9, 2, 4.5], [0, 2, 6]].map(([dx, dy, rr]) => [cx + dx * s, cy + dy * s, rr * s]);
    for (let y = Math.floor(cy - 10 * s); y < cy + 8 * s; y++) for (let x = Math.floor(cx - 16 * s); x < cx + 16 * s; x++) {
      if (y > cy + 4 * s) continue;
      if (!discs.some(([a, b, rr]) => Math.hypot(x + 0.5 - a, y + 0.5 - b) <= rr)) continue;
      put(x, y, y > cy + 1.5 * s ? '#DDF1FE' : '#FFFFFF');
    }
  };
  cloud(77, 60, 1); cloud(111, 67, 0.72); cloud(18, 55, 0.7);

  // 遠山
  const hill = (x) => Math.round(79 - 6 * Math.sin((x + 8) / 19) - 3 * Math.sin(x / 7.5 + 1));
  for (let x = 0; x < AW; x++) {
    const t = hill(x);
    for (let y = t; y < 100; y++) put(x, y, y === t ? '#6FB35E' : y < t + 2 ? '#B9E79A' : '#A6DC86');
  }
  const tree = (x, y, rr) => {
    rect(x - 1, y - 1, 2, 4, '#8A5534');
    for (let yy = Math.floor(y - rr * 2 - 1); yy <= y; yy++) for (let xx = Math.floor(x - rr - 1); xx <= x + rr + 1; xx++) {
      const d = Math.hypot(xx + 0.5 - x, yy + 0.5 - (y - rr));
      if (d > rr + 0.9) continue;
      let col = d > rr - 0.1 ? '#2F6E3A' : (xx < x - 0.5 && yy < y - rr - 0.5 && d < rr - 1) ? '#9BE07A' : (yy > y - rr + 1 ? '#4E9E4B' : '#6CC061');
      put(xx, yy, col);
    }
  };
  tree(65, 80, 3.4); tree(70, 81, 2.6); tree(124, 76, 4); tree(117, 78, 3);

  // 草地
  const meadow = (x) => Math.round(88 - 2.5 * Math.sin((x + 20) / 30));
  for (let x = 0; x < AW; x++) {
    const t = meadow(x);
    for (let y = t; y < AH; y++) {
      let col = y === t ? '#3F8C3F' : y < t + 2 ? '#A4E07E' : '#7ACB5F';
      if (y > 196) col = '#6CBF55';
      else if (y > 193 && (x + y) % 2 === 0) col = '#6CBF55';
      put(x, y, col);
    }
  }
  // 草地亮區
  for (let y = 120; y < 180; y++) for (let x = 0; x < AW; x++) {
    const d = ((x - 74) / 66) ** 2 + ((y - 148) / 34) ** 2;
    if (d < 1 && (d < 0.8 || (x + y) % 2 === 0)) put(x, y, '#86D26A');
  }

  // 筒倉
  const outlineB = '#5A3A2E';
  for (let y = 66; y < 101; y++) for (let x = 43; x < 54; x++) {
    let col = x === 43 || x === 53 ? outlineB : x === 44 ? '#E3F0FA' : x > 50 ? '#93B6DA' : '#B9D3EA';
    if ((y - 66) % 9 === 8 && x > 43 && x < 53) col = '#7EA3CB';
    if (y === 100) col = outlineB;
    put(x, y, col);
  }
  for (let y = 60; y < 67; y++) for (let x = 42; x < 55; x++) {
    const d = Math.hypot(x + 0.5 - 48.5, y + 0.5 - 67);
    if (d > 6.4) continue;
    put(x, y, d > 5.4 ? outlineB : x < 47 && y < 64 ? '#B9D3EA' : '#8EB2DA');
  }
  // 穀倉（山牆斜率 0.8，屋頂沿同一斜率往外多伸 4 格）
  const gable = (x) => 60 + 0.8 * Math.abs(x - 24);
  const inWall = (x, y) => y <= 100.5 && x >= 7 && x <= 42 && y >= gable(x);
  for (let y = 56; y <= 101; y++) for (let x = 5; x <= 43; x++) {
    if (!inWall(x + 0.5, y + 0.5)) continue;
    const edge = !inWall(x - 0.5, y + 0.5) || !inWall(x + 1.5, y + 0.5) || !inWall(x + 0.5, y + 1.5);
    let col = edge ? outlineB : (x % 3 === 0 ? '#C23A45' : '#DE4A53');
    put(x, y, col);
  }
  for (let x = 2; x <= 46; x++) {
    const yTop = Math.round(gable(x + 0.5) - 4.5);
    for (let k = 0; k < 5; k++) put(x, yTop + k, k === 0 || k === 4 ? outlineB : k === 1 ? '#FF8A80' : '#A8313C');
  }
  for (let x = 2; x <= 46; x++) { const yTop = Math.round(gable(x + 0.5) - 4.5); if (x === 2 || x === 46) for (let k = 0; k < 5; k++) put(x, yTop + k, outlineB); }
  // 門：白框＋一個大 X（Bresenham 直線，每條 1 像素）
  for (let y = 84; y <= 100; y++) for (let x = 17; x <= 31; x++) {
    let col = '#A8313C';
    if (x === 17 || x === 31 || y === 84) col = outlineB;
    else if (x === 18 || x === 30 || y === 85) col = '#FFF4EA';
    else if (x === 19 || y === 86) col = '#8E2733';
    put(x, y, col);
  }
  const line = (x0, y0, x1, y1, col) => {
    const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
    let err = dx + dy;
    for (;;) {
      put(x0, y0, col);
      if (x0 === x1 && y0 === y1) break;
      const e2 = 2 * err;
      if (e2 >= dy) { err += dy; x0 += sx; }
      if (e2 <= dx) { err += dx; y0 += sy; }
    }
  };
  line(19, 86, 29, 100, '#FFF4EA'); line(29, 86, 19, 100, '#FFF4EA');
  // 乾草窗
  for (let y = 66; y < 77; y++) for (let x = 19; x < 30; x++) {
    const d = Math.hypot(x + 0.5 - 24.5, y + 0.5 - 71.5);
    if (d > 4.6) continue;
    put(x, y, d > 3.7 ? outlineB : d > 2.8 ? '#FFF4EA' : (y === 70 || y === 72) ? '#D9962B' : '#FFD23F');
  }

  // 柵欄
  const fy = 94;
  for (let x = 0; x < AW; x++) {
    for (const ry of [fy + 3, fy + 8]) {
      put(x, ry - 1, outlineB); put(x, ry, '#FFE3B3'); put(x, ry + 1, '#D9AE6E'); put(x, ry + 2, outlineB);
    }
  }
  for (let px = 2; px < AW; px += 12) {
    for (let y = fy; y <= fy + 13; y++) for (let x = px - 1; x <= px + 3; x++) {
      if (y === fy && (x === px - 1 || x === px + 3)) continue;
      let col = x === px - 1 || x === px + 3 || y === fy || y === fy + 13 ? outlineB : x === px + 2 ? '#D9AE6E' : '#FFEFD0';
      if (y === fy + 1 && (x === px - 1 || x === px + 3)) col = outlineB;
      put(x, y, col);
    }
  }

  // 草叢與花
  const cows = herd.map((c) => ({ x: c.x / PX, y: c.y / PX }));
  const free = (x, y) => cows.every((c) => Math.abs(c.x - x) > 18 || y > c.y + 2 || y < c.y - 24);
  for (let i = 0, n = 0; i < 500 && n < 26; i++) {
    const x = 3 + Math.floor(r() * 124), y = 112 + Math.floor(r() * 70);
    if (!free(x, y)) continue;
    put(x, y, '#4FA24A'); put(x + 2, y, '#4FA24A'); put(x + 1, y + 1, '#4FA24A'); put(x + 1, y - 1, '#A4E07E'); n++;
  }
  const fcol = ['#FFFFFF', '#FFC4D3', '#FFFFFF', '#FFEC8A'];
  for (let i = 0, n = 0; i < 500 && n < 12; i++) {
    const x = 3 + Math.floor(r() * 124), y = 114 + Math.floor(r() * 66);
    if (!free(x, y)) continue;
    const col = fcol[n % 4];
    put(x, y - 1, col); put(x - 1, y, col); put(x + 1, y, col); put(x, y + 1, col); put(x, y, '#FFB02E'); n++;
  }
  // 乾草捆
  const hb = ['..oooooooo...', '.oYYYYYYYoo..', 'oYyyyyyyyoyyo', 'oyyydyyyyoydo', 'oyyyyyyyyoydo', 'oyyydyyyyoyyo', 'odddddddddooo', '.oooooooooo..'];
  ctx.drawImage(stamp(hb), 113, 150);

  // 牛
  let bubble = null;
  const sorted = [...herd].sort((a, b) => a.depth - b.depth || a.y - b.y);
  sorted.forEach((c) => {
    const M = buildCow(genesFor(c));
    const S = spriteB(M, { facing: c.facing });
    const fx = Math.round(c.x / PX), fy2 = Math.round(c.y / PX);
    const sx = fx - Math.round(S.footX), sy = fy2 - Math.round(S.footY);
    const bx = sx + Math.round(S.bodyCx);
    const rx = Math.round(S.shadowRx * 0.9);
    for (let x = -rx; x <= rx; x++) { put(bx + x, fy2 - 1, '#5FAE4E'); put(bx + x, fy2, '#5FAE4E'); }
    for (let x = -rx + 2; x <= rx - 2; x++) put(bx + x, fy2 + 1, '#5FAE4E');
    ctx.drawImage(S.canvas, sx, sy);
    const hx = sx + S.headTop[0], hy = sy + S.headTop[1];
    if (c.bubble) bubble = [Math.round(hx) * PX, Math.round(hy - 2) * PX];
    if (BREEDS[c.breed].special) {
      const sp = (x, y) => { put(x, y - 1, '#FFE066'); put(x - 1, y, '#FFE066'); put(x + 1, y, '#FFE066'); put(x, y + 1, '#FFE066'); put(x, y, '#FFFFFF'); };
      sp(Math.round(hx + (c.facing === 'right' ? 9 : -9)), Math.round(hy + 2));
      sp(Math.round(hx + (c.facing === 'right' ? -8 : 8)), Math.round(hy + 5));
    }
  });

  cv.style.width = `${AW * PX}px`; cv.style.height = `${AH * PX}px`;
  cv.className = 'px-scene';
  el.appendChild(cv);
  return { bubble };
}

// 泡泡：量好尺寸後對齊 3px 像素格（避免半像素讓像素框模糊）
export function after(root) {
  const b = root.querySelector('.bubble');
  if (!b) return;
  const x = parseFloat(b.style.left), y = parseFloat(b.style.top);
  const r = b.getBoundingClientRect();
  const snap = (v) => Math.round(v / PX) * PX;
  const w = Math.ceil(r.width / PX) * PX;
  b.style.transform = 'none';
  b.style.width = `${w}px`;
  b.style.left = `${snap(x - w / 2)}px`;
  b.style.top = `${snap(y - r.height)}px`;
  b.style.setProperty('--tail-x', `${snap(w / 2) - PX}px`);
}
