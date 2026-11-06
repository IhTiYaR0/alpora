pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../logic/OverviewGeometry.js" as Geometry

Singleton {
    id: root

    // Reference Counting: only track window lifecycle when UI subscribers are active.
    property int subscribers: 0
    readonly property bool active: subscribers > 0
    property var cachedGroups: []

    // Multi-Compositor Detection (HAL)
    readonly property string compositor: {
        const sig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        if (sig && sig.length) return "hyprland";
        const sway = Quickshell.env("SWAYSOCK");
        if (sway && sway.length) return "sway";
        const niri = Quickshell.env("NIRI_SOCKET");
        if (niri && niri.length) return "niri";
        const mango = Quickshell.env("MANGOHUD");
        if (mango && mango.length) return "mango";
        const desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase();
        if (desktop.includes("sway")) return "sway";
        if (desktop.includes("niri")) return "niri";
        return "hyprland";
    }

    function subscribe(): void {
        subscribers++;
        if (subscribers === 1)
            refresh();
    }

    function unsubscribe(): void {
        subscribers = Math.max(0, subscribers - 1);
    }

    function key(value: string): string {
        return (value || "").toLowerCase().replace(/\.desktop$/, "").replace(/[^a-z0-9]/g, "");
    }

    function matches(entry: var, app: string): bool {
        if (!entry || !app) return false;
        return [entry.id, entry.startupClass, entry.icon].some(value => value && key(value) === key(app));
    }

    function computeGroups(): var {
        const favorites = AppCatalog.pinnedIds.map(id => AppCatalog.entries.find(e => e.id === id)).filter(e => !!e);
        const groups = favorites.map(e => ({id: e.id, entry: e, name: e.name, pinned: true, windows: [], active: false, urgent: false}));
        
        if (compositor === "hyprland" && Hyprland.toplevels) {
            Hyprland.toplevels.values.forEach(t => {
                const data = t.lastIpcObject;
                if (!data) return;
                const workspace = t.workspace ? {id: t.workspace.id, name: t.workspace.name || String(t.workspace.id)}
                    : {id: Number(data.workspace?.id || 0), name: String(data.workspace?.name || data.workspace?.id || "")};
                if (data.mapped === false || data.hidden || workspace.name.startsWith("special:")) return;
                const app = data.class || (t.wayland ? t.wayland.appId : "") || data.initialClass || "";
                const entry = favorites.find(e => matches(e, app)) || AppCatalog.entries.find(e => matches(e, app));
                const id = entry ? entry.id : "window:" + (app || t.address);
                let group = groups.find(g => g.id === id);
                if (!group) {
                    group = {id: id, entry: entry || null, name: entry ? entry.name : app || t.title || I18n.tr("dock.app_fallback"), pinned: false, windows: [], active: false, urgent: false};
                    groups.push(group);
                }
                group.windows.push({
                    address: "0x" + t.address.replace(/^0x/, ""),
                    title: t.title || group.name,
                    workspace: workspace,
                    active: t.activated,
                    urgent: t.urgent,
                    order: Number(data.focusHistoryID ?? 999)
                });
                group.active = group.active || t.activated;
                group.urgent = group.urgent || t.urgent;
            });
        }

        groups.forEach(g => g.windows.sort((a, b) => a.order - b.order));
        return groups.filter(g => g.pinned).concat(groups.filter(g => !g.pinned).sort((a, b) => a.name.localeCompare(b.name)));
    }

    function refresh(): void {
        if (compositor === "hyprland") {
            cachedGroups = computeGroups();
        } else if (compositor === "sway") {
            if (!swayWorker.running) swayWorker.running = true;
        } else if (compositor === "niri") {
            if (!niriWorker.running) niriWorker.running = true;
        } else {
            cachedGroups = computeGroups();
        }
    }

    readonly property var groups: active ? cachedGroups : (cachedGroups.length ? cachedGroups : computeGroups())

    function group(id: string): var {
        return groups.find(g => g.id === id) || null;
    }

    // Compositor Hardware Abstraction Layer (HAL)
    function focus(window: var): void {
        if (!window) return;
        if (compositor === "hyprland") {
            const command = Geometry.dispatch("focus", window.workspace, window.address, Hyprland.usingLua);
            if (command) Hyprland.dispatch(command);
        } else if (compositor === "sway") {
            Quickshell.execDetached(["swaymsg", "[con_id=" + (window.con_id || window.address) + "] focus"]);
        } else if (compositor === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(window.niri_id || window.address)]);
        } else {
            Quickshell.execDetached(["wtype", "-k", "Return"]);
        }
    }

    function close(window: var): void {
        if (!window) return;
        if (compositor === "hyprland") {
            const command = Geometry.dispatch("close", window.workspace, window.address, Hyprland.usingLua);
            if (command) Hyprland.dispatch(command);
        } else if (compositor === "sway") {
            Quickshell.execDetached(["swaymsg", "[con_id=" + (window.con_id || window.address) + "] kill"]);
        } else if (compositor === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", String(window.niri_id || window.address)]);
        }
    }

    function focusWorkspace(workspaceId: var): void {
        const id = String(workspaceId);
        if (compositor === "hyprland") {
            Hyprland.dispatch("workspace " + id);
        } else if (compositor === "sway") {
            Quickshell.execDetached(["swaymsg", "workspace", id]);
        } else if (compositor === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", id]);
        }
    }

    // Throttle / debounce updates only when UI subscribers are listening
    Connections {
        target: Hyprland
        enabled: root.active && root.compositor === "hyprland"
        function onRawEvent(event): void {
            if (/^(openwindow|closewindow|movewindow|activewindow|workspace|fullscreen|changefloatingmode|urgent)/.test(event.name)) {
                lazyRefresh.restart();
            }
        }
    }

    Timer {
        id: lazyRefresh
        interval: 40
        onTriggered: if (root.active) root.refresh()
    }

    // Sway Window Worker
    Process {
        id: swayWorker
        command: ["swaymsg", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return;
                try {
                    const tree = JSON.parse(text);
                    const favorites = AppCatalog.pinnedIds.map(id => AppCatalog.entries.find(e => e.id === id)).filter(e => !!e);
                    const groups = favorites.map(e => ({id: e.id, entry: e, name: e.name, pinned: true, windows: [], active: false, urgent: false}));
                    
                    function walk(node) {
                        if (!node) return;
                        if (node.app_id || node.window_properties?.class) {
                            const app = node.app_id || node.window_properties?.class || "";
                            const entry = favorites.find(e => root.matches(e, app)) || AppCatalog.entries.find(e => root.matches(e, app));
                            const id = entry ? entry.id : "window:" + (app || String(node.id));
                            let g = groups.find(item => item.id === id);
                            if (!g) {
                                g = {id: id, entry: entry || null, name: entry ? entry.name : app || node.name || I18n.tr("dock.app_fallback"), pinned: false, windows: [], active: false, urgent: false};
                                groups.push(g);
                            }
                            g.windows.push({address: String(node.id), con_id: node.id, title: node.name || g.name, active: !!node.focused, urgent: !!node.urgent, order: 0});
                            g.active = g.active || !!node.focused;
                            g.urgent = g.urgent || !!node.urgent;
                        }
                        if (node.nodes) node.nodes.forEach(walk);
                        if (node.floating_nodes) node.floating_nodes.forEach(walk);
                    }
                    walk(tree);
                    root.cachedGroups = groups.filter(g => g.pinned).concat(groups.filter(g => !g.pinned).sort((a, b) => a.name.localeCompare(b.name)));
                } catch (e) { console.error("Sway tree parse error:", e); }
            }
        }
    }

    // Niri Window Worker
    Process {
        id: niriWorker
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return;
                try {
                    const list = JSON.parse(text);
                    const favorites = AppCatalog.pinnedIds.map(id => AppCatalog.entries.find(e => e.id === id)).filter(e => !!e);
                    const groups = favorites.map(e => ({id: e.id, entry: e, name: e.name, pinned: true, windows: [], active: false, urgent: false}));
                    (Array.isArray(list) ? list : []).forEach(w => {
                        const app = w.app_id || "";
                        const entry = favorites.find(e => root.matches(e, app)) || AppCatalog.entries.find(e => root.matches(e, app));
                        const id = entry ? entry.id : "window:" + (app || String(w.id));
                        let g = groups.find(item => item.id === id);
                        if (!g) {
                            g = {id: id, entry: entry || null, name: entry ? entry.name : app || w.title || I18n.tr("dock.app_fallback"), pinned: false, windows: [], active: false, urgent: false};
                            groups.push(g);
                        }
                        g.windows.push({address: String(w.id), niri_id: w.id, title: w.title || g.name, active: !!w.is_focused, urgent: false, order: 0});
                        g.active = g.active || !!w.is_focused;
                    });
                    root.cachedGroups = groups.filter(g => g.pinned).concat(groups.filter(g => !g.pinned).sort((a, b) => a.name.localeCompare(b.name)));
                } catch (e) { console.error("Niri windows parse error:", e); }
            }
        }
    }
}
