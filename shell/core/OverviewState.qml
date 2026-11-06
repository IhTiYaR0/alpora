pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../logic/OverviewGeometry.js" as Geometry
import "../logic/OverviewGesture.js" as Gesture

Singleton {
    id: root
    property bool opened: false
    property real progress: 0
    property bool gestureActive: false
    property string gestureId: ""
    property real gestureOrigin: 0
    property bool gestureWasOpen: false
    property real gestureDistance: 0
    property real gestureTime: 0
    property real gestureVelocity: 0
    property string screenName: ""
    property int selected: 0
    property var clients: []
    property bool dragging: false
    property bool refreshPending: false
    property string error: ""
    property string response: ""
    property string action: ""
    readonly property bool busy: writer.running || actionDelay.running
    readonly property var workspaces: {
        const actual = Hyprland.workspaces.values;
        const entries = [];
        for (let id = 1; id <= 10; id++) {
            const ws = actual.find(w => w.id === id);
            entries.push({id: id, name: ws ? ws.name : String(id), monitor: ws && ws.monitor ? ws.monitor.name : root.screenName});
        }
        actual.forEach(ws => {
            if ((ws.id > 10 || ws.id < 0) && !ws.name.startsWith("special:"))
                entries.push({id: ws.id, name: ws.name, monitor: ws.monitor ? ws.monitor.name : root.screenName});
        });
        return entries;
    }
    readonly property string wallpaper: {
        if (TimelineState.active && TimelineState.loaded) {
            const stop = TimelineState.stops[TimelineState.segment.lower];
            return stop ? stop.image : "";
        }
        const theme = ThemeState.items.find(t => t.id === ThemeState.baseId);
        return theme ? theme.image : "";
    }
    readonly property string upperWallpaper: {
        const stop = TimelineState.active && TimelineState.loaded ? TimelineState.stops[TimelineState.segment.upper] : null;
        return stop ? stop.image : "";
    }
    function toggle(screen: string): void {
        if (opened) { close(); return; }
        open(screen);
    }
    function open(screen: string): void {
        if (opened) return;
        if (busy || !Session.loaded || !Quickshell.screens.some(s => s.name === screen)) return;
        screenName = screen;
        selected = Math.max(0, workspaces.findIndex(w => w.id === Session.focusedWorkspace));
        error = "";
        BarState.dismiss();
        opened = true;
        refresh();
        animateTo(1, Motion.openMs * 1.7);
    }
    function close(): void {
        gestureActive = false; gestureId = "";
        opened = false; dragging = false; actionDelay.stop();
        animateTo(0, Motion.closeMs * 1.25);
    }
    function animateTo(value: real, duration: real): void {
        settling.stop();
        if (Motion.reduced || Math.abs(progress - value) < 0.0001) { progress = value; return; }
        settling.to = value; settling.duration = Math.max(1, Math.round(duration)); settling.start();
    }
    NumberAnimation { id: settling; target: root; property: "progress"; easing.type: Easing.OutCubic }
    function swipe(data: string): void {
        const e = Gesture.parse(data);
        if (!e) return;
        if (e.phase === "start") {
            if (busy || dragging || !Session.loaded || (e.direction < 0 && progress < 0.001 && !opened)) return;
            const screen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens[0]?.name || "");
            if (!Quickshell.screens.some(s => s.name === screen)) return;
            settling.stop();
            gestureOrigin = progress; gestureWasOpen = opened;
            gestureId = e.id; gestureDistance = 0; gestureTime = e.time; gestureVelocity = 0;
            screenName = screen;
            if (!opened) {
                selected = Math.max(0, workspaces.findIndex(w => w.id === Session.focusedWorkspace));
                error = ""; BarState.dismiss(); opened = true; refresh();
            }
            gestureActive = true;
        }
        if (!gestureActive || e.id !== gestureId || e.time < gestureTime) return;
        if (e.phase !== "finish") {
            const elapsed = e.time - gestureTime;
            if (elapsed > 0) {
                const next = (e.distance - gestureDistance) / 300 / elapsed;
                gestureVelocity = elapsed > 100 ? next : gestureVelocity * 0.35 + next * 0.65;
            }
            gestureDistance = e.distance; gestureTime = e.time;
            // Direct assignment: a held finger holds the reveal at exactly this point.
            progress = Gesture.progress(gestureOrigin, e.distance);
            return;
        }
        const target = Gesture.destination(progress, gestureVelocity, e.time - gestureTime, e.cancelled, gestureWasOpen);
        gestureActive = false; gestureId = ""; opened = target === 1;
        animateTo(target, Math.max(70, Math.min(240, Math.abs(target - progress) * Motion.openMs)));
    }
    function refresh(): void {
        if (!opened) return;
        if (reader.running || dragging) { refreshPending = true; return; }
        refreshPending = false;
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        reader.running = true;
    }
    function windows(id: int): var {
        const ws = workspaces.find(w => w.id === id);
        const mon = ws ? Hyprland.monitors.values.find(m => m.name === ws.monitor) : null;
        return clients.filter(c => c.mapped && !c.hidden && c.workspace && (c.workspace.id === id || (c.pinned && mon && c.monitor === mon.id)))
            .sort((a, b) => Number(a.floating) - Number(b.floating) || b.focusHistoryID - a.focusHistoryID);
    }
    function monitor(name: string): var {
        const found = Hyprland.monitors.values.find(m => m.name === name);
        return found ? found.lastIpcObject : {};
    }
    function capture(address: string): var {
        const found = Hyprland.toplevels.values.find(t => t.address.replace(/^0x/, "") === address.replace(/^0x/, ""));
        return found ? found.wayland : null;
    }
    function appIcon(client: var): string {
        const ident = String(client.class || "").toLowerCase();
        const entry = AppCatalog.entries.find(e => e.id.replace(/\.desktop$/, "").toLowerCase() === ident
            || (e.startupClass && e.startupClass.toLowerCase() === ident));
        return entry ? AppCatalog.iconSource(entry) : Quickshell.iconPath(client.class || "", "application-x-executable");
    }
    function windowLabel(count: int): string {
        const end = count % 10, tens = count % 100;
        const key = (end === 1 && tens !== 11) ? "overview.window_label_1"
            : (end >= 2 && end <= 4 && (tens < 12 || tens > 14)) ? "overview.window_label_few"
            : "overview.window_label_many";
        return I18n.trWith(key, {count: count});
    }
    function navigate(delta: int): void { selected = Math.max(0, Math.min(workspaces.length - 1, selected + delta)); }
    function run(next: string, id: int, address: string): void {
        if (busy || !opened || gestureActive) return;
        const ws = workspaces.find(w => w.id === id);
        const client = clients.find(c => c.address === address && c.mapped && !c.hidden);
        if (!ws || (next !== "workspace" && !client)) return;
        if (next === "move" && client.pinned) { error = I18n.tr("overview.unpin_first"); return; }
        const command = Geometry.dispatch(next, ws, address, Hyprland.usingLua);
        if (!command) return;
        action = next; response = ""; error = "";
        writer.command = ["hyprctl", "dispatch", command];
        if (next === "move") writer.running = true;
        else { close(); actionDelay.start(); }
    }
    // Relinquish the layer keyboard grab before focusing an application.
    Timer { id: actionDelay; interval: 30; onTriggered: writer.running = true }
    Timer { id: refreshDelay; interval: 100; onTriggered: root.refresh() }
    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (event.name === "custom" && event.data.startsWith("poly-overview-swipe,")) root.swipe(event.data);
            if (root.gestureActive && event.name === "configreloaded") root.close();
            if (root.opened && /^(openwindow|closewindow|movewindow|moveworkspace|workspace|createworkspace|destroyworkspace|activewindow|focusedmon|fullscreen|changefloatingmode|pin|monitor|configreloaded)/.test(event.name)) refreshDelay.restart();
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            if (root.opened && !Quickshell.screens.some(s => s.name === root.screenName)) root.close();
        }
    }
    Connections { target: ClockState; function onPreparingForSleep(): void { root.close(); } }
    Connections { target: BarState; function onSelectionChanged(): void { if (BarState.selection.name) root.close(); } }
    Process {
        id: reader
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!Array.isArray(result)) throw new Error("invalid clients");
                    if (!root.dragging) root.clients = result;
                    else root.refreshPending = true;
                } catch (_) { root.error = I18n.tr("overview.error_windows_list"); }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) root.error = I18n.tr("overview.hyprland_no_response");
            if (root.refreshPending && !root.dragging) refreshDelay.restart();
        }
    }
    Process {
        id: writer
        stdout: StdioCollector { onStreamFinished: root.response = text.trim() }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.error = text.trim() }
        onExited: exitCode => {
            if (exitCode !== 0 || root.response !== "ok") {
                root.error = root.error || root.response || I18n.tr("overview.error_action");
                root.opened = true;
                root.animateTo(1, Motion.openMs);
            }
            refreshDelay.restart();
        }
    }
    onDraggingChanged: if (!dragging && refreshPending) refreshDelay.restart()
    IpcHandler {
        target: "overview"
        function toggle(): void { root.toggle(Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens[0]?.name || "")); }
        function open(): void { root.open(Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens[0]?.name || "")); }
        function close(): void { root.close(); }
        function sources(): string { return JSON.stringify(Hyprland.toplevels.values.map(t => ({address: t.address, wayland: !!t.wayland}))); }
        function status(): string {
            return JSON.stringify({opened: root.opened, progress: root.progress, gestureActive: root.gestureActive, gestureId: root.gestureId,
                screen: root.screenName, selected: root.selected, dragging: root.dragging, busy: root.busy,
                workspaces: root.workspaces.map(w => ({id: w.id, name: w.name, monitor: w.monitor, windows: root.windows(w.id).length})),
                clients: root.clients.length, error: root.error});
        }
    }
}
