pragma Singleton
import QtQuick
import ".."
import Quickshell

Singleton {
    id: root

    readonly property bool enabled: Session.settings.audioFeedback !== false
    readonly property string assetsDir: Quickshell.env("POLY_SHELL_ASSETS") || ""
    readonly property string soundPath: (assetsDir.length ? assetsDir : "/usr/share/poly-shell/assets") + "/sounds/tock.wav"

    function playTock(): void {
        if (!enabled || !soundPath.length) return;
        IpcClient.exec([
            "sh", "-c",
            "pw-play --volume 0.7 \"$1\" 2>/dev/null || paplay --volume=45000 \"$1\" 2>/dev/null || aplay -q \"$1\" 2>/dev/null",
            "sh", soundPath
        ]);
    }
}
