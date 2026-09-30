// 牧場背景的幾何（五種畫風共用，版面同 R1-A）：天空、太陽、雲、遠山、樹、草地、筒倉、穀倉、柵欄、草叢、花、乾草捆。
// 同樣輸出部位清單，畫風各自決定怎麼畫；扁平幾何風會把曲線換成幾何形。
import { ellipsePts, superPts, densify, rng, roundRectPts } from './q.js';

export const W = 390, H = 844;

function cloudPts(x, y, s) {
  const pts = [];
  const bumps = [[-26, 4, 11], [-12, -6, 15], [6, -9, 16], [22, -2, 12], [30, 6, 8]];
  // 雲：底部平、上方幾個圓鼓
  for (let a = Math.PI; a <= 2 * Math.PI + 0.001; a += Math.PI / 40) {
    const cx = x + Math.cos(a) * 36 * s;
    let top = y + 8 * s;
    for (const [bx, by, br] of bumps) {
      const dx = cx - (x + bx * s);
      if (Math.abs(dx) < br * s) top = Math.min(top, y + by * s - Math.sqrt((br * s) ** 2 - dx * dx));
    }
    pts.push([cx, top]);
  }
  pts.push([x + 36 * s, y + 8 * s], [x - 36 * s, y + 8 * s]);
  return pts;
}

export function sceneItems(herd) {
  const I = [];
  const fill = (role, pts, extra = {}) => I.push({ t: 'fill', role, pts, ...extra });
  const line = (role, pts, w, extra = {}) => I.push({ t: 'line', role, pts, w, ...extra });
  const dot = (role, cx, cy, rx, ry = rx, extra = {}) => I.push({ t: 'dot', role, cx, cy, rx, ry, rot: 0, ...extra });

  fill('sky', [[0, 0], [W, 0], [W, H], [0, H]], { rect: true, smooth: false });
  dot('sun', 352, 170, 18);
  [[232, 178, 1.05], [330, 200, 0.72], [52, 164, 0.7]].forEach(([x, y, s]) => fill('cloud', cloudPts(x, y, s), { smooth: false, geo: { k: 'cloud', x, y, s } }));
  const hill = []; for (let x = -10; x <= 400; x += 10) hill.push([x, 238 - 18 * Math.sin((x + 30) / 70) - 8 * Math.sin(x / 31)]);
  fill('hillFar', [...hill, [400, 330], [-10, 330]], { smooth: false });
  [[196, 244, 9], [213, 242, 7], [372, 232, 11], [352, 238, 8]].forEach(([x, y, r]) => {
    fill('trunk', roundRectPts(x - 2.5, y - 6, 5, 12, 2, 3), { smooth: false });
    dot('treeCrown', x, y - r - 3, r, r);
  });
  const meadow = []; for (let x = -10; x <= 400; x += 10) meadow.push([x, 262 - 6 * Math.sin((x + 40) / 90)]);
  fill('meadow', [...meadow, [400, H], [-10, H]], { smooth: false, region: 'meadow' });
  dot('meadowLight', 214, 440, 200, 100, { clip: 'meadow' });
  const band = []; for (let x = -10; x <= 400; x += 10) band.push([x, 600 - 6 * Math.sin((x + 10) / 80)]);
  fill('meadowBand', [...band, [400, H], [-10, H]], { smooth: false, clip: 'meadow' });
  // 筒倉
  fill('silo', roundRectPts(130, 212, 30, 92, 4, 3), { smooth: false });
  line('siloBand', [[131, 238], [159, 238]], 2);
  line('siloBand', [[131, 264], [159, 264]], 2);
  fill('siloDome', [...ellipsePts(145, 213, 16, 15, 0, 28).filter((p) => p[1] <= 213), [161, 214], [129, 214]], { smooth: false });
  // 穀倉
  fill('barnWall', [[22, 240], [72, 196], [122, 240], [122, 302], [22, 302]], { smooth: false });
  [252, 266, 280].forEach((y) => line('barnPlank', [[26, y], [118, y]], 1.6));
  fill('barnRoof', [[8, 238], [72, 180], [136, 238], [128, 246], [72, 196], [16, 246]], { smooth: false });
  fill('barnDoor', [[50, 256], [94, 256], [94, 302], [50, 302]], { smooth: false });
  line('barnTrim', [[54, 260], [90, 298]], 3); line('barnTrim', [[90, 260], [54, 298]], 3);
  dot('barnWindow', 72, 226, 10.5);
  // 柵欄
  const fy = 282;
  line('rail', [[-6, fy + 11], [W + 6, fy + 11]], 7);
  line('rail', [[-6, fy + 25], [W + 6, fy + 25]], 7);
  for (let x = 6; x < W + 20; x += 36) fill('post', [[x - 5, fy + 36], [x - 5, fy + 4], [x - 3.5, fy], [x + 3.5, fy], [x + 5, fy + 4], [x + 5, fy + 36]], { smooth: false });
  // 草叢與花（避開牛）
  const r = rng(42);
  const cows = herd.map((c) => ({ x: c.x, y: c.y }));
  const free = (x, y) => cows.every((c) => Math.abs(c.x - x) > 52 || y > c.y + 8 || y < c.y - 70);
  for (let i = 0, n = 0; i < 400 && n < 18; i++) {
    const x = 10 + r() * 370, y = 338 + r() * 200;
    if (!free(x, y)) continue;
    line('tuft', [[x - 5, y], [x - 3, y - 7]], 1.8); line('tuft', [[x, y], [x + 0.5, y - 9]], 1.8); line('tuft', [[x + 5, y], [x + 3.5, y - 6.5]], 1.8);
    n++;
  }
  const fl = [];
  for (let i = 0, n = 0; i < 400 && n < 11; i++) {
    const x = 12 + r() * 366, y = 344 + r() * 196;
    if (!free(x, y)) continue;
    fl.push([x, y, n % 3]); n++;
  }
  fl.forEach(([x, y, k]) => { dot(`flower${k}`, x, y, 3.6); dot('flowerCenter', x, y, 1.5); });
  // 乾草捆
  fill('hay', roundRectPts(338, 494, 42, 30, 10, 4), { smooth: false });
  dot('hayEnd', 378, 509, 10, 15);
  line('haySwirl', [[378, 509], [381, 506], [383, 511], [378, 516], [372, 510], [376, 502], [384, 503]], 1.6);
  return I;
}
