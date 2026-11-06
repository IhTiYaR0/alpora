pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls

Button {
    id: tile
    required property var entry
    property bool selected: false
    property bool compact: false
    property real expansion: compact ? 0 : 1
    property bool entranceActive: true
    property bool animateEntrance: true
    property int entranceOrder: 0
    signal launchRequested()
    implicitHeight: 64
    hoverEnabled: true
    padding: 8 + 2 * expansion
    HoverHandler { id: tiltPointer }
    EntranceMotion { id: entrance; shown: tile.entranceActive; order: tile.entranceOrder; immediate: !tile.animateEntrance }
    opacity: entrance.opacity
    transform: [
        PointerTilt { item: tile; hovered: tiltPointer.hovered; pointerX: tiltPointer.point.position.x; pointerY: tiltPointer.point.position.y },
        InteractionMotion { item: tile; pressed: tile.down; hovered: tile.hovered || tile.visualFocus; hoverScale: 1.015; pressScale: 0.975 },
        Scale { origin.x: tile.width / 2; origin.y: 0; xScale: entrance.scale; yScale: entrance.scale },
        Rotation { origin.x: tile.width / 2; origin.y: 0; axis.x: 1; axis.y: 0.2; axis.z: 0; angle: entrance.tilt },
        Translate { x: entrance.lateral; y: entrance.offset }
    ]
    Accessible.name: entry.name + ", " + AppCatalog.categoryName(entry)
    background: Rectangle {
        radius: 12
        color: Glass.tint(tile.down ? PolyTheme.Theme.color("#44533f") : tile.hovered || tile.selected || tile.visualFocus ? PolyTheme.Theme.color("#35423a") : PolyTheme.Theme.color("#293032"), tile.hovered || tile.selected ? 0.64 : 0.4)
        border.width: 1
        border.color: tile.selected || tile.visualFocus ? PolyTheme.Theme.color("#a9b99a") : PolyTheme.Theme.color("#3c4543")
        Behavior on color { ColorAnimation { duration: Session.settings.reducedMotion ? 0 : 100 } }
        SurfaceLight { anchors.fill: parent; anchors.margins: 3; hovered: tile.hovered; pressed: tile.down }
    }
    contentItem: Item {
        Image {
            id: appIcon
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            width: 26 + 8 * tile.expansion; height: width
            source: AppCatalog.iconSource(tile.entry)
            sourceSize.width: 68; sourceSize.height: 68
            // Native icon providers create QPixmaps; keep them on the GUI thread.
            // The raster cache and file images can still load asynchronously.
            asynchronous: !source.toString().startsWith("image://")
            fillMode: Image.PreserveAspectFit
        }
        Column {
            anchors.left: appIcon.right; anchors.leftMargin: 8 + 4 * tile.expansion
            anchors.right: parent.right; anchors.rightMargin: 25
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text { width: parent.width; text: tile.entry.name; textFormat: Text.PlainText; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11 + tile.expansion; elide: Text.ElideRight }
            Text { width: parent.width; text: AppCatalog.categoryName(tile.entry); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; elide: Text.ElideRight }
        }
        ToolButton {
            id: pin
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 25; height: 30
            readonly property bool isPinned: AppCatalog.pinnedIds.includes(tile.entry.id)
            Accessible.name: isPinned ? I18n.tr("app.remove_favorite") : I18n.tr("app.add_favorite")
            contentItem: Icon {
                name: pin.isPinned ? "star-filled" : "star"
                width: 15; height: 15
                anchors.centerIn: parent
                color: pin.isPinned ? Session.accent : Session.muted
            }
            background: Rectangle { radius: 6; color: pin.hovered ? Glass.tint(Session.accent, 0.2) : "transparent" }
            onClicked: AppCatalog.togglePin(tile.entry.id)
        }
    }
    onClicked: launchRequested()
}
