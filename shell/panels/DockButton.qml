pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme

Item {
    id: root
    required property var group
    property bool menuOpened: false
    property real cursorX: -1000
    property bool waveActive: false
    readonly property real centerX: x + width / 2
    readonly property real cursorDist: Math.abs(cursorX - centerX)
    readonly property real waveFactor: (!waveActive || cursorDist >= 95) ? 0 : Math.cos((cursorDist / 95) * (Math.PI / 2))
    signal hoverChanged(bool hovered)
    signal menuRequested()
    implicitWidth: 56; implicitHeight: 64
    readonly property bool hovered: pointer.hovered
    HoverHandler { id: pointer; onHoveredChanged: root.hoverChanged(hovered) }
    Rectangle {
        x: 3; y: 6; width: parent.width - 6; height: 48
        radius: Math.min(15, Session.visual.panelRadius)
        color: PolyTheme.Theme.withAlpha(Session.accent, mouse.pressed ? 0.22 : root.hovered || root.menuOpened ? 0.13 : root.group.active ? 0.07 : 0)
        border.width: root.hovered || root.menuOpened ? 1 : 0
        border.color: PolyTheme.Theme.withAlpha(Session.accent, 0.25)
        Behavior on color { ColorAnimation { duration: Motion.responseMs } }
    }
    Image {
        id: icon
        anchors.horizontalCenter: parent.horizontalCenter
        readonly property real targetY: Motion.reduced ? 12 : root.waveActive ? (12 - 9 * root.waveFactor) : (root.hovered ? 7 : 12)
        readonly property real targetScale: Motion.reduced ? 1 : mouse.pressed ? 0.93 : root.waveActive ? (1.0 + 0.30 * root.waveFactor) : (root.hovered ? 1.1 : 1)
        y: targetY
        width: 40; height: 40
        scale: targetScale
        source: DockState.iconSource(root.group)
        sourceSize: Qt.size(96, 96); fillMode: Image.PreserveAspectFit
        // QIcon-backed providers must not create GUI pixmaps in an image worker.
        asynchronous: !source.toString().startsWith("image://")
        Behavior on y { NumberAnimation { duration: Motion.reduced ? 0 : 130; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: Motion.reduced ? 0 : 130; easing.type: Easing.OutQuad } }
    }
    Rectangle {
        visible: root.group.windows.length > 1
        anchors.right: parent.right; anchors.rightMargin: 1; y: 2
        width: 17; height: 17; radius: 8.5
        color: Session.surface; border.width: 1; border.color: PolyTheme.Theme.withAlpha(Session.accent, 0.5)
        Text { anchors.centerIn: parent; text: root.group.windows.length; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 9 }
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter; y: 58
        width: root.group.active ? 16 : 5; height: 3; radius: 1.5
        visible: root.group.windows.length > 0 || DockState.launchingId === root.group.id
        color: root.group.active || root.group.urgent || DockState.launchingId === root.group.id ? Session.accent : PolyTheme.Theme.withAlpha(Session.foreground, 0.48)
        Behavior on width { NumberAnimation { duration: Motion.responseMs; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        Accessible.role: Accessible.Button
        Accessible.name: root.group.name + (root.group.windows.length ? " · " + root.group.windows.length + " " + I18n.tr("dock.windows") : " · " + I18n.tr("dock.open"))
        onClicked: event => {
            if (event.button === Qt.RightButton) root.menuRequested();
            else if (event.button === Qt.MiddleButton) DockState.launch(root.group.id);
            else DockState.activate(root.group.id);
        }
        onWheel: event => {
            // Horizontal trackpad travel belongs to the overflowing dock;
            // vertical wheel travel cycles only apps with multiple windows.
            if (event.angleDelta.x || event.pixelDelta.x || root.group.windows.length < 2) {
                event.accepted = false; return;
            }
            DockState.cycle(root.group.id, event.angleDelta.y < 0 ? 1 : -1);
            event.accepted = true;
        }
    }
}
