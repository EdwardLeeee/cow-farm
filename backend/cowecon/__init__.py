"""cowecon：cow-farm 的經濟引擎（行情與牧場規則）。M1 起放在 backend/cowecon/，伺服器與 docs/research/economy/ 的模擬共用這一份。

只用 Python 3.10 標準函式庫；給定 seed 結果固定。M1 的 FastAPI 伺服器直接 import 這個套件，
模擬的數字就是遊戲的數字。參數全部在 params.py。
"""

from .params import DAY, DEFAULT, ENGINE_VERSION, HOUR, MINUTE, EconomyParams, with_overrides
from .market import Exchange, ImpactState, Market, MarketEvent, SaleResult
from .farm import BeefLot, Cow, Farm, Lot, beef_storage_factor, freshness, offspring_distribution, tier_distribution

__all__ = [
    "DAY", "DEFAULT", "ENGINE_VERSION", "HOUR", "MINUTE", "EconomyParams", "with_overrides",
    "Exchange", "ImpactState", "Market", "MarketEvent", "SaleResult",
    "BeefLot", "Cow", "Farm", "Lot", "beef_storage_factor", "freshness", "offspring_distribution", "tier_distribution",
]
