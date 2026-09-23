import math
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))

from yoy_bridge import Segment, driver_bridge, segment_bridge  # noqa: E402


class SegmentBridgeTest(unittest.TestCase):
    def setUp(self):
        self.rows = [
            Segment("vertical", "Local", 110, 100, 90, 100),
            Segment("vertical", "Goods", 50, 50, 55, 50),
            Segment("vertical", "Travel", 20, 25, 18, 30),
        ]

    def test_contributions_sum_to_total_yoy(self):
        total, rows = segment_bridge(self.rows)
        self.assertAlmostEqual(sum(r.contrib_d1 for r in rows), total["yoy_d1"])
        self.assertAlmostEqual(sum(r.contrib_d for r in rows), total["yoy_d"])
        self.assertAlmostEqual(sum(r.delta for r in rows), total["delta"])

    def test_rate_plus_mix_equals_delta(self):
        _, rows = segment_bridge(self.rows)
        for r in rows:
            self.assertAlmostEqual(r.rate_effect + r.mix_effect + r.new_lost, r.delta)

    def test_sorted_by_absolute_change(self):
        _, rows = segment_bridge(self.rows)
        self.assertEqual(rows[0].segment, "Local")

    def test_segment_without_ly_goes_to_new_lost(self):
        rows = self.rows + [Segment("vertical", "NewBiz", 0, 0, 10, 0)]
        total, out = segment_bridge(rows)
        new = next(r for r in out if r.segment == "NewBiz")
        self.assertEqual(new.rate_effect, 0.0)
        self.assertAlmostEqual(new.new_lost, new.delta)
        self.assertAlmostEqual(sum(r.delta for r in out), total["delta"])

    def test_zero_ly_total_raises(self):
        with self.assertRaises(ValueError):
            segment_bridge([Segment("x", "a", 1, 0, 1, 0)])


class DriverBridgeTest(unittest.TestCase):
    def setUp(self):
        # (ty_d1, ly_d1, ty_d, ly_d)
        self.components = {
            "traffic": (1000, 1000, 950, 1000),
            "orders": (50, 48, 45, 50),
            "gb": (5000, 4700, 4400, 5100),
        }

    def test_allocation_sums_to_delta(self):
        res = driver_bridge(self.components)
        self.assertAlmostEqual(sum(res["delta_pp_by_driver"].values()), res["delta_pp"])

    def test_log_identity(self):
        res = driver_bridge(self.components)
        lhs = math.log(1 + res["yoy_d"]) - math.log(1 + res["yoy_d1"])
        self.assertAlmostEqual(lhs, res["ty_dod_log"] - res["ly_dod_log"])
        for day in ("yoy_by_driver_d1", "yoy_by_driver_d"):
            prod = math.prod(1 + v for v in res[day].values())
            yoy = res["yoy_d1"] if day.endswith("d1") else res["yoy_d"]
            self.assertAlmostEqual(prod, 1 + yoy)


if __name__ == "__main__":
    unittest.main()
