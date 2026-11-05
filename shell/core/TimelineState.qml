pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import "../logic/TimelineMath.js" as TimelineMath

Singleton {
    id: root
    readonly property bool active: Session.loaded && Session.appearance.id === "timeline"
    property bool loaded: false
    property var stops: []
    property int minute: 1110
    property int savedMinute: 1110
    property bool dragging: false
    property real shownMinute: minute
    readonly property var segment: TimelineMath.segment(shownMinute, stops)
    readonly property var palette: active && loaded && Session.appearance.colorsFromWallpaper !== false ? TimelineMath.palette(shownMinute, stops) : null
    readonly property string formatted: TimelineMath.format(minute)
    readonly property bool dirty: minute % 1440 !== savedMinute
    readonly property bool busy: writer.running
    property string error: ""
    property var response: null
    property bool pending: false
    property var readyScreens: ({})
    property bool presented: false
    function wallpaperReady(name: string, ready: bool): void {
        const next = Object.assign({}, readyScreens); next[name] = ready; readyScreens = next;
        if (active && !presented && !takeover.running && Quickshell.screens.every(s => !!next[s.name])) takeover.running = true;
    }
    Behavior on shownMinute { NumberAnimation { duration: Motion.reduced || !root.loaded ? 0 : 110; easing.type: Easing.OutCubic } }
    function refresh(): void { if (active && !reader.running) reader.running = true; }
    function move(value: real): void {
        if (!active || !loaded) return;
        minute = Math.max(0, Math.min(1440, Math.round(value))); error = "";
        // Persist after a short idle gap too, so wheel/keyboard changes survive.
        saveDelay.restart();
    }
    function commit(): void {
        saveDelay.stop();
        if (!active || !loaded || !dirty) return;
        if (writer.running) { pending = true; return; }
        response = null; error = ""; pending = false;
        writer.command = [Session.controller, "timeline", "set", JSON.stringify({minute: minute})];
        writer.running = true;
    }
    onActiveChanged: {
        if (active) refresh();
        else {
            dragging = false; pending = false; saveDelay.stop();
            minute = savedMinute; loaded = false; stops = []; readyScreens = ({}); presented = false;
            if (BarState.popup === "timeline") BarState.close();
        }
    }
    Timer { id: saveDelay; interval: 400; onTriggered: if (!root.dragging) root.commit() }
    Process {
        id: takeover
        command: [Session.controller, "timeline", "ready"]
        stdout: StdioCollector { onStreamFinished: { try { root.presented = !!JSON.parse(text).presented; } catch (_) {} } }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.error = text.trim().replace(/^poly-shell: /, "") }
    }
    Process {
        id: reader
        command: [Session.controller, "timeline", "get"]
        stdout: StdioCollector { onStreamFinished: {
            if (!root.active) return;
            try {
                const data = JSON.parse(text);
                const follow = !root.loaded || (!root.dragging && !root.dirty && !root.busy);
                if (JSON.stringify(root.stops) !== JSON.stringify(data.stops)) root.stops = data.stops;
                root.savedMinute = data.minute;
                if (follow) root.minute = data.minute;
                root.loaded = true;
            } catch (_) { root.error = I18n.tr("timeline.error_read"); }
        } }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.error = text.trim().replace(/^poly-shell: /, "") }
    }
    Process {
        id: writer
        stdout: StdioCollector { onStreamFinished: { try { root.response = JSON.parse(text); } catch (_) {} } }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.error = text.trim().replace(/^poly-shell: /, "") }
        onExited: exitCode => {
            if (exitCode === 0 && root.response && root.response.saved) root.savedMinute = root.response.minute;
            else if (!root.error) root.error = I18n.tr("timeline.error_save");
            if (root.pending && root.active) { root.pending = false; Qt.callLater(root.commit); }
        }
    }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/poly-shell/timeline.json"
        watchChanges: true; printErrors: false
        onFileChanged: { reload(); root.refresh(); }
    }
    Component.onCompleted: refresh()
    IpcHandler {
        target: "timeline"
        function setTime(minute: int): void { root.move(minute); root.commit(); }
        function status(): string { return JSON.stringify({active: root.active, loaded: root.loaded, minute: root.minute, saved: root.savedMinute, shown: root.shownMinute, segment: root.segment, palette: root.palette, dirty: root.dirty, busy: root.busy, presented: root.presented, error: root.error}); }
    }
}
