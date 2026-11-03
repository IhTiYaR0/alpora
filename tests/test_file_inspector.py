"""Unit tests for ALPORA File and Folder Properties Inspector."""
import argparse
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from poly_shell.services.file_inspector import FileInspectorService, compute_file_hashes
from poly_shell.commands.properties_cmd import handle_properties, _safe_print


class FileInspectorTests(unittest.TestCase):
    """Test suite for FileInspectorService metadata and checksums."""

    def test_compute_hashes(self):
        """Streaming hash computation should produce valid SHA256 and MD5."""
        with tempfile.NamedTemporaryFile(delete=False) as tf:
            tf.write(b"ALPORA OS File Integrity Test Payload")
            tmp_path = Path(tf.name)

        try:
            hashes = compute_file_hashes(tmp_path)
            self.assertIn("sha256", hashes)
            self.assertIn("md5", hashes)
            self.assertEqual(len(hashes["sha256"]), 64)
            self.assertEqual(len(hashes["md5"]), 32)
        finally:
            tmp_path.unlink(missing_ok=True)

    def test_inspect_file(self):
        """Inspecting a file should return full metadata properties."""
        with tempfile.NamedTemporaryFile(suffix=".txt", delete=False) as tf:
            tf.write(b"Hello ALPORA Desktop")
            tmp_path = Path(tf.name)

        try:
            info = FileInspectorService.inspect(str(tmp_path))
            self.assertTrue(info["exists"])
            self.assertFalse(info["is_dir"])
            self.assertIn("size_human", info)
            self.assertIn("permissions_human", info)
            self.assertIn("hashes", info)
        finally:
            tmp_path.unlink(missing_ok=True)

    def test_inspect_directory(self):
        """Inspecting a directory should count items and sizes."""
        with tempfile.TemporaryDirectory() as td:
            td_path = Path(td)
            (td_path / "sub1.txt").write_text("file 1")
            (td_path / "sub2.txt").write_text("file 2")

            info = FileInspectorService.inspect(str(td_path))
            self.assertTrue(info["exists"])
            self.assertTrue(info["is_dir"])
            self.assertEqual(info["item_count"], 2)


class PropertiesCommandTests(unittest.TestCase):
    """Test suite for poly-shell properties CLI command."""

    def test_safe_print_does_not_crash(self):
        """_safe_print must handle text safely."""
        _safe_print("ALPORA Properties: 🟢 Ready")

    @patch("sys.stdout")
    def test_handle_properties_existing_file(self, _mock_stdout):
        """`poly-shell properties <file>` should output metadata and exit 0."""
        with tempfile.NamedTemporaryFile(delete=False) as tf:
            tmp_path = Path(tf.name)

        try:
            args = argparse.Namespace(target=str(tmp_path))
            code = handle_properties(args)
            self.assertEqual(code, 0)
        finally:
            tmp_path.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()

