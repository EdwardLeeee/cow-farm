# R7 設計稿：兩個角度更貼近參考圖（第 7 輪）

- **主題**：線條 B 乾淨中線；正面坐著、臉各照參考圖（第 6 輪裁示）。這一輪把側面畫得更像 9966、正面畫得更像 9967。
- **日期**：2026-09-30
- **依據的使用者原話**（看過第 6 輪之後）：「做姿01-a好  臉選02-a，正面我希望你畫的跟9967一樣」，接著補充「而且側面也不夠像9966」。
- **著作權底線（D13）**：參考圖是有版權的圖庫圖片，只貼近比例與特徵；斑點排列與形狀、角和耳朵的確切形狀、細部比例是我們自己的，不描圖、參考圖不進 repo。出圖前在本機把荷斯坦放大和參考圖並排檢查過（檢查圖不存進 repo）。
- **狀態**：待使用者看圖。

| 檔名 | 項目與選項 | 使用者會看到什麼 |
|---|---|---|
| `R7-01-更像參考圖-A-側面9966正面9967-mobile.png` | 01 更像參考圖（只有一個版本） | 左牧場畫面（五頭側面、荷斯坦與草莓牛轉正面坐著）、中側面九頭＋剪影、右正面九頭＋剪影 |
| `R7-99-總覽對照.png` | 0 現況（第 6 輪使用者選的組合）與第 7 輪並排 | — |

只有一種合理做法（照使用者指定的參考圖修），所以只畫一個版本；0 現況放在總覽對照。

## 這一輪改了什麼

| | 第 6 輪 | 第 7 輪 |
|---|---|---|
| 側面身體 | 偏扁長 | 深而方（深約長的 0.74），背往屁股稍微往下 |
| 側面頭 | 約身體深的 0.7 | 約身體深的 0.84，頭頂略高過背 |
| 側面眼睛 | 臉的中間 | 臉的上半，兩眼分開 |
| 側面口鼻 | 淺橘色，有深色分界線 | 淺橘色，只換顏色、沒有分界線 |
| 側面腿 | 張開走路 | 直直站著、稍粗（走路動作之後做動畫）；乳用腿短一點 |
| 側面斑 | 大塊 | 小一點，白色比較多 |
| 正面身體 | 圓的梨形 | 高的梯形，上窄下寬、兩側微鼓 |
| 正面臉 | 寬約高的 1.2 倍 | 寬約高的 1.3 倍、下巴收窄；眼睛靠近、偏高 |
| 正面腳 | 前腳粗短、後腳橢圓 | 胸前兩隻細小前腳；後腳從底部往外伸，腳尖深色 |
| 正面細節 | — | 圓形耳標（畫面右邊的耳朵） |

我們自己的細節（不照參考圖）：正面的角是往外再往內彎的月牙、耳朵圓頭微垂、耳標是圓的、斑點排列是自己的（右上大、左下中、中間小、右下被邊切掉），顏色沿用 R1-A 的色票。

## 資料夾內容與指令

| 路徑 | 內容 |
|---|---|
| `src/shapes/r7.js` | R7 產生器（側面 9966 構圖、正面 9967 構圖、線條 B） |
| `src/data.js`、`src/cows.js`、`src/lineup.js` | 基因、登記、排排站（`?view=side｜front`） |
| `harness/capture.mjs`、`harness/compose.mjs`、`harness/preview*.mjs`、`svg2png.py` | 出圖、拼圖、不開瀏覽器的快速預覽 |
| `raw/` | 原始截圖（PNG 不進 git）與量測 JSON；`r7-00-r6-*` 是從 `round6/raw/` 的 `sitRef` 複製來的 0 現況 |

```bash
cd design/artboards/round7
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm ci
for f in side front; do cp ../round6/raw/r6-lineup-$f-sitRef.png raw/r7-00-r6-$f.png; cp ../round6/raw/r6-lineup-$f-sitRef.json raw/r7-00-r6-$f.json; done
cp ../round6/raw/r6-sitRef-mobile.png raw/r7-00-r6-mobile.png; cp ../round6/raw/r6-sitRef-mobile.json raw/r7-00-r6-mobile.json
free -m    # available 少於 2000 MB 就先等
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 node harness/capture.mjs
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 node harness/compose.mjs
```

## 前端版本、網路狀態、用 JS 改 DOM 的狀態

不適用：獨立 HTML mockup。

## 瀏覽器、裝置

同第 6 輪：Chromium（`@playwright/test` 1.62.0），`zh-TW`、light、`reducedMotion: reduce`；牧場主畫面 390×844 DPR 3（安全區 47／34px，疊加層 `.sim-statusbar`、`.sim-home-indicator`）；排排站 720×900 DPR 3；進 git 的單張 DPR 2、總覽 DPR 1.5。

## 量測（`raw/*.json`）

| 項目 | 第 7 輪 |
|---|---|
| 牧場畫面最小字級、文字被截／出框／意外換行 | 11px、0 |
| 分頁觸控、安全區、橫向捲動 | 78×59px、避開、無 |
| 排排站最小字級、名字被截或重疊（側面／正面） | 12px、0／12px、0 |
| 小牛／成年荷斯坦身高（側面／正面） | 0.595／0.561 |
| 正面坐著高度／側面站著高度（荷斯坦／安格斯） | 1.20／1.06 |

以上是瀏覽器模擬的預檢。出圖時 `free -m` available 約 1.87 GB，低於 2 GB 的等待門檻（仍在 `systemd-run MemoryMax=1500M` 內完成）；之後出圖前會等到 2 GB 以上。

## 核准版對照表

待定。
