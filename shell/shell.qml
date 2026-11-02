//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QSG_USE_SIMPLE_ANIMATION_DRIVER=1
//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root
    // Shared shell state and IPC endpoints live in this root.
    function focusedScreen(): string {
        const monitor = Hyprland.focusedMonitor;
        return monitor ? monitor.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "");
    }

    function markReady(): void {
        if (Session.loaded && readiness.path.length > 0) {
            readiness.setText("ready\n");
            console.info("Poly Shell ready; mode:", Session.mode, "screens:", Quickshell.screens.length);
        }
    }

    Variants {
        model: Quickshell.screens
        TopBar {}
    }
    Variants { model: Quickshell.screens; Osd {} }
    Variants { model: Quickshell.screens; DesktopThemeMenu {} }
    Variants { model: Quickshell.screens; LivingLandscape {} }
    Variants { model: Quickshell.screens; DesktopWidgets {} }
    Variants { model: Quickshell.screens; DeveloperMetricsPanel {} }
    Variants { model: Quickshell.screens; TimelineWallpaper {} }
    Variants { model: Quickshell.screens; WorkspaceOverview {} }
    Variants { model: Quickshell.screens; Dock {} }
    Variants { model: Quickshell.screens; ScreenshotOverlay {} }
    Variants { model: Quickshell.screens; PowerMenu {} }
    Variants { model: Quickshell.screens; DisplayProjectMenu {} }
    Variants { model: Quickshell.screens; BrightnessOverlay {} }
    Variants { model: Quickshell.screens; VideoPipOverlay {} }

    // Native Wayland shortcuts avoid spawning an IPC client before input can
    // reach the launcher. Keep registration once per shell, not per monitor.
    NativeShortcut {
        appid: "poly-shell"; name: "power-menu"; description: I18n.tr("power.title")
        onActivated: PowerState.toggle(root.focusedScreen())
    }
    NativeShortcut {
        appid: "poly-shell"; name: "screenshot"; description: I18n.tr("quick.screenshot")
        onActivated: ScreenshotState.open(root.focusedScreen())
    }
    NativeShortcut {
        appid: "poly-shell"; name: "overview"; description: I18n.tr("shortcut.overview")
        onActivated: OverviewState.toggle(root.focusedScreen())
    }
    NativeShortcut {
        appid: "poly-shell"; name: "overview-open"; description: I18n.tr("shortcut.overview_open")
        onActivated: OverviewState.open(root.focusedScreen())
    }
    NativeShortcut {
        appid: "poly-shell"; name: "overview-close"; description: I18n.tr("shortcut.overview_close")
        onActivated: OverviewState.close()
    }
    NativeShortcut {
        appid: "poly-shell"; name: "launcher"; description: I18n.tr("shortcut.launcher")
        onActivated: BarState.toggle("launcher", root.focusedScreen())
    }
    NativeShortcut {
        appid: "poly-shell"; name: "quick-settings"; description: I18n.tr("shortcut.quick_settings")
        onActivated: Session.toggleQuickSettings(root.focusedScreen())
    }
    NativeShortcut {
        appid: "poly-shell"; name: "notifications"; description: I18n.tr("shortcut.notifications")
        onActivated: BarState.toggle("notifications", root.focusedScreen())
    }

    NativeShortcut {
        appid: "poly-shell"; name: "clipboard"; description: I18n.tr("shortcut.clipboard")
        onActivated: BarState.toggle("clipboard", root.focusedScreen())
    }

    NativeShortcut {
        appid: "poly-shell"; name: "toggle-mode"; description: I18n.tr("shortcut.toggle_mode")
        onActivated: Session.setMode("toggle")
    }

    NativeShortcut {
        appid: "poly-shell"; name: "display-project"; description: I18n.tr("display_project.title")
        onActivated: DisplayProjectState.toggle(root.focusedScreen())
    }
    NativeShortcut {
        appid: "poly-shell"; name: "video-pip"; description: "Video PiP (TikTok / Shorts / YouTube)"
        onActivated: VideoPipState.toggle(root.focusedScreen())
    }

    FileView {
        id: readiness
        path: Quickshell.env("POLY_SHELL_READY") || ""
        preload: false
        printErrors: false
        onSaveFailed: console.error("Cannot write readiness marker", path)
    }

    Connections {
        target: ClockState
        function onPreparingForSleep(): void {
            // Drop temporary blur/input surfaces before the compositor suspends.
            // PanelMotion snaps shut while sleeping, avoiding stale animations.
            BarState.close();
            Session.closeQuickSettings();
        }
    }

    Connections {
        target: Session
        function onLoadedChanged(): void {
            if (Session.loaded)
                Qt.callLater(root.markReady);
        }
    }

    IpcHandler {
        target: "shell"
        function status(): string {
            return JSON.stringify({ ready: Session.loaded, mode: Session.mode, screens: Quickshell.screens.length, workspace: Session.focusedWorkspace, quickSettings: Session.quickSettingsOpen, day: { loaded: DayState.loaded, error: DayState.error, events: DayState.data.events.length, tasks: DayState.data.tasks.length, remaining: DayState.remaining, running: DayState.running }, music: { players: MusicState.players.length, active: MusicState.player ? MusicState.player.dbusName : "", playing: !!MusicState.player && MusicState.player.isPlaying }, bar: { centerPage: BarState.centerPage, popup: BarState.popup, layout: BarState.layout, keyboard: BarState.keyboardName, trayItems: BarState.trayItems.length, hiddenTray: BarState.hiddenTray.length, notifications: BarState.notifications.length, history: BarState.history.length, notificationError: BarState.notificationError }, battery: { present: Session.batteryPresent, charging: Session.batteryCharging, onBattery: Session.onBattery, percentage: Session.battery ? Session.battery.percentage : null, description: Session.batteryDescription }, error: Session.error, desktopError: Desktop.error, desktop: Desktop.data, wifi: Session.wifiEnabled, bluetooth: Session.bluetoothEnabled, bluetoothAvailable: !!Session.bluetoothAdapter, audio: { volume: Session.audio ? Session.audio.volume : null, muted: Session.audio ? Session.audio.muted : null, microphone: Session.microphone ? Session.microphone.volume : null, microphoneMuted: Session.microphone ? Session.microphone.muted : null, outputs: Session.outputs.length, inputs: Session.inputs.length } });
        }
        function setMode(mode: string): void { Session.setMode(mode); }
        function toggleMode(): void { Session.setMode("toggle"); }
        function focusWorkspace(workspace: int): void { Session.focusWorkspace(workspace); }
        function toggleQuickSettings(): void { Session.toggleQuickSettings(root.focusedScreen()); }
        function toggleLauncher(): void {
            const monitor = Hyprland.focusedMonitor;
            const screen = monitor ? monitor.name : Quickshell.screens[0].name;
            BarState.toggle("launcher", screen);
        }
        function launcherStatus(): string {
            return JSON.stringify({ open: BarState.popup === "launcher", screen: BarState.popupScreen, count: AppCatalog.entries.length, cachedIcons: Object.keys(AppCatalog.iconFiles).length, favorites: AppCatalog.pinnedIds, error: AppCatalog.error });
        }
        function launcherSearch(query: string): string {
            return JSON.stringify(AppCatalog.results(query, "").map(entry => ({ id: entry.id, name: entry.name })));
        }
        function closeQuickSettings(): void { Session.closeQuickSettings(); }
        function toggleBarPanel(page: string): void {
            if (["launcher", "calendar", "notifications", "tray", "timeline", "clipboard"].includes(page)) BarState.toggle(page, root.focusedScreen());
        }
        function closeBarPanel(): void { BarState.close(); }
        function setCenterPage(page: int): void { if (page >= 0 && page <= 1) BarState.centerPage = page; }
        function desktopAction(action: string, value: string): void { Desktop.request(action, value); }
        function showOsd(kind: string, value: real, muted: bool): void { OsdState.show(kind, value, muted); }
        function showToggleOsd(kind: string, state: bool): void { OsdState.showToggle(kind, state); }
        function osdStatus(): string { return JSON.stringify({ opened: OsdState.opened, kind: OsdState.kind, value: OsdState.value, muted: OsdState.muted, screen: OsdState.screenName }); }
        function notificationsStatus(): string { return JSON.stringify({ active: BarState.notifications.map(item => item.id), history: BarState.visibleHistory.map(item => item.id), dnd: BarState.dnd, busy: BarState.notificationBusy, error: BarState.notificationError }); }
        function dismissNotification(id: int): void { BarState.dismissNotification(id); }
        function invokeNotification(id: int, action: string): void { BarState.invokeNotification(id, action); }
        function toggleDnd(): void { BarState.toggleDnd(); }
        function startFrameProbe(): void { FrameMetrics.start(); }
        function stopFrameProbe(): string { return FrameMetrics.finish(); }
        function screenshot(): void { ScreenshotState.open(root.focusedScreen()); }
        function powerMenu(): void { PowerState.toggle(root.focusedScreen()); }
        function toggleOverview(): void { OverviewState.toggle(root.focusedScreen()); }
        function toggleDisplayProject(): void { DisplayProjectState.toggle(root.focusedScreen()); }
    }


    Component.onCompleted: Qt.callLater(root.markReady)
}
