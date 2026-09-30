// R2 共用資料：牧場畫面的假資料與 R1 完全相同（沿用 R1 的 FARM 與站位），只換牛。
// A／B／C 三個版本用同一組 R2 基因；0 現況用 R1 原本的基因與模型當對照。
import { FARM as FARM_R1, HERD as HERD_R1 } from './r1/data.js';

export const FARM = FARM_R1;
export const HERD = HERD_R1;

// 基因欄位（R2）
//   coat 毛色｜pattern 花紋 patches 大塊斑／dots 小點／solid 素色／strawberry 草莓（紅斑塊＋斑上淡色籽點）
//   patternColor 花紋色｜seedColor 草莓籽色｜horns 角 none／bud 角芽／short 短角／long 長角
//   build 體型 dairy 乳用（高瘦、腰臀有稜角）／petite 嬌小／beef 肉用（矮壯、胸深、脖子粗）／
//         low 低矮（腿短、身體貼地）／round 圓潤／dual 兼用（中等偏壯）
//   fur 毛質 smooth 平順／fluffy 蓬鬆長毛｜age 年齡 adult／calf｜eyes normal／big｜eyeRim 眼圈深色（娟珊）
//   face 臉 normal／short（短而凹）｜overlay 特殊疊層 none／berry 綠葉蒂頭／cream 奶油旋
//   muzzle 口鼻色｜earColor coat／pattern｜collar bell／none｜seed 花紋亂數種子
export const BREEDS = {
  holstein: {
    name: '荷斯坦', coat: '#FFFFFF', pattern: 'patches', patternColor: '#2E2A33', horns: 'short',
    build: 'dairy', fur: 'smooth', eyes: 'normal', face: 'normal', overlay: 'none',
    muzzle: '#F4E1D6', earColor: 'pattern', collar: 'bell', seed: 7,
  },
  jersey: {
    name: '娟珊', coat: '#D6995C', pattern: 'solid', patternColor: '#9C6436', horns: 'bud',
    build: 'petite', fur: 'smooth', eyes: 'big', eyeRim: true, face: 'short', overlay: 'none',
    muzzle: '#F2E3CB', earColor: 'coat', collar: 'bell', seed: 3,
  },
  wagyu: {
    name: '和牛', coat: '#3F2C27', pattern: 'solid', patternColor: '#2A1C18', horns: 'short',
    build: 'beef', fur: 'smooth', eyes: 'normal', face: 'normal', overlay: 'none',
    muzzle: '#E5D2C0', earColor: 'coat', collar: 'bell', seed: 5,
  },
  highland: {
    name: '高地牛', coat: '#E0913F', pattern: 'solid', patternColor: '#C0712A', horns: 'long',
    build: 'low', fur: 'fluffy', eyes: 'normal', face: 'normal', overlay: 'none',
    muzzle: '#F3DCC0', earColor: 'coat', collar: 'bell', seed: 9,
  },
  strawberry: {
    name: '草莓牛', coat: '#FFF6E6', pattern: 'strawberry', patternColor: '#EE4F63', seedColor: '#FFE9A8', horns: 'bud',
    build: 'round', fur: 'smooth', eyes: 'normal', face: 'normal', overlay: 'berry',
    muzzle: '#F9DCD9', earColor: 'coat', collar: 'bell', seed: 13, special: true,
  },
  chocolate: {
    name: '巧克力牛', coat: '#7B4A2D', pattern: 'patches', patternColor: '#FFE7C2', horns: 'short',
    build: 'dual', fur: 'smooth', eyes: 'normal', face: 'normal', overlay: 'cream',
    muzzle: '#F1DBC4', earColor: 'coat', collar: 'bell', seed: 21, special: true,
  },
};

export const LINEUP = [
  { breed: 'holstein', label: '荷斯坦' },
  { breed: 'jersey', label: '娟珊' },
  { breed: 'wagyu', label: '和牛' },
  { breed: 'highland', label: '高地牛' },
  { breed: 'strawberry', label: '草莓牛' },
  { breed: 'chocolate', label: '巧克力牛' },
  { breed: 'holstein', age: 'calf', seed: 31, label: '荷斯坦小牛' },
];

export function genesFor(entry) {
  const base = BREEDS[entry.breed];
  const calf = entry.age === 'calf';
  return {
    ...base, breed: entry.breed, age: calf ? 'calf' : 'adult', seed: entry.seed ?? base.seed,
    horns: calf && base.horns !== 'none' ? 'bud' : base.horns,
  };
}
