// 三種風格共用的畫面骨架：同一組假資料、同一個 DOM 結構，外觀由各風格的 kit 與 CSS 決定。
// kit 需要提供：icon(name, opts)、num(text, role)、avatar()、spark(series, dir)、bucket(pct)、scene(el) → { bubble:[x,y] }、after?(root)
import { FARM, HERD } from './data.js';

const statusIcons = `
<svg width="18" height="12" viewBox="0 0 18 12" aria-hidden="true"><g fill="#111114"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></g></svg>
<svg width="16" height="12" viewBox="0 0 16 12" aria-hidden="true"><g fill="none" stroke="#111114" stroke-width="2" stroke-linecap="round"><path d="M1.5 4.2a9.5 9.5 0 0 1 13 0"/><path d="M4.2 7a5.6 5.6 0 0 1 7.6 0"/></g><circle cx="8" cy="10" r="1.6" fill="#111114"/></svg>
<svg width="27" height="13" viewBox="0 0 27 13" aria-hidden="true"><rect x="0.8" y="0.8" width="22.4" height="11.4" rx="3.4" fill="none" stroke="#111114" stroke-opacity="0.45" stroke-width="1.2"/><rect x="2.6" y="2.6" width="18.8" height="7.8" rx="2" fill="#111114"/><path d="M24.6 4.4v4.2a2.1 2.1 0 0 0 0-4.2z" fill="#111114" fill-opacity="0.5"/></svg>`;

export function mount(kit) {
  const app = document.getElementById('app');
  const n = kit.num;
  const [milk, beef] = FARM.market;
  const S = FARM.storage;
  const bk = FARM.bucket;

  const market = (m) => `
    <article class="card market ${m.dir}" data-key="${m.key}">
      <div class="mk-head row">
        <span class="mk-icon">${kit.icon(m.key === 'milk' ? 'bottle' : 'crate', { small: true })}</span>
        <span class="mk-name nowrap">${m.label}</span>
        <span class="mk-chg nowrap">${kit.icon(m.dir === 'up' ? 'up' : 'down')}${n(m.change, 'chg', { dir: m.dir })}</span>
      </div>
      <div class="mk-body row">
        <span class="mk-price nowrap">${n(m.price, 'price')}</span>
        <span class="mk-spark">${kit.spark(m.series, m.dir)}</span>
      </div>
    </article>`;

  app.innerHTML = `
  <div class="phone style-${kit.name}">
    <div class="scene" id="scene"></div>
    <div class="overlays" id="overlays"></div>

    <header class="hud">
      <div class="profile">
        <div class="avatar">${kit.avatar()}</div>
        <div class="profile-text">
          <div class="farm-name" data-oneline>${FARM.name}</div>
          <div class="farm-level"><span class="lv">${n(FARM.level, 'lv')}</span><span class="title">${FARM.title}</span></div>
        </div>
      </div>
      <div class="coins"><span class="coin-icon">${kit.icon('coin')}</span><span class="coin-val">${n(FARM.coins, 'coins')}</span></div>
    </header>

    <div class="ticker">
      <span class="ticker-icon">${kit.icon('news')}</span>
      <div class="ticker-track"><span class="ticker-text">${FARM.news}</span></div>
    </div>

    <section class="dock">
      <article class="card bucket">
        <div class="card-head row"><span class="card-title nowrap">${bk.label}</span><span class="bucket-pct nowrap">${n(bk.pct + '%', 'pct')}</span></div>
        <div class="bucket-body row">
          <div class="bucket-icon">${kit.bucket(bk.pct)}</div>
          <div class="bucket-info">
            <div class="bar"><i style="width:${bk.pct}%"></i></div>
            <div class="bucket-count nowrap">${n(`${bk.cur}/${bk.max}`, 'count')}<span class="unit">${bk.unit}</span></div>
          </div>
        </div>
      </article>
      <article class="card storage">
        <div class="card-head row"><span class="card-title nowrap">${S.label}</span></div>
        <div class="stock milk row">
          <span class="stock-icon">${kit.icon('bottle')}</span>
          <div class="stock-text">
            <div class="stock-line nowrap"><span class="stock-name">${S.milk.label}</span>${n(String(S.milk.qty), 'qty')}<span class="unit">${S.milk.unit}</span></div>
            <div class="fresh nowrap">${kit.icon('leaf')}<span class="fresh-label">${S.milk.freshLabel}</span>${n(S.milk.fresh + '%', 'fresh')}</div>
          </div>
        </div>
        <div class="stock beef row">
          <span class="stock-icon">${kit.icon('crate')}</span>
          <div class="stock-text">
            <div class="stock-line nowrap"><span class="stock-name">${S.beef.label}</span>${n(String(S.beef.qty), 'qty')}<span class="unit">${S.beef.unit}</span></div>
          </div>
        </div>
      </article>
      ${market(milk)}
      ${market(beef)}
    </section>

    <nav class="tabbar">
      ${FARM.tabs.map((t) => `<button class="tab${t.active ? ' active' : ''}" data-tab="${t.key}" ${t.active ? 'aria-current="page"' : ''}>
        <span class="tab-icon">${kit.icon('tab-' + t.key, { active: !!t.active })}</span><span class="tab-label">${t.label}</span></button>`).join('')}
    </nav>

    <div class="sim-statusbar" aria-hidden="true"><span class="sb-time">9:41</span><span class="sb-icons">${statusIcons}</span></div>
    <div class="sim-home-indicator" aria-hidden="true"></div>
  </div>`;

  const anchors = kit.scene(document.getElementById('scene'), HERD) || {};
  if (anchors.bubble) {
    const [x, y] = anchors.bubble;
    document.getElementById('overlays').insertAdjacentHTML('beforeend',
      `<div class="bubble" style="left:${x}px;top:${y}px">${kit.icon('bubble')}<span class="bubble-text">${FARM.bubble}</span></div>`);
  }
  if (kit.after) kit.after(app);
}

export async function ready() {
  await document.fonts.ready;
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
  window.__ready = true;
}
