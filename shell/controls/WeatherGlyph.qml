pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Shapes
import "../theme" as PolyTheme

Item {
    id: root
    property int code: 0
    property bool day: true
    property bool animated: false
    property real externalTime: -1
    readonly property real time: externalTime >= 0 ? externalTime : phase
    readonly property bool moving: animated && visible && !Motion.reduced && !!WidgetState.values.animations
    clip: true
    // Subpixel weather motion needs only 20 updates/s, not a 60 Hz desktop redraw.
    property real phase: 0
    Timer { interval: 50; repeat: true; running: root.moving && root.externalTime < 0; onTriggered: root.phase += 0.05 }
    readonly property bool cloudy: code > 0
    readonly property bool wet: (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95
    readonly property bool snow: (code >= 71 && code <= 77) || code === 85 || code === 86
    Item {
        width: 120; height: 100
        scale: Math.min(root.width / width, root.height / height)
        transformOrigin: Item.TopLeft
        Shape {
        preferredRendererType: Shape.CurveRenderer
            id: sun
            visible: root.day && root.code < 3
            layer.enabled: true
            opacity: root.moving ? 0.86 + Math.sin(root.time * 1.2) * 0.14 : 1
            ShapePath {
                strokeWidth: 0; fillColor: PolyTheme.Theme.secondary
                startX: 81; startY: 3
                PathLine { x: 91; y: 18 } PathLine { x: 108; y: 23 }
                PathLine { x: 104; y: 42 } PathLine { x: 111; y: 57 }
                PathLine { x: 94; y: 65 } PathLine { x: 82; y: 79 }
                PathLine { x: 68; y: 66 } PathLine { x: 51; y: 60 }
                PathLine { x: 54; y: 42 } PathLine { x: 48; y: 25 }
                PathLine { x: 67; y: 19 } PathLine { x: 81; y: 3 }
            }
            ShapePath {
                strokeWidth: 0; fillColor: PolyTheme.Theme.mix(PolyTheme.Theme.secondary, Session.foreground, 0.3)
                startX: 81; startY: 14
                PathLine { x: 100; y: 30 } PathLine { x: 81; y: 44 }
                PathLine { x: 60; y: 30 } PathLine { x: 81; y: 14 }
            }
        }
        Shape {
            visible: !root.day && root.code < 3
            x: 54; y: 10; width: 30; height: 30; scale: 1.8
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Session.foreground; strokeWidth: 0
                PathSvg { path: "M 22,2 A 14,14 0 1 0 28,23 A 13,13 0 0 1 22,2 Z" }
            }
        }
        Shape {
        preferredRendererType: Shape.CurveRenderer
            id: cloud
            visible: root.cloudy
            layer.enabled: true
            x: root.moving ? Math.sin(root.time * 0.6) * 3.5 : 0
            ShapePath {
                strokeWidth: 0; fillColor: PolyTheme.Theme.mix(Session.muted, Session.foreground, 0.4)
                startX: 7; startY: 70
                PathLine { x: 19; y: 49 } PathLine { x: 34; y: 47 }
                PathLine { x: 49; y: 29 } PathLine { x: 67; y: 33 }
                PathLine { x: 80; y: 49 } PathLine { x: 99; y: 49 }
                PathLine { x: 115; y: 71 } PathLine { x: 97; y: 79 }
                PathLine { x: 22; y: 79 } PathLine { x: 7; y: 70 }
            }
            ShapePath {
                strokeWidth: 0; fillColor: PolyTheme.Theme.mix(Session.muted, Session.surface, 0.25)
                startX: 49; startY: 29
                PathLine { x: 59; y: 61 } PathLine { x: 22; y: 79 }
                PathLine { x: 97; y: 79 } PathLine { x: 80; y: 49 }
                PathLine { x: 67; y: 33 } PathLine { x: 49; y: 29 }
            }
        }
        Repeater {
            model: root.wet || root.snow ? 3 : 0
            Rectangle {
                id: drop
                required property int index
                x: 30 + index * 27
                y: root.moving ? 80 + ((root.time + index * 0.18) % (root.snow ? 1.9 : 0.72)) / (root.snow ? 1.9 : 0.72) * 23 : 86
                width: root.snow ? 5 : 3; height: root.snow ? 5 : 11
                radius: root.snow ? 2 : 1
                rotation: root.snow ? 45 : 22; color: PolyTheme.Theme.cool

            }
        }
    }
}
