# cow-farm 經濟模擬

研究筆記：[`../2026-09-economy.md`](../2026-09-economy.md)（v0.2 在第 9 節；D26 借種費依體重在第 10 節，`out/` 現在是這一輪的結果）。這裡是程式與原始數據。v0.2 引擎給伺服器的變更清單：[`v0.2-engine-changes.md`](v0.2-engine-changes.md)。

| 路徑 | 內容 |
|---|---|
| [`../../../backend/cowecon/`](../../../backend/cowecon/) | 經濟引擎（純 Python 3.10 標準函式庫，給定 seed 結果固定）。2026-09-30 從這裡用 `git mv` 搬到 `backend/`，只保留那一份：伺服器和這裡的模擬 import 同一份。`sim/__init__.py` 會把 `backend/` 加進 `sys.path`。 |
| `backend/cowecon/params.py` | **所有可調參數**，附單位與中文註解；企劃書的初始數值以這份為準。 |
| `backend/cowecon/market.py` | 行情：每個 tick 的價格更新、滑價成交、新聞事件、需求（線上人數 + 電腦買家）、每位玩家影響上限。 |
| `backend/cowecon/market.py` 的三個市場 | v0.2：牛奶、牛肉、稻米。 |
| `backend/cowecon/farm.py` | 牧場：牛的一生、產奶（只有母乳牛）與奶桶、耕田與稻米、新鮮度、出貨評級、商店等級、配種一次、借種市場 `StudMarket`、各項成本、新手開局。 |
| `sim/` | 玩家 bot（六種玩法＋大戶）、情境、執行、統計、畫圖（可用 numpy／matplotlib；目前只用 matplotlib）。 |
| `tests/` | `python3 -m unittest` 測試 47 個：結果固定、價格邊界、滑價隨單量單調、新鮮度單調、tick 大小不影響結果、每位玩家上限；v0.2 規則（`test_v02.py`：只有母乳牛產奶、商店與出貨評級的精確機率、配種一次、耕田、借種、存檔）。 |
| `out/` | v0.2 的圖（PNG）、`goals.json`（各目標的實際數字）、`tables.md`、`runs/`（每個情境的 JSON 摘要與 CSV）。 |
| `out/v0.1/` | v0.1 的圖與摘要 JSON（保留對照；逐分鐘的 CSV 沒留，可用 git 版本 `3aeeacb` 重建）。 |

## 怎麼跑

以下指令都在這個資料夾執行（`sim` 與 `tests` 會自動從 `backend/cowecon/` import 引擎，不用另外設定）：

```bash
cd docs/research/economy

# 1. 測試（47 個，約 14 秒）
python3 -m unittest

# 2. 全部情境（36 個）。v0.2.1 實測：一次一個、nice 19，20:13–20:32 共約 19 分鐘；
#    10,000 人 30 天那個 493 秒、單一行程最多約 260 MB。
#    這台電腦 2026-09-30 因記憶體用光當機過：先看 free -m，available 少於 1000 MB 就等一下（使用者 2026-10-03 從 2000 改成 1000）；
#    用 systemd-run 限制記憶體，一次只跑一個：
free -m
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 nice -n 19 python3 -m sim.run --force --jobs 1

#    只跑一部分：名稱包含指定文字（逗號分隔）
python3 -m sim.run --only base_100,whale_10_ --force

# 3. 算目標數字（寫 out/goals.json，並印出摘要；約 5 秒），再產生筆記用的表格（out/tables.md）
python3 -m sim.report
python3 -m sim.tables

#    輔助量測：伺服器角度的耗時（out/bench.json）、一般玩家的滑價（out/slippage_normal.json，約 20 秒）、
#    各策略每單位實收（out/unitprice.json，約 30 秒）
python3 -m sim.bench
python3 -m sim.slipcheck
python3 -m sim.unitprice

# 4. 畫圖（寫 out/*.png；約 10 秒）
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 python3 -m sim.plots
```

- 不需要安裝任何套件：引擎只用標準函式庫；畫圖用系統上的 matplotlib 3.8（Ubuntu 套件），中文字型用 Noto Sans CJK TC。
- 量測環境：Surface（Linux 6.19，8 核心），Python 3.10.12。實際耗時看 `out/goals.json` 的 `wall` 欄位。

## 伺服器怎麼用（M1）

M1 伺服器已經做好，在 [`../../../backend/`](../../../backend/)（說明見那裡的 README）。下面是引擎本身的用法：

```python
from cowecon import DEFAULT, Exchange, Farm
ex = Exchange(DEFAULT, seed=伺服器啟動時的亂數種子, t0=time.time())
# 每 1 分鐘：
ex.step(now, online_count)            # online_count = 這一分鐘同時在線的玩家數
# 玩家賣奶：
farm.sell_all_milk(ex.markets["milk"], now)
# 玩家出貨（v0.2 一定要傳 rng，才會抽出貨評級）：
farm.ship(cow, ex.markets["beef"], now, rng)
# 稻米：收成、賣
farm.harvest(now); farm.sell_rice(ex.markets["rice"], farm.rice_stock(), now)
```

- 伺服器要存的狀態：`Exchange.to_dict()`、每位玩家的 `Farm.to_dict()`（含田地、稻米、配種次數、每種商品的 `ImpactState`），以及全服一份 `StudMarket.to_dict()`。
- 啟動時印出 `DEFAULT.fingerprint()`，和 `out/goals.json` 的 `params_fingerprint` 相同，就代表用的是模擬驗證過的那一份參數。
- 情境清單在 `sim/scenarios.py`（純資料）；M1 驗收要把這些情境變成伺服器自動測試，照同樣的 seed 應該得到同樣的數字。
