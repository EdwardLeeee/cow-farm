// 整合走查（headless Chromium，v0.2 流程），每步截圖：
//   收奶 → 賣奶 → 擴建 → 商店買 C 級 → 派耕牛下田 → 收成 → 賣稻米 → 上架公牛 → 借別人公牛配種 → 出貨看評級 → 排行榜
//
// 做法：打開 Flutter 網頁版的無障礙樹（flt-semantics），照按鈕與分頁的名稱操作；賣出滑桿點卡片右緣 = 全部賣出。
// 用法（Node 18+；Playwright 只讀借用 connect4 已安裝的套件，瀏覽器用 ~/.cache/ms-playwright）：
//   free -m   # available ≥ 2000 MB 再跑
//   PLAYWRIGHT_MODULE=~/Desktop/connect4-web2-worktrees/mobile/frontend/node_modules/playwright \
//     systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 \
//     node app/tool/walk.cjs http://127.0.0.1:8787/ app/test_shots/v02
// 每次都用新的瀏覽器設定檔，所以伺服器上會多一個新的訪客牧場。
// 倍率 144 時整趟約 5–8 分鐘（大部分在等牛奶、稻米長出來換錢）。
// 環境變數：SHOT_PREFIX=xx-（截圖與紀錄檔名前綴）、EARN_LIMIT_S（每次「賺錢」最多等幾秒，預設 420）。
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const fs = require('fs');

const url = process.argv[2];
const shots = process.argv[3];
if (!url || !shots) {
  console.error('用法：node walk.cjs <網址> <截圖資料夾>');
  process.exit(2);
}
fs.mkdirSync(shots, { recursive: true });
const prefix = process.env.SHOT_PREFIX || '';
const earnLimitMs = Number(process.env.EARN_LIMIT_S || 420) * 1000;
const t0 = Date.now();
const sec = () => ((Date.now() - t0) / 1000).toFixed(1);
const log = [];
const issues = [];
const note = (s) => { const l = `[${sec()}] ${s}`; log.push(l); console.log(l); };
const issue = (s) => { issues.push(s); note(`ISSUE: ${s}`); };
const writeLog = () => fs.writeFileSync(`${shots}/${prefix}walk.log`, log.join('\n') + '\n\nISSUES:\n' + (issues.join('\n') || '(none)') + '\n');

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const ctx = await browser.newContext({ viewport: { width: 430, height: 932 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true, locale: 'zh-TW' });
  const page = await ctx.newPage();
  page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') log.push(`[${sec()}] console.${m.type()}: ${m.text().slice(0, 300)}`); });
  page.on('pageerror', (e) => issue(`pageerror: ${e.message}`));
  page.on('response', (r) => { if (r.url().includes('/v1/') && r.status() >= 400) note(`HTTP ${r.status()} ${r.request().method()} ${new URL(r.url()).pathname}`); });
  page.on('websocket', (ws) => { note('ws open'); ws.on('close', () => note('ws close')); });

  // ---- 小工具 ----
  let n = 0;
  const shot = async (name) => { n += 1; const f = `${prefix}${String(n).padStart(2, '0')}-${name}.png`; await page.screenshot({ path: `${shots}/${f}` }); note(`shot ${f}`); };
  const leaves = () => page.evaluate(() => [...document.querySelectorAll('flt-semantics')].filter((e) => !e.querySelector('flt-semantics')).map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim()).filter(Boolean));
  const fullText = () => page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map((e) => e.getAttribute('aria-label') || '').join('\n') + '\n' + (document.querySelector('flt-semantics-host')?.textContent || ''));
  const coins = async () => { const m = (await fullText()).match(/金幣 ([\d,]+)/); return m ? Number(m[1].replace(/,/g, '')) : NaN; };
  const wait = (ms) => page.waitForTimeout(ms);
  const tap = async (loc) => { await loc.dispatchEvent('click'); };
  const tab = async (name) => { await tap(page.getByRole('tab', { name, exact: true }).first()); await wait(700); };
  const button = (name) => page.getByRole('button', { name });
  const enabled = async (loc) => (await loc.count()) > 0 && (await loc.first().getAttribute('aria-disabled')) !== 'true';
  let before = [];
  const mark = async () => { before = await leaves(); };
  const snack = async () => {
    await wait(900);
    const t = await leaves();
    return t.filter((x) => !before.includes(x) && !x.includes('\n') && !x.startsWith('遊戲時間') && !x.startsWith('金幣') && !x.startsWith('【')).join(' / ') || '(沒有新訊息)';
  };
  const tapIfEnabled = async (loc, what) => {
    if (!(await enabled(loc))) { issue(`${what}：按鈕停用或找不到（金幣 ${await coins()}）`); return false; }
    await mark(); await tap(loc.first());
    note(`${what}：${await snack()}`);
    return true;
  };
  /// 點選清單中名稱完全相同的無障礙節點（chip、對話框選項）。
  const tapLabel = (label) => page.evaluate((label) => {
    const el = [...document.querySelectorAll('flt-semantics')].find((e) => !e.querySelector('flt-semantics') && (e.getAttribute('aria-label') || e.textContent || '').trim() === label);
    if (!el) return false;
    (el.closest('[flt-tappable]') || el).click();
    return true;
  }, label);

  // 賣出：市場 → 商品分頁 → 滑桿拉到最右（全部）→ 看試算 → 確認賣出
  const sellAll = async (commodity, shotName) => {
    await tab('市場');
    await tap(page.getByRole('tab', { name: commodity, exact: true }).first()).catch(() => {});
    await wait(800);
    const slider = page.getByRole('slider').first();
    if ((await slider.count()) === 0) { note(`${commodity}：倉庫沒有可以賣的`); return false; }
    const box = await slider.boundingBox();
    await page.mouse.click(400, box.y + box.height / 2); // 滑桿的 semantics 框只有一小塊；點卡片右緣 = 最大值
    await wait(1300);
    const ft = await fullText();
    const avg = ft.match(/預估成交均價\s*([\d.]+ 幣／\S+)/);
    const tot = ft.match(/預估總額 [\d,]+ 幣\s*市價 [\d.]+/);
    note(`${commodity} 試算：均價 ${avg ? avg[1] : '?'}；${tot ? tot[0] : '?'}${ft.includes('一次賣太多') ? '；顯示「一次賣太多」' : ''}`);
    if (!avg) issue(`${commodity}：試算沒有顯示均價`);
    if (shotName) await shot(shotName);
    return tapIfEnabled(button(/^確認賣出/), `賣${commodity}`);
  };

  // 賺錢：收奶＋賣奶（有稻米也收成、賣掉）直到金幣 ≥ target
  const earnUntil = async (target) => {
    const st = Date.now();
    while ((await coins()) < target && Date.now() - st < earnLimitMs) {
      await tab('牧場');
      await wait(15000);
      await mark(); await tap(button('收奶'));
      await wait(800);
      await sellAll('牛奶', '');
      note(`金幣 ${await coins()}（目標 ${target}）`);
    }
    if ((await coins()) < target) issue(`等了 ${earnLimitMs / 1000} 秒還賺不到 ${target}`);
  };

  // 牛舍滿了就先擴建
  const ensureSlot = async () => {
    await tab('商店');
    const ft = await fullText();
    const pen = ft.match(/牛舍 (\d+) \/ (\d+) 格/);
    if (!pen || Number(pen[1]) < Number(pen[2])) return;
    const mm = ft.match(/\d+ → \d+ 格・([\d,]+) 幣/);
    const cost = mm ? Number(mm[1].replace(/,/g, '')) : 600;
    note(`牛舍滿了（${pen[1]}/${pen[2]}），先擴建，費用 ${cost}`);
    await earnUntil(cost);
    await tab('商店');
    for (let i = 0; i < 20 && !(await enabled(button('擴建牛舍'))); i++) await wait(2000); // 第一次擴建要等開放
    await tapIfEnabled(button('擴建牛舍'), '擴建');
  };

  // ---- 開始 ----
  await page.goto(url, { waitUntil: 'load' });
  await wait(7000);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await wait(1500);
  if ((await leaves()).includes('連線中…')) issue('開啟 8.5 秒後仍顯示「連線中…」');
  note(`初始金幣 ${await coins()}`);
  await shot('start');

  // 1. 收奶
  await tapIfEnabled(button('收奶'), '收奶');
  await shot('collect');

  // 2. 賣奶
  await sellAll('牛奶', 'sell-milk-quote');
  await shot('sold-milk');

  // 3. 擴建
  await ensureSlot();
  await shot('expanded');

  // 4. 商店買 C 級
  await earnUntil(900);
  await tab('商店');
  await wait(800);
  note(`商店 C 級機率：${((await fullText()).match(/(用途|公母|稀有度)：[^\n]+/g) || []).slice(-3).join(' | ')}`);
  if (await tapIfEnabled(button(/^買 C 級/), '買 C 級')) {
    await wait(500);
    note(`抽到：${(await leaves()).filter((x) => x.includes('抽到') || /（牛 #\d+）/.test(x)).join(' | ')}`);
    await shot('shop-drawn');
    await tap(button('好')).catch(() => {});
    await wait(500);
  } else {
    await shot('shop');
  }

  // 5. 派耕牛下田（開局的公耕牛約 8 秒長大）
  await tab('田地');
  let assigned = false;
  for (let i = 0; i < 15 && !assigned; i++) {
    await tap(button('派耕牛').first());
    await wait(700);
    const opts = (await leaves()).filter((x) => /^牛 #\d+\s+耕牛・/.test(x));
    if (opts.length > 0) {
      await mark();
      await tapLabel(opts[0]);
      note(`派耕牛 ${opts[0]}：${await snack()}`);
      assigned = true;
    } else {
      await page.keyboard.press('Escape');
      await wait(3000);
    }
  }
  if (!assigned) issue('沒有能下田的耕牛');
  await shot('field-assigned');

  // 6. 收成（等稻米長一些）
  await wait(20000);
  await tab('田地');
  await tapIfEnabled(button(/^收成/), '收成');
  await shot('harvested');

  // 7. 賣稻米
  await sellAll('稻米', 'sell-rice-quote');
  await shot('sold-rice');

  // 8. 上架公牛：先把耕牛叫回來（在田裡不能上架），再到借種頁上架（預設第一個價位）
  await tab('田地');
  if (await enabled(button('叫回'))) await tapIfEnabled(button('叫回'), '叫回');
  await tab('配種');
  await tab('借種');
  await wait(1500);
  if (await tapIfEnabled(button('上架'), '上架公牛')) await wait(500);
  await shot('stud-listed');

  // 9. 借別人公牛配種：確保牛舍有空位、金幣夠 → 選第一筆上架 → 選第一頭能配的母牛 → 看機率 → 借種
  await ensureSlot();
  await earnUntil(300);
  await tab('配種');
  await tab('借種');
  await wait(1500);
  const ls = await leaves();
  const cut = ls.indexOf('選自己的母牛');
  const listingLabel = ls.find((x) => /・\S+・[\d,]+ 幣/.test(x) && x.includes('主人'));
  const damLabel = ls.slice(cut + 1).find((x) => /^#\d+ 乳牛|^#\d+ 耕牛|^#\d+ 肉牛/.test(x) && !x.includes('（'));
  note(`借種：選 ${listingLabel ? listingLabel.replace(/\n/g, ' ') : '(沒有上架)'}，母牛 ${damLabel || '(沒有)'}`);
  if (listingLabel) await tapLabel(listingLabel);
  await wait(500);
  if (damLabel) await tapLabel(damLabel);
  await wait(1500);
  const ft = await fullText();
  note(`借種預覽：${(ft.match(/費用 [\d,]+ 幣/) || ['?'])[0]}；${(ft.match(/小牛用途：[^\n]+/) || ['?'])[0]}`);
  await shot('stud-preview');
  await tapIfEnabled(button(/^借種（/), '借種');
  await shot('stud-borrowed');

  // 10. 出貨看評級：從牧場最後一頭牛往前找第一頭能出貨的
  await tab('牧場');
  const cards = await page.getByRole('button', { name: /^.*牛 #\d+/ }).all();
  let shipped = false;
  for (let i = cards.length - 1; i >= 0 && !shipped; i--) {
    await tab('牧場');
    const c = page.getByRole('button', { name: /^.*牛 #\d+/ }).nth(i);
    if ((await c.count()) === 0) continue;
    await tap(c);
    await wait(700);
    if (await enabled(button('出貨'))) {
      await shot('cow-detail');
      await tap(button('出貨').first());
      await wait(1500);
      const t = await fullText();
      note(`出貨評級機率：${(t.match(/[ABC] 級 [\d.]+%　收入約 [\d,]+ 幣/g) || []).join(' | ')}`);
      await shot('ship-grade-probs');
      await mark(); await tap(button('確定'));
      await wait(1500);
      const r = await fullText();
      note(`出貨結果：${(r.match(/評級：[ABC] 級/) || ['?'])[0]}；${(r.match(/[\d.]+ 公斤牛肉放進倉庫，現在全部賣掉約 [\d,]+ 幣/) || [''])[0]}`);
      await shot('ship-result');
      await tap(button('好')).catch(() => {});
      shipped = true;
    } else {
      await tap(button('返回')).catch(() => {});
      await wait(500);
    }
  }
  if (!shipped) issue('找不到能出貨的牛');

  // 11. 排行榜
  await tab('紀錄');
  await tab('排行榜');
  await wait(1500);
  note(`排行榜：${((await fullText()).match(/我的名次：[^\n]+/) || ['?'])[0]}`);
  await shot('leaderboard');

  writeLog();
  await browser.close();
  console.log(`done, issues=${issues.length}`);
})().catch((e) => { console.error(e); log.push(`FATAL ${e}`); writeLog(); process.exit(1); });
