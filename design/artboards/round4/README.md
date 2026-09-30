# R4 設計稿：五種胖胖的牛（第 4 輪）

- **主題**：畫風改回 R1-A 圓潤Q版，只換牛。提出五種新的牛外型，都是胖胖、可愛的牛；總覽另放兩格被否決的對照（R1-A 的牛、R2-C 側面輪廓）。
- **日期**：2026-09-30
- **依據的使用者原話**（看過第 3 輪之後）：「原本的風格比較好，我知道問題在哪裡了，牛的外型怪怪的，你重新設計一下，一樣給我五種外型，然後或許可以參考胖胖的可愛的牛。你的牛的外型要改。」
  - 解讀與要做到的事：見 `design/spec.md` 第 3 輪章節。
- **狀態**：待使用者挑選，還沒有核准版。

| 檔名 | 內容 | 一句話（使用者會看到什麼） |
|---|---|---|
| `R4-01-牛的外型-A-胖胖側面-mobile.png` | 左：牧場主畫面；右：九頭排排站＋剪影 | 麵包形的胖身體、短腿；頭畫側面，口鼻短短往前；豆豆眼 |
| `R4-01-牛的外型-B-轉頭看你-mobile.png` | 同上 | 身體側面、頭轉過來看你；圓亮眼；寬寬的奶油色口鼻 |
| `R4-01-牛的外型-C-圓球糰子-mobile.png` | 同上 | 身體幾乎是一顆球、腿很短；小側臉貼在身上；笑瞇瞇的彎眼 |
| `R4-01-牛的外型-D-斜側四分之三-mobile.png` | 同上 | 桶形身體、腿稍長；頭斜 45 度，看得到兩隻眼睛 |
| `R4-01-牛的外型-E-軟方塊-mobile.png` | 同上 | 像棉花糖的圓角方塊，頭和身體連成一體；短方腿；杏仁眼加睫毛 |
| `R4-99-總覽對照.png` | 最左兩格是被否決的對照（R1-A 的牛、R2-C），接著 A–E；每格是排排站＋剪影，下面是檔名、描述、量測 | — |

這些是「使用者會看到的樣子」，不是可以直接搬進程式的程式碼：正式 app 用 Flutter／Flame 重做，規則以之後的規格為準。
選項圖外面套了示意手機框（四角 46px 圓角）；比對請用 `raw/` 裡沒有裁角的原始截圖。

## 五種外型怎麼拉開差異

| | 頭朝哪邊 | 身體輪廓 | 腿 | 眼睛 | 口鼻 |
|---|---|---|---|---|---|
| A 胖胖側面 | 側面 | 麵包形（超橢圓 n=2.7） | 短 | 豆豆眼＋一個反光 | 側面奶油色圓鼻頭 |
| B 轉頭看你 | 正面看玩家 | 麵包形 | 短 | 圓亮眼、兩個反光 | 寬扁的奶油色圓角長方形，鼻孔在上緣兩側 |
| C 圓球糰子 | 側面（頭小、貼在身上） | 幾乎是圓球（n=2.1） | 很短的小樁 | 笑瞇瞇彎眼 | 側面小鼻頭 |
| D 斜側四分之三 | 斜 45 度，兩隻眼都看得到 | 桶形（n=2.4） | 稍長 | 圓亮眼（遠側那隻小一點） | 往左下突出的奶油色口鼻，兩個鼻孔 |
| E 軟方塊 | 側面，頭身連成一體不畫分界線 | 圓角方塊（n=4.2） | 短而方 | 杏仁眼＋睫毛 | 側面奶油色鼻頭 |

五種都避開被否決的畫法：直立的橢圓眼、粉紅大圓鼻（像豬）、每一頭同一個身體（R1-A）；兩頭身大頭（R2-A）；細長的身體和腿（R2-C）。

## 牛：基因決定長相（照企劃書 4.5 的 24 種名單，main 61725c6）

流程：**基因（`src/data.js`）→ `plan()` 體型參數 → 外型比例 → 幾何 → Q 版畫筆（`src/shapes/q.js`，R1-A 的粗描邊、扁平粉彩）**，全部在 `src/shapes/chub.js`。
五種外型共用同一套基因規則，所以品種差異在每一種外型都看得到。

| 排排站 | 用途 | 顯現的特徵 | 性別／年齡 | 看得到的差異 |
|---|---|---|---|---|
| 荷斯坦 | 乳用 | — | 母牛 | 三種用途裡最高、腿最長、有乳房；白底黑斑、短角 |
| 荷斯坦公牛 | 乳用 | — | 公牛 | 大一號、肩峰、脖子粗、角較粗較長、沒有乳房 |
| 荷斯坦小牛 | 乳用 | — | 小牛 | 約成年荷斯坦 56–57% 高、身體短圓、腿有肉、只有角芽 |
| 娟珊 | 乳用 | B 淡色 | 母牛 | 骨架小一號、臉短、眼大、淡色眼圈；全身淺褐 |
| 西門塔爾 | 兼用 | — | 母牛 | 中等身材；紅褐底、白臉 |
| 高地牛 | 兼用 | A 長毛 | 母牛 | 長毛蓋住上半截腿，看起來更低更寬；瀏海、長角、蓬尾巴 |
| 安格斯 | 肉用 | — | 母牛 | 最寬、最深、腿最短；全黑、無角 |
| 和牛 | 肉用 | C 光澤 | 母牛 | 肌肉多一點、毛有光澤、肩頸淡色霜降細紋；無角 |
| 草莓牛 | 乳用 | A＋B＋C（傳說） | 母牛 | 奶油白底、草莓紅斑＋籽點、頭頂綠葉；帶一點長毛（瀏海、蓬尾巴）、柔和臉、光澤 |

- 角由規則推，不寫在基因裡：肉用一律無角（公牛也是）、兼用＋A 長角、其他短角、小牛只有角芽（肉用小牛沒有）。
- 牧場主畫面的七頭：安格斯、高地牛、荷斯坦、荷斯坦小牛、娟珊、草莓牛、西門塔爾（站位沿用 R1）。

## 資料夾內容

| 路徑 | 內容 |
|---|---|
| `src/data.js` | R4 基因（七個代表品種、排排站九頭、牧場站位）；牧場假資料 `FARM` 沿用 R1 |
| `src/shapes/chub.js` | 五種外型的產生器（體型參數、身體、腿、三種頭、眼睛、角、組裝） |
| `src/shapes/q.js` | Q 版畫筆（從 round2 複製，沒有改動） |
| `src/cows.js` | 外型登記與排排站外框計算 |
| `src/screen.html?v=a…e` | 牧場主畫面（`ui.js`、`style-a.js`、`style-a.css`、`common.css` 沿用 R1-A，只換牛） |
| `src/lineup.html?v=a…e` | 九頭排排站＋剪影面板（720×864） |
| `src/r1/` | R1 的共用工具與假資料（從 round2 複製，只讀） |
| `harness/capture.mjs`、`harness/compose.mjs` | 出圖與拼圖；`server.mjs`、`serve.mjs`、`shot.mjs` 同前幾輪 |
| `harness/preview.mjs`、`harness/preview-scene.mjs`、`harness/svg2png.py` | 不開瀏覽器的快速預覽：node 輸出 SVG，librsvg 轉 PNG（設計時用，幾乎不吃記憶體） |
| `raw/` | 未縮放原始截圖（PNG 不進 git）與量測 JSON；`r4-00-control-*` 是從 `round2/raw/` 複製來的對照（R1-A＝`r2-lineup-0`、R2-C＝`r2-lineup-c`，沒有重拍） |

### 指令（這台電腦曾經記憶體用光當機，一律照這個做法）

```bash
cd design/artboards/round4
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm ci
# 對照圖：從 round2 複製（raw 的 PNG 不進 git）
cp ../round2/raw/r2-lineup-0.png raw/r4-00-control-r1a.png; cp ../round2/raw/r2-lineup-0.json raw/r4-00-control-r1a.json
cp ../round2/raw/r2-lineup-c.png raw/r4-00-control-r2c.png; cp ../round2/raw/r2-lineup-c.json raw/r4-00-control-r2c.json
free -m    # available 少於 2000 MB 就先等
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 node harness/capture.mjs   # 一次只開一個瀏覽器
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 node harness/compose.mjs
# 不開瀏覽器的快速預覽
node harness/preview.mjs && python3 harness/svg2png.py raw/preview-a.svg raw/preview-a.png 1.5
```

遇到 exit 137（超過記憶體上限）就改成一個 job 一個 job 跑（`capture.mjs r4-lineup-b` 這樣帶名稱片段），不要調高上限。

## 前端版本

不適用：還沒有前端，這一輪是獨立的 HTML mockup。

## 瀏覽器與固定設定

- Chromium（`@playwright/test` 1.62.0，無頭模式用 `~/.cache/ms-playwright/chromium_headless_shell-1234`，沒有另外下載）；實際版本記在每個 `raw/*.json` 的 `browser` 欄。
- `locale: zh-TW`、`colorScheme: light`、`reducedMotion: reduce`、`isMobile: true`、`hasTouch: true`；`<html lang="zh-Hant-TW">`。
- 字型只用本機已有的 Noto Sans CJK TC。

## 裝置、安全區、示意疊加層

| 畫面 | viewport | DPR | 備註 |
|---|---|---|---|
| 牧場主畫面 | 390×844 | 3 | `--safe-top: 47px`、`--safe-bottom: 34px`；疊加層 `.sim-statusbar`、`.sim-home-indicator` |
| 九頭排排站＋剪影 | 720×864 | 3 | 九頭同一比例；剪影用 SVG 濾鏡把整頭牛塗成深色 |

進 git 的加標籤圖：單張 DPR 2（2460×1956）、總覽 DPR 1.5；raw 的原始截圖是 DPR 3。

## 網路狀態

不適用：獨立 mockup，沒有連線。

## 用 JS 改 DOM 做出來的狀態

不適用：畫面本身就是依假資料用 JS 產生的。

## 量測（`raw/*.json`）

出圖後填。

## 核准版對照表

待定：使用者還沒選。選定後填「核准內容 → 原始截圖檔名 → 現況對照檔名」。

## 進 git 的方式（ceo 2026-09-30）

- 加標籤的選項圖與總覽進 git；`raw/` 的原始截圖（PNG）不進 git（見 `.gitignore`），量測 JSON 有進 git。
- 要取得原尺寸，照上面的指令用 harness 重新產生（同一個 commit、同樣的假資料）。
