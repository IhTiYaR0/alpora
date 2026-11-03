"""Unit tests for ALPORA Application Privacy and Sandboxing Service."""
import argparse
import unittest
from unittest.mock import patch

from poly_shell.services.privacy_service import PrivacyService
from poly_shell.commands.privacy_cmd import handle_privacy, _safe_print


class PrivacyServiceTests(unittest.TestCase):
    """Test suite for PrivacyService audit and permission management."""

    def setUp(self):
        self.service = PrivacyService()

    def test_health_check(self):
        """Privacy health check should query successfully."""
        self.assertTrue(self.service.health_check())

    def test_audit_returns_apps(self):
        """Audit should report applications list and isolation stats."""
        report = self.service.audit()
        self.assertGreater(report.total_apps, 0)
        self.assertIsInstance(report.apps, list)
        self.assertEqual(report.total_apps, report.isolated_apps + report.exposed_apps)

    def test_isolate_app(self):
        """Isolating an application should succeed."""
        res = self.service.isolate_app("com.discordapp.Discord")
        self.assertTrue(res.get("success"))

    def test_set_permission(self):
        """Toggling permission should return updated status."""
        res = self.service.set_permission("com.discordapp.Discord", "mic", False)
        self.assertTrue(res.get("success"))
        self.assertFalse(res.get("allowed"))


class PrivacyCommandTests(unittest.TestCase):
    """Test suite for poly-shell privacy CLI subcommands."""

    def test_safe_print_does_not_crash(self):
        """_safe_print must handle text safely."""
        _safe_print("ALPORA Privacy: 🟢 Isolated")

    @patch("sys.stdout")
    def test_handle_privacy_status(self, _mock_stdout):
        """`poly-shell privacy status` should execute and exit 0."""
        args = argparse.Namespace(privacy_action="status")
        code = handle_privacy(args)
        self.assertEqual(code, 0)

    @patch("sys.stdout")
    def test_handle_privacy_isolate(self, _mock_stdout):
        """`poly-shell privacy isolate` should execute and exit 0."""
        args = argparse.Namespace(privacy_action="isolate", app="com.discordapp.Discord")
        code = handle_privacy(args)
        self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()

