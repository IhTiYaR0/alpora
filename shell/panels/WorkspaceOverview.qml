pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../theme" as PolyTheme
import "../logic/OverviewGeometry.js" as Geometry

Scope {
    id: root
    required property var modelData
    readonly property bool opened: OverviewState.opened && !!modelData && OverviewState.screenName === modelData.name
    readonly property real reveal: OverviewState.screenName === (modelData ? modelData.name : "")
        ? (Motion.reduced ? (opened ? 1 : 0) : OverviewState.progress) : 0
    onOpenedChanged: if (opened) Qt.callLater(function() { const view = contentLoader.item as Item; if (view) view.forceActiveFocus(); })

    // qmllint disable uncreatable-type
    PanelWindow {
        // qmllint enable uncreatable-type
        id: overlay
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore; exclusiveZone: 0
        color: "transparent"
        visible: root.opened || root.reveal > 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "poly-workspace-overview"
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        Loader {
            id: contentLoader
            anchors.fill: parent
            active: overlay.visible
            sourceComponent: overviewContent
            onLoaded: if (root.opened) (item as Item).forceActiveFocus()
        }
    }
    Component {
        id: overviewContent
        FocusScope {
            id: content
            focus: true
            opacity: root.reveal
            readonly property int columns: width >= 1450 ? 5 : width >= 1050 ? 4 : width >= 750 ? 3 : 2
            readonly property real gridWidth: Math.min(1640, width - 64)
            readonly property real tileWidth: gridWidth / columns - 16
            readonly property real tileHeight: (tileWidth - 16) * 9 / 16 + 66
            property var dragClient: null
            property real dragX: 0
            property real dragY: 0
            property int dragTarget: 0
            property var captureStates: ({})
            property bool pointerMode: false
            property int hovered: -1
            property point lastPointer: Qt.point(-1, -1)
            HoverHandler {
                onPointChanged: {
                    const p = point.position;
                    if (root.reveal > 0.99 && Math.hypot(p.x - content.lastPointer.x, p.y - content.lastPointer.y) > 0.1)
                        content.pointerMode = true;
                    content.lastPointer = p;
                }
            }
            function targetAt(x: real, y: real): int {
                for (let i = 0; i < grid.count; i++) {
                    const card = grid.itemAtIndex(i);
                    if (!card) continue;
                    const p = card.mapFromItem(content, x, y);
                    const viewport = grid.mapFromItem(content, x, y);
                    if (viewport.y >= 0 && viewport.y <= grid.height && p.x >= 0 && p.y >= 0 && p.x <= card.width && p.y <= card.height)
                        return OverviewState.workspaces[i].id;
                }
                return 0;
            }
            function updateDrag(client: var, x: real, y: real): void {
                if (OverviewState.busy) return;
                dragClient = client; dragX = x; dragY = y;
                OverviewState.dragging = true;
                dragTarget = targetAt(x, y);
            }
            function finishDrag(): void {
                const client = dragClient, target = dragTarget;
                dragClient = null; dragTarget = 0; OverviewState.dragging = false;
                if (client && target && client.workspace.id !== target) OverviewState.run("move", target, client.address);
            }
            function cancelDrag(): void { dragClient = null; dragTarget = 0; OverviewState.dragging = false; }
            Keys.onPressed: event => {
                content.pointerMode = false;
                if (event.key === Qt.Key_Escape) {
                    if (content.dragClient) content.cancelDrag(); else OverviewState.close();
                } else if (content.dragClient) return;
                else if (event.key === Qt.Key_Left) OverviewState.navigate(-1);
                else if (event.key === Qt.Key_Right) OverviewState.navigate(1);
                else if (event.key === Qt.Key_Up) OverviewState.navigate(-content.columns);
                else if (event.key === Qt.Key_Down) OverviewState.navigate(content.columns);
                else if (event.key === Qt.Key_Tab) OverviewState.navigate(event.modifiers & Qt.ShiftModifier ? -1 : 1);
                else if (event.key === Qt.Key_Home) OverviewState.selected = 0;
                else if (event.key === Qt.Key_End) OverviewState.selected = OverviewState.workspaces.length - 1;
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    OverviewState.run("workspace", OverviewState.workspaces[OverviewState.selected].id, "");
                else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9)
                    OverviewState.run("workspace", event.key === Qt.Key_0 ? 10 : event.key - Qt.Key_0, "");
                else return;
                event.accepted = true;
            }
            // Composite over the live desktop. Wallpaper belongs inside desk
            // previews only; an opaque backdrop would hide the current apps.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: PolyTheme.Theme.withAlpha(Session.background, 0.58) }
                    GradientStop { position: 0.5; color: PolyTheme.Theme.withAlpha(Session.background, 0.32) }
                    GradientStop { position: 1; color: PolyTheme.Theme.withAlpha(Session.background, 0.52) }
                }
            }
            MouseArea { anchors.fill: parent; onClicked: OverviewState.close() }
            Item {
                id: layout
                width: content.gridWidth
                height: Math.min(content.height - 64, grid.height + 206)
                anchors.centerIn: parent
                transform: Translate { y: Motion.reduced ? 0 : (1 - root.reveal) * 40 }
                Text {
                    x: 8; y: 0
                    text: I18n.tr("overview.title")
                    color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 10; font.letterSpacing: 4; font.weight: Font.DemiBold
                }
                Text {
                    x: 6; y: 22
                    text: I18n.tr("overview.subtitle")
                    color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 38; font.weight: Font.DemiBold
                }
                Text {
                    x: 10; y: 77
                    text: I18n.trWith("overview.desks_label", {label: PolyTheme.Theme.label, count: OverviewState.workspaces.length})
                    color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 13
                }
                Button {
                    id: closeButton
                    anchors.right: parent.right; anchors.rightMargin: 8
                    y: 30; width: 90; height: 38
                    text: "Esc    ×"; focusPolicy: Qt.NoFocus
                    Accessible.name: I18n.tr("overview.close")
                    onClicked: OverviewState.close()
                    background: Rectangle { radius: 19; border.width: 1; border.color: PolyTheme.Theme.withAlpha(Session.muted, 0.2); color: closeButton.hovered ? Session.surface : PolyTheme.Theme.withAlpha(Session.surface, 0.5) }
                    contentItem: Text { text: closeButton.text; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                GridView {
                    id: grid
                    x: 0; y: 126; width: parent.width
                    height: Math.max(100, Math.min(Math.ceil(count / content.columns) * cellHeight, content.height - 280))
                    cellWidth: width / content.columns; cellHeight: content.tileHeight + 24
                    clip: true
                    topMargin: 10
                    model: OverviewState.workspaces
                    currentIndex: OverviewState.selected
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                    interactive: !OverviewState.dragging
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property var windows: OverviewState.windows(modelData.id)
                        readonly property var monitor: OverviewState.monitor(modelData.monitor)
                        readonly property bool selected: content.pointerMode ? content.hovered === index : OverviewState.selected === index
                        readonly property bool current: Session.focusedWorkspace === modelData.id
                        readonly property bool dropTarget: !!content.dragClient && content.dragTarget === modelData.id
                        readonly property real entrance: Motion.reduced ? 1 : Math.max(0, Math.min(1, (root.reveal - (index % content.columns) * 0.025 - Math.floor(index / content.columns) * 0.055) / 0.8))
                        property real emphasis: selected || dropTarget ? 1 : 0
                        property real lightX: hover.point.position.x
                        Behavior on emphasis { NumberAnimation { duration: Motion.responseMs; easing.type: Easing.OutCubic } }
                        Behavior on lightX { NumberAnimation { duration: Motion.responseMs; easing.type: Easing.OutCubic } }
                        width: content.tileWidth; height: content.tileHeight
                        radius: Math.min(22, Session.visual.panelRadius)
                        color: "transparent"
                        opacity: entrance
                        scale: 0.86 + entrance * 0.14
                        rotation: Motion.reduced ? 0 : ((index % content.columns) - (content.columns - 1) / 2) * 2.5 * (1 - entrance)
                        transform: Translate {
                            x: Motion.reduced ? 0 : ((content.columns - 1) / 2 - card.index % content.columns) * 22 * (1 - card.entrance)
                            y: Motion.reduced ? 0 : (1 - card.entrance) * (100 + Math.floor(card.index / content.columns) * 32)
                        }
                        HoverHandler {
                            id: hover
                            onHoveredChanged: {
                                if (hovered && !content.dragClient) content.hovered = card.index;
                                else if (content.hovered === card.index) content.hovered = -1;
                            }
                        }
                        Rectangle {
                            x: 2; y: 8; width: parent.width - 4; height: parent.height
                            radius: card.radius + 2; color: PolyTheme.Theme.withAlpha(Session.background, 0.55)
                        }
                        Rectangle {
                            anchors.fill: parent; radius: card.radius
                            color: Session.surface
                            border.width: 2
                            border.color: PolyTheme.Theme.mix(PolyTheme.Theme.mix(Session.surface, Session.muted, 0.3), Session.accent, card.emphasis)
                        }
                        Item {
                            id: scene
                            anchors.fill: parent; anchors.margins: 3
                            layer.enabled: true
                            layer.effect: MultiEffect { maskEnabled: true; maskSource: sceneMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1 }
                            Image {
                                anchors.fill: parent
                                source: OverviewState.wallpaper ? "file://" + OverviewState.wallpaper : ""
                                sourceSize: Qt.size(640, 400); fillMode: Image.PreserveAspectCrop; smooth: true
                                horizontalAlignment: card.index % content.columns < content.columns / 2 ? Image.AlignLeft : Image.AlignRight
                            }
                            Image {
                                anchors.fill: parent
                                source: OverviewState.upperWallpaper ? "file://" + OverviewState.upperWallpaper : ""
                                sourceSize: Qt.size(640, 400); fillMode: Image.PreserveAspectCrop; smooth: true
                                opacity: TimelineState.active ? TimelineState.segment.blend : 0
                                horizontalAlignment: card.index % content.columns < content.columns / 2 ? Image.AlignLeft : Image.AlignRight
                            }
                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0; color: PolyTheme.Theme.withAlpha(Session.background, 0.08) }
                                    GradientStop { position: 0.5; color: PolyTheme.Theme.withAlpha(Session.background, 0.12) }
                                    GradientStop { position: 1; color: PolyTheme.Theme.withAlpha(Session.background, 0.97) }
                                }
                            }
                            // The reflection moves inside a fixed, rounded surface.
                            // It never moves the hit area or any captured window.
                            Rectangle {
                                x: card.lightX - width / 2; y: -scene.height * 0.4
                                width: scene.width * 0.55; height: scene.height * 1.8
                                rotation: 18; opacity: card.emphasis * 0.8
                                visible: !Motion.reduced
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 0.5; color: PolyTheme.Theme.withAlpha(Session.foreground, 0.16) }
                                    GradientStop { position: 1; color: "transparent" }
                                }
                            }
                            Rectangle {
                                anchors.fill: parent; radius: card.radius - 3; color: "transparent"
                                border.width: 1; border.color: PolyTheme.Theme.withAlpha(Session.foreground, 0.12 + card.emphasis * 0.22)
                            }
                        }
                        Rectangle {
                            id: sceneMask
                            width: scene.width; height: scene.height; radius: Math.max(0, card.radius - 3)
                            color: "white"; visible: false; layer.enabled: true
                        }
                        Rectangle {
                            x: Math.max(16, Math.min(parent.width - width - 16, card.lightX - width / 2)); y: 2
                            width: parent.width * 0.4; height: 2; radius: 1
                            opacity: card.emphasis
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: "transparent" }
                                GradientStop { position: 0.5; color: Session.accent }
                                GradientStop { position: 1; color: "transparent" }
                            }
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: I18n.trWith("overview.workspace_a11y", {name: modelData.name, count: windows.length})
                        Accessible.onPressAction: OverviewState.run("workspace", card.modelData.id, "")
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: OverviewState.run("workspace", card.modelData.id, "")
                        }
                        Rectangle {
                            x: 16; y: 16; width: 6; height: 6; radius: 3
                            color: Session.accent; visible: card.current
                        }
                        Text {
                            x: 28; y: 12; visible: card.current
                            text: I18n.tr("overview.current"); font.letterSpacing: 1.2
                            color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 8; font.weight: Font.DemiBold
                        }
                        Text {
                            x: 17; y: parent.height - 59
                            text: card.modelData.id > 0 ? String(card.modelData.id).padStart(2, "0") : "◆"
                            color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 38; font.weight: Font.Light
                        }
                        Text {
                            x: 74; y: parent.height - 50; width: parent.width - 176; elide: Text.ElideRight
                            text: card.modelData.id > 0 ? I18n.tr("overview.workspace") : card.modelData.name
                            color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold
                        }
                        Text {
                            x: 74; y: parent.height - 31; width: parent.width - 150; elide: Text.ElideRight
                            text: card.windows.length ? OverviewState.windowLabel(card.windows.length) : content.dragClient ? I18n.tr("overview.drop_here") : I18n.tr("overview.empty")
                            color: card.current ? Session.accent : Session.muted; font.family: Session.fontFamily; font.pixelSize: 10
                        }
                        Rectangle {
                            x: parent.width - appShelf.width - 16; y: parent.height - 47
                            width: appShelf.width + 12; height: 30; radius: 15
                            visible: card.windows.length > 0
                            color: PolyTheme.Theme.withAlpha(Session.surface, 0.8)
                            border.width: 1; border.color: PolyTheme.Theme.withAlpha(Session.foreground, 0.18)
                        }
                        Row {
                            id: appShelf
                            anchors.right: parent.right; anchors.rightMargin: 10; y: parent.height - 44; spacing: 3
                            Repeater {
                                model: card.windows.slice(0, 3)
                                Rectangle {
                                    required property var modelData
                                    width: 24; height: 24; radius: 8; color: "transparent"
                                    Image { anchors.fill: parent; anchors.margins: 3; source: OverviewState.appIcon(parent.modelData); sourceSize: Qt.size(36, 36); smooth: true }
                                }
                            }
                        }
                        Rectangle {
                            id: desktop
                            x: 8; y: 30; width: parent.width - 16; height: parent.height - 96
                            color: "transparent"; radius: Math.max(4, card.radius - 6); clip: true
                            Rectangle {
                                anchors.centerIn: parent
                                width: 46; height: 46; radius: 23
                                visible: card.windows.length === 0
                                opacity: content.dragClient ? 1 : card.emphasis * 0.8
                                color: PolyTheme.Theme.withAlpha(Session.background, 0.3)
                                border.width: 1; border.color: PolyTheme.Theme.withAlpha(Session.foreground, 0.45)
                                Text { anchors.centerIn: parent; text: "+"; color: Session.foreground; font.pixelSize: 24; font.weight: Font.Light }
                            }
                            Repeater {
                                model: card.windows
                                Rectangle {
                                    id: preview
                                    required property var modelData
                                    readonly property var box: Geometry.windowBox(modelData, card.monitor, desktop.width, desktop.height)
                                    readonly property bool beingDragged: !!content.dragClient && content.dragClient.address === modelData.address
                                    x: box.x; y: box.y; width: box.width; height: box.height
                                    visible: width > 2 && height > 2
                                    opacity: beingDragged ? 0.3 : 1
                                    color: Session.surface; radius: 5; clip: true
                                    border.width: windowMouse.containsMouse ? 2 : 1
                                    border.color: windowMouse.containsMouse ? Session.accent : PolyTheme.Theme.withAlpha(Session.muted, 0.45)
                                    ScreencopyView {
                                        id: capture
                                        anchors.fill: parent; anchors.margins: 1
                                        captureSource: OverviewState.capture(preview.modelData.address)
                                        live: false; paintCursor: false
                                        constraintSize: Qt.size(Math.ceil(preview.width * overlay.devicePixelRatio), Math.ceil(preview.height * overlay.devicePixelRatio))
                                        onHasContentChanged: {
                                            const states = Object.assign({}, content.captureStates);
                                            states[preview.modelData.address] = hasContent;
                                            content.captureStates = states;
                                        }
                                    }
                                    Text {
                                        anchors.centerIn: parent; width: parent.width - 12
                                        visible: !capture.hasContent
                                        text: preview.modelData.class || I18n.tr("overview.window"); elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                                        color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12
                                    }
                                    Rectangle {
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                        height: 23; color: PolyTheme.Theme.withAlpha(Session.background, 0.92)
                                        opacity: card.selected || windowMouse.containsMouse ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: Motion.responseMs } }
                                        Text { anchors.fill: parent; anchors.margins: 5; text: (preview.modelData.pinned ? "∞  " : "") + preview.modelData.title; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 10; elide: Text.ElideRight }
                                    }
                                    MouseArea {
                                        id: windowMouse
                                        anchors.fill: parent; hoverEnabled: true; preventStealing: true
                                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                        property real startX: 0
                                        property real startY: 0
                                        property bool moved: false
                                        property bool cancelled: false
                                        onPressed: mouse => { startX = mouse.x; startY = mouse.y; moved = false; cancelled = false; }
                                        onPositionChanged: mouse => {
                                            if (!pressed || cancelled) return;
                                            if (!moved && Math.hypot(mouse.x - startX, mouse.y - startY) < 8) return;
                                            moved = true;
                                            const p = mapToItem(content, mouse.x, mouse.y);
                                            content.updateDrag(preview.modelData, p.x, p.y);
                                        }
                                        onReleased: {
                                            if (moved) content.finishDrag();
                                            else OverviewState.run("focus", card.modelData.id, preview.modelData.address);
                                        }
                                        onCanceled: content.cancelDrag()
                                        Connections {
                                            target: OverviewState
                                            function onDraggingChanged(): void {
                                                if (!OverviewState.dragging && windowMouse.pressed && windowMouse.moved) windowMouse.cancelled = true;
                                            }
                                        }
                                    }
                                }
                            }
                            Rectangle { anchors.fill: parent; color: PolyTheme.Theme.withAlpha(Session.accent, 0.16); visible: card.dropTarget; border.width: 2; border.color: Session.accent; radius: 10 }
                        }
                    }
                }
                Text {
                    x: 8; y: grid.y + grid.height + 18; width: parent.width - 16
                    text: OverviewState.error || (content.dragClient ? I18n.tr("overview.drag_active") : I18n.tr("overview.drag_hint"))
                    color: OverviewState.error ? Session.accent : Session.muted
                    font.family: Session.fontFamily; font.pixelSize: 12; wrapMode: Text.WordWrap
                }
            }
            Loader {
                active: !!content.dragClient
                x: content.dragX - width / 2; y: content.dragY - 30
                width: 220; height: 144; z: 100
                sourceComponent: Rectangle {
                    radius: 12; color: Session.surface; border.width: 2; border.color: Session.accent; clip: true
                    ScreencopyView {
                        anchors.fill: parent; anchors.margins: 4
                        captureSource: content.dragClient ? OverviewState.capture(content.dragClient.address) : null
                        live: false; constraintSize: Qt.size(440, 288)
                    }
                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                        height: 30; color: Session.surface
                        Text { anchors.fill: parent; anchors.margins: 8; text: content.dragClient ? content.dragClient.title : ""; elide: Text.ElideRight; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11 }
                    }
                }
            }
            IpcHandler {
                target: "overview-layout-" + root.modelData.name
                function status(): string {
                    const tiles = [];
                    for (let i = 0; i < grid.count; i++) {
                        const item = grid.itemAtIndex(i);
                        if (!item) continue;
                        const p = item.mapToItem(content, 0, 0), ws = OverviewState.workspaces[i];
                        const windows = OverviewState.windows(ws.id).map(client => {
                            const b = Geometry.windowBox(client, OverviewState.monitor(ws.monitor), item.width - 16, item.height - 96);
                            return {address: client.address, x: p.x + 8 + b.x, y: p.y + 30 + b.y, width: b.width, height: b.height, captured: !!content.captureStates[client.address]};
                        });
                        tiles.push({id: ws.id, x: p.x, y: p.y, width: item.width, height: item.height, windows: windows});
                    }
                    return JSON.stringify({columns: content.columns, tiles: tiles, dragging: !!content.dragClient, dropTarget: content.dragTarget,
                        scrollY: grid.contentY, hovered: content.hovered, pointerMode: content.pointerMode, keyboardIndex: OverviewState.selected});
                }
            }
        }
    }
    IpcHandler {
        target: "overview-" + (root.modelData ? root.modelData.name : "disconnected")
        function status(): string { return JSON.stringify({visible: overlay.visible, opened: root.opened, reveal: root.reveal, loaded: contentLoader.active}); }
    }
}
