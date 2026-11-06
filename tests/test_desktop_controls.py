"""Unit tests for ui-scale, touchpad, and font controls in poly_shell.desktop."""
from pathlib import Path
import tempfile
import unittest

from poly_shell.desktop import control
from poly_shell.state import ConfigError, Paths, read_object, update_session


class DesktopControlsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.paths = Paths(root / "config", root / "state", root / "runtime")
        update_session(self.paths)

    def test_ui_scale_valid_and_persisted(self):
        control(self.paths, "ui-scale", "1.25")
        settings = read_object(self.paths.config / "settings.json")
        self.assertEqual(settings["bar"]["uiScale"], 1.25)

        control(self.paths, "ui-scale", "2.0")
        settings = read_object(self.paths.config / "settings.json")
        self.assertEqual(settings["bar"]["uiScale"], 2.0)

    def test_ui_scale_invalid_bounds(self):
        with self.assertRaises(ConfigError):
            control(self.paths, "ui-scale", "0.2")
        with self.assertRaises(ConfigError):
            control(self.paths, "ui-scale", "4.0")
        with self.assertRaises(ConfigError):
            control(self.paths, "ui-scale", "invalid")

    def test_touchpad_valid_and_persisted(self):
        payload = '{"tapToClick": false, "naturalScroll": false, "sensitivity": 0.5}'
        control(self.paths, "touchpad", payload)
        settings = read_object(self.paths.config / "settings.json")
        self.assertFalse(settings["input"]["touchpad"]["tapToClick"])
        self.assertFalse(settings["input"]["touchpad"]["naturalScroll"])
        self.assertEqual(settings["input"]["touchpad"]["sensitivity"], 0.5)

    def test_touchpad_invalid_payload(self):
        with self.assertRaises(ConfigError):
            control(self.paths, "touchpad", "not-a-json")

    def test_font_valid_and_persisted(self):
        control(self.paths, "font", "JetBrains Mono")
        settings = read_object(self.paths.config / "settings.json")
        self.assertEqual(settings["bar"]["fontFamily"], "JetBrains Mono")

    def test_font_empty_rejected(self):
        with self.assertRaises(ConfigError):
            control(self.paths, "font", "   ")

    def test_gamemode_control(self):
        res = control(self.paths, "gamemode", "on")
        self.assertTrue(res["gameMode"])

        res_off = control(self.paths, "gamemode", "off")
        self.assertFalse(res_off["gameMode"])

    def test_phone_control(self):
        res = control(self.paths, "phone")
        self.assertIn("available", res)
        self.assertIn("devices", res)


if __name__ == "__main__":
    unittest.main()
