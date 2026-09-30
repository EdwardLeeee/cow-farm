# R5 設計稿：照參考圖風格的同一隻牛，比較三種線條（第 5 輪）

- **主題**：照使用者參考圖的共同點畫「同一隻牛」；三個選項外型、顏色完全相同，只差線條處理。每頭牛都有正面與側面走路兩個角度（D11）。畫面其他部分照 R1-A。
- **日期**：2026-09-30
- **依據的使用者原話**（看過第 4 輪之後）：「都不滿意，你看一下下載的cow zip 我喜歡這種風格」
  - 參考圖是使用者下載的 5 張有浮水印的圖庫圖片（PIXTA、616pic、pngtree）：**只參考風格，不描圖、不照抄構圖、不放進 repo**。共同點見 `design/spec.md` 第 4 輪。
  - D11（使用者在 ceo 那邊選的）：「牧場裡就會轉身」——平常側面走路；停下來、被點到、奶桶滿了時轉正面；詳細資料、圖鑑、出生用正面。
- **狀態**：待使用者挑選，還沒有核准版。

| 檔名 | 內容 | 一句話（使用者會看到什麼） |
|---|---|---|
| `R5-01-牛的線條-A-細手繪線-mobile.png` | 左：牧場主畫面（五頭側面走路、兩頭轉正面）；右：九頭正面＋四頭側面走路＋剪影 | 細的咖啡色線，輪廓有一點手畫的抖動 |
| `R5-01-牛的線條-B-乾淨中線-mobile.png` | 同上 | 中等粗細的深咖啡色線，輪廓平滑乾淨 |
| `R5-01-牛的線條-C-不描邊-mobile.png` | 同上 | 沒有外框線，只用色塊分出形狀 |
| `R5-99-總覽對照.png` | 最左一格是對照（R1-A 的牛），接著 A、B、C；下面是檔名、描述、量測 | — |

這些是「使用者會看到的樣子」，不是可以直接搬進程式的程式碼：正式 app 用 Flutter／Flame 重做，規則以之後的規格為準。
選項圖外面套了示意手機框；比對請用 `raw/` 裡沒有裁角的原始截圖。

## 這隻牛（三個選項共用）

- **正面**：臉朝玩家、頭約和身體一樣高、跟身體連成一體不畫脖子線；小點眼、兩眼分開；下半臉一整條淺橘色寬口鼻（黑牛是灰粉色）、兩個小點鼻孔；耳朵往兩側上方；小角。
- **側面走路**：頭也轉成側面，口鼻在臉前端、同樣的淺橘色；一隻點眼、一個鼻孔；前後腿一前一後張開。身體、斑點位置、顏色和正面相同。
- 少數幾塊大斑、短腿、深色蹄、平塗沒有陰影和亮面、沒有牛鈴；乳用母牛有一個小乳房。
- 牧場主畫面：安格斯、高地牛、小牛、娟珊、西門塔爾側面走路；荷斯坦（奶桶滿了）與草莓牛（被點到）轉正面。
- 排排站的每排上半加了淡藍底，讓 C（不描邊）的白牛在淺色底上看得清楚；三個選項都一樣。

## 三個選項只差線條

| | 線寬（模型單位） | 線色 | 輪廓 |
|---|---|---|---|
| A 細手繪線 | 1.3 | `#6A4435` | 沿法線加平滑的小抖動（固定亂數，重拍相同） |
| B 乾淨中線 | 2.4 | `#4B3326` | 平滑 |
| C 不描邊 | 0 | — | 平滑；淺色牛的尾巴改用深一點的同色系，否則會看不見 |

R1-A 畫面本身的卡片、按鈕還是粗描邊；如果細線的牛勝出，畫面要不要跟著變細，之後再請使用者選。

## 基因決定長相（照企劃書 4.5）

流程：**基因（`src/data.js`）→ `plan()` → 幾何 → 畫筆（`src/shapes/q.js`）**，全部在 `src/shapes/ref.js`。
品種、公母、小牛與角的規則同第 4 輪 README：乳用最高、腿最長、有乳房；肉用最寬、最深、腿最短、無角；B 淡色骨架小一號、臉短、眼大；A 長毛更低更寬、有瀏海；公牛大一號、肩峰；小牛約成牛 58–59% 高、只有角芽。

## 資料夾內容

| 路徑 | 內容 |
|---|---|
| `src/data.js` | 基因（七個代表品種）、排排站正面九頭與側面四頭、牧場站位（含 `pose`） |
| `src/shapes/ref.js` | R5 產生器：同一隻牛、兩個角度、三種線條處理 |
| `src/shapes/q.js`、`src/r1/` | 畫筆與共用工具（從 round4 複製，沒有改動） |
| `src/cows.js` | 選項登記與排排站外框計算 |
| `src/screen.html?v=a…c`、`src/lineup.html?v=a…c` | 牧場主畫面；排排站（720×1080：正面、側面走路、剪影） |
| `harness/capture.mjs`、`harness/compose.mjs` | 出圖與拼圖 |
| `harness/preview.mjs`、`harness/preview-scene.mjs`、`harness/svg2png.py` | 不開瀏覽器的快速預覽（node＋librsvg） |
| `raw/` | 原始截圖（PNG 不進 git）與量測 JSON；`r5-00-control-r1a` 是從 `round2/raw/r2-lineup-0` 複製來的對照 |

### 指令（這台電腦曾經記憶體用光當機，一律照這個做法）

```bash
cd design/artboards/round5
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm ci
cp ../round2/raw/r2-lineup-0.png raw/r5-00-control-r1a.png; cp ../round2/raw/r2-lineup-0.json raw/r5-00-control-r1a.json
free -m    # available 少於 2000 MB 就先等
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 node harness/capture.mjs
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 node harness/compose.mjs
```

## 前端版本

不適用：還沒有前端，這一輪是獨立的 HTML mockup。

## 瀏覽器與固定設定

- Chromium（`@playwright/test` 1.62.0，`~/.cache/ms-playwright/chromium_headless_shell-1234`）；實際版本記在 `raw/*.json` 的 `browser` 欄。
- `locale: zh-TW`、`colorScheme: light`、`reducedMotion: reduce`、`isMobile: true`、`hasTouch: true`；`<html lang="zh-Hant-TW">`；字型 Noto Sans CJK TC。

## 裝置、安全區、示意疊加層

| 畫面 | viewport | DPR | 備註 |
|---|---|---|---|
| 牧場主畫面 | 390×844 | 3 | `--safe-top: 47px`、`--safe-bottom: 34px`；疊加層 `.sim-statusbar`、`.sim-home-indicator` |
| 排排站 | 720×1080 | 3 | 正面九頭、側面四頭同一比例；剪影用 SVG 濾鏡塗黑 |

進 git 的加標籤圖：單張 DPR 2、總覽 DPR 1.5。

## 網路狀態、用 JS 改 DOM 做出來的狀態

不適用：獨立 mockup，沒有連線；畫面依假資料用 JS 產生。

## 量測（`raw/*.json`）

| 項目 | A | B | C |
|---|---|---|---|
| 牧場畫面最小字級、文字被截／出框／意外換行 | 11px、0 | 11px、0 | 11px、0 |
| 分頁觸控、安全區、橫向捲動 | 78×59px、避開、無 | 同左 | 同左 |
| 排排站最小字級、名字被截或重疊 | 12px、0 | 12px、0 | 12px、0 |
| 小牛／成年荷斯坦身高（正面／側面） | 0.58／0.59 | 0.58／0.59 | 0.58／0.59 |

以上是瀏覽器模擬的預檢。轉身動畫這一輪不出，外型定了再出分鏡與 GIF。

## 核准版對照表

待定：使用者還沒選。
