pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var values: ({animations: true, screen: "", clock: {enabled: true, x: 0, y: 0},
        weather: {enabled: true, x: 100, y: 0}, music: {enabled: true, x: 100, y: 238},
        location: {name: "Almaty", latitude: 43.25, longitude: 76.95}})
    property var base: ({})
    property var draft: ({})
    property bool editing: false
    property bool loaded: false
    property string error: ""
    property string message: ""
    property var result: null
    readonly property bool busy: writer.running
    readonly property bool dirty: editing && JSON.stringify(base) !== JSON.stringify(draft)
    function clone(value: var): var { return JSON.parse(JSON.stringify(value)); }
    function begin(): void {
        if (busy || dirty) return;
        base = clone(values); draft = clone(values); editing = true;
    }
    function edit(kind: string, key: string, value: var): void {
        if (busy) return;
        const next = clone(draft);
        next[kind][key] = value; draft = next; error = ""; message = "";
    }
    function setScreen(name: string): void {
        if (busy) return;
        const next = clone(draft); next.screen = name; draft = next; message = "";
    }
    function setAnimations(enabled: bool): void {
        if (busy) return;
        const next = clone(draft); next.animations = enabled; draft = next; message = "";
    }
    function move(kind: string, position: var): void {
        if (busy) return;
        const next = clone(draft);
        next[kind].x = position.x; next[kind].y = position.y;
        draft = next; message = "";
    }
    function setLocation(location: var): void {
        if (busy) return;
        const next = clone(draft);
        next.location = {name: location.name, latitude: location.latitude, longitude: location.longitude};
        draft = next; error = ""; message = "";
    }
    function cancel(): void { if (busy) return; editing = false; begin(); error = ""; message = ""; }
    function reset(): void {
        if (busy) return;
        const next = clone(draft);
        next.clock = {enabled: next.clock.enabled, x: 0, y: 0};
        next.weather = {enabled: next.weather.enabled, x: 100, y: 0};
        next.music = {enabled: next.music.enabled, x: 100, y: 238}; draft = next; message = I18n.tr("widgets.initial_pos_chosen");
    }
    function apply(): void {
        if (busy || !dirty) return;
        result = null; error = ""; message = "";
        writer.command = [Session.controller, "widgets", "apply", JSON.stringify({values: draft, expected: base})];
        writer.running = true;
    }
    function refresh(): void { if (!reader.running) reader.running = true; }
    Process {
        id: reader
        command: [Session.controller, "widgets", "get"]
        stdout: StdioCollector { onStreamFinished: {
            try { root.values = JSON.parse(text).values; root.loaded = true; if (root.editing && !root.dirty && !root.busy) root.begin(); }
            catch (_) { root.error = I18n.tr("widgets.error_read"); }
        } }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.error = text.trim().replace(/^poly-shell: /, "") }
    }
    Process {
        id: writer
        stdout: StdioCollector { onStreamFinished: { try { root.result = JSON.parse(text); } catch (_) {} } }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.error = text.trim().replace(/^poly-shell: /, "") }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && exitStatus === 0 && root.result && root.result.saved) {
                root.values = root.clone(root.result.values);
                root.loaded = true;
                root.base = root.clone(root.result.values); root.draft = root.clone(root.result.values);
                root.message = I18n.tr("widgets.saved_pos");
            } else if (!root.error) root.error = I18n.tr("widgets.error_save");
        }
    }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/poly-shell/widgets.json"
        watchChanges: true; printErrors: false
        onFileChanged: { reload(); root.refresh(); }
    }
    IpcHandler {
        target: "widgets"
        function status(): string { return JSON.stringify({values: root.values, draft: root.draft, dirty: root.dirty, busy: root.busy, error: root.error}); }
        function edit(kind: string, key: string, value: string): void { root.begin(); root.edit(kind, key, JSON.parse(value)); }
        function apply(): void { root.apply(); }
        function cancel(): void { root.cancel(); }
        function screen(name: string): void { root.begin(); root.setScreen(name); }
        function location(json: string): void { root.begin(); root.setLocation(JSON.parse(json)); }
    }
    Component.onCompleted: refresh()
}
