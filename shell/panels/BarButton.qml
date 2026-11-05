import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls

Button {
    id: control
    property string symbol: ""
    property string hint: ""
    property bool marked: false
    implicitWidth: 30
    implicitHeight: 30
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: hint
    background: Rectangle {
        radius: 9
        color: control.down ? PolyTheme.Theme.color("#485149") : (control.hovered || control.visualFocus || control.highlighted ? PolyTheme.Theme.color("#353e39") : "transparent")
        border.width: control.visualFocus ? 1 : 0
        border.color: PolyTheme.Theme.color("#a4b396")
        Behavior on color { ColorAnimation { duration: Motion.responseMs } }
    }
    contentItem: Item {
        Icon { anchors.centerIn: parent; name: control.symbol; width: 18; height: 18 }
        Rectangle { visible: control.marked; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 3; width: 5; height: 5; radius: 3; color: PolyTheme.Theme.color("#a4b396") }
    }
}
