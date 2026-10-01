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
| `lib/l10n/strings.dart` | 所有給玩家看的文字（繁體中文），加語言時換這個檔 |
| `lib/api/models.dart` | 協定 v1 的資料格式；欄位名稱只出現在這裡 |
| `lib/api/game_api.dart` | 資料層介面（測試換成假資料） |
| `lib/api/http_game_api.dart` | HTTP 實作：Bearer token、request_id、重送 |
| `lib/api/push.dart` | WebSocket 推播與斷線重連（指數退避加隨機等待 full jitter：第 n 次等 random(0, min(5, 0.5×2^n)) 秒） |
| `lib/storage/` | token 存放：手機用 `flutter_secure_storage`，網頁版用瀏覽器 localStorage |
| `lib/state/game_model.dart` | 狀態（ChangeNotifier＋provider），奶桶與遊戲時間的平滑推算 |
| `lib/ui/` | 頂列、各分頁畫面（`screens/`）、共用元件（`widgets/`） |
| `lib/theme/` | 設計參數（顏色、尺寸、圓角、實心下陰影、文字樣式），照 M2 設計稿的 `base.css`、`kit.css`；`app_theme.dart` 是頁面底色、字型和字型授權 |
| `assets/fonts/` | 內建字型（T3）：Noto Sans TC 可變字型完整版（google/fonts 2.004-H2）、Noto Sans Thai 可變字型（2.002）、兩份 OFL 授權 |
| `test/` | widget test 與單元測試，全部用 `test/fakes.dart` 的假資料層 |

## 規則怎麼落實

- **所有帳都由伺服器算**：app 不送任何時間、產量或結果。奶桶和遊戲時間只在畫面上推算：
  `遊戲時間 = server_time + 手機單調時鐘經過的秒數 × time_scale`，
  `奶桶 = min(容量, 量 + 每小時產量 × 經過的遊戲小時)`。
  單調時鐘不受改手機時間影響。每次操作後和每 5 秒重新拿 `/v1/state` 校正。
- **request_id**：會改變狀態的請求（收奶、賣出、出貨、商店抽牛、配種、升級、田地四個動作、借種上架／下架／借用）
  每次產生新的 UUID；
  沒收到回應（連線失敗、逾時、502/503/504）時用同一個 request_id 重送，最多 3 次。收到 4xx 不重送，
  直接顯示伺服器給的繁中錯誤訊息。
- **斷線**：WebSocket 斷線、或最近一次 HTTP 失敗時，頂列顯示「連線中…」，所有操作按鈕和賣出滑桿停用。
  底部分頁仍可切換查看（切換分頁不改變任何狀態）。超過 6 秒沒收到推播也當作斷線重連。
  重連後先補抓 `/v1/state` 與 `/v1/market`。
- **行情顏色**：漲紅跌綠（`lib/ui/palette.dart`）。
- **賣出面板**：拉滑桿停 300 ms 後才呼叫 `/v1/sell/quote`；伺服器回 `warn_big_order: true`
  （滑價 ≥ 5%）就提示「一次賣太多，均價會變差」。滑桿拉到最右邊 = 全部，送倉庫的 `milk_total`／`beef_total`／`rice_total`
  原值（含小數）。
- **能不能做**：牛能不能配種、出貨、下田，以伺服器的 `can_breed`／`can_ship`／`can_work` 為準；按下去前的機率
  （商店、出貨評級、配種、借種）一律向伺服器拿，不在 app 寫死。
- **`POST /v1/buy_calf` 已停用**（410），app 只用 `POST /v1/shop/buy`。
- **token 失效**（HTTP 401，或 WebSocket 用關閉碼 4401 關閉，例如資料庫重建）：不再重連，丟掉舊 token，
  重新建立訪客帳號（兩邊同時發生也只建立一次）。

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
