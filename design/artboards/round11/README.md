# R11 設計稿：粉紅圓乳房三種大小、v0.2 新名單（第 11 輪）

- **主題**：套用第 10 輪的選擇（和牛黑亮加短角、黑牛毛改炭灰），試畫使用者提議的「沒有外框的粉紅圓」乳房，並換成企劃書 v0.2 的新名單（乳牛、耕牛、肉牛）。
- **日期**：2026-09-30
- **依據的使用者原話**（第 10 輪選擇欄位的回答）：01「不如就肚子中間劃一圈沒有框的粉紅色就代表乳房，你試試看」、02「C 黑亮加短角」、03「B 毛改炭灰」。
- **企劃書**：v0.2（main 8070fb0；D17 玩法修改、D18 角規則）。
- **著作權底線（D13）**：只貼近參考圖的比例與特徵，不描圖、參考圖不進 repo。
- **狀態**：待使用者看圖。

| 檔名 | 項目與選項 | 使用者會看到什麼 |
|---|---|---|
| `R11-01-乳房-A-中-mobile.png` | 01 乳房 A 中（預設） | 牧場畫面、正面 12 頭、乳房特寫；肚子中間一塊沒有外框的粉紅圓，直徑約身體寬的 28% |
| `R11-01-乳房-B-小-mobile.png` | 01 乳房 B 小 | 同上，粉紅圓約身體寬的 20% |
| `R11-01-乳房-C-大-mobile.png` | 01 乳房 C 大 | 同上，粉紅圓約身體寬的 36% |
| `R11-02-新名單-A-乳牛耕牛肉牛-mobile.png` | 02 新名單（只有一個版本） | 側面 12 頭、正面 12 頭、新耕牛特寫（台灣黃牛、台灣水牛；下面是和牛與安格斯在牧場上的大小） |
| `R11-99-總覽對照.png` | 全部並排，0 現況是第 10 輪 | — |

- 乳房只畫在成年母乳牛（荷斯坦、娟珊、巧克力牛、草莓牛）的正面；公牛、小牛、耕牛、肉牛都沒有；側面都不畫。
- 項目 02 只畫一個版本：新名單照企劃書畫，台灣黃牛的肩峰、台灣水牛的角是新設計，讓使用者看了再說。
- 這些是「使用者會看到的樣子」，不是可以直接搬進程式的程式碼。

## 排排站 12 頭

| 排 | 牛 |
|---|---|
| 乳牛 | 荷斯坦（母）、荷斯坦公牛、荷斯坦小牛 |
| 乳牛（稀有） | 娟珊（B）、巧克力牛（B＋C）、草莓牛（A＋B＋C 傳說） |
| 耕牛 | 台灣黃牛（一般，肩峰）、高地牛（A，長角）、台灣水牛（C，水牛角） |
| 肉牛 | 安格斯（一般，炭灰、無角）、和牛（C，黑亮加短角）、夏洛來（B，奶油白、無角） |

## 資料夾內容與指令

| 路徑 | 內容 |
|---|---|
| `src/data.js` | v0.2 基因與角的規則（`hornsFor`）、12 頭排排站、牧場站位（西門塔爾換成台灣黃牛） |
| `src/shapes/r11.js` | R11 產生器；`VARIANTS`：`r11`／`udderM`（中）、`udderS`（小）、`udderL`（大） |
| `src/lineup.html?v=…&view=side｜front` | 12 頭排排站（720×1200），每排左上角標用途；剪影分兩排 |
| `src/closeup.html?v=…&mode=udder｜v02` | 乳房特寫／新耕牛特寫（720×900） |
| `harness/capture.mjs`、`harness/compose.mjs` | 出圖與拼圖 |
| `harness/preview*.mjs`、`bigsheet.mjs`、`darksheet.mjs`、`svg2png.py` | 不開瀏覽器的本機預覽（不進設計稿） |
| `raw/` | 原始截圖（PNG 不進 git）與量測 JSON；`r11-00-r10-*` 是從 `round10/raw/` 複製來的 0 現況 |

```bash
cd design/artboards/round11
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm ci
cp ../round10/raw/r10-closeup-udder-teatsOn4.png raw/r11-00-r10-udder.png; cp ../round10/raw/r10-closeup-udder-teatsOn4.json raw/r11-00-r10-udder.json
for f in side front; do cp ../round10/raw/r10-lineup-$f-r10.png raw/r11-00-r10-$f.png; cp ../round10/raw/r10-lineup-$f-r10.json raw/r11-00-r10-$f.json; done
free -m    # available 少於 2000 MB 就先等
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 node harness/capture.mjs
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 node harness/compose.mjs
```

## 前端版本、網路狀態、用 JS 改 DOM 的狀態

不適用：獨立 HTML mockup。

## 瀏覽器、裝置

同第 10 輪：Chromium（`@playwright/test` 1.62.0），`zh-TW`、light、`reducedMotion: reduce`；牧場主畫面 390×844 DPR 3（安全區 47／34px，疊加層 `.sim-statusbar`、`.sim-home-indicator`）；排排站 720×1200、特寫 720×900，DPR 3；進 git 的單張 DPR 2、總覽 DPR 1.5。

## 量測（`raw/*.json`）

| 項目 | 結果 |
|---|---|
| 牧場畫面（中、小、大）最小字級、文字被截／出框／意外換行 | 11px、0 |
| 分頁觸控、安全區、橫向捲動 | 78×59px、避開、無 |
| 排排站最小字級、名字被截或重疊、直向超出 | 12px、0、無 |
| 特寫面板最小字級、名字被截或重疊、直向超出 | 13px、0、無 |
| 小牛／成年荷斯坦身高（側面／正面） | 0.578／0.577 |

- 這一輪新增「直向超出」檢查（`verticalOverflow`）：第一次出圖時剪影第二排被切掉、量測沒抓到，補上後重拍。
- 以上是瀏覽器模擬的預檢；出圖前 `free -m` available 都在 2.1 GB 以上。

## 核准版對照表

待定。
