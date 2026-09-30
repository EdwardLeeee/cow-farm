// R4 共用資料：牧場畫面的假資料沿用 R1（FARM），牛換成企劃書 4.5 的 24 種名單裡的代表品種。
// 五種外型（a–e）共用同一組基因；0 現況（R1-A）與 R2-C 的對照直接用前兩輪的原始截圖，不在這裡重畫。
import { FARM as FARM_R1 } from './r1/data.js';

export const FARM = FARM_R1;

// 基因欄位（R4，對齊企劃書 4.5，main 61725c6）
//   use     用途 dairy 乳用（MM）／dual 兼用（MF）／beef 肉用（FF）
//           三種都是胖身材：乳用最高、腿最長、有乳房；肉用最寬、最深、腿最短
//   traits  顯現的隱性特徵 { A 長毛, B 淡色, C 光澤 }；稀有度＝顯現的數量
//   sex     cow 母牛／bull 公牛（大一號、肩峰與脖子較粗、沒有乳房、角較明顯）
//   age     adult／calf（約成牛 55–60% 高、身體短圓、腿有肉、只有角芽）
//   coat 毛色｜pattern solid 素色／patches 大塊斑／strawberry 草莓（紅斑塊＋斑上淡色籽點）
//   patternColor 花紋色｜faceColor 白臉｜seedColor 草莓籽色｜overlay none／berry 綠葉蒂頭
//   legendFluff 傳說牛帶一點長毛（瀏海、蓬尾巴）｜eyeRim 眼圈深色｜muzzle 口鼻色｜earColor coat／pattern
//   角不寫在基因裡，由規則推：肉用無角（公牛也是）、兼用＋A 長角、其他短角、小牛角芽（肉用小牛沒有）
export const BREEDS = {
  holstein: {
    name: '荷斯坦', use: 'dairy', traits: {}, coat: '#FFFFFF', pattern: 'patches', patternColor: '#2E2A33',
    muzzle: '#F4E1D6', earColor: 'pattern', seed: 7,
  },
  jersey: {
    name: '娟珊', use: 'dairy', traits: { B: true }, coat: '#DDA46A', pattern: 'solid', eyeRim: true,
    muzzle: '#F3E3CC', earColor: 'coat', seed: 3,
  },
  simmental: {
    name: '西門塔爾', use: 'dual', traits: {}, coat: '#B9633A', pattern: 'solid', faceColor: '#FFF8EE',
    muzzle: '#F4E1D6', earColor: 'coat', seed: 11,
  },
  highland: {
    name: '高地牛', use: 'dual', traits: { A: true }, coat: '#E0913F', pattern: 'solid',
    muzzle: '#F3DCC0', earColor: 'coat', seed: 9,
  },
  angus: {
    name: '安格斯', use: 'beef', traits: {}, coat: '#34292A', pattern: 'solid',
    muzzle: '#E3D1C3', earColor: 'coat', seed: 5,
  },
  wagyu: {
    name: '和牛', use: 'beef', traits: { C: true }, coat: '#221A1B', pattern: 'solid', marbleColor: '#C9A7A0',
    muzzle: '#E3D1C3', earColor: 'coat', seed: 15,
  },
  strawberry: {
    name: '草莓牛', use: 'dairy', traits: { A: true, B: true, C: true }, legend: true, legendFluff: true,
    coat: '#FFF6E6', pattern: 'strawberry', patternColor: '#EE4F63', seedColor: '#FFE9A8', overlay: 'berry',
    muzzle: '#F9E4DC', earColor: 'coat', seed: 13,
  },
};

// 品種排排站：9 頭，三排
export const LINEUP = [
  { breed: 'holstein', label: '荷斯坦' },
  { breed: 'holstein', sex: 'bull', seed: 23, label: '荷斯坦公牛' },
  { breed: 'holstein', age: 'calf', seed: 31, label: '荷斯坦小牛' },
  { breed: 'jersey', label: '娟珊' },
  { breed: 'simmental', label: '西門塔爾' },
  { breed: 'highland', label: '高地牛' },
  { breed: 'angus', label: '安格斯' },
  { breed: 'wagyu', label: '和牛' },
  { breed: 'strawberry', label: '草莓牛' },
];

// 側面（照 9966：身體橫著、臉朝玩家）與正面（照 9967）各一套九頭
export const SIDE_LINEUP = LINEUP.map((e) => ({ ...e, pose: 'side' }));
export const FRONT_LINEUP = LINEUP.map((e) => ({ ...e, pose: 'front' }));

// 牧場主畫面的站位（沿用 R1 的位置，品種換成名單裡的）。
// D11：平常側面走路（照 9966，臉朝玩家）；奶桶滿了（荷斯坦，有「奶桶滿了」泡泡）和被點到（草莓牛）的轉正面（照 9967）
export const HERD = [
  { id: 'angus', breed: 'angus', x: 204, y: 334, facing: 'right', depth: 0, pose: 'side' },
  { id: 'highland', breed: 'highland', x: 318, y: 338, facing: 'left', depth: 0, pose: 'side' },
  { id: 'holstein', breed: 'holstein', x: 70, y: 420, facing: 'right', depth: 1, bubble: true, pose: 'front' },
  { id: 'calf', breed: 'holstein', age: 'calf', x: 186, y: 424, facing: 'right', depth: 1, seed: 31, pose: 'side' },
  { id: 'jersey', breed: 'jersey', x: 310, y: 422, facing: 'left', depth: 1, pose: 'side' },
  { id: 'strawberry', breed: 'strawberry', x: 122, y: 540, facing: 'right', depth: 2, pose: 'front' }, // R9：坐著的正面比較高，往右下移，免得跟荷斯坦疊在一起
  { id: 'simmental', breed: 'simmental', x: 268, y: 508, facing: 'left', depth: 2, pose: 'side' },
];

export function hornsFor(g) {
  if (g.use === 'beef') return 'none';
  if (g.age === 'calf') return 'bud';
  if (g.use === 'dual' && g.traits.A) return 'long';
  return 'short';
}

export function genesFor(entry) {
  const base = BREEDS[entry.breed];
  const g = {
    ...base, patternColor: base.patternColor || base.coat, breed: entry.breed, sex: entry.sex || 'cow', age: entry.age || 'adult',
    seed: entry.seed ?? base.seed, collar: 'bell', overlay: base.overlay || 'none',
  };
  g.horns = hornsFor(g);
  return g;
}
