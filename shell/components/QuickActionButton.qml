pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
Button {
    id: control
    required property string symbol
    implicitHeight: 40
    hoverEnabled: true; padding: 8
    Accessible.name: text
    background: Rectangle {
        radius: 10
        color: control.hovered || control.down ? Glass.tint(Session.accent, 0.14) : Glass.tint(Session.surface, 0.30)
        border.width: control.visualFocus ? 1.5 : 1
        border.color: Glass.tint(Session.accent, control.visualFocus ? 1 : 0.20)
        Behavior on color { ColorAnimation { duration: Motion.responseMs } }
    }
    contentItem: Item {
        implicitWidth: buttonRow.implicitWidth
        implicitHeight: buttonRow.implicitHeight
        RowLayout {
            id: buttonRow
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width)
            spacing: 6
            Icon { name: control.symbol; Layout.preferredWidth: 17; Layout.preferredHeight: 17 }
            Text { visible: control.text.length > 0; Layout.fillWidth: true; text: control.text; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11; elide: Text.ElideRight }
        }
    }
}
