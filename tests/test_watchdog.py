"""Unit tests for runtime watchdog, telemetry, and crash logging in poly_shell.watchdog."""
import json
import tempfile
import unittest
from pathlib import Path

from poly_shell.state import Paths
from poly_shell.watchdog import CrashReporter, HeartbeatWatchdog, ProcessMonitor


class TestWatchdog(unittest.TestCase):
    def test_process_monitor_metrics(self):
        # Current python process metrics should resolve without error
        telemetry = ProcessMonitor.get_process_metrics()
        if telemetry is not None:
            self.assertGreater(telemetry.pid, 0)
            self.assertIsInstance(telemetry.rss_mb, float)
            self.assertGreaterEqual(telemetry.threads_count, 1)

    def test_heartbeat_watchdog_detects_stall(self):
        watchdog = HeartbeatWatchdog(heartbeat_timeout=0.04)
        self.assertFalse(watchdog.is_stalled())
        watchdog.beat()
        self.assertFalse(watchdog.is_stalled())

        import time
        time.sleep(0.06)
        self.assertTrue(watchdog.is_stalled())

    def test_crash_reporter_dump(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            fake_paths = Paths(
                config=temp_path / "config",
                state=temp_path / "state",
                runtime=temp_path / "runtime",
            )
            fake_paths.state.mkdir(parents=True, exist_ok=True)

            CrashReporter.install(fake_paths)
            try:
                raise RuntimeError("Simulated test panic")
            except RuntimeError as exc:
                dump_file = CrashReporter._create_crash_dump(type(exc), exc, exc.__traceback__)

            self.assertTrue(dump_file.exists())
            data = json.loads(dump_file.read_text(encoding="utf-8"))
            self.assertEqual(data["exception"]["type"], "RuntimeError")
            self.assertIn("Simulated test panic", data["exception"]["message"])
            self.assertTrue(len(data["exception"]["traceback"]) > 0)


if __name__ == "__main__":
    unittest.main()
