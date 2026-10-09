// 字串表檢查（不開瀏覽器）：node harness/i18ncheck.mjs
// 1. 24 種牛的名字、介紹、特徵名（breed.*、trait.*）跟 src/cow/breeds.js 一樣（breeds.js 是 node 端出牛圖用的繁中來源）
// 2. 新聞標題（news.<商品>_<漲跌>.<序號>）跟 backend/cowecon/params.py 的 HEADLINES、FEED_HEADLINES（飼料）一樣；
//    「幫我想一個」的詞庫（namegen.*，ceo 2026-10-01）繁中跟 backend/server/data/ranch_words.json 一樣
// 3. 程式裡 t('…')、T('…') 用到的 key 都在 zh-Hant.json；列出沒用到的 key（用變數組出來的 key 前綴另外算）
// 4. 其他語言（en.json、th.json…）：缺哪些 key（畫面會用繁中）、多了哪些、佔位符 {x} 跟繁中不一樣的、空字串
// 有第 1–3 項的錯誤就回傳 1。
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const I18N = join(ROOT, 'i18n');
const load = (f) => JSON.parse(readFileSync(join(I18N, f), 'utf8'));
const zh = load('zh-Hant.json');
const errs = [];

// 1. 牛
const { BREEDS, INTRO, TRAIT_NAME } = await import(pathToFileURL(join(ROOT, 'src/cow/breeds.js')).href);
for (const [k0, b] of Object.entries(BREEDS)) {
  const k = b.mix ? 'mix' : k0; // 雜種牛三種體型共用 breed.mix.*
  if (zh[`breed.${k}.name`] !== b.name) errs.push(`breed.${k}.name 跟 breeds.js 不一樣：${zh[`breed.${k}.name`]} ≠ ${b.name}`);
  if (zh[`breed.${k}.intro`] !== INTRO[k]) errs.push(`breed.${k}.intro 跟 breeds.js 不一樣`);
}
for (const [k, v] of Object.entries(TRAIT_NAME)) if (zh[`trait.${k}`] !== v) errs.push(`trait.${k} 跟 breeds.js 不一樣`);

// 2. 新聞標題（params.py 的 HEADLINES：{"milk+": ("…", …), …}；飼料新聞在 FEED_HEADLINES：{"oats+": ("…", …), …}）
const PARAMS = join(ROOT, '../../backend/cowecon/params.py');
let headlines = 0;
if (existsSync(PARAMS)) {
  const src = readFileSync(PARAMS, 'utf8');
  const dict = (name) => { const i = src.search(new RegExp(`^${name}\\b`, 'm')); if (i < 0) return ''; const block = src.slice(i); return block.slice(block.indexOf('{'), block.indexOf('\n}') + 2); };
  const body = dict('HEADLINES') + dict('FEED_HEADLINES');
  for (const m of body.matchAll(/"(\w+)([+-])"\s*:\s*\(([^)]*)\)/g)) {
    const items = [...m[3].matchAll(/"((?:[^"\\]|\\.)*)"/g)].map((x) => x[1]);
    items.forEach((s, i) => {
      const key = `news.${m[1]}_${m[2] === '+' ? 'up' : 'down'}.${i + 1}`;
      headlines++;
      if (zh[key] !== s) errs.push(`${key} 跟 params.py 不一樣：${zh[key]} ≠ ${s}`);
    });
  }
  const extra = Object.keys(zh).filter((k) => /^news\.\w+_(up|down)\.\d+$/.test(k)).length - headlines;
  if (extra) errs.push(`zh-Hant.json 多了 ${extra} 則 params.py 沒有的新聞標題`);
} else console.log(`（找不到 ${PARAMS}，跳過新聞標題檢查）`);

// 2b. 取名詞庫：繁中照 ranch_words.json 的順序
const WORDS = join(ROOT, '../../backend/server/data/ranch_words.json');
const NG = ['first', 'second', 'third'];
if (existsSync(WORDS)) {
  const w = JSON.parse(readFileSync(WORDS, 'utf8'));
  for (const g of NG) (w[g] || []).forEach((s, i) => { if (zh[`namegen.${g}.${i}`] !== s) errs.push(`namegen.${g}.${i} 跟 ranch_words.json 不一樣：${zh[`namegen.${g}.${i}`]} ≠ ${s}`); });
} else console.log(`（找不到 ${WORDS}，跳過詞庫檢查）`);
// 取名的長度規則（D23，ceo 2026-10-01）：Mn、Me、Cf 算 0，East Asian Width 是 W、F 的算 2，其他算 1，總共 2–16（src/js/namewidth.js）
const { nameWidth } = await import(pathToFileURL(join(ROOT, 'src/js/namewidth.js')).href);
// 每組 12 個詞、接法有三個佔位符；最長的組合不能超過 16（缺的詞用繁中補，跟畫面一樣）
function checkNamegen(d, label, out) {
  const v = (k) => (d[k] != null ? d[k] : zh[k]);
  const pat = v('namegen.pattern') || '';
  for (const p of ['{first}', '{second}', '{third}']) if (!pat.includes(p)) out.push(`${label} namegen.pattern 少了 ${p}`);
  const groups = NG.map((g) => Array.from({ length: 12 }, (_, i) => v(`namegen.${g}.${i}`)));
  groups.forEach((ws, gi) => ws.forEach((s, i) => { if (!s || !String(s).trim()) out.push(`${label} namegen.${NG[gi]}.${i} 是空的`); }));
  const longest = groups.map((ws) => ws.reduce((a, b) => (nameWidth(b || '') > nameWidth(a || '') ? b : a), ''));
  const name = pat.replace('{first}', longest[0]).replace('{second}', longest[1]).replace('{third}', longest[2]);
  if (nameWidth(name) > 16) out.push(`${label} 取名詞庫接出來最長的「${name}」寬度 ${nameWidth(name)}，超過 16`);
  return name;
}
const longestZh = checkNamegen(zh, '繁中', errs);

// 3. 程式用到的 key
const files = [];
const walk = (d) => readdirSync(d, { withFileTypes: true }).forEach((e) => (e.isDirectory() ? walk(join(d, e.name)) : e.name.endsWith('.js') && files.push(join(d, e.name))));
walk(join(ROOT, 'src/js'));
const used = new Set(), dyn = new Set();
for (const f of files) {
  const s = readFileSync(f, 'utf8');
  for (const m of s.matchAll(/\b[tT]\(\s*'([^'$]+)'/g)) used.add(m[1]);
  for (const m of s.matchAll(/\b[tT]\(\s*`([^`$]*)\$\{/g)) dyn.add(m[1]); // t(`s19.desc${g}`) 這種：記前綴
  for (const m of s.matchAll(/\btb\(\s*'([^']+)'/g)) used.add(m[1]);
}
// 用變數組 key 的地方（i18n.js 的 breedName、tierName…；fixtures 的新聞；畫面裡的對照表）
['breed.', 'trait.', 'tier', 'news.', 'namegen.', 'date.', 'weekday.', 'ago.', 'err.', 's20.tip', 's19.desc', 'typeD', 'typeB', 'bull', 'cow', 'days', 'hours', 'minutes', 'seconds'].forEach((p) => dyn.add(p));
for (const f of files) { const s = readFileSync(f, 'utf8'); for (const m of s.matchAll(/'((?:[a-z]\w*\.)+\w+|[a-z]+[A-Z]\w*)'/g)) if (zh[m[1]] != null) used.add(m[1]); } // 對照表裡寫成字串的 key
for (const k of used) if (zh[k] == null) errs.push(`程式用到 ${k}，字串表沒有`);
const unused = Object.keys(zh).filter((k) => !used.has(k) && ![...dyn].some((p) => k.startsWith(p)));

const ph = (s) => [...String(s).matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort().join(',');
console.log(`繁中 ${Object.keys(zh).length} 個 key；牛 ${Object.values(BREEDS).filter((b) => !b.mix).length} 種＋雜種牛；新聞標題 ${headlines} 則；取名詞庫最長「${longestZh}」寬度 ${nameWidth(longestZh)}；程式直接用到 ${used.size} 個`);
if (unused.length) console.log(`沒用到的 key（${unused.length}）：${unused.join('、')}`);

// 4. 其他語言
for (const f of readdirSync(I18N).filter((x) => x.endsWith('.json') && x !== 'zh-Hant.json').sort()) {
  const d = load(f), lang = f.replace(/\.json$/, '');
  const missing = Object.keys(zh).filter((k) => d[k] == null);
  const extra = Object.keys(d).filter((k) => zh[k] == null);
  const badPh = Object.keys(d).filter((k) => zh[k] != null && ph(d[k]) !== ph(zh[k]));
  const empty = Object.keys(d).filter((k) => String(d[k]).trim() === '' && String(zh[k] || '').trim() !== '');
  const curly = Object.keys(d).filter((k) => /[‘’“”]/.test(d[k])); // 用詞表：一律直引號
  console.log(`\n${lang}：${Object.keys(d).length} 個 key，缺 ${missing.length}（畫面用繁中）、多 ${extra.length}、佔位符不一樣 ${badPh.length}、空字串 ${empty.length}、彎引號 ${curly.length}`);
  if (missing.length) console.log(`  缺：${missing.slice(0, 80).join('、')}${missing.length > 80 ? ` …共 ${missing.length} 個` : ''}`);
  if (extra.length) console.log(`  多：${extra.join('、')}`);
  for (const k of badPh) console.log(`  佔位符 ${k}：繁中 {${ph(zh[k])}}，${lang} {${ph(d[k])}}`);
  if (empty.length) console.log(`  空字串：${empty.join('、')}`);
  if (curly.length) console.log(`  彎引號：${curly.join('、')}`);
  if (Object.keys(d).some((k) => k.startsWith('namegen.'))) {
    const bad = [];
    const nm = checkNamegen(d, lang, bad);
    console.log(`  取名詞庫：最長「${nm}」寬度 ${nameWidth(nm)}（上限 16）`);
    bad.forEach((b) => console.log('  !!', b));
  }
  if (lang === 'th') {
    // 牛名多半是外來字：Intl.Segmenter（跟手機的換行用同一套 ICU）會把不認識的字切成幾段，換行時可能從中間斷開
    const sg = new Intl.Segmenter('th', { granularity: 'word' });
    const risky = Object.keys(d).filter((k) => /^breed\.\w+\.name$/.test(k)).map((k) => [k, [...sg.segment(d[k])].filter((s) => s.segment.trim()).map((s) => s.segment)]).filter(([, p]) => p.length > 1);
    if (risky.length) console.log(`  牛名會被切成幾段（換行時可能從中間斷開，量測時看有沒有換行）：${risky.map(([k, p]) => `${k.split('.')[1]} ${p.join('|')}`).join('、')}`);
  }
}

if (errs.length) { console.log(`\n錯誤 ${errs.length} 個：`); errs.forEach((e) => console.log('  !!', e)); process.exit(1); }
console.log('\n沒有錯誤');
