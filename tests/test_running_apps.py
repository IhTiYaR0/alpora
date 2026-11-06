"""ALPORA process manager helper tests; does not send signals to real processes."""
import unittest
from poly_shell.running_apps import _app_key, _safe_command, _process_matches_app, _descendant_distance


class RunningAppsHelperTests(unittest.TestCase):
    """process manager helper tests"""
    def test_desktop_id_maps_to_stable_app_key(self):
        self.assertEqual(_app_key("org.mozilla.firefox"), "orgmozillafirefox")

    def test_process_tree_distance_maps_children(self):
        processes = {
            100: {"pid": 100, "ppid": 1},
            101: {"pid": 101, "ppid": 100},
            102: {"pid": 102, "ppid": 101},
        }
        self.assertEqual(_descendant_distance(processes, 102, 100), 2)
        self.assertIsNone(_descendant_distance(processes, 100, 999))

    def test_window_class_matches_application_executable(self):
        proc = {"name": "firefox", "exe": "firefox", "argv": ["/usr/lib/firefox/firefox"]}
        self.assertTrue(_process_matches_app(proc, "org.mozilla.firefox"))

    def test_command_line_secret_values_are_redacted(self):
        command = _safe_command(["browser", "--api-token", "abc123", "--profile", "default"], "browser")
        self.assertNotIn("abc123", command)
        self.assertIn("<redacted>", command)

    def test_running_apps_cli_snapshot_handler(self):
        from poly_shell.commands.running_apps_cmd import handle_running_apps
        from argparse import Namespace
        import io
        import sys
        import json

        captured = io.StringIO()
        old_stdout = sys.stdout
        try:
            sys.stdout = captured
            ret = handle_running_apps(Namespace(action="snapshot", args=["[]"]))
            self.assertEqual(ret, 0)
            data = json.loads(captured.getvalue())
            self.assertTrue(data.get("ok"))
            self.assertIn("processes", data)
        finally:
            sys.stdout = old_stdout



if __name__ == "__main__":
    unittest.main()
