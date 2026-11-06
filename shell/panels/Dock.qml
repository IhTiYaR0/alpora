pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme" as PolyTheme

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: dock
    required property var modelData
    screen: modelData
    anchors { bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore; exclusiveZone: 0
    color: "transparent"
    implicitHeight: Math.max(180, Math.min(480, modelData ? modelData.height - 80 : 480))
    visible: Session.loaded && !!modelData && !ClockState.sleeping
    WlrLayershell.namespace: "poly-shell-dock"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    readonly property var monitor: modelData ? Hyprland.monitorFor(modelData) : null
    readonly property bool fullscreen: !!monitor && !!monitor.activeWorkspace && monitor.activeWorkspace.hasFullscreen
    readonly property bool launcherActive: BarState.selection.name === "launcher" && BarState.selection.origin === "dock"
        && !!modelData && BarState.selection.screen === modelData.name
    readonly property bool allowed: Session.loaded && !ClockState.sleeping && !fullscreen && !OverviewState.opened
        && (!BarState.selection.name || launcherActive)
    readonly property real dockWidth: Math.max(0, Math.min(width - 32, 90 + DockState.groups.length * 56))
    readonly property real restingY: height - 86
    property bool requested: false
    readonly property bool opened: allowed && (requested || launcherActive)
    property string contextId: ""
    property real contextCenter: width / 2
    readonly property var contextGroup: DockState.group(contextId)
    property Item hoverItem: null
    property string hoverId: ""
    readonly property var hoveredGroup: DockState.group(hoverId)
    // One observer owns the whole input surface. Separate child enter/leave
    // events would briefly disagree while the reveal grows under the cursor.
    readonly property bool pointerInside: surfaceHover.hovered
    HoverHandler { id: surfaceHover }
    function updatePointer(): void {
        requested = allowed && pointerInside;
        if (!requested) { contextId = ""; hoverId = ""; hoverItem = null; }
    }
    onPointerInsideChanged: Qt.callLater(updatePointer)
    onAllowedChanged: if (!allowed) { requested = false; contextId = ""; hoverId = ""; hoverItem = null; }
    onContextGroupChanged: if (!contextGroup) contextId = ""
    onOpenedChanged: {
        if (opened) WindowTracker.subscribe();
        else WindowTracker.unsubscribe();
    }
    Component.onCompleted: if (opened) WindowTracker.subscribe()
    Component.onDestruction: if (opened) WindowTracker.unsubscribe()
    PanelMotion { id: motion; opened: dock.opened; openDuration: Motion.openMs; closeDuration: Motion.closeMs }

    // Only the thin summon strip receives input while hidden. Closing releases
    // the entire dock/menu region immediately, before its last visual frame.
    mask: Region {
        Region { x: (dock.width - dock.dockWidth) / 2; y: dock.height - 3; width: dock.allowed ? dock.dockWidth : 0; height: 3 }
        Region { x: mainZone.x; y: mainZone.y; width: dock.opened ? mainZone.width : 0; height: mainZone.height }
        Region { x: menuZone.x; y: menuZone.y; width: dock.opened && contextMenu.visible ? menuZone.width : 0; height: menuZone.height }
    }
    Item {
        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
        width: dock.dockWidth; height: 3
        Rectangle {
            anchors.centerIn: parent; width: 48; height: 2; radius: 1
            visible: dock.allowed && !dock.opened
            color: PolyTheme.Theme.withAlpha(Session.accent, 0.35)
        }
    }
    Item {
        id: mainZone
        x: (dock.width - dock.dockWidth) / 2 - 8; y: dock.restingY - 38
        width: dock.dockWidth + 16; height: dock.height - y
    }
    Item {
        id: menuZone
        x: contextMenu.x; y: contextMenu.y
        width: contextMenu.width; height: contextMenu.height + 12
        visible: contextMenu.visible
    }
    Item {
        id: frame
        x: (dock.width - dock.dockWidth) / 2; y: dock.restingY
        width: dock.dockWidth; height: 72
        visible: motion.presented
        opacity: motion.progress
        transform: Translate { y: Motion.reduced ? 0 : (1 - motion.progress) * 88 }
        SoftShadow { anchors.fill: parent; cornerRadius: glass.radius; spread: 8; strength: Session.visual.panelShadow / 20 }
        Rectangle {
            id: glass
            anchors.fill: parent; radius: Math.min(25, Session.visual.panelRadius)
            border.width: Session.visual.panelBorder
            border.color: PolyTheme.Theme.withAlpha(Session.accent, 0.3)
            gradient: Gradient {
                GradientStop { position: 0; color: Glass.panelTop }
                GradientStop { position: 1; color: Glass.panelBottom }
            }
        }
        Rectangle {
            x: 24; y: 1; width: Math.max(0, parent.width - 48); height: 1
            color: PolyTheme.Theme.withAlpha(Session.foreground, 0.12)
        }
        Flickable {
            id: strip
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
            contentWidth: icons.width; contentHeight: height
            clip: true; boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            Row {
                id: icons
                height: 64; y: 4; spacing: 0
                readonly property real waveCursorX: iconsHover.hovered ? iconsHover.point.position.x : -1000
                readonly property bool waveActive: !Motion.reduced && dock.opened && iconsHover.hovered
                HoverHandler { id: iconsHover; enabled: !Motion.reduced && dock.opened }
                Button {
                    id: applications
                    width: 56; height: 64; padding: 0
                    hoverEnabled: true; focusPolicy: Qt.NoFocus
                    Accessible.name: I18n.tr("dock.all_apps")
                    readonly property real appDist: Math.abs(icons.waveCursorX - 28)
                    readonly property real appWave: (icons.waveActive && appDist < 95) ? Math.cos((appDist / 95) * (Math.PI / 2)) : 0
                    onHoveredChanged: {
                        if (hovered) { dock.hoverItem = applications; dock.hoverId = ""; }
                        else if (dock.hoverItem === applications) dock.hoverItem = null;
                    }
                    background: Rectangle {
                        x: 3; y: 6; width: 50; height: 48
                        radius: Math.min(15, Session.visual.panelRadius)
                        color: PolyTheme.Theme.withAlpha(Session.accent, applications.hovered || dock.launcherActive ? 0.15 : 0.04)
                    }
                    contentItem: Item {
                        FacetedMark {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: Motion.reduced ? -2 : -2 - 8 * applications.appWave
                            scale: Motion.reduced ? 1 : 1.0 + 0.28 * applications.appWave
                            width: 34; height: 34
                            Behavior on scale { NumberAnimation { duration: Motion.reduced ? 0 : 130; easing.type: Easing.OutQuad } }
                            Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: Motion.reduced ? 0 : 130; easing.type: Easing.OutQuad } }
                        }
                    }
                    onClicked: {
                        dock.contextId = "";
                        const p = applications.mapToItem(null, 0, 0);
                        BarState.toggleDockLauncher(dock.modelData.name,
                            {x: p.x, y: dock.modelData.height - dock.height + p.y - (Motion.reduced ? 0 : (1 - motion.progress) * 88),
                                width: applications.width, height: applications.height}, dock);
                    }
                }
                Item {
                    width: 14; height: 64
                    Rectangle { anchors.centerIn: parent; width: 1; height: 28; color: PolyTheme.Theme.withAlpha(Session.muted, 0.25) }
                }
                Repeater {
                    id: buttons
                    model: DockState.groups
                    DockButton {
                        id: button
                        required property var modelData
                        required property int index
                        group: modelData; width: 56; height: 64
                        cursorX: icons.waveCursorX
                        waveActive: icons.waveActive
                        menuOpened: dock.contextId === group.id
                        onHoverChanged: hovered => {
                            if (hovered) { dock.hoverItem = button; dock.hoverId = group.id; }
                            else if (dock.hoverItem === button) { dock.hoverItem = null; dock.hoverId = ""; }
                        }
                        onMenuRequested: {
                            DockState.dismissDockLauncher();
                            dock.contextCenter = button.mapToItem(null, button.width / 2, 0).x;
                            dock.contextId = dock.contextId === group.id ? "" : group.id;
                        }
                    }
                }
            }
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
        }
    }
    Rectangle {
        id: label
        readonly property real center: dock.hoverItem ? dock.hoverItem.mapToItem(null, dock.hoverItem.width / 2, 0).x + strip.contentX * 0 : dock.width / 2
        x: Math.max(16, Math.min(dock.width - width - 16, center - width / 2))
        y: dock.restingY - height - 8
        width: Math.min(280, labelText.implicitWidth + 24); height: 30; radius: Math.min(10, Session.visual.panelRadius)
        visible: dock.opened && motion.progress > 0.95 && !!dock.hoverItem && !dock.contextId && !dock.launcherActive
        color: Session.surface; border.width: 1; border.color: PolyTheme.Theme.withAlpha(Session.accent, 0.25)
        Text {
            id: labelText
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
            text: dock.hoveredGroup ? dock.hoveredGroup.name + (dock.hoveredGroup.windows.length > 1 ? " · " + dock.hoveredGroup.windows.length + " " + I18n.tr("dock.windows_plural") : "") : I18n.tr("dock.all_apps")
            textFormat: Text.PlainText; elide: Text.ElideRight
            color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
    }
    Rectangle {
        id: contextMenu
        property var item: dock.contextGroup
        readonly property int windowCount: item ? item.windows.length : 0
        width: Math.min(320, dock.width - 32)
        height: Math.max(100, Math.min(dock.height - 110, 84 + Math.min(4, windowCount) * 48 + (item && item.entry ? 76 : 0)))
        x: Math.max(16, Math.min(dock.width - width - 16, dock.contextCenter - width / 2))
        y: dock.restingY - height - 12
        visible: dock.opened && !!item
        radius: Math.min(20, Session.visual.panelRadius)
        color: Session.surface; border.width: Session.visual.panelBorder
        border.color: PolyTheme.Theme.withAlpha(Session.accent, 0.35)
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 6
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Image { source: contextMenu.item ? DockState.iconSource(contextMenu.item) : ""; Layout.preferredWidth: 28; Layout.preferredHeight: 28; sourceSize: Qt.size(56, 56) }
                Text { Layout.fillWidth: true; text: contextMenu.item ? contextMenu.item.name : ""; textFormat: Text.PlainText; elide: Text.ElideRight; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 13 }
                BarButton { symbol: "close"; hint: I18n.tr("dock.close_menu"); onClicked: dock.contextId = "" }
            }
            ListView {
                id: windows
                visible: contextMenu.windowCount > 0
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0
                clip: true; spacing: 3; boundsBehavior: Flickable.StopAtBounds
                model: contextMenu.item ? contextMenu.item.windows : []
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Button {
                    id: windowButton
                    required property var modelData
                    width: windows.width; height: 45; padding: 8
                    hoverEnabled: true; focusPolicy: Qt.NoFocus
                    Accessible.name: modelData.title + ", " + I18n.tr("dock.workspace_prefix") + modelData.workspace.name
                    background: Rectangle { radius: Math.min(9, Session.visual.panelRadius); color: PolyTheme.Theme.withAlpha(Session.accent, windowButton.hovered ? 0.18 : windowButton.modelData.active ? 0.09 : 0) }
                    contentItem: Column {
                        spacing: 3
                        Text { width: parent.width; text: windowButton.modelData.title; textFormat: Text.PlainText; elide: Text.ElideRight; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11 }
                        Text { width: parent.width; text: I18n.tr("dock.workspace_prefix") + windowButton.modelData.workspace.name + (windowButton.modelData.active ? " · " + I18n.tr("dock.active_indicator") : ""); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 9 }
                    }
                    onClicked: { DockState.focus(modelData); dock.contextId = ""; }
                }
            }
            Text {
                visible: contextMenu.windowCount === 0
                Layout.fillWidth: true; Layout.fillHeight: true
                text: I18n.tr("dock.app_not_running"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11
                verticalAlignment: Text.AlignVCenter
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: PolyTheme.Theme.withAlpha(Session.muted, 0.2) }
            DayAction {
                visible: !!contextMenu.item && !!contextMenu.item.entry
                Layout.fillWidth: true
                text: I18n.tr("dock.launch_app")
                onClicked: { DockState.launch(dock.contextId); dock.contextId = ""; }
            }
            DayAction {
                visible: !!contextMenu.item && !!contextMenu.item.entry
                Layout.fillWidth: true
                text: contextMenu.item && contextMenu.item.pinned ? I18n.tr("dock.unpin_from_dock") : I18n.tr("dock.pin_to_dock")
                onClicked: { const id = dock.contextId; dock.contextId = ""; DockState.togglePin(id); }
            }
        }
    }
    IpcHandler {
        target: "dock-" + (dock.modelData ? dock.modelData.name : "disconnected")
        function status(): string {
            const items = [];
            for (let i = 0; i < buttons.count; i++) {
                const button = buttons.itemAt(i) as DockButton;
                if (!button) continue;
                const p = button.mapToItem(null, 0, 0);
                items.push({id: button.group.id, x: p.x, y: p.y, width: button.width, height: button.height, windows: button.group.windows.length});
            }
            return JSON.stringify({opened: dock.opened, allowed: dock.allowed, fullscreen: dock.fullscreen,
                progress: motion.progress, pointerInside: dock.pointerInside, keyboardFocus: "none", context: dock.contextId,
                width: dock.dockWidth, height: dock.height, screenY: dock.modelData ? dock.modelData.height - dock.height : 0,
                trigger: {x: (dock.width - dock.dockWidth) / 2, y: dock.height - 3, width: dock.dockWidth, height: 3},
                menu: {x: contextMenu.x, y: contextMenu.y, width: contextMenu.width, height: contextMenu.height}, items: items});
        }
    }
}
