# R1 設計稿：美術風格（第 1 輪）

- **主題**：整款遊戲的畫風三選一（這一輪只挑畫風）。三種風格畫同一個畫面「牧場主畫面」、用同一組假資料。
- **日期**：2026-09-30
- **狀態**：使用者 2026-09-30 裁示：「選a 但我不喜歡牛的樣子 要給我另外的設計」。A 圓潤Q版是整體畫風；牛的造型不採用，第 2 輪（`design/artboards/round2/`）重新提案。

| 檔名 | 項目與選項 | 一句話 |
|---|---|---|
| `R1-01-美術風格-A-圓潤Q版-mobile.png` | 01 美術風格 — A 圓潤Q版 | 粗圓描邊、扁平粉彩、胖嘟嘟比例 |
| `R1-01-美術風格-B-像素風-mobile.png` | 01 美術風格 — B 像素風 | 點陣像素（1 美術像素 = 3 CSS px）、自畫像素數字 |
| `R1-01-美術風格-C-軟萌立體-mobile.png` | 01 美術風格 — C 軟萌立體 | 柔和漸層、軟陰影、像黏土玩具（遠景微失焦） |
| `R1-99-總覽對照.png` | 總覽 | 三張並排，格子下印檔名、白話描述、量測（綠＝通過、紅＝有問題、灰＝說明） |

這些是「使用者會看到的樣子」，不是可以直接搬進程式的 CSS：正式 app 用 Flutter／Flame 重做，規則以之後的規格為準。

- 選項圖與總覽外面套了示意手機框，螢幕四角用 46px 圓角裁掉；`raw/` 的原始截圖沒有裁角，之後比對請用 `raw/`。
- 這一輪的 PNG 合計約 8 MB（原始截圖＋選項圖＋總覽＋圖庫）。要不要進 git 由 ceo 決定；README、`src/`、`harness/` 要和圖放在一起交接。

## 資料夾內容

| 路徑 | 內容 |
|---|---|
| `src/data.js` | 共用假資料（牧場名、遊戲幣、奶桶、倉庫、行情、新聞、分頁）與牛的基因、牧場裡的站位 |
| `src/cowgen.js` | 牛的參數化產生器：基因 → 幾何與配色模型（不管畫風） |
| `src/cowgen-a.js`、`cowgen-b.js`、`cowgen-c.js` | 三種畫風的 renderer，讀同一個模型：A 輸出 SVG、B 點陣化成 canvas、C 輸出帶漸層的 SVG |
| `src/ui.js`、`src/common.css` | 三種風格共用的畫面骨架（同一個 DOM 結構）、安全區與示意疊加層 |
| `src/style-a/b/c.js`、`.css` | 各風格的場景、圖示、數字、小走勢線與外觀 |
| `src/screen-a.html`、`screen-b.html`、`screen-c.html` | 三個畫面 |
| `src/gallery.html?style=a｜b｜c` | 產生器圖庫：六個品種＋小牛，再加 24 組隨機基因 |
| `harness/capture.mjs` | 出圖：拍三個畫面與三張圖庫到 `raw/`，每個 job 另存量測 JSON |
| `harness/compose.mjs` | 拼圖：`raw/` → 加標籤的選項圖（DPR 3）與總覽（DPR 2） |
| `harness/server.mjs` | 行程內的靜態伺服器（ES module 不能從 file:// 載入）；腳本結束就關，不留背景程式 |
| `harness/serve.mjs`、`harness/shot.mjs` | 手動預覽、開發時拍單張 |
| `raw/r1-01-{a,b,c}-mobile.png／.json` | 未縮放原始截圖（1170×2532）與量測值 |
| `raw/gallery-{a,b,c}.png` | 產生器圖庫截圖（量產證明，不是選項） |
| `package.json`、`package-lock.json` | 出圖工具（`@playwright/test` 1.62.0 固定版本）；`node_modules/` 由 repo 的 `.gitignore` 排除 |

### 指令

```bash
cd design/artboards/round1
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm ci   # 不下載瀏覽器，沿用 ~/.cache/ms-playwright
node harness/capture.mjs                    # → raw/*.png、raw/*.json（可加 job 名片段，例如 r1-01-b）
node harness/compose.mjs                    # → R1-01-*.png、R1-99-總覽對照.png
node harness/serve.mjs 8123                 # 手動預覽：http://127.0.0.1:8123/src/screen-a.html（Ctrl+C 結束）
```

## 前端版本

不適用：還沒有前端，這一輪是獨立的 HTML mockup（skill 步驟 3「第一版方向先用獨立 HTML 出稿」）。

## 瀏覽器與固定設定

- Chromium 151.0.7922.34：`@playwright/test` 1.62.0 無頭模式實際啟動的是 `~/.cache/ms-playwright/chromium_headless_shell-1234`（已從 `/proc` 查證）。
  - 選 1.62.0 的理由：`~/Desktop/connect4-web2/frontend/node_modules/playwright-core/browsers.json`（1.62.0）對到 chromium 1234，本機已有這版，所以沒有另外下載。
- `locale: zh-TW`、`colorScheme: light`、`reducedMotion: reduce`、`isMobile: true`、`hasTouch: true`；`<html lang="zh-Hant-TW">`。
- 跑馬燈動畫在 `prefers-reduced-motion: reduce` 時關掉，所以每次截圖位置一樣。
- 中文字型：`fc-list :lang=zh-tw` 確認有 Noto Sans CJK TC（Regular～Black），三種風格都用它，沒有安裝任何系統套件。

## 裝置、安全區、示意疊加層

| 裝置 | viewport | DPR | 安全區（CSS 變數） | 輸出 |
|---|---|---|---|---|
| 一般手機（直式） | 390×844 | 3 | `--safe-top: 47px`、`--safe-bottom: 34px` | 原始 1170×2532；選項圖 1446×2934（DPR 3，不縮放）；總覽 DPR 2 |

- 示意疊加層（比對時可遮掉）：`.sim-statusbar`（上方 47px：9:41、訊號、Wi-Fi、電池、瀏海示意）、`.sim-home-indicator`（下方 134×5px 橫條，離底 8px）。
- 上方資訊列從 `--safe-top` 以下開始；分頁的按鈕底邊都在 `844 − --safe-bottom = 810px` 以上（量測 JSON 的 `safeArea`）。

## 網路狀態

不適用：獨立 mockup，沒有連線。

## 用 JS 改 DOM 做出來的狀態

不適用：畫面本身就是用 JS 依假資料產生的，沒有「在真實前端上改 DOM」的狀態。
（唯一的 JS 後處理：B 的「奶桶滿了」泡泡量好尺寸後對齊 3px 像素格，避免半像素讓像素框模糊。）

## 產生方式（為什麼能量產）

同一個流程：**基因 → `cowgen.js` 模型 → 各風格 renderer**。三種風格畫的是同一個模型，差別只在畫法。

- 基因欄位（題目要求）：毛色 `coat`、花紋 `pattern`（`patches` 大塊斑／`dots` 小點／`solid` 素色／`strawberry` 草莓）、
  角 `horns`（無／短／長）、體型 `build`（壯／一般）、毛質 `fur`（平順／蓬鬆）、特殊疊層 `overlay`（`berry` 草莓蒂頭、`cream` 奶油旋）。
- 另外加的欄位（畫得出來需要）：`eyes`（一般／大眼，娟珊用）、`age`（成牛／小牛：縮小、頭比例變大、沒有角）、
  `patternColor` 花紋色、`muzzle` 口鼻色、`earColor` 耳朵用主色或花紋色、`seed` 花紋亂數種子。
- 六個品種：荷斯坦（白底黑斑）、娟珊（淺褐、大眼）、和牛（深褐偏黑、壯、肩部隆起）、高地牛（薑黃、蓬毛、長角、瀏海）、
  草莓牛（粉紅底、草莓籽、蒂頭）、巧克力牛（咖啡底、奶油色斑、頭頂奶油旋）。
- **小牛的解讀**：題目「其中一頭頭上有泡泡，另外有一頭小牛」。這裡畫成**六個品種各一頭成牛，再加一頭荷斯坦小牛（共 7 頭）**，
  這樣六個品種都能看到成牛的樣子；如果原意是六頭之一是小牛，改 `data.js` 的 `HERD` 一行即可。
- 「奶桶滿了」泡泡在荷斯坦成牛頭上。
- `raw/gallery-*.png`：每種風格各 24 組隨機基因，證明同一個產生器能畫出幾十種品種。
- B 的像素：`cowgen-b.js` 把同一個幾何模型直接點陣化（加外框、左上受光的色階、花紋遮罩），眼睛與特殊疊層用小圖章確保清楚；
  不同大小是用較小的「每單位像素數」重新點陣化，不是把圖縮小，所以像素格一致。

## 畫面內容（三種風格相同）

- 牧場名「晴天．高原．牧場」、「Lv.5 場主」、遊戲幣「12,450」（圖示是原創的「牛鈴幣」：金幣上一個牛鈴，沒有用任何真實貨幣符號）。
- 新聞跑馬燈「颱風接近，牛奶收購價上漲中」。
- 牛奶桶 72%（36/50 瓶）；倉庫：牛奶 120 瓶（新鮮度 92%）、牛肉 3 箱。
- 行情小卡：牛奶 12.4 ▲3.2%（上揚走勢線）、牛肉 38.0 ▼1.1%（下跌走勢線）。
  **顏色用台灣慣例：漲紅跌綠**（上漲紅色、下跌綠色），和歐美股市相反。
- 底部 5 個分頁：牧場（目前頁）、市場、配種、圖鑑、排行；每個觸控範圍 ≥ 44px。
- 原創：畫面上沒有「MIX」「養豬場」字樣，也沒有真實品牌；牛肉用裝箱圖示呈現，沒有屠宰畫面。

## 量測（`raw/r1-01-*-mobile.json`）

| 項目 | A 圓潤Q版 | B 像素風 | C 軟萌立體 |
|---|---|---|---|
| 最小字級（標準 ≥ 11px） | 11px | 11px（像素數字最小 15px 高） | 11px |
| 文字被截／出框／意外換行 | 0／0／0 | 0／0／0 | 0／0／0 |
| 分頁觸控最小 | 78×59px | 76×54px | 72×66px |
| 橫向捲動 | 無 | 無 | 無 |
| 內容避開安全區 | 是 | 是 | 是 |
| 像素格 | — | 29 張像素圖全部 1:3 | — |

- B 的中文用系統字 Noto Sans CJK TC：本機沒有像素中文字型。數字、%、▲▼、Lv 用自己畫的 3×5 與 5×7 像素字形。
  如果選 B，正式版可以評估開源的像素中文字型，授權要另外查證。
- 以上都是瀏覽器模擬的預檢；手機實機（字級、觸控、安全區）要等正式畫面再由使用者確認。

## 核准版對照表

待定：使用者還沒選。選定後在這裡填「核准內容 → 原始截圖檔名 → 現況對照檔名」。
