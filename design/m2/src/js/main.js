// 路由：?id=S03-02&w=390 畫一個狀態；?list=1 列出全部狀態給出圖腳本。
import { applyDevice } from './kit.js';
import { STATES } from './states.js';

const q = new URLSearchParams(location.search);
const w = +(q.get('w') || 390);
const dev = applyDevice(w);
const app = document.getElementById('app');

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
    if (st.type === 'full') ph.insertAdjacentHTML('beforeend', `<div class="fold-line" style="top:${dev.h}px"><span>手機一個畫面到這裡</span></div>`);
    await settle();
  }
  if (st.type !== 'sheet') { window.__size = { w: dev.w, h }; window.__ready = true; }
}
