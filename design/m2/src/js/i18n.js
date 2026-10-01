// 設計稿的字串表（ceo 2026-10-01 交辦；D25 繁中、英文、泰文）。
// 網址加 ?lang=zh-Hant｜en｜th（預設 zh-Hant）。字串在 design/m2/i18n/<語言>.json，一層「key → 文字」，佔位符寫成 {name}、{n}、{price}。
// 沿用 app/lib/l10n/strings.dart 的 key 時，佔位符名稱跟 strings.dart 的參數一樣（例如 level 用 {lv}、days 用 {d}）。
// 英文、泰文缺的 key 用繁中顯示，並記下來給量測報告（window.__i18n.missing）；繁中也沒有的 key 直接報錯，免得打錯字沒發現。
// 注意：牛的產生器（breeds.js、render.js、r11.js、q.js、cowgen.js）在 node 也會跑，不能引用這個檔。
export let LANG = 'zh-Hant';
let ZH = {}, DICT = {};
const missing = new Set();

export async function loadLang(lang = 'zh-Hant') {
  LANG = lang;
  ZH = await (await fetch('../i18n/zh-Hant.json')).json();
  if (lang === 'zh-Hant') DICT = ZH;
  else {
    const r = await fetch(`../i18n/${lang}.json`);
    DICT = r.ok ? await r.json() : {};
  }
  document.documentElement.lang = { 'zh-Hant': 'zh-Hant-TW', en: 'en', th: 'th' }[lang] || lang;
  window.__i18n = { lang, missing: () => [...missing].sort() };
}

export function t(key, p = {}) {
  let s = DICT[key];
  if (s == null) {
    s = ZH[key];
    if (s == null) throw new Error(`字串表沒有這個 key：${key}`);
    if (LANG !== 'zh-Hant') missing.add(key);
  }
  return s.replace(/\{(\w+)\}/g, (m, k) => (k in p ? String(p[k]) : m));
}

// 字串裡的換行（\n）在設計稿用 <br> 畫出來
export const tb = (key, p) => t(key, p).replace(/\n/g, '<br>');

// 時間長度：{ d, h, m, s } → 「2 天 5 小時」（用 days、hours、minutes、seconds 這幾個 key 組起來）
export function dur({ d = 0, h = 0, m = 0, s = 0 } = {}) {
  const out = [];
  if (d) out.push(t('days', { d }));
  if (h) out.push(t('hours', { h }));
  if (m) out.push(t('minutes', { m }));
  if (s) out.push(t('seconds', { s }));
  return out.join(' ');
}
// 多久以前：{ min } {h} {d} → 「12 分鐘前」「3 小時前」「2 天前」
export function ago(a) {
  if (a.min != null) return t('ago.min', { n: a.min });
  if (a.h != null) return t('ago.hour', { n: a.h });
  if (a.d != null) return t('ago.day', { n: a.d });
  return t('ago.now');
}
// 日期：{ day: 'today'|'yesterday', time } 或 { m, d, time } → 「今天 09:12」「9 月 29 日 13:05」
export function dateText(w) {
  if (w.day) return t(`date.${w.day}`, { time: w.time });
  return t('date.md', { m: w.m, d: w.d, time: w.time });
}
// 牛的名字、用途、稀有度、公母
export const breedName = (k) => t(`breed.${k}.name`);
export const breedIntro = (k) => t(`breed.${k}.intro`);
export const useName = (use) => t({ dairy: 'typeDairy', draft: 'typeDual', beef: 'typeBeef' }[use]);
export const tierName = (n) => t(`tier${n}`);
export const sexName = (sex) => t(sex === 'bull' ? 'bull' : 'cow');
export const cowName = (breed, id) => `${breedName(breed)} #${id}`;
