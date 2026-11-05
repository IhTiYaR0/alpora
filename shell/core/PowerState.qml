pragma Singleton
import QtQuick
import ".."
import Quickshell

Singleton {
    id: root

    property bool active: false
    property string targetScreen: ""

    function open(screen: string): void {
        targetScreen = screen || (Quickshell.screens.length ? Quickshell.screens[0].name : "");
        active = true;
    }

    function close(): void {
        active = false;
    }

    function toggle(screen: string): void {
        if (active) close();
        else open(screen);
    }

    function execute(action: string): void {
        close();
        if (action === "lock") {
            const home = Quickshell.env("HOME") || "";
            IpcClient.exec(["hyprlock", "-c", home + "/.config/hypr/hyprlock.conf"]);
        } else if (action === "suspend") {
            IpcClient.exec(["systemctl", "suspend"]);
        } else if (action === "reboot") {
            IpcClient.exec(["systemctl", "reboot"]);
        } else if (action === "poweroff") {
            IpcClient.exec(["systemctl", "poweroff"]);
        } else if (action === "logout") {
            const comp = WindowTracker.compositor;
            if (comp === "sway") IpcClient.exec(["swaymsg", "exit"]);
            else if (comp === "niri") IpcClient.exec(["niri", "msg", "action", "quit"]);
            else IpcClient.exec(["hyprctl", "dispatch", "exit"]);
        }
    }
}
