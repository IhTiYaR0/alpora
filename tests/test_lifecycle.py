"""Exercise the supervisor with a real child process, without touching Wayland."""
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipIf(os.name == 'nt', 'Supervisor lifecycle tests require POSIX execution')
class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        fake = self.directory / "quickshell"
        fake.write_text('''#!/usr/bin/python3
import os, signal, sys
from pathlib import Path
if "--version" in sys.argv:
    print("Quickshell fake test child")
    sys.exit(0)
if "FAKE_CHILD_EXIT" in os.environ:
    sys.exit(int(os.environ["FAKE_CHILD_EXIT"]))
Path(os.environ["POLY_SHELL_READY"]).write_text("ready")
signal.pause()
''')
        fake.chmod(0o755)
        # The supervisor may refresh notification styling; never reload the
        # developer's real notification daemon from this isolated test.
        fake_mako = self.directory / "makoctl"
        fake_mako.write_text('#!/bin/sh\nexit 0\n')
        fake_mako.chmod(0o755)
        self.environment = dict(os.environ, PATH=f"{self.directory}:/usr/bin:/bin",
                                WAYLAND_DISPLAY="test-no-real-display",
                                XDG_CONFIG_HOME=str(self.directory / "config"),
                                XDG_STATE_HOME=str(self.directory / "state"),
                                XDG_RUNTIME_DIR=str(self.directory / "runtime"))
        self.environment.pop("HYPRLAND_INSTANCE_SIGNATURE", None)

    def test_requested_stop_is_success_and_cleans_ready_marker(self):
        child = subprocess.Popen([str(ROOT / "bin/poly-shell"), "run"], env=self.environment,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        ready = self.directory / "runtime/poly-shell/ready"
        try:
            for _ in range(100):
                if ready.exists() or child.poll() is not None:
                    break
                time.sleep(.02)
            self.assertTrue(ready.exists(), "Fake shell never became ready")
            child.terminate()
            _, errors = child.communicate(timeout=5)
            self.assertEqual(child.returncode, 0, errors)
            self.assertFalse(ready.exists())
        finally:
            if child.poll() is None:
                child.kill()
                child.communicate()

    def test_unexpected_child_failure_is_propagated(self):
        environment = dict(self.environment, FAKE_CHILD_EXIT="42")
        result = subprocess.run([str(ROOT / "bin/poly-shell"), "run"], env=environment,
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 42, result.stderr)


if __name__ == "__main__":
    unittest.main()
