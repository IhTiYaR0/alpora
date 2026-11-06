from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from poly_shell.state import Paths
from poly_shell.wellbeing import WellbeingTracker


class WellbeingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.paths = Paths(root / "config", root / "state", root / "runtime")
        self.paths.state.mkdir(parents=True, exist_ok=True)
        self.tracker = WellbeingTracker(self.paths)

    def tearDown(self):
        self.tmp.cleanup()

    def test_record_switch_accumulates_duration(self):
        with patch("time.time") as mock_time:
            mock_time.return_value = 1000.0
            self.tracker.record_switch("kitty")

            mock_time.return_value = 1010.0  # 10 seconds in kitty
            self.tracker.record_switch("firefox")

            mock_time.return_value = 1030.0  # 20 seconds in firefox
            self.tracker.record_switch("code")

            summary = self.tracker.get_summary()

        self.assertEqual(summary["total_seconds"], 30)
        apps = {app["name"]: app["seconds"] for app in summary["apps"]}
        self.assertEqual(apps.get("kitty"), 10)
        self.assertEqual(apps.get("firefox"), 20)

    def test_empty_or_corrupt_file_returns_safe_default(self):
        summary = self.tracker.get_summary("2026-01-01")
        self.assertEqual(summary["total_seconds"], 0)
        self.assertEqual(summary["apps"], [])

    def test_sub_second_switch_ignored_to_prevent_flutter(self):
        with patch("time.time") as mock_time:
            mock_time.return_value = 1000.0
            self.tracker.record_switch("kitty")
            mock_time.return_value = 1000.2  # only 0.2s
            self.tracker.record_switch("firefox")
            summary = self.tracker.get_summary()

        self.assertEqual(summary["total_seconds"], 0)


if __name__ == "__main__":
    unittest.main()
