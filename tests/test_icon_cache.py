"""The optional raster cache is keyed by source revision and selected theme."""
from pathlib import Path
import runpy
import tempfile
import unittest

KEY = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'scripts/build/build-app-icon-cache'))['cache_key']


class IconCacheTests(unittest.TestCase):
    def test_key_is_stable_and_cannot_contain_source_path(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'icon.svg'
            source.write_text('<svg/>')
            key = KEY('Alpine', source)
            self.assertEqual(key, KEY('Alpine', source))
            self.assertRegex(key, r'^[a-f0-9]{64}\.png$')

    def test_theme_and_source_edits_invalidate_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'icon.svg'
            source.write_text('<svg/>')
            before = KEY('Alpine', source)
            self.assertNotEqual(before, KEY('Other', source))
            source.write_text('<svg><!-- updated --></svg>')
            self.assertNotEqual(before, KEY('Alpine', source))


if __name__ == '__main__':
    unittest.main()
