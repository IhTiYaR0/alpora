"""OSD reads are non-mutating; notification styles follow the saved palette."""
from pathlib import Path
from subprocess import CompletedProcess
import tempfile
import unittest
from unittest.mock import patch

from poly_shell.indicators import indicator, mako_style, show_indicator, sync_notifications
from poly_shell.state import ConfigError, Paths, update_session


class IndicatorTests(unittest.TestCase):
    def test_audio_and_microphone_read_actual_values_without_writes(self):
        with patch('poly_shell.indicators.subprocess.run', return_value=CompletedProcess([], 0, 'Volume: 0.36 [MUTED]')) as run:
            self.assertEqual(indicator('microphone'), (.36, True))
            self.assertEqual(run.call_args.args[0], ['wpctl', 'get-volume', '@DEFAULT_AUDIO_SOURCE@'])
        with patch('poly_shell.indicators.subprocess.run', return_value=CompletedProcess([], 0, 'Volume: 1.25')):
            self.assertEqual(indicator('volume'), (1.25, False))

    def test_missing_devices_and_bad_audio_are_reported(self):
        with patch('poly_shell.indicators.backlight_device', return_value=('', 0)):
            with self.assertRaises(ConfigError):
                indicator('brightness')
        with patch('poly_shell.indicators.subprocess.run', return_value=CompletedProcess([], 1, '')):
            with self.assertRaises(ConfigError):
                indicator('volume')
        with self.assertRaises(ConfigError):
            indicator('unknown')

    def test_brightness_and_ipc_use_read_value(self):
        with patch('poly_shell.indicators.backlight_device', return_value=('display', 72)):
            self.assertEqual(indicator('brightness'), (.72, False))
        with patch('poly_shell.indicators.indicator', return_value=(.72, False)), patch('poly_shell.indicators.subprocess.run') as run:
            show_indicator('brightness')
            self.assertEqual(run.call_args.args[0][-4:], ['showOsd', 'brightness', '0.72', 'false'])

    def test_theme_reload_is_idempotent_and_missing_mako_is_optional(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = Paths(root / 'config', root / 'state', root / 'runtime')
            work = update_session(paths, 'work')
            with patch('poly_shell.indicators.subprocess.run', side_effect=FileNotFoundError) as run:
                sync_notifications(paths)
                sync_notifications(paths)
                self.assertEqual(run.call_count, 1)
            generated = (paths.state / 'mako-theme.conf').read_text()
            self.assertIn('border-color=' + work['profile']['palette']['accent'], generated)
            vibe = update_session(paths, 'vibe')
            self.assertNotEqual(mako_style(work), mako_style(vibe))
            self.assertEqual(work['appearance'], vibe['appearance'])

    def test_font_cannot_inject_notification_configuration(self):
        with self.assertRaises(ConfigError):
            mako_style({'profile': {'palette': {}}, 'appearance': {'fonts': {'interface': 'Noto\ninclude=other'}}})


    def test_osd_toggle_cli(self):
        from poly_shell.cli import main
        with patch('poly_shell.cli.SafeRunner.run', return_value=CompletedProcess([], 0, '')) as mock_run:
            ret = main(['osd', 'capslock', '--state', 'on'])
            self.assertEqual(ret, 0)
            mock_run.assert_called_once()
            call_cmd = mock_run.call_args[0][0]
            self.assertIn('showToggleOsd', call_cmd)
            self.assertIn('capslock', call_cmd)
            self.assertIn('true', call_cmd)


if __name__ == '__main__':
    unittest.main()
