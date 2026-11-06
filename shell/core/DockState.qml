pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../logic/OverviewGeometry.js" as Geometry

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
    // Delegate window tracking to WindowTracker (Reference Counting subscriber model)
    readonly property var groups: WindowTracker.groups
    function group(id: string): var { return WindowTracker.group(id); }
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
        launchingId = id; launchCooldown.restart(); item.entry.execute();
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
