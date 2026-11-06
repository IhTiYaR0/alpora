pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    property bool opened: false
    property string screenName: ""
    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property bool ready: false

    readonly property bool isToggle: ["capslock", "numlock", "airplane"].includes(kind)
    readonly property string title: kind === "brightness" ? I18n.tr("osd.brightness")
        : kind === "microphone" ? I18n.tr("osd.microphone")
        : kind === "capslock" ? "Caps Lock"
        : kind === "numlock" ? "Num Lock"
        : kind === "airplane" ? I18n.tr("quick.airplane_mode")
        : I18n.tr("osd.volume")

    readonly property string symbol: kind === "brightness" ? "sun"
        : kind === "microphone" ? (muted ? "microphone-muted" : "microphone")
        : kind === "capslock" || kind === "numlock" ? "keyboard"
        : kind === "airplane" ? "airplane"
        : (muted ? "muted" : "volume")

    function show(next: string, amount: real, silenced: bool): void {
        if (!["volume", "microphone", "brightness", "capslock", "numlock", "airplane"].includes(next) || !isFinite(amount)) return;
        const monitor = Hyprland.focusedMonitor;
        screenName = monitor ? monitor.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "");
        kind = next;
        value = Math.max(0, amount);
        muted = silenced;
        opened = true;
        expiry.restart();
    }

    function showToggle(toggleKind: string, state: bool): void {
        const monitor = Hyprland.focusedMonitor;
        screenName = monitor ? monitor.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "");
        kind = toggleKind;
        value = state ? 1.0 : 0.0;
        muted = !state;
        opened = true;
        expiry.restart();
    }

    Timer { id: expiry; interval: 1500; onTriggered: root.opened = false }

    Timer {
        id: startupGuard
        interval: 1800
        running: true
        onTriggered: root.ready = true
    }

    // Auto-listen to audio changes
    readonly property real currentVolume: Session.sink && Session.sink.audio ? Session.sink.audio.volume : 0
    readonly property bool currentMuted: Session.sink && Session.sink.audio ? Session.sink.audio.muted : false
    readonly property bool currentMicMuted: Session.microphone ? Session.microphone.muted : false
    readonly property real currentBrightness: Desktop.data.brightness

    onCurrentVolumeChanged: {
        if (ready && Session.sink && Session.sink.audio)
            show("volume", currentVolume, currentMuted);
    }
    onCurrentMutedChanged: {
        if (ready && Session.sink && Session.sink.audio)
            show("volume", currentVolume, currentMuted);
    }
    onCurrentMicMutedChanged: {
        if (ready && Session.microphone)
            show("microphone", 1.0, currentMicMuted);
    }
    onCurrentBrightnessChanged: {
        if (ready && Desktop.data.brightnessAvailable)
            show("brightness", currentBrightness / 100, false);
    }
}
