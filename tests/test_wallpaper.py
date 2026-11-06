from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import Mock, patch

from poly_shell.desktop import wallpaper
from poly_shell.state import ConfigError, Paths, ROOT, atomic_json, read_object


class WallpaperTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        self.paths = Paths(root / 'config', root / 'state', root / 'runtime')
        self.image = root / 'my wallpaper.png'
        self.image.write_bytes(b'test')
        self.active = True
        self.launch_failure = False
        self.calls = []

        def command(args, **_):
            self.calls.append(args)
            if args[0] == 'systemd-run' and self.launch_failure:
                raise ConfigError('service launch failed')
            if args[:3] == ['systemctl', '--user', 'is-active']:
                return SimpleNamespace(stdout='', returncode=0 if self.active else 1)
            return SimpleNamespace(stdout='123\n' if args[0] == 'pgrep' else '', returncode=0)

        for target, value in [
            ('poly_shell.desktop.command', Mock(side_effect=command)),
            ('poly_shell.desktop.subprocess.Popen', Mock(side_effect=AssertionError('Renderer must not inherit caller cgroup'))),
            ('poly_shell.desktop.os.kill', Mock()),
            ('poly_shell.desktop.time.sleep', Mock()),
        ]:
            patcher = patch(target, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        from poly_shell import desktop
        self.desktop = desktop

    def test_custom_image_runs_in_independent_user_service_and_is_remembered(self):
        wallpaper(self.paths, str(self.image))
        args = next(c for c in self.calls if c[0] == 'systemd-run')
        self.assertEqual(args[-5:], ['swaybg', '-i', str(self.image), '-m', 'fill'])
        self.assertIn('--user', args)
        self.assertIn('--collect', args)
        self.assertIn('--service-type=exec', args)
        self.assertTrue(any(arg.startswith('--unit=poly-shell-wallpaper-') for arg in args))
        self.assertNotIn('--scope', args)
        self.assertEqual(read_object(self.paths.config / 'wallpaper.json')['image'], str(self.image))
        self.desktop.os.kill.assert_called_once()
        self.desktop.subprocess.Popen.assert_not_called()

    def test_startup_reuses_saved_image_and_reset_restores_alpine(self):
        atomic_json(self.paths.config / 'wallpaper.json', {'image': str(self.image)})
        wallpaper(self.paths)
        self.assertEqual(next(c for c in self.calls if c[0] == 'systemd-run')[-3], str(self.image))
        wallpaper(self.paths, reset=True)
        self.assertEqual(read_object(self.paths.config / 'wallpaper.json')['image'], str(ROOT / 'assets/wallpapers/alpine-dawn.png'))
        units = [next(arg for arg in c if arg.startswith('--unit=')) for c in self.calls if c[0] == 'systemd-run']
        self.assertNotEqual(*units)

    def test_failed_renderer_keeps_old_process_and_preference(self):
        atomic_json(self.paths.config / 'wallpaper.json', {'image': 'previous.png'})
        self.active = False
        with self.assertRaises(ConfigError):
            wallpaper(self.paths, str(self.image))
        self.desktop.os.kill.assert_not_called()
        self.assertTrue(any(c[:3] == ['systemctl', '--user', 'stop'] for c in self.calls))
        self.assertEqual(read_object(self.paths.config / 'wallpaper.json')['image'], 'previous.png')

    def test_failed_save_stops_new_service_and_keeps_old_one(self):
        with patch('poly_shell.desktop.atomic_json', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                wallpaper(self.paths, str(self.image))
        unit = next(arg.removeprefix('--unit=') for c in self.calls if c[0] == 'systemd-run' for arg in c if arg.startswith('--unit='))
        self.assertIn(['systemctl', '--user', 'stop', unit], self.calls)
        self.desktop.os.kill.assert_not_called()

    def test_launch_failure_does_not_replace_preferences_or_stop_old_renderer(self):
        atomic_json(self.paths.config / 'wallpaper.json', {'image': 'previous.png'})
        self.launch_failure = True
        with self.assertRaises(ConfigError):
            wallpaper(self.paths, str(self.image))
        self.desktop.os.kill.assert_not_called()
        self.assertEqual(read_object(self.paths.config / 'wallpaper.json')['image'], 'previous.png')

    def test_invalid_or_missing_image_never_starts_service(self):
        for image in (str(self.image.parent / 'missing.png'), str(self.image.parent / 'script.sh')):
            with self.subTest(image=image), self.assertRaises(ConfigError):
                wallpaper(self.paths, image)
        self.assertFalse(self.calls)

    def test_drop_origin_is_relative_top_left_and_renderer_survives_restart(self):
        with patch('poly_shell.desktop.shutil.which', side_effect=lambda name: '/bin/' + name):
            self.desktop._wallpaper(self.paths, str(self.image), transition={'x': 0.25, 'y': 0.8})
            args = next(c for c in self.calls if len(c) > 1 and c[1] == 'img')
            self.assertEqual(args[args.index('--transition-pos') + 1], '0.250000,0.800000')
            self.assertIn('--invert-y', args)
            self.assertEqual(args[args.index('--transition-type') + 1], 'grow')
            self.assertEqual(read_object(self.paths.config / 'wallpaper.json')['renderer'], 'animated')
            self.calls.clear()
            wallpaper(self.paths)
            self.assertFalse(any(c[0] == 'systemd-run' for c in self.calls))
            self.assertEqual(len([c for c in self.calls if c[1:2] == ['img']]), 1)
            self.assertEqual(next(c for c in self.calls if c[1:2] == ['img'])[-1], 'none')

    def test_invalid_drop_never_starts_renderer(self):
        for origin in ({'x': -0.1, 'y': 0}, {'x': 1, 'y': float('nan')},
                       {'x': True, 'y': 0}, {'x': 0}, '0,0'):
            with self.subTest(origin=origin), self.assertRaises(ConfigError):
                self.desktop._wallpaper(self.paths, str(self.image), transition=origin)
        self.assertFalse(self.calls)

    def test_reduced_motion_disables_drop_animation(self):
        with patch('poly_shell.desktop.shutil.which', side_effect=lambda name: '/bin/' + name), \
             patch('poly_shell.state.settings_for', return_value={'reducedMotion': True}):
            self.desktop._wallpaper(self.paths, str(self.image), transition={'x': 0, 'y': 1})
        args = next(c for c in self.calls if c[1:2] == ['img'])
        self.assertNotIn('--transition-pos', args)
        self.assertEqual(args[-1], 'none')

    def test_fade_crossfade_transition_uses_fast_duration(self):
        with patch('poly_shell.desktop.shutil.which', side_effect=lambda name: '/bin/' + name):
            self.desktop._wallpaper(self.paths, str(self.image), transition='fade')
        args = next(c for c in self.calls if c[1:2] == ['img'])
        self.assertEqual(args[args.index('--transition-type') + 1], 'fade')
        self.assertEqual(args[args.index('--transition-duration') + 1], '0.25')

    def test_transition_falls_back_to_static_wallpaper_when_awww_missing(self):
        # When awww and swww are not available, transition should fall back gracefully to swaybg
        with patch('poly_shell.desktop.shutil.which', return_value=None):
            self.desktop._wallpaper(self.paths, str(self.image), transition='fade')
        args = next(c for c in self.calls if c[0] == 'systemd-run')
        self.assertEqual(args[-5:], ['swaybg', '-i', str(self.image), '-m', 'fill'])
        self.assertEqual(read_object(self.paths.config / 'wallpaper.json')['image'], str(self.image))



if __name__ == '__main__':
    unittest.main()
