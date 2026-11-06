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
        color: control.down ? Glass.tint(Session.accent, 0.28) : (control.hovered ? Glass.tint(Session.accent, 0.18) : Glass.tint(Session.surface, 0.35))
        border.width: control.visualFocus ? 1.5 : 1
        border.color: control.visualFocus ? Session.accent : (control.hovered ? Glass.tint(Session.accent, 0.55) : Glass.tint(Session.accent, 0.22))
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
