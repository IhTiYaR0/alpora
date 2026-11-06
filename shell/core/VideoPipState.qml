pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    property bool open: false
    property string activeScreen: ""
    property string mode: "vertical" // "vertical" (9:16) or "landscape" (16:9)
    property string targetApp: "tiktok" // "tiktok", "shorts", "youtube"
    property real pipWidth: mode === "vertical" ? 360 : 540
    property real pipHeight: mode === "vertical" ? 640 : 304
    property real posX: -1
    property real posY: -1
    property real opacityLevel: 0.95
    property bool pinned: true

    readonly property var player: MusicState.player
    readonly property bool hasMedia: !!player && (player.isPlaying || (player.trackTitle && player.trackTitle.length > 0))

    Process {
        id: launcherProc
    }

    function toggle(screen: string): void {
        if (screen && screen.length > 0) activeScreen = screen;
        open = !open;
    }

    function close(): void {
        open = false;
    }

    function setMode(newMode: string): void {
        mode = newMode;
        if (mode === "vertical") {
            pipWidth = 360;
            pipHeight = 640;
        } else {
            pipWidth = 540;
            pipHeight = 304;
        }
    }

    function toggleMode(): void {
        setMode(mode === "vertical" ? "landscape" : "vertical");
    }

    function setSizePreset(preset: string): void {
        if (mode === "vertical") {
            if (preset === "S") { pipWidth = 300; pipHeight = 533; }
            else if (preset === "M") { pipWidth = 360; pipHeight = 640; }
            else if (preset === "L") { pipWidth = 420; pipHeight = 746; }
        } else {
            if (preset === "S") { pipWidth = 400; pipHeight = 225; }
            else if (preset === "M") { pipWidth = 540; pipHeight = 304; }
            else if (preset === "L") { pipWidth = 720; pipHeight = 405; }
        }
    }

    function openApp(app: string): void {
        targetApp = app;
        if (app === "tiktok" || app === "shorts") {
            setMode("vertical");
        } else if (app === "youtube") {
            setMode("landscape");
        }
    }

    function launchFloatingWindow(): void {
        launcherProc.command = [
            Session.controller,
            "pip",
            targetApp,
            "--mode",
            mode,
            "--width",
            Math.round(pipWidth).toString(),
            "--height",
            Math.round(pipHeight).toString()
        ];
        launcherProc.running = true;
    }
}

