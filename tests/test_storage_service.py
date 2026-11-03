"""Unit tests for ALPORA Storage Guard and Anti-Bloat Service."""
import argparse
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from poly_shell.services.storage_service import StorageService, _format_bytes
from poly_shell.commands.storage_cmd import handle_storage, _safe_print


class StorageServiceTests(unittest.TestCase):
    """Test suite for StorageService partition queries and clean mechanics."""

    def setUp(self):
        self.service = StorageService()

    def test_health_check(self):
        """Storage health check should query successfully."""
        self.assertTrue(self.service.health_check())

    def test_format_bytes(self):
        """Format bytes should produce clean units."""
        self.assertEqual(_format_bytes(500), "500 B")
        self.assertEqual(_format_bytes(1024), "1.0 KB")
        self.assertEqual(_format_bytes(1024 * 1024 * 50), "50.0 MB")
        self.assertEqual(_format_bytes(1024 * 1024 * 1024 * 2), "2.0 GB")

    def test_get_overview_contains_partitions(self):
        """Overview must contain at least root partition."""
        overview = self.service.get_overview()
        self.assertTrue(len(overview.partitions) >= 1)
        root_part = overview.partitions[0]
        self.assertGreater(root_part.total_bytes, 0)
        self.assertGreater(root_part.free_bytes, 0)

    def test_clean_caches(self):
        """Clean method should succeed and return cleaned targets."""
        res = self.service.clean(targets=["thumbnails", "pip"])
        self.assertTrue(res.success)
        self.assertIsInstance(res.cleaned_targets, list)

    def test_move_directory_library(self):
        """Moving directory library should move content and create functional symlink."""
        with tempfile.TemporaryDirectory() as src_parent:
            with tempfile.TemporaryDirectory() as dst_parent:
                source_dir = Path(src_parent) / "GameLibrary"
                source_dir.mkdir()
                test_file = source_dir / "asset.pak"
                test_file.write_text("dummy game data", encoding="utf-8")

                res = self.service.move_directory_library(str(source_dir), dst_parent)
                self.assertTrue(res.get("success"))
                is_link = source_dir.is_symlink() or (hasattr(source_dir, "is_junction") and source_dir.is_junction())
                self.assertTrue(is_link)

                # The file must still be accessible through the original path via symlink
                self.assertTrue(test_file.exists())
                self.assertEqual(test_file.read_text(encoding="utf-8"), "dummy game data")


class StorageCommandTests(unittest.TestCase):
    """Test suite for poly-shell storage CLI subcommands."""

    def test_safe_print_does_not_crash(self):
        """_safe_print must handle unicode cleanly."""
        _safe_print("ALPORA Storage: 🟢 Clean")

    @patch("sys.stdout")
    def test_handle_storage_status(self, _mock_stdout):
        """`poly-shell storage status` should execute successfully."""
        args = argparse.Namespace(storage_action="status")
        code = handle_storage(args)
        self.assertEqual(code, 0)

    @patch("sys.stdout")
    def test_handle_storage_clean(self, _mock_stdout):
        """`poly-shell storage clean` should execute and reclaim space."""
        args = argparse.Namespace(storage_action="clean")
        code = handle_storage(args)
        self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()
