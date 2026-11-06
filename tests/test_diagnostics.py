import json
import tarfile
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from poly_shell.cli import main
from poly_shell.diagnostics import collect_diagnostic_bundle, get_os_release, sanitize_dict


class TestDiagnostics(unittest.TestCase):
    def test_sanitize_dict(self):
        raw = {
            "theme": "alpine-dawn",
            "wifi_password": "supersecretpassword",
            "nested": {
                "auth_token": "xyz123",
                "normal": "value",
            },
        }
        clean = sanitize_dict(raw)
        self.assertEqual(clean["theme"], "alpine-dawn")
        self.assertEqual(clean["wifi_password"], "[REDACTED]")
        self.assertEqual(clean["nested"]["auth_token"], "[REDACTED]")
        self.assertEqual(clean["nested"]["normal"], "value")

    def test_get_os_release(self):
        release = get_os_release()
        self.assertIsInstance(release, dict)
        self.assertTrue(len(release) > 0)

    def test_collect_diagnostic_bundle(self):
        with tempfile.TemporaryDirectory() as tmp_str:
            tmp = Path(tmp_str)
            session_file = tmp / "session.json"
            session_file.write_text(json.dumps({"mode": "vibe", "secret_key": "123"}), encoding="utf-8")

            paths = SimpleNamespace(session=session_file)
            archive = collect_diagnostic_bundle(paths, output_dir=tmp)

            self.assertTrue(archive.exists())
            self.assertTrue(str(archive).endswith(".tar.gz"))

            with tarfile.open(archive, "r:gz") as tar:
                names = tar.getnames()
                self.assertTrue(any("system_info.json" in n for n in names))
                self.assertTrue(any("inventory.json" in n for n in names))
                self.assertTrue(any("session_state.json" in n for n in names))
                self.assertTrue(any("poly-shell.log" in n for n in names))

                # Verify session state was sanitized
                session_member = [m for m in tar.getmembers() if "session_state.json" in m.name][0]
                extracted = tar.extractfile(session_member)
                self.assertIsNotNone(extracted)
                content = json.loads(extracted.read().decode("utf-8"))
                self.assertEqual(content["mode"], "vibe")
                self.assertEqual(content["secret_key"], "[REDACTED]")

    def test_cli_doctor_bundle(self):
        with tempfile.TemporaryDirectory() as tmp_str:
            ret = main(["doctor", "--bundle", "--output", tmp_str])
            self.assertEqual(ret, 0)
            archives = list(Path(tmp_str).glob("*.tar.gz"))
            self.assertEqual(len(archives), 1)


if __name__ == "__main__":
    unittest.main()
