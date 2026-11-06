pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool enabled: true
    property bool lively: true
    property bool flights: true
    property bool loaded: false
    property string error: ""
    function save(): void {
        preferences.setText(JSON.stringify({version: 1, enabled: enabled, lively: lively, flights: flights}));
    }
    function setEnabled(value: bool): void { enabled = value; save(); }
    function setLively(value: bool): void { lively = value; save(); }
    function setFlights(value: bool): void { flights = value; save(); }
    FileView {
        id: preferences
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/poly-shell/companion.json"
        printErrors: false; watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                if (saved.version !== 1 || typeof saved.enabled !== "boolean" || typeof saved.lively !== "boolean") throw new Error("Invalid companion preferences");
                if (saved.flights !== undefined && typeof saved.flights !== "boolean") throw new Error("Invalid flight preference");
                root.enabled = saved.enabled; root.lively = saved.lively; root.flights = saved.flights !== false; root.error = "";
            } catch (_) { root.error = I18n.tr("companion.error_read"); }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
        onSaveFailed: root.error = I18n.tr("companion.error_save")
    }
    IpcHandler {
        target: "companion"
        function status(): string { return JSON.stringify({enabled: root.enabled, lively: root.lively, flights: root.flights, loaded: root.loaded, error: root.error}); }
        function enable(value: bool): void { root.setEnabled(value); }
        function lively(value: bool): void { root.setLively(value); }
        function flights(value: bool): void { root.setFlights(value); }
    }
}
