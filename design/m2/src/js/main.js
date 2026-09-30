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

if (q.has('list')) {
  window.__states = STATES.map(({ render, ...m }) => m);
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
  if (st.tall && ph) {
    const c = ph.querySelector('.content');
    h = Math.max(dev.h, Math.ceil(c.offsetTop + c.scrollHeight));
    ph.style.height = `${h}px`;
    ph.insertAdjacentHTML('beforeend', `<div class="fold-line" style="top:${dev.h}px"><span>手機一個畫面到這裡</span></div>`);
    await settle();
  }
  if (st.type !== 'sheet') { window.__size = { w: dev.w, h }; window.__ready = true; }
}
