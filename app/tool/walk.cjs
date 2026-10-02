// 整合走查（headless Chromium，正式畫面 + 還沒換掉的 M1 分頁），每步截圖：
//   開新牧場（S02 取名、歡迎）→ 收奶 → 賣奶（S06）→ 擴建牛舍、加大奶桶（S10）→ 抽 C 級（S19）→
//   等小牛長大 → 出貨（S04 → S07 → A-03 卡車 → S20）→ 田地（S17）：派耕牛、收成 → 賣稻米 → 叫回耕牛 →
//   借種（S18）：上架、借別人的公牛、借種紀錄 → 圖鑑、排行榜（M1）→
//   另開一個新牧場（新的瀏覽器設定檔）：收奶賣奶、擴建牛舍 → 自己配種（S08）：開局的公母配、機率、新小牛、已配種
//
// 做法：打開 Flutter 網頁版的無障礙樹（flt-semantics），照按鈕的名字操作。正式畫面的分頁、配種頁上面的
// 「自己配種／借種」都是按鈕；M1 畫面裡的次分頁（圖鑑／排行榜）是 tab。頂列的金幣沒有名字，讀「設定」前面最後一個數字。
// 用法（Node 18+；Playwright 只讀借用 connect4 已安裝的套件，瀏覽器用 ~/.cache/ms-playwright）：
//   free -m   # available ≥ 2000 MB 再跑
//   PLAYWRIGHT_MODULE=~/Desktop/connect4-web2-worktrees/mobile/frontend/node_modules/playwright \
//     systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 \
//     node app/tool/walk.cjs http://127.0.0.1:8790/ app/build/walk
// 每次都用新的瀏覽器設定檔，所以伺服器上會多一個新的牧場（從 S02 取名開始）。不要對試玩的 8787 跑。
// 倍率 144 時整趟約 5–10 分鐘（大部分在等牛奶、稻米長出來換錢）。
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
const steps = [];
const note = (s) => { const l = `[${sec()}] ${s}`; log.push(l); console.log(l); };
const issue = (s) => { issues.push(s); note(`ISSUE: ${s}`); };
const writeLog = () => fs.writeFileSync(
  `${shots}/${prefix}walk.log`,
  `${log.join('\n')}\n\nSTEPS:\n${steps.join('\n')}\n\nISSUES:\n${issues.join('\n') || '(none)'}\n`,
);

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  /// 新的瀏覽器設定檔（新的訪客 token），開一個分頁並記下錯誤、HTTP 4xx／5xx、WebSocket。
  const newPage = async () => {
    const ctx = await browser.newContext({ viewport: { width: 430, height: 932 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true, locale: 'zh-TW' });
    const p = await ctx.newPage();
    p.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') log.push(`[${sec()}] console.${m.type()}: ${m.text().slice(0, 300)}`); });
    p.on('pageerror', (e) => issue(`pageerror: ${e.message}`));
    p.on('response', (r) => { if (r.url().includes('/v1/') && r.status() >= 400) note(`HTTP ${r.status()} ${r.request().method()} ${new URL(r.url()).pathname}`); });
    p.on('websocket', (ws) => { note('ws open'); ws.on('close', () => note('ws close')); });
    return p;
  };
  /// 現在操作的分頁。第 11 步（自己配種）換一個新的瀏覽器設定檔，所以是 let；下面的小工具都讀這個變數。
  let page = await newPage();

  // ---- 小工具 ----
  let n = 0;
  const shot = async (name) => { n += 1; const f = `${prefix}${String(n).padStart(2, '0')}-${name}.png`; await page.screenshot({ path: `${shots}/${f}` }); note(`shot ${f}`); return f; };
  /// 無障礙樹的節點（照文件順序）：role、名字、停用。
  const nodes = () => page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map((e) => ({
    role: e.getAttribute('role') || '',
    label: (e.getAttribute('aria-label') || (e.querySelector('flt-semantics') ? '' : e.textContent) || '').trim(),
    disabled: e.getAttribute('aria-disabled') === 'true',
  })).filter((x) => x.label));
  const labels = async () => (await nodes()).map((x) => x.label);
  const fullText = async () => (await labels()).join('\n');
  /// 頂列的金幣：一般在「設定」前面（牧場名、Lv、經驗、金幣、設定）；牧場分頁的頂列疊在場景上，
  /// 無障礙樹照位置排成「設定」在最前面，這時金幣是後面幾個裡的第一個數字。
  const coins = async () => {
    const all = await nodes();
    const end = all.findIndex((x) => x.role === 'button' && x.label === '設定');
    const isNum = (l) => /^[\d,.]+萬?$/.test(l);
    const before = all.slice(0, end < 0 ? 8 : end).map((x) => x.label).filter(isNum);
    const after = end < 0 ? [] : all.slice(end + 1, end + 5).map((x) => x.label).filter(isNum);
    const l = before.length ? before[before.length - 1] : after[0];
    if (!l) return NaN;
    return l.endsWith('萬') ? Math.round(parseFloat(l) * 10000) : Number(l.replace(/,/g, ''));
  };
  const wait = (ms) => page.waitForTimeout(ms);
  const tap = async (loc) => { await loc.dispatchEvent('click'); };
  const button = (name) => page.getByRole('button', { name, exact: typeof name === 'string' });
  const enabled = async (loc) => (await loc.count()) > 0 && (await loc.first().getAttribute('aria-disabled')) !== 'true';
  /// 場主升級慶祝（S11-01）：跳出來就記下升到幾級，按「好」關掉（在哪一頁升級就在哪一頁跳）。
  const levelUps = [];
  const closeLevelUp = async () => {
    const all = await labels();
    if (!all.includes('場主升級')) return;
    const i = all.indexOf('Lv');
    levelUps.push(i >= 0 ? `Lv ${all[i + 1]}` : '?');
    await shot(`level-up-${levelUps.length}`);
    await tap(button('好').first());
    await wait(600);
  };
  const tab = async (name) => { await closeLevelUp(); await tap(button(name).last()); await wait(900); };
  const subTab = async (name) => { await tap(page.getByRole('tab', { name, exact: true }).first()); await wait(900); };
  let before = [];
  const mark = async () => { before = await labels(); };
  /// 按下去之後多出來的字（提示、對話框）。
  const news = async () => {
    await wait(1000);
    await closeLevelUp();
    const now = await labels();
    return now.filter((x) => !before.includes(x) && !x.includes('\n') && !/^[\d,.]+萬?$/.test(x)).slice(0, 6).join(' / ') || '(沒有新訊息)';
  };
  const tapIfEnabled = async (loc, what) => {
    if (!(await enabled(loc))) { issue(`${what}：按鈕停用或找不到（金幣 ${await coins()}）`); return false; }
    await mark(); await tap(loc.first());
    note(`${what}：${await news()}`);
    return true;
  };
  /// 清單只建畫面附近的元件，捲出去太遠的不在無障礙樹裡（市場的公牛一多，下面的母牛、借種鈕就找不到）：
  /// 往下捲到 [has] 成立為止；scrollTop 捲回最上面。
  const scrollUntil = async (has, max = 10) => {
    await page.mouse.move(215, 600);
    for (let k = 0; k < max; k++) {
      if (await has()) return true;
      await page.mouse.wheel(0, 400);
      await wait(600);
    }
    return has();
  };
  const scrollTop = async () => { await page.mouse.move(215, 400); await page.mouse.wheel(0, -8000); await wait(800); };
  const step = (name, ok, detail = '') => { steps.push(`${ok ? '過' : '沒過'}  ${name}${detail ? `：${detail}` : ''}`); note(`STEP ${ok ? 'OK' : 'FAIL'} ${name} ${detail}`); };
  /// 點清單、對話框裡的一個選項（M1 畫面）：名字裡的空白、換行都當成一個空白比對。
  const tapLabel = async (label) => {
    const re = new RegExp(`^${label.trim().split(/\s+/).map((w) => w.replace(/[.*+?^${}()|[\]\\#]/g, '\\$&')).join('\\s+')}$`);
    // M1 的選項有的是按鈕，有的是可以勾的（FilterChip 是 checkbox）：找得到哪一種就點哪一種
    for (const role of ['button', 'checkbox', 'radio', 'option', 'tab']) {
      const loc = page.getByRole(role, { name: re });
      if (await loc.count()) { await tap(loc.last()); return true; }
    }
    const loc = page.getByText(re);
    if (!(await loc.count())) return false;
    await tap(loc.last());
    return true;
  };

  // 賣出：市場 → 點那一列商品 → 「全部」→ 「確認賣出」
  const sellAll = async (commodity, shotName) => {
    await tab('市場');
    await tap(button(new RegExp(`^${commodity}\\s`)).first()).catch(() => {});
    await wait(1500);
    const ft = await fullText();
    if (ft.includes(`倉庫裡沒有${commodity}可以賣`)) { note(`${commodity}：倉庫沒有可以賣的`); return false; }
    await tap(button('全部')).catch(() => {});
    await wait(1500);
    const base = (ft.match(/平常（基本價）：[^\n]+/) || ['?'])[0];
    if (base.includes('–')) issue(`市場「${base}」沒有基本價`);
    const est = (await fullText()).match(/預估總額\n([\d,]+ 幣)/);
    note(`${commodity} 試算：${est ? est[1] : '?'}；${base}`);
    if (shotName) await shot(shotName);
    const c0 = await coins();
    const ok = await tapIfEnabled(button(/^確認賣出/), `賣${commodity}`);
    await wait(800);
    note(`金幣 ${c0} → ${await coins()}`);
    return ok;
  };

  // 賺錢：收奶＋賣奶直到金幣 ≥ target
  const earnUntil = async (target) => {
    const st = Date.now();
    while ((await coins()) < target && Date.now() - st < earnLimitMs) {
      await tab('牧場');
      await wait(12000);
      if (await enabled(button('收奶'))) await tap(button('收奶'));
      await wait(800);
      await sellAll('牛奶', '');
      note(`金幣 ${await coins()}（目標 ${target}）`);
    }
    if ((await coins()) < target) issue(`等了 ${earnLimitMs / 1000} 秒還賺不到 ${target}`);
    return (await coins()) >= target;
  };

  /// 一列的價格鈕（設施、抽牛的卡片）：一列的字是一個節點（其中一行是 [title]，例「擴建牛舍」「C 級」），
  /// 價格鈕（「280 幣」）是同一列高度裡的另一顆按鈕。按鈕自己一個無障礙節點，不會跟列的字併在一起。
  const rowButton = async (title) => {
    const rows = await page.evaluate((t) => [...document.querySelectorAll('flt-semantics')]
      .filter((e) => e.getAttribute('role') !== 'button')
      .map((e) => ({ label: (e.getAttribute('aria-label') || (e.querySelector('flt-semantics') ? '' : e.textContent) || ''), r: e.getBoundingClientRect() }))
      .filter((x) => x.label.split('\n').some((l) => l.trim() === t))
      .map((x) => ({ y: x.r.top, h: x.r.height })), title);
    if (!rows.length) return null;
    const row = rows[0];
    const btns = page.getByRole('button', { name: /^[\d,]+ 幣$/ });
    for (let i = 0; i < (await btns.count()); i++) {
      const bb = await btns.nth(i).boundingBox();
      if (bb && bb.y >= row.y - 4 && bb.y + bb.height <= row.y + row.h + 4) return btns.nth(i);
    }
    return null;
  };
  const rowPrice = async (loc) => {
    const label = (await loc.getAttribute('aria-label')) || (await loc.textContent()) || '';
    return Number(((label.match(/([\d,]+) 幣\s*$/) || [])[1] || '0').replace(/,/g, ''));
  };

  // 商店的設施（S10）：例「擴建牛舍」那一列的價格鈕
  const upgrade = async (what) => {
    const open = async () => { await tab('商店'); await tap(button('設施')); await wait(1200); };
    await open();
    let b = await rowButton(what);
    const price = b ? await rowPrice(b) : 0;
    if (!price) { issue(`${what}：找不到價格`); return false; }
    if (!(await earnUntil(price))) return false;
    await open();
    for (let i = 0; i < 20; i++) { // 第一次擴建要等開放
      b = await rowButton(what);
      if (b && (await enabled(b))) break;
      await wait(2000);
    }
    return b ? tapIfEnabled(b, what) : false;
  };

  /// 開新牧場：S02「幫我想一個」→「就叫這個」→ 歡迎 →「進牧場」。回傳歡迎卡的字。
  const newRanch = async () => {
    await page.goto(url, { waitUntil: 'load' });
    await wait(7000);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await wait(1500);
    await shot('s02-name');
    await tap(button('幫我想一個'));
    await wait(600);
    await mark(); await tap(button('就叫這個'));
    await wait(4000);
    const welcome = (await labels()).find((x) => x.startsWith('歡迎來到')) || '';
    await shot('welcome');
    await tap(button('進牧場')).catch(() => {});
    await wait(2500);
    if ((await labels()).includes('連線中…')) issue('進牧場後顯示「連線中…」');
    return welcome;
  };

  // ---- 1. 開新牧場（S02 取名 → 歡迎）----
  const welcome = await newRanch();
  step('開新牧場（取名、歡迎）', welcome !== '', welcome.replace(/\n/g, ' '));
  note(`初始金幣 ${await coins()}`);
  await shot('ranch');

  // ---- 2. 收奶 ----
  const collected = await tapIfEnabled(button('收奶'), '收奶');
  await shot('collect');
  step('收奶', collected, (await labels()).find((x) => x.startsWith('收了')) || '');

  // ---- 3. 賣奶（S06）----
  const c3 = await coins();
  await sellAll('牛奶', 'sell-milk-quote');
  await shot('sold-milk');
  step('賣奶（S06）', (await coins()) > c3, `金幣 ${c3} → ${await coins()}`);

  // ---- 4. 設施（S10）：擴建牛舍（開局牛舍是滿的）、加大奶桶 ----
  const penOk = await upgrade('擴建牛舍');
  await shot('pen-expanded');
  step('擴建牛舍（S10）', penOk, (await labels()).find((x) => x.includes('升級完成')) || '');
  const bucketOk = await upgrade('加大奶桶');
  await shot('bucket-upgraded');
  step('加大奶桶（S10）', bucketOk, (await labels()).find((x) => x.includes('升級完成')) || '');

  // ---- 5. 抽 C 級（S19）----
  let drawn = '';
  if (await earnUntil(900)) {
    await tab('商店');
    await tap(button('抽牛'));
    await wait(1500);
    const buyC = await rowButton('C 級');
    if (buyC && (await tapIfEnabled(buyC, '抽 C 級'))) {
      // 抽到的牛的對話框有時候過幾秒才出來（伺服器忙的時候）：最多等 15 秒
      for (let k = 0; k < 15 && !drawn; k++) {
        drawn = (await labels()).find((x) => /^\S+ #\d+$/.test(x) && !before.includes(x)) || '';
        if (!drawn) await wait(1000);
      }
      await shot('shop-drawn');
      await tap(button('好')).catch(() => {});
      await wait(600);
    }
  }
  step('抽 C 級（S19）', drawn !== '', drawn);

  // ---- 6. 出貨（S04 → S07 → S20）：等抽到的小牛長大，從牛舍清單點它 ----
  let shipped = '';
  const openCowFromList = async (name) => {
    await tab('牧場');
    await tap(button(/^我的牛/));
    await wait(1200);
    const row = button(new RegExp(`^${name.replace(/[#()]/g, '\\$&')}\\s`));
    if (!(await row.count())) return false;
    await tap(row.first());
    await wait(1200);
    return true;
  };
  if (drawn) {
    for (let i = 0; i < 12 && !shipped; i++) {
      if (!(await openCowFromList(drawn))) { issue(`牛舍清單找不到 ${drawn}`); break; }
      if (!(await enabled(button('出貨')))) {
        note(`${drawn} 還不能出貨，等一下`);
        await tap(button('返回')).catch(() => {});
        await wait(8000);
        continue;
      }
      await shot('cow-detail');
      await tap(button('出貨'));
      await wait(2500);
      const conf = await fullText();
      note(`出貨確認：${(conf.match(/[ABC] 級\n[\d.]+%/g) || []).map((x) => x.replace('\n', ' ')).join(' | ')}；${(conf.match(/期望收入[^\n]*/) || ['?'])[0]}`);
      await shot('ship-confirm');
      if (!(await enabled(button('確定出貨')))) { issue('出貨確認：「確定出貨」停用'); break; }
      await mark(); await tap(button('確定出貨'));
      // A-03 出貨卡車：播 3.6 秒（畫面上有「點一下跳過」），播完換成評級結果（S20）
      await wait(1500);
      const truck = (await labels()).includes('點一下跳過');
      await shot('ship-truck');
      step('出貨卡車（A-03）', truck, truck ? '播到一半：有「點一下跳過」' : '沒看到卡車那一幕');
      let res = '';
      for (let i = 0; i < 16 && !/出貨評級/.test(res); i++) { await wait(500); res = await fullText(); }
      const grade = (res.match(/[^\n]*出貨評級/) || [''])[0];
      const kg = (res.match(/[\d,.]+ 公斤牛肉放進倉庫了/) || [''])[0];
      if (grade && kg) shipped = `${grade}；${kg}；${(res.match(/現在全部賣掉約 [\d,]+ 幣/) || ['?'])[0]}`;
      else issue('出貨：卡車播完後沒有看到評級結果（S20）');
      await shot('ship-result');
      await tap(button('好')).catch(() => {});
      await wait(800);
    }
  }
  step('出貨（S04 → S07 → S20）', shipped !== '', shipped);

  // ---- 7. 田地（S17）：空田按「派耕牛」→ 面板預選第一頭能下田的 →「派去田裡」；等稻米長一些再收成 ----
  // 開局的小公牛（台灣黃牛 #2）20 遊戲分鐘後長大才能下田：「派耕牛」停用就等一下再試
  await tab('田地');
  let assigned = '';
  for (let i = 0; i < 10 && !assigned; i++) {
    const go = button('派耕牛');
    await scrollUntil(async () => (await go.count()) > 0, 4);
    if (!(await enabled(go))) { note('「派耕牛」停用（還沒有能下田的耕牛），等一下'); await wait(4000); await tab('田地'); continue; }
    await tap(go.first());
    await wait(1200);
    // 面板的每一頭是一顆按鈕；能下田的寫「每小時 …」，預選的是第一頭
    const opt = (await nodes()).find((x) => x.role === 'button' && /#\d+/.test(x.label) && x.label.includes('每小時'));
    await shot('field-pick-ox');
    await mark();
    if (!(await tapIfEnabled(button('派去田裡'), '派去田裡'))) break;
    await wait(1500);
    await scrollTop();
    const recall = button('叫回');
    await scrollUntil(async () => (await recall.count()) > 0, 4);
    if (await recall.count()) assigned = opt ? opt.label.replace(/\n/g, ' ') : '（面板裡的第一頭）';
    else issue(`派去田裡以後沒有「叫回」：${await news()}`);
  }
  await scrollTop();
  await shot('field-assigned');
  step('派耕牛（S17）', assigned !== '', assigned);
  await wait(20000);
  await tab('田地');
  await mark();
  const harvested = await tapIfEnabled(button(/^收成（田裡約/), '收成');
  await shot('harvested');
  step('收成（S17）', harvested, (await labels()).find((x) => x.startsWith('收成了')) || '');

  // ---- 8. 賣稻米（S06）----
  const c8 = await coins();
  await sellAll('稻米', 'sell-rice-quote');
  await shot('sold-rice');
  step('賣稻米（S06）', (await coins()) > c8, `金幣 ${c8} → ${await coins()}`);

  // ---- 9. 借種（S18）：叫回耕牛（在田裡不能上架）→ 上架 → 借別人的公牛給自己的母牛 → 借種紀錄 ----
  const studTab = async () => { await tab('配種'); await tap(button('借種').first()); await wait(2500); };
  /// 市場的每一列是一顆按鈕，名字是整列的字（品種名公、用途、稀有度、主人：…），單獨一行的數字是借種費。
  const listingRows = async () => (await nodes())
    .filter((x) => x.role === 'button' && x.label.includes('主人：'))
    .map((x) => ({ label: x.label, price: Number((x.label.split('\n').map((l) => l.trim()).filter((l) => /^[\d,]+$/.test(l)).pop() || 'NaN').replace(/,/g, '')) }));
  await tab('田地');
  await scrollUntil(async () => (await button('叫回').count()) > 0, 4);
  if (await enabled(button('叫回'))) await tapIfEnabled(button('叫回'), '叫回');
  await studTab();
  const listed = await tapIfEnabled(button('上架'), '上架公牛');
  await wait(1000);
  const unlistShown = (await button('下架').count()) > 0;
  await shot('stud-listed');
  step('上架公牛（S18）', listed && unlistShown, unlistShown ? '我的公牛那一列換成「下架」' : '沒看到「下架」');

  /// 「選自己的母牛」底下第一頭能選的母牛。
  const damRow = async () => {
    const all = await nodes();
    const cut = all.findIndex((x) => x.label === '選自己的母牛');
    return (cut < 0 ? null : all.slice(cut + 1).find((x) => x.role === 'button' && /#\d+/.test(x.label) && !x.disabled)) || null;
  };

  const rows0 = await listingRows();
  const cheapest = Math.min(...rows0.map((r) => r.price).filter((p) => p > 0));
  note(`借種市場（畫面上看得到的）${rows0.length} 頭：${rows0.map((r) => r.price).join('、')} 幣`);
  await earnUntil((Number.isFinite(cheapest) ? cheapest : 500) + 100);
  let borrowed = '';
  // 等賺錢的時候，挑好的那頭可能被別人借走（S18-10）或長大變貴（S18-12）：最多試三頭
  for (let attempt = 0; attempt < 3 && !borrowed; attempt++) {
    await studTab();
    const c = await coins();
    const pick = (await listingRows()).filter((r) => r.price > 0 && r.price <= c).sort((a, b) => a.price - b.price)[0];
    if (!pick) { issue(`借種：沒有付得起的公牛（金幣 ${c}）`); break; }
    await tapLabel(pick.label);
    await wait(1500);
    await scrollUntil(async () => (await damRow()) !== null);
    const dam = await damRow();
    note(`借種：選 ${pick.label.replace(/\n/g, ' ')}，母牛 ${dam ? dam.label.replace(/\n/g, ' ') : '(沒有)'}`);
    if (!dam) { issue('借種：沒有能借種的母牛（捲到底也沒看到）'); break; }
    await tapLabel(dam.label);
    await wait(3000);
    // 借種鈕在最下面：捲到它進了無障礙樹，再多捲一點，截圖看得到機率卡、提醒和借種鈕
    const b = button(/^借種（/);
    await scrollUntil(async () => (await b.count()) > 0);
    await page.mouse.wheel(0, 300);
    await wait(600);
    note(`機率卡：${(((await nodes()).find((x) => x.label.startsWith('可能生出的小牛')) || {}).label || '?').replace(/\n/g, ' ')}`);
    await shot('stud-preview');
    if (!(await b.count())) { issue('找不到借種鈕（捲到底也不在無障礙樹裡）'); break; }
    if (!(await enabled(b))) {
      // 停用時把機率卡到借種鈕之間的字記下來（金幣不夠、牛舍滿了…），再看有沒有離線
      const all2 = await nodes();
      const i0 = all2.findIndex((x) => x.label.startsWith('可能生出的小牛'));
      const i1 = all2.findIndex((x) => x.role === 'button' && /^借種（/.test(x.label));
      const between = i0 < 0 || i1 < 0 ? '?' : all2.slice(i0 + 1, i1).map((x) => x.label.replace(/\n/g, ' ')).join(' / ');
      issue(`借種鈕停用（金幣 ${await coins()}）：${between || '(沒有提醒)'}；離線：${all2.some((x) => /離線|連線中/.test(x.label))}`);
      break;
    }
    const c0 = await coins();
    await mark(); await tap(b.first());
    await wait(2500);
    let ft = await fullText();
    if (ft.includes('借種費變了')) {
      note(`借種費變了：${await news()}`);
      await shot('stud-fee-changed');
      await tap(button(/^用新價格借/));
      await wait(2500);
      ft = await fullText();
    }
    if (ft.includes('借不到了')) {
      note('借不到了（被別人借走或主人下架）：重新整理市場再挑一頭');
      await shot('stud-gone');
      await tap(button('重新整理市場')).catch(() => {});
      await wait(1500);
      continue;
    }
    await shot('stud-borrowed');
    if ((await button('已借種').count()) === 0) { issue(`借種沒有成功：${await news()}`); break; }
    borrowed = `${(ft.match(/借種成功！[^\n]*/) || ['已借種'])[0]}；金幣 ${c0} → ${await coins()}`;
  }
  step('借別人的公牛（S18）', borrowed !== '', borrowed);

  // 借種紀錄（S18-11）：剛才借入的那一筆是「今天」；上架的公牛被別人借走的話，也會有一筆借出。
  // 連結在最上面的「我的公牛」卡片裡：先捲回最上面（捲出畫面的元件不在無障礙樹裡）
  await scrollTop();
  await tap(button('借種紀錄'));
  await wait(2500);
  const logRows = (await nodes()).filter((x) => /^(借入|借出)\n/.test(x.label)).map((x) => x.label.replace(/\n/g, ' '));
  logRows.forEach((r) => note(`紀錄：${r}`));
  if (!logRows.length) note(`借種紀錄頁的字：${(await fullText()).replace(/\n/g, ' | ').slice(0, 600)}`);
  const logOpen = (await labels()).some((x) => x.includes('只保留最近'));
  await shot('stud-log');
  step('借種紀錄（S18）', logOpen && (!borrowed || logRows.some((r) => r.startsWith('借入') && r.includes('今天'))), logRows[0] || '(沒有紀錄)');
  // 返回鈕的名字只有「返回」：旁邊的標題不能併進按鈕
  const back = button('返回');
  if (!(await back.count())) issue('借種紀錄的返回鈕名字不只「返回」（標題併進按鈕了）');
  await tap((await back.count()) ? back.first() : button(/^返回/).first()).catch(() => {});
  await wait(800);

  // ---- 10. 圖鑑、排行榜（M1）----
  await tab('紀錄');
  await subTab('圖鑑');
  const dex = (await labels()).find((x) => x.startsWith('已發現')) || '';
  await shot('codex');
  step('圖鑑（M1 紀錄）', dex !== '', dex);
  await subTab('排行榜');
  await wait(1500);
  const rank = ((await fullText()).match(/我的名次[^\n]*/) || [''])[0];
  await shot('leaderboard');
  step('排行榜（M1 紀錄）', rank !== '', rank);

  step('升級慶祝（S11-01）', levelUps.length > 0, levelUps.join('、'));

  // ---- 11. 自己配種（S08）：另開一個新牧場（新的瀏覽器設定檔），開局的小公牛長大以後跟開局的母牛直接配 ----
  // 開局牛舍 2 格是滿的、小牛沒位子：先收奶賣奶、擴建牛舍（S10）
  page = await newPage();
  note(`第二個牧場（自己配種）：${(await newRanch()).replace(/\n/g, ' ')}`);
  await tapIfEnabled(button('收奶'), '收奶');
  if (!(await upgrade('擴建牛舍'))) issue('自己配種：擴建牛舍沒有成功，小牛沒有位子');
  await tab('配種');
  await tap(button('自己配種').first());
  await wait(2000);
  /// 「選公牛」「選母牛」底下第一頭能選的牛。
  const pickUnder = async (title) => {
    const all = await nodes();
    const cut = all.findIndex((x) => x.label === title);
    return (cut < 0 ? null : all.slice(cut + 1).find((x) => x.role === 'button' && /#\d+/.test(x.label) && !x.disabled)) || null;
  };
  let bred = '', odds = '';
  const sire = await pickUnder('選公牛');
  if (sire) await tapLabel(sire.label);
  await wait(800);
  await scrollUntil(async () => (await pickUnder('選母牛')) !== null);
  const dam2 = await pickUnder('選母牛');
  if (dam2) await tapLabel(dam2.label);
  await wait(3000);
  note(`自己配種：公牛 ${sire ? sire.label.replace(/\n/g, ' ') : '(沒有)'}，母牛 ${dam2 ? dam2.label.replace(/\n/g, ' ') : '(沒有)'}`);
  const go = button(/^配種（/);
  await scrollUntil(async () => (await go.count()) > 0);
  await page.mouse.wheel(0, 300);
  await wait(600);
  odds = ((await nodes()).find((x) => x.label.startsWith('可能生出的小牛')) || {}).label || '';
  note(`機率卡：${odds.replace(/\n/g, ' ') || '(沒看到)'}`);
  await shot('breed-preview');
  if (!sire || !dam2) issue('自己配種：選不到公牛或母牛');
  else if (!(await go.count())) issue('自己配種：找不到配種鈕（捲到底也不在無障礙樹裡）');
  else if (!(await enabled(go))) {
    const all3 = await nodes();
    const i0 = all3.findIndex((x) => x.label.startsWith('可能生出的小牛'));
    const i1 = all3.findIndex((x) => x.role === 'button' && /^配種（/.test(x.label));
    issue(`配種鈕停用：${i0 < 0 || i1 < 0 ? '?' : all3.slice(i0 + 1, i1).map((x) => x.label.replace(/\n/g, ' ')).join(' / ') || '(沒有提醒)'}`);
  } else {
    await mark(); await tap(go.first());
    await wait(2500);
    const toastText = ((await fullText()).match(/配種成功！[^\n]*/) || [''])[0];
    await scrollUntil(async () => (await labels()).some((x) => x.startsWith('新小牛')), 4);
    const doneBtn = (await button('已配種').count()) > 0;
    const calfCard = (await labels()).find((x) => x.startsWith('新小牛')) || '';
    await shot('breed-done');
    if (doneBtn && calfCard) bred = `${toastText || '（提示已經消失）'}；${calfCard.replace(/\n/g, ' ')}；按鈕「已配種」`;
    else issue(`配種之後沒看到「已配種」或新小牛：${await news()}`);
    // 新小牛把牛舍佔滿了，「已配種」下面也不能跳「牛舍滿了」（ceo 2026-10-02）
    if ((await labels()).some((x) => x.includes('牛舍滿了'))) issue('「已配種」下面出現「牛舍滿了」');
  }
  step('自己配種（S08）：機率、配種、新小牛、已配種', bred !== '' && odds !== '', bred);

  writeLog();
  await browser.close();
  console.log(`done, steps ok=${steps.filter((s) => s.startsWith('過')).length}/${steps.length}, issues=${issues.length}`);
})().catch((e) => { console.error(e); console.log(`FATAL ${e}`); log.push(`FATAL ${e}`); writeLog(); process.exit(1); });
