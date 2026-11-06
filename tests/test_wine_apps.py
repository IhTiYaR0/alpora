import argparse
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, MagicMock

from poly_shell.wine_apps import (
    KNOWN_PRESETS,
    get_wine_prefix,
    generate_vietnamese_font_reg,
    create_desktop_entry,
    find_installed_exe,
    is_wine_available,
    register_exe_mime_handler,
)
from poly_shell.commands.exe_cmd import handle_exe


class TestWineApps(unittest.TestCase):
    def test_known_presets_structure(self):
        self.assertIn("zalo", KNOWN_PRESETS)
        self.assertIn("ultraviewer", KNOWN_PRESETS)
        self.assertIn("notepadpp", KNOWN_PRESETS)

        zalo = KNOWN_PRESETS["zalo"]
        self.assertEqual(zalo["name"], "Zalo")
        self.assertTrue(zalo["url"].startswith("http"))
        self.assertIn("InstantMessaging", zalo["categories"])

    def test_get_wine_prefix_sanitization(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            with patch.dict(os.environ, {"XDG_DATA_HOME": tmpdir}):
                prefix = get_wine_prefix("Zalo App 2026!")
                self.assertTrue(prefix.exists())
                self.assertIn("zaloapp2026", str(prefix).lower())

    def test_generate_vietnamese_font_reg(self):
        reg = generate_vietnamese_font_reg()
        self.assertIn("Windows Registry Editor Version 5.00", reg)
        self.assertIn('"Tahoma"="Noto Sans"', reg)
        self.assertIn('"Segoe UI"="Noto Sans"', reg)
        self.assertIn('"Arial"="Liberation Sans"', reg)

    def test_create_desktop_entry(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            with patch.dict(os.environ, {"XDG_DATA_HOME": tmpdir}):
                desktop = create_desktop_entry(
                    name="Test App",
                    exec_cmd="poly-shell exe run /test/app.exe",
                    icon="test-icon",
                    categories="Utility;Office;"
                )
                self.assertTrue(desktop.exists())
                content = desktop.read_text(encoding="utf-8")
                self.assertIn("Name=Test App", content)
                self.assertIn("Exec=poly-shell exe run /test/app.exe", content)
                self.assertIn("Icon=test-icon", content)
                self.assertIn("Categories=Utility;Office;", content)

    def test_find_installed_exe(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            target = root / "drive_c" / "Program Files" / "Zalo" / "Zalo.exe"
            target.parent.mkdir(parents=True)
            target.write_bytes(b"dummy")

            found = find_installed_exe(root, ["drive_c/Program Files*/Zalo/Zalo.exe"])
            self.assertEqual(found, target)

            not_found = find_installed_exe(root, ["drive_c/NonExistent/*.exe"])
            self.assertIsNone(not_found)

    def test_cli_exe_list(self):
        args = argparse.Namespace(exe_action="list")
        res = handle_exe(args)
        self.assertEqual(res, 0)

    @patch("poly_shell.commands.exe_cmd.download_file")
    def test_cli_exe_download_preset(self, mock_dl):
        with tempfile.TemporaryDirectory() as tmpdir:
            args = argparse.Namespace(
                exe_action="download",
                target="zalo",
                output=tmpdir
            )
            res = handle_exe(args)
            self.assertEqual(res, 0)
            mock_dl.assert_called_once()
            called_url = mock_dl.call_args[0][0]
            self.assertEqual(called_url, KNOWN_PRESETS["zalo"]["url"])

    def test_cli_exe_run_nonexistent_file(self):
        args = argparse.Namespace(
            exe_action="run",
            path="/nonexistent/app.exe",
            prefix=None,
            extra_args=[]
        )
        res = handle_exe(args)
        self.assertEqual(res, 1)


if __name__ == "__main__":
    unittest.main()
