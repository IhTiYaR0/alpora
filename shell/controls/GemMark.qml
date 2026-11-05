import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Shapes

Item {
    id: root
    implicitWidth: 24; implicitHeight: 28
    Shape {
        preferredRendererType: Shape.CurveRenderer
        width: 24; height: 28; anchors.centerIn: parent
        scale: Math.min(root.width / 24, root.height / 28)
        ShapePath { strokeWidth: 0; fillColor: PolyTheme.Theme.color("#b6c5a3"); startX: 12; startY: 1; PathLine { x: 3; y: 7 } PathLine { x: 9; y: 13 } PathLine { x: 12; y: 1 } }
        ShapePath { strokeWidth: 0; fillColor: PolyTheme.Theme.color("#94a682"); startX: 12; startY: 1; PathLine { x: 21; y: 6 } PathLine { x: 17; y: 14 } PathLine { x: 9; y: 13 } PathLine { x: 12; y: 1 } }
        ShapePath { strokeWidth: 0; fillColor: PolyTheme.Theme.color("#c0cdae"); startX: 3; startY: 7; PathLine { x: 1; y: 15 } PathLine { x: 9; y: 13 } PathLine { x: 3; y: 7 } }
        ShapePath { strokeWidth: 0; fillColor: PolyTheme.Theme.color("#7f9370"); startX: 21; startY: 6; PathLine { x: 23; y: 16 } PathLine { x: 17; y: 14 } PathLine { x: 21; y: 6 } }
        ShapePath { strokeWidth: 0; fillColor: PolyTheme.Theme.color("#a2b48f"); startX: 1; startY: 15; PathLine { x: 9; y: 13 } PathLine { x: 12; y: 27 } PathLine { x: 1; y: 15 } }
        ShapePath { strokeWidth: 0; fillColor: PolyTheme.Theme.color("#657a59"); startX: 9; startY: 13; PathLine { x: 17; y: 14 } PathLine { x: 12; y: 27 } PathLine { x: 9; y: 13 } }
        ShapePath { strokeWidth: 0; fillColor: PolyTheme.Theme.color("#849775"); startX: 17; startY: 14; PathLine { x: 23; y: 16 } PathLine { x: 12; y: 27 } PathLine { x: 17; y: 14 } }
    }
}
