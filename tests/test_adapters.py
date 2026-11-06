import subprocess
import unittest
from unittest.mock import patch

from poly_shell.adapters.base import SafeRunner
from poly_shell.adapters.hyprland import HyprlandAdapter


class TestAdapters(unittest.TestCase):
    def test_safe_runner_missing_binary(self):
        # A nonexistent command should return rc=127 without raising FileNotFoundError
        res = SafeRunner.run(["nonexistent_command_12345", "--arg"])
        self.assertEqual(res.returncode, 127)
        self.assertIn("not found", res.stderr)

    def test_safe_runner_empty_command(self):
        res = SafeRunner.run([])
        self.assertEqual(res.returncode, 1)

    @patch("shutil.which", return_value="/usr/bin/mocked")
    @patch("subprocess.run")
    def test_safe_runner_timeout(self, mock_run, mock_which):
        mock_run.side_effect = subprocess.TimeoutExpired(cmd=["mocked"], timeout=2.0)
        res = SafeRunner.run(["mocked"], timeout=2.0)
        self.assertEqual(res.returncode, 124)
        self.assertIn("timed out", res.stderr)

    @patch("shutil.which", return_value="/usr/bin/hyprctl")
    @patch("subprocess.run")
    def test_hyprland_adapter_monitors(self, mock_run, mock_which):
        mock_run.return_value = subprocess.CompletedProcess(
            args=["hyprctl", "monitors", "-j"],
            returncode=0,
            stdout='[{"id": 0, "name": "eDP-1", "width": 1920, "height": 1080}]',
            stderr="",
        )
        monitors = HyprlandAdapter.get_monitors()
        self.assertEqual(len(monitors), 1)
        self.assertEqual(monitors[0]["name"], "eDP-1")

    @patch("shutil.which", return_value="/usr/bin/hyprctl")
    @patch("subprocess.run")
    def test_hyprland_adapter_clients(self, mock_run, mock_which):
        mock_run.return_value = subprocess.CompletedProcess(
            args=["hyprctl", "clients", "-j"],
            returncode=0,
            stdout='[{"address": "0x123", "title": "Firefox", "class": "firefox", "workspace": {"id": 1}}]',
            stderr="",
        )
        clients = HyprlandAdapter.get_clients()
        self.assertEqual(len(clients), 1)
        self.assertEqual(clients[0]["class"], "firefox")

    def test_hyprland_socket2_missing_env(self):
        with patch.dict("os.environ", {}, clear=True):
            sock = HyprlandAdapter.get_socket2_path()
            self.assertIsNone(sock)

    @patch("shutil.which", return_value=None)
    def test_hyprland_adapter_unavailable(self, mock_which):
        self.assertFalse(HyprlandAdapter.is_available())
        monitors = HyprlandAdapter.get_monitors()
        self.assertEqual(monitors, [])


if __name__ == "__main__":
    unittest.main()
