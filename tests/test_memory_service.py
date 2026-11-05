"""Unit tests for ALPORA MemoryService and Anti-Thrashing Optimization."""
import json
import unittest
from unittest.mock import MagicMock, patch

from poly_shell.contracts.hardware import MemoryStateDTO, WorkspaceMemoryDTO
from poly_shell.services.memory_service import MemoryService


class MemoryServiceTests(unittest.TestCase):
    """Test suite for MemoryService."""

    def setUp(self):
        self.service = MemoryService()

    def test_health_check(self):
        """Health check returns True if /proc/meminfo exists."""
        self.assertTrue(self.service.health_check())

    @patch.object(MemoryService, "_read_meminfo")
    @patch.object(MemoryService, "_read_zram_stats")
    @patch.object(MemoryService, "_read_psi")
    @patch.object(MemoryService, "_get_workspace_memory")
    def test_get_overview(self, mock_ws, mock_psi, mock_zram, mock_mem):
        """get_overview should aggregate all memory and zRAM metrics."""
        mock_mem.return_value = {
            "MemTotal": 8000000,
            "MemFree": 1000000,
            "MemAvailable": 4000000,
            "Cached": 2000000,
            "Buffers": 500000,
            "SwapTotal": 4000000,
            "SwapFree": 3000000,
        }
        mock_zram.return_value = {
            "has_zram": True,
            "orig_mb": 2048.0,
            "compr_mb": 768.0,
            "ratio": 2.67,
        }
        mock_psi.return_value = {
            "some_avg10": 2.5,
            "full_avg10": 0.0,
        }
        mock_ws.return_value = [
            WorkspaceMemoryDTO(workspace_id=1, total_rss_mb=500.0, app_count=1, apps=["browser"]),
            WorkspaceMemoryDTO(workspace_id=2, total_rss_mb=1200.0, app_count=2, apps=["code", "terminal"]),
        ]

        state = self.service.get_overview()
        self.assertIsInstance(state, MemoryStateDTO)
        self.assertAlmostEqual(state.total_mb, 7812.5, places=1)
        self.assertTrue(state.has_zram)
        self.assertEqual(state.zram_ratio, 2.67)
        self.assertFalse(state.is_thrashing)
        self.assertEqual(len(state.workspaces), 2)
        self.assertEqual(state.workspaces[1].total_rss_mb, 1200.0)

    @patch("poly_shell.adapters.base.SafeRunner.run")
    def test_drop_caches(self, mock_run):
        """drop_caches should execute sync and return memory diff."""
        mock_proc = MagicMock()
        mock_proc.returncode = 0
        mock_run.return_value = mock_proc

        res = self.service.drop_caches()
        self.assertTrue(res.get("success"))
        mock_run.assert_called()

    def test_get_zram_config(self):
        """get_zram_config returns valid systemd zram-generator config."""
        config = self.service.get_zram_config()
        self.assertIn("[zram0]", config)
        self.assertIn("compression-algorithm = zstd", config)
        self.assertIn("swap-priority = 100", config)

    def test_get_performance_sysctl(self):
        """get_performance_sysctl returns optimized vm.swappiness and anti-thrashing parameters."""
        sysctl = self.service.get_performance_sysctl()
        self.assertIn("vm.swappiness = 180", sysctl)
        self.assertIn("vm.watermark_boost_factor = 0", sysctl)
        self.assertIn("vm.watermark_scale_factor = 125", sysctl)
        self.assertIn("vm.page-cluster = 0", sysctl)

    @patch("poly_shell.adapters.hyprland.HyprlandAdapter.hyprctl")
    @patch("os.setpriority")
    def test_eco_optimize_workspaces(self, mock_setpriority, mock_hyprctl):
        """eco_optimize_workspaces should de-prioritize background workspace windows."""
        mock_hyprctl.return_value = json.dumps([
            {"workspace": {"id": 1}, "pid": 1001, "class": "browser"},
            {"workspace": {"id": 2}, "pid": 2002, "class": "ide"},
        ])
        res = self.service.eco_optimize_workspaces(active_workspace_id=2)
        self.assertTrue(res.get("success"))
        self.assertEqual(res.get("active_workspace"), 2)
        self.assertEqual(res.get("throttled_count"), 1)
        self.assertEqual(res.get("prioritized_count"), 1)


if __name__ == "__main__":
    unittest.main()

