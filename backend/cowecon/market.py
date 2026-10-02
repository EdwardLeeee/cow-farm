"""行情引擎：每種商品一個 Market；Exchange 管多個 Market 和共用的新聞事件。

價格怎麼算（每個 tick，伺服器每 1 分鐘呼叫一次 Exchange.step）

    log(價格 / 基本價) = 時段波動(t) + 新聞事件(t) + 雜訊 x + 賣壓 y

- 時段波動：日內與週波動，直接乘上去，所以設計的起伏會準時、足額出現。
- 新聞事件：每則事件 15 分鐘內漲（跌）到全幅，之後照半衰期消退。
- 雜訊 x：OU 過程，半衰期 6 小時，會回到 0（也就是回到目標價）。
- 賣壓 y：全服賣出量超過需求時往下壓，自己以 1.5 小時半衰期消退；長期存在的那一部分（48 小時平均）
  會被市場吸收，所以長期平均價格回到基本價。
- 價格超出基本價 [0.6, 1.7] 倍時，超出那段以 20 分鐘半衰期拉回；另有硬邊界保證不會超出 [0.45, 2.2]。

所有參數都是真實時間，換 tick 大小（1 分鐘、5 分鐘）統計結果不變；見 tests/test_market.py。
本模組只用標準函式庫；亂數一律由呼叫端傳入 random.Random，給定 seed 結果固定。

存檔與回復（M1 伺服器用）：Market、Exchange、ImpactState 都有 to_dict()／from_dict()，
內容是純 JSON（亂數狀態也在裡面）。回復後繼續跑，和沒中斷過的同一個 seed 每個數字都一樣
（backend/tests/test_persist.py）。
"""

from __future__ import annotations

import math
import random
from collections import deque
from typing import Dict, Iterable, List, NamedTuple, Optional, Sequence, Tuple

from .params import (
    DAY,
    HEADLINES,
    HOUR,
    TZ_OFFSET_S,
    CommodityParams,
    EconomyParams,
    EventParams,
)

LN2 = math.log(2.0)


def rng_to_state(rng: random.Random) -> list:
    """random.Random 的完整狀態 → JSON 可存的 list（含 gauss 的暫存值，Market.step 用 gauss）。"""
    version, internal, gauss_next = rng.getstate()
    return [version, list(internal), gauss_next]


def rng_from_state(state: Sequence) -> random.Random:
    rng = random.Random()
    version, internal, gauss_next = state
    rng.setstate((version, tuple(internal), gauss_next))
    return rng


# ---------------------------------------------------------------------------
# 時段波動
# ---------------------------------------------------------------------------
def local_hour(t: float) -> float:
    """Unix 時間 → 台灣時間的小時（0–24，含小數）。"""
    return ((t + TZ_OFFSET_S) % DAY) / HOUR


def local_weekday(t: float) -> float:
    """Unix 時間 → 台灣時間的星期（0=週一，含小數）。1970-01-01 是週四。"""
    days = (t + TZ_OFFSET_S) / DAY
    return (days + 3.0) % 7.0


def seasonal_log(cp: CommodityParams, t: float) -> float:
    """日內波動 × 週波動（對數）。"""
    h = local_hour(t)
    d = local_weekday(t)
    intraday = cp.intraday_amp * math.cos(2 * math.pi * (h - cp.intraday_peak_hour) / 24.0)
    weekly = cp.weekly_amp * math.cos(2 * math.pi * (d - cp.weekly_peak_day) / 7.0)
    return intraday + weekly


# ---------------------------------------------------------------------------
# 每位玩家、每種商品的影響狀態（伺服器存進資料庫，4 個數字）
# ---------------------------------------------------------------------------
class ImpactState:
    """recent：最近賣出量（隨時間衰減，用來算滑價）；allow：還能計入賣壓的額度。"""

    __slots__ = ("recent", "allow", "t")

    def __init__(self) -> None:
        self.recent = 0.0
        self.allow: Optional[float] = None  # None = 第一次賣，額度給滿
        self.t: Optional[float] = None

    def to_dict(self) -> dict:
        return {"recent": self.recent, "allow": self.allow, "t": self.t}

    @classmethod
    def from_dict(cls, d: dict) -> "ImpactState":
        s = cls()
        s.recent, s.allow, s.t = d["recent"], d["allow"], d["t"]
        return s


class SaleResult(NamedTuple):
    proceeds: float  # 總收入（幣，未取整）
    units: float  # 賣出量
    counted: float  # 計入全服賣壓的量（受每位玩家上限限制）
    avg_discount: float  # 平均滑價折扣（0.03 = 3%）
    price: float  # 成交當下的市價（每單位，未含倍率）


def _ramp_integral(a: float, b: float, depth: float, qmax: float) -> float:
    """∫_a^b min(u/depth, qmax) du：累積量從 a 到 b 的折扣積分（未乘 κ）。"""
    ucap = qmax * depth
    if b <= ucap:
        return (b * b - a * a) / (2.0 * depth)
    if a >= ucap:
        return qmax * (b - a)
    return (ucap * ucap - a * a) / (2.0 * depth) + qmax * (b - ucap)


# ---------------------------------------------------------------------------
# 單一商品的市場
# ---------------------------------------------------------------------------
class Market:
    def __init__(self, cp: CommodityParams, t0: float, rng: random.Random) -> None:
        self.cp = cp
        self.rng = rng
        self.t_start = t0
        self.t = t0
        self.x = 0.0  # 雜訊（對數），開服時在目標價
        self.y = 0.0  # 賣壓（對數），原始值
        self.y_base = 0.0  # 賣壓的長期平均（pressure_absorb_s 的 EMA）；價格只用 y − y_base
        self.flow = 0.0  # 計入賣壓的賣出流量，平滑後（單位／小時）
        self.online = 0.0  # 線上人數 EMA（短）
        self.ref_flow = cp.ref_flow_prior  # 長期平均賣出流量（單位／小時），含未計入賣壓的量
        self.ref_online = 0.0  # 長期平均線上人數
        # 平常單量（以量加權）= Σq·min(q, 上限) 的 EMA / Σq 的 EMA：很多小單不會把它拉低
        self._ord_wq = cp.order_size_prior * cp.order_size_prior
        self._ord_w = cp.order_size_prior
        self.pending_counted = 0.0
        self.pending_actual = 0.0
        self.pending_ord_w = 0.0
        self.pending_ord_wq = 0.0
        self.event_log = 0.0
        self.season_log = seasonal_log(cp, t0)
        self.excess = 0.0  # 上一個 tick 的超賣比例 e
        self.price = cp.base_price * math.exp(self.season_log)
        self._hist: deque = deque()
        self._hist_sum = 0.0
        self.last_contribution: Optional[Tuple[float, float, float, float]] = None  # 上一筆成交對 pending 的貢獻
        self._push_hist(t0, self.price)

    # ---- 讀取 ----
    def demand_rate(self) -> float:
        """需求 D（單位／小時）= 長期平均賣出量 × (線上 + 電腦買家) / (平均線上 + 電腦買家)。

        線上人數最多只算到「長期平均線上 × online_surge_cap」：平常的晚上尖峰照算，
        但突然大家同時湧進來賣（例如大利多之後），需求不會跟著無限放大，價格才會跌。
        """
        cp = self.cp
        npc = cp.npc_online_equiv
        ref = max(self.ref_flow, 0.1 * cp.ref_flow_prior)
        online = min(self.online, cp.online_surge_cap * max(self.ref_online, 1.0))
        return ref * (online + npc) / (self.ref_online + npc)

    def typical_order(self) -> float:
        return self._ord_wq / self._ord_w

    def depth(self) -> float:
        """市場深度：累積賣出量到這麼多時，滑價達到上限的一半…上限。"""
        cp = self.cp
        return max(self.demand_rate() * cp.slip_window_s / HOUR, cp.slip_typical_mult * self.typical_order())

    def ratio(self) -> float:
        return self.price / self.cp.base_price

    @property
    def pressure(self) -> float:
        """實際作用在價格上的賣壓（對數）= 原始賣壓 − 長期平均。"""
        return self.y - self.y_base

    @property
    def ratio_ex_news(self) -> float:
        """新聞以外的部分（時段 × 雜訊 × 賣壓，基本價倍數），已經過軟邊界和硬邊界；價格 = 基本價 × 這個 × 新聞倍數
        （再夾總價格的上下限）。分析、測試用；從存檔的狀態就算得出來，不另外存。"""
        return min(max(math.exp(self.season_log + self.x + self.pressure), self.cp.hard_lo), self.cp.hard_hi)

    def moving_average(self) -> float:
        return self._hist_sum / len(self._hist)

    # ---- 成交 ----
    def _refreshed_impact(self, imp: ImpactState, now: float, dem: float) -> Tuple[float, float]:
        cp = self.cp
        cap = cp.player_cap_frac * dem * cp.player_cap_window_s / HOUR
        if imp.t is None or imp.allow is None:
            return 0.0, cap
        dt = max(0.0, now - imp.t)
        recent = imp.recent * math.exp(-dt / cp.slip_decay_s)
        allow = min(cap, imp.allow + cp.player_cap_frac * dem * dt / HOUR)
        return recent, allow

    def _price_parts(self, recent: float, parts: Iterable[Tuple[float, float]], depth: float) -> Tuple[float, float]:
        """回傳 (總收入, 總量)。parts = [(數量, 價格倍率), ...]，倍率含稀有度與新鮮度。"""
        cp = self.cp
        proceeds = 0.0
        total = 0.0
        p = self.price
        for q, mult in parts:
            if q <= 0:
                continue
            a = recent + total
            disc = cp.slip_kappa * _ramp_integral(a, a + q, depth, cp.slip_qmax) / q
            proceeds += q * p * mult * (1.0 - disc)
            total += q
        return proceeds, total

    def quote(self, imp: ImpactState, parts: Sequence[Tuple[float, float]], now: float) -> SaleResult:
        """試算，不改任何狀態（給畫面預覽）。"""
        dem = self.demand_rate()
        recent, allow = self._refreshed_impact(imp, now, dem)
        proceeds, total = self._price_parts(recent, parts, self.depth())
        gross = sum(q * self.price * m for q, m in parts if q > 0)
        disc = 1.0 - proceeds / gross if gross > 0 else 0.0
        return SaleResult(proceeds, total, min(total, allow), disc, self.price)

    def execute_sale(self, imp: ImpactState, parts: Sequence[Tuple[float, float]], now: float) -> SaleResult:
        """成交：回傳收入，並把這筆記進下一個 tick 的賣壓。"""
        cp = self.cp
        dem = self.demand_rate()
        recent, allow = self._refreshed_impact(imp, now, dem)
        proceeds, total = self._price_parts(recent, parts, self.depth())
        gross = sum(q * self.price * m for q, m in parts if q > 0)
        disc = 1.0 - proceeds / gross if gross > 0 else 0.0
        counted = min(total, allow)
        imp.recent = recent + total
        imp.allow = allow - counted
        imp.t = now
        self.last_contribution = None
        if total > 0:
            # 長期平均賣出量：每筆最多算平常單量的 order_size_update_cap 倍，大戶倒貨不會把「平常需求」墊高
            capped = min(total, cp.order_size_update_cap * self.typical_order())
            self.last_contribution = (counted, capped, total, total * capped)
            self.apply_contribution(self.last_contribution)
        return SaleResult(proceeds, total, counted, disc, self.price)

    def apply_contribution(self, c: Sequence[float]) -> None:
        """把一筆成交對下一個 tick 的貢獻加進 pending。

        c = (計入賣壓的量, 計入長期平均的量, 賣出量, 賣出量 × 計入長期平均的量)，就是 execute_sale 後的
        last_contribution。伺服器把它存進成交紀錄；當機重啟時，照原本的順序把上一個 tick 之後的成交
        再加一次，pending 就和當機前完全一樣。
        """
        self.pending_counted += c[0]
        self.pending_actual += c[1]
        self.pending_ord_w += c[2]
        self.pending_ord_wq += c[3]

    # ---- 每個 tick ----
    def step(self, now: float, online_count: float, event_log: float) -> None:
        cp = self.cp
        dt = now - self.t
        if dt <= 0:
            return
        h = dt / HOUR

        # 線上人數 EMA（短）
        a_on = 1.0 - math.exp(-dt / cp.online_tau_s)
        self.online += a_on * (online_count - self.online)

        # 長期平均：開服初期視窗從 ref_warmup_s 慢慢長到 ref_tau_s
        tau_ref = min(cp.ref_tau_s, cp.ref_warmup_s + (self.t - self.t_start))
        a_ref = 1.0 - math.exp(-dt / tau_ref)
        self.ref_flow += a_ref * (self.pending_actual / h - self.ref_flow)
        self.ref_online += a_ref * (online_count - self.ref_online)
        tau_ord = min(cp.order_size_tau_s, cp.ref_warmup_s + (self.t - self.t_start))
        d_ord = math.exp(-dt / tau_ord)
        self._ord_wq = self._ord_wq * d_ord + self.pending_ord_wq
        self._ord_w = self._ord_w * d_ord + self.pending_ord_w
        if self._ord_w < 1e-9:
            self._ord_wq, self._ord_w = cp.order_size_prior * cp.order_size_prior, cp.order_size_prior

        # 計入賣壓的流量：這段時間的賣出量視為在區間開頭進場，指數平滑
        tau_f_h = cp.flow_tau_s / HOUR
        start_flow = self.flow + self.pending_counted / tau_f_h
        decay_f = math.exp(-dt / cp.flow_tau_s)
        avg_flow = start_flow * (cp.flow_tau_s / dt) * (1.0 - decay_f)  # 區間平均
        self.flow = start_flow * decay_f

        dem = self.demand_rate()
        e = avg_flow / dem - 1.0
        if e > cp.excess_clip_hi:
            e = cp.excess_clip_hi
        elif e < -1.0:
            e = -1.0
        self.excess = e

        # 賣壓 y：dy/dt = −k_y·y − λ·e（e 在區間內視為常數，精確解）
        k_y = LN2 / (cp.pressure_half_life_s / HOUR)
        lam = cp.pressure_down_per_h if e > 0 else cp.pressure_up_per_h
        dec_y = math.exp(-k_y * h)
        self.y = self.y * dec_y - (lam * e / k_y) * (1.0 - dec_y)
        # 長期存在的賣壓會被市場吸收（例如每天早上大家都賣前一晚的奶）：只有「比平常多的」賣壓會壓價，
        # 所以長期平均價格回到基本價；幾小時內的砸盤、恐慌賣幾乎不受影響。
        tau_abs = min(cp.pressure_absorb_s, cp.ref_warmup_s + (self.t - self.t_start))
        self.y_base += (1.0 - math.exp(-dt / tau_abs)) * (self.y - self.y_base)

        # 雜訊 x：OU 精確離散化，長期標準差 = noise_sd
        dec_x = math.exp(-LN2 * dt / cp.noise_half_life_s)
        self.x = self.x * dec_x + cp.noise_sd * math.sqrt(1.0 - dec_x * dec_x) * self.rng.gauss(0.0, 1.0)

        # 目標價，D33 起分三層（CommodityParams 的邊界說明）：
        # 1. 新聞以外的部分（時段 + 雜訊 + 賣壓）：軟邊界、硬邊界只管這部分。以前軟邊界連新聞一起算，新聞把價格推出邊界時，
        #    雜訊 x 會被拉成很大的反向值：+100% 出不來，黑天鵝退掉以後價格反而衝到 1.2 倍。
        # 2. 新聞倍數：Exchange.event_log_for 已經夾在 total_cap_down–total_cap_up。
        # 3. 總價格 = 1 × 2，最後夾在 price_lo–price_hi。
        self.season_log = seasonal_log(cp, now)
        self.event_log = event_log
        r = self.season_log + self.x + self.pressure

        # 軟邊界：超出的那一段加速拉回，按 x、y 各自往外推的份量分攤
        lo, hi = math.log(cp.soft_lo), math.log(cp.soft_hi)
        if r > hi or r < lo:
            edge = hi if r > hi else lo
            over = r - edge
            corr = over * (1.0 - math.exp(-LN2 * dt / cp.soft_half_life_s))
            s = 1.0 if over > 0 else -1.0
            wx = max(0.0, s * self.x)
            wy = max(0.0, s * self.pressure)
            if wx + wy <= 0.0:
                self.x -= corr
            else:
                self.x -= corr * wx / (wx + wy)
                self.y -= corr * wy / (wx + wy)

        ratio = self.ratio_ex_news * math.exp(event_log)
        if ratio < cp.price_lo:
            ratio = cp.price_lo
        elif ratio > cp.price_hi:
            ratio = cp.price_hi
        self.price = cp.base_price * ratio

        self.pending_counted = 0.0
        self.pending_actual = 0.0
        self.pending_ord_w = 0.0
        self.pending_ord_wq = 0.0
        self.t = now
        self._push_hist(now, self.price)

    def _push_hist(self, t: float, p: float) -> None:
        self._hist.append((t, p))
        self._hist_sum += p
        limit = t - self.cp.ma_window_s
        while self._hist and self._hist[0][0] < limit:
            self._hist_sum -= self._hist.popleft()[1]

    # ---- 存檔與回復 ----
    _STATE_FIELDS = (
        "t_start",
        "t",
        "x",
        "y",
        "y_base",
        "flow",
        "online",
        "ref_flow",
        "ref_online",
        "_ord_wq",
        "_ord_w",
        "pending_counted",
        "pending_actual",
        "pending_ord_w",
        "pending_ord_wq",
        "event_log",
        "season_log",
        "excess",
        "price",
        "_hist_sum",
    )

    def to_dict(self, include_hist: bool = True) -> dict:
        """完整狀態（純 JSON）。include_hist=False 時不含走勢圖的 24 小時歷史（伺服器另存在價格表）。"""
        d = {"id": self.cp.id}
        for k in self._STATE_FIELDS:
            d[k.lstrip("_")] = getattr(self, k)
        d["rng"] = rng_to_state(self.rng)
        if include_hist:
            d["hist"] = [[t, p] for t, p in self._hist]
        return d

    @classmethod
    def from_dict(cls, cp: CommodityParams, d: dict, hist: Optional[Iterable[Tuple[float, float]]] = None) -> "Market":
        """從 to_dict() 回復。hist 沒給就用 d["hist"]；兩者都沒有時，歷史只剩目前價格一筆。"""
        if d.get("id", cp.id) != cp.id:
            raise ValueError(f"商品不符：存檔是 {d.get('id')}，參數是 {cp.id}")
        m = cls.__new__(cls)
        m.cp = cp
        for k in cls._STATE_FIELDS:
            setattr(m, k, d[k.lstrip("_")])
        m.rng = rng_from_state(d["rng"])
        m.last_contribution = None
        if hist is None:
            hist = d.get("hist")
        m._hist = deque((float(t), float(p)) for t, p in hist) if hist is not None else deque()
        if not m._hist:
            m._hist.append((m.t, m.price))
            m._hist_sum = m.price
        return m

    def snapshot(self) -> dict:
        """給畫面／除錯用的摘要（不能用來回復；回復用 to_dict）。"""
        return {
            "t": self.t,
            "price": self.price,
            "x": self.x,
            "y": self.y,
            "y_base": self.y_base,
            "flow": self.flow,
            "online": self.online,
            "ref_flow": self.ref_flow,
            "ref_online": self.ref_online,
            "typical_order": self.typical_order(),
            "excess": self.excess,
            "event_log": self.event_log,
            "season_log": self.season_log,
        }


# ---------------------------------------------------------------------------
# 新聞事件
# ---------------------------------------------------------------------------
def tier_for_factor(ep: EventParams, factor: float) -> str:
    """幅度和方向對到 ep.tiers 的哪一級（測試、情境注入的事件用）：從幅度下限最大的級別往下找。
    例：1.4 → big、2.0 → super、0.1 → crash、1.1 → normal。"""
    mag = abs(factor - 1.0)
    up = factor > 1.0
    for name, _p, lo, _hi, up_p in sorted(ep.tiers, key=lambda t: -t[2]):
        if mag >= lo - 1e-9 and (up_p > 0.0 if up else up_p < 1.0):
            return name
    return ep.tiers[0][0]


class MarketEvent:
    __slots__ = (
        "eid",
        "targets",
        "factor",
        "dev",
        "announce_at",
        "start_at",
        "ramp_s",
        "half_life_s",
        "end_at",
        "headline",
        "rare",
        "tier",
    )

    def __init__(
        self,
        eid,
        targets,
        factor,
        announce_at,
        start_at,
        ramp_s,
        half_life_s,
        lifetime_hl,
        headline,
        rare=False,
        tier=None,
    ):
        self.eid = eid
        self.targets = tuple(targets)
        self.factor = factor
        self.dev = factor - 1.0  # 全幅時的偏離量（+1.0 = 變兩倍，−0.9 = 剩一成）
        self.announce_at = announce_at
        self.start_at = start_at
        self.ramp_s = ramp_s
        self.half_life_s = half_life_s
        self.end_at = start_at + ramp_s + lifetime_hl * half_life_s
        self.headline = headline
        # 級別（D33）：normal、big、super、crash。rare 照舊存（舊程式讀新存檔要用）= 大事件以上（不是 normal）
        self.tier = tier if tier is not None else ("big" if rare else "normal")
        self.rare = self.tier != "normal"

    def log_effect(self, t: float) -> float:
        """t 時這則新聞對價格的影響（對數；Exchange 把每則加起來 = 倍數相乘，再夾 total_cap）。
        偏離量照半衰期減半：倍數 = 1 + dev × g，開始後 ramp_s 內 g 從 0 線性漲到 1，之後每個半衰期減半
        （ceo 2026-10-03，D33）。以前是倍數本身照對數消退（factor^g）：−90% 回到平常比 +100% 慢得多，
        兩種一樣多時平均價格偏低 2–5%；現在 +100%、−90% 的面積是 +1.44、−1.30（× 半衰期）。"""
        if t <= self.start_at or t >= self.end_at:
            return 0.0
        s = t - self.start_at
        g = s / self.ramp_s if s < self.ramp_s else 2.0 ** (-(s - self.ramp_s) / self.half_life_s)
        return math.log1p(self.dev * g)

    def to_dict(self) -> dict:
        """摘要（模擬報表用）。存檔回復用 to_state()。"""
        return {
            "id": self.eid,
            "targets": list(self.targets),
            "factor": self.factor,
            "announce_at": self.announce_at,
            "start_at": self.start_at,
            "half_life_h": self.half_life_s / HOUR,
            "headline": self.headline,
            "rare": self.rare,
            "tier": self.tier,
        }

    def to_state(self) -> dict:
        return {
            "id": self.eid,
            "targets": list(self.targets),
            "factor": self.factor,
            "announce_at": self.announce_at,
            "start_at": self.start_at,
            "ramp_s": self.ramp_s,
            "half_life_s": self.half_life_s,
            "end_at": self.end_at,
            "headline": self.headline,
            "rare": self.rare,
            "tier": self.tier,
        }

    @classmethod
    def from_state(cls, d: dict) -> "MarketEvent":
        ev = cls.__new__(cls)
        ev.eid = d["id"]
        ev.targets = tuple(d["targets"])
        ev.factor = d["factor"]
        ev.dev = ev.factor - 1.0
        ev.announce_at = d["announce_at"]
        ev.start_at = d["start_at"]
        ev.ramp_s = d["ramp_s"]
        ev.half_life_s = d["half_life_s"]
        ev.end_at = d["end_at"]
        ev.headline = d["headline"]
        ev.tier = d.get("tier") or ("big" if d["rare"] else "normal")  # D33 以前的存檔沒有 tier
        ev.rare = ev.tier != "normal"
        return ev


class EventGenerator:
    """Poisson 新聞事件。每則事件的所有屬性在抽到發生時間時一次抽完，所以結果與 tick 大小無關。"""

    def __init__(
        self, ep: EventParams, rng: random.Random, t0: float, commodity_ids: Sequence[str] = ("milk", "beef", "rice")
    ):
        self.ep = ep
        self.rng = rng
        self.cids = tuple(commodity_ids)
        self._n = 0
        self._queue: List[MarketEvent] = []  # 已抽出、還沒公開
        self._next_start = t0 + self._gap()

    def _gap(self) -> float:
        return self.rng.expovariate(self.ep.rate_per_day / DAY)

    def _target_table(self) -> List[Tuple[Tuple[str, ...], float]]:
        """params 的 targets 只留下這個交易所有的商品，機率重新正規化。"""
        rows = []
        for tg, p in self.ep.targets:
            kept = tuple(c for c in tg if c in self.cids)
            if kept and p > 0:
                rows.append((kept, p))
        total = sum(p for _, p in rows)
        return [(tg, p / total) for tg, p in rows]

    def _draw(self, start: float) -> MarketEvent:
        ep, r = self.ep, self.rng
        u = r.random()
        table = self._target_table()
        targets = table[-1][0]
        acc = 0.0
        for tg, p in table:
            acc += p
            if u < acc:
                targets = tg
                break
        key = targets[0] if len(targets) == 1 else "all"
        # 級別（D33）。每則新聞用的亂數次數跟以前一樣（級別、幅度、漲跌各一次），同一個 seed 的新聞時間和作用對象不變
        u = r.random() * sum(t[1] for t in ep.tiers)
        tier, _p, lo, hi, up_p = ep.tiers[-1]
        acc = 0.0
        for row in ep.tiers:
            acc += row[1]
            if u < acc:
                tier, _p, lo, hi, up_p = row
                break
        mag = r.uniform(lo, hi)
        up = r.random() < up_p  # 超級大事件 up_p = 1（只往上）、黑天鵝 0（只往下）
        announced = r.random() < ep.announce_prob
        hl = r.uniform(ep.half_life_lo_s, ep.half_life_hi_s)
        pool = HEADLINES[key + ("+" if up else "-")]
        headline = pool[r.randrange(len(pool))]
        self._n += 1
        return MarketEvent(
            eid=self._n,
            targets=targets,
            factor=(1.0 + mag) if up else (1.0 - mag),
            announce_at=start - ep.announce_lead_s if announced else start,
            start_at=start,
            ramp_s=ep.ramp_s,
            half_life_s=hl,
            lifetime_hl=ep.lifetime_half_lives,
            headline=headline,
            tier=tier,
        )

    def to_dict(self) -> dict:
        return {
            "n": self._n,
            "next_start": self._next_start,
            "queue": [ev.to_state() for ev in self._queue],
            "rng": rng_to_state(self.rng),
            "commodities": list(self.cids),
        }

    @classmethod
    def from_dict(cls, ep: EventParams, d: dict) -> "EventGenerator":
        g = cls.__new__(cls)
        g.ep = ep
        g.rng = rng_from_state(d["rng"])
        g.cids = tuple(d["commodities"])
        g._n = d["n"]
        g._queue = [MarketEvent.from_state(e) for e in d["queue"]]
        g._next_start = d["next_start"]
        return g

    def advance(self, now: float) -> List[MarketEvent]:
        """回傳到 now 為止新公開（公告或開始）的事件。"""
        while self._next_start <= now + self.ep.announce_lead_s:
            self._queue.append(self._draw(self._next_start))
            self._next_start += self._gap()
        out = [ev for ev in self._queue if ev.announce_at <= now]
        if out:
            self._queue = [ev for ev in self._queue if ev.announce_at > now]
        return out


# ---------------------------------------------------------------------------
# 交易所：多種商品 + 共用事件
# ---------------------------------------------------------------------------
class Exchange:
    def __init__(
        self,
        params: EconomyParams,
        seed,
        t0: float,
        commodity_ids: Optional[Sequence[str]] = None,
        events_enabled: bool = True,
    ):
        """commodity_ids 沒給就用 params.commodity_ids（v0.2：牛奶、牛肉、稻米）。"""
        if commodity_ids is None:
            commodity_ids = params.commodity_ids
        self.params = params
        self.t = t0
        self.markets: Dict[str, Market] = {
            cid: Market(params.commodity(cid), t0, random.Random(f"{seed}:noise:{cid}")) for cid in commodity_ids
        }
        self.generator: Optional[EventGenerator] = (
            EventGenerator(params.events, random.Random(f"{seed}:events"), t0, commodity_ids)
            if events_enabled
            else None
        )
        self.events: List[MarketEvent] = []  # 已公開、還沒結束
        self.event_log_history: List[MarketEvent] = []  # 全部出現過的事件（分析用）
        self._cap_hi = math.log(params.events.total_cap_up)
        self._cap_lo = math.log(params.events.total_cap_down)

    def inject_event(
        self,
        targets: Sequence[str],
        factor: float,
        start_at: float,
        half_life_s: float,
        announce_lead_s: float = 0.0,
        headline: str = "（測試事件）",
    ) -> MarketEvent:
        ep = self.params.events
        ev = MarketEvent(
            eid=-(len(self.event_log_history) + 1),
            targets=targets,
            factor=factor,
            announce_at=start_at - announce_lead_s,
            start_at=start_at,
            ramp_s=ep.ramp_s,
            half_life_s=half_life_s,
            lifetime_hl=ep.lifetime_half_lives,
            headline=headline,
            tier=tier_for_factor(ep, factor),
        )
        self.events.append(ev)
        self.event_log_history.append(ev)
        return ev

    def event_log_for(self, cid: str, t: float) -> float:
        z = 0.0
        for ev in self.events:
            if cid in ev.targets:
                z += ev.log_effect(t)
        if z > self._cap_hi:
            z = self._cap_hi
        elif z < self._cap_lo:
            z = self._cap_lo
        return z

    def step(self, now: float, online_count: float) -> None:
        if self.generator is not None:
            new = self.generator.advance(now)
            self.events.extend(new)
            self.event_log_history.extend(new)
        for cid, m in self.markets.items():
            m.step(now, online_count, self.event_log_for(cid, now))
        if self.events:
            self.events = [ev for ev in self.events if ev.end_at > now]
        self.t = now

    def upcoming(self, now: float) -> List[MarketEvent]:
        """已公告、還沒開始的事件（畫面上的「即將發生」）。沒到公告時間的不給看。"""
        return [ev for ev in self.events if ev.announce_at <= now < ev.start_at]

    def visible(self, now: float) -> List[MarketEvent]:
        """畫面上看得到的事件（已公告或已開始、還沒結束）。"""
        return [ev for ev in self.events if ev.announce_at <= now < ev.end_at]

    def price(self, cid: str) -> float:
        return self.markets[cid].price

    # ---- 存檔與回復 ----
    def to_dict(self, include_hist: bool = True, include_history: bool = True) -> dict:
        """完整狀態（純 JSON）。

        include_hist：各市場走勢圖的 24 小時歷史（伺服器另存在價格表，可以不含）。
        include_history：出現過的全部事件（模擬報表用；伺服器另存在新聞表，可以不含）。
        """
        d = {
            "engine": "cowecon",
            "t": self.t,
            "markets": {cid: m.to_dict(include_hist=include_hist) for cid, m in self.markets.items()},
            "generator": self.generator.to_dict() if self.generator is not None else None,
            "events": [ev.to_state() for ev in self.events],
        }
        if include_history:
            d["history"] = [ev.to_state() for ev in self.event_log_history]
        return d

    @classmethod
    def from_dict(
        cls, params: EconomyParams, d: dict, hist: Optional[Dict[str, Iterable[Tuple[float, float]]]] = None
    ) -> "Exchange":
        """從 to_dict() 回復。hist = {商品: [(時間, 價格), ...]}，存檔沒有含歷史時由呼叫端補。"""
        ex = cls.__new__(cls)
        ex.params = params
        ex.t = d["t"]
        hist = hist or {}
        ex.markets = {
            cid: Market.from_dict(params.commodity(cid), md, hist.get(cid)) for cid, md in d["markets"].items()
        }
        ex.generator = (
            EventGenerator.from_dict(params.events, d["generator"]) if d.get("generator") is not None else None
        )
        by_id: Dict[int, MarketEvent] = {}
        if "history" in d:
            ex.event_log_history = []
            for e in d["history"]:
                ev = MarketEvent.from_state(e)
                by_id[ev.eid] = ev
                ex.event_log_history.append(ev)
        ex.events = [by_id.get(e["id"]) or MarketEvent.from_state(e) for e in d["events"]]
        if "history" not in d:
            ex.event_log_history = list(ex.events)
        ex._cap_hi = math.log(params.events.total_cap_up)
        ex._cap_lo = math.log(params.events.total_cap_down)
        return ex
