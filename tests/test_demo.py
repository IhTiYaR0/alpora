"""Unit tests for ALPORA Demo Module (poly_shell.commands.demo_cmd & poly_shell.system.demo_server)."""
import argparse
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest.mock import patch, MagicMock
import urllib.request

from poly_shell.core.state import Paths, update_session
from poly_shell.system.demo_server import (
    get_system_telemetry,
    get_available_themes,
    find_free_port,
    start_demo_server,
)
from poly_shell.commands.demo_cmd import handle_demo


class TestDemoModule(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.paths = Paths(root / "config", root / "state", root / "runtime")
        update_session(self.paths)

    def test_get_system_telemetry_structure(self):
        telemetry = get_system_telemetry(self.paths)
        self.assertTrue(telemetry["online"])
        self.assertIn("platform", telemetry)
        self.assertIn("session", telemetry)
        self.assertIn("metrics", telemetry)
        self.assertIn("cpuPercent", telemetry["metrics"])
        self.assertIn("ramUsedGb", telemetry["metrics"])
        self.assertIn("batteryPercent", telemetry["metrics"])

    def test_get_available_themes(self):
        themes = get_available_themes()
        self.assertIsInstance(themes, list)
        self.assertGreater(len(themes), 0)
        theme_ids = [t["id"] for t in themes]
        self.assertIn("alpine", theme_ids)
        self.assertIn("moon-lake", theme_ids)

    def test_demo_server_endpoints(self):
        # Start server non-blocking in a background thread
        server, port = start_demo_server(paths=self.paths, port=8890, open_browser=False, blocking=False)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        time.sleep(0.15)

        try:
            base_url = f"http://127.0.0.1:{port}"

            # 1. Test redirect to /shell/demos/web/index.html
            class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
                def http_error_302(self, req, fp, code, msg, headers):
                    return fp

            opener = urllib.request.build_opener(NoRedirectHandler)
            with opener.open(f"{base_url}/", timeout=3) as resp:
                self.assertEqual(resp.status, 302)
                self.assertEqual(resp.headers.get("Location"), "/shell/demos/web/index.html")

            # 2. Test /api/state
            with urllib.request.urlopen(f"{base_url}/api/state", timeout=3) as resp:
                self.assertEqual(resp.status, 200)
                data = json.loads(resp.read().decode("utf-8"))
                self.assertTrue(data.get("online"))
                self.assertIn("metrics", data)

            # 3. Test /api/themes
            with urllib.request.urlopen(f"{base_url}/api/themes", timeout=3) as resp:
                self.assertEqual(resp.status, 200)
                themes = json.loads(resp.read().decode("utf-8"))
                self.assertTrue(len(themes) > 0)

            # 4. Test /api/action POST
            req = urllib.request.Request(
                f"{base_url}/api/action",
                data=json.dumps({"action": "mode", "value": "vibe"}).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=3) as resp:
                self.assertEqual(resp.status, 200)
                res_data = json.loads(resp.read().decode("utf-8"))
                self.assertTrue(res_data.get("ok"))
        finally:
            server.shutdown()
            server.server_close()

    @patch("poly_shell.commands.demo_cmd.start_demo_server")
    def test_handle_demo_web_mode(self, mock_start):
        args = argparse.Namespace(mode="web", port=8080, no_browser=True)
        code = handle_demo(self.paths, args)
        self.assertEqual(code, 0)
        mock_start.assert_called_once_with(paths=self.paths, port=8080, open_browser=False, blocking=True)

    @patch("poly_shell.commands.demo_cmd.shutil.which")
    def test_handle_demo_native_missing_quickshell(self, mock_which):
        mock_which.return_value = None
        args = argparse.Namespace(mode="native", port=8080, no_browser=True)
        code = handle_demo(self.paths, args)
        self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()

