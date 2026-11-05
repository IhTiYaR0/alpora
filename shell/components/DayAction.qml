import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls

Button {
    id: control
    property bool primary: false
    implicitHeight: 34
    implicitWidth: Math.max(76, contentItem.implicitWidth + 26)
    padding: 10
    hoverEnabled: true
    transform: InteractionMotion { item: control; pressed: control.down; hovered: control.hovered || control.visualFocus; hoverScale: 1.025; pressScale: 0.965 }
    background: Rectangle {
        radius: 10
        color: control.primary ? (control.hovered ? PolyTheme.Theme.color("#b4c5a3") : PolyTheme.Theme.color("#98ac85")) : (control.hovered ? PolyTheme.Theme.color("#3b493e") : PolyTheme.Theme.color("#2d3832"))
        border.width: control.visualFocus ? 1.2 : 0.7
        border.color: control.visualFocus ? PolyTheme.Theme.color("#c3d4af") : PolyTheme.Theme.color("#52614c")
        opacity: control.enabled ? 1 : 0.5
        Behavior on color { ColorAnimation { duration: Session.settings.reducedMotion ? 0 : 140 } }
        SurfaceLight { anchors.fill: parent; anchors.margins: 3; hovered: control.hovered; pressed: control.down }
    }
    contentItem: Text {
        text: control.text
        textFormat: Text.PlainText
        color: control.primary ? PolyTheme.Theme.color("#253023") : Session.foreground
        font.family: Session.fontFamily; font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    }
}
