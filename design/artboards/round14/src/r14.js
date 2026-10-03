// 第 14 輪草稿（ceo 2026-10-03 交辦）：01 打掃小幫手用日系動畫的畫風重畫。
// 網址：r14.html?b=R14-00&w=390 畫一張說明圖；?list=1 列出全部說明圖（harness/make.mjs 用）。
import { faceA, LOOK_A, hairBackA, hairFrontA, hairShoulderA, browsA, bodyA, BODY_A, HAIR_A, defsA } from './anime.js';

const q = new URLSearchParams(location.search);
const app = document.getElementById('app');

// 一張說明圖：左上角印檔名，下面是標題、說明、一排圖
function board({ id, title, sub = '', cells = [], notes = [] }) {
  return `<div class="board" style="width:max-content">
    <div class="b-label">${id}</div><div class="b-title">${title}</div>${sub ? `<div class="b-sub">${sub}</div>` : ''}
    <div class="pr-row">${cells.map((c) => `<div class="pr-cell"><div class="pr-cap">${c.cap}${c.note ? `<span>${c.note}</span>` : ''}</div><div class="pr-art">${c.html}</div></div>`).join('')}</div>
    ${notes.length ? `<ul class="b-notes">${notes.map((n) => `<li>${n}</li>`).join('')}</ul>` : ''}
  </div>`;
}
// 畫風試畫：頭（放大看細節、實際大小）
function probe() {
  const art = () => `${defsA()}${hairBackA(HAIR_A)}${bodyA(BODY_A)}${faceA(LOOK_A)}${hairShoulderA(HAIR_A)}${hairFrontA(HAIR_A)}${browsA(LOOK_A)}`;
  const view = (w, [x, y, vw, vh]) => `<svg viewBox="${x} ${y} ${vw} ${vh}" width="${w}" height="${Math.round((w * vh) / vw)}" aria-hidden="true">${art()}</svg>`;
  return board({
    id: 'R14-00-畫風試畫-臉和上半身', title: '畫風試畫：造型 A 的臉和上半身',
    cells: [
      { cap: '臉（放大）', html: view(420, [130, 30, 160, 190]) },
      { cap: '上半身', html: view(420, [90, 0, 240, 480]) },
      { cap: '實際大小', note: '網頁縮成 1400 寬時，全身大約 450 高：上半身大約這麼大', html: view(103, [90, 0, 240, 480]) },
    ],
  });
}

const BOARDS = [{ id: 'R14-00', w: 390, render: probe }];

async function settle() {
  await document.fonts.ready;
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
}
if (q.has('list')) {
  window.__boards = BOARDS.map(({ id, w }) => ({ id, w }));
  window.__ready = true;
} else {
  const b = BOARDS.find((x) => x.id === q.get('b'));
  if (!b) throw new Error(`沒有這張：${q.get('b')}`);
  app.innerHTML = b.render();
  await settle();
  const el = app.querySelector('.board');
  window.__file = el.querySelector('.b-label').textContent;
  window.__size = { w: Math.ceil(el.offsetWidth), h: Math.ceil(el.offsetHeight) };
  window.__ready = true;
}
