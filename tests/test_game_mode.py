"""Unit tests for ALPORA Game Mode and Hoyoverse gaming optimizations."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import MagicMock, patch

from poly_shell.adapters.base import SafeRunner
from poly_shell.commands.game_cmd import handle_game
from poly_shell.core.state import Paths
from poly_shell.services.game_mode import GameModeService


class GameModeServiceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.paths = Paths(root / "config", root / "state", root / "runtime")
        self.service = GameModeService(paths=self.paths)

    @patch.object(SafeRunner, "is_available")
    def test_health_check(self, mock_avail):
        mock_avail.side_effect = lambda tool: tool == "hyprctl"
        self.assertTrue(self.service.health_check())

        mock_avail.side_effect = lambda tool: False
        self.assertFalse(self.service.health_check())

    @patch.object(SafeRunner, "run")
    @patch.object(SafeRunner, "is_available", return_value=True)
    def test_enable_and_get_state(self, mock_avail, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="performance", stderr="")

        res = self.service.enable("Zenless Zone Zero")
        self.assertTrue(res)

        state = self.service.get_state()
        self.assertTrue(state.enabled)
        self.assertEqual(state.active_game, "Zenless Zone Zero")
        self.assertTrue(state.animations_disabled)
        self.assertTrue(state.blur_disabled)
        self.assertIn("hyprland_animations_disabled", state.optimizations)

    @patch.object(SafeRunner, "run")
    @patch.object(SafeRunner, "is_available", return_value=True)
    def test_disable_and_toggle(self, mock_avail, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="balanced", stderr="")

        # Enable
        self.service.enable("Honkai: Star Rail")
        self.assertTrue(self.service.get_state().enabled)

        # Disable
        self.service.disable()
        self.assertFalse(self.service.get_state().enabled)

        # Toggle on
        toggled_on = self.service.toggle("ZZZ")
        self.assertTrue(toggled_on)
        self.assertTrue(self.service.get_state().enabled)

        # Toggle off
        toggled_off = self.service.toggle()
        self.assertFalse(toggled_off)
        self.assertFalse(self.service.get_state().enabled)

    def test_hoyoverse_presets(self):
        zzz_preset = self.service.get_hoyoverse_preset("zzz")
        self.assertIn("Zenless Zone Zero", zzz_preset["title"])
        self.assertEqual(zzz_preset["env_vars"]["DXVK_ASYNC"], "1")
        self.assertEqual(zzz_preset["env_vars"]["WINEFSYNC"], "1")

        hsr_preset = self.service.get_hoyoverse_preset("starrail")
        self.assertIn("Honkai: Star Rail", hsr_preset["title"])
        self.assertEqual(hsr_preset["env_vars"]["DXVK_ASYNC"], "1")

        gi_preset = self.service.get_hoyoverse_preset("genshin")
        self.assertIn("Genshin", gi_preset["title"])

    @patch.object(SafeRunner, "run")
    @patch.object(SafeRunner, "is_available", return_value=True)
    def test_cli_handlers(self, mock_avail, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="balanced", stderr="")

        # Test CLI on
        args_on = MagicMock(game_action="on", game="ZZZ")
        self.assertEqual(handle_game(args_on), 0)

        # Test CLI status
        args_status = MagicMock(game_action="status", json=False)
        self.assertEqual(handle_game(args_status), 0)

        # Test CLI hoyo
        args_hoyo = MagicMock(game_action="hoyo", target="zzz")
        self.assertEqual(handle_game(args_hoyo), 0)

        # Test CLI off
        args_off = MagicMock(game_action="off")
        self.assertEqual(handle_game(args_off), 0)


if __name__ == "__main__":
    unittest.main()
