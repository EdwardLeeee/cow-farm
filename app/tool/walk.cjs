// 整合走查（headless Chromium）：收奶 → 賣奶 →（牛舍滿就擴建）→ 買小牛 → 配種 → 出貨 → 排行榜，每步截圖。
//
// 做法：打開 Flutter 網頁版的無障礙樹（flt-semantics），照按鈕名稱操作；滑桿點卡片右緣 = 全部賣出。
// 用法（Node 18+；Playwright 只讀借用 connect4 已安裝的套件，瀏覽器用 ~/.cache/ms-playwright）：
//   free -m   # available ≥ 2000 MB 再跑
//   PLAYWRIGHT_MODULE=~/Desktop/connect4-web2-worktrees/mobile/frontend/node_modules/playwright \
//     systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 \
//     node tool/walk.cjs http://127.0.0.1:8787/ test_shots
// 選項（環境變數）：
//   SKIP_BUY=1          不買小牛（省下賺 1,000 金幣的幾分鐘）
//   STOP_AFTER_BREED=1  配種完就停
//   SHOT_PREFIX=xx-     截圖與紀錄檔名前綴
// 倍率 144 時，新玩家要賺到 1,000 金幣買小牛約需 3–4 分鐘（每 20 秒收奶＋賣一次）。
const { chromium } = require(process.env.PLAYWRIGHT_MODULE);
const fs = require('fs');
const url = process.argv[2], shots = process.argv[3];
const t0 = Date.now();
const sec = () => ((Date.now() - t0) / 1000).toFixed(1);
const log = [];
const issues = [];
const note = (s) => { const l = `[${sec()}] ${s}`; log.push(l); console.log(l); };
const issue = (s) => { issues.push(s); note(`ISSUE: ${s}`); };

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const ctx = await browser.newContext({ viewport: { width: 430, height: 932 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true, locale: 'zh-TW' });
  const page = await ctx.newPage();
  page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') log.push(`[${sec()}] console.${m.type()}: ${m.text().slice(0, 300)}`); });
  page.on('pageerror', (e) => issue(`pageerror: ${e.message}`));
  page.on('response', (r) => { if (r.url().includes('/v1/') && r.status() >= 400) log.push(`[${sec()}] HTTP ${r.status()} ${r.request().method()} ${r.url()}`); });
  page.on('websocket', (ws) => { note(`ws open ${ws.url().replace(/token=[^&]+/, 'token=…')}`); ws.on('close', () => note('ws close')); });

  let n = 0;
  const prefix = process.env.SHOT_PREFIX || '';
  const shot = async (name) => { n += 1; const f = `${prefix}${String(n).padStart(2, '0')}-${name}.png`; await page.screenshot({ path: `${shots}/${f}` }); note(`shot ${f}`); };
  const texts = () => page.evaluate(() => [...document.querySelectorAll('flt-semantics')].filter((e) => !e.querySelector('flt-semantics')).map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim()).filter(Boolean));
  const fullText = () => page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map((e) => e.getAttribute('aria-label') || '').join('\n') + '\n' + (document.querySelector('flt-semantics-host')?.textContent || ''));
  const coins = async () => { const t = (await texts()).find((s) => s.startsWith('金幣 ')); return t ? Number(t.slice(3).replace(/,/g, '')) : NaN; };
  const tap = async (loc) => { await loc.dispatchEvent('click'); };
  const tab = async (name) => { await tap(page.getByRole('tab', { name, exact: true }).first()); await page.waitForTimeout(700); };
  const button = (name) => page.getByRole('button', { name });
  let before = [];
  const mark = async () => { before = await texts(); };
  const snack = async () => { await page.waitForTimeout(900); const t = await texts(); return t.filter((x) => !before.includes(x) && !x.includes('\n') && !x.startsWith('遊戲時間') && !x.startsWith('金幣') && !x.startsWith('【')).join(' / ') || '(沒有新訊息)'; };
  const enabled = async (loc) => (await loc.count()) > 0 && (await loc.first().getAttribute('aria-disabled')) !== 'true';

  await page.goto(url, { waitUntil: 'load' });
  await page.waitForTimeout(7000);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1500);
  const offline = (await texts()).includes('連線中…');
  if (offline) issue('開啟 8.5 秒後仍顯示「連線中…」');
  note(`初始金幣 ${await coins()}`);
  await shot('start');

  // 1. 收奶
  await mark(); await tap(button('收奶'));
  note(`收奶結果：${await snack()}`);
  await shot('collect');

  // 2. 賣奶（拉到最右邊 = 全部）
  const sellAll = async (label) => {
    await tab('市場');
    await tap(page.getByRole('tab', { name: '牛奶' }).first()).catch(() => {});
    await page.waitForTimeout(500);
    const slider = page.getByRole('slider').first();
    if ((await slider.count()) === 0) { note('沒有滑桿（倉庫可能沒有牛奶）'); return false; }
    const box = await slider.boundingBox();
    // 滑桿的 semantics 框只有一小塊；直接點卡片右緣（超過軌道就是最大值）
    await page.mouse.click(400, box.y + box.height / 2);
    await page.waitForTimeout(1300);
    const ft = await fullText();
    const avg = /預估總額/.test(ft);
    const m1 = ft.match(/預估成交均價\s*([\d.]+ 幣／瓶)/), m2 = ft.match(/預估總額 [\d,]+ 幣\s*市價 [\d.]+/), warn = ft.includes('一次賣太多');
    note(`${label} 試算：均價 ${m1 ? m1[1] : '?'}；${m2 ? m2[0] : '?'}${warn ? '；顯示「一次賣太多」' : ''}`);
    if (label) await shot(label);
    const confirm = button(/^確認賣出/);
    if (!(await enabled(confirm))) { issue('確認賣出按鈕停用'); return false; }
    await mark(); await tap(confirm.first());
    note(`賣出結果：${await snack()}`);
    return !!avg;
  };
  if (!(await sellAll('sell-quote'))) issue('賣奶試算沒有顯示均價');
  await shot('sold');

  // 3. 賺錢：收奶＋賣奶循環（每次最多 4 分鐘）
  const earnUntil = async (target) => {
    const st = Date.now();
    while ((await coins()) < target && Date.now() - st < 420000) {
      await tab('牧場');
      await page.waitForTimeout(20000);
      await mark(); await tap(button('收奶'));
      await page.waitForTimeout(800);
      await sellAll('');
      note(`金幣 ${await coins()}（目標 ${target}）`);
    }
  };
  const penInfo = async () => { await tab('商店'); const t = (await texts()).find((x) => /^牛舍 \d+ \/ \d+ 格$/.test(x)); const m = t && t.match(/(\d+) \/ (\d+)/); return m ? { used: +m[1], slots: +m[2] } : null; };
  const ensureSlot = async () => {
    const p = await penInfo();
    if (!p || p.used < p.slots) return;
    const ft = await fullText();
    const mm = ft.match(/\d+ → \d+ 格・([\d,]+) 幣/);
    const cost = mm ? Number(mm[1].replace(/,/g, '')) : 600;
    const info = mm ? mm[0] : '';
    note(`牛舍滿了（${p.used}/${p.slots}），先擴建，費用約 ${cost}（${info || ''}）`);
    await earnUntil(cost);
    await tab('商店');
    for (let i = 0; i < 20; i++) { if (await enabled(button('擴建牛舍'))) break; await page.waitForTimeout(2000); }
    await mark(); await tap(button('擴建牛舍'));
    note(`擴建：${await snack()}`);
  };
  await ensureSlot();
  if (process.env.SKIP_BUY !== '1') {
    await earnUntil(1000);
    await tab('商店');
    const buy = button(/^乳用 母/);
    if (!(await enabled(buy))) issue(`買小牛按鈕停用（金幣 ${await coins()}）`);
    else { await mark(); await tap(buy.first()); note(`買小牛：${await snack()}`); }
    await shot('buy-calf');
  }

  // 4. 配種：選第一頭公牛、第一頭母牛
  await ensureSlot();
  await tab('配種');
  await page.waitForTimeout(500);
  // 候選 chip：在「選母牛」之前的是公牛，之後的是母牛
  const chips = async () => page.evaluate(() => {
    const leaves = [...document.querySelectorAll('flt-semantics')].filter((e) => !e.querySelector('flt-semantics')).map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim());
    const cut = leaves.indexOf('選母牛');
    const isChip = (x) => /^#\S+ /.test(x);
    return { sires: leaves.slice(0, cut).filter(isChip), dams: leaves.slice(cut + 1).filter(isChip) };
  });
  const pickChip = async (label) => page.evaluate((label) => {
    const el = [...document.querySelectorAll('flt-semantics')].find((e) => !e.querySelector('flt-semantics') && (e.getAttribute('aria-label') || e.textContent || '').trim() === label);
    if (!el) return false;
    (el.closest('[flt-tappable]') || el).click();
    return true;
  }, label);
  let c = await chips();
  // 等公牛長大、冷卻結束（最多 60 秒）
  for (let i = 0; i < 30 && (!c.sires.some((x) => !x.includes('冷卻中')) || !c.dams.some((x) => !x.includes('冷卻中'))); i++) { await page.waitForTimeout(2000); c = await chips(); }
  note(`配種候選：公 ${c.sires.join(' ; ')}｜母 ${c.dams.join(' ; ')}`);
  const sire = c.sires.find((x) => !x.includes('冷卻中')), dam = c.dams.find((x) => !x.includes('冷卻中'));
  const sireOk = !!sire && (await pickChip(sire));
  await page.waitForTimeout(400);
  const damOk = !!dam && (await pickChip(dam));
  if (!sireOk || !damOk) issue(`配種選不到公牛或母牛`);
  await page.waitForTimeout(1200);
  note(`配種預覽：${(await texts()).filter((s) => s.includes('%') || s.includes('費用')).join(' | ').replace(/\n/g, ' ')}`);
  await shot('breed-preview');
  const go = button('配種');
  if (!(await enabled(go))) issue('配種按鈕停用');
  else { await mark(); await tap(go.last()); note(`配種結果：${await snack()}`); }
  await page.waitForTimeout(800);
  await shot('breed-countdown');

  if (process.env.STOP_AFTER_BREED === '1') {
    fs.writeFileSync(`${shots}/${process.env.SHOT_PREFIX || ""}walk.log`, log.join('\n') + '\n\nISSUES:\n' + (issues.join('\n') || '(none)') + '\n');
    await browser.close();
    console.log(`done, issues=${issues.length}`);
    return;
  }

  // 5. 出貨：牧場 → 公牛的卡片 → 出貨
  await tab('牧場');
  const bullCard = page.getByRole('button', { name: /・公・成年/ });
  if ((await bullCard.count()) === 0) issue('找不到成年公牛可出貨');
  else {
    await tap(bullCard.first());
    await page.waitForTimeout(700);
    await shot('cow-detail');
    await tap(button('出貨').first());
    await page.waitForTimeout(700);
    note(`出貨確認：${(await texts()).filter((s) => s.includes('估值')).join(' | ')}`);
    await shot('ship-confirm');
    await mark(); await tap(button('確定'));
    note(`出貨結果：${await snack()}`);
    await shot('shipped');
  }

  // 6. 排行榜
  await tab('排行');
  await page.waitForTimeout(1500);
  note(`排行榜：${(await texts()).filter((s) => s.includes('我的名次') || s.includes('電腦')).slice(0, 4).join(' | ').replace(/\n/g, ' ')}`);
  await shot('leaderboard');

  // 7. 圖鑑、市場牛肉頁
  await tab('圖鑑');
  await shot('codex');
  await tab('市場');
  await tap(page.getByRole('tab', { name: '牛肉' }).first()).catch(() => {});
  await page.waitForTimeout(800);
  await shot('market-beef');

  fs.writeFileSync(`${shots}/${process.env.SHOT_PREFIX || ""}walk.log`, log.join('\n') + '\n\nISSUES:\n' + (issues.join('\n') || '(none)') + '\n');
  await browser.close();
  console.log(`done, issues=${issues.length}`);
})().catch((e) => { console.error(e); fs.writeFileSync(`${shots}/${process.env.SHOT_PREFIX || ""}walk.log`, log.join('\n') + `\nFATAL ${e}\n`); process.exit(1); });
