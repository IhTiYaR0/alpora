pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Shapes

Item {
    id: root
    property string kind: "wifi-disconnected"
    property int level: 0
    property bool busy: false
    property bool warning: false
    property color ink: Session.foreground
    readonly property bool wifi: kind.startsWith("wifi")
    readonly property bool disconnected: kind === "wifi-disconnected" || kind === "wifi-off" || kind === "wifi-unavailable"
    readonly property bool unavailable: kind.endsWith("unavailable") || kind.endsWith("off")
    implicitWidth: 20; implicitHeight: 20
    Accessible.role: Accessible.Graphic
    Item {
        width: 24; height: 24
        anchors.centerIn: parent
        scale: Math.min(root.width, root.height) / 24
        opacity: root.unavailable ? .45 : 1
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.ink; strokeWidth: 1.7; fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                PathSvg { path: root.wifi ? "M11.4 19h1.2" : root.kind === "wired" ? "M5 3h14v11H5z M9 14v4 M15 14v4 M3 20h18 M12 18v2"
                    : root.kind.startsWith("bluetooth") ? "M12 2v20l7-6-13-9 M6 17 19 8 12 2"
                    : "M11 4 6 8H2v8h4l5 4z" }
            }
            ShapePath {
                strokeWidth: 1.7; fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                strokeColor: Glass.tint(root.ink, root.wifi && (root.level < 1 || root.disconnected) ? .18 : 1)
                PathSvg { path: root.wifi ? "M8.5 15.4a5.5 5.5 0 0 1 7 0"
                    : root.kind === "volume" && root.level > 0 ? "M15 8a6 6 0 0 1 0 8" : "" }
            }
            ShapePath {
                strokeWidth: 1.7; fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                strokeColor: Glass.tint(root.ink, root.wifi && (root.level < 2 || root.disconnected) ? .18 : 1)
                PathSvg { path: root.wifi ? "M5 12a10.5 10.5 0 0 1 14 0"
                    : root.kind === "volume" && root.level > 1 ? "M18 4a11 11 0 0 1 0 16" : "" }
            }
            ShapePath {
                strokeWidth: 1.7; fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                strokeColor: Glass.tint(root.ink, root.level < 3 || root.disconnected ? .18 : 1)
                PathSvg { path: root.wifi ? "M2 8.8a15 15 0 0 1 20 0" : "" }
            }
            ShapePath {
                strokeColor: root.ink; strokeWidth: 1.7; fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: root.disconnected ? "M4 4 20 20"
                    : root.kind === "muted" || root.kind === "audio-unavailable" ? "M16 9 22 15 M22 9 16 15" : "" }
            }
        }
        Rectangle {
            visible: root.warning || root.kind === "bluetooth-connected" || root.kind === "bluetooth-disconnected"
            x: root.kind === "bluetooth-disconnected" ? 17 : 18; y: root.kind === "bluetooth-disconnected" ? 15 : 16
            width: root.kind === "bluetooth-disconnected" ? 7 : 5; height: width; radius: 2.5
            color: root.warning ? Session.palette.secondary || Session.accent : root.kind === "bluetooth-disconnected" ? Session.background : Session.accent
            border.width: root.kind === "bluetooth-disconnected" ? 0 : 1; border.color: Session.background
            Shape {
                anchors.fill: parent; visible: root.kind === "bluetooth-disconnected"
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 1.4; strokeColor: root.ink; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathSvg { path: "M1.5 1.5 L5.5 5.5 M5.5 1.5 L1.5 5.5" }
                }
            }
        }
    }
    // Run only while the service reports an actual connection attempt.
    SequentialAnimation on opacity {
        running: root.visible && root.busy && !Motion.reduced
        loops: Animation.Infinite
        NumberAnimation { to: .4; duration: 450; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 450; easing.type: Easing.InOutSine }
        onStopped: root.opacity = 1
    }
}
