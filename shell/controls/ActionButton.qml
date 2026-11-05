import QtQuick
import ".."
import QtQuick.Controls

Button {
    id: control

    property string hint: ""
    implicitHeight: 30
    implicitWidth: Math.max(30, label.implicitWidth + 18)
    padding: 8
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: hint || text

    background: Rectangle {
        radius: 5
        color: control.highlighted ? Session.accent : (control.hovered || control.down ? Session.surface : "transparent")
        border.width: control.visualFocus ? 2 : 0
        border.color: Session.accent
        Behavior on color {
            ColorAnimation { duration: Motion.responseMs }
        }
    }

    contentItem: Text {
        id: label
        text: control.text
        color: control.highlighted ? Session.background : Session.foreground
        font.family: Session.settings.bar ? Session.settings.bar.fontFamily : "Noto Sans"
        font.pixelSize: Session.settings.bar ? Session.settings.bar.fontSize : 13
        font.weight: control.highlighted ? Font.DemiBold : Font.Medium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: control.enabled ? 1 : 0.45
    }

}
