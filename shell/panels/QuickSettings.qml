pragma ComponentBehavior: Bound
import QtQuick
import "../logic/StatusLogic.js" as StatusLogic
import "../theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: popup
    required property var modelData
    required property var barWindow
    readonly property real uiScale: barWindow.uiScale
    screen: modelData
    anchors { top: true; left: true }
    readonly property real viewportWidth: modelData ? modelData.width : 0
    readonly property real viewportHeight: modelData ? modelData.height : 0
    readonly property real panelWidth: Math.max(0, Math.min(460, viewportWidth - 32))
    property bool preview: false
    // Shared controls stay mounted; extra rows unfold around them.
    property real expansion: preview ? 0 : 1
    Behavior on expansion {
        NumberAnimation {
            duration: popup.opened && popup.reveal > 0 ? Motion.openMs : 0
            easing.type: Easing.Linear
        }
    }
    Connections {
        target: BarState
        function onSelectionChanged(): void { if (popup.opened) popup.preview = BarState.quickPreview; }
    }
    readonly property real expansionCurve: expansion * expansion * (3 - 2 * expansion)
    property real desiredHeight: page === "main" ? mainColumn.implicitHeight + Session.visual.panelPadding * 2 : 590
    Behavior on desiredHeight { NumberAnimation { duration: popup.opened && popup.page !== "main" ? Motion.resizeMs : 0; easing.type: Easing.OutCubic } }
    readonly property real panelHeight: Math.max(0, Math.min(desiredHeight, viewportHeight - restingY - 16))
    // Do not renegotiate the native Wayland buffer size on every animation frame.
    readonly property real windowHeight: Math.max(0, Math.min(Math.max(mainColumn.implicitHeight + Session.visual.panelPadding * 2, 640), viewportHeight - restingY - 16))
    readonly property bool pointerInside: panelHover.hovered || gapHover.hovered || barWindow.quickHovered || outputControl.dragging || brightness.dragging || inputControl.dragging
    onPointerInsideChanged: updatePreviewClose()
    // Keyboard-opened panels arm dismissal once the pointer reaches them.
    property bool pointerDismissArmed: false
    function updatePreviewClose(): void {
        if (opened && pointerInside) pointerDismissArmed = true;
        // Recheck after hover delivery between the bar, bridge and popup.
        // No timed delay: leaving the combined area starts closing immediately.
        if (opened && (preview || pointerDismissArmed) && !pointerInside) Qt.callLater(popup.closePreviewOutside);
    }
    function closePreviewOutside(): void {
        pointerExit.check();
    }
    PointerExitGuard {
        id: pointerExit
        ownerToken:BarState.selection.name+"|"+BarState.selection.screen+"|"+String(!!BarState.selection.preview)
        enabledForClose: popup.opened && (popup.preview || popup.pointerDismissArmed)
        pointerInside: popup.pointerInside
        barWindow: popup.barWindow
        sourceItem: popup.barWindow.quickSource
        screenOffset: Qt.point(popup.modelData ? popup.modelData.x : 0, popup.modelData ? popup.modelData.y : 0)
        panelBounds: Qt.rect(body.screenPosition.x, popup.restingY, popup.panelWidth, popup.panelHeight)
        onOutside: Session.closeQuickSettings()
    }
    onPreviewChanged: {
        updatePreviewClose();
        if (opened && !preview) focusDelay.restart();
    }
    implicitWidth: panelWidth + 32
    readonly property real topPadding: restingY
    implicitHeight: windowHeight + topPadding + 16
    // qmllint disable missing-property
    margins { left: Math.max(0, popup.viewportWidth - popup.panelWidth - Math.max(16, popup.barWindow.rightMargin) - 16); top: 0 }
    // qmllint enable missing-property
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    readonly property bool opened: !!modelData && Session.quickSettingsOpen && Session.quickSettingsScreen === modelData.name
    readonly property bool keyboardActive: content.Window.active
    property bool focusEstablished: false
    onKeyboardActiveChanged: if (keyboardActive) focusEstablished = true
    property bool grabReady: false
    readonly property real reveal: panelMotion.progress
    readonly property real restingY: barWindow.topMargin + barWindow.barHeight + 10
    PanelMotion { id: panelMotion; opened: popup.opened; openDuration: Motion.openMs; closeDuration: Motion.closeMs }
    IpcHandler {
        target: "quick-settings-" + (popup.modelData ? popup.modelData.name : "disconnected")
        function motionStatus(): string {
            return JSON.stringify({ opened: popup.opened, progress: popup.reveal,
                renderAnimating: panelMotion.renderAnimating, presented: panelMotion.presented,
                palette: { accent: String(Session.accent), surface: String(Session.surface), text: String(Session.foreground) }, wifiDetail: Session.wifiNetwork ? Session.wifiNetwork.name : Session.wifiStatus.label, wifiNote: "", bluetoothDetail: Session.bluetoothDescription, page: popup.page, preview: popup.preview, expansion: popup.expansion, fullOpacity: mainScroll.opacity, pointerInside: popup.pointerInside, width: body.surfaceWidth, height: body.surfaceHeight,
                fullWidth: body.width, fullHeight: body.height, effectReady: body.effectReady,
                originX: body.origin.x, originY: body.origin.y, screenX: body.screenPosition.x, screenY: body.screenPosition.y,
                surfaceX: body.surfaceX, surfaceY: body.surfaceY, keyboardActive: popup.keyboardActive, focusEstablished: popup.focusEstablished });
        }
        function showPreview(): void { BarState.dismiss(); BarState.previewQuick(popup.modelData.name); }
        function expand(): void { BarState.expandQuick(); }
        function startMotionTrace(): void { body.startTrace(); }
        function stopMotionTrace(): string { return JSON.stringify(body.finishTrace()); }
        function navigate(page: string): bool {
            if (!popup.opened || !["main", "wifi", "bluetooth", "output", "input", "settings", "power", "nightlight", "dnd", "profiles", "airplane", "hotspot", "password"].includes(page)) return false;
            BarState.expandQuick(); popup.page = page; return true;
        }
    }
    Connections {
        target: content.Window.window
        function onFrameSwapped(): void { if (popup.opened) popup.grabReady = true; }
    }
    property string page: "main"
    PageMotion { id: pageMotion; page: popup.page; enabled: popup.opened && popup.grabReady }
    property string powerAction: ""
    property var selectedNetwork: null
    property bool isEnterprise: false
    property string customSsid: ""
    property bool showPassword: false
    property string localError: ""
    readonly property var passwordInput: passwordLoader.item
    readonly property string title: ({wifi: "Wi‑Fi", bluetooth: "Bluetooth", output: I18n.tr("settings.sound_output"), input: I18n.tr("settings.microphone"), settings: I18n.tr("settings.devices"), power: I18n.tr("settings.power"), password: I18n.tr("wifi.connecting_title"), nightlight: I18n.tr("quick.night_light"), dnd: I18n.tr("notification.dnd"), profiles: I18n.tr("quick.power_mode"), airplane: I18n.tr("quick.airplane_mode"), hotspot: I18n.tr("quick.mobile_hotspot")})[page] || I18n.tr("quick.control_center")
    readonly property string profileLabel: ({"power-saver": I18n.tr("quick.power_saver_short"), balanced: I18n.tr("quick.balanced_short"), performance: I18n.tr("quick.performance_short")})[Desktop.data.powerProfile] || I18n.tr("quick.power_unavailable")
    function launchTerminal(args: var): void {
        Session.closeQuickSettings();
        Quickshell.execDetached(Session.settings.apps.terminal.concat(["-e"]).concat(args));
    }
    onPageChanged: {
        localError = "";
        showPassword = false;
        if (popup.passwordInput) popup.passwordInput.clear();
    }
    Binding {
        target: Session.wifiDevice
        property: "scannerEnabled"
        value: popup.opened && popup.page === "wifi" && Session.wifiEnabled
        when: !!Session.wifiDevice
        restoreMode: Binding.RestoreBindingOrValue
    }

    visible: panelMotion.presented
    mask: Region { x: 16; y: popup.topPadding - 10; width: popup.opened ? popup.panelWidth : 0; height: popup.opened ? popup.panelHeight + 10 : 0 }
    // A small input-only bridge keeps the menu reachable across the visual gap.
    Item {
        x: 16; y: popup.topPadding - 10; width: popup.panelWidth; height: 10
        visible: popup.opened
        HoverHandler { id: gapHover }
    }
    WlrLayershell.namespace: "poly-panel-quick-settings" + (Motion.reduced ? "-static" : "")
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: !opened || preview ? WlrKeyboardFocus.None : focusEstablished ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive


    onOpenedChanged: {
        pointerDismissArmed = opened && pointerInside;
        grabReady = false; focusEstablished = false;
        if (opened) {
            preview = BarState.quickPreview;
            page = "main";
            localError = "";
            powerAction = "";
            if (!preview) focusDelay.restart();
            updatePreviewClose();
        } else {
            focusDelay.stop();
            if (popup.passwordInput) popup.passwordInput.clear();
            selectedNetwork = null;
        }
    }

    Timer {
        id: focusDelay
        interval: 0
        onTriggered: if (popup.opened && !popup.preview) content.forceActiveFocus()
    }

    // Outside clicks are dismissed by the separate input surface. The native
    // surface is bounded to the panel, without a full-screen blur buffer.
    Item {
        id: content
        x: 16
        y: popup.topPadding
        width: popup.panelWidth
        height: body.height
        scale: popup.uiScale
        opacity: 1
        transformOrigin: Item.TopLeft
        focus: popup.opened && !popup.preview
        HoverHandler { id: panelHover }

        UnfoldPanel {
            id: body
            motion: panelMotion
            faceted: false
            screenPosition: Qt.point(Math.max(0, popup.viewportWidth - popup.panelWidth - Math.max(16, popup.barWindow.rightMargin) - 16) + content.x, popup.topPadding)
            surfaceTop: Glass.panelTop
            surfaceBottom: Glass.panelBottom
            sourceItem: popup.barWindow.quickSource
            x: 0; y: 0
            width: content.width
            height: popup.panelHeight

            QuickHoverContent {
                id: hoverContent
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: Session.visual.panelPadding
                visible: popup.page === "main" && popup.preview
                onExpandRequested: BarState.expandQuick()
                onPageRequested: page => popup.page = page
            }

            ScrollView {
                id: mainScroll
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: Session.visual.panelPadding
                height: Math.max(0, Math.min(mainColumn.implicitHeight, popup.panelHeight - Session.visual.panelPadding * 2))
                visible: popup.page === "main" && !popup.preview
                contentWidth: availableWidth
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                Column {
                    id: mainColumn
                    width: mainScroll.availableWidth; spacing: 0
                    Item {
                        width: parent.width; height: 42
                        MountainRidge { anchors.right: parent.right; anchors.bottom: parent.bottom; width: parent.width * 0.47; height: 32; opacity: 0.42 }
                        RowLayout {
                            anchors.fill: parent; spacing: 10
                            GemMark { Layout.preferredWidth: 22; Layout.preferredHeight: 26 }
                            Text { Layout.fillWidth: true; text: popup.preview ? I18n.tr("quick.quick_access") : I18n.tr("quick.control_center"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 15; font.weight: Font.Medium; elide: Text.ElideRight }
                            IconButton { opacity: popup.expansionCurve; enabled: !popup.preview; symbol: "close"; hint: I18n.tr("common.close"); implicitWidth: 28; implicitHeight: 28; onClicked: Session.closeQuickSettings() }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Glass.tint(Session.accent, 0.22) }
                    Item { width: 1; height: 8 }
                    RowLayout {
                        width: parent.width; height: 86; spacing: 10
                        QuickSwitchTile {
                            Layout.fillWidth: true; Layout.preferredWidth: 1
                            title: "Wi-Fi"; symbol: "wifi"; active: Session.wifiEnabled; details: true
                            subtitle: Session.wifiNetwork ? Session.wifiNetwork.name : Session.wifiStatus.label
                            statusKind: Session.wifiStatus.kind; statusLevel: Session.wifiStatus.level
                            statusBusy: Session.wifiStatus.busy; statusWarning: Session.wifiStatus.warning
                            enabled: !!Session.wifiDevice && Session.wifiObservation.hardwareEnabled && !Desktop.changingSettings && !Desktop.data.airplane
                            onToggled: Session.toggleWifi()
                            onDetailsRequested: { BarState.expandQuick(); popup.page = "wifi"; }
                        }
                        QuickSwitchTile {
                            Layout.fillWidth: true; Layout.preferredWidth: 1
                            title: "Bluetooth"; symbol: "bluetooth"; active: Session.bluetoothEnabled; details: true
                            subtitle: Session.connectedBluetooth.length ? Session.connectedBluetooth[0].name : Session.bluetoothDescription
                            enabled: !!Session.bluetoothAdapter && !Desktop.changingSettings && !Desktop.data.airplane
                            onToggled: Session.toggleBluetooth()
                            onDetailsRequested: { BarState.expandQuick(); popup.page = "bluetooth"; }
                        }
                    }
                    Item { width: 1; height: 8 }
                    ControlRow {
                        id: outputControl
                        width: parent.width; height: implicitHeight
                        showLabel: true; label: I18n.tr("osd.volume"); symbol: Session.audio && Session.audio.muted ? "muted" : "volume"
                        statusKind: Session.audioStatus.kind; statusLevel: Session.audioStatus.level
                        value: Session.audio ? Session.audio.volume : 0
                        adjustable: !!Session.audio; muted: Session.audio ? Session.audio.muted : false
                        hasMute: true; hasDetails: true
                        deviceName: Session.sink ? (Session.sink.nickname || Session.sink.description || I18n.tr("audio.speakers")) : I18n.tr("audio.no_output_device")
                        onAdjusted: value => { if (Session.audio) { Session.audio.volume = value; if (value > 0) Session.audio.muted = false; } }
                        onMuteRequested: if (Session.audio) Session.audio.muted = !Session.audio.muted
                        onDetailsRequested: { BarState.expandQuick(); popup.page = "output"; }
                    }
                    Item { width: 1; height: brightness.visible ? 8 : 0 }
                    Rectangle { width: parent.width; height: brightness.visible ? 1 : 0; visible: brightness.visible; color: Glass.tint(Session.accent, 0.16) }
                    Item { width: 1; height: brightness.visible ? 8 : 0 }
                    ControlRow {
                        id: brightness
                        visible: Session.brightnessAvailable && Desktop.data.brightnessAvailable
                        width: parent.width; height: visible ? implicitHeight : 0
                        property real pendingValue: value
                        showLabel: true; label: I18n.tr("osd.brightness"); symbol: "sun"
                        minimum: 0.05; value: Desktop.data.brightness / 100
                        adjustable: Desktop.data.brightnessAvailable
                        onAdjusted: value => { pendingValue = value; brightnessDebounce.restart(); }
                        Timer { id: brightnessDebounce; interval: 70; onTriggered: Desktop.request("brightness", String(Math.max(5, Math.round(brightness.pendingValue * 100)))) }
                    }
                    Item {
                        width: parent.width; height: (inputControl.implicitHeight + 8) * popup.expansionCurve
                        clip: true
                        ControlRow {
                            id: inputControl
                            y: 8; width: parent.width; height: implicitHeight
                            enabled: !popup.preview
                            showLabel: true; label: I18n.tr("settings.microphone"); symbol: Session.microphone && Session.microphone.muted ? "microphone-muted" : "microphone"
                            value: Session.microphone ? Session.microphone.volume : 0
                            adjustable: !!Session.microphone; muted: Session.microphone ? Session.microphone.muted : false
                            hasMute: true; hasDetails: true
                            deviceName: Session.source ? (Session.source.nickname || Session.source.description || I18n.tr("settings.microphone")) : I18n.tr("audio.no_input_device")
                            onAdjusted: value => { if (Session.microphone) { Session.microphone.volume = value; if (value > 0) Session.microphone.muted = false; } }
                            onMuteRequested: if (Session.microphone) Session.microphone.muted = !Session.microphone.muted
                            onDetailsRequested: popup.page = "input"
                        }
                    }
                    Item { width: parent.width; height: 17; Rectangle { y: 8; width: parent.width; height: 1; color: Glass.tint(Session.accent, 0.22) } }
                    Row {
                        id: modes
                        width: parent.width; height: 44 + 36 * popup.expansionCurve
                        spacing: 10 * popup.expansionCurve
                        readonly property real tileWidth: (modes.width - 30) / 4
                        QuickSwitchTile {
                            width: modes.width - (3 * modes.tileWidth + 30) * popup.expansionCurve
                            height: modes.height
                            compactProgress: 1 - popup.expansionCurve
                            title: I18n.tr("notification.dnd"); symbol: "bell"; active: Desktop.data.dnd
                            enabled: Desktop.data.dndAvailable && !Desktop.changingSettings
                            onToggled: Desktop.request("dnd", "")
                        }
                        QuickSwitchTile {
                            width: modes.tileWidth * popup.expansionCurve; height: modes.height
                            clip: true; opacity: popup.expansionCurve; enabled: !popup.preview && Desktop.data.nightLightAvailable && !Desktop.changingSettings
                            title: I18n.tr("quick.night_light"); symbol: "moon-warm"; active: Desktop.data.nightLight
                            onToggled: Desktop.request("nightlight", "")
                        }
                        QuickSwitchTile {
                            width: modes.tileWidth * popup.expansionCurve; height: modes.height
                            clip: true; opacity: popup.expansionCurve; enabled: !popup.preview && Desktop.data.airplaneAvailable && !Desktop.changingSettings
                            title: I18n.tr("quick.airplane_mode"); symbol: "airplane"; active: !!Desktop.data.airplane
                            onToggled: Desktop.request("airplane", Desktop.data.airplane || Desktop.data.airplaneManaged ? "off" : "on")
                        }
                        QuickSwitchTile {
                            width: modes.tileWidth * popup.expansionCurve; height: modes.height
                            clip: true; opacity: popup.expansionCurve; enabled: !popup.preview && Desktop.data.hotspotAvailable && !Desktop.changingSettings && !Desktop.data.airplane
                            title: I18n.tr("quick.mobile_hotspot"); symbol: "hotspot"; active: !!Desktop.data.hotspot
                            onToggled: Desktop.request("hotspot", Desktop.data.hotspot ? "off" : "on")
                        }
                    }
                    Item { width: 1; height: 8 }
                    Item {
                        width: parent.width; height: 70 * popup.expansionCurve; clip: true
                        SettingsRow { width: parent.width; height: 53; enabled: !popup.preview; text: I18n.tr("quick.power_mode"); subtitle: popup.profileLabel; symbol: "performance"; onClicked: popup.page = "profiles" }
                        Rectangle { y: 61; width: parent.width; height: 1; color: Glass.tint(Session.accent, 0.22) }
                    }
                    Item { width: 1; height: 8 * popup.expansionCurve }
                    Item {
                        width: parent.width; height: 104 * popup.expansionCurve; clip: true
                        opacity: popup.expansionCurve
                        SecurityShieldCard {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            enabled: !popup.preview
                            onAuditRequested: {
                                Session.closeQuickSettings();
                                popup.launchTerminal(["poly-shell", "security", "status"]);
                            }
                            onHardenRequested: {
                                Session.closeQuickSettings();
                                popup.launchTerminal(["poly-shell", "security", "harden"]);
                            }
                        }
                    }
                    Item { width: 1; height: 8 * popup.expansionCurve }
                    Item {
                        width: parent.width; height: 40 * (1 - popup.expansionCurve); clip: true
                        QuickActionButton { width: parent.width; height: 40; enabled: popup.preview; text: I18n.tr("quick.open_control_center"); symbol: "settings"; onClicked: BarState.expandQuick() }
                    }
                    Item {
                        width: parent.width; height: 40 * popup.expansionCurve; clip: true
                        RowLayout {
                            width: parent.width; height: 40; spacing: 8; enabled: !popup.preview
                            QuickActionButton { Layout.fillWidth: true; Layout.preferredWidth: 1; text: I18n.tr("settings.title"); symbol: "settings"; onClicked: { Session.closeQuickSettings(); Quickshell.execDetached([Session.controller, "settings"]); } }
                            QuickActionButton { Layout.fillWidth: true; Layout.preferredWidth: 1; text: I18n.tr("quick.lock"); symbol: "lock"; onClicked: { Session.closeQuickSettings(); Session.launch("lock"); } }
                            QuickActionButton { Layout.fillWidth: true; Layout.preferredWidth: 1; text: I18n.tr("settings.power"); symbol: "power"; onClicked: popup.page = "power" }
                            QuickActionButton {
                                Layout.preferredWidth: 40; Layout.minimumWidth: 40
                                symbol: "monitor"; Accessible.name: I18n.tr("display_project.title")
                                ToolTip.visible: hovered; ToolTip.text: I18n.tr("display_project.title") + " (Super+P)"
                                onClicked: {
                                    Session.closeQuickSettings();
                                    DisplayProjectState.open(popup.modelData ? popup.modelData.name : "");
                                }
                            }
                            QuickActionButton {
                                Layout.preferredWidth: 40; Layout.minimumWidth: 40
                                symbol: "screenshot"; Accessible.name: I18n.tr("quick.screenshot")
                                ToolTip.visible: hovered; ToolTip.text: I18n.tr("quick.screenshot")
                                onClicked: BarState.screenshot()
                            }
                            QuickActionButton {
                                Layout.preferredWidth: 40; Layout.minimumWidth: 40
                                symbol: "coffee"; Accessible.name: "Caffeine"
                                ToolTip.visible: hovered; ToolTip.text: (Desktop.data.caffeine ? "Caffeine: Active" : "Caffeine: Inactive")
                                onClicked: Desktop.request("caffeine", Desktop.data.caffeine ? "off" : "on")
                            }
                        }
                    }
                }
            }

            QuickSettingsSubpages {
                id: subpages
                anchors.fill: parent
                anchors.margins: Session.visual.panelPadding
                visible: popup.page !== "main"
                popup: popup
            }

            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.margins: 8
                height: errorText.implicitHeight + 16
                radius: 10
                color: PolyTheme.Theme.color("#493d35")
                visible: Desktop.error.length > 0 || popup.localError.length > 0
                Text { id: errorText; anchors.fill: parent; anchors.margins: 8; text: Desktop.error || popup.localError; color: PolyTheme.Theme.color("#f4d7bc"); font.pixelSize: 11; wrapMode: Text.Wrap }
                TapHandler { onTapped: { Desktop.error = ""; popup.localError = ""; } }
            }
        }
    }

}
