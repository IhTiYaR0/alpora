import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch
from xml.etree import ElementTree as ET

from poly_shell.landscapes import KINDS, kind_for, svg_for, landscape_assets, palette_colors
from poly_shell import themes
from poly_shell.state import Paths, ConfigError, read_object, update_session


def geometry(source):
    return [(n.tag, n.get('points'), n.get('d')) for n in ET.fromstring(source) if n.tag.endswith(('path','polygon'))]


class LandscapeTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(); self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        self.paths = Paths(root/'config/poly-shell', root/'state', root/'runtime')
        update_session(self.paths)
        self.palette = themes.load_theme(self.paths, 'moon-lake')['palette']

    def test_all_six_themes_have_distinct_geometry_and_semantic_colors(self):
        signatures = []
        for ident in themes.IDS:
            text = svg_for(kind_for(ident), self.palette)
            signatures.append(str(geometry(text)))
            for node in ET.fromstring(text):
                self.assertIn(node.get('fill'), palette_colors(self.palette))
                self.assertFalse(any('href' in name for name in node.attrib))
        self.assertEqual(len(set(signatures)), 6)

    def test_recolor_preserves_shape_but_invalidates_both_image_urls(self):
        a, files_a = landscape_assets(self.paths, 'moon-lake', self.palette)
        changed = self.palette | {'accent':'#e5a9c4','secondary':'#efb89e'}
        b, files_b = landscape_assets(self.paths, 'moon-lake', changed)
        self.assertNotEqual(a['ridge'], b['ridge'])
        self.assertNotEqual(a['clockRidge'], b['clockRidge'])
        self.assertEqual(geometry(files_a[Path(a['ridge'])]), geometry(files_b[Path(b['ridge'])]))
        self.assertNotEqual(files_a[Path(a['ridge'])], files_b[Path(b['ridge'])])

    def test_custom_wallpaper_identity_is_repeatable(self):
        first_kind = kind_for('custom-1234')
        second_kind = kind_for('custom-1234')
        self.assertEqual(first_kind, second_kind)
        self.assertIn(first_kind, KINDS.values())

    def test_assets_survive_mode_refresh_and_failed_theme_switch(self):
        with patch('poly_shell.themes.runtime_border'), patch('poly_shell.themes.subprocess.run'), patch('poly_shell.desktop._wallpaper') as wallpaper:
            themes.apply_theme(self.paths, 'alpine')
            old = read_object(self.paths.session)['appearance']
            for mode in ('work','vibe'):
                now = update_session(self.paths, mode)['appearance']
                self.assertEqual(now['ridge'], old['ridge'])
                self.assertEqual(now['clockRidge'], old['clockRidge'])
            originals = {p:p.read_bytes() for p in (self.paths.state/'landscapes').glob('*.svg')}
            wallpaper.side_effect = ConfigError('test startup failure')
            with self.assertRaises(ConfigError): themes.apply_theme(self.paths, 'moon-lake')
            self.assertEqual({p:p.read_bytes() for p in (self.paths.state/'landscapes').glob('*.svg')}, originals)
            self.assertEqual(read_object(self.paths.session)['appearance']['ridge'], old['ridge'])


if __name__ == '__main__': unittest.main()
