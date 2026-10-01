// 用設計稿自己的格式函式（design/m2/src/js/fixtures.js、i18n.js）產生 test/fixtures/format_cases.json。
// lib/l10n/format.dart 用 test/format_test.dart 逐筆比：設計稿怎麼寫數字和時間，app 就怎麼寫。
// 用法（在 app/ 下）：node tool/gen_format_cases.mjs
// 設計稿的程式是給瀏覽器跑的：這裡用讀檔頂替 fetch，document、window 給空物件，不改設計稿。
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const I18N = new URL('../../design/m2/i18n/', import.meta.url);
globalThis.fetch = async (url) => {
  const name = String(url).split('/').pop();
  try {
    const text = readFileSync(new URL(name, I18N), 'utf8');
    return { ok: true, json: async () => JSON.parse(text) };
  } catch {
    return { ok: false, json: async () => ({}) };
  }
};
globalThis.document = { documentElement: {} };
globalThis.window = {};

const i18n = await import('../../design/m2/src/js/i18n.js');
const fx = await import('../../design/m2/src/js/fixtures.js');

const ints = [0, 5, 12, 999, 1000, 9999, 10000, 12345, 15000, 99999, 100000, 123456, 150000, 999999, 999950, 1000000,
  1050000, 1234567, 1500000, 9950000, 9999999, 12345678, 99999999, 100000000, 123456789, 1234567890];
const decimals = [0.5, 1.25, 1.35, 2.5, 12.345, 999.95, 1234.5, 0.04, 7.005];
const pcts = [0, 0.05, 0.123, 0.1234, 0.2, -0.15, 1, 0.999, 0.0049, 0.0951, -0.2049];
const durs = [{ d: 2, h: 5 }, { h: 3 }, { m: 42 }, { d: 1, h: 2, m: 3, s: 4 }, { s: 30 }, {}];
const agos = [{ min: 5 }, { h: 3 }, { d: 2 }, {}];
const dates = [{ day: 'today', time: '09:12' }, { day: 'yesterday', time: '23:59' }, { m: 9, d: 29, time: '13:05' }];

const out = { generatedFrom: 'design/m2/src/js/fixtures.js（fmt、compact、compactBig、pct）、i18n.js（dur、ago、dateText）' };
for (const lang of ['zh-Hant', 'en', 'th']) {
  try {
    await i18n.loadLang(lang);
  } catch {
    // 設計稿的 loadLang 最後會碰 document、window；字串表在那之前就載好了
  }
  out[lang] = {
    fmt: ints.map((n) => [n, fx.fmt(n)]),
    fmt1: decimals.map((n) => [n, fx.fmt(n, 1)]),
    fmt2: decimals.map((n) => [n, fx.fmt(n, 2)]),
    compact: ints.map((n) => [n, fx.compact(n)]),
    compact100k: ints.map((n) => [n, fx.compact(n, 100000)]),
    compact1m: ints.map((n) => [n, fx.compact(n, 1000000)]),
    compactBig: ints.map((n) => [n, fx.compactBig(n)]),
    pct: pcts.map((v) => [v, fx.pct(v)]),
    pct0: pcts.map((v) => [v, fx.pct(v, 0)]),
    dur: durs.map((d) => [d, i18n.dur(d)]),
    ago: agos.map((a) => [a, i18n.ago(a)]),
    date: dates.map((d) => [d, i18n.dateText(d)]),
  };
}
mkdirSync(new URL('../test/fixtures/', import.meta.url), { recursive: true });
writeFileSync(new URL('../test/fixtures/format_cases.json', import.meta.url), `${JSON.stringify(out, null, 1)}\n`);
console.log('ok test/fixtures/format_cases.json');
