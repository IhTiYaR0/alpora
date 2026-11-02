pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    property var data: ({
        sampled_at: 0, hostname: "", uptime_seconds: 0,
        cpu: {percent: null, model: "", cores: 0, temperature_c: null, load1: null, load5: null, load15: null},
        memory: {total_mb: 0, used_mb: 0, available_mb: 0, percent: null, swap_total_mb: 0, swap_used_mb: 0, swap_percent: 0},
        gpu: {available: false, name: "", utilization_percent: null, vram_used_mb: null, vram_total_mb: null, temperature_c: null, power_w: null},
        network: {interface: null, rx_bytes: 0, tx_bytes: 0},
        disk: {mount: "/", total_gb: null, used_gb: null, free_gb: null, percent: null},
        processes_cpu: [], processes_memory: []
    })
    property string error: ""
    property bool detailsOpen: false
    property string detailsScreen: ""
    property real downloadBytesPerSecond: 0
    property real uploadBytesPerSecond: 0
    property real previousRxBytes: -1
    property real previousTxBytes: -1
    property double previousSampleMs: 0
    property bool busy: false
    readonly property bool active: detailsOpen || (WidgetState.loaded && !!WidgetState.values.developer && WidgetState.values.developer.enabled)

    function openDetails(screenName: string): void {
        detailsScreen = screenName || (Quickshell.screens.length ? Quickshell.screens[0].name : "")
        detailsOpen = true
        refresh()
    }
    function closeDetails(): void { detailsOpen = false; detailsScreen = ""; }
    function refresh(): void {
        if (!active || busy) return;
        busy = true;
        IpcClient.send("widgets", ["metrics"], (res, err) => {
            busy = false;
            if (err) {
                root.error = err.replace(/^poly-shell:\s*/, "");
            } else if (res) {
                if (typeof res === "object") {
                    acceptSnapshotObj(res);
                } else if (typeof res === "string") {
                    acceptSnapshot(res);
                }
            }
        });
    }
    function formatBytes(value: real): string {
        if (!isFinite(value) || value < 0) return "—"
        if (value >= 1073741824) return (value / 1073741824).toFixed(1) + " GB"
        if (value >= 1048576) return (value / 1048576).toFixed(1) + " MB"
        if (value >= 1024) return (value / 1024).toFixed(0) + " KB"
        return Math.round(value) + " B"
    }
    function formatRate(value: real): string {
        if (!isFinite(value) || value < 0) return "—"
        if (value >= 1048576) return (value / 1048576).toFixed(1) + " MB/s"
        if (value >= 1024) return (value / 1024).toFixed(value >= 10240 ? 0 : 1) + " KB/s"
        return Math.round(value) + " B/s"
    }
    function formatUptime(value: real): string {
        const total = Math.max(0, Math.floor(value || 0))
        const days = Math.floor(total / 86400)
        const hours = Math.floor((total % 86400) / 3600)
        const mins = Math.floor((total % 3600) / 60)
        return days > 0 ? days + " d " + hours + " h" : hours + " h " + mins + " min"
    }
    function acceptSnapshot(text: string): void {
        try {
            const next = JSON.parse(text);
            acceptSnapshotObj(next);
        } catch (_) { error = I18n.tr("Could not read system metrics"); }
    }
    function acceptSnapshotObj(next: var): void {
        if (!next || typeof next !== "object") return;
        const now = Date.now()
        const net = next.network || {}
        const dt = previousSampleMs > 0 ? (now - previousSampleMs) / 1000 : 0
        if (dt > 0 && previousRxBytes >= 0 && previousTxBytes >= 0) {
            downloadBytesPerSecond = Math.max(0, (Number(net.rx_bytes || 0) - previousRxBytes) / dt)
            uploadBytesPerSecond = Math.max(0, (Number(net.tx_bytes || 0) - previousTxBytes) / dt)
        } else {
            downloadBytesPerSecond = 0; uploadBytesPerSecond = 0
        }
        previousRxBytes = Number(net.rx_bytes || 0)
        previousTxBytes = Number(net.tx_bytes || 0)
        previousSampleMs = now
        data = next
        error = ""
    }

    Timer { interval: root.detailsOpen ? 1500 : 4000; repeat: true; running: root.active; onTriggered: root.refresh() }

    IpcHandler {
        target: "developer-metrics"
        function status(): string { return JSON.stringify({active: root.active, busy: root.busy, detailsOpen: root.detailsOpen, downloadBytesPerSecond: root.downloadBytesPerSecond, uploadBytesPerSecond: root.uploadBytesPerSecond, error: root.error, data: root.data}); }
        function refresh(): void { root.refresh(); }
        function openDetails(): void { root.openDetails(Quickshell.screens.length ? Quickshell.screens[0].name : ""); }
        function closeDetails(): void { root.closeDetails(); }
    }
    Component.onCompleted: Qt.callLater(root.refresh)
}
