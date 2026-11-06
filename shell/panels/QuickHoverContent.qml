pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Layouts

ColumnLayout {
    id: root
    signal expandRequested()
    readonly property bool dragging: volume.dragging || brightness.dragging
    readonly property bool wifiConnected: Session.wifiEnabled && !!Session.wifiNetwork && !Session.wifiStatus.busy
    readonly property string wifiDetail: wifiConnected ? Session.wifiNetwork.name
        : Session.wifiStatus.busy ? I18n.tr("quick.connecting")
        : !Session.wifiDevice ? I18n.tr("quick.no_adapter")
        : !Session.wifiObservation.hardwareEnabled ? I18n.tr("quick.hardware_locked")
        : !Session.wifiEnabled ? I18n.tr("common.disabled") : I18n.tr("quick.no_connection")
    readonly property string wifiNote: ""
    readonly property string bluetoothDetail: !Session.bluetoothAdapter ? I18n.tr("quick.no_adapter")
        : !Session.bluetoothEnabled ? I18n.tr("common.disabled")
        : Session.connectedBluetooth.length ? Session.connectedBluetooth[0].name : I18n.tr("quick.no_bluetooth_connections")
    readonly property string bluetoothNote: Session.connectedBluetooth.length > 1 ? I18n.trWith("quick.bluetooth_connected_count", {count: Session.connectedBluetooth.length})
        : ""
    signal pageRequested(string page)
    spacing: 8
    Item {
        Layout.fillWidth: true; Layout.preferredHeight: 34
        MountainRidge { anchors.right: parent.right; anchors.bottom: parent.bottom; width: parent.width * 0.47; height: 27; opacity: 0.42 }
        RowLayout {
            anchors.fill: parent; spacing: 10
            GemMark { Layout.preferredWidth: 22; Layout.preferredHeight: 26 }
            Text { Layout.fillWidth: true; text: I18n.tr("quick.quick_access"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 15; elide: Text.ElideRight }
        }
    }
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Glass.tint(Session.accent, 0.22) }
    RowLayout {
        Layout.fillWidth: true; spacing: 10; uniformCellSizes: true
        QuickSwitchTile {
            Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 1
            title: "Wi-Fi"; symbol: "wifi"; active: Session.wifiEnabled; details: true
            subtitle: root.wifiDetail
            statusKind: Session.wifiStatus.kind; statusLevel: Session.wifiStatus.level
            statusBusy: Session.wifiStatus.busy; statusWarning: Session.wifiStatus.warning
            enabled: !!Session.wifiDevice && Session.wifiObservation.hardwareEnabled && !Desktop.changingSettings && !Desktop.data.airplane
            onToggled: Session.toggleWifi()
            onDetailsRequested: root.pageRequested("wifi")
        }
        QuickSwitchTile {
            Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 1
            title: "Bluetooth"; symbol: "bluetooth"; active: Session.bluetoothEnabled; details: true
            subtitle: root.bluetoothDetail
            enabled: !!Session.bluetoothAdapter && !Desktop.changingSettings && !Desktop.data.airplane
            onToggled: Session.toggleBluetooth()
            onDetailsRequested: root.pageRequested("bluetooth")
        }
    }
    ControlRow {
        id: volume
        Layout.fillWidth: true; Layout.preferredHeight: implicitHeight
        showLabel: true; label: I18n.tr("osd.volume"); symbol: Session.audio && Session.audio.muted ? "muted" : "volume"
        deviceName: Session.sink ? (Session.sink.nickname || Session.sink.description || Session.sink.name) : I18n.tr("audio.no_output_device")
        value: Session.audio ? Session.audio.volume : 0
        adjustable: !!Session.audio; muted: Session.audio ? Session.audio.muted : false
        hasMute: true; hasDetails: true
        statusKind: Session.audioStatus.kind; statusLevel: Session.audioStatus.level
        onAdjusted: value => { if (Session.audio) { Session.audio.volume = value; if (value > 0) Session.audio.muted = false; } }
        onMuteRequested: if (Session.audio) Session.audio.muted = !Session.audio.muted
        onDetailsRequested: root.pageRequested("output")
    }
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Glass.tint(Session.accent, 0.16) }
    ControlRow {
        id: brightness
        Layout.fillWidth: true; Layout.preferredHeight: implicitHeight
        property real pendingValue: value
        showLabel: true; label: I18n.tr("osd.brightness"); symbol: "sun"
        minimum: 0.05; value: Desktop.data.brightness / 100
        adjustable: Desktop.data.brightnessAvailable
        onAdjusted: value => { pendingValue = value; brightnessDebounce.restart(); }
        Timer { id: brightnessDebounce; interval: 70; onTriggered: Desktop.request("brightness", String(Math.max(5, Math.round(brightness.pendingValue * 100)))) }
    }
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Glass.tint(Session.accent, 0.22) }
    QuickSwitchTile {
        Layout.fillWidth: true
        compact: true
        title: I18n.tr("notification.dnd"); symbol: Desktop.data.dnd ? "bell-muted" : "bell"; active: Desktop.data.dnd
        enabled: Desktop.data.dndAvailable && !Desktop.changingSettings
        onToggled: Desktop.request("dnd", "")
    }
    QuickActionButton {
        Layout.fillWidth: true
        text: I18n.tr("quick.open_control_center"); symbol: "settings"
        onClicked: root.expandRequested()
    }
}
