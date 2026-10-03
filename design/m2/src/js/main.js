// 路由：?id=S03-02&w=390 畫一個狀態；?list=1 列出全部狀態給出圖腳本；?lang=en｜th 換語言（預設繁中）。
import { applyDevice, fitTitles, fitOriginTags, placeVersion, fitSwipeHint, fitMiniLines, placeCowPop, fitGrade, fitActions, fitRankRows, fitMyRank } from './kit.js';
import { loadLang } from './i18n.js';

const q = new URLSearchParams(location.search);
const w = +(q.get('w') || 390);
const dev = applyDevice(w);
const app = document.getElementById('app');
// 先載入字串表，再載入各畫面（畫面模組的常數會用到字串）
const lang = q.get('lang') || 'zh-Hant';
await loadLang(lang);
// 泰文：泰文字型接在中文字型後面（英文字母、數字照舊用中文字型裡的，泰文字才用 Noto Sans Thai）
if (lang === 'th') document.documentElement.style.setProperty('--font-ui', '"Noto Sans CJK TC", "Noto Sans Thai", "Noto Sans TC", sans-serif');
const { STATES } = await import('./states.js');

async function settle() {
  await document.fonts.ready;
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
}

if (q.has('anim')) {
  // 動畫：?anim=A-01&w=390 畫底圖，window.__frame(t) 把畫面停在第 t 秒
  const { ANIMS } = await import('./anims.js');
  const a = ANIMS.find((x) => x.id === q.get('anim'));
  const ctx = { dev, w, q };
  app.innerHTML = a.base(ctx);
  window.__frame = async (t) => { a.frame(app, t, ctx); await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))); };
  window.__animMeta = { id: a.id, name: a.name, dur: a.dur, keys: a.keys, reduced: a.reduced, where: a.where, gifDpr: a.gifDpr || 1, loop: !!a.loop };
  await settle();
  if (fitGrade(app)) await settle(); // 評級框放不下就整組縮小（A-10；繁中、泰文不會變）
  await window.__frame(0);
  window.__ready = true;
} else if (q.has('list')) {
  window.__states = STATES.map(({ render, ...m }) => m);
  const { ANIMS } = await import('./anims.js');
  window.__anims = ANIMS.map((a) => ({ id: a.id, name: a.name, dur: a.dur, keys: a.keys, reduced: a.reduced, where: a.where, gifDpr: a.gifDpr || 1, loop: !!a.loop }));
  window.__ready = true;
} else {
  const st = STATES.find((s) => s.id === q.get('id'));
  if (!st) throw new Error(`沒有這個狀態：${q.get('id')}`);
  const out = st.render({ dev, w, q });
  app.innerHTML = typeof out === 'string' ? out : out.html;
  if (out && out.after) await out.after(app, dev);
  await settle();
  if (fitTitles(app)) await settle(); // 大標題一行放不下就縮小（英文、泰文；繁中不會變）
  if (fitOriginTags(app) + placeVersion(app)) await settle(); // 大圖的來源標籤不蓋到牛頭；開場的版本號不被框蓋住（繁中 430、390 不會變）
  if (fitSwipeHint(app) + fitMiniLines(app)) await settle(); // 牧場的滑動提示放不下就換行；小卡一行放不下就把左邊縮小（繁中不會變）
  if (placeCowPop(app)) await settle(); // 點後排的牛：名片上面放不下就放到牛的下面（前排的牛不變）
  if (fitGrade(app)) await settle(); // 出貨評級的大框：字放不下就整組縮小（英文；繁中、泰文不會變）
  if (fitActions(app) + fitRankRows(app) + fitMyRank(app)) await settle(); // 牛的詳細：動作區比預留的高時，內容區讓出位置；排行榜的列、下面那一條放不下時「完成」只留打勾，那一條還放不下就整條縮小（繁中 430、390 不會變）
  if (st.type === 'sheet') {
    document.body.style.background = '#FFF9EF';
    window.__size = { w: st.viewport.w, h: Math.ceil(app.scrollHeight) };
    window.__ready = true;
  }
  const ph = app.querySelector('.phone');
  let h = dev.h;
  if (st.tall && ph) { // 長頁：把手機撐高到內容的高度；整頁狀態另外畫「手機一個畫面到這裡」的線
    const c = ph.querySelector('.content');
    h = Math.max(dev.h, Math.ceil(c.offsetTop + c.scrollHeight));
    ph.style.height = `${h}px`;
    if (st.type === 'full') ph.insertAdjacentHTML('beforeend', `<div class="fold-line" style="top:${dev.h}px" data-note><span>手機一個畫面到這裡</span></div>`);
    await settle();
  }
  if (st.type !== 'sheet') { window.__size = { w: dev.w, h }; window.__ready = true; }
}
