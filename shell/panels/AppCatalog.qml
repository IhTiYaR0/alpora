pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property var categories: [
        { id: "Network", name: I18n.tr("app.category.Network"), icon: "wifi" },
        { id: "AudioVideo", name: I18n.tr("app.category.AudioVideo"), icon: "music" },
        { id: "Office", name: I18n.tr("app.category.Office"), icon: "note" },
        { id: "Graphics", name: I18n.tr("app.category.Graphics"), icon: "sun" },
        { id: "Utility", name: I18n.tr("app.category.Utility"), icon: "terminal" },
        { id: "System", name: I18n.tr("app.category.System"), icon: "settings" },
        { id: "Development", name: I18n.tr("app.category.Development"), icon: "terminal" },
        { id: "Game", name: I18n.tr("app.category.Game"), icon: "plus" }
    ]
    readonly property var entries: DesktopEntries.applications.values.filter(entry => !entry.noDisplay).slice().sort((a, b) => a.name.localeCompare(b.name))
    property var pinnedIds: []
    property bool initialized: false
    property string error: ""
    readonly property string iconTheme: Session.appearance.iconTheme || "Poly-Alpine"
    property string cachedTheme: ""
    property var iconFiles: ({})
    function iconSource(entry: var): string {
        if (cachedTheme === iconTheme && iconFiles[entry.icon]) return iconFiles[entry.icon];
        return entry.icon.startsWith("/") ? "file://" + entry.icon : Quickshell.iconPath(entry.icon, "application-x-executable");
    }
    readonly property var favorites: entries.filter(entry => pinnedIds.includes(entry.id))
    function categoryName(entry: var): string {
        const category = categories.find(item => entry.categories.includes(item.id));
        return category ? category.name : I18n.tr("app.category.default");
    }
    function results(query: string, category: string): var {
        const words = query.trim().toLocaleLowerCase().split(/\s+/).filter(word => word.length);
        return entries.filter(entry => {
            const text = [entry.name, entry.genericName, entry.comment, entry.id].concat(entry.keywords).join(" ").toLocaleLowerCase();
            return (!category || entry.categories.includes(category)) && words.every(word => text.includes(word));
        }).sort((a, b) => {
            const q = query.trim().toLocaleLowerCase();
            const rank = entry => entry.name.toLocaleLowerCase() === q ? 0 : entry.name.toLocaleLowerCase().startsWith(q) ? 1 : 2;
            return rank(a) - rank(b) || a.name.localeCompare(b.name);
        });
    }
    function seed(): void {
        if (initialized || !entries.length) return;
        const preferred = ["kitty", "foot", "org.gnome.Nautilus", "firefox", "com.google.Chrome", "code"];
        pinnedIds = preferred.map(id => entries.find(entry => entry.id === id || entry.id === id + ".desktop")).filter(entry => !!entry).slice(0, 6).map(entry => entry.id);
        initialized = true;
    }
    function togglePin(id: string): void {
        pinnedIds = pinnedIds.includes(id) ? pinnedIds.filter(item => item !== id) : pinnedIds.concat([id]);
        preferences.setText(JSON.stringify({ version: 1, pinned: pinnedIds }));
    }
    onEntriesChanged: { Qt.callLater(seed); iconDelay.restart(); }
    onIconThemeChanged: { iconFiles = ({}); iconDelay.restart(); }
    Component.onCompleted: { Qt.callLater(seed); iconDelay.restart(); }
    Connections {
        target: Session
        function onLoadedChanged(): void { if (Session.loaded) iconDelay.restart(); }
    }
    Timer {
        id: iconDelay
        interval: 120
        onTriggered: {
            if (!Session.loaded || !root.entries.length) return;
            if (iconBuilder.running) { restart(); return; }
            iconBuilder.theme = root.iconTheme;
            iconBuilder.command = ["python3", Quickshell.env("POLY_SHELL_ASSETS") + "/../scripts/build-app-icon-cache", root.iconTheme].concat(root.entries.map(entry => entry.icon));
            iconBuilder.running = true;
        }
    }
    Process {
        id: iconBuilder
        property string theme: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (iconBuilder.theme !== root.iconTheme) return;
                try { root.iconFiles = JSON.parse(text); root.cachedTheme = iconBuilder.theme; }
                catch (_) { console.warn("Invalid optional icon cache result"); }
            }
        }
    }
    FileView {
        id: preferences
        path: (Quickshell.env("POLY_SHELL_STATE") || "").replace(/session\.json$/, "launcher.json")
        printErrors: false
        onLoaded: {
            try {
                const value = JSON.parse(text());
                if (!Array.isArray(value.pinned) || !value.pinned.every(id => typeof id === "string")) throw new Error(I18n.tr("app.invalid_pinned"));
                root.pinnedIds = value.pinned;
                root.initialized = true;
            } catch (_) { root.error = I18n.tr("app.favorites_error"); root.seed(); }
        }
        onLoadFailed: root.seed()
        onSaveFailed: root.error = I18n.tr("app.favorites_save_error")
    }
}
