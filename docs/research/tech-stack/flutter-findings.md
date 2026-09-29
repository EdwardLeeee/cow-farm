# Flutter＋Flame 在 iPhone 14 Pro Max 夠不夠順：測試 app 與 TestFlight 流程準備報告

- 日期：2026-09-30
- 負責：ceo 派出的研究 session（只做用完即丟的測試 app 與 CI，沒有動產品程式）
- 問題：使用者已同意 app 用 Flutter、牧場畫面用 Flame、其他畫面用 Flutter 元件。要一個測試 app 裝到
  iPhone 14 Pro Max（有 Android 手機也裝）量流暢度，同時把打包、上傳 TestFlight 的流程完整跑一次。
- 範圍：`docs/research/tech-stack/flutter-spike/`（Flutter 專案）、`.github/workflows/spike-*.yml`、本文件，
  以及網頁版截圖 `docs/research/tech-stack/flutter-spike-shots/`（brief 第 3 步要求，ceo 可以不收）。

## 先說結論

1. **測試 app 與兩條 CI 都準備好了，本機驗證全過**：`flutter analyze` 0 個問題、11 個測試全過、網頁版
   32 秒建好。iPhone 的真正數字要等三件事：使用者在 Apple 網站做完第 7 節的 3 步、ceo 推上 GitHub 並設好
   secrets、執行一次 Spike iOS。使用者在 TestFlight 裝好後打開放著約 87 秒，截圖結果表即可。
2. **120 Hz 需要 Info.plist 的 `CADisableMinimumFrameDurationOnPhone = true`**。Apple 文件與 Flutter 引擎原始碼
   都這樣寫。Flutter 範本已經內建這個設定，CI 也會檢查 IPA 裡真的有。測試前使用者要關掉「低電量模式」和
   「限制影格速率」，這兩個都會把畫面鎖在 60 Hz。
3. **簽章建議沿用 connect4 的做法**：沿用團隊層級的發布憑證與 App Store Connect API key，只新做一個描述檔
   （在網頁上約 5 分鐘）。自動簽章要改用權限更大的 Admin 等級 API key，而且 `flutter build ipa` 不能把 API key
   傳給 Xcode，所以這次不採用，理由見第 6 節。
4. **上傳用 `xcodebuild -exportArchive`**（destination upload，搭配 API key）。這和 connect4 是同一套，已經在這個
   Apple 帳號成功上傳過，不改用 `altool`。
5. **研究中發現兩個會卡住上傳的坑，都已避開**：
   - `device_info_plus` 13.2.0 在 iOS 讀取磁碟空間（`NSFileSystemFreeSize`，Apple 規定要宣告理由的 API），
     它的隱私清單卻沒有宣告。Apple 寫明這種 app「aren't accepted by App Store Connect」。所以這個外掛不用，
     機型改用 `dart:ffi` 直接呼叫系統函式讀。
   - `flutter build ipa` 匯出 IPA 失敗時仍然回報成功（Flutter 3.47.5 原始碼 `build_ios.dart` 的註解寫
     「Still count this as success」）。所以 CI 另外檢查 IPA 是否存在，並核對 IPA 的內容。
6. **使用者要做的事**依序是：(a) 註冊 App ID → (b) 建立描述檔 → (c) 在 App Store Connect 建立 app → 把
   描述檔交給 ceo。(d) secrets 只有描述檔要新做，其他 6 個沿用 connect4 的值。(e) Android 不用做任何事。
   逐步畫面說明在第 8 節。

## 名詞

- **FPS**：每秒實際畫出幾張畫面。iPhone 14 Pro Max 最高 120。
- **畫面時間**：一張畫面花多久做完，本文取 max(build, raster)。
  - build：UI 執行緒算出畫面內容的時間。
  - raster：繪圖執行緒把畫面送給 GPU 的時間。
  - 120 Hz 時每張的時間上限是 8.3 ms，60 Hz 是 16.7 ms，超過就會掉格。
- **p99**：把畫面時間由快到慢排好，第 99% 那張的時間，代表「最慢的那 1%」。
- **ProMotion**：iPhone 13 Pro 之後的 Pro 機種，螢幕可以在 10–120 Hz 之間自動切換。
- **TestFlight**：Apple 的測試版發佈工具。上傳到 App Store Connect 的建置處理完之後，受邀的人可以用
  TestFlight app 安裝，不用送審。
- **App ID／bundle ID**：app 在 Apple 的身分證字號，這裡是 `com.oraclelee.cowfarm`，上傳後永遠不能改。
- **描述檔（provisioning profile）**：把 App ID 和發布憑證綁在一起的檔案。每個 App ID 要一個。
- **API key**：App Store Connect 發的金鑰（`.p8`），讓 GitHub 不用輸入 Apple ID 密碼就能上傳。
- **secrets**：存在 GitHub 的加密設定值。寫入後讀不回來，只有 workflow 執行時用得到。
- **workflow_dispatch**：GitHub Actions 的「手動執行」觸發方式。
- **fork PR**：別人把 repo 複製到自己帳號修改後送來的 pull request。
- **側載**：不透過商店，直接把 APK 檔裝到 Android 手機。

## 1. Flutter SDK

| 項目 | 值 |
|---|---|
| 版本 | Flutter 3.47.5（stable，2026-09-18 發布），framework `6a19cca564`，engine `af7e796e16`，Dart 3.13.4，DevTools 2.60.0 |
| 路徑 | `~/development/flutter`（約 2.4 GB），執行檔 `~/development/flutter/bin/flutter` |
| 安裝方式 | 官方 Linux tarball `flutter_linux_3.47.5-stable.tar.xz`（1.5 GB）。SHA-256 `2132e990…652cbb` 與官方清單 `releases_linux.json` 相符。 |
| 沒改的東西 | `~/.bashrc`、PATH、系統設定都沒動，所以指令一律寫完整路徑 |
| 附帶寫入 | 工具自己的快取：`~/.pub-cache`、`~/.config/flutter`、`~/.dart-tool` |

`flutter doctor` 的結果：

- `[!] Flutter`：flutter、dart 不在 PATH 上。這是預期的，因為沒有改 PATH。
- `[✗] Android toolchain`：找不到 Android SDK。預期中，由 CI 建置。
- `[✓] Chrome`：google-chrome 151。
- `[✗] Linux toolchain`：缺 clang++、CMake、ninja、pkg-config。用不到。
- `[✓] Connected device`、`[✓] Network resources`。
- Linux 上不會出現 Xcode 那一項，iOS 一律在 GitHub 的 Mac 上建置。
- 預設開啟的功能旗標包括 `enable-swift-package-manager`（iOS 外掛改走 Swift Package Manager，不再需要 CocoaPods）
  與 `enable-uiscene-migration`。

**使用數據回報**：第一次執行時 Flutter 顯示了使用數據（telemetry）說明。這次每個指令都加了
`--suppress-analytics`，只在該次執行不回報，沒有改全域設定。要不要永久關閉由使用者決定，關閉指令是
`~/development/flutter/bin/flutter --disable-analytics`。

## 2. 測試 app 的設計

專案 `cowfarm_spike`，bundle ID／applicationId `com.oraclelee.cowfarm`，桌面名稱「牧場測試」，版本 `0.0.1+1`
（CI 把建置號換成 GitHub run number），只支援直式，iOS 只支援 iPhone。

**畫面**

- 背景是 Flame 畫的草地。草地只在畫面大小改變時畫一次，存成圖片，之後每張畫面只貼圖。
- 牛全部用程式畫，沒有圖檔：白色圓角身體、3 塊黑色或咖啡色斑點、頭、耳朵、粉紅鼻子、眼睛、4 條會擺動的腿、
  尾巴、影子，每頭約 16 個繪圖指令。牛會左右走，碰到邊緣就回頭，走路時上下晃。
- 上方疊一張 Flutter `CustomPainter` 折線圖「牛奶收購價（測試用假資料）」，每 100 ms 加一個隨機漫步的價格點
  （每秒更新 10 次），並重畫標題與價格文字。
- 截圖：`docs/research/tech-stack/flutter-spike-shots/web-running-n30.png`、`web-running-n200.png`、`web-results.png`。

**自動測試流程**：打開就開始，全程約 87 秒。

1. 熱身 5 秒（30 頭，不列入統計）。
2. N = 30、60、100、200 依序各跑 20 秒。
3. 最後多跑 2 秒，等最後一批畫面時間送到，然後顯示結果表。

**量法**

- 每張畫面的時間來自 `SchedulerBinding.addTimingsCallback`，引擎回報的 `FrameTiming`。release 版大約每秒
  才回報一批（文件：「approximately once a second」），所以不能用「收到的時間」分段。
- 改用每張畫面自己的 `buildStart` 時間戳對照各段的起訖。起訖點取自
  `SchedulerBinding.currentSystemFrameTimeStamp`，兩者是同一個時鐘。依據是 `FrameTiming.buildDuration` 的
  文件：onBeginFrame 收到的 Duration「is exactly」`buildStart`。
- 每段開頭 1 秒不計，因為切換牛數時會一次新增很多元件，那一下不是穩定狀態。
- 門檻用 Flutter 文件原文：「To ensure smooth animations of X fps, this should not exceed 1000/X milliseconds.
  That's about 16ms for 60fps, and 8ms for 120fps.」所以 120 Hz 的門檻是 8.33 ms，60 Hz 是 16.67 ms。
- 百分位數用相鄰兩點線性內插（與 numpy 預設相同）。某段沒有資料時顯示「—」，不會當掉。
- 記憶體用 `ProcessInfo.currentRss`，每秒量一次，每段取最大值。iOS 上它是常駐記憶體，不等於系統判斷要不要
  關掉 app 的 phys_footprint，只能看趨勢。網頁版讀不到，顯示「—」。

**結果表**（見 `web-results.png`）

- 表格欄是牛的數量，列依序是：
  - 實際 FPS
  - 畫面時間中位數、畫面時間 p99
  - 超過 8.3 ms 的比例、超過 16.7 ms 的比例
  - build p99、raster p99
  - 延遲 p99（vsync 到畫完）
  - 記憶體峰值、畫面數
- 表格上方寫機型、系統版本、螢幕像素與倍率、螢幕上限更新率、app 版本與建置號、release／profile、繪圖引擎
  （Impeller 或 Skia）、Flutter／Dart／Flame 版本、完成時間。
- 表格寬度照 iPhone 14 Pro Max（430 pt）設計。widget test 確認整頁在 430×932 內不用捲動；較窄的手機會等比縮小。
- **「複製結果」按鈕**：把完整 JSON 複製起來，使用者可以直接貼到對話裡。結果也會印到 console（`COWFARM_SPIKE_…`），
  但 iPhone 的 console 要接 Mac 才看得到，使用者沒有 Mac，所以實際上靠截圖和這個按鈕。
- 測試途中 app 如果離開畫面（鎖定、切到背景），結果表上方會顯示警告，請使用者按「再跑一次」。
  短暫的 inactive 不警告：iOS 冷啟動、拉下通知時都會出現，畫面照常更新。它只記在 JSON 的 `inactive_events`。

**其他設定**

- iOS 在 `AppDelegate` 設 `isIdleTimerDisabled`，Android 在 `MainActivity` 設 `FLAG_KEEP_SCREEN_ON`，測試途中
  螢幕不會自動變暗、鎖定。
- 機型與系統版本：
  - iOS 用 `uname()` 的 machine 欄位（例如 iPhone 14 Pro Max 是 `iPhone15,3`），加上 `Platform.operatingSystemVersion`。
  - Android 讀系統屬性 `ro.product.model` 等（bionic libc 的 `__system_property_get`）。
  - 兩者都不在 Apple 的 required reason API 清單裡；讀取失敗只會少顯示機型。
  - FFI 的配置記憶體、讀字串流程已在 Linux 用 `uname` 實測可用；iOS 與 Android 的實際呼叫要等 CI 與實機驗證。
- 繪圖引擎判斷用 `ImageFilter.isShaderFilterSupported`，它在引擎裡直接回傳「是否用 Impeller」。

**這個測法的限制**

- **牛用向量圖形畫，比正式版嚴格**。正式版多半用圖片精靈，一頭一次貼圖。所以 200 頭如果順，正式版一定順；
  如果不順，要先換成貼圖再測，不能直接判定 Flutter 不行。
- **raster 時間只算 CPU 端送指令，不含 GPU 真正執行的時間**。GPU 忙不過來時，FrameTiming 看起來可能還好，
  FPS 卻掉下來。所以**「實際 FPS」是最後的判準**，網頁版實測就出現了這個情形（第 4 節）。
- 螢幕上限更新率（`display.refreshRate`）在 iOS 等於硬體上限：引擎的 `displayRefreshRate` 回傳
  `UIScreen.main.maximumFramesPerSecond`。它不代表 app 真的跑到 120 Hz，一樣要看實際 FPS。

**建議判讀方式**（暫定，ceo 可以調整）：在 iPhone 14 Pro Max 上，某個 N 同時符合下面三項，就算 120 Hz 流暢：

- 實際 FPS ≥ 114（120 的 95%）。
- 超過 8.3 ms 的比例 ≤ 1%。
- 超過 16.7 ms 的比例是 0。

## 3. 120 Hz 要不要 `CADisableMinimumFrameDurationOnPhone`：要

- **Apple 文件**〈Optimizing iPhone and iPad apps to support ProMotion displays〉：
  「Core Animation won't apply any refresh rate that's faster than the system's default. To enable your timing hints
  … in your iPhone app, … add the `CADisableMinimumFrameDurationOnPhone` key to your app's information property list
  with the Boolean value `true`」，以及「If you don't enable this support, Core Animation won't access higher frame
  rates (above 60Hz). … The iPad Pro doesn't require this special configuration.」
- **Flutter 引擎原始碼**（3.47.5）`engine/src/flutter/shell/platform/darwin/ios/framework/Source/DisplayLinkManager.swift`
  第 15–17 行：「On ProMotion iPhones, 120Hz variable refresh rate support must be explicitly unlocked by setting the
  `CADisableMinimumFrameDurationOnPhone` key … to `true` in the application's `Info.plist`.」同一個檔案的
  `maxRefreshRateEnabledOnIPhone` 直接讀 Info.plist 的這個值。
- **Flutter 範本**：PR flutter/flutter#94509（2022-03-09 合併）起，`flutter create` 產生的 Info.plist 就有
  `CADisableMinimumFrameDurationOnPhone = true`。本專案保留這個值，CI 會檢查 IPA 裡的 Info.plist 確實是 `true`。
- **使用者要注意**：「低電量模式」和「設定 → 輔助使用 → 動態效果 → 限制影格速率」都會把畫面鎖在 60 Hz，
  「超過 8.3 ms」那一列會因此失真。測試前兩個都要關掉（第 8 節第 6 步）。

## 4. 本機結果

| 檢查 | 結果 |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 11 個全過。9 個統計單元測試：百分位數、空資料、門檻、時間窗、FrameTiming 轉換。2 個 widget test：用統計函式算出的數字顯示在結果表上、430×932 不用捲動、360 dp 寬會縮小不溢出 |
| `flutter build web --release --no-wasm-dry-run` | 成功，32 秒，峰值記憶體 0.73 GB |
| `flutter build web --release`（預設） | 預設會多做一次 wasm 試編譯。這台筆電的 swap 已滿（2.0/2.0 GB，其他 session 占用），卡在 dart2wasm 超過 10 分鐘，最後用 PID 關掉。這台機器請加 `--no-wasm-dry-run` |
| workflow 靜態檢查 | `actionlint` 1.7.12＋`shellcheck` 0.11.0 兩個檔都 0 個問題 |

**網頁版大小**：`build/web` 共 40 MB。大部分是 5 種 CanvasKit／Skwasm 變體和 `.symbols` 除錯檔，瀏覽器只會
下載其中一種。

| 檔案 | 原始大小 | gzip 後 | 備註 |
|---|---|---|---|
| `main.dart.js`（app 本體） | 2.09 MB | 0.62 MB | 從區網主機下載 |
| `canvaskit.wasm`（Safari 用） | 7.28 MB | 2.92 MB | 預設從 `www.gstatic.com/flutter-canvaskit/<engine>` CDN 下載 |
| `chromium/canvaskit.wasm`（Chrome 用） | 5.43 MB | 2.06 MB | 同上 |
| `assets/`（NOTICES 授權文字 1.3 MB 等） | 1.3 MB | — | NOTICES 只有開授權頁才載入 |

**M1 區網內部預覽的路徑可行**：

- `build/web` 用 `python3 -m http.server 8765 --bind <這台筆電的 Wi-Fi 區網位址>` 開出來，
  headless Chromium 從 `http://<區網位址>:8765/` 載入（不是 localhost）。流程跑完，結果表正常顯示。
- 伺服器用完就用 PID 關掉了。
- 注意事項：
  - 手機要能連外網：CanvasKit 從 gstatic 的 CDN 下載，中文字型從 `fonts.gstatic.com` 下載。
    CanvasKit 可以用 `--no-web-resources-cdn` 改成自己提供，字型可以用 `fontFallbackBaseUrl` 指定。
  - **iPhone Safari 沒有實測**。照使用者的規則，手機畫面要在實機上看過才算驗收。

**網頁版數字（不是目標量測）**：headless Chromium 153，用 SwiftShader 軟體繪圖，模擬 430×932 @3x。
筆電同時跑著其他 session，swap 已滿。這些數字只證明整條流程可行：畫面時間收得到、各段分得開、結果表畫得出來。
它不代表手機的效能，兩次之間的差距也很大。

| 牛數 | FPS 第 1 次／第 2 次 | 畫面時間中位 ms | 畫面時間 p99 ms | raster p99 ms（第 2 次） |
|---|---|---|---|---|
| 30 | 15.6／11.8 | 6.80／8.20 | 14.6／21.3 | 19.1 |
| 60 | 11.4／9.4 | 11.6／14.6 | 21.4／29.2 | 20.7 |
| 100 | 8.6／7.8 | 20.6／21.9 | 46.2／44.4 | 22.0 |
| 200 | 3.3／6.1 | 49.3／37.3 | 90.0／55.6 | 20.0 |

第 2 次的 raster p99 一直在 20 ms 左右，FPS 卻從 11.8 掉到 6.1：SwiftShader 在 GPU 端的工作沒有算進
FrameTiming，這就是第 2 節說「實際 FPS 才是最後判準」的原因。原始 console 紀錄（第 2 次）在
`flutter-spike-shots/web-console.log`。

## 5. CI 設計

### 5.1 共同原則

- 兩個 workflow 都**只用 `workflow_dispatch`（手動執行）觸發**。push 和 pull request 都不會跑，公開 repo
  的免費 macOS 機器也不會被自動 PR 用掉。
- `permissions: contents: read`、`concurrency` 一次只跑一個、`actions/checkout` 不保留 token（`persist-credentials: false`）。
- 版本固定：
  - Flutter 由 `subosito/flutter-action` 讀 `pubspec.yaml` 的 `environment.flutter: 3.47.5`，本機與 CI 同一版。
  - `subosito/flutter-action` 本身鎖在 commit `1a449444…`（v2.23.0）。
  - 官方 actions 用 checkout v7、setup-java v6、upload-artifact v7，與 connect4 相同。
- 建置號 `GITHUB_RUN_NUMBER` 同時傳給 `--build-number` 與 `--dart-define=BUILD_NUMBER`，結果表上的建置號會和
  TestFlight 上看到的一致。
- 跑在 GitHub 的 `macos-latest`，目前是 macOS 26 arm64，預設 Xcode 26.6。

### 5.2 `.github/workflows/spike-ios.yml`

有兩種模式：

- `compile-only`：不需要任何 secret，只確認 iOS 版編譯得過。建議 ceo 推上去後先跑一次。這台 Linux 沒有 Xcode，
  iOS 的原生設定（AppDelegate 改動、xcconfig、FFI）要到這一步才第一次被編譯。
- `testflight`（預設）：步驟如下。
  1. **檢查 secrets**：7 個 secret 缺任何一個就失敗，並在 Summary 列出缺哪些。綠燈只代表「真的簽過、傳過」。
  2. **裝發布憑證**：建臨時 keychain，匯入 `.p12`（步驟與 connect4 相同，照 bash 3.2 語法寫）。
     憑證名稱含帳號持有人的本名，而這個 repo 的 log 是公開的，所以只檢查不印出，並用 `::add-mask::` 遮住。
  3. **裝描述檔並核對**：
     - 名稱必須是 `Cowfarm App Store`。
     - `application-identifier` 必須是「Team ID.com.oraclelee.cowfarm」。這一條會擋下誤貼 connect4 描述檔的情況。
     - 不能有 `ProvisionedDevices`（有的話是開發用或 ad hoc 描述檔）。
     - 描述檔的到期日寫進 Summary。
  4. **寫入簽章設定**：寫 `ios/Flutter/Signing.xcconfig`（手動簽章、Apple Distribution、描述檔名稱、Team ID）。
     它由 `Release.xcconfig` 的 `#include?` 讀入，所以只套用在 Runner 這個 target。
     connect4 的教訓是：簽章參數放在 xcodebuild 命令列會套到 Swift 套件上而失敗，所以不放命令列。
     這個檔已列入 `ios/.gitignore`。
  5. **建 IPA**：`flutter build ipa --release --export-options-plist=…`。ExportOptions 內容：
     - `method: app-store-connect`、`destination: export`、`signingStyle: manual`
     - `signingCertificate: Apple Distribution`、`teamID`
     - `provisioningProfiles: {com.oraclelee.cowfarm: Cowfarm App Store}`
     - `manageAppVersionAndBuildNumber: false`、`uploadSymbols: true`
  6. **檢查成品**：因為 `flutter build ipa` 匯出失敗也會回報成功，這一步另外要求 archive 和 IPA 都存在，並解開
     IPA 核對：
     - bundle ID、版本、建置號、桌面名稱
     - `ITSAppUsesNonExemptEncryption = false`、`CADisableMinimumFrameDurationOnPhone = true`
     - `UIDeviceFamily = [1]`、只支援直式
     - `codesign --verify` 通過、簽章者是 Apple Distribution、內嵌的描述檔名稱正確
  7. **上傳**：`xcodebuild -exportArchive`，ExportOptions 改成 `destination: upload`，帶
     `-authenticationKeyPath/-authenticationKeyID/-authenticationKeyIssuerID`。處理完成後出現在 TestFlight。
  8. **收尾**（不論成功或失敗都會執行）：刪掉 keychain、`.p8`、描述檔、`Signing.xcconfig`、解開的 IPA。

用到的 secrets 沿用 connect4 的名稱：`IOS_DIST_CERT_P12_BASE64`、`IOS_DIST_CERT_P12_PASSWORD`、`IOS_PROFILE_BASE64`、
`APPLE_TEAM_ID`、`ASC_API_KEY_ID`、`ASC_API_ISSUER_ID`、`ASC_API_KEY_P8_BASE64`。

### 5.3 上傳工具：選 `xcodebuild -exportArchive`，不用 `xcrun altool`

- **選 xcodebuild 的理由**：
  - connect4 的 Mobile release 用的就是這一套，已經在同一個 Apple 團隊成功把建置送進 TestFlight。這次唯一的
    新變數是 Flutter，不要再多一個。
  - 驗證參數是 Apple 在 `man xcodebuild` 寫明的 `-authenticationKeyPath` 等三個參數，金鑰路徑直接指定，
    用完即刪。
- **altool 的狀況**：
  - Flutter 文件建議的指令是 `xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa --apiKey … --apiIssuer …`。
  - 它只會到固定的資料夾找金鑰：`./private_keys`、`~/private_keys`、`~/.private_keys`、`~/.appstoreconnect/private_keys`，
    或環境變數 `API_PRIVATE_KEYS_DIR` 指定的位置。
  - Apple 的〈Upload builds〉說明頁對 altool 只舉了帳號密碼的用法。
  - 在這個帳號沒有用過。
- **代價**：xcodebuild 會從 archive 再匯出一次，多花不到一分鐘。

### 5.4 `.github/workflows/spike-android.yml`

- 在 ubuntu 上執行，不用任何 secret。Java 用 Temurin 17（AGP 9.1 的最低需求）。
- 先跑 `flutter analyze` 與 `flutter test`，再跑 `flutter build apk --release`。
- 範本的 release 設定就是用 debug key 簽章，只能側載，不能上 Google Play。
- 用 `aapt2 dump badging` 核對 applicationId、versionCode（等於 run number）、versionName 0.0.1、桌面名稱「牧場測試」；
  用 `apksigner` 印出簽章者（`CN=Android Debug`，不含個人資料）。
- APK 上傳成 artifact `cowfarm-spike-apk`，檔名 `cowfarm-spike-0.0.1-<run>.apk`，保留 14 天。
- runner 每次產生的 debug key 都不同，換新版 APK 前要先把舊的解除安裝。

### 5.5 公開 repo 的 secrets 安全

- 兩個 spike workflow 只有 `workflow_dispatch` 一種觸發方式。GitHub 文件寫明手動執行需要 repo 的寫入權限
  （「Write access to the repository is required」），而且 workflow 必須在預設分支上。所以外部的人無法觸發，
  fork PR 也不會執行它們。
- GitHub 文件：「With the exception of `GITHUB_TOKEN`, secrets are not passed to the runner when a workflow is
  triggered from a forked repository.」
- 之後新增 workflow 的規則：
  - **不要**用 `pull_request_target` 去 checkout PR 的程式碼。
  - **不要**讓任何會被 PR 觸發的 workflow 讀這 7 個 secrets。
- 建議 repo 設定：Settings → Actions → General。
  - 「Approval for running fork pull request workflows from contributors」選
    「Require approval for all external contributors」（所有外部貢獻者的 PR 都要先核准才執行）。
  - 「Workflow permissions」維持唯讀。
- 公開 repo 的 Actions log 任何人都看得到：
  - workflow 不印任何秘密值，也不印憑證上的本名（還加了遮罩）。
  - Android artifact 登入 GitHub 的人都能下載，但裡面只有 debug key 簽的測試 APK，沒有任何秘密。

### 5.6 可能卡住的地方與備案

| 狀況 | 看到的訊息 | 處理 |
|---|---|---|
| 還沒在 App Store Connect 建 app | 上傳時說找不到符合 bundle ID 的 app 記錄 | 做第 7 節 (c) 後重跑 |
| 描述檔貼錯（例如 connect4 的） | `the provisioning profile is for …` | 換成 `Cowfarm App Store` 的描述檔 |
| 同一個 run 按「Re-run」 | 建置號重複被拒 | 改用「Run workflow」開新的 run（run number 會加 1） |
| `flutter build ipa` 的 archive 步驟簽章失敗 | Xcode 的簽章錯誤 | 備案：先 `flutter build ios --release --config-only`，再照 connect4 直接用 `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release archive`，簽章設定一樣由 `Signing.xcconfig` 提供 |
| 發布憑證到期 | 約在 connect4 建立憑證後一年（2027-09 前後）；描述檔跟著失效 | 照 connect4 流程重做憑證與兩個 app 的描述檔，更新兩個 repo 的 secrets |

## 6. 自動簽章評估：這次不採用

**它能省什麼**：`man xcodebuild` 對 `-allowProvisioningUpdates` 的說明是「For automatically signed targets, xcodebuild
will create and update profiles, app IDs, and certificates. For manually signed targets, xcodebuild will download
missing or updated provisioning profiles.」Xcode 13 起可以用 App Store Connect API key 驗證（Xcode 13 release notes，
51444716）：「This enables the use of automatic signing via `xcodebuild` in headless environments, such as build machines
and continuous integration setups … When creating a key, you can assign it a role to control its permissions」。
理論上可以省掉 (a) 註冊 App ID、(b) 做描述檔，連 `.p12` 都不用。

**不採用的理由**

1. **要 Admin 等級的 API key**：
   - Xcode 13 release notes 寫雲端發布憑證「accessible only to members of your development team with the Admin role」。
   - Apple Developer Forums 698117：非 Admin 的 API key 做雲端簽章會得到「Cloud signing permission error」，
     另一位開發者補充 API key 沒有可以勾選開放的選項。
   - connect4 的 key 是 App Manager，得另外產生一把 Admin key 放進公開 repo 的 CI。這把 key 可以管理使用者和
     所有 app，一旦外洩，影響比現在大得多。
2. **App Manager 做描述檔也要額外權限**：Apple 的角色權限表寫，App Manager 建立發布用描述檔、註冊 App ID 都要先在
   App Store Connect 開「Certificates, Identifiers & Profiles」存取權。API key 能不能開這個權限，文件沒寫。
3. **Flutter 不支援傳 API key**：Flutter 3.47.5 的 `flutter build ipa` 在 archive 與 export 時都會加
   `-allowProvisioningUpdates`（`mac.dart` 第 414 行、`build_ios.dart` 第 567 行），但沒有任何參數可以傳 API key
   （flutter/flutter#139212 仍未解決）。runner 上又沒有登入的 Xcode 帳號，要自動簽章就得捨棄 `flutter build ipa`，
   自己寫 xcodebuild 指令。
4. **省下的很少**：手動做 App ID 和描述檔一次約 5 分鐘，描述檔一年才更新一次。

**折衷方案（也不建議）**：手動簽章加 `-allowProvisioningUpdates` 和 API key，可以讓 xcodebuild 自己下載描述檔，
省掉 `IOS_PROFILE_BASE64` 這個 secret。但描述檔還是要在網頁上建，而且同樣受第 3 點限制。

**App ID 用 API 註冊**：App Store Connect API 有 `POST /v1/bundleIds`（「Register a new bundle ID for app development」）
和 `POST /v1/profiles`（「Create a new provisioning profile」）。只做一次的事在網頁上按 2 分鐘就好，不值得為它寫一支
要照 safe-ops-script 規範（dry-run、確認）的腳本。至於 App Store Connect 的 app 記錄，API 沒有「建立 app」的端點：
`POST /v1/apps` 的文件不存在（404），API 文件 Apps 一節的「Add a new app」連到的是網頁操作說明。
所以 (c) 一定要在網頁上做。

**建議**：這次用手動簽章，照第 7、8 節做。M4（cow-release）如果描述檔維護變成負擔再重新評估。到時候可以考慮
放在受保護 GitHub Environment（要人核准才能執行）的 Admin key。

## 7. 使用者要做什麼、照什麼順序

前提：Apple Developer 會員仍有效，connect4 已經在用。建議順序：

1. **ceo（不需要使用者）**：審過後 commit、push，然後 Actions → Spike iOS → Run workflow，選 `compile-only`，
   先確認 iOS 版編譯得過。同時可以跑 Spike Android。
2. **使用者 (a) 註冊 App ID** `com.oraclelee.cowfarm`：網頁操作約 2 分鐘，見第 8 節第 1 步。API 註冊可行但不建議
   （第 6 節）。
3. **使用者 (b) 建立描述檔** `Cowfarm App Store`：選 connect4 已經有的 Apple Distribution 憑證，**不用做新憑證**，
   見第 8 節第 2 步。自動簽章不採用（第 6 節）。
4. **使用者 (c) 在 App Store Connect 建立 app 記錄**，見第 8 節第 3 步。名稱在整個 App Store 必須唯一，
   長度 2–30 字元，送審前都可以改（Apple：「You can edit it until you submit the app to App Review」）。
   建議 3 組暫用名稱：
   - 英文 **Moo Ticker Ranch**／中文 **哞哞行情牧場**
   - 英文 **Spotted Cow Market**／中文 **斑點牛市集**
   - 英文 **Milk Ticker Pasture**／中文 **牛奶行情小牧場**

   2026-09-30 用 App Store 公開搜尋 API（台灣、美國）查過，都沒有同名 app。但別人保留還沒上架的名稱查不到，
   建立時才會知道。三組都避開了「養豬場」「MIX」和其他遊戲的名稱。
5. **(d) secrets**：哪些沿用、哪些新做如下表。secrets 以 repo 為單位，寫入後也讀不回來，所以 7 個都要在
   cow-farm repo 重新設定一次。值從這台電腦的正本讀，經 stdin 設定。

| secret | 沿用或新做 | 正本位置 |
|---|---|---|
| `IOS_DIST_CERT_P12_BASE64`、`IOS_DIST_CERT_P12_PASSWORD` | 沿用（團隊層級的發布憑證，所有 app 共用） | `~/.config/connect4-mobile/ios/distribution.p12`、`p12-password.txt` |
| `ASC_API_KEY_P8_BASE64`、`ASC_API_KEY_ID`、`ASC_API_ISSUER_ID` | 沿用（團隊層級的 App Manager key，可以上傳任何 app） | 同一個資料夾的 `AuthKey_<KEY_ID>.p8`、`asc.json` |
| `APPLE_TEAM_ID` | 沿用 | 發布憑證的 OU 欄位（下面的指令只取值、不印出） |
| `IOS_PROFILE_BASE64` | **新做**：描述檔是一個 App ID 一個 | 下載後搬到 `~/.config/cow-farm/ios/app-store.mobileprovision` |

   由 ceo 或 cow-release 在這台電腦執行，使用者同意後再做。只放「檔案在哪」，不印任何內容。取值的部分已經在這台
   電腦驗證過：Team ID 10 碼英數、Key ID 10 碼、Issuer ID 是 UUID 格式、`.p8` 剛好 1 個。驗證時只檢查長度與格式，
   沒有印出值。

   ```bash
   REPO=EdwardLeeee/cow-farm
   C4=~/.config/connect4-mobile/ios
   # 沿用 connect4 的 6 個值
   base64 -w0 "$C4/distribution.p12" | gh secret set IOS_DIST_CERT_P12_BASE64 --repo "$REPO"
   gh secret set IOS_DIST_CERT_P12_PASSWORD --repo "$REPO" < "$C4/p12-password.txt"
   base64 -w0 "$C4"/AuthKey_*.p8 | gh secret set ASC_API_KEY_P8_BASE64 --repo "$REPO"
   python3 -c 'import json,sys; sys.stdout.write(json.load(open(sys.argv[1]))["key_id"])' "$C4/asc.json" \
     | gh secret set ASC_API_KEY_ID --repo "$REPO"
   python3 -c 'import json,sys; sys.stdout.write(json.load(open(sys.argv[1]))["issuer_id"])' "$C4/asc.json" \
     | gh secret set ASC_API_ISSUER_ID --repo "$REPO"
   openssl x509 -in "$C4/distribution.pem" -noout -subject -nameopt multiline \
     | sed -n 's/^ *organizationalUnitName *= //p' | tr -d '\n' \
     | gh secret set APPLE_TEAM_ID --repo "$REPO"
   # 新做的描述檔：搬離「下載」資料夾、只給自己讀、核對名稱後再設定
   install -d -m 700 ~/.config/cow-farm/ios
   mv ~/Downloads/Cowfarm_App_Store.mobileprovision ~/.config/cow-farm/ios/app-store.mobileprovision
   chmod 600 ~/.config/cow-farm/ios/app-store.mobileprovision
   openssl smime -inform der -verify -noverify -in ~/.config/cow-farm/ios/app-store.mobileprovision 2>/dev/null \
     | sed -n '/<key>Name<\/key>/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}'   # 應該印出 Cowfarm App Store
   base64 -w0 ~/.config/cow-farm/ios/app-store.mobileprovision | gh secret set IOS_PROFILE_BASE64 --repo "$REPO"
   gh secret list --repo "$REPO"   # 應該看到 7 個名稱與更新時間
   ```

   - 也可以用網頁：repo → Settings → Secrets and variables → Actions → New repository secret，填 Name 與 Secret
     → Add secret。但 base64 的值要先在終端機產生，所以建議用上面的指令。
   - 描述檔可以隨時從 Apple 網站重新下載，不是只能下載一次的檔案，備份非必要。
   - `.p12` 和 `.p8` 的正本仍然只有 connect4 那一份，沒有複製第二份，備份照 connect4 原本的安排。
   - 可以考慮為 cow-farm 另做一把 App Manager 等級的 key，出事時能單獨撤銷，不影響 connect4。這是加分項，
     不是必要。
6. **ceo**：Actions → Spike iOS → Run workflow，選 `testflight`。Summary 出現 “Uploaded … to App Store Connect”
   就是成功，Apple 處理完成後會寄信。
7. **使用者**：在 TestFlight 開內部測試、在 iPhone 安裝並跑測試，見第 8 節第 5、6 步。把截圖和「複製結果」的
   內容傳給 ceo。
8. **(e) Android**：使用者不用做任何帳號設定。ceo 跑 Spike Android 後把 APK 交給使用者側載，見第 8 節第 7 步。

## 8. 給使用者看的逐步說明（iPhone 測試版）

大約 15 分鐘：在蘋果網站上按幾個按鈕、下載 1 個檔案，剩下由 ceo 處理。這次**不用做新憑證、不用做新的 API key**，
直接沿用四子棋（connect4）那時做好的。

**開始前**

- 用加入 Apple Developer 會員的 Apple ID 登入，會要求兩步驟驗證。
- 網頁上方如果出現「需要同意新版協議」的橫幅，先按進去同意，不然後面的按鈕會是灰的。
- 下載的檔案留在瀏覽器預設的「下載」資料夾（這台電腦是 `~/Downloads`），不用搬。

### 1. 登記 app 的身分（App ID）

告訴蘋果「com.oraclelee.cowfarm 這個 app 是我的」。

1. 開 https://developer.apple.com/account/resources/identifiers/list
2. 按「Identifiers」標題旁的藍色 **＋**。
3. 選 **App IDs** → **Continue** → 選 **App** → **Continue**。
4. **Description** 填 `Cow Farm`；**Bundle ID** 選 **Explicit**，填 `com.oraclelee.cowfarm`（一字不差，上傳後就永遠
   不能改）。
5. 下面一長串 Capabilities 都不用勾 → **Continue** → **Register**。列表裡會多一行 `Cow Farm`。

### 2. 建立描述檔（Provisioning Profile）

把「app 身分」和四子棋那時做好的「發布憑證」綁在一起。

1. 開 https://developer.apple.com/account/resources/profiles/list
2. 按「Profiles」標題旁的 **＋**。
3. 在 **Distribution** 底下選 **App Store Connect** → **Continue**。
4. **App ID** 選 `Cow Farm (com.oraclelee.cowfarm)` → **Continue**。
5. 勾選列表裡的 **Apple Distribution** 憑證。有好幾張的話，選到期日最晚的那張，也就是四子棋用的那張。
   → **Continue**。
6. **Provisioning Profile Name** 一定要填 `Cowfarm App Store`（大小寫、空白都要一樣，程式會用這個名字找它）
   → **Generate**。
7. 按 **Download**。檔案叫 `Cowfarm_App_Store.mobileprovision`，會存到 `~/Downloads`。

### 3. 在 App Store Connect 建立 app

這一步才會知道名稱有沒有被別人用掉。

1. 開 https://appstoreconnect.apple.com/apps → 左上角 **＋** → **New App**。
2. **Platforms** 勾 **iOS**。
3. **Name** 先填 `Moo Ticker Ranch`。如果出現「名稱已被使用」，依序改填 `Spotted Cow Market`、`Milk Ticker Pasture`。
   三個都被用掉就先停下來告訴 ceo。這是暫用名稱，送審前都可以改。
4. **Primary Language** 選 **English (U.S.)**（和四子棋一樣；中文名稱之後填商店資料時再加）。
5. **Bundle ID** 選 `Cow Farm - com.oraclelee.cowfarm`。如果清單裡沒有它，重新整理頁面；第 1 步剛做完時
   可能要等一下才出現。
6. **SKU** 填 `cowfarm-ios`（只給自己看的代號）。
7. **User Access** 選 **Full Access** → **Create**。

### 4. 交給 ceo

跟 ceo 說「好了」，並告訴 ceo 第 3 步最後用了哪個名稱。這次沒有任何代碼要抄，Team ID、Key ID、Issuer ID
都沿用四子棋的。

ceo 接著會：

- 把 `~/Downloads` 裡的 `Cowfarm_App_Store.mobileprovision` 搬到 `~/.config/cow-farm/ios/`（只有你的帳號能讀）；
- 把 7 個設定值存進 GitHub（6 個沿用四子棋，1 個是剛才的描述檔）；
- 在 GitHub 按一次上傳，幾分鐘到半小時後你會收到蘋果寄來「處理完成」的信。

### 5. 開 TestFlight 內部測試（收到「處理完成」的信之後）

1. 開 https://appstoreconnect.apple.com/apps → 點剛建立的 app → 上方 **TestFlight** 分頁。
2. 左邊 **Internal Testing** 旁邊按 **＋**，群組名稱填 `自己` → **Create**。
3. 在群組裡的 **Testers** 按 **＋**，勾選你自己的帳號 → **Add**。
4. 在群組裡的 **Builds** 按 **＋**，選 `0.0.1` 底下最新的建置號 → **Add**。
5. iPhone 上會收到 TestFlight 的邀請通知或 email。沒有 TestFlight app 的話，先從 App Store 安裝「TestFlight」。

不用填出口合規問卷：app 已經在 Info.plist 聲明只用系統內建的加密。

### 6. 在 iPhone 上跑測試（約 2 分鐘）

1. 關掉**低電量模式**：設定 → 電池 → 低電量模式 → 關。
2. 關掉**限制影格速率**：設定 → 輔助使用 → 動態效果 → 限制影格速率 → 關。
3. 打開 **TestFlight** → 「牧場測試」→ **安裝** → **打開**。
4. 畫面上會有很多牛在草地上走，上方有一張折線圖，下方有進度條。**放著不要碰**，約 90 秒，螢幕不會自己關。
5. 出現「牧場測試：效能結果」表格後**截圖**。再按「**複製結果**」，把複製到的文字貼到對話給 ceo。
6. 有空的話按「**再跑一次**」，第二次的截圖一起傳。兩次的數字可以看出誤差有多大。

### 7. Android 手機（有的話，不用任何帳號）

1. ceo 會給你一個檔名像 `cowfarm-spike-0.0.1-12.apk` 的檔案，來自 GitHub 的 Spike Android 執行結果。
2. 把檔案傳到手機，例如用 USB 或雲端硬碟，在手機上點它安裝。
3. 手機問「要允許這個來源安裝不明應用程式嗎」→ 允許。
4. 如果 Play 安全防護說「未知的開發人員」→ 選「仍要安裝」。
5. 之前裝過舊版牧場測試的話，要先解除安裝。每次建置的簽章都不同，不能直接覆蓋。
6. 手機有 90 Hz 或 120 Hz 螢幕的話，先在「設定 → 顯示」把螢幕更新率設成高或自動。Android 上的 Flutter app
   不一定會自己切到高更新率。
7. 打開「牧場測試」，後面和 iPhone 的第 4–6 步一樣。

## 附錄

### 重現指令

```bash
cd docs/research/tech-stack/flutter-spike
F=~/development/flutter/bin/flutter
$F --suppress-analytics pub get
$F --suppress-analytics analyze
$F --suppress-analytics test
$F --suppress-analytics build web --release --no-wasm-dry-run
# 區網預覽（結束時用 PID 關掉伺服器）
(cd build/web && python3 -m http.server 8765 --bind "$(ip route get 1.1.1.1 | sed -n 's/.* src \([0-9.]*\).*/\1/p')")
# headless 檢查與截圖（Playwright，只讀借用 connect4 已安裝的套件）
PLAYWRIGHT_MODULE=~/Desktop/connect4-web2-worktrees/mobile/frontend/node_modules/playwright \
  node tool/web_check.cjs http://<區網 IP>:8765/ ../flutter-spike-shots
```

iOS 與 Android 只能在 CI 建置：`gh workflow run spike-ios.yml --repo EdwardLeeee/cow-farm -f mode=compile-only`
（或 `-f mode=testflight`）、`gh workflow run spike-android.yml --repo EdwardLeeee/cow-farm`。

### 限制（還沒驗證的事）

- **iOS 與 Android 版都還沒真正編譯過**：這台 Linux 沒有 Xcode 和 Android SDK。以下三項要等 CI 的
  `compile-only` 和 Spike Android 第一次跑才知道結果：
  - `AppDelegate`／`MainActivity` 的一行修改
  - `#include? "Signing.xcconfig"`
  - `dart:ffi` 讀機型的程式
- **手動簽章經 xcconfig 套用的做法沒有在 Mac 上跑過**。依據是 Flutter 的簽章邏輯：
  `code_signing.dart` 發現專案已經有 `DEVELOPMENT_TEAM` 就不再自己加參數。另外，xcconfig 是掛在 Runner target
  上的（`baseConfigurationReference`）。失敗時的備案見 5.6。
- **網頁數字是軟體繪圖**，不能推估手機表現。iPhone 的數字要等 TestFlight。
- **iPhone Safari 開區網網頁版沒有實測**。

### 來源

- Apple：Optimizing iPhone and iPad apps to support ProMotion displays —
  https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays
- Flutter 引擎 3.47.5：`engine/src/flutter/shell/platform/darwin/ios/framework/Source/DisplayLinkManager.swift`
  （SDK 內附原始碼，第 15–17、28–40、53–78 行）
- Flutter PR #94509（範本加入 `CADisableMinimumFrameDurationOnPhone`）— https://github.com/flutter/flutter/pull/94509
- Flutter API：`SchedulerBinding.addTimingsCallback` — https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addTimingsCallback.html ；
  `FrameTiming`（SDK `sky_engine/lib/ui/platform_dispatcher.dart`）
- Dart：`ProcessInfo.currentRss`（SDK `dart-sdk/lib/io/process.dart`）
- Flutter：Build and release an iOS app — https://docs.flutter.dev/deployment/ios
- Flutter 3.47.5 原始碼：`packages/flutter_tools/lib/src/commands/build_ios.dart`（匯出失敗仍回報成功、export 帶
  `-allowProvisioningUpdates`）、`ios/mac.dart` 第 414 行、`ios/code_signing.dart` 第 170–212 行
- flutter/flutter#139212（`flutter build ipa` 不能傳 API key）— https://github.com/flutter/flutter/issues/139212
- Apple：Describing use of required reason API — https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api ；
  NSPrivacyAccessedAPIType（磁碟空間 API 含 `systemFreeSize`、`systemSize`）—
  https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- device_info_plus 13.2.0：`ios/device_info_plus/Sources/device_info_plus/FPPDeviceInfoPlusPlugin.m` 第 38–43 行、
  `PrivacyInfo.xcprivacy`（`NSPrivacyAccessedAPITypes` 為空）
- Xcode 13 Release Notes（51444716、cloud signing）— https://developer.apple.com/documentation/xcode-release-notes/xcode-13-release-notes
- `man xcodebuild`（`-allowProvisioningUpdates`、`-authenticationKey*`）— 線上副本 https://leancrew.com/all-this/man/man1/xcodebuild.html ；
  Apple Developer Forums 764554 引用同一段 — https://developer.apple.com/forums/thread/764554
- Apple Developer Forums 698117（非 Admin key 的 Cloud signing permission error）— https://developer.apple.com/forums/thread/698117
- Apple：Cloud-managed certificates — https://developer.apple.com/help/account/certificates/cloud-managed-certificates ；
  Program roles — https://developer.apple.com/help/account/access/roles/
- Apple：Upload builds — https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds ；
  `man altool`（金鑰資料夾）— https://keith.github.io/xcode-man-pages/altool.1.html
- Apple：App information（名稱 2–30 字元、送審前可改）— https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
- App Store Connect API：Register a new bundle ID — https://developer.apple.com/documentation/appstoreconnectapi/post-v1-bundleids ；
  Create a profile — https://developer.apple.com/documentation/appstoreconnectapi/post-v1-profiles
- GitHub：Using secrets in GitHub Actions — https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions ；
  Manually running a workflow — https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-workflow-runs/manually-running-a-workflow
- GitHub runner images（macos-latest＝macOS 26 arm64、預設 Xcode 26.6；已預裝 yq）— https://github.com/actions/runner-images
- connect4 參考（只讀）：`.github/workflows/mobile-release.yml`、`docs/ios-apple-setup.md`、`docs/mobile-release.md`、
  `mobile/scripts/ios-signing.sh`
