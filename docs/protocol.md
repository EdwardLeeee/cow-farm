# cow-farm 協定 v2（手機 ↔ 伺服器）

- 狀態：**v2 草稿**（2026-10-02，cow-back）。ceo 審過以後 cow-app 才照著寫。伺服器分 PR 3–10 實作，每一項由哪個 PR 做、做好了沒，看第 0 節的表。
- 這份文件由伺服器端（cow-back）負責；伺服器、`docs/design/m3-backlog.md` 跟這份不一致時，以這份為準，並通知 cow-back 修正。
- 依據：使用者裁示 D22–D27（`docs/decisions.md`）、核准的設計稿 `design/m2/`（錯誤文案在 `design/m2/scope.md` 第 7 節，字串表在 `design/m2/i18n/`）、ceo 2026-10-02 對 cow-back 計畫的裁示。
- 還沒上架，v2 直接改，不保留 v1 的舊欄位。**上架以後只能新增欄位，不能改名、改型別或刪除**（api-evolution）。
- app 要忽略不認得的欄位和不認得的 WebSocket 訊息類型：伺服器之後只會「加」。
- **伺服器不送給玩家看的文字**（D25：繁中、英文、泰文）。名字、新聞、錯誤都送代碼，app 用字串表依玩家的語言顯示。例外是玩家自己取的牧場名（資料，原樣顯示）。

## 0. v2 改了什麼（給 app）

| # | 項目 | v1（M1 原型） | v2 | PR |
|---|---|---|---|---|
| 1 | 顯示用的中文 | `type_name`、`tier_name`、新聞 `title`、`unit`、排行榜 `name`（「電腦 」前綴）、借種 `owner_name` | 全部拿掉。app 用 `type`、`tier`、`breed`、新聞 `code` 查字串表 | 3，已做 |
| 2 | 錯誤 | app 直接顯示伺服器的 `message` | 依 `code` 顯示字串表的文案（1.4 節的表有每個碼的 key）；`message` 只供除錯 | 3，已做 |
| 3 | 牧場 | 只有 `ranch_name` 字串 | 排行榜、借種上架、借種紀錄、借種通知都用同一個「牧場」物件（1.6 節） | 3，已做 |
| 4 | 排行榜 | 沒有等級 | 每列帶場主等級 | 3，已做 |
| 5 | 新聞 | 中文標題 | 代碼 `code`、參數 `params`、幅度 `pct` | 3，已做 |
| 6 | v0.1 相容欄位 | 還留著 | 拿掉：`shop.calf_price`、`breed`（`first_free`）、`cows[].ready_at`、`breed_ready`、配種的 `fee`／`normal_fee`／`first_free`、`POST /v1/buy_calf`、錯誤碼 `gone`、`breed_cooldown` | 3，已做 |
| 7 | 行情 | `/v1/market` 每種商品帶 24 小時走勢 `history` | 拿掉 `history`（D24 沒有走勢圖）；`/v1/market/history` 不變 | 3，已做 |
| 8 | WS `hello` | `protocol: 1` | `protocol: 2` | 3，已做 |
| 9 | 圖鑑 | 12 格（用途 × 稀有度） | 24 個品種（`breed`），附第一次發現的時間 | 4，已做 |
| 10 | 牛 | — | `cows[].breed`（品種代號），app 顯示「品種名 #id」 | 4，已做 |
| 11 | 建立牧場 | 伺服器從詞庫隨機取名 | 玩家自己取：`POST /v1/session {ranch_name}`，取好名字才建立（D23） | 5，已做 |
| 12 | 電腦牧場名 | 中文字串 | 三組詞的編號 `name_words`，app 照 `namegen.pattern` 用玩家的語言組 | 3，已做（PR 5 起伺服器直接存編號，協定不變） |
| 13 | 借種費 | 主人從 300／800／2,000／5,000 選 | 系統依公牛現在的體重和稀有度算（D26）；借種要帶預覽看到的價格，變了回 `price_changed` | 6，已做 |
| 14 | 借種紀錄 | 沒有 | `GET /v1/stud/log` | 7，已做 |
| 15 | 維護 | 沒有 | `GET /v1/status`、`maintenance` 物件、503 `maintenance`、WS 4503 | 8 |
| 16 | 帳號 | 只有訪客 token | 綁定、解除、找回、換回、刪除牧場（D22）；舊手機收到 `signed_in_elsewhere` | 9 |
| 17 | 遊戲時間 | 伺服器關著時暫停 | 倍率 1（正式版）照真實時間走，關機那段也算；試玩倍率照舊暫停 | 10 |

PR 3–7 已做；PR 8–10 還沒做（2026-10-02）。每個 PR 合併時更新這張表的「PR」欄。

**存檔不相容**：PR 4 起存檔格式改變，舊的世界（v0.2）伺服器會拒絕啟動。原型階段直接清掉資料庫重來（`backend/README.md`）。

## 1. 通則

### 1.1 連線

| 項目 | 值 |
|---|---|
| 網址 | 區網試玩：`http://<開發機區網 IP>:8787`。正式主機 M4 定 |
| 格式 | 請求與回應都是 JSON（UTF-8） |
| 認證 | 除了 `POST /v1/session`、`POST /v1/account/recover`、`GET /v1/status`，都要帶 `Authorization: Bearer <token>`。WebSocket 見第 7 節 |
| CORS | 開放所有來源（token 放 header、不用 cookie） |

### 1.2 時間

- **時間欄位都是「遊戲時間」的 Unix 秒數**（數字，可以有小數）。例外：名字以 `_real` 結尾的欄位是**現實時間**的 Unix 秒數（維護時間、帳號綁定時間）。
- 遊戲時間 = 開服遊戲時間 + (現實時間 − 開服現實時間) × 倍率。倍率由伺服器的 `COWFARM_TIME_SCALE` 決定（試玩 144：遊戲 1 天 = 現實 10 分鐘；正式版 1）。
- 每個回應都附：

  | 欄位 | 型別 | 說明 |
  |---|---|---|
  | `server_time` | number | 伺服器處理這個請求時的遊戲時間 |
  | `real_time` | number | 當時的現實 Unix 秒數 |
  | `time_scale` | number | 倍率 |

- **手機不送任何時間**，伺服器也不看手機時間。倒數、奶桶動畫由手機換算：
  `現在的遊戲時間 ≈ server_time + (手機單調時鐘的經過秒數) × time_scale`。經過秒數用單調時鐘（Dart 的 `Stopwatch`），不要用手機的牆上時間。
- PR 10 之後，倍率 1 時遊戲時間跟現實時間只差開服時的零頭（不到 1 分鐘）。app 一律照手機的時區顯示。
- **伺服器關著的那段**（PR 10）：
  - 倍率 1（正式版）：照真實時間走，關機那段也算。重開後奶桶照樣累積、田裡照樣長、市場補跑那段的行情；電腦假玩家略過那段（不補做關機期間的動作）。
  - 倍率不是 1（試玩）：關機期間暫停，重開後從上次的時間接著走（試玩時晚上關機，隔天牧場不會老 48 天）。

### 1.3 會改變狀態的請求：`request_id`

- 下面這些**必須**帶 `request_id`（UUID 字串）：`POST /v1/collect`、`/v1/sell`、`/v1/ship`、`/v1/breed`、`/v1/upgrade`、`/v1/shop/buy`、`/v1/field/assign`、`/v1/field/recall`、`/v1/field/harvest`、`/v1/field/expand`、`/v1/stud/list`、`/v1/stud/unlist`、`/v1/stud/borrow`。
- `POST /v1/session` 可以帶（建議帶），規則見 2.1 節。
- 每個「使用者動作」產生一個新的 UUID；網路逾時要重送時，**用同一個 request_id** 重送。
- 同一位玩家、同一個 request_id 重送：伺服器不再執行，直接回傳**第一次的回應本文**（HTTP 200，內容逐字相同，包括當時的 `server_time`）。重送拿到的 `state` 可能是舊的，之後請再 `GET /v1/state`。
- 只記住**成功**的結果。失敗（4xx）沒有改變任何狀態，用同一個 request_id 重送會重新判斷。
- 同一個 request_id 拿去做別種動作：回 `409 request_id_reused`。
- request_id 以玩家為範圍，保存 7 天（現實時間）。

### 1.4 錯誤

一律是 HTTP 4xx（伺服器錯誤 500、維護中 503），本文：

```json
{"error": {"code": "not_enough_coins", "message": "金幣不夠", "detail": {"need": 1000, "have": 414}}}
```

| 欄位 | 說明 |
|---|---|
| `code` | 穩定的英文代碼。**app 用它查字串表**（下表「app 文案」欄），上架以後不改名 |
| `message` | 繁中，只供除錯和日誌，**不要顯示給玩家** |
| `detail` | 選填，有額外資訊時才有 |

「app 文案」欄：`err.*`、`notEnoughCoins` 這類是 `design/m2/i18n/zh-Hant.json` 的 key；「畫面 Sxx」是設計稿的整頁狀態，不是提示條。`unknownError` 是通用的「操作失敗，請再試一次」（scope.md 第 7 節：玩家碰不到的錯誤碼都用它）。網路失敗（重試 3 次）是 `networkError`，不是錯誤碼。

| HTTP | code | 什麼時候 | detail | app 文案 | PR |
|---|---|---|---|---|---|
| 400 | `bad_request` | 欄位缺少、型別不對（數字不接受字串或 true/false）、request_id 不是 UUID、qty ≤ 0 | `fields`（格式錯誤時） | `unknownError` | |
| 400 | `invalid_pair` | 配種、借種不是「公牛 + 母牛」 | | `unknownError` | |
| 400 | `invalid_name` | 牧場名不能用（2.2 節） | `reason`、`width`、`char` | 見 2.2 節 | 5 |
| 400 | `sign_in_failed` | Apple／Google 的登入憑證驗證不過、換回的憑單無效或過期 | `reason` | `s13.toast.failed`（S13-12、S14-08） | 9 |
| 401 | `unauthorized` | 沒帶 token、token 無效（例如牧場已刪除、資料庫清掉） | | 畫面 S15-03 | |
| 401 | `signed_in_elsewhere` | 這個牧場已經在另一支手機找回，這支手機的 token 失效 | | 畫面 S14-05 | 9 |
| 404 | `cow_not_found` | 牛的 id 不在自己的牧場 | `cow_id` | `err.cow_not_found` | |
| 404 | `field_not_found` | 沒有這塊田 | `field` | `err.field_not_found` | |
| 404 | `listing_not_found` | 借種上架不存在（被借走、下架，或下架的不是自己的） | `listing_id` | `err.listing_gone` | |
| 404 | `listing_gone` | 上架的公牛已經不能借了（很少見） | | `err.listing_gone` | |
| 404 | `account_not_linked` | 找回牧場時，這個帳號沒有綁任何牧場 | `provider` | 畫面 S14-03 | 9 |
| 404 | `not_linked` | 解除綁定時，這個牧場沒有綁這種帳號 | `provider` | `unknownError` | 9 |
| 404 | `not_found` | 網址不存在 | | `unknownError` | |
| 405 | `method_not_allowed` | 方法不對 | | `unknownError` | |
| 409 | `not_enough_coins` | 金幣不夠 | `need`、`have`（整數） | `notEnoughCoins`（`{n}` = need − have） | |
| 409 | `not_enough_stock` | 倉庫裡沒有這麼多牛奶／牛肉／稻米 | `have`、`want` | `err.not_enough_stock` | |
| 409 | `pen_full` | 牛舍滿了（買牛、配種、借種都要有空格給小牛） | `slots` | `penFull` | |
| 409 | `cow_not_adult` | 小牛還沒長大 | `cow_id`、`until` | `err.cow_not_adult` | |
| 409 | `already_bred` | 這頭牛這輩子已經配過種 | `cow_id` | `err.already_bred` | |
| 409 | `cow_in_field` | 牛在田裡工作 | `cow_id`、`field` | `err.cow_in_field` | |
| 409 | `cow_listed` | 公牛正在借種市場上架 | `cow_id`、`listing_id` | `err.cow_listed` | |
| 409 | `cow_not_in_field` | 叫回的牛沒有在田裡 | `cow_id` | `err.cow_not_in_field` | |
| 409 | `no_free_field` | 派牛時沒指定田號，而且沒有空田 | | `err.no_free_field` | |
| 409 | `field_occupied` | 這塊田已經有牛 | `field`、`cow_id` | `err.field_occupied` | |
| 409 | `not_an_ox` | 只有耕牛能下田 | `cow_id` | `unknownError` | |
| 409 | `not_a_bull` | 只有公牛能上架借種 | `cow_id` | `unknownError` | |
| 409 | `own_listing` | 不能借自己上架的公牛 | | `unknownError` | |
| 409 | `price_changed` | 借種費跟你預覽時看到的不一樣（公牛長大了） | `price`（現在的價）、`expected`（你送的價） | S18-12（`s18.feeChangedTitle`、`s18.feeChangedBody` 的 `{old}` = expected、`{now}` = price） | 6 |
| 409 | `max_level` | 已經是最高級 | | `err.max_level` | |
| 409 | `not_yet_available` | 第一次擴建還沒開放（教學第 15 分鐘開放） | `open_at` | `err.not_yet_available`（`{time}` = open_at − 現在） | |
| 409 | `account_in_use` | 要綁的帳號已經綁了別的牧場 | `provider`、`ranch`、`switch_ticket`、`ticket_expires_at_real` | 畫面 S13-08 | 9 |
| 409 | `provider_already_linked` | 這個牧場已經綁了另一個同種帳號（例如已綁一個 Apple，又要綁另一個 Apple） | `provider` | `unknownError` | 9 |
| 409 | `request_id_reused` | 同一個 request_id 用在別的動作 | `endpoint` | `unknownError` | |
| 409 | `rejected` | 其他無法執行的情況（理論上不會出現） | | `unknownError` | |
| 500 | `internal` | 伺服器錯誤，狀態沒有改變，可以用同一個 request_id 重送 | | `err.internal` | |
| 503 | `maintenance` | 維護中 | `ends_at_real` | 畫面 S16-01 | 8 |

- v2 拿掉的：`gone`（`/v1/buy_calf` 整個拿掉，現在打它是 404 `not_found`）、`breed_cooldown`（v0.2 起就不會出現）。
- 表裡的錯誤碼上架以後不改名、不換 HTTP 狀態碼；之後只會加新的碼。app 收到不認得的碼，一律顯示 `unknownError`。
- 401 有兩種：`unauthorized` 和 `signed_in_elsewhere`。帳號綁定、找回的錯誤都**不用 401**，免得 app 誤以為 token 失效。

### 1.5 數字

- 金幣、費用、估值都是**整數**。價格、數量是小數（數量最多 6 位小數）。
- 牛奶單位是「瓶」，牛肉和稻米是「公斤」（單位的字在字串表）。倉庫裡的牛奶、田裡的稻米是連續累積的，數量可能有小數。
- 要「全部賣出」時，送 `GET /v1/state` 裡的 `warehouse.milk_total`（或 `beef_total`、`rice_total`）原值；伺服器把「和庫存相差 0.000001 以內」視為全部。
- 機率都是 0–1 的小數（精確值，加總是 1，最後幾位可能有浮點誤差）。

### 1.6 共用物件

#### 牧場（PR 3）

排行榜、借種上架的主人、借種紀錄的對方、借種通知的借方，都用這個形狀：

```json
{"player_id": 31, "name": "小花的快樂牧場", "name_words": null, "is_bot": false, "level": 3}
{"player_id": 4, "name": null, "name_words": [8, 0, 5], "is_bot": true, "level": 6}
```

| 欄位 | 型別 | 說明 |
|---|---|---|
| `player_id` | int／null | 牧場編號；公營種牛站（見下）是 null |
| `name` | string／null | 真人自己取的牧場名，原樣顯示；電腦牧場是 null |
| `name_words` | int[3]／null | 電腦牧場名的三組詞編號（各 0–11）；真人是 null |
| `is_bot` | bool | 電腦假玩家（含公營種牛站） |
| `level` | int／null | 場主等級；公營種牛站是 null |

app 怎麼顯示：
- 名字：真人用 `name`；電腦用字串表 `namegen.pattern`，把 `{first}`、`{second}`、`{third}` 換成 `namegen.first.<name_words[0]>`、`namegen.second.<name_words[1]>`、`namegen.third.<name_words[2]>`（玩家目前的語言），前面加 `botPrefix`（例「電腦 露珠溪谷牧野」）。
- 編號：`#` + `player_id` 補零到 4 位（`#0031`），超過 9999 照實顯示（`#12345`）。`player_id` 是 null 就不顯示編號。名字太長時只截名字，「電腦」和 #編號一定看得到（S18-13）。
- **公營種牛站**：電腦系統固定上架的 3 頭一般公牛（第 4 節），沒有主人。`player_id`、`level` 是 null，`is_bot` true，`name_words` 由伺服器給（每筆上架一組，由上架編號決定，重啟後不變），看起來跟其他電腦牧場一樣（「電腦 ○○牧場」，沒有 #編號）。
- 對方的牧場已經刪除時，借種紀錄裡的 `ranch` 是 null（4.6 節）。

#### 品種（PR 4）

`breed` 是品種代號，跟 `design/m2/src/cow/breeds.js` 的 key 一樣；名字和介紹查字串表 `breed.<breed>.name`、`breed.<breed>.intro`。24 種 = 3 種用途 × 8 種特徵組合（企劃書 4.5）。特徵組合是 3 個位元：1 = A 長毛、2 = B 淡色、4 = C 光澤；稀有度 = 位元數。

| 特徵組合 | 稀有度 | 乳牛 `dairy` | 耕牛 `dual` | 肉牛 `beef` |
|---|---|---|---|---|
| 0（無） | 0 一般 | `holstein` | `yellow` | `angus` |
| 1（A） | 1 優良 | `fluffyHolstein` | `highland` | `galloway` |
| 2（B） | 1 優良 | `jersey` | `milkTea` | `charolais` |
| 3（A＋B） | 2 稀有 | `cottonCream` | `cottonCandy` | `whiteFleece` |
| 4（C） | 1 優良 | `glossBlack` | `buffalo` | `wagyu` |
| 5（A＋C） | 2 稀有 | `velvetBlack` | `shaggyBuffalo` | `fluffyWagyu` |
| 6（B＋C） | 2 稀有 | `chocolate` | `honey` | `whiteWagyu` |
| 7（A＋B＋C） | 3 傳說 | `strawberry` | `goldenEar` | `starry` |

- 用途 `type`：`dairy` 乳牛、`dual` 耕牛（v0.1 叫兼用，協定值沿用）、`beef` 肉牛。用途、稀有度的名字查字串表。
- 伺服器的測試會讀 `breeds.js` 比對這張表。

#### 借種費（PR 6）

```json
{"price": 540, "per_kg": 1.1, "kg": 495.0, "at_max": true}
```

| 欄位 | 說明 |
|---|---|
| `price` | 借種費（幣，整數）＝ `kg` × `per_kg`，四捨五入到 10 幣（D26） |
| `per_kg` | 每公斤價格，看稀有度：一般 1.1、優良 2.75、稀有 6.6、傳說 16.5（數字暫定，ceo 跑完經濟模擬後定案） |
| `kg` | 公牛現在的體重（公斤，公牛比母牛重 1.1 倍，小數 2 位） |
| `at_max` | 已經長到最壯，借種費不會再漲 |

- 價格跟著公牛長大自動漲（S04-04「{tier}（每公斤 {rate} 幣）× {kg} 公斤，長大後會再漲／已經長到最壯」）。
- 公營種牛站的公牛照同一個公式，用那種用途公牛的最佳體重算：一般乳牛 275 公斤 → 300 幣、耕牛 495 公斤 → 540 幣、肉牛 880 公斤 → 970 幣（`at_max` true）。站上的公牛是 C 級基因，少數會顯現特徵，那種就照稀有度的每公斤價格算。

## 2. 帳號與牧場

### 2.1 `POST /v1/session` 建立牧場（PR 5）

流程（D23；ceo 2026-10-02 選方案 A）：S14-01 按「開新牧場」→ S02 取名 → 按「就叫這個」→ S01-03「建立牧場中」（等這個請求）→ 成功：S02-02 歡迎卡；`invalid_name`：回 S02，顯示 S02-05 的提示。**取好名字才建立**，伺服器沒有「還沒取名」的牧場。

請求：

```json
{"ranch_name": "小花的快樂牧場", "request_id": "3f1c2a9e-…"}
```

回應（`state` 形狀同 `GET /v1/state`，S02-02 的開局牛、金幣、奶桶都從這裡拿）：

```json
{"server_time": 1791129600.0, "real_time": 1790736267.97, "time_scale": 144.0,
 "token": "gJ77xMDokb7Gk8zg69N-22Jvvlo-1PkIhQB6TdpNAsM", "player_id": 31, "ranch_name": "小花的快樂牧場",
 "created": true, "state": {"…": "同 GET /v1/state"}}
```

| 欄位 | 說明 |
|---|---|
| `ranch_name` | 去掉前後空白之後的名字（伺服器存的就是這個） |
| `token` | 登入憑證（43 字元）。放手機的安全儲存區。伺服器只存它的 SHA-256 |
| `player_id` | 整數；顯示成 #編號（1.6 節） |
| `created` | 這次有沒有建立新牧場（重送時是 false，見下） |

- 錯誤：`invalid_name`（2.2 節）、`bad_request`（沒有 `ranch_name` 或不是字串）。失敗時什麼都沒建立。
- `request_id`（選填，建議帶）：網路逾時重送時用同一個。10 分鐘內（現實時間）同一個 request_id 重送：回**同一個牧場**（名字以第一次為準），發一個新的 token，前一次的 token 作廢（反正手機沒收到），`created` 是 false。不帶就每次都建新牧場。
- 收到 `401 unauthorized`（例如資料庫清掉了）：app 顯示 S15-03，玩家選「找回我的牧場」或「開新牧場」。

### 2.2 牧場名的規則（D23；PR 5）

伺服器以這裡為準。app 在送出前用同一套規則檢查並即時顯示字數；伺服器會再檢查一次。

1. **去掉前後的空白**：Unicode 的 White_Space 字元（U+0009–U+000D、U+0020、U+0085、U+00A0、U+1680、U+2000–U+200A、U+2028、U+2029、U+202F、U+205F、U+3000）。中間的空白保留。**不做正規化**（NFC 等），照送來的字元算。
2. **逐個字元（Unicode code point）檢查**，有下面這些就拒收：
   - emoji（`reason: "emoji"`）：
     - Unicode emoji-data 的 Extended_Pictographic（含官方替未來 emoji 保留的區段，所以新的 emoji 也擋得到）；
     - 區域指示符 U+1F1E6–U+1F1FF（國旗）、膚色 U+1F3FB–U+1F3FF；
     - U+FE0F（emoji 樣式）、U+20E3（鍵帽）、U+200D（ZWJ）、tag 字元 U+E0020–U+E007F。
     - 結果：© ® ™ ‼ 和 ★ ♪ ♥ 這類符號都在 Extended_Pictographic 裡，算 emoji；☆（U+2606）不在，可以用。數字、`#`、`*` 可以用（鍵帽 1️⃣ 有 U+FE0F／U+20E3，不行）。
     - 區間表：`backend/server/data/extended_pictographic.json`（Unicode 13.0 的 emoji-data.txt，`backend/scripts/gen_name_tables.py` 產生並核對 SHA-256），app 可以直接拿去用。
   - 不能用的字元（`reason: "bad_char"`）：這是為了顯示安全，不是內容過濾。
     - 控制字元（類別 Cc），以及在中間的換行、換段分隔 U+2028、U+2029；
     - 雙向控制字元 U+061C、U+200E、U+200F、U+202A–U+202E、U+2066–U+2069（會讓後面的 #編號倒過來顯示）；
     - 私用區（Co，例如 U+F8FF 在 iPhone 顯示成 Apple 標誌、在 Android 是方塊）、代理字元（Cs）、還沒指派的字元（Cn）。
3. **寬度**：逐個字元，類別 Mn、Me、Cf 算 0（例如泰文的上下標記號），East Asian Width 是 W 或 F 算 2（中文字、全形符號），其他算 1（英文字母、數字、泰文的子音和母音）。總共 **2–16**，也就是最多 8 個中文字。
   - 類別、East Asian Width、「還沒指派」都以 **Unicode 13.0** 為準（伺服器的 Python 3.10 內建的 unicodedata）。W／F 的範圍另外把漢字區塊補到區塊結尾。完整區間跟 `design/m2/src/js/namewidth.js` 的 `WIDE` 一樣（伺服器測試會比對兩邊）。
   - 例：「晨光河畔牧場」12、「MorningRiverFarm」16、「ฟาร์ม」4（์ 是 Mn）、「ＡＢ」4（全形）、「小花牧場🐮」→ emoji。
4. **先查字元、再查寬度**：有不能用的字元時回報第一個（`emoji` 或 `bad_char`）；字元都可以用，才看 `too_short`、`too_long`。
5. 名字不必唯一，顯示時加 #編號（1.6 節）。不做不雅字過濾、檢舉、封鎖。

`invalid_name` 的 detail 與 app 文案：

| `reason` | 什麼時候 | app 文案 |
|---|---|---|
| `too_short` | 去掉前後空白後寬度 < 2（含全是空白） | `s02.errShort` |
| `too_long` | 寬度 > 16 | `s02.errLong` |
| `emoji` | 有 emoji | `s02.errEmoji` |
| `bad_char` | 有不能用的字元 | `s02.errChar`「名字裡有不能用的字」（ceo 2026-10-02：cow-ui 會加；加好之前 app 用 `s02.errEmoji`） |

```json
{"error": {"code": "invalid_name", "message": "名字不能用表情符號", "detail": {"reason": "emoji", "width": 10, "char": "U+1F42E"}}}
```

- `width`：去掉前後空白後的寬度（照第 3 點算，不能用的字元也照算）；`char`：第一個不能用的字元（`U+XXXX`），沒有就不給。
- 測試向量：`backend/server/data/name_cases.json`（37 個名字和伺服器的答案 `ok`、`reason`、`width`），app 和 i18ncheck 拿去跑，確認三邊算得一樣。規則改了由 `backend/tests/test_ranchname.py` 重產。

### 2.3 `GET /v1/state` 整個牧場

回應（節錄；`cows` 只列兩頭；數字會隨經濟參數調整而不同）：

```json
{
 "server_time": 1791141900.0, "real_time": 1790771411.05, "time_scale": 144.0,
 "player_id": 31, "ranch_name": "小花的快樂牧場",
 "coins": 3300,
 "level": 2, "level_progress": {"earned": 594, "level_at": 500, "next_at": 1500},
 "cows": [
  {"id": 2, "type": "dual", "bull": true, "tier": 0, "breed": "yellow", "stage": "adult",
   "born_at": 1791129600.0, "adult_at": 1791130800.0, "age_h": 3.42,
   "milk_per_h": 0.0, "milk_frac": 1.0, "weight_kg": 52.78, "beef_quality": 1.0, "ship_value": 614,
   "bred": false, "working": true, "field": 0, "listed": null, "can_breed": false, "can_ship": false, "can_work": false,
   "rice_per_h": 11.0, "grade_probs": {"A": 0.137323, "B": 0.492535, "C": 0.370142}, "origin": "start",
   "stud_fee": {"price": 60, "per_kg": 1.1, "kg": 52.78, "at_max": false}},
  {"id": 3, "type": "dairy", "bull": true, "tier": 0, "breed": "holstein", "stage": "calf",
   "born_at": 1791131100.0, "adult_at": 1791134700.0, "age_h": 0.0,
   "milk_per_h": 0.0, "milk_frac": 0.0, "weight_kg": 0.0, "beef_quality": 1.0, "ship_value": 0,
   "bred": false, "working": false, "field": null, "listed": null, "can_breed": false, "can_ship": false, "can_work": false,
   "rice_per_h": 0.0, "grade_probs": null, "origin": "B", "stud_fee": null}
 ],
 "bucket": {"qty": 0.0, "by_tier": [0.0, 0.0, 0.0, 0.0], "capacity": 28.0, "per_hour": 70.0,
            "boost": {"mult": 5.0, "until": 1791133200.0}},
 "warehouse": {"capacity": 150.0, "used": 0.0, "milk_total": 0.0, "beef_total": 40.439815,
   "milk_lots": [],
   "beef_lots": [{"qty": 40.439815, "tier": 0, "cow_id": 1, "shipped_at": 1791141900.0, "quality": 0.75, "storage_factor": 1.0, "grade": "C"}],
   "rice_total": 33.0, "rice_lots": [{"qty": 33.0, "harvested_at": 1791141900.0, "quality": 1.0}]},
 "pen": {"slots": 6, "used": 3, "next_cost": 280, "next_open_at": null, "max_slots": 40},
 "upgrades": {
  "pen": {"level": 0, "cost": 280, "next_open_at": null, "slots": 6, "next_slots": 7},
  "bucket": {"level": 0, "cost": 200, "capacity": 28.0, "next_capacity": 42.0},
  "warehouse": {"level": 0, "cost": 300, "capacity": 150.0, "next_capacity": 225.0},
  "fresh": {"level": 0, "cost": 1500, "fresh_h": 6.0, "half_h": 48.0, "next_fresh_h": 9.0, "next_half_h": 60.0},
  "field": {"level": 0, "cost": 1800, "count": 1, "max": 12}},
 "shop": {"grades": [{"grade": "A", "price": 3200}, {"grade": "B", "price": 1700}, {"grade": "C", "price": 900}]},
 "codex": [{"breed": "holstein", "found_at": 1791129600.0}, {"breed": "yellow", "found_at": 1791129600.0}],
 "fields": [{"index": 0, "cow_id": 2, "rice": 33.0, "capacity": 88.0, "per_hour": 11.0}],
 "rice": {"in_fields": 33.0, "stock": 0.0, "per_hour": 11.0},
 "stud": {"listings": [], "income": 0},
 "account": {"links": []},
 "maintenance": null
}
```

頂層：

| 欄位 | 型別 | 說明 |
|---|---|---|
| `player_id`、`ranch_name` | int、string | 自己的牧場（顯示「ranch_name #編號」） |
| `coins` | int | 金幣 |
| `level` | int | 場主等級，只是顯示。累積收入（賣出牛奶、牛肉、稻米＋借種收入）≥ 500 × (2^(L−1) − 1) 就是 L 級：1 級 0、2 級 500、3 級 1,500、4 級 3,500… |
| `level_progress` | object | `earned` 累積收入、`level_at` 這一級的門檻、`next_at` 下一級的門檻（頂列經驗條） |
| `shop.grades[]` | array | 商店各等級 `{"grade": "A"｜"B"｜"C", "price"}`。錢不夠就停用按鈕。精確機率看 `GET /v1/shop` |
| `codex[]` | array | PR 4：已發現的品種 `{"breed", "found_at"}`，`found_at` 是第一次發現的遊戲時間（S09-03「第一次發現：{date}」）。牛一出生（或抽到、借種生下）就算發現，之後出貨也不會消失。共 24 種，沒出現在陣列裡的顯示剪影。「目前有 n 頭」由 app 數 `cows[]` |
| `fields[]`、`rice` | | 田地（見下） |
| `stud` | object | `listings` 自己上架的借種（形狀同 `GET /v1/stud` 的 `listings[]`）、`income` 借種收入累計（幣） |
| `account` | object | PR 9：`links[]` 綁定的帳號 `{"provider": "apple"｜"google", "linked_at_real"}`。空陣列 = 還沒備份（頂列齒輪的小點 G-10、S13-01「還沒備份」） |
| `maintenance` | object／null | PR 8：維護預告或維護中（第 6 節）；沒有是 null |

`cows[]` 每頭牛：

| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | int | 牛的編號（在自己的牧場裡唯一），送回伺服器時原樣送；畫面顯示「品種名 #id」 |
| `type` | string | 用途 `dairy`／`dual`／`beef` |
| `bull` | bool | true = 公牛（公牛不產奶） |
| `tier` | int | 稀有度 0 一般、1 優良、2 稀有、3 傳說 |
| `breed` | string | PR 4：品種代號（1.6 節） |
| `stage` | string | `calf` 還沒長大；`adult` 壯年；`old` 過了巔峰（母乳牛、耕牛：成年 48 遊戲小時後產奶／工作力開始下降；其他：過了最佳體重 24 小時、肉質開始下降） |
| `born_at` | number | 出生（抽到）的遊戲時間 |
| `adult_at` | number | 長大的遊戲時間（倒數用） |
| `age_h` | number | 出生後幾個遊戲小時 |
| `milk_per_h` | number | 這頭牛現在每小時產奶（瓶），**不含**新手期加倍。只有成年母乳牛大於 0。整座牧場的產量看 `bucket.per_hour` |
| `milk_frac` | number | 產奶（耕牛是工作力）是壯年的幾成（0.4–1；其他牛與小牛為 0） |
| `weight_kg` | number | 現在出貨可得的牛肉（公斤）；小牛為 0 |
| `beef_quality` | number | 年齡因素（0.6–1），過了最佳體重 24 小時後開始下降，影響評級機率 |
| `ship_value` | int | 現在出貨並立刻全部賣出的估計收入（幣）：評級用期望值，含市價、稀有度與這位玩家的滑價；小牛為 0 |
| `bred` | bool | 這輩子配過種了（公母都一樣，借出去也算）。true 就不能再配、不能上架 |
| `working` | bool | 在田裡工作 |
| `field` | int／null | 在第幾塊田（從 0 開始）；沒有下田是 null |
| `listed` | int／null | 在借種市場的上架編號；沒有上架是 null |
| `can_breed` | bool | 現在能配種（成年、沒配過、不在田裡、沒上架） |
| `can_ship` | bool | 現在能出貨（成年、不在田裡、沒上架） |
| `can_work` | bool | 現在能下田（成年耕牛、不在田裡、沒上架） |
| `rice_per_h` | number | 耕牛在田裡時每小時產稻米（公斤；其他牛 0） |
| `grade_probs` | object／null | 現在出貨評到 A／B／C 的精確機率；小牛 null |
| `origin` | string／null | 來源 `start` 開局、`A`／`B`／`C` 商店等級、`breed` 自己配種、`stud` 借種 |
| `stud_fee` | object／null | PR 6：成年、沒配過種的公牛現在的借種費（1.6 節，上架前就先算好給 S04-04）；其他牛 null |

v2 拿掉的：`type_name`、`tier_name`、`ready_at`、`breed_ready`（看 `can_breed`）、頂層的 `breed`（`first_free`）、`shop.calf_price`、`stud.prices`。

`bucket`（奶桶，離線也會累積，滿了就停）：

| 欄位 | 說明 |
|---|---|
| `qty` | `server_time` 當下奶桶裡的牛奶（瓶） |
| `by_tier` | 各稀有度的量 `[一般, 優良, 稀有, 傳說]`（稀有牛的牛奶賣價較高） |
| `capacity` | 容量 |
| `per_hour` | 整座牧場現在每小時產量，**已含新手期加倍**。app 用 `min(capacity, qty + per_hour × 經過的遊戲小時)` 推算 |
| `boost` | 新手期加倍 `{"mult": 5.0, "until": 遊戲時間}`；結束後是 `null`。跨過 `until` 時產量會變，app 可以在那時重抓 state |

`warehouse`（倉庫）：

| 欄位 | 說明 |
|---|---|
| `capacity` | 牛奶容量（瓶）；牛肉、稻米不佔這個容量 |
| `used` | 牛奶佔用量（含已經壞掉、還沒丟掉的） |
| `milk_total` | 可以賣的牛奶（瓶，不含壞掉的） |
| `beef_total` | 牛肉（公斤） |
| `milk_lots[]` | 每次收奶一批：`qty`、`tier`、`collected_at`、`freshness`（0–1，賣價乘上它；0 = 壞掉，下次收奶或賣出時丟掉）、`fresh_until`（新鮮度開始下降的時間）、`spoils_at`（壞掉的時間） |
| `beef_lots[]` | 每出貨一頭一批：`qty`（公斤）、`tier`、`cow_id`、`shipped_at`、`grade`（`A`／`B`／`C`）、`quality`（現在的賣價倍率，不含稀有度：評級倍率 × 倉庫衰減）、`storage_factor`（倉庫衰減那一部分） |
| `rice_total` | 稻米（公斤） |
| `rice_lots[]` | 每次收成一批：`qty`（公斤）、`harvested_at`、`quality`（0.7–1，賣價乘上它：收成後 72 遊戲小時內 1，之後慢慢降到 0.7，不會壞） |

賣出時一律**最舊的先賣**，最後一批可以只賣一部分。

`pen`（牛舍）與 `upgrades`：

| 欄位 | 說明 |
|---|---|
| `pen.slots`／`used`／`max_slots` | 格數、已用（= 牛的頭數）、上限 40 |
| `pen.next_cost` | 下次擴建的費用；`null` = 已滿級 |
| `pen.next_open_at` | 下次可以擴建的遊戲時間；`null` = 已經開放（只有第一次擴建要等到教學第 15 分鐘） |
| `upgrades.<kind>.cost` | 下一級的費用；`null` = 已滿級。kind 是 `pen`、`bucket`、`warehouse`、`fresh`、`field` |
| `upgrades.<kind>.level` | 目前等級（`pen` 是擴建過幾次；`field` 是開過幾塊新田） |
| `upgrades.bucket`／`warehouse` | `capacity` 目前容量、`next_capacity` 升級後容量 |
| `upgrades.fresh` | 冷藏：`fresh_h` 牛奶維持 100% 的小時數、`half_h` 降到 50% 的小時數，`next_*` 是升級後 |
| `upgrades.field` | 田地：`count` 目前幾塊、`max` 上限、`cost` 再開一塊的價格 |

`fields[]`（田地；開局 1 塊）：

| 欄位 | 說明 |
|---|---|
| `index` | 田的編號（從 0 開始），派牛時用 |
| `cow_id` | 在這塊田工作的耕牛；空田是 null |
| `rice` | `server_time` 當下田裡長好、還沒收的稻米（公斤）。牛叫回來後，已經長好的留在田裡，收成時一起收 |
| `capacity` | 這頭耕牛下田時，這塊田最多累積多少（公斤，長滿就停）；空田 null。畫面用 `rice ÷ capacity` 畫稻子的生長階段 |
| `per_hour` | 這塊田現在每小時長多少（公斤）。app 用 `min(capacity, rice + per_hour × 經過的遊戲小時)` 推算 |

`rice`：`in_fields` 田裡長好還沒收的稻米、`stock` 倉庫裡的稻米、`per_hour` 田裡所有耕牛現在每小時產量。

### 2.4 `POST /v1/collect` 收奶

請求：`{"request_id": "<uuid>"}`

回應（另外附完整的 `state`，這裡省略）：

```json
{"server_time": 1791129600.0, "real_time": 1790736267.98, "time_scale": 144.0,
 "collected": 20.0, "spoiled": 0.0, "warehouse_full": false, "coins": 100,
 "bucket": {"qty": 0.0, "by_tier": [0.0, 0.0, 0.0, 0.0], "capacity": 24.0, "per_hour": 55.0, "boost": {"mult": 5.0, "until": 1791133200.0}},
 "warehouse": {"…": "同 state.warehouse"},
 "state": {"…": "同 GET /v1/state"}}
```

| 欄位 | 說明 |
|---|---|
| `collected` | 這次從奶桶移到倉庫幾瓶 |
| `spoiled` | 順便丟掉幾瓶已經壞掉的牛奶 |
| `warehouse_full` | 倉庫滿了、奶桶還有剩（不是錯誤，回 200；S03-04） |

## 3. 市場、出貨、商店、配種、升級、田地

### 3.1 `POST /v1/sell/quote` 賣出前試算（不成交）

請求：`{"commodity": "milk", "qty": 15}`（`commodity` 是 `milk`、`beef` 或 `rice`；`qty` > 0）

```json
{"server_time": 1791129600.0, "real_time": 1790736267.99, "time_scale": 144.0,
 "commodity": "milk", "qty": 15.0, "avg_price": 12.538022, "total": 188, "market_price": 12.573385,
 "discount": 0.002812, "warn_big_order": false}
```

| 欄位 | 說明 |
|---|---|
| `qty` | 會賣出的量（超過庫存會回 `409 not_enough_stock`） |
| `avg_price` | 預估成交均價（每瓶／每公斤，含稀有度、新鮮度、評級、倉庫衰減、滑價） |
| `total` | 預估收入（整數幣） |
| `market_price` | 現在的市價 |
| `discount` | 滑價讓均價少了幾成（0.03 = 3%） |
| `warn_big_order` | `discount` ≥ 5% 時為 true：畫面提示「一次賣太多，均價會變差，要不要分批？」 |

試算用的是這一刻的市價；市價每遊戲分鐘更新一次，真的賣出時可能不同。

### 3.2 `POST /v1/sell` 賣出

請求：`{"commodity": "milk", "qty": 20, "request_id": "<uuid>"}`

```json
{"server_time": 1791129600.0, "real_time": 1790736268.0, "time_scale": 144.0,
 "commodity": "milk", "qty": 20.0, "avg_price": 12.526235, "total": 251, "market_price": 12.573385, "discount": 0.00375,
 "price_after": 12.573385, "next_unit_price": 12.479084, "coins": 351,
 "warehouse": {"…": "同 state.warehouse"}, "state": {"…": "同 GET /v1/state"}}
```

| 欄位 | 說明 |
|---|---|
| `qty`、`avg_price`、`total`、`market_price`、`discount` | 同 quote，是實際成交的數字；`total` 已經加進 `coins` |
| `price_after` | 賣完之後的市價。市價只在每遊戲分鐘的 tick 更新，所以這裡等於成交當下的市價；這筆賣量在下一個 tick 反映 |
| `next_unit_price` | 你現在再賣一單位（一般品質）拿得到的價格：市價扣掉你最近賣量造成的滑價。剛賣完會比市價低，約 1 遊戲小時後回來 |
| `coins` | 賣完後的金幣 |

### 3.3 `POST /v1/ship` 出貨（牛 → 倉庫裡的牛肉，當場評級）

請求：`{"cow_id": 1, "request_id": "<uuid>"}`

```json
{"server_time": 1791141900.0, "real_time": 1790771411.11, "time_scale": 144.0,
 "cow_id": 1, "grade": "C", "grade_probs": {"A": 0.156616, "B": 0.488677, "C": 0.354707},
 "beef": {"qty": 40.439815, "tier": 0, "shipped_at": 1791141900.0, "grade": "C", "grade_mult": 0.75, "quality": 0.75, "value_estimate": 375},
 "coins": 2300, "warehouse": {"…": "同 state.warehouse"}, "state": {"…": "同 GET /v1/state"}}
```

- 出貨只把牛變成倉庫裡的一批牛肉（`beef`），**還沒賣**；要賣用 `POST /v1/sell` 的 `commodity: "beef"`。
- 出貨當場評級 A／B／C（`grade`），賣價倍率 `grade_mult`（A 1.25、B 1.0、C 0.75，再乘稀有度）。`grade_probs` 是出貨那一刻的精確機率（跟 `GET /v1/ship/preview`、`state.cows[].grade_probs` 相同）。
- `value_estimate`：這批牛肉現在全部賣掉的估計收入（用實際評級）。
- 錯誤：`cow_not_found`、`cow_not_adult`、`cow_in_field`、`cow_listed`。
- 牛肉在倉庫：24 遊戲小時內價值不變，之後 96 小時線性降到 6 成，之後維持 6 成；不佔牛奶倉庫的容量，原型不設上限（試玩後再定）。

### 3.4 `GET /v1/ship/preview?cow_id=<id>` 出貨前看評級機率

```json
{"server_time": 1791141900.0, "real_time": 1790771411.11, "time_scale": 144.0,
 "cow_id": 1, "weight_kg": 40.44, "tier": 0,
 "grade_probs": {"A": 0.156616, "B": 0.488677, "C": 0.354707}, "grade_mult": {"A": 1.25, "B": 1.0, "C": 0.75},
 "value_by_grade": {"A": 625, "B": 500, "C": 375}, "expected_value": 475, "can_ship": true, "blockers": []}
```

| 欄位 | 說明 |
|---|---|
| `grade_probs` | 現在出貨評到 A／B／C 的精確機率（出貨確認畫面公開） |
| `grade_mult` | 各評級的賣價倍率（不含稀有度） |
| `value_by_grade` | 評到各級時，出貨後立刻全部賣掉的估計收入（幣，含這位玩家的滑價） |
| `expected_value` | 期望值（= `state.cows[].ship_value`） |
| `can_ship`／`blockers[]` | 現在能不能出貨；不能的原因 `{"code", "message", …}`：`cow_not_adult`、`cow_in_field`、`cow_listed`。app 用 `code` 查 `err.<code>`，不顯示 `message` |

### 3.5 `GET /v1/shop` 商店等級與精確機率

```json
{"server_time": 1791131100.0, "real_time": 1790771408.94, "time_scale": 144.0, "coins": 5000, "free_slots": 4,
 "grades": [
  {"grade": "A", "price": 3200,
   "tier_probs": [0.421875, 0.421875, 0.140625, 0.015625],
   "type_probs": {"dairy": 0.45, "dual": 0.275, "beef": 0.275}, "bull_prob": 0.5,
   "distribution": [{"type": "dairy", "bull": false, "traits": 0, "tier": 0, "breed": "holstein", "p": 0.094921875},
                    {"type": "dairy", "bull": false, "traits": 1, "tier": 1, "breed": "fluffyHolstein", "p": 0.031640625}, "…共 48 筆"]},
  {"grade": "B", "…": "…"}, {"grade": "C", "…": "…"}]}
```

| 欄位 | 說明 |
|---|---|
| `price` | 價格（幣） |
| `tier_probs` | 抽到稀有度 0–3 的精確機率 |
| `type_probs` | 抽到乳牛／耕牛／肉牛的機率 |
| `bull_prob` | 抽到公牛的機率 |
| `distribution[]` | 完整分布：每種（用途、公母、特徵組合 `traits`）的機率；`breed` 是 PR 4 加的 |
| `free_slots` | 牛舍還有幾格（0 就不能買） |

機率由經濟引擎直接算，跟抽牛用的是同一份參數；經濟參數調整後數字會變，app 不要寫死。

### 3.6 `POST /v1/shop/buy` 商店抽牛

請求：`{"grade": "B", "request_id": "<uuid>"}`（`grade` 是 `A`、`B`、`C`）

```json
{"server_time": 1791131100.0, "real_time": 1790771408.95, "time_scale": 144.0, "grade": "B",
 "cow": {"id": 3, "type": "dairy", "bull": true, "tier": 0, "breed": "holstein", "stage": "calf",
         "adult_at": 1791134700.0, "…": "欄位同 state.cows[]", "origin": "B"},
 "cost": 1700, "coins": 3300, "pen": {"slots": 6, "used": 3, "next_cost": 280, "next_open_at": null, "max_slots": 40},
 "state": {"…": "同 GET /v1/state"}}
```

- `cow`：抽到的牛（用途、公母、稀有度都是隨機的），畫面做開獎動畫（A-09）。
- 錯誤：`pen_full`、`not_enough_coins`、`bad_request`（等級不對）。

### 3.7 `GET /v1/breed/preview?sire=<id>&dam=<id>` 配種前看可能結果

```json
{"server_time": 1791130860.0, "real_time": 1790736268.39, "time_scale": 144.0,
 "sire": 2, "dam": 1,
 "tier_probs": [1.0, 0.0, 0.0, 0.0], "type_probs": {"dairy": 0.5, "dual": 0.5, "beef": 0.0}, "bull_prob": 0.5,
 "can_breed": true, "blockers": []}
```

| 欄位 | 說明 |
|---|---|
| `tier_probs` | 小牛稀有度 0–3 的精確機率（依父母基因算出，合計 1） |
| `type_probs` | 小牛用途的機率（乳牛 × 肉牛 = 全部耕牛） |
| `bull_prob` | 小牛是公牛的機率（0.5） |
| `can_breed` | 現在能不能配 |
| `blockers[]` | 不能配的原因 `{"code", "message", …}`：`cow_not_adult`（`cow_id`、`until`）、`already_bred`（`cow_id`）、`cow_in_field`、`cow_listed`、`pen_full` |

- 自己的公母配種免費（v2 拿掉 `fee`、`normal_fee`、`first_free`）。
- 不是「公牛 + 母牛」時回 `400 invalid_pair`；牛不存在回 `404 cow_not_found`。

### 3.8 `POST /v1/breed` 配種（自己的公牛 × 自己的母牛）

請求：`{"sire": 2, "dam": 1, "request_id": "<uuid>"}`

```json
{"server_time": 1791130860.0, "real_time": 1790736268.4, "time_scale": 144.0,
 "calf": {"id": 3, "type": "dual", "bull": false, "tier": 0, "breed": "yellow", "stage": "calf",
          "adult_at": 1791134460.0, "…": "欄位同 state.cows[]", "origin": "breed"},
 "sire": {"id": 2, "bred": true}, "dam": {"id": 1, "bred": true},
 "coins": 169, "state": {"…": "同 GET /v1/state"}}
```

- `calf.adult_at`：小牛長大的時間（倒數用）。長大時間：一般 1、優良 2、稀有 4、傳說 8 遊戲小時。
- 每頭牛一輩子配種一次：配完公母的 `bred` 都變 true，不能再配、公牛不能上架。
- 錯誤：`invalid_pair`、`cow_not_found`、`cow_not_adult`、`already_bred`、`cow_in_field`、`cow_listed`、`pen_full`。

### 3.9 `POST /v1/upgrade` 升級

請求：`{"kind": "pen", "request_id": "<uuid>"}`（`pen` 擴建、`bucket` 奶桶、`warehouse` 倉庫、`fresh` 冷藏、`field` 開新田（同 `/v1/field/expand`））

回應：`kind`、`cost`（花了多少）、`coins`、`upgrades`、`pen`、`state`。
錯誤：`not_enough_coins`、`max_level`、`not_yet_available`（第一次擴建在建立牧場後 15 遊戲分鐘開放，`detail.open_at`）。

### 3.10 田地

成年耕牛（`type: "dual"`，公母都行）派到田裡，稻米持續長在田裡，長滿（`fields[].capacity`）就停；收成時全部移到倉庫。
耕牛稀有度越高產量越多，年紀大了會衰退（和產奶同一條曲線）。在田裡的牛要先叫回來，才能出貨、配種、上架。

| 端點 | 請求 | 回應（另外都附 `coins`、`fields`、`rice`、`state`） | 錯誤 |
|---|---|---|---|
| `POST /v1/field/assign` 派牛下田 | `{"cow_id": 2, "field": 0, "request_id": "<uuid>"}`；`field` 可省略（找第一塊空田） | `cow_id`、`field`（派到的田號） | `cow_not_found`、`not_an_ox`、`cow_not_adult`、`cow_in_field`、`cow_listed`、`no_free_field`、`field_not_found`、`field_occupied` |
| `POST /v1/field/recall` 叫回 | `{"cow_id": 2, "request_id": "<uuid>"}` | `cow_id`、`field`（原本的田號）。已經長好的稻米留在田裡 | `cow_not_found`、`cow_not_in_field` |
| `POST /v1/field/harvest` 收成 | `{"request_id": "<uuid>"}` | `harvested`（公斤，所有田加起來）、`warehouse`。什麼都沒長也回 200（`harvested: 0`） | |
| `POST /v1/field/expand` 開新田 | `{"request_id": "<uuid>"}` | `kind: "field"`、`cost`、`upgrades` | `not_enough_coins`、`max_level` |

```json
{"server_time": 1791141900.0, "real_time": 1790771411.05, "time_scale": 144.0, "harvested": 33.0,
 "fields": [{"index": 0, "cow_id": 2, "rice": 0.0, "capacity": 88.0, "per_hour": 11.0}],
 "rice": {"in_fields": 0.0, "stock": 33.0, "per_hour": 11.0},
 "warehouse": {"…": "rice_total 33.0、rice_lots …"}, "coins": 3300, "state": {"…": "同 GET /v1/state"}}
```

稻米用 `POST /v1/sell {"commodity": "rice", …}` 賣；倉庫裡的稻米 72 遊戲小時內 100%，之後慢慢降到 7 成，不會壞。

### 3.11 `GET /v1/market` 行情

```json
{"server_time": 1791213660.0, "real_time": 1790736283.89, "time_scale": 144.0, "tick_t": 1791213660.0, "next_tick_at": 1791213720.0,
 "milk": {"price": 13.428, "change_24h": 0.392, "change_24h_pct": 0.030071, "ma24": 13.105, "base_price": 12.0, "ratio": 1.119},
 "beef": {"…": "同 milk"},
 "rice": {"…": "同 milk"},
 "news": [
  {"id": 3, "code": "milk_up.1", "params": {}, "pct": 0.18, "commodity": "milk", "targets": ["milk"], "direction": "up", "big": false,
   "time": 1791200814.43, "announce_at": 1791200814.43, "start_at": 1791200814.43, "end_at": 1791256527.72, "state": "active"},
  {"id": 2, "code": "all_down.3", "params": {}, "pct": -0.12, "commodity": null, "targets": ["milk", "beef", "rice"], "direction": "down", "big": false,
   "time": 1791162297.74, "announce_at": 1791162297.74, "start_at": 1791162297.74, "end_at": 1791315849.45, "state": "active"}]}
```

每種商品（`milk`、`beef`、`rice`）：

| 欄位 | 說明 |
|---|---|
| `price` | 現在的收購價（每瓶／每公斤） |
| `base_price` | 基本價：牛奶 12、牛肉 12、稻米 5。S06「平常（基本價）」 |
| `ratio` | 現價 ÷ 基本價。「比平常高／低幾 %」= `ratio − 1`（D24） |
| `change_24h` | 跟 24 遊戲小時前比，差多少幣（現價 − 24 小時前；開服不到 24 小時就跟開服價比） |
| `change_24h_pct` | 同上，比例（−0.046 = 跌 4.6%） |
| `ma24` | 24 遊戲小時移動平均 |

- 漲跌顏色跟著語言和設定（D25：繁中漲紅跌綠、英泰綠漲紅跌），伺服器只給數字。
- v2 拿掉 `unit`（單位的字在字串表）和 `history`（D24 沒有走勢圖）。
- `tick_t` 是最近一次市場更新的時間，`next_tick_at` 是下一次（每遊戲分鐘一次）。

`news[]`：最近的新聞，新的在前，最多 20 則（已公告的、進行中的、24 遊戲小時內結束的）。PR 3：

| 欄位 | 說明 |
|---|---|
| `id` | int |
| `code` | 新聞代碼，app 查字串表 `news.<code>`。格式 `<商品>_<漲跌>.<序號>`：商品是 `milk`、`beef`、`rice`、`all`（三種一起），漲跌是 `up`、`down`，序號從 1 開始（跟 `backend/cowecon/params.py` 的 `HEADLINES` 一樣，i18ncheck 會檢查） |
| `params` | 標題的佔位符參數；目前的標題都沒有佔位符，一律 `{}` |
| `pct` | 這則新聞的幅度：全幅時讓價格變多少（+0.18 = 漲 18%，−0.12 = 跌 12%）。開始後 15 遊戲分鐘漲（跌）到全幅，之後慢慢消退。`|pct|` ≥ 0.20 時 app 在牧場頁提示一次（S03-15） |
| `commodity` | 受影響的商品；**不只一種時是 `null`**（`targets` 列出全部） |
| `targets` | 受影響的商品清單 |
| `direction` | `up` 利多／`down` 利空 |
| `big` | 罕見的大新聞（±30–40%） |
| `time` | 新聞出現的時間（= `announce_at`） |
| `announce_at`／`start_at`／`end_at` | 公告、開始影響價格、影響結束。約 4 成新聞提前 30 遊戲分鐘公告（`state: "upcoming"`），其餘公告即開始 |
| `state` | `upcoming` 即將發生、`active` 進行中、`ended` 已結束 |

v2 拿掉 `title`。

### 3.12 `GET /v1/market/history?commodity=milk&range=1d` 走勢

app 第一版用不到（D24），留著給除錯和經濟分析。`range`：`1h`（每 1 遊戲分鐘一點）、`1d`（每 5 分鐘）、`7d`（每 30 分鐘）。

```json
{"server_time": 1791213660.0, "real_time": 1790736283.91, "time_scale": 144.0,
 "commodity": "beef", "range": "1h", "step_s": 60.0, "ma24": 11.618328,
 "points": [[1791210060.0, 11.776167], [1791210120.0, 11.772986], "…"]}
```

### 3.13 `GET /v1/leaderboard?kind=networth` 排行榜（PR 3）

`kind`：
- `networth` 總資產：金幣 + 倉庫與奶桶的牛奶、牛肉、稻米 + 田裡的稻米 + 成年牛出貨價值（評級期望值）+ 小牛（C 級價），按現價、不含滑價。
- `collection` 圖鑑：發現幾種（PR 4 起 0–24）。
- `weekly` 本週收入：週一 00:00（台灣時間）起的賣出收入 + 借種收入。

```json
{"server_time": 1791213660.0, "real_time": 1790736283.92, "time_scale": 144.0, "kind": "networth", "total": 37,
 "entries": [
  {"rank": 1, "ranch": {"player_id": 3, "name": null, "name_words": [11, 9, 11], "is_bot": true, "level": 6}, "score": 5448, "is_me": false},
  {"rank": 2, "ranch": {"player_id": 4, "name": null, "name_words": [8, 0, 5], "is_bot": true, "level": 6}, "score": 5252, "is_me": false}],
 "me": {"rank": 7, "ranch": {"player_id": 31, "name": "小花的快樂牧場", "name_words": null, "is_bot": false, "level": 2}, "score": 4189, "is_me": true}}
```

- `entries`：前 50 名。同分時先建立的在前。`ranch` 是 1.6 節的牧場物件（每列的等級就是 `ranch.level`）。
- `score`：整數（總資產與本週收入是幣，圖鑑是種數）。
- `me`：自己的名次（不論在不在前 50）。
- 排行榜每 3 現實秒重算一次。刪除的牧場不會出現。

`kind=weekly` 時多兩個欄位（ceo 2026-10-02；`s12.weeklyHint`「每週{w} {time} 重新計算」由 app 依手機時區換算）：

```json
{"…": "同上", "kind": "weekly", "week_started_at_real": 1790726400.0, "next_reset_at_real": 1790730600.0}
```

| 欄位 | 說明 |
|---|---|
| `week_started_at_real` | 這一週開始的**現實時間** |
| `next_reset_at_real` | 下次重算（下週一 00:00 台灣時間）的**現實時間** |

- 一週照遊戲時間算，再照現在的倍率換算成現實時間：倍率 1（正式版）就是真的一週；試玩倍率 144 時一週只有 70 分鐘。

## 4. 借種市場

主人把自己成年、沒配過、沒在田裡的公牛上架；借種費由系統依公牛現在的體重和稀有度算（D26，1.6 節），主人只決定要不要上架。
別的玩家用自己成年、沒配過的母牛借種：**付錢給主人、小牛歸借的人**，公牛和母牛的「一輩子一次」都用掉，上架自動移除。
公營種牛站（電腦系統）至少維持 3 筆一般公牛（乳牛、耕牛、肉牛各一），借這些的錢不給任何人；被借走會自動補上。
電腦假玩家也會上架自己的公牛、向別人（包括真人）借種，和真人一樣收付錢。

### 4.1 上架清單的形狀（PR 6）

```json
{"id": 4, "breed": "yellow", "type": "dual", "tier": 0,
 "owner": {"player_id": 31, "name": "小花的快樂牧場", "name_words": null, "is_bot": false, "level": 2},
 "is_mine": true, "cow_id": 2, "listed_at": 1791141900.0,
 "fee": {"price": 60, "per_kg": 1.1, "kg": 52.78, "at_max": false}}
```

| 欄位 | 說明 |
|---|---|
| `id` | 上架編號（借種、下架用） |
| `breed`、`type`、`tier` | 公牛的品種、用途、稀有度 |
| `owner` | 主人（1.6 節的牧場物件）；公營種牛站是 `player_id: null` 的那種 |
| `is_mine` | 是不是自己上架的 |
| `cow_id` | 主人牧場裡的牛編號；公營種牛站是 null |
| `listed_at` | 上架的遊戲時間 |
| `fee` | 借種費（1.6 節），這一刻現算 |

v2 拿掉 `price`（看 `fee.price`）、`type_name`、`tier_name`、`owner_id`、`owner_name`、`is_bot`（看 `owner`）、`weight_kg`（看 `fee.kg`）。

### 4.2 `GET /v1/stud` 上架清單

```json
{"server_time": 1791141900.0, "real_time": 1790771411.09, "time_scale": 144.0,
 "listings": [
  {"id": 1, "breed": "holstein", "type": "dairy", "tier": 0,
   "owner": {"player_id": null, "name": null, "name_words": [3, 5, 0], "is_bot": true, "level": null},
   "is_mine": false, "cow_id": null, "listed_at": 1791129600.0,
   "fee": {"price": 300, "per_kg": 1.1, "kg": 275.0, "at_max": true}},
  {"id": 4, "…": "形狀同 4.1"}],
 "mine": ["…自己上架的，形狀同上"]}
```

- `listings[]`：全部上架，便宜的在前（照這一刻的價格）。`mine[]`：自己上架的（同 `state.stud.listings`）。
- v2 拿掉 `prices`（不再選價位）。

### 4.3 `GET /v1/stud/preview?listing_id=<id>&dam=<id>` 借種前看可能結果

```json
{"server_time": 1791141900.0, "real_time": 1790771411.09, "time_scale": 144.0, "listing_id": 5, "dam": 1,
 "fee": {"price": 530, "per_kg": 1.1, "kg": 480.11, "at_max": false},
 "tier_probs": [1.0, 0.0, 0.0, 0.0], "type_probs": {"dairy": 0.5, "dual": 0.5, "beef": 0.0}, "bull_prob": 0.5,
 "can_borrow": true, "blockers": []}
```

- 機率欄位同 `breed/preview`。`blockers[]`：`own_listing`、`cow_not_adult`、`already_bred`、`cow_in_field`、`cow_listed`、`pen_full`、`not_enough_coins`（`need`、`have`）、`listing_gone`。
- PR 6：`fee` 取代 v1 的 `price`。借種時把 `fee.price` 原樣送回。

### 4.4 `POST /v1/stud/borrow` 借種

請求（PR 6 起要帶 `price`）：

```json
{"listing_id": 5, "dam": 1, "price": 530, "request_id": "<uuid>"}
```

回應：

```json
{"server_time": 1791141900.0, "real_time": 1790771411.1, "time_scale": 144.0,
 "calf": {"id": 3, "type": "dairy", "bull": true, "tier": 0, "breed": "holstein", "stage": "calf", "adult_at": 1791145500.0, "…": "欄位同 state.cows[]", "origin": "stud"},
 "price": 530, "listing_id": 5, "dam": {"id": 1, "bred": true}, "coins": 4200, "state": {"…": "同 GET /v1/state"}}
```

- `price`：你預覽時看到的借種費（`fee.price`）。伺服器用**這一刻**的價格算；跟你送的不一樣就回 `409 price_changed`，什麼都不扣（S18-12：「借種費變了」，按「用新價格借」就用新的價重送，記得換一個新的 request_id）：

  ```json
  {"error": {"code": "price_changed", "message": "借種費變了", "detail": {"price": 540, "expected": 530}}}
  ```

- 錢從借的人扣、同一個交易加到主人（主人在線的話會收到 WebSocket `stud`）；重送同一個 request_id 不會重複付錢。
- 錯誤：`listing_not_found`（404，已被借走或下架）、`own_listing`、`invalid_pair`（dam 是公牛）、`cow_not_found`、`cow_not_adult`、`already_bred`、`cow_in_field`、`cow_listed`、`pen_full`、`not_enough_coins`、`listing_gone`、`price_changed`。

### 4.5 `POST /v1/stud/list` 上架、`POST /v1/stud/unlist` 下架

| 端點 | 請求 | 回應 | 錯誤 |
|---|---|---|---|
| `/v1/stud/list` | `{"cow_id": 2, "request_id": "<uuid>"}`（PR 6 起不收 `price`，有送也忽略） | `listing`（4.1 節的形狀）、`coins`、`state` | `cow_not_found`、`not_a_bull`、`cow_not_adult`、`already_bred`、`cow_in_field`、`cow_listed` |
| `/v1/stud/unlist` | `{"listing_id": 4, "request_id": "<uuid>"}` | `listing_id`、`cow_id`、`coins`、`state` | `listing_not_found`（不存在或不是自己的） |

上架中的公牛不能出貨、配種、下田（`cow_listed`），要先下架。上架沒有期限；借種費跟著公牛長大自動漲（S04-05）。

### 4.6 `GET /v1/stud/log` 借種紀錄（S18-11；PR 7）

```json
{"server_time": 1791141900.0, "real_time": 1790771411.12, "time_scale": 144.0,
 "keep_days": 30, "income_total": 1510,
 "entries": [
  {"kind": "out", "t": 1791141900.0, "price": 60, "bull": {"id": 2, "breed": "yellow"}, "calf": null,
   "ranch": {"player_id": 12, "name": null, "name_words": [0, 1, 0], "is_bot": true, "level": 4}},
  {"kind": "in", "t": 1791138300.0, "price": 970, "bull": {"id": null, "breed": "angus"}, "calf": {"id": 9, "breed": "galloway"},
   "ranch": null}]}
```

| 欄位 | 說明 |
|---|---|
| `keep_days` | 只保留最近幾天（遊戲時間）的紀錄（`s18.logKeep` 的 `{n}`），目前 30 |
| `income_total` | 借出收入累計（幣，全部時間，= `state.stud.income`；`s18.logIncome`） |
| `entries[]` | 新的在前，最多 200 筆 |
| `kind` | `out` 借出（別人借了我的公牛，`s18.lentTo`「{cow} 借給 {ranch}」）、`in` 借入（我借別人的公牛，`s18.borrowedFrom`「{cow} 借自 {ranch}」） |
| `t`、`price` | 時間、價錢（借出是收到的，借入是付出的） |
| `bull` | 公牛：`breed`；`id` 只在借出時有（自己牧場的牛編號，可能已經出貨），借入時 null |
| `calf` | 借入時生下的小牛 `{"id", "breed"}`（`s18.calfBorn`「生下 {cow}」）；借出時 null |
| `ranch` | 對方（1.6 節的牧場物件，含公營種牛站）；**對方牧場已經刪除時是 null**，app 顯示 `s18.deletedRanch`（「已刪除的牧場」，cow-ui 會加） |

## 5. 帳號：備份、找回、刪除牧場（D22；PR 9）

**這一節是草稿**：PR 9 會先照 tech-decision 查 Apple、Google 官方文件（寫進 `docs/research/`），欄位可能依研究結果調整，改了會通知 cow-app。

- 一個牧場可以同時綁 Apple 和 Google 各一個；一個 Apple 或 Google 帳號只能綁一個牧場。
- 伺服器只存 Apple／Google 給的帳號識別碼（`sub`）和綁定時間，**不存 email 和姓名**（登入憑證裡有也不存）。
- Apple 綁定時另外要送 `authorization_code`：伺服器拿它向 Apple 換 refresh token 並加密保存，刪除牧場或解除綁定時用它撤銷 Apple 登入（Apple 5.1.1(v)）。這是憑證、不是身分資料。
- `provider`：`apple` 或 `google`。`id_token`：Apple 的 identity token、Google 的 ID token（JWT，原樣送）。
- 結果怎麼顯示：綁定成功 `s13.toast.bound`、解除 `s13.toast.unbound`、取消登入 `s13.toast.cancelled`（app 自己知道，不打伺服器）、`sign_in_failed` → `s13.toast.failed`。

### 5.1 `POST /v1/account/link` 綁定（要 token）

請求：

```json
{"provider": "apple", "id_token": "eyJraWQiOi…", "authorization_code": "c1a2b3…"}
```

回應：

```json
{"server_time": 1791141900.0, "real_time": 1790771411.2, "time_scale": 144.0,
 "linked": {"provider": "apple", "linked_at_real": 1790771411.2},
 "account": {"links": [{"provider": "apple", "linked_at_real": 1790771411.2}]}}
```

- 同一個帳號已經綁在這個牧場：回 200（重送也安全）。
- 帳號已經綁了**別的**牧場：`409 account_in_use`（S13-08「這個帳號已經備份了另一個牧場」）：

  ```json
  {"error": {"code": "account_in_use", "message": "這個帳號已經綁了別的牧場",
   "detail": {"provider": "apple", "ranch": {"player_id": 17, "name": "青草小丘農莊", "name_words": null, "is_bot": false, "level": 5},
              "switch_ticket": "t9Qx…", "ticket_expires_at_real": 1790772011.2}}}
  ```

  玩家選「換回那個牧場」並再確認（S13-09）後，用 `switch_ticket` 打 5.2；選「取消」就什麼都不用做。
- 其他錯誤：`provider_already_linked`（這個牧場已經綁了另一個同種帳號）、`sign_in_failed`（`reason`：`token_invalid`、`token_expired`、`code_invalid`）。

### 5.2 `POST /v1/account/switch` 換回那個牧場（要 token）

請求：`{"switch_ticket": "t9Qx…"}`（10 分鐘內有效，只能用一次，跟發出它的牧場綁在一起）

回應（形狀同 2.1，`created: false`）：

```json
{"server_time": 1791141960.0, "real_time": 1790771421.0, "time_scale": 144.0,
 "token": "Zk1…", "player_id": 17, "ranch_name": "青草小丘農莊", "created": false, "state": {"…": "那個牧場的 GET /v1/state"}}
```

- 伺服器在同一個動作裡：**刪除這支手機現在的牧場**（跟 5.5 一樣）、發新 token 給那個牧場；那個牧場原本的 token 全部失效（舊手機收到 `signed_in_elsewhere`）。
- app 換掉存的 token，回到牧場畫面。
- 錯誤：`sign_in_failed`（`reason`：`ticket_invalid`、`ticket_expired`）。

### 5.3 `POST /v1/account/unlink` 解除綁定（要 token）

請求：`{"provider": "apple"}`。回應：`{"…時間欄位", "account": {"links": […]}}`。

- Apple 的會順便撤銷 Apple 登入（撤銷失敗會在背景重試，不影響回應）。
- 錯誤：`not_linked`。

### 5.4 `POST /v1/account/recover` 找回牧場（不用 token）

新手機或重裝後，S14-02 按登入按鈕。請求：`{"provider": "google", "id_token": "eyJhbGciOi…"}`

回應（形狀同 2.1，`created: false`；S14-04「歡迎回來」的等級、金幣、牛從 `state` 拿）：

```json
{"server_time": 1791141960.0, "real_time": 1790771421.0, "time_scale": 144.0,
 "token": "Pq8…", "player_id": 17, "ranch_name": "青草小丘農莊", "created": false, "state": {"…": "同 GET /v1/state"}}
```

- 發新 token；這個牧場原本的 token 全部失效（舊手機收到 `signed_in_elsewhere`，伺服器也會主動關掉它開著的 WebSocket）。
- 錯誤：`account_not_linked`（S14-03「這個帳號沒有備份過牧場」）、`sign_in_failed`。

### 5.5 `POST /v1/account/delete` 刪除牧場（要 token）

請求：`{}`（「輸入刪除兩個字」只在 app 裡確認）。回應：`{"…時間欄位", "deleted": true}`。

- 伺服器刪除牧場、牛、金幣、倉庫、排行榜紀錄；解除所有綁定並撤銷 Apple 登入；他上架的公牛下架。
- 留下來的：市場的成交紀錄（不帶身分，市場重算要用）；別人的借種紀錄（對方顯示「已刪除的牧場」）。
- 之後這個 token 會收到 `401 unauthorized`；app 回到第一次打開的畫面（S13-04）。
- 刪除後，同一個 Apple／Google 帳號可以再綁新的牧場。

### 5.6 舊手機：`signed_in_elsewhere`

- 牧場在另一支手機找回（5.4）或換回（5.2）之後，舊手機的 token 失效：HTTP 回 `401 signed_in_elsewhere`；WebSocket 先送 `{"type": "error", "error": {"code": "signed_in_elsewhere", …}}` 再用 4401 關閉（開著的連線伺服器也會主動關）。
- app 顯示 S14-05「牧場已經在另一支手機登入」（`s14.elsewhereLead` 的 `{name}` 用 app 自己記得的牧場名）。
- 牧場刪除後，舊 token 改回 `unauthorized`（S15-03）。

## 6. 維護（S16；PR 8）

### 6.1 `GET /v1/status`（不用 token）

app 啟動時先打這個（還沒有 token 也能打），再決定要不要顯示維護畫面。

```json
{"server_time": 1791141900.0, "real_time": 1790771411.3, "time_scale": 1.0, "protocol": 2,
 "maintenance": {"starts_at_real": 1790780400.0, "ends_at_real": 1790784000.0, "active": false}}
```

`maintenance` 物件（`/v1/status`、`/v1/state`、WS `maintenance` 訊息都用這個形狀；沒有安排維護是 null）：

| 欄位 | 說明 |
|---|---|
| `starts_at_real` | 開始維護的**現實時間**（Unix 秒） |
| `ends_at_real` | 預計恢復的**現實時間**（S16-01「預計 {date} 恢復」） |
| `active` | 現在是不是已經在維護 |

### 6.2 維護前、維護中

- 維護前（`active: false`）：照常玩，app 可以提示維護時間（設計稿沒有畫這個提示，cow-app 跟 ceo 決定要不要做）。
- 維護中（`active: true`）：除了 `GET /v1/status` 和 `/healthz`，所有 `/v1/*` 回 `503 maintenance`（`detail.ends_at_real`）；WebSocket 送 `maintenance` 訊息後用 **4503** 關閉，app 不要重連，改成每 30 秒打一次 `/v1/status`，`maintenance` 變成 null 就重新載入。
- 維護由營運在伺服器上用腳本（`backend/scripts/maint.sh`）安排、取消，不經過 API。
- 伺服器整個停掉（部署）的那幾分鐘，沒有程式能回 503：M4 由反向代理回同一個形狀的 503，在那之前 app 會看到連不上（S15-01「連線中…」）。

## 7. WebSocket 即時推播：`/v1/ws`

- 連線：`ws://<主機>:8787/v1/ws?token=<token>`。也可以用子協定帶 token（瀏覽器不能自訂 header 時）：`["cowfarm.v1", "cowfarm.token." + token]`，伺服器會選 `cowfarm.v1` 回應。伺服器不記存取日誌，網址上的 token 不會寫進日誌。
- 用戶端送的任何訊息都會被忽略（可以用來保持連線）；伺服器每 20 秒 ping 一次。

關閉碼：

| 關閉碼 | 什麼時候 | 之前先送 | app 要做什麼 |
|---|---|---|---|
| 4401 | token 無效 | `{"type": "error", "error": {"code": "unauthorized" 或 "signed_in_elsewhere", …}}` | 不要重連；依 code 顯示 S15-03 或 S14-05 |
| 4503 | 維護中（PR 8） | `{"type": "maintenance", "maintenance": {…}}` | 不要重連；顯示 S16-01，照 6.2 打 `/v1/status` |
| 其他 | 網路斷線、伺服器重啟 | | 照下面的重連規則 |

伺服器送的訊息（都是 JSON 文字，看 `type` 分辨；不認得的 `type` 要忽略）：

| type | 什麼時候 | 內容 |
|---|---|---|
| `hello` | 連上時一次 | 時間欄位、`player_id`、`protocol`（**2**） |
| `market` | 連上時一次，之後**每現實 1 秒** | 時間欄位、`tick_t`，以及 `milk`、`beef`、`rice` 各 `{price, change_24h, change_24h_pct, ma24}` |
| `news` | 新聞第一次出現（公告或直接開始）時 | 跟 `news[]` 單筆同形狀，平鋪在訊息裡（`id`、`code`、`params`、`pct`、`commodity`、`targets`、`direction`、`big`、`time`、`announce_at`、`start_at`、`end_at`、`state`） |
| `stud` | 有人借了你上架的公牛（你在線時） | `event: "borrowed"`、`listing_id`、`cow`（你的公牛 `{"id", "breed"}`）、`price`（收到的錢）、`borrower`（1.6 節的牧場物件）、時間欄位。G-05「{cow} 借給 {ranch}，收到 {price} 幣」。app 收到後重抓 `GET /v1/state`（PR 3） |
| `maintenance` | 安排、改變、取消維護時，和開始維護的那一刻（PR 8） | `maintenance`（6.1 節的物件，取消時是 null） |
| `error` | 關閉前 | 見上表 |

```json
{"type": "stud", "event": "borrowed", "server_time": 1791141900.0, "real_time": 1790771411.1, "time_scale": 144.0,
 "listing_id": 4, "cow": {"id": 2, "breed": "yellow"}, "price": 60,
 "borrower": {"player_id": 12, "name": null, "name_words": [0, 1, 0], "is_bot": true, "level": 4}}
```

同一則新聞只推一次；「即將發生 → 進行中」的變化由 app 用 `start_at` 自己判斷，或重抓 `GET /v1/market`。

**斷線重連**：指數退避加隨機等待（full jitter），第 n 次等 `random(0, min(5, 0.5 × 2^n))` 秒，上限 5 秒。連上後先打一次 `GET /v1/market` 和 `GET /v1/state` 補齊斷線期間的變化。斷線期間畫面顯示「連線中…」並停用所有按鈕；連續 60 秒以上顯示「斷線很久」（S15-04）。

## 8. 其他

- `GET /healthz`：營運用（不需要 token，不屬於協定）：遊戲時間、tick、玩家數、假玩家數、連線數、錯誤數、參數指紋。
- `GET /v1/docs`：FastAPI 自動產生的 API 頁面（只列請求格式，回應格式以本文件為準）。

## 9. 電腦假玩家

- 伺服器裡有 30 位電腦假玩家（`COWFARM_BOTS`），六種玩法各約六分之一：乳牛派、肉牛派、耕田派、配種收集派、抓時機派、出借公牛派。照 `docs/research/economy/sim/bots.py` 移植。
- 他們呼叫的是和 API 同一組服務層函式，對市場的影響跟真人一樣。
- 名字是三組詞的編號（`name_words`，PR 5），app 用玩家的語言組，前面加「電腦」（1.6 節）。
- 開服後 1 遊戲小時內陸續加入，每天上線 4–8 次（台灣晚上較多）。出貨後大多立刻賣出（抓時機派會存著等好價）。

## 10. 重啟與回復

- 所有帳都在伺服器算，存在 PostgreSQL；伺服器被關掉（包括強制終止）再開，牧場、金幣、倉庫、行情、新聞、借種都還在。
- 行情引擎的狀態（含亂數）每個 tick 存一次；上一個 tick 之後的成交照序號重建，回復後的市場和當機前完全一樣。
- 遊戲時間：見 1.2 節（倍率 1 照真實時間走，試玩倍率關機期間暫停）。強制終止時，倍率不是 1 的伺服器從最後一個 tick 或動作的時間接著走，重啟後的 `server_time` 可能比斷線前最後看到的早一點（最多 1 遊戲分鐘），app 以新的 `server_time` 為準重新對時即可。
- app 在伺服器重啟期間會斷線，照第 7 節重連，token 不會失效。
- 存檔格式不相容的舊世界（例如 v0.2）伺服器會拒絕啟動並說明原因；原型階段直接清掉資料庫重來，玩家要重新建立牧場（app 收到 401 就顯示 S15-03）。

## 11. 變更紀錄

- 2026-09-30：v1 第一版（M1 原型）。
- 2026-09-30：v1 加 v0.2 玩法（企劃書 4.0、D17）：稻米、商店等級、出貨評級、配種一次、田地、借種；`/v1/buy_calf` 停用。
- 2026-10-02：v2 草稿（D22–D27、ceo 2026-10-02 裁示）：見第 0 節。v1 的「跟 M1 規格表不一樣的地方」對照表拿掉了，要看請查 git 歷史（`f11ce12` 的 `docs/protocol.md` 第 8 節）。
- 2026-10-02：PR 3 做完第 0 節 1–8、12 項；每週排行榜加 `week_started_at_real`、`next_reset_at_real`（ceo 2026-10-02）。
- 2026-10-02：PR 4 做完第 0 節 9、10 項：`cows[].breed`、24 品種圖鑑 `codex[] {breed, found_at}`、借種上架和 WS `stud` 的 `breed`、商店機率表的 `breed`。存檔格式升到 3，v0.2 的世界拒絕啟動。
- 2026-10-02：PR 5 做完第 0 節 11 項：`POST /v1/session {ranch_name, request_id}`、牧場名規則、測試向量 `name_cases.json`；電腦牧場改存詞庫編號。更正 2.2 節的例子：★ ♪ ♥ 在 Extended_Pictographic 裡，算 emoji（之前誤寫 ♪ 可以用）。
- 2026-10-02：PR 6 做完第 0 節 13 項（D26）：借種費依公牛現在的體重和稀有度現算（`fee`、`cows[].stud_fee`），`/v1/stud/list` 不收 `price`，`/v1/stud/borrow` 要帶 `price`、變了回 409 `price_changed`；拿掉 `stud.prices`、上架清單的 `price`、`weight_kg`。存檔格式升到 4。
- 2026-10-02：PR 7 做完第 0 節 14 項：`GET /v1/stud/log`（借出、借入，保留 30 遊戲天，最多 200 筆）；紀錄跟借種在同一個交易寫入。
