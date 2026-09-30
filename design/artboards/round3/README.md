# R3 設計稿：五種新畫風（第 3 輪）

- **主題**：整個畫面換成五種全新的畫風，牛延用 R2-C「側面輪廓」的造型方向，小牛比例重做。
- **日期**：2026-09-30
- **依據的使用者原話**（看過 R2 之後）：「側面的好多了，但我不喜歡目前的風格，還有小牛的比例超級怪。請你提供五種新的不同風格的畫風」
  - 解讀（ceo）：牛延用 R2-C 的側面造型；整體畫風不要 R1-A 圓潤Q版，也不再出 R1 已否決的像素風、軟萌立體；小牛比例要修。
- **狀態**：待使用者挑選，還沒有核准版。

| 檔名 | 內容 | 一句話 |
|---|---|---|
| `R3-01-美術風格-A-水彩繪本-mobile.png` | 左：牧場主畫面；右：七頭側面牛排排站 | 水彩暈染、紙紋、鉛筆線，溫暖柔和 |
| `R3-01-美術風格-B-剪紙拼貼-mobile.png` | 同上 | 一層層色紙，邊緣不規則、底下有小陰影 |
| `R3-01-美術風格-C-扁平幾何-mobile.png` | 同上 | 沒有描邊的大色塊與切面幾何，配色大膽 |
| `R3-01-美術風格-D-復古農場海報-mobile.png` | 同上 | 低飽和、網點陰影、放射光芒、明體標題 |
| `R3-01-美術風格-E-日系手帳線稿-mobile.png` | 同上 | 細線條加淡彩、米白點格紙、紙膠帶 |
| `R3-99-總覽對照.png` | 最左一格小的 0 現況（R2-C），接著五種畫風；每格是縮小的牧場畫面＋排排站，下面是檔名、描述、量測 | — |

這些是「使用者會看到的樣子」，不是可以直接搬進程式的程式碼；正式 app 用 Flutter／Flame 重做，規則以之後的規格為準。
選項圖外面套了示意手機框（四角 46px 圓角）；比對請用 `raw/` 裡沒有裁角的原始截圖。

## 五種畫風：整個畫面都換

天空、地面、穀倉、UI 面板、圖示、數字字型都跟著畫風換，不是只換牛。

| 畫風 | 畫面處理 | 字型（只用本機已有的） | 在 Flutter／Flame 怎麼量產 |
|---|---|---|---|
| A 水彩繪本 | SVG 濾鏡：turbulence＋displacement 讓色塊邊緣不規則、邊緣顏料堆積、顆粒感；抖動的鉛筆線；整張紙紋 | 楷體（AR PL UKai TW）標題、Noto Sans CJK TC 數字與內文 | 水彩濾鏡在手機上即時算太重：建置時用同一個 SVG 產生器依基因把每頭牛輸出成 PNG 精靈圖（sprite），Flame 用 SpriteComponent 顯示；紙紋是一張重複貼圖 |
| B 剪紙拼貼 | 每一塊都是色紙：邊緣 displacement、紙纖維紋理、每層小陰影；UI 是剪下來的色紙與斜貼的紙條 | Noto Sans CJK TC 粗體 | 建置時把每個部位輸出成帶陰影的 PNG 圖層（或整頭牛一張精靈圖）；也可以把產生器的幾何點轉成 Flutter Path，用 drawShadow＋紙紋 ImageShader 即時畫 |
| C 扁平幾何 | 沒有描邊、沒有漸層，大色塊，曲線改成切面多邊形；暗面是一塊平塗的深色 | Noto Sans CJK TC 粗體 | 最容易：產生器輸出的多邊形直接轉成 Flutter Path，用 Canvas.drawPath 即時畫，不必預先輸出圖片 |
| D 復古農場海報 | 低飽和配色、略粗糙的墨線、暗面網點、色塊與墨線有一點套印偏移、天空放射光芒、紙紋 | 明體（AR PL UMing TW）標題、Noto Sans CJK TC 數字 | 色塊與墨線用 Path 即時畫；網點和紙紋做成貼圖（ImageShader）遮在暗面；或建置時輸出精靈圖 |
| E 日系手帳線稿 | 細的單線條加淡彩，淡彩稍微錯開；米白點格紙、紙膠帶、虛線 | 楷體點綴（標題、分頁）、Noto Sans CJK TC 內文 | 線條與淡彩都是 Path，用 Canvas 即時畫（描線＋位移的填色）；點格紙是一張重複背景圖 |

## 牛

- **造型**：延用 R2-C 側面輪廓（頭也是側面、口鼻往前），五種畫風**共用同一個牛的幾何模型**（`src/cowgeo.js`），只換 renderer。
- 幾何模型輸出「部位清單」（角色、形狀、畫的順序、要裁在哪個區域），不含任何畫風資訊；`src/render.js` 走訪清單，畫風只決定每個部位怎麼畫。
- **體型由基因決定**（`src/plan.js`，同 R2）：荷斯坦高瘦乳用、娟珊嬌小、和牛矮壯、高地牛低矮長毛長角、草莓牛圓潤、巧克力牛兼用。
- **小牛比例重做**（R2 的小牛大頭、細長腿、小身體）：身高約成年荷斯坦的 59%（實測 52.3／89.0）、身體短而圓、頭相對大但不大過身體、腿比成牛略長一點但有肉且膝蓋圓、沒有乳房、只有小角芽。排排站裡小牛放在成年荷斯坦旁邊，一起看比例。
- 共同特徵照舊：耳朵往兩側、角或角芽、尾巴末端一撮毛、深色蹄、成年母牛有乳房、牛鈴項圈、奶油色寬扁口鼻。

## 資料夾內容

| 路徑 | 內容 |
|---|---|
| `src/cowgeo.js` | 牛的幾何模型（五種畫風共用） |
| `src/scenegeo.js`、`src/icongeo.js` | 牧場背景與圖示的幾何（同樣是部位清單，五種畫風共用） |
| `src/render.js`、`src/kit.js` | 部位清單走訪器；把畫風包成畫面需要的場景、牛、圖示、數字、頭像、走勢線 |
| `src/styles/{a,b,c,d,e}.js／.css` | 五種畫風：怎麼畫每個部位、濾鏡與圖樣、UI 外觀 |
| `src/plan.js`、`src/data.js`、`src/q.js`、`src/r1/` | 體型參數、基因、幾何工具；牧場假資料與站位沿用 R1（從 round2 複製，round1、round2 沒有改動） |
| `src/screen.html?s=a…e`、`src/lineup.html?s=a…e` | 牧場主畫面、七頭排排站（640×864） |
| `harness/capture.mjs`、`harness/compose.mjs` | 出圖與拼圖；`server.mjs`、`serve.mjs`、`shot.mjs` 同前兩輪 |
| `raw/` | 未縮放原始截圖與量測 JSON；`r3-00-control-*` 是從 round2 複製來的 0 現況對照（沒有重拍） |

### 指令（這台電腦曾經記憶體用光當機，一律照這個做法）

```bash
cd design/artboards/round3
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm ci
free -m    # available 少於 2000 MB 就先等
# 一次只開一個瀏覽器；濾鏡多的畫面一個 job 跑一次
for j in r3-01-a r3-01-b r3-01-c r3-01-d r3-01-e r3-lineup-a r3-lineup-b r3-lineup-c r3-lineup-d r3-lineup-e; do
  systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 node harness/capture.mjs $j
done
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 node harness/compose.mjs
```

遇到 exit 137 就改成更小的單位或降低同時開的頁面數，不要調高上限。

## 前端版本

不適用：還沒有前端，這一輪是獨立的 HTML mockup。

## 瀏覽器與固定設定

- Chromium 151.0.7922.34（`@playwright/test` 1.62.0，無頭模式用 `~/.cache/ms-playwright/chromium_headless_shell-1234`，沒有另外下載）。
- `locale: zh-TW`、`colorScheme: light`、`reducedMotion: reduce`、`isMobile: true`、`hasTouch: true`；`<html lang="zh-Hant-TW">`。
- 字型只用本機已有的：Noto Sans CJK TC、AR PL UKai TW（楷體）、AR PL UMing TW（明體）；沒有下載或安裝字型。

## 裝置、安全區、示意疊加層

| 畫面 | viewport | DPR | 備註 |
|---|---|---|---|
| 牧場主畫面 | 390×844 | 3 | `--safe-top: 47px`、`--safe-bottom: 34px`；疊加層 `.sim-statusbar`、`.sim-home-indicator` |
| 七頭排排站 | 640×864 | 3 | 七頭同一比例；荷斯坦與小牛並排 |

單張選項圖 3450×2934（DPR 3，不縮放）；總覽 DPR 2。

## 網路狀態

不適用：獨立 mockup，沒有連線。

## 用 JS 改 DOM 做出來的狀態

不適用：畫面本身就是依假資料用 JS 產生的。

## 量測（`raw/*.json`）

| 項目 | A | B | C | D | E |
|---|---|---|---|---|---|
| 牧場畫面最小字級（標準 ≥ 11px） | 11px | 11px | 11px | 11px | 11px |
| 牧場畫面文字被截／出框／意外換行 | 0 | 0 | 0 | 0 | 0 |
| 分頁觸控最小（標準 ≥ 44px） | 78×61px | 78×62px | 78×62px | 78×62px | 78×61px |
| 內容避開安全區、沒有橫向捲動 | 是 | 是 | 是 | 是 | 是 |
| 排排站最小字級、名字被截 | 13px、0 | 13px、0 | 13px、0 | 12px、0 | 13px、0 |
| 楷體／明體／Noto 字型載入 | 是 | 是 | 是 | 是 | 是 |

- 小牛與成年荷斯坦的身高比：0.59（52.3／89.0 單位），在 55–60% 範圍內。
- 以上是瀏覽器模擬的預檢；實機確認等正式畫面。

## 核准版對照表

待定：使用者還沒選。選定後填「核准內容 → 原始截圖檔名 → 現況對照檔名」。

## 進 git 的方式（ceo 2026-09-30）

- 為了控制公開 repo 的大小，加標籤的選項圖與總覽都從拼圖輸出縮成 2/3 再進 git，選項圖相當於裝置像素比 2。
- `raw/` 的原始截圖（PNG）不進 git（見 `.gitignore`），量測 JSON 有進 git。
- 要取得原尺寸，照上面的指令用 harness 重新產生（同一個 commit、同樣的假資料）。
