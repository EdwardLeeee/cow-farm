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

    # --- 邊界 ---
    soft_lo: float = 0.6  # 軟邊界（基本價倍數）：超出後回歸加強
    soft_hi: float = 1.7
    soft_half_life_s: float = 20 * MINUTE  # 超出軟邊界那一段的回歸半衰期
    hard_lo: float = 0.45  # 硬邊界：價格絕對不會超出
    hard_hi: float = 2.2
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
    mag_lo: float = 0.05  # 一般事件幅度下限（±5%）
    mag_hi: float = 0.25  # 一般事件幅度上限（±25%）
    rare_prob: float = 0.05  # 罕見大事件的機率
    rare_lo: float = 0.30
    rare_hi: float = 0.40  # 罕見大事件最大 ±40%
    up_prob: float = 0.5  # 利多的機率
    announce_prob: float = 0.4  # 提前公告的機率
    announce_lead_s: float = 30 * MINUTE  # 提前多久公告
    ramp_s: float = 15 * MINUTE  # 開始後幾分鐘內漲（跌）到全幅
    half_life_lo_s: float = 2 * HOUR  # 效果衰減半衰期下限
    half_life_hi_s: float = 8 * HOUR
    lifetime_half_lives: float = 6.0  # 幾個半衰期後移除（剩 1.6%）
    total_cap_up: float = 1.6  # 所有進行中事件相乘的上限（倍）
    total_cap_down: float = 0.62  # 相乘的下限（倍）


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
    tier_growth_h: Tuple[float, float, float, float] = (1.0, 2.0, 4.0, 8.0)  # 小牛長大要幾小時
    tier_mult: Tuple[float, float, float, float] = (1.0, 1.3, 1.7, 2.5)  # 牛奶、牛肉賣價倍率；耕田產量倍率

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
    stud_fee_per_kg: Tuple[float, float, float, float] = (1.1, 2.75, 6.6, 16.5)
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
