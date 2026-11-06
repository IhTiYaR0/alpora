# -*- coding: utf-8 -*-
import json
from pathlib import Path
import shutil
import subprocess
import unittest


@unittest.skipUnless(shutil.which('node'), 'JavaScript status checks require node')
class BarStatusTests(unittest.TestCase):
    def evaluate(self, expression):
        script = Path(__file__).resolve().parents[1] / 'shell/logic/StatusLogic.js'
        code = script.read_text(encoding='utf-8') + '\nconsole.log(JSON.stringify(' + expression + '));'
        return json.loads(subprocess.check_output(['node', '-e', code], text=True, encoding='utf-8'))

    def observation(self, **changes):
        data = dict(wifiAvailable=True, hardwareEnabled=True, wifiEnabled=True,
                    connected=False, connecting=False, strength=1, name='Test',
                    wiredConnected=False, connectivity='Unknown')
        data.update(changes)
        return json.dumps(data)

    def test_enabled_radio_without_connection_never_displays_connected(self):
        result = self.evaluate('network(' + self.observation() + ')')
        self.assertEqual(result['kind'], 'wifi-disconnected')
        self.assertEqual(result['level'], 0)
        self.assertIn('Нет подключения', result['label'])

    def test_disabled_missing_and_hardware_blocked_radios(self):
        for changes, expected in ((dict(wifiEnabled=False), 'wifi-off'),
                                  (dict(wifiAvailable=False), 'wifi-unavailable'),
                                  (dict(hardwareEnabled=False), 'wifi-off')):
            with self.subTest(changes=changes):
                self.assertEqual(self.evaluate('wifiStatus(' + self.observation(**changes) + ')')['kind'], expected)

    def test_connecting_is_busy_but_does_not_claim_signal_or_internet(self):
        result = self.evaluate('network(' + self.observation(connecting=True) + ')')
        self.assertTrue(result['busy'])
        self.assertEqual(result['level'], 0)
        self.assertNotIn('Есть интернет', result['label'])

    def test_wifi_signal_and_internet_are_independent(self):
        for strength, level in ((0, 0), (.1, 1), (.4, 2), (.9, 3)):
            with self.subTest(strength=strength):
                result = self.evaluate('network(' + self.observation(connected=True, strength=strength) + ')')
                self.assertEqual(result['level'], level)
                self.assertIn('не проверен', result['label'])
                self.assertFalse(result['warning'])
        for connectivity in ('None', 'Limited', 'Portal'):
            result = self.evaluate('network(' + self.observation(connected=True, connectivity=connectivity) + ')')
            self.assertTrue(result['warning'])
            self.assertNotIn('Есть интернет', result['label'])

    def test_wired_connection_survives_disabled_wifi(self):
        result = self.evaluate('network(' + self.observation(wifiEnabled=False, wiredConnected=True, connectivity='Full') + ')')
        self.assertEqual(result['kind'], 'wired')
        self.assertIn('Есть интернет', result['label'])

    def test_audio_tracks_missing_sink_zero_mute_and_live_volume(self):
        for args, kind, level in (('false,false,1', 'audio-unavailable', 0),
                                  ('true,false,0', 'muted', 0),
                                  ('true,true,.8', 'muted', 0),
                                  ('true,false,.2', 'volume', 1),
                                  ('true,false,.5', 'volume', 2),
                                  ('true,false,.9', 'volume', 3)):
            with self.subTest(args=args):
                result = self.evaluate('audio(' + args + ')')
                self.assertEqual((result['kind'], result['level']), (kind, level))
