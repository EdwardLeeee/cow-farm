# M1 連線原型規格

- 日期：2026-09-30
- 負責：ceo
- 依據：
  - 使用者 2026-09-30：「先把app內容做好再來做測試的事情」
  - 計畫的 M1 段落
  - `docs/decisions.md` D1–D8、T1、T2
  - 經濟引擎筆記 `docs/research/2026-09-economy.md`

## 目的

在做正式畫面之前，驗證兩件事：
- 「牛奶還是牛肉＋全服行情」好不好玩。
- 「所有帳都由伺服器算」的架構行不行得通。

**畫面只用色塊和文字，這不是正式畫面。** 正式畫面要等 cow-ui 的完整設計稿核准才做。伺服器程式寫得好的話，M3 會沿用。

## 架構

| 部分 | 位置 | 技術 |
|---|---|---|
| 伺服器 | `backend/` | Python 3.10、FastAPI、uvicorn 1 個 worker、PostgreSQL 17（rootless podman，`--memory 256m`） |
| 經濟引擎 | `backend/cowecon/` | 從 `docs/research/economy/cowecon/` 用 `git mv` 搬過來，只保留這一份；`docs/research/economy/sim` 改成 import 這一份，模擬測試照樣通過 |
| 電腦假玩家 | `backend/` 內 | 沿用 `docs/research/economy/sim/bots.py` 的 S1–S4 策略。預設 30 位，在伺服器行程裡跑，**跟真人走同一套服務層函式**，所以對市場的影響跟真人一樣 |
| app | `app/` | Flutter 3.47.5（`~/development/flutter`），只用色塊和文字 |
| 試玩 | 同一個埠 | FastAPI 同時提供 Flutter 網頁版的靜態檔，iPhone 在家裡 Wi-Fi 用 Safari 開 `http://<開發機區網 IP>:8787/` |

## 遊戲時間

- 伺服器有一個遊戲時鐘，`遊戲時間 = 開服遊戲時間 + (現實時間 − 開服現實時間) × 倍率`。
  - 倍率由環境變數 `COWFARM_TIME_SCALE` 決定，預設 1。試玩建議 144，也就是遊戲 1 天 = 現實 10 分鐘。
- cowecon 的所有計算都用遊戲時間；市場每遊戲分鐘 tick 一次。
- 手機不送任何時間。回應裡附 `server_time`（遊戲時間）、`real_time`、`time_scale`，倒數與奶桶動畫由手機換算。

## 資料與重啟

- PostgreSQL 表（原型可以簡化，但必須能重啟回復）：
  - `players`：id、token 的 SHA-256、牧場名、建立時間。
  - `farms`：player_id、狀態 JSONB、版本號，用樂觀鎖。
  - `markets`：商品、`snapshot()` JSON、更新時間。
  - `trades`：成交紀錄。
  - `news`：新聞事件。
  - `processed_requests`：request_id，用來防止重送時重複成交。
- 照 T1 的規則：成交只寫 `trades`，全服成交量由市場 tick 彙總，不讓每筆交易更新同一列。
- cowecon 目前還不能從存檔回復，這一點要補：`Market`、`Exchange`、`Farm`、`ImpactState` 都要能序列化與回復，並附測試。回復後繼續跑的結果，必須跟沒有中斷過的同一個 seed 完全一樣。

## 協定 v1（手機 ↔ 伺服器）

- 全部是 JSON，除了 `POST /v1/session` 以外都要帶 `Authorization: Bearer <token>`。
- 會改變狀態的請求都帶 `request_id`（UUID），同一個 request_id 重送會回傳第一次的結果。
- 錯誤一律回 `{"error": {"code": "...", "message": "<繁中>"}}`，HTTP 狀態碼 4xx。

| 方法與路徑 | 用途 | 重點欄位 |
|---|---|---|
| `POST /v1/session` | 建立訪客帳號 | 回 `token`、`player_id`、`ranch_name`（伺服器從詞庫隨機組合；詞庫放 `backend/` 內，約 3 組×12 個詞） |
| `GET /v1/state` | 整個牧場 | `server_time`、`real_time`、`time_scale`、`coins`、`level`（由累積收入換算，只是顯示）、`cows[]`（id、用途類型、公母、稀有度、階段、年齡、產奶量、體重、可出貨估值、配種冷卻）、`bucket`（量、容量、每小時產量）、`warehouse`（牛奶批次含新鮮度、牛肉批次、容量）、`pen`（格數、已用、下次擴建費與開放時間）、`upgrades`（各項下一級費用）、`codex`（已發現的用途×稀有度） |
| `POST /v1/collect` | 收奶 | 回新的 `bucket` 與 `warehouse` |
| `POST /v1/sell/quote` | 賣出前試算，不成交 | `commodity`（milk／beef）、`qty` → `avg_price`、`total`、`market_price` |
| `POST /v1/sell` | 賣出 | `commodity`、`qty`、`request_id` → `qty`、`avg_price`、`total`、`price_after` |
| `POST /v1/ship` | 出貨，牛變成牛肉放進倉庫 | `cow_id`、`request_id` |
| `POST /v1/buy_calf` | 買小牛 | `type`（dairy／dual／beef）、`bull`、`request_id` |
| `GET /v1/breed/preview` | 配種前看可能結果 | `sire`、`dam` → 各稀有度機率、費用 |
| `POST /v1/breed` | 配種 | `sire`、`dam`、`request_id` |
| `POST /v1/upgrade` | 升級 | `kind`（pen／bucket／warehouse／fresh）、`request_id` |
| `GET /v1/market` | 行情 | 兩種商品各有 `price`、`change_24h`、`ma24`；最近 24 遊戲小時的走勢；`news[]` |
| `GET /v1/market/history` | 走勢 | `commodity`、`range`（1h／1d／7d，遊戲時間） |
| `GET /v1/leaderboard` | 排行榜 | `kind`（networth／collection／weekly）→ 前 50 名＋自己的名次；假玩家也列入，名字前面標「電腦」 |
| `WS /v1/ws?token=…` | 即時推播 | 每現實 1 秒推 `{"type":"market", ...}`；有新聞時推 `{"type":"news", ...}`；重連用指數退避加隨機等待，上限 5 秒 |

- 協定要寫成 `docs/protocol.md`（由伺服器端負責），跟這張表不一致時，以 `docs/protocol.md` 為準，並通知 ceo。
- 上架以後只能新增欄位、不能改或刪（api-evolution）。原型階段可以改，但要同步更新文件。

## app 畫面（色塊＋文字）

- **牧場**
  - 每頭牛一張卡：用途色塊、公母、稀有度、階段、產奶量、體重。
  - 奶桶進度條（手機依伺服器給的產量與時間換算，平滑增加）、「收奶」按鈕、倉庫摘要。
- **市場**
  - 牛奶、牛肉兩個分頁。
  - 現價與 24 小時漲跌：**漲紅跌綠**。
  - 折線圖用 CustomPainter，可以切 1 小時、1 天、7 天。
  - 新聞列表。
  - 賣出面板：數量滑桿 → 呼叫 quote 顯示「預估成交均價」，單量大時提示「一次賣太多，均價會變差」→ 確認賣出。
- **牛的詳細資料**：出貨按鈕，按下前先顯示估值；「選這頭去配種」。
- **配種**：選公牛、選母牛 → 顯示可能的稀有度機率與費用 → 配種，然後顯示倒數。
- **商店／升級**：買小牛（三種用途×公母）、擴建、奶桶、倉庫、冷藏；每項顯示費用，錢不夠就停用。
- **圖鑑**：用途×稀有度共 12 格，還沒發現的顯示「？」。
- **排行榜**：三個分頁。
- **頂列**：牧場名、等級、金幣、遊戲時間與倍率。斷線時顯示「連線中…」，並停用所有按鈕。

## 驗收

- **使用者試玩**：15–20 分鐘，倍率 144。玩完回答 5 個問題：
  - 好不好玩？
  - 看不看得懂行情？
  - 會不會想存貨等好價？
  - 想不想配種收集？
  - 哪裡無聊？
- **伺服器自動測試**
  - `docs/research/economy/sim/scenarios.py` 的大戶倒貨、10 人和 100 人各 30 天等情境要能在伺服器的服務層重跑，並達到經濟筆記的同樣目標。
  - 存檔回復測試。
  - request_id 防重送測試。
  - 錢不夠、牛不存在、冷卻中等錯誤都要有測試。
- **手動驗證**（ceo 做）
  - 伺服器重啟後進度還在。
  - 改手機時間不會影響任何結果。
  - 假玩家一起賣時價格會跌，之後會回升。
  - 倍率 144 連續跑 1 現實小時沒有錯誤。
- **app**：`flutter analyze` 沒有問題，主要畫面有 widget test，`flutter build web` 成功。

## 不做

- 移轉碼、刪除帳號、音效、動畫、正式美術、推播、牧場股市、商店上架。

## 驗收紀錄（ceo，2026-09-30）

- **同源走查**：伺服器在 `/` 提供 `app/build/web`，倍率 144，headless Chromium 430×932。
  - 走過：收奶 → 賣奶（試算均價 9.26，實際成交 9.29）→ 擴建 → 配種。
  - 0 個問題。
- **1 小時連續運轉**：commit 7e63474，倍率 144，30 位假玩家；每現實分鐘讀一次 `/healthz`，共 60 次。
  - errors 全程 0，tick 延遲最大 3.6 ms，共 8,786 次 tick（約 6 個遊戲天）。
  - 牛奶價格 7.41–13.06（基本價的 0.74–1.31 倍），牛肉 9.69–14.60（0.81–1.22 倍）。
- **iPhone 實機**：使用者開了電腦防火牆的區網規則（`ufw allow from 192.168.1.0/24 to any port 8787 proto tcp`）後，iPhone Safari 連上了。試玩回饋待收。
- 還沒做：改手機時間的測試（設計上 app 用單調時鐘，伺服器不收任何時間），以及使用者的 5 題回饋。

## v0.2 驗收紀錄（ceo，2026-10-01）

- 電腦在 2026-09-30 晚上重開過，舊的 v0.1 試玩伺服器因此停止。
  - v0.1 世界備份在 `~/.cache/cow-farm/backups/cowfarm-v0.1-20261001-0101.dump`（不進 repo）。
  - 資料庫 cowfarm 清空重建。
- v0.2 伺服器在 8787 啟動：commit fc27245，倍率 144，參數指紋 `9097bb48b2949aa3`，同一個埠也提供網頁版。
- **同源走查**（`app/tool/walk.cjs`，headless Chromium 430×932，截圖在 `app/test_shots/v02/`）
  - 流程：收奶 → 賣奶 → 擴建 → 商店買 C 級 → 派耕牛下田 → 收成 → 賣稻米 → 上架公牛 → 借電腦玩家的公牛配種 → 出貨看評級 → 排行榜。
  - **0 個問題**，全程約 4.3 分鐘。
  - 過程中看到的數字：
    - C 級抽到肉牛母牛一般。
    - 稻米收成 9.6 公斤，均價 4.45。
    - 借種預覽費用 300 幣。
    - 出貨評級機率 A 13.3%／B 49.3%／C 37.4%，這次評到 B 級：76 公斤牛肉，約 976 幣。
- 還沒做：使用者 iPhone 實機試玩與 5 題回饋。
