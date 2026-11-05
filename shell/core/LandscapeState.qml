pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool enabled: false
    property bool loaded: false
    property string error: ""
    signal themeRequested(string screenName, real x, real y)
    function setEnabled(value: bool): void {
        enabled = value;
        preferences.setText(JSON.stringify({version: 1, enabled: value}));
    }
    FileView {
        id: preferences
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/poly-shell/landscape.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const value = JSON.parse(text());
                if (value.version !== 1 || typeof value.enabled !== "boolean") throw new Error("invalid preferences");
                root.enabled = value.enabled;
                root.error = "";
            } catch (_) { root.error = I18n.tr("landscape.error_read"); }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
        onSaveFailed: root.error = I18n.tr("landscape.error_save")
    }
    IpcHandler {
        target: "landscape"
        function status(): string { return JSON.stringify({enabled: root.enabled, loaded: root.loaded, theme: Session.appearance.id, error: root.error}); }
        function enable(value: bool): void { root.setEnabled(value); }
        function toggle(): void { root.setEnabled(!root.enabled); }
    }
}
