# 裁示與決定紀錄

新裁示要取代舊的時，舊的那筆不刪，只標「已被取代」並註明是被哪一筆取代。每筆都附日期與原話。

## 2026-09-30 使用者裁示

### D1 股票系統：兩種都要，分階段做

- 原話：使用者選「兩種都要，分階段做（推薦）」。原本的構想是「說不定我們能加入一個股票價格系統進去更有趣」。
- 內容
  - 第一版：牛奶、牛肉的收購價像股票一樣漲跌，有走勢圖和新聞事件，玩家可以先存貨、等好價錢再賣。牛奶有新鮮度。
  - 第二階段：開放牧場股市。公司是虛構的，玩家用遊戲幣投資、領股利，股價跟行情連動。
- 影響：企劃書要附牧場股市的草案；行情引擎要能支援多種商品。

### D2 第一版就連線

- 原話：使用者選「一開始就連線」。這個選項已經寫明要架伺服器、做帳號和防作弊、每月有主機費，沒網路就不能玩。
- ceo 原本推薦先做單機，使用者沒有採用。
- 影響：所有帳由伺服器算；M1 原型就要有伺服器和電腦假玩家；上架前要準備主機、資料庫、帳號、刪除流程和隱私權政策。

### D3 第一版免費，不放廣告和內購

- 原話：使用者選「第一版免費，不放廣告和內購（推薦）」。
- 遊戲裡預留「看廣告換加速」和「買裝飾」的位置，上架後看數據再決定第二版要不要開。

### D4 只做 app；前端用 Flutter，後端用 FastAPI；agent 分批開

- 原話：「我們是要app不要網站，應該是flutter比較好吧，然後後端框架如何做選擇呢？有比python fast更好的選擇嗎」。ceo 說明後，使用者回「好聽你的」。
- 內容
  - 只做 iOS 和 Android app，另外做隱私權政策和刪除帳號申請兩頁說明（商店規定）。
  - 內部試玩可以把 Flutter 輸出成網頁，在家裡 Wi-Fi 用 Safari 看，這不公開。
  - app 用 Flutter，牧場畫面用 Flame；後端以 FastAPI 為主。
  - M0、M1 由 ceo 做；M2 開 cow-ui，M3 開 cow-back 和 cow-app，M4 開 cow-release。
- 依據
  - Flutter 官方文件：Impeller「is the only supported rendering engine on iOS」，Android 則是「enabled by default on Android API 29+」。
  - 官方休閒遊戲工具包收錄 `in_app_purchase`、`google_mobile_ads`、`games_services`。
  - Flame 1.38.2，MIT 授權。
  - 遊戲對伺服器的負擔小，FastAPI 可以沿用 connect4 的部署和發版流程，也能跟 Python 經濟模擬共用同一份行情程式。
- 沒選的方案
  - Capacitor＋Vue：不做網站之後，「網站和 app 共用程式」的好處就沒了；內購和廣告也要靠社群套件。
  - Unity：以圖形編輯器操作為主，AI session 不容易可靠地修改。
  - Godot：要做大量選單和圖表比較費工。
  - Go、Rust 後端：遊戲的負擔用不到它們的速度，開發也比較慢。
  - Serverpod（Dart）和 Nakama：M0 會拿來跟 FastAPI 比較。

### D5 GitHub repo 公開

- 原話：「repo公開就好，這樣潛了github actions就不要錢了」。
- 內容：repo 是 `EdwardLeeee/cow-farm`，公開。主分支是 `main`，2026-09-30 建立。
- 依據：GitHub 文件寫明，公開 repo 使用標準 GitHub 代管機器「free」，包含打包 iOS 用的 Mac 機器；私有 repo 的 Mac 機器每分鐘 US$0.062。
- 影響
  - 企劃書、經濟數值、伺服器程式任何人都看得到。
  - 金鑰和憑證只放在 GitHub secrets 與使用者的備份，不進 repo。
  - repo 名稱之後可以改成正式遊戲名，GitHub 會自動轉址。

### D6 畫風選 A 圓潤Q版，牛的造型重畫

- 原話：「選a 但我不喜歡牛的樣子 要給我另外的設計」（看過 `design/artboards/round1/` 的四張圖之後）。
- 內容：整體畫風採用 A 圓潤Q版，牛的造型在第 2 輪重新提案（`design/artboards/round2/`）。摘要記在 `design/spec.md`。

## 設計底線（ceo 以總設計師身分決定，使用者 2026-09-30 核准計畫時一併同意）

- **原創**
  - Apple 4.1：「Don't simply copy the latest popular app … or make some minor changes to another app's name or UI and pass it off as your own.」
  - 名字、畫風、畫面配置都自己做，不用「養豬場」「MIX」字樣。
  - 股市裡的公司全部虛構（Apple 5.2.1）。
- **牧場名稱**：只能從詞庫組合挑，不開放自由打字。這樣就不需要 Apple 1.2 要求的過濾、檢舉、封鎖功能。
- **帳號**
  - 第一次打開就自動建立訪客帳號，換手機時用移轉碼搬資料。
  - app 內可以刪除牧場，另外有網頁刪除入口。依據是 Apple 5.1.1(v)：「If your app supports account creation, you must also offer account deletion within the app.」Google Play 也有同樣要求。
  - 只用自己的帳號系統，就不必加 Apple 登入（Apple 4.8）。
- **不賣用真錢買的隨機商品**：因此不受 Apple 3.1.1 和台灣機率揭露規定管轄。
- **牛肉用「出貨」呈現**，畫面上不出現屠宰。
- **所有帳都由伺服器算**，改手機時間或改程式都不能多賺。
- **行情**
  - 價格由基本價、時段波動、新聞事件、全服最近的賣出量決定，而且會回到基本價。
  - 每位玩家的影響依線上人數換算並設上限；人少時由電腦買家補足需求。

## 技術決定

（M0 技術研究完成後補上：數字、選擇與沒選的理由。）
