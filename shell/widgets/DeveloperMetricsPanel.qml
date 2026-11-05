pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    id: root
    required property var modelData
    readonly property var metrics: DeveloperMetricsState.data
    readonly property var cpu: metrics.cpu || ({})
    readonly property var memory: metrics.memory || ({})
    readonly property var gpu: metrics.gpu || ({})
    readonly property var network: metrics.network || ({})
    readonly property var disk: metrics.disk || ({})

    function fmt(value): string { return typeof value === "number" && isFinite(value) ? String(Math.round(value)) : "—"; }
    function percent(value): string { return typeof value === "number" && isFinite(value) ? Math.round(value) + "%" : "—"; }
    function memoryPair(used, total): string {
        if (typeof used !== "number") return I18n.tr("Unavailable")
        return DeveloperMetricsState.formatBytes(used * 1048576) + (typeof total === "number" ? " / " + DeveloperMetricsState.formatBytes(total * 1048576) : "")
    }

    PanelWindow {
        id: window
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        visible: DeveloperMetricsState.detailsOpen && DeveloperMetricsState.detailsScreen === (root.modelData ? root.modelData.name : "")
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore; exclusiveZone: 0
        WlrLayershell.namespace: "poly-developer-metrics"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        mask: Region { item: backdrop }

        Rectangle {
            id: backdrop
            anchors.fill: parent
            color: "#72000000"
            MouseArea { anchors.fill: parent; onClicked: DeveloperMetricsState.closeDetails() }
        }
        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: Math.min(parent.width - 36, 900)
            height: Math.min(parent.height - 36, 680)
            radius: 18
            color: Session.background
            border.width: 1; border.color: Glass.tint(Session.accent, 0.35)
            clip: true
            MouseArea { anchors.fill: parent; onClicked: mouse.accepted = true }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 22; spacing: 13
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    CutSurface {
                        Layout.preferredWidth: 42; Layout.preferredHeight: 42
                        edgeColor: Session.accent
                        Text { anchors.centerIn: parent; text: "DEV"; color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 12; font.weight: Font.Bold }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: I18n.tr("Developer panel"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 21; font.weight: Font.DemiBold }
                        Text { text: (root.metrics.hostname || I18n.tr("System")) + " · " + I18n.tr("Updates every 2 s"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11 }
                    }
                    Text { text: DeveloperMetricsState.busy ? I18n.tr("Refreshing…") : DeveloperMetricsState.error ? I18n.tr("Partial data") : I18n.tr("Real time"); color: DeveloperMetricsState.error ? "#E7B477" : Session.accent; font.family: Session.fontFamily; font.pixelSize: 11 }
                    ToolButton {
                        text: "×"; Accessible.name: I18n.tr("Close developer panel")
                        onClicked: DeveloperMetricsState.closeDetails()
                    }
                }
                FacetDivider { Layout.fillWidth: true }
                ScrollView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    ColumnLayout {
                        width: parent.width; spacing: 12
                        GridLayout {
                            Layout.fillWidth: true; columns: 2; columnSpacing: 12; rowSpacing: 12
                            Repeater {
                                model: [
                                    {title: I18n.tr("Processor"), value: root.percent(root.cpu.percent), detail: (root.cpu.model || "CPU") + " · " + (root.cpu.cores || 0) + " " + I18n.tr("logical threads"), percent: root.cpu.percent},
                                    {title: I18n.tr("RAM memory"), value: root.percent(root.memory.percent), detail: root.memoryPair(root.memory.used_mb, root.memory.total_mb) + " " + I18n.tr("used") + " · " + DeveloperMetricsState.formatBytes((root.memory.available_mb || 0) * 1048576) + " " + I18n.tr("available"), percent: root.memory.percent},
                                    {title: "GPU", value: root.gpu.available ? root.percent(root.gpu.utilization_percent) : I18n.tr("Not detected"), detail: root.gpu.name || I18n.tr(root.gpu.available ? "No telemetry available" : "Not detected"), percent: root.gpu.utilization_percent},
                                    {title: I18n.tr("Graphics memory"), value: root.gpu.available ? root.memoryPair(root.gpu.vram_used_mb, root.gpu.vram_total_mb) : "—", detail: root.gpu.available ? I18n.tr("VRAM used / total") : I18n.tr("Check GPU support"), percent: root.gpu.vram_total_mb > 0 ? 100 * root.gpu.vram_used_mb / root.gpu.vram_total_mb : -1},
                                    {title: I18n.tr("Network · download / upload"), value: "↓ " + DeveloperMetricsState.formatRate(DeveloperMetricsState.downloadBytesPerSecond) + "  ↑ " + DeveloperMetricsState.formatRate(DeveloperMetricsState.uploadBytesPerSecond), detail: I18n.tr("Interface: ") + (root.network.interface || I18n.tr("unknown")), percent: -1},
                                    {title: I18n.tr("Root disk · /"), value: root.disk.percent === null ? "—" : root.percent(root.disk.percent), detail: DeveloperMetricsState.formatBytes((root.disk.free_gb || 0) * 1073741824) + " " + I18n.tr("free of") + " " +DeveloperMetricsState.formatBytes((root.disk.total_gb || 0) * 1073741824), percent: root.disk.percent}
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true; Layout.preferredHeight: 106; radius: 12
                                    color: Glass.tint(Session.accent, 0.055)
                                    border.width: 1; border.color: Glass.tint(Session.accent, 0.12)
                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: 12; spacing: 5
                                        Text { text: modelData.title; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; font.weight: Font.Medium }
                                        Text { Layout.fillWidth: true; text: modelData.value; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                        Text { Layout.fillWidth: true; text: modelData.detail; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; elide: Text.ElideRight }
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.preferredHeight: 4; radius: 2; color: Glass.tint(Session.muted, 0.16); visible: typeof modelData.percent === "number" && modelData.percent >= 0
                                            Rectangle { width: parent.width * Math.max(0, Math.min(100, Number(modelData.percent) || 0)) / 100; height: parent.height; radius: 2; color: Session.accent }
                                        }
                                    }
                                }
                            }
                        }
                        Text { text: I18n.tr("Temperatures and load"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "CPU " + (typeof root.cpu.temperature_c === "number" ? root.cpu.temperature_c + " °C" : "—")
                                + "   ·   GPU " + (typeof root.gpu.temperature_c === "number" ? root.gpu.temperature_c + " °C" : "—")
                                + "   ·   " + I18n.tr("GPU power") + " " + (typeof root.gpu.power_w === "number" ? root.gpu.power_w + " W" : "—")
                                + "   ·   " + I18n.tr("Load average") + " " + (typeof root.cpu.load1 === "number" ? root.cpu.load1.toFixed(2) : "—") + " / " + (typeof root.cpu.load5 === "number" ? root.cpu.load5.toFixed(2) : "—") + " / " + (typeof root.cpu.load15 === "number" ? root.cpu.load15.toFixed(2) : "—")
                            color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text { text: I18n.tr("Processes · top CPU"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold }
                                Repeater {
                                    model: root.metrics.processes_cpu || []
                                    delegate: RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true; spacing: 8
                                        Text { Layout.preferredWidth: 44; text: String(modelData.pid); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10 }
                                        Text { Layout.fillWidth: true; text: modelData.name; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 10; elide: Text.ElideRight }
                                        Text { text: modelData.cpu_percent.toFixed(1) + "%"; color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 10 }
                                    }
                                }
                            }
                            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Glass.tint(Session.accent, 0.16) }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text { text: I18n.tr("Processes · top RAM"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold }
                                Repeater {
                                    model: root.metrics.processes_memory || []
                                    delegate: RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true; spacing: 8
                                        Text { Layout.preferredWidth: 44; text: String(modelData.pid); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10 }
                                        Text { Layout.fillWidth: true; text: modelData.name; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 10; elide: Text.ElideRight }
                                        Text { text: modelData.memory_percent.toFixed(1) + "%"; color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 10 }
                                    }
                                }
                            }
                        }
                        Text { text: I18n.tr("Uptime: ") + DeveloperMetricsState.formatUptime(root.metrics.uptime_seconds || 0) + (DeveloperMetricsState.error ? " · " + I18n.trStatus(DeveloperMetricsState.error) : ""); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; wrapMode: Text.Wrap }
                    }
                }
            }
        }
        Shortcut { sequence: "Escape"; enabled: window.visible; context: Qt.ApplicationShortcut; onActivated: DeveloperMetricsState.closeDetails() }
    }
}
