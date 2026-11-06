"""Exercise the real installer under a clean HOME, never the current session."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]


@unittest.skipIf(os.name == 'nt', 'Installer tests require POSIX execution')
class CleanInstallationTests(unittest.TestCase):
    def setUp(self):
        temporary=tempfile.TemporaryDirectory(prefix='poly clean install ')
        self.addCleanup(temporary.cleanup)
        self.home=Path(temporary.name)
        self.env=dict(os.environ,HOME=str(self.home),XDG_CONFIG_HOME=str(self.home/'config'),
                      XDG_STATE_HOME=str(self.home/'state'),XDG_DATA_HOME=str(self.home/'data'),
                      XDG_RUNTIME_DIR=str(self.home/'runtime'))
        for name in ('HYPRLAND_INSTANCE_SIGNATURE','WAYLAND_DISPLAY','DISPLAY'):self.env.pop(name,None)

    def install(self):
        return subprocess.run([str(ROOT/'bin/poly-shell'),'install'],env=self.env,capture_output=True,text=True,timeout=8)

    def test_first_install_and_repeat_preserve_unrelated_files_under_spaced_home(self):
        sentinel=self.home/'config/unrelated';sentinel.parent.mkdir(parents=True);sentinel.write_text('keep me')
        before=None
        for _ in range(2):
            result=self.install();self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual((self.home/'.local/bin/poly-shell').resolve(),ROOT/'bin/poly-shell')
            self.assertEqual((self.home/'.local/bin/alpora-fetch').resolve(),ROOT/'bin/alpora-fetch')
            self.assertEqual((self.home/'config/quickshell/poly-shell').resolve(),ROOT/'shell')
            unit=(self.home/'config/systemd/user/poly-shell.service').read_text()
            self.assertIn('ExecStart="'+str(self.home/'.local/bin/poly-shell')+'" run',unit)
            desktop=(self.home/'data/applications/poly-shell-settings.desktop').read_text()
            self.assertIn(str(ROOT/'bin/poly-shell'),desktop)
            self.assertEqual(sentinel.read_text(),'keep me')
            card=subprocess.run([str(self.home/'.local/bin/alpora-fetch'),'--once'],
                                env=self.env,cwd=self.home,capture_output=True,text=True,timeout=3)
            self.assertEqual(card.returncode,0,card.stderr)
            self.assertIn('A L P O R A',card.stdout)
            if before is not None:self.assertEqual(unit,before)
            before=unit

    def test_existing_unrelated_launcher_is_refused_and_preserved(self):
        for name in ('poly-shell','alpora-fetch'):
            with self.subTest(name=name):
                target=self.home/'.local/bin'/name
                target.parent.mkdir(parents=True,exist_ok=True);target.write_text('personal launcher')
                result=self.install()
                self.assertNotEqual(result.returncode,0)
                self.assertIn('Refusing to overwrite',result.stderr)
                self.assertEqual(target.read_text(),'personal launcher')
                self.assertFalse((self.home/'config/systemd/user/poly-shell.service').exists())
                target.unlink()

    def test_settings_launcher_conflict_is_detected_before_any_installation_writes(self):
        target=self.home/'data/applications/poly-shell-settings.desktop'
        target.parent.mkdir(parents=True);target.write_text('personal desktop entry')
        result=self.install()
        self.assertNotEqual(result.returncode,0)
        self.assertIn('Existing settings launcher differs',result.stderr)
        self.assertEqual(target.read_text(),'personal desktop entry')
        self.assertFalse((self.home/'.local/bin').exists())
        self.assertFalse((self.home/'config/systemd').exists())
        self.assertFalse((self.home/'config/quickshell').exists())
