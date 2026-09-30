// R4 出圖：五種牛的外型各一張牧場主畫面（390×844、DPR 3）與一張品種排排站＋剪影（720×864、DPR 3）；
// 每個 job 另存量測 JSON。0 現況（R1-A）與 R2-C 的對照不重拍，直接用 round2/raw 的原始截圖（見 README）。
// 用法：node harness/capture.mjs [job 名稱片段]
import { chromium } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { startServer } from './server.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const RAW = join(ROOT, 'raw');

export const DEVICE = {
  viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true,
  locale: 'zh-TW', colorScheme: 'light', reducedMotion: 'reduce',
};
export const JOBS = ['a', 'b', 'c', 'd', 'e'].flatMap((v) => [
  { job: `r4-01-${v}-mobile`, page: `src/screen.html?v=${v}` },
  { job: `r4-lineup-${v}`, page: `src/lineup.html?v=${v}`, lineup: true, viewport: { width: 720, height: 864 } },
]);

// 排排站面板的量測：最小字級、文字有沒有被截或超出所屬的格子、面板有沒有橫向溢出
function measureLineup() {
  const els = [...document.querySelectorAll('.panel *')].filter((el) => [...el.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim()));
  const texts = els.map((el) => ({ text: el.textContent.trim(), fontSize: parseFloat(getComputedStyle(el).fontSize) }));
  const outside = [];
  els.forEach((el) => {
    const r = document.createRange(); r.selectNodeContents(el);
    const tr = r.getBoundingClientRect();
    const c = el.closest('.fig, .sec, .panel').getBoundingClientRect();
    if (tr.left < c.left - 0.5 || tr.right > c.right + 0.5 || tr.top < c.top - 0.5 || tr.bottom > c.bottom + 0.5) outside.push(el.textContent.trim());
  });
  const panel = document.querySelector('.panel').getBoundingClientRect();
  const figs = [...document.querySelectorAll('.fig')].map((f) => f.getBoundingClientRect());
  const figOverflow = figs.filter((f) => f.left < panel.left - 0.5 || f.right > panel.right + 0.5).length;
  // 剪影的名字彼此不能重疊
  const sn = [...document.querySelectorAll('.sname')].map((e) => { const r = document.createRange(); r.selectNodeContents(e); return r.getBoundingClientRect(); });
  let overlap = 0;
  for (let i = 1; i < sn.length; i++) if (sn[i].left < sn[i - 1].right - 0.5) overlap++;
  return {
    lang: document.documentElement.lang, minFontSize: Math.min(...texts.map((t) => t.fontSize)), texts, outside,
    clipped: [], figOverflow, silNameOverlap: overlap, horizontalScroll: document.scrollingElement.scrollWidth > innerWidth,
    ...(window.__meta || {}),
  };
}

// 在頁面裡量：最小字級、文字有沒有被截或超出框、橫向捲動、分頁觸控大小、安全區、字型、像素格
function measure() {
  const vis = (el) => {
    const r = el.getBoundingClientRect(), cs = getComputedStyle(el);
    return r.width > 0 && r.height > 0 && cs.visibility !== 'hidden' && cs.display !== 'none' && +cs.opacity !== 0;
  };
  const box = (r) => ({ x: Math.round(r.left * 10) / 10, y: Math.round(r.top * 10) / 10, w: Math.round(r.width * 10) / 10, h: Math.round(r.height * 10) / 10 });
  const inOverlay = (el) => !!el.closest('.sim-statusbar, .sim-home-indicator');
  const textEls = [...document.querySelectorAll('.phone *')].filter((el) => !inOverlay(el) && vis(el)
    && [...el.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim()));
  const texts = textEls.map((el) => {
    const cs = getComputedStyle(el);
    const range = document.createRange(); range.selectNodeContents(el);
    const rects = [...range.getClientRects()];
    const lh = parseFloat(cs.lineHeight) || parseFloat(cs.fontSize) * 1.4;
    const lines = new Set(rects.map((r) => Math.round(r.top))).size;
    return { text: el.textContent.trim(), cls: String(el.className), fontSize: parseFloat(cs.fontSize), weight: cs.fontWeight, lines, lineHeight: lh, box: box(range.getBoundingClientRect()) };
  });
  const pxTexts = [...document.querySelectorAll('[data-px-size]')].filter(vis).map((el) => ({ text: el.getAttribute('aria-label'), pxSize: +el.dataset.pxSize, box: box(el.getBoundingClientRect()) }));

  // 被截：文字範圍超出任何一個 overflow 不是 visible 的祖先，或 scrollWidth > clientWidth
  const clipped = [];
  const checkClip = (el, rect, label) => {
    for (let a = el.parentElement; a && a !== document.body; a = a.parentElement) {
      const cs = getComputedStyle(a);
      if (cs.overflowX !== 'visible' || cs.overflowY !== 'visible') {
        const ar = a.getBoundingClientRect();
        if (rect.left < ar.left - 0.5 || rect.right > ar.right + 0.5 || rect.top < ar.top - 0.5 || rect.bottom > ar.bottom + 0.5) {
          clipped.push({ text: label, by: String(a.className) }); return;
        }
      }
    }
  };
  textEls.forEach((el) => { const r = document.createRange(); r.selectNodeContents(el); checkClip(el, r.getBoundingClientRect(), el.textContent.trim()); });
  document.querySelectorAll('[data-px-size]').forEach((el) => checkClip(el, el.getBoundingClientRect(), el.getAttribute('aria-label')));
  [...document.querySelectorAll('.phone *')].filter((el) => !inOverlay(el) && vis(el)).forEach((el) => {
    const cs = getComputedStyle(el);
    if (!el.textContent.trim() && !el.querySelector('[data-px-size]')) return;
    if ((cs.overflowX === 'hidden' || cs.textOverflow === 'ellipsis') && el.scrollWidth > el.clientWidth + 1) clipped.push({ text: el.textContent.trim().slice(0, 30), by: 'scrollWidth>clientWidth ' + el.className });
  });

  // 超出框：文字要在所屬的卡片／膠囊／分頁裡面
  const CONTAINERS = '.card, .profile-text, .coins, .ticker, .tab, .bubble';
  const outside = [];
  const pad = 0.5;
  const within = (r, c) => r.left >= c.left - pad && r.right <= c.right + pad && r.top >= c.top - pad && r.bottom <= c.bottom + pad;
  textEls.forEach((el) => {
    const c = el.closest(CONTAINERS); if (!c) return;
    const r = document.createRange(); r.selectNodeContents(el);
    if (!within(r.getBoundingClientRect(), c.getBoundingClientRect())) outside.push({ text: el.textContent.trim(), container: String(c.className) });
  });
  document.querySelectorAll('[data-px-size]').forEach((el) => {
    const c = el.closest(CONTAINERS); if (!c) return;
    if (!within(el.getBoundingClientRect(), c.getBoundingClientRect())) outside.push({ text: el.getAttribute('aria-label'), container: String(c.className) });
  });

  // 單行：nowrap 與 data-oneline 的文字不能變兩行
  const wrapped = texts.filter((t) => t.lines > 1).map((t) => t.text);

  const tabs = [...document.querySelectorAll('.tab')].map((el) => ({ label: el.textContent.trim(), ...box(el.getBoundingClientRect()) }));
  const hud = document.querySelector('.hud').getBoundingClientRect();
  const tabbar = document.querySelector('.tabbar').getBoundingClientRect();
  const safeTop = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--safe-top'));
  const safeBottom = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--safe-bottom'));
  const tabContentBottom = Math.max(...[...document.querySelectorAll('.tab')].map((el) => el.getBoundingClientRect().bottom));
  const sb = document.querySelector('.sim-statusbar').getBoundingClientRect();
  const hi = document.querySelector('.sim-home-indicator').getBoundingClientRect();

  // 像素格（B）：每張像素圖顯示尺寸 = 原始尺寸 × 3
  const pxImgs = [...document.querySelectorAll('img.px-img, canvas.px-scene')];
  const pxScale = pxImgs.map((el) => {
    const r = el.getBoundingClientRect();
    const nw = el.naturalWidth || el.width, nh = el.naturalHeight || el.height;
    return { sx: Math.round((r.width / nw) * 1000) / 1000, sy: Math.round((r.height / nh) * 1000) / 1000 };
  });
  const pxScales = [...new Set(pxScale.map((p) => `${p.sx}x${p.sy}`))];

  const allSizes = [...texts.map((t) => t.fontSize), ...pxTexts.map((t) => t.pxSize)];
  return {
    lang: document.documentElement.lang,
    fontsCheck: {
      notoTC700: document.fonts.check('700 13px "Noto Sans CJK TC"'),
      notoTC900: document.fonts.check('900 13px "Noto Sans CJK TC"'),
      fontFaces: [...document.fonts].map((f) => ({ family: f.family, status: f.status })),
    },
    viewport: { w: innerWidth, h: innerHeight, dpr: devicePixelRatio },
    horizontalScroll: document.scrollingElement.scrollWidth > innerWidth,
    minFontSize: Math.min(...allSizes),
    minFontSizeText: texts.length ? Math.min(...texts.map((t) => t.fontSize)) : null,
    minPixelGlyph: pxTexts.length ? Math.min(...pxTexts.map((t) => t.pxSize)) : null,
    texts, pxTexts, clipped, outside, wrapped,
    tabs, minTab: { w: Math.min(...tabs.map((t) => t.w)), h: Math.min(...tabs.map((t) => t.h)) },
    safeArea: { top: safeTop, bottom: safeBottom, hudTop: hud.top, tabbarTop: tabbar.top, tabContentBottom, hudBelowStatusbar: hud.top >= safeTop, tabsAboveHome: tabContentBottom <= innerHeight - safeBottom + 0.5 },
    overlays: { statusbar: { cls: 'sim-statusbar', ...box(sb) }, home: { cls: 'sim-home-indicator', ...box(hi) } },
    pixelScales: pxScales, pixelImages: pxImgs.length,
    errorOverlay: !!document.querySelector('vite-error-overlay'),
  };
}

async function run(filter) {
  await mkdir(RAW, { recursive: true });
  const srv = await startServer(ROOT);
  const browser = await chromium.launch();
  const version = browser.version();
  const results = [];
  try {
    for (const j of JOBS.filter((x) => !filter || x.job.includes(filter))) {
      const ctx = await browser.newContext({ ...DEVICE, ...(j.viewport ? { viewport: j.viewport } : {}), ...(j.dpr ? { deviceScaleFactor: j.dpr } : {}) });
      const page = await ctx.newPage();
      page.setDefaultTimeout(20000);
      const errors = [];
      page.on('pageerror', (e) => errors.push(String(e)));
      page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
      await page.goto(`${srv.base}/${j.page}`, { waitUntil: 'load', timeout: 20000 });
      await page.waitForFunction(() => window.__ready === true, null, { timeout: 20000 });
      await page.evaluate(() => document.fonts.ready);
      await page.waitForTimeout(300);
      const png = join(RAW, `${j.job}.png`);
      await page.screenshot({ path: png, fullPage: !!j.gallery, timeout: 20000 });
      const meta = { job: j.job, page: j.page, browser: `chromium ${version}`, device: { ...DEVICE, ...(j.viewport ? { viewport: j.viewport } : {}), ...(j.dpr ? { deviceScaleFactor: j.dpr } : {}) }, errors };
      if (j.lineup) Object.assign(meta, await page.evaluate(measureLineup));
      else if (!j.gallery) Object.assign(meta, await page.evaluate(measure));
      await writeFile(join(RAW, `${j.job}.json`), JSON.stringify(meta, null, 2));
      if (errors.length || meta.errorOverlay) throw new Error(`${j.job}: ${errors.join(' | ') || 'error overlay'}`);
      results.push(meta);
      console.log(`ok ${j.job}${j.gallery ? '' : j.lineup ? `  min font ${meta.minFontSize}px, outside ${meta.outside.length}, figOverflow ${meta.figOverflow}, silNameOverlap ${meta.silNameOverlap}, calf ${meta.calfRatio}` : `  min font ${meta.minFontSize}px, clipped ${meta.clipped.length}, outside ${meta.outside.length}, wrapped ${meta.wrapped.length}, tab ${meta.minTab.w}x${meta.minTab.h}, hscroll ${meta.horizontalScroll}, px ${meta.pixelScales.join(',')}`}`);
      await ctx.close();
    }
  } finally {
    await browser.close();
    await srv.close();
  }
  return results;
}

const isMain = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isMain) {
  const watchdog = setTimeout(() => { console.error('capture timeout (180s)'); process.exit(2); }, 180000);
  run(process.argv[2]).then(() => { clearTimeout(watchdog); }).catch((e) => { console.error(e); process.exit(1); });
}
