pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property date date: clock.date
    property int resumeCount: 0
    property bool sleeping: false
    signal preparingForSleep()
    signal resumed()

    // QTimer deadlines use a monotonic clock which excludes suspend time.
    // Re-arm the minute clock from wall time as soon as logind reports wakeup.
    function refresh(): void {
        clock.enabled = false;
        clock.enabled = true;
    }
    function handleSleepSignal(data: string): void {
        if (/org\.freedesktop\.login1\.Manager\.PrepareForSleep\s*\(true\s*,?\s*\)/.test(data)) {
            sleeping = true;
            preparingForSleep();
        } else if (/org\.freedesktop\.login1\.Manager\.PrepareForSleep\s*\(false\s*,?\s*\)/.test(data)) {
            sleeping = false;
            refresh();
            resumeCount += 1;
            resumed();
        }
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Process {
        id: sleepMonitor
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                root.handleSleepSignal(data);
                if (data.includes("owned by")) root.refresh();
            }
        }
        onExited: retry.restart()
    }
    Timer { id: retry; interval: 5000; onTriggered: sleepMonitor.running = true }
    IpcHandler {
        target: "clock"
        function refresh(): void { root.refresh(); }
        function status(): string {
            return JSON.stringify({date: root.date, systemDate: new Date(), resumeCount: root.resumeCount, sleeping: root.sleeping, watching: sleepMonitor.running});
        }
    }
}
