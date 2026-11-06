pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import "../logic/AppearanceCatalog.js" as Catalog

Singleton {
    id: root
    property var defaults: Catalog.defaults
    property string element: "panel"
    property var base: ({})
    property var draft: ({})
    property bool loaded: false
    property string error: ""
    property string message: ""
    property var result: null
    readonly property bool busy: writer.running
    readonly property bool dirty: loaded && Object.keys(defaults).some(key => draft[key] !== base[key])

    function begin(): void {
        if (busy || (loaded && dirty)) return;
        base = Object.assign({}, Session.visual);
        draft = Object.assign({}, base);
        loaded = true;
    }
    function edit(key: string, value: var): void {
        if (busy || !Object.prototype.hasOwnProperty.call(defaults, key)) return;
        const next = Object.assign({}, draft);
        next[key] = value;
        draft = next;
        message = ""; error = "";
    }
    function resetElement(): void {
        if (busy) return;
        const next = Object.assign({}, draft);
        Catalog.keys(element).forEach(key => next[key] = defaults[key]);
        draft = next; error = ""; message = I18n.tr("appearance.reset_element_msg");
    }
    function reset(): void {
        if (busy) return;
        draft = Object.assign({}, defaults);
        message = I18n.tr("appearance.preset_chosen_msg");
        error = "";
    }
    function cancel(): void {
        if (busy) return;
        loaded = false; begin(); error = ""; message = "";
    }
    function apply(): void {
        if (busy || !dirty) return;
        result = null; error = ""; message = "";
        writer.command = [Session.controller, "appearance", "apply",
            JSON.stringify({values: draft, expected: base})];
        writer.running = true;
    }
    Process {
        id: writer
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.result = JSON.parse(text); }
                catch (failure) { root.error = I18n.tr("appearance.error_read_result"); }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = text.trim().replace(/^poly-shell: /, "")
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && exitStatus === 0 && root.result && root.result.saved) {
                root.base = Object.assign({}, root.result.values);
                root.draft = Object.assign({}, root.result.values);
                root.defaults = root.result.defaults;
                root.error = "";
                root.message = I18n.tr("appearance.saved_msg");
            } else if (!root.error) root.error = I18n.tr("appearance.error_apply_msg");
        }
    }
    Connections {
        target: Session
        function onVisualChanged(): void {
            if (root.loaded && !root.dirty && !root.busy) root.begin();
        }
    }
    IpcHandler {
        target: "appearance"
        function edit(key: string, jsonValue: string): void { root.begin(); root.edit(key, JSON.parse(jsonValue)); }
        function select(element: string): void { if (Catalog.elements.some(e => e.id === element)) root.element = element; }
        function resetElement(): void { root.resetElement(); }
        function cancel(): void { root.cancel(); }
        function reset(): void { root.reset(); }
        function apply(): void { root.apply(); }
        function status(): string {
            return JSON.stringify({element: root.element, loaded: root.loaded, dirty: root.dirty, busy: root.busy,
                base: root.base, draft: root.draft, effective: Session.visual,
                error: root.error, message: root.message});
        }
    }
}
