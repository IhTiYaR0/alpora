pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "OverviewGeometry.js" as Geometry

Singleton {
    id: root
    property string launchingId: ""
    property string pendingFocus: ""
    function dismissDockLauncher(): bool {
        if (BarState.selection.name !== "launcher" || BarState.selection.origin !== "dock") return false;
        BarState.dismiss();
        return true;
    }
    function key(value: string): string { return value.toLowerCase().replace(/\.desktop$/, "").replace(/[^a-z0-9]/g, ""); }
    function matches(entry: var, app: string): bool {
        return [entry.id, entry.startupClass, entry.icon].some(value => value && key(value) === key(app));
    }
    // Prefer pinned aliases (e.g. com.google.Chrome / google-chrome), so a
    // running application never duplicates its existing favorite in the dock.
    readonly property var groups: {
        const favorites = AppCatalog.pinnedIds.map(id => AppCatalog.entries.find(e => e.id === id)).filter(e => !!e);
        const groups = favorites.map(e => ({id: e.id, entry: e, name: e.name, pinned: true, windows: [], active: false, urgent: false}));
        Hyprland.toplevels.values.forEach(t => {
            const data = t.lastIpcObject;
            const workspace = t.workspace ? {id: t.workspace.id, name: t.workspace.name || String(t.workspace.id)}
                : {id: Number(data.workspace?.id || 0), name: String(data.workspace?.name || data.workspace?.id || "")};
            if (data.mapped === false || data.hidden || workspace.name.startsWith("special:")) return;
            const app = data.class || (t.wayland ? t.wayland.appId : "") || data.initialClass || "";
            const entry = favorites.find(e => matches(e, app)) || AppCatalog.entries.find(e => matches(e, app));
            const id = entry ? entry.id : "window:" + (app || t.address);
            let group = groups.find(g => g.id === id);
            if (!group) {
                group = {id: id, entry: entry || null, name: entry ? entry.name : app || t.title || "Приложение", pinned: false, windows: [], active: false, urgent: false};
                groups.push(group);
            }
            group.windows.push({address: "0x" + t.address.replace(/^0x/, ""), title: t.title || group.name,
                workspace: workspace,
                active: t.activated, urgent: t.urgent, order: Number(data.focusHistoryID ?? 999)});
            group.active = group.active || t.activated;
            group.urgent = group.urgent || t.urgent;
        });
        groups.forEach(g => g.windows.sort((a, b) => a.order - b.order));
        return groups.filter(g => g.pinned).concat(groups.filter(g => !g.pinned).sort((a, b) => a.name.localeCompare(b.name)));
    }
    function group(id: string): var { return groups.find(g => g.id === id) || null; }
    function iconSource(item: var): string {
        return item.entry ? AppCatalog.iconSource(item.entry) : Quickshell.iconPath(item.name, "application-x-executable");
    }
    function focus(window: var): void {
        if (!window || !Hyprland.toplevels.values.some(t => "0x" + t.address.replace(/^0x/, "") === window.address)) return;
        const command = Geometry.dispatch("focus", window.workspace, window.address, Hyprland.usingLua);
        if (command) {
            if (dismissDockLauncher()) { pendingFocus = command; focusDelay.restart(); }
            else Hyprland.dispatch(command);
        }
    }
    function launch(id: string): void {
        const item = group(id);
        if (!item || !item.entry || launchingId === id) return;
        dismissDockLauncher();
        launchingId = id; launchCooldown.restart(); Session.launchEntry(item.entry);
    }
    function activate(id: string): void {
        const item = group(id);
        if (!item) return;
        if (!item.windows.length) { launch(id); return; }
        cycle(id, 1);
    }
    function cycle(id: string, direction: int): void {
        const item = group(id);
        if (!item || !item.windows.length) return;
        const index = item.windows.findIndex(w => w.active);
        focus(item.windows[index < 0 ? 0 : (index + direction + item.windows.length) % item.windows.length]);
    }
    function togglePin(id: string): void {
        const item = group(id);
        if (item && item.entry) AppCatalog.togglePin(item.entry.id);
    }
    Timer { id: launchCooldown; interval: 1200; onTriggered: root.launchingId = "" }
    Timer { id: focusDelay; interval: 30; onTriggered: { const command = root.pendingFocus; root.pendingFocus = ""; if (command) Hyprland.dispatch(command); } }
    IpcHandler {
        target: "dock"
        function status(): string {
            return JSON.stringify({launching: root.launchingId, groups: root.groups.map(g => ({id: g.id, name: g.name,
                pinned: g.pinned, active: g.active, urgent: g.urgent, windows: g.windows.map(w => ({address: w.address, workspace: w.workspace.id, active: w.active}))}))});
        }
    }
}
