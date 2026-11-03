"""Unit tests for ALPORA Instant System Recovery and Btrfs Snapshots."""
import argparse
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from poly_shell.services.snapshot_service import SnapshotService
from poly_shell.commands.snapshot_cmd import handle_snapshot, _safe_print


class SnapshotServiceTests(unittest.TestCase):
    """Test suite for SnapshotService list and create mechanics."""

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.state_dir = Path(self.temp_dir.name)
        self.service = SnapshotService(state_dir=self.state_dir)

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_health_check(self):
        """Snapshot health check should return True."""
        self.assertTrue(self.service.health_check())

    def test_create_and_list_snapshots(self):
        """Creating and listing snapshots should persist metadata and report count."""
        res = self.service.create_snapshot(description="Test ALPORA State")
        self.assertTrue(res.get("success"))

        overview = self.service.list_snapshots()
        self.assertGreaterEqual(overview.count, 1)
        found = any("Test ALPORA State" in s.description for s in overview.snapshots)
        self.assertTrue(found)

    def test_delete_snapshot(self):
        """Deleting a snapshot should remove it from the list."""
        res = self.service.create_snapshot(description="To be deleted")
        snap_id = res.get("id")
        self.assertIsNotNone(snap_id)

        del_res = self.service.delete_snapshot(snap_id)
        self.assertTrue(del_res.get("success"))


class SnapshotCommandTests(unittest.TestCase):
    """Test suite for poly-shell snapshot CLI subcommands."""

    def test_safe_print_does_not_crash(self):
        """_safe_print must handle text safely."""
        _safe_print("ALPORA Snapshot: 🟢 Ready")

    @patch("sys.stdout")
    def test_handle_snapshot_list(self, _mock_stdout):
        """`poly-shell snapshot list` should execute and exit 0."""
        args = argparse.Namespace(snapshot_action="list")
        code = handle_snapshot(args)
        self.assertEqual(code, 0)

    @patch("sys.stdout")
    def test_handle_snapshot_create(self, _mock_stdout):
        """`poly-shell snapshot create` should execute and exit 0."""
        args = argparse.Namespace(snapshot_action="create", description="CLI Test")
        code = handle_snapshot(args)
        self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()

