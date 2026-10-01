// M2 圖鑑 24 種（企劃書 4.5）：3 種用途 × 8 種特徵組合。
// 前 10 種的基因照抄第 11 輪 round11/src/data.js（D19 定案），一個字都不改；harness/cowcheck.mjs 會比對畫出來的 SVG 是否跟第 11 輪完全相同。
// 後 14 種是 M2 新畫的，跟 24 種全圖（S09-05）一起給使用者核准。新基因欄位只有新品種用：
//   lightShine 淺色毛的光澤（白色亮光外面加一圈深一點的毛色，淺色毛上才看得出來）
//   curly      肉牛長毛是捲毛（身上畫小捲）
//   pattern 'stars' 星星斑點（星空牛）、'rice' 稻穗紋（金穗牛）；overlay 'rice' 頭頂一小束稻穗（金穗牛）

export const USE_NAME = { dairy: '乳牛', draft: '耕牛', beef: '肉牛' };
export const TIER_NAME = ['一般', '優良', '稀有', '傳說'];
export const TRAIT_NAME = { A: '長毛', B: '淡色', C: '光澤' };

export const BREEDS = {
  // ---- 第 11 輪已定案的 10 種（照抄） ----
  holstein: {
    name: '荷斯坦', use: 'dairy', traits: {}, coat: '#FFFFFF', pattern: 'patches', patternColor: '#2E2A33',
    muzzle: '#F4E1D6', earColor: 'pattern', seed: 7,
  },
  jersey: {
    name: '娟珊', use: 'dairy', traits: { B: true }, coat: '#DDA46A', pattern: 'solid', eyeRim: true,
    muzzle: '#F3E3CC', earColor: 'coat', seed: 3,
  },
  chocolate: {
    name: '巧克力牛', use: 'dairy', traits: { B: true, C: true }, coat: '#7B4A2D', pattern: 'patches', patternColor: '#FFE7C2', overlay: 'cream',
    muzzle: '#F1DBC4', earColor: 'coat', seed: 21,
  },
  yellow: {
    name: '台灣黃牛', use: 'draft', traits: {}, coat: '#C7813F', pattern: 'solid',
    muzzle: '#F3DCC0', earColor: 'coat', seed: 17,
  },
  buffalo: {
    name: '台灣水牛', use: 'draft', traits: { C: true }, coat: '#4B4852', pattern: 'solid',
    muzzle: '#B9ADB3', earColor: 'coat', seed: 19,
  },
  charolais: {
    name: '夏洛來', use: 'beef', traits: { B: true }, coat: '#F4E8D4', pattern: 'solid',
    muzzle: '#F4DCD0', earColor: 'coat', seed: 27,
  },
  highland: {
    name: '高地牛', use: 'draft', traits: { A: true }, coat: '#E0913F', pattern: 'solid',
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

  // ---- M2 新畫的 14 種 ----
  fluffyHolstein: {
    name: '蓬蓬荷斯坦', use: 'dairy', traits: { A: true }, coat: '#FFFFFF', pattern: 'patches', patternColor: '#2E2A33',
    muzzle: '#F4E1D6', earColor: 'pattern', seed: 41,
  },
  glossBlack: { // 大片亮黑：黑底白斑，黑的部分有亮光
    name: '亮黑乳牛', use: 'dairy', traits: { C: true }, coat: '#26222B', pattern: 'patches', patternColor: '#FFFFFF',
    muzzle: '#E6D5CC', earColor: 'coat', seed: 43,
  },
  cottonCream: {
    name: '奶油棉花牛', use: 'dairy', traits: { A: true, B: true }, coat: '#F5E2BF', pattern: 'solid',
    muzzle: '#F7E6D3', earColor: 'coat', seed: 45,
  },
  velvetBlack: {
    name: '黑絨乳牛', use: 'dairy', traits: { A: true, C: true }, coat: '#29232E', pattern: 'solid',
    muzzle: '#E3D1C3', earColor: 'coat', seed: 47,
  },
  milkTea: {
    name: '奶茶黃牛', use: 'draft', traits: { B: true }, coat: '#D8B48C', pattern: 'solid',
    muzzle: '#F4E4D0', earColor: 'coat', seed: 49,
  },
  cottonCandy: {
    name: '棉花糖高地牛', use: 'draft', traits: { A: true, B: true }, coat: '#F3D5CB', pattern: 'solid',
    muzzle: '#F8E6DF', earColor: 'coat', seed: 51,
  },
  shaggyBuffalo: {
    name: '長毛水牛', use: 'draft', traits: { A: true, C: true }, coat: '#4E4A58', pattern: 'solid',
    muzzle: '#B9ADB3', earColor: 'coat', seed: 53,
  },
  honey: {
    name: '蜂蜜牛', use: 'draft', traits: { B: true, C: true }, coat: '#E2A23E', pattern: 'solid', lightShine: true,
    muzzle: '#F6DDB6', earColor: 'coat', seed: 55,
  },
  goldenEar: {
    name: '金穗牛', use: 'draft', traits: { A: true, B: true, C: true }, legend: true, legendFluff: true, lightShine: true,
    coat: '#EDBF57', pattern: 'rice', patternColor: '#C98A26', overlay: 'rice',
    muzzle: '#F8E3BE', earColor: 'coat', seed: 57,
  },
  galloway: {
    name: '蓋洛威', use: 'beef', traits: { A: true }, coat: '#2C2427', pattern: 'solid', curly: true,
    muzzle: '#E3D1C3', earColor: 'coat', seed: 59,
  },
  whiteFleece: {
    name: '白絨牛', use: 'beef', traits: { A: true, B: true }, coat: '#F7EEDD', pattern: 'solid', curly: true,
    muzzle: '#F4DCD0', earColor: 'coat', seed: 61,
  },
  fluffyWagyu: {
    name: '絨毛和牛', use: 'beef', traits: { A: true, C: true }, coat: '#241C1E', pattern: 'solid', curly: true,
    muzzle: '#E3D1C3', earColor: 'coat', seed: 63,
  },
  whiteWagyu: {
    name: '白和牛', use: 'beef', traits: { B: true, C: true }, coat: '#F1E1C4', pattern: 'solid', lightShine: true,
    muzzle: '#F4DCD0', earColor: 'coat', seed: 65,
  },
  starry: {
    name: '星空牛', use: 'beef', traits: { A: true, B: true, C: true }, legend: true, legendFluff: true,
    coat: '#2F3F74', pattern: 'stars', patternColor: '#FFFFFF', seedColor: '#FFE9A8',
    muzzle: '#D9CFE6', earColor: 'coat', seed: 67,
  },
};

// 圖鑑順序：企劃書 4.5 的編號 1–24
export const CODEX_ORDER = [
  'holstein', 'fluffyHolstein', 'jersey', 'glossBlack', 'cottonCream', 'velvetBlack', 'chocolate', 'strawberry',
  'yellow', 'highland', 'milkTea', 'buffalo', 'cottonCandy', 'shaggyBuffalo', 'honey', 'goldenEar',
  'angus', 'galloway', 'charolais', 'wagyu', 'whiteFleece', 'fluffyWagyu', 'whiteWagyu', 'starry',
];
export const NEW_IN_M2 = CODEX_ORDER.slice().filter((k) => !['holstein', 'jersey', 'chocolate', 'strawberry', 'yellow', 'highland', 'buffalo', 'angus', 'wagyu', 'charolais'].includes(k));

// 一句話介紹（ceo 2026-10-01 審過：牛奶照稀有度叫、圖鑑介紹不提牛肉、近黑的毛寫炭灰黑）
export const INTRO = {
  holstein: '黑白花斑的招牌乳牛，個子高、產奶穩定。',
  fluffyHolstein: '荷斯坦多了一身蓬蓬長毛和瀏海，冬天最不怕冷。',
  jersey: '淺褐色的小個子，臉短短、眼睛又大又亮。',
  glossBlack: '黑亮的毛上點綴白斑，站在太陽底下會反光。',
  cottonCream: '奶油色的蓬毛像一團棉花，看起來軟綿綿。',
  velvetBlack: '一身亮黑長毛，像穿了一件絨毛大衣。',
  chocolate: '咖啡色的毛配奶油色斑，頭頂一球奶油，看起來像一杯巧克力牛奶。',
  strawberry: '奶油白底配草莓紅斑，頭頂一片綠葉，像一顆會走路的草莓。',
  yellow: '黃褐色、肩上一個圓圓的小肩峰，田裡最可靠的幫手。',
  highland: '薑黃色長毛蓋住眼睛，頭上一對長長的角。',
  milkTea: '淡淡的奶茶色，肩峰圓圓的，脾氣很溫和。',
  buffalo: '深灰色亮毛，一對往後彎的大角，力氣很大。',
  cottonCandy: '淡米粉色的長毛蓬蓬的，像一球會走路的棉花糖。',
  shaggyBuffalo: '水牛多了一身深灰長毛，角一樣又大又彎。',
  honey: '金黃色的亮毛，像淋了一層蜂蜜。',
  goldenEar: '金黃色的身上有稻穗紋，頭頂一小束稻穗，耕田的產量特別多。',
  angus: '炭灰黑的壯碩肉牛，沒有角。',
  galloway: '炭灰黑的長捲毛又厚又暖，沒有角。',
  charolais: '奶油白的大個子，肌肉結實。',
  wagyu: '黑亮的毛帶一道光澤，頭上一對短角。',
  whiteFleece: '奶油白的長捲毛，遠看像一朵雲。',
  fluffyWagyu: '和牛的長毛版本，毛又亮又蓬，一樣有短角。',
  whiteWagyu: '奶油白的毛帶著光澤，頭上一對短角。',
  starry: '深藍色的毛上有白色星星，是最難遇到的肉牛。',
};

export function tierOf(b) { return Object.keys(b.traits || {}).filter((k) => b.traits[k]).length; }

export function hornsFor(g) {
  const t = g.traits || {};
  if (g.use === 'beef' && !t.C) return 'none';
  if (g.age === 'calf') return 'bud';
  if (g.use === 'draft' && t.C) return 'buffalo';
  if (g.use === 'draft' && t.A) return 'long';
  return 'short';
}

// entry：{ breed, sex?, age?, seed? }（跟第 11 輪 genesFor 相同的組法）
export function genesFor(entry) {
  const base = BREEDS[entry.breed];
  const g = {
    ...base, patternColor: base.patternColor || base.coat, breed: entry.breed, sex: entry.sex || 'cow', age: entry.age || 'adult',
    seed: entry.seed ?? base.seed, collar: 'bell', overlay: base.overlay || 'none',
  };
  g.horns = hornsFor(g);
  return g;
}
