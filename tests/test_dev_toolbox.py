"""Unit tests for ALPORA Developer Toolbox and CLI Toolchain Hub."""
import argparse
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from poly_shell.services.dev_toolbox import DevToolboxService, CURATED_CATALOG
from poly_shell.commands.dev_cmd import handle_dev, _safe_print


class DevToolboxServiceTests(unittest.TestCase):
    """Test suite for DevToolboxService installation and PATH management."""

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root_path = Path(self.temp_dir.name)
        self.service = DevToolboxService(root_dir=self.root_path)

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_health_check(self):
        """DevToolbox health check should pass."""
        self.assertTrue(self.service.health_check())

    def test_get_status_returns_catalog(self):
        """Status should report full catalog tools."""
        st = self.service.get_status()
        self.assertEqual(st.total_tools, len(CURATED_CATALOG))
        self.assertIsInstance(st.tools, list)
        tool_names = [t.name for t in st.tools]
        self.assertIn("lazygit", tool_names)
        self.assertIn("uv", tool_names)
        self.assertIn("bun", tool_names)

    def test_install_and_remove_tool(self):
        """Installing and then removing a tool should manage files and registry cleanly."""
        res = self.service.install_tool("lazygit")
        self.assertTrue(res.get("success"))

        st_after = self.service.get_status()
        lazygit_tool = next(t for t in st_after.tools if t.name == "lazygit")
        self.assertTrue(lazygit_tool.installed)

        # Clean removal
        rem_res = self.service.remove_tool("lazygit")
        self.assertTrue(rem_res.get("success"))

        st_final = self.service.get_status()
        lazygit_final = next(t for t in st_final.tools if t.name == "lazygit")
        self.assertFalse(lazygit_final.installed)

    def test_doctor_diagnostics(self):
        """Doctor should diagnose $PATH and cleanup broken symlinks."""
        doc = self.service.doctor()
        self.assertIn("in_path", doc)
        self.assertIn("bin_dir", doc)
        self.assertIn("export_command", doc)

    def test_export_and_import_stack(self):
        """Exporting and importing a developer profile should restore tools."""
        self.service.install_tool("uv")
        stack_file = self.root_path / "export_test.json"
        self.service.export_stack(str(stack_file))
        self.assertTrue(stack_file.exists())

        # Test import in another clean toolbox instance
        new_dir = Path(self.temp_dir.name) / "toolbox_new"
        new_service = DevToolboxService(root_dir=new_dir)
        imp_res = new_service.import_stack(str(stack_file))
        self.assertTrue(imp_res.get("success"))
        self.assertGreaterEqual(imp_res.get("count", 0), 1)

    def test_clone_reflink(self):
        """Reflink clone should replicate files and directories cleanly."""
        src = self.root_path / "project_src"
        src.mkdir()
        (src / "package.json").write_text('{"name": "test"}', encoding="utf-8")
        dst = self.root_path / "project_dst"

        res = self.service.clone_reflink(str(src), str(dst))
        self.assertTrue(res.get("success"))
        self.assertTrue(dst.exists())
        self.assertTrue((dst / "package.json").exists())


class DevCommandTests(unittest.TestCase):
    """Test suite for poly-shell dev CLI subcommands."""

    def test_safe_print_does_not_crash(self):
        """_safe_print should safely output emojis and text."""
        _safe_print("ALPORA Dev Hub: 🟢 Ready")

    @patch("sys.stdout")
    def test_handle_dev_list(self, _mock_stdout):
        """`poly-shell dev list` should execute and exit 0."""
        args = argparse.Namespace(dev_action="list")
        code = handle_dev(args)
        self.assertEqual(code, 0)

    @patch("sys.stdout")
    def test_handle_dev_doctor(self, _mock_stdout):
        """`poly-shell dev doctor` should execute and exit 0."""
        args = argparse.Namespace(dev_action="doctor")
        code = handle_dev(args)
        self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()

