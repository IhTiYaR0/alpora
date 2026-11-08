import json
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('node'), 'JavaScript launch checks require node')
class AppLaunchTests(unittest.TestCase):
    def evaluate(self, expression):
        script = ROOT / 'shell/AppLaunch.js'
        code = script.read_text() + '\nconsole.log(JSON.stringify(' + expression + '));'
        return json.loads(subprocess.check_output(['node', '-e', code], text=True))

    def call(self, function, *args):
        return self.evaluate(function + '(' + ', '.join(json.dumps(arg) for arg in args) + ')')

    def test_unit_name_follows_desktop_environment_scheme(self):
        self.assertEqual(self.call('unitName', 'alpora', 'org.mozilla.firefox', '1a2b'),
                         'app-alpora-org.mozilla.firefox@1a2b.service')

    def test_dash_in_desktop_id_is_escaped(self):
        self.assertEqual(self.call('unitName', 'alpora', 'google-chrome', '1a2b'),
                         'app-alpora-google\\x2dchrome@1a2b.service')

    def test_escape_matches_systemd_escape_rules(self):
        vectors = {
            'org.mozilla.firefox': 'org.mozilla.firefox',
            'google-chrome': 'google\\x2dchrome',
            'my app': 'my\\x20app',
            'x:y_z.1': 'x:y_z.1',
            '.hidden': '\\x2ehidden',
            'café': 'caf\\xc3\\xa9',
            'a\U0001F600': 'a\\xf0\\x9f\\x98\\x80',
        }
        for app_id, expected in vectors.items():
            with self.subTest(app_id=app_id):
                self.assertEqual(self.call('escapeId', app_id), expected)

    def test_slash_is_escaped_instead_of_turned_into_a_dash(self):
        # systemd-escape maps "/" to "-", but a dash would split the AppID.
        self.assertEqual(self.call('escapeId', 'vendor/app'), 'vendor\\x2fapp')

    @unittest.skipUnless(shutil.which('systemd-escape'), 'requires systemd-escape')
    def test_escape_agrees_with_real_systemd_escape(self):
        for app_id in ('org.mozilla.firefox', 'google-chrome', 'my app', 'x:y_z.1',
                       '.hidden', 'café', 'a\U0001F600', 'kitty'):
            with self.subTest(app_id=app_id):
                expected = subprocess.check_output(['systemd-escape', '--', app_id], text=True).strip()
                self.assertEqual(self.call('escapeId', app_id), expected)

    def test_fallback_id_is_basename_without_dash(self):
        self.assertEqual(self.call('fallbackId', ['/usr/bin/xdg-open', '/home/x']), 'xdg_open')
        self.assertEqual(self.call('fallbackId', ['kitty', '-e', 'nmtui']), 'kitty')
        self.assertEqual(self.call('fallbackId', []), 'command')
        unit = self.call('unitName', 'alpora', self.call('fallbackId', ['/usr/bin/xdg-open']), '1a2b')
        self.assertEqual(unit, 'app-alpora-xdg_open@1a2b.service')

    def test_unit_name_has_exactly_the_scheme_dashes(self):
        for app_id in ('google-chrome', 'a-b-c', 'vendor/app-x', '-'):
            with self.subTest(app_id=app_id):
                unit = self.call('unitName', 'alpora', app_id, '1a2b')
                self.assertEqual(unit.count('-'), 2)
                self.assertRegex(unit, r'^app-alpora-[A-Za-z0-9:_.\\]+@1a2b\.service$')

    def test_command(self):
        self.assertEqual(self.call('command', 'alpora', 'kitty', ['kitty'], '1a2b'),
                         ['systemd-run', '--user', '--slice=app.slice', '--collect', '--quiet',
                          '--service-type=exec', '-p', 'ExitType=cgroup',
                          '--unit=app-alpora-kitty@1a2b.service', '--', 'kitty'])

    def test_command_with_working_directory(self):
        self.assertEqual(self.call('command', 'alpora', 'kitty', ['kitty'], '1a2b', '/tmp'),
                         ['systemd-run', '--user', '--slice=app.slice', '--collect', '--quiet',
                          '--service-type=exec', '-p', 'ExitType=cgroup', '--working-directory=/tmp',
                          '--unit=app-alpora-kitty@1a2b.service', '--', 'kitty'])

    def test_command_with_slice(self):
        result = self.call('command', 'alpora', 'hyprlock', ['hyprlock'], '1a2b', '', 'session.slice')
        self.assertEqual(result[:3], ['systemd-run', '--user', '--slice=session.slice'])
        self.assertIn('--unit=app-alpora-hyprlock@1a2b.service', result)
        for slice_ in ('', None):
            with self.subTest(slice=slice_):
                result = self.call('command', 'alpora', 'kitty', ['kitty'], '1a2b', '', slice_)
                self.assertIn('--slice=app.slice', result)

    def test_command_keeps_argv_after_separator(self):
        argv = ['kitty', '-e', 'nmtui', '--unit=evil']
        result = self.call('command', 'alpora', 'kitty', argv, '1a2b', '')
        self.assertNotIn('--working-directory=', ' '.join(result))
        self.assertEqual(result[result.index('--') + 1:], argv)

    def test_command_uses_fallback_id_without_desktop_id(self):
        result = self.call('command', 'alpora', '', ['/usr/bin/xdg-open', '/home/x'], '1a2b')
        self.assertIn('--unit=app-alpora-xdg_open@1a2b.service', result)


class AppLaunchRegressionTests(unittest.TestCase):
    def test_no_shell_component_launches_desktop_entries_in_the_shell_cgroup(self):
        # DesktopEntry.execute() starts the app inside poly-shell.service, so a
        # shell restart or OOM kill takes the app down. Use Session.launchEntry().
        offenders = [f'{path.name}:{number}'
                     for path in sorted((ROOT / 'shell').glob('*.qml'))
                     for number, line in enumerate(path.read_text().splitlines(), 1)
                     if re.search(r'\.execute\s*\(', line)]
        self.assertEqual(offenders, [])

    def test_terminal_and_file_manager_launches_get_their_own_unit(self):
        offenders = [f'{path.name}:{number}'
                     for path in sorted((ROOT / 'shell').glob('*.qml'))
                     for number, line in enumerate(path.read_text().splitlines(), 1)
                     if 'execDetached' in line and re.search(r'apps\.terminal|xdg-open|settings\.apps', line)]
        self.assertEqual(offenders, [])

    def test_only_the_lock_screen_runs_in_session_slice(self):
        source = (ROOT / 'shell/Session.qml').read_text()
        maps = re.findall(r'readonly property var appSlices: \(\{([^}]*)\}\)', source)
        self.assertEqual(len(maps), 1)
        pairs = dict(re.findall(r'(\w+)\s*:\s*"([^"]*)"', maps[0]))
        self.assertEqual(pairs, {'lock': 'session.slice'})
        self.assertEqual(re.findall(r'"[\w.-]+\.slice"', source), ['"session.slice"'])
        self.assertIn('launchCommand("", command, "", appSlices[name] || "")', source)

    def test_launcher_name_is_one_dashless_constant(self):
        source = (ROOT / 'shell/Session.qml').read_text()
        names = re.findall(r'readonly property string appLauncherName: "([^"]*)"', source)
        self.assertEqual(len(names), 1)
        self.assertRegex(names[0], r'^[A-Za-z0-9_.]+$')


if __name__ == '__main__':
    unittest.main()
