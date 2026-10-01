// 所有狀態的登記表：每個狀態一個穩定的頁面 ID（Sxx-yy、G-yy）。
// type：full 整頁（430、390 各一張）；part 局部（只截 crop 那一塊，並排在狀態表上）。tall：長頁（整頁捲動內容，標出第一個畫面的範圍）。
import G from './screens/g.js';
import S01 from './screens/s01.js';
import S02 from './screens/s02.js';
import S03 from './screens/s03.js';
import S04 from './screens/s04.js';
import S05 from './screens/s05.js';
import S06 from './screens/s06.js';
import { S07, S20M } from './screens/s07.js';
import { S08, S18 } from './screens/s08.js';
import { S09, S12 } from './screens/s09.js';
import { S10M, S11M, S19M } from './screens/s10.js';
import { S13M, S14M, S15M, S16M } from './screens/s13.js';
import S17 from './screens/s17.js';

export const SCREENS = [G, S01, S02, S03, S04, S05, S06, S07, S08, S09, S10M, S11M, S12, S13M, S14M, S15M, S16M, S17, S18, S19M, S20M];
export const STATES = SCREENS.flatMap((m) => m.states.map((s) => ({ ...s, screen: m.id, screenName: m.name })));
