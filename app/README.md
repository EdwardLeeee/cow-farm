# 牛市牧場 app（M1 連線原型，v0.2 玩法）

- Flutter 3.47.5，專案名 `cowfarm`，bundle id／applicationId `com.oraclelee.cowfarm`，桌面名稱「牛市牧場」。
- 只支援直式；iOS 只支援 iPhone。
- **畫面只用色塊和文字，不是正式畫面。** 正式畫面要等 cow-ui 的完整設計稿核准才做。
- 規格：`docs/design/m1-prototype.md`、企劃書 `docs/design/gdd.md` 4.0（v0.2）與第 8 節 S17–S20；
  協定：`docs/protocol.md`（伺服器端負責，不一致時以 protocol.md 為準）。

## 畫面（底部 6 個分頁）

| 分頁 | 內容 |
|---|---|
| 牧場 | 奶桶（平滑推算）與收奶、倉庫（牛奶、牛肉、稻米）、每頭牛一張卡：用途色塊（乳牛／耕牛／肉牛）、公母、稀有度、階段；只有母乳牛顯示產奶，田裡的耕牛顯示產稻米；標示「已配種」「工作中」「上架中」 |
| 牛的詳細資料 | 點牛卡進入。出貨（S20）：先抓 `/v1/ship/preview` 顯示 A／B／C 各級機率與收入，確定後揭曉評級與收入；選這頭去配種；耕牛下田／叫回；公牛上架借種（四個價位）／下架。工作中或上架中的牛不能出貨、配種 |
| 市場 | 牛奶、牛肉、稻米三個分頁：現價與 24 小時漲跌（漲紅跌綠）、走勢圖（1 小時／1 天／7 天）、新聞、賣出面板（防抖動試算、單量大提示） |
| 田地（S17） | 田地清單、每塊田的稻米進度（平滑推算，長滿就停）、派耕牛（只列能下田的成年耕牛）、叫回、全部收成、開新田（錢不夠停用） |
| 配種 | 「自己配種」：自己的公母免費，每頭一輩子一次，已配種／工作中／上架中的牛會標示且不能選；顯示稀有度、用途、公母機率。「借種」（S18）：上架自己的公牛（四個價位）、下架、借種收入；瀏覽別人的公牛（用途、稀有度、價格、主人），選自己的母牛先看機率與費用再借 |
| 商店（S19） | A／B／C 三個等級，各自顯示價格與用途、公母、稀有度機率（來自 `GET /v1/shop`，不寫死）；買了之後顯示抽到的牛；另有擴建、奶桶、倉庫、冷藏升級 |
| 紀錄 | 圖鑑（12 格，沒發現的顯示「？」）、排行榜（三個分頁） |

頂列：牧場名、等級、金幣、遊戲時間與倍率；斷線時顯示「連線中…」。有人借了你上架的公牛時（WebSocket `stud`），跳出一則提示並重抓 state。

## 結構

| 路徑 | 內容 |
|---|---|
| `lib/l10n/strings.dart` | M1 畫面的文字（繁體中文）；畫面照 M2 設計稿重做時改用下面的 `Strings`，全部換完就刪掉 |
| `lib/l10n/l10n.dart` | 語言（`AppLang`：繁中、英文、泰文）與給畫面用的字串 `Strings.of(context)`（D25） |
| `lib/l10n/gen/strings.g.dart` | 由 `tool/gen_l10n.dart` 從 `design/m2/i18n/*.json` 產生，不要手改 |
| `lib/l10n/format.dart` | 數字的寫法（千分位、萬／億、K／M、百分比），照設計稿 |
| `lib/state/settings.dart` | 語言、漲跌顏色這些偏好設定（shared_preferences；token 不放這裡） |
| `lib/api/models.dart` | 協定 v2 的資料格式；欄位名稱只出現在這裡 |
| `lib/api/breeds.dart` | 24 個品種：用途 × 特徵組合 → 品種代號、圖鑑順序（協定 1.6；測試讀 `breeds.js` 比對） |
| `lib/api/game_api.dart` | 資料層介面（測試換成假資料） |
| `lib/api/http_game_api.dart` | HTTP 實作：Bearer token、request_id、重送 |
| `lib/api/push.dart` | WebSocket 推播與斷線重連（指數退避加隨機等待 full jitter：第 n 次等 random(0, min(5, 0.5×2^n)) 秒） |
| `lib/storage/` | token 存放：手機用 `flutter_secure_storage`，網頁版用瀏覽器 localStorage |
| `lib/state/game_model.dart` | 狀態（ChangeNotifier＋provider），奶桶與遊戲時間的平滑推算 |
| `lib/util/ranch_name.dart` | 牧場名的規則（D23；協定 2.2 節）：去掉前後空白、emoji 和不能用的字、顯示寬度 2–16，跟伺服器一樣 |
| `lib/util/name_tables.g.dart` | 由 `tool/gen_name_tables.py` 用伺服器的 `backend/server/ranchname.py` 逐字產生（要 Python 3.10，Unicode 13.0），不要手改 |
| `lib/ui/` | 頂列、各分頁畫面（`screens/`）、共用元件（`widgets/`） |
| `lib/theme/` | 設計參數（顏色、尺寸、圓角、實心下陰影、文字樣式），照 M2 設計稿的 `base.css`、`kit.css`；`app_theme.dart` 是頁面底色、字型和字型授權 |
| `assets/cows/`、`assets/ui/` | 牛、圖示、場景、卡車零件的 SVG 和描述檔（`cows.json`、`ui.json`），由 cow-ui 的 `design/m2/harness/assetexport.mjs` 產生，不要手改；執行時讀 SVG（T3）。`test/cow_assets_test.dart` 檢查檔案、雜湊和產生器有沒有漂移 |
| `assets/fonts/` | 內建字型（T3）：Noto Sans TC 可變字型完整版（google/fonts 2.004-H2）、Noto Sans Thai 可變字型（2.002）、兩份 OFL 授權 |
| `test/` | widget test 與單元測試，全部用 `test/fakes.dart` 的假資料層 |

## 規則怎麼落實

- **所有帳都由伺服器算**：app 不送任何時間、產量或結果。奶桶和遊戲時間只在畫面上推算：
  `遊戲時間 = server_time + 手機單調時鐘經過的秒數 × time_scale`，
  `奶桶 = min(容量, 量 + 每小時產量 × 經過的遊戲小時)`。
  單調時鐘不受改手機時間影響。每次操作後和每 5 秒重新拿 `/v1/state` 校正。
- **request_id**：會改變狀態的請求（收奶、賣出、出貨、商店抽牛、配種、升級、田地四個動作、借種上架／下架／借用）
  每次產生新的 UUID；
  沒收到回應（連線失敗、逾時、502／504、沒有錯誤本文的 503）時用同一個 request_id 重送，最多 3 次。
  收到 4xx、500 或 503 maintenance 不重送。
- **錯誤**（協定 1.4）：依錯誤碼顯示字串表的文案（`Strings.errorText`），**不顯示**伺服器的 message。
  不認得的碼顯示「操作失敗，請再試一次」；網路失敗顯示「網路不穩，請稍後再試」。
  「現在不能做」的原因（blockers）也是代碼。
- **斷線**（S15）：WebSocket 斷線、或最近一次 HTTP 失敗時，頂列顯示「連線中…」，所有操作按鈕和賣出滑桿停用。
  底部分頁仍可切換查看（切換分頁不改變任何狀態）。超過 6 秒沒收到推播也當作斷線重連。
  重連後先補抓 `/v1/state` 與 `/v1/market`，兩個都成功才提示「已重新連線，資料更新了」（S15-02；第一次連上不提示）。
  連續 60 秒以上連不上，上方提示「連不上伺服器，已經超過 {n} 分鐘」（S15-04），可以按「重試」。
  斷線時間用單調時鐘算。
- **維護**（S16-01，協定第 6 節）：開機先打 `GET /v1/status`（不用 token，還沒有牧場也先看）。
  `maintenance.active` 是 true、API 回 `503 maintenance`、或 WebSocket 送來 active 的 `maintenance` 時，
  整個畫面換成維護中，關掉 WebSocket（不重連），每 30 秒打一次 `/v1/status`；`active` 不是 true 就重新載入。
  維護前（`active: false`）照常玩，v1 不提示。維護中、token 失效時操作失敗不另外跳錯誤提示（整個畫面會換掉）。
- **行情顏色**：漲紅跌綠（`lib/ui/palette.dart`）。
- **賣出面板**：拉滑桿停 300 ms 後才呼叫 `/v1/sell/quote`；伺服器回 `warn_big_order: true`
  （滑價 ≥ 5%）就提示「一次賣太多，均價會變差」。滑桿拉到最右邊 = 全部，送倉庫的 `milk_total`／`beef_total`／`rice_total`
  原值（含小數）。
- **能不能做**：牛能不能配種、出貨、下田，以伺服器的 `can_breed`／`can_ship`／`can_work` 為準；按下去前的機率
  （商店、出貨評級、配種、借種）一律向伺服器拿，不在 app 寫死。
- **建立牧場**（協定 2.1，D23）：取好名字才建立。手機上沒有 token 時，停在「還沒有牧場」（S02 取名），
  不自動取名、不自動建立。
- **token 失效**（HTTP 401，或 WebSocket 用關閉碼 4401 關閉）：不再重連，也不默默開新牧場。
  依錯誤碼停在 S15-03（unauthorized）或 S14-05（signed_in_elsewhere），玩家選「開新牧場」才清掉 token。
- **伺服器不送給玩家看的中文**（v2）：品種、用途、新聞、電腦牧場名都用代碼查字串表。
  電腦牧場名用詞庫編號照玩家的語言組，前面加「電腦」，#編號是 player_id 補零到 4 位。
- **借種費**（D26）：由系統依體重和稀有度算，上架不帶價格；借種帶預覽看到的價格，變了伺服器回 price_changed。

## 語言與字串（D25）

- 字串只有一份：`design/m2/i18n/` 的 `zh-Hant.json`、`en.json`、`th.json`（cow-ui 出繁中、ceo 出英文和泰文）。
  app 用 `tool/gen_l10n.dart` 產生成 Dart：每個 key 一個成員，佔位符是具名參數，打錯 key 或參數就編譯不過。
  例：`s02.suggest` → `Strings.of(context).s02Suggest`，`level`（`Lv {lv}`）→ `level(lv: 3)`。
- 品種名、取名詞庫這類依資料組的 key 用 `breedName(breed)`、`ranchNameFromWords([a, b, c])` 等方法。
- 字串表改了以後在 `app/` 跑 `dart run tool/gen_l10n.dart`。`test/l10n_test.dart` 會檢查：
  - 三種語言的 key 和佔位符一樣；
  - 產生的檔跟字串表同步；
  - 前後刻意留的空白有保留；
  - 依資料組的 key 每一組都齊。
- 數字和時間的寫法照設計稿的程式（`design/m2/src/js/fixtures.js`、`i18n.js`）：
  - `node tool/gen_format_cases.mjs` 用設計稿的函式產生 `test/fixtures/format_cases.json`；
  - `test/format_test.dart` 逐筆比。
- 語言：
  - 還沒在設定選過時，每次打開都跟著手機的第一個偏好語言：中文 → 繁中、泰文 → 泰文、其他 → 英文。
  - 選過以後固定用玩家選的（ceo 2026-10-02）。
- 漲跌顏色：繁中漲紅跌綠，英文、泰文綠漲紅跌；設定裡選過就固定。

## 指令

這台電腦記憶體有限：`flutter test`、`flutter build web`、headless Chromium 之前先看 `free -m`，
available 少於 2000 MB 就等；指令用 `systemd-run` 限制記憶體，一次只跑一個。

```bash
cd app
F=~/development/flutter/bin/flutter
LIMIT="systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0"

$LIMIT $F --suppress-analytics pub get
$LIMIT $F --suppress-analytics analyze
$LIMIT $F --suppress-analytics test --concurrency=1
$LIMIT $F --suppress-analytics build web --release --no-wasm-dry-run   # 輸出在 app/build/web
```

- 這台請一定加 `--no-wasm-dry-run`（原因見 `docs/research/tech-stack/flutter-findings.md`）。
- 伺服器網址用 `--dart-define=API_BASE=http://<IP>:8787`。沒給的話：
  - 網頁版用目前網頁的同一個網域（網頁由伺服器在 `/` 提供），所以一般不用給。
  - 手機 app 用 `http://127.0.0.1:8787`，實機一定要給開發機的區網 IP。

## 跟伺服器一起試玩

1. 照 `backend/README.md` 啟動伺服器，倍率 144（遊戲 1 天 = 現實 10 分鐘）：`COWFARM_TIME_SCALE=144`。
2. 建好網頁版（上面的 `build web`）。伺服器在 `/` 提供 `app/build/web`。
3. 開發機瀏覽器開 `http://127.0.0.1:8787/`；iPhone 在家裡 Wi-Fi 用 Safari 開 `http://<開發機區網 IP>:8787/`。
   - 手機要能連外網：CanvasKit 與中文字型從 Google 的 CDN 下載。
   - 第一次打開會自動建立訪客帳號，token 存在這個瀏覽器；清掉網站資料就會變成新牧場。
4. 試玩流程：收奶 → 市場賣奶 → 擴建 → 商店買 C 級 → 田地派耕牛 → 收成 → 賣稻米 → 上架公牛 → 借別人的公牛配種 → 出貨看評級 → 排行榜。

## 整合走查

- 腳本：`tool/walk.cjs`（Playwright，打開 Flutter 的無障礙樹後照按鈕與分頁名稱操作；用法寫在檔頭）。
  v0.2 流程：收奶 → 賣奶 → 擴建 → 商店買 C 級 → 派耕牛下田 → 收成 → 賣稻米 → 上架公牛 → 借別人公牛配種 →
  出貨看評級 → 排行榜，每步截圖並寫 `walk.log`（最後列出 ISSUES）。
- 在真的伺服器上跑（同源 `/`，伺服器設 `COWFARM_WEB_DIR=app/build/web`）：

  ```bash
  free -m   # available ≥ 2000 MB 再跑
  PLAYWRIGHT_MODULE=~/Desktop/connect4-web2-worktrees/mobile/frontend/node_modules/playwright \
    systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 \
    node app/tool/walk.cjs http://127.0.0.1:8787/ app/test_shots/v02
  ```

- 截圖放 `app/test_shots/`（只供整合用，要不要進 repo 由 ceo 決定）。M1 的兩輪（v0.1）在
  `cross-origin-run1/`、`cross-origin-run2-disconnect/`（第 2 輪途中伺服器被測試關掉：頂列顯示「連線中…」、
  按鈕全部停用，伺服器回來後自動重連）。

## 手機實機（之後）

- 真機 app 連區網 http 需要例外設定，照 T1 只在開發版加：
  - iOS：`NSAppTransportSecurity` → `NSAllowsLocalNetworking`（還沒加）。
  - Android：debug 版的 `usesCleartextTraffic`（還沒加）。
- 建置與上架照 T2 與 D8，TestFlight 延後。
