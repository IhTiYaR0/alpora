import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls

Button {
    id: control
    required property string symbol
    property string hint: ""
    property bool circular: true
    implicitWidth: 38
    implicitHeight: 38
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: hint
    background: Rectangle {
        radius: control.circular ? width / 2 : 8
        color: Glass.tint(control.hovered || control.down ? PolyTheme.Theme.color("#48504d") : PolyTheme.Theme.color("#363d3c"), control.hovered || control.down ? 0.7 : 0.45)
        border.width: control.visualFocus ? 1.5 : 0.7
        border.color: control.visualFocus ? Session.accent : PolyTheme.Theme.color("#46504a")
        Behavior on color { ColorAnimation { duration: Motion.responseMs } }
    }
    contentItem: Item {
        Icon { anchors.centerIn: parent; name: control.symbol; width: 18; height: 18 }
    }
}
