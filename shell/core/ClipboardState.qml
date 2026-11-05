pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var entries: []
    property bool paused: false
    property bool ready: false
    property bool busy: false
    property string error: ""
    function request(action: string, id: string): void {
        if (!ready || busy) return;
        busy = true;
        worker.write(JSON.stringify({action: action, id: id}) + "\n");
    }
    Process {
        id: worker
        command: [Quickshell.env("POLY_SHELL_CTL") || "poly-shell", "clipboard-serve"]
        stdinEnabled: true
        running: true
        stdout: SplitParser {
            onRead: message => {
                try {
                    const data = JSON.parse(message);
                    root.entries = data.entries; root.paused = data.paused;
                    root.error = data.error; root.ready = true; root.busy = false;
                    if (data.action === "copy") BarState.close();
                } catch (_) { root.error = I18n.tr("clipboard.error_read"); }
            }
        }
        stderr: SplitParser { onRead: message => { root.error = message; } }
        onExited: {
            root.ready = false; root.busy = false;
            if (!root.error) root.error = I18n.tr("clipboard.unavailable");
            retry.restart();
        }
    }
    Timer { id: retry; interval: 3000; onTriggered: worker.running = true }
    IpcHandler {
        target: "clipboard"
        function status(): string { return JSON.stringify({ready: root.ready, busy: root.busy, paused: root.paused, count: root.entries.length, pinned: root.entries.filter(e => e.pinned).length, error: root.error}); }
        function action(action: string, id: string): void { root.request(action, id); }
    }
}
