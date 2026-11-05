import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Shapes

Button {
    id: control
    property int workspace: 1
    property bool occupied: false
    implicitWidth: 34
    implicitHeight: 28
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    padding: 0
    Accessible.name: I18n.tr("overview.workspace") + " " + workspace
    background: Item {
        Shape {
        preferredRendererType: Shape.CurveRenderer
            anchors.fill: parent
            ShapePath {
                strokeWidth: control.visualFocus ? 1.5 : 0
                strokeColor: Session.foreground
                fillColor: Glass.tint(control.highlighted ? (control.hovered ? PolyTheme.Theme.color("#b1c1a0") : PolyTheme.Theme.color("#9eaf8e")) : (control.hovered ? PolyTheme.Theme.color("#424c45") : PolyTheme.Theme.color("#2e3638")), control.highlighted ? 0.88 : 0.5)
                Behavior on fillColor { ColorAnimation { duration: Motion.responseMs } }
                startX: 8; startY: 1
                PathLine { x: 26; y: 1 }
                PathLine { x: 33; y: 14 }
                PathLine { x: 26; y: 27 }
                PathLine { x: 8; y: 27 }
                PathLine { x: 1; y: 14 }
                PathLine { x: 8; y: 1 }
            }
            ShapePath {
                strokeWidth: 0
                fillColor: control.highlighted ? PolyTheme.Theme.color("#20f0f5db") : PolyTheme.Theme.color("#06e0e7d0")
                startX: 8; startY: 1
                PathLine { x: 26; y: 1 }
                PathLine { x: 15; y: 15 }
                PathLine { x: 8; y: 1 }
            }
        }
    }
    contentItem: Item {
        Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        text: String(control.workspace)
        color: control.highlighted ? PolyTheme.Theme.color("#29312a") : Session.foreground
        font.family: Session.settings.bar ? Session.settings.bar.fontFamily : "Noto Sans"
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        }
        Rectangle {
            opacity: control.occupied ? 1 : 0
            scale: control.occupied ? 1 : 0.3
            Behavior on opacity { NumberAnimation { duration: Motion.responseMs } }
            Behavior on scale { NumberAnimation { duration: Motion.responseMs; easing.type: Easing.OutCubic } }
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 6
            width: 3; height: 3; radius: 1.5
            color: control.highlighted ? PolyTheme.Theme.color("#394833") : PolyTheme.Theme.color("#b2bea9")
        }
    }
}
