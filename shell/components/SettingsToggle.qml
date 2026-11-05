pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls
Switch {
    id: control
    implicitWidth: 48; implicitHeight: 32
    padding: 0
    indicator: Rectangle {
        anchors.centerIn: parent
        width: 46; height: 26; radius: 13
        color: control.checked ? PolyTheme.Theme.color("#b7cea2") : PolyTheme.Theme.color("#525a60")
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? PolyTheme.Theme.color("#eef2e5") : PolyTheme.Theme.color("#608c9981")
        opacity: control.enabled ? 1 : 0.4
        Rectangle {
            x: control.checked ? 23 : 3; y: 3; width: 20; height: 20; radius: 10
            color: control.checked ? PolyTheme.Theme.color("#29332d") : PolyTheme.Theme.color("#c8ced0")
            Behavior on x { NumberAnimation { duration: Session.settings.reducedMotion ? 0 : 120 } }
        }
    }
}
