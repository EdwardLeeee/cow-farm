# R9 設計稿：乳房在肚子上、母牛放大、公牛更大（第 9 輪）

- **主題**：依第 8 輪意見，只改乳房位置與牛的大小；另外趁這輪把正面的肩膀、小短腳和和牛的霜降紋畫得更好。其他照第 8 輪（線條 B、身體曲線、短尾巴、正面臉長 B）。
- **日期**：2026-09-30
- **依據的使用者原話**（看過第 8 輪之後）：「1. 奶頭是在肚子上，不是屁股，如果放不下你也可以讓母牛大一點 公牛更大」；接著說「你慢慢想好好畫，我不趕時間」。
- **著作權底線（D13）**：只貼近參考圖的比例與特徵；斑點排列、角和耳朵的確切形狀、細部比例是我們自己的，不描圖、參考圖不進 repo。
- **狀態**：待使用者看圖。

| 檔名 | 項目與選項 | 使用者會看到什麼 |
|---|---|---|
| `R9-01-乳房在肚子上-A-母牛放大公牛更大-mobile.png` | 01 乳房在肚子上（只有一個版本） | 左牧場畫面（五頭側面走路、荷斯坦與草莓牛轉正面坐著）、中側面九頭＋剪影、右正面九頭＋剪影 |
| `R9-99-總覽對照.png` | 0 現況（第 8 輪）與第 9 輪並排 | — |

## 這一輪改了什麼

| | 第 8 輪 | 第 9 輪 |
|---|---|---|
| 側面乳房 | 掛在後腿前面，靠近屁股 | 掛在肚子中間（前後腿中間） |
| 正面乳房 | 兩條大腿中間的最底下，看起來像屁股 | 肚子上：胸前小短腳下方、身體正面；圓圓的粉紅乳房（寬約高的 1.6 倍），下緣四個奶頭 |
| 母牛大小 | — | 整體 1.08 倍；正面身體再加寬 12%、加高 10%，肚子放得下乳房 |
| 公牛大小 | 母牛的 1.1 倍 | 約母牛的 1.2 倍 |
| 小牛 | 成牛的 58%／56% | 成牛的 58%／58%（側面／正面） |
| 正面肩膀 | 窄，身體像往下張開的斗篷 | 寬一點，上窄下寬的梯形 |
| 正面小短腳 | 細長 | 短一點，下端稍微往外 |
| 和牛霜降紋 | 波浪線 | 一群淡色、像米粒的細點（側面在身體中間，正面在兩側肩膀） |
| 牧場站位 | 荷斯坦和草莓牛坐著會疊在一起 | 草莓牛往右下移、荷斯坦往左一點 |

- 正面臉長：使用者沒選，照「沒提到就是同意」用第 8 輪 01 的 B（臉高÷寬 1.25），可以隨時換 A（1.1）或 C（1.4）。
- 側面乳房選「畫清楚」，使用者也可以改選拿掉。

## 資料夾內容與指令

| 路徑 | 內容 |
|---|---|
| `src/shapes/r9.js` | R9 產生器（以 r8.js 為底） |
| `src/data.js`、`src/cows.js`、`src/lineup.js` | 基因、站位（草莓牛與荷斯坦位置調整）、登記、排排站（`?v=r9&view=side｜front`） |
| `harness/capture.mjs`、`harness/compose.mjs`、`harness/preview*.mjs`、`svg2png.py` | 出圖、拼圖、不開瀏覽器的快速預覽 |
| `harness/bigsheet.mjs` | 本機檢查用：九頭牛放大成一張圖（不進設計稿） |
| `raw/` | 原始截圖（PNG 不進 git）與量測 JSON；`r9-00-r8-*` 是從 `round8/raw/` 複製來的 0 現況 |

```bash
cd design/artboards/round9
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm ci
for f in side front; do cp ../round8/raw/r8-lineup-$f-r8.png raw/r9-00-r8-$f.png; cp ../round8/raw/r8-lineup-$f-r8.json raw/r9-00-r8-$f.json; done
cp ../round8/raw/r8-r8-mobile.png raw/r9-00-r8-mobile.png; cp ../round8/raw/r8-r8-mobile.json raw/r9-00-r8-mobile.json
free -m    # available 少於 2000 MB 就先等
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 node harness/capture.mjs
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 node harness/compose.mjs
```

## 前端版本、網路狀態、用 JS 改 DOM 的狀態

不適用：獨立 HTML mockup。

## 瀏覽器、裝置

同第 8 輪：Chromium（`@playwright/test` 1.62.0），`zh-TW`、light、`reducedMotion: reduce`；牧場主畫面 390×844 DPR 3（安全區 47／34px，疊加層 `.sim-statusbar`、`.sim-home-indicator`）；排排站 720×900 DPR 3；進 git 的單張 DPR 2、總覽 DPR 1.5。

## 量測（`raw/*.json`）

出圖後填。

## 核准版對照表

待定。
