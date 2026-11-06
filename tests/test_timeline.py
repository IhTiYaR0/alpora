from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from poly_shell import themes, timeline
from poly_shell.state import Paths, ConfigError, atomic_json, read_object, update_session


class TimelineTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(); self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        self.paths = Paths(root/'config/poly-shell', root/'state', root/'runtime')
        border = patch('poly_shell.themes.runtime_border')
        self.border = border.start(); self.addCleanup(border.stop)

    def select(self):
        atomic_json(self.paths.config/'appearance.json', {'theme': 'timeline'})

    def test_six_readable_same_size_images_and_one_catalog_theme(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("PIL is required for image verification tests")
        assets = timeline.assets()
        self.assertEqual(len(assets), 6)
        sizes = []
        for item in assets:
            with Image.open(item['image']) as image:
                image.verify()
                sizes.append(image.size)
        self.assertEqual(len(set(sizes)), 1)
        self.assertEqual(sizes[0], (1672, 941))
        catalog = themes.catalog(self.paths)
        self.assertEqual(len([item for item in catalog['items'] if item['id'] == 'timeline']), 1)

    def test_saved_position_survives_new_process_and_mode_refresh(self):
        self.select()
        timeline.timeline_control(self.paths, 'set', {'minute': 460})
        for mode in ('work', 'vibe'):
            snapshot = update_session(self.paths, mode)
            self.assertEqual(snapshot['appearance']['id'], 'timeline')
            self.assertEqual(timeline.timeline_control(self.paths, 'get', {})['minute'], 460)

    def test_full_day_endpoint_wraps_to_midnight(self):
        self.select()
        timeline.timeline_control(self.paths, 'set', {'minute': 1440})
        self.assertEqual(timeline.saved_minute(self.paths), 0)

    def test_invalid_input_and_inactive_theme_do_not_overwrite_position(self):
        self.select()
        timeline.timeline_control(self.paths, 'set', {'minute': 720})
        target = self.paths.config/'timeline.json'; original = target.read_bytes()
        for value in (-1, 1441, True, '12:00', 2.5, None):
            with self.assertRaises(ConfigError): timeline.timeline_control(self.paths, 'set', {'minute': value})
        atomic_json(self.paths.config/'appearance.json', {'theme': 'moon-lake'})
        with self.assertRaises(ConfigError): timeline.timeline_control(self.paths, 'set', {'minute': 120})
        self.assertEqual(target.read_bytes(), original)

    def test_failed_write_and_corrupt_preferences_preserve_last_file(self):
        self.select()
        timeline.timeline_control(self.paths, 'set', {'minute': 100})
        target = self.paths.config/'timeline.json'; original = target.read_bytes()
        with patch('poly_shell.state.os.replace', side_effect=OSError('disk full')):
            with self.assertRaises((OSError, ConfigError)): timeline.timeline_control(self.paths, 'set', {'minute': 300})
        self.assertEqual(target.read_bytes(), original)
        target.write_text('{corrupt')
        with self.assertRaises(ConfigError): timeline.timeline_control(self.paths, 'set', {'minute': 300})
        self.assertEqual(target.read_text(), '{corrupt')

    def test_theme_apply_and_switch_away_keep_timeline_preference(self):
        with patch('poly_shell.themes.runtime_border'), patch('poly_shell.desktop._wallpaper'), patch('poly_shell.themes.subprocess.run'):
            themes.apply_theme(self.paths, 'timeline')
            self.assertEqual(read_object(self.paths.session)['appearance']['id'], 'timeline')
            timeline.timeline_control(self.paths, 'set', {'minute': 1000})
            themes.apply_theme(self.paths, 'alpine')
            self.assertNotEqual(read_object(self.paths.session)['appearance']['id'], 'timeline')
            themes.apply_theme(self.paths, 'timeline')
            self.assertEqual(timeline.saved_minute(self.paths), 1000)

    def test_missing_assets_reject_theme_before_publication(self):
        update_session(self.paths)
        before = self.paths.session.read_bytes()
        with patch('poly_shell.timeline.assets', side_effect=ConfigError('missing image')):
            with self.assertRaises(ConfigError): themes.apply_theme(self.paths, 'timeline')
        self.assertEqual(self.paths.session.read_bytes(), before)

    def test_fallback_takeover_requires_timeline_and_empty_payload(self):
        with patch('poly_shell.timeline.release_fallback') as release:
            self.assertFalse(timeline.timeline_control(self.paths, 'ready', {})['presented'])
            release.assert_not_called()
            self.select()
            self.assertTrue(timeline.timeline_control(self.paths, 'ready', {})['presented'])
            release.assert_called_once()
            with self.assertRaises(ConfigError): timeline.timeline_control(self.paths, 'ready', {'anything': 1})

    def test_takeover_only_stops_the_owned_timeline_fallback(self):
        expected = str(timeline.ROOT/'assets/wallpapers/timeline/sunset.png')
        with patch('poly_shell.timeline.subprocess.run') as run, patch('poly_shell.timeline.Path.read_bytes') as read, patch('poly_shell.timeline.os.kill') as kill:
            run.return_value.stdout = '123 456'
            read.side_effect = [f'/usr/bin/swaybg\0-i\0{expected}\0'.encode(), b'/usr/bin/swaybg\0-i\0/another/user-image.png\0']
            timeline.release_fallback()
            kill.assert_called_once_with(123, timeline.signal.SIGTERM)

    def test_time_updates_system_palette_and_survives_mode_refresh(self):
        self.select()
        urls = []
        for minute in (0, 780, 1110):
            timeline.timeline_control(self.paths, 'set', {'minute': minute})
            wanted = timeline.palette_for(minute)
            snapshot = read_object(self.paths.session)
            self.assertEqual(snapshot['appearance']['palette'], wanted)
            urls.append(snapshot['appearance']['ridge'])
            self.assertEqual(read_object(self.paths.config/'appearance.json')['palette'], wanted)
            self.assertIn(wanted['accent'][1:], (self.paths.config.parent/'hypr/poly-shell-theme.lua').read_text())
            self.assertIn(wanted['accent'], (self.paths.state/'mako-theme.conf').read_text())
            for mode in ('work', 'vibe'):
                self.assertEqual(update_session(self.paths, mode)['appearance']['palette'], wanted)
        self.assertEqual(len(set(urls)), 3)

    def test_palette_publication_failure_restores_time_and_all_generated_files(self):
        self.select()
        timeline.timeline_control(self.paths, 'set', {'minute': 0})
        before = {p: p.read_bytes() for folder in (self.paths.config.parent, self.paths.state) for p in folder.rglob('*') if p.is_file()}
        original = themes.atomic_text
        failed = [False]
        def fail_once(path, text):
            if path == self.paths.session and not failed[0]:
                failed[0] = True; raise OSError('publication failed')
            original(path, text)
        with patch.object(themes, 'atomic_text', side_effect=fail_once):
            with self.assertRaises(ConfigError): timeline.timeline_control(self.paths, 'set', {'minute': 780})
        after = {p: p.read_bytes() for folder in (self.paths.config.parent, self.paths.state) for p in folder.rglob('*') if p.is_file()}
        self.assertEqual(after, before)
        self.assertEqual(self.border.call_args.args[0], timeline.palette_for(0))

    def test_automatic_colors_switch_is_respected(self):
        self.select()
        original = timeline.palette_for(1110)
        atomic_json(self.paths.config/'appearance.json', {'theme': 'timeline', 'palette': original, 'colorsFromWallpaper': False})
        timeline.timeline_control(self.paths, 'set', {'minute': 0})
        self.assertEqual(update_session(self.paths)['appearance']['palette'], original)
        self.border.assert_not_called()

    def test_timeline_sync_clock(self):
        self.select()
        result = timeline.timeline_control(self.paths, 'sync-clock', {})
        self.assertTrue(result['synced'])
        self.assertTrue(result['saved'])
        self.assertIsInstance(result['minute'], int)
        self.assertTrue(0 <= result['minute'] <= 1440)


if __name__ == '__main__': unittest.main()
