pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../logic/StatusLogic.js" as StatusLogic
import "../theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking

ColumnLayout {
    id: root
    required property var popup
    spacing: 12
    opacity: popup.pageMotion.opacity
    transformOrigin: Item.Top

    RowLayout {
        IconButton {
            symbol: "chevron-left"
            hint: I18n.tr("common.back")
            implicitWidth: 30
            implicitHeight: 30
            onClicked: { root.popup.page = "main"; root.popup.powerAction = ""; }
        }
        Text {
            text: root.popup.title
            color: Session.foreground
            font.family: Session.fontFamily
            font.pixelSize: 15
        }
        Item { Layout.fillWidth: true }
        IconButton {
            symbol: "close"
            hint: I18n.tr("common.close")
            implicitWidth: 30
            implicitHeight: 30
            onClicked: Session.closeQuickSettings()
        }
    }

    ScrollView {
        id: deviceScroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: ["wifi", "bluetooth", "output", "input"].includes(root.popup.page)
        clip: true
        contentWidth: availableWidth

        Column {
            width: deviceScroll.availableWidth
            spacing: 8

            SettingsRow {
                width: parent.width
                visible: root.popup.page === "wifi"
                symbol: "wifi"
                text: Session.wifiEnabled ? I18n.tr("wifi.enabled") : I18n.tr("wifi.disabled")
                statusKind: Session.wifiStatus.kind
                statusLevel: Session.wifiStatus.level
                statusBusy: Session.wifiStatus.busy
                statusWarning: Session.wifiStatus.warning
                subtitle: I18n.tr("quick.click_to_toggle")
                selected: Session.wifiEnabled
                enabled: !!Session.wifiDevice
                onClicked: Session.toggleWifi()
            }

            SettingsRow {
                width: parent.width
                visible: root.popup.page === "bluetooth"
                symbol: "bluetooth"
                text: Session.bluetoothEnabled ? "Bluetooth enabled" : "Bluetooth disabled"
                subtitle: "Click to toggle"
                selected: Session.bluetoothEnabled
                enabled: !!Session.bluetoothAdapter
                onClicked: Session.toggleBluetooth()
            }

            Repeater {
                model: root.popup.page === "wifi" && Session.wifiEnabled && Session.wifiDevice ? Session.wifiDevice.networks.values : []
                SettingsRow {
                    id: networkRow
                    required property var modelData
                    width: parent.width
                    text: modelData.name || I18n.tr("quick.hidden_network")
                    symbol: "wifi"
                    selected: modelData.connected
                    statusKind: modelData.stateChanging ? "wifi-connecting" : "wifi"
                    statusLevel: StatusLogic.wifiLevel(modelData.signalStrength)
                    statusBusy: modelData.stateChanging
                    statusWarning: modelData.connected && Session.wifiStatus.warning
                    statusLabel: I18n.trWith("quick.signal_level", {level: statusLevel})
                    subtitle: modelData.stateChanging ? I18n.tr("quick.connecting") : modelData.connected ? I18n.tr("quick.connected") : ""
                    enabled: !modelData.stateChanging
                    onClicked: {
                        if (modelData.connected) return;
                        root.popup.selectedNetwork = modelData;
                        root.popup.customSsid = "";
                        root.popup.localError = "";
                        if (modelData.known || modelData.security === WifiSecurityType.Open || modelData.security === WifiSecurityType.Owe) {
                            modelData.connect();
                        } else if ([WifiSecurityType.Wpa2Psk, WifiSecurityType.WpaPsk, WifiSecurityType.Sae].includes(modelData.security)) {
                            root.popup.isEnterprise = false;
                            root.popup.page = "password";
                        } else {
                            root.popup.isEnterprise = true;
                            root.popup.page = "password";
                        }
                    }
                    Connections {
                        target: networkRow.modelData
                        function onConnectionFailed(reason): void { root.popup.localError = "Wi-Fi: " + ConnectionFailReason.toString(reason); }
                    }
                }
            }

            Repeater {
                model: root.popup.page === "bluetooth" && Session.bluetoothAdapter ? Session.bluetoothAdapter.devices.values.filter(device => device.paired) : []
                RowLayout {
                    id: btDeviceRow
                    required property var modelData
                    width: parent.width
                    spacing: 4
                    SettingsRow {
                        Layout.fillWidth: true
                        symbol: "bluetooth"
                        text: btDeviceRow.modelData.name || btDeviceRow.modelData.address
                        selected: btDeviceRow.modelData.connected
                        subtitle: btDeviceRow.modelData.connected ? "Connected · click to disconnect" : "Paired · click to connect"
                        enabled: Session.bluetoothEnabled
                        onClicked: {
                            if (btDeviceRow.modelData.connected) btDeviceRow.modelData.disconnect();
                            else btDeviceRow.modelData.connect();
                        }
                    }
                    IconButton {
                        symbol: "delete"
                        hint: "Forget device"
                        implicitWidth: 32
                        implicitHeight: 32
                        onClicked: btDeviceRow.modelData.forget()
                    }
                }
            }

            Repeater {
                model: root.popup.page === "input" ? Session.inputs : root.popup.page === "output" ? Session.outputs : []
                SettingsRow {
                    required property var modelData
                    width: parent.width
                    symbol: root.popup.page === "input" ? "microphone" : "volume"
                    text: modelData.nickname || modelData.description || modelData.name
                    subtitle: selected ? "Selected" : "Click to use this device"
                    selected: modelData === (root.popup.page === "input" ? Session.source : Session.sink)
                    enabled: modelData.ready
                    onClicked: { if (root.popup.page === "input") Session.selectInput(modelData); else Session.selectOutput(modelData); }
                }
            }

            Text {
                width: parent.width
                visible: (root.popup.page === "input" && !Session.inputs.length) || (root.popup.page === "output" && !Session.outputs.length)
                text: I18n.tr("audio.no_devices")
                color: Session.muted
                font.family: Session.fontFamily
                font.pixelSize: 12
                padding: 8
            }

            // Per-Application Audio Streams (Pipewire)
            Column {
                width: parent.width
                visible: root.popup.page === "output" && Session.audioStreams && Session.audioStreams.length > 0
                spacing: 8

                Item { width: parent.width; height: 12 }
                GlowSectionDivider { width: parent.width }
                Text {
                    text: I18n.tr("audio.app_streams")
                    color: Session.foreground
                    font.family: Session.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    padding: 4
                }

                Repeater {
                    model: Session.audioStreams
                    HoverControl {
                        required property var modelData
                        width: parent.width
                        label: (modelData.properties && (modelData.properties["application.name"] || modelData.properties["node.description"])) || modelData.name || "App"
                        symbol: (modelData.properties && modelData.properties["application.icon-name"]) || "volume"
                        detail: (modelData.properties && modelData.properties["media.name"]) || ""
                        value: modelData.audio ? modelData.audio.volume : 0
                        muted: modelData.audio ? modelData.audio.muted : false
                        hasMute: true
                        onAdjusted: v => {
                            if (modelData.audio) {
                                modelData.audio.volume = v;
                                if (v > 0) modelData.audio.muted = false;
                            }
                        }
                        onMuteRequested: {
                            if (modelData.audio) {
                                modelData.audio.muted = !modelData.audio.muted;
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsRow {
        visible: root.popup.page === "wifi"
        Layout.fillWidth: true
        text: I18n.tr("quick.mobile_hotspot")
        subtitle: Desktop.data.hotspot ? (Desktop.data.hotspotClients > 0 ? I18n.trWith("wifi.hotspot_devices", {count: Desktop.data.hotspotClients}) : I18n.tr("common.enabled")) : I18n.tr("common.disabled")
        symbol: "hotspot"
        onClicked: root.popup.page = "hotspot"
    }

    SettingsRow {
        visible: root.popup.page === "wifi"
        Layout.fillWidth: true
        text: I18n.tr("wifi.add_hidden")
        symbol: "plus"
        onClicked: { root.popup.selectedNetwork = null; root.popup.customSsid = ""; root.popup.isEnterprise = false; root.popup.localError = ""; root.popup.page = "password"; }
    }

    SettingsRow {
        visible: root.popup.page === "bluetooth"
        Layout.fillWidth: true
        text: I18n.tr("bluetooth.pair_new")
        symbol: "bluetooth"
        enabled: Session.bluetoothEnabled
        onClicked: root.popup.launchTerminal(["bluetoothctl"])
    }

    // Password connection subpage
    ColumnLayout {
        visible: root.popup.page === "password"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Icon { name: "wifi"; implicitWidth: 20; implicitHeight: 20 }
            Text {
                Layout.fillWidth: true
                text: root.popup.selectedNetwork ? root.popup.selectedNetwork.name : (root.popup.customSsid || I18n.tr("quick.hidden_network"))
                color: Session.foreground
                font.family: Session.fontFamily
                font.pixelSize: 15
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        Text {
            visible: !root.popup.selectedNetwork
            text: I18n.tr("wifi.enter_ssid")
            color: Session.muted
            font.family: Session.fontFamily
            font.pixelSize: 11
        }

        TextField {
            id: hiddenSsidInput
            visible: !root.popup.selectedNetwork
            Layout.fillWidth: true
            placeholderText: I18n.tr("wifi.hotspot_name")
            color: Session.foreground
            selectionColor: Session.accent
            font.family: Session.fontFamily
            font.pixelSize: 13
            padding: 10
            background: Rectangle {
                radius: 10
                color: Glass.tint(PolyTheme.Theme.color("#303939"), 0.5)
                border.width: 1
                border.color: hiddenSsidInput.activeFocus ? Session.accent : PolyTheme.Theme.color("#49534b")
            }
            onTextChanged: root.popup.customSsid = text.trim()
        }

        Rectangle {
            Layout.fillWidth: true
            height: 36
            radius: 8
            color: Glass.tint(Session.surface, 0.3)
            border.width: 1
            border.color: Glass.tint(Session.accent, 0.15)
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8
                Rectangle {
                    width: 16
                    height: 16
                    radius: 4
                    color: root.popup.isEnterprise ? Session.accent : "transparent"
                    border.width: 1.5
                    border.color: root.popup.isEnterprise ? Session.accent : Session.muted
                    Icon { anchors.centerIn: parent; name: "check"; implicitWidth: 12; implicitHeight: 12; visible: root.popup.isEnterprise }
                }
                Text {
                    Layout.fillWidth: true
                    text: I18n.tr("wifi.enterprise_checkbox")
                    color: Session.foreground
                    font.family: Session.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.popup.isEnterprise = !root.popup.isEnterprise
            }
        }

        ColumnLayout {
            visible: root.popup.isEnterprise
            Layout.fillWidth: true
            spacing: 4
            Text { text: I18n.tr("wifi.enterprise_identity"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11 }
            TextField {
                id: identityField
                Layout.fillWidth: true
                placeholderText: "identity / username"
                color: Session.foreground
                selectionColor: Session.accent
                font.family: Session.fontFamily
                font.pixelSize: 13
                padding: 10
                background: Rectangle {
                    radius: 10
                    color: Glass.tint(PolyTheme.Theme.color("#303939"), 0.5)
                    border.width: 1
                    border.color: identityField.activeFocus ? Session.accent : PolyTheme.Theme.color("#49534b")
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text { text: I18n.tr("wifi.password_label"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11 }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Loader {
                    id: passwordLoader
                    Layout.fillWidth: true
                    active: root.popup.opened && root.popup.page === "password"
                    onLoaded: Qt.callLater(() => { if (root.popup.passwordInput) root.popup.passwordInput.forceActiveFocus(); })
                    sourceComponent: TextField {
                        id: password
                        placeholderText: I18n.tr("wifi.password_placeholder")
                        echoMode: root.popup.showPassword ? TextInput.Normal : TextInput.Password
                        color: Session.foreground
                        selectionColor: Session.accent
                        font.family: Session.fontFamily
                        font.pixelSize: 13
                        padding: 10
                        background: Rectangle {
                            radius: 10
                            color: Glass.tint(PolyTheme.Theme.color("#303939"), 0.5)
                            border.width: 1
                            border.color: password.activeFocus ? Session.accent : PolyTheme.Theme.color("#49534b")
                        }
                        onAccepted: if (connectButton.enabled) connectButton.clicked()
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 38
                    radius: 9
                    color: Glass.tint(Session.surface, 0.4)
                    border.width: 1
                    border.color: Glass.tint(Session.accent, 0.2)
                    Text {
                        anchors.centerIn: parent
                        text: root.popup.showPassword ? I18n.tr("wifi.hide_password") : I18n.tr("wifi.show_password")
                        color: Session.accent
                        font.family: Session.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.popup.showPassword = !root.popup.showPassword
                    }
                }
            }
        }

        Text {
            visible: !!root.popup.localError || !!Desktop.error
            Layout.fillWidth: true
            text: root.popup.localError || Desktop.error
            color: PolyTheme.Theme.color("#f18b82")
            font.family: Session.fontFamily
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            SettingsRow {
                id: connectButton
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: I18n.tr("wifi.connect_button")
                symbol: "wifi"
                readonly property string activeSsid: root.popup.selectedNetwork ? root.popup.selectedNetwork.name : root.popup.customSsid
                readonly property string passVal: root.popup.passwordInput ? root.popup.passwordInput.text : ""
                readonly property string identVal: identityField ? identityField.text.trim() : ""
                enabled: activeSsid.length > 0 && (!root.popup.isEnterprise ? (passVal.length >= 8 || !root.popup.selectedNetwork) : (identVal.length > 0 && passVal.length > 0)) && !Desktop.changingSettings
                onClicked: {
                    if (!enabled) return;
                    root.popup.localError = "";
                    if (root.popup.isEnterprise) {
                        Desktop.request("wifi-connect", JSON.stringify({ ssid: activeSsid, identity: identVal, password: passVal }));
                        root.popup.page = "wifi";
                    } else if (root.popup.selectedNetwork) {
                        root.popup.selectedNetwork.connectWithPsk(passVal);
                        if (root.popup.passwordInput) root.popup.passwordInput.clear();
                        root.popup.page = "wifi";
                    } else {
                        Desktop.request("wifi-connect", JSON.stringify({ ssid: activeSsid, password: passVal, hidden: true }));
                        root.popup.page = "wifi";
                    }
                }
            }
            SettingsRow {
                Layout.preferredWidth: 80
                text: I18n.tr("common.cancel")
                symbol: "close"
                onClicked: { root.popup.localError = ""; root.popup.page = "wifi"; }
            }
        }
        Item { Layout.fillHeight: true }
    }

    // Hotspot subpage
    ColumnLayout {
        visible: root.popup.page === "hotspot"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12
        Text {
            Layout.fillWidth: true
            text: I18n.tr("wifi.hotspot_desc")
            color: Session.muted
            font.family: Session.fontFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        SettingsRow {
            Layout.fillWidth: true
            text: I18n.tr("quick.mobile_hotspot")
            symbol: "hotspot"
            selected: !!Desktop.data.hotspot
            subtitle: Desktop.data.hotspot ? (Desktop.data.hotspotClients > 0 ? I18n.trWith("wifi.hotspot_devices", {count: Desktop.data.hotspotClients}) : I18n.tr("common.enabled")) : I18n.tr("common.disabled")
            enabled: Desktop.data.hotspotAvailable && !Desktop.changingSettings && !Desktop.data.airplane
            onClicked: Desktop.request("hotspot", Desktop.data.hotspot ? "off" : "on")
        }
        GlowSectionDivider {
            Layout.fillWidth: true
        }
        Text {
            text: I18n.tr("wifi.hotspot_name")
            color: Session.muted
            font.family: Session.fontFamily
            font.pixelSize: 11
        }
        TextField {
            id: hotspotSsidEdit
            Layout.fillWidth: true
            text: Desktop.data.hotspotSsid || "Alpora-Hotspot"
            color: Session.foreground
            selectionColor: Session.accent
            font.family: Session.fontFamily
            font.pixelSize: 13
            padding: 10
            background: Rectangle {
                radius: 10
                color: Glass.tint(PolyTheme.Theme.color("#303939"), 0.5)
                border.width: 1
                border.color: hotspotSsidEdit.activeFocus ? Session.accent : PolyTheme.Theme.color("#49534b")
            }
        }
        Text {
            text: I18n.tr("wifi.hotspot_password")
            color: Session.muted
            font.family: Session.fontFamily
            font.pixelSize: 11
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            TextField {
                id: hotspotPasswordEdit
                Layout.fillWidth: true
                text: Desktop.data.hotspotPassword || "alporapassword"
                echoMode: root.popup.showPassword ? TextInput.Normal : TextInput.Password
                color: Session.foreground
                selectionColor: Session.accent
                font.family: Session.fontFamily
                font.pixelSize: 13
                padding: 10
                background: Rectangle {
                    radius: 10
                    color: Glass.tint(PolyTheme.Theme.color("#303939"), 0.5)
                    border.width: 1
                    border.color: hotspotPasswordEdit.activeFocus ? Session.accent : PolyTheme.Theme.color("#49534b")
                }
            }
            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 38
                radius: 9
                color: Glass.tint(Session.surface, 0.4)
                border.width: 1
                border.color: Glass.tint(Session.accent, 0.2)
                Text {
                    anchors.centerIn: parent
                    text: root.popup.showPassword ? I18n.tr("wifi.hide_password") : I18n.tr("wifi.show_password")
                    color: Session.accent
                    font.family: Session.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.popup.showPassword = !root.popup.showPassword
                }
            }
        }
        Text {
            text: I18n.tr("wifi.hotspot_band")
            color: Session.muted
            font.family: Session.fontFamily
            font.pixelSize: 11
        }
        SettingsRow {
            Layout.fillWidth: true
            text: I18n.tr("wifi.hotspot_save")
            symbol: "check"
            enabled: hotspotSsidEdit.text.trim().length > 0 && hotspotPasswordEdit.text.trim().length >= 8 && !Desktop.changingSettings
            onClicked: {
                Desktop.request("hotspot", JSON.stringify({ ssid: hotspotSsidEdit.text.trim(), password: hotspotPasswordEdit.text.trim(), active: Desktop.data.hotspot }));
            }
        }
        Item { Layout.fillHeight: true }
    }

    // Devices subpage
    ColumnLayout {
        visible: root.popup.page === "settings"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            HoverStatusTile {
                Layout.fillWidth: true
                title: "Wi-Fi"
                symbol: "wifi"
                detail: Desktop.data.wifiSsid || I18n.tr("common.disconnected")
                active: Desktop.data.wifiEnabled
                connected: !!Desktop.data.wifiSsid
                statusKind: "wifi"
                statusLevel: Desktop.data.wifiStrength || 0
                onClicked: root.popup.page = "wifi"
            }

            HoverStatusTile {
                Layout.fillWidth: true
                title: "Bluetooth"
                symbol: "bluetooth"
                detail: Desktop.data.bluetoothConnectedDevice || (Desktop.data.bluetoothEnabled ? I18n.tr("bluetooth.on") : I18n.tr("common.off"))
                active: Desktop.data.bluetoothEnabled
                connected: !!Desktop.data.bluetoothConnectedDevice
                statusKind: "bluetooth"
                onClicked: root.popup.page = "bluetooth"
            }

            HoverStatusTile {
                Layout.fillWidth: true
                title: "Audio Out"
                symbol: "volume"
                detail: Desktop.data.audioOutputDescription || "Default Output"
                active: !Desktop.data.audioMuted
                connected: true
                onClicked: root.popup.page = "output"
            }

            HoverStatusTile {
                Layout.fillWidth: true
                title: "Power Profile"
                symbol: "performance"
                detail: Desktop.data.powerProfile || "balanced"
                active: Desktop.data.powerProfile === "performance"
                connected: Desktop.data.powerProfilesAvailable
                onClicked: root.popup.page = "profiles"
            }
        }

        GlowSectionDivider { Layout.fillWidth: true }

        SettingsRow { Layout.fillWidth: true; text: I18n.tr("quick.sound_output"); symbol: "volume"; onClicked: root.popup.page = "output" }
        SettingsRow { Layout.fillWidth: true; text: I18n.tr("quick.microphone"); symbol: "microphone"; onClicked: root.popup.page = "input" }
        SettingsRow { Layout.fillWidth: true; text: "Wi-Fi"; symbol: "wifi"; onClicked: root.popup.page = "wifi" }
        SettingsRow { Layout.fillWidth: true; text: "Bluetooth"; symbol: "bluetooth"; onClicked: root.popup.page = "bluetooth" }
        SettingsRow { Layout.fillWidth: true; text: I18n.tr("quick.mobile_hotspot"); symbol: "hotspot"; onClicked: root.popup.page = "hotspot" }
        SettingsRow { Layout.fillWidth: true; text: I18n.tr("quick.power_mode"); symbol: "performance"; onClicked: root.popup.page = "profiles" }
        SettingsRow { Layout.fillWidth: true; text: I18n.tr("quick.airplane_mode"); symbol: "airplane"; onClicked: root.popup.page = "airplane" }
        SettingsRow { Layout.fillWidth: true; text: I18n.tr("quick.night_light"); symbol: "moon-warm"; onClicked: root.popup.page = "nightlight" }
        SettingsRow { Layout.fillWidth: true; text: I18n.tr("quick.dnd"); symbol: "bell"; onClicked: root.popup.page = "dnd" }
        Item { Layout.fillHeight: true }
    }

    // Power Profiles subpage
    ColumnLayout {
        visible: root.popup.page === "profiles"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12
        Text {
            Layout.fillWidth: true
            text: Desktop.data.powerProfilesAvailable ? I18n.tr("quick.power_profiles_desc") : I18n.tr("quick.power_profiles_unavailable")
            color: Session.muted
            font.family: Session.fontFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        Repeater {
            model: [{key: "power-saver", label: I18n.tr("quick.power_saver"), detail: I18n.tr("quick.power_saver_desc"), icon: "leaf"}, {key: "balanced", label: I18n.tr("quick.balanced"), detail: I18n.tr("quick.balanced_desc"), icon: "balance"}, {key: "performance", label: I18n.tr("quick.performance"), detail: I18n.tr("quick.performance_desc"), icon: "performance"}]
            QuickTile {
                required property var modelData
                Layout.fillWidth: true
                title: modelData.label
                subtitle: modelData.detail
                symbol: modelData.icon
                active: Desktop.data.powerProfile === modelData.key
                enabled: Desktop.data.powerProfilesAvailable && (Desktop.data.powerProfiles || []).includes(modelData.key) && !Desktop.changingSettings
                onClicked: Desktop.request("power-profile", modelData.key)
            }
        }
        Text {
            visible: !!Desktop.data.powerDegraded
            Layout.fillWidth: true
            text: I18n.tr("quick.power_throttled")
            color: PolyTheme.Theme.color("#d9b38d")
            font.family: Session.fontFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        Item { Layout.fillHeight: true }
    }

    // Airplane subpage
    ColumnLayout {
        visible: root.popup.page === "airplane"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 14
        Text {
            Layout.fillWidth: true
            text: I18n.tr("quick.airplane_desc")
            color: Session.muted
            font.family: Session.fontFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        SettingsRow {
            Layout.fillWidth: true
            text: I18n.tr("quick.airplane_mode")
            symbol: "airplane"
            selected: !!Desktop.data.airplane
            subtitle: Desktop.data.airplaneManaged && !selected ? I18n.tr("quick.airplane_restore") : (selected ? I18n.tr("quick.airplane_on_desc") : I18n.tr("quick.airplane_off_desc"))
            enabled: Desktop.data.airplaneAvailable && !Desktop.changingSettings
            onClicked: Desktop.request("airplane", Desktop.data.airplane || Desktop.data.airplaneManaged ? "off" : "on")
        }
        Text {
            visible: !!Desktop.data.airplaneHardwareBlocked
            Layout.fillWidth: true
            text: I18n.tr("quick.airplane_hardware_rfkill")
            color: PolyTheme.Theme.color("#d9b38d")
            font.family: Session.fontFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        Item { Layout.fillHeight: true }
    }

    // Nightlight / DND subpage
    ColumnLayout {
        visible: root.popup.page === "nightlight" || root.popup.page === "dnd"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 16
        Text {
            Layout.fillWidth: true
            text: root.popup.page === "nightlight" ? "Warmer screen colors at 4500 K reduce blue light. Your brightness stays unchanged." : "Pause notification banners while you focus. Turn off to resume notifications."
            color: Session.muted
            font.family: Session.fontFamily
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }
        SettingsRow {
            Layout.fillWidth: true
            symbol: root.popup.page === "nightlight" ? "moon-warm" : "bell"
            text: root.popup.title
            selected: root.popup.page === "nightlight" ? Desktop.data.nightLight : Desktop.data.dnd
            subtitle: selected ? "On · click to disable" : "Off · click to enable"
            enabled: root.popup.page === "nightlight" ? Desktop.data.nightLightAvailable : Desktop.data.dndAvailable
            onClicked: Desktop.request(root.popup.page === "nightlight" ? "nightlight" : "dnd", "")
        }
        Item { Layout.fillHeight: true }
    }

    // Power Actions subpage
    ColumnLayout {
        visible: root.popup.page === "power"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12
        Text {
            text: root.popup.powerAction ? I18n.trWith("quick.confirm_action", {action: root.popup.powerAction === "poweroff" ? I18n.tr("quick.shutdown") : I18n.tr("quick.reboot")}) : I18n.tr("quick.choose_action")
            color: Session.foreground
            font.family: Session.fontFamily
            font.pixelSize: 14
        }
        SettingsRow { text: I18n.tr("quick.reboot"); symbol: "refresh"; Layout.fillWidth: true; onClicked: root.popup.powerAction = "reboot" }
        SettingsRow { text: I18n.tr("quick.shutdown"); symbol: "power"; Layout.fillWidth: true; onClicked: root.popup.powerAction = "poweroff" }
        SettingsRow { text: I18n.tr("common.confirm"); selected: true; symbol: "check"; visible: !!root.popup.powerAction; Layout.fillWidth: true; onClicked: { Quickshell.execDetached(["systemctl", root.popup.powerAction]); Session.closeQuickSettings(); } }
        Item { Layout.fillHeight: true }
    }
}

