pragma ComponentBehavior: Bound
import QtQuick
import "StatusLogic.js" as StatusLogic
import "theme" as PolyTheme
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
            if (!popup.opened || !["main", "wifi", "bluetooth", "output", "input", "settings", "power", "nightlight", "dnd", "profiles", "airplane"].includes(page)) return false;
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
    property string localError: ""
    readonly property var passwordInput: passwordLoader.item
    readonly property string title: ({wifi: "Wi‑Fi", bluetooth: "Bluetooth", output: "Вывод звука", input: "Микрофон", settings: "Устройства", power: "Питание", password: "Подключение к Wi‑Fi", nightlight: "Ночной свет", dnd: "Не беспокоить", profiles: "Режим питания", airplane: "Авиарежим"})[page] || "Центр управления"
    readonly property string profileLabel: ({"power-saver": "Экономия", balanced: "Баланс", performance: "Производительность"})[Desktop.data.powerProfile] || "Недоступно"
    function launchTerminal(args: var): void {
        Session.closeQuickSettings();
        Session.launchCommand("", Session.settings.apps.terminal.concat(["-e"]).concat(args), "", "");
    }
    onPageChanged: {
        localError = "";
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

            ScrollView {
                id: mainScroll
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: Session.visual.panelPadding
                height: Math.max(0, Math.min(mainColumn.implicitHeight, popup.panelHeight - Session.visual.panelPadding * 2))
                visible: popup.page === "main"
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
                            Text { Layout.fillWidth: true; text: popup.preview ? "Быстрый доступ" : "Центр управления"; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 15; font.weight: Font.Medium; elide: Text.ElideRight }
                            IconButton { opacity: popup.expansionCurve; enabled: !popup.preview; symbol: "close"; hint: "Закрыть"; implicitWidth: 28; implicitHeight: 28; onClicked: Session.closeQuickSettings() }
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
                        showLabel: true; label: "Громкость"; symbol: Session.audio && Session.audio.muted ? "muted" : "volume"
                        statusKind: Session.audioStatus.kind; statusLevel: Session.audioStatus.level
                        value: Session.audio ? Session.audio.volume : 0
                        adjustable: !!Session.audio; muted: Session.audio ? Session.audio.muted : false
                        hasMute: true; hasDetails: true
                        deviceName: Session.sink ? (Session.sink.nickname || Session.sink.description || "Динамики") : "Нет устройства вывода"
                        onAdjusted: value => { if (Session.audio) { Session.audio.volume = value; if (value > 0) Session.audio.muted = false; } }
                        onMuteRequested: if (Session.audio) Session.audio.muted = !Session.audio.muted
                        onDetailsRequested: { BarState.expandQuick(); popup.page = "output"; }
                    }
                    Item { width: 1; height: 8 }
                    Rectangle { width: parent.width; height: 1; color: Glass.tint(Session.accent, 0.16) }
                    Item { width: 1; height: 8 }
                    ControlRow {
                        id: brightness
                        width: parent.width; height: implicitHeight
                        property real pendingValue: value
                        showLabel: true; label: "Яркость"; symbol: "sun"
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
                            showLabel: true; label: "Микрофон"; symbol: Session.microphone && Session.microphone.muted ? "microphone-muted" : "microphone"
                            value: Session.microphone ? Session.microphone.volume : 0
                            adjustable: !!Session.microphone; muted: Session.microphone ? Session.microphone.muted : false
                            hasMute: true; hasDetails: true
                            deviceName: Session.source ? (Session.source.nickname || Session.source.description || "Микрофон") : "Нет устройства ввода"
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
                        QuickSwitchTile {
                            width: modes.width - (2 * (modes.width - 20) / 3 + 20) * popup.expansionCurve
                            height: modes.height
                            compactProgress: 1 - popup.expansionCurve
                            title: "Не беспокоить"; symbol: "bell"; active: Desktop.data.dnd
                            enabled: Desktop.data.dndAvailable && !Desktop.changingSettings
                            onToggled: Desktop.request("dnd", "")
                        }
                        QuickSwitchTile {
                            width: (modes.width - 20) / 3 * popup.expansionCurve; height: modes.height
                            clip: true; opacity: popup.expansionCurve; enabled: !popup.preview && Desktop.data.nightLightAvailable && !Desktop.changingSettings
                            title: "Ночной свет"; symbol: "moon-warm"; active: Desktop.data.nightLight
                            onToggled: Desktop.request("nightlight", "")
                        }
                        QuickSwitchTile {
                            width: (modes.width - 20) / 3 * popup.expansionCurve; height: modes.height
                            clip: true; opacity: popup.expansionCurve; enabled: !popup.preview && Desktop.data.airplaneAvailable && !Desktop.changingSettings
                            title: "Авиарежим"; symbol: "airplane"; active: !!Desktop.data.airplane
                            onToggled: Desktop.request("airplane", Desktop.data.airplane || Desktop.data.airplaneManaged ? "off" : "on")
                        }
                    }
                    Item { width: 1; height: 8 }
                    Item {
                        width: parent.width; height: 70 * popup.expansionCurve; clip: true
                        SettingsRow { width: parent.width; height: 53; enabled: !popup.preview; text: "Режим питания"; subtitle: popup.profileLabel; symbol: "performance"; onClicked: popup.page = "profiles" }
                        Rectangle { y: 61; width: parent.width; height: 1; color: Glass.tint(Session.accent, 0.22) }
                    }
                    Item {
                        width: parent.width; height: 40 * (1 - popup.expansionCurve); clip: true
                        QuickActionButton { width: parent.width; height: 40; enabled: popup.preview; text: "Открыть центр управления"; symbol: "settings"; onClicked: BarState.expandQuick() }
                    }
                    Item {
                        width: parent.width; height: 40 * popup.expansionCurve; clip: true
                        RowLayout {
                            width: parent.width; height: 40; spacing: 8; enabled: !popup.preview
                            QuickActionButton { Layout.fillWidth: true; Layout.preferredWidth: 1; text: "Настройки"; symbol: "settings"; onClicked: { Session.closeQuickSettings(); Quickshell.execDetached([Session.controller, "settings"]); } }
                            QuickActionButton { Layout.fillWidth: true; Layout.preferredWidth: 1; text: "Блокировка"; symbol: "lock"; onClicked: { Session.closeQuickSettings(); Session.launch("lock"); } }
                            QuickActionButton { Layout.fillWidth: true; Layout.preferredWidth: 1; text: "Питание"; symbol: "power"; onClicked: popup.page = "power" }
                            QuickActionButton {
                                Layout.preferredWidth: 40; Layout.minimumWidth: 40
                                symbol: "screenshot"; Accessible.name: "Снимок экрана"
                                ToolTip.visible: hovered; ToolTip.text: "Снимок экрана"
                                onClicked: BarState.screenshot()
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: Session.visual.panelPadding; spacing: 12
                visible: popup.page !== "main"
                opacity: pageMotion.opacity
                transformOrigin: Item.Top
                RowLayout {
                    IconButton { symbol: "chevron-left"; hint: "Назад"; implicitWidth: 30; implicitHeight: 30; onClicked: { popup.page = "main"; popup.powerAction = ""; } }
                    Text { text: popup.title; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 15 }
                    Item { Layout.fillWidth: true }
                    IconButton { symbol: "close"; hint: "Закрыть"; implicitWidth: 30; implicitHeight: 30; onClicked: Session.closeQuickSettings() }
                }
                ScrollView {
                    id: deviceScroll
                    Layout.fillWidth: true; Layout.fillHeight: true
                    visible: ["wifi", "bluetooth", "output", "input"].includes(popup.page)
                    clip: true
                    contentWidth: availableWidth
                    Column {
                        width: deviceScroll.availableWidth; spacing: 8
                        SettingsRow {
                            width: parent.width; visible: popup.page === "wifi"
                            symbol: "wifi"; text: Session.wifiEnabled ? "Wi-Fi включён" : "Wi-Fi выключен"
                            statusKind: Session.wifiStatus.kind; statusLevel: Session.wifiStatus.level
                            statusBusy: Session.wifiStatus.busy; statusWarning: Session.wifiStatus.warning
                            subtitle: "Нажми, чтобы переключить"; selected: Session.wifiEnabled
                            enabled: !!Session.wifiDevice
                            onClicked: Session.toggleWifi()
                        }
                        SettingsRow {
                            width: parent.width; visible: popup.page === "bluetooth"
                            symbol: "bluetooth"; text: Session.bluetoothEnabled ? "Bluetooth enabled" : "Bluetooth disabled"
                            subtitle: "Click to toggle"; selected: Session.bluetoothEnabled
                            enabled: !!Session.bluetoothAdapter
                            onClicked: Session.toggleBluetooth()
                        }
                        Repeater {
                            model: popup.page === "wifi" && Session.wifiEnabled && Session.wifiDevice ? Session.wifiDevice.networks.values : []
                            SettingsRow {
                                id: networkRow
                                required property var modelData
                                width: parent.width
                                text: modelData.name || "Скрытая сеть"
                                symbol: "wifi"; selected: modelData.connected
                                statusKind: modelData.stateChanging ? "wifi-connecting" : "wifi"
                                statusLevel: StatusLogic.wifiLevel(modelData.signalStrength)
                                statusBusy: modelData.stateChanging
                                statusWarning: modelData.connected && Session.wifiStatus.warning
                                statusLabel: "Уровень приёма: " + statusLevel + " из 3"
                                subtitle: modelData.stateChanging ? "Подключение…" : modelData.connected ? "Подключено" : ""
                                enabled: !modelData.stateChanging
                                onClicked: {
                                    if (modelData.connected) return;
                                    popup.selectedNetwork = modelData;
                                    if (modelData.known || modelData.security === WifiSecurityType.Open || modelData.security === WifiSecurityType.Owe) modelData.connect();
                                    else if ([WifiSecurityType.Wpa2Psk, WifiSecurityType.WpaPsk, WifiSecurityType.Sae].includes(modelData.security)) popup.page = "password";
                                    else popup.launchTerminal(["nmtui"]);
                                }
                                Connections {
                                    target: networkRow.modelData
                                    function onConnectionFailed(reason): void { popup.localError = "Wi-Fi: " + ConnectionFailReason.toString(reason); }
                                }
                            }
                        }
                        Repeater {
                            model: popup.page === "bluetooth" && Session.bluetoothAdapter ? Session.bluetoothAdapter.devices.values.filter(device => device.paired) : []
                            SettingsRow {
                                required property var modelData
                                width: parent.width; symbol: "bluetooth"
                                text: modelData.name; selected: modelData.connected
                                subtitle: modelData.connected ? "Connected · click to disconnect" : "Paired · click to connect"
                                enabled: Session.bluetoothEnabled
                                onClicked: modelData.connected = !modelData.connected
                            }
                        }
                        Text {
                            width: parent.width; visible: popup.page === "bluetooth"
                            text: "Paired devices appear here. Use pairing to add a new device, including PIN confirmation."
                            color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap; padding: 8
                        }
                        Repeater {
                            model: popup.page === "output" ? Session.outputs : (popup.page === "input" ? Session.inputs : [])
                            SettingsRow {
                                required property var modelData
                                width: parent.width
                                symbol: popup.page === "input" ? "microphone" : "volume"
                                text: modelData.nickname || modelData.description || modelData.name
                                subtitle: selected ? "Selected" : "Click to use this device"
                                selected: modelData === (popup.page === "input" ? Session.source : Session.sink)
                                enabled: modelData.ready
                                onClicked: { if (popup.page === "input") Session.selectInput(modelData); else Session.selectOutput(modelData); }
                            }
                        }
                        Text {
                            width: parent.width
                            visible: (popup.page === "input" && !Session.inputs.length) || (popup.page === "output" && !Session.outputs.length)
                            text: "No audio devices available"; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 12; padding: 8
                        }
                    }
                }
                SettingsRow { visible: popup.page === "wifi"; Layout.fillWidth: true; text: "Network settings"; symbol: "settings"; onClicked: popup.launchTerminal(["nmtui"]) }
                SettingsRow { visible: popup.page === "bluetooth"; Layout.fillWidth: true; text: "Pair a new device"; symbol: "bluetooth"; enabled: Session.bluetoothEnabled; onClicked: popup.launchTerminal(["bluetoothctl"]) }
                ColumnLayout {
                    visible: popup.page === "password"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                    Text { Layout.fillWidth: true; text: popup.selectedNetwork ? popup.selectedNetwork.name : ""; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 14; wrapMode: Text.Wrap }
                    Loader {
                        id: passwordLoader
                        Layout.fillWidth: true
                        active: popup.opened && popup.page === "password"
                        onLoaded: Qt.callLater(() => { if (popup.passwordInput) popup.passwordInput.forceActiveFocus(); })
                        sourceComponent: TextField {
                            id: password
                            placeholderText: "Wi-Fi password"; echoMode: TextInput.Password
                            color: Session.foreground; selectionColor: Session.accent
                            font.family: Session.fontFamily; font.pixelSize: 13
                            background: Rectangle { radius: 10; color: Glass.tint(PolyTheme.Theme.color("#303939"), 0.5); border.width: 1; border.color: password.activeFocus ? Session.accent : PolyTheme.Theme.color("#49534b") }
                            onAccepted: connectButton.clicked()
                        }
                    }
                    SettingsRow {
                        id: connectButton
                        Layout.fillWidth: true; text: "Connect"; symbol: "wifi"; enabled: !!popup.passwordInput && popup.passwordInput.text.length >= 8
                        onClicked: if (enabled && popup.selectedNetwork) { popup.selectedNetwork.connectWithPsk(popup.passwordInput.text); if (popup.passwordInput) popup.passwordInput.clear(); popup.page = "wifi"; }
                    }
                    Item { Layout.fillHeight: true }
                }
                ColumnLayout {
                    visible: popup.page === "settings"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                    SettingsRow { Layout.fillWidth: true; text: "Sound output"; symbol: "volume"; onClicked: popup.page = "output" }
                    SettingsRow { Layout.fillWidth: true; text: "Microphone"; symbol: "microphone"; onClicked: popup.page = "input" }
                    SettingsRow { Layout.fillWidth: true; text: "Wi-Fi"; symbol: "wifi"; onClicked: popup.page = "wifi" }
                    SettingsRow { Layout.fillWidth: true; text: "Bluetooth"; symbol: "bluetooth"; onClicked: popup.page = "bluetooth" }
                    SettingsRow { Layout.fillWidth: true; text: "Режим питания"; symbol: "performance"; onClicked: popup.page = "profiles" }
                    SettingsRow { Layout.fillWidth: true; text: "Авиарежим"; symbol: "airplane"; onClicked: popup.page = "airplane" }
                    SettingsRow { Layout.fillWidth: true; text: "Night Light"; symbol: "moon-warm"; onClicked: popup.page = "nightlight" }
                    SettingsRow { Layout.fillWidth: true; text: "Do Not Disturb"; symbol: "bell"; onClicked: popup.page = "dnd" }
                    Item { Layout.fillHeight: true }
                }
                ColumnLayout {
                    visible: popup.page === "profiles"
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                    Text {
                        Layout.fillWidth: true
                        text: Desktop.data.powerProfilesAvailable ? "Выбери баланс между скоростью работы и расходом батареи." : "Служба профилей питания недоступна. Нужен power-profiles-daemon."
                        color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 12; wrapMode: Text.Wrap
                    }
                    Repeater {
                        model: [{key: "power-saver", label: "Энергосбережение", detail: "Дольше от батареи, тише охлаждение", icon: "leaf"}, {key: "balanced", label: "Сбалансированный", detail: "Для повседневной работы", icon: "balance"}, {key: "performance", label: "Производительность", detail: "Для высокой нагрузки; выше расход энергии", icon: "performance"}]
                        SettingsRow {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.label; subtitle: modelData.detail; symbol: modelData.icon
                            selected: Desktop.data.powerProfile === modelData.key
                            enabled: Desktop.data.powerProfilesAvailable && (Desktop.data.powerProfiles || []).includes(modelData.key) && !Desktop.changingSettings
                            onClicked: Desktop.request("power-profile", modelData.key)
                        }
                    }
                    Text {
                        visible: !!Desktop.data.powerDegraded
                        Layout.fillWidth: true
                        text: "Система временно ограничивает высокую мощность — например, из-за температуры."
                        color: PolyTheme.Theme.color("#d9b38d"); font.family: Session.fontFamily; font.pixelSize: 12; wrapMode: Text.Wrap
                    }
                    Item { Layout.fillHeight: true }
                }
                ColumnLayout {
                    visible: popup.page === "airplane"
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
                    Text {
                        Layout.fillWidth: true
                        text: "Отключает беспроводные радиомодули, включая Wi-Fi и Bluetooth. При выключении восстанавливает их прежнее состояние."
                        color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 12; wrapMode: Text.Wrap
                    }
                    SettingsRow {
                        Layout.fillWidth: true
                        text: "Авиарежим"; symbol: "airplane"; selected: !!Desktop.data.airplane
                        subtitle: Desktop.data.airplaneManaged && !selected ? "Нажми, чтобы восстановить радиомодули" : (selected ? "Включён · нажми, чтобы выключить" : "Выключен · нажми, чтобы включить")
                        enabled: Desktop.data.airplaneAvailable && !Desktop.changingSettings
                        onClicked: Desktop.request("airplane", Desktop.data.airplane || Desktop.data.airplaneManaged ? "off" : "on")
                    }
                    Text {
                        visible: !!Desktop.data.airplaneHardwareBlocked
                        Layout.fillWidth: true
                        text: "Часть радиомодулей отключена аппаратным переключателем. Для их включения используй переключатель или клавишу ноутбука."
                        color: PolyTheme.Theme.color("#d9b38d"); font.family: Session.fontFamily; font.pixelSize: 12; wrapMode: Text.Wrap
                    }
                    Item { Layout.fillHeight: true }
                }
                ColumnLayout {
                    visible: popup.page === "nightlight" || popup.page === "dnd"
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 16
                    Text {
                        Layout.fillWidth: true
                        text: popup.page === "nightlight" ? "Warmer screen colors at 4500 K reduce blue light. Your brightness stays unchanged." : "Pause notification banners while you focus. Turn off to resume notifications."
                        color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 13; wrapMode: Text.Wrap
                    }
                    SettingsRow {
                        Layout.fillWidth: true
                        symbol: popup.page === "nightlight" ? "moon-warm" : "bell"
                        text: popup.title
                        selected: popup.page === "nightlight" ? Desktop.data.nightLight : Desktop.data.dnd
                        subtitle: selected ? "On · click to disable" : "Off · click to enable"
                        enabled: popup.page === "nightlight" ? Desktop.data.nightLightAvailable : Desktop.data.dndAvailable
                        onClicked: Desktop.request(popup.page === "nightlight" ? "nightlight" : "dnd", "")
                    }
                    Item { Layout.fillHeight: true }
                }
                ColumnLayout {
                    visible: popup.page === "power"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                    Text { text: popup.powerAction ? "Confirm " + (popup.powerAction === "poweroff" ? "power off?" : "restart?") : "Choose an action"; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 14 }
                    SettingsRow { text: "Restart"; symbol: "refresh"; Layout.fillWidth: true; onClicked: popup.powerAction = "reboot" }
                    SettingsRow { text: "Power Off"; symbol: "power"; Layout.fillWidth: true; onClicked: popup.powerAction = "poweroff" }
                    SettingsRow { text: "Confirm"; selected: true; symbol: "check"; visible: !!popup.powerAction; Layout.fillWidth: true; onClicked: { Quickshell.execDetached(["systemctl", popup.powerAction]); Session.closeQuickSettings(); } }
                    Item { Layout.fillHeight: true }
                }
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
