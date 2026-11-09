pragma ComponentBehavior: Bound
import QtQuick
import "StatusLogic.js" as StatusLogic
import "theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

ScrollView {
    id: root
    property string page: "wifi"
    property var monitors: []
    property url wallpaper: ""
    property var selectedNetwork: null
    property string localError: ""
    signal navigate(string page)
    signal chooseWallpaper()
    signal restoreWallpaper()
    clip: true; contentWidth: availableWidth
    function terminal(args: var): void { Session.launchCommand("", (Session.settings.apps.terminal || ["kitty"]).concat(["-e"]).concat(args), "", ""); }
    onPageChanged: { selectedNetwork = null; password.clear(); localError = ""; }
    Binding {
        target: Session.wifiDevice; property: "scannerEnabled"
        value: root.visible && root.page === "wifi" && Session.wifiEnabled
        when: !!Session.wifiDevice; restoreMode: Binding.RestoreBindingOrValue
    }
    ColumnLayout {
        width: root.availableWidth; spacing: 14
        SettingsCard {
            Layout.fillWidth: true; visible: root.page === "wifi" || root.page === "bluetooth"
            RowLayout {
                Layout.fillWidth: true
                SettingsBadge { symbol: root.page === "wifi" ? "wifi" : "bluetooth"; tint: root.page === "wifi" ? PolyTheme.Theme.color("#b8ce9f") : PolyTheme.Theme.color("#9cc8df") }
                ColumnLayout {
                    Layout.fillWidth: true
                    Text { text: root.page === "wifi" ? "Беспроводная сеть" : "Bluetooth"; color: PolyTheme.Theme.color("#f0f1f5"); font.family: Session.fontFamily; font.pixelSize: 17 }
                    Text { text: root.page === "wifi" ? (Session.wifiDevice ? "Доступные сети и подключение" : "Wi-Fi адаптер не найден") : (Session.bluetoothAdapter ? "Сопряжённые устройства" : "Bluetooth адаптер не найден"); color: PolyTheme.Theme.color("#bec6ce"); font.family: Session.fontFamily; font.pixelSize: 12 }
                }
                SettingsToggle {
                    checked: root.page === "wifi" ? Session.wifiEnabled : Session.bluetoothEnabled
                    enabled: root.page === "wifi" ? !!Session.wifiDevice : !!Session.bluetoothAdapter && !Desktop.changingSettings
                    Accessible.name: root.page === "wifi" ? "Включить Wi-Fi" : "Включить Bluetooth"
                    onToggled: root.page === "wifi" ? Session.toggleWifi() : Session.toggleBluetooth()
                }
            }
        }
        Repeater {
            model: root.page === "wifi" && Session.wifiEnabled && Session.wifiDevice ? Session.wifiDevice.networks.values : []
            SettingsRow {
                id: networkRow
                required property var modelData
                Layout.fillWidth: true
                symbol: "wifi"; text: modelData.name || "Скрытая сеть"; selected: modelData.connected
                statusKind: modelData.stateChanging ? "wifi-connecting" : "wifi"
                statusLevel: StatusLogic.wifiLevel(modelData.signalStrength)
                statusBusy: modelData.stateChanging
                statusWarning: modelData.connected && Session.wifiStatus.warning
                statusLabel: "Уровень приёма: " + statusLevel + " из 3"
                subtitle: modelData.stateChanging ? "Подключение…" : modelData.connected ? "Подключено" : ""
                enabled: !modelData.stateChanging
                onClicked: {
                    if (modelData.connected) return;
                    root.localError = "";
                    if (modelData.known || [WifiSecurityType.Open, WifiSecurityType.Owe].includes(modelData.security)) modelData.connect();
                    else if ([WifiSecurityType.Wpa2Psk, WifiSecurityType.WpaPsk, WifiSecurityType.Sae].includes(modelData.security)) { root.selectedNetwork = modelData; password.clear(); password.forceActiveFocus(); }
                    else root.terminal(["nmtui"]);
                }
                Connections { target: networkRow.modelData; function onConnectionFailed(reason): void { root.localError = String(reason); } }
            }
        }
        SettingsCard {
            Layout.fillWidth: true; visible: root.page === "wifi" && !!root.selectedNetwork
            Text { text: "Пароль: " + (root.selectedNetwork ? root.selectedNetwork.name : ""); color: PolyTheme.Theme.color("#eff1f4"); font.family: Session.fontFamily; font.pixelSize: 14 }
            TextField {
                id: password
                Layout.fillWidth: true; placeholderText: "Пароль Wi-Fi"; echoMode: TextInput.Password
                color: PolyTheme.Theme.color("#eff1f4"); font.family: Session.fontFamily; font.pixelSize: 14; padding: 12
                background: Rectangle { radius: 9; color: PolyTheme.Theme.color("#252c33"); border.color: password.activeFocus ? PolyTheme.Theme.color("#b5c99d") : PolyTheme.Theme.color("#596166") }
                onAccepted: if (connectButton.enabled) connectButton.clicked()
            }
            AppearanceButton {
                id: connectButton
                text: "Подключиться"; symbol: "wifi"; primary: true
                enabled: password.text.length >= 8 && password.text.length <= 63
                onClicked: { if (!root.selectedNetwork) return; root.selectedNetwork.connectWithPsk(password.text); password.clear(); root.selectedNetwork = null; }
            }
        }
        Text { Layout.fillWidth: true; visible: root.page === "wifi" && Session.wifiEnabled && Session.wifiDevice && !Session.wifiDevice.networks.values.length; text: "Поиск доступных сетей…"; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 13 }
        AppearanceButton { visible: root.page === "wifi"; text: "Расширенные настройки сети"; symbol: "settings"; onClicked: root.terminal(["nmtui"]) }
        Repeater {
            model: root.page === "bluetooth" && Session.bluetoothAdapter ? Session.bluetoothAdapter.devices.values.filter(d => d.paired) : []
            SettingsRow {
                required property var modelData
                Layout.fillWidth: true; symbol: "bluetooth"; text: modelData.name; selected: modelData.connected
                subtitle: modelData.connected ? "Подключено · нажми, чтобы отключить" : "Сопряжено · нажми, чтобы подключить"
                enabled: Session.bluetoothEnabled
                onClicked: modelData.connected = !modelData.connected
            }
        }
        SettingsCard {
            Layout.fillWidth: true; visible: root.page === "bluetooth"
            Text { Layout.fillWidth: true; text: "Новые устройства пока подключаются через Bluetoothctl с подтверждением PIN. Встроенное сопряжение добавим следующим этапом."; wrapMode: Text.Wrap; color: PolyTheme.Theme.color("#c2c9d1"); font.family: Session.fontFamily; font.pixelSize: 13 }
            AppearanceButton { text: "Подключить новое устройство"; symbol: "plus"; enabled: Session.bluetoothEnabled; onClicked: root.terminal(["bluetoothctl"]) }
        }
        Repeater {
            model: root.page === "monitors" ? root.monitors : []
            SettingsCard {
                id: monitorCard
                required property var modelData
                Layout.fillWidth: true
                RowLayout {
                    Layout.fillWidth: true
                    SettingsBadge { symbol: "monitor" }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Text { text: monitorCard.modelData.name; color: PolyTheme.Theme.color("#eff1f4"); font.family: Session.fontFamily; font.pixelSize: 17 }
                        Text { Layout.fillWidth: true; text: monitorCard.modelData.description; color: PolyTheme.Theme.color("#bec7ce"); font.family: Session.fontFamily; font.pixelSize: 12; wrapMode: Text.Wrap }
                    }
                }
                Text { text: monitorCard.modelData.width + " × " + monitorCard.modelData.height + " · " + Math.round(monitorCard.modelData.refreshRate) + " Гц · масштаб " + monitorCard.modelData.scale; color: PolyTheme.Theme.color("#d3d9db"); font.family: Session.fontFamily; font.pixelSize: 13 }
                Text { text: "Расположение: " + monitorCard.modelData.x + ", " + monitorCard.modelData.y; color: PolyTheme.Theme.color("#bec7ce"); font.family: Session.fontFamily; font.pixelSize: 12 }
            }
        }
        SettingsCard {
            Layout.fillWidth: true; visible: root.page === "monitors"
            Text { Layout.fillWidth: true; text: "Здесь показаны текущие данные Hyprland. Изменение разрешения, масштаба и расположения экранов добавим отдельно, с подтверждением и автоматическим возвратом."; wrapMode: Text.Wrap; color: PolyTheme.Theme.color("#c2c9d1"); font.family: Session.fontFamily; font.pixelSize: 13 }
            ControlSlider { Layout.fillWidth: true; wheelEnabled: false; visible: Desktop.data.brightnessAvailable; from: 5; to: 100; stepSize: 1; value: Desktop.data.brightness; Accessible.name: "Яркость экрана"; onPressedChanged: if (!pressed) Desktop.request("brightness", String(Math.round(value))) }
        }
        SettingsCard {
            Layout.fillWidth: true; visible: root.page === "wallpaper"
            SettingsImage { Layout.fillWidth: true; Layout.preferredHeight: 285; source: root.wallpaper; sourceSize: Qt.size(1100, 570) }
            Text { text: "Обои рабочего стола"; color: PolyTheme.Theme.color("#eff1f4"); font.family: Session.fontFamily; font.pixelSize: 19 }
            Text { Layout.fillWidth: true; text: "Выбери своё изображение или верни альпийский рассвет. Обои сохраняются для следующего входа."; wrapMode: Text.Wrap; color: PolyTheme.Theme.color("#c2c9d1"); font.family: Session.fontFamily; font.pixelSize: 13 }
            RowLayout {
                AppearanceButton { text: "Сменить обои"; symbol: "wallpaper"; primary: true; onClicked: root.chooseWallpaper() }
                AppearanceButton { text: "Вернуть Alpine"; symbol: "refresh"; onClicked: root.restoreWallpaper() }
            }
        }
        SettingsCard {
            Layout.fillWidth: true; visible: root.page === "sound"
            Text { text: "Вывод звука"; color: PolyTheme.Theme.color("#eff1f4"); font.family: Session.fontFamily; font.pixelSize: 17 }
            RowLayout {
                Layout.fillWidth: true
                IconButton { symbol: Session.audio && Session.audio.muted ? "muted" : "volume"; hint: "Выключить / включить звук"; enabled: !!Session.audio; onClicked: Session.audio.muted = !Session.audio.muted }
                ControlSlider { Layout.fillWidth: true; wheelEnabled: false; enabled: !!Session.audio; value: Session.audio ? Session.audio.volume : 0; Accessible.name: "Громкость"; onMoved: if (Session.audio) Session.audio.volume = value }
            }
            Repeater {
                model: Session.outputs
                SettingsRow { required property var modelData; Layout.fillWidth: true; text: modelData.nickname || modelData.description || modelData.name; symbol: "volume"; selected: modelData === Session.sink; enabled: modelData.ready; onClicked: Session.selectOutput(modelData) }
            }
            Text { text: "Микрофон"; color: PolyTheme.Theme.color("#eff1f4"); font.family: Session.fontFamily; font.pixelSize: 17 }
            RowLayout {
                Layout.fillWidth: true
                IconButton { symbol: Session.microphone && Session.microphone.muted ? "microphone-muted" : "microphone"; hint: "Выключить / включить микрофон"; enabled: !!Session.microphone; onClicked: Session.microphone.muted = !Session.microphone.muted }
                ControlSlider { Layout.fillWidth: true; wheelEnabled: false; enabled: !!Session.microphone; value: Session.microphone ? Session.microphone.volume : 0; Accessible.name: "Громкость микрофона"; onMoved: if (Session.microphone) Session.microphone.volume = value }
            }
            Repeater {
                model: Session.inputs
                SettingsRow { required property var modelData; Layout.fillWidth: true; text: modelData.nickname || modelData.description || modelData.name; symbol: "microphone"; selected: modelData === Session.source; enabled: modelData.ready; onClicked: Session.selectInput(modelData) }
            }
        }
        SettingsCard {
            Layout.fillWidth: true; visible: root.page === "power"
            Text { text: Session.batteryDescription; color: PolyTheme.Theme.color("#eff1f4"); font.family: Session.fontFamily; font.pixelSize: 17 }
            Repeater {
                model: [{key: "power-saver", label: "Энергосбережение", icon: "leaf"}, {key: "balanced", label: "Сбалансированный", icon: "balance"}, {key: "performance", label: "Производительность", icon: "performance"}]
                SettingsRow {
                    required property var modelData
                    Layout.fillWidth: true; text: modelData.label; symbol: modelData.icon
                    selected: Desktop.data.powerProfile === modelData.key
                    enabled: Desktop.data.powerProfilesAvailable && (Desktop.data.powerProfiles || []).includes(modelData.key) && !Desktop.changingSettings
                    onClicked: Desktop.request("power-profile", modelData.key)
                }
            }
            Text { Layout.fillWidth: true; visible: !Desktop.data.powerProfilesAvailable; text: "Служба профилей питания недоступна."; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 12 }
        }
        SettingsCard {
            Layout.fillWidth: true; visible: root.page === "notifications"
            RowLayout {
                Layout.fillWidth: true
                SettingsBadge { symbol: "bell"; tint: PolyTheme.Theme.color("#edb493") }
                Text { Layout.fillWidth: true; text: "Не беспокоить"; color: PolyTheme.Theme.color("#eff1f4"); font.family: Session.fontFamily; font.pixelSize: 17 }
                SettingsToggle { checked: !!Desktop.data.dnd; enabled: Desktop.data.dndAvailable && !Desktop.changingSettings; Accessible.name: "Не беспокоить"; onToggled: Desktop.request("dnd", "") }
            }
            Text { Layout.fillWidth: true; text: "Приостанавливает всплывающие уведомления. История остаётся доступной в баре."; color: PolyTheme.Theme.color("#c2c9d1"); wrapMode: Text.Wrap; font.family: Session.fontFamily; font.pixelSize: 13 }
        }
        SettingsCard {
            Layout.fillWidth: true; visible: root.page === "modes"
            Text { text: "Режим работы"; color: PolyTheme.Theme.color("#eff1f4"); font.family: Session.fontFamily; font.pixelSize: 17 }
            Text { Layout.fillWidth: true; text: "Work и Vibe переключают профили независимо от оформления Alpine."; color: PolyTheme.Theme.color("#c2c9d1"); wrapMode: Text.Wrap; font.family: Session.fontFamily; font.pixelSize: 13 }
            RowLayout {
                AppearanceButton { text: "Work"; symbol: "monitor"; selected: Session.mode === "work"; enabled: !Session.switching; onClicked: Session.setMode("work") }
                AppearanceButton { text: "Vibe"; symbol: "moon"; selected: Session.mode === "vibe"; enabled: !Session.switching; onClicked: Session.setMode("vibe") }
            }
        }
        SettingsCard {
            Layout.fillWidth: true; visible: ["panel", "input", "devices"].includes(root.page)
            Text { Layout.fillWidth: true; text: root.page === "panel" ? "Настройки геометрии бара и меню доступны в разделе «Внешний вид»." : root.page === "input" ? "Отдельные настройки раскладки, клавиш и указателя появятся здесь следующим этапом." : "Аудиоустройства и Bluetooth уже доступны в своих разделах. Управление остальной периферией добавим сюда."; color: PolyTheme.Theme.color("#c2c9d1"); font.family: Session.fontFamily; font.pixelSize: 14; wrapMode: Text.Wrap }
            AppearanceButton { text: root.page === "panel" ? "Внешний вид" : "Bluetooth"; symbol: root.page === "panel" ? "palette" : "bluetooth"; onClicked: root.navigate(root.page === "panel" ? "appearance" : "bluetooth") }
        }
        Text { Layout.fillWidth: true; visible: !!root.localError; text: root.localError; color: PolyTheme.Theme.color("#f0b297"); font.family: Session.fontFamily; font.pixelSize: 13; wrapMode: Text.Wrap }
    }
}
