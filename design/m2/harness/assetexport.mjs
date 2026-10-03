// 把設計稿的牛和素材匯出給 app（docs/research/2026-10-cow-rendering.md 第 6 節；ceo 2026-10-02 選選項 2；位置和格式跟 cow-app 商量好）。
// 用法（在哪個資料夾跑都可以）：
//   node design/m2/harness/assetexport.mjs          清空 app/assets/cows/、app/assets/ui/ 再重新寫
//   node design/m2/harness/assetexport.mjs --check  在記憶體重產一次，跟 repo 裡的檔案逐檔比；不一樣就列出來、結束碼 1
// 這兩個資料夾只放這支腳本寫的檔案，不要手改。改了牛的產生器、圖示、場景或卡車，就重跑一次，跟 design/ 的改動放在同一個 PR。
// app 的測試（cow-app 的 test/cow_assets_test.dart）會核對 cows.json、ui.json 記的每個檔案和產生器的雜湊。
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync, rmSync, readdirSync, existsSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const SELF = fileURLToPath(import.meta.url);
const M2 = resolve(HERE, '..'), REPO = resolve(M2, '../..');
const OUT = { cows: join(REPO, 'app/assets/cows'), ui: join(REPO, 'app/assets/ui') };
const imp = (p) => import(pathToFileURL(join(M2, p)).href);

const { BREEDS, CODEX_ORDER, MIX_LOOK } = await imp('src/cow/breeds.js');
const { drawCow } = await imp('src/cow/render.js');
const { calfBow, hasBow, CALF_LOOK } = await imp('src/cow/calf.js');
const { sickLines, SICK_BUBBLE_INNER } = await imp('src/cow/sick.js');
const { ICON_NAMES, TAB_KEYS, icon, tabIcon } = await imp('src/js/icons.js');
const { backdrop, sparkle, HERD, WIDE } = await imp('src/js/scene.js');
const { TK, truckBack, truckFront, wheel, A03_HERD } = await imp('src/js/truck.js');

const f = (v) => Math.round(v * 100) / 100;
const sha = (s) => createHash('sha256').update(s).digest('hex');
const rel = (p) => relative(REPO, p).split('\\').join('/');

// ---------- 產生器的雜湊：從入口檔沿著 import 找全部用到的檔（不手寫清單，免得漏掉） ----------
function closure(entries) {
  const seen = new Set(), stack = entries.map((e) => resolve(M2, e));
  while (stack.length) {
    const p = stack.pop();
    if (seen.has(p)) continue;
    seen.add(p);
    const src = readFileSync(p, 'utf8');
    for (const m of src.matchAll(/^\s*import\s+(?:[\s\S]*?\s+from\s+)?['"](\.{1,2}\/[^'"]+)['"]/gm)) stack.push(resolve(dirname(p), m[1]));
  }
  seen.add(SELF);
  return Object.fromEntries([...seen].map((p) => [rel(p), sha(readFileSync(p))]).sort(([a], [b]) => (a < b ? -1 : 1)));
}

// ---------- 牛 ----------
const PAD = 4; // 留邊，跟 kit.js 的 cowSVG 一樣，描邊不會被切掉
// 朝右另外畫的 12 種：有光澤的牛高光一律在畫面左上，朝右不是朝左的鏡像（mirror.py＋compare.py 量的；改了高光畫法要重量）
const RIGHT = ['starry', 'honey', 'goldenEar', 'buffalo', 'wagyu', 'velvetBlack', 'shaggyBuffalo', 'fluffyWagyu', 'glossBlack', 'chocolate', 'whiteWagyu', 'angus'];
// 花紋跟著 seed 變的 9 種，各 4 個變體：v0 是品種本身的 seed（圖鑑、設計稿那一頭），v1–v3 用固定的 seed（cow-ui 2026-10-02 看過）
const VARIES = ['holstein', 'fluffyHolstein', 'glossBlack', 'chocolate', 'strawberry', 'galloway', 'whiteFleece', 'fluffyWagyu', 'starry'];
const EXTRA_SEEDS = [1000, 1037, 1074];

function cowFile(entry, facing) {
  const r = drawCow(entry, { x: 0, y: 0, scale: 1, facing, id: 'c' });
  // bbox 是模型座標；朝右時畫面上的範圍左右對調。原點在腳底，往上是負的
  const [bx0, bx1] = facing === 'right' ? [-r.bbox.x1, -r.bbox.x0] : [r.bbox.x0, r.bbox.x1];
  // 母小牛頭上的蝴蝶結（第 13 輪 02-A；design/m2/src/cow/calf.js）：圖的上緣算到蝴蝶結頂
  const bow = hasBow(entry) ? calfBow(r, entry.pose, facing) : null;
  const top = bow ? Math.min(-r.height, bow.top) : -r.height;
  const x0 = f(bx0 * r.scale - PAD), x1 = f(bx1 * r.scale + PAD), y0 = f(top - PAD), y1 = PAD;
  const w = f(x1 - x0), h = f(y1 - y0);
  // 病牛（v0.3 第 5 節）：額頭的藍色線畫進圖裡；頭上的溫度計泡泡是 ui 的 parts/sick_bubble，app 另外疊
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${x0} ${y0} ${w} ${h}" width="${w}" height="${h}">${r.svg}${bow ? bow.svg : ''}${entry.sick ? sickLines(r) : ''}</svg>\n`;
  const meta = {
    w, h, x0, y0, height: f(r.height),
    face: { cx: f(r.face.cx), cy: f(r.face.cy), r: f(r.face.r) },
    headTop: { x: f(r.headTop[0]), y: f(r.headTop[1]) },
    shadow: { cx: f(r.shadow.cx), rx: f(r.shadow.rx), ry: f(r.shadow.ry) },
  };
  return { svg, meta };
}

function cows() {
  const files = {}, breeds = {}, images = {};
  for (const breed of CODEX_ORDER) {
    const seeds = [BREEDS[breed].seed, ...(VARIES.includes(breed) ? EXTRA_SEEDS : [])];
    const right = RIGHT.includes(breed);
    breeds[breed] = { seeds, right };
    for (const sex of ['cow', 'bull']) for (const age of ['calf', 'adult']) for (const pose of ['side', 'front']) for (const facing of right ? ['left', 'right'] : ['left']) {
      seeds.forEach((seed, v) => {
        const name = `${breed}_${sex}_${age}_${pose}_${facing}_v${v}`;
        const { svg, meta } = cowFile({ breed, sex, age, pose, seed }, facing);
        files[`svg/${name}.svg`] = svg;
        images[name] = { ...meta, sha256: sha(svg) };
      });
    }
  }
  // 雜種牛（v0.3 第 1.1 節；第 13 輪 03-A）：照用途三種體型，只有長大的樣子（小牛一律用 CALF_LOOK 那個品種的小牛圖）；素色沒有光澤，朝右用翻轉
  for (const breed of Object.values(MIX_LOOK)) {
    const seeds = [BREEDS[breed].seed];
    breeds[breed] = { seeds, right: false, mix: true };
    for (const sex of ['cow', 'bull']) for (const pose of ['side', 'front']) {
      const name = `${breed}_${sex}_adult_${pose}_left_v0`;
      const { svg, meta } = cowFile({ breed, sex, age: 'adult', pose, seed: seeds[0] }, 'left');
      files[`svg/${name}.svg`] = svg;
      images[name] = { ...meta, sha256: sha(svg) };
    }
  }
  // 病牛（v0.3 第 5 節；第 13 輪 04-A）：一律轉正面，所以只有 front。臉色發青、額頭藍線；成年牛照品種，小牛照 CALF_LOOK
  const sick = (breed, sex, age, seeds, right) => {
    for (const facing of right ? ['left', 'right'] : ['left']) seeds.forEach((seed, v) => {
      const name = `${breed}_${sex}_${age}_front_${facing}_v${v}_sick`;
      const { svg, meta } = cowFile({ breed, sex, age, pose: 'front', seed, sick: true }, facing);
      files[`svg/${name}.svg`] = svg;
      images[name] = { ...meta, sha256: sha(svg) };
    });
  };
  for (const breed of [...CODEX_ORDER, ...Object.values(MIX_LOOK)]) for (const sex of ['cow', 'bull']) sick(breed, sex, 'adult', breeds[breed].seeds, breeds[breed].right);
  for (const breed of Object.values(CALF_LOOK)) for (const sex of ['cow', 'bull']) sick(breed, sex, 'calf', breeds[breed].seeds, breeds[breed].right);
  const manifest = {
    about: [
      'cow-ui 的 design/m2/harness/assetexport.mjs 產生的，不要手改。',
      '座標：每張 SVG 自己的座標（跟 viewBox 同一套），原點在腳底中間，往上是負的；x0、y0 是 viewBox 的原點，w、h 是寬高（留邊 4）。',
      'face 是臉的圓（點牛的範圍）、headTop 是頭頂（泡泡的位置）、shadow 是腳底影子的橢圓（中心 y = 1）、height 是從腳底到頭頂的高。',
      '年紀只有 calf、adult：老牛用 adult 的圖。朝右只有 right 為 true 的品種有，其他品種朝右時把朝左的圖左右翻轉。',
      '變體：seeds 的長度就是變體數，app 用「牛的編號 mod 變體數」挑。',
      '雜種牛（breeds 裡 mix 為 true）：照用途挑，乳牛 mixDairy、耕牛 mixDraft、肉牛 mixBeef；只有 adult（小牛一律用 CALF_LOOK 那個品種的小牛圖）。',
      '病牛：名字後面加 _sick，只有 front（病牛一律轉正面）；臉色發青、額頭藍線已經畫在圖裡。成年牛照品種（含雜種牛），小牛照 CALF_LOOK。頭上的溫度計泡泡用 ui 的 parts/sick_bubble 另外疊（位置見 ui.json 的 about）。',
    ],
    generator: closure(['src/cow/breeds.js', 'src/cow/render.js', 'src/cow/calf.js']),
    breeds,
    images,
  };
  files['cows.json'] = JSON.stringify(manifest, null, 1) + '\n';
  return files;
}

// ---------- 圖示、場景、動畫零件 ----------
// 圖示原本的 <svg> 帶顯示大小和 aria；匯出成獨立檔案時，寬高照 viewBox
function standalone(svg) {
  const vb = svg.match(/viewBox="([^"]+)"/)[1].split(/\s+/).map(Number);
  const inner = svg.replace(/^\s*<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
  return { svg: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vb.join(' ')}" width="${vb[2]}" height="${vb[3]}">${inner}</svg>\n`, w: vb[2], h: vb[3] };
}
const wrap = (vb, inner) => standalone(`<svg viewBox="${vb.join(' ')}">${inner}</svg>`);

function ui() {
  const files = {}, list = {};
  const put = (path, { svg, w, h }) => { files[path] = svg; list[path] = { w, h, sha256: sha(svg) }; };
  // 圖示：icons.js 的 48 個＋分頁列 6 個（選中、沒選中各一張）。up、down 用 currentColor，app 自己上色
  for (const n of ICON_NAMES) put(`icons/${n}.svg`, standalone(icon(n)));
  for (const k of TAB_KEYS) for (const on of [true, false]) put(`icons/tab_${k}_${on ? 'on' : 'off'}.svg`, standalone(tabIcon(k, on)));
  // 場景（不含牛）：設計稿的座標，一個螢幕 390×844；app 照設計稿用 cover（等比例放大、置中裁切）
  // 草叢和小花會避開牛站的地方，所以照設計稿的牛的位置排（牧場用 HERD、出貨那一幕用 A-03 的三頭牛）
  put('scenes/ranch.svg', wrap([0, 0, WIDE, 844], backdrop(HERD, true)));
  put('scenes/ship.svg', wrap([0, 0, 390, 844], backdrop(A03_HERD, false)));
  // 出貨那一幕的路：畫在螢幕座標，不跟著場景縮放（screens.css 的 .cut-road）；可以左右重複接
  put('parts/road.svg', wrap([0, 0, 48, 70], `<rect x="0" y="0" width="48" height="70" fill="#E3CDA8"/><path d="M0,1.5 H48 M0,68.5 H48" stroke="#4B3326" stroke-width="3"/><path d="M0,36 H48" stroke="#FFFFFF" stroke-width="4" stroke-dasharray="8 4"/>`));
  // 卡車：車身分兩層（back 在牛後面、front 在牛前面），輪子和擋板另外一張；座標都是卡車自己的 270×152
  put('parts/truck_back.svg', standalone(truckBack()));
  const front = truckFront('').replace(/<text[^>]*><\/text>/, '').replace(/<g id="tk-gate"[^>]*>[\s\S]*?<\/g>/, '').replace(/<g class="tk-wheel"[^>]*>[\s\S]*?<\/g>/g, '').replace(/<!--[^>]*-->\s*/g, '');
  put('parts/truck_front.svg', standalone(front));
  const r = TK.wheelR, cy = TK.h - 6 - r;
  put('parts/truck_wheel.svg', wrap([-r - 2, cy - r - 2, 2 * r + 4, 2 * r + 4], wheel(0).replace(/ class="tk-wheel"[^>]*?(?=>)/, '')));
  const gate = truckFront('').match(/<g id="tk-gate"[^>]*>([\s\S]*?)<\/g>/)[1];
  const [hx, hy] = TK.hinge;
  put('parts/truck_tailgate.svg', wrap([hx - 8, hy - 62, 12, 66], gate));
  // 星星亮光（傳說牛頭上、揭曉動畫）：半徑 10；設計稿的描邊固定 1.6，畫小的星星時描邊不要跟著縮
  put('parts/sparkle.svg', wrap([-12, -12, 24, 24], sparkle(0, 0, 10)));
  // 病牛頭上的溫度計泡泡（v0.3 第 5 節）：中心 (0, 0)、半徑 10，尾巴往左下指向牛頭
  put('parts/sick_bubble.svg', wrap([-12.6, -11, 24.6, 25.8], SICK_BUBBLE_INNER));
  const manifest = {
    about: [
      'cow-ui 的 design/m2/harness/assetexport.mjs 產生的，不要手改。files 的 key 是 app/assets/ui/ 底下的路徑。',
      'scenes：設計稿的座標，一個螢幕 390×844（ranch 是兩個螢幕寬 780），app 用 cover 放到螢幕上；不含牛。',
      'parts/road：出貨那一幕的路，畫在螢幕座標：上緣 = 螢幕高 × 0.74 − 34，高 70，左右各多 10；48 寬一段，左右重複接。',
      'parts/truck_*：卡車自己的座標 270×152（anchors.truck）。back 畫在牛後面，front 畫在牛前面；輪子、擋板另外畫。',
      'parts/sparkle：半徑 10，中心在 (0, 0)；描邊 1.6，設計稿畫小的星星時描邊不縮。',
      'parts/sick_bubble：病牛頭上的溫度計泡泡，中心在 (0, 0)、半徑 10。放的位置照 cows.json 那張牛圖的 face、headTop：中心 (face.cx + 0.9315 × face.r, headTop.y − 0.2 × face.r)，半徑 0.5 × face.r（設計稿 src/cow/sick.js 的 sickBubbleAt）。',
      'icons/poop：大便（霜淇淋捲），牧場場景裡的大便也是這張：底部中間對齊地上那一點，寬約 19（場景座標）。',
    ],
    generator: closure(['src/js/icons.js', 'src/js/scene.js', 'src/js/truck.js']),
    anchors: {
      truck: {
        size: [TK.w, TK.h],
        wheels: TK.wheels.map((x) => [x, cy]), wheelR: r, wheelSvgOrigin: [0, cy],
        hinge: TK.hinge, gateOpenDeg: -145,
        floor: TK.floor, bedCx: TK.bedCx,
        namePlate: { x: 83, y: 96, anchor: 'middle', font: 'Noto Sans CJK TC', weight: 900, size: 11.5, color: '#4B3326' },
        reverseLight: { x: 13.5, y: 88, w: 5.5, h: 8, on: '#FFE27A', off: '#FFF7D6' },
      },
      road: { top: '0.74*H-34', height: 70, overhang: 10, dash: [8, 4], dashY: 36 },
      scenes: { base: [390, 844], ranchWidth: WIDE, fit: 'cover' },
    },
    files: list,
  };
  files['ui.json'] = JSON.stringify(manifest, null, 1) + '\n';
  return files;
}

// ---------- 寫檔或比對 ----------
const sets = { cows: cows(), ui: ui() };
const walk = (d) => (existsSync(d) ? readdirSync(d).flatMap((n) => { const p = join(d, n); return statSync(p).isDirectory() ? walk(p) : [p]; }) : []);
if (process.argv.includes('--check')) {
  const bad = [];
  for (const [k, files] of Object.entries(sets)) {
    const want = new Map(Object.entries(files).map(([p, s]) => [join(OUT[k], p), s]));
    for (const p of walk(OUT[k])) if (!want.has(p)) bad.push(`多出來：${rel(p)}`);
    for (const [p, s] of want) {
      if (!existsSync(p)) bad.push(`少了：${rel(p)}`);
      else if (readFileSync(p, 'utf8') !== s) bad.push(`不一樣：${rel(p)}`);
    }
  }
  if (bad.length) {
    console.log(`app/assets 跟產生器的輸出不一樣（${bad.length} 個）：`);
    bad.slice(0, 40).forEach((b) => console.log('  ' + b));
    console.log('重跑 node design/m2/harness/assetexport.mjs，跟 design/ 的改動一起 commit。');
    process.exit(1);
  }
  console.log(`一樣：牛 ${Object.keys(sets.cows).length - 1} 張、素材 ${Object.keys(sets.ui).length - 1} 個`);
} else {
  for (const [k, files] of Object.entries(sets)) {
    rmSync(OUT[k], { recursive: true, force: true });
    for (const [p, s] of Object.entries(files)) { const full = join(OUT[k], p); mkdirSync(dirname(full), { recursive: true }); writeFileSync(full, s); }
  }
  const size = (k) => Object.values(sets[k]).reduce((n, s) => n + Buffer.byteLength(s), 0);
  console.log(`寫好了：app/assets/cows/ ${Object.keys(sets.cows).length - 1} 張牛＋cows.json（${(size('cows') / 1048576).toFixed(1)} MB），app/assets/ui/ ${Object.keys(sets.ui).length - 1} 個＋ui.json（${(size('ui') / 1024).toFixed(0)} KB）`);
}
