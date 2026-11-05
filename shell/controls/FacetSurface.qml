import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Shapes

Rectangle {
    id: root
    property color baseColor: PolyTheme.Theme.color("#292f32")
    property bool accented: false
    radius: 14
    antialiasing: true
    color: Glass.tint(baseColor, accented ? 0.72 : 0.42)
    border.width: 0.7
    border.color: accented ? PolyTheme.Theme.color("#839277") : PolyTheme.Theme.color("#41494a")
    Shape {
        preferredRendererType: Shape.CurveRenderer
        anchors.fill: parent
        opacity: root.accented ? 1 : 0.36
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#12dbe4d1")
            startX: 12; startY: 1
            PathLine { x: root.width * 0.65; y: 1 }
            PathLine { x: root.width * 0.36; y: root.height - 1 }
            PathLine { x: 1; y: root.height * 0.63 }
            PathLine { x: 12; y: 1 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#0f030b0e")
            startX: root.width * 0.65; startY: 1
            PathLine { x: root.width - 10; y: 1 }
            PathLine { x: root.width * 0.79; y: root.height * 0.65 }
            PathLine { x: root.width * 0.36; y: root.height - 1 }
            PathLine { x: root.width * 0.65; y: 1 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#0db3c6b5")
            startX: root.width - 1; startY: root.height * 0.28
            PathLine { x: root.width - 1; y: root.height - 12 }
            PathLine { x: root.width * 0.68; y: root.height - 1 }
            PathLine { x: root.width - 1; y: root.height * 0.28 }
        }
    }
}
