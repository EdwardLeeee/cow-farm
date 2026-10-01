// A-03 出貨卡車的畫法（從 anims.js 搬出來，素材匯出 harness/assetexport.mjs 也用這一份；畫法沒有改）
// 小貨車（側面，車頭在右）：木柵車斗、車尾擋板放下來當斜坡、車窗、後照鏡、頭燈、保險桿、會轉的輪子。
// 分兩層畫：back（遠側柵欄、車斗地板、車頭）在牛後面，front（近側柵欄、車斗側板、擋板、輪子）在牛前面，牛坐在車斗裡。
export const TK = { w: 270, h: 152, hinge: [12, 100], floor: 98, wheelR: 18, wheels: [62, 204], bedCx: 82 };
export const WOOD = '#F5D9A8', WOOD_D = '#DDBB86', INK3 = '#4B3326';
export function truckBack() {
  return `<svg viewBox="0 0 ${TK.w} ${TK.h}" width="${TK.w}" height="${TK.h}" aria-hidden="true">
    <!-- 遠側的柵欄（顏色深一點） -->
    <g fill="${WOOD_D}" stroke="${INK3}" stroke-width="2.2" stroke-linejoin="round">
      <rect x="20" y="40" width="5" height="36" rx="1.5"/><rect x="56" y="40" width="5" height="36" rx="1.5"/><rect x="92" y="40" width="5" height="36" rx="1.5"/><rect x="128" y="40" width="5" height="36" rx="1.5"/>
      <rect x="16" y="43" width="136" height="7" rx="3"/><rect x="16" y="59" width="136" height="7" rx="3"/>
    </g>
    <!-- 底盤、排氣管、車斗地板 -->
    <rect x="2" y="108" width="18" height="6" rx="3" fill="#B9ADA3" stroke="${INK3}" stroke-width="2.2"/>
    <rect x="16" y="104" width="236" height="11" rx="4" fill="#7A675D" stroke="${INK3}" stroke-width="3"/>
    <rect x="12" y="95" width="142" height="11" rx="3" fill="#D9A777" stroke="${INK3}" stroke-width="3"/>
    <!-- 車頭 -->
    <path d="M154,108 V40 a8,8 0 0 1 8,-8 H200 a10,10 0 0 1 9,5.4 L226,68 H246 a12,12 0 0 1 12,12 V108 Z" fill="#FFD45E" stroke="${INK3}" stroke-width="3.5" stroke-linejoin="round"/>
    <path d="M155.8,88 H256.2 V95 H155.8 Z" fill="#FFF4CC"/>
    <path d="M164,42 H197 a6,6 0 0 1 5.4,3.2 L215,68 H164 Z" fill="#D6ECFA" stroke="${INK3}" stroke-width="2.6" stroke-linejoin="round"/>
    <path d="M170,62 L182,46 M178,63 L186,52" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" opacity="0.9"/>
    <path d="M163,74 V103 H207 V74" fill="none" stroke="#E0A93E" stroke-width="2" stroke-linejoin="round"/>
    <rect x="168" y="77" width="11" height="4.6" rx="2.3" fill="#FFF4DE" stroke="${INK3}" stroke-width="1.6"/>
    <path d="M214,60 h6" stroke="${INK3}" stroke-width="2.4" stroke-linecap="round"/><rect x="218" y="50" width="7" height="14" rx="3" fill="#7A675D" stroke="${INK3}" stroke-width="2"/>
    <rect x="171" y="24" width="16" height="8.5" rx="4" fill="#FF9F5E" stroke="${INK3}" stroke-width="2.2"/>
    <ellipse cx="253.5" cy="83" rx="4.6" ry="6" fill="#FFF1B8" stroke="${INK3}" stroke-width="2.2"/>
    <path d="M244,95.5 h9 M244,99.5 h9" stroke="#C99A3A" stroke-width="1.8" stroke-linecap="round"/>
    <rect x="243" y="101" width="22" height="10" rx="4.5" fill="#F1EADF" stroke="${INK3}" stroke-width="2.6"/>
  </svg>`;
}
export function wheel(cx) {
  const cy = TK.h - 6 - TK.wheelR, r = TK.wheelR;
  const spokes = [0, 60, 120].map((d) => `<path d="M${cx - 9.5},${cy} H${cx + 9.5}" transform="rotate(${d} ${cx} ${cy})" stroke="#D9C8A8" stroke-width="2.2" stroke-linecap="round"/>`).join('');
  return `<g class="tk-wheel" data-cx="${cx}" data-cy="${cy}"><circle cx="${cx}" cy="${cy}" r="${r}" fill="#5A4038" stroke="${INK3}" stroke-width="3"/><circle cx="${cx}" cy="${cy}" r="10.6" fill="#FFF4DE" stroke="${INK3}" stroke-width="2.2"/>${spokes}<circle cx="${cx}" cy="${cy}" r="3.8" fill="#F5BD83" stroke="${INK3}" stroke-width="1.8"/></g>`;
}
export function truckFront(name) {
  const [hx, hy] = TK.hinge;
  return `<svg viewBox="0 0 ${TK.w} ${TK.h}" width="${TK.w}" height="${TK.h}" aria-hidden="true" style="overflow:visible">
    <!-- 近側的柵欄 -->
    <g fill="${WOOD}" stroke="${INK3}" stroke-width="2.6" stroke-linejoin="round">
      <rect x="14" y="38" width="6" height="40" rx="2"/><rect x="50" y="38" width="6" height="40" rx="2"/><rect x="86" y="38" width="6" height="40" rx="2"/><rect x="122" y="38" width="6" height="40" rx="2"/><rect x="146" y="38" width="6" height="40" rx="2"/>
      <rect x="12" y="43" width="142" height="8" rx="3.5"/><rect x="12" y="59" width="142" height="8" rx="3.5"/>
    </g>
    <!-- 車斗側板與牧場名 -->
    <rect x="12" y="74" width="142" height="27" rx="5" fill="#A9DBFF" stroke="${INK3}" stroke-width="3.2"/>
    <path d="M19,80.5 H118" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" opacity="0.75"/>
    <text x="83" y="96" text-anchor="middle" font-family="Noto Sans CJK TC" font-weight="900" font-size="11.5" fill="${INK3}">${name}</text>
    <!-- 尾燈、倒車燈 -->
    <rect x="13.5" y="77" width="5.5" height="8" rx="2" fill="#FF6B5E" stroke="${INK3}" stroke-width="1.6"/>
    <rect id="tk-rev" x="13.5" y="88" width="5.5" height="8" rx="2" fill="#FFF7D6" stroke="${INK3}" stroke-width="1.6"/>
    <!-- 車尾擋板：關著是直的，放下來變斜坡（以車斗地板後緣為軸） -->
    <g id="tk-gate" data-hx="${hx}" data-hy="${hy}"><rect x="${hx - 6}" y="${hy - 60}" width="8" height="62" rx="3" fill="${WOOD}" stroke="${INK3}" stroke-width="2.8"/><path d="M${hx - 2},${hy - 52} V${hy - 8}" stroke="${WOOD_D}" stroke-width="2" stroke-linecap="round"/></g>
    <!-- 擋泥板、輪子 -->
    <path d="M38,${TK.h - 22} a24,24 0 0 1 48,0 h-7 a17,17 0 0 0 -34,0 Z" fill="#8CC8F5" stroke="${INK3}" stroke-width="2.6" stroke-linejoin="round"/>
    <path d="M180,${TK.h - 22} a24,24 0 0 1 48,0 h-7 a17,17 0 0 0 -34,0 Z" fill="#FFC53D" stroke="${INK3}" stroke-width="2.6" stroke-linejoin="round"/>
    ${TK.wheels.map(wheel).join('')}
  </svg>`;
}

// 留在牧場的牛，站在後面看
export const A03_HERD = [
  { id: 8, breed: 'holstein', sex: 'bull', seed: 23, x: 318, y: 338, facing: 'left', depth: 0 },
  { id: 15, breed: 'holstein', age: 'calf', seed: 31, x: 148, y: 420, facing: 'right', depth: 1 },
  { id: 7, breed: 'jersey', x: 262, y: 404, facing: 'left', depth: 1 },
];
