"""Stopping the shell must reload changed unit files first, without touching the real session."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, call, patch
from poly_shell import cli
from poly_shell.state import Paths


class ServiceCommandTests(unittest.TestCase):
    def calls(self,command):
        recorder=Mock()
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            with patch.object(cli.Paths,'current',return_value=Paths(root/'config',root/'state',root/'runtime')),\
                 patch.object(cli,'systemctl',recorder.systemctl),patch.object(cli,'start',recorder.start):
                cli.main([command])
        return recorder.mock_calls

    def test_restart_reloads_unit_files_before_stopping(self):
        calls=self.calls('restart')
        self.assertEqual(calls[:2],[call.systemctl('daemon-reload'),call.systemctl('stop','poly-shell.service')])
        self.assertEqual(calls[2][0],'start')

    def test_stop_reloads_unit_files_before_stopping(self):
        self.assertEqual(self.calls('stop'),[call.systemctl('daemon-reload'),call.systemctl('stop','poly-shell.service')])
