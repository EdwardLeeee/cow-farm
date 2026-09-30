// S02 新手：轉輪挑牧場名（企劃書 4.11、4.13）。詞庫：backend/server/data/ranch_words.json
import { frame, btn, cowSVG, icon, dialog } from '../kit.js';

const WORDS = {
  first: ['晨光', '青草', '白雲', '星河', '楓葉', '暖陽', '微風', '山嵐', '月牙', '麥浪', '彩虹', '露珠'],
  second: ['小丘', '河畔', '原野', '松林', '花田', '湖邊', '坡地', '竹林', '石橋', '溪谷', '谷地', '森林'],
  third: ['牧場', '農莊', '牧園', '農場', '乳坊', '牛舍', '莊園', '牧舍', '小屋', '家園', '田園', '牧野'],
};
// 每個轉輪顯示 5 格，中間那格是選到的
function wheel(list, pick, { spin = false } = {}) {
  const i = list.indexOf(pick);
  const items = [-2, -1, 0, 1, 2].map((d) => list[(i + d + list.length) % list.length]);
  return `<div class="wheel${spin ? ' spin' : ''}">${items.map((w, k) => `<div class="w-item${k === 2 ? ' on' : ''}${Math.abs(k - 2) === 2 ? ' far' : ''}">${w}</div>`).join('')}</div>`;
}
function page(ctx, { a = '晨光', b = '河畔', c = '牧場', spin = false, overlays = '' } = {}) {
  const content = `<div class="namer">
    <div class="namer-head">
      ${cowSVG({ breed: 'holstein' }, { w: 84, h: 84, pose: 'front' })}
      <div><h1>幫牧場取個名字</h1><p class="hint">轉出喜歡的組合就可以了。</p></div>
    </div>
    <div class="card wheels-card">
      <div class="wheel-caps"><span>景色</span><span>地形</span><span>稱呼</span></div>
      <div class="wheels">${wheel(WORDS.first, a, { spin })}${wheel(WORDS.second, b, { spin })}${wheel(WORDS.third, c, { spin })}</div>
      <div class="name-preview">${spin ? '<span class="muted">轉動中…</span>' : `<span class="num">${a}${b}${c}</span>`}</div>
    </div>
    <p class="hint" style="text-align:center">名字只能從轉輪裡選，不能自己打字；<br>跟別人同名也沒關係，會加上 #編號分辨。</p>
    <div class="btn-row">${btn('重轉', { ic: 'refresh', disabled: spin })}${btn('就叫這個', { kind: 'primary', disabled: spin })}</div>
  </div>`;
  return frame(ctx.dev, { tab: null, hud: false, content, overlays });
}

const S = [];
const full = (id, name, render, x = {}) => S.push({ id, name, type: 'full', render, ...x });

full('S02-01', '三個轉輪', (ctx) => page(ctx));
full('S02-02', '選好後：歡迎卡與開局的牛', (ctx) => page(ctx, {
  overlays: dialog({
    title: '歡迎來到<br>晨光河畔牧場 #1234',
    body: `<p style="text-align:center">先送你這些，開始經營吧！</p>
      <div class="gift-row">
        <div class="gift">${cowSVG({ breed: 'holstein' }, { w: 96, h: 96, pose: 'front' })}<b>荷斯坦 #1</b><span>母・會產奶</span></div>
        <div class="gift">${cowSVG({ breed: 'yellow', sex: 'bull', age: 'calf', seed: 33 }, { w: 96, h: 96, pose: 'front' })}<b>台灣黃牛 #2</b><span>公・20 分後長大</span></div>
      </div>
      <div class="gift-coin">${icon('coin', 26)}<b class="num">100</b> 幣　${icon('pail', 22)}奶桶裡已經有 <b class="num">20</b> 瓶</div>
      <p class="hint" style="text-align:center;margin-top:4px">開局 1 小時產奶 ×5，進去就能收奶、賣奶。</p>`,
    buttons: btn('進牧場', { kind: 'primary', block: true }),
  }),
}));
full('S02-03', '轉輪轉動中', (ctx) => page(ctx, { a: '麥浪', b: '松林', c: '乳坊', spin: true }));

export default { id: 'S02', name: '轉輪取名', states: S };
