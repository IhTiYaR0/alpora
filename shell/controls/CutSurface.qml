pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Shapes
import "../theme" as PolyTheme

// Theme roles remain live bindings, including intermediate Timeline palettes.
Item {
    id: root
    property color fillColor: PolyTheme.Theme.mix(Session.background, Session.surface, 0.65)
    property color edgeColor: Glass.tint(Session.accent, 0.30)
    property real edgeWidth: 0.8
    property real cut: Math.min(12, Math.max(3, Session.visual.panelRadius * 0.65))
    property bool facets: true
    readonly property real bevel: Math.min(cut, width / 4, height / 4)
    readonly property string outline: {
        const w = width - 0.7, h = height - 0.7, c = bevel, s = 0.7;
        return "M" + c + " " + s + " H" + (w-c) + " L" + w + " " + c
            + " V" + (h-c) + " L" + (w-c) + " " + h + " H" + c
            + " L" + s + " " + (h-c) + " V" + c + " Z";
    }
    Shape {
        anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: root.edgeWidth; strokeColor: root.edgeColor
            fillColor: root.fillColor; joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.outline }
        }
        ShapePath {
            strokeWidth: 0; fillColor: root.facets ? Glass.tint(Session.accent, 0.035) : "transparent"
            startX: root.bevel + 1; startY: 2
            PathLine { x: root.width * 0.88; y: 2 }
            PathLine { x: root.width * 0.32; y: root.height - 2 }
            PathLine { x: root.bevel + 1; y: root.height - 2 }
            PathLine { x: 2; y: root.height - root.bevel - 1 }
            PathLine { x: 2; y: root.bevel + 1 }
            PathLine { x: root.bevel + 1; y: 2 }
        }
    }
}
