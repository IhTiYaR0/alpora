"""Theme persistence, palette extraction, mode independence and rollback."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from poly_shell import themes
from poly_shell.state import ConfigError, Paths, atomic_json, read_object, update_session


class ThemeTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(); self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        self.paths = Paths(root / 'config/poly-shell', root / 'state', root / 'runtime')
        update_session(self.paths)
        for target in ('poly_shell.themes.runtime_border', 'poly_shell.desktop._wallpaper', 'poly_shell.themes.subprocess.run'):
            patcher = patch(target)
            mock = patcher.start(); self.addCleanup(patcher.stop)
            if target.endswith('runtime_border'): self.border = mock
            if target.endswith('_wallpaper'): self.wallpaper = mock

    def test_builtin_themes_have_distinct_complete_palettes(self):
        items = themes.catalog(self.paths)['items']
        self.assertEqual(len(items), 7)
        self.assertEqual(len({i['palette']['accent'] for i in items}), 7)
        for item in items:
            self.assertTrue(Path(item['image']).is_file())
            self.assertEqual(set(themes.validate_palette(item['palette'])), set(themes.KEYS))

    def test_palette_wallpaper_and_mode_survive_refresh_and_mode_switches(self):
        update_session(self.paths, 'vibe')
        atomic_json(self.paths.config / 'visual.json', {'schemaVersion': 1, 'values': {'windowRadius': 27}})
        themes.apply_theme(self.paths, 'moon-lake')
        snapshot = read_object(self.paths.session)
        self.assertEqual(snapshot['mode'], 'vibe')
        self.assertEqual(snapshot['visual']['windowRadius'], 27)
        wanted = themes.load_theme(self.paths, 'moon-lake')['palette']
        for mode in ('work', 'vibe'):
            snapshot = update_session(self.paths, mode)
            self.assertEqual(snapshot['appearance']['palette'], wanted)
            self.assertIn('moon-lake.png', snapshot['appearance']['wallpaper'])
            self.assertEqual(snapshot['visual']['windowRadius'], 27)
        self.assertIn(wanted['accent'], (self.paths.state / 'mako-theme.conf').read_text(encoding="utf-8"))
        self.assertIn(wanted['accent'][1:], (self.paths.state / 'hyprlock-theme.conf').read_text(encoding="utf-8"))

    def test_disabling_automatic_colors_changes_only_wallpaper(self):
        themes.apply_theme(self.paths, 'forest-mist')
        before = read_object(self.paths.session)['appearance']['palette']
        themes.apply_theme(self.paths, 'warm-desert', False)
        after = read_object(self.paths.session)['appearance']
        self.assertEqual(after['palette'], before)
        self.assertIn('warm-desert.png', after['wallpaper'])
        self.assertFalse(after['colorsFromWallpaper'])

    def test_invalid_selection_is_rejected_before_any_change(self):
        before = self.paths.session.read_bytes()
        for bad in ('../etc/passwd', 'missing', 22, 'moon-lake\ncode'):
            with self.subTest(id=bad), self.assertRaises(ConfigError):
                themes.apply_theme(self.paths, bad)
        with self.assertRaises(ConfigError): themes.apply_theme(self.paths, 'moon-lake', 1)
        self.assertEqual(self.paths.session.read_bytes(), before)
        self.wallpaper.assert_not_called(); self.border.assert_not_called()

    def test_drop_coordinates_reach_renderer_without_changing_mode_or_geometry(self):
        update_session(self.paths, 'vibe')
        origin = {'x': 0.2, 'y': 0.85}
        themes.theme_control(self.paths, 'apply', {'id': 'forest-mist', 'transition': origin})
        self.assertEqual(self.wallpaper.call_args.kwargs['transition'], origin)
        self.assertEqual(read_object(self.paths.session)['mode'], 'vibe')
        self.assertNotIn('transition', read_object(self.paths.config / 'appearance.json'))

    def test_invalid_drop_is_rejected_before_theme_files_change(self):
        before = self.paths.session.read_bytes()
        with self.assertRaises(ConfigError):
            themes.apply_theme(self.paths, 'moon-lake', transition={'x': 2, 'y': 0.5})
        self.assertEqual(self.paths.session.read_bytes(), before)
        self.wallpaper.assert_not_called()
        self.border.assert_not_called()

    def test_drop_starts_before_durable_writes_and_rolls_back_on_write_failure(self):
        events = []
        self.wallpaper.side_effect = lambda *args, **kwargs: events.append('wallpaper')
        def fail_write(*args):
            events.append('write')
            raise OSError('disk full')
        before = self.paths.session.read_bytes()
        with patch.object(themes, 'atomic_text', side_effect=fail_write):
            with self.assertRaisesRegex(ConfigError, 'disk full'):
                themes.apply_theme(self.paths, 'forest-mist', transition={'x': 0.2, 'y': 0.7})
        self.assertEqual(events[0], 'wallpaper')
        self.assertEqual(events[-1], 'wallpaper')
        self.assertEqual(self.paths.session.read_bytes(), before)

    def test_failure_launching_wallpaper_restores_all_existing_files(self):
        themes.apply_theme(self.paths, 'alpine')
        files = [p for p in self.paths.config.parent.rglob('*') if p.is_file()] + [self.paths.session, self.paths.state/'mako-theme.conf', self.paths.state/'hyprlock-theme.conf', self.paths.state/'theme-ridge.svg']
        before = {p: p.read_bytes() for p in files}
        self.wallpaper.side_effect = ConfigError('renderer refused')
        with self.assertRaisesRegex(ConfigError, 'renderer refused'): themes.apply_theme(self.paths, 'moon-lake')
        self.assertEqual({p: p.read_bytes() for p in files}, before)
        self.assertEqual(self.border.call_args.args[0]['accent'], themes.load_theme(self.paths, 'alpine')['palette']['accent'])

    def test_failed_final_publication_restores_wallpaper_and_removes_new_files(self):
        before = self.paths.session.read_bytes()
        original = themes.atomic_text
        def fail_once(path, text):
            if path == self.paths.session and 'moon-lake' in text: raise OSError('disk full')
            original(path, text)
        with patch.object(themes, 'atomic_text', side_effect=fail_once):
            with self.assertRaisesRegex(ConfigError, 'disk full'): themes.apply_theme(self.paths, 'moon-lake')
        self.assertEqual(self.paths.session.read_bytes(), before)
        self.assertFalse((self.paths.config / 'appearance.json').exists())
        self.assertFalse((self.paths.config.parent / 'gtk-4.0/poly-palette.css').exists())
        self.assertEqual(self.wallpaper.call_count, 2)
        self.assertIn('alpine-dawn.png', str(self.wallpaper.call_args))

    def test_failure_at_each_theme_write_restores_exact_previous_files(self):
        themes.apply_theme(self.paths, 'alpine')
        files = [p for p in self.paths.config.parent.rglob('*') if p.is_file()] + [self.paths.session, self.paths.state/'mako-theme.conf', self.paths.state/'hyprlock-theme.conf', self.paths.state/'theme-ridge.svg']
        before = {p: p.read_bytes() for p in files}
        original = themes.atomic_text
        # A different palette creates a new immutable GTK theme directory;
        # old named themes are retained rather than rewritten.
        next_toolkit = themes.toolkit_files(self.paths, themes.load_theme(self.paths, 'moon-lake')['palette'])
        targets = [p for p in files if p.name != "settings.json" and not p.is_relative_to(themes.toolkit_theme_root(self.paths))]
        targets += [p for p in next_toolkit if p.is_relative_to(themes.toolkit_theme_root(self.paths))]
        for target in targets:
            failed = [False]
            def fail_once(path, text):
                if path == target and not failed[0]:
                    failed[0] = True
                    raise OSError('write interrupted')
                original(path, text)
            with self.subTest(target=target), patch.object(themes, 'atomic_text', side_effect=fail_once):
                with self.assertRaises(ConfigError): themes.apply_theme(self.paths, 'moon-lake')
            self.assertEqual({p: p.read_bytes() for p in files}, before)

    def test_toolkit_bridge_is_stable_and_both_gtk_versions_select_new_named_theme(self):
        palettes = [themes.load_theme(self.paths, name)['palette'] for name in ('forest-mist', 'moon-lake')]
        first, second = [themes.toolkit_files(self.paths, palette, 'Poly-Alpine') for palette in palettes]
        self.assertNotEqual(themes.toolkit_theme_name(palettes[0]), themes.toolkit_theme_name(palettes[1]))
        for version in ('3', '4'):
            root = self.paths.config.parent / ('gtk-' + version + '.0')
            if version == '3':
                self.assertEqual(first[root / 'poly-palette.css'], second[root / 'poly-palette.css'])
                self.assertIn('@poly_c_', second[root / 'poly-palette.css'])
            else:
                self.assertNotIn('@poly_c_', second[root / 'poly-palette.css'])
                self.assertNotEqual(first[root / 'poly-palette.css'], second[root / 'poly-palette.css'])
            self.assertIn('gtk-theme-name=' + themes.toolkit_theme_name(palettes[1]), second[root / 'settings.ini'])
            theme_file = themes.toolkit_theme_root(self.paths) / themes.toolkit_theme_name(palettes[1]) / ('gtk-' + version + '.0') / 'gtk.css'
            self.assertIn('@define-color poly_c_', second[theme_file])

    def test_gtk_settings_preserve_other_sections_and_missing_keys_are_added(self):
        text = '[Settings]\ngtk-theme-name=Old\ngtk-font-name=My Font 13\n[Unrelated]\nkeep=yes\n'
        changed = themes.ini_settings(text, {'gtk-theme-name': 'New', 'gtk-icon-theme-name': 'Icons'})
        self.assertIn('gtk-font-name=My Font 13', changed)
        self.assertIn('[Unrelated]\nkeep=yes', changed)
        self.assertIn('gtk-icon-theme-name=Icons', changed.split('[Unrelated]')[0])

    def test_owned_palette_updates_preserve_user_terminal_preferences(self):
        kitty = self.paths.config.parent / 'hypr/kitty.conf'; kitty.parent.mkdir(parents=True)
        kitty.write_text('font_size 17\nbackground #202729\nforeground #e7e9e5\nallow_remote_control no\n')
        themes.apply_theme(self.paths, 'moon-lake')
        text = kitty.read_text()
        self.assertIn('font_size 17', text); self.assertIn('allow_remote_control no', text)
        self.assertIn('background #172239', text)

    def test_import_is_deterministic_private_and_readable_after_original_removed(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("PIL is required for wallpaper import tests")
        source = self.paths.state / 'my blue image.png'
        Image.new('RGB', (48, 48), (40, 90, 180)).save(source)
        first = themes.import_wallpaper(self.paths, str(source))
        second = themes.import_wallpaper(self.paths, str(source))
        self.assertEqual(first['imported'], second['imported'])
        self.assertEqual(len(second['items']), 8)
        source.unlink()
        doc = themes.load_theme(self.paths, first['imported'])
        self.assertTrue(themes.theme_image(self.paths, doc).is_file())
        self.assertTrue(themes.theme_image(self.paths, doc).is_relative_to(self.paths.config))
        themes.validate_palette(doc['palette'])

    def test_invalid_image_or_palette_cannot_inject_configuration(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("PIL is required for wallpaper import tests")
        source = self.paths.state / 'bad.png'; source.write_text('not an image')
        with self.assertRaises(ConfigError): themes.import_wallpaper(self.paths, str(source))
        palette = themes.load_theme(self.paths, 'alpine')['palette']
        for key in themes.KEYS:
            with self.subTest(key=key), self.assertRaises(ConfigError): themes.validate_palette(palette | {key: '#fff\nexecute'})


if __name__ == '__main__': unittest.main()
