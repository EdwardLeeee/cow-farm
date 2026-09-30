# 牛市牧場 app（M1 連線原型）

- Flutter 3.47.5，專案名 `cowfarm`，bundle id／applicationId `com.oraclelee.cowfarm`，桌面名稱「牛市牧場」。
- 只支援直式；iOS 只支援 iPhone。
- **畫面只用色塊和文字，不是正式畫面。** 正式畫面要等 cow-ui 的完整設計稿核准才做。
- 規格：`docs/design/m1-prototype.md`；協定：`docs/protocol.md`（伺服器端負責，兩者不一致時以 protocol.md 為準）。

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
| `lib/ui/` | 頂列、牧場、市場、牛的詳細資料、配種、商店／升級、圖鑑、排行榜 |
| `test/` | widget test 與單元測試，全部用 `test/fakes.dart` 的假資料層 |

## 規則怎麼落實

- **所有帳都由伺服器算**：app 不送任何時間、產量或結果。奶桶和遊戲時間只在畫面上推算：
  `遊戲時間 = server_time + 手機單調時鐘經過的秒數 × time_scale`，
  `奶桶 = min(容量, 量 + 每小時產量 × 經過的遊戲小時)`。
  單調時鐘不受改手機時間影響。每次操作後和每 5 秒重新拿 `/v1/state` 校正。
- **request_id**：會改變狀態的請求（收奶、賣出、出貨、買小牛、配種、升級）每次產生新的 UUID；
  沒收到回應（連線失敗、逾時、502/503/504）時用同一個 request_id 重送，最多 3 次。收到 4xx 不重送，
  直接顯示伺服器給的繁中錯誤訊息。
- **斷線**：WebSocket 斷線、或最近一次 HTTP 失敗時，頂列顯示「連線中…」，所有操作按鈕和賣出滑桿停用。
  底部分頁仍可切換查看（切換分頁不改變任何狀態）。超過 6 秒沒收到推播也當作斷線重連。
  重連後先補抓 `/v1/state` 與 `/v1/market`。
- **行情顏色**：漲紅跌綠（`lib/ui/palette.dart`）。
- **賣出面板**：拉滑桿停 300 ms 後才呼叫 `/v1/sell/quote`；伺服器回 `warn_big_order: true`
  （滑價 ≥ 5%）就提示「一次賣太多，均價會變差」。滑桿拉到最右邊 = 全部，送倉庫的 `milk_total`／`beef_total` 原值（含小數）。
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
4. 試玩流程：收奶 → 市場賣奶 → 商店買小牛 → 配種 → 牛的詳細資料出貨 → 排行榜。

## 整合走查（2026-09-30）

- 腳本：`tool/walk.cjs`（Playwright，打開 Flutter 的無障礙樹後照按鈕名稱操作；用法寫在檔頭）。
  流程：收奶 → 賣奶 →（牛舍滿就擴建）→ 買小牛 → 配種 → 出貨 → 排行榜。
- 截圖在 `app/test_shots/`（只供這次整合用，要不要進 repo 由 ceo 決定）：
  - `cross-origin-run1/`：網頁版開在 8790、跨來源連伺服器 8787。收奶、賣奶、擴建、買小牛、出貨、排行榜都走通
    （01–09 的截圖被第 2 輪覆蓋，紀錄在 `walk-run1.log`）。
  - `cross-origin-run2-disconnect/`：走到一半伺服器被測試關掉。頂列顯示「連線中…」、按鈕全部停用，
    伺服器回來後自動重連並繼續賣出。
- 還沒在真的伺服器上走過：配種、同源 `/`（`COWFARM_WEB_DIR`）。

## 手機實機（之後）

- 真機 app 連區網 http 需要例外設定，照 T1 只在開發版加：
  - iOS：`NSAppTransportSecurity` → `NSAllowsLocalNetworking`（還沒加）。
  - Android：debug 版的 `usesCleartextTraffic`（還沒加）。
- 建置與上架照 T2 與 D8，TestFlight 延後。
