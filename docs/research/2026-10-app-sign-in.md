# app 怎麼接 Apple、Google 登入（備份與找回牧場）：查證

- 日期：2026-10-03
- 負責：cow-app（只研究；app 的程式在 S13 PR B）
- 問題：brief 第 7 步「Google 登入只要求最少的資料，不拿 email。開工前查 Google 官方文件確認做法。」以及接 `sign_in_with_apple`、`google_sign_in` 之前要確認的事：nonce 怎麼交給套件、Apple 的 authorization code、網頁版、按鈕的字、token 怎麼存。
- 依據：協定第 5 節（`docs/protocol.md`）、伺服器端的研究 `docs/research/2026-10-sso-verification.md`。
- 決定：ceo 2026-10-03 回覆，寫在第 6 節。

## 先說結論

1. **Apple：跟協定對得上，照做。**
   - `sign_in_with_apple` 8.2.0 的 `getAppleIDCredential` 每次登入都可以給一個 nonce，原樣寫進 identity token；`scopes` 給空的就不要 email 和姓名；回傳有 authorization code。
2. **Google 少要資料做不到，改字。**
   - Google 官方說明：用 Google 登入時，姓名、email、頭像一定會分享給 app，「you can't exclude any of these pieces of data」。
   - app 和伺服器都不讀、不存（伺服器只存 `sub`）。但設計稿上「只用來找回牧場，不會拿你的 email 和姓名」字面上不對：Google 的同意畫面會告訴玩家，姓名和 email 會分享給牛市牧場。
   - **決定**：改成「只用來找回牧場，不會留下你的 email 和姓名」。cow-ui 改字串表，cow-app 重產 `strings.g.dart`。
3. **Google 每次登入換一個 nonce，套件沒有正式支援；決定每次登入前重新 `initialize()`（方案 A）。**
   - `google_sign_in` 7.x 的 nonce 只能在 `initialize()` 給，文件寫 `initialize()` 只能叫一次，叫第二次「will result in undefined behavior」。官方 issue #175029（2025-09-07 開，P2，還開著）就是在要這個功能。
   - 協定的 nonce 每個只能用一次，所以第二次登入（取消或失敗後再按、解除後再綁）要換新的 nonce。
   - **方案 A 是讀程式推出來的，沒有實測**：兩個手機平台的 Dart 端，再叫一次 `initialize()` 是把 nonce 覆蓋掉（第 1.2 節）。iOS 原生端重新設定會怎樣沒讀到。
   - 套件版本釘死。**M4 實機一定要測「失敗後再按一次」「解除後再綁」**；不行就找 cow-back 改成方案 B（伺服器放寬 Google 的 nonce）。
4. **登入只在設好 client ID 的建置出現。**
   - Google 規定網頁版要用 SDK 畫的按鈕，而且兩家都要 client ID（M4 才建）。沒有的話伺服器回 `not_configured`。
   - **決定**：「備份牧場」那一列、S15-03 和 S14 的「找回我的牧場」，只在設好 client ID 的建置（M4 起的 iOS、Android）顯示。網頁試玩版、沒設的建置都不顯示。伺服器不做假的驗證器讓試玩版登入。
5. **按鈕的字。**
   - Apple 的泰文：Apple 自己的泰文說明頁寫「ลงชื่อเข้าด้วย Apple」，我們的字串是「ลงชื่อเข้าใช้ด้วย Apple」。Apple 規定按鈕只能用官方的標題。**決定**：改成 Apple 的寫法（cow-ui 改字串表）。繁中「使用 Apple 登入」、英文「Sign in with Apple」跟 Apple 的一樣。
   - Google 准許翻譯，沒有官方的翻譯表。Google 的按鈕規格是 Google Sans Medium 14／20，設計稿是 17 粗體。**決定**：字級由 cow-ui 定。
6. **token 存法**：`flutter_secure_storage` 11.x，iOS 用 `KeychainAccessibility.first_unlock_this_device`，Android 在備份規則排除它的 SharedPreferences。

## 名詞

- **nonce**：伺服器發的一次性亂數。登入時交給 Apple／Google，會寫進登入憑證，伺服器比對後用掉，別人拿舊憑證來重送會被擋。
- **ID token／identity token**：Apple／Google 發給 app 的登入憑證（JWT），裡面有帳號識別碼 `sub`。
- **authorization code**：Apple 登入時多給的一次性換票碼，伺服器拿它換 refresh token，刪除牧場、解除綁定時用來撤銷 Apple 登入。
- **client ID**：在 Apple Developer、Google Cloud 建的「這個 app」的代號。M4 由使用者建立。
- **建置**：把程式編成 iPhone、Android 或網頁可以裝的版本。client ID 在建置時填進去。

## 1. 正確性：官方文件怎麼寫

### 1.1 Apple（`sign_in_with_apple` 8.2.0）

- `getAppleIDCredential({required scopes, webAuthenticationOptions, nonce, state})`。
- nonce：「Optional string which, if set, will be be embedded in the resulting `identityToken`」「can be used to mitigate replay attacks by using a unique argument per sign-in attempt」。每次呼叫各給一個，原樣寫進 token。協定 5.0 比對「原值或原值的 SHA-256」，原值送就對得上。
- scopes：必填的 list，給 `[]` 就不要 email 和姓名（`AppleIDAuthorizationScopes.email`、`.fullName` 都不給）。
- 回傳 `AuthorizationCredentialAppleID`：`identityToken`、`authorizationCode`、`userIdentifier`。綁定（5.2）要送 authorization code。
- 例外：`SignInWithAppleAuthorizationException`（取消是 `AuthorizationErrorCode.canceled`，app 自己顯示「已取消登入」，不打伺服器）、`SignInWithAppleNotSupportedException`（iOS 13 以下）。
- Android、網頁要 `webAuthenticationOptions`（Service ID、redirect URI）。設計稿 Android 版本來就沒有 Apple 按鈕；網頁版不顯示登入（結論第 4 點）。
- 按鈕：`SignInWithAppleButton({onPressed, text = 'Sign in with Apple', height = 44, style = black, borderRadius = 8, iconAlignment = center})`。設計稿 48 高、圓角 16，text 傳我們的字串。

### 1.2 Google（`google_sign_in` 7.2.0）

- `initialize({clientId, serverClientId, nonce, hostedDomain})`：「Clients must call this method exactly once … calling this method more than once, will result in undefined behavior.」
- nonce 只在 `initialize()`：「will be passed as part of any authentication requests」。`authenticate({scopeHint})` 沒有 nonce 參數。
- 官方 issue：flutter/flutter#175029「[google_sign_in] Support setting the nonce for each authentication」，2025-09-07，P2，open，沒有維護者回覆。
- 讀原始碼（flutter/packages main）：
  - Android（`google_sign_in_android`）：`init` 只是把 nonce 存在變數 `_nonce`，每次 `authenticate` 讀它；再叫一次就是覆蓋。Android 本身的 Credential Manager 是每次登入各設一次 nonce（`GetGoogleIdOption.Builder().setNonce(...)`，官方文件的寫法）。
  - iOS（`google_sign_in_ios`）：`init` 存 `_nonce`，每次 `authenticate` 傳給 `_signIn(scopeHint, _nonce)`；再叫一次會覆蓋並重新 `configure`。
  - 外層 `google_sign_in`：`initialize` 會訂閱平台的登入事件（平台有提供的話），叫兩次會重複訂閱；手機兩個平台沒有提供，網頁有（網頁不顯示登入）。
- 會分享哪些資料（Google 帳號說明 12921417）：「Your name, Your email address, Your profile picture」「If you want to use Sign in with Google, you can't exclude any of these pieces of data.」ID token 範例欄位有 `email`、`email_verified`、`name`、`picture`、`given_name`、`family_name`、`locale`。
- 伺服器只用 `sub`（Google：「Only use Google ID token `sub` field as identifier」），協定 5 已經這樣做。
- 網頁：「user-initiated sign in on web must use a button rendered by the sign in SDK, rather than application-provided UI」。
- 取消：`authenticate` 失敗都丟 `GoogleSignInException`，取消有自己的 code（`canceled`），app 自己顯示「已取消登入」。

### 1.3 Google 按鈕規格（Sign in with Google Branding Guidelines）

- 字：「Sign in with Google」「Sign up with Google」「Continue with Google」；「Localization of this text to match the language of your app or website is permitted and encouraged」，沒有官方翻譯表。
- 「G」標誌：「you can't change the size or color of the Google 'G' logo. It must be the standard color version」，放白底。m3-backlog：可以內建 Google 官方的「G」檔（不改、註明來源）。
- 淺色：底 #FFFFFF、框 #747775 1px、字 #1F1F1F Google Sans Medium 14／20；左右內距 iOS 16／12、Android 12／10。設計稿的框色和底色一樣，字是 17 粗體 Noto Sans。
- 「at least as prominently as other third party sign-in options」：設計稿兩顆一樣大，符合。

### 1.4 token 存法（`flutter_secure_storage` 11.x）

- Android：「By default Android backups data on Google Drive. It can cause exception java.security.InvalidKeyException: Failed to unwrap key.」README 的做法：`android:allowBackup="false"`，或用 `fullBackupContent`／`dataExtractionRules` 排除它的 SharedPreferences。
- iOS：`IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device)`：開機後解鎖過一次就讀得到，不會隨備份搬到新手機（backend-findings 的建議）。
- 現況：`storage/token_store_io.dart` 用預設的 `FlutterSecureStorage()`，兩個都還沒設；AndroidManifest 沒有備份規則。

## 2. 速度

不適用：登入一次是玩家按一下、等 Apple／Google 的系統畫面，app 這邊沒有要算的東西。

## 3. 大小

- 兩個套件都會帶原生程式：Android 是 Credential Manager（androidx.credentials、googleid），iOS 是 GoogleSignIn SDK。
- 安裝檔多多少，M4 建第一個 TestFlight／APK 時量，寫進這份筆記。

## 4. 替代方案比較（Google 每次登入換 nonce）

| | A. 每次登入前重新 `initialize()` | B. 伺服器放寬：Google 的 nonce 在這次打開 app 期間可以重複用 | C. 自己寫原生程式（Android Credential Manager、iOS GoogleSignIn SDK） |
|---|---|---|---|
| 玩家看到的差別 | 沒有 | 沒有 | 沒有 |
| app 要做的 | 每次按 Google 先拿 nonce、`initialize(nonce)`、`authenticate()` | 打開 app 後第一次按時拿一次 nonce | Kotlin、Swift 各寫一段，接 platform channel |
| 伺服器 | 不用改 | cow-back 改協定 5.0、5.1（防重放變弱） | 不用改 |
| 風險 | 文件說叫兩次是「未定義行為」；現在兩個手機平台的 Dart 端是覆蓋（讀過原始碼），套件升版可能變；要釘版本、M4 實機驗 | 一張被偷的 token 在那段時間內可以重送 | 程式多、要自己維護兩個平台的登入 |

選 A（ceo 2026-10-03）：玩家沒有差別、伺服器不用動。A 沒有實測，只是讀程式：

- 官方文件寫叫兩次是「未定義行為」；
- Android 的 Dart 端確認是覆蓋；iOS 的 Dart 端是覆蓋並重新 `configure`，原生端重叫 `configure` 會怎樣沒讀到原始碼；
- 套件版本釘死，追 #175029（官方支援每次給 nonce 以後改用正式的做法）；
- M4 實機驗收一定要測「失敗後再按一次」「解除後再綁」，也測「取消後再按」；不行就找 cow-back 改成 B。

**不建議** C：A 不行時 B 只要伺服器改兩節協定，C 要自己維護兩個平台的原生登入程式。

## 5. 對現有程式的影響（S13 PR B 的工作清單）

- `pubspec.yaml`：加 `sign_in_with_apple` 8.2.0；Google 加 `google_sign_in_android` 7.2.17、`google_sign_in_ios` 6.3.6、`google_sign_in_platform_interface` 3.1.0（就是 `google_sign_in` 7.2.0 用的那三個；版本釘死，理由見第 4 節）。
  - **不直接依賴 `google_sign_in`**：它的網頁實作（`google_sign_in_web` 1.1.3）在 app 啟動、註冊套件時就去載 `https://accounts.google.com/gsi/client`（`GoogleSignInPlugin` 的建構式呼叫 `loadWebSdk()`），網頁試玩版沒有登入也會每次連 Google。
  - 只依賴 Android、iOS 的實作時，Flutter 工具照樣在手機上註冊（`flutter_tools` 的 `_resolveImplementationOfPlugin`：只有一個候選就用它），網頁版就沒有 Google 的實作。
  - app 呼叫共用介面的 `init`、`authenticate`、`signOut`，跟 `google_sign_in` 7.2.0 的 `initialize`、`authenticate`、`signOut` 裡面呼叫的是同一組，第 4 節方案 A 的分析不變。
  - Apple 的網頁實作（`sign_in_with_apple_web`）註冊時什麼都不做，不用排除。
- **什麼時候顯示登入**：建置時用 `--dart-define` 填 Google 的 client ID（伺服器用的 Web client ID；iOS 另外要 iOS client ID）。沒填、或是網頁版，就不顯示「備份牧場」那一列、S15-03 和 S14 的「找回我的牧場」，齒輪也不放小點（G-10）。
- `lib/auth/sign_in.dart`（新）：`SignInService` 介面，回傳「拿到憑證（id_token、nonce、Apple 另有 authorization_code）」「玩家取消」「失敗」三種結果。
  - 真的實作只在玩家按下按鈕時才建；Google 每次按都先拿 nonce、重新 `initialize()`（第 4 節方案 A）。
  - 測試用假的實作，只在測試裡；app 本身沒有假的登入。
  - 平台（iPhone 兩顆、Android 一顆）由外面明確傳進來，不用 `defaultTargetPlatform` 猜（網頁版會變成 linux）。
- `api/`：nonce、綁定、解除、換回、找回五個端點（協定 5.1–5.5），綁定、換回、找回帶 request_id。
- `state/game_model.dart`：綁定的流程；換回成功後換 token、清掉舊牧場的狀態（跟刪除一樣走 `_forgetRanch`，再載入新牧場），升級慶祝不能拿新牧場的等級跟舊牧場比。
- `storage/token_store_io.dart`：iOS `first_unlock_this_device`；`android/app/src/main/AndroidManifest.xml` 加備份規則，排除 flutter_secure_storage 的 SharedPreferences。
- iOS：Runner 加 Sign in with Apple 的 capability（entitlements）、Google 的 URL scheme（反過來的 client ID，M4 才有）。這兩個沒有 client ID 也能先放結構，值 M4 填。
- 畫面：S13-02、07～16、19，G-10 齒輪小點（還沒備份、也還沒打開過「備份牧場」頁）。
- 字串：「不會留下你的 email 和姓名」、Apple 泰文按鈕字，cow-ui 改字串表，cow-app 重產 `strings.g.dart`（三步走）。

## 6. 決定與分階段

ceo 2026-10-03 的決定：

1. Google 的 nonce 用方案 A（每次登入前重新 `initialize()`），套件版本釘死。這份筆記寫明 A 是讀程式推的、沒有實測；M4 實機測「失敗後再按一次」「解除後再綁」，不行就找 cow-back 改 B。
2. 字改成「只用來找回牧場，不會留下你的 email 和姓名」；Apple 泰文按鈕改成「ลงชื่อเข้าด้วย Apple」。cow-ui 改字串，cow-app 重產。Google 按鈕的字級由 cow-ui 定。
3. 登入只在設好 client ID 的建置（M4 起的 iOS、Android）顯示；網頁試玩版和沒設的建置不顯示。不做假的驗證器。

分階段：

1. **S13 PR B**：照上面的決定接兩個套件；token 存法一起改；登入做成一個介面（`SignInService`），測試用假的實作。
   - 驗收：widget 測試走完綁定、取消、失敗、已經綁了別的牧場（換回）、解除；沒設 client ID 時那幾個入口都不在。
2. **M4**：建 client ID、Apple Service ID 後，在 iPhone 和 Android 模擬器實測：綁定、取消、取消後再按、失敗後再按一次、解除後再綁、找回、換回、刪除後 Apple 帳號設定裡看不到 app。量安裝檔多多少，寫回第 3 節。

## 附錄

### 限制

- 沒有 client ID，Apple、Google 的登入畫面都沒有實際跑過；以上是官方文件和套件原始碼。
- `google_sign_in` 的 iOS 原生端重新 `configure` 會不會有副作用，只看了 Dart 端，原生端沒讀到。

### 來源（2026-10-03 讀取）

- sign_in_with_apple：https://pub.dev/packages/sign_in_with_apple ；getAppleIDCredential、SignInWithAppleButton 的 API 文件
- google_sign_in：https://pub.dev/packages/google_sign_in ；initialize、authenticate 的 API 文件
- flutter/flutter#175029：https://github.com/flutter/flutter/issues/175029
- google_sign_in 原始碼：flutter/packages main 的 google_sign_in_android、google_sign_in_ios、google_sign_in 的 lib
- Android Credential Manager 的 Sign in with Google：https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation
- Google 帳號說明「How Sign in with Google helps you share data safely」：https://support.google.com/accounts/answer/12921417
- 驗證 Google ID token：https://developers.google.com/identity/gsi/web/guides/verify-google-id-token
- Sign in with Google Branding Guidelines：https://developers.google.com/identity/branding-guidelines
- Apple 泰文說明「ลงชื่อเข้าด้วย Apple คืออะไร」：https://support.apple.com/th-th/102609
- flutter_secure_storage：https://pub.dev/packages/flutter_secure_storage
