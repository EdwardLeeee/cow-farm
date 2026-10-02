// M2 出圖與量測：每個狀態 × 每種寬度，存 raw/<ID>__<寬>.png 與 .json。
// 430、390 用 DPR 3（送核准）；360、320 用 DPR 1（只量測）。局部狀態只截 crop 那一塊（外加 8px 邊）。
// 用法：node harness/capture.mjs [ID 前綴或逗號清單] [寬度清單，預設 430,390,360,320] [語言：zh-Hant（預設）｜en｜th]
// 英文、泰文存到 raw/<語言>/（只量測，不送核准，D25）；缺翻譯的 key 用繁中顯示，記在 .json 的 missing。
// 泰文另外檢查換行（用詞表）：會換行的泰文用 Intl.Segmenter 切詞，記下實際換行的位置（thaiBreaks）。
//   換在詞中間（midWord）算錯；把用詞表裡的詞拆到兩行（splitTerms）要人看：複合詞（例 ตลาด|พ่อพันธุ์）可以，外來字（例 ออฟ|ไลน์）不行。
// 記憶體：跑之前先看 free -m（available 少於 1000 MB 就先等，使用者 2026-10-03），用 systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 包起來。
import { chromium } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { startServer } from './server.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const LANG = process.argv[4] || 'zh-Hant';
const RAW = LANG === 'zh-Hant' ? join(ROOT, 'raw') : join(ROOT, 'raw', LANG);
const LOCALE = { 'zh-Hant': 'zh-TW', en: 'en-US', th: 'th-TH' }[LANG] || 'zh-TW';
const LQ = LANG === 'zh-Hant' ? '' : `&lang=${LANG}`;
// 換行時要注意不能拆開的泰文詞：用詞表（docs/i18n/glossary.md）表格裡的詞，加上 th.json 的 24 種牛名（多半是外來字）
// 字串表的外來字中間有 U+2060（看不見，擋住斷行），用詞表寫原文：這裡一律去掉 U+2060，measure 比對時再忽略 U+2060
export function glossaryTerms() {
  const p = join(ROOT, '../../docs/i18n/glossary.md'), th = join(ROOT, 'i18n/th.json');
  const out = new Set(), add = (w) => out.add(w.replace(/\u2060/g, ''));
  if (existsSync(th)) for (const [k, v] of Object.entries(JSON.parse(readFileSync(th, 'utf8')))) if (/^breed\.\w+\.name$/.test(k) && /[\u0E00-\u0E7F]/.test(v)) add(v);
  if (!existsSync(p)) return [...out];
  for (const line of readFileSync(p, 'utf8').split('\n')) {
    if (!line.startsWith('|')) continue;
    for (const cell of line.split('|')) for (const w of cell.split(/[、，,／/（）()\s]+/)) if (/^[\u0E00-\u0E7F\u2060]{2,}$/.test(w)) add(w);
  }
  return [...out].sort((a, b) => b.length - a.length);
}
const DEV = { 430: [430, 932, 3], 390: [390, 844, 3], 360: [360, 800, 1], 320: [320, 568, 1] };

// ---- 在頁面裡量 ----（anim.mjs 量英文、泰文的動畫最後一格也用這個）
export function measure(terms = []) {
  const phone = document.querySelector('.phone');
  const inSim = (el) => !!el.closest('.sim-statusbar, .sim-home-indicator, .fold-line');
  const vis = (el) => {
    const r = el.getBoundingClientRect(), cs = getComputedStyle(el);
    return r.width > 0 && r.height > 0 && cs.visibility !== 'hidden' && cs.display !== 'none' && +cs.opacity !== 0;
  };
  const rnd = (v) => Math.round(v * 10) / 10;
  const box = (r) => ({ x: rnd(r.left), y: rnd(r.top), w: rnd(r.width), h: rnd(r.height) });
  const textEls = [...phone.querySelectorAll('*')].filter((el) => !inSim(el) && vis(el) && [...el.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim()));
  const rangeRect = (el) => { const r = document.createRange(); r.selectNodeContents(el); return r; };
  const texts = textEls.map((el) => {
    const cs = getComputedStyle(el), rg = rangeRect(el);
    // 行數：把字框依垂直範圍分群（同一行裡字大小不同也算一行）
    const rs = [...rg.getClientRects()].filter((r) => r.width > 0.5).sort((a, b) => a.top - b.top);
    let lines = 0, bottom = -Infinity;
    rs.forEach((r) => { if (r.top > bottom - Math.min(4, r.height * 0.4)) { lines++; bottom = r.bottom; } else bottom = Math.max(bottom, r.bottom); });
    return { el, text: el.textContent.trim().replace(/\s+/g, ' ').slice(0, 40), fontSize: parseFloat(cs.fontSize), lines, nowrap: cs.whiteSpace === 'nowrap' || el.hasAttribute('data-oneline'), rect: rg.getBoundingClientRect() };
  });
  // 捲動區（.content；開場頁變長可以捲時是 [data-scroll]，kit.js 的 placeVersion）外面的字：捲出畫面了，看不到，不算版面問題
  const SCROLL = '.content, [data-scroll]';
  const outOfView = (el, r) => {
    const c = el.closest(SCROLL); if (!c || getComputedStyle(c).overflowY === 'visible') return false;
    const cr = c.getBoundingClientRect(); return r.bottom <= cr.top + 1 || r.top >= cr.bottom - 1;
  };
  const hiddenTexts = texts.filter((t) => outOfView(t.el, t.rect));
  const shown = texts.filter((t) => !outOfView(t.el, t.rect));
  // 看得到的那一塊：在捲動區裡的字，只算捲動區範圍內的部分
  const visRect = (el, r) => {
    const c = el.closest(SCROLL); if (!c || getComputedStyle(c).overflowY === 'visible') return r;
    const cr = c.getBoundingClientRect();
    const top = Math.max(r.top, cr.top), bottom = Math.min(r.bottom, cr.bottom);
    return { left: r.left, right: r.right, top, bottom, width: r.width, height: Math.max(0, bottom - top) };
  };
  shown.forEach((t) => {
    t.vr = visRect(t.el, t.rect);
    // 刻意截成「…」的字（自己或上一層 overflow:hidden＋ellipsis）：看得到的只有那個框
    const clipEl = [t.el, t.el.parentElement].find((e) => e && getComputedStyle(e).textOverflow === 'ellipsis' && getComputedStyle(e).overflowX !== 'visible');
    if (clipEl) { const b = clipEl.getBoundingClientRect(); t.vr = { left: Math.max(t.vr.left, b.left), right: Math.min(t.vr.right, b.right), top: t.vr.top, bottom: t.vr.bottom }; t.ellip = clipEl; }
  });
  // 被截：超出 overflow 不是 visible 的祖先（含手機邊界）
  const clipped = [], truncated = [], belowFold = hiddenTexts.map((t) => t.text);
  shown.forEach((t) => {
    if (t.el.closest('[data-marquee], [data-hscroll]')) return; // 跑馬燈、橫向捲動的列本來就會切到
    for (let a = t.el.parentElement; a && a !== document.body; a = a.parentElement) {
      const cs = getComputedStyle(a);
      if (cs.overflowX !== 'visible' || cs.overflowY !== 'visible') {
        const ar = a.getBoundingClientRect(), r = t.rect;
        if (r.left < ar.left - 0.5 || r.right > ar.right + 0.5 || r.top < ar.top - 0.5 || r.bottom > ar.bottom + 0.5) {
          if (getComputedStyle(a).textOverflow === 'ellipsis' || (getComputedStyle(t.el).textOverflow === 'ellipsis' && a === t.el.parentElement)) { if (!truncated.includes(t.text)) truncated.push(t.text); break; }
          // 可以捲動的內容區：底下被切到只是「要往下捲才看得到」，另外記
          if (a.matches(SCROLL) && r.left >= ar.left - 0.5 && r.right <= ar.right + 0.5) belowFold.push(t.text);
          else clipped.push({ text: t.text, by: String(a.className).slice(0, 40) });
          break;
        }
      }
    }
    if (t.el.scrollWidth > t.el.clientWidth + 1 && getComputedStyle(t.el).overflowX !== 'visible') {
      if (getComputedStyle(t.el).textOverflow === 'ellipsis') truncated.push(t.text); // 刻意截成「…」
      else clipped.push({ text: t.text, by: 'scrollWidth' });
    }
  });
  // 超出所屬的框
  const CONT = '.grade-big, .sso, .card, .btn, .badge, .tier, .toast, .dialog, .sheet, .tab, .seg button, .coins, .profile-text, .bubble, .ticker, .pen-pill, .notice, .filter button, .w-item, .gift, .cow-pop, .kv .cell, .chip-box';
  const outside = [];
  shown.forEach((t) => {
    if (t.el.closest('[data-marquee], [data-free]')) return; // 故意超出框的（例如卡片上緣的緞帶）
    const tcs = getComputedStyle(t.el);
    if (tcs.textOverflow === 'ellipsis' && tcs.overflowX !== 'visible') { if (t.el.scrollWidth > t.el.clientWidth + 1 && !truncated.includes(t.text)) truncated.push(t.text); return; } // 刻意截成「…」
    const c = t.el.closest(CONT); if (!c) return;
    const cr = c.getBoundingClientRect(), r = t.rect;
    if (r.left < cr.left - 0.5 || r.right > cr.right + 0.5 || r.top < cr.top - 0.5 || r.bottom > cr.bottom + 0.5) outside.push({ text: t.text, container: String(c.className).slice(0, 40) });
  });
  // 超出最近的「看得出邊界」的框（有背景色或外框的區塊，包括自己）：補上面那份固定名單沒列到的列、格子
  const boxed = (el) => {
    const cs = getComputedStyle(el);
    if (cs.overflowX !== 'visible' || cs.overflowY !== 'visible') return false; // 會裁切的框交給「被截」那一項
    const bg = cs.backgroundColor, hasBg = bg && bg !== 'transparent' && !/rgba\([^)]*,\s*0\)$/.test(bg);
    const hasBorder = ['Top', 'Right', 'Bottom', 'Left'].some((s) => parseFloat(cs[`border${s}Width`]) > 0 && cs[`border${s}Style`] !== 'none');
    return hasBg || hasBorder || cs.backgroundImage !== 'none';
  };
  shown.forEach((t) => {
    if (t.ellip || t.el.closest('[data-marquee], [data-free], [data-hscroll]')) return;
    let c = null;
    for (let a = t.el; a && a !== phone; a = a.parentElement) if (boxed(a)) { c = a; break; }
    if (!c || c.matches(CONT)) return; // 固定名單的框上面已經查過
    const cr = c.getBoundingClientRect(), r = t.rect;
    if (r.left < cr.left - 1 || r.right > cr.right + 1 || r.top < cr.top - 1 || r.bottom > cr.bottom + 1) outside.push({ text: t.text, container: String(c.className || c.tagName).slice(0, 40) });
  });
  // 不該換行的換行了
  const wrapped = shown.filter((t) => t.nowrap && t.lines > 1).map((t) => t.text);
  // 文字互相重疊（不同元素、不是祖孫關係）
  const overlaps = [];
  for (let i = 0; i < shown.length; i++) for (let j = i + 1; j < shown.length; j++) {
    const a = shown[i], b = shown[j];
    if (a.el.contains(b.el) || b.el.contains(a.el)) continue;
    const x = Math.min(a.vr.right, b.vr.right) - Math.max(a.vr.left, b.vr.left);
    const y = Math.min(a.vr.bottom, b.vr.bottom) - Math.max(a.vr.top, b.vr.top);
    if (x > 2 && y > 0.35 * Math.min(a.rect.height, b.rect.height)) { // 字框比行高大，上下兩行的字框本來就會碰到一點
      const za = a.el.closest('.backdrop ~ *, .dialog, .sheet, .toast, .cow-pop, .bubble, .hud-offline, .lv-wrap, .long-off, .big-news, .swipe-hint');
      const zb = b.el.closest('.backdrop ~ *, .dialog, .sheet, .toast, .cow-pop, .bubble, .hud-offline, .lv-wrap, .long-off, .big-news, .swipe-hint');
      if (!!za !== !!zb) continue; // 對話框、提示蓋在頁面上是故意的
      overlaps.push([a.text, b.text]);
    }
  }
  // 文字被按鈕蓋住（文字不在那顆按鈕裡）
  const btns = [...phone.querySelectorAll('.btn, button')].filter((b) => vis(b) && !inSim(b) && !outOfView(b, b.getBoundingClientRect()));
  shown.forEach((t) => {
    btns.forEach((b) => {
      if (b.contains(t.el) || t.el.contains(b)) return;
      const r = visRect(b, b.getBoundingClientRect());
      const x = Math.min(t.vr.right, r.right) - Math.max(t.vr.left, r.left), y = Math.min(t.vr.bottom, r.bottom) - Math.max(t.vr.top, r.top);
      const OV = '.dialog, .sheet, .toast, .cow-pop, .hud-offline, .bubble, .lv-wrap, .long-off, .big-news, .swipe-hint';
      if (x > 2 && y > 2 && !!t.el.closest(OV) === !!b.closest(OV)) overlaps.push([t.text, '按鈕:' + b.textContent.trim().slice(0, 10)]);
    });
  });
  // 文字被別的東西蓋住，或壓在不屬於它的圖上（ceo 2026-10-02：英文 S01 的標題壓到牛、S01-04 英文 320 的卡片蓋住版本號）
  // 在字的每一行取幾排點（行高的 1/4、1/2、3/4，每排最多 4 點），用 elementsFromPoint 看那一點由上到下疊了什麼：
  //   在字上面、真的有畫東西（底色、外框、背景圖，或 SVG 的線條／色塊、圖片）→「蓋住」
  //   在字下面、不是字的上層也不是字自己帶的圖示、是一張圖（SVG 的線條／色塊、圖片），而且這張圖沒有整個包住字 →「圖」（整個包住的是底圖）
  //   不算：對話框、提示、泡泡疊在頁面上（故意的）；浮在牧場場景（.scene）上的介面；
  //   捲動區裡的字被捲動區外面的東西（分頁列、下方按鈕區）蓋住，而且還能往那邊捲（捲了就看得到，算「要捲」）
  const OVL = '.backdrop, .backdrop ~ *, .dialog, .sheet, .toast, .cow-pop, .bubble, .hud-offline, .lv-wrap, .long-off, .big-news, .swipe-hint';
  const SHAPES = ['path', 'circle', 'ellipse', 'rect', 'polygon', 'polyline', 'line', 'text', 'use', 'image'];
  const picOf = (e) => (e instanceof SVGElement ? (SHAPES.includes(e.tagName.toLowerCase()) ? e.ownerSVGElement : null) : /^(IMG|CANVAS|VIDEO)$/.test(e.tagName) ? e : null);
  const memo = (f) => { const m = new Map(); return (e) => { if (!m.has(e)) m.set(e, f(e)); return m.get(e); }; };
  const painted = memo((e) => {
    if (picOf(e)) return true;
    if (e instanceof SVGElement) return false;
    const cs = getComputedStyle(e);
    if (+cs.opacity === 0 || cs.visibility === 'hidden') return false;
    const bg = cs.backgroundColor, hasBg = bg && bg !== 'transparent' && !/rgba\([^)]*,\s*0\)$/.test(bg);
    const hasBorder = ['Top', 'Right', 'Bottom', 'Left'].some((s) => parseFloat(cs[`border${s}Width`]) > 0 && cs[`border${s}Style`] !== 'none');
    return hasBg || hasBorder || cs.backgroundImage !== 'none';
  });
  const rectOf = memo((e) => e.getBoundingClientRect());
  const inOvl = memo((e) => !!e.closest(OVL));
  const inScene = memo((e) => !!e.closest('.scene'));
  const scroller = memo((e) => { const c = e.closest(SCROLL); return c && getComputedStyle(c).overflowY !== 'visible' ? c : null; });
  const holds = (o, r) => o.left <= r.left + 1 && o.right >= r.right - 1 && o.top <= r.top + 1 && o.bottom >= r.bottom - 1;
  const cls = (e) => (e && e.getAttribute && e.getAttribute('class') ? '.' + e.getAttribute('class').trim().split(/\s+/)[0] : '');
  const what = (e) => { const p = picOf(e) || e; return `${p.tagName.toLowerCase()}${cls(p) || (cls(p.parentElement) ? '（在 ' + cls(p.parentElement) + ' 裡）' : '')}`.slice(0, 40); };
  shown.forEach((t) => {
    if (t.el.closest('[data-note], [data-marquee]')) return;
    const cover = new Set(), pics = new Set(), sc = scroller(t.el), tOvl = inOvl(t.el), tScene = inScene(t.el);
    // 捲動區外面的東西（分頁列、下方按鈕區）蓋住捲動區裡的字：還能捲的距離夠讓這一行移出來，就算「要捲」
    const scR = sc && rectOf(sc);
    const scrollAway = (e, r) => {
      if (!sc || sc.contains(e)) return false;
      const er = rectOf(e);
      if (er.top >= scR.top) return sc.scrollHeight - sc.clientHeight - sc.scrollTop >= r.bottom - er.top; // 在下面：往下捲
      if (er.bottom <= scR.bottom) return sc.scrollTop >= er.bottom - r.top; // 在上面：往上捲
      return false;
    };
    [...rangeRect(t.el).getClientRects()].filter((r) => r.width > 2 && r.height > 2).forEach((r) => {
      const n = Math.max(1, Math.min(4, Math.round(r.width / 20)));
      for (const fy of [0.25, 0.5, 0.75]) for (let i = 0; i < n; i++) {
        const x = r.left + (r.width * (i + 0.5)) / n, y = r.top + r.height * fy;
        if (y < t.vr.top || y > t.vr.bottom) continue; // 捲出畫面的部分不算
        if (t.vr.left != null && (x < t.vr.left || x > t.vr.right)) continue; // 刻意截成「…」的，只看得到框裡
        const st = document.elementsFromPoint(x, y);
        const at = st.findIndex((e) => e === t.el || t.el.contains(e));
        if (at < 0) continue;
        for (let k = 0; k < at; k++) {
          const e = st[k];
          if (inSim(e) || e.contains(t.el) || !painted(e)) continue;
          if (inOvl(e) && !tOvl) continue;
          if (scrollAway(e, r)) continue;
          cover.add(what(e));
        }
        if (tOvl) continue;
        for (let k = at + 1; k < st.length; k++) {
          const p = picOf(st[k]);
          if (!p || p.contains(t.el) || t.el.contains(p) || inSim(p)) continue;
          if (inScene(p) && !tScene) continue;
          if (holds(rectOf(p), t.rect)) continue;
          pics.add(what(st[k]));
        }
      }
    });
    cover.forEach((c) => overlaps.push([t.text, '蓋住:' + c]));
    pics.forEach((c) => overlaps.push([t.text, '圖:' + c]));
  });
  // 觸控大小：按鈕至少 44×44（第二層分頁的按鈕算上外框的內距）
  const small = [];
  [...phone.querySelectorAll('button, a, .btn, [role=button]')].filter((el) => vis(el) && !inSim(el) && !outOfView(el, el.getBoundingClientRect())).forEach((el) => {
    let r = el.getBoundingClientRect();
    if (el.closest('.seg')) { const s = el.closest('.seg').getBoundingClientRect(); r = { width: r.width, height: s.height }; }
    if (r.width < 43.5 || r.height < 43.5) small.push({ text: (el.getAttribute('aria-label') || el.textContent.trim()).slice(0, 20), w: rnd(r.width), h: rnd(r.height) });
  });
  // 安全區：可點的東西與文字不能進狀態列或 Home 指示條
  const st = getComputedStyle(document.documentElement);
  const safeTop = parseFloat(st.getPropertyValue('--safe-top')), safeBottom = parseFloat(st.getPropertyValue('--safe-bottom'));
  const H = phone.getBoundingClientRect().height, tall = phone.classList.contains('tall');
  const unsafe = [];
  if (!tall) {
    shown.forEach((t) => { if (t.el.closest('.scene')) return; if (t.vr.bottom - t.vr.top < 1) return; if (t.vr.top < safeTop - 0.5 || t.vr.bottom > H - safeBottom + 0.5) unsafe.push(t.text); });
    [...phone.querySelectorAll('button')].filter((b) => vis(b) && !outOfView(b, b.getBoundingClientRect())).forEach((b) => { const r = visRect(b, b.getBoundingClientRect()); if (r.bottom - r.top < 1) return; if (r.top < safeTop - 0.5 || r.bottom > H - safeBottom + 0.5) unsafe.push('按鈕:' + b.textContent.trim().replace(/\s+/g, ' ').slice(0, 12)); });
  }
  // 泰文換行：每個換了行、含泰文的字，找出實際換行的位置（這個字比前一個字低半行以上），跟 Intl.Segmenter 的詞界比
  const thaiBreaks = [];
  if (document.documentElement.lang === 'th' && typeof Intl.Segmenter === 'function') {
    const sg = new Intl.Segmenter('th', { granularity: 'word' }), seen = new Set();
    shown.forEach((t) => {
      if (t.lines < 2 || t.el.closest('[data-note], [data-keep]')) return;
      const tw = document.createTreeWalker(t.el, NodeFilter.SHOW_TEXT);
      let full = '', ni = 0;
      const tops = [], node = []; // node：每個字屬於第幾個文字節點（換到另一個區塊造成的分行不算斷在詞中間）
      for (let n = tw.nextNode(); n; n = tw.nextNode(), ni++) {
        for (let i = 0; i < n.length; i++) {
          const r = document.createRange(); r.setStart(n, i); r.setEnd(n, i + 1);
          const rc = [...r.getClientRects()].find((x) => x.width > 0);
          tops.push(rc ? rc.top + rc.height / 2 : null); full += n.data[i]; node.push(ni);
        }
      }
      if (!/[\u0E00-\u0E7F]/.test(full) || seen.has(full)) return;
      seen.add(full);
      const breaks = []; let prev = null;
      tops.forEach((y, i) => { if (y == null) return; if (prev != null && y > prev + t.fontSize * 0.6) breaks.push(i); prev = y; });
      const bounds = new Set([...sg.segment(full)].map((s) => s.index));
      // 換行的前一個字是 U+2060（看不見、沒有位置）時往前找真正的字，不然剛好斷在 U+2060 那裡（外來字最不該斷的地方）會漏掉
      const prevChar = (b) => { let j = b - 1; while (j > 0 && full[j] === '\u2060') j--; return j; };
      const atBound = (j, b) => { for (let i = j + 1; i <= b; i++) if (bounds.has(i)) return true; return false; };
      const midWord = breaks.filter((b) => { const j = prevChar(b); return node[b] === node[j] && !atBound(j, b) && /[\u0E00-\u0E7FA-Za-z]/.test(full[j] || '') && /[\u0E00-\u0E7FA-Za-z]/.test(full[b] || ''); });
      // 用詞表的詞：忽略 U+2060（畫面上的字可能在任兩個字之間夾著 U+2060），記下畫面上的原樣
      const split = [];
      terms.forEach((w) => {
        const re = new RegExp([...w.replace(/\u2060/g, '')].map((c) => c.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('\u2060*'), 'g');
        for (const m of full.matchAll(re)) if (breaks.some((b) => b > m.index && b < m.index + m[0].length)) split.push(m[0]);
      });
      const view = [...sg.segment(full)].map((s) => s.segment).join('|');
      const breaksAt = breaks.slice().reverse().reduce((s, b) => s.slice(0, b) + '⏎' + s.slice(b), full); // ⏎ 是實際換行的地方
      thaiBreaks.push({ text: full.slice(0, 80), lines: t.lines, breaksAt: breaksAt.slice(0, 120), words: view.slice(0, 160), midWord: midWord.length, splitTerms: [...new Set(split)] });
    });
  }
  return {
    lang: document.documentElement.lang,
    i18nMissing: window.__i18n ? window.__i18n.missing() : [],
    thaiBreaks,
    fonts: { tc700: document.fonts.check('700 13px "Noto Sans CJK TC"'), tc900: document.fonts.check('900 13px "Noto Sans CJK TC"') },
    fontUi: getComputedStyle(document.documentElement).getPropertyValue('--font-ui').trim(),
    viewport: { w: innerWidth, h: innerHeight, dpr: devicePixelRatio },
    horizontalScroll: document.scrollingElement.scrollWidth > innerWidth + 0.5,
    minFontSize: shown.length ? Math.min(...shown.map((t) => t.fontSize)) : null,
    smallestTexts: texts.filter((t) => t.fontSize < 12).map((t) => `${t.fontSize}px ${t.text}`),
    clipped, truncated, belowFold, outside, wrapped, overlaps, smallTargets: small, unsafe,
    texts: texts.map((t) => ({ text: t.text, fontSize: t.fontSize, lines: t.lines, box: box(t.rect) })),
  };
}

async function run(filter, widths) {
  await mkdir(RAW, { recursive: true });
  const terms = LANG === 'th' ? glossaryTerms() : [];
  const srv = await startServer(ROOT);
  const browser = await chromium.launch();
  const summary = [];
  try {
    const lp = await (await browser.newContext()).newPage();
    await lp.goto(`${srv.base}/src/index.html?list=1`);
    await lp.waitForFunction(() => window.__ready === true, null, { timeout: 20000 });
    const all = await lp.evaluate(() => window.__states);
    await lp.context().close();
    const want = (!filter ? all : all.filter((s) => filter.split(',').some((f) => s.id === f || s.id.startsWith(f))))
      .filter((s) => LANG === 'zh-Hant' || !s.zhOnly); // 只有繁中的（例如按下狀態表）：英文、泰文不量
    // 大張的表（例如 S09-05 24 種全圖）：不是手機畫面，只出一張 DPR 2（給使用者核准外型用，只有繁中）
    for (const s of want.filter((x) => x.type === 'sheet' && LANG === 'zh-Hant')) {
      const ctx = await browser.newContext({ viewport: { width: s.viewport.w, height: s.viewport.h }, deviceScaleFactor: 2, locale: 'zh-TW', colorScheme: 'light', reducedMotion: 'reduce' });
      const page = await ctx.newPage();
      const errors = [];
      page.on('pageerror', (e) => errors.push(String(e)));
      await page.goto(`${srv.base}/src/index.html?id=${encodeURIComponent(s.id)}&w=390`, { waitUntil: 'load' });
      await page.waitForFunction(() => window.__ready === true, null, { timeout: 30000 });
      const size = await page.evaluate(() => window.__size);
      await page.setViewportSize({ width: s.viewport.w, height: size.h });
      await page.waitForTimeout(100);
      await page.screenshot({ path: join(RAW, `${s.id}__sheet.png`), fullPage: true });
      await writeFile(join(RAW, `${s.id}__sheet.json`), JSON.stringify({ id: s.id, name: s.name, screen: s.screen, screenName: s.screenName, type: 'sheet', size, errors }, null, 1));
      console.log(`${errors.length ? '!!' : 'ok'} ${s.id} 大張 ${s.viewport.w}×${size.h}${errors.length ? ' 錯誤:' + errors.join('|') : ''}`);
      await ctx.close();
    }
    for (const w of widths) {
      const [vw, vh, dpr] = DEV[w];
      const ctx = await browser.newContext({ viewport: { width: vw, height: vh }, deviceScaleFactor: dpr, isMobile: true, hasTouch: true, locale: LOCALE, colorScheme: 'light', reducedMotion: 'reduce' });
      // 同一個分頁拍太多張，記憶體會越用越多（長頁加上逐點量測時，分頁曾在 360 寬當掉）：每 25 張換一個新分頁；
      // 分頁當掉就換新分頁重拍一次
      let page = null, used = 0;
      const fresh = async () => { if (page) await page.close().catch(() => {}); page = await ctx.newPage(); page.setDefaultTimeout(20000); used = 0; };
      await fresh();
      const shoot = async (s) => {
        const errors = [];
        const onErr = (e) => errors.push(String(e));
        const onCon = (m) => { if (m.type() === 'error') errors.push(m.text()); };
        page.on('pageerror', onErr); page.on('console', onCon);
        await page.setViewportSize({ width: vw, height: vh });
        await page.goto(`${srv.base}/src/index.html?id=${encodeURIComponent(s.id)}&w=${w}${LQ}`, { waitUntil: 'load' });
        await page.waitForFunction(() => window.__ready === true, null, { timeout: 20000 }).catch(() => errors.push('等不到 __ready'));
        const size = await page.evaluate(() => window.__size);
        if (s.tall && size) await page.setViewportSize({ width: vw, height: size.h });
        await page.waitForTimeout(80);
        const base = join(RAW, `${s.id}__${w}`);
        if (s.type === 'part') {
          const r = await page.evaluate((sel) => { const e = document.querySelector(sel); if (!e) return null; const b = e.getBoundingClientRect(); return { x: b.left, y: b.top, w: b.width, h: b.height }; }, s.crop);
          if (!r) errors.push(`找不到 crop：${s.crop}`);
          else {
            // 只截畫面裡看得到的部分（窄手機上局部可能超出畫面）
            const vh2 = (s.tall && size ? size.h : vh), pad = 8;
            const x = Math.max(0, r.x - pad), y = Math.max(0, r.y - pad);
            const cw = Math.min(vw - x, r.w + pad * 2), chh = Math.min(vh2 - y, r.h + pad * 2 - (y - (r.y - pad)));
            if (cw > 10 && chh > 10) await page.screenshot({ path: `${base}.png`, clip: { x, y, width: cw, height: chh } });
            else errors.push('局部在畫面外，沒有截圖');
          }
        } else {
          await page.screenshot({ path: `${base}.png`, fullPage: !!s.tall });
        }
        const m = await page.evaluate(measure, terms).catch((e) => ({ error: String(e) }));
        if (/crash/i.test(m.error || '')) throw new Error(m.error);
        if (m.error) errors.push('量測失敗：' + m.error.split('\n')[0]);
        const meta = { id: s.id, name: s.name, note: s.note || '', screen: s.screen, screenName: s.screenName, type: s.type, tall: !!s.tall, ...(s.board ? { board: s.board } : {}), width: w, uiLang: LANG, errors, ...m };
        await writeFile(`${base}.json`, JSON.stringify(meta, null, 1));
        page.off('pageerror', onErr); page.off('console', onCon);
        const issues = ['clipped', 'outside', 'wrapped', 'overlaps', 'smallTargets', 'unsafe'].map((k) => (meta[k] || []).length);
        summary.push({ id: s.id, w, min: meta.minFontSize, issues, hscroll: meta.horizontalScroll, errors: errors.length });
        const flag = errors.length || meta.horizontalScroll || issues.some((n) => n);
        const thBad = (meta.thaiBreaks || []).filter((x) => x.midWord).length, thSplit = (meta.thaiBreaks || []).filter((x) => x.splitTerms.length).length;
        console.log(`${flag || thBad ? '!!' : 'ok'} ${s.id} ${w}${LANG === 'zh-Hant' ? '' : ' ' + LANG}  字 ${meta.minFontSize}px${(meta.i18nMissing || []).length ? `  缺字串${meta.i18nMissing.length}` : ''}${thBad ? `  泰文斷在詞中間${thBad}` : ''}${thSplit ? `  拆開用詞表的詞${thSplit}（要人看）` : ''}${(meta.belowFold || []).length ? `  要捲${meta.belowFold.length}` : ''}  截${issues[0]} 出框${issues[1]} 換行${issues[2]} 疊${issues[3]} 小鈕${issues[4]} 安全區${issues[5]}${meta.horizontalScroll ? ' 橫捲' : ''}${errors.length ? ' 錯誤:' + errors.join('|') : ''}`);
      };
      for (const s of want.filter((x) => x.type !== 'sheet')) {
        if (used >= 25) await fresh();
        used++;
        for (let attempt = 0; ; attempt++) {
          try { await shoot(s); break; } catch (e) {
            if (attempt === 0 && /crash/i.test(String(e))) { console.log(`.. ${s.id} ${w}  分頁當掉，換新分頁重拍`); await fresh(); continue; }
            console.log(`!! ${s.id} ${w}  出圖失敗：${String(e).split('\n')[0]}`);
            summary.push({ id: s.id, w, failed: String(e).split('\n')[0] });
            break;
          }
        }
      }
      await ctx.close();
    }
  } finally {
    await browser.close();
    await srv.close();
  }
  return summary;
}

const isMain = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isMain) {
  const filter = process.argv[2] && process.argv[2] !== 'all' ? process.argv[2] : '';
  const widths = (process.argv[3] || '430,390,360,320').split(',').map(Number);
  const watchdog = setTimeout(() => { console.error('capture timeout (45 分)'); process.exit(2); }, 45 * 60 * 1000); // 全部 × 四種寬度大約 25 分
  run(filter, widths).then(() => clearTimeout(watchdog)).catch((e) => { console.error(e); process.exit(1); });
}
