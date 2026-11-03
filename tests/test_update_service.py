"""Unit tests for ALPORA OS Update Center and OTA patch service."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import MagicMock, patch

from poly_shell.commands.update_cmd import handle_update
from poly_shell.core.state import Paths
from poly_shell.services.update_service import UpdateService, parse_semver


class UpdateServiceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.paths = Paths(root / "config", root / "state", root / "runtime")
        self.service = UpdateService(paths=self.paths)

    def test_semver_parsing(self):
        self.assertEqual(parse_semver("v1.0.0"), (1, 0, 0))
        self.assertEqual(parse_semver("1.2.3"), (1, 2, 3))
        self.assertTrue(parse_semver("v1.1.0") > parse_semver("v1.0.0"))
        self.assertTrue(parse_semver("2.0.0") > parse_semver("1.9.9"))

    @patch("urllib.request.urlopen")
    def test_check_update_with_newer_release(self, mock_urlopen):
        mock_response = MagicMock()
        mock_response.status = 200
        mock_response.read.return_value = b"""{
            "tag_name": "v1.2.0",
            "name": "ALPORA OS v1.2.0 Release",
            "body": "- Added Game Mode\\n- Added Phone Connect",
            "published_at": "2026-11-03T12:00:00Z",
            "html_url": "https://github.com/pnam-it309/alpora/releases/tag/v1.2.0",
            "assets": [
                {"name": "alpora-archlinux-2026.11.iso", "browser_download_url": "https://example.com/alpora.iso"}
            ]
        }"""
        mock_urlopen.return_value.__enter__.return_value = mock_response

        # Test with version 1.0.0
        with patch.object(self.service, "get_current_version", return_value="1.0.0"):
            res = self.service.check_update(force=True)
            self.assertTrue(res["has_update"])
            self.assertEqual(res["latest_version"], "v1.2.0")
            self.assertEqual(res["iso_download_url"], "https://example.com/alpora.iso")

    @patch("urllib.request.urlopen")
    def test_check_update_up_to_date(self, mock_urlopen):
        mock_response = MagicMock()
        mock_response.status = 200
        mock_response.read.return_value = b"""{
            "tag_name": "v1.0.0",
            "name": "ALPORA OS v1.0.0",
            "body": "Initial Release"
        }"""
        mock_urlopen.return_value.__enter__.return_value = mock_response

        with patch.object(self.service, "get_current_version", return_value="1.0.0"):
            res = self.service.check_update(force=True)
            self.assertFalse(res["has_update"])

    @patch("subprocess.run")
    def test_apply_update_git_failure_handling(self, mock_run):
        mock_run.return_value = MagicMock(returncode=1, stderr="Connection error")
        res = self.service.apply_update()
        self.assertFalse(res["success"])

    @patch.object(UpdateService, "check_update")
    def test_cli_update_handlers(self, mock_check):
        mock_check.return_value = {
            "has_update": False,
            "current_version": "1.0.0",
            "latest_version": "1.0.0",
            "release_title": "Up to date",
            "release_notes": "",
            "published_at": "",
            "html_url": "",
            "iso_download_url": None,
        }

        # Test CLI check
        args_check = MagicMock(update_action="check", json=False)
        self.assertEqual(handle_update(args_check), 0)

        # Test CLI status
        args_status = MagicMock(update_action="status")
        self.assertEqual(handle_update(args_status), 0)


if __name__ == "__main__":
    unittest.main()
