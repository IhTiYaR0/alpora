import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Shapes

Item {
    id: root
    implicitWidth: 26
    implicitHeight: 26
    Shape {
        preferredRendererType: Shape.CurveRenderer
        width: 26; height: 26
        anchors.centerIn: parent
        scale: Math.min(root.width / 26, root.height / 26)
        ShapePath {
            strokeWidth: 0
            fillColor: PolyTheme.Theme.color("#b9c9a7")
            startX: 2; startY: 4
            PathLine { x: 15; y: 2 }
            PathLine { x: 10; y: 15 }
            PathLine { x: 7; y: 15 }
            PathLine { x: 2; y: 4 }
        }
        ShapePath {
            strokeWidth: 0
            fillColor: PolyTheme.Theme.color("#8f9f80")
            startX: 15; startY: 2
            PathLine { x: 17; y: 12 }
            PathLine { x: 10; y: 15 }
            PathLine { x: 15; y: 2 }
        }
        ShapePath {
            strokeWidth: 0
            fillColor: PolyTheme.Theme.color("#aaba98")
            startX: 10; startY: 15
            PathLine { x: 24; y: 10 }
            PathLine { x: 17; y: 24 }
            PathLine { x: 10; y: 15 }
        }
        ShapePath {
            strokeWidth: 0
            fillColor: PolyTheme.Theme.color("#68785f")
            startX: 7; startY: 15
            PathLine { x: 10; y: 15 }
            PathLine { x: 17; y: 24 }
            PathLine { x: 11; y: 22 }
            PathLine { x: 7; y: 15 }
        }
    }
}
