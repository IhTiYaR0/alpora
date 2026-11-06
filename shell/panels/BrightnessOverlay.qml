pragma ComponentBehavior: Bound
import QtQuick
import ".."
import Quickshell
import Quickshell.Wayland

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root
    required property var modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore; exclusiveZone: 0
    color: "transparent"

    readonly property real brightness: Desktop.data ? (Desktop.data.brightness || 100) : 100
    readonly property bool isSoftware: Desktop.data ? (Desktop.data.brightnessType === "software") : false
    readonly property real dimRatio: Math.max(0, Math.min(0.85, (100.0 - brightness) / 100.0 * 0.85))

    visible: isSoftware && brightness < 99
    WlrLayershell.namespace: "poly-brightness-dimmer"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Empty input mask: all mouse, touch, and click events pass through untouched
    mask: Region {}

    Rectangle {
        id: dimRect
        anchors.fill: parent
        color: "#000000"
        opacity: root.dimRatio

        Behavior on opacity {
            NumberAnimation { duration: Motion.responseMs }
        }
    }
}
