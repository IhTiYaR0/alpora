pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var items: []
    property string selectedId: "alpine"
    property string baseId: "alpine"
    property bool automatic: true
    property bool baseAutomatic: true
    property bool loaded: false
    property string error: ""
    property string message: ""
    property var response: null
    property string action: ""
    property bool wallpaperTransitioning: false
    Timer { id: wallpaperHandoff; interval: 1500; onTriggered: root.wallpaperTransitioning = false }
    readonly property bool busy: worker.running
    readonly property bool dirty: loaded && (selectedId !== baseId || automatic !== baseAutomatic)
    readonly property var selected: items.find(item => item.id === selectedId) || null
    function refresh(): void { if (!busy) request("list", {}); }
    function select(ident: string): void { if (!busy && items.some(item => item.id === ident)) { selectedId = ident; error = ""; message = ""; } }
    function cancel(): void { if (!busy) { selectedId = baseId; automatic = baseAutomatic; error = ""; message = ""; } }
    function apply(): void { if (!busy && selected && dirty) request("apply", {id: selectedId, colorsFromWallpaper: automatic}); }
    function importImage(path: string): void { if (!busy) request("import", {image: path}); }
    function request(next: string, payload: var): void {
        if (next === "apply") {
            wallpaperHandoff.stop();
            root.wallpaperTransitioning = payload.id === "timeline" && !!payload.transition && !Motion.reduced;
        }
        root.action = next; root.response = null; root.error = ""; root.message = "";
        worker.command = [Session.controller, "theme", next, JSON.stringify(payload)];
        worker.running = true;
    }
    Process {
        id: worker
        stdout: StdioCollector { onStreamFinished: { try { root.response = JSON.parse(text); } catch (_) { root.error = I18n.tr("theme.error_collection"); } } }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.error = text.trim().replace(/^poly-shell: /, "") }
        onExited: exitCode => {
            if (exitCode !== 0 || !root.response) { root.wallpaperTransitioning = false; if (!root.error) root.error = I18n.tr("theme.error_action"); return; }
            if (root.wallpaperTransitioning) wallpaperHandoff.restart();
            const keepDraft = root.loaded && root.dirty && root.action === "list";
            root.items = root.response.items;
            root.baseId = root.response.selected;
            root.baseAutomatic = root.response.colorsFromWallpaper;
            if (!keepDraft) { root.selectedId = root.response.imported || root.baseId; root.automatic = root.baseAutomatic; }
            root.loaded = true;
            if (root.action === "apply") root.message = I18n.tr("theme.applied");
            if (root.action === "import") root.message = I18n.tr("theme.imported");
        }
    }
    Component.onCompleted: refresh()
    IpcHandler {
        target: "themes"
        function select(id: string): void { root.select(id); }
        function apply(): void { root.apply(); }
        function cancel(): void { root.cancel(); }
        function refresh(): void { root.refresh(); }
        function status(): string { return JSON.stringify({selected: root.selectedId, saved: root.baseId, automatic: root.automatic, dirty: root.dirty, busy: root.busy, count: root.items.length, error: root.error, message: root.message}); }
    }
}
