import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Shapes

Item {
    id: root
    readonly property string landscape: Session.appearance.ridge || ""
    implicitWidth: 96; implicitHeight: 36
    property bool mirrored: false
    clip: true
    transform: Scale { origin.x: root.width / 2; xScale: root.mirrored ? -1 : 1 }
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
        width: 96; height: 36
        scale: Math.min(root.width / width, root.height / height)
        transformOrigin: Item.BottomLeft
        anchors.bottom: parent.bottom
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#303c40")
            startX: 0; startY: 22
            PathLine { x: 17; y: 12 } PathLine { x: 31; y: 0 } PathLine { x: 52; y: 21 }
            PathLine { x: 70; y: 14 } PathLine { x: 96; y: 36 } PathLine { x: 12; y: 36 } PathLine { x: 0; y: 22 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#566058")
            startX: 0; startY: 22
            PathLine { x: 31; y: 0 } PathLine { x: 21; y: 24 } PathLine { x: 0; y: 22 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#c09d76")
            startX: 17; startY: 12
            PathLine { x: 31; y: 0 } PathLine { x: 26; y: 15 } PathLine { x: 17; y: 12 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#465149")
            startX: 31; startY: 0
            PathLine { x: 52; y: 21 } PathLine { x: 41; y: 29 } PathLine { x: 31; y: 0 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#253139")
            startX: 12; startY: 36
            PathLine { x: 21; y: 24 } PathLine { x: 41; y: 29 } PathLine { x: 52; y: 21 }
            PathLine { x: 70; y: 36 } PathLine { x: 12; y: 36 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#5c6455")
            startX: 52; startY: 21
            PathLine { x: 70; y: 14 } PathLine { x: 64; y: 29 } PathLine { x: 52; y: 21 }
        }
        ShapePath {
            strokeWidth: 0; fillColor: PolyTheme.Theme.color("#35413e")
            startX: 70; startY: 14
            PathLine { x: 96; y: 36 } PathLine { x: 64; y: 29 } PathLine { x: 70; y: 14 }
        }
    }
}
