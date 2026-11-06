import QtQuick
import ".."
import QtQuick.Shapes
import Quickshell

Item {
    id: root
    required property string name
    property color color: "transparent"
    readonly property bool nativeGlyph: ["clipboard", "pin"].includes(name)
    implicitWidth: 20
    implicitHeight: 20
    Image {
        visible: !root.nativeGlyph
        anchors.fill: parent
        source: !root.name || root.nativeGlyph ? "" : (Quickshell.env("POLY_SHELL_ASSETS") ? ("file://" + Quickshell.env("POLY_SHELL_ASSETS") + "/icons/" + root.name + ".svg") : Qt.resolvedUrl("../../assets/icons/" + root.name + ".svg"))
        sourceSize.width: Math.max(1, Math.ceil(width * Screen.devicePixelRatio * 2))
        sourceSize.height: Math.max(1, Math.ceil(height * Screen.devicePixelRatio * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
    Item {
        anchors.centerIn: parent
        width: 24; height: 24
        scale: Math.min(root.width, root.height) / 24
        visible: root.nativeGlyph
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Session.foreground; strokeWidth: 1.6
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: root.name === "clipboard"
                        ? "M9 5H6Q4 5 4 7V20Q4 22 6 22H18Q20 22 20 20V7Q20 5 18 5H15 M10.5 2H13.5Q15 2 15 3.5V5.5Q15 7 13.5 7H10.5Q9 7 9 5.5V3.5Q9 2 10.5 2 M8 12H16 M8 16H13"
                        : "M16 3L21 8L17 9L13 14V17L7 11H10L15 7Z M10 14L3 21"
                }
            }
        }
    }
}
