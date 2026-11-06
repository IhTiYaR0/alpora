import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls

Button {
    id: root
    property string symbol: "chevron-right"
    property string subtitle: ""
    property string statusKind: ""
    property int statusLevel: 0
    property bool statusBusy: false
    property bool statusWarning: false
    property string statusLabel: ""
    property bool selected: false
    property bool entranceActive: true
    property int entranceOrder: 0
    implicitHeight: subtitle ? 53 : 42
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: text + (subtitle ? ", " + subtitle : "") + (statusLabel ? ", " + statusLabel : "")
    EntranceMotion { id: entrance; shown: root.entranceActive; order: root.entranceOrder }
    opacity: entrance.opacity
    transform: [
        InteractionMotion { item: root; pressed: root.down; hovered: root.hovered || root.visualFocus; hoverScale: 1.015; pressScale: 0.98 },
        Scale { origin.x: root.width / 2; origin.y: 0; xScale: entrance.scale; yScale: entrance.scale },
        Translate { x: entrance.lateral; y: entrance.offset }
    ]
    background: FacetSurface {
        accented: root.selected
        baseColor: root.selected ? PolyTheme.Theme.color("#4b5947") : (root.hovered ? PolyTheme.Theme.color("#38423f") : PolyTheme.Theme.color("#292f32"))
        Behavior on baseColor { ColorAnimation { duration: Session.settings.reducedMotion ? 0 : 140 } }
        border.width: root.visualFocus ? 1.5 : 0.7
        border.color: root.visualFocus ? Session.accent : PolyTheme.Theme.color("#41494a")
        SurfaceLight { anchors.fill: parent; anchors.margins: 3; hovered: root.hovered; pressed: root.down }
    }
    contentItem: Item {
        opacity: root.enabled ? 1 : 0.4
        Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: root.symbol; width: 20; height: 20; visible: !root.statusKind }
        StatusIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; visible: !!root.statusKind; kind: root.statusKind; level: root.statusLevel; busy: root.statusBusy; warning: root.statusWarning }
        Column {
            x: 42; width: parent.width - 70; anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text { width: parent.width; text: root.text; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12; elide: Text.ElideRight }
            Text { width: parent.width; visible: !!root.subtitle; text: root.subtitle; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; elide: Text.ElideRight }
        }
        Icon { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; name: root.selected ? "check" : "chevron-right"; width: 14; height: 14 }
    }
}
