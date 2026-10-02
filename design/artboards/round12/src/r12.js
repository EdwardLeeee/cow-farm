// 第 12 輪草稿（ceo 2026-10-03 交辦）：D34 改牧場名和頭像、D33 超級大事件和超級黑天鵝怎麼顯示。
// 網址：r12.html?b=R12-01-A&w=390 畫一張說明圖；?list=1 列出全部說明圖（harness/make.mjs 用）。
// 元件、字串、假資料都用 M2 設計稿（design/m2）的。新的字是草稿，直接寫在這裡，沒有進字串表：
// 使用者核准以後才加 key、翻英文和泰文（D25）。
import { applyDevice, frame, btn, icon, fmt, cowFace, badge, toast, nameWidth, fitTitles, fitOriginTags, placeVersion, fitSwipeHint, fitMiniLines, placeCowPop, fitGrade, fitActions, fitMyRank } from '../../../m2/src/js/kit.js';
import { loadLang, t, ago, breedName } from '../../../m2/src/js/i18n.js';
import { RANCH, MARKET, FOUND, newsTag } from '../../../m2/src/js/fixtures.js';
import { CODEX_ORDER } from '../../../m2/src/cow/breeds.js';

// i18n.js 用「../i18n/」載字串表（相對於 m2/src 的頁面）；這一頁在 artboards/round12/src，改指到 m2 的字串表
const realFetch = window.fetch.bind(window);
window.fetch = (u, o) => realFetch(typeof u === 'string' && u.startsWith('../i18n/') ? `../../../m2/${u.slice(3)}` : u, o);

const q = new URLSearchParams(location.search);
const W = +(q.get('w') || 390);
const dev = applyDevice(W);
const ctx = { dev, w: W, q };
const app = document.getElementById('app');
await loadLang('zh-Hant');
// 畫面模組的常數會用到字串：字串表載好才載入（跟 m2 的 main.js 一樣）
const { ranchPage } = await import('../../../m2/src/js/screens/s03.js');
const { sellCard, vsText } = await import('../../../m2/src/js/screens/s06.js');

const PAD = 36, GAP = 40;
const KB_H = { 430: 300, 390: 292 }; // 跟 S02 一樣的系統鍵盤高度

// ---------- M2 沒有的小圖示 ----------
const PENCIL = (s = 12) => `<svg viewBox="0 0 16 16" width="${s}" height="${s}" aria-hidden="true"><path d="M2.6 13.4l.8-3.3 7.2-7.2a1.6 1.6 0 0 1 2.3 0l.2.2a1.6 1.6 0 0 1 0 2.3l-7.2 7.2z" fill="#FFFFFF" stroke="#4B3326" stroke-width="1.7" stroke-linejoin="round"/><path d="M9.3 4.2l2.5 2.5" stroke="#4B3326" stroke-width="1.5"/></svg>`;
// 黑天鵝：一隻往左游的天鵝側影（顏色跟著字）
const SWAN = (s = 13) => `<span class="swan-ic"><svg viewBox="0 0 20 20" width="${s}" height="${s}" aria-hidden="true"><path d="M2.4 5.6L5 4.6C5.3 3 7.3 2.4 8.5 3.6c1.1 1.1.4 2.8-.5 4.1-.8 1.2-1.1 2.4-.4 3.5 2.6-1.3 6.2-2 10.2-3.2-.1 4.8-3.3 8-8 8-3.5 0-5.6-1.6-5.9-3.9-.2-1.4.5-2.8 1.4-4 .8-1.1 1.2-2 .7-2.6-.4-.4-1-.3-1.5 0z" fill="currentColor"/></svg></span>`;
// 放射狀的光（超級大事件的背景）
const RAYS = (cls, n = 16) => `<svg class="${cls}" viewBox="-50 -50 100 100" aria-hidden="true">${Array.from({ length: n }, (_, i) => {
  const a = (i * 360) / n, d = 360 / n / 4, p = (x) => `${(60 * Math.cos((x * Math.PI) / 180)).toFixed(1)} ${(60 * Math.sin((x * Math.PI) / 180)).toFixed(1)}`;
  return `<path d="M0 0L${p(a - d)}L${p(a + d)}z" fill="#FFFFFF"/>`;
}).join('')}</svg>`;

// ---------- 說明圖的版面 ----------
// 左上角印檔名（跟檔名一樣的標籤），下面是標題、說明、一排或幾排手機、註解
function board({ id, title, sub = '', cells = [], cols = cells.length, notes = [], width, body = '' }) {
  const wpx = width || PAD * 2 + cols * dev.w + (cols - 1) * GAP;
  const html = `<div class="board" style="width:${wpx}px">
    <div class="b-label">${id}</div>
    <div class="b-title">${title}</div>${sub ? `<div class="b-sub">${sub}</div>` : ''}
    ${cells.length ? `<div class="b-row" style="grid-template-columns:repeat(${cols}, ${dev.w}px)">${cells.map((c) => `<figure class="b-cell"><figcaption><b>${c.cap}</b>${c.note || ''}</figcaption>${c.html}</figure>`).join('')}</div>` : ''}
    ${body}
    ${notes.length ? `<ul class="b-notes">${notes.map((n) => `<li>${n}</li>`).join('')}</ul>` : ''}
  </div>`;
  return { html, after: async (root) => { const figs = root.querySelectorAll('.b-cell'); for (let i = 0; i < cells.length; i++) if (cells[i].after) await cells[i].after(figs[i]); } };
}
// 頂列的小鉛筆（D34 進入點，提案）：頭像會切圓，所以放在頭像旁邊、疊在右下角
const addPencil = (root) => root.querySelectorAll('.hud .avatar').forEach((a) => a.insertAdjacentHTML('afterend', `<i class="hud-edit" aria-hidden="true">${PENCIL(13)}</i>`));
const setFace = (breed) => (el) => { const a = el.querySelector('.hud .avatar'); if (a) a.innerHTML = cowFace({ breed }, 46); };
const setTicker = (n) => (el) => { const tk = el.querySelector('.ticker-text'); if (tk) tk.textContent = `${newsTag(n)}${n.text}`; };
// 進入點的註解：虛線圈住頭像和牧場名（給看圖的人，不是畫面的一部分）
function ring(el) {
  const ph = el.querySelector('.phone'), av = el.querySelector('.hud .avatar'), tx = el.querySelector('.hud .profile-text');
  const a = ph.getBoundingClientRect(), b1 = av.getBoundingClientRect(), b2 = tx.getBoundingClientRect(), p = 7;
  const l = b1.left - a.left - p, tp = Math.min(b1.top, b2.top) - a.top - p, r = b2.right - a.left + p, bt = Math.max(b1.bottom, b2.bottom) - a.top + p;
  ph.insertAdjacentHTML('beforeend', `<div class="note-ring" data-note style="left:${l}px;top:${tp}px;width:${r - l}px;height:${bt - tp}px"></div><div class="note-tag" data-note style="left:${l + 4}px;top:${bt + 8}px">點頭像或牧場名都會打開</div>`);
}

// ---------- D34 牧場資料面板 ----------
const NAME1 = '小花的快樂牧場', NAME2 = '楓葉溪谷牧園';
const OPT = {
  A: { price: 500, name: '固定 500 幣', file: '固定500幣' },
  B: { price: 1000, name: '固定 1,000 幣', file: '固定1000幣' },
  C: { price: RANCH.level * 100, name: '依等級：等級 × 100 幣', file: '等級乘100', rule: `等級 × 100（現在 Lv ${RANCH.level}）`, after: '（等級 × 100）' },
};
function keyboard(w) {
  const rows = [10, 9, 7].map((n) => `<div class="kb-row">${'<i></i>'.repeat(n)}</div>`).join('');
  return `<div class="kb" style="height:${KB_H[w]}px"><div class="kb-label" data-note>系統鍵盤（不畫）</div>${rows}<div class="kb-row last"><i class="w"></i><i class="sp"></i><i class="w"></i></div></div>`;
}
const withKb = (html) => html.replace('<div class="phone', `<div style="--kb-h:${KB_H[W]}px" class="phone`);
// price：0＝第一次（免費）；rule：價錢的算法（選項 C）；err：名字不能用；kb：鍵盤開著；short：錢不夠時還差多少
function profSheet({ name = RANCH.name, value = NAME1, price = 0, rule = '', err = '', kb = false, short = 0 } = {}) {
  const w = nameWidth(value), ok = !err && !short && w >= 2 && w <= 16;
  const tag = price ? `<span class="price-tag">${icon('coin', 18)}<b class="num">${fmt(price)}</b>幣</span>${rule ? `<span class="hint">${rule}</span>` : ''}` : badge('free', '第一次免費');
  const go = price
    ? `<button class="btn primary"${ok ? '' : ' disabled'}><span>改名</span><span class="btn-price">${icon('coin', 20)}<b class="num">${fmt(price)}</b></span></button>`
    : `<button class="btn primary"${ok ? '' : ' disabled'}><span>改名（免費）</span></button>`;
  return `<div class="backdrop"></div><section class="sheet prof-sheet${kb ? ' kb-up' : ''}" role="dialog">
    <div class="grab"></div><h2>牧場資料</h2>
    <div class="prof-head">
      <button class="prof-av" aria-label="換頭像"><span class="av-circle">${cowFace({ breed: 'holstein' }, 60)}</span><i class="av-edit">${PENCIL(15)}</i></button>
      <div class="grow"><b class="ph-name">${name}<span class="ph-tag num">${RANCH.tag}</span></b><span class="ph-sub"><span class="lv num">${t('level', { lv: RANCH.level })}</span><span class="prof-link">換頭像（免費）${icon('chevron', 14)}</span></span></div>
    </div>
    <div class="prof-sec"><span>牧場名</span>${tag}</div>
    <div class="card name-card">
      <div class="input name-input${err ? ' err' : ''} filled${kb ? ' focus' : ''}"><span class="nv">${value}</span>${kb ? '<span class="caret"></span>' : ''}</div>
      <div class="name-meta"><span class="${err ? 'err-text' : 'hint'}">${err || t('s02.widthRule')}</span><span class="num name-count${w > 16 ? ' over' : ''}">${w} / 16</span></div>
      ${btn(t('s02.suggest'), { ic: 'sparkle', block: true, cls: 'idea-btn' })}
    </div>
    <p class="hint prof-rule">${RANCH.tag} 不會變；跟別人同名也沒關係。</p>
    ${short ? `<p class="warn-text prof-warn">${icon('warn', 18)}${t('notEnoughCoins', { n: fmt(short) })}</p>` : ''}
    <div class="btn-row">${btn(t('cancel'))}${go}</div>
  </section>`;
}
const doneToast = (o) => toast('ok', `牧場名改好了！下次改名要 ${fmt(o.price)} 幣${o.after || ''}`);
// 牧場資料的各個狀態（價錢照選項 o）
const ST = (o) => ({
  entry: { cap: '進入點', note: '頂列頭像的右下角多一枝小鉛筆；點頭像或牧場名，打開「牧場資料」', html: ranchPage(ctx), after: ring },
  first: { cap: '第一次改名', note: '寫「第一次免費」，按鈕寫「改名（免費）」', html: ranchPage(ctx, { overlays: profSheet() }) },
  typing: { cap: '打字中（鍵盤開著）', note: '面板移到鍵盤上面：輸入框、字數、按鈕都看得到', html: withKb(ranchPage(ctx, { overlays: profSheet({ value: '小花的快樂', kb: true }) + keyboard(W) })) },
  later: { cap: '之後改名', note: `第二次以後寫價錢${o === OPT.A ? '（這裡用 A 的 500 幣示範）' : ''}`, html: ranchPage(ctx, { hud: { ranch: { ...RANCH, name: NAME1 } }, overlays: profSheet({ name: NAME1, value: NAME2, price: o.price, rule: o.rule }) }) },
  poor: { cap: '錢不夠', note: `金幣只有 320、改名要 ${fmt(o.price)}：按鈕不能按，寫還差多少`, html: ranchPage(ctx, { hud: { ranch: { ...RANCH, name: NAME1 }, coins: 320 }, overlays: profSheet({ name: NAME1, value: NAME2, price: o.price, rule: o.rule, short: o.price - 320 }) }) },
  bad: { cap: '名字不能用', note: '規則和提示照 S02-05（太短、太長、表情符號、不能用的字）；按鈕不能按', html: ranchPage(ctx, { overlays: profSheet({ value: '小花牧場🐮', err: t('s02.errEmoji') }) }) },
  done: { cap: '改好了', note: '面板關掉，頂列換成新名字；提示下次改名要多少錢', html: ranchPage(ctx, { hud: { ranch: { ...RANCH, name: NAME1 } }, overlays: doneToast(o) }) },
  face: { cap: '換好頭像', note: '頂列換成新的頭像（從 R12-02 的面板選）', html: ranchPage(ctx, { overlays: toast('ok', '頭像換好了！') }), after: setFace('jersey') },
});

// ---------- D34 換頭像 ----------
// scope：'all' 全部 24 種｜'found' 只有圖鑑裡發現過的；sel：選中的；tapped：點了還沒發現的（只有 found）
function avSheet(scope, { sel = 'jersey', tapped = '' } = {}) {
  const cells = CODEX_ORDER.map((k) => {
    const lock = scope === 'found' && !FOUND.includes(k), on = k === sel;
    return `<button class="av-cell${on ? ' on' : ''}${lock ? ' locked' : ''}${k === tapped ? ' tapped' : ''}" aria-label="${breedName(k)}"><span class="av-circle">${cowFace({ breed: k }, 48)}</span>${lock ? `<span class="av-lock">${icon('lock', 12)}</span>` : ''}${on ? `<span class="pick-check">${icon('ok', 20)}</span>` : ''}</button>`;
  }).join('');
  const foot = scope === 'all' ? ''
    : tapped ? `<p class="warn-text av-count">${icon('lock', 14)}還沒發現「${breedName(tapped)}」，在圖鑑發現以後就能用</p>`
      : `<p class="hint av-count">${icon('lock', 14)}已發現 ${FOUND.length} / ${CODEX_ORDER.length} 種；還沒發現的，發現以後就能用</p>`;
  return `<div class="backdrop"></div><section class="sheet av-sheet" role="dialog"><div class="grab"></div>
    <div class="av-top"><h2>換頭像</h2>${badge('free', '免費')}</div>
    <div class="av-preview"><span class="av-circle now">${cowFace({ breed: 'holstein' }, 48)}</span>${icon('chevron', 18)}<span class="av-circle">${cowFace({ breed: sel }, 48)}</span><div class="grow"><b>${breedName(sel)}</b><span class="hint">${scope === 'all' ? '還沒發現的也能選' : '只有圖鑑裡發現過的能選'}</span></div></div>
    <div class="av-grid">${cells}</div>${foot}
    <div class="btn-row">${btn(t('cancel'))}${btn('用這個頭像', { kind: 'primary' })}</div>
  </section>`;
}

// ---------- D33 超級大事件、超級黑天鵝 ----------
// 專屬標題草稿（R12-06）：每種商品和「三種一起」各 3 則。只寫事件，不寫真的品牌、地名、食品安全；最長 14 個字（跟現有標題一樣）
export const HL = {
  milk: { sup: ['全國學校改喝鮮奶，訂單暴增', '國際冰淇淋大賽開幕，鮮奶搶光', '鮮奶拿鐵爆紅，咖啡店搶不到奶'], swan: ['乳品廠大停電，鮮奶全面停收', '冷藏車大罷工，鮮奶運不出去', '超級寒流來襲，冰品店全部休息'] },
  beef: { sup: ['世界牛排大賽在本地舉辦', '全國烤肉節提前開跑，肉商搶貨', '牛肉麵登上國際美食榜'], swan: ['冷凍物流大當機，肉商全面停收', '便宜進口牛肉湧入，價格崩盤', '全國蔬食週開跑，牛肉沒人買'] },
  rice: { sup: ['新米拿下國際金獎，米價翻倍', '海外飯糰大流行，外銷訂單爆量', '國宴指定在地新米，糧商搶貨'], swan: ['糧商全面停收，新米堆成山', '百年一見大豐收，新米賣不出去', '麵食大流行，米飯沒人吃'] },
  all: { sup: ['世界美食節在本地登場', '觀光人潮創新高，餐廳天天客滿', '超級連假來了，餐飲需求翻倍'], swan: ['超級颱風來襲，市場全面停擺', '港口全面封閉，農產品出不了貨', '全國消費急凍，農產品沒人買'] },
};
const EV = {
  supBeef: { c: 'beef', kind: 'sup', dir: 'up', pct: '+100%', text: HL.beef.sup[0], when: { min: 8 }, price: 24, unit: 'unitBeef' },
  swanMilk: { c: 'milk', kind: 'swan', dir: 'down', pct: '−90%', text: HL.milk.swan[0], when: { min: 40 }, price: 1.2, unit: 'unitMilk' },
  supAll: { c: 'all', kind: 'sup', dir: 'up', pct: '+100%', text: HL.all.sup[0], when: { min: 5 } },
  swanAllSoon: { c: 'all', kind: 'swan', dir: 'down', pct: '−90%', text: HL.all.swan[0], when: { min: 2 }, upcoming: true },
};
// 一般新聞、大新聞（對照用，標題是現有的）
const NORMAL = [
  { c: 'rice', big: true, dir: 'up', tk: 'news.rice_up.1', when: { h: 2 } },
  { c: 'all', dir: 'down', tk: 'news.all_down.2', when: { h: 3 } },
  { c: 'rice', dir: 'down', tk: 'news.rice_down.3', when: { h: 6 } },
];
const tagHtml = (n) => (n.kind === 'sup' ? `${icon('sparkle', 14)}超級大事件` : `${SWAN(15)}超級黑天鵝`);
const evBadge = (n) => `<span class="badge ${n.kind}">${tagHtml(n)}</span>`;
const upcomingBadge = (n) => (n.upcoming ? `<span class="badge new">${t('s06.upcoming')}</span>` : '');
const icBox = (n, cls, s1, s3) => (n.c === 'all' ? `<span class="${cls} all">${icon('milk', s3)}${icon('beef', s3)}${icon('rice', s3)}</span>` : `<span class="${cls}">${icon(n.c, s1)}</span>`);
// 說明句：A 沿用 D29 的句子（s03.bigNewsBody、s03.bigNewsAll）；B 另外寫「變兩倍」「只剩一成」（草稿），大卡上分兩行
const chgLine = (n) => (n.c === 'all' ? t('s03.bigNewsAll', { chg: `<b class="${n.dir}-text">${n.pct}</b>` }) : t('s03.bigNewsBody', { name: t(n.c), chg: `<b class="${n.dir}-text">${n.pct}</b>`, price: n.price, unit: t(n.unit) }));
function plainLines(n) {
  const what = n.kind === 'sup' ? '變兩倍' : '只剩一成';
  if (n.upcoming) return ['大約 30 分鐘後開始', `收購價會${what}`];
  return n.c === 'all' ? ['全部商品的收購價', `都${what}`] : [`${t(n.c)}收購價${what}`, `現在 ${n.price} 幣／${t(n.unit)}`];
}

// 新聞的一則（一般、大新聞照 S06 現在的樣子；超級的照方向 A）
function newsItem(n) {
  const text = n.text || t(n.tk);
  const tags = `<span class="n-tag">${newsTag(n)}</span>${n.kind ? evBadge(n) : ''}${n.big ? `<span class="badge full">${t('s06.bigNews')}</span>` : ''}${upcomingBadge(n)}<span class="n-dir ${n.dir}">${icon(n.dir === 'up' ? 'up' : 'down', 11)}${t(n.dir === 'up' ? 's06.up' : 's06.down')}</span><span class="n-when">${ago(n.when)}</span>`;
  return `<div class="news-item${n.kind ? ` ${n.kind}` : ''}"><div class="n-tags">${tags}</div>${n.kind ? `<div class="n-row"><p class="n-text">${text}</p><b class="n-pct num ${n.dir}">${n.pct}</b></div>` : `<p class="n-text">${text}</p>`}</div>`;
}
// 方向 B：釘在新聞卡最上面的大卡
function pin(n) {
  return `<div class="pin ${n.kind}">${n.kind === 'sup' ? RAYS('pin-rays') : ''}
    <div class="pin-top">${evBadge(n)}${upcomingBadge(n)}<span class="n-tag">${newsTag(n)}</span><span class="n-when">${ago(n.when)}</span></div>
    <div class="pin-main">${icBox(n, 'pin-ic', 34, 22)}<div class="grow"><b class="t">${n.text}</b><div class="pin-fx"><b class="pin-big num">${n.pct}</b><p class="pin-sub">${plainLines(n).join('<br>')}</p></div></div></div>
  </div>`;
}
const newsHead = `<div class="card-head"><span class="card-title coral">${icon('news', 18)}${t('newsTitle')}</span></div>`;
function newsCardDraft(v, items) {
  if (v === 'A') return `<article class="card news-card">${newsHead}<div class="news-list">${items.map(newsItem).join('')}</div></article>`;
  const pins = items.filter((n) => n.kind), rest = items.filter((n) => !n.kind);
  return `<article class="card news-card">${newsHead}<div class="pins">${pins.map(pin).join('')}</div><div class="news-list">${rest.map(newsItem).join('')}</div></article>`;
}
// 市場頁（照 S06 的順序：收購價、最新一則、賣出、新聞），捲到新聞卡
function pricesCard(sel, mk) {
  return `<article class="card prices-card">
    <div class="card-head"><span class="card-title green">${icon('coin', 16)}${t('s06.title')}</span><span class="card-sub">${t('s06.tapToSell')}</span></div>
    <div class="price-rows">${['milk', 'beef', 'rice'].map((k) => {
      const m = mk[k];
      return `<button class="price-row${k === sel ? ' on' : ''}"><span class="pr-ic">${icon(k, 26)}</span><span class="pr-name">${m.name}</span>
        <span class="pr-right"><span class="pr-price"><b class="num">${m.price}</b><small>${t('priceUnit', { unit: m.unit })}</small></span>${vsText(m)}</span></button>`;
    }).join('')}</div>
    <p class="hint pr-base">${t('s06.baseLine', { milk: 12, beef: 12, rice: 5 })}</p>
  </article>`;
}
const MK_NEWS = { milk: { ...MARKET.milk, price: 1.2 }, beef: { ...MARKET.beef, price: 24 }, rice: { ...MARKET.rice } };
function marketPhone(card, top) {
  const content = `<div class="stack">${pricesCard('milk', MK_NEWS)}
    <div class="headline"><span class="hl-ic">${icon('news', 20)}</span><span class="hl-text">${newsTag(top)}${top.text}</span><span class="hl-when">${ago(top.when)}</span></div>
    ${sellCard(MK_NEWS.milk, 'ok', { qty: 130, avg: 1.2, total: 156, lots: 3 })}${card}</div>`;
  return { html: frame(dev, { tab: 'market', content }), after: (el) => { const c = el.querySelector('.content'), n = el.querySelector('.news-card'); c.scrollTop = n.offsetTop - 6; } };
}
// 牧場頁的提示 A：原本的大新聞提示卡（S03-15／16／17）換成超級的樣子
function promptA(n) {
  const sparks = n.kind === 'sup' ? `<span class="bn-spark" style="left:146px;top:8px">${icon('sparkle', 16)}</span><span class="bn-spark" style="left:168px;top:22px">${icon('sparkle', 10)}</span>` : '';
  return `<div class="big-news card ${n.kind}">${sparks}<button class="bn-close" aria-label="${t('g.close')}">${icon('close', 18)}</button><span class="bn-tag">${tagHtml(n)}</span>
    <div class="bn-main">${icBox(n, 'bn-ic', 34, 22)}<div class="grow"><b>${n.text}</b><p>${chgLine(n)}</p></div></div>
    ${btn(t('s03.bigNewsGo'), { kind: 'primary', block: true, ic: 'coin' })}</div>`;
}
// 牧場頁的提示 B：整個畫面變暗，中間一張大卡，幅度放最大
function promptB(n) {
  return `<div class="sx-back ${n.kind}"></div><section class="sx ${n.kind}" role="dialog">${n.kind === 'sup' ? RAYS('sx-rays', 18) : ''}<button class="bn-close" aria-label="${t('g.close')}">${icon('close', 20)}</button>
    <span class="sx-tag">${tagHtml(n)}</span>${icBox(n, 'sx-ic', 54, 30)}<div class="sx-big num">${n.pct}</div><div class="sx-title">${n.text}</div><p class="sx-sub">${plainLines(n).join(n.c === 'all' ? '' : '，')}</p>
    ${btn(t('s03.bigNewsGo'), { kind: 'primary', block: true, ic: 'coin' })}</section>`;
}
const MK_EV = {
  supBeef: { ...MARKET, beef: { ...MARKET.beef, price: 24 } },
  swanMilk: { ...MARKET, milk: { ...MARKET.milk, price: 1.2 } },
  supAll: { milk: { ...MARKET.milk, price: 24 }, beef: { ...MARKET.beef, price: 24 }, rice: { ...MARKET.rice, price: 10 } },
};
const ranchEv = (key, prompt) => ({ html: ranchPage(ctx, { dock: { market: MK_EV[key] }, overlays: prompt(EV[key]) }), after: setTicker(EV[key]) });

// ---------- 說明圖 ----------
const PRICE_NOTE = '參考：假資料的 Lv 4 牧場有 12,480 幣；一次賣 130 瓶牛奶約 1,924 幣（S06-13）。';
const RULES = '名字規則照 D23（中文字算 2、英文字母和數字算 1，總共 2–16；不收表情符號和控制字元），由伺服器檢查；#1234 不會變。';
function r1201(k) {
  const o = OPT[k], st = ST(o);
  return board({
    id: `R12-01-改名價錢-${k}-${o.file}-390`, title: `01 改名的價錢　${k}：${o.name}`,
    sub: '第一次改名免費（D34），之後每次付這個價錢、次數不限。三支手機：第一次改名、之後改名、改好以後的提示。',
    cells: [
      { ...st.first, cap: '第一次改名：免費', note: '寫「第一次免費」，按鈕寫「改名（免費）」；三個選項都一樣' },
      { ...st.later, cap: `之後改名：${fmt(o.price)} 幣`, note: o.rule ? `價錢＝${o.rule}；升級以後會變貴` : '價錢寫在「牧場名」旁邊和按鈕上' },
      { ...st.done, cap: '改好了', note: '第一次改好時，順便提醒下次要多少錢' },
    ],
    notes: [
      k === 'C' ? `等級 × 100：Lv 1 要 100 幣、Lv 4 要 400 幣、Lv 10 要 1,000 幣、Lv 14 要 1,400 幣。${PRICE_NOTE}` : PRICE_NOTE,
      RULES,
      '「牧場資料」從哪裡打開（點頂列的頭像或牧場名）、頂列的小鉛筆，是 cow-ui 的提案；見 R12-03 的「進入點」。',
    ],
  });
}
function r1202(k) {
  const all = k === 'A';
  return board({
    id: `R12-02-頭像範圍-${k}-${all ? '全部24種' : '只有發現過的'}-390`, title: `02 頭像可以選哪些牛　${k}：${all ? '全部 24 種（沒發現的也能選）' : '只有圖鑑裡發現過的'}`,
    sub: '在「牧場資料」點頭像（或「換頭像」）打開。換頭像免費（ceo 提案）、次數不限。',
    cells: all ? [
      { cap: '換頭像：選了娟珊', note: '24 種都是彩色的、都能點', html: ranchPage(ctx, { overlays: avSheet('all') }) },
      { cap: '也能選還沒發現的', note: '例：還沒發現的「星空牛」也能直接用', html: ranchPage(ctx, { overlays: avSheet('all', { sel: 'starry' }) }) },
    ] : [
      { cap: '換頭像：選了娟珊', note: `發現過的 ${FOUND.length} 種是彩色的；其他畫成剪影加鎖`, html: ranchPage(ctx, { overlays: avSheet('found') }) },
      { cap: '點了還沒發現的', note: '不能選；下面那行換成提示', html: ranchPage(ctx, { overlays: avSheet('found', { tapped: 'starry' }) }) },
    ],
    notes: all ? [
      '好處：一開始就能挑喜歡的牛當頭像。',
      '代價：還沒發現的牛的臉先看到了，圖鑑「發現新品種」的驚喜少一點。',
    ] : [
      '好處：發現新品種就多一個頭像能用，算是收集圖鑑的小獎勵；不會先看到還沒發現的牛。',
      '代價：剛開始只有幾種能選（開局送的荷斯坦、台灣黃牛……）。',
      '剪影只看得出輪廓、看不出顏色（圖鑑裡還沒發現的品種也是這樣）。',
    ],
  });
}
function r1203() {
  const st = ST(OPT.A), order = ['entry', 'first', 'typing', 'later', 'poor', 'bad', 'done', 'face'];
  return board({
    id: `R12-03-牧場資料的狀態-${W}`, title: `03 牧場資料：全部狀態（${W} 寬）`,
    sub: '價錢先用 R12-01 的 A（500 幣）示範，照使用者選的換。頂列頭像的小鉛筆、點頭像或牧場名打開，都是 cow-ui 的提案。',
    cols: 4, cells: order.map((k, i) => ({ ...st[k], cap: `${i + 1}　${st[k].cap}` })),
    notes: [
      '名字跟現在一樣、或還沒改的時候，「改名」鈕不能按（沒有另外畫）。',
      '改名、換頭像都由伺服器處理（cow-back 在使用者選完以後加 API）；錢不夠、名字不能用的檢查以伺服器為準。',
      '換頭像只換頂列和牧場資料的頭像；#1234 不會變。',
    ],
  });
}
function r1204(k) {
  const a = k === 'A', items = [EV.supBeef, EV.swanMilk, ...NORMAL], soon = [EV.swanAllSoon, ...NORMAL];
  const now = marketPhone(newsCardDraft(k, items), EV.swanMilk), pre = marketPhone(newsCardDraft(k, soon), EV.swanAllSoon);
  return board({
    id: `R12-04-新聞卡-${k}-${a ? '同一列換顏色' : '釘在最上面的大卡'}-390`, title: `04 市場的新聞卡　${k}：${a ? '留在原本的位置，那一則換顏色' : '釘在新聞卡最上面，變成大卡'}`,
    sub: '超級大事件：金色、「超級大事件」標籤；超級黑天鵝：深色、「超級黑天鵝」標籤。兩種都寫出幅度 +100%／−90%。',
    cells: [
      { cap: '發生了：牛肉 +100%、牛奶 −90%', note: a ? '照時間排在原本的位置；一般新聞、大新聞照 S06 現在的樣子' : '超級的兩則釘在最上面；下面是一般新聞、大新聞', html: now.html, after: now.after },
      { cap: '預告：三種一起 −90%', note: '跟一般新聞一樣，有時先預告（D33）；多一個「預告」標籤', html: pre.html, after: pre.after },
    ],
    notes: [
      '漲紅跌綠照台灣習慣（英文、泰文照 D25 的設定）。一般新聞、大新聞照現在的樣子，不寫幅度。',
      a ? '一般新聞變多以後，超級的那一則會被擠到下面（照時間排）。' : '事件的影響退了以後，大卡收起來、回到下面的清單（照時間排）。大卡下面那行字是新的（草稿）。',
      '新聞卡右上角已經拿掉「全部是虛構的」（D33，#114）。',
    ],
  });
}
function r1205(k) {
  const a = k === 'A', p = a ? promptA : promptB;
  return board({
    id: `R12-05-牧場提示-${k}-${a ? '原本的提示卡換顏色' : '滿版大卡'}-390`, title: `05 牧場頁的提示　${k}：${a ? '原本的大新聞提示卡換成超級的樣子' : '整個畫面變暗，中間一張大卡'}`,
    sub: '跟 D29 的大新聞提示（S03-15／16／17）一樣只跳一次；按「去市場看看」到市場頁、選好那種商品，按 ✕ 關掉。',
    cells: [
      { cap: '超級大事件：牛肉 +100%', note: a ? '金色底、金色標籤，幅度的字放大' : '金色的光、幅度放最大', ...ranchEv('supBeef', p) },
      { cap: '超級黑天鵝：牛奶 −90%', note: a ? '深色底、白色標籤' : '畫面變得很暗、深色大卡', ...ranchEv('swanMilk', p) },
      { cap: '三種一起：+100%', note: '三個商品的圖示，句子寫「全部商品的收購價」（照 S03-16）', ...ranchEv('supAll', p) },
    ],
    notes: [
      a ? '位置、大小跟現在的大新聞提示一樣，只換顏色、標籤、幅度的字。' : '比較像「發生大事了」；大卡下面那行字是新的（草稿）。',
      '提示上的標題用 R12-06 的專屬標題（這裡各用第 1 則）。',
    ],
  });
}
function r1206() {
  const rows = [['milk', t('milk')], ['beef', t('beef')], ['rice', t('rice')], ['all', '三種一起']];
  const ic = (k) => (k === 'all' ? `${icon('milk', 18)}${icon('beef', 18)}${icon('rice', 18)}` : icon(k, 22));
  const table = `<table class="hl"><thead><tr><th></th><th class="sup">${icon('sparkle', 16)} 超級大事件（+100%）</th><th class="swan">${SWAN(16)} 超級黑天鵝（−90%）</th></tr></thead>
    <tbody>${rows.map(([k, name]) => `<tr><th><span>${ic(k)}${name}</span></th>${['sup', 'swan'].map((kind) => `<td class="${kind}"><ol>${HL[k][kind].map((s) => `<li>${s}</li>`).join('')}</ol></td>`).join('')}</tr>`).join('')}</tbody></table>`;
  return board({
    id: 'R12-06-專屬標題草稿', title: '06 超級大事件、超級黑天鵝的專屬標題（繁中草稿）', width: 1000,
    sub: '每種商品和「三種一起」各 3 則。英文、泰文等核准以後再翻（D25）。',
    body: table,
    notes: [
      '只寫事件：不寫真的品牌、真的地名，也不寫食品安全的事。',
      '比現有的大新聞再大一級（例：現有的「颱風過境，市場休市一日」→ 超級黑天鵝「超級颱風來襲，市場全面停擺」）。',
      '最長 14 個字（跟現有的標題一樣），牧場頁的提示放得下一行。',
      '核准以後：cow-back 在新聞的標題表（HEADLINES）加超級大事件、超級黑天鵝的分類；字串 key 建議 news.milk_super.1–3、news.milk_swan.1–3（跟現在 milk+ 對到 news.milk_up 一樣）。',
    ],
  });
}
// 總覽：每個要選的項目一排，選項並排（手機縮小）
function r1299() {
  const S = 0.75, sw = Math.round(dev.w * S), sh = Math.round(dev.h * S);
  const mini = (c) => `<div class="ov-cell"><div class="ov-cap"><b>${c.cap}</b></div><div class="ov-ph" style="width:${sw}px;height:${sh}px"><div style="transform:scale(${S});transform-origin:0 0">${c.html}</div></div></div>`;
  const later = (k) => ({ cap: `${k}　${OPT[k].name}`, html: ST(OPT[k]).later.html });
  const n4 = (k) => { const m = marketPhone(newsCardDraft(k, [EV.supBeef, EV.swanMilk, ...NORMAL]), EV.swanMilk); return { cap: `${k}　${k === 'A' ? '同一列換顏色' : '釘在最上面的大卡'}`, ...m }; };
  const p5 = (k, key) => ({ cap: `${k}　${k === 'A' ? '原本的提示卡換顏色' : '滿版大卡'}・${key === 'supBeef' ? '超級大事件' : '超級黑天鵝'}`, ...ranchEv(key, k === 'A' ? promptA : promptB) });
  const rows = [
    ['01 改名的價錢（第二次以後的樣子；第一次都免費）', ['A', 'B', 'C'].map(later)],
    ['02 頭像可以選哪些牛（換頭像免費）', [{ cap: 'A　全部 24 種', html: ranchPage(ctx, { overlays: avSheet('all') }) }, { cap: 'B　只有發現過的', html: ranchPage(ctx, { overlays: avSheet('found') }) }]],
    ['04 市場的新聞卡', ['A', 'B'].map(n4)],
    ['05 牧場頁的提示', [p5('A', 'supBeef'), p5('A', 'swanMilk'), p5('B', 'supBeef'), p5('B', 'swanMilk')]],
  ];
  const cells = rows.flatMap((r) => r[1]);
  const body = rows.map(([title, cs]) => `<div class="ov-row"><div class="ov-title">${title}</div><div class="ov-cells">${cs.map(mini).join('')}</div></div>`).join('');
  return {
    html: `<div class="board" style="width:${PAD * 2 + 4 * sw + 3 * 28}px"><div class="b-label">R12-99-總覽對照</div><div class="b-title">第 12 輪：要選的四項</div>
      <div class="b-sub">03 牧場資料的全部狀態（430、390）、06 專屬標題草稿不用選，見各自的圖。</div>${body}</div>`,
    after: async (root) => { const els = root.querySelectorAll('.ov-cell'); for (let i = 0; i < cells.length; i++) if (cells[i].after) await cells[i].after(els[i]); },
  };
}

const BOARDS = [
  ...['A', 'B', 'C'].map((k) => ({ id: `R12-01-${k}`, w: 390, render: () => r1201(k) })),
  ...['A', 'B'].map((k) => ({ id: `R12-02-${k}`, w: 390, render: () => r1202(k) })),
  { id: 'R12-03-430', w: 430, render: r1203 },
  { id: 'R12-03-390', w: 390, render: r1203 },
  ...['A', 'B'].map((k) => ({ id: `R12-04-${k}`, w: 390, render: () => r1204(k) })),
  ...['A', 'B'].map((k) => ({ id: `R12-05-${k}`, w: 390, render: () => r1205(k) })),
  { id: 'R12-06', w: 390, render: r1206 },
  { id: 'R12-99', w: 390, render: r1299 },
];

async function settle() {
  await document.fonts.ready;
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
}
if (q.has('list')) {
  window.__boards = BOARDS.map(({ id, w }) => ({ id, w }));
  window.__ready = true;
} else {
  const b = BOARDS.find((x) => x.id === q.get('b'));
  if (!b) throw new Error(`沒有這張：${q.get('b')}`);
  const out = b.render();
  app.innerHTML = out.html;
  addPencil(app);
  await settle();
  if (out.after) await out.after(app);
  await settle();
  // 跟 m2 的 main.js 一樣的調整（繁中 430、390 都不會變，照樣跑）
  if (fitTitles(app)) await settle();
  if (fitOriginTags(app) + placeVersion(app)) await settle();
  if (fitSwipeHint(app) + fitMiniLines(app)) await settle();
  if (placeCowPop(app)) await settle();
  if (fitGrade(app)) await settle();
  if (fitActions(app) + fitMyRank(app)) await settle();
  const el = app.querySelector('.board');
  window.__file = el.querySelector('.b-label').textContent;
  window.__size = { w: Math.ceil(el.offsetWidth), h: Math.ceil(el.offsetHeight) };
  window.__ready = true;
}
