# 後端選型：FastAPI 夠不夠用、資料庫與即時行情怎麼做——可行性研究

- 日期：2026-09-30
- 負責：ceo session 派出的研究代理（只研究，沒有改產品程式；程式與原始數據在 `docs/research/tech-stack/backend/`）
- 問題：使用者已同意「後端以 FastAPI 為主」，要用實測數字確認；並決定 SQLite 或 PostgreSQL、WebSocket 或輪詢、手機 token 放哪裡、M1 原型 app 怎麼連到開發機。

## 先說結論

1. **FastAPI 夠用，而且一顆 CPU 就夠 10,000 人同時在線。** 一個 uvicorn 程序綁在這台筆電（i5-8250U）的 1 顆邏輯 CPU 上，模擬 10,000 人、每人每 10–20 秒動作一次（實際 657–660 req/s），CPU 用 47–67%，零錯誤，p99 延遲 22–121 ms（依資料庫與當時的干擾）。單核飽和點約 1,000 req/s（PostgreSQL）到 1,200 req/s（SQLite NORMAL）。**換算：每顆 vCPU 保留約 40% 餘裕，約可服務 8,000–10,000 名同時在線**（估計，見第 2 節換算）。
2. **資料庫建議 PostgreSQL 17，但要遵守一條設計規則：不要讓每筆交易都去更新「全服共用的同一列」。** 在同樣「每筆 commit 都落盤」的條件下，SQLite（FULL）卡在這顆磁碟的 fsync（中位數 4.6 ms），最多約 350–410 筆寫入/秒，不論設計怎麼改；PostgreSQL 如果每筆 sell 都累加 `market` 那一列，也只有 290–380 筆/秒，但改成「只寫成交紀錄、由每秒 tick 彙總」就升到 1,390–1,860 筆/秒（多筆 commit 合併落盤）。10,000 人時實際需要約 263 筆寫入/秒。SQLite 開 NORMAL 可以到每秒數千筆，但斷電或主機當機時可能丟掉最後幾筆已完成的交易，而且綁死單一程序。
3. **即時行情用 WebSocket 推播，輪詢留作補救。** 10,000 人時：WebSocket 伺服器 CPU 14.4%、每次價格更新 p99 0.77 秒內送到每個人；每 10 秒輪詢則要 42.4% CPU、玩家看到的價格平均已經舊了 2.5 秒（p99 5.0 秒），而且每兩次更新漏掉一次。WebSocket 的代價是記憶體：每條連線約 38 KB，10,000 條約 +370 MB。
4. **重連用「指數退避＋隨機抖動（full jitter），上限約 5 秒」。** 伺服器被強制終止、5 秒後重啟：上限 5 秒時 1,000 條連線在伺服器恢復後 4.9 秒內全部連回，尖峰每秒 347 次連線嘗試；固定每秒重試雖然 1.6 秒內全回，但第一秒湧入 928 次（上萬人時會變成瞬間洪峰）；上限 30 秒則最慢要 26 秒。
5. **token 放 `flutter_secure_storage`，不要放 `shared_preferences`。** 後者官方寫明「must not be used for storing critical data」，Android 還預設會被 Auto Backup 備份到 Google Drive。
6. **M1 連線：日常預覽用 Flutter 網頁版在家裡 Wi-Fi 走 HTTP；真機 app 在同一個 Wi-Fi 時用「只放在開發版」的 ATS 區網例外；不在同一個網路的測試者，用臨時 HTTPS tunnel。** iOS 17 起 ATS 預設擋直接連 IP 位址，`NSAllowsLocalNetworking` 同時放行 IP、`.local` 與無網域名稱；另外第一次連區網會跳「區域網路」權限提示。
7. **研究中順帶發現的坑**：主機上的 `pg_dump` 14 不能備份 17 版伺服器；SQLite 只 `cp` 主檔（沒帶 `-wal`）會少資料（實測少 99 筆成交）；Python 3.10 內建的 SQLite 3.37.2 落在官方 WAL-reset bug 的影響範圍（修正版 3.51.3）。
8. **實測過程中開發機當機一次**（全機記憶體耗盡，見附錄「限制」）。所有數字都是當機前或重開機後補跑的完整結果；原因無法從紀錄判定，但我在可用記憶體偏低時仍跑了三次重連測試，這點違反了我自己訂的門檻。

## 名詞

- **同時在線（CCU）**：同一時間開著遊戲的人數。本研究假設每人每 10–20 秒做一個動作，所以 10,000 人 ≈ 每秒 667 個請求。
- **req/s**：伺服器每秒處理的請求數。
- **p50／p99**：把所有請求的延遲排序，第 50%／第 99% 那個值。p99 代表「100 次裡最慢的那 1 次大約多慢」。
- **fsync**：要求作業系統把資料真的寫進磁碟。資料庫「保證不掉資料」的 commit 要等它完成，這顆磁碟一次約 4.6 ms。
- **WAL**：SQLite 與 PostgreSQL 都用的「先寫日誌」機制。SQLite 的 WAL 模式讓讀寫互不阻擋，但同時只能有一個寫入者。
- **synchronous=FULL／NORMAL**：SQLite 的落盤設定。FULL 每次 commit 都 fsync；NORMAL 不在每次 commit 時 fsync，斷電時可能丟最後幾筆。
- **熱點列（hot row）**：很多交易都要更新的同一列資料，例如「全服成交量」。它會讓交易排隊。
- **group commit**：PostgreSQL 把同時到達的多筆 commit 合併成一次 fsync。
- **扇出（fan-out）**：把同一則訊息送給每一條連線。
- **full jitter**：重連等待時間在 0 到「上限」之間隨機取，避免所有人同時重連。
- **ATS（App Transport Security）**：iOS 預設只允許 HTTPS 的規則。
- **邏輯 CPU／vCPU**：這台 CPU 每個實體核心有 2 個 hyperthread；雲端主機的「1 vCPU」通常也是 1 個 hyperthread。
- **RSS**：程序實際佔用的記憶體。

## 1. 正確性

- 做了什麼：`docs/research/tech-stack/backend/cowbench/` 是一個最小但具代表性的 API（丟棄式，不是產品程式）：
  - `POST /v1/session` 建訪客帳號（伺服器產生 32 bytes 隨機 token，資料庫只存 SHA-256）。
  - `GET /v1/farm`：每次都查資料庫驗證 token。
  - `POST /v1/collect`：伺服器用自己的時間戳算牛奶產量（用戶端不送數量）。
  - `POST /v1/sell`：一筆交易內扣倉庫、加金幣、寫成交紀錄、累加市場成交量（熱點列最後才更新）。
  - `GET /v1/market`：回傳預先序列化好的快照。
  - 背景每秒一次市場 tick（加速；佔位公式：均值回歸＋噪音＋成交量衝擊，**不是** `cowecon` 的引擎）。
  - `WS /v1/ws/market`：連線時驗證 token，每次 tick 後推播。
- 所有 HTTP 負載測試（混合、階梯、sell、輪詢合計 463,266 個請求）錯誤數都是 0；建帳號 2 × 10,000 次全部成功；WebSocket 10,000 條連線零失敗；三種重連策略 1,000/1,000 全部連回。
- 備份還原兩邊都比對了內容雜湊（見第 4 節），一致。
- **沒做**：帳目守恆檢查（例如「每位玩家金幣 = 初始值＋所有成交金額」）；多個 uvicorn worker 的正確性。

## 2. 速度

### 量法

- 伺服器：1 個 uvicorn worker，`taskset` 綁 CPU 2，放在 `systemd-run --scope` 裡限制記憶體；關掉 access log。
- PostgreSQL 17.11：rootless podman、`--network host`（避開 rootless 的轉發代理）、綁 CPU 6（和 CPU 2 同一個實體核心，相當於一台 2 vCPU 主機）、`--memory 512m`、設定全用預設（`synchronous_commit=on`）。
- 負載產生器：Python asyncio＋aiohttp，綁 CPU 3、7；CPU 0、1、4、5 留給使用者。
- **每個請求都新開 TCP 連線**：uvicorn 預設 keep-alive 只有 5 秒，比玩家 10–20 秒的操作間隔短，真實手機多半每次都要重連。**沒有 TLS**（正式環境由反向代理處理，沒量）。
- 動作比例：30% GET farm、30% GET market、25% collect、15% sell。暖身 20 秒後量 60 秒。
- 環境全文見 `backend/results/env.txt`。這台筆電同時有其他 session 在跑（load average 最高到 45），所以每筆結果都記了「CPU 2 被其他程序佔用的比例」。

### 混合負載結果

| 設定 | 在線人數 | 實際 req/s | p50 ms | p99 ms | 最慢 ms | 錯誤率 | 伺服器 CPU% | 伺服器 RSS MB | PG CPU% | 每請求 CPU ms（伺服器／含 PG） | CPU 2 外部佔用% |
|---|---|---|---|---|---|---|---|---|---|---|---|
| PG 17 | 1,000 | 65.6 | 6.1 | 21.6 | 35.3 | 0 | 18.6 | 52.4 | 5.8 | 2.84／3.73 | 5.0 |
| PG 17 | 10,000 | 660.2 | 6.3 | 71.8 | 413.4 | 0 | 67.0 | 49.7 | 24.7 | 1.02／1.39 | 1.8 |
| SQLite FULL | 1,000 | 65.6 | 3.9 | 13.6 | 32.3 | 0 | 10.5 | 47.4 | — | 1.60 | 5.8 |
| SQLite FULL | 10,000 | 657.6 | 4.1 | 121.0 | 265.8 | 0 | 48.8 | 50.2 | — | 0.74 | 5.4 |
| SQLite NORMAL | 1,000 | 65.6 | 2.8 | 11.0 | 86.8 | 0 | 11.9 | 55.9 | — | 1.82 | 5.7 |
| SQLite NORMAL | 10,000 | 657.9 | 5.9 | 84.1 | 232.6 | 0 | 54.6 | 55.6 | — | 0.83 | 22.5 |
| SQLite NORMAL（第 2 次） | 10,000 | 657.0 | 2.5 | 21.6 | 129.0 | 0 | 47.2 | 58.0 | — | 0.72 | 1.9 |

10,000 人時各端點 p50／p99（ms）：

| 設定 | GET farm | GET market | POST collect | POST sell |
|---|---|---|---|---|
| PG 17 | 4.7／62.4 | 2.4／45.0 | 10.0／77.5 | 12.3／113.9 |
| SQLite FULL | 2.8／23.3 | 1.8／19.1 | 9.1／169.1 | 9.9／172.7 |
| SQLite NORMAL | 6.1／60.6 | 4.0／52.9 | 7.8／97.7 | 8.3／102.6 |
| SQLite NORMAL（第 2 次） | 2.6／20.7 | 1.8／16.8 | 3.0／24.7 | 3.4／27.5 |

讀法：

- 同一設定跑兩次，p99 從 84 ms 變成 22 ms，差別在 CPU 2 被外部程序佔用 22.5% 還是 1.9%。**這台共用筆電上的尾端延遲會被干擾放大數倍**，比較時看干擾小的那次。
- SQLite FULL 的寫入（collect、sell）p99 約 170 ms：10,000 人每秒約 263 筆寫入，而 FULL 模式每筆都要 fsync，單一寫入者最多約 350–410 筆/秒，已經用掉六到七成，開始排隊。
- 1,000 人時「每請求 CPU」看起來比較高（1.6–2.8 ms），因為固定開銷（tick、計時器）攤在較少請求上，且低負載時 CPU 會降頻。估算容量請用 10,000 人或階梯測試的數字。

### 單核飽和點（固定速率階梯，每階 20 秒）

| 設定 | 目標 req/s | 實際 req/s | p50 ms | p99 ms | 伺服器 CPU% | PG CPU% |
|---|---|---|---|---|---|---|
| PG 17 | 400 | 399.9 | 11.9 | 33.8 | 50.0 | 16.5 |
| PG 17 | 700 | 699.9 | 10.6 | 29.9 | 70.7 | 25.9 |
| PG 17 | 900 | 899.9 | 11.0 | 47.8 | 81.1 | 31.2 |
| PG 17 | 1,100 | 1,099.8 | 1,585.5 | 6,165.5 | 99.8 | 40.5 |
| SQLite FULL | 400 | 399.9 | 12.7 | 28.2 | 40.8 | — |
| SQLite FULL | 700 | 699.9 | 17.8 | 454.3 | 72.2 | — |
| SQLite NORMAL | 700 | 699.9 | 8.1 | 35.5 | 58.1 | — |
| SQLite NORMAL | 900 | 899.9 | 8.0 | 35.4 | 67.7 | — |
| SQLite NORMAL | 1,100 | 1,099.8 | 8.1 | 51.5 | 67.6 | — |
| SQLite NORMAL | 1,300 | 1,299.8 | 537.9 | 1,540.2 | 95.5 | — |

- 這裡的延遲從「預定送出時間」算起（含產生器排隊），所以低負載時的 p50 比混合負載高一些。
- 產生器用 2 個程序，每個最高 55% CPU，沒有成為瓶頸。
- SQLite FULL 在 700 req/s 時 CPU 只用 72% 就排隊爆掉，瓶頸是 fsync 不是 CPU。

### 換算到正式主機（估計）

- 這台的「1 顆邏輯 CPU」≈ 雲端「1 vCPU」（都是 1 個 hyperthread）。正式主機的 CPU 型號未知，沒有做跑分換算，下面是**估計**。
- 10,000 人時每請求約 0.72–1.02 ms 伺服器 CPU（PG 另加 0.37 ms）。單核飽和約 1,000–1,200 req/s。
- 保留約 40% 餘裕（只跑到 60% CPU）：約 540–720 req/s/vCPU ≈ **每顆 vCPU 8,000–10,000 名同時在線**（每人每 15 秒一個動作）。WebSocket 每 10,000 條再加約 14% CPU（見第 3 節）。
- **這個數字只算 API 程序。** 用 PostgreSQL 時，資料庫每請求另需約 0.37 ms CPU，10,000 人約再佔 0.25 顆 vCPU（實測 24.7%），所以 1 萬人規模至少要 2 vCPU，不要用 1 vCPU 主機同時跑 API 和 PG。
- 記憶體：API 程序約 50–60 MB；PostgreSQL 容器實測 85–157 MB；WebSocket 每條約 38 KB。

## 3. 大小與記憶體；即時行情

### 資料庫寫入（sell 交易）

同一份交易程式，只換資料庫。「只打 sell」是經過 HTTP、keep-alive、每個 worker 用不同玩家；「純資料庫」不經 HTTP。

| 設定 | 併發 1 | 併發 8 | 併發 32 | 併發 128 | 備註 |
|---|---|---|---|---|---|
| API：PG 17 | 174 tx/s（p99 11 ms） | 377（101 ms） | 342（344 ms） | 291（793 ms） | 熱點列排隊 |
| API：SQLite FULL | 202（12 ms） | 354（39 ms） | 386（120 ms） | 377（527 ms） | fsync 上限 |
| API：SQLite NORMAL | 506（4 ms） | 734（57 ms） | 1,240（74 ms） | 891（1,099 ms） | CPU 上限 |
| 純 DB：PG，更新熱點列 | 222 | 348 | 309 | 298 | |
| 純 DB：PG，只寫成交紀錄 | 228 | 1,388 | 1,773 | 1,856 | group commit 生效 |
| 純 DB：SQLite FULL，更新熱點列 | 378 | 315 | 330 | 350 | 單一寫入者＋每筆 fsync |
| 純 DB：SQLite FULL，只寫成交紀錄 | 405 | 389 | 394 | 412 | 設計改了也沒差 |
| 純 DB：SQLite NORMAL（干擾小） | 3,898 | 3,271 | 3,544 | 5,542 | 干擾大時同一測試只有 588–829 |

- 磁碟 fsync（4 KiB × 500 次）：p50 4.58 ms、p99 10.66 ms；fdatasync p50 4.07 ms、p99 8.53 ms。**1 ÷ 4 ms ≈ 250 筆/秒，就是「每筆都要等落盤、又彼此排隊」的交易上限。**
- 建立帳號（32 個同時）：PG 1,219 個/秒；SQLite FULL 350 個/秒。
- 完整數字表：`backend/report.py` 產生（見附錄）。

### WebSocket 廣播 vs HTTP 輪詢

量法：伺服器 tick 改成每 5 秒一次，每次 tick 後把快照（359 bytes）推給所有連線；輪詢組每人每 10 秒 GET `/v1/market`（每次新連線）。客戶端是自寫的最小 WebSocket 客戶端（每連線約 3 KB，才能在這台機器開到 10,000 條），分 2 個程序、綁 CPU 3、7。量 30 秒（6 次廣播）。伺服器關掉 permessage-deflate（壓縮）。流量是 loopback 介面的位元組數（含 TCP/IP 標頭，已扣掉背景流量）。

| 方式 | N | 連上 | 送出→收到 p50／p99 ms | 一次扇出最慢 ms | 伺服器 CPU% | 伺服器 RSS MB | 每連線 KB | 流量 KB/s |
|---|---|---|---|---|---|---|---|---|
| WebSocket | 1,000 | 1,000 | 42.8／144.8 | 148 | 2.8 | 87 | 35.6 | 99 |
| WebSocket | 2,500 | 2,500 | 62.2／184.1 | 190 | 3.1 | 144 | 39.5 | 193 |
| WebSocket | 5,000 | 5,000 | 153.1／375.4 | 376 | 7.4 | 236 | 38.7 | 411 |
| WebSocket | 10,000 | 10,000 | 236.1／768.3 | 796 | 14.4 | 418 | 38.0 | 854 |

| 方式 | N | req/s | 回應 p50／p99 ms | 價格發布→玩家拿到 p50／p99 ms | 漏掉的更新 | 伺服器 CPU% | 伺服器 RSS MB | 流量 KB/s |
|---|---|---|---|---|---|---|---|---|
| 輪詢 | 1,000 | 100 | 2.8／8.6 | 2,665／4,940 | 50% | 10.9 | 40 | 112 |
| 輪詢 | 10,000 | 1,000 | 1.4／4.5 | 2,475／4,960 | 50% | 42.4 | 48 | 1,024 |

- N=1,000 的 WebSocket 是當機前在記憶體吃緊、CPU 2 平均只有 1.48 GHz 時量的；2,500 以上是重開機後量的（CPU 2 約 2.6–3.0 GHz）。
- WebSocket 的延遲幾乎全是扇出時間：單一程序依序送出，每條連線約 80 µs，10,000 條最後一個人約 0.8 秒後收到。價格 5 秒才變一次，這個延遲可以接受。
- 流量：10,000 人時 WebSocket 每人約 87 bytes/秒（每小時約 0.3 MB），而且收到**每一次**更新；輪詢每人約 105 bytes/秒，只收到一半的更新。
- 伺服器 CPU：WebSocket 是輪詢的三分之一；記憶體則是輪詢的 9 倍（+370 MB／10,000 條）。

### 斷線重連（1,000 條 WebSocket；SIGKILL 伺服器、5 秒後重啟，模擬 systemd `RestartSec=5s`）

| 客戶端退避策略 | 伺服器重啟到可服務 | 伺服器恢復後多久連回 p50／p99／最慢 | 每人嘗試次數 p50／最多 | 恢復後第 1–5 秒每秒連線嘗試 |
|---|---|---|---|---|
| 指數退避＋full jitter，0.5 秒起、上限 30 秒 | 1.08 秒 | 3.2／15.6／25.9 秒 | 5／8 | 182, 138, 141, 146, 110 |
| 指數退避＋full jitter，0.5 秒起、上限 5 秒 | 0.76 秒 | 1.5／4.6／4.9 秒 | 5／10 | 347, 277, 211, 113, 46 |
| 固定每 1 秒重試（無 jitter） | 1.15 秒 | 0.8／1.6／1.6 秒 | 6／7 | 928, 0, 0, 0, 0 |

- 三種都 1,000/1,000 連回，重連時每條連線都重新驗證 token（查一次資料庫）。
- 固定重試最快，但把所有人擠在同一秒：1,000 人時第一秒 928 次；照比例 10,000 人約 9,000 次/秒，遠超過本研究實際驗證過的每秒 500 條連線建立速度。
- 注意：這三次是在可用記憶體約 720–760 MB 時跑的（見「限制」）。

## 4. 替代方案比較

### 資料庫

| | PostgreSQL 17 | SQLite FULL | SQLite NORMAL |
|---|---|---|---|
| 斷電／主機當機後 | 已 commit 的都在（`synchronous_commit=on`） | 已 commit 的都在 | **可能丟最後幾筆**，但資料一致不損毀 |
| 本機每筆落盤的寫入上限 | 熱點列設計 290–380 筆/秒；只寫成交紀錄 1,390–1,860 筆/秒 | 350–410 筆/秒（設計改了也一樣） | 數千筆/秒 |
| 10,000 人時寫入 p99 | 78–114 ms | 169–173 ms | 25–103 ms |
| 多個程序／多台主機 | 可以 | 單一寫入者；多程序要靠 busy_timeout 排隊 | 同左 |
| 備份 | `pg_dump` 線上一致性備份：22 MB 資料庫 2.7 秒，還原 5.9 秒，雜湊一致 | Online Backup API：4.6 MB 約 0.04–0.06 秒，雜湊一致；持續備份用 Litestream | 同左 |
| 額外成本 | 多一個容器（實測 85–157 MB）、要固定版本 | 一個檔案 | 一個檔案 |

官方定位（原文）：

- SQLite whentouse：「SQLite supports an unlimited number of simultaneous readers, but it will only allow one writer at any instant in time.」以及「if the website is write-intensive or is so busy that it requires multiple servers, then consider using an enterprise-class client/server database engine instead of SQLite.」但它也說「Developers report that SQLite is often faster than a client/server SQL database engine in this scenario. Database requests are serialized by the server, so concurrency is not an issue.」（應用伺服器與資料在同一台時）。https://www.sqlite.org/whentouse.html
- SQLite pragma：「A transaction committed in WAL mode with synchronous=NORMAL might roll back following a power loss or system crash. Transactions are durable across application crashes regardless of the synchronous setting or journal mode.」https://www.sqlite.org/pragma.html#pragma_synchronous
- SQLite WAL（WAL-reset bug）：「It is fixed in version 3.51.3 (2026-03-13) and later.」「The bug only affects databases in WAL mode when there are two or more database connections open on the same file, in separate threads or processes, and when those two connections attempt to write or checkpoint at the same instant.」本研究用的 Python 3.10 連結的是 3.37.2。https://www.sqlite.org/wal.html
- PostgreSQL pg_dump：「It makes consistent backups even if the database is being used concurrently.」「pg_dump cannot dump from PostgreSQL servers newer than its own major version; it will refuse to even try」。https://www.postgresql.org/docs/17/app-pgdump.html

備份與還原步驟（兩邊都實際做過一次，結果在 `backend/results/*_backup_restore.txt`）：

SQLite（實測用 Python 的 `Connection.backup()`；它和 CLI 的 `.backup` 用同一個 Online Backup API，這台沒裝 sqlite3 CLI）：
1. 線上備份，不必停機：`sqlite3 game.db ".backup /backup/game-$(date +%F).db"`。實測 4.6 MB 在負載中花 0.04 秒，同時段 API p99 12.5 ms。
2. 檢查備份：`sqlite3 /backup/game-….db "PRAGMA integrity_check"` 要回 `ok`。
3. 還原：停伺服器 → 把 `game.db`、`game.db-wal`、`game.db-shm` **三個一起**移走 → 複製備份成 `game.db` → 啟動 → 用已知玩家打 `GET /v1/farm` 核對。實測數值一致。
4. 不要用 `cp game.db`：實測少了 99 筆成交（新資料還在 WAL）。SQLite 官方：「If a database file is separated from its WAL file, then transactions that were previously committed to the database might be lost, or the database file might become corrupted.」https://www.sqlite.org/wal.html
5. 持續備份的思路是 Litestream：「It runs as a separate background process and continuously copies write-ahead log pages from disk to a replica.」「By default, Litestream will replicate new changes to an S3 replica every second. During this time where data has not yet been replicated, a catastrophic crash on your server will result in the loss of data in that time window.」https://litestream.io/how-it-works/ 、https://litestream.io/tips/ （沒實測）

PostgreSQL：
1. 線上備份：`podman exec <容器> pg_dump -U postgres -Fc cowfarm > cowfarm.dump`。pg_dump 的主版本要 ≥ 伺服器（主機的 pg_dump 14 實測被拒：「aborting because of server version mismatch」），所以在容器裡跑。實測 22 MB 資料庫 2.66 秒、檔案 1.8 MB。
2. 還原到新資料庫：`createdb cowfarm_restore`，再 `podman exec -i <容器> pg_restore -U postgres -d cowfarm_restore --exit-on-error < cowfarm.dump`。實測 5.88 秒。
3. 核對：players／farms／trades 的列數與內容 md5 兩邊一致（實測一致）；API 改連還原後的資料庫，同一玩家的 milk／coins 相同，sell 正常。

**建議 PostgreSQL 17。** 理由：同樣「不掉資料」的條件下，它的寫入餘裕是 SQLite FULL 的 4–5 倍（前提是避開熱點列）；日後要開第二個程序或第二台主機（例如第二階段的牧場股市）不用換資料庫；備份還原工具與官方說法完整。代價是多一個容器與版本管理。

**不建議**：
- SQLite FULL：這顆磁碟上 10,000 人時已用掉寫入上限的六到七成，第二階段股市加上去就不夠；改設計也沒用（上限來自 fsync）。
- 每筆 sell 都 `UPDATE market SET volume = volume + ?`：實測讓 PG 寫入上限掉到五分之一（1,856 → 298 筆/秒）。

**可接受的替代**：如果使用者更在意最低成本、最簡單的部署，SQLite NORMAL（單一程序、SQLite ≥ 3.51.3、用 Litestream 持續備份）也撐得住 10,000 人；代價是主機當機可能丟最後幾秒的交易，而且之後要擴成多程序得換資料庫。

### 即時行情

**建議 WebSocket 推播，`GET /v1/market` 保留作為開 app 與重連後的補快照。** 依據是上面的數字：同樣 10,000 人，CPU 是輪詢的三分之一、價格在 0.8 秒內送達（輪詢平均晚 2.5 秒且漏一半）。代價是每條連線約 38 KB 記憶體，以及「推播只能由一個程序負責」（多程序時要加訊息轉發，例如 PostgreSQL LISTEN/NOTIFY 或 Redis，沒量）。

官方原文：
- uvicorn：「--ws-per-message-deflate <bool> - Enable/disable WebSocket per-message-deflate compression. Only available with the websockets protocol. Default: True.」本研究關掉壓縮。https://uvicorn.dev/settings/
- websockets 函式庫（它自己的 asyncio 伺服器，不是 uvicorn）：「The asyncio implementation with default settings uses 64 KiB of memory for each connection.」「You can reduce memory usage to 14 KiB per connection if you disable compression entirely.」https://websockets.readthedocs.io/en/stable/topics/memory.html 。我們在 uvicorn＋Starlette 實測是 38 KB/連線（沒開壓縮）。
- websockets broadcast：「If a client gets too far behind, eventually it reaches the limit defined by ping_timeout and websockets terminates the connection.」https://websockets.readthedocs.io/en/stable/topics/broadcast.html

重連建議：指數退避＋full jitter，起始 0.5 秒、上限 5 秒；連回後先打一次 `GET /v1/market` 補齊漏掉的價格。

### 後端框架

| | FastAPI（本研究實測） | Serverpod 4.0.3 | Nakama v3.41.0 |
|---|---|---|---|
| 伺服器語言 | Python | Dart（和 app 同語言） | Go 核心；自訂邏輯用 TypeScript/JS（官方推薦）、Go、Lua |
| 資料庫 | 自選（建議 PG） | 「Serverpod supports both PostgreSQL and SQLite as database backends.」所有 run mode 必須用同一種 | 架構頁：「supporting any PostgreSQL wire-compatible database」；Linux 安裝頁：「officially supports CockroachDB」、PostgreSQL「for development environments only」（兩頁說法不一致） |
| Redis | 不需要（單程序） | 「Redis is optional.」多個 instance 要共享快取／事件時才要 | 文件沒要求 |
| 即時連線 | Starlette WebSocket（實測 10,000 條／1 核） | 「Stream Dart objects to your app over WebSockets」 | WebSocket 與 rUDP |
| 訪客／裝置帳號 | 自己寫（本研究約 20 行） | 內建多種登入，含 anonymous | 內建 device authentication |
| 排行榜、儲存 | 自己寫 | ORM＋migration | 內建排行榜；儲存引擎是 JSON collections，「The creation of custom tables is strongly discouraged.」 |
| 授權 | MIT（FastAPI）、BSD-3-Clause（uvicorn） | 主套件 `serverpod` 為 SSPL-1.0，其他套件 BSD-3 | Apache-2.0；叢集是 Enterprise 功能 |
| Flutter 客戶端 | 自己寫 HTTP／WebSocket | 自動產生 | 官方 `nakama` 1.4.0（heroiclabs.com） |
| 對本專案 | 可和 Python 經濟模擬共用行情程式；沿用 connect4 部署流程；有實測數字 | 沒實測；經濟模擬要改寫成 Dart | 沒實測；市場與股市要塞進它的儲存模型與 runtime，和「不要自建資料表」的建議衝突 |

結論：維持 FastAPI。Serverpod 的主要好處（前後端同語言、自動產生客戶端）抵不過「經濟模擬要重寫」；Nakama 的內建功能（排行榜、裝置登入）我們用得不多，核心的市場與股市反而不合它的資料模型。

## 5. 手機 token 存放

| | flutter_secure_storage | shared_preferences |
|---|---|---|
| 版本／發布者／最後發布 | 11.2.0／steenbakker.dev／2026-09-16 | 2.5.5／flutter.dev／2026-03-25 |
| 平台 | android、ios、macos、linux、web、windows | android、ios、linux、macos、web、windows |
| iOS 底層 | Keychain | NSUserDefaults |
| Android 底層 | v10 起自有加密（RSA OAEP＋AES-GCM），金鑰在 Android KeyStore | SharedPreferences／DataStore，未加密 |
| 官方說法 | 「Uses Keychain for iOS/macOS, custom secure ciphers … for Android」 | 「this plugin must not be used for storing critical data」 |

注意事項（原文）：
- flutter_secure_storage README：「By default Android backups data on Google Drive. It can cause exception java.security.InvalidKeyException: Failed to unwrap key.」要停用 Auto Backup 或排除它用的 sharedprefs。https://pub.dev/packages/flutter_secure_storage
- iOS 存取層級：`*_this_device` 類選項「Items with this attribute do not migrate to a new device.」
- Android Auto Backup：「To back up user credentials and authentication tokens, don't store them in shared preferences or a file.」https://developer.android.com/identity/data/autobackup

**建議**：token 放 flutter_secure_storage。iOS 用 `first_unlock_this_device`（開機後解鎖過一次，背景也能讀；而且不會隨備份搬到新手機）；Android 依 README 在備份規則排除它的 sharedprefs。這樣「換手機」在兩個平台都一律走移轉碼，行為一致，也不會有兩支手機拿著同一個 token。（2026-10-01 D22：移轉碼改成綁定 Apple／Google 帳號，換手機一律走「找回我的牧場」；token 的存法不變。）若使用者希望 iPhone 換機時自動帶過去，可改用 `first_unlock`，但這是從「`*_this_device` 不會遷移」反推的，要實機驗證。**未能讀到原文**：刪除 app 後 iOS Keychain 的資料是否留存（影響「刪掉重裝是不是同一個牧場」），M1 要用真機驗證。

## 6. M1 原型 app 怎麼連到開發機

官方原文：
- `NSAllowsLocalNetworking`：「controls whether App Transport Security (ATS) allows your app to connect to unqualified domains, .local domains, and IP addresses using IPv4 or IPv6.」「In iOS 17, iPadOS 17, and macOS 14, ATS no longer allows connections to IP addresses by default.」https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking
- 需要在送審時提出理由的 ATS 例外清單包含 `NSAllowsArbitraryLoads` 與 `NSExceptionAllowsInsecureHTTPLoads`，**沒有列 `NSAllowsLocalNetworking`**（但文件也沒明說它免理由）。https://developer.apple.com/documentation/security/preventing-insecure-network-connections
- 區網隱私：「The first time a program accesses the local network, the system displays an alert asking the user to approve that access.」「they apply to all networking APIs. This includes Network framework, BSD Sockets, URLSession」「The simulator doesn't support local network privacy. Test your local network privacy behavior on a real device.」「Traffic originating from WKWebView, SFSafariViewController, and Safari doesn't require local network access.」https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy
- `NSLocalNetworkUsageDescription`：「Any app that uses the local network, directly or indirectly, should include this description.」
- Android：「Starting with Android 9 (API level 28), cleartext support is disabled by default.」要用 network security config 的 `<domain-config cleartextTrafficPermitted="true">` 開放。https://developer.android.com/privacy-and-security/security-config
- Cloudflare Quick Tunnel：「Quick Tunnels are intended for testing and development only.」「Currently, this limit is 200 in-flight requests. If a Quick Tunnel hits this limit, the HTTP response will return a 429 status code.」https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/
- 推論（沒有官方逐字說法）：Flutter 的 `dart:io` HttpClient 走自己的 socket，不經 URLSession，所以很可能不受 ATS 攔截；但區網隱私提示照樣會出現。要實機驗證。

| 做法 | 使用者看到什麼 | 成本 | 風險 |
|---|---|---|---|
| A. Flutter 網頁版，家裡 Wi-Fi 用 Safari 開 `http://<開發機 IP>` | 不用安裝，打開網址就玩；不會跳區網提示（Safari 例外） | 最低，D4 已經規劃 | 不是真的 app：儲存、效能、手勢會不同 |
| B. 真機 app（debug／TestFlight 開發版）直連開發機區網 IP | 第一次會跳「允許尋找區域網路上的裝置」，拒絕就連不上，要去設定改；手機要和開發機同一個 Wi-Fi | 開發版 Info.plist 加 `NSAllowsLocalNetworking` 與區網說明；Android debug 版開 cleartext；app 要能設定伺服器網址、第一次失敗要重試 | 這些例外要限定在開發版，送審前拿掉；iOS 背景時連線會被直接拒絕 |
| C. 真機 app 經臨時 HTTPS tunnel（`cloudflared tunnel --url http://localhost:18080`） | 不用同一個 Wi-Fi，4G 也能連；不跳區網提示（公網位址，推論）；不用 ATS 例外 | 裝 cloudflared；每次啟動網址會變，app 要能改網址 | 官方只給測試用、無 SLA；同時超過 200 個請求回 429；Quick Tunnel 頁沒寫 WebSocket（一般 Tunnel FAQ 寫支援），要實測；開發機暴露在網路上 |

**建議**：日常看畫面用 A；需要真機行為（推播重連、secure storage、效能）時，在家用 B，找外面的人試玩用 C。正式版一律走有網域的 HTTPS，不帶任何 ATS 例外。

## 7. 對現有架構的影響

- **worker 數**：官方文件沒有給計算公式。uvicorn：「--workers <int> - Number of worker processes. Defaults to the $WEB_CONCURRENCY environment variable if available, or 1.」（https://uvicorn.dev/settings/）。FastAPI：有叢集時「You would want to have just a single Uvicorn process per container (but probably multiple containers).」；單機時「You could want a process manager in the container if your application is simple enough that you can run it on a single server」（https://fastapi.tiangolo.com/deployment/docker/）。
- **單一 API 程序負責 tick 與推播。** FastAPI 官方：「multiple processes normally don't share any memory」（https://fastapi.tiangolo.com/deployment/concepts/）。本研究的市場快照、tick、WebSocket 連線都放在程序記憶體裡，所以正式版先用 1 個 worker（本研究顯示 1 核可撐約 1 萬人）；要多開 worker 時，tick 要改成單一負責者、推播要經訊息轉發。
- **市場成交量不要每筆更新同一列。** 成交只寫 `trades`，由 tick 彙總（或每個程序在記憶體累加、每秒寫一次）。
- **備份**：PG 在容器內跑 `pg_dump -Fc`（主機的 pg_dump 14 不能用），每天一次，並定期實際還原一次；若改用 SQLite，一定用 Online Backup API／`VACUUM INTO`／Litestream，不要 `cp`。
- **部署**：沿用 connect4 的 rootless podman＋systemd；加一個 PG 容器。記憶體估計：API 60 MB＋WebSocket 每萬條 370 MB＋PG 160 MB＋系統，**建議正式主機至少 2 GB RAM、2 vCPU**（估計）。
- **WebSocket 伺服器設定**：關掉 per-message-deflate（省記憶體；價格訊息只有 359 bytes）；保留 uvicorn 預設每 20 秒 ping。

## 8. 建議與分階段

1. **M1（ceo）**：原型後端用 FastAPI＋PostgreSQL 17 容器（直接拿 `scripts/pg.sh` 的做法），1 個 worker；行情用 WebSocket＋`GET /v1/market` 補快照；連線用做法 A，真機測試用 B。
   驗收：原型 app 在真機上能建立訪客帳號、收牛奶、賣出、看到每 5 秒更新的價格；伺服器被重啟後 app 在 10 秒內自動恢復。
2. **M3（cow-back）**：正式 schema 用 append-only 成交紀錄＋tick 彙總；token 只存雜湊；重連協定（退避上限 5 秒）寫進協定文件；把 `loadgen.py mixed --users 10000` 當成發版前的本機回歸測試。
   驗收：10,000 人混合負載 p99 < 150 ms、零錯誤；`pg_dump`→還原→雜湊一致。
3. **M4（cow-release）**：正式網域 HTTPS；移除開發版 ATS／cleartext 例外；token 設定照第 5 節。
   驗收：release 版 Info.plist 沒有 `NSAllowsLocalNetworking`／`NSAllowsArbitraryLoads`；Android release 版沒有 cleartext 設定。

**需要使用者決定的**：資料庫要 PostgreSQL（建議，多一個容器、不掉資料、日後能擴）還是 SQLite NORMAL（最省事，主機當機可能丟最後幾秒交易）。

## 附錄

### 量測工具與重現

所有指令在 `docs/research/tech-stack/backend/` 下執行。資料庫、token、PID、備份放在 repo 外（`$SCR`）。

```bash
cd docs/research/tech-stack/backend
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
export SCR=/tmp/cowbench && mkdir -p $SCR/data $SCR/run $SCR/backups
export COW_RUN_DIR=$SCR/run COW_START_MILK=1000000
GEN="systemd-run --user --scope --quiet -p MemoryMax=500M -p MemorySwapMax=0 taskset -c 3,7 .venv/bin/python"
# --mem-floor：MemAvailable 低於此值（MB）就中止或不開始。loadgen 預設 1000、wsbench 預設 900；
# 這台共用筆電常只有約 1 GB 可用，HTTP 測試本身只佔約 40 MB，所以 HTTP 測試用 450。WebSocket 測試維持 ≥ 900。

# 磁碟 fsync
taskset -c 2 .venv/bin/python fsyncbench.py --dir $SCR/data --n 500 --out results/fsync.json

# ---- PostgreSQL 17
scripts/pg.sh up                      # 印出 postmaster PID 與 CPU 綁定；做完用 scripts/pg.sh down 移除
export COW_DB=postgres COW_PG_DSN="$(scripts/pg.sh dsn)" PGPID=$(scripts/pg.sh pid)
taskset -c 2 .venv/bin/python dbbench.py --db postgres --dsn "$COW_PG_DSN" --pg-pid $PGPID --hotrow 1 --out results/dbbench_pg_hotrow.json
taskset -c 2 .venv/bin/python dbbench.py --db postgres --dsn "$COW_PG_DSN" --pg-pid $PGPID --hotrow 0 --out results/dbbench_pg_append.json
scripts/server.sh start && SPID=$(cat $SCR/run/server.pid)
$GEN loadgen.py --server-pid $SPID --pg-pid $PGPID --out results/seed_pg.json seed --n 10000 --tokens $SCR/data/tokens_pg.json
$GEN loadgen.py --server-pid $SPID --mem-floor 450 --pg-pid $PGPID --label mixed_pg_1k --out results/mixed_pg_1k.json mixed --tokens $SCR/data/tokens_pg.json --users 1000
$GEN loadgen.py --server-pid $SPID --mem-floor 450 --pg-pid $PGPID --label mixed_pg_10k --out results/mixed_pg_10k.json mixed --tokens $SCR/data/tokens_pg.json --users 10000
$GEN loadgen.py --server-pid $SPID --mem-floor 450 --pg-pid $PGPID --label ramp_pg --out results/ramp_pg.json ramp --tokens $SCR/data/tokens_pg.json --rates 400,700,900,1100,1300,1500 --step 20 --procs 2
$GEN loadgen.py --server-pid $SPID --mem-floor 450 --pg-pid $PGPID --label sell_pg --out results/sell_pg.json sell --tokens $SCR/data/tokens_pg.json --concurrency 1,8,32,128 --duration 15
COW_BACKUP_DIR=$SCR/backups scripts/pg_backup_restore.sh | tee results/pg_backup_restore.txt
scripts/server.sh stop && scripts/pg.sh down

# ---- SQLite（FULL，之後改 NORMAL 用同一個檔案）
export COW_DB=sqlite COW_SQLITE_PATH=$SCR/data/game.db COW_SQLITE_SYNC=FULL
scripts/server.sh start && SPID=$(cat $SCR/run/server.pid)
$GEN loadgen.py --server-pid $SPID --out results/seed_sqlite_full.json seed --n 10000 --tokens $SCR/data/tokens_sqlite.json
$GEN loadgen.py --server-pid $SPID --mem-floor 450 --label mixed_sqlite_full_1k --out results/mixed_sqlite_full_1k.json mixed --tokens $SCR/data/tokens_sqlite.json --users 1000
$GEN loadgen.py --server-pid $SPID --mem-floor 450 --label mixed_sqlite_full_10k --out results/mixed_sqlite_full_10k.json mixed --tokens $SCR/data/tokens_sqlite.json --users 10000
$GEN loadgen.py --server-pid $SPID --mem-floor 450 --label ramp_sqlite_full --out results/ramp_sqlite_full.json ramp --tokens $SCR/data/tokens_sqlite.json --rates 400,700,900,1100,1300,1500 --step 20 --procs 2
$GEN loadgen.py --server-pid $SPID --mem-floor 450 --label sell_sqlite_full --out results/sell_sqlite_full.json sell --tokens $SCR/data/tokens_sqlite.json
scripts/server.sh stop && export COW_SQLITE_SYNC=NORMAL && scripts/server.sh start && SPID=$(cat $SCR/run/server.pid)
#   同上，把 label／out 的 full 換成 normal：sell、ramp、mixed 10k、mixed 1k
for S in FULL NORMAL; do taskset -c 2 .venv/bin/python dbbench.py --db sqlite --path $SCR/data/bench_$S.db --sync $S --hotrow 1,0 --out results/dbbench_sqlite_${S,,}.json; done
COW_BACKUP_DIR=$SCR/backups/sqlite COW_TOKENS=$SCR/data/tokens_sqlite.json scripts/sqlite_backup_restore.sh | tee results/sqlite_backup_restore.txt

# ---- 即時行情（伺服器 tick 5 秒、每次 tick 後推播）
export COW_TICK_SEC=5 COW_WS_PUSH=1 COW_WS_AUTH=1 COW_SERVER_MEM=800M
# N=1000 的結果檔名是 ws_1k.json（當機前量的）
for N in 1000 2500 5000 10000; do
  scripts/server.sh stop; scripts/server.sh start; SPID=$(cat $SCR/run/server.pid)
  $GEN wsbench.py --server-pid $SPID --tokens $SCR/data/tokens_sqlite.json --procs 2 --mem-floor 1000 --label ws_$N --out results/ws_$N.json ws --n $N --connect-rate 500 --duration 30
done
for N in 1000 10000; do
  scripts/server.sh stop; scripts/server.sh start; SPID=$(cat $SCR/run/server.pid)
  $GEN wsbench.py --server-pid $SPID --tokens $SCR/data/tokens_sqlite.json --procs 2 --label poll_$N --out results/poll_$N.json poll --n $N --interval 10
done
# 重連（會用 SIGKILL 關掉 server.pid 的伺服器，再用 scripts/server.sh 重啟）
$GEN wsbench.py --tokens $SCR/data/tokens_sqlite.json --procs 1 --label reconnect_1k_jitter --out results/reconnect_1k_jitter.json reconnect --n 1000 --gap 5 --policy jitter --base-delay 0.5 --cap 30
$GEN wsbench.py --tokens $SCR/data/tokens_sqlite.json --procs 1 --label reconnect_1k_jitter_cap5 --out results/reconnect_1k_jitter_cap5.json reconnect --n 1000 --gap 5 --policy jitter --base-delay 0.5 --cap 5
$GEN wsbench.py --tokens $SCR/data/tokens_sqlite.json --procs 1 --label reconnect_1k_fixed1 --out results/reconnect_1k_fixed1.json reconnect --n 1000 --gap 5 --policy fixed1
scripts/server.sh stop

# 產生本文的表格
.venv/bin/python report.py
```

檔案：

| 檔案 | 內容 |
|---|---|
| `cowbench/server.py`、`cowbench/db.py` | 實測用 API 與資料庫層 |
| `loadgen.py` | HTTP 負載（seed／mixed／ramp／sell） |
| `dbbench.py` | 純資料庫 sell 交易 |
| `wsbench.py` | WebSocket 廣播、輪詢、重連 |
| `procmon.py` | 伺服器 CPU／RSS、PG cgroup、CPU 頻率、記憶體看門狗 |
| `fsyncbench.py` | 磁碟 fsync 延遲 |
| `sqlite_backup.py`、`scripts/*.sh` | 伺服器／PG 啟停、兩種備份還原 |
| `report.py` | 從 `results/*.json` 產生表格 |
| `results/*.json`、`results/*.txt` | 每次測試的摘要、系統取樣、參數 |
| `results/raw/*.csv.gz` | HTTP 測試每個請求的延遲原始資料 |
| `results/env.txt` | 環境 |

### 限制

- **開發機當機一次。** 2026-09-30 03:02:43 全機記憶體耗盡觸發 OOM killer（核心紀錄：swap 剩 104 kB），之後當機重開。當時我最後完成的是 03:02 的重連測試（我的程序合計估計 < 150 MB）。核心紀錄的程序清單在寫到一半時中斷，看不到 python、瀏覽器、其他 session 各佔多少，**無法判定元兇**。但那三次重連測試開始時可用記憶體只有 718–756 MB，低於我給 WebSocket 測試訂的 900 MB 門檻，而 `reconnect` 子命令當時沒有記憶體檢查——這是我的疏失，已補上啟動前檢查。重開機後只補跑了缺少的 WebSocket 2,500／5,000／10,000 與輪詢 10,000，當時可用記憶體 2.2–3.0 GB。
- 當機前的 PID 紀錄（`pids.log`）、測試資料庫與 token 都放在 /tmp，隨重開機消失；重開機後確認沒有殘留的伺服器程序、systemd scope 或我建立的容器（使用者自己的 podman 容器沒動過），補跑時重建了資料庫與 token，做完已用 PID 關閉伺服器。
- **這台筆電是共用的**：測試期間其他 session 在編譯 Flutter／跑 Dart（常瞬間多吃 500 MB、load average 最高 45）。同一測試在干擾大小不同時可差到數倍（例如 SQLite NORMAL 純 DB 588 vs 3,898 筆/秒；10,000 人 p99 84 vs 22 ms）。表中都附了 CPU 2 的外部佔用；結論只用「干擾小的那次」或「兩次都成立」的數字。
- **只在開發機量過。** CPU 是 2017 年的筆電低壓處理器、磁碟是入門 NVMe（fsync 4.6 ms）。雲端主機的 fsync 與單核速度都可能不同，換算標為「估計」。
- **沒量 TLS**（反向代理的 CPU）、沒量 Python 3.12 以上、沒量多個 uvicorn worker、沒量 rootless podman 的 port 轉發（用 `--network host` 避開）。
- 市場公式是佔位的；負載的動作比例、每人每 10–20 秒一次都是假設。
- 1,000 人的 WebSocket 是在記憶體吃緊、CPU 降頻時量的，和 2,500 人以上的條件不同。
- 重連只量了 1,000 條；10,000 條時的重連洪峰沒量。

### 來源

抓取日期都是 2026-09-30。

- FastAPI 部署概念 https://fastapi.tiangolo.com/deployment/concepts/ ；Server Workers https://fastapi.tiangolo.com/deployment/server-workers/ ；Docker https://fastapi.tiangolo.com/deployment/docker/
- uvicorn 設定 https://uvicorn.dev/settings/ ；伺服器行為 https://uvicorn.dev/server-behavior/ ；部署 https://uvicorn.dev/deployment/
- websockets 記憶體 https://websockets.readthedocs.io/en/stable/topics/memory.html ；廣播 https://websockets.readthedocs.io/en/stable/topics/broadcast.html
- SQLite：whentouse https://www.sqlite.org/whentouse.html ；WAL https://www.sqlite.org/wal.html ；pragma https://www.sqlite.org/pragma.html#pragma_synchronous ；備份 https://www.sqlite.org/backup.html ；VACUUM INTO https://www.sqlite.org/lang_vacuum.html
- Litestream https://litestream.io/how-it-works/ 、https://litestream.io/tips/
- PostgreSQL 17 pg_dump https://www.postgresql.org/docs/17/app-pgdump.html ；synchronous_commit https://www.postgresql.org/docs/17/runtime-config-wal.html
- Serverpod https://docs.serverpod.dev/ （版本 https://pub.dev/api/packages/serverpod ）
- Nakama https://heroiclabs.com/docs/nakama/getting-started/architecture/ 、https://heroiclabs.com/docs/nakama/getting-started/install/linux/ 、https://heroiclabs.com/docs/nakama/concepts/storage/
- flutter_secure_storage https://pub.dev/packages/flutter_secure_storage ；shared_preferences https://pub.dev/packages/shared_preferences ；Android Auto Backup https://developer.android.com/identity/data/autobackup
- Apple：NSAllowsLocalNetworking、NSLocalNetworkUsageDescription、Preventing Insecure Network Connections、TN3179（網址見第 6 節；以 `developer.apple.com/tutorials/data/documentation/<path>.json` 讀取）
- Flutter 網路政策（已於 2.2.0 撤回）https://docs.flutter.dev/release/breaking-changes/network-policy-ios-android
- Android network security config https://developer.android.com/privacy-and-security/security-config
- Cloudflare Quick Tunnel https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/
- 授權：PyPI（fastapi 0.142.0 MIT；uvicorn 0.54.0 BSD-3-Clause）
