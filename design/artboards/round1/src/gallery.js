// 產生器圖庫：六個品種＋小牛，再加 24 組隨機基因，證明同一個產生器能量產。
import { BREEDS } from './data.js';
import { buildCow, randomGenes } from './cowgen.js';

const params = new URLSearchParams(location.search);
const style = params.get('style') || 'a';
const cols = +(params.get('cols') || 4);
const nRandom = +(params.get('n') ?? 24);
const size = +(params.get('size') || 150);
document.documentElement.style.setProperty('--cols', cols);

const R = await import(`./cowgen-${style}.js`);
const app = document.getElementById('app');
const label = { a: 'A 圓潤Q版', b: 'B 像素風', c: 'C 軟萌立體' }[style];
app.insertAdjacentHTML('beforeend', `<h1>牛產生器圖庫｜${label}</h1><h2>六個品種＋小牛</h2><div class="grid" id="breeds"></div><h2>隨機基因 ${nRandom} 組</h2><div class="grid" id="rand"></div>`);

function describe(g) {
  const map = { patches: '大塊斑', dots: '小點', solid: '素色', strawberry: '草莓', none: '無', short: '短角', long: '長角', stocky: '壯', normal: '一般', smooth: '平順', fluffy: '蓬鬆', berry: '草莓葉', cream: '奶油', big: '大眼', calf: '小牛', adult: '' };
  return [map[g.pattern], g.horns === 'none' ? '無角' : map[g.horns], map[g.build], map[g.fur], g.overlay !== 'none' ? map[g.overlay] : '', g.eyes === 'big' ? '大眼' : '', g.age === 'calf' ? '小牛' : ''].filter(Boolean).join('・');
}

function cell(target, genes, title, i) {
  const M = buildCow(genes);
  const div = document.createElement('div');
  div.className = 'cell';
  const node = R.renderCell(M, { id: `g${target.id}${i}`, size });
  if (typeof node === 'string') div.innerHTML = node; else div.appendChild(node);
  div.insertAdjacentHTML('beforeend', `<div>${title}</div><div class="genes">${describe(genes)}</div>`);
  target.appendChild(div);
}

const breeds = document.getElementById('breeds');
Object.entries(BREEDS).forEach(([k, g], i) => cell(breeds, { ...g, age: 'adult' }, g.name, i));
cell(breeds, { ...BREEDS.holstein, age: 'calf', seed: 31 }, '荷斯坦（小牛）', 9);
const rand = document.getElementById('rand');
for (let i = 0; i < nRandom; i++) cell(rand, randomGenes(i + 1), `隨機 #${i + 1}`, i);
window.__ready = true;
