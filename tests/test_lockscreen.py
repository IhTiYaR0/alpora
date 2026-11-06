"""Theme generation and real Hyprlock parsing, never locking the live desktop."""
from datetime import datetime
from pathlib import Path
try:
    import resource
except ImportError:
    resource = None
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from poly_shell.lockscreen import lock_date, lock_style, sync_lockscreen
from poly_shell.state import ConfigError, Paths, ROOT, update_session


class LockscreenTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        self.paths = Paths(root / 'config', root / 'state', root / 'runtime')
        self.snapshot = update_session(self.paths)

    def test_russian_date_does_not_require_installed_locale(self):
        self.assertEqual(lock_date(datetime(2026, 10, 19)), 'понедельник · 19 октября')
        self.assertEqual(lock_date(datetime(2026, 1, 1)), 'четверг · 1 января')

    def test_modes_update_colors_without_changing_theme(self):
        work = lock_style(self.snapshot)
        vibe = update_session(self.paths, 'vibe')
        self.assertNotEqual(work, lock_style(vibe))
        self.assertEqual(self.snapshot['appearance'], vibe['appearance'])
        self.assertIn('alpine-dawn.png', work)
        self.assertNotIn('auth:', work)
        self.snapshot['settings']['reducedMotion'] = True
        self.assertIn('$lockMotion = false', lock_style(self.snapshot))

    def test_theme_values_cannot_inject_locker_configuration(self):
        for bad in ('Noto\nauth:pam:enabled = false', 'Noto $USER', 'Noto # ignored'):
            self.snapshot['settings']['bar']['fontFamily'] = bad
            with self.assertRaises(ConfigError):
                lock_style(self.snapshot)
        self.snapshot['settings']['bar']['fontFamily'] = 'Noto Sans'
        for bad in ('../../../etc/passwd', '/etc/passwd', 'wallpapers/missing.png'):
            self.snapshot['appearance']['wallpaper'] = bad
            with self.assertRaises(ConfigError):
                lock_style(self.snapshot)

    def test_atomic_write_preserves_last_good_theme_and_cleans_temporary(self):
        sync_lockscreen(self.paths)
        target = self.paths.state / 'hyprlock-theme.conf'
        before = target.read_bytes()
        update_session(self.paths, 'vibe')
        with patch('poly_shell.lockscreen.os.replace', side_effect=OSError('disk failure')):
            with self.assertRaises(OSError):
                sync_lockscreen(self.paths)
        self.assertEqual(target.read_bytes(), before)
        self.assertEqual(sorted(path.name for path in self.paths.state.iterdir()),
                         ['hyprlock-theme.conf', 'session.json', 'state.lock'])

    @unittest.skipUnless(shutil.which('hyprlock'), 'Hyprlock is not installed')
    def test_native_parser_accepts_theme_without_connecting_to_real_display(self):
        sync_lockscreen(self.paths)
        config = self.paths.state / 'validate.conf'
        config.write_text(f'source = {self.paths.state / "hyprlock-theme.conf"}\n'
                          f'source = {ROOT / "assets/lockscreen/layout.conf"}\n')
        def no_core_dump():
            if resource:
                resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        # An absolute nonexistent socket path cannot resolve to the user's display.
        kwargs = {"preexec_fn": no_core_dump} if resource else {}
        result = subprocess.run(['hyprlock', '--config', str(config), '--display',
                                 str(self.paths.state / 'nonexistent-wayland-socket')],
                                capture_output=True, text=True, timeout=5, **kwargs)
        output = result.stdout + result.stderr
        self.assertNotIn('Config has errors', output)
        self.assertNotIn('Config threw', output)
        self.assertIn("Couldn't connect to a wayland compositor", output)


if __name__ == '__main__':
    unittest.main()
