// S17 田地與耕田。照協定：稻米在田裡持續長，每塊田最多存這頭耕牛壯年 8 小時的量，長滿就停（企劃書 4.0）。
import { frame, btn, icon, fmt, bar, cowSVG, sheet, toast, tierChip, badge, BREEDS } from '../kit.js';
import { FIELDS, FIELD_UP, cowById, WAREHOUSE, sum, RANCH } from '../fixtures.js';
import { drawCow } from '../../cow/render.js';
import { tierOf } from '../../cow/breeds.js';
import { t, tb, dur, cowName, calfName } from '../i18n.js';

const L = '#4B3326';
// 田地場景：每塊田一格水田，稻子依長滿的比例長高，長滿變金黃；有牛的田，牛站在田前面
export function fieldScene(w, fields) {
  const h = 150, n = Math.min(fields.length, 4), pw = (w - 16) / Math.max(n, 3), o = [];
  o.push(`<defs><linearGradient id="fsky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#94D3FF"/><stop offset="1" stop-color="#E4F6FF"/></linearGradient></defs>`);
  o.push(`<rect width="${w}" height="${h}" fill="url(#fsky)"/>`);
  o.push(`<circle cx="${w - 34}" cy="26" r="12" fill="#FFE58A" stroke="${L}" stroke-width="2.2"/>`);
  o.push(`<path d="M-10,64 C${w * 0.2},44 ${w * 0.45},48 ${w * 0.6},60 C${w * 0.75},46 ${w * 0.9},44 ${w + 10},58 L${w + 10},90 L-10,90Z" fill="#C6ECAB" stroke="#8CC77E" stroke-width="2.2"/>`);
  o.push(`<rect x="-4" y="70" width="${w + 8}" height="${h}" fill="#AEE594" stroke="${L}" stroke-width="2.6"/>`);
  fields.slice(0, n).forEach((f, i) => {
    const x0 = 8 + pw * i + 4, x1 = x0 + pw - 8, yt = 80, yb = h - 10;
    o.push(`<path d="M${x0 + 6},${yt} H${x1 - 6} L${x1},${yb} H${x0}Z" fill="${f.cow ? '#9CC9E8' : '#C99A6B'}" stroke="${L}" stroke-width="2.4" stroke-linejoin="round"/>`);
    if (f.cow) {
      o.push(`<path d="M${x0 + 12},${yt + 8} h${(x1 - x0) * 0.3}" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" opacity="0.8"/>`);
      // 稻子：一叢三片葉，依長滿的比例長高；長滿變金黃、穗往下垂
      const ratio = f.rice / f.cap, ripe = ratio >= 1, hh = 7 + 17 * Math.min(1, ratio);
      const col = ripe ? '#E0AE3C' : '#6DBB55';
      for (let r = 0; r < 4; r++) for (let c = 0; c < 7; c++) {
        const t = (c + 0.5 + (r % 2) * 0.5) / 7.5, y = yt + 14 + r * 14, xl = x0 + 4 + r * 1.5, xr = x1 - 4 - r * 1.5, x = xl + (xr - xl) * t;
        const k = 0.75 + r * 0.1;
        o.push(`<path d="M${x},${y} q-${3 * k},-${hh * 0.5 * k} -${5 * k},-${hh * 0.8 * k}M${x},${y} q0,-${hh * 0.6 * k} ${ripe ? 2 : 0},-${hh * k}M${x},${y} q${3 * k},-${hh * 0.5 * k} ${5 * k},-${hh * 0.8 * k}" fill="none" stroke="${col}" stroke-width="${1.8 * k}" stroke-linecap="round"/>`);
        if (ripe) o.push(`<ellipse cx="${x + 3 * k}" cy="${y - hh * k + 3}" rx="${2.4 * k}" ry="${1.5 * k}" transform="rotate(35 ${x + 3 * k} ${y - hh * k + 3})" fill="#FFD35C" stroke="${L}" stroke-width="0.8"/>`);
      }
      const c = cowById(f.cow);
      const cow = drawCow({ breed: c.breed, sex: c.sex, pose: 'side', seed: c.seed }, { x: x0 + (x1 - x0) * 0.3, y: yb + 4, scale: 0.4, facing: 'right', id: `fs${i}` });
      o.push(`<ellipse cx="${cow.shadow.cx}" cy="${yb - 1}" rx="${cow.shadow.rx}" ry="${cow.shadow.ry}" fill="#6FA7C9" opacity="0.6"/>${cow.svg}`);
    } else {
      for (let r = 0; r < 3; r++) o.push(`<path d="M${x0 + 8 + r * 2},${yt + 18 + r * 18} H${x1 - 8 - r * 2}" stroke="#B0804F" stroke-width="2.4" stroke-linecap="round"/>`);
    }
    o.push(`<rect x="${(x0 + x1) / 2 - 12}" y="${yt - 13}" width="24" height="18" rx="6" fill="#FFFFFF" stroke="${L}" stroke-width="2"/><text x="${(x0 + x1) / 2}" y="${yt + 1}" text-anchor="middle" font-family="Noto Sans CJK TC" font-weight="900" font-size="12" fill="${L}">${f.index + 1}</text>`);
  });
  return `<svg viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" aria-hidden="true">${o.join('')}</svg>`;
}

function until(f) {
  const m = Math.ceil(((f.cap - f.rice) / f.rate) * 60);
  return m >= 60 ? `${t('hours', { h: Math.floor(m / 60) })} ${t('minutes', { m: m % 60 })}` : t('minutes', { m });
}
function fieldCard(f, o = {}) {
  const head = `<div class="fc-head"><span class="fc-no">${t('fieldName', { n: f.index + 1 })}</span>`;
  if (!f.cow) {
    const left = f.rice > 0 ? `<p class="hint">${t('s17.leftover', { kg: `<b class="num">${fmt(f.rice, 1)}</b>` })}</p>` : `<p class="hint">${t('s17.emptyHint')}</p>`;
    return `<article class="card field-card empty">${head}${badge('lock', t('fieldEmpty'))}</div>${left}
      ${o.noOx ? `<p class="warn-text">${icon('warn', 16)} ${t('noOx')}</p>` : ''}${btn(t('assignOx'), { kind: 'green', small: true, ic: 'sprout', disabled: o.noOx, block: true })}</article>`;
  }
  // 田裡剩的稻米比這頭牛的上限多（叫回稀有耕牛後改派一般耕牛）：照長滿了顯示，進度條到滿為止，數字只寫公斤數（缺口清單 2-5）
  const c = cowById(f.cow), b = BREEDS[c.breed], full = f.rice >= f.cap, over = f.rice > f.cap, p = Math.min(100, (f.rice / f.cap) * 100);
  return `<article class="card field-card${full ? ' full' : ''}">${head}${full ? `<span class="badge full">${t('s17.full')}</span>` : badge('working', t('badgeWorking'))}</div>
    <div class="fc-ox">${cowSVG({ breed: c.breed, sex: c.sex, seed: c.seed }, { w: 52, h: 52, pad: 2 })}<div class="grow"><b>${cowName(c.breed, c.id)}</b><div class="chips">${tierChip(tierOf(b))}<span class="hint">${t('fieldRate', { v: f.rate })}</span></div></div>${btn(t('recall'), { small: true, ic: 'hand' })}</div>
    <div class="fc-bar">${bar(p, { color: full ? 'yellow' : 'green' })}<span class="num">${over ? fmt(f.rice, 1) : `${fmt(f.rice, 1)} / ${fmt(f.cap, 1)}`}</span><small>${t('g.kg')}</small></div>
    <p class="${full ? 'warn-text' : 'hint'}">${full ? t('fieldFull') : t('s17.fullIn', { time: until(f), h: 8 })}</p></article>`;
}

function fieldsPage(ctx, o = {}) {
  const fields = o.fields || FIELDS;
  const inField = fields.reduce((s, f) => s + (f.rice || 0), 0);
  const rate = fields.reduce((s, f) => s + (f.cow ? (f.rice >= f.cap ? 0 : f.rate) : 0), 0);
  const w = ctx.dev.w - 24;
  const content = `<div class="stack">
    <article class="card field-scene">${fieldScene(w - 6, fields)}</article>
    <div class="kv kv3"><div class="cell"><div class="k">${t('fieldsTitle')}</div><div class="v num">${fields.length} <small>${t('s17.ofMax', { max: FIELD_UP.max })}</small></div></div><div class="cell"><div class="k">${t('s17.stock')}</div><div class="v num">${fmt(o.stock ?? sum(WAREHOUSE.rice))} <small>${t('g.kg')}</small></div></div><div class="cell"><div class="k">${t('s17.perHour')}</div><div class="v num">${fmt(rate, 1)} <small>${t('g.kg')}</small></div></div></div>
    ${btn(inField > 0 ? t('harvestAll', { kg: fmt(inField) }) : t('s17.harvestNone'), { kind: 'green', block: true, ic: 'rice', disabled: inField <= 0 || o.offline })}
    ${fields.map((f) => fieldCard(f, o.card || {})).join('')}
    ${o.newField || btn(t('expandField', { cost: fmt(FIELD_UP.cost) }), { block: true, ic: 'plus' })}
  </div>`;
  const out = frame(ctx.dev, { tab: 'fields', content, tall: o.tall, overlays: o.overlays || '', offline: o.offline, hud: o.hud || {} });
  if (!o.scrollTo) return out;
  return { html: out, after: (root) => { const c = root.querySelector('.content'); const el = root.querySelector(o.scrollTo); if (c && el) c.scrollTop = el.offsetTop - 6; } };
}

const S = [];
const full = (id, name, render, x = {}) => S.push({ id, name, type: 'full', render, ...x });
const part = (id, name, crop, render, x = {}) => S.push({ id, name, type: 'part', crop, render, ...x });

full('S17-01', '一般：田地場景與每塊田（長頁）', (ctx) => fieldsPage(ctx, { tall: true }), { tall: true });
part('S17-02', '空田：沒有能下田的耕牛時停用', '.field-card.empty', (ctx) => fieldsPage(ctx, { card: { noOx: true }, scrollTo: '.field-card.empty' }));
full('S17-03', '選一頭耕牛下田', (ctx) => fieldsPage(ctx, {
  fields: [FIELDS[0], FIELDS[1], { ...FIELDS[2] }],
  // 列出全部耕牛：能下田的（產量高的先）→ 在田裡的（田號小的先）→ 上架中的 → 小牛（快長大的先）；預選第一頭能下田的（cow-app #108，ceo 2026-10-03）
  overlays: sheet({ cls: 'ox-pick', title: t('pickOx', { n: 2 }), body: `<div class="list" data-scroll>
    <button class="card ox-opt on">${cowSVG({ breed: 'milkTea', sex: 'bull', seed: 101 }, { w: 56, h: 56, pad: 2 })}<div class="grow"><b>${cowName('milkTea', 18)}</b><div class="chips">${tierChip(1)}<span class="hint">${t('fieldRate', { v: 14.3 })}</span></div></div><span class="pick-check static">${icon('ok', 24)}</span></button>
    <button class="card ox-opt off" disabled>${cowSVG({ breed: 'yellow', sex: 'bull', seed: 17 }, { w: 56, h: 56, pad: 2 })}<div class="grow"><b>${cowName('yellow', 2)}</b><div class="chips">${badge('working', t('s17.inField', { n: 1 }))}</div></div></button>
    <button class="card ox-opt off" disabled>${cowSVG({ breed: 'highland', sex: 'cow' }, { w: 56, h: 56, pad: 2 })}<div class="grow"><b>${cowName('highland', 9)}</b><div class="chips">${badge('working', t('s17.inField', { n: 3 }))}</div></div></button>
    <button class="card ox-opt off" disabled>${cowSVG({ breed: 'yellow', age: 'calf', seed: 105 }, { w: 56, h: 56, pad: 2 })}<div class="grow"><b>${calfName('draft', 19)}</b><div class="chips">${badge('calf', t('stageCalf'))}<span class="hint">${t('g.growsIn', { time: dur({ h: 1 }) })}</span></div></div></button></div>
    <div class="btn-row" style="margin-top:14px">${btn(t('cancel'))}${btn(t('g.assign'), { kind: 'green', ic: 'sprout' })}</div>` }),
}));
part('S17-04', '沒有能下田的耕牛', '.sheet', (ctx) => fieldsPage(ctx, { overlays: sheet({ title: t('pickOx', { n: 2 }), body: `<div class="empty">${cowSVG({ breed: 'yellow', sex: 'bull', seed: 33 }, { w: 90, h: 90, sil: true })}<div class="t1">${t('noOx')}</div><div class="t2">${tb('s17.noOxHint')}</div></div>${btn(t('g.gotIt'), { block: true })}` }) }));
part('S17-05', '耕作中：進度、產量、叫回', '.field-card', (ctx) => fieldsPage(ctx, { scrollTo: '.field-card' }));
full('S17-06', '長滿了，快收成', (ctx) => fieldsPage(ctx, { scrollTo: '.field-card.full' }));
part('S17-07', '叫回後田裡還有稻米', '.field-card.empty', (ctx) => fieldsPage(ctx, { fields: [FIELDS[0], { index: 1, cow: null, rice: 20.4 }, FIELDS[2]], scrollTo: '.field-card.empty' }));
part('S17-08', '田裡沒有稻米：收成鈕停用', '.content .stack > .btn', (ctx) => fieldsPage(ctx, { fields: [{ index: 0, cow: 2, rice: 0, cap: 88, rate: 11 }, { index: 1, cow: null, rice: 0 }, { index: 2, cow: null, rice: 0 }] }));
full('S17-09', '收成成功', (ctx) => fieldsPage(ctx, { stock: 361, fields: [{ ...FIELDS[0], rice: 0 }, FIELDS[1], { ...FIELDS[2], rice: 0 }], overlays: toast('ok', t('harvested', { kg: 177 })) }));
part('S17-10', '開新田：金幣不夠、已經 12 塊', '#crop', (ctx) => frame(ctx.dev, { tab: 'fields', content: `<div id="crop" class="stack">${btn(t('expandField', { cost: fmt(FIELD_UP.cost) }), { block: true, ic: 'plus', disabled: true })}<p class="warn-text" style="text-align:center">${t('notEnoughCoins', { n: fmt(FIELD_UP.cost - 3200) })}</p>${btn(t('s17.maxFields', { n: 12 }), { block: true, disabled: true })}</div>`, hud: { coins: 3200 } }));
part('S17-11', '開新田成功', '.toast', (ctx) => fieldsPage(ctx, { hud: { coins: RANCH.coins - FIELD_UP.cost }, fields: [...FIELDS, { index: 3, cow: null, rice: 0 }], overlays: toast('ok', t('fieldExpanded', { n: 4 })) }));
// 第 1 塊田：之前的稀有耕牛長了 120 公斤，叫回後改派一般耕牛（上限 88 公斤），伺服器不會再長
part('S17-12', '田裡剩的稻米比這頭牛的上限多', '.field-card', (ctx) => fieldsPage(ctx, { fields: [{ ...FIELDS[0], rice: 120 }, FIELDS[1], FIELDS[2]], scrollTo: '.field-card' }), { board: '剩的稻米-狀態表' });

export default { id: 'S17', name: '田地', states: S };
