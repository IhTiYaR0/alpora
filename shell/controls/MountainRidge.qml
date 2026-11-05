import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Shapes

Item {
    id: root
    readonly property string landscape: Session.appearance.ridge || ""
    Image {
        anchors.fill: parent
        source: root.landscape ? "file://" + root.landscape : ""
        sourceSize: Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio * 2)), Math.max(1, Math.ceil(height * Screen.devicePixelRatio * 2)))
        fillMode: Image.PreserveAspectFit
        verticalAlignment: Image.AlignBottom
        asynchronous: false
    }
    Shape {
        preferredRendererType: Shape.CurveRenderer
        visible: !root.landscape
        width: 360; height: 62
        scale: root.width / 360
        transformOrigin: Item.BottomLeft
        anchors.bottom: parent.bottom
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#2e3736")
            startX: 100; startY: 61
            PathLine { x: 218; y: 0 } PathLine { x: 280; y: 43 }
            PathLine { x: 360; y: 61 } PathLine { x: 100; y: 61 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#36403d")
            startX: 218; startY: 0
            PathLine { x: 198; y: 61 } PathLine { x: 255; y: 61 }
            PathLine { x: 218; y: 0 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#242c30")
            startX: 0; startY: 61
            PathLine { x: 40; y: 37 } PathLine { x: 72; y: 55 }
            PathLine { x: 128; y: 34 } PathLine { x: 188; y: 1 }
            PathLine { x: 243; y: 45 } PathLine { x: 277; y: 38 }
            PathLine { x: 360; y: 61 } PathLine { x: 0; y: 61 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#3d4740")
            startX: 98; startY: 61
            PathLine { x: 162; y: 28 } PathLine { x: 219; y: 60 }
            PathLine { x: 98; y: 61 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#53604d")
            startX: 162; startY: 28
            PathLine { x: 145; y: 61 } PathLine { x: 185; y: 61 }
            PathLine { x: 162; y: 28 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#313b38")
            startX: 162; startY: 28
            PathLine { x: 219; y: 60 } PathLine { x: 185; y: 61 }
            PathLine { x: 162; y: 28 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#56614e")
            startX: 232; startY: 61
            PathLine { x: 278; y: 39 } PathLine { x: 333; y: 61 }
            PathLine { x: 232; y: 61 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#77806a")
            startX: 278; startY: 39
            PathLine { x: 295; y: 61 } PathLine { x: 333; y: 61 }
            PathLine { x: 278; y: 39 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#303b3e")
            startX: 0; startY: 61
            PathLine { x: 40; y: 37 } PathLine { x: 72; y: 61 }
            PathLine { x: 0; y: 61 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#424e4d")
            startX: 40; startY: 37
            PathLine { x: 47; y: 61 } PathLine { x: 72; y: 61 }
            PathLine { x: 40; y: 37 }
        }
        ShapePath {
            strokeColor: PolyTheme.Theme.color("#839174"); strokeWidth: 0.65; fillColor: "transparent"
            startX: 98; startY: 60
            PathLine { x: 162; y: 28 } PathLine { x: 219; y: 60 }
        }
    }
}
