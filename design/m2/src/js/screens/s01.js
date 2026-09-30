// S01 啟動與載入
import { frame, btn, cowSVG, icon } from '../kit.js';

// 遊戲名先用暫名「牛市牧場」，做成單一文字，正式名稱定案後只換這一個字串
export const GAME_NAME = '牛市牧場';
const VERSION = '1.0.0';

// 草地上的草叢和小花（R1-A 場景的畫法）
function deco(dev) {
  const L = '#4B3326', W = dev.w;
  const tuft = (x, y, k = 1) => `<path d="M${x - 6 * k},${y} q${2 * k},${-6 * k} ${3 * k},${-7 * k} q${k},${4 * k} ${3 * k},${7 * k} q${1.5 * k},${-5 * k} ${3 * k},${-8 * k} q${k},${5 * k} ${3 * k},${8 * k}" fill="none" stroke="#6FBF5E" stroke-width="${2.2 * k}" stroke-linecap="round" stroke-linejoin="round"/>`;
  const flower = (x, y, c) => [0, 1, 2, 3, 4].map((i) => { const a = (i / 5) * Math.PI * 2 - Math.PI / 2; return `<circle cx="${x + Math.cos(a) * 3.3}" cy="${y + Math.sin(a) * 3.3}" r="2.6" fill="${c}" stroke="${L}" stroke-width="1.2"/>`; }).join('') + `<circle cx="${x}" cy="${y}" r="2.2" fill="#FFD04D" stroke="${L}" stroke-width="1.1"/>`;
  const T = [[0.08, 40], [0.22, 92], [0.4, 30], [0.62, 70], [0.86, 36], [0.93, 118], [0.14, 170], [0.5, 150], [0.74, 196], [0.3, 236], [0.88, 260], [0.06, 300]];
  const F = [[0.18, 58, '#FFFFFF'], [0.78, 52, '#FFC2D4'], [0.56, 112, '#FFE08A'], [0.1, 128, '#FFC2D4'], [0.84, 170, '#FFFFFF'], [0.36, 196, '#FFE08A'], [0.66, 250, '#FFFFFF']];
  return `<svg class="splash-deco" width="${W}" height="400" viewBox="0 0 ${W} 400" aria-hidden="true">${T.map(([x, y]) => tuft(x * W, y, 1.1)).join('')}${F.map(([x, y, c]) => flower(x * W, y, c)).join('')}</svg>`;
}

function splash(ctx, inner) {
  const dev = ctx.dev;
  const cows = `<div class="splash-cows">${cowSVG({ breed: 'holstein' }, { w: 150, h: 150, pose: 'front' })}${cowSVG({ breed: 'yellow', sex: 'bull', age: 'calf', seed: 33 }, { w: 96, h: 96, pose: 'front', facing: 'right' })}</div>`;
  const body = `<div class="splash">
    <div class="splash-sun"></div>
    <div class="splash-title"><span class="t">${GAME_NAME}</span></div>
    ${cows}
    <div class="splash-ground"></div>
    ${deco(dev)}
    <div class="splash-box">${inner}</div>
    <div class="splash-ver">版本 ${VERSION}</div>
  </div>`;
  return frame(dev, { tab: null, hud: false, body });
}

const S = [];
const full = (id, name, render, x = {}) => S.push({ id, name, type: 'full', render, ...x });

full('S01-01', '啟動畫面', (ctx) => splash(ctx, ''));
full('S01-02', '載入中', (ctx) => splash(ctx, `<div class="loading-row"><span class="spinner"></span><span>正在載入牧場…</span></div>`));
full('S01-03', '第一次打開：建立牧場中', (ctx) => splash(ctx, `<div class="loading-row"><span class="spinner"></span><span>正在幫你準備新牧場…</span></div><p class="hint" style="text-align:center;margin-top:6px">第一次打開要幾秒鐘</p>`));
full('S01-04', '載入失敗', (ctx) => splash(ctx, `<div class="card" style="text-align:center">
  <div class="row" style="justify-content:center;gap:6px">${icon('offline', 22)}<b style="font-size:16px">連不上伺服器</b></div>
  <p class="hint" style="margin-top:6px">請確認網路後重試。<br>每 5 秒也會自動再試一次。</p>
  <div style="margin-top:12px">${btn('重試', { kind: 'primary', block: true, ic: 'refresh' })}</div></div>`));

export default { id: 'S01', name: '啟動與載入', states: S };
