# 牛在 app 裡怎麼畫、同品種的個體差異怎麼保留、要內建多大的字型：研究

- 日期：2026-10-02
- 負責：cow-app（只研究，沒有改產品程式；檔頭「結果」2026-10-02 補上 ceo 的決定和一處更正）
- 問題：
  - cow-app brief（`docs/briefs/2026-10-01-app.md`）第 2 步：牛要畫 24 種 × 公母 × 小牛／成牛／老牛 × 側面／正面，加上轉身。比較 (a) cow-ui 用產生器匯出圖、app 載入，和 (b) 把產生器移植成 Dart；同品種的個體微調怎麼保留；列出要 cow-ui 匯出的東西。
  - ceo 2026-10-02 補充：
    - 這一步不量 fps，改成 M4 的驗收條件。
    - 字型要量完整版、常用字子集和可變字型的大小。
    - 決定時看三件事：多出來的 MB 數、跟核准圖的一致性、cow-ui 之後改牛時要不要整批重出。

## 結果（2026-10-02 更新）

- **ceo 定的**（PR #28 合併後，記成 T3）：
  - 牛用選項 2：會變花紋的 9 種各 4 個變體，加上 12 種的朝右版本。
  - 字型內建可變字型完整版。
- **更正：素材不在建置時轉換，執行時直接讀 SVG**（ceo 2026-10-02，選三個做法的第 1 種）。
  - 原本建議用 pubspec 的 asset transformer 在建置時把 SVG 編成 `.vec`。研究時只拿 1 個檔試，確認會轉換、解得開。
  - 真的對 600 張開轉換後，`flutter test` 在這台的記憶體上限（1.5 GB）內兩次都在 4 秒內被 OOM 砍掉（結束碼 137）。
  - 原因：Flutter 每個檔各開一個 `dart run vector_graphics_compiler` 行程，同時 4 個（flutter_tools 的 `Pool(4)`），再加上 flutter 本身。
  - 所以改成執行時用 flutter_svg 讀 SVG。畫出來跟 `.vec` 一模一樣（第 1 節的表：直接讀 SVG 和關掉最佳化的 `.vec` 數字完全相同）。
  - 大小（600 張實測）：iPhone 安裝 +29.2 MB、下載 +5.8 MB。原本 `.vec` 是 +10.6 MB／+7.3 MB：安裝多 18.6 MB，下載反而少 1.5 MB。
  - 載入：每張第一次解析約 4.2 ms（筆電），之後快取。
  - 備案：同樣的轉換用批次模式（`vector_graphics_compiler --input-dir`，一個行程）600 張只要 3 秒、137 MB。M4 實機的載入時間或記憶體不理想時，在建置前加這一步，素材本身不用動。
- 下面「先說結論」到第 6 節是當時的分析，保留原文；跟這段不同的地方以這段為準。

## 先說結論

1. **跟核准圖一致：三個選項都做得到，因為最後都用同一個方法畫。**
   - 做法：把產生器輸出的 SVG 交給 flutter_svg 畫。
   - 比對對象：設計稿出圖用的 Chromium。
   - 結果（384 張）：
     - 差到看得出來（超過 16／255）的像素，中位數 0.13%、最多 0.86%。
     - 差超過一半（128）的像素：0。
     - 外形重疊度最低 0.9991。
   - 對照組：另一個繪圖程式 librsvg 跟 Chromium 比，同一個數字是 1.16%。Flutter 比它還接近。
   - 三個選項只差在 SVG 從哪裡來。
2. **個體差異只影響 9 種牛。**
   - 會受 seed 影響的是有斑點、捲毛、星星的品種：荷斯坦、蓬蓬荷斯坦、亮黑乳牛、巧克力牛、草莓牛、蓋洛威、白絨牛、絨毛和牛、星空牛。
   - 其他 15 種，seed 怎麼換，畫出來都一模一樣。
3. **朝右的牛不能都用朝左的圖翻過來。**
   - 產生器讓高光一律在畫面左上，所以朝右時，額頭亮光（星空牛連額頭的星星）會換到另一邊。
   - 11 種有光澤的牛加上安格斯，翻過來會跟核准圖不一樣：明顯不同（差 > 64）的像素，每種的中位數 1.2–3.5%，最多 4.6%。
   - 其他 12 種翻過來完全相同。
   - 所以「匯出圖」的選項要多匯出這 12 種的朝右版本。
4. **app 會多多大：**
   - 格式：建置時編成 `.vec`，並關掉三個最佳化（理由見第 5 點）。
   - 「安裝」是 iPhone 安裝後的大小；「下載」是下載大小，也接近 Android 安裝包裡的大小。

   | 選項 | 張數 | 安裝 | 下載 |
   |---|---|---|---|
   | 1：每個品種一種長相 | 288 | +4.6 MB | +3.2 MB |
   | 2：會變的 9 種各 4 個變體 | 600 | +10.6 MB | +7.3 MB |
   | 3：移植成 Dart | 不用圖檔 | 約 0 | 約 0 |

5. **預先編譯的最佳化會改到圖。**
   - vector_graphics_compiler 預設的最佳化會把星空牛、金穗牛身上的小星芒畫細。
   - 關掉三個最佳化後，跟直接讀 SVG 的結果完全相同，還比 SVG 文字小（192 張 3.1 MB 對 9.2 MB）。
   - 載入也快 8 倍：中位數 0.5 ms 對 4.2 ms。
6. **字型：用可變字型的完整版（一個檔包含所有粗細），在 ceo 定的 15 MB 以內。**

   | 字型 | 加上泰文的大小 | 有沒有超過 15 MB |
   |---|---|---|
   | 三個固定粗細的完整版 | 17.0 MB | 超過 |
   | 可變字型 TTF 完整版 | 11.6 MB | 在內 |
   | 可變字型 TTF 常用字子集 | 3.4 MB | 在內 |

   - Flutter 3.47.5 實測，只設 fontWeight 就會帶動可變字型的粗細。
   - 跟固定粗細的字型比：字寬完全一樣，肉眼看不出差別。
   - 同時設 fontWeight 和 fontVariations 不會粗上加粗。
7. **建議：選項 2（4 個變體）＋可變字型完整版。**
   - 選項 2 的理由：
     - 荷斯坦是開局就有的牛，玩家會養很多頭。選項 1 會讓同一種牛長得一模一樣，核准的設計稿裡同品種的牛斑點是不一樣的。
     - cow-ui 改牛時，一條指令就能重出全部的圖，cow-app 不必改程式。
   - 選項 3 最省空間、每頭都不一樣，但要移植約 1,300 行，之後產生器每改一次，cow-app 都要跟著改 Dart（見第 4 節）。
   - 字型：可變字型的完整版能不能算 ceo 說的「完整版」，請 ceo 定（見第 6 節）。
8. **fps 這一步不量**。照 ceo 的決定，改成 M4 的驗收條件：
   - 在 iPhone 14 Pro Max（TestFlight）上，牧場 40 頭牛走動。
   - fps 中位數 ≥ 55，最慢 5% ≥ 30。

## 名詞

- **SVG**：用文字描述的向量圖，放大不會糊。設計稿的牛就是產生器輸出的 SVG。
- **點陣圖**：一格一格像素的圖，例如 PNG。手機最後都是把牛畫成點陣圖再貼到畫面上。
- **flutter_svg**：Flutter 用來畫 SVG 的套件。
- **`.vec`**：vector_graphics 套件的預先編譯格式。建置 app 時就先把 SVG 轉好，手機上不用再解析文字。
- **seed（種子）**：產生器的亂數起點。同一個品種換一個 seed，斑點、捲毛、星星的位置就不一樣，這就是「個體差異」。
- **變體**：同一個品種預先挑幾個 seed 各畫一份，每頭牛依編號挑一份。
- **朝向**：牛臉朝左或朝右。產生器朝右時不是單純翻轉，高光會留在畫面左上。
- **可變字型**：一個字型檔包含所有粗細（100–900），用一個數字調粗細。
- **常用字子集**：只留常用的字，讓字型檔變小；字型裡沒有的字，手機改用系統字型顯示。
- **像素差**：同一個位置兩張圖的顏色差，0–255。16 以下肉眼幾乎看不出來，128 以上是完全不同的顏色。

## 1. 正確性：跟核准圖一不一致

**量法**
- 用設計稿的產生器（`design/m2/src/cow/`，cowcheck 103/103 鎖住的那一份）匯出每一種組合的 SVG。腳本是 `cow-render/export.mjs`，共 384 張：24 種 × 公母 × 小牛／成牛 × 側面／正面 × 朝左／朝右。
- 同一批 SVG 用兩邊畫成 3 倍解析度的 PNG：
  - Chromium（`chromium_render.mjs`）：設計稿出圖用的同一個瀏覽器，當標準答案。
  - Flutter（`spike/test/render_test.dart`）。
- `compare.py` 疊在白底上逐像素比，只算牛的範圍。

**結果**

| 比較 | 張數 | 像素差的平均（中位數） | 差 > 16 的像素（中位數／最多） | 差 > 128 的像素（最多） | 外形重疊度（最低） |
|---|---|---|---|---|---|
| flutter_svg 直接讀 SVG vs Chromium | 384 | 0.22 | 0.13%／0.86% | 0% | 0.9991 |
| `.vec`，關掉三個最佳化 vs Chromium | 192 | 0.22 | 0.13%／0.86% | 0% | 0.9991 |
| `.vec`，預設的最佳化 vs Chromium | 192 | 0.28 | 0.30%／1.26% | 0.087% | 0.9991 |
| 對照組：librsvg vs Chromium | 192 | 0.83 | 1.16%／2.60% | 0.011% | 0.9966 |

- 差最多的幾張只差在線條邊緣的抗鋸齒：`cow-render/results/worst-svg-vs-chromium-both-facings.png`，右欄是差異放大 4 倍。
- 預設的最佳化會把星芒畫細（`results/vec-optimized-sparkle-zoom.png`，由左到右：Chromium、直接讀 SVG、預設最佳化）。所以 `.vec` 一定要關掉 `--optimize-masks`、`--optimize-clips`、`--optimize-overdraw`。

**朝右能不能翻轉朝左的圖**
- 產生器 `q.js` 的 painter：`lx = mirror ? 1 : -1`，註解寫「高光一律在畫面左上」。
- 量法（`mirror.py`）：
  - 把朝左的 SVG 在向量階段左右翻轉，用 Chromium 畫，跟原生朝右比。
  - 同一個繪圖程式、位置完全對齊，所以量到的只有真正的差別。
- 結果（`results/mirror-vs-native-right.*`）：
  - 外形重疊度全部是 1.0。
  - 12 種完全相同：荷斯坦、蓬蓬荷斯坦、娟珊、奶油棉花牛、草莓牛、台灣黃牛、高地牛、奶茶黃牛、棉花糖高地牛、蓋洛威、夏洛來、白絨牛。
  - 安格斯差 0.16%。
  - 11 種有光澤的牛，差 > 64 的像素每種的中位數 1.2–3.5%，個別圖從 0.11% 到 4.6%：星空牛、蜂蜜牛、金穗牛、台灣水牛、和牛、黑絨乳牛、長毛水牛、絨毛和牛、亮黑乳牛、巧克力牛、白和牛。
  - 差的是額頭亮光和額頭星星的位置（`results/mirror-vs-native-right-worst.png`）。
- 核准的設計稿裡：
  - 牧場靜止的畫面，朝右的牛是原生朝右。
  - 走路動畫 A-11 往回走時，是把整頭牛左右翻轉（`anims.js` walkFrame 的 `scale(${flip} 1)`）。
  - 所以 app 也照這樣：靜止時用原生朝向，往回走時翻轉。

**個體差異**
- 每個品種用 8 個 seed 畫成年母牛，看畫出幾種不同的樣子（`results/export-stats-both-facings-k8.json` 的 `perBreedSeedVaries`）。
- 會變的 9 種：荷斯坦、蓬蓬荷斯坦、亮黑乳牛、巧克力牛、草莓牛、蓋洛威、白絨牛、絨毛和牛、星空牛。
- 其他 15 種，8 個 seed 畫出來都一樣。

**移植成 Dart 能不能做到一字不差**（選項 3 的驗法）
- 產生器用到 `Math.sin`、`cos`、`atan2`、`hypot`、`round`，座標輸出是 `Math.round(v * 100) / 100` 轉字串。程式裡沒有排序，所以不會有排序後順序不同的問題。
- 量法（`mathcheck.mjs`、`spike/tool/mathcheck.dart`）：20 萬筆亂數，node 23.11 和 Dart（Flutter 3.47.5）各算一次。
- 結果：
  - 計算結果位元不同的比例：sin 3.3%、cos 3.4%、atan2 17.8%、`hypot` 對 `sqrt(x²+y²)` 36.6%。
  - 照產生器的寫法四捨五入到 0.01，再照 JavaScript 的規則轉字串（`.5` 往正無限大進位、整數不帶 `.0`）：20 萬筆全部相同。
- 結論：移植版可以拿 cow-ui 匯出的參考 SVG 逐字比對。少數剛好落在進位邊界的數字，可以退一步改成「差不超過 0.01」。

## 2. 速度：載入成本（不是 fps）

- 環境：Intel i5-8250U 筆電，`flutter test`（Linux，Skia CPU 繪圖），Flutter 3.47.5，flutter_svg 2.3.0。
- 量法：每張圖量一次「解析」和「畫成 3 倍點陣圖」的時間（`results/raster-timing-*.csv`）。

| 步驟 | 中位數 | 最慢 5% |
|---|---|---|
| 解析 SVG 文字 | 4.2 ms | 7.4 ms |
| 解析 `.vec` | 0.5 ms | 1.3 ms |
| 畫成 3 倍點陣圖 | 2.7 ms | 4.5–5.0 ms（最慢 14 ms） |

- 這是每種長相只做一次的成本，做完的圖存起來重複用。之後每一格畫面只是把圖貼上去，加上移動、翻轉、搖晃。
- 以 40 頭都不一樣、各要側面加正面來算，筆電上約 0.3–0.6 秒，可以在背景慢慢做。
- 這些數字不代表 fps。
- **M4 驗收條件（ceo 2026-10-02 定）**，在 iPhone 14 Pro Max（TestFlight）上量：
  1. 牧場 40 頭牛走動：fps 中位數 ≥ 55，最慢 5% ≥ 30。量法沿用 `docs/research/tech-stack/flutter-findings.md` 的 FrameTiming 做法。
  2. 安裝大小（執行時讀 SVG：牛 +29.2 MB、字型 +11.8 MB）。
  3. 牧場第一次打開到牛全部畫出來的時間（每張 SVG 第一次要解析，筆電上約 4.2 ms 一張）。
  4. 記憶體。
  - 第 3、4 項不理想時，在建置前加批次編譯成 `.vec` 的步驟（見檔頭「結果」），素材不用動。

## 3. 大小與記憶體

**牛的圖檔**
- 格式：`.vec`，關掉最佳化。
- 量法：`sizes.py`，結果在 `results/cow-asset-sizes.json`。
- 「需要朝右」是第 1 節量到翻轉後會不一樣的 12 種。

| 變體數 | 只匯出朝左 | 朝左＋12 種的朝右 | 兩個朝向全部 |
|---|---|---|---|
| 1 | 192 張，3.09／2.14 MB | 288 張，4.60／3.17 MB | 384 張，6.19／4.27 MB |
| 4 | 408 張，7.31／5.09 MB | 600 張，10.58／7.33 MB | 816 張，14.62／10.16 MB |
| 8 | 696 張，12.94／9.02 MB | 1,016 張，18.55／12.89 MB | 1,392 張，25.88／18.03 MB |

（每格：張數，安裝大小／下載大小）

- 對照：直接放 SVG 文字，384 張要 18.3 MB（壓縮後 3.5 MB）。iPhone 安裝後是解開放的，所以 `.vec` 比較省。

**記憶體**（用「寬 × 高 × 4 bytes」算的，不是量的）
- 條件：430 寬的手機、最前排的牛（`scene.js` 的放大 1.04 × 430/390）、3 倍解析度。
- 一張圖多大：
  - 成牛側面：中位數 596 KB、最大 902 KB。
  - 成牛正面：中位數 489 KB。
  - 小牛：約 216 KB。
- 40 頭牛都長得不一樣、只留側面：中位數 23 MB，全部最大也只有 35 MB。正面在轉身時才畫，轉回去就丟掉。
- 選項 1、2 同樣長相的牛共用一張圖，實際會更少。
- 兩個螢幕寬的牧場背景，整張轉成 3 倍點陣圖要 27.5 MB（2 倍 12.2 MB）。這跟選哪個選項無關，第 5 步做場景時再決定要不要分塊或降解析度。

**字型**
- 量法：`fonts.py`，結果在 `results/font-sizes.json`。
- 常用字子集：Big5 第一字面（符號＋5,401 個常用字）加上三份字串表用到的字，共 5,963 個字。字串表的 642 個漢字全部在 Big5 第一字面裡。

| 字型（版本） | 完整版 | 常用字子集 |
|---|---|---|
| Noto Sans TC 一般（2.004，OTF） | 5.42／4.67 MB | 1.59／1.38 MB |
| Noto Sans TC 粗（700） | 5.57／4.84 MB | 1.62／1.42 MB |
| Noto Sans TC 特粗（900） | 5.79／4.94 MB | 1.71／1.47 MB |
| 三個固定粗細合計 | 16.78／14.45 MB | 4.92／4.27 MB |
| Noto Sans TC 可變字型 OTF（CFF2，100–900） | 9.65／6.54 MB | 2.67／1.87 MB |
| Noto Sans TC 可變字型 TTF（Google Fonts 2.004-H2，100–900） | 11.39／7.24 MB | 3.16／2.08 MB |
| Noto Sans Thai 可變字型（2.002，粗細 100–900、寬度 62.5–100） | 0.21／0.13 MB | — |

（每格：安裝大小／壓縮後）

- 設計稿用到的粗細：900（97 處）、700（79 處）、一般內文 400。600 只有示意狀態列用到。

**可變字型在 Flutter 裡的粗細**
- 量法：`spike/test/font_test.dart`，同一行字用各種寫法畫，比墨水量和像素。結果在 `results/fonts-variable-weight.csv`、`results/fonts-static-vs-variable.png`。
- 結果：
  - 只設 `fontWeight: w900`、只設 `fontVariations: [FontVariation.weight(900)]`、兩個都設，三種畫出來的像素完全相同。
  - 跟固定的特粗字型比：字寬完全相同（文字的左右邊界一樣），墨水量 1.806 對 1.833，差 1.5%。像素差只在邊緣：TTF 和 OTF 的外框格式不同，抗鋸齒不一樣。
  - 粗（700）：墨水量 1.531 對 1.554。
  - 泰文 400、900 都正常，上下標記號的位置正確。
- 官方文件：
  - `FontVariation` 的 API 文件和字型 cookbook 都沒寫 fontWeight 會不會帶動可變字型。
  - cookbook 寫了 pubspec 的 weight：「You can't use the `weight` property to override the weight of the font.」
  - 所以 app 的主題兩個都設：同時設 fontWeight 和 FontVariation.weight。實測不會粗上加粗，iPhone 上也不必賭。

## 4. 三個選項的比較

| | 選項 1：每個品種一種長相 | 選項 2：會變的 9 種各 4 個變體（建議） | 選項 3：移植成 Dart |
|---|---|---|---|
| 玩家看到的 | 同一品種、同公母、同年紀的牛完全一樣（所有成年荷斯坦母牛的斑點都一樣） | 9 種有花紋的牛有 4 種花紋，依牛的編號挑；其他 15 種本來就一樣 | 每頭牛的花紋都不一樣，像設計稿 |
| app 多多大（安裝／下載） | 4.6／3.2 MB | 10.6／7.3 MB | 約 0（程式碼幾十 KB） |
| 跟核准圖 | 跟直接讀 SVG 相同（第 1 節） | 同左 | 一樣用 flutter_svg 畫；要靠移植一字不差，拿參考 SVG 逐字比對（第 1 節的數學比對支持做得到） |
| cow-ui 改牛時 | 一條指令重出全部（匯出幾秒、編譯 2 秒），cow-app 不用改 | 同左 | 不用重出圖，但 cow-app 要把產生器的改動移植成 Dart，用參考 SVG 驗證 |
| 現在的工作量 | cow-ui 寫匯出腳本（照 `export.mjs`）；app 載入約半天 | 同左 | 移植約 1,000–1,300 行（`r11.js`、`q.js`、`r1/cowgen.js` 用到的部分）加比對工具，估計 1–2 天；app 載入約半天 |
| 風險 | 同品種一模一樣，跟設計稿的示意不同 | 同品種最多 4 種花紋，40 頭裡難免重複 | 每次改牛都有兩份產生器要對齊；不對齊時測試會擋 |

- 三個選項的變體都用牛的編號挑（例：編號除以變體數的餘數），不用改協定。
- 圖鑑和品種卡用變體 0，也就是品種本身的 seed，跟核准的 24 種全圖（S09-05）一樣。
- 老牛用成牛的圖加「老牛」標籤（`kit.js` 第 148 行），所以不用另外畫。
- 選項 1、2 也可以只做朝左，朝右全部靠翻轉，可以再省 1.5–3.3 MB。代價是那 12 種牛的額頭亮光會換邊，跟核准的靜止畫面不同。不建議。

**不建議**
- 三個固定粗細的完整字型：加泰文 17.0 MB，超過 ceo 定的 15 MB。
- 可變字型的 OTF 版（CFF2）：比 TTF 小 1.7 MB，但這台只驗過 Linux，iPhone 對 CFF2 的支援沒驗過。TTF 用的是最普遍的外框格式。
- `.vec` 開著最佳化：星芒會畫細。
- 匯出 PNG：解析度固定，放大會糊。192 張 3 倍 PNG 就要 4.0 MB，比 `.vec` 大。

## 5. 對現有架構的影響

- pubspec（2026-10-02 更正：不用 asset transformer，見檔頭「結果」）：
  - 加 `flutter_svg`，素材照原樣宣告，執行時讀 SVG。
  - 原本的想法是用 transformer 編成 `.vec` 並關掉三個最佳化。官方文件：「You can configure your project to automatically transform assets at build time」。但 600 張在這台跑不動。
- 素材的來源：
  - cow-ui 從 `design/m2/` 匯出 SVG 和 `cows.json`（每張圖的框、臉、頭頂、影子）。
  - app 用小工具複製進 `app/assets/cows/`，用測試鎖住兩邊相同，跟字串表的做法一樣。
- 執行時：
  - 載入 `.vec` 後，依手機解析度畫成點陣圖存起來，交給 Flame 當 Sprite。
  - 往回走時左右翻轉（照 A-11）。轉身（A-07）時側面和正面兩張交替。
  - 剪影用 ColorFilter 把圖塗成一個顏色：圖鑑用深色，配種機率用淺灰加「？」。這個還沒畫過，第 4 步做 S09 時對照 S09-04 的圖確認。
  - 頭像（S13 的牧場卡）用正面荷斯坦的圖，照 `cows.json` 的臉座標裁切。不用另外匯出。
- 字型：
  - pubspec 宣告 Noto Sans TC 可變字型 TTF 和 Noto Sans Thai 可變字型。
  - 主題同時設 fontWeight 和 `FontVariation.weight`。
  - 授權：兩個字型都是 SIL Open Font License 1.1。條件 2 原文：「each copy contains the above copyright notice and this license」。用 `LicenseRegistry.addLicense` 放進 app 的第三方授權頁（ceo 2026-10-02 要求）。
  - Noto Sans TC 的保留名稱是「Source」。如果改用子集（子集算 Modified Version），檔名和字型名不能用「Source」；「Noto Sans TC」不受影響。
- 研究時確認過 asset transformer 在 `flutter test` 也會跑（`spike/test/transformer_test.dart`，只有 1 個檔）：`rootBundle` 讀到的是編好的 `.vec`（17,105 bytes；原始 SVG 45,774 bytes）。
  - 但 600 張在 1.5 GB 記憶體上限內跑不動（見檔頭「結果」），所以沒有採用。

## 6. 建議與分階段

1. **請 ceo 定**：
   - 牛的畫法：選項 1、2（建議，4 個變體）或 3。
   - 字型：可變字型的完整版（11.6 MB）算不算「完整版」。不算的話，改用常用字子集，罕用字由系統字型顯示。
2. **cow-ui 要匯出的東西**（選項 1、2；選項 3 只要第 2–4 項）：
   1. 牛：
      - 範圍：24 種 × 公母 × 小牛／成牛 × 側面／正面，全部朝左；第 1 節那 12 種加朝右。
      - 變體：會變的 9 種各 4 個（變體 0 是品種本身的 seed，其他三個用固定的 seed）。
      - 檔名：`<品種>_<公母>_<年紀>_<姿勢>_<朝向>_v<n>.svg`。
      - 留邊 4、從腳底量起的 viewBox：照 `docs/research/cow-render/export.mjs`。
      - 附 `cows.json`：每張的寬高、viewBox 原點、臉（cx、cy、r）、頭頂、影子（cx、rx、ry）。
      - 匯出腳本放在 `design/m2/harness/`。
      - 產生器改了高光的畫法，就用 `mirror.py`＋`compare.py` 重量哪些品種需要朝右。
   2. 場景背景：牧場（兩個螢幕寬）、田地、出貨卡車的路，都不含牛。
   3. 圖示：`icons.js` 的 54 個，每個一個 SVG。
   4. 動畫用的零件：出貨卡車的車身、車輪、擋板（A-03），星星亮光（`scene.js` 的 sparkle）。其他飛的東西用第 3 項的圖示。
3. **cow-app 接著做**：
   - 第 3a 步：字型和主題（字型等 ceo 定）。
   - 牛的圖到了以後，才做有牛的畫面和第 5 步的場景。
   - 驗收：每個畫面的截圖跟設計稿並排，牛的部分照第 1 節的量法再比一次。
4. **M4**：照第 2 節的四項驗收條件（fps、安裝大小、第一次載入的時間、記憶體），在 iPhone 上量。牛的圖在 Impeller（iPhone 的繪圖引擎）上，用同一套比對工具再跑一次。

## 附錄

### 量測工具與重現

腳本都在 `docs/research/cow-render/`，原始數據在 `results/`。中間檔（SVG、PNG）放 repo 外，下面用 `$S`。

```bash
S=<repo 外的暫存資料夾>
# 1. 匯出（K = 變體數；朝向預設 left,right）
node docs/research/cow-render/export.mjs $S/lr-k1 1
node docs/research/cow-render/export.mjs $S/lr-k4 4
node docs/research/cow-render/export.mjs $S/lr-k8 8
# 2. Chromium 標準圖（playwright-core 1.62.0 裝在 repo 外，對應 ~/.cache/ms-playwright 的 chromium 1234）
free -m   # available 要 2000 MB 以上
PLAYWRIGHT_CORE=<…/node_modules/playwright-core/index.mjs> systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 \
  node docs/research/cow-render/chromium_render.mjs $S/lr-k1/svg $S/chromium-lr-k1 3
# 3. Flutter 畫同一批（在 docs/research/cow-render/spike/ 下）
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 ~/development/flutter/bin/flutter --suppress-analytics \
  test test/render_test.dart --dart-define=SVG_DIR=$S/lr-k1/svg --dart-define=OUT_DIR=$S/flutter-lr-k1
# 4. 比對（--rsvg 加 librsvg 對照組；--mirror 只比朝右、受測用朝左翻轉的點陣圖）
python3 docs/research/cow-render/compare.py $S/chromium-lr-k1 $S/flutter-lr-k1 $S/cmp-lr-k1 --rsvg $S/lr-k1/svg
# 5. 朝右能不能翻轉：向量階段翻轉後用 Chromium 畫，跟原生朝右比
python3 docs/research/cow-render/mirror.py $S/lr-k1/svg $S/mirror-svg
node docs/research/cow-render/chromium_render.mjs $S/mirror-svg $S/chromium-mirror 3   # 同樣要 PLAYWRIGHT_CORE、systemd-run
mkdir -p $S/chromium-right && cp $S/chromium-lr-k1/*_right_*.png $S/chromium-right/
python3 docs/research/cow-render/compare.py $S/chromium-right $S/chromium-mirror $S/cmp-mirror-vector
# 6. 預先編譯（關掉最佳化）、大小、Flutter 畫 .vec
(cd docs/research/cow-render/spike && dart run vector_graphics_compiler --input-dir $S/lr-k1/svg --out-dir $S/vec-lr-k1 \
  -k 2 --no-optimize-masks --no-optimize-clips --no-optimize-overdraw)
python3 docs/research/cow-render/sizes.py $S/vec-lr-k1 $S/vec-lr-k4 $S/vec-lr-k8
# 7. 數學比對
node docs/research/cow-render/mathcheck.mjs $S/mathcheck.json 200000
(cd docs/research/cow-render/spike && dart run tool/mathcheck.dart $S/mathcheck.json)
# 8. 字型大小（會下載字型）、可變字型的粗細
python3 docs/research/cow-render/fonts.py $S/fonts
(cd docs/research/cow-render/spike && flutter test test/font_test.dart --dart-define=FONT_DIR=$S/fonts --dart-define=OUT_DIR=$S/font-out)
# 9. asset transformer 在 flutter test 會不會跑（spike/assets/test_cow.svg 是 export.mjs 匯出的荷斯坦）
(cd docs/research/cow-render/spike && flutter test test/transformer_test.dart)
```

### 版本

- Flutter 3.47.5（Dart 3.13），flutter_svg 2.3.0、vector_graphics 1.2.3、vector_graphics_compiler 1.3.0、vector_graphics_codec 1.1.13。spike 的 pubspec.lock 沒進 git，版本以這裡為準。
- Chromium：Playwright 1.62.0 的 headless shell（chromium 1234），跟 cow-ui 出設計稿的同一版。
- librsvg：系統的 gi Rsvg 2.0。node 23.11.0。fontTools 4.44.0。
- 字型：
  - Noto Sans TC 2.004（notofonts/noto-cjk 的 SubsetOTF／Variable）。
  - Noto Sans TC 2.004-H2（google/fonts 的可變 TTF）。
  - Noto Sans Thai 2.002（google/fonts）。

### 限制

- Flutter 這邊是 `flutter test` 的 Skia CPU 繪圖。iPhone 用 Impeller，線條邊緣的抗鋸齒可能不同。M4 在實機用同一套比對再量一次。
- 記憶體是算的（寬 × 高 × 4），不是在手機上量的。
- 可變字型的粗細只在 Linux 的 flutter test 驗過，iPhone 沒驗。所以主題兩個都設，實測不會粗上加粗。
- 可變字型 OTF（CFF2）在 iPhone 沒驗，所以選 TTF。
- 移植的工作量是估的。數學比對證明數字轉字串做得到一樣，但沒有真的移植。
- 剪影用 ColorFilter 還沒實際畫過。
- 載入時間是筆電 CPU 的數字，只能拿來比較選項，不能換算成 iPhone 的 fps。

### 來源

- flutter_svg 2.3.0 README（https://pub.dev/packages/flutter_svg）：
  - 「The vector_graphics backend supports SVG compilation which produces a binary format that is faster to parse and can optimize SVGs to reduce the amount of clipping, masking, and overdraw.」
  - 「By default, the rendering uses the original picture mode, which retains full flexibility in scaling.」
- Flutter 文件「Transforming assets at build time」（https://docs.flutter.dev/ui/assets/asset-transformation）：
  - 「You can configure your project to automatically transform assets at build time using compatible Dart packages.」
  - 範例 `transformers: - package: vector_graphics_compiler`，並可加 `args`。
- Flutter 文件「Use a custom font」（https://docs.flutter.dev/cookbook/design/fonts）：
  - 「The `weight` property specifies the weight of the outlines in the file as an integer multiple of 100, between 100 and 900.」
  - 「You can't use the `weight` property to override the weight of the font.」
- `FontVariation` API（https://api.flutter.dev/flutter/dart-ui/FontVariation-class.html）：
  - 「Some fonts are variable fonts that can generate a range of different font faces by altering the values of the font's design axes.」
  - 沒寫 fontWeight 會不會帶動 wght，所以實測。
- SIL Open Font License 1.1（字型附的 OFL.txt）：條件 2「Original or Modified Versions of the Font Software may be bundled, redistributed and/or sold with any software, provided that each copy contains the above copyright notice and this license.」
- 字型檔：
  - https://github.com/notofonts/noto-cjk （Sans/SubsetOTF/TC、Sans/Variable/OTF/Subset）
  - https://github.com/google/fonts （ofl/notosanstc、ofl/notosansthai）
