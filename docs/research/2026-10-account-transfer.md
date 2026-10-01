# 換手機時怎麼把牧場帶過去，移轉碼還是綁定帳號：研究

- 日期：2026-10-01
- 負責：ceo（只研究，沒有改產品程式）
- 問題：使用者 2026-10-01：「沒有手遊是用轉移碼轉資料的吧」

## 先說結論

1. **有手遊用移轉碼，而且不少。** 這是日系手遊常見的做法：養豬場MIX、貓咪大戰爭、Fate/Grand Order 都有（第 2 節）。
2. **但移轉碼救不了一種情況**：手機掉了、壞了或誤刪 app，而事前沒有產生碼。
   - 我們現在的設計更嚴：碼只有 24 小時有效，只能在換機當天用，不能當備份。
   - 貓咪大戰爭後來加了「使用 Apple 登入」「使用 Google 登入」的帳號綁定。官方寫的用途就是這個：「當行動裝置不小心遺失、或是誤刪遊戲時，也可以復原帳號資料」。
3. **綁定帳號符合商店規定，但有三個附帶條件**（第 3 節）：
   - iPhone 版放 Google 登入，就要同時放 Apple 登入。
   - 刪除牧場時要多做一步：撤銷 Apple 登入。
   - 一樣不能強迫登入：第一次打開仍然自動建立訪客帳號。
4. **建議**：改成綁定 Apple／Google 帳號，不做移轉碼（第 6 節）。要不要改由使用者決定，因為使用者要多做兩個後台的設定。

## 名詞

- **訪客帳號**：第一次打開 app 時，伺服器自動建立的帳號。玩家不用輸入任何東西。
- **移轉碼**：玩家在舊手機產生的一串字，在新手機輸入後，牧場就搬過去。日系手遊叫「引繼碼」。
- **綁定帳號**：把牧場連到玩家的 Apple 或 Google 帳號。之後在任何手機登入同一個帳號，就能找回牧場。
- **token**：登入憑證，手機用它向伺服器證明「我是這個牧場的主人」。

## 1. 現在的設計（企劃書 4.11）

- 第一次打開自動建立訪客帳號，不收 email、電話、姓名。
- 設定裡按「產生移轉碼」：一次性，24 小時有效，產生新的時舊的就作廢。
- 新手機選「我有移轉碼」，輸入後牧場搬過來，舊手機自動登出。
- 設計稿已經畫好（PR #11）：S13-02 產生移轉碼；S14-01 到 S14-05 新手機輸入移轉碼。

**問題**
- 碼要事先產生。手機突然壞掉的人沒有碼，牧場就救不回來。
- 沒有任何東西能證明「誰是這個牧場的主人」。
  - 玩家寫信來說牧場不見了，我們沒辦法驗證，也就沒辦法幫他找回。
  - 已經刪掉 app 的人想在網頁上申請刪除帳號（Google Play 規定要有這個管道），同樣沒辦法驗證身分。

## 2. 別的遊戲怎麼做

| 遊戲 | 做法 | 依據 |
|---|---|---|
| 養豬場MIX | 移轉用的 ID 和密碼：舊手機先做「轉移登錄」設密碼，新手機輸入帳號和密碼 | 巴哈姆特玩家討論（不是官方文件）：「轉移另一支手機前要先轉移登錄，會叫你輸入密碼，另一支要登入帳號跟密碼」 |
| 貓咪大戰爭 | 兩種都有：號碼，加上後來新增的帳號綁定 | PONOS 官方說明（下面兩段原文） |
| Fate/Grand Order | 引繼碼加密碼，用一次就失效；繁中版另外可以綁手機號碼 | 巴哈姆特與 Mooncell 的教學（不是官方文件） |

**貓咪大戰爭官方原文**
- 號碼：「儲存轉移紀錄後會顯示『轉移號碼』與『認證號碼』，此2組號碼為繼承至新裝置的重要號碼，若遺失則無法回復紀錄，請務必妥善保管。」
- 綁定：「完成帳號綁定的話，當行動裝置不小心遺失、或是誤刪遊戲時，也可以復原帳號資料」；登入方式是「選擇『使用Apple登入』或『使用Google登入』」。

**讀法**
- 移轉碼不是我們發明的冷門做法，我們參考的養豬場MIX 就是這樣。
- 業界的走向是加上帳號綁定。貓咪大戰爭玩家把這個功能叫做「歷史里程碑」，巴哈姆特上也有好幾篇「找回遺失的帳號」教學，表示只靠號碼時，弄丟帳號是常見的痛點。

## 3. 平台規則

| 規則 | 原文 | 對我們的意思 |
|---|---|---|
| Apple 4.8 | 「Apps that use a third-party or social login service (such as Facebook Login, Google Sign-In, …) to set up or authenticate the user's primary account with the app must also offer as an equivalent option another login service …」；例外：「Your app exclusively uses your company's own account setup and sign-in systems.」 | 只用訪客帳號和移轉碼時不受限制。iPhone 版一放 Google 登入，就要同時放 Apple 登入 |
| Apple 5.1.1(v) | 「If your app doesn't include significant account-based features, let people use it without a login. If your app supports account creation, you must also offer account deletion within the app.」 | 不能強迫登入：訪客帳號要保留，綁定是選用的。刪除牧場照舊要有 |
| Apple 刪除帳號說明 | 「Apps that support Sign in with Apple should use the Sign in with Apple REST API to revoke user tokens.」 | 有 Apple 登入時，刪除牧場要多呼叫一次 Apple 的 API，伺服器要保管一把 Apple 金鑰 |
| Apple 刪除帳號說明 | 「Users should have the option to delete automatically generated accounts (sometimes called "guest" accounts) and the data associated with those accounts.」 | 訪客帳號也要能刪。現在的設計已經符合 |
| Google Play | 要有 app 內和網頁上的刪除管道（原計畫已查） | 綁定帳號後，刪掉 app 的人可以重裝、登入、再刪除，身分驗證有著落 |

## 4. 方案比較

| | A 只用移轉碼（現況） | B 綁定 Apple／Google，不做移轉碼 | C 兩個都做 |
|---|---|---|---|
| 玩家換手機 | 舊手機產生碼，新手機輸入 | 設定裡按一次登入；新手機登入同一個帳號 | 兩種都可以 |
| 手機掉了、壞了 | 沒事先產生碼就救不回來 | 綁過就救得回來 | 綁過就救得回來 |
| iPhone 換 Android | 可以 | 要先在 iPhone 上綁 Google 帳號 | 可以（用碼） |
| 被騙走帳號 | 有風險：碼可以念給別人聽 | 沒有可以念給別人的碼 | 有風險 |
| 收的個人資料 | 沒有 | Apple／Google 給的帳號識別碼 | 同 B |
| 使用者要做的事 | 沒有 | Apple Developer 開「Sign in with Apple」、建一把金鑰；Google Cloud 建登入用的用戶端 | 同 B |
| 設計稿 | 已經畫好 | S13、S14 重畫 | S13、S14 加畫 |
| 程式 | 最少 | 伺服器驗證兩種登入、刪除時撤銷 Apple 登入；app 加兩個套件 | 最多 |
| 審核 | 最單純 | Apple 會實測登入和刪除 | 同 B |

- B 的 Android 版只放 Google 登入。
  - Apple 登入在 Android 上要走網頁流程，還要伺服器接回呼。`sign_in_with_apple` 8.2.0 的說明：「On the Sign in with Apple callback on your server (specified in `WebAuthenticationOptions.redirectUri`), redirect safely back to your Android app …」。
  - 第一版不做這一段。
- C 比 B 多出來的好處很少：手機突然壞掉時，沒綁帳號的人一樣沒有碼。多出來的是畫面、程式和被騙走帳號的風險。

## 5. 對現有設計與程式的影響（選 B 時）

- **企劃書 4.11**：移轉碼改成「備份牧場」（綁定 Apple／Google）；新手機第一次打開的選擇改成「開新牧場」「找回我的牧場」。
- **設計稿**：S13-02 與 S14-01 到 S14-05 重畫，另外要畫幾個新狀態：
  - 還沒綁定、已經綁定、綁定失敗。
  - 這個帳號已經綁了另一個牧場。
  - 新手機已經玩了一下才登入舊帳號：要問玩家「要換回舊牧場嗎？這個新牧場會消失」。
- **伺服器**：綁定、解除綁定、用帳號找回牧場三個功能；驗證 Apple 與 Google 的登入憑證；刪除牧場時撤銷 Apple 登入。
- **金鑰**：伺服器要保管一把 Apple 金鑰（.p8），照 secrets-custody 處理，不進 repo。
- **隱私權政策**：多寫一項「Apple／Google 帳號的識別碼，只用來找回牧場」。
- **時程**：畫面現在改（M2 還沒核准，現在改最省）；程式在 M3 做；Apple 和 Google 的後台設定跟著 M4 的 TestFlight 一起做。

**不管選哪一個都要處理（寫進 M3 待辦）**
- Android 的自動備份會讓存 token 的套件出錯。`flutter_secure_storage` 11.2.0 的說明：「By default Android backups data on Google Drive. It can cause exception `java.security.InvalidKeyException: Failed to unwrap key`.」做法是關掉自動備份，或把那個檔案排除在備份之外。
- 加分項（M3 再評估，沒有實測）：Android 的 Block Store 可以讓 token 跟著系統的換機流程搬到新手機。官方原文：「The Block Store API allows your app to store data that it can later retrieve to re-authenticate users on a new device.」做得到的話，Android 換 Android 連登入都不用按。

## 6. 建議與分階段

**建議：B 綁定 Apple／Google 帳號，不做移轉碼。**
- 理由 1：牧場不見等於玩家流失。綁定之後玩家可以自己找回，不用寫信給我們，我們也不必判斷誰是主人。
- 理由 2：只有一種做法，畫面和程式都比 C 少，也沒有可以被騙走的碼。
- 理由 3：現在改最便宜。設計稿還沒核准，M3 還沒開工。

**分階段**
1. 現在：使用者決定 → ceo 改企劃書 4.11 與決定紀錄 → cow-ui 重畫 S13、S14，跟整套設計稿一起核准。
2. M3：cow-back 做綁定與驗證，cow-app 接兩個登入套件。驗收：自動測試涵蓋綁定、找回、帳號已綁別的牧場、刪除時撤銷。
3. M4：使用者照步驟做 Apple Developer 與 Google Cloud 的設定；在 iPhone 實機驗收「綁定 → 刪掉 app → 重裝 → 找回牧場」。

**不建議**：C 兩個都做。因為手機突然壞掉時，碼幫不上忙（第 4 節），卻多了被騙走帳號的風險。

## 附錄

### 限制（沒查到或沒實測的）

- 養豬場MIX 和 FGO 的做法來自玩家討論，不是官方文件。
- 沒有實測 Apple 登入與 Google 登入；Google 登入在 Android 只能先用模擬器驗（使用者沒有 Android 手機）。
- Google 登入預設會要哪些資料，`google_sign_in` 7.2.0 的說明頁沒寫清楚。M3 開工前查 Google 官方文件，只要求最少的資料，不拿 email。
- iPhone 換 iPhone 時，Keychain 裡的 token 會不會跟著系統的換機流程過去：沒查到官方說法，也沒有實測。
- Google Cloud 的登入設定要不要經過 Google 審核：沒查，M4 做設定前查官方文件。

### 來源

- 貓咪大戰爭官方說明：[機種變更／帳號綁定](https://ponosgames.com/information/appli/battlecats/faq/tw/change.html)、[透過帳號綁定功能來進行資料繼承](https://ponosgames.com/information/appli/battlecats/faq/tw/change_detail_account.html)
- 養豬場MIX：[巴哈姆特玩家討論](https://forum.gamer.com.tw/C.php?bsn=27034&snA=560)
- Fate/Grand Order：[巴哈姆特引繼使用教學](https://forum.gamer.com.tw/Co.php?bsn=26742&sn=611)、[Mooncell：日服的數據繼承](https://fgo.wiki/w/%E6%97%A5%E6%9C%8D%E7%9A%84%E6%95%B0%E6%8D%AE%E7%BB%A7%E6%89%BF)
- [App Store 審核準則](https://developer.apple.com/app-store/review/guidelines/) 4.8、5.1.1(v)
- [Apple：Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- 套件：[sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple)、[google_sign_in](https://pub.dev/packages/google_sign_in)、[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
- [Android Block Store](https://developer.android.com/identity/block-store)
