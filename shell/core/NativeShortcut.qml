// qmllint disable import unresolved-type
import QtQuick
import ".."
import Quickshell.Hyprland

// Quickshell's installed GlobalShortcut metadata omits its PostReloadHook
// dependency. Keep that upstream lint workaround local; runtime registrations
// and physical-key roundtrips are checked against Hyprland.
QtObject {
    id: shortcut
    property string appid: "poly-shell"
    property string name: ""
    property string description: ""
    signal activated()
    readonly property var registration: GlobalShortcut {
        appid: shortcut.appid
        name: shortcut.name
        description: shortcut.description
        onPressed: shortcut.activated()
    }
}
