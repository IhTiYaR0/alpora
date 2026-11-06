import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('node'), 'Geometry checks require Node')
class LivingLandscapeGeometryTests(unittest.TestCase):
    def evaluate(self, code):
        source = (ROOT / 'shell/logic/LandscapeGeometry.js').read_text().replace('.pragma library', '')
        return json.loads(subprocess.check_output(['node', '-e', source + '\n' + code], text=True))

    def test_cover_mapping_tracks_the_artwork_instead_of_stretching(self):
        points = self.evaluate('console.log(JSON.stringify([fitPoint([0.5,0.5],3440,1440),fitPoint([0,0],1080,1920)]))')
        self.assertEqual(points[0], {'x':1720, 'y':720})
        self.assertLess(points[1]['x'], 0)
        self.assertAlmostEqual(points[1]['y'], 0)

    def test_all_themes_and_unknown_import_keep_controls_on_screen(self):
        layouts = self.evaluate('''
            const all = [];
            for (const name of Object.keys(scenes).concat(['custom-new']))
                for (const size of [[1920,1080],[3440,1440],[1080,1920],[800,600],[3840,2160]])
                    for (const minute of [0,330,780,1110,1380])
                        all.push({size,layout:layout(name,minute,...size)});
            console.log(JSON.stringify(all));
        ''')
        for item in layouts:
            width, height = item['size']
            for name in ('light', 'peak', 'music'):
                point = item['layout'][name]
                self.assertTrue(0 <= point['x'] <= width)
                self.assertTrue(0 <= point['y'] <= height)
            scale = item['layout']['scale']
            light, peak, music = (item['layout'][n] for n in ('light','peak','music'))
            self.assertGreaterEqual(light['x'] - 190 * scale, -5 * scale)
            self.assertLessEqual(light['x'] + 175 * scale, width)
            self.assertGreaterEqual(peak['x'] - 250 * scale, 0)
            self.assertLessEqual(peak['x'] + 250 * scale, width)
            self.assertLessEqual(music['y'] + 145 * scale, height)

    def test_reflections_are_not_invented_for_desert_or_unknown_wallpapers(self):
        flags = self.evaluate('console.log(JSON.stringify([scene("warm-desert",0).water,scene("custom",0).water,scene("moon-lake",0).water]))')
        self.assertEqual(flags, [False,False,True])


if __name__ == '__main__':
    unittest.main()
