import json
import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from poly_shell.cli import main
from poly_shell.preflight import (
    check_compositor,
    check_directory_writable,
    check_xdg_permissions,
    format_preflight_report,
    run_preflight,
)


class TestPreflight(unittest.TestCase):
    def test_check_directory_writable(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertTrue(check_directory_writable(Path(tmp)))

    def test_check_xdg_permissions(self):
        with tempfile.TemporaryDirectory() as tmp_str:
            tmp = Path(tmp_str)
            paths = SimpleNamespace(
                config=tmp / "config",
                state=tmp / "state",
                runtime=tmp / "runtime",
            )
            results = check_xdg_permissions(paths)
            self.assertEqual(len(results), 3)
            self.assertTrue(all(r["writable"] for r in results))

    @patch.dict(os.environ, {"HYPRLAND_INSTANCE_SIGNATURE": "sig_123", "WAYLAND_DISPLAY": "wayland-1"})
    def test_check_compositor_inside(self):
        info = check_compositor()
        self.assertTrue(info["inside_hyprland"])
        self.assertEqual(info["instance_signature"], "sig_123")
        self.assertEqual(info["wayland_display"], "wayland-1")

    @patch.dict(os.environ, {}, clear=True)
    def test_check_compositor_outside(self):
        info = check_compositor()
        self.assertFalse(info["inside_hyprland"])

    @patch("poly_shell.preflight.inventory")
    def test_run_preflight_all_available(self, mock_inv):
        mock_inv.return_value = [
            {"name": "Quickshell", "package": "quickshell", "required": True, "available": True, "purpose": "Shell UI"},
            {"name": "Foot", "package": "foot", "required": False, "available": False, "purpose": "Terminal"},
        ]
        with tempfile.TemporaryDirectory() as tmp_str:
            tmp = Path(tmp_str)
            paths = SimpleNamespace(config=tmp / "cfg", state=tmp / "st", runtime=tmp / "rt")
            report = run_preflight(paths)
            self.assertTrue(report["ready"])
            self.assertEqual(report["tools"]["required_available"], 1)
            self.assertEqual(len(report["tools"]["missing_required"]), 0)

    @patch("poly_shell.preflight.inventory")
    def test_run_preflight_missing_required(self, mock_inv):
        mock_inv.return_value = [
            {"name": "Quickshell", "package": "quickshell", "required": True, "available": False, "purpose": "Shell UI"},
        ]
        with tempfile.TemporaryDirectory() as tmp_str:
            tmp = Path(tmp_str)
            paths = SimpleNamespace(config=tmp / "cfg", state=tmp / "st", runtime=tmp / "rt")
            report = run_preflight(paths)
            self.assertFalse(report["ready"])
            self.assertEqual(len(report["tools"]["missing_required"]), 1)

    def test_format_preflight_report(self):
        fake_report = {
            "ready": True,
            "os": {"NAME": "Arch Linux", "PRETTY_NAME": "Arch Linux"},
            "compositor": {"inside_hyprland": True, "monitor_count": 1, "hyprctl_available": True},
            "permissions": [{"name": "Config", "path": "/tmp/cfg", "writable": True}],
            "tools": {
                "required_count": 5,
                "required_available": 5,
                "missing_required": [],
                "optional_count": 10,
                "optional_available": 8,
                "missing_optional": [{"name": "Pavucontrol", "package": "pavucontrol", "purpose": "Audio GUI"}],
            },
        }
        text = format_preflight_report(fake_report)
        self.assertIn("ALPORA / POLY-SHELL PRE-FLIGHT CHECKLIST", text)
        self.assertIn("Arch Linux", text)
        self.assertIn("READY FOR INSTALLATION", text)

    def test_cli_preflight_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            ret = main(["preflight", "--json"])
            # Exit code is either 0 or 1 depending on whether local machine has all required Linux tools
            self.assertIn(ret, (0, 1))


if __name__ == "__main__":
    unittest.main()
