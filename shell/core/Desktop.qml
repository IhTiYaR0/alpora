pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    property var data: ({ brightness: 100, brightnessAvailable: false, dnd: false, dndAvailable: false, nightLight: false, nightLightAvailable: false, powerProfilesAvailable: false, powerProfiles: [], powerProfile: "", powerDegraded: "", airplaneAvailable: false, airplane: false, airplaneHardwareBlocked: false, airplaneManaged: false, hotspotAvailable: false, hotspot: false, hotspotSsid: "Alpora-Hotspot", hotspotPassword: "", hotspotClients: 0, gameMode: false, phoneAvailable: false })
    property string error: ""
    readonly property bool changingSettings: IpcClient.busy

    readonly property var validActions: ["status", "brightness", "dnd", "nightlight", "bluetooth", "power-profile", "airplane", "hotspot", "wifi-connect", "ui-scale", "touchpad", "font", "caffeine", "gamemode", "phone"]

    function request(action: string, value: string): void {
        if (!validActions.includes(action)) {
            console.warn("Desktop.request: rejected unknown action:", action);
            return;
        }
        if (action === "brightness") {
            const num = parseInt(value, 10);
            if (isNaN(num) || num < 5 || num > 100) {
                console.warn("Desktop.request: invalid brightness value:", value);
                return;
            }
        } else if (action === "bluetooth" || action === "airplane") {
            if (value !== "on" && value !== "off" && value !== "") {
                console.warn("Desktop.request: invalid toggle value for " + action + ":", value);
                return;
            }
        } else if (action === "hotspot") {
            if (value !== "on" && value !== "off" && value !== "toggle" && value !== "" && !value.trim().startsWith("{")) {
                console.warn("Desktop.request: invalid hotspot value:", value);
                return;
            }
        } else if (action === "wifi-connect") {
            if (!value.trim().startsWith("{")) {
                console.warn("Desktop.request: invalid wifi-connect payload:", value);
                return;
            }
        } else if (action === "power-profile") {
            if (value !== "power-saver" && value !== "balanced" && value !== "performance") {
                console.warn("Desktop.request: invalid power profile:", value);
                return;
            }
        }

        const args = (value && value.length > 0) ? [action, value] : [action];
        IpcClient.send("control", args, (res, err) => {
            if (err) {
                root.error = err.replace(/^poly-shell:\s*/, "");
                console.error("Desktop control error:", root.error);
            } else if (res && typeof res === "object") {
                root.data = res;
                root.error = "";
            }
        });
    }

    // External backlight keys or mako commands are reflected while the popup is open.
    // Closed panels perform no periodic work.
    Timer {
        interval: 2500
        repeat: true
        running: Session.quickSettingsOpen
        onTriggered: if (!IpcClient.busy) root.request("status", "")
    }

    Component.onCompleted: root.request("status", "")
}
