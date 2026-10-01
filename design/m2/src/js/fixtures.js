// M2 假資料：數字照企劃書第 5 節與協定（牛奶 12 幣／瓶、牛肉 12 幣／公斤、稻米 5 幣／公斤；ceo 2026-10-01）。
// 牧場名只用詞庫 backend/server/data/ranch_words.json 的詞；別人的牧場名加「#編號」。時間一律是真實時間。
import { BREEDS, tierOf } from '../cow/breeds.js';
import { t, LANG, cowName as nameOf } from './i18n.js';

export const RANCH = { name: '晨光河畔牧場', tag: '#1234', level: 4, earned: 5120, levelAt: 3500, nextAt: 7500, coins: 12480 };
export const xpPct = (r = RANCH) => Math.round(((r.earned - r.levelAt) / (r.nextAt - r.levelAt)) * 100);

// 我的牛（牛舍 12 格用了 10 格）
export const COWS = [
  { id: 3, breed: 'holstein', sex: 'cow', age: 'adult', age_: { d: 2, h: 5 }, milk: 14, kg: 212, value: 2514, probs: { A: 0.397, B: 0.441, C: 0.162 }, origin: 'start' },
  { id: 7, breed: 'jersey', sex: 'cow', age: 'adult', age_: { d: 1, h: 20 }, milk: 14, kg: 196, value: 3102, probs: { A: 0.402, B: 0.437, C: 0.161 }, origin: 'B' },
  { id: 12, breed: 'strawberry', sex: 'cow', age: 'adult', age_: { d: 1, h: 2 }, milk: 14, kg: 174, value: 5520, probs: { A: 0.487, B: 0.402, C: 0.111 }, origin: 'breed' },
  { id: 15, breed: 'holstein', sex: 'cow', age: 'calf', seed: 31, age_: { m: 18 }, grow_: { m: 42 }, origin: 'breed' },
  { id: 2, breed: 'yellow', sex: 'bull', age: 'adult', age_: { d: 3, h: 1 }, kg: 431, value: 5108, probs: { A: 0.416, B: 0.428, C: 0.156 }, rice: 11, field: 0, origin: 'start' },
  { id: 9, breed: 'highland', sex: 'cow', age: 'adult', age_: { d: 2, h: 9 }, kg: 377, value: 5832, probs: { A: 0.401, B: 0.439, C: 0.16 }, rice: 14.3, field: 2, origin: 'A' },
  { id: 5, breed: 'angus', sex: 'bull', age: 'adult', age_: { d: 2, h: 14 }, kg: 790, value: 9420, probs: { A: 0.448, B: 0.414, C: 0.138 }, listed: 870, origin: 'C' },
  { id: 11, breed: 'wagyu', sex: 'cow', age: 'adult', age_: { d: 1, h: 18 }, kg: 612, value: 10024, probs: { A: 0.418, B: 0.436, C: 0.146 }, origin: 'A' },
  { id: 8, breed: 'holstein', sex: 'bull', age: 'old', seed: 23, age_: { d: 7, h: 3 }, kg: 268, value: 2810, probs: { A: 0.262, B: 0.469, C: 0.269 }, bred: true, origin: 'C' },
  { id: 14, breed: 'jersey', sex: 'bull', age: 'adult', seed: 85, age_: { d: 1, h: 6 }, kg: 205, value: 3240, probs: { A: 0.383, B: 0.446, C: 0.171 }, origin: 'breed' },
];
export const PEN = { slots: 12, used: 10, max: 40, nextCost: 12150 };
export const cowById = (id) => COWS.find((c) => c.id === id);
export const breedOf = (c) => BREEDS[c.breed];
export const useOf = (c) => BREEDS[c.breed].use;
export const tierOfCow = (c) => tierOf(BREEDS[c.breed]);
export const cowName = (c) => nameOf(c.breed, c.id);

export const BUCKET = { qty: 36.4, cap: 42, perHour: 42, level: 1 };
export const WAREHOUSE = {
  cap: 225, level: 1,
  milk: [
    { qty: 60, tier: 0, fresh: 1.0, ago: { h: 1 } },
    { qty: 48, tier: 1, fresh: 0.82, ago: { h: 15 } },
    { qty: 22, tier: 3, fresh: 0.64, ago: { h: 30 } },
    { qty: 16, tier: 0, fresh: 0.27, ago: { h: 67 } },
  ],
  beef: [
    { qty: 236, tier: 0, grade: 'A', cow: { breed: 'holstein', id: 4 }, factor: 1.0, ago: { h: 3 } },
    { qty: 698, tier: 0, grade: 'B', cow: { breed: 'angus', id: 6 }, factor: 0.86, ago: { d: 2 } },
  ],
  rice: [
    { qty: 120, quality: 1.0, ago: { h: 5 } },
    { qty: 64, quality: 0.93, ago: { d: 4 } },
  ],
};
export const sum = (a, k = 'qty') => a.reduce((s, x) => s + x[k], 0);

// 行情（台灣慣例漲紅跌綠）
// 價格走勢：隨機漫步（每一步很小、前後相關），再拉直到指定的起點和終點
function walk(n, start, end, seed, vol) {
  let s = seed;
  const r = () => ((s = (s * 16807) % 2147483647) / 2147483647);
  const raw = [0];
  let v = 0;
  for (let i = 1; i < n; i++) { v = v * 0.7 + (r() - 0.5); raw.push(raw[i - 1] + v); }
  const k = vol / (Math.max(...raw) - Math.min(...raw) || 1);
  return raw.map((x, i) => {
    const t = i / (n - 1);
    return start + (end - start) * t + (x - raw[0] - (raw[n - 1] - raw[0]) * t) * k;
  });
}
function candles(series, per, seed) {
  let s = seed;
  const r = () => ((s = (s * 48271) % 2147483647) / 2147483647);
  const out = [];
  for (let i = 0; i + per <= series.length; i += per) {
    const seg = series.slice(i, i + per + 1);
    const o = seg[0], c = seg[seg.length - 1];
    const hi = Math.max(...seg) + r() * 0.12, lo = Math.min(...seg) - r() * 0.12;
    out.push({ o, c, hi, lo, vol: 800 + Math.round(r() * 2400 + (Math.abs(c - o) * 3000)) });
  }
  return out;
}
const MILK_1D = walk(97, 12.4, 13.4, 11, 0.32);
const BEEF_1D = walk(97, 11.6, 11.2, 29, 0.28);
const RICE_1D = walk(97, 5.24, 5.35, 7, 0.09);
export const MARKET = {
  milk: {
    key: 'milk', get name() { return t('milk'); }, get unit() { return t('unitMilk'); }, price: 13.4, chg: 6.3, ma24: 12.9, base: 12,
    h1: walk(13, 13.05, 13.4, 5, 0.12), d1: MILK_1D, d7: walk(85, 11.6, 13.4, 17, 0.6),
    k1d: candles(MILK_1D, 4, 3), k7d: candles(walk(169, 11.6, 13.4, 23, 0.55), 6, 9), stock: 146,
  },
  beef: {
    key: 'beef', get name() { return t('beef'); }, get unit() { return t('unitBeef'); }, price: 11.2, chg: -3.4, ma24: 11.5, base: 12,
    h1: walk(13, 11.32, 11.2, 8, 0.1), d1: BEEF_1D, d7: walk(85, 12.3, 11.2, 13, 0.5),
    k1d: candles(BEEF_1D, 4, 5), k7d: candles(walk(169, 12.3, 11.2, 31, 0.5), 6, 11), stock: 934,
  },
  rice: {
    key: 'rice', get name() { return t('rice'); }, get unit() { return t('unitRice'); }, price: 5.35, chg: 2.1, ma24: 5.3, base: 5,
    h1: walk(13, 5.31, 5.35, 3, 0.04), d1: RICE_1D, d7: walk(85, 4.9, 5.35, 19, 0.2),
    k1d: candles(RICE_1D, 4, 7), k7d: candles(walk(169, 4.9, 5.35, 37, 0.18), 6, 13), stock: 184,
  },
};
// 比平常高或低幾 %（D24：平常＝基本價；四捨五入到整數）
export const vsBase = (m) => Math.round((m.price / m.base - 1) * 100);
// 新聞：c 是商品（milk、beef、rice、all），tk 是標題的 key（backend/cowecon/params.py 的 HEADLINES）；when 是多久以前（ago.*）
export const NEWS = [
  { c: 'milk', dir: 'up', tk: 'news.milk_up.1', when: { min: 12 } },
  { c: 'beef', upcoming: true, dir: 'up', tk: 'news.beef_up.3', when: { h: 1 } },
  { c: 'all', dir: 'down', tk: 'news.all_down.2', when: { h: 3 } },
  { c: 'rice', dir: 'up', tk: 'news.rice_up.1', when: { h: 5 } },
];
// 新聞的商品標籤（【牛奶】【全部】，沿用 strings.dart 的 commodityTag、bothTag）、標題
export const newsTag = (n) => (n.c === 'all' ? t('bothTag') : t('commodityTag', { name: t(n.c) }));
export const newsText = (n) => t(n.tk);

// 田地（3 / 12 塊；每塊最多存這頭耕牛壯年 8 小時的量）
export const FIELDS = [
  { index: 0, cow: 2, rice: 62.5, cap: 88, rate: 11 },
  { index: 1, cow: null, rice: 0 },
  { index: 2, cow: 9, rice: 114.4, cap: 114.4, rate: 14.3 },
];
export const FIELD_UP = { count: 3, max: 12, cost: 4608 };

// 設施升級（企劃書 4.8）
export const UPGRADES = {
  pen: { level: 10, cost: 12150, now: 12, next: 13 }, // 開局 2 格、每次 +1；第 n 次 420 × 1.4^(n−1)
  bucket: { level: 1, cost: 310, now: 42, next: 63 }, // 200 × 1.55^L
  warehouse: { level: 1, cost: 480, now: 225, next: 337 }, // 300 × 1.6^L
  fresh: { level: 1, max: 4, cost: 4000, now: [9, 60], next: [12, 72] }, // 1,500／4,000／10,000／25,000
};

// 商店（企劃書第 5 節：A 3,200／B 1,700／C 900；用途 45／27.5／27.5；公母各半；稀有度由隱性基因頻率 0.5／0.3／0.1 算出）
export const SHOP = [
  { grade: 'A', price: 3200, tier: [42.2, 42.2, 14.1, 1.6] },
  { grade: 'B', price: 1700, tier: [75.4, 22.4, 2.2, 0.07] },
  { grade: 'C', price: 900, tier: [97.0, 2.9, 0.03, 0.0001] },
];
export const SHOP_TYPE = [45, 27.5, 27.5];

// 借種市場。借種費由系統算（D26，數字暫定）：公牛現在的體重 × 每公斤價格（一般 1.1、優良 2.75、稀有 6.6、傳說 16.5），四捨五入到 10 幣
export const STUD_RATE = [1.1, 2.75, 6.6, 16.5];
export const BEST_BULL_KG = { dairy: 275, draft: 495, beef: 880 }; // 公牛的最佳體重（企劃書第 5 節 × 1.1）
export const studFee = (kg, tier) => Math.round((kg * STUD_RATE[tier]) / 10) * 10;
export const STUD = [
  { id: 41, breed: 'holstein', seed: 71, kg: 275, price: 300, owner: '麥浪溪谷牧園', bot: true },
  { id: 42, breed: 'yellow', seed: 73, kg: 495, price: 540, owner: '露珠坡地小屋', bot: true },
  { id: 43, breed: 'chocolate', seed: 75, kg: 275, price: 1820, owner: '楓葉花田乳坊', tag: '#5821' },
  { id: 44, breed: 'highland', seed: 77, kg: 380, price: 1050, owner: '星河松林牧舍', tag: '#3310', growing: true },
  { id: 45, breed: 'wagyu', seed: 79, kg: 880, price: 2420, owner: '暖陽原野農場', tag: '#0907' },
  { id: 46, breed: 'angus', seed: 81, kg: 880, price: 970, owner: '白雲竹林農莊', bot: true },
];
export const STUD_INCOME = 1160;
// 借種紀錄：when 是日期（今天、昨天、幾月幾日），who 是對方的牧場（bot 是電腦玩家），cow、calf 用品種＋編號
export const STUD_LOG = [
  { dir: 'out', when: { day: 'today', time: '09:12' }, who: '星河松林牧舍 #3310', cow: { breed: 'angus', id: 5 }, price: 870 },
  { dir: 'in', when: { day: 'yesterday', time: '21:40' }, who: '楓葉花田乳坊 #5821', cow: { breed: 'chocolate' }, price: 1820, calf: { breed: 'chocolate', id: 14 } },
  { dir: 'out', when: { m: 9, d: 29, time: '13:05' }, who: '暖陽原野農場 #0907', cow: { breed: 'holstein', id: 8, bull: true }, price: 290 },
  { dir: 'in', when: { m: 9, d: 28, time: '20:18' }, who: '麥浪溪谷牧園', bot: true, cow: { breed: 'holstein' }, price: 300, calf: { breed: 'holstein', id: 10 } },
];
// 名字最長（量測用；D23：中文最多 8 個字、英文字母最多 16 個）
export const LONG_NAMES = { cjk: '晨光河畔牧場小屋', latin: 'MorningRiverFarm' };

// 圖鑑：已發現 10 / 24
export const FOUND = ['holstein', 'fluffyHolstein', 'jersey', 'chocolate', 'strawberry', 'yellow', 'highland', 'buffalo', 'angus', 'wagyu'];

// 排行榜
const NAMES = ['星河花田乳坊', '月牙湖邊莊園', '暖陽原野農場', '楓葉花田乳坊', '山嵐松林牧舍', '彩虹溪谷牧場', '麥浪溪谷牧園', '青草坡地家園', '白雲竹林農莊', '露珠石橋田園', '微風湖邊小屋', '晨光森林牛舍'];
export const RANK = {
  networth: NAMES.map((n, i) => ({ rank: i + 1, name: n, tag: `#${String(1021 + i * 713).padStart(4, '0').slice(-4)}`, level: 12 - Math.floor(i / 2), value: Math.round(412000 * Math.pow(0.82, i)), bot: i === 6 || i === 8 })),
  me: { networth: { rank: 37, value: 58920 }, collection: { rank: 21, value: 10 }, weekly: { rank: 44, value: 8340 } },
  collection: NAMES.map((n, i) => ({ rank: i + 1, name: n, tag: `#${String(2031 + i * 517).slice(-4)}`, level: 11 - Math.floor(i / 3), value: 24 - Math.floor(i * 0.9), bot: i === 9 })),
  weekly: NAMES.map((n, i) => ({ rank: i + 1, name: n, tag: `#${String(3041 + i * 311).slice(-4)}`, level: 10 - Math.floor(i / 3), value: Math.round(96000 * Math.pow(0.8, i)), bot: i === 3 })),
};

// 格式
export const fmt = (n, d = 0) => Number(n).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
// 很大的數字用「萬」：1,234,567 → 123.5萬（頂列金幣、牧場頁的小卡片）
// 排行榜的大數字：一億以上寫「億」、一百萬以上寫「萬」
// 英文、泰文用 K／M／B（Intl 的 compact 寫法）；繁中照原本的「萬」「億」
const compactIntl = (n) => new Intl.NumberFormat(LANG === 'th' ? 'th' : 'en', { notation: 'compact', maximumFractionDigits: 1 }).format(n);
export const compactBig = (n) => (LANG !== 'zh-Hant' ? (n >= 1e6 ? compactIntl(n) : fmt(n)) : n >= 1e8 ? `${(n / 1e8).toFixed(1)}億` : n >= 1e6 ? `${Math.round(n / 1e4).toLocaleString('en-US')}萬` : fmt(n));
export const compact = (n, from = 10000) => (n >= from ? (LANG !== 'zh-Hant' ? compactIntl(n) : `${(Math.floor(n / 1000) / 10).toFixed(1).replace(/\.0$/, '')}萬`) : fmt(n));
export const pct = (v, d = 1) => `${(v * 100).toFixed(d).replace(/\.0$/, '')}%`;
