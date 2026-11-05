pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Scope {
    id: root
    required property var modelData
    property bool opened: false
    Connections {
        target: LandscapeState
        function onThemeRequested(screenName: string, x: real, y: real): void {
            if (root.modelData && root.modelData.name === screenName) root.openAt(x, y);
        }
    }
    // One reversible timeline drives the entire fan; no per-card timers.
    property real reveal: opened ? 1 : 0
    property int hoveredIndex: -1
    property real orbit: 0
    property real direction: -90
    property real cursorX: 0
    property real cursorY: 0
    property string dragId: ""
    property string dragImage: ""
    property string dragLabel: ""
    property real dragX: 0
    property real dragY: 0
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property real dragScale: 1
    property var lastDrop: null
    WallpaperReveal {
        id: wallpaperReveal
        screen: root.modelData
        decodeSize: Qt.size(root.modelData ? root.modelData.width : 1920, root.modelData ? root.modelData.height : 1080)
    }
    onOpenedChanged: if (!opened) dragId = ""
    Behavior on orbit { NumberAnimation { duration: Motion.reduced ? 0 : Session.visual.panelOpenMs * 2; easing.type: Easing.OutQuint } }
    Behavior on direction { NumberAnimation { duration: Motion.reduced ? 0 : 260; easing.type: Easing.OutCubic } }
    Behavior on cursorX { NumberAnimation { duration: Motion.responseMs; easing.type: Easing.OutCubic } }
    Behavior on cursorY { NumberAnimation { duration: Motion.responseMs; easing.type: Easing.OutCubic } }
    function aim(index: int): void {
        const target = -90 + index * 360 / Math.max(1, choices.length);
        direction += ((target - direction + 540) % 360 + 360) % 360 - 180;
    }
    function turn(delta: real): void {
        if (!opened || ThemeState.busy || dragId.length) return;
        orbit += (delta < 0 ? 1 : -1) * 360 / Math.max(1, choices.length);
    }
    Behavior on reveal {
        NumberAnimation {
            duration: Motion.reduced ? 0 : root.opened ? Session.visual.panelOpenMs : Session.visual.panelCloseMs
            easing.type: root.opened ? Easing.OutCubic : Easing.InCubic
        }
    }
    property real pointerX: 0
    property real pointerY: 0
    property int page: 0
    readonly property int pageCount: Math.max(1, Math.ceil(ThemeState.items.length / 7))
    readonly property var choices: ThemeState.items.slice(page * 7, page * 7 + 7)
    function shortLabel(theme: var): string {
        const labels = {"alpine": I18n.tr("theme.alpine"), "moon-lake": I18n.tr("theme.moon_lake"), "forest-mist": I18n.tr("theme.forest_mist"),
            "warm-desert": I18n.tr("theme.warm_desert"), "northern-lights": I18n.tr("theme.northern_lights"), "rose-sunset": I18n.tr("theme.rose_sunset"), "timeline": "Timeline"};
        return labels[theme.id] || theme.label;
    }
    function openAt(x: real, y: real): void {
        pointerX = x; pointerY = y; page = 0; hoveredIndex = -1; cursorX = 0; cursorY = 0;
        BarState.close();
        ThemeState.refresh();
        opened = true;
        Qt.callLater(function() { keyboard.forceActiveFocus(); });
    }
    function choose(id: string, origin: var): void {
        if (ThemeState.busy) return;
        if (id === ThemeState.baseId) { opened = false; return; }
        // Use the saved color preference; the settings window owns its own draft.
        const payload = {id: id, colorsFromWallpaper: ThemeState.baseAutomatic};
        if (origin) {
            payload.transition = origin;
            wallpaperReveal.startAt(origin.x * overlay.width, origin.y * overlay.height);
        } else {
            const item = ThemeState.items.find(t => t.id === id);
            if (item && item.image) wallpaperReveal.crossfade(item.image);
        }
        ThemeState.request("apply", payload);
    }
    Connections {
        target: ThemeState
        function onMessageChanged(): void {
            if (ThemeState.action === "apply" && (ThemeState.message === I18n.tr("theme.applied") || ThemeState.message === I18n.tr("theme.saved"))) root.opened = false;
        }
    }
    Connections {
        target: ClockState
        function onPreparingForSleep(): void { root.opened = false; }
    }
    Connections {
        target: OverviewState
        function onOpenedChanged(): void { if (OverviewState.opened) root.opened = false; }
    }
    // A bottom-layer input surface only receives exposed desktop clicks.
    // Applications and desktop widget surfaces remain above it.
    // qmllint disable uncreatable-type
    PanelWindow {
        // qmllint enable uncreatable-type
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore; exclusiveZone: 0
        color: "transparent"
        visible: Session.loaded && !!root.modelData && !LandscapeState.enabled
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "poly-desktop-input"
        mask: DesktopInputRegion { screenData: root.modelData }
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: mouse => root.openAt(mouse.x, mouse.y)
        }
    }
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
        WlrLayershell.namespace: "poly-theme-picker"
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        HoverHandler {
            enabled: root.opened
            onPointChanged: {
                root.cursorX = Math.max(-1, Math.min(1, (point.position.x - ring.x - 220 * ring.fit) / (220 * ring.fit)));
                root.cursorY = Math.max(-1, Math.min(1, (point.position.y - ring.y - 220 * ring.fit) / (220 * ring.fit)));
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.opened
            acceptedButtons: Qt.AllButtons
            onClicked: root.opened = false
            onWheel: wheel => {
                root.turn(wheel.angleDelta.y || wheel.pixelDelta.y);
            }
        }
        FocusScope {
            id: keyboard
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.opened = false
            Keys.onLeftPressed: root.turn(1)
            Keys.onRightPressed: root.turn(-1)
            Item {
                id: ring
                readonly property real fit: Math.min(1, overlay.width / 460, overlay.height / 460)
                width: 440; height: 440
                scale: fit; transformOrigin: Item.TopLeft
                transform: [
                    Rotation { origin.x: 220; origin.y: 220; axis.x: 1; axis.y: 0; axis.z: 0; angle: Motion.reduced ? 0 : -root.cursorY * 7 },
                    Rotation { origin.x: 220; origin.y: 220; axis.x: 0; axis.y: 1; axis.z: 0; angle: Motion.reduced ? 0 : root.cursorX * 9 }
                ]
                x: Math.max(8, Math.min(root.pointerX - width * fit / 2, overlay.width - width * fit - 8))
                y: Math.max(8, Math.min(root.pointerY - height * fit / 2, overlay.height - height * fit - 8))
                // Broken orbital rails form a compass, drawn below the cards.
                Repeater {
                    model: root.choices.length
                    Shape {
                        id: rail
                        required property int index
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        opacity: root.reveal * (root.hoveredIndex === index ? 0.85 : 0.3)
                        Behavior on opacity { NumberAnimation { duration: Motion.responseMs } }
                        ShapePath {
                            strokeColor: Session.accent; strokeWidth: rail.index === root.hoveredIndex ? 2 : 1
                            fillColor: "transparent"; capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: 220; centerY: 220
                                radiusX: 103 * root.reveal; radiusY: 103 * root.reveal
                                startAngle: -90 + rail.index * 360 / Math.max(1, root.choices.length) + root.orbit - 15 - (Motion.reduced ? 0 : (1 - root.reveal) * 60)
                                sweepAngle: 30 * root.reveal
                            }
                        }
                    }
                }
                Item {
                    anchors.centerIn: parent
                    width: 0; height: 0
                    rotation: root.direction + root.orbit
                    opacity: root.reveal * (root.hoveredIndex >= 0 ? 0.8 : 0.3)
                    Behavior on opacity { NumberAnimation { duration: Motion.responseMs } }
                    Rectangle {
                        x: 30; y: -1
                        width: (root.hoveredIndex >= 0 ? 65 : 16) * root.reveal; height: 2; radius: 1
                        color: Session.accent
                        Behavior on width { NumberAnimation { duration: Motion.reduced ? 0 : 220; easing.type: Easing.OutCubic } }
                    }
                    Rectangle { x: 26; y: -3; width: 6; height: 6; rotation: 45; color: Session.accent }
                }
                Repeater {
                    model: root.choices
                    Button {
                        id: tile
                        required property int index
                        required property var modelData
                        readonly property real arrival: Motion.reduced ? root.reveal : Math.max(0, Math.min(1, root.reveal * 1.36 - index * 0.055))
                        readonly property real angle: -Math.PI / 2 + index * 2 * Math.PI / root.choices.length + root.orbit * Math.PI / 180 - (Motion.reduced ? 0 : (1 - arrival) * 1.05)
                        property real lift: hovered || visualFocus ? 1 : 0
                        Behavior on lift { NumberAnimation { duration: Motion.responseMs; easing.type: Easing.OutCubic } }
                        readonly property bool current: modelData.id === ThemeState.baseId
                        width: 112; height: 82
                        x: ring.width / 2 + Math.cos(angle) * (154 * arrival + 9 * lift) - width / 2 + (Motion.reduced ? 0 : root.cursorX * 5 * lift)
                        y: ring.height / 2 + Math.sin(angle) * (154 * arrival + 9 * lift) - height / 2 + (Motion.reduced ? 0 : root.cursorY * 5 * lift)
                        opacity: arrival * (root.dragId === modelData.id ? 0 : 1)
                        scale: Motion.reduced ? 1 : 0.25 + 0.75 * arrival + 0.07 * lift
                        rotation: Motion.reduced ? 0 : (1 - arrival) * -9
                        z: hovered || visualFocus ? 2 : 1
                        padding: 5
                        hoverEnabled: true
                        enabled: root.opened && root.reveal > 0.65 && !ThemeState.busy
                        onHoveredChanged: {
                            if (hovered) { root.hoveredIndex = index; root.aim(index); wallpaperReveal.prepare(modelData.image); }
                            else if (root.hoveredIndex === index) root.hoveredIndex = -1;
                        }
                        onVisualFocusChanged: if (visualFocus) { root.hoveredIndex = index; root.aim(index); }
                        WheelHandler { onWheel: event => { root.turn(event.angleDelta.y || event.pixelDelta.y); event.accepted = true; } }
                        Accessible.name: modelData.label
                        onPressed: wallpaperReveal.prepare(modelData.image)
                        onClicked: {
                            const p = tile.mapToItem(keyboard, tile.width / 2, tile.height / 2);
                            root.choose(modelData.id, {x: Math.max(0, Math.min(1, p.x / overlay.width)), y: Math.max(0, Math.min(1, p.y / overlay.height))});
                        }
                        DragHandler {
                            id: drag
                            target: null
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.ClosedHandCursor
                            enabled: root.opened && !ThemeState.busy
                            function updatePoint(): void {
                                root.dragX = Math.max(0, Math.min(overlay.width, centroid.scenePosition.x));
                                root.dragY = Math.max(0, Math.min(overlay.height, centroid.scenePosition.y));
                            }
                            onCentroidChanged: if (active) updatePoint()
                            onCanceled: root.dragId = ""
                            onActiveChanged: {
                                if (active) {
                                    root.dragId = tile.modelData.id;
                                    root.dragImage = tile.modelData.image;
                                    wallpaperReveal.prepare(tile.modelData.image);
                                    root.dragLabel = root.shortLabel(tile.modelData);
                                    root.dragScale = tile.scale * ring.fit;
                                    root.dragOffsetX = centroid.pressPosition.x * root.dragScale;
                                    root.dragOffsetY = centroid.pressPosition.y * root.dragScale;
                                    updatePoint();
                                } else if (root.dragId === tile.modelData.id && root.opened) {
                                    updatePoint();
                                    const origin = {x: root.dragX / overlay.width, y: root.dragY / overlay.height};
                                    root.lastDrop = {id: root.dragId, x: origin.x, y: origin.y};
                                    root.dragId = "";
                                    root.choose(tile.modelData.id, origin);
                                }
                            }
                        }
                        background: Rectangle {
                            radius: Session.visual.panelRadius
                            color: Glass.materialBottom(Session.visual.panelOpacity)
                            border.width: tile.current || tile.visualFocus || tile.hovered ? Math.max(2, Session.visual.panelBorder) : Session.visual.panelBorder
                            border.color: tile.current || tile.visualFocus || tile.hovered ? Session.accent : Session.muted
                            Behavior on border.color { ColorAnimation { duration: Motion.responseMs } }
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Session.accent
                                opacity: tile.lift * 0.09
                            }
                        }
                        contentItem: Item {
                            SettingsImage {
                                width: parent.width; height: 50
                                radius: Math.max(0, Session.visual.panelRadius - 5)
                                source: "file://" + encodeURI(tile.modelData.image).replace(/#/g, "%23").replace(/\?/g, "%3F")
                                sourceSize: Qt.size(224, 100)
                            }
                            Text {
                                anchors.bottom: parent.bottom; width: parent.width
                                text: root.shortLabel(tile.modelData)
                                color: Session.foreground
                                font.family: Session.fontFamily; font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight; textFormat: Text.PlainText
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.top: parent.top
                                width: 18; height: 18; radius: 9
                                visible: tile.current
                                color: Session.surface
                                border.width: 1; border.color: Session.accent
                                Icon { anchors.centerIn: parent; name: "check"; width: 12; height: 12 }
                            }
                        }
                    }
                }
                // Seven quiet points connect the small hub to the theme fan.
                Repeater {
                    model: root.choices.length
                    Rectangle {
                        id: point
                        required property int index
                        readonly property bool highlighted: root.hoveredIndex === index
                        readonly property real angle: -Math.PI / 2 + index * 2 * Math.PI / root.choices.length + root.orbit * Math.PI / 180
                        width: highlighted ? 5 : 3; height: width; radius: width / 2
                        x: ring.width / 2 + Math.cos(angle) * (25 + 7 * root.reveal) - width / 2
                        y: ring.height / 2 + Math.sin(angle) * (25 + 7 * root.reveal) - height / 2
                        color: Session.accent
                        opacity: root.reveal * (highlighted ? 1 : 0.32)
                        Behavior on width { NumberAnimation { duration: Motion.responseMs } }
                        Behavior on opacity { NumberAnimation { duration: Motion.responseMs } }
                    }
                }
                Button {
                    id: hub
                    anchors.centerIn: parent
                    width: 42; height: 42
                    hoverEnabled: true
                    enabled: root.opened
                    opacity: root.reveal
                    scale: Motion.reduced ? 1 : 0.7 + 0.3 * root.reveal
                    Accessible.name: root.pageCount > 1 ? I18n.tr("theme.next_themes") : I18n.tr("theme.close_menu")
                    onClicked: {
                        if (root.pageCount > 1) root.page = (root.page + 1) % root.pageCount;
                        else root.opened = false;
                    }
                    background: Rectangle {
                        radius: 21
                        color: Glass.materialBottom(Session.visual.panelOpacity)
                        border.width: hub.visualFocus ? 2 : 0
                        border.color: Session.accent
                        Rectangle {
                            anchors.fill: parent; radius: parent.radius
                            color: Session.accent
                            opacity: hub.hovered || hub.visualFocus ? 0.16 : 0.06
                            Behavior on opacity { NumberAnimation { duration: Motion.responseMs } }
                        }
                    }
                    contentItem: Item {
                        Icon {
                            anchors.centerIn: parent; width: 18; height: 18
                            name: root.pageCount > 1 ? "palette" : "close"
                            rotation: Motion.reduced ? 0 : (1 - root.reveal) * -90
                        }
                        Text {
                            anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                            visible: root.pageCount > 1
                            text: (root.page + 1) + "/" + root.pageCount
                            color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 9
                        }
                    }
                }
                Rectangle {
                    id: caption
                    readonly property string label: ThemeState.error || (ThemeState.busy ? I18n.tr("theme.applying") : root.hoveredIndex >= 0 && root.choices[root.hoveredIndex] ? root.choices[root.hoveredIndex].label : "")
                    x: (parent.width - width) / 2; y: 405
                    width: Math.min(400, captionText.implicitWidth + 24)
                    height: captionText.implicitHeight + 14
                    radius: Math.min(Session.visual.panelRadius, height / 2)
                    color: Glass.materialBottom(Session.visual.panelOpacity)
                    opacity: label.length ? root.reveal : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.responseMs } }
                    Text {
                        id: captionText
                        anchors.centerIn: parent
                        width: Math.min(376, implicitWidth)
                        text: caption.label
                        color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap; textFormat: Text.PlainText
                    }
                }
            }
            Item {
                visible: root.dragId.length > 0
                x: root.dragX - root.dragOffsetX
                y: root.dragY - root.dragOffsetY
                scale: root.dragScale
                transformOrigin: Item.TopLeft
                Rectangle {
                    width: 112; height: 82
                    radius: Session.visual.panelRadius
                    color: Glass.materialBottom(Session.visual.panelOpacity)
                    border.width: Math.max(2, Session.visual.panelBorder); border.color: Session.accent
                    SettingsImage {
                        x: 5; y: 5; width: 102; height: 50
                        radius: Math.max(0, Session.visual.panelRadius - 5)
                        source: root.dragImage.length ? "file://" + encodeURI(root.dragImage).replace(/#/g, "%23").replace(/\?/g, "%3F") : ""
                        sourceSize: Qt.size(224, 100)
                    }
                    Text {
                        x: 5; y: 61; width: 102
                        text: root.dragLabel
                        color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
    IpcHandler {
        target: "theme-menu-" + (root.modelData ? root.modelData.name : "disconnected")
        function open(x: real, y: real): void { root.openAt(x, y); }
        function close(): void { root.opened = false; }
        function turn(delta: real): void { root.turn(delta); }
        function status(): string { return JSON.stringify({opened: root.opened, visible: overlay.visible, reveal: root.reveal, orbit: root.orbit, direction: root.direction, tilt: [root.cursorX, root.cursorY], dragging: root.dragId, dragPoint: [root.dragX, root.dragY], dragOffset: [root.dragOffsetX, root.dragOffsetY], lastDrop: root.lastDrop, wallpaper: {showing: wallpaperReveal.showing, progress: wallpaperReveal.progress, loading: wallpaperReveal.pendingStart}, reduced: Motion.reduced, count: ThemeState.items.length, page: root.page, busy: ThemeState.busy, error: ThemeState.error}); }
    }
}
