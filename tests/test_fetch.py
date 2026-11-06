"""Exercise live theme following in a real PTY without changing the desktop."""
from contextlib import contextmanager
import json
import os
from pathlib import Path
import select
import signal
import struct
import subprocess
import tempfile
import time
import unittest

try:
    import fcntl
    import pty
    import termios
except ImportError:
    fcntl = None
    pty = None
    termios = None

from poly_shell.timeline import palette_for

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipIf(fcntl is None or pty is None, "POSIX PTY required for alpora-fetch live terminal tests")
class FetchTests(unittest.TestCase):
    @contextmanager
    def terminal(self):
        with tempfile.TemporaryDirectory(prefix='alpora-fetch-') as directory:
            home = Path(directory)
            config = home / 'config/poly-shell'
            config.mkdir(parents=True)
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / 'config'),
                       XDG_STATE_HOME=str(home / 'state'), TERM='xterm-256color')
            env.pop('NO_COLOR', None)
            master, slave = pty.openpty()
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 30, 100, 0, 0))
            original = termios.tcgetattr(slave)
            process = subprocess.Popen([str(ROOT / 'bin/alpora-fetch')], env=env,
                                       stdin=slave, stdout=slave, stderr=slave)
            try:
                yield master, slave, process, config, original
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=3)
                os.close(master)
                os.close(slave)

    def wait_for(self, master, expected):
        output = b''
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if select.select([master], [], [], .1)[0]:
                output += os.read(master, 65536)
                if expected in output:
                    return output
        self.fail(f'Missing terminal output {expected!r}; received {output[-500:]!r}')

    def save(self, path, value):
        temp = path.with_suffix('.tmp')
        temp.write_text(json.dumps(value))
        temp.replace(path)

    def test_running_card_follows_themes_custom_colours_and_timeline(self):
        with self.terminal() as (master, slave, process, config, original):
            self.wait_for(master, b'Alpine')
            self.save(config / 'appearance.json', {'theme': 'northern-lights'})
            self.wait_for(master, b'Northern Lights')
            doc = json.loads((ROOT / 'assets/themes/northern-lights.json').read_text())
            palette = doc.get('palette') or doc['themePalette']
            palette['accent'] = '#123456'
            self.save(config / 'appearance.json', {'theme': 'northern-lights', 'palette': palette})
            self.wait_for(master, b'\x1b[38;2;18;52;86m')
            self.save(config / 'timeline.json', {'schemaVersion': 1, 'minute': 720})
            self.save(config / 'appearance.json', {'theme': 'timeline', 'colorsFromWallpaper': True})
            self.wait_for(master, b'Timeline')
            self.save(config / 'timeline.json', {'schemaVersion': 1, 'minute': 1000})
            colour = palette_for(1000)['accent']
            rgb = ';'.join(str(int(colour[i:i+2], 16)) for i in (1, 3, 5))
            self.wait_for(master, f'\x1b[38;2;{rgb}m'.encode())
            os.write(master, b'q')
            self.assertEqual(process.wait(timeout=3), 0)
            self.wait_for(master, b'\x1b[?25h\x1b[?1049l')
            self.assertEqual(termios.tcgetattr(slave), original)
            self.assertFalse((config.parent.parent / 'state').exists())

    def test_termination_restores_terminal(self):
        with self.terminal() as (master, slave, process, config, original):
            self.wait_for(master, b'Alpine')
            process.send_signal(signal.SIGTERM)
            self.assertEqual(process.wait(timeout=3), 0)
            self.wait_for(master, b'\x1b[?25h\x1b[?1049l')
            self.assertEqual(termios.tcgetattr(slave), original)

    def test_redirected_output_remains_once_and_plain(self):
        result = subprocess.run([str(ROOT / 'bin/alpora-fetch')], capture_output=True,
                                text=True, timeout=3)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('\x1b', result.stdout)
        self.assertIn('A L P O R A', result.stdout)
