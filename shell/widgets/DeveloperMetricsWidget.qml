pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts

DesktopWidgetCard {
    id: root
    implicitWidth: 410; implicitHeight: 206
    property string screenName: ""
    readonly property var metrics: DeveloperMetricsState.data
    readonly property var cpu: metrics.cpu || ({})
    readonly property var memory: metrics.memory || ({})
    readonly property var gpu: metrics.gpu || ({})
    readonly property bool living: animate && !ClockState.sleeping

    function number(value): string { return typeof value === "number" && isFinite(value) ? String(Math.round(value)) : "—"; }
    function percent(value): string { return typeof value === "number" && isFinite(value) ? Math.round(value) + "%" : "—"; }
    function ramUsed(): string { return memory.used_mb === undefined ? "—" : DeveloperMetricsState.formatBytes(memory.used_mb * 1048576) + " / " + DeveloperMetricsState.formatBytes(memory.total_mb * 1048576); }
    function vramUsed(): string { return gpu.available && typeof gpu.vram_used_mb === "number" ? DeveloperMetricsState.formatBytes(gpu.vram_used_mb * 1048576) + (typeof gpu.vram_total_mb === "number" ? " / " + DeveloperMetricsState.formatBytes(gpu.vram_total_mb * 1048576) : "") : I18n.tr("Unavailable"); }
    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: DeveloperMetricsState.openDetails(root.screenName) }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 15; spacing: 8
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Rectangle {
                Layout.preferredWidth: 31; Layout.preferredHeight: 31; radius: 9
                color: Glass.tint(Session.accent, 0.16)
                Text { anchors.centerIn: parent; text: "DEV"; color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 10; font.weight: Font.Bold }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text { text: I18n.tr("Developer panel"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold }
                Text { text: root.metrics.hostname || I18n.tr("System metrics"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; elide: Text.ElideRight }
            }
            Rectangle { radius: 7; color: Glass.tint(Session.accent, 0.1); implicitWidth: 42; implicitHeight: 22
                Text { anchors.centerIn: parent; text: DeveloperMetricsState.busy ? "…" : root.metrics.sampled_at ? "LIVE" : "—"; color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 9; font.weight: Font.Bold }
            }
        }
        GridLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; columnSpacing: 14; rowSpacing: 8
            Repeater {
                model: [
                    {label: "CPU", value: root.percent(root.cpu.percent), detail: (root.cpu.temperature_c === null || root.cpu.temperature_c === undefined ? I18n.tr("Temperature") + " —" : I18n.tr("Temp. ") + root.number(root.cpu.temperature_c) + " °C"), percent: root.cpu.percent},
                    {label: "RAM", value: root.percent(root.memory.percent), detail: root.ramUsed(), percent: root.memory.percent},
                    {label: "GPU", value: root.gpu.available ? root.percent(root.gpu.utilization_percent) : I18n.tr("Not detected"), detail: root.vramUsed(), percent: root.gpu.utilization_percent},
                    {label: "NET", value: "↓ " + DeveloperMetricsState.formatRate(DeveloperMetricsState.downloadBytesPerSecond), detail: "↑ " + DeveloperMetricsState.formatRate(DeveloperMetricsState.uploadBytesPerSecond), percent: -1}
                ]
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 3
                    RowLayout {
                        Layout.fillWidth: true; spacing: 5
                        Text { text: modelData.label; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 9; font.weight: Font.DemiBold }
                        Item { Layout.fillWidth: true }
                        Text { text: modelData.value; color: Session.foreground; font.family: Session.monoFontFamily || Session.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 4; radius: 2; color: Glass.tint(Session.muted, 0.16); visible: typeof modelData.percent === "number" && modelData.percent >= 0
                        Rectangle { width: parent.width * Math.max(0, Math.min(100, Number(modelData.percent) || 0)) / 100; height: parent.height; radius: 2; color: modelData.label === "GPU" ? "#9CC8DF" : Session.accent }
                    }
                    Text { Layout.fillWidth: true; text: modelData.detail; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 9; elide: Text.ElideRight }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 5
            Text { Layout.fillWidth: true; text: I18n.tr("Load ") + (typeof root.cpu.load1 === "number" ? root.cpu.load1.toFixed(2) : "—") + "  ·  " + I18n.tr("Uptime ") + DeveloperMetricsState.formatUptime(root.metrics.uptime_seconds || 0); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 9; elide: Text.ElideRight }
            Text { text: I18n.tr("View details") + "  ↗"; color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 9; font.weight: Font.Medium }
        }
    }
}
