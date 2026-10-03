// 第 14 輪 01 打掃小幫手：日系動畫的畫風（使用者 2026-10-03：「你要畫風如日本動漫overload那樣」）。
// 只學畫風（細緻的眼睛、一束一束有亮帶的頭髮、兩階的動畫陰影、粗細有變化的線條、約 7 頭身），角色、長相、服裝都是原創。
// 做法：線條畫成「筆刷」（沿著曲線、寬度會變的填色形狀），每個區塊用 clipPath 疊兩階陰影，虹膜和頭髮的亮帶用漸層。
// 座標：頭長 H = 150（頭頂 y=30、下巴 y=180），臉的中線 x=210；全身約 7 頭身（腳底 y≈1080）。

const f = (n) => Math.round(n * 100) / 100;
let uid = 0;
const nid = (p) => `${p}${++uid}`;

// ---------- 曲線工具 ----------
// Catmull-Rom 取樣（開放曲線）：經過每個點，每段取 per 個點
function sample(pts, per = 10) {
  const n = pts.length, out = [];
  const P = (i) => pts[Math.max(0, Math.min(n - 1, i))];
  for (let i = 0; i < n - 1; i++) {
    const p0 = P(i - 1), p1 = P(i), p2 = P(i + 1), p3 = P(i + 2);
    for (let k = 0; k < per; k++) {
      const t = k / per, t2 = t * t, t3 = t2 * t;
      const q = (a, b, c, d) => 0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3);
      out.push([q(p0[0], p1[0], p2[0], p3[0]), q(p0[1], p1[1], p2[1], p3[1])]);
    }
  }
  out.push(pts[n - 1]);
  return out;
}
// 閉合的平滑形狀（Catmull-Rom → 三次貝茲）
export function shape(pts) {
  const n = pts.length, P = (i) => pts[(i + n) % n];
  let d = `M${f(pts[0][0])},${f(pts[0][1])}`;
  for (let i = 0; i < n; i++) {
    const p0 = P(i - 1), p1 = P(i), p2 = P(i + 1), p3 = P(i + 2);
    d += `C${f(p1[0] + (p2[0] - p0[0]) / 6)},${f(p1[1] + (p2[1] - p0[1]) / 6)} ${f(p2[0] - (p3[0] - p1[0]) / 6)},${f(p2[1] - (p3[1] - p1[1]) / 6)} ${f(p2[0])},${f(p2[1])}`;
  }
  return d + 'Z';
}
const poly = (pts) => pts.map((p, i) => `${i ? 'L' : 'M'}${f(p[0])},${f(p[1])}`).join('') + 'Z';
const ease = (t) => Math.sin((t * Math.PI) / 2);
// 筆刷：沿著經過 pts 的曲線，寬度從 w0（頭）到 w1（中間）到 w2（尾），兩端收尖。回傳 path 的 d
export function brushD(pts, w0, w1, w2 = w0, per = 10) {
  const P = sample(pts, per), n = P.length;
  const len = [0];
  for (let i = 1; i < n; i++) len.push(len[i - 1] + Math.hypot(P[i][0] - P[i - 1][0], P[i][1] - P[i - 1][1]));
  const total = len[n - 1] || 1, L = [], R = [];
  for (let i = 0; i < n; i++) {
    const a = P[Math.max(0, i - 1)], b = P[Math.min(n - 1, i + 1)];
    const dx = b[0] - a[0], dy = b[1] - a[1], dl = Math.hypot(dx, dy) || 1;
    const t = len[i] / total;
    const w = t < 0.5 ? w0 + (w1 - w0) * ease(t / 0.5) : w1 + (w2 - w1) * (1 - Math.cos(((t - 0.5) / 0.5) * Math.PI / 2));
    const nx = -dy / dl, ny = dx / dl;
    L.push([P[i][0] + nx * w / 2, P[i][1] + ny * w / 2]);
    R.push([P[i][0] - nx * w / 2, P[i][1] - ny * w / 2]);
  }
  return poly([...L, ...R.reverse()]);
}
export const brush = (pts, w0, w1, w2, fill, extra = '') => `<path d="${brushD(pts, w0, w1, w2)}" fill="${fill}"${extra}/>`;
const mirrorX = (s, cx = 210) => `<g transform="translate(${cx * 2} 0) scale(-1 1)">${s}</g>`;

// ---------- 顏色（造型 A：蜂蜜金色的頭髮、綠眼睛） ----------
const SKIN = { base: '#FFE8D8', sh: '#F6C2AB', sh2: '#E7A08A', line: '#5C2F27', soft: '#A8665A', blush: '#FF8C8C' };

// ---------- 眼睛（畫右眼，左眼用鏡像） ----------
function eyeR(C, gid) {
  const sclera = 'M222,116.5C226,106 244,99.5 255.5,108.5C251.5,119.5 238.5,126.5 229,124C225.5,123 223.5,120 222,116.5Z';
  const clip = nid('eclip');
  return `<defs><clipPath id="${clip}"><path d="${sclera}"/></clipPath></defs>
    <path d="${sclera}" fill="#FFFFFF"/>
    <g clip-path="url(#${clip})">
      <ellipse cx="238.6" cy="114.6" rx="9.8" ry="11.8" fill="url(#${gid})"/>
      <ellipse cx="238.6" cy="114.6" rx="9.8" ry="11.8" fill="none" stroke="${C.irisRim}" stroke-width="1.3"/>
      <ellipse cx="238.6" cy="114.6" rx="6.6" ry="8.2" fill="none" stroke="${C.irisRim}" stroke-width="0.7" opacity="0.45"/>
      <ellipse cx="238.6" cy="115.6" rx="4.1" ry="6" fill="${C.pupil}"/>
      <ellipse cx="238.6" cy="121.6" rx="6.4" ry="3.2" fill="${C.irisGlow}" opacity="0.85"/>
      <path d="M222,116.5C226,106 244,99.5 255.5,108.5L255,113C244,106 230,108.5 223.5,119.5Z" fill="#3A1F3A" opacity="0.3"/>
      <ellipse cx="234" cy="109.4" rx="3.6" ry="2.6" fill="#FFFFFF" transform="rotate(-22 234 109.4)"/>
      <circle cx="243.8" cy="119.6" r="1.5" fill="#FFFFFF"/><circle cx="232.2" cy="118.6" r="0.9" fill="#FFFFFF" opacity="0.9"/>
    </g>
    ${brush([[220.6, 118], [224, 110.5], [231, 104.6], [240, 101.4], [249.2, 102.8], [257, 108.4]], 0.8, 4.2, 3.2, C.lash)}
    ${brush([[254.5, 106.6], [259.4, 104.4], [263, 104.2]], 2.8, 1.6, 0.3, C.lash)}
    ${brush([[251.6, 103.6], [255.6, 99.6], [258.4, 98.2]], 1.9, 1.1, 0.2, C.lash)}
    ${brush([[247.4, 102.2], [250.4, 97.6], [252.6, 96]], 1.5, 0.9, 0.2, C.lash)}
    ${brush([[240.6, 125.6], [247.6, 122.6], [254.4, 116.4]], 0.3, 1.4, 0.4, C.lash)}
    ${brush([[227.4, 102.6], [238, 97.4], [250.6, 98.8]], 0.3, 1.3, 0.3, SKIN.soft)}
`;
}
const browR = (C) => brush([[225.6, 92.4], [237.6, 87.4], [251.6, 87.6], [258.6, 90.6]], 2.8, 2, 0.4, C.brow, ' opacity="0.9"');
// 眉毛畫在瀏海上面（動畫常見的畫法，瀏海後面的眉毛也看得到）
export const browsA = (C) => `${browR(C)}${mirrorX(browR(C))}`;

// ---------- 頭（臉、眼睛、鼻子、嘴巴、耳朵、脖子）：頭髮另外畫 ----------
export function faceA(C) {
  const gid = nid('iris'), bl = nid('blush');
  const face = shape([[156, 78], [155.4, 100], [158, 124], [165, 145], [178, 162], [194, 174.6], [210, 179.6], [226, 174.6], [242, 162], [255, 145], [262, 124], [264.6, 100], [264, 78], [250, 52], [210, 40], [170, 52]]);
  const neck = 'M191.5,160L228.5,160L232,206L188,206Z';
  const nclip = nid('nclip'), fclip = nid('fclip');
  return `<defs>
      <linearGradient id="${gid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${C.iris1}"/><stop offset="0.55" stop-color="${C.iris2}"/><stop offset="1" stop-color="${C.iris3}"/></linearGradient>
      <radialGradient id="${bl}"><stop offset="0" stop-color="${SKIN.blush}" stop-opacity="0.5"/><stop offset="1" stop-color="${SKIN.blush}" stop-opacity="0"/></radialGradient>
      <clipPath id="${nclip}"><path d="${neck}"/></clipPath><clipPath id="${fclip}"><path d="${face}"/></clipPath>
    </defs>
    <path d="${neck}" fill="${SKIN.base}"/>
    <g clip-path="url(#${nclip})"><path d="M186,156L234,156L234,190C226,184 218,183 210,191C202,183 194,184 186,190Z" fill="${SKIN.sh}"/></g>
    ${brush([[193, 172], [192, 188], [189, 202]], 0.4, 1.6, 0.6, SKIN.line)}${brush([[227, 172], [228, 188], [231, 202]], 0.4, 1.6, 0.6, SKIN.line)}
    <path d="M153,106C148,102 149,122 156,127C157,119 157,111 153,106Z" fill="${SKIN.base}"/><path d="M267,106C272,102 271,122 264,127C263,119 263,111 267,106Z" fill="${SKIN.base}"/>
    <path d="${face}" fill="${SKIN.base}"/>
    <g clip-path="url(#${fclip})">
      <ellipse cx="183" cy="139" rx="15" ry="7.5" fill="url(#${bl})"/><ellipse cx="237" cy="139" rx="15" ry="7.5" fill="url(#${bl})"/>
      <path d="M150,60C170,74 250,74 270,60L270,92C246,83 174,83 150,92Z" fill="${SKIN.sh}" opacity="0.9"/>
    </g>
    ${[[176, 141], [182, 141], [188, 141], [230, 141], [236, 141], [242, 141]].map(([x, y]) => brush([[x, y], [x + 2.4, y - 4]], 0.2, 1, 0.2, '#E47E76', ' opacity="0.65"')).join('')}
    ${brush([[156.6, 100], [158.6, 124], [165.6, 145.6], [178.6, 162.6], [194.6, 175], [210, 179.8]], 0.3, 1.9, 1.1, SKIN.line)}
    ${brush([[263.4, 100], [261.4, 124], [254.4, 145.6], [241.4, 162.6], [225.4, 175], [210, 179.8]], 0.3, 1.9, 1.1, SKIN.line)}
    ${eyeR(C, gid)}${mirrorX(eyeR(C, gid))}
    <path d="M206.6,128.6L210.6,141.4L205.4,141.8Z" fill="${SKIN.sh}" opacity="0.8"/>
    ${brush([[211, 135.4], [213.4, 141.2], [209.6, 143]], 0.3, 1.5, 0.4, SKIN.soft)}
    <path d="M201.2,156.2C205,159.6 215,159.6 218.8,155.8C216,162.6 204.4,163.2 201.2,156.2Z" fill="#C7525B"/>
    <path d="M204.6,160.4C207,162.4 213,162.4 215.4,160.2C213,162.8 207,163 204.6,160.4Z" fill="#F08A8E"/>
    ${brush([[200.2, 155.8], [205, 158.6], [210, 159.4], [215, 158.6], [219.8, 155.4]], 0.4, 1.8, 0.4, SKIN.line)}
    ${brush([[206.4, 166], [210, 166.8], [213.6, 166]], 0.2, 0.9, 0.2, SKIN.soft)}`;
}

export const LOOK_A = {
  iris1: '#21431D', iris2: '#4E9A3A', iris3: '#B9E58A', irisRim: '#16290F', irisGlow: '#D7F2A8', pupil: '#0F1C0A', lash: '#2C1714', brow: '#8A5A2E',
};

// ---------- 頭髮 ----------
// 有墨線的形狀：先畫往右下偏一點的深色（線條在陰影那一邊比較粗），再畫填色和細外框
function inked(d, fill, C, { dx = 0.9, dy = 1.3, w = 0.9, extra = '' } = {}) {
  return `<path d="${d}" fill="${C.hairLine}" transform="translate(${dx} ${dy})"/><path d="${d}" fill="${fill}" stroke="${C.hairLine}" stroke-width="${w}" stroke-linejoin="round"${extra}/>`;
}
// 一束頭髮：沿著 pts（根 → 尖），根部寬 w；裡面一條陰影（靠 side 那一邊）、一道亮光（根部附近）
function lock(pts, w, C, { side = 1, hi = true, shade = 0.5 } = {}) {
  const d = brushD(pts, w, w * 0.82, 0.3, 12), cid = nid('lk');
  const off = pts.map(([x, y], i) => { const t = i / (pts.length - 1); return [x + side * w * 0.28 * (1 - t * 0.6), y + w * 0.12]; });
  const sh = brushD(off, w * shade, w * shade * 0.8, 0.2, 12);
  const n = pts.length, hp = sample(pts, 12), m = hp.length;
  const hiPts = hp.slice(Math.round(m * 0.12), Math.round(m * 0.42)).filter((_, i) => i % 3 === 0).map(([x, y]) => [x - side * w * 0.16, y]);
  return `<defs><clipPath id="${cid}"><path d="${d}"/></clipPath></defs>${inked(d, C.hair, C)}
    <g clip-path="url(#${cid})"><path d="${sh}" fill="${C.hairSh}"/>${hi && hiPts.length > 1 ? brush(hiPts, 0.4, w * 0.2, 0.3, C.hairHi, ' opacity="0.95"') : ''}</g>
    <path d="${d}" fill="none" stroke="${C.hairLine}" stroke-width="0.8" stroke-linejoin="round"/>`;
}
// 造型 A 的頭髮：後面一大片（到背後）、頭頂、斜瀏海、兩邊的鬢髮
export function hairBackA(C) {
  const back = shape([[148, 70], [160, 36], [192, 16], [228, 15], [262, 30], [282, 62], [290, 112], [292, 170], [298, 236], [306, 300], [296, 336], [278, 314], [266, 262], [154, 262], [142, 314], [124, 336], [114, 300], [122, 236], [128, 170], [130, 112]]);
  const lines = [[[152, 120], [144, 200], [132, 290], [126, 330]], [[166, 150], [158, 220], [150, 290]], [[268, 120], [276, 200], [288, 290], [296, 330]], [[254, 150], [262, 220], [270, 290]], [[140, 90], [134, 160], [128, 240]], [[280, 90], [286, 160], [292, 240]]];
  return inked(back, C.hairSh, C, { dx: 1.2, dy: 1.6, w: 1 }) + lines.map((l) => brush(l, 0.3, 1.4, 0.3, C.hairSh2)).join('');
}
export function hairFrontA(C) {
  const crownPts = [[147, 100], [145, 64], [158, 38], [188, 22], [226, 18], [258, 26], [277, 48], [282, 80], [279, 100], [272, 80], [262, 64], [246, 54], [228, 50], [208, 52], [188, 58], [168, 70], [154, 86]];
  const crown = shape(crownPts), tid = nid('top');
  const outer = [[147, 100], [145, 64], [158, 38], [188, 22], [226, 18], [258, 26], [277, 48], [282, 80], [279, 100]];
  // 頭頂的亮帶（天使光環）：沿著頭的弧線，一段一段尖尖的亮光
  // 頭頂的亮帶（天使光環）：在頭的弧線上，一條一條順著髮流（從頭頂往下）的細長亮光，長短不一
  const ringShapes = [[160, 64, 8], [170, 55, 10], [181, 49, 11], [193, 45, 12], [205, 43, 10], [217, 42, 12], [229, 43, 11], [241, 45, 12], [252, 49, 10], [262, 55, 9], [270, 63, 7]]
    .map(([x, y, l], i) => { const dx = (x - 214) * 0.12; return brush([[x - dx * 0.6, y - l * 0.55], [x, y], [x + dx * 0.6, y + l * 0.5]], 0.3, i % 3 === 1 ? 3.6 : 2.6, 0.3, C.hairHi); }).join('');
  const locks = [
    lock([[222, 44], [204, 56], [184, 72], [166, 90], [156, 104]], 24, C, { side: 1 }),
    lock([[226, 46], [212, 60], [199, 78], [190, 97], [186, 107]], 21, C, { side: 1 }),
    lock([[231, 47], [224, 64], [216, 84], [208, 104]], 19, C, { side: 1 }),
    lock([[238, 48], [239, 66], [234, 86], [228, 102]], 17, C, { side: -1 }),
    lock([[244, 49], [253, 66], [257, 86], [254, 105]], 18, C, { side: -1 }),
    lock([[250, 52], [266, 66], [272, 86], [270, 106]], 16, C, { side: -1 }),
  ];
  const side = [
    lock([[160, 70], [152, 100], [150, 136], [154, 172], [160, 204], [158, 230]], 16, C, { side: 1 }),
    lock([[166, 76], [160, 110], [161, 146], [166, 178], [170, 206]], 11, C, { side: 1, hi: false }),
    lock([[260, 70], [268, 100], [270, 136], [266, 172], [260, 204], [262, 230]], 16, C, { side: -1 }),
    lock([[254, 76], [260, 110], [259, 146], [254, 178], [250, 206]], 11, C, { side: -1, hi: false }),
  ];
  return `${side.join('')}${locks.join('')}
    <defs><clipPath id="${tid}"><path d="${crown}"/></clipPath></defs><path d="${crown}" fill="${C.hair}"/>
    <g clip-path="url(#${tid})"><path d="M140,58C170,48 250,48 290,58L290,110L140,110Z" fill="${C.hairSh}" opacity="0.55"/>${ringShapes}</g>
    ${brush(outer, 1.2, 2.2, 1.2, C.hairLine)}`;
}
// 肩膀前面垂下來的頭髮（畫在衣服上面）
export function hairShoulderA(C) {
  return [
    lock([[156, 168], [147, 208], [141, 250], [141, 292], [147, 330], [153, 352]], 15, C, { side: 1 }),
    lock([[162, 178], [157, 216], [157, 256], [161, 292]], 10, C, { side: 1, hi: false }),
    lock([[264, 168], [273, 208], [279, 250], [279, 292], [273, 330], [267, 352]], 15, C, { side: -1 }),
    lock([[258, 178], [263, 216], [263, 256], [259, 292]], 10, C, { side: -1, hi: false }),
  ].join('');
}
export const HAIR_A = { hair: 'url(#hgA)', hairSh: '#D49A46', hairSh2: '#A8702E', hairHi: '#FFF4C8', hairLine: '#6E3F1C' };
// 頭髮的漸層（上面亮、髮尾暗一點）：每個 svg 放一次
export const defsA = () => `<defs><linearGradient id="hgA" gradientUnits="userSpaceOnUse" x1="0" y1="20" x2="0" y2="360"><stop offset="0" stop-color="#F8D886"/><stop offset="0.55" stop-color="#F0C064"/><stop offset="1" stop-color="#DDA350"/></linearGradient></defs>`;

// ---------- 身體（造型 A：白色泡泡袖露肩上衣、綠色綁帶背心；只到腰） ----------
export const BODY_A = { blouse: '#FFFFFF', blouseSh: '#E2D6E8', blouseSh2: '#C6B6CF', blouseLine: '#5E4660', bodice: '#3E7D58', bodiceSh: '#28553C', bodiceHi: '#69AD82', lace: '#FFF0C8' };
const mxp = (a) => a.map(([x, y]) => [420 - x, y]);
// 有深色偏移外框的形狀（線條在右下比較粗）
const inkShape = (d, fill, line, w = 0.9) => `<path d="${d}" fill="${line}" transform="translate(0.9 1.3)"/><path d="${d}" fill="${fill}" stroke="${line}" stroke-width="${w}" stroke-linejoin="round"/>`;
export function bodyA(B) {
  const S = SKIN, L = S.line;
  // 皮膚：肩膀、鎖骨、胸口（脖子短一點：斜方肌從 y≈200 開始）
  const chest = shape([[191, 196], [168, 206], [144, 220], [130, 238], [126, 262], [140, 300], [210, 318], [280, 300], [294, 262], [290, 238], [276, 220], [252, 206], [229, 196]]);
  // 胸部的兩個圓（上衣照這個輪廓）
  const bust = (cx) => shape([[cx - 44, 318], [cx - 40, 296], [cx - 24, 280], [cx, 274], [cx + 24, 280], [cx + 40, 296], [cx + 46, 320], [cx + 40, 346], [cx + 22, 362], [cx, 366], [cx - 24, 362], [cx - 40, 344]]);
  const neckline = [[126, 262], [150, 268], [170, 278], [188, 290], [210, 300], [232, 290], [250, 278], [270, 268], [294, 262]];
  // 上衣：肩膀下面、胸部的外緣往外鼓，下面收到胸下
  const blouse = shape([[126, 262], [150, 268], [170, 278], [188, 290], [210, 300], [232, 290], [250, 278], [270, 268], [294, 262], [302, 280], [308, 306], [308, 332], [300, 352], [284, 364], [262, 368], [240, 364], [222, 358], [210, 354], [198, 358], [180, 364], [158, 368], [136, 364], [120, 352], [112, 332], [112, 306], [118, 280]]);
  const bcl = nid('bl'), dcl = nid('bd'), ccl = nid('ch');
  // 背心：胸下到腰，腰細（152–268），上緣沿著胸下兩個弧
  const bodice = shape([[118, 352], [136, 364], [158, 370], [182, 366], [200, 358], [210, 356], [220, 358], [238, 366], [262, 370], [284, 364], [302, 352], [296, 384], [282, 414], [272, 446], [270, 478], [150, 478], [148, 446], [138, 414], [124, 384]]);
  // 手臂：靠著身體、手肘微彎（上臂往外、前臂往內），內側一條陰影
  const armPts = [[124, 296], [114, 330], [110, 368], [114, 404], [122, 440], [130, 476], [146, 476], [142, 440], [138, 404], [138, 368], [142, 332], [146, 300]];
  const armShPts = [[136, 300], [146, 300], [142, 332], [138, 368], [138, 404], [142, 440], [146, 476], [138, 476], [134, 440], [130, 404], [130, 368], [134, 332]];
  const arm = (m) => { const p = m ? mxp(armPts) : armPts, sh = m ? mxp(armShPts) : armShPts, id = nid('arm');
    const outer = m ? mxp([[124, 300], [114, 330], [110, 368], [114, 404], [122, 440], [130, 476]]) : [[124, 300], [114, 330], [110, 368], [114, 404], [122, 440], [130, 476]];
    const inner = m ? mxp([[146, 304], [142, 332], [138, 368], [138, 404], [142, 440], [146, 476]]) : [[146, 304], [142, 332], [138, 368], [138, 404], [142, 440], [146, 476]];
    return `<defs><clipPath id="${id}"><path d="${shape(p)}"/></clipPath></defs><path d="${shape(p)}" fill="${S.base}"/><g clip-path="url(#${id})"><path d="${shape(sh)}" fill="${S.sh}"/></g>
      ${brush(outer, 0.5, 2.1, 0.6, L)}${brush(inner, 0.4, 1.3, 0.4, L)}${brush(m ? mxp([[118, 404], [124, 408], [128, 404]]) : [[118, 404], [124, 408], [128, 404]], 0.2, 0.9, 0.2, S.soft)}`; };
  const sleeveP = [[120, 240], [104, 254], [97, 278], [101, 300], [120, 312], [146, 308], [151, 286], [147, 260], [134, 244]];
  const sleeve = (m) => { const mx = (a) => (m ? mxp(a) : a), p = mx(sleeveP), id = nid('slv');
    return `<defs><clipPath id="${id}"><path d="${shape(p)}"/></clipPath></defs>${inkShape(shape(p), B.blouse, B.blouseLine)}
      <g clip-path="url(#${id})"><path d="${shape(mx([[96, 284], [110, 298], [130, 304], [152, 296], [154, 320], [96, 320]]))}" fill="${B.blouseSh}"/><path d="${shape(mx([[112, 250], [124, 246], [118, 262], [110, 272]]))}" fill="#FFFFFF"/></g>
      ${[[110, 256, 106, 274], [122, 250, 118, 272], [134, 252, 134, 274], [104, 282, 108, 296], [140, 286, 138, 300]].map(([x1, y1, x2, y2]) => brush(mx([[x1, y1], [x2, y2]]), 0.2, 1, 0.2, B.blouseSh2)).join('')}
      ${inkShape(shape(mx([[100, 296], [120, 306], [146, 302], [147, 311], [120, 316], [99, 305]])), B.blouseSh, B.blouseLine)}`; };
  const ruffle = () => { const P = sample(neckline, 6), out = []; for (let i = 0; i < P.length - 1; i += 2) { const [x1, y1] = P[i], [x2, y2] = P[Math.min(P.length - 1, i + 2)]; const r = Math.hypot(x2 - x1, y2 - y1) / 2; out.push(`<path d="M${f(x1)},${f(y1)}A${f(r)},${f(r)} 0 0 0 ${f(x2)},${f(y2)}" fill="${B.blouse}" stroke="${B.blouseLine}" stroke-width="0.8"/>`); } return out.join(''); };
  const gathers = sample(neckline, 3).filter((_, i) => i % 2 === 1).map(([x, y]) => brush([[x, y + 4], [x + (x - 210) * 0.02, y + 12]], 0.2, 0.9, 0.2, B.blouseSh2)).join('');
  const lacing = [372, 388, 404, 420, 436, 452, 468];
  // 胸部的陰影：下半部一個月牙（兩階：淺、深），上面一道亮光
  const bustShade = (cx) => `<path d="${shape([[cx - 46, 322], [cx - 38, 346], [cx - 20, 362], [cx, 366], [cx + 22, 362], [cx + 40, 346], [cx + 48, 322], [cx + 36, 340], [cx + 16, 350], [cx - 6, 350], [cx - 26, 344]])}" fill="${B.blouseSh}"/>
    <path d="${shape([[cx - 30, 356], [cx - 10, 366], [cx + 12, 366], [cx + 30, 358], [cx + 12, 362], [cx - 10, 362]])}" fill="${B.blouseSh2}"/>
    ${brush([[cx - 26, 298], [cx - 12, 290], [cx + 4, 288]], 0.3, 2.6, 0.3, '#FFFFFF')}`;
  return `<defs><clipPath id="${bcl}"><path d="${blouse}"/></clipPath><clipPath id="${dcl}"><path d="${bodice}"/></clipPath><clipPath id="${ccl}"><path d="${chest}"/></clipPath></defs>
    <path d="${chest}" fill="${S.base}"/>
    <g clip-path="url(#${ccl})"><path d="${shape([[190, 196], [230, 196], [227, 205], [219, 213], [210, 217], [201, 213], [193, 205]])}" fill="${S.sh}"/>
      <path d="${shape([[196, 270], [204, 282], [210, 300], [216, 282], [224, 270], [218, 290], [210, 306], [202, 290]])}" fill="${S.sh}"/></g>
    ${brush([[198, 230], [180, 234], [160, 231], [146, 225]], 0.3, 1.4, 0.3, S.soft)}${brush([[222, 230], [240, 234], [260, 231], [274, 225]], 0.3, 1.4, 0.3, S.soft)}
    ${brush([[204, 215], [210, 223], [216, 215]], 0.2, 1, 0.2, S.soft)}
    ${brush([[189, 199], [168, 207], [146, 218], [130, 238]], 0.4, 1.8, 0.6, L)}${brush([[231, 199], [252, 207], [274, 218], [290, 238]], 0.4, 1.8, 0.6, L)}
    ${brush([[172, 262], [188, 274], [202, 290], [208, 300]], 0.2, 1.3, 0.2, S.soft)}${brush([[248, 262], [232, 274], [218, 290], [212, 300]], 0.2, 1.3, 0.2, S.soft)}
    ${inkShape(blouse, B.blouse, B.blouseLine)}
    <g clip-path="url(#${bcl})">${bustShade(168)}${bustShade(252)}</g>
    ${brush([[210, 301], [209.6, 318], [210, 340], [210, 354]], 0.2, 1.4, 0.3, B.blouseLine)}
    ${brush([[116, 318], [122, 340], [138, 358], [162, 368], [188, 364], [206, 354]], 0.3, 1.8, 0.4, B.blouseLine)}${brush([[304, 318], [298, 340], [282, 358], [258, 368], [232, 364], [214, 354]], 0.3, 1.8, 0.4, B.blouseLine)}
    ${gathers}${ruffle()}
    ${inkShape(bodice, B.bodice, '#1C3A29', 1)}
    <g clip-path="url(#${dcl})"><path d="${shape([[112, 350], [146, 372], [150, 420], [158, 480], [112, 480]])}" fill="${B.bodiceSh}"/><path d="${shape([[308, 350], [274, 372], [270, 420], [262, 480], [308, 480]])}" fill="${B.bodiceSh}"/>
      <path d="M200,356L220,356L220,480L200,480Z" fill="${B.blouse}"/><path d="M200,356L206,356L206,480L200,480Z" fill="${B.blouseSh}"/>
      ${brush([[126, 358], [146, 368], [170, 372], [196, 362]], 0.4, 1.6, 0.4, B.bodiceHi)}${brush([[294, 358], [274, 368], [250, 372], [224, 362]], 0.4, 1.6, 0.4, B.bodiceHi)}
      ${brush([[170, 384], [168, 420], [166, 466]], 0.3, 1.2, 0.3, B.bodiceHi)}${brush([[250, 384], [252, 420], [254, 466]], 0.3, 1.2, 0.3, B.bodiceHi)}</g>
    ${lacing.slice(0, -1).map((y, i) => `<path d="M199,${y}L221,${lacing[i + 1]}M221,${y}L199,${lacing[i + 1]}" stroke="${B.lace}" stroke-width="2.2" stroke-linecap="round"/><path d="M199,${y}L221,${lacing[i + 1]}M221,${y}L199,${lacing[i + 1]}" stroke="#8C6A3A" stroke-width="0.5" stroke-linecap="round" opacity="0.7"/>`).join('')}
    ${lacing.map((y) => `<circle cx="199" cy="${y}" r="2.1" fill="#E8D6A2" stroke="#1C3A29" stroke-width="0.7"/><circle cx="221" cy="${y}" r="2.1" fill="#E8D6A2" stroke="#1C3A29" stroke-width="0.7"/>`).join('')}
    ${arm(false)}${arm(true)}${sleeve(false)}${sleeve(true)}`;
}
