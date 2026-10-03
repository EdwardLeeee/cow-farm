// 第 13 輪 01 打掃小幫手（D35 補充，ceo 2026-10-03 的條件）：成年的牧場大姊姊，日系可愛動漫風、身材可以豐滿；
// 牧場工作服、撿大便的樣子；不畫暴露的衣服、刻意性感的姿勢或角度。三個造型共用同一個身體（約 5.4 頭身，看得出是大人），
// 換髮型、衣服、工具。座標：寬 300、高 560，腳底在 y≈546，臉的中線 x=150。
const L = '#4B3326';
const SKIN = '#FFE3D0', SKIN_SH = '#F5C7B0';
const ln = (w = 3) => `stroke="${L}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"`;
const mirror = (s) => `<g transform="translate(300 0) scale(-1 1)">${s}</g>`;

// ---------- 臉 ----------
function eye(iris, irisDark, id) {
  // 畫在右邊（x=167）；左眼用 mirror
  const ex = 167, ey = 86;
  const shape = `M${ex - 10} ${ey}C${ex - 8} ${ey - 8} ${ex + 6} ${ey - 10} ${ex + 10.5} ${ey - 4}C${ex + 11} ${ey + 4} ${ex + 6} ${ey + 11} ${ex} ${ey + 11}C${ex - 6} ${ey + 11} ${ex - 10} ${ey + 6} ${ex - 10} ${ey}Z`;
  return `<defs><clipPath id="${id}"><path d="${shape}"/></clipPath></defs>
    <path d="${shape}" fill="#FFFFFF"/>
    <g clip-path="url(#${id})"><ellipse cx="${ex + 0.6}" cy="${ey + 2}" rx="7.6" ry="9.8" fill="${iris}"/><ellipse cx="${ex + 0.6}" cy="${ey + 3.4}" rx="4" ry="5.6" fill="${irisDark}"/>
      <path d="M${ex - 7} ${ey + 6}Q${ex + 0.6} ${ey + 11.5} ${ex + 8} ${ey + 6}" stroke="#FFFFFF" stroke-width="1.6" fill="none" opacity="0.55"/></g>
    <circle cx="${ex - 2.4}" cy="${ey - 1.6}" r="2.7" fill="#FFFFFF"/><circle cx="${ex + 3.4}" cy="${ey + 6.2}" r="1.3" fill="#FFFFFF"/>
    <path d="M${ex - 11} ${ey + 0.6}C${ex - 8} ${ey - 9} ${ex + 6} ${ey - 11} ${ex + 11.4} ${ey - 4.2}" fill="none" stroke="#3A2620" stroke-width="3.4" stroke-linecap="round"/>
    <path d="M${ex + 10.8} ${ey - 4.6}l4 -3M${ex + 9.6} ${ey - 1.6}l4.2 -0.6" stroke="#3A2620" stroke-width="2.4" stroke-linecap="round"/>
    <path d="M${ex - 4.6} ${ey + 12.4}Q${ex + 0.4} ${ey + 13.6} ${ex + 5.4} ${ey + 11.6}" stroke="#C98F82" stroke-width="1.4" fill="none" stroke-linecap="round"/>`;
}
function face({ iris = '#8A6A3A', irisDark = '#4E3420', brow = '#5A3826', id = 'h' } = {}) {
  const facePath = 'M115 62C114 86 120 104 133 116C139 121 144 124 150 124C156 124 161 121 167 116C180 104 186 86 185 62C185 38 169 26 150 26C131 26 115 38 115 62Z';
  return `<ellipse cx="115" cy="88" rx="6" ry="9" fill="${SKIN}" ${ln(2.4)}/><ellipse cx="185" cy="88" rx="6" ry="9" fill="${SKIN}" ${ln(2.4)}/>
    <path d="M139.5 112V143Q150 150 160.5 143V112Z" fill="${SKIN}" ${ln(2.6)}/><path d="M140.5 121Q150 131 159.5 121V129Q150 138 140.5 129Z" fill="${SKIN_SH}"/>
    <path d="${facePath}" fill="${SKIN}" ${ln(3)}/>
    <ellipse cx="127" cy="103.5" rx="8.4" ry="3.8" fill="#FF9E98" opacity="0.6"/><ellipse cx="173" cy="103.5" rx="8.4" ry="3.8" fill="#FF9E98" opacity="0.6"/>
    ${eye(iris, irisDark, `${id}e1`)}${mirror(eye(iris, irisDark, `${id}e2`))}
    <path d="M159 70.5Q167 66.4 176.4 69.6" fill="none" stroke="${brow}" stroke-width="2.4" stroke-linecap="round"/>${mirror(`<path d="M159 70.5Q167 66.4 176.4 69.6" fill="none" stroke="${brow}" stroke-width="2.4" stroke-linecap="round"/>`)}
    <path d="M151.4 100.6q1.6 1.8 -0.8 2.8" fill="none" stroke="#D49A88" stroke-width="1.6" stroke-linecap="round"/>
    <path d="M144 110.4Q150 117 156 110.4Q150 112.4 144 110.4Z" fill="#E77B70" stroke="#8E4A3E" stroke-width="1.8" stroke-linejoin="round"/>`;
}

// ---------- 身體（衣服下面的手臂、手） ----------
// 手套（黃色工作手套）：(x, y) 是手的中心
const glove = (x, y, c = '#FFD45E') => `<path d="M${x - 9} ${y - 9}h15q5 0 5 5v11q0 9 -9 9h-5q-8 0 -8 -8z" fill="${c}" ${ln(2.6)}/><path d="M${x - 3.6} ${y + 1}v6M${x + 1} ${y + 1}v6" stroke="${L}" stroke-width="1.5" stroke-linecap="round"/>`;
// 手臂（畫在左邊，右邊用 mirror）：sleeveEnd 是袖口的高度；longSleeve 整條是袖子
function arms({ sleeve, sleeveDark, sleeveEnd = 200, longSleeve = false, cuff = null }) {
  const arm = `<path d="M82 190C78 208 76 226 76 242C77 260 81 278 85 296L99 296C96 280 93 262 92 246C94 230 99 214 104 196Z" fill="${longSleeve ? sleeve : SKIN}" ${ln(2.8)}/>`;
  const sl = longSleeve ? `<path d="M82.4 282L96.6 282L99 296L85 296Z" fill="${cuff || sleeveDark}" ${ln(2.2)}/>`
    : `<path d="M110 147C95 149 86 161 84 179L81 ${sleeveEnd}L106 ${sleeveEnd + 3}L110 168Z" fill="${sleeve}" ${ln(2.8)}/><path d="M81.6 ${sleeveEnd - 8}L106.6 ${sleeveEnd - 5}L106 ${sleeveEnd + 3}L81 ${sleeveEnd}Z" fill="${sleeveDark}" ${ln(2.2)}/>`;
  const sh = longSleeve ? `<path d="M110 147C95 149 86 161 84 179L82 196L106 198L110 168Z" fill="${sleeve}" ${ln(2.8)}/>` : '';
  const one = arm + sh + sl;
  return one + mirror(one);
}
// 上半身的衣服（領口到腰，身體曲線：胸比較豐滿、腰細、臀部寬）
const TORSO = 'M140 140C127 142 116 144 108 150C100 156 95 168 94 182C93 196 97 207 105 216C111 223 115 231 117 240L183 240C185 231 189 223 195 216C203 207 207 196 206 182C205 168 200 156 192 150C184 144 173 142 160 140Z';

// ---------- 造型 ----------
// A：吊帶褲＋短袖襯衫捲袖＋紅色點點頭巾、棕色馬尾、綠色雨鞋、黃色手套；長柄畚箕＋藍色水桶
function lookA() {
  const HAIR = '#8A5A3C', HAIR_D = '#6A4330', HAIR_H = '#B9845A';
  const DEN = '#86ADDA', DEN_D = '#6189BC', DEN_L = '#B4CFEE';
  const back = `<path d="M178 36C206 30 226 50 226 80C226 106 216 124 221 146C225 160 233 168 240 172C221 178 202 166 197 145C193 127 199 106 195 88C192 72 186 60 174 54Z" fill="${HAIR}" ${ln(3)}/>
    <path d="M208 62C214 80 212 102 207 120" fill="none" stroke="${HAIR_H}" stroke-width="3" stroke-linecap="round"/>
    <path d="M113 66C109 40 126 20 150 20C174 20 191 40 187 66C188 80 186 92 180 100L120 100C114 92 112 80 113 66Z" fill="${HAIR}" ${ln(3)}/>`;
  const boots = [96, 160].map((x) => `<path d="M${x + 2} 458h42v62c4 2 8 6 8 12c0 9 -7 14 -16 14h-36c-8 0 -13 -5 -13 -12c0 -8 6 -12 13 -14z" fill="#7CC76A" ${ln(3)}/><path d="M${x - 2} 534h52" stroke="${L}" stroke-width="2.2"/><path d="M${x + 9} 486v22" stroke="#B5E5A5" stroke-width="3.4" stroke-linecap="round"/>`).join('');
  const shirt = `<path d="${TORSO}" fill="#FFF1C4" ${ln(3)}/><path d="M140 140L150 154L160 140" fill="#FFF8E0" ${ln(2.4)}/>
    <path d="M103 196C108 204 114 208 120 209M197 196C192 204 186 208 180 209" fill="none" stroke="#E9CF8A" stroke-width="2.2" stroke-linecap="round"/>`;
  const overalls = `<path d="M127 177L173 177C181 184 186 195 186 207C186 220 181 230 181 240C193 254 205 272 207 294L207 470L160 470L155 334Q150 326 145 334L140 470L93 470L93 294C95 272 107 254 119 240C119 230 114 220 114 207C114 195 119 184 127 177Z" fill="${DEN}" ${ln(3)}/>
    <path d="M118 204C124 213 136 216 146 213M154 213C164 216 176 213 182 204" fill="none" stroke="${DEN_D}" stroke-width="2.2" stroke-linecap="round" opacity="0.6"/>
    <path d="M150 252V322" stroke="${DEN_D}" stroke-width="2" stroke-dasharray="4 4"/>
    <path d="M119 241Q150 250 181 241" fill="none" stroke="${DEN_D}" stroke-width="2.4"/>
    <path d="M138 190h24v15q0 7 -7 7h-10q-7 0 -7 -7z" fill="${DEN_L}" ${ln(2.4)}/><path d="M140 195h20" stroke="${DEN_D}" stroke-width="1.6" stroke-dasharray="3 3"/>
    <path d="M93 456h47.6v14h-47.6zM159.4 456h47.6v14h-47.6z" fill="${DEN_L}" ${ln(2.6)}/>
    <path d="M161 384h24v22h-24z" fill="#FFC98A" ${ln(2.2)}/><path d="M164 387h18v16h-18z" fill="none" stroke="${L}" stroke-width="1.2" stroke-dasharray="2.4 2.4"/>
    <path d="M103 330C105 366 105 410 103 450M197 330C195 366 195 410 197 450" fill="none" stroke="${DEN_D}" stroke-width="2"/>`;
  // 瀏海：幾撮圓圓的頭髮往左邊撥；兩邊各一撮細長的鬢髮
  const straps = `<path d="M124 180C121 168 119 156 118 144L109 147C111 160 114 170 117 181Z" fill="${DEN}" ${ln(2.6)}/><path d="M176 180C179 168 181 156 182 144L191 147C189 160 186 170 183 181Z" fill="${DEN}" ${ln(2.6)}/>
    <circle cx="124" cy="183" r="4.6" fill="#FFD45E" ${ln(2)}/><circle cx="176" cy="183" r="4.6" fill="#FFD45E" ${ln(2)}/>`;
  const front = `<path d="M114 72C110 44 127 25 150 25C173 25 190 44 186 72C184 66 180 61 175 58C176 64 177 69 176 74C171 64 164 58 156 55C158 62 157 68 153 73C150 64 144 57 136 55C137 61 135 67 130 71C127 64 124 61 120 60C118 64 116 68 114 72Z" fill="${HAIR}" ${ln(3)}/>
    <path d="M117 66C112 84 112 104 120 120C121 112 122 104 121 96C123 86 124 78 126 70Z" fill="${HAIR}" ${ln(2.6)}/><path d="M183 66C188 84 188 104 180 120C179 112 178 104 179 96C177 86 176 78 174 70Z" fill="${HAIR}" ${ln(2.6)}/>
    <path d="M131 42Q141 35 152 34" stroke="${HAIR_H}" stroke-width="3.2" fill="none" stroke-linecap="round"/>`;
  const bandana = `<path d="M111 57C113 31 130 15 150 15C170 15 187 31 189 57C178 47 165 42 150 42C135 42 122 47 111 57Z" fill="#FF8C7C" ${ln(3)}/>
    ${[[128, 31], [146, 23], [164, 27], [177, 41], [138, 37], [158, 35], [121, 45]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="2.6" fill="#FFFFFF"/>`).join('')}
    <path d="M189 34C197 26 206 24 210 28C207 34 200 38 192 38Z" fill="#FF8C7C" ${ln(2.6)}/><path d="M190 40C199 40 207 44 207 50C200 51 193 48 189 44Z" fill="#FF8C7C" ${ln(2.6)}/><circle cx="188" cy="38" r="5.4" fill="#F06E5E" ${ln(2.4)}/>`;
  const scoop = `<path d="M100 232L62 524" stroke="${L}" stroke-width="8" stroke-linecap="round"/><path d="M100 232L62 524" stroke="#E2A15E" stroke-width="4" stroke-linecap="round"/>
    <path d="M38 516L86 522L82 548L34 542Z" fill="#FFB07C" ${ln(3)}/><path d="M42 522L82 527" stroke="#FFFFFF" stroke-width="2.4" opacity="0.7"/>`;
  const bucket = `<path d="M196 330h50l-5 44q-1 7 -8 7h-24q-7 0 -8 -7z" fill="#A9DBFF" ${ln(3)}/><ellipse cx="221" cy="330" rx="25" ry="6" fill="#D7EEFF" ${ln(2.6)}/><path d="M204 340v28" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round"/>
    <path d="M198 330C198 312 204 300 208 300C215 300 244 312 244 330" fill="none" stroke="${L}" stroke-width="2.6"/>`;
  return `${back}${scoop}${boots}${shirt}${overalls}${arms({ sleeve: '#FFF1C4', sleeveDark: '#F5DC96' })}${straps}${glove(92, 302)}${bucket}${mirror(glove(92, 302))}
    ${face({ iris: '#7C9A4E', irisDark: '#3F5626', brow: HAIR_D, id: 'ha' })}${front}${bandana}`;
}

// 臉旁邊的鬢髮、瀏海（中分、幾撮圓的）：B、C 用
const bangsMid = (HAIR, HAIR_H) => `<path d="M114 72C110 44 127 25 150 25C173 25 190 44 186 72C183 66 179 62 174 60C175 66 174 71 171 75C168 66 162 59 154 56C154 62 151 66 147 69C145 62 140 57 133 56C132 62 129 66 125 68C122 64 118 66 114 72Z" fill="${HAIR}" ${ln(3)}/>
  <path d="M138 38Q146 33 156 33" stroke="${HAIR_H}" stroke-width="3.2" fill="none" stroke-linecap="round"/>`;
const sideLocks = (HAIR, len = 120) => `<path d="M117 66C112 84 112 104 120 ${len}C121 112 122 104 121 96C123 86 124 78 126 70Z" fill="${HAIR}" ${ln(2.6)}/><path d="M183 66C188 84 188 104 180 ${len}C179 112 178 104 179 96C177 86 176 78 174 70Z" fill="${HAIR}" ${ln(2.6)}/>`;
const bootPair = (fill, hi, lace = false) => [96, 160].map((x) => `<path d="M${x + 2} 458h42v62c4 2 8 6 8 12c0 9 -7 14 -16 14h-36c-8 0 -13 -5 -13 -12c0 -8 6 -12 13 -14z" fill="${fill}" ${ln(3)}/><path d="M${x - 2} 534h52" stroke="${L}" stroke-width="2.2"/>${lace ? `<path d="M${x + 16} 476l12 6m-12 6l12 6m-12 6l12 6" stroke="${hi}" stroke-width="2.4" stroke-linecap="round"/>` : `<path d="M${x + 9} 486v22" stroke="${hi}" stroke-width="3.4" stroke-linecap="round"/>`}`).join('');

// B：連身裙＋白色圍裙＋草帽、深棕色側邊辮子、短靴；竹掃把＋長柄畚斗
function lookB() {
  const HAIR = '#5E3A2A', HAIR_D = '#43281D', HAIR_H = '#8A5A40';
  const DRESS = '#9ED9B4', DRESS_D = '#6DBB8E', APRON = '#FFFDF4', APRON_D = '#E8DCC4';
  const back = `<path d="M113 66C109 40 126 20 150 20C174 20 191 40 187 66C189 84 188 98 184 108L116 108C112 98 111 84 113 66Z" fill="${HAIR}" ${ln(3)}/>`;
  const legs = [108, 158].map((x) => `<path d="M${x} 410h34l-2 60h-30z" fill="#8A7466" ${ln(2.8)}/>`).join('');
  const skirt = `<path d="M117 236L183 236C197 288 214 356 226 426C200 438 176 442 150 442C124 442 100 438 74 426C86 356 103 288 117 236Z" fill="${DRESS}" ${ln(3)}/>
    <path d="M92 402C100 380 104 340 110 300M208 402C200 380 196 340 190 300" fill="none" stroke="${DRESS_D}" stroke-width="2.2" stroke-linecap="round"/>`;
  const top = `<path d="${TORSO}" fill="${DRESS}" ${ln(3)}/><path d="M136 141C140 152 160 152 164 141L172 146C166 160 134 160 128 146Z" fill="#FFFFFF" ${ln(2.4)}/>`;
  const apron = `<path d="M129 182L171 182C178 196 181 214 180 236C188 290 196 350 200 408C184 418 168 422 150 422C132 422 116 418 100 408C104 350 112 290 120 236C119 214 122 196 129 182Z" fill="${APRON}" ${ln(3)}/>
    <path d="M129 182C127 166 131 152 139 143M171 182C173 166 169 152 161 143" fill="none" stroke="${L}" stroke-width="7" stroke-linecap="round"/><path d="M129 182C127 166 131 152 139 143M171 182C173 166 169 152 161 143" fill="none" stroke="${APRON}" stroke-width="3.6" stroke-linecap="round"/>
    <path d="M120 236Q150 244 180 236" fill="none" stroke="${APRON_D}" stroke-width="5"/><path d="M181 238l12 -6l2 12zM181 240l10 10l-12 2z" fill="${APRON}" ${ln(2.2)}/>
    <path d="M122 206C130 215 142 217 148 214M152 214C158 217 170 215 178 206" fill="none" stroke="${APRON_D}" stroke-width="2.2" stroke-linecap="round"/>
    <path d="M126 318h48v34q0 8 -8 8h-32q-8 0 -8 -8z" fill="${APRON}" ${ln(2.4)}/><path d="M126 326h48" stroke="${APRON_D}" stroke-width="2"/>
    <path d="M102 408C108 414 114 412 118 416C124 420 130 418 136 421C142 423 146 421 150 422C156 422 160 423 166 421C172 418 178 420 184 416C188 412 194 414 200 408" fill="none" stroke="${APRON_D}" stroke-width="2.2"/>`;
  // 辮子：從右耳後面繞到胸前（一節一節）
  const braid = [[186, 120], [190, 140], [193, 160], [195, 180], [196, 200], [197, 220], [198, 238]].map(([x, y], i) => `<ellipse cx="${x}" cy="${y}" rx="${10 - i * 0.4}" ry="12" transform="rotate(${i % 2 ? 18 : -18} ${x} ${y})" fill="${HAIR}" ${ln(2.6)}/>`).join('')
    + `<path d="M190 252l16 -4l-2 10l-14 -2z" fill="#FF8FB1" ${ln(2.2)}/><path d="M194 258C190 266 192 274 198 280C204 274 206 266 202 258Z" fill="${HAIR}" ${ln(2.4)}/>`;
  const hat = `<ellipse cx="150" cy="48" rx="62" ry="15" fill="#F6D58A" ${ln(3)}/><path d="M118 46C118 22 132 10 150 10C168 10 182 22 182 46C170 50 130 50 118 46Z" fill="#F6D58A" ${ln(3)}/>
    <path d="M118 38C130 43 170 43 182 38L182 46C170 51 130 51 118 46Z" fill="#7CC4F0" ${ln(2.4)}/><path d="M126 22l6 6m4 -12l4 8m10 -10l0 9m12 -7l-4 8m12 -2l-6 6" stroke="#D9AE5A" stroke-width="1.8" stroke-linecap="round"/>
    <path d="M100 52Q150 66 200 52" fill="none" stroke="#D9AE5A" stroke-width="2"/>`;
  const broom = `<path d="M98 214L70 470" stroke="${L}" stroke-width="7" stroke-linecap="round"/><path d="M98 214L70 470" stroke="#C98E5E" stroke-width="3.4" stroke-linecap="round"/>
    <path d="M62 466l18 2l14 64l-46 -5z" fill="#F2D27A" ${ln(2.8)}/><path d="M66 486l-4 38M74 488l2 40M82 488l6 38" stroke="#C9A24E" stroke-width="2"/><path d="M62 470l20 2" stroke="#C0392B" stroke-width="4"/>`;
  const pan = `<path d="M206 300L214 498" stroke="${L}" stroke-width="7" stroke-linecap="round"/><path d="M206 300L214 498" stroke="#C98E5E" stroke-width="3.4" stroke-linecap="round"/>
    <path d="M190 494h46v36q0 6 -6 6h-34q-6 0 -6 -6z" fill="#8CD46F" ${ln(2.8)}/><path d="M190 502h46" stroke="${L}" stroke-width="2.2"/>`;
  return `${back}${broom}${legs}${bootPair('#B07A4E', '#F2D3A8', true)}${skirt}${top}${apron}${arms({ sleeve: DRESS, sleeveDark: DRESS_D, longSleeve: true, cuff: '#FFFFFF' })}${pan}${glove(92, 302, SKIN)}${mirror(glove(92, 302, SKIN))}
    ${face({ iris: '#9A6A40', irisDark: '#5A3820', brow: HAIR_D, id: 'hb' })}${sideLocks(HAIR)}${bangsMid(HAIR, HAIR_H)}${braid}${hat}`;
}

// C：連身工作服（捲袖、拉鍊、腰帶）＋帽子、黑色短髮、脖子上小領巾、黃色雨鞋；一手叉腰、一手扶著鏟子
function lookC() {
  const HAIR = '#3B3550', HAIR_D = '#25202F', HAIR_H = '#6A6488';
  const SUIT = '#FFAE80', SUIT_D = '#E68A5A', SUIT_L = '#FFD2B5';
  const back = `<path d="M112 70C108 42 126 22 150 22C174 22 192 42 188 70C190 88 188 104 182 116C176 112 170 104 168 96L132 96C130 104 124 112 118 116C112 104 110 88 112 70Z" fill="${HAIR}" ${ln(3)}/>`;
  const suit = `<path d="M140 140C127 142 116 144 108 150C100 156 95 168 94 182C93 196 97 207 105 216C111 223 115 231 117 240C105 256 95 274 93 296L93 470L141 470L145 334Q150 326 155 334L159 470L207 470L207 296C205 274 195 256 183 240C185 231 189 223 195 216C203 207 207 196 206 182C205 168 200 156 192 150C184 144 173 142 160 140Z" fill="${SUIT}" ${ln(3)}/>
    <path d="M150 156V330" stroke="${SUIT_D}" stroke-width="2.4"/><path d="M146 160h8" stroke="${L}" stroke-width="2.4"/>
    <path d="M118 236Q150 246 182 236L183 248Q150 258 117 248Z" fill="#A8703F" ${ln(2.4)}/><rect x="142" y="238" width="16" height="13" rx="2" fill="#FFD45E" ${ln(2.2)}/>
    <path d="M120 207C128 214 138 216 145 214M155 214C162 216 172 214 180 207" fill="none" stroke="${SUIT_D}" stroke-width="2" stroke-linecap="round" opacity="0.45"/>
    <path d="M110 300h24v26h-24zM166 300h24v26h-24z" fill="${SUIT_L}" ${ln(2.2)}/>
    <path d="M104 336C106 370 106 410 104 450M196 336C194 370 194 410 196 450" fill="none" stroke="${SUIT_D}" stroke-width="2"/>`;
  const collar = `<path d="M136 140L150 160L164 140L172 146L156 170L150 162L144 170L128 146Z" fill="${SUIT_L}" ${ln(2.4)}/><path d="M138 150Q150 160 162 150L158 168Q150 178 142 168Z" fill="#7CC4F0" ${ln(2.2)}/>`;
  // 右手（畫面左邊）扶著鏟子；左手（畫面右邊）叉腰
  const armL = `<path d="M110 147C95 149 86 161 84 179L80 218L104 222L110 168Z" fill="${SUIT}" ${ln(2.8)}/><path d="M80.6 208L104.4 212L104 224L80 220Z" fill="${SUIT_L}" ${ln(2.2)}/>
    <path d="M81 220C78 236 78 252 80 266C81 276 83 284 85 292L99 292C98 282 97 274 97 264C97 250 100 236 103 224Z" fill="${SKIN}" ${ln(2.8)}/>`;
  const armR = `<path d="M190 147C205 149 214 161 217 178L230 210L210 222L198 192Z" fill="${SUIT}" ${ln(2.8)}/><path d="M228 204L232 214L212 226L208 216Z" fill="${SUIT_L}" ${ln(2.2)}/>
    <path d="M231 214C228 230 216 242 202 250L194 238C204 232 210 226 212 222Z" fill="${SKIN}" ${ln(2.8)}/>`;
  const fistR = `<path d="M186 236q6 -6 13 -2l5 6q2 7 -4 11l-6 3q-7 2 -10 -4z" fill="#C98E5E" ${ln(2.6)}/>`;
  const shovel = `<path d="M92 270L80 494" stroke="${L}" stroke-width="8" stroke-linecap="round"/><path d="M92 270L80 494" stroke="#C98E5E" stroke-width="4" stroke-linecap="round"/>
    <path d="M84 262h16v8h-16z" fill="#C98E5E" ${ln(2.2)}/><path d="M64 490h32l-2 34q-1 12 -14 14q-13 -2 -15 -14z" fill="#C9D3DC" ${ln(2.8)}/><path d="M70 498v22" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round"/>`;
  const front = `<path d="M112 74C108 46 126 26 150 26C174 26 192 46 188 74C182 66 176 62 170 60C170 66 168 70 164 73C162 64 156 58 148 56C147 62 143 67 138 69C136 62 132 58 126 57C124 63 118 68 112 74Z" fill="${HAIR}" ${ln(3)}/>
    <path d="M116 68C111 86 112 104 118 116C119 106 120 96 120 88C122 80 123 74 125 70Z" fill="${HAIR}" ${ln(2.6)}/><path d="M184 68C189 86 188 104 182 116C181 106 180 96 180 88C178 80 177 74 175 70Z" fill="${HAIR}" ${ln(2.6)}/>`;
  const cap = `<path d="M114 50C114 26 130 12 150 12C170 12 186 26 186 50C170 46 130 46 114 50Z" fill="#8CD46F" ${ln(3)}/><path d="M112 50C128 44 172 44 188 50C186 58 168 56 150 56C132 56 114 58 112 50Z" fill="#6DB35E" ${ln(2.8)}/>
    <path d="M150 12V44" stroke="#6DB35E" stroke-width="2"/><circle cx="150" cy="13" r="3.4" fill="#6DB35E" ${ln(2)}/><path d="M136 30q4 -6 10 -4q-2 6 -10 4z" fill="#FFFFFF" ${ln(1.6)}/>`;
  return `${back}${shovel}${bootPair('#FFD45E', '#FFF0B0')}${suit}${collar}${armL}${armR}${fistR}${glove(92, 290, '#C98E5E')}
    ${face({ iris: '#5A6FA8', irisDark: '#2C3660', brow: HAIR_D, id: 'hc' })}${front}${cap}`;
}

export const HELPERS = {
  A: { draw: lookA, name: '美穗姐', outfit: '吊帶褲、捲袖襯衫、點點頭巾、馬尾、雨鞋' },
  B: { draw: lookB, name: '千夏姐', outfit: '連身裙、白色圍裙、草帽、側邊辮子、短靴' },
  C: { draw: lookC, name: '阿葵姐', outfit: '連身工作服、帽子、短髮、小領巾、雨鞋' },
};
let n = 0;
export function helperSVG(look, { w = 300, h = 560, cls = '' } = {}) {
  return `<svg class="${cls}" viewBox="0 0 300 560" width="${w}" height="${h}" aria-hidden="true">${helperInner(look)}</svg>`;
}
// 不包 <svg>（畫進場景用）
// lineK：線條加粗的倍數（縮小放進場景時，線條要跟牛差不多粗）
export function helperInner(look, { lineK = 1 } = {}) {
  n += 1;
  let svg = HELPERS[look].draw().replace(/id="(h[abc])e([12])"/g, `id="$1e$2_${n}"`).replace(/url\(#(h[abc])e([12])\)/g, `url(#$1e$2_${n})`);
  if (lineK !== 1) svg = svg.replace(/stroke-width="([\d.]+)"/g, (m, w) => `stroke-width="${Math.round(w * lineK * 100) / 100}"`);
  return svg;
}
// 頭像（只有頭）：viewBox 圈住頭和頭髮
export function helperFace(look, size = 40) {
  return `<svg viewBox="96 6 108 108" width="${size}" height="${size}" aria-hidden="true">${helperInner(look)}</svg>`;
}
