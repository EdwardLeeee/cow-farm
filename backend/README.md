# cow-farm 伺服器（M1 連線原型）

FastAPI + PostgreSQL 17。規格：[`docs/design/m1-prototype.md`](../docs/design/m1-prototype.md)；協定（app 照這份寫）：[`docs/protocol.md`](../docs/protocol.md)。

**v0.2 玩法**（企劃書 4.0、決定 D17；2026-09-30）：乳牛／耕牛／肉牛、耕田與稻米行情、商店 A／B／C 等級抽牛、出貨評級、
每頭牛一輩子配種一次（自己配免費）、借種市場。引擎版本 0.2（`cowecon.ENGINE_VERSION`）。
v0.1 的資料庫不相容，見「從舊資料庫升級」。

| 路徑 | 內容 |
|---|---|
| `cowecon/` | 經濟引擎（行情與牧場規則，只用標準函式庫）。從 `docs/research/economy/cowecon/` 搬來，只保留這一份；研究模擬也 import 這一份。 |
| `server/game.py` | 服務層：收奶、賣出（牛奶、牛肉、稻米）、出貨評級、商店抽牛、配種、田地、借種、升級。**真人（API）和電腦假玩家呼叫同一組函式。** |
| `server/bots.py` | 假玩家六種玩法（乳牛、肉牛、耕田、配種收集、抓時機、出借公牛；W 大戶只給測試），照 `docs/research/economy/sim/bots.py`（v0.2）移植。 |
| `server/runtime.py` | 遊戲時鐘、市場 tick、假玩家排程、存檔與 request_id 防重送、WebSocket 推播、重啟回復。 |
| `server/app.py` | HTTP／WebSocket 端點、錯誤格式、網頁版靜態檔。 |
| `server/store.py` | PostgreSQL 表與存取。 |
| `server/views.py` | 把狀態變成協定的 JSON（協定 v2：不送中文顯示字，送代碼）。 |
| `server/breeds.py` | 24 個品種代號（用途 × 特徵組合，跟設計稿 `breeds.js` 一樣）。 |
| `server/ranchname.py` | 玩家自己取的牧場名：寬度、emoji、不能用的字元（協定 2.2 節）。 |
| `server/accounts.py` | 帳號：驗 Apple／Google 的登入憑證、呼叫 Apple（換 refresh token、撤銷）、加密 refresh token、nonce 與換回憑單（協定第 5 節）。 |
| `server/data/extended_pictographic.json` | emoji 的區間表（Unicode 13.0 emoji-data 的 Extended_Pictographic），`scripts/gen_name_tables.py` 產生。 |
| `server/data/name_cases.json` | 牧場名規則的測試向量（給 app 和設計稿的 i18ncheck 跑），`tests/test_ranchname.py` 產生。 |
| `server/data/ranch_words.json` | 電腦牧場名的詞庫（3 組 × 12 詞）。協定只送編號，app 用字串表 `namegen.*` 組；繁中跟字串表一樣（i18ncheck 會檢查）。 |
| `scripts/pg.sh` | PostgreSQL 容器（rootless podman）的啟停、備份、清掉資料庫重來（`resetdb`）。 |
| `scripts/serve.sh` | 在背景啟動／停止伺服器。 |
| `scripts/maint.py` | 安排、查詢、結束伺服器維護（寫資料庫並通知執行中的伺服器）。 |
| `scripts/gen_name_tables.py` | 從 Unicode 13.0 的 emoji-data.txt 產生牧場名用的 emoji 區間表。 |
| `tests/` | pytest：存檔回復、經濟情境、協定、重啟回復。 |

## 1. 安裝（第一次）

需要 Python 3.10、podman（rootless）。套件裝在 `backend/.venv`（已被 .gitignore 排除），不裝到系統。

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

## 2. PostgreSQL

**記憶體安全**（這台電腦 2026-09-30 因記憶體耗盡當機過）：先看 `free -m`，available 少於 1000 MB 就等一下（使用者 2026-10-03 從 2000 MB 改成 1000 MB）。`pg.sh up` 也會檢查（加 `--force` 可以略過）。

```bash
free -m
scripts/pg.sh up        # 第一次：產生密碼檔、建立容器 cowfarm-pg 與資料卷 cowfarm-pgdata；之後：啟動既有容器
scripts/pg.sh status    # 狀態與記憶體
scripts/pg.sh stop      # 停止（資料留著；再 up 就回來）
scripts/pg.sh psql      # 進資料庫
scripts/pg.sh dump cowfarm.dump   # 線上備份（在容器裡跑 pg_dump；主機的 pg_dump 14 不能備份 17）
scripts/pg.sh resetdb [名稱]      # 清掉一個資料庫重建成空的（預設 cowfarm；要輸入名稱確認）
scripts/pg.sh destroy   # 刪除容器、資料卷與密碼檔（所有遊戲資料消失；要輸入 DESTROY）
```

- 容器：`postgres:17`，`--memory 256m`，`--network host`，只聽 `127.0.0.1:55433`（不對區網開放）。
- 密碼：每台電腦第一次 `up` 時隨機產生，存在 `~/.config/cow-farm/pg.env`（權限 600，不進 repo）。伺服器自己會讀這個檔；也可以用環境變數 `COWFARM_PG_DSN` 指定別的資料庫。
- 密碼只在第一次建立資料卷時設定。如果資料卷還在、密碼檔不見了，`up` 會停下來：找回 `pg.env`，或 `destroy` 重來。

## 3. 啟動伺服器

伺服器聽 `0.0.0.0:8787`，同一個 Wi-Fi 的 iPhone 可以連進來。

```bash
# 試玩：倍率 144（遊戲 1 天 = 現實 10 分鐘），在背景跑，記憶體限制 1500 MB
scripts/serve.sh start 144
scripts/serve.sh status   # PID、記憶體、/healthz
scripts/serve.sh logs     # 最後 50 行日誌（~/.cache/cow-farm/server.log）
scripts/serve.sh stop     # 用 PID 停止

# 或在前景跑（Ctrl-C 停止）
COWFARM_TIME_SCALE=144 systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 .venv/bin/python -m server
```

加上網頁版（`app/build/web` 由 app 那邊用 `flutter build web` 產生；資料夾不存在時伺服器照常啟動，只是 `/` 沒有網頁）：

```bash
COWFARM_WEB_DIR=$PWD/../app/build/web scripts/serve.sh start 144
```

iPhone 在同一個 Wi-Fi 用 Safari 開 `http://<這台電腦的區網 IP>:8787/`（`serve.sh start` 會印出來）。
網頁資料夾只在伺服器啟動時掛上：`flutter build web` 是在伺服器啟動之後才做的話，要 `serve.sh stop` 再 `start` 一次。

| 環境變數 | 預設 | 說明 |
|---|---|---|
| `COWFARM_TIME_SCALE` | 1 | 遊戲時間倍率；試玩 144 |
| `COWFARM_WEB_DIR` | 無 | Flutter 網頁版的資料夾，在 `/` 提供 |
| `COWFARM_BOTS` | 30 | 電腦假玩家數（只會增加，不會刪） |
| `COWFARM_PORT`／`COWFARM_HOST` | 8787／0.0.0.0 | |
| `COWFARM_PG_DSN` | 讀 `~/.config/cow-farm/pg.env` | 資料庫 |
| `COWFARM_SEED`、`COWFARM_GAME_START` | 隨機、現在 | 只在第一次建立世界時用（測試用） |
| `COWFARM_RUN_DIR` | `~/.cache/cow-farm` | `serve.sh` 的 PID 與日誌位置；同時跑第二台伺服器時換一個，才不會停到別台 |

同時跑第二台（例如驗證用，不動 8787 上的試玩伺服器）：

```bash
DSN="$(grep ^COWFARM_PG_DSN ~/.config/cow-farm/pg.env | cut -d= -f2- | sed 's#/cowfarm$#/cowfarm_v02#')"
scripts/pg.sh resetdb cowfarm_v02 --yes           # 空的資料庫
COWFARM_RUN_DIR=/tmp/cowfarm-v02 COWFARM_PORT=8789 COWFARM_PG_DSN="$DSN" scripts/serve.sh start 144
COWFARM_RUN_DIR=/tmp/cowfarm-v02 COWFARM_PORT=8789 scripts/serve.sh stop
```

啟動時日誌會印 `cowecon 參數指紋`：跟 `docs/research/economy/out/goals.json` 的 `params_fingerprint` 相同，代表用的是模擬驗證過的那一份參數。改了 `cowecon/params.py`（例如 D26 的借種費）之後會不同，要等 ceo 重跑經濟模擬。

### 遊戲時間與重啟

- 遊戲時間 = 開服遊戲時間 + (現實時間 − 開服現實時間) × 倍率；市場每遊戲分鐘 tick 一次。
- **伺服器關著的那段**（`server/runtime.py` 的 `resume_game_time`；ceo 2026-10-02）：
  - 倍率 1（正式版）：照真實時間走，關機那段也算。重開後奶桶照樣累積、田裡照樣長、市場補跑那段的 tick（一次最多 120 個 tick 存一次檔），電腦假玩家不補做關機那段排好的動作。
  - 其他倍率（試玩）：暫停，重啟後從上次存下的時間接著走。試玩時晚上關機，隔天牧場不會一下子老 48 遊戲天。
- 強制終止（`kill -9`、當機）也不會丟已經回覆給手機的動作：每個動作回覆前已經寫進資料庫；市場狀態每個 tick 存一次，之後的成交照序號重建。
- 正常停止（`serve.sh stop`）會存下關機那一刻的遊戲時間和現實時間；強制終止時從最後一個 tick 存下的接著算，所以試玩倍率重啟後的遊戲時間可能比斷線前最後看到的早一點（最多 1 遊戲分鐘），牧場狀態不受影響。

### 從舊資料庫升級（v0.1 → v0.2 → 協定 v2）

**原型階段直接清掉重來，不做搬移。** 伺服器啟動時發現資料庫是不相容的舊世界，會停下來並在日誌說明（不會讀到一半壞掉）：

- v0.1 的世界：只有兩個市場、牛的規則也不同（兼用牛產奶、配種有冷卻）。
- v0.2 的世界（存檔格式 2）：圖鑑是「用途 × 稀有度」12 格。協定 v2 改成 24 品種（存檔格式 3，`server/runtime.py` 的 `WORLD_FORMAT`），舊的圖鑑分不出品種，無法完整搬（ceo 2026-10-02：舊世界拒絕啟動，8787 換新版時由 ceo 重建資料庫）。

```bash
scripts/serve.sh stop            # 先停掉用這個資料庫的伺服器
scripts/pg.sh resetdb            # 清掉 cowfarm 重建成空的（要輸入 cowfarm 確認）
scripts/serve.sh start 144       # 建立新世界（30 位假玩家、公營種牛站的 3 頭公牛）
```

玩家的 token 會失效：app 收到 `401 unauthorized` 時顯示 S15-03，玩家重新開牧場（協定 2.1 節）。
想留一份舊資料的話，清掉前先 `scripts/pg.sh dump cowfarm-old.dump`。

### 帳號：Apple／Google 登入（協定第 5 節）

M4 以前的伺服器沒有 Apple、Google 的設定：綁定和找回回 `sign_in_failed`（`not_configured`），其他照常。M4 由使用者照 ceo 的步驟在 Apple Developer、Google Cloud 建好以後，設這些環境變數（研究：`docs/research/2026-10-sso-verification.md`）：

| 環境變數 | 內容 |
|---|---|
| `COWFARM_APPLE_CLIENT_IDS` | Apple 的 client_id（App ID：`com.oraclelee.cowfarm`），可以用逗號隔開好幾個 |
| `COWFARM_GOOGLE_CLIENT_IDS` | Google 的 Web client ID（手機 app 拿 ID token 用的 server client ID） |
| `COWFARM_APPLE_TEAM_ID`、`COWFARM_APPLE_KEY_ID`、`COWFARM_APPLE_KEY_FILE` | Team ID、金鑰 ID、.p8 檔的路徑（權限 600，不進 git） |
| `COWFARM_TOKEN_KEY_FILE` | 加密 Apple refresh token 的金鑰檔；預設 `~/.config/cow-farm/token.key`。伺服器啟動時沒有就自動產生（權限 600），沒有 Apple 設定也會產生 |

- 金鑰照 secrets-custody：`.p8` 和 `token.key` 都不進 git、不寫日誌，要另外備份。`token.key` 不見了，存著的 Apple refresh token 就解不開，那時只能請使用者自己到 Apple 帳號設定解除。
- Apple 撤銷失敗（例如 Apple 連不上）會放在 `apple_revoke_queue`，伺服器每 60 個 tick 重試一次（1 分鐘起、每次加倍、最多 1 小時）；刪除牧場不會因此失敗（Apple TN3194）。
- 刪除牧場是軟刪除：`players` 留一列只有編號和時間的空殼，名字、登入憑證、綁定、進度都刪掉；編號不會被新牧場重複使用。

### 維護（協定第 6 節）

```bash
.venv/bin/python scripts/maint.py schedule "2026-10-03 03:00" +1h   # 預告：台灣時間 03:00 開始，預計 1 小時
.venv/bin/python scripts/maint.py schedule now +30m                  # 馬上開始
.venv/bin/python scripts/maint.py status
.venv/bin/python scripts/maint.py end                                # 結束維護（或取消預告）
```

- 腳本直接寫資料庫的 `meta`（`maintenance`），再 NOTIFY `cowfarm_admin`；執行中的伺服器馬上生效，另外每 30 秒自己讀一次。
  不經過 API，所以不用另一套管理用的認證：能連資料庫的人才能改。資料庫照伺服器的設定（`COWFARM_PG_DSN` 或 `pg.env`）。
- 預告時照常玩，app 從 `/v1/status`、`/v1/state`、WebSocket 的 `maintenance` 拿到時間。開始以後，除了 `/v1/status` 都回 503，
  WebSocket 先送 `maintenance` 再用 4503 關閉。過了預計結束時間還沒 `end` 就照樣維護中。
- 伺服器整個停掉（部署）的那幾分鐘沒有程式能回 503：M4 由反向代理（Caddy／nginx）在後端連不上時回一份同形狀的 503 JSON
  （`{"error": {"code": "maintenance", "message": "伺服器維護中", "detail": {"ends_at_real": …}}}`），跟部署一起做。

### 原型規則（試玩後再定）

- **出貨後的牛肉放在倉庫**，之後再用賣出賣掉（規格如此；經濟引擎原本是出貨即賣出）。倉庫裡的牛肉 24 遊戲小時內價值不變，之後 96 小時降到 6 成，之後維持 6 成；不佔牛奶倉庫的容量，不設上限。ceo 2026-09-30 核准為原型規則，冷凍庫容量與牛肉新鮮度的正式數字等使用者試玩後再定。
- 假玩家出貨後立刻賣（抓時機派例外，會存著等好價），和研究模擬的規則相同。
- 田地是「稻米持續長、長滿就停、收成清空」（和奶桶同一種算法），不是企劃書寫的「耕地 → 種稻 → 收成」週期；研究筆記 9.2 說明了原因。

## 4. 測試

```bash
free -m    # available ≥ 1000 MB 再跑；試玩或長時間跑的時候用 scripts/pg.sh status 看 PostgreSQL 的記憶體（上限 256 MB，大部分是可回收的檔案快取）
scripts/pg.sh up
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 .venv/bin/python -m pytest -q
```

約 4 分鐘。會建立 `cowfarm_test_*` 資料庫（每次重建），不會碰到試玩用的 `cowfarm` 資料庫；沒有資料庫時，需要資料庫的測試會 skip。

排版和 lint（CI 會檢查；ruff 要跟 CI 同版：`.venv/bin/pip install ruff==0.15.2`）：

```bash
.venv/bin/ruff format .          # 行寬 120，設定在 repo 根目錄的 ruff.toml
.venv/bin/ruff check ..          # 整個 repo 的 Python
```

| 檔案 | 測什麼 | 要資料庫 |
|---|---|---|
| `test_persist.py` | cowecon 各類別（含田地、稻米、借種市場）存檔回復；同一個 seed「跑一半存檔、回復、再跑」＝「一路跑到底」（每個數字） | 否 |
| `test_scenarios.py` | v0.2 經濟情境在服務層重跑並達到筆記的目標；和研究模擬逐數字相同（見下） | 否 |
| `test_accounts_unit.py` | 帳號零件：真的驗證程式照官方步驟擋錯的 token（自己的金鑰）、呼叫 Apple 的請求格式（假的傳輸層）、金鑰檔權限、nonce、換回憑單 | 否 |
| `test_accounts.py` | 帳號流程：nonce、綁定、換回、找回（舊手機 401／4401）、解除、軟刪除（空殼沒有個資）、Apple 撤銷重試、編號不重複使用 | 是 |
| `test_ranchname.py` | 牧場名規則：寬度跟設計稿 `namewidth.js` 逐字相同、跟 Unicode 13.0 一致、emoji 與不能用的字元、測試向量檔 | 否 |
| `test_views.py` | 協定 v2 的代碼對照：24 品種代號跟設計稿 `breeds.js` 一致、新聞代碼跟字串表 `news.*` 一致、電腦牧場名的詞庫編號組得回原名、公營種牛站的名字固定 | 否 |
| `test_api.py` | 協定欄位、request_id 防重送（含抽牛、出貨、借種）、錢不夠、牛不存在、還沒長大、牛舍滿、格式錯誤、WebSocket 與 4401；v0.2：抽牛機率與引擎一致（含抽樣）、評級機率與抽法、配種一次、借種付款與小牛歸屬、田地流程、舊資料庫拒絕啟動；協定 v2：牧場物件、新聞代碼、24 品種圖鑑、舊存檔格式拒絕啟動、建立牧場的名字檢查與 request_id 重送、借種費（D26）與 price_changed、借種紀錄、維護（503、4503、腳本通知伺服器） | 是 |
| `test_recovery.py` | 當機回復逐數字相同（含借種市場、田地）；「跑一半當機再跑」＝「一路跑到底」；真的伺服器程序 SIGKILL 後重開；倍率 1 關機一小時後重開（照真實時間走） | 是 |

經濟代理還在調 `cowecon/params.py` 的數值：測試裡的期望值都由引擎算，不寫死數字。
假玩家的調整值（`server/bots.py` 的 `VALUE_TABLE` 等）要和研究模擬同步：不同步時 `test_bot_tunables_match_research` 會出警告（不算失敗），
逐數字比對的測試會先把研究模擬的調整值複製過來再比，比的是流程。

經濟情境（`test_scenarios.py`，約 2.5 分鐘）的規模：10 人（seed 1–5）與 100 人（seed 1–3）各 30 天；大戶（100 人＋100 頭，倒貨／分批／一直囤）、大利多後恐慌賣（100 人）各 23 天；人少的一天（100 人）20 天。1,000 人 30 天預設不跑（`COWFARM_SCENARIO_1000=1` 才跑）；1,000 人的大戶與 10,000 人沒有在服務層重跑。服務層和研究模擬同一個 seed 逐數字相同（10 人 30 天、大戶倒貨、恐慌賣有測試比對），所以筆記裡 1,000／10,000 人的數字同樣適用。

### 改到經濟引擎的行為時：CI 會紅在 `test_numbers_match_research_note`

`test_numbers_match_research_note` 用研究筆記 `docs/research/economy/out/goals.json` 的數字，比對服務層重跑 10 人（seed 1–5）30 天的結果（誤差 1e-12）：

- 價格在 0.6–1.7 倍的時間比例（各 seed 最低）
- 每天的借種成交數
- 出借派的借種收入佔比
- 六種玩法 30 天的總收入

只有 `goals.json` 的參數指紋跟現在的 `cowecon/params.py` 一樣時才比，不一樣就 skip。

`test_identical_to_research_sim` 只證明伺服器和研究模擬兩邊一樣；兩邊共用 `cowecon`，所以改了引擎它還是會通過，看不出研究結果變了。真正擋下來的是上面這個測試。

改到 `cowecon` 的行為（不只改 `params.py` 的數字；例如 #89 把公營種牛站改成缺哪種補哪種）時，照三步走：

1. 改引擎的人推修改、開 PR。PR 說明寫改了什麼行為，最好附上自己重跑一兩個情境的比對（`cd docs/research/economy && python -m sim.run --only base_10_s1,base_100_s1 --force`，各幾秒；重跑的檔案不要提交，比完用 `git checkout` 還原）。
2. CI 會紅在 `test_numbers_match_research_note`。這是預期的，代表研究筆記的數字過期了。
3. ceo 在**同一個分支**重跑完整模擬（36 個情境，約 20 分鐘），加上 `out/` 和研究筆記的 commit，CI 變綠以後再合併。

研究模擬（`docs/research/economy/`）自己的單元測試照樣可以跑：

```bash
cd ../docs/research/economy && python3 -m unittest
```

## 5. 停止與清除

```bash
scripts/serve.sh stop      # 停伺服器（用 PID）
scripts/pg.sh stop         # 停 PostgreSQL（資料留著）
scripts/pg.sh destroy      # 全部清掉：容器、資料卷、密碼檔（要輸入 DESTROY）
```

只想重開一個新世界、保留容器：先停伺服器，`scripts/pg.sh psql postgres` 裡執行 `DROP DATABASE cowfarm WITH (FORCE); CREATE DATABASE cowfarm;`。測試資料庫 `cowfarm_test_*` 也可以這樣 DROP。
