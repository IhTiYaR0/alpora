"""Companion smoothing follows its bounded clock, including retargets and pause."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('quickshell'), 'Quickshell required')
class CompanionTweenTests(unittest.TestCase):
    def test_retarget_wrap_pause_and_reduced_motion(self):
        with tempfile.TemporaryDirectory(prefix='poly-companion-tween-') as temporary:
            directory = Path(temporary)
            shutil.copy(ROOT / 'shell/components/CompanionTween.qml', directory)
            (directory / 'shell.qml').write_text('''import QtQuick
import Quickshell
ShellRoot {
    id: test
    property real phase: 0
    property real target: 0
    property bool motion: true
    CompanionTween {
        id: tween; clock: test.phase; targetValue: test.target
        duration: 1000; enabled: test.motion
    }
    function near(expected: real): void {
        if (Math.abs(tween.value-expected) > .00001)
            throw new Error("Expected " + expected + ", got " + tween.value);
    }
    Timer { interval: 1; running: true; onTriggered: {
        test.target = 10; test.near(0);
        test.phase = .5; test.near(5);
        test.target = 20; test.near(5); // Retarget must not jump.
        test.phase = .75; test.near(6.875);
        test.phase = 1.5; test.near(20);
        test.motion = false; test.phase = 3599.75;
        test.motion = true; test.target = 30; test.near(20);
        test.phase = .25; test.near(25); // One-hour clock wrap.
        pauseCheck.start();
    }}
    Timer { id: pauseCheck; interval: 100; onTriggered: {
        test.near(25); // Wall-clock time cannot advance a stopped clock.
        test.motion = false; test.target = -10; test.near(-10);
        test.phase = .75; test.near(-10);
        test.motion = true; test.near(-10);
        tween.easeInOut = false; test.target = 10;
        test.phase = 1; test.near(-5);
        test.phase = 2; test.near(10);
        console.info("COMPANION_TWEEN_OK"); Qt.quit();
    }}
    Timer { interval: 2000; running: true; onTriggered: Qt.quit() }
}
''')
            env = dict(os.environ, QT_QPA_PLATFORM='offscreen',
                       QT_QPA_PLATFORMTHEME='generic', XDG_RUNTIME_DIR=str(directory))
            result = subprocess.run(['quickshell', '--path', str(directory)],
                                    env=env, capture_output=True, text=True, timeout=5)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('COMPANION_TWEEN_OK', output)
