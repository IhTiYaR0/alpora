pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property bool opened: false
    property string screen: ""
    property string currentMode: "extend"
    property var monitors: []

    readonly property bool hasExternal: monitors.length > 1

    function open(screenName: string): void {
        screen = screenName || (Quickshell.screens.length ? Quickshell.screens[0].name : "");
        refreshMonitors();
        opened = true;
    }

    function close(): void {
        opened = false;
    }

    function toggle(screenName: string): void {
        if (opened) close();
        else open(screenName);
    }

    function refreshMonitors(): void {
        if (!monitorQuery.running) monitorQuery.running = true;
    }

    Process {
        id: monitorQuery
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text);
                } catch (_) {
                    root.monitors = [];
                }
            }
        }
    }

    function applyMode(mode: string): void {
        currentMode = mode;
        AudioFeedback.playTock();

        if (monitors.length < 2) {
            closeTimer.restart();
            return;
        }

        const internal = monitors.find(m => /^(eDP|LVDS|DSI)/i.test(m.name)) || monitors[0];
        const external = monitors.find(m => m.name !== internal.name) || (monitors.length > 1 ? monitors[1] : null);

        if (!external) {
            closeTimer.restart();
            return;
        }

        if (mode === "internal") {
            IpcClient.exec(["hyprctl", "keyword", "monitor", external.name + ",disable"]);
            IpcClient.exec(["hyprctl", "keyword", "monitor", internal.name + ",preferred,auto,1"]);
        } else if (mode === "mirror") {
            IpcClient.exec(["hyprctl", "keyword", "monitor", external.name + ",preferred,auto,1,mirror," + internal.name]);
            IpcClient.exec(["hyprctl", "keyword", "monitor", internal.name + ",preferred,auto,1"]);
        } else if (mode === "extend") {
            IpcClient.exec(["hyprctl", "keyword", "monitor", internal.name + ",preferred,0x0,1"]);
            IpcClient.exec(["hyprctl", "keyword", "monitor", external.name + ",preferred,auto,1"]);
        } else if (mode === "external") {
            IpcClient.exec(["hyprctl", "keyword", "monitor", internal.name + ",disable"]);
            IpcClient.exec(["hyprctl", "keyword", "monitor", external.name + ",preferred,0x0,1"]);
        }

        closeTimer.restart();
    }

    Timer {
        id: closeTimer
        interval: 350
        onTriggered: root.close()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (["monitoradded", "monitoraddedv2", "monitorremoved"].includes(event.name)) {
                root.refreshMonitors();
            }
        }
    }

    Component.onCompleted: refreshMonitors()

    IpcHandler {
        target: "display-project"
        function open(): void { root.open(""); }
        function close(): void { root.close(); }
        function toggle(): void { root.toggle(""); }
        function setMode(mode: string): void { root.applyMode(mode); }
        function status(): string {
            return JSON.stringify({
                opened: root.opened,
                mode: root.currentMode,
                monitors: root.monitors.length,
                hasExternal: root.hasExternal
            });
        }
    }
}
