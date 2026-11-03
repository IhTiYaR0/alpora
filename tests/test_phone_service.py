"""Unit tests for ALPORA Phone Ecosystem and KDE Connect integration."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import MagicMock, patch

from poly_shell.adapters.base import SafeRunner
from poly_shell.commands.phone_cmd import handle_phone
from poly_shell.core.state import Paths
from poly_shell.services.phone_service import PhoneService


class PhoneServiceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.paths = Paths(root / "config", root / "state", root / "runtime")
        self.service = PhoneService(paths=self.paths)

    @patch.object(SafeRunner, "is_available")
    def test_health_check(self, mock_avail):
        mock_avail.side_effect = lambda tool: tool == "kdeconnect-cli"
        self.assertTrue(self.service.health_check())

        mock_avail.side_effect = lambda tool: False
        self.assertFalse(self.service.health_check())

    @patch.object(SafeRunner, "run")
    @patch.object(SafeRunner, "is_available", return_value=True)
    def test_get_devices_parsing(self, mock_avail, mock_run):
        mock_output = (
            "- Galaxy S24 Ultra: dev_s24 (paired and reachable)\n"
            "- iPhone 15 Pro: dev_iphone (paired)\n"
        )
        mock_run.return_value = MagicMock(returncode=0, stdout=mock_output, stderr="")

        devices = self.service.get_devices(force_refresh=True)
        self.assertEqual(len(devices), 2)

        s24 = devices[0]
        self.assertEqual(s24.id, "dev_s24")
        self.assertEqual(s24.name, "Galaxy S24 Ultra")
        self.assertTrue(s24.is_reachable)
        self.assertTrue(s24.is_trusted)

        iphone = devices[1]
        self.assertEqual(iphone.id, "dev_iphone")
        self.assertEqual(iphone.name, "iPhone 15 Pro")
        self.assertFalse(iphone.is_reachable)

        active = self.service.get_active_device()
        self.assertIsNotNone(active)
        self.assertEqual(active.id, "dev_s24")

    @patch.object(SafeRunner, "run")
    @patch.object(SafeRunner, "is_available", return_value=True)
    def test_ring_and_ping(self, mock_avail, mock_run):
        mock_output = "- Pixel 8: dev_pixel (reachable)\n"
        mock_run.return_value = MagicMock(returncode=0, stdout=mock_output, stderr="")

        # Test ring
        success_ring = self.service.ring_device("dev_pixel")
        self.assertTrue(success_ring)

        # Test ping
        success_ping = self.service.send_ping("dev_pixel", message="Hello Phone")
        self.assertTrue(success_ping)

    @patch.object(SafeRunner, "run")
    @patch.object(SafeRunner, "is_available", return_value=True)
    def test_clipboard_and_file_sharing(self, mock_avail, mock_run):
        mock_output = "- Pixel 8: dev_pixel (reachable)\n"
        mock_run.return_value = MagicMock(returncode=0, stdout=mock_output, stderr="")

        # Test clipboard sharing with explicit text
        success_clip = self.service.share_clipboard("Code snippet 123", "dev_pixel")
        self.assertTrue(success_clip)

        # Test send file with existing temporary file
        temp_file = Path(self.tmp.name) / "test_image.png"
        temp_file.write_text("dummy binary content")
        success_file = self.service.send_file(temp_file, "dev_pixel")
        self.assertTrue(success_file)

    @patch.object(SafeRunner, "run")
    @patch.object(SafeRunner, "is_available", return_value=True)
    def test_cli_handlers(self, mock_avail, mock_run):
        mock_output = "- Pixel 8: dev_pixel (reachable)\n"
        mock_run.return_value = MagicMock(returncode=0, stdout=mock_output, stderr="")

        # CLI list
        args_list = MagicMock(phone_action="list", json=False)
        self.assertEqual(handle_phone(args_list), 0)

        # CLI status
        args_status = MagicMock(phone_action="status", json=False)
        self.assertEqual(handle_phone(args_status), 0)

        # CLI ring
        args_ring = MagicMock(phone_action="ring", device_id="dev_pixel")
        self.assertEqual(handle_phone(args_ring), 0)


if __name__ == "__main__":
    unittest.main()
