pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: bar
    required property var modelData
    screen: modelData
    anchors { top: true; left: true; right: true }
    readonly property int barHeight: Session.visual.barHeight
    readonly property int outerMargin: Math.min(Session.visual.barLeft, Math.max(0, (width - 500) / 2))
    readonly property int rightMargin: Math.min(Session.visual.barRight, Math.max(0, (width - 500) / 2))
    readonly property int topMargin: Session.visual.barTop
    readonly property real uiScale: Session.settings && Session.settings.bar && Session.settings.bar.uiScale ? Number(Session.settings.bar.uiScale) : 1.0
    readonly property string screenName: modelData ? modelData.name : ""
    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property int activeWorkspace: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
    readonly property Item launcherSource: launcherButton
    readonly property Item clockSource: clockButton
    readonly property Item timelineSource: timelineButton
    readonly property Item clipboardSource: clipboardButton
    readonly property bool clipboardHovered: clipboardButton.hovered || clipboardTransit.hovered
    readonly property Item notificationSource: bell
    readonly property Item traySource: trayButton
    readonly property Item quickSource: statusButton
    property bool launcherPreviewBlocked: false
    function rearmLauncherHover(x: real, y: real): void {
        const source = buttonBounds(launcherButton);
        if (x < source.x || x > source.x + source.width || y < source.y || y > source.y + source.height)
            launcherPreviewBlocked = false;
    }
    readonly property bool launcherHovered: launcherButton.hovered || launcherTransit.hovered
    readonly property bool quickHovered: statusButton.hovered || statusTransit.hovered
    readonly property bool centerHovered: clockButton.hovered || clockTransit.hovered
    readonly property bool timelineHovered: timelineButton.hovered
    readonly property bool trayHovered: trayButton.hovered
    readonly property bool notificationHovered: bell.hovered || bellTransit.hovered
    property real popupAnchorX: width / 2
    property string lastActivation: ""
    readonly property bool compact: width < 1150
    readonly property int workspaceSlots: Math.max(1, Math.min(Session.settings.bar ? Session.settings.bar.workspaceCount : 4,
        Math.floor((surface.width / 2 - 130) / 41)))
    readonly property int workspaceStart: Math.min(11 - workspaceSlots, Math.floor((Math.max(1, activeWorkspace) - 1) / workspaceSlots) * workspaceSlots + 1)
    implicitHeight: topMargin + barHeight + Session.visual.barBottom
    exclusiveZone: implicitHeight
    color: "transparent"
    visible: !!modelData && Session.loaded
    WlrLayershell.namespace: "poly-shell"
    // While a modal panel is open, keep its navigation buttons on the same
    // layer so compositor input routing can reach the allowed bar surface.
    WlrLayershell.layer: WlrLayer.Overlay
    // The persistent bar must never take typing focus from applications.
    // Global shortcuts belong to Hyprland, not this surface's keyboard focus.
    WlrLayershell.keyboardFocus: activePanel && activePanel !== appLauncher && !BarState.selection.preview ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        Region {
            x: surface.x; y: surface.y
            width: surface.width
            height: surface.height
        }
    }
    // Give the companion the larger genuinely empty lane, derived from the
    // actual bar layout; labels, workspaces, clock and status remain clear.
    DesktopCompanion {
        modelData: bar.modelData
        readonly property real leftStart: surface.x + leftGroup.x + leftGroup.width + 14
        readonly property real leftEnd: surface.x + clockButton.x - 14
        readonly property real rightStart: surface.x + clockButton.x + clockButton.width + (TimelineState.active ? 94 : 0) + 14
        readonly property real rightEnd: surface.x + rightGroup.x - 14
        readonly property bool useLeft: leftEnd - leftStart >= rightEnd - rightStart
        railLeft: useLeft ? leftStart : rightStart
        railRight: useLeft ? leftEnd : rightEnd
        railBottom: surface.y + surface.height - 2
    }
    function openPanel(name: string, button: Item): void {
        lastActivation = name;
        popupAnchorX = button.mapToItem(null, button.width / 2, 0).x;
        BarState.toggle(name, bar.screenName);
    }
    function buttonBounds(button: Item): var {
        const point = button.mapToItem(null, 0, 0);
        return { x: point.x, y: point.y, width: button.width, height: button.height,
            enabled: button.enabled };
    }
    IpcHandler {
        target: "bar-" + (bar.screenName || "disconnected")
        function controls(): string {
            return JSON.stringify({ launcher: bar.buttonBounds(launcherButton),
                calendar: bar.buttonBounds(clockButton),
                clipboard: bar.buttonBounds(clipboardButton),
                notifications: bar.buttonBounds(bell),
                tray: Object.assign(bar.buttonBounds(trayButton), {visible: trayButton.visible}),
                timeline: Object.assign(bar.buttonBounds(timelineButton), {visible: timelineButton.visible}),
                quickSettings: Object.assign(bar.buttonBounds(statusButton), {networkVisible: statusButton.networkVisible, bluetoothVisible: statusButton.bluetoothVisible, audioVisible: statusButton.audioVisible, batteryVisible: statusButton.batteryVisible}), network: Session.networkStatus, audio: Session.audioStatus, bluetooth: Session.bluetoothDescription,
                visible: bar.visible, surfaceOpacity: surface.opacity, launcherHovered: bar.launcherHovered, launcherButtonHovered: launcherButton.hovered, launcherBridgeHovered: launcherTransit.hovered, notificationHovered: bar.notificationHovered, bellHovered: bell.hovered, bellBridge: bellTransit.hovered, lastActivation: bar.lastActivation, focusGrabActive: panelGrab.active });
        }
    }
    Item {
        // The clipboard bridge extends down to the panel, never sideways over
        // the notification button or another bar control.
        x: surface.x + rightGroup.x + clipboardButton.x
        y: surface.y + rightGroup.y + clipboardButton.y
        width: clipboardButton.width
        height: bar.topMargin + bar.barHeight - y
        HoverHandler { id: clipboardTransit }
    }
    Item {
        x: surface.x + leftGroup.x + launcherButton.x
        y: surface.y + leftGroup.y + launcherButton.y
        width: launcherButton.width
        height: bar.topMargin + bar.barHeight - y
        HoverHandler { id: launcherTransit; onHoveredChanged: if (!hovered && bar.launcherPreviewBlocked) appLauncher.closePreviewOutside() }
    }
    SoftShadow { x: surface.x; y: surface.y; width: surface.width; height: surface.height; cornerRadius: surface.radius; spread: 6; strength: Session.visual.barShadow / 20 }
        Rectangle {
        id: surface
        x: bar.outerMargin; y: bar.topMargin
        width: bar.width - bar.outerMargin - bar.rightMargin; height: bar.barHeight
        radius: Math.min(Session.visual.barRadius, height / 2); antialiasing: true
            border.width: Session.visual.barBorder; border.color: PolyTheme.Theme.color("#4b5850")
        gradient: Gradient {
                    GradientStop { position: 0; color: Glass.barTop }
                    GradientStop { position: 1; color: Glass.barBottom }
        }
        Row {
            id: leftGroup
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 30; spacing: 10
            BarButton {
                id: launcherButton
                onHoveredChanged: {
                    if (hovered && !bar.launcherPreviewBlocked) BarState.previewLauncher(bar.screenName);
                    else if (!hovered && bar.launcherPreviewBlocked) appLauncher.closePreviewOutside();
                }
                hint: I18n.tr("bar.open_apps")
                highlighted: BarState.popup === "launcher" && BarState.popupScreen === bar.screenName
                contentItem: Item {
                    FacetedMark {
                        anchors.centerIn: parent; width: 25; height: 25
                    }
                }
                onClicked: { bar.launcherPreviewBlocked = true; bar.openPanel("launcher", launcherButton); }
            }
            Rectangle { width: 1; height: 20; y: 5; color: PolyTheme.Theme.color("#48504a") }
            Row {
                height: 30; spacing: 7
                Repeater {
                    model: bar.workspaceSlots
                    WorkspaceButton {
                        required property int index
                        workspace: bar.workspaceStart + index
                        highlighted: bar.activeWorkspace === workspace
                        occupied: Hyprland.workspaces.values.some(item => item.id === workspace && item.toplevels.values.length > 0)
                        onClicked: Session.focusWorkspace(workspace)
                    }
                }
            }
            TopBarMiniPlayer {
                id: miniPlayer
                anchors.verticalCenter: parent.verticalCenter
            }
            TopBarVideoPipButton {
                id: videoPipBtn
                screenName: bar.screenName
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Button {
            id: clockButton
            HoverHandler { id: clockTransit; margin: 10 }
            onHoveredChanged: if (hovered) BarState.previewCenter(bar.screenName)
            anchors.centerIn: parent
            width: Math.max(76, Math.min(440, surface.width - 2 * Math.max(leftGroup.width + 12, rightGroup.width + 12) - 24 - (TimelineState.active ? 88 : 0)))
            height: parent.height - 2
            padding: 0; hoverEnabled: true; focusPolicy: Qt.StrongFocus
            Accessible.name: I18n.trWith("bar.calendar_a11y", {time: Qt.formatDateTime(ClockState.date, "HH:mm, d MMMM")})
            background: Item {
                id: clockBackground
                // One outline drives both the frame and the landscape mask.
                readonly property string outline: "M4 .5 H" + (width - 4)
                    + " Q" + width + " .5 " + (width - 1) + " 4"
                    + " L" + (width - 24) + " " + (height - 3)
                    + " Q" + (width - 26) + " " + (height - .5) + " " + (width - 29) + " " + (height - .5)
                    + " H29 Q26 " + (height - .5) + " 24 " + (height - 3)
                    + " L1 4 Q0 .5 4 .5 Z"
                Shape {
        preferredRendererType: Shape.CurveRenderer
                    id: clockShape
                    anchors.fill: parent
                    property color surfaceColor: clockButton.down ? PolyTheme.Theme.color("#53634f") : (clockButton.hovered || clockButton.visualFocus || (BarState.popup === "calendar" && BarState.popupScreen === bar.screenName) ? PolyTheme.Theme.color("#35443c") : PolyTheme.Theme.color("#293431"))
                    Behavior on surfaceColor { ColorAnimation { duration: Motion.responseMs } }
                    ShapePath {
                        strokeWidth: clockButton.hovered || clockButton.visualFocus ? 1.1 : 0.7
                        strokeColor: clockButton.hovered || clockButton.visualFocus ? PolyTheme.Theme.color("#9fb58f") : PolyTheme.Theme.color("#526158")
                        fillColor: Glass.tint(clockShape.surfaceColor, 0.5)
                        PathSvg { path: clockBackground.outline }
                    }
                }
                Item {
                    anchors.fill: parent
                    visible: clockButton.width > 390
                    layer.enabled: visible
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: landscapeMask }
                    // Full landscapes taper naturally at both ends; the frame
                    // clips only the outer foothills, never a rectangular crop.
                    ClockRidge {
                        x: 0; anchors.bottom: parent.bottom
                        width: Math.min(158, (parent.width - 124) / 2)
                        height: Math.min(34, parent.height - 4)
                        opacity: 0.9
                    }
                    ClockRidge {
                        anchors.right: parent.right; anchors.bottom: parent.bottom
                        width: Math.min(158, (parent.width - 124) / 2)
                        height: Math.min(34, parent.height - 4)
                        mirrored: true; opacity: 0.9
                    }
                }
                Shape {
        preferredRendererType: Shape.CurveRenderer
                    id: landscapeMask
                    anchors.fill: parent
                    visible: false; layer.enabled: true
                    ShapePath {
                        strokeWidth: 0; fillColor: "white"
                        PathSvg { path: clockBackground.outline }
                    }
                }
            }
            contentItem: Column {
                anchors.centerIn: parent
                spacing: 0
                Text {
                    width: clockButton.width
                    text: Qt.formatDateTime(ClockState.date, "HH:mm")
                    color: PolyTheme.Theme.color("#f5f7f0")
                    font.family: Session.fontFamily
                    font.pixelSize: 21
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.8
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    width: clockButton.width
                    text: ClockState.date.toLocaleDateString(I18n.qtLocale, "ddd  ·  d MMMM").toUpperCase()
                    color: PolyTheme.Theme.color("#b8c7b0")
                    font.family: Session.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            onClicked: bar.openPanel("calendar", clockButton)
        }
        BarButton {
            id: timelineButton
            anchors.left: clockButton.right; anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: TimelineState.active
            symbol: "sun"; hint: "Timeline · " + TimelineState.formatted
            highlighted: BarState.popup === "timeline" && BarState.popupScreen === bar.screenName
            onClicked: bar.openPanel("timeline", timelineButton)
        }
        Row {
            id: rightGroup
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 30; spacing: 6
            Button {
                id: layoutButton
                width: 32; height: 30
                hoverEnabled: true; focusPolicy: Qt.StrongFocus; padding: 0
                enabled: true
                Accessible.name: I18n.trWith("bar.layout_a11y", {layout: BarState.layout})
                background: Rectangle {
                    radius: 8
                    color: layoutButton.hovered || layoutButton.visualFocus ? Glass.tint(Session.accent, 0.18) : "transparent"
                    border.width: layoutButton.hovered || layoutButton.visualFocus ? 1 : 0
                    border.color: Glass.tint(Session.accent, 0.6)
                    Behavior on color { ColorAnimation { duration: Motion.responseMs } }
                }
                contentItem: Text {
                    text: BarState.layout || "EN"
                    font.family: Session.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: (layoutButton.hovered || BarState.layout === "VN") ? Session.accent : Session.foreground
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: BarState.nextLayout()
            }
            Rectangle { visible: BarState.trayItems.length > 0; width: 1; height: 18; y: 6; color: PolyTheme.Theme.color("#414943") }
            Row {
                visible: !bar.compact
                height: 30; spacing: 2
                Repeater {
                    model: bar.compact ? [] : BarState.inlineTray
                    TrayButton { required property var modelData; trayItem: modelData }
                }
            }
            BarButton {
                id: trayButton
                visible: BarState.hiddenTray.length > 0 || (bar.compact && BarState.trayItems.length > 0)
                symbol: "chevron-down"; hint: I18n.tr("bar.tray")
                highlighted: BarState.popup === "tray" && BarState.popupScreen === bar.screenName
                onClicked: bar.openPanel("tray", trayButton)
            }
            BarButton {
                id: clipboardButton
                onHoveredChanged: if (hovered) BarState.previewClipboard(bar.screenName)
                symbol: "clipboard"; hint: I18n.tr("bar.clipboard")
                highlighted: BarState.popup === "clipboard" && BarState.popupScreen === bar.screenName
                marked: ClipboardState.paused || !!ClipboardState.error
                onClicked: bar.openPanel("clipboard", clipboardButton)
            }
            BarButton {
                id: bell
                HoverHandler { id: bellTransit; margin: (bar.barHeight - bell.height) / 2 + 8 }
                onHoveredChanged: if (hovered) BarState.previewNotifications(bar.screenName)
                highlighted: BarState.popup === "notifications" && BarState.popupScreen === bar.screenName
                symbol: BarState.dnd ? "bell-muted" : "bell"; hint: BarState.dnd ? I18n.tr("bar.notifications_dnd") : I18n.tr("bar.notifications")
                marked: BarState.notifications.length > 0
                onClicked: bar.openPanel("notifications", bell)
            }
            Rectangle { width: 1; height: 18; y: 6; color: PolyTheme.Theme.color("#414943") }
            Button {
                id: statusButton
                readonly property bool networkVisible: !!Session.wiredDevice || (!!Session.wifiDevice && Session.wifiEnabled && Session.wifiObservation.hardwareEnabled)
                readonly property bool bluetoothVisible: !!Session.bluetoothAdapter && Session.bluetoothEnabled
                readonly property bool audioVisible: !!Session.audio
                readonly property bool batteryVisible: Session.batteryPresent
                readonly property bool expanded: Session.quickSettingsOpen && Session.quickSettingsScreen === bar.screenName
                HoverHandler { id: statusTransit; margin: (bar.barHeight - statusButton.height) / 2 }
                width: Math.max(36, statusIndicators.implicitWidth + 18); height: 30
                hoverEnabled: true; focusPolicy: Qt.StrongFocus; padding: 0
                Accessible.name: I18n.tr("bar.quick_a11y") + (networkVisible ? " · " + Session.networkStatus.label : "")
                    + (bluetoothVisible ? " · " + Session.bluetoothDescription : "")
                    + (audioVisible ? " · " + Session.audioStatus.label : "")
                    + (batteryVisible ? " · " + Session.batteryDescription : "")
                background: Rectangle {
                    radius: Math.min(12, Session.visual.barRadius)
                    color: Glass.tint(Session.accent, statusButton.down ? 0.16 : statusButton.hovered || statusButton.visualFocus || statusButton.expanded ? 0.08 : 0)
                    Behavior on color { ColorAnimation { duration: Motion.responseMs } }
                }
                contentItem: Item {
                    Row {
                        id: statusIndicators
                        anchors.centerIn: parent; spacing: 9; height: 24
                        StatusIcon {
                            visible: statusButton.networkVisible
                            kind: Session.networkStatus.kind; level: Session.networkStatus.level
                            busy: Session.networkStatus.busy; warning: Session.networkStatus.warning
                            ink: kind === "wifi-disconnected" ? Session.muted : Session.foreground
                            width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter
                        }
                        StatusIcon {
                            visible: statusButton.bluetoothVisible
                            kind: Session.connectedBluetooth.length ? "bluetooth-connected" : "bluetooth-disconnected"
                            ink: Session.connectedBluetooth.length ? Session.accent : Session.muted
                            width: 17; height: 17; anchors.verticalCenter: parent.verticalCenter
                        }
                        StatusIcon {
                            visible: statusButton.audioVisible
                            kind: Session.audioStatus.kind; level: Session.audioStatus.level
                            ink: kind === "muted" ? Session.muted : Session.foreground
                            width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            visible: statusButton.batteryVisible && (statusButton.networkVisible || statusButton.bluetoothVisible || statusButton.audioVisible)
                            width: 1; height: 12; color: Glass.tint(Session.accent, 0.2)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            visible: statusButton.batteryVisible
                            width: chargeContent.implicitWidth + 12; height: 24
                            radius: Math.min(8, Session.visual.barRadius)
                            color: Glass.tint(Session.accent, Session.batteryCharging ? 0.13 : 0.06)
                            Row {
                                id: chargeContent
                                anchors.centerIn: parent; spacing: 6; height: 18
                                BatteryIcon { width: 23; height: 14; charge: Session.battery ? Session.battery.percentage : 0; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    visible: !bar.compact
                                    text: Session.battery ? Math.round(Session.battery.percentage * 100) + "%" : ""
                                    color: Session.batteryCharging ? Session.accent : Session.foreground
                                    font.family: Session.fontFamily; font.pixelSize: 11; font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                        Icon {
                            visible: !statusButton.networkVisible && !statusButton.bluetoothVisible && !statusButton.audioVisible && !statusButton.batteryVisible
                            name: "settings"; width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                onHoveredChanged: if (hovered) BarState.previewQuick(bar.screenName)
                onClicked: Session.toggleQuickSettings(bar.screenName)
            }

        }
    }
    // qmllint disable uncreatable-type
    PanelWindow {
        // qmllint enable uncreatable-type
        id: dismissal
        screen: bar.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore; exclusiveZone: 0
        color: "transparent"
        visible: !!bar.activePanel && bar.activePanel !== appLauncher && !bar.clipboardActive && !BarState.selection.preview
        WlrLayershell.namespace: "poly-panel-dismiss"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { x: 0; y: bar.topMargin + bar.barHeight; width: dismissal.width; height: Math.max(0, dismissal.height - y) }
        MouseArea { anchors.fill: parent; onPressed: BarState.dismiss() }
    }
    QuickSettings { id: quickSettingsPopup; modelData: bar.modelData; barWindow: bar }
    Launcher { id: appLauncher; modelData: bar.modelData; barWindow: bar }
    BarPopup { id: standardPopup; modelData: bar.modelData; barWindow: bar }
    readonly property var activePanel: BarState.selection.screen !== screenName ? null
        : BarState.selection.name === "quick-settings" ? quickSettingsPopup
        : BarState.selection.name === "launcher" ? appLauncher
        : BarState.selection.name ? standardPopup : null
    property bool allowBarFocus: false
    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: !!bar.activePanel
        onActivated: {
            if (bar.activePanel === quickSettingsPopup && quickSettingsPopup.page !== "main") quickSettingsPopup.page = "main";
            else BarState.dismiss();
        }
    }
    onActivePanelChanged: allowBarFocus = false
    Connections {
        target: BarState
        function onSelectionChanged(): void {
            if (bar.activePanel === appLauncher) bar.allowBarFocus = false;
        }
    }
    Connections {
        target: bar.activePanel
        function onKeyboardActiveChanged(): void {
            if (bar.activePanel && bar.activePanel.keyboardActive) bar.allowBarFocus = true;
        }
    }
    // One grab owns every panel on this screen. Wait for a newly mapped
    // settings/calendar window's first frame before requesting keyboard focus.
    readonly property bool clipboardActive: bar.activePanel === standardPopup && BarState.popup === "clipboard"
    HyprlandFocusGrab {
        id: panelGrab
        windows: !bar.activePanel ? [] : bar.activePanel === appLauncher
            ? BarState.selection.origin === "dock" && BarState.selection.sourceWindow
                ? (bar.allowBarFocus ? [appLauncher, BarState.selection.sourceWindow, bar] : [appLauncher])
                : (bar.allowBarFocus || BarState.selection.preview ? [appLauncher, bar] : [appLauncher])
            : [bar, bar.activePanel]
        active: bar.activePanel === appLauncher
        onCleared: {
            if (bar.activePanel !== appLauncher) return;
            if (BarState.selection.preview) Qt.callLater(appLauncher.closePreviewOutside);
            else BarState.dismiss();
        }
    }

}
