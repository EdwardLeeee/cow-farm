# cow-farm 協定 v1（手機 ↔ 伺服器）

- 狀態：M1 連線原型（2026-09-30）。伺服器實作在 `backend/server/`，這份文件由伺服器端（cow-back）負責。
- 跟 `docs/design/m1-prototype.md` 的表格不一致時，**以這份為準**；不一樣的地方逐條列在最後一節「跟規格表不一樣的地方」。
- 原型階段可以改，但要同步更新這份文件。上架以後只能新增欄位、不能改名、改型別或刪除（api-evolution）。
- 用戶端（app）要忽略不認得的欄位與不認得的 WebSocket 訊息類型：伺服器之後只會「加」。

## 1. 通則

### 1.1 連線

| 項目 | 值 |
|---|---|
| 網址 | 區網試玩：`http://<開發機區網 IP>:8787`。網頁版（Flutter build web）也由同一個埠的 `/` 提供。 |
| 格式 | 請求與回應都是 JSON（UTF-8）。 |
| 認證 | 除了 `POST /v1/session` 以外，都要帶 `Authorization: Bearer <token>`。WebSocket 見第 4 節。 |
| CORS | 開放所有來源（token 放 header、不用 cookie），`flutter run -d web-server` 用別的埠也能連。 |

### 1.2 時間

- **所有時間欄位都是「遊戲時間」的 Unix 秒數**（數字，可以有小數），不用 ISO 字串。app 一律照台灣時間 UTC+8 顯示。
- 遊戲時間 = 開服遊戲時間 + (現實時間 − 開服現實時間) × 倍率。倍率由伺服器的 `COWFARM_TIME_SCALE` 決定（試玩 144：遊戲 1 天 = 現實 10 分鐘）。
- 每個回應都附：

  | 欄位 | 型別 | 說明 |
  |---|---|---|
  | `server_time` | number | 伺服器處理這個請求時的遊戲時間 |
  | `real_time` | number | 當時的現實 Unix 秒數（只供除錯與對時參考） |
  | `time_scale` | number | 倍率 |

- **手機不送任何時間**，伺服器也不看手機時間。倒數、奶桶動畫由手機換算：
  `現在的遊戲時間 ≈ server_time + (手機單調時鐘的經過秒數) × time_scale`。
  「經過秒數」請用單調時鐘（例如 Dart 的 `Stopwatch`），不要用手機的牆上時間，這樣改手機時間連畫面都不受影響。
- 伺服器關著的時候遊戲時間**暫停**，重啟後從上次的時間接著走（M1 的選擇，見第 7 節）。

### 1.3 會改變狀態的請求：`request_id`

- `POST /v1/collect`、`/v1/sell`、`/v1/ship`、`/v1/buy_calf`、`/v1/breed`、`/v1/upgrade` 都**必須**帶 `request_id`（UUID 字串，例如 `"3f1c…"`）。
- 每個「使用者動作」產生一個新的 UUID；網路逾時要重送時，**用同一個 request_id** 重送。
- 同一位玩家、同一個 request_id 重送：伺服器不再執行一次，直接回傳**第一次的回應本文**（HTTP 200，內容逐字相同，包括當時的 `server_time`）。所以重送拿到的 `state` 可能是舊的，之後請再 `GET /v1/state`。
- 只有**成功**的結果會被記住。失敗（4xx）沒有改變任何狀態，用同一個 request_id 重送會重新判斷。
- 同一個 request_id 拿去做別種動作（例如先 `sell` 再 `ship`）：回 `409 request_id_reused`。
- request_id 以玩家為範圍，保存 7 天（現實時間）。

### 1.4 錯誤

一律是 HTTP 4xx（伺服器錯誤是 500），本文：

```json
{"error": {"code": "not_enough_coins", "message": "金幣不夠", "detail": {"need": 1000, "have": 414}}}
```

| 欄位 | 說明 |
|---|---|
| `code` | 穩定的英文代碼，app 用它決定怎麼處理。 |
| `message` | 繁體中文，可以直接顯示。 |
| `detail` | 選填，有額外資訊時才有（例如 `need`／`have`、`until`）。 |

錯誤碼一覽：

| HTTP | code | 什麼時候 | detail |
|---|---|---|---|
| 400 | `bad_request` | 欄位缺少、型別不對（數字不接受字串或 true/false）、request_id 不是 UUID、qty ≤ 0 | 格式錯誤時有 `fields`（哪些欄位） |
| 400 | `invalid_pair` | 配種不是「一頭公牛 + 一頭母牛」 | |
| 401 | `unauthorized` | 沒帶 token 或 token 無效 | |
| 404 | `cow_not_found` | 牛的 id 不在自己的牧場 | `cow_id` |
| 404 | `not_found` | 網址不存在 | |
| 405 | `method_not_allowed` | 方法不對 | |
| 409 | `not_enough_coins` | 金幣不夠 | `need`、`have`（整數） |
| 409 | `not_enough_stock` | 倉庫裡沒有這麼多牛奶／牛肉 | `have`、`want` |
| 409 | `pen_full` | 牛舍滿了（買小牛、配種都要有空格） | `slots` |
| 409 | `cow_not_adult` | 小牛還沒長大（不能出貨、不能配種） | `adult_at` 或 `cow_id`、`until` |
| 409 | `breed_cooldown` | 配種冷卻中 | `cow_id`、`until`（可以再配的遊戲時間） |
| 409 | `max_level` | 已經是最高級 | |
| 409 | `not_yet_available` | 第一次擴建還沒開放（教學第 15 分鐘開放） | `open_at` |
| 409 | `request_id_reused` | 同一個 request_id 用在別的動作 | `endpoint` |
| 409 | `rejected` | 其他無法執行的情況（理論上不會出現） | |
| 500 | `internal` | 伺服器錯誤，狀態沒有改變，可以用同一個 request_id 重送 | |

### 1.5 數字

- 金幣、費用、估值都是**整數**。價格、數量是小數（數量最多 6 位小數）。
- 牛奶單位是「瓶」，牛肉單位是「公斤」。倉庫裡的牛奶是連續累積的，數量可能有小數。
- 要「全部賣出」時，送 `GET /v1/state` 裡的 `warehouse.milk_total`（或 `beef_total`）原值；伺服器把「和庫存相差 0.000001 以內」視為全部。

## 2. 帳號與牧場

### `POST /v1/session` 建立訪客帳號

請求本文：不需要（有也忽略）。回應：

```json
{"server_time": 1791129600.0, "real_time": 1790736267.97, "time_scale": 144.0,
 "token": "gJ77xMDokb7Gk8zg69N-22Jvvlo-1PkIhQB6TdpNAsM", "player_id": 7, "ranch_name": "麥浪石橋牧野", "created": true}
```

| 欄位 | 說明 |
|---|---|
| `token` | 登入憑證（43 字元）。放 `flutter_secure_storage`（T1）。伺服器只存它的 SHA-256。 |
| `player_id` | 整數。 |
| `ranch_name` | 伺服器從詞庫（`backend/server/data/ranch_words.json`，3 組 × 12 詞）隨機組合，玩家不能自己取名。 |
| `created` | 一律 `true`（這個端點只會建立新帳號）。 |

收到 `401 unauthorized` 時（例如伺服器資料庫被清掉），app 重新呼叫這個端點建立新帳號。

### `GET /v1/state` 整個牧場

回應（節錄；`cows` 只列兩頭）：

```json
{
 "server_time": 1791141660.0, "real_time": 1790736271.85, "time_scale": 144.0,
 "player_id": 7, "ranch_name": "麥浪石橋牧野",
 "coins": 414,
 "level": 2, "level_progress": {"earned": 594, "level_at": 500, "next_at": 1500},
 "cows": [
  {"id": 2, "type": "dual", "type_name": "兼用", "bull": true, "tier": 0, "tier_name": "一般", "stage": "adult",
   "born_at": 1791129600.0, "adult_at": 1791130800.0, "ready_at": 1791138060.0, "breed_ready": true, "age_h": 3.35,
   "milk_per_h": 0.0, "milk_frac": 0.0, "weight_kg": 52.09, "beef_quality": 1.0, "ship_value": 606},
  {"id": 3, "type": "dual", "type_name": "兼用", "bull": false, "tier": 0, "tier_name": "一般", "stage": "calf",
   "born_at": 1791130860.0, "adult_at": 1791134460.0, "ready_at": 1791134460.0, "breed_ready": false, "age_h": 0.0,
   "milk_per_h": 0.0, "milk_frac": 0.0, "weight_kg": 0.0, "beef_quality": 1.0, "ship_value": 0}
 ],
 "bucket": {"qty": 0.0, "by_tier": [0.0, 0.0, 0.0, 0.0], "capacity": 24.0, "per_hour": 55.0,
            "boost": {"mult": 5.0, "until": 1791133200.0}},
 "warehouse": {"capacity": 150.0, "used": 20.0, "milk_total": 20.0, "beef_total": 40.236111,
   "milk_lots": [{"qty": 20.0, "tier": 0, "collected_at": 1791129600.0, "freshness": 1.0,
                  "fresh_until": 1791151200.0, "spoils_at": 1791453600.0}],
   "beef_lots": [{"qty": 40.236111, "tier": 0, "cow_id": 1, "shipped_at": 1791141660.0, "quality": 1.0, "storage_factor": 1.0}]},
 "pen": {"slots": 3, "used": 2, "next_cost": 588, "next_open_at": null, "max_slots": 40},
 "upgrades": {
  "pen": {"level": 1, "cost": 588, "next_open_at": null, "slots": 3, "next_slots": 4},
  "bucket": {"level": 0, "cost": 200, "capacity": 24.0, "next_capacity": 36.0},
  "warehouse": {"level": 0, "cost": 300, "capacity": 150.0, "next_capacity": 225.0},
  "fresh": {"level": 0, "cost": 1500, "fresh_h": 6.0, "half_h": 48.0, "next_fresh_h": 9.0, "next_half_h": 60.0}},
 "shop": {"calf_price": {"dairy": 1000, "dual": 1000, "beef": 1000}},
 "breed": {"first_free": false},
 "codex": [{"type": "dairy", "tier": 0}, {"type": "dual", "tier": 0}]
}
```

頂層：

| 欄位 | 型別 | 說明 |
|---|---|---|
| `coins` | int | 金幣 |
| `level` | int | 等級，只是顯示。累積賣出收入（牛奶＋牛肉）≥ 500 × (2^(L−1) − 1) 就是 L 級：1 級 0、2 級 500、3 級 1,500、4 級 3,500… |
| `level_progress` | object | `earned` 累積賣出收入、`level_at` 這一級的門檻、`next_at` 下一級的門檻 |
| `shop.calf_price` | object | 各用途小牛的價格 `{"dairy", "dual", "beef"}`（目前都是 1000）。錢不夠就停用按鈕。 |
| `breed.first_free` | bool | 下一次配種免費（新手教學：第一次配種免費） |
| `codex` | array | 已發現的「用途 × 稀有度」，每格 `{"type", "tier"}`；共 3 × 4 = 12 格，沒出現在陣列裡的顯示「？」。牛一出生（或買進）就算發現，之後出貨也不會消失。 |

`cows[]` 每頭牛：

| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | int | 牛的編號（在自己的牧場裡唯一），送回伺服器時原樣送 |
| `type` | string | 用途：`dairy` 乳用、`dual` 兼用、`beef` 肉用（`type_name` 是中文） |
| `bull` | bool | true = 公牛（公牛不產奶） |
| `tier` | int | 稀有度 0 一般、1 優良、2 稀有、3 傳說（`tier_name` 是中文） |
| `stage` | string | `calf` 還沒長大；`adult` 壯年；`old` 過了巔峰（母牛：成年 48 遊戲小時後產奶開始下降；公牛：成年 96 小時後肉質開始下降） |
| `born_at` | number | 出生（買進）的遊戲時間 |
| `adult_at` | number | 長大的遊戲時間（倒數用） |
| `ready_at` | number | 可以（再）配種的遊戲時間；還沒長大時 = `adult_at` |
| `breed_ready` | bool | 現在可以配種（已長大且冷卻結束） |
| `age_h` | number | 出生後幾個遊戲小時 |
| `milk_per_h` | number | 這頭牛現在每小時產奶（瓶），**不含**新手期加倍；整座牧場的產量看 `bucket.per_hour` |
| `milk_frac` | number | 產奶是壯年的幾成（0.4–1；公牛與小牛為 0） |
| `weight_kg` | number | 現在出貨可得的牛肉（公斤）；小牛為 0 |
| `beef_quality` | number | 肉質（0.6–1），過了最佳體重 24 小時後開始下降 |
| `ship_value` | int | 現在出貨並立刻全部賣出的估計收入（幣），已含市價、稀有度、肉質與這位玩家的滑價；小牛為 0 |

`bucket`（奶桶，離線也會累積，滿了就停）：

| 欄位 | 說明 |
|---|---|
| `qty` | `server_time` 當下奶桶裡的牛奶（瓶） |
| `by_tier` | 各稀有度的量 `[一般, 優良, 稀有, 傳說]`（稀有牛的牛奶賣價較高） |
| `capacity` | 容量 |
| `per_hour` | 整座牧場現在每小時產量，**已含新手期加倍**。app 用 `min(capacity, qty + per_hour × 經過的遊戲小時)` 平滑推算 |
| `boost` | 新手期加倍 `{"mult": 5.0, "until": 遊戲時間}`；結束後是 `null`。跨過 `until` 時產量會變，app 可以在那時重抓 state |

`warehouse`（倉庫）：

| 欄位 | 說明 |
|---|---|
| `capacity` | 牛奶容量（瓶）；牛肉不佔這個容量 |
| `used` | 牛奶佔用量（含已經壞掉、還沒丟掉的） |
| `milk_total` | 可以賣的牛奶（瓶，不含壞掉的） |
| `beef_total` | 牛肉（公斤） |
| `milk_lots[]` | 每次收奶一批：`qty`、`tier`、`collected_at`、`freshness`（0–1，賣價乘上它；0 = 壞掉，下次收奶或賣出時丟掉）、`fresh_until`（新鮮度開始下降的時間）、`spoils_at`（壞掉的時間） |
| `beef_lots[]` | 每出貨一頭一批：`qty`（公斤）、`tier`、`cow_id`、`shipped_at`、`quality`（現在的肉質，含放在倉庫的衰減）、`storage_factor`（倉庫衰減那一部分） |

賣出時一律**最舊的先賣**，最後一批可以只賣一部分。

`pen`（牛舍）與 `upgrades`：

| 欄位 | 說明 |
|---|---|
| `pen.slots`／`used`／`max_slots` | 格數、已用（= 牛的頭數）、上限 40 |
| `pen.next_cost` | 下次擴建的費用；`null` = 已滿級 |
| `pen.next_open_at` | 下次可以擴建的遊戲時間；`null` = 已經開放（只有第一次擴建要等到教學第 15 分鐘） |
| `upgrades.<kind>.cost` | 下一級的費用；`null` = 已滿級。kind 是 `pen`、`bucket`、`warehouse`、`fresh` |
| `upgrades.<kind>.level` | 目前等級（`pen` 是擴建過幾次） |
| `upgrades.bucket`／`warehouse` | `capacity` 目前容量、`next_capacity` 升級後容量 |
| `upgrades.fresh` | 冷藏：`fresh_h` 牛奶維持 100% 的小時數、`half_h` 降到 50% 的小時數，`next_*` 是升級後 |

### `POST /v1/collect` 收奶

請求：`{"request_id": "<uuid>"}`

回應（另外附完整的 `state`，形狀同 `GET /v1/state`，這裡省略）：

```json
{"server_time": 1791129600.0, "real_time": 1790736267.98, "time_scale": 144.0,
 "collected": 20.0, "spoiled": 0.0, "warehouse_full": false, "coins": 100,
 "bucket": {"qty": 0.0, "by_tier": [0.0, 0.0, 0.0, 0.0], "capacity": 24.0, "per_hour": 55.0, "boost": {"mult": 5.0, "until": 1791133200.0}},
 "warehouse": {"capacity": 150.0, "used": 20.0, "milk_total": 20.0, "beef_total": 0.0,
   "milk_lots": [{"qty": 20.0, "tier": 0, "collected_at": 1791129600.0, "freshness": 1.0, "fresh_until": 1791151200.0, "spoils_at": 1791453600.0}],
   "beef_lots": []},
 "state": {"…": "同 GET /v1/state"}}
```

| 欄位 | 說明 |
|---|---|
| `collected` | 這次從奶桶移到倉庫幾瓶 |
| `spoiled` | 順便丟掉幾瓶已經壞掉的牛奶 |
| `warehouse_full` | 倉庫滿了、奶桶還有剩（不是錯誤，回 200） |

## 3. 市場

### `POST /v1/sell/quote` 賣出前試算（不成交）

請求：`{"commodity": "milk", "qty": 15}`（`commodity` 是 `milk` 或 `beef`；`qty` > 0）

```json
{"server_time": 1791129600.0, "real_time": 1790736267.99, "time_scale": 144.0,
 "commodity": "milk", "qty": 15.0, "avg_price": 10.448352, "total": 157, "market_price": 10.477821,
 "discount": 0.002812, "warn_big_order": false}
```

| 欄位 | 說明 |
|---|---|
| `qty` | 會賣出的量（超過庫存會回 `409 not_enough_stock`） |
| `avg_price` | 預估成交均價（每瓶／每公斤，含稀有度、新鮮度、肉質、滑價） |
| `total` | 預估收入（整數幣） |
| `market_price` | 現在的市價 |
| `discount` | 滑價讓均價少了幾成（0.03 = 3%） |
| `warn_big_order` | `discount` ≥ 5% 時為 true：畫面提示「一次賣太多，均價會變差」 |

試算用的是這一刻的市價；市價每遊戲分鐘更新一次，真的賣出時可能不同。

### `POST /v1/sell` 賣出

請求：`{"commodity": "milk", "qty": 20, "request_id": "<uuid>"}`

```json
{"server_time": 1791129600.0, "real_time": 1790736268.0, "time_scale": 144.0,
 "commodity": "milk", "qty": 20.0, "avg_price": 10.438529, "total": 209, "market_price": 10.477821, "discount": 0.00375,
 "price_after": 10.477821, "next_unit_price": 10.399237, "coins": 309,
 "warehouse": {"…": "同 state.warehouse"}, "state": {"…": "同 GET /v1/state"}}
```

| 欄位 | 說明 |
|---|---|
| `qty`、`avg_price`、`total`、`market_price`、`discount` | 同 quote，是實際成交的數字；`total` 已經加進 `coins` |
| `price_after` | 賣完之後的市價。**市價只在每遊戲分鐘的 tick 更新**，所以這裡等於成交當下的市價；這筆賣量會在下一個 tick 反映（全服一起賣就會跌） |
| `next_unit_price` | 你現在再賣一單位（一般品質）拿得到的價格：市價扣掉你最近賣量造成的滑價。剛賣完會比市價低，隔一段時間（約 1 遊戲小時）會回來 |
| `coins` | 賣完後的金幣 |

### `POST /v1/ship` 出貨（牛 → 倉庫裡的牛肉）

請求：`{"cow_id": 1, "request_id": "<uuid>"}`

```json
{"server_time": 1791141660.0, "real_time": 1790736271.84, "time_scale": 144.0,
 "cow_id": 1, "beef": {"qty": 40.236111, "tier": 0, "shipped_at": 1791141660.0, "quality": 1.0, "value_estimate": 468},
 "coins": 414, "warehouse": {"…": "同 state.warehouse"}, "state": {"…": "同 GET /v1/state"}}
```

- 出貨只把牛變成倉庫裡的一批牛肉（`beef`），**還沒賣**；要賣用 `POST /v1/sell` 的 `commodity: "beef"`。
- `value_estimate`：這批牛肉現在全部賣掉的估計收入。按下出貨前，畫面用 `cows[].ship_value` 顯示估值。
- 小牛不能出貨（`409 cow_not_adult`）。
- **牛肉在倉庫的規則（原型規則，試玩後再定；ceo 2026-09-30 核准）**：
  - 放進倉庫後 24 遊戲小時內價值不變，之後 96 小時線性降到 6 成，之後維持 6 成（沿用牛的肉質曲線）。
  - 不佔牛奶倉庫的容量，原型不設上限。
  - 冷凍庫容量和牛肉新鮮度的正式數字，等使用者試玩後由 ceo 統一改企劃書。

### `POST /v1/buy_calf` 買小牛

請求：`{"type": "dairy", "bull": false, "request_id": "<uuid>"}`（`type` 是 `dairy`／`dual`／`beef`；`bull` 必須是 JSON 的 true/false）

回應：`cow`（新小牛，欄位同 `state.cows[]`）、`cost`（花了多少）、`coins`、`pen`、`state`。
錯誤：`pen_full`、`not_enough_coins`。

### `GET /v1/breed/preview?sire=<id>&dam=<id>` 配種前看可能結果

```json
{"server_time": 1791130860.0, "real_time": 1790736268.39, "time_scale": 144.0,
 "sire": 2, "dam": 1, "fee": 0, "normal_fee": 300, "first_free": true,
 "tier_probs": [1.0, 0.0, 0.0, 0.0], "type_probs": {"dairy": 0.5, "dual": 0.5, "beef": 0.0}, "bull_prob": 0.5,
 "can_breed": true, "blockers": []}
```

| 欄位 | 說明 |
|---|---|
| `fee` | 這次要付的費用（第一次免費時是 0） |
| `normal_fee` | 原價：300 × (1 + 父母最高稀有度) |
| `tier_probs` | 小牛稀有度 0–3 的精確機率（依父母基因算出，合計 1） |
| `type_probs` | 小牛用途的機率 |
| `bull_prob` | 小牛是公牛的機率（0.5） |
| `can_breed` | 現在能不能配 |
| `blockers[]` | 不能配的原因，每筆 `{"code", "message", …}`：`cow_not_adult`（`cow_id`、`until`）、`breed_cooldown`（`cow_id`、`until`）、`pen_full`、`not_enough_coins`（`need`、`have`） |

不是「公牛 + 母牛」時回 `400 invalid_pair`；牛不存在回 `404 cow_not_found`。

### `POST /v1/breed` 配種

請求：`{"sire": 2, "dam": 1, "request_id": "<uuid>"}`

```json
{"server_time": 1791130860.0, "real_time": 1790736268.4, "time_scale": 144.0,
 "calf": {"id": 3, "type": "dual", "type_name": "兼用", "bull": false, "tier": 0, "tier_name": "一般", "stage": "calf",
          "born_at": 1791130860.0, "adult_at": 1791134460.0, "ready_at": 1791134460.0, "breed_ready": false, "age_h": 0.0,
          "milk_per_h": 0.0, "milk_frac": 0.0, "weight_kg": 0.0, "beef_quality": 1.0, "ship_value": 0},
 "fee": 0, "sire": {"id": 2, "ready_at": 1791138060.0}, "dam": {"id": 1, "ready_at": 1791217260.0},
 "coins": 169, "state": {"…": "同 GET /v1/state"}}
```

- `calf.adult_at`：小牛長大的時間（倒數用）。長大時間：一般 1、優良 2、稀有 4、傳說 8 遊戲小時。
- `sire.ready_at`／`dam.ready_at`：父母可以再配的時間（公牛冷卻 2 小時、母牛 24 小時）。
- 錯誤：`invalid_pair`、`cow_not_found`、`cow_not_adult`、`breed_cooldown`、`pen_full`、`not_enough_coins`。

### `POST /v1/upgrade` 升級

請求：`{"kind": "pen", "request_id": "<uuid>"}`（`pen` 擴建、`bucket` 奶桶、`warehouse` 倉庫、`fresh` 冷藏）

回應：`kind`、`cost`（花了多少）、`coins`、`upgrades`、`pen`、`state`。
錯誤：`not_enough_coins`、`max_level`、`not_yet_available`（第一次擴建在建立帳號後 15 遊戲分鐘開放，`detail.open_at`）。

### `GET /v1/market` 行情

```json
{"server_time": 1791213660.0, "real_time": 1790736283.89, "time_scale": 144.0, "tick_t": 1791213660.0, "next_tick_at": 1791213720.0,
 "milk": {"price": 9.991896, "change_24h": -0.485925, "change_24h_pct": -0.046377, "ma24": 9.411344,
          "base_price": 10.0, "ratio": 0.99919, "unit": "瓶",
          "history": [[1791129840.0, 10.476567], [1791130140.0, 10.423029], "…"]},
 "beef": {"…": "同 milk"},
 "news": [
  {"id": 3, "title": "學校午餐加訂鮮奶", "commodity": "milk", "targets": ["milk"], "direction": "up", "big": false,
   "time": 1791200814.43, "announce_at": 1791200814.43, "start_at": 1791200814.43, "end_at": 1791256527.72, "state": "active"},
  {"id": 2, "title": "港口罷工，出口受阻", "commodity": null, "targets": ["milk", "beef"], "direction": "down", "big": false,
   "time": 1791162297.74, "announce_at": 1791162297.74, "start_at": 1791162297.74, "end_at": 1791315849.45, "state": "active"}]}
```

每種商品：

| 欄位 | 說明 |
|---|---|
| `price` | 現價（每瓶／每公斤） |
| `change_24h` | 跟 24 遊戲小時前比，**差多少幣**（現價 − 24 小時前；開服不到 24 小時就跟開服價比）。畫面**漲紅跌綠** |
| `change_24h_pct` | 同上，比例（−0.046 = 跌 4.6%） |
| `ma24` | 24 遊戲小時移動平均 |
| `base_price`／`ratio`／`unit` | 基本價（牛奶 10、牛肉 12）、現價 ÷ 基本價、單位 |
| `history` | 最近 24 遊戲小時的走勢 `[[遊戲時間, 價格], …]`，每 5 遊戲分鐘一點（那 5 分鐘最後的價格） |

`tick_t` 是最近一次市場更新的時間，`next_tick_at` 是下一次（每遊戲分鐘一次）。

`news[]`：最近的新聞，新的在前，最多 20 則（已公告的、進行中的、24 遊戲小時內結束的）：

| 欄位 | 說明 |
|---|---|
| `id` | int |
| `title` | 標題（虛構範本） |
| `commodity` | 受影響的商品 `milk`／`beef`；**兩者都受影響時是 `null`**（`targets` 列出全部） |
| `direction` | `up` 利多／`down` 利空 |
| `big` | 大新聞（±30–40%） |
| `time` | 新聞出現的時間（= `announce_at`） |
| `announce_at`／`start_at`／`end_at` | 公告、開始影響價格、影響結束。約 4 成新聞提前 30 遊戲分鐘公告（`state: "upcoming"`），其餘公告即開始 |
| `state` | `upcoming` 即將發生、`active` 進行中、`ended` 已結束 |

### `GET /v1/market/history?commodity=milk&range=1d` 走勢

`range`：`1h`（每 1 遊戲分鐘一點，約 60 點）、`1d`（每 5 分鐘，約 288 點）、`7d`（每 30 分鐘，約 336 點）。預設 `1d`。

```json
{"server_time": 1791213660.0, "real_time": 1790736283.91, "time_scale": 144.0,
 "commodity": "beef", "range": "1h", "step_s": 60.0, "ma24": 11.618328,
 "points": [[1791210060.0, 11.776167], [1791210120.0, 11.772986], "…"]}
```

開服不滿 7 天時，只回有資料的部分。

### `GET /v1/leaderboard?kind=networth` 排行榜

`kind`：`networth` 總資產（金幣 + 倉庫與奶桶的牛奶、牛肉 + 成年牛出貨價值 + 小牛買價，按現價、不含滑價）、`collection` 圖鑑（發現幾格，0–12）、`weekly` 本週收入（這個遊戲週、週一 00:00 台灣時間起的賣出收入）。

```json
{"server_time": 1791213660.0, "real_time": 1790736283.92, "time_scale": 144.0, "kind": "networth", "total": 7,
 "entries": [
  {"rank": 1, "player_id": 3, "name": "電腦 露珠溪谷牧野", "ranch_name": "露珠溪谷牧野", "score": 5448, "is_bot": true, "is_me": false},
  {"rank": 2, "player_id": 4, "name": "電腦 月牙小丘牛舍", "ranch_name": "月牙小丘牛舍", "score": 5252, "is_bot": true, "is_me": false}],
 "me": {"rank": 7, "player_id": 7, "name": "麥浪石橋牧野", "ranch_name": "麥浪石橋牧野", "score": 4189, "is_bot": false, "is_me": true}}
```

- `entries`：前 50 名。同分時先建立的在前。
- `name`：顯示用名字；**電腦假玩家前面加「電腦 」**。`ranch_name` 是原本的牧場名。
- `score`：整數（總資產與本週收入是幣，圖鑑是格數）。
- `me`：自己的名次（不論在不在前 50）。
- 排行榜每 3 現實秒重算一次。

## 4. WebSocket 即時推播：`/v1/ws`

- 連線：`ws://<主機>:8787/v1/ws?token=<token>`。
  - 也可以用子協定帶 token（瀏覽器不能自訂 header 時）：`new WebSocket(url, ["cowfarm.v1", "cowfarm.token." + token])`，伺服器會選 `cowfarm.v1` 回應。
  - 伺服器不記存取日誌，網址上的 token 不會寫進日誌。
- token 無效：伺服器先完成握手，送一則 `{"type": "error", "error": {"code": "unauthorized", …}}`，再用**關閉碼 4401** 關閉。app 收到 4401 就不要重連，改走「建立新帳號」。
- 用戶端送的任何訊息都會被忽略（可以用來保持連線）；伺服器每 20 秒 ping 一次（uvicorn 預設）。

伺服器送的訊息（都是 JSON 文字，看 `type` 分辨；不認得的 `type` 要忽略）：

| type | 什麼時候 | 內容 |
|---|---|---|
| `hello` | 連上時一次 | `server_time`、`real_time`、`time_scale`、`player_id`、`protocol`（1） |
| `market` | 連上時一次，之後**每現實 1 秒** | `server_time`、`real_time`、`time_scale`、`tick_t`，以及 `milk`、`beef` 各 `{price, change_24h, change_24h_pct, ma24}`（和 `GET /v1/market` 每種商品的同名欄位一樣；走勢不在這裡，要用 GET 補） |
| `news` | 新聞第一次出現（公告或直接開始）時 | 和 `news[]` 單筆同形狀，平鋪在訊息裡：`id`、`title`、`commodity`、`targets`、`direction`、`big`、`time`、`announce_at`、`start_at`、`end_at`、`state` |

```json
{"type": "market", "server_time": 1791213660.0, "real_time": 1790736283.92, "time_scale": 144.0, "tick_t": 1791213660.0,
 "milk": {"price": 9.991896, "change_24h": -0.485925, "change_24h_pct": -0.046377, "ma24": 9.411344},
 "beef": {"price": 11.553147, "change_24h": -0.31408, "change_24h_pct": -0.026466, "ma24": 11.618328}}
```

同一則新聞只推一次；「即將發生 → 進行中」的變化由 app 用 `start_at` 自己判斷，或重抓 `GET /v1/market`。

**斷線重連**（backend-findings 實測）：指數退避加隨機等待（full jitter），第 n 次等 `random(0, min(5, 0.5 × 2^n))` 秒，上限 5 秒。連上後先打一次 `GET /v1/market` 和 `GET /v1/state` 補齊斷線期間的變化。斷線期間畫面顯示「連線中…」並停用所有按鈕。

## 5. 其他

- `GET /healthz`：營運用（不需要 token，不屬於協定 v1）：遊戲時間、tick、玩家數、假玩家數、連線數、錯誤數、參數指紋。
- `GET /v1/docs`：FastAPI 自動產生的 API 頁面（只列請求格式，回應格式以本文件為準）。

## 6. 假玩家

- 伺服器裡有 30 位電腦假玩家（`COWFARM_BOTS`），策略 S1 即賣、S2 牛肉派、S3 配種收集、S4 抓時機各約四分之一，照 `docs/research/economy/sim/bots.py` 移植。
- 他們呼叫的是和 API 同一組服務層函式（`backend/server/game.py`），對市場的影響跟真人一樣；排行榜上名字前面有「電腦」。
- 開服後 1 遊戲小時內陸續加入，每天上線 4–8 次（台灣晚上較多）。出貨後立刻賣出。

## 7. 重啟與回復

- 所有帳都在伺服器算，存在 PostgreSQL；伺服器被關掉（包括強制終止）再開，牧場、金幣、倉庫、行情、走勢、新聞都還在。
- 行情引擎的狀態（含亂數）每個 tick 存一次；上一個 tick 之後的成交照序號重建，回復後的市場和當機前完全一樣。
- **遊戲時間在伺服器關著時暫停**，重啟後從上次的時間接著走（試玩時晚上關機，隔天牧場不會老 48 天）。正式上線（倍率 1）應該改成照真實時間走，M3 再定。
  - 正常關機會存下關機那一刻的遊戲時間；被強制終止時，從最後一個 tick 或最後一個動作的時間接著走，所以重啟後的 `server_time` 可能比斷線前最後看到的早一點（最多 1 遊戲分鐘）。app 重連後以新的 `server_time` 為準重新對時即可，牧場狀態不受影響。
- app 在伺服器重啟期間會斷線，照第 4 節重連即可，token 不會失效。

## 8. 跟規格表不一樣的地方

以下對照 `docs/design/m1-prototype.md` 的「協定 v1」表格與附近的文字。1–6 是 ceo 2026-09-30 轉達的 app 需求（已決定）。

| # | 規格表 | 這份文件 | 理由 |
|---|---|---|---|
| 1 | 時間欄位格式沒寫 | 全部是遊戲時間 Unix 秒（數字） | ceo 決定；app 照台灣時間顯示 |
| 2 | `state` 沒有商店欄位 | 加 `shop.calf_price = {dairy, dual, beef}` | ceo 決定；錢不夠時 app 停用按鈕。注意：目前 `app/lib/api/models.dart` 把 `shop.calf_price` 當成單一數字解析，要改 |
| 3 | 牛的「配種冷卻」 | `ready_at`（絕對遊戲時間）＋ `breed_ready`，另有 `adult_at` | ceo 決定；絕對時間不會因為網路延遲而偏移 |
| 4 | 牛的「階段」 | `stage` 取值 `calf`／`adult`／`old` | ceo 的例子寫 `senior`；我用 `old`，因為 `models.dart` 已經解析 `old`。要改成 `senior` 的話只是改字串，告訴我即可 |
| 5 | `pen` 的「開放時間」 | `pen.next_open_at`（`null` = 已開放）；費用 `null` = 滿級，`upgrades` 各項同樣 | ceo 決定 |
| 6 | 奶桶「每小時產量」 | `bucket.per_hour` 已含新手期加倍；另外給 `boost.until` | ceo 決定；app 直接拿它推算 |
| 7 | 表格只有 sell、ship、buy_calf、breed、upgrade 帶 `request_id` | `collect` 也**必須**帶 | 規格文字「會改變狀態的請求都帶 request_id」；收奶會改倉庫 |
| 8 | 各動作只回少數欄位 | 另外都附完整的 `state`（和 `GET /v1/state` 同形狀），以及 `coins` | app 不用每次動作後再抓一次；只加不改 |
| 9 | `sell` 回 `price_after` | `price_after` = 成交當下的市價；另加 `next_unit_price` | 市價每遊戲分鐘 tick 才更新，賣量在下一個 tick 反映；`next_unit_price` 讓玩家看到自己剛賣完的滑價 |
| 10 | `sell/quote` 回 `avg_price`、`total`、`market_price` | 另加 `discount`、`warn_big_order` | 規格要求「單量大時提示」，門檻（5%）由伺服器決定，app 不用自己算 |
| 11 | `ship`「牛變成牛肉放進倉庫」 | 照做；倉庫牛肉的衰減與容量規則見第 3 節 | 經濟引擎原本是出貨即賣出，這是新規則；ceo 核准為原型規則，試玩後再定 |
| 12 | `market` 的「最近 24 遊戲小時的走勢」 | 放在每種商品的 `history`，每 5 遊戲分鐘一點 | 一天 1,440 點太多，5 分鐘足夠畫圖 |
| 13 | `change_24h` | 差多少幣（絕對值），另加 `change_24h_pct` | `models.dart` 已經當成「幣」解析 |
| 14 | `market/history` 的點數沒寫 | 1h 每分鐘、1d 每 5 分鐘、7d 每 30 分鐘 | 每個範圍約 60–340 點 |
| 15 | `news[]` 欄位沒寫 | `id`、`title`、`commodity`（兩者都受影響時 `null`）、`direction`、`time` 加上 `targets`、`big`、`announce_at`、`start_at`、`end_at`、`state` | ceo 轉達的欄位 + 畫「即將發生」需要的時間。不給新聞的精確幅度，只給方向與大新聞旗標 |
| 16 | 排行榜「前 50 名＋自己的名次」 | `entries[]`（`rank`、`name`、`score`、`is_bot`、`is_me`）＋ `me`；假玩家 `name` 前面加「電腦 」 | ceo 決定欄位名 |
| 17 | 排行榜 `weekly` 沒定義 | 這個遊戲週（週一 00:00 台灣時間起）的賣出收入；`collection` = 發現幾格 | 補定義 |
| 18 | WS `{"type":"market", ...}` | 另外有 `hello`（連上時）與 `error`（token 無效、接著 4401 關閉）；`market` 連上時先送一次 | 連上就有資料；4401 讓 app 分得出「token 失效」和「網路斷線」（api-evolution） |
| 19 | WS 只寫 `?token=` | 也接受子協定 `cowfarm.token.<token>` | 瀏覽器不能自訂 header；兩種都行 |
| 20 | 錯誤「HTTP 狀態碼 4xx」 | 具名錯誤碼與狀態碼對照見 1.4；欄位格式錯誤回 400（不是 FastAPI 預設的 422）；可能多一個 `detail` | 所有錯誤同一種形狀 |
| 21 | `session` 回 `token`、`player_id`、`ranch_name` | 另加 `created: true` 與時間欄位 | api-evolution 的慣例 |
| 22 | 等級「由累積收入換算」 | 公式：累積賣出收入 ≥ 500 × (2^(L−1) − 1) | 補定義 |
| 23 | 遊戲時間公式 | 伺服器關著時暫停 | 見第 7 節 |

## 9. 變更紀錄

- 2026-09-30：第一版（M1 原型）。
