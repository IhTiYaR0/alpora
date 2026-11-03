"""Unit tests for ALPORA Security and System Hardening Service."""
import argparse
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, MagicMock

from poly_shell.services.security_service import SecurityService
from poly_shell.commands.security_cmd import handle_security, _safe_print


class SecurityServiceTests(unittest.TestCase):
    """Test suite for SecurityService audit and hardening recommendations."""

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.sock_path = Path(self.temp_dir.name) / "ipc.sock"
        self.service = SecurityService(socket_path=self.sock_path)

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_health_check_passes(self):
        """Health check should return True under normal conditions."""
        self.assertTrue(self.service.health_check())

    def test_sysctl_strings_contain_critical_keys(self):
        """Security and performance sysctl configurations must contain vital kernel keys."""
        sec = self.service.get_security_sysctl()
        self.assertIn("kernel.dmesg_restrict = 1", sec)
        self.assertIn("kernel.kptr_restrict = 2", sec)
        self.assertIn("kernel.unprivileged_bpf_disabled = 1", sec)
        self.assertIn("net.ipv4.tcp_syncookies = 1", sec)

        perf = self.service.get_performance_sysctl()
        self.assertIn("vm.swappiness = 10", perf)
        self.assertIn("vm.max_map_count = 1048576", perf)

    def test_hardening_commands_are_valid(self):
        """Hardening commands must include firewall, apparmor, and sysctl commands."""
        cmds = self.service.get_hardening_commands()
        self.assertIsInstance(cmds, list)
        self.assertTrue(any("ufw" in cmd for cmd in cmds))
        self.assertTrue(any("apparmor" in cmd for cmd in cmds))
        self.assertTrue(any("sysctl" in cmd for cmd in cmds))

    @patch.dict(os.environ, {"WAYLAND_DISPLAY": "wayland-1"})
    def test_audit_detects_wayland(self):
        """Audit must recognize an active Wayland session."""
        audit = self.service.audit()
        self.assertTrue(audit.wayland_session)
        self.assertGreaterEqual(audit.score, 20)

    @patch("poly_shell.services.security_service.shutil.which")
    @patch("poly_shell.adapters.base.SafeRunner.run")
    def test_audit_with_active_ufw_and_apparmor(self, mock_run, mock_which):
        """Audit score increases when UFW and AppArmor are active."""
        mock_which.return_value = "/usr/bin/ufw"
        mock_run.return_value = MagicMock(returncode=0, stdout="Status: active\n")

        with patch.object(self.service, "is_apparmor_active", return_value=True):
            with patch.dict(os.environ, {"WAYLAND_DISPLAY": "wayland-1"}):
                audit = self.service.audit()
                self.assertTrue(audit.ufw_active)
                self.assertTrue(audit.apparmor_active)
                self.assertGreaterEqual(audit.score, 50)


class SecurityCommandTests(unittest.TestCase):
    """Test suite for poly-shell security CLI command handler."""

    def test_safe_print_does_not_crash(self):
        """_safe_print should safely handle UTF-8 and emoji strings."""
        _safe_print("ALPORA Security: 🟢 Hardened")

    @patch("sys.stdout")
    def test_handle_security_status(self, _mock_stdout):
        """`poly-shell security status` should execute and exit with code 0."""
        args = argparse.Namespace(security_action="status")
        code = handle_security(args)
        self.assertEqual(code, 0)

    @patch("sys.stdout")
    def test_handle_security_harden(self, _mock_stdout):
        """`poly-shell security harden` should print hardening commands and exit 0."""
        args = argparse.Namespace(security_action="harden")
        code = handle_security(args)
        self.assertEqual(code, 0)

    @patch("sys.stdout")
    def test_handle_security_sysctl(self, _mock_stdout):
        """`poly-shell security sysctl` should output sysctl blocks and exit 0."""
        args = argparse.Namespace(security_action="sysctl")
        code = handle_security(args)
        self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()

