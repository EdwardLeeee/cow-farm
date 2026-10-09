"""cowecon 的所有可調參數，集中在這一個檔案。

單位規則
- 時間一律存「秒」，因為伺服器用 Unix 時間；寫法用 HOUR、MINUTE，讀起來就是幾小時、幾分鐘。
- 價格：牛奶是「幣／瓶」，牛肉、稻米是「幣／公斤」。
- 流量（賣出量、需求量）：單位／小時。
- 「對數」：價格乘上 1.1 等於對數加 0.095；小幅度時對數約等於百分比。

改參數的方法：用 `with_overrides()` 產生新的一份，不要直接改 DEFAULT（DEFAULT 是凍結的）。
企劃書的初始數值就是這裡的預設值；M1 伺服器 import 同一份。

v0.2（2026-09-30，企劃書 4.0／決定 D17）：乳牛／耕牛／肉牛、只有成年母乳牛產奶、耕牛耕田產稻米
（第三種行情商品）、商店只挑 A／B／C 等級、出貨評 A／B／C 級、每頭牛一輩子配一次、借種市場。

v0.3（2026-10-03，docs/design/v0.3-care.md／決定 D35）：照顧（CareParams）：小牛長大才揭曉、飼料與雜種牛、地板、
大便與生病、治療、打掃小幫手。
"""

from __future__ import annotations

import hashlib
import json
import math
from dataclasses import asdict, dataclass, field, fields, is_dataclass, replace
from typing import Any, Dict, Tuple

MINUTE = 60.0
HOUR = 3600.0
DAY = 86400.0
TZ_OFFSET_S = 8 * HOUR  # 台灣時間 UTC+8，沒有日光節約時間

ENGINE_VERSION = "0.2.0"


# ---------------------------------------------------------------------------
# 市場（每種商品一份）
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class CommodityParams:
    id: str  # 程式用代號：milk、beef；第二階段的股票也用同一個類別
    name: str  # 畫面名稱
    unit: str  # 計價單位
    base_price: float  # 基本價（幣／單位）；長期平均會回到這裡

    # --- 目標價的時段波動（直接乘在價格上，不經過回歸延遲） ---
    intraday_amp: float  # 日內波動振幅（對數）；0.05 ≈ ±5%
    intraday_peak_hour: float  # 台灣時間幾點最高（0–24）
    weekly_amp: float  # 週波動振幅（對數）
    weekly_peak_day: float  # 一週中哪一天最高：0=週一 … 5=週六（可有小數）

    # --- 隨機雜訊（對數價格偏離目標的 OU 過程） ---
    noise_half_life_s: float  # 雜訊回歸半衰期
    noise_sd: float  # 雜訊的長期標準差（對數）

    # --- 賣壓（全服賣出量超過需求時往下壓） ---
    pressure_half_life_s: float  # 賣壓自己消退的半衰期 = 砸盤後的回復速度
    pressure_absorb_s: float  # 長期存在的賣壓被市場吸收的時間常數（只有比平常多的賣壓才壓價）
    pressure_down_per_h: float  # λ↓：超賣比例每 1.0 持續 1 小時，對數價格被壓低多少
    pressure_up_per_h: float  # λ↑：沒人賣（超賣比例 −1）時每小時往上推多少；刻意比 λ↓ 小
    excess_clip_hi: float  # k：超賣比例上限，(S−D)/D 最多算到 +k
    flow_tau_s: float  # 賣出流量的平滑時間常數（真實時間，與 tick 無關）
    online_tau_s: float  # 線上人數 EMA 的時間常數；與 flow_tau_s 相同，尖峰時段才不會有假賣壓
    ref_tau_s: float  # 長期平均賣出量與平均線上人數的 EMA 時間常數
    ref_warmup_s: float  # 開服初期 EMA 視窗從這個長度開始長到 ref_tau_s
    npc_online_equiv: float  # 電腦買家 = 幾位線上玩家的需求；人少時由它補足
    online_surge_cap: float  # 需求最多跟著線上人數放大到「長期平均線上」的幾倍（擋突然湧入）
    ref_flow_prior: float  # 開服時的長期賣出量預設值（單位／小時）

    # --- 每位玩家的影響上限 ---
    player_cap_frac: float  # c：一位玩家計入賣壓的量，最多是需求的 c 倍（持續）
    player_cap_window_s: float  # W：額度最多存 W 時間的量；一次倒貨最多計入 c×D×W

    # --- 滑價（一次賣很多，均價變差） ---
    slip_kappa: float  # κ：最大折扣比例；最差成交價 = (1 − κ·qmax) × 市價
    slip_qmax: float  # qmax：累積量 / 深度 的上限
    slip_window_s: float  # 市場深度 = 需求 × 這段時間
    slip_typical_mult: float  # 市場深度下限 = 平常單量 × 這個倍數（人少時靠它）
    slip_decay_s: float  # 玩家「最近賣出量」的衰減時間常數；分批賣要隔開才有用
    order_size_prior: float  # 開服時的平常單量預設值（單位）
    order_size_tau_s: float  # 平常單量 EMA 的時間常數
    order_size_update_cap: float  # 單筆最多用平常單量的幾倍去更新 EMA（防止灌大單操縱）

    # --- 邊界（D33 起分三層，ceo 2026-10-03）---
    # 1. 新聞以外的部分（時段 × 雜訊 × 賣壓）：軟邊界 soft_lo–soft_hi 加速拉回，硬邊界 hard_lo–hard_hi 夾住
    #    （大戶倒貨、賣壓的最壞情況跟 D33 以前一樣）。
    # 2. 新聞倍數：所有進行中的事件相乘，夾在 EventParams.total_cap_down–total_cap_up。
    # 3. 總價格（1 × 2）：最後夾在 price_lo–price_hi。下限放寬到 0.05 黑天鵝 −90% 才出得來；
    #    上限 2.2：「買 C 級小牛、長大馬上出貨」照剛成年的實際評級機率要約 2.6 倍才超過 900 幣，不會變成套利。
    soft_lo: float = 0.6  # 軟邊界（基本價倍數）：新聞以外的部分超出後回歸加強
    soft_hi: float = 1.7
    soft_half_life_s: float = 20 * MINUTE  # 超出軟邊界那一段的回歸半衰期
    hard_lo: float = 0.45  # 硬邊界：新聞以外的部分絕對不會超出
    hard_hi: float = 2.2
    price_lo: float = 0.05  # 總價格（新聞以外 × 新聞）絕對不會超出
    price_hi: float = 2.2
    ma_window_s: float = 24 * HOUR  # 走勢圖的移動平均視窗


MILK = CommodityParams(
    id="milk",
    name="牛奶",
    unit="瓶",
    base_price=12.0,
    intraday_amp=0.08,
    intraday_peak_hour=20.0,
    weekly_amp=0.03,
    weekly_peak_day=5.5,
    noise_half_life_s=6 * HOUR,
    noise_sd=0.07,
    pressure_half_life_s=1.5 * HOUR,
    pressure_absorb_s=48 * HOUR,
    pressure_down_per_h=0.12,
    pressure_up_per_h=0.012,
    excess_clip_hi=1.5,
    flow_tau_s=15 * MINUTE,
    online_tau_s=15 * MINUTE,
    ref_tau_s=12 * HOUR,
    ref_warmup_s=1 * HOUR,
    npc_online_equiv=2.0,
    online_surge_cap=3.0,
    ref_flow_prior=100.0,
    player_cap_frac=0.25,
    player_cap_window_s=15 * MINUTE,
    slip_kappa=0.3,
    slip_qmax=1.0,
    slip_window_s=30 * MINUTE,
    slip_typical_mult=20.0,
    slip_decay_s=1 * HOUR,
    order_size_prior=40.0,
    order_size_tau_s=12 * HOUR,
    order_size_update_cap=5.0,
)

BEEF = CommodityParams(
    id="beef",
    name="牛肉",
    unit="公斤",
    base_price=12.0,
    intraday_amp=0.07,
    intraday_peak_hour=18.0,
    weekly_amp=0.05,
    weekly_peak_day=5.0,
    noise_half_life_s=6 * HOUR,
    noise_sd=0.06,
    pressure_half_life_s=1.5 * HOUR,
    pressure_absorb_s=48 * HOUR,
    pressure_down_per_h=0.12,
    pressure_up_per_h=0.012,
    excess_clip_hi=1.5,
    flow_tau_s=15 * MINUTE,
    online_tau_s=15 * MINUTE,
    ref_tau_s=12 * HOUR,
    ref_warmup_s=1 * HOUR,
    npc_online_equiv=2.0,
    online_surge_cap=3.0,
    ref_flow_prior=100.0,
    player_cap_frac=0.25,
    player_cap_window_s=15 * MINUTE,
    slip_kappa=0.3,
    slip_qmax=1.0,
    slip_window_s=30 * MINUTE,
    slip_typical_mult=20.0,
    slip_decay_s=1 * HOUR,
    order_size_prior=300.0,
    order_size_tau_s=12 * HOUR,
    order_size_update_cap=5.0,
)


RICE = CommodityParams(
    id="rice",
    name="稻米",
    unit="公斤",
    base_price=5.0,
    intraday_amp=0.06,
    intraday_peak_hour=11.0,
    weekly_amp=0.04,
    weekly_peak_day=6.0,
    noise_half_life_s=6 * HOUR,
    noise_sd=0.06,
    pressure_half_life_s=1.5 * HOUR,
    pressure_absorb_s=48 * HOUR,
    pressure_down_per_h=0.12,
    pressure_up_per_h=0.012,
    excess_clip_hi=1.5,
    flow_tau_s=15 * MINUTE,
    online_tau_s=15 * MINUTE,
    ref_tau_s=12 * HOUR,
    ref_warmup_s=1 * HOUR,
    npc_online_equiv=2.0,
    online_surge_cap=3.0,
    ref_flow_prior=100.0,
    player_cap_frac=0.25,
    player_cap_window_s=15 * MINUTE,
    slip_kappa=0.3,
    slip_qmax=1.0,
    slip_window_s=30 * MINUTE,
    slip_typical_mult=20.0,
    slip_decay_s=1 * HOUR,
    order_size_prior=150.0,
    order_size_tau_s=12 * HOUR,
    order_size_update_cap=5.0,
)

COMMODITY_IDS: Tuple[str, ...] = ("milk", "beef", "rice")  # 行情商品清單：Exchange、新聞、Farm.impact 都照這份


# ---------------------------------------------------------------------------
# 新聞事件
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class EventParams:
    rate_per_day: float = 4.0  # Poisson 平均每天幾次（v0.2 三種商品，每種每天約 1.8–2 則，和 v0.1 相近）
    # 作用對象與機率：(商品組合, 機率)；「all」= 三種一起
    targets: Tuple[Tuple[Tuple[str, ...], float], ...] = (
        (("milk",), 0.30),
        (("beef",), 0.25),
        (("rice",), 0.25),
        (("milk", "beef", "rice"), 0.20),
    )
    # 新聞分四級（D33，使用者 2026-10-03）：(級別, 機率, 幅度下限, 幅度上限, 利多的機率)。每則新聞先抽級別。
    # 一般 ±5–15%；大事件 ±25–40%；超級大事件 +100%（只往上，收購價變兩倍）；超級黑天鵝 −90%（只往下，剩一成）。
    # 超級、黑天鵝各約 1/(4×3.5)：每天 4 則，各約 3–4 個遊戲天一次。級別代碼就是協定 news[].tier。
    tiers: Tuple[Tuple[str, float, float, float, float], ...] = (
        ("normal", 0.7072, 0.05, 0.15, 0.5),
        ("big", 0.15, 0.25, 0.40, 0.5),
        ("super", 0.0714, 1.0, 1.0, 1.0),
        ("crash", 0.0714, 0.9, 0.9, 0.0),
    )
    announce_prob: float = 0.0  # 提前公告的機率（D33：使用者 2026-10-03「全部新聞都不預告」，原本 0.4）
    announce_lead_s: float = 30 * MINUTE  # 提前多久公告
    ramp_s: float = 15 * MINUTE  # 開始後幾分鐘內漲（跌）到全幅
    half_life_lo_s: float = 2 * HOUR  # 效果衰減半衰期下限
    half_life_hi_s: float = 8 * HOUR
    lifetime_half_lives: float = 6.0  # 幾個半衰期後移除（剩 1.6%）
    total_cap_up: float = 2.5  # 所有進行中事件相乘的上限（倍；D33 從 1.6 放寬，+100% 才出得來）
    total_cap_down: float = 0.08  # 相乘的下限（倍；D33 從 0.62 放寬，−90% 才出得來）


# 新聞標題（虛構）：(商品, 利多/利空) → 標題清單；伺服器可以換成企劃寫的稿
HEADLINES: Dict[str, Tuple[str, ...]] = {
    "milk+": ("學校午餐加訂鮮奶", "連日高溫，冰品店大量進貨", "烘焙展開幕，鮮奶需求大增", "鮮奶檢驗全數合格，買氣回溫"),
    "milk-": ("鄰近牧場產量大增", "超市推出鮮奶特賣", "連日寒流，冰品銷量下滑", "物流塞車，乳品廠暫停收購"),
    "beef+": ("烤肉季開跑", "餐廳推出牛排節", "年節備貨潮提前", "牛肉麵大賽熱鬧登場"),
    "beef-": (
        "健康飲食風潮，肉品需求降溫",
        "進口牛肉到港量創新高",
        "冷凍倉庫滿載，肉商暫緩收購",
        "連假結束，餐廳訂單減少",
    ),
    "rice+": ("颱風過境，稻米收購價上漲", "便當業者搶購新米", "米食文化節開幕", "外銷訂單增加，米價走揚"),
    "rice-": ("中部豐收，新米大量上市", "公糧收購暫停", "連日好天氣，各地提早收割", "米倉滿載，糧商暫緩收購"),
    "all+": ("觀光牧場人潮湧入", "農產品博覽會開幕", "連假出遊潮，餐飲需求旺"),
    "all-": ("颱風過境，市場休市一日", "物價調查公布，消費者縮減開支", "港口罷工，出口受阻"),
    # D33 超級大事件（++，代碼 <商品>_super.N）、超級黑天鵝（--，代碼 <商品>_swan.N）的專屬標題，原文照字串表
    "milk++": ("全國學校改喝鮮奶，訂單暴增", "國際冰淇淋大賽開幕，鮮奶搶光", "鮮奶拿鐵爆紅，咖啡店搶不到奶"),
    "milk--": ("乳品廠大停電，鮮奶全面停收", "冷藏車大罷工，鮮奶運不出去", "超級寒流來襲，冰品店全部休息"),
    "beef++": ("世界牛排大賽在本地舉辦", "全國烤肉節提前開跑，肉商搶貨", "牛肉麵登上國際美食榜"),
    "beef--": ("冷凍物流大當機，肉商全面停收", "便宜進口牛肉湧入，價格崩盤", "全國蔬食週開跑，牛肉沒人買"),
    "rice++": ("新米拿下國際金獎，米價翻倍", "海外飯糰大流行，外銷訂單爆量", "國宴指定在地新米，糧商搶貨"),
    "rice--": ("糧商全面停收，新米堆成山", "百年一見大豐收，新米賣不出去", "麵食大流行，米飯沒人吃"),
    "all++": ("世界美食節在本地登場", "觀光人潮創新高，餐廳天天客滿", "超級連假來了，餐飲需求翻倍"),
    "all--": ("超級颱風來襲，市場全面停擺", "港口全面封閉，農產品出不了貨", "全國消費急凍，農產品沒人買"),
}


# ---------------------------------------------------------------------------
# 牧場
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class FarmParams:
    # 用途基因 M/F：MM 乳牛、MF 耕牛、FF 肉牛（索引 0/1/2）
    type_names: Tuple[str, str, str] = ("乳牛", "耕牛", "肉牛")
    milk_per_h: Tuple[float, float, float] = (14.0, 0.0, 0.0)  # 壯年母牛每小時產奶（瓶）；v0.2 只有母乳牛產奶
    adult_weight_kg: Tuple[float, float, float] = (30.0, 30.0, 30.0)  # 剛成年的體重（低，避免買小牛立刻出貨套利）
    peak_weight_kg: Tuple[float, float, float] = (250.0, 450.0, 800.0)  # 最佳體重：肉牛最多、耕牛中等、乳牛最少
    peak_age_h: Tuple[float, float, float] = (72.0, 72.0, 72.0)  # 成年後幾小時達到最佳體重
    bull_weight_mult: float = 1.1  # 公牛比母牛重多少倍

    # 老牛：產奶（和耕田）先維持壯年，之後線性衰退
    milk_prime_h: float = 48.0  # 成年後幾小時內全速
    milk_decline_end_h: float = 168.0  # 衰退到最低的時間（成年後）
    milk_old_frac: float = 0.4  # 最低剩幾成

    # 肉質（年齡因素）：過了最佳體重一段時間後變差。v0.2 起不再直接乘在價格上，而是影響出貨評級的機率；
    # 倉庫裡的牛肉批次仍用同一條曲線折價（beef_storage_factor）。
    beef_hold_h: float = 24.0  # 到達最佳體重後，肉質還維持滿分的時間
    beef_decline_h: float = 96.0  # 之後花多久降到最低
    beef_quality_min: float = 0.6

    # 出貨評級 A／B／C：分數 s = (1 − w) × 狀態 + w × 稀有度/3；狀態 = 體重/最佳體重 × 肉質
    # P(A) = a0 + a1 × s；P(C) = c0 × (1 − s)；P(B) = 其餘
    beef_grade_names: Tuple[str, str, str] = ("A", "B", "C")
    beef_grade_mult: Tuple[float, float, float] = (1.25, 1.0, 0.75)  # 牛肉賣價倍率
    beef_grade_tier_weight: float = 0.3
    beef_grade_a0: float = 0.10
    beef_grade_a1: float = 0.50
    beef_grade_c0: float = 0.40

    # 稀有度：隱性稀有基因 A/B/C 有幾個是純合
    tier_names: Tuple[str, str, str, str] = ("一般", "優良", "稀有", "傳說")
    # 小牛長大要幾小時（依基因的稀有度）。v0.3（規格第 1 節，ceo 2026-10-03）每頭一樣 3 小時：照稀有度長的話，
    # 看倒數就猜得到稀有度，長大揭曉就沒有驚喜。3 小時是讓最快的地板（×1.5，2 小時）也來得及吃 2 種指定飼料
    # （小牛冷卻 45 分鐘，CareParams）。
    tier_growth_h: Tuple[float, float, float, float] = (3.0, 3.0, 3.0, 3.0)
    # 價值等級的倍數：牛奶、牛肉賣價、耕田產量。索引 0–3 是一般、優良、稀有、傳說；索引 4 是雜種牛（v0.3，HYBRID：
    # 稀有以上的小牛沒吃到指定的飼料，長大變雜種，比一般還低）。基因和原本的稀有度照舊保留，配種用得到。
    tier_mult: Tuple[float, float, float, float, float] = (1.0, 1.3, 1.7, 2.5, 0.6)

    # 耕田：成年耕牛（公母都可以）派去田裡，稻米持續長在田裡，最多存 field_cap_h 小時的量，收成時進倉庫
    rice_per_h: Tuple[float, float, float] = (0.0, 11.0, 0.0)  # 壯年耕牛每小時產稻米（公斤），× 稀有度倍率 × 年齡曲線
    field_start: int = 1  # 開局田地數
    field_max: int = 12
    field_cost_base: float = 1800.0  # 第 n 塊新田（開局那塊不算）= base × growth^(n−1)
    field_cost_growth: float = 1.6
    field_cap_h: float = 8.0  # 一塊田最多累積這頭耕牛壯年幾小時的產量（等於「成熟後就停」）
    # 倉庫裡的稻米：rice_full_h 小時內 100%，之後線性降到 rice_floor_h 小時剩 rice_floor，之後維持
    rice_full_h: float = 72.0
    rice_floor_h: float = 240.0
    rice_floor: float = 0.7

    # 商店：只挑 A／B／C 等級；用途、公母、稀有特徵隨機。等級越高，稀有基因越常見
    shop_grade_names: Tuple[str, str, str] = ("A", "B", "C")
    shop_grade_price: Tuple[float, float, float] = (3200.0, 1700.0, 900.0)
    shop_grade_recessive_freq: Tuple[float, float, float] = (0.5, 0.3, 0.1)  # 每個稀有基因座、每個等位基因是隱性的機率
    shop_type_probs: Tuple[float, float, float] = (0.45, 0.275, 0.275)  # 乳牛／耕牛／肉牛（乳牛多一些：牛奶是核心）
    shop_bull_prob: float = 0.5
    calf_price: float = 900.0  # 舊版（v0.1）「選用途與公母」的小牛價格；v0.2 = C 級價格，只為相容保留

    # 配種：每頭牛一輩子一次（公母一樣）；自己的公母免費。
    # 借種費（D26，2026-10-01 取代 300／800／2,000／5,000 四檔）：公牛現在的體重（公斤）× 每公斤價格（依稀有度），
    # 四捨五入到 stud_fee_round 幣，跟著公牛長大自動漲；主人只決定要不要上架。數字 2026-10-02 重跑經濟模擬後定案
    # （docs/research/2026-09-economy.md 第 10 節）。
    stud_fee_per_kg: Tuple[float, float, float, float, float] = (1.1, 2.75, 6.6, 16.5, 0.6)  # 索引 4 = 雜種牛（v0.3）
    stud_fee_round: float = 10.0
    npc_stud_listings: int = 3  # 公營種牛站最少維持幾筆上架（每種用途一頭，借種費用那種用途公牛的最佳體重算）

    # 牛舍（格數）
    pen_start_slots: int = 2
    pen_max_slots: int = 40
    pen_cost_base: float = 420.0  # 第 n 次擴建 = base × growth^(n−1)
    pen_cost_growth: float = 1.4

    # 奶桶（離線也會累積，滿了就停）
    bucket_start_cap: float = 28.0  # 起始容量（瓶）≈ 起始母牛 2 小時產量
    bucket_cap_growth: float = 1.5  # 每升一級容量乘多少
    bucket_cost_base: float = 200.0  # 升到第 L+1 級 = base × growth^L
    bucket_cost_growth: float = 1.55
    bucket_max_level: int = 16

    # 倉庫（放收好的牛奶）
    wh_start_cap: float = 150.0
    wh_cap_growth: float = 1.5
    wh_cost_base: float = 300.0
    wh_cost_growth: float = 1.6
    wh_max_level: int = 14

    # 新鮮度（倉庫裡的牛奶）：前 fresh_full_h 小時 100%，之後線性降，fresh_half_h 時剩 50%，
    # 同樣斜率降到 0 就壞掉丟棄。冷藏升級每級延長兩個時間點。
    fresh_full_h: float = 6.0
    fresh_half_h: float = 48.0
    fresh_full_step_h: float = 3.0
    fresh_half_step_h: float = 12.0
    fresh_costs: Tuple[float, ...] = (1500.0, 4000.0, 10000.0, 25000.0)  # 升到 1、2、3、4 級


# ---------------------------------------------------------------------------
# 照顧（v0.3，docs/design/v0.3-care.md 第 1、2、4、5 節，D35）
# ---------------------------------------------------------------------------
FEED_IDS: Tuple[str, ...] = ("grass", "hay", "oat", "alfalfa", "corn", "soymeal")  # 飼料索引 0–5


@dataclass(frozen=True)
class CareParams:
    # --- 飼料（第 2 節；ceo 2026-10-03：每次長固定公斤數，不用百分比）---
    feed_names: Tuple[str, ...] = ("牧草", "乾草", "燕麥", "苜蓿", "玉米", "豆粕")
    feed_kg: Tuple[float, ...] = (1.0, 1.5, 2.0, 3.0, 5.0, 8.0)  # 吃一份長幾公斤（越貴長越多）
    feed_price: Tuple[float, ...] = (5.0, 10.0, 15.0, 20.0, 30.0, 45.0)  # 幣／份。PR A 用這個固定價買；飼料市場在 PR B
    bonus_max_kg: float = 60.0  # 每頭牛的飼料加成最多幾公斤，不會減少
    # 加成跟著年紀長出來：體重 = 照年紀的體重 + 加成 ×（成年後的年紀 ÷ 長到最壯的時間，最多 1）。剛成年時加成還沒長出來，
    # 「買 C 級小牛、灌飼料、一長大就出貨」才不會變成套利（固定公斤的話市價 1.36 倍就回本）。
    feed_cooldown_s: float = 4 * HOUR  # 成牛吃飽冷卻（現實的遊戲時間，不受地板影響）
    calf_feed_cooldown_s: float = 45 * MINUTE  # 小牛吃飽冷卻：3 小時內吃得到 2 種指定飼料（最快的地板 2 小時也來得及）
    feed_cap: int = 200  # 每種飼料倉庫最多幾份（D35 補充 4）
    # 稀有、傳說的品種小牛時期要吃到的飼料（規格 2.1 節的表；同一種用途兩個品種共用一組，看飼料猜不到是哪一個）：
    # (用途, 稀有特徵位元, 飼料索引)。一般、優良的品種沒有指定，不會變雜種。
    required_feeds: Tuple[Tuple[int, int, Tuple[int, ...]], ...] = (
        (0, 3, (3,)),  # 奶油棉花牛：苜蓿
        (0, 5, (2, 5)),  # 黑絨乳牛：燕麥、豆粕
        (0, 6, (3,)),  # 巧克力牛：苜蓿
        (0, 7, (2, 5)),  # 草莓牛（傳說）：燕麥、豆粕
        (1, 3, (1, 4)),  # 棉花糖高地牛：乾草、玉米
        (1, 5, (2,)),  # 長毛水牛：燕麥
        (1, 6, (2,)),  # 蜂蜜牛：燕麥
        (1, 7, (1, 4)),  # 金穗牛（傳說）：乾草、玉米
        (2, 3, (3, 1)),  # 白絨牛：苜蓿、乾草
        (2, 5, (3, 1)),  # 絨毛和牛：苜蓿、乾草
        (2, 6, (4, 5)),  # 白和牛：玉米、豆粕
        (2, 7, (4, 5)),  # 星空牛（傳說）：玉米、豆粕
    )

    # --- 地板（第 4 節）：牛的年紀走多快（Farm.set_speed），全部的牛一起。泥土地開局就有 ---
    # ceo 2026-10-08 照使用者原話（D35「長快的讓小牛快長大、快到最壯，長慢的讓壯年維持更久」）分兩段：
    # floor_speed 乘「長到最壯之前」（小牛長大、成牛長到最壯），floor_late_speed 乘「過了最壯以後」（變老、產量下降、
    # 肉質變差）。乳牛的產奶全速期在最壯之前，所以長快地板也會讓它變短：各玩法適合的地板不一樣。
    # 長快地板只用租的（ceo 2026-10-08）：一次買斷的話收入一直多 15–44%，人人必買；按天付租金（跟小幫手一樣預付、到期回
    # 泥土地），牛少的新手不划算、牧場大了才值得。軟墊地一次買斷，另外讓這個牛舍的牛生病速度 ×floor_sick_mult
    # （給不雇小幫手、想留好牛多產幾天的人用；只放慢變老的話免費也沒人要）。
    floor_ids: Tuple[str, ...] = ("dirt", "hay_bed", "meadow", "cushion")
    floor_names: Tuple[str, ...] = ("泥土地", "乾草床", "青草地", "軟墊地")
    floor_speed: Tuple[float, ...] = (1.0, 1.25, 1.5, 1.0)
    floor_late_speed: Tuple[float, ...] = (1.0, 1.0, 1.0, 0.75)
    floor_price: Tuple[float, ...] = (0.0, 0.0, 0.0, 3000.0)  # 一次買斷（0 = 不能買）
    floor_rent_per_day: Tuple[float, ...] = (0.0, 8000.0, 20000.0, 0.0)  # 按天租（0 = 不能租）；租的地板不能改生病速度
    floor_rent_max_days: int = 7  # 最多一次預付幾天
    floor_sick_mult: Tuple[float, ...] = (1.0, 1.0, 1.0, 0.5)

    # --- 大便與生病（第 5 節）：沒上線也照樣累積；時間都是現實的遊戲時間，不受地板影響 ---
    poop_every_s: float = 3 * HOUR  # 每頭牛（小牛也算）每 3 小時一坨
    poop_max_per_cow: int = 4  # 每頭牛最多累積幾坨，之後不再增加
    # 每頭牛每小時生病的機率 = sick_rate_per_h ×（髒的程度 − sick_dirt_free），髒的程度 = 還沒清的大便 ÷ 牛的數量。
    # 使用者 2026-10-08 選「調一半：睡一覺偶爾有病牛」：10 頭牛的牧場睡前清乾淨、不雇小幫手，睡 8 小時後大約 1/4 的機會
    # 至少一頭病牛（規格起點 1.5% 是 2/3）；一整天不管約九成。0.4% 照這個校準（test_care 的 TestSickness 鎖住）。
    sick_rate_per_h: float = 0.004
    sick_dirt_free: float = 0.5
    newbie_safe_s: float = 24 * HOUR  # 開牧場後多久不會生病（ceo 2026-10-03：蓋過第一個晚上）
    cure_price: float = 5000.0  # 治療一頭，馬上好（使用者選「固定很貴」）
    sick_beef_mult: float = 0.1  # 病牛出貨，牛肉價值只剩一成

    # --- 打掃牛（5.1 節；使用者 2026-10-09 把「打掃小幫手」改名，規則一樣。程式裡照舊叫 helper）---
    helper_price_per_day: float = 2000.0  # ceo 2026-10-08 從 800 漲（目標：小幫手、地板、治療等花費佔收入 5–15%）
    helper_max_days: int = 7  # 最多一次預付幾天（遊戲時間）
    helper_clean_s: float = 30 * MINUTE  # 雇用期間每 30 分鐘清掉全部大便（雇用那一刻也清一次）

    # --- 大便掃地機（使用者 2026-10-09 選兩款，cow-back 試算的 R3）：一次買斷，開始動以後每 robot_clean_s 清掉全部大便
    # （比打掃牛慢）。會隨機壞掉：每次開始動（買來、修好）抽一個壞掉的時間，平均 robot_mtbf_d 天；壞了就停，付修理費才再動。
    # 牛多又常上線的人買掃地機划算，常常不在的人（壞了沒人修）雇打掃牛划算。一次只有一台，買另一款就換掉舊的。---
    robot_ids: Tuple[str, ...] = ("basic", "sturdy")
    robot_names: Tuple[str, ...] = ("基本款", "耐用款")  # 乳牛紋圓盤、透明圓頂
    robot_price: Tuple[float, ...] = (3000.0, 12000.0)
    robot_mtbf_d: Tuple[float, ...] = (1.0, 3.0)  # 平均幾天（遊戲時間）壞一次
    robot_repair: Tuple[float, ...] = (750.0, 3000.0)  # 修理費（買價的 1/4）
    robot_clean_s: float = 60 * MINUTE

    # --- 牧場資料（v0.3 第 8 節、D34）：改名第一次免費，之後每次這個價錢（S21 時先放伺服器常數，v0.3 搬進參數）---
    rename_price: float = 1000.0


# ---------------------------------------------------------------------------
# 新手開局
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class OnboardingParams:
    start_coins: float = 100.0
    start_bucket: float = 20.0  # 奶桶裡預先放好的牛奶（瓶）：打開就能收、能賣
    starter_cow_type: int = 0  # 起始成年母牛：乳用
    starter_calf_type: int = 1  # 起始小牛：耕牛公牛（配種後可以下田）
    starter_calf_remaining_s: float = 20 * MINUTE  # 起始小牛還要多久長大 = 配種解鎖時間
    newbie_boost_mult: float = 5.0  # 開局一小時產奶 ×5（新手期）
    newbie_boost_s: float = 1 * HOUR
    first_expand_unlock_s: float = 15 * MINUTE  # 教學在第 15 分鐘開放第一次擴建
    first_expand_cost: float = 280.0  # 第一次擴建的價格；市價跌到 0.55 倍也買得起
    first_breed_free: bool = True  # v0.1 遺留；v0.2 自己的公母配種本來就免費


@dataclass(frozen=True)
class EconomyParams:
    milk: CommodityParams = MILK
    beef: CommodityParams = BEEF
    rice: CommodityParams = RICE
    commodity_ids: Tuple[str, ...] = COMMODITY_IDS
    events: EventParams = field(default_factory=EventParams)
    farm: FarmParams = field(default_factory=FarmParams)
    onboarding: OnboardingParams = field(default_factory=OnboardingParams)
    care: CareParams = field(default_factory=CareParams)

    def commodity(self, cid: str) -> CommodityParams:
        if cid not in self.commodity_ids:
            raise KeyError(f"未知商品：{cid}")
        return getattr(self, cid)

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    def fingerprint(self) -> str:
        """參數內容的雜湊：伺服器啟動時印出來，就能確認跟模擬用的是同一份。"""
        blob = json.dumps(self.to_dict(), sort_keys=True, ensure_ascii=False).encode()
        return hashlib.sha256(blob).hexdigest()[:16]


DEFAULT = EconomyParams()


def with_overrides(p: EconomyParams, overrides: Dict[str, Any]) -> EconomyParams:
    """用 {"milk.pressure_down_per_h": 0.1, "farm.calf_price": 900} 這種寫法產生新的一份參數。

    "market.xxx" 會同時改所有行情商品（牛奶、牛肉、稻米）。
    """
    groups: Dict[str, Dict[str, Any]] = {}
    for key, value in overrides.items():
        grp, _, name = key.partition(".")
        targets = list(p.commodity_ids) if grp == "market" else [grp]
        for g in targets:
            sub = getattr(p, g)
            if not is_dataclass(sub) or name not in {f.name for f in fields(sub)}:
                raise KeyError(f"未知參數：{key}")
            groups.setdefault(g, {})[name] = value
    kwargs = {g: replace(getattr(p, g), **vals) for g, vals in groups.items()}
    return replace(p, **kwargs)


def half_life_to_rate(half_life_s: float) -> float:
    """半衰期（秒）→ 每秒的衰減率。"""
    return math.log(2.0) / half_life_s
