from copy import deepcopy
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch

from poly_shell.state import Paths, ConfigError, atomic_json, update_session
from poly_shell.widgets import DEFAULTS, values_for, widgets_control, weather, search


class WidgetTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(); self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        self.paths = Paths(root/'config', root/'state', root/'runtime')
        self.values = deepcopy(DEFAULTS)
        self.forecast = {'current': {'temperature_2m': 18.2, 'weather_code': 2, 'is_day': 1},
                         'daily': {'time': ['2026-10-20', '2026-10-21', '2026-10-22'],
                                   'weather_code': [2, 0, 61], 'temperature_2m_max': [19, 17, 13],
                                   'temperature_2m_min': [8, 7, 6]}}

    def save(self, values=None, **extra):
        return widgets_control(self.paths, 'apply', {'values': values or self.values, **extra})

    def test_layout_persists_and_mode_refresh_does_not_change_it(self):
        self.values['clock'].update(x=37, y=192)
        self.values['music']['enabled'] = False
        self.values['screen'] = 'HDMI-A-1'
        self.save()
        for mode in ('work', 'vibe'):
            update_session(self.paths, mode)
            self.assertEqual(values_for(self.paths), self.values)

    def test_invalid_positions_and_locations_preserve_saved_file(self):
        self.save(); target = self.paths.config/'widgets.json'; original = target.read_bytes()
        for key, field, value in [('clock', 'x', -1), ('clock', 'x', 101), ('music', 'y', 9000),
                                  ('music', 'enabled', 1), ('location', 'latitude', float('nan')),
                                  ('location', 'longitude', 181), ('clock', 'y', True)]:
            bad = deepcopy(self.values); bad[key][field] = value
            with self.assertRaises(ConfigError): self.save(bad)
            self.assertEqual(target.read_bytes(), original)

    def test_stale_editor_cannot_overwrite_new_layout(self):
        self.save(); old = deepcopy(self.values)
        self.values['weather']['x'] = 40; self.save()
        with self.assertRaises(ConfigError): self.save(old, expected=old)
        self.assertEqual(values_for(self.paths), self.values)

    def test_motion_migrates_old_layout_and_persists_switch(self):
        old = deepcopy(self.values); old.pop('animations')
        atomic_json(self.paths.config/'widgets.json', {'schemaVersion': 1, 'values': old})
        self.assertEqual(values_for(self.paths), self.values)
        self.values['animations'] = False
        self.save(expected=old)
        self.assertFalse(values_for(self.paths)['animations'])
        with self.assertRaises(ConfigError): self.save(self.values | {'animations': 1})

    def test_running_apps_widget_migrates_old_layout(self):
        old = deepcopy(self.values); old.pop('apps')
        atomic_json(self.paths.config/'widgets.json', {'schemaVersion': 1, 'values': old})
        self.assertEqual(values_for(self.paths), self.values)

    def test_failed_atomic_write_preserves_last_layout(self):
        self.save(); original = values_for(self.paths)
        self.values['clock']['x'] = 50
        with patch('poly_shell.state.os.replace', side_effect=OSError('disk full')):
            with self.assertRaises(OSError): self.save()
        self.assertEqual(values_for(self.paths), original)
        self.assertEqual(len(list(self.paths.config.iterdir())), 1)

    def test_corrupt_saved_config_is_not_overwritten(self):
        target = self.paths.config/'widgets.json'; target.parent.mkdir(); target.write_text('{broken')
        with self.assertRaises(ConfigError): self.save()
        self.assertEqual(target.read_text(), '{broken')

    def test_weather_cache_avoids_repeated_network_calls(self):
        with patch('poly_shell.widgets.request_json', return_value=self.forecast) as request:
            first = weather(self.paths); second = weather(self.paths)
        self.assertEqual(request.call_count, 1)
        self.assertEqual(first, second)
        self.assertEqual(first['current']['temperature_2m'], 18.2)

    def test_offline_preserves_same_city_forecast_and_rejects_other_city(self):
        with patch('poly_shell.widgets.request_json', return_value=self.forecast): weather(self.paths)
        with patch('poly_shell.widgets.time.time', return_value=4e9), patch('poly_shell.widgets.request_json', side_effect=ConfigError('offline')):
            stale = weather(self.paths)
            self.assertTrue(stale['stale']); self.assertIn('current', stale)
            self.values['location'] = {'name': 'Астана', 'latitude': 51.17, 'longitude': 71.43}; self.save()
            missing = weather(self.paths)
            self.assertNotIn('current', missing); self.assertFalse(missing['stale']); self.assertTrue(missing['error'])

    def test_bad_api_data_does_not_replace_last_good_forecast(self):
        with patch('poly_shell.widgets.request_json', return_value=self.forecast): weather(self.paths)
        target = self.paths.state/'weather.json'; original = target.read_bytes()
        for bad in ({}, {'current': None}, self.forecast | {'current': {'temperature_2m': None}}):
            with patch('poly_shell.widgets.time.time', return_value=4e9), patch('poly_shell.widgets.request_json', return_value=bad):
                result = weather(self.paths)
            self.assertTrue(result['stale']); self.assertEqual(target.read_bytes(), original)

    def test_corrupt_cache_can_be_recovered_and_search_returns_options(self):
        atomic_json(self.paths.state/'weather.json', {'coordinates': [43.25, 76.95], 'current': {}, 'fetchedAt': 'bad'})
        with patch('poly_shell.widgets.request_json', return_value=self.forecast):
            self.assertFalse(weather(self.paths)['error'])
        with patch('poly_shell.widgets.request_json', return_value={'results': [
                {'name': 'Алматы', 'latitude': 43.25, 'longitude': 76.95, 'country': 'Казахстан'}]}):
            self.assertEqual(search('Алматы')['results'][0]['description'], 'Казахстан')
        with self.assertRaises(ConfigError): search(' ')


if __name__ == '__main__': unittest.main()
