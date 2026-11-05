pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Shapes
Item {
    id: root
    implicitHeight: 4
    Shape {
        anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0.7; strokeColor: Glass.tint(Session.accent, 0.28); fillColor: "transparent"
            startX: 0; startY: root.height
            PathLine { x: 6; y: 1 } PathLine { x: root.width - 6; y: 1 }
            PathLine { x: root.width; y: root.height }
        }
    }
}
