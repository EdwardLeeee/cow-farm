"""整個模擬（玩家 bot + 市場）給定 seed 結果固定。"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import sim  # noqa: E402,F401  （把 backend/ 加進 sys.path；cowecon 在 backend/cowecon/）

from sim.world import World  # noqa: E402

SC = {"players": 24, "days": 2, "tick_s": 60}


def fingerprint(seed):
    w = World(SC, seed)
    s = w.run()
    prices = (tuple(w.rec["milk"]), tuple(w.rec["beef"]))
    coins = tuple(round(b.farm.coins, 6) for b in w.bots)
    herds = tuple((len(b.farm.cows), b.farm.slots) for b in w.bots)
    return prices, coins, herds, s["onboarding"]


class TestSimDeterminism(unittest.TestCase):
    def test_same_seed_identical(self):
        a = fingerprint(123)
        b = fingerprint(123)
        self.assertEqual(a, b)

    def test_different_seed_differs(self):
        self.assertNotEqual(fingerprint(123)[0], fingerprint(124)[0])


if __name__ == "__main__":
    unittest.main()
