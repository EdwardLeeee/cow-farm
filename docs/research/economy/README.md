# cow-farm 經濟模擬

研究筆記：[`../2026-09-economy.md`](../2026-09-economy.md)。這裡是程式與原始數據。

| 路徑 | 內容 |
|---|---|
| [`../../../backend/cowecon/`](../../../backend/cowecon/) | 經濟引擎（純 Python 3.10 標準函式庫，給定 seed 結果固定）。2026-09-30 從這裡用 `git mv` 搬到 `backend/`，只保留那一份：伺服器和這裡的模擬 import 同一份。`sim/__init__.py` 會把 `backend/` 加進 `sys.path`。 |
| `backend/cowecon/params.py` | **所有可調參數**，附單位與中文註解；企劃書的初始數值以這份為準。 |
| `backend/cowecon/market.py` | 行情：每個 tick 的價格更新、滑價成交、新聞事件、需求（線上人數 + 電腦買家）、每位玩家影響上限。 |
| `backend/cowecon/farm.py` | 牧場：牛的一生、產奶與奶桶、新鮮度、牛肉價值、配種機率、各項成本、新手開局。 |
| `sim/` | 玩家 bot、情境、執行、統計、畫圖（可用 numpy／matplotlib；目前只用 matplotlib）。 |
| `tests/` | `python3 -m unittest` 測試 30 個：結果固定、價格邊界、滑價隨單量單調、新鮮度單調、tick 大小不影響結果、每位玩家上限等。 |
| `out/` | 圖（PNG）、`goals.json`（四個目標的實際數字）、`runs/`（每個情境的 JSON 摘要與 CSV）。 |

## 怎麼跑

以下指令都在這個資料夾執行（`sim` 與 `tests` 會自動從 `backend/cowecon/` import 引擎，不用另外設定）：

```bash
cd docs/research/economy

# 1. 測試（30 個，約 10 秒）
python3 -m unittest

# 2. 全部情境（36 個）。10,000 人 30 天那個單獨約 308 秒、單一行程約 200 MB。
#    這台電腦 2026-09-30 因記憶體用光當機過：先看 free -m，available 少於 2000 MB 就等一下；
#    用 systemd-run 限制記憶體，一次只跑一個（全部約 10 分鐘，估計）：
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
# 玩家出貨：
farm.ship(cow, ex.markets["beef"], now)
```

- 伺服器要存的狀態：每個 `Market` 的 `snapshot()`、每位玩家 `Farm` 的欄位，以及每位玩家每種商品的 `ImpactState`（4 個數字）。
- 啟動時印出 `DEFAULT.fingerprint()`，和 `out/goals.json` 的 `params_fingerprint` 相同，就代表用的是模擬驗證過的那一份參數。
- 情境清單在 `sim/scenarios.py`（純資料）；M1 驗收要把這些情境變成伺服器自動測試，照同樣的 seed 應該得到同樣的數字。
