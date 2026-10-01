// M2 出圖與量測：每個狀態 × 每種寬度，存 raw/<ID>__<寬>.png 與 .json。
// 430、390 用 DPR 3（送核准）；360、320 用 DPR 1（只量測）。局部狀態只截 crop 那一塊（外加 8px 邊）。
// 用法：node harness/capture.mjs [ID 前綴或逗號清單] [寬度清單，預設 430,390,360,320]
// 記憶體：跑之前先看 free -m（available ≥ 2000 MB），用 systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 包起來。
import { chromium } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { startServer } from './server.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const RAW = join(ROOT, 'raw');
const DEV = { 430: [430, 932, 3], 390: [390, 844, 3], 360: [360, 800, 1], 320: [320, 568, 1] };

// ---- 在頁面裡量 ----
function measure() {
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
  // 捲動區（.content）外面的字：捲出畫面了，看不到，不算版面問題
  const outOfView = (el, r) => {
    const c = el.closest('.content'); if (!c || getComputedStyle(c).overflowY === 'visible') return false;
    const cr = c.getBoundingClientRect(); return r.bottom <= cr.top + 1 || r.top >= cr.bottom - 1;
  };
  const hiddenTexts = texts.filter((t) => outOfView(t.el, t.rect));
  const shown = texts.filter((t) => !outOfView(t.el, t.rect));
  // 看得到的那一塊：在捲動區裡的字，只算捲動區範圍內的部分
  const visRect = (el, r) => {
    const c = el.closest('.content'); if (!c || getComputedStyle(c).overflowY === 'visible') return r;
    const cr = c.getBoundingClientRect();
    const top = Math.max(r.top, cr.top), bottom = Math.min(r.bottom, cr.bottom);
    return { left: r.left, right: r.right, top, bottom, width: r.width, height: Math.max(0, bottom - top) };
  };
  shown.forEach((t) => { t.vr = visRect(t.el, t.rect); });
  // 被截：超出 overflow 不是 visible 的祖先（含手機邊界）
  const clipped = [], truncated = [], belowFold = hiddenTexts.map((t) => t.text);
  shown.forEach((t) => {
    if (t.el.closest('[data-marquee], [data-hscroll]')) return; // 跑馬燈、橫向捲動的列本來就會切到
    for (let a = t.el.parentElement; a && a !== document.body; a = a.parentElement) {
      const cs = getComputedStyle(a);
      if (cs.overflowX !== 'visible' || cs.overflowY !== 'visible') {
        const ar = a.getBoundingClientRect(), r = t.rect;
        if (r.left < ar.left - 0.5 || r.right > ar.right + 0.5 || r.top < ar.top - 0.5 || r.bottom > ar.bottom + 0.5) {
          if (getComputedStyle(t.el).textOverflow === 'ellipsis' && a === t.el.parentElement) { truncated.push(t.text); break; }
          // 可以捲動的內容區：底下被切到只是「要往下捲才看得到」，另外記
          if (a.classList.contains('content') && r.left >= ar.left - 0.5 && r.right <= ar.right + 0.5) belowFold.push(t.text);
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
  const CONT = '.sso, .card, .btn, .badge, .tier, .toast, .dialog, .sheet, .tab, .seg button, .coins, .profile-text, .bubble, .ticker, .pen-pill, .notice, .filter button, .w-item, .gift, .cow-pop, .kv .cell, .chip-box';
  const outside = [];
  shown.forEach((t) => {
    if (t.el.closest('[data-marquee], [data-free]')) return; // 故意超出框的（例如卡片上緣的緞帶）
    const tcs = getComputedStyle(t.el);
    if (tcs.textOverflow === 'ellipsis' && tcs.overflowX !== 'visible') { if (t.el.scrollWidth > t.el.clientWidth + 1 && !truncated.includes(t.text)) truncated.push(t.text); return; } // 刻意截成「…」
    const c = t.el.closest(CONT); if (!c) return;
    const cr = c.getBoundingClientRect(), r = t.rect;
    if (r.left < cr.left - 0.5 || r.right > cr.right + 0.5 || r.top < cr.top - 0.5 || r.bottom > cr.bottom + 0.5) outside.push({ text: t.text, container: String(c.className).slice(0, 40) });
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
      const za = a.el.closest('.backdrop ~ *, .dialog, .sheet, .toast, .cow-pop, .bubble, .hud-offline, .lv-wrap, .long-off');
      const zb = b.el.closest('.backdrop ~ *, .dialog, .sheet, .toast, .cow-pop, .bubble, .hud-offline, .lv-wrap, .long-off');
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
      const OV = '.dialog, .sheet, .toast, .cow-pop, .hud-offline, .bubble, .lv-wrap, .long-off';
      if (x > 2 && y > 2 && !!t.el.closest(OV) === !!b.closest(OV)) overlaps.push([t.text, '按鈕:' + b.textContent.trim().slice(0, 10)]);
    });
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
  return {
    lang: document.documentElement.lang,
    fonts: { tc700: document.fonts.check('700 13px "Noto Sans CJK TC"'), tc900: document.fonts.check('900 13px "Noto Sans CJK TC"') },
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
  const srv = await startServer(ROOT);
  const browser = await chromium.launch();
  const summary = [];
  try {
    const lp = await (await browser.newContext()).newPage();
    await lp.goto(`${srv.base}/src/index.html?list=1`);
    await lp.waitForFunction(() => window.__ready === true, null, { timeout: 20000 });
    const all = await lp.evaluate(() => window.__states);
    await lp.context().close();
    const want = !filter ? all : all.filter((s) => filter.split(',').some((f) => s.id === f || s.id.startsWith(f)));
    // 大張的表（例如 S09-05 24 種全圖）：不是手機畫面，只出一張 DPR 2
    for (const s of want.filter((x) => x.type === 'sheet')) {
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
      const ctx = await browser.newContext({ viewport: { width: vw, height: vh }, deviceScaleFactor: dpr, isMobile: true, hasTouch: true, locale: 'zh-TW', colorScheme: 'light', reducedMotion: 'reduce' });
      const page = await ctx.newPage();
      page.setDefaultTimeout(20000);
      for (const s of want.filter((x) => x.type !== 'sheet')) {
       try {
        const errors = [];
        const onErr = (e) => errors.push(String(e));
        const onCon = (m) => { if (m.type() === 'error') errors.push(m.text()); };
        page.on('pageerror', onErr); page.on('console', onCon);
        await page.setViewportSize({ width: vw, height: vh });
        await page.goto(`${srv.base}/src/index.html?id=${encodeURIComponent(s.id)}&w=${w}`, { waitUntil: 'load' });
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
        const m = await page.evaluate(measure).catch((e) => ({ error: String(e) }));
        const meta = { id: s.id, name: s.name, note: s.note || '', screen: s.screen, screenName: s.screenName, type: s.type, tall: !!s.tall, width: w, errors, ...m };
        await writeFile(`${base}.json`, JSON.stringify(meta, null, 1));
        page.off('pageerror', onErr); page.off('console', onCon);
        const issues = ['clipped', 'outside', 'wrapped', 'overlaps', 'smallTargets', 'unsafe'].map((k) => (meta[k] || []).length);
        summary.push({ id: s.id, w, min: meta.minFontSize, issues, hscroll: meta.horizontalScroll, errors: errors.length });
        const flag = errors.length || meta.horizontalScroll || issues.some((n) => n);
        console.log(`${flag ? '!!' : 'ok'} ${s.id} ${w}  字 ${meta.minFontSize}px${(meta.belowFold || []).length ? `  要捲${meta.belowFold.length}` : ''}  截${issues[0]} 出框${issues[1]} 換行${issues[2]} 疊${issues[3]} 小鈕${issues[4]} 安全區${issues[5]}${meta.horizontalScroll ? ' 橫捲' : ''}${errors.length ? ' 錯誤:' + errors.join('|') : ''}`);
       } catch (e) {
        console.log(`!! ${s.id} ${w}  出圖失敗：${String(e).split('\n')[0]}`);
        summary.push({ id: s.id, w, failed: String(e).split('\n')[0] });
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
  const watchdog = setTimeout(() => { console.error('capture timeout (20 分)'); process.exit(2); }, 20 * 60 * 1000);
  run(filter, widths).then(() => clearTimeout(watchdog)).catch((e) => { console.error(e); process.exit(1); });
}
