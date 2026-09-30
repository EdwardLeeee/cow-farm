// R1 共用假資料：三種風格都讀這一份。
// 牛只用「基因」描述，圖一律交給 cowgen.js 產生，三個風格各自決定怎麼畫。

export const FARM = {
  name: '晴天．高原．牧場',
  level: 'Lv.5',
  title: '場主',
  coins: '12,450',
  bucket: { label: '牛奶桶', pct: 72, cur: 36, max: 50, unit: '瓶' },
  storage: {
    label: '倉庫',
    milk: { label: '牛奶', qty: 120, unit: '瓶', freshLabel: '新鮮度', fresh: 92 },
    beef: { label: '牛肉', qty: 3, unit: '箱' },
  },
  // 台灣慣例：漲紅跌綠
  market: [
    {
      key: 'milk', label: '牛奶', price: '12.4', change: '3.2%', dir: 'up',
      series: [11.62, 11.55, 11.74, 11.69, 11.83, 11.96, 11.9, 12.08, 12.02, 12.21, 12.16, 12.4],
    },
    {
      key: 'beef', label: '牛肉', price: '38.0', change: '1.1%', dir: 'down',
      series: [38.46, 38.6, 38.52, 38.71, 38.55, 38.42, 38.5, 38.31, 38.36, 38.18, 38.22, 38.0],
    },
  ],
  news: '颱風接近，牛奶收購價上漲中',
  bubble: '奶桶滿了',
  tabs: [
    { key: 'ranch', label: '牧場', active: true },
    { key: 'market', label: '市場' },
    { key: 'breed', label: '配種' },
    { key: 'dex', label: '圖鑑' },
    { key: 'rank', label: '排行' },
  ],
};

// 基因欄位
//   coat         毛色（主色）
//   pattern      花紋：patches 大塊斑｜dots 小點｜solid 素色｜strawberry 草莓
//   patternColor 花紋顏色
//   horns        角：none 無｜short 短｜long 長
//   build        體型：stocky 壯｜normal 一般
//   fur          毛質：smooth 平順｜fluffy 蓬鬆
//   overlay      特殊疊層：none｜berry 草莓葉冠＋籽｜cream 奶油旋
// 另外加的欄位（題目沒列、但畫得出來需要）：
//   eyes   眼睛：normal｜big
//   age    年齡：adult｜calf（小牛：體型縮小、頭比例變大、沒有角）
//   muzzle 口鼻顏色；earColor 耳朵用主色或花紋色；seed 花紋亂數種子
export const BREEDS = {
  holstein: {
    name: '荷斯坦', coat: '#FFFFFF', pattern: 'patches', patternColor: '#2E2A33',
    horns: 'short', build: 'normal', fur: 'smooth', overlay: 'none',
    eyes: 'normal', muzzle: '#FFB3BF', earColor: 'pattern', seed: 7,
  },
  jersey: {
    name: '娟珊', coat: '#D9A066', pattern: 'solid', patternColor: '#B97D48',
    horns: 'none', build: 'normal', fur: 'smooth', overlay: 'none',
    eyes: 'big', muzzle: '#F4DCC4', earColor: 'coat', seed: 3,
  },
  wagyu: {
    name: '和牛', coat: '#3F2C27', pattern: 'solid', patternColor: '#2A1C18',
    horns: 'short', build: 'stocky', fur: 'smooth', overlay: 'none',
    eyes: 'normal', muzzle: '#D99AA0', earColor: 'coat', seed: 5,
  },
  highland: {
    name: '高地牛', coat: '#E0913F', pattern: 'solid', patternColor: '#C0712A',
    horns: 'long', build: 'normal', fur: 'fluffy', overlay: 'none',
    eyes: 'normal', muzzle: '#F3B79B', earColor: 'coat', seed: 9,
  },
  strawberry: {
    name: '草莓牛', coat: '#FFA9BF', pattern: 'strawberry', patternColor: '#FFF2A6',
    horns: 'none', build: 'normal', fur: 'smooth', overlay: 'berry',
    eyes: 'normal', muzzle: '#FF7F9E', earColor: 'coat', seed: 13, special: true,
  },
  chocolate: {
    name: '巧克力牛', coat: '#7B4A2D', pattern: 'patches', patternColor: '#FFE7C2',
    horns: 'short', build: 'normal', fur: 'smooth', overlay: 'cream',
    eyes: 'normal', muzzle: '#EEB9A6', earColor: 'coat', seed: 21, special: true,
  },
};

// 牧場裡的牛：x 是身體中心、y 是腳底（場景座標，CSS px，場景寬 390）。
// depth 越大越靠前；A、C 依 depth 縮放，B（像素）不縮放以免破壞像素格，只有小牛用較小的原生尺寸。
// 小牛是第 7 頭：六個品種都以成牛出現，另外加一頭荷斯坦小牛。
export const HERD = [
  { id: 'wagyu', breed: 'wagyu', x: 204, y: 334, facing: 'right', depth: 0 },
  { id: 'highland', breed: 'highland', x: 318, y: 338, facing: 'left', depth: 0 },
  { id: 'holstein', breed: 'holstein', x: 78, y: 418, facing: 'right', depth: 1, bubble: true },
  { id: 'calf', breed: 'holstein', age: 'calf', x: 186, y: 424, facing: 'right', depth: 1, seed: 31 },
  { id: 'jersey', breed: 'jersey', x: 310, y: 422, facing: 'left', depth: 1 },
  { id: 'strawberry', breed: 'strawberry', x: 96, y: 506, facing: 'right', depth: 2 },
  { id: 'chocolate', breed: 'chocolate', x: 268, y: 508, facing: 'left', depth: 2 },
];

export function genesFor(entry) {
  const base = BREEDS[entry.breed];
  return { ...base, age: entry.age || 'adult', seed: entry.seed ?? base.seed, breed: entry.breed };
}
