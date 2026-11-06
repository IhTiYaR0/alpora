"""Exercise the real QML clock with an isolated logind signal stream."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("quickshell"), "Quickshell is required")
class ClockResumeTests(unittest.TestCase):
    def test_wakeup_rearms_clock_without_waiting_for_old_deadline(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            # Expose the native clock only in this temporary test copy, so we
            # can pause its deadline without suspending the user's computer.
            source = (ROOT / "shell/core/ClockState.qml").read_text()
            (directory / "ClockState.qml").write_text(source.replace(
                "id: root", "id: root\n    property alias testClock: clock", 1))
            shutil.copy(ROOT / "shell/core/PanelMotion.qml", directory)
            (directory / "Motion.qml").write_text('''pragma Singleton
import QtQuick
QtObject { readonly property int openMs: 320; readonly property int closeMs: 200 }
''')
            (directory / "qmldir").write_text(
                "singleton ClockState 1.0 ClockState.qml\n"
                "singleton Motion 1.0 Motion.qml\nPanelMotion 1.0 PanelMotion.qml\n")
            monitor = directory / "gdbus"
            monitor.write_text('''#!/usr/bin/python3
import time
print('/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)', flush=True)
time.sleep(.1)
print('/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (false,)', flush=True)
time.sleep(30)
''')
            monitor.chmod(0o755)
            (directory / "shell.qml").write_text('''import QtQuick
import Quickshell
ShellRoot {
    id: test
    property int changes: 0
    property bool prepared: false
    PanelMotion { id: panelMotion; opened: false }
    Component.onCompleted: {
        ClockState.testClock.enabled = false;
        panelMotion.opened = true;
    }
    Connections {
        target: ClockState.testClock
        function onDateChanged(): void { test.changes += 1; }
    }
    Connections {
        target: ClockState
        function onPreparingForSleep(): void {
            if (!ClockState.sleeping || ClockState.resumeCount !== 0 || ClockState.testClock.enabled)
                throw new Error("Sleep preparation must precede wakeup");
            panelMotion.opened = false;
            if (panelMotion.presented || panelMotion.progress !== 0)
                throw new Error("Panel must close immediately before suspend");
            test.prepared = true;
        }
        function onResumed(): void {
            if (!test.prepared || ClockState.sleeping || ClockState.resumeCount !== 1 || !ClockState.testClock.enabled || test.changes < 1)
                throw new Error("Resume did not immediately re-arm the paused clock");
            const age = Date.now() - ClockState.date.getTime();
            if (age < 0 || age >= 60000) throw new Error("Clock does not match wall time");
            console.info("CLOCK_RESUME_OK");
            Qt.quit();
        }
    }
    Timer { interval: 3000; running: true; onTriggered: Qt.quit() }
}
''')
            environment = dict(os.environ, QT_QPA_PLATFORM="offscreen",
                               QT_QPA_PLATFORMTHEME="generic", QT_STYLE_OVERRIDE="Fusion",
                               QT_QUICK_CONTROLS_STYLE="Basic",
                               PATH=f"{directory}:/usr/bin:/bin",
                               XDG_RUNTIME_DIR=str(directory))
            result = subprocess.run(["quickshell", "--path", str(directory)],
                                    env=environment, capture_output=True, text=True, timeout=8)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("CLOCK_RESUME_OK", output)
