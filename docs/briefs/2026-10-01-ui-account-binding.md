主旨：cow-ui 把設定（S13）和新手機（S14）兩組畫面從「移轉碼」改成「綁定 Apple／Google 帳號」，因為使用者決定不做移轉碼（D22）

## 目標

- 玩家在設定裡按一次登入，就把牧場備份到自己的 Apple 或 Google 帳號。
- 換手機或重裝後，登入同一個帳號就找回牧場。
- 這兩組畫面重畫後，跟整套 M2 設計稿一起交使用者核准。

## 依據

- 使用者裁示（2026-10-01）：「沒有手遊是用轉移碼轉資料的吧」。ceo 查證後列出四種做法，使用者在選擇欄位選「綁定 Apple／Google（推薦）」。記在 `docs/decisions.md` D22（main d044102）。
- 規則：`docs/design/gdd.md` 4.11（已重寫，以它為準）。
- 查證與比較：`docs/research/2026-10-account-transfer.md`。
- Apple 審核準則 4.8：「Apps that use a third-party or social login service (such as Facebook Login, Google Sign-In, …) to set up or authenticate the user's primary account with the app must also offer as an equivalent option another login service …」。所以 iPhone 版要同時有 Apple 和 Google 兩種登入。
- Apple 設計規範（Sign in with Apple）：
  - 「Make a Sign in with Apple button no smaller than other sign-in buttons, and avoid making people scroll to see the button.」
  - 「Titles. Use only Sign in with Apple, Sign up with Apple, or Continue with Apple.」
  - 「Logo and title colors. Within a button, both items must be either black or white; don't use custom colors.」
  - 「Background appearance. The overall color needs to remain black or white.」
  - 「Use only the logo artwork downloaded from Apple Design Resources; never create a custom Apple logo.」
  - 「Adjust the corner radius to match the appearance of other buttons in your app.」
  - 「App Review evaluates all custom Sign in with Apple buttons.」
  - 「Ask people to sign in only in exchange for value.」「Delay sign-in as long as possible.」
- Google 品牌規範（Sign in with Google）：
  - 「The button must always include the standard color for the Google 'G'.」
  - 「You can't change the size or color of the Google 'G' logo.」
  - 「The Sign in with Google button should be displayed at least as prominently as other third party sign-in options.」

## 範圍

**要改**（`design/`；頁面 ID 怎麼編由你決定）

S13 設定
1. S13-01 設定主頁：「產生移轉碼」那一列改成「備份牧場」，副標「換手機或手機壞了都能找回」，右邊標狀態「還沒備份」或「已備份」。
2. S13-02 備份牧場，還沒綁定（iPhone）：
   - 好處：「備份以後，換手機或手機壞了，都能找回牧場。」
   - 提醒：「沒有備份的牧場，手機壞了就找不回來。」
   - 兩顆一樣大的按鈕：「使用 Apple 登入」「使用 Google 登入」。
   - 小字：「只用來找回牧場，不會拿你的 email 和姓名。」
3. 局部：Android 版只有「使用 Google 登入」一顆。
4. 已經綁定：每種帳號一列，例如「Apple 帳號　已綁定・2026/10/01」加「解除」；還沒綁的那一種顯示登入按鈕。
   - iPhone 上只綁了 Apple 時加一句：「以後可能換 Android 手機的話，再綁一個 Google 帳號。」
5. 局部：綁定成功的提示；登入取消或失敗的提示；解除綁定的確認（「解除以後，就不能用這個帳號找回牧場」）。
6. 這個帳號已經綁了另一個牧場：顯示那個牧場的名字、#編號、等級；按鈕「換回那個牧場」「取消」。
7. 換回前再確認：「這支手機現在的牧場『○○牧場 #5678』會刪除，不能復原」；按鈕「換回，並刪除現在的牧場」「取消」。
8. S13-03 刪除牧場：後果清單多一條「綁定的 Apple／Google 帳號會解除，之後可以再綁新的牧場」。
9. S13-05：拿掉「移轉碼產生失敗」。

S14 找回牧場（新手機或重裝後）
1. S14-01 第一次打開：「開新牧場」「找回我的牧場」。
2. S14-02 找回我的牧場：說明「用之前備份牧場的帳號登入」；登入按鈕（iPhone 兩顆、Android 一顆）；「登入中…」狀態。
   - Android 版加一句：「之前用 iPhone、只綁了 Apple 帳號？請先在 iPhone 的設定裡再綁一個 Google 帳號。」
3. S14-03 局部：「這個帳號沒有備份過牧場」加「換一個帳號」「開新牧場」；登入取消或失敗。
4. S14-04 歡迎回來：照舊，說明文字改成「牧場已經回到這支手機，舊手機已經登出。」
5. S14-05 舊手機：「牧場已經在另一支手機登入」加「找回我的牧場」「開新牧場」。
   - 原本的「如果不是你做的，請聯絡我們」改成「如果不是你做的，請先檢查那個 Apple 或 Google 帳號的安全，再登入拿回牧場。」

其他受影響的地方
- S15-03 帳號失效：按鈕「輸入移轉碼」改成「找回我的牧場」。
- 提醒卡：升到 Lv2 的慶祝卡之後出現一次，「把牧場備份起來，換手機或手機壞了都找得回來」加「現在備份」「之後再說」。
- G-02 頂列齒輪：還沒綁定、也還沒打開過「備份牧場」頁時，齒輪上有一個小點。
- `scope.md`、`README.md`、錯誤文案（第 7 節）：拿掉移轉碼的內容，README 的定案清單拿掉「移轉碼 8 個字」。

**不做**
- 企劃書、決定紀錄：ceo 已經改好。
- 協定與程式：M3 交給 cow-back、cow-app（`docs/design/m3-backlog.md`）。
- Apple、Google 自己跳出來的登入視窗：那是系統畫面，不用畫。只畫我們自己的頁面和「登入中…」。

## 驗收條件

- [ ] 上面每個狀態都有圖，430、390 各一張；360、320 照舊只量測。
- [ ] 設計稿、`scope.md`、`README.md` 裡不再出現「移轉碼」。
- [ ] 兩顆登入按鈕一樣大，不用捲動就看得到。
- [ ] 登入按鈕照官方樣式，不套我們的 Q 版樣式：
  - Apple 的用黑底白字。
  - Google 的用白底加細外框。
  - 圓角可以配合我們的按鈕。
- [ ] 設計稿上不自己畫 Apple 或 Google 的標誌，也不把官方標誌檔放進 repo。標誌的位置畫佔位方塊，旁邊註明「實作時用官方按鈕」。
- [ ] `cowcheck` 照舊通過（第 11 輪定案的牛逐字相同）。
- [ ] 沒改到的畫面，圖檔跟現在逐位元相同。

## 限制

- 記憶體安全規則照舊（`free -m` 2000 MB 以上、`systemd-run` 包起來、一次一個瀏覽器）。
- 假資料不用真實的 email 或姓名。畫面本來就不顯示 email。

## 回報方式

1. 這次不用先回計畫。清單有不同意的地方，或你覺得少了哪個狀態，先講再畫。
2. 改在 `ui/m2-set`（PR #11）上。改完回報：新增與拿掉的頁面 ID、四種寬度的量測結果。
3. 使用者對其他畫面的核准照常進行。S13、S14 重畫完再請使用者看這兩組。
4. 需要使用者決定、但不屬於畫面的事，回報 ceo。
