"""Unit tests for ALPORA panel and window CLI dispatchers."""
import argparse
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, MagicMock

from poly_shell import cli
from poly_shell.commands import panel_cmd
from poly_shell.core.state import Paths, atomic_json


class PanelCommandsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        self.paths = Paths(root / "config/poly-shell", root / "state", root / "runtime")
        self.paths.config.mkdir(parents=True, exist_ok=True)
        self.paths.runtime.mkdir(parents=True, exist_ok=True)

    @patch("poly_shell.commands.panel_cmd.subprocess.run")
    def test_call_shell_ipc_success(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0)
        self.assertTrue(panel_cmd.call_shell_ipc("toggleLauncher"))
        mock_run.assert_called_once()
        args = mock_run.call_args[0][0]
        self.assertIn("quickshell", args)
        self.assertIn("toggleLauncher", args)

    @patch("poly_shell.commands.panel_cmd.call_shell_ipc")
    def test_handle_launcher(self, mock_ipc):
        mock_ipc.return_value = True
        self.assertEqual(panel_cmd.handle_launcher(self.paths, None), 0)
        mock_ipc.assert_called_once_with("toggleLauncher")

    @patch("poly_shell.commands.panel_cmd.call_shell_ipc")
    def test_handle_quick_settings(self, mock_ipc):
        mock_ipc.return_value = True
        self.assertEqual(panel_cmd.handle_quick_settings(self.paths, None), 0)
        mock_ipc.assert_called_once_with("toggleQuickSettings")

    @patch("poly_shell.commands.panel_cmd.call_shell_ipc")
    def test_handle_notifications(self, mock_ipc):
        mock_ipc.return_value = True
        self.assertEqual(panel_cmd.handle_notifications(self.paths, None), 0)
        mock_ipc.assert_called_once_with("toggleBarPanel", "notifications")

    @patch("poly_shell.commands.panel_cmd.call_shell_ipc")
    def test_handle_clipboard(self, mock_ipc):
        mock_ipc.return_value = True
        self.assertEqual(panel_cmd.handle_clipboard(self.paths, None), 0)
        mock_ipc.assert_called_once_with("toggleBarPanel", "clipboard")

    @patch("poly_shell.commands.panel_cmd.call_shell_ipc")
    def test_handle_overview(self, mock_ipc):
        mock_ipc.return_value = True
        self.assertEqual(panel_cmd.handle_overview(self.paths, None), 0)
        mock_ipc.assert_called_once_with("toggleOverview")

    @patch("poly_shell.commands.panel_cmd.call_shell_ipc")
    def test_handle_power_menu(self, mock_ipc):
        mock_ipc.return_value = True
        self.assertEqual(panel_cmd.handle_power_menu(self.paths, None), 0)
        mock_ipc.assert_called_once_with("powerMenu")

    @patch("poly_shell.commands.panel_cmd.call_shell_ipc")
    def test_handle_toggle_mode(self, mock_ipc):
        mock_ipc.return_value = True
        atomic_json(self.paths.config / "settings.json", {"mode": "work"})
        self.assertEqual(panel_cmd.handle_toggle_mode(self.paths, None), 0)
        mock_ipc.assert_called_once_with("toggleMode")

    @patch("poly_shell.commands.panel_cmd.subprocess.run")
    def test_open_welcome_raises_window_if_already_running(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0)
        with patch.dict("os.environ", {"WAYLAND_DISPLAY": "wayland-1"}):
            self.assertEqual(panel_cmd.open_welcome(self.paths), 0)

    @patch("poly_shell.cli.commands.handle_launcher")
    def test_cli_dispatches_launcher(self, mock_launcher):
        mock_launcher.return_value = 0
        self.assertEqual(cli.main(["launcher"]), 0)
        mock_launcher.assert_called_once()

    @patch("poly_shell.cli.commands.handle_clipboard")
    def test_cli_dispatches_clipboard(self, mock_clipboard):
        mock_clipboard.return_value = 0
        self.assertEqual(cli.main(["clipboard"]), 0)
        mock_clipboard.assert_called_once()

    @patch("poly_shell.cli.commands.handle_quick_settings")
    def test_cli_dispatches_quick_settings(self, mock_qs):
        mock_qs.return_value = 0
        self.assertEqual(cli.main(["quick-settings"]), 0)
        mock_qs.assert_called_once()


if __name__ == "__main__":
    unittest.main()
