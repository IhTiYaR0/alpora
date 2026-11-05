pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Shapes
import "../theme" as PolyTheme

Item {
    id: root
    implicitHeight: 6
    implicitWidth: 200

    property color glowColor: Glass.tint(Session.accent, 0.45)
    property real strokeThickness: 0.8

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.strokeThickness
            strokeColor: root.glowColor
            fillColor: "transparent"
            startX: 0
            startY: root.height / 2 + 1
            PathLine { x: 8; y: root.height / 2 - 1 }
            PathLine { x: root.width - 8; y: root.height / 2 - 1 }
            PathLine { x: root.width; y: root.height / 2 + 1 }
        }
    }
}

