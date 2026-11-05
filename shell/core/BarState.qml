pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Singleton {
    id: root
    // Publish destination and screen together: panels never see half a switch.
    property var selection: ({name: "", screen: ""})
    readonly property string popup: selection.name === "quick-settings" ? "" : selection.name
    readonly property string popupScreen: selection.screen
    readonly property bool quickPreview: selection.name === "quick-settings" && !!selection.preview
    function beginPreview(name: string, screenName: string): bool {
        if (!Quickshell.screens.some(s => s.name === screenName)
            || (selection.name && !selection.preview)
            || (selection.name === name && selection.screen === screenName)) return false;
        // A new hovered button takes ownership immediately. Waiting for the
        // previous preview to close loses the new button's single enter event.
        root.selection = {name: name, screen: screenName, preview: true};
        return true;
    }
    function previewQuick(screenName: string): void {
        if (beginPreview("quick-settings", screenName)) {
            Desktop.request("status", "");
        }
    }
    function expandQuick(): void {
        if (selection.name === "quick-settings")
            root.selection = {name: "quick-settings", screen: selection.screen, preview: false};
    }
    readonly property bool notificationPreview: selection.name === "notifications" && !!selection.preview
    function previewNotifications(screenName: string): void {
        if (beginPreview("notifications", screenName)) {
            refreshNotifications();
        }
    }
    function expandNotifications(): void {
        if (selection.name === "notifications")
            root.selection = {name: "notifications", screen: selection.screen, preview: false};
    }
    function previewClipboard(screenName: string): void {
        beginPreview("clipboard", screenName);
    }
    function expandClipboard(): void {
        if (selection.name === "clipboard")
            root.selection = {name: "clipboard", screen: selection.screen, preview: false};
    }
    function previewCenter(screenName: string): void {
        if (beginPreview("calendar", screenName)) {
            DayState.request("get", {});
        }
    }
    function expandCenter(): void {
        if (selection.name === "calendar")
            root.selection = {name: "calendar", screen: selection.screen, preview: false};
    }
    function previewLauncher(screenName: string): void {
        beginPreview("launcher", screenName);
    }
    function expandLauncher(): void {
        if (selection.name === "launcher")
            root.selection = Object.assign({}, selection, {preview: false});
    }
    function toggleDockLauncher(screenName: string, anchor: var, sourceWindow: var): void {
        if (!Quickshell.screens.some(s => s.name === screenName)) return;
        const same = selection.name === "launcher" && selection.screen === screenName && selection.origin === "dock";
        root.selection = same ? {name: "", screen: ""}
            : {name: "launcher", screen: screenName, preview: false, origin: "dock", anchor: anchor, sourceWindow: sourceWindow};
    }
    property int centerPage: 0
    property string layout: "—"
    property string keyboardName: ""
    property var notifications: []
    property var history: []
    property string notificationReadError: ""
    property string notificationActionError: ""
    readonly property string notificationError: notificationActionError || notificationReadError
    property string notificationOwner: ""
    property bool dnd: false
    property var hiddenHistory: []
    readonly property var visibleHistory: history.filter((item, index, all) => !notifications.some(active => active.id === item.id) && !hiddenHistory.includes(notificationKey(item)) && all.findIndex(other => other.id === item.id) === index)
    readonly property bool notificationBusy: notificationWriter.running
    function notificationKey(item: var): string { return JSON.stringify([notificationOwner, item.id, item.app_name, item.summary, item.body]); }
    function hideHistory(): void {
        hiddenHistory = hiddenHistory.concat(visibleHistory.map(item => notificationKey(item))).slice(-500);
        historyPreferences.setText(JSON.stringify({ hidden: hiddenHistory }));
    }
    function dismissNotification(id: int): void {
        if (!notificationWriter.running && notifications.some(item => item.id === id)) {
            notificationWriter.command = ["makoctl", "dismiss", "-n", String(id)];
            notificationWriter.running = true;
        }
    }
    function dismissAll(): void {
        if (!notificationWriter.running && notifications.length) {
            notificationWriter.command = ["makoctl", "dismiss", "--all"];
            notificationWriter.running = true;
        }
    }
    function invokeNotification(id: int, action: string): void {
        const item = notifications.find(item => item.id === id);
        if (!notificationWriter.running && item && item.actions && Object.prototype.hasOwnProperty.call(item.actions, action)) {
            notificationWriter.command = ["makoctl", "invoke", "-n", String(id), action];
            notificationWriter.running = true;
        }
    }
    function toggleDnd(): void {
        if (!notificationWriter.running) {
            notificationWriter.command = ["makoctl", "mode", "-t", "do-not-disturb"];
            notificationWriter.running = true;
        }
    }
    readonly property var trayModel: SystemTray.items
    readonly property var trayItems: trayModel.values.filter(item => item && item.status !== Status.Passive)
    readonly property var inlineTray: trayItems.slice(0, 2)
    readonly property var hiddenTray: trayItems.slice(2)

    function dismiss(): void { root.selection = {name: "", screen: ""}; }
    function close(): void {
        if (selection.name !== "quick-settings") root.selection = {name: "", screen: ""};
    }
    function closeQuickSettings(): void {
        if (selection.name === "quick-settings") root.selection = {name: "", screen: ""};
    }
    function toggle(name: string, screenName: string): void {
        if (!["launcher", "calendar", "notifications", "tray", "timeline", "clipboard", "quick-settings"].includes(name)
            || !Quickshell.screens.some(s => s.name === screenName)) return;
        if (name === "launcher" && selection.name === "launcher" && selection.screen === screenName && selection.origin === "dock") {
            root.selection = {name: "launcher", screen: screenName, preview: false};
            return;
        }
        if (name === "quick-settings" && selection.screen === screenName && quickPreview) {
            expandQuick(); return;
        }
        if (name === "notifications" && selection.screen === screenName && notificationPreview) {
            expandNotifications(); return;
        }
        if (name === "calendar" && selection.screen === screenName && selection.name === name && selection.preview) {
            expandCenter(); return;
        }
        if (name === "launcher" && selection.screen === screenName && selection.name === name && selection.preview) {
            expandLauncher(); return;
        }
        const same = selection.name === name && selection.screen === screenName;
        if (same && name === "clipboard" && selection.preview) {
            expandClipboard(); return;
        }
        root.selection = same ? {name: "", screen: ""} : {name: name, screen: screenName};
        if (root.popup === "notifications") refreshNotifications();
    }
    function refreshNotifications(): void {
        if (!activeReader.running) activeReader.running = true;
        if (!historyReader.running) historyReader.running = true;
        if (!modeReader.running) modeReader.running = true;
    }
    function refreshLayout(): void { if (!keyboardReader.running) keyboardReader.running = true; }
    function nextLayout(): void {
        if (!layoutWriter.running && keyboardName.length) {
            layoutWriter.command = ["hyprctl", "switchxkblayout", keyboardName, "next"];
            layoutWriter.running = true;
        }
    }
    function screenshot(): void {
        const target = root.popupScreen || "";
        close();
        Session.closeQuickSettings();
        ScreenshotState.open(target);
    }

    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            if (root.selection.name && !Quickshell.screens.some(s => s.name === root.selection.screen))
                root.selection = {name: "", screen: ""};
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (["activelayout", "deviceadded", "deviceremoved"].includes(event.name)) layoutDebounce.restart();
        }
    }
    Timer { id: layoutDebounce; interval: 60; onTriggered: root.refreshLayout() }
    Timer { id: notificationDebounce; interval: 80; onTriggered: root.refreshNotifications() }
    Process {
        id: keyboardReader
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards || [];
                    const main = keyboards.find(keyboard => keyboard.main) || keyboards[0];
                    if (!main) { root.keyboardName = ""; root.layout = "—"; return; }
                    root.keyboardName = main.name;
                    const codes = main.layout.split(",");
                    const code = codes[main.active_layout_index] || "";
                    root.layout = code === "us" ? "EN" : code.toUpperCase();
                } catch (failure) { console.warn("Keyboard status:", String(failure)); }
            }
        }
    }
    Process { id: layoutWriter; onExited: root.refreshLayout() }
    FileView {
        id: historyPreferences
        path: (Quickshell.env("POLY_SHELL_STATE") || "").replace(/session\.json$/, "notification-history.json")
        printErrors: false
        onLoaded: {
            try { const data = JSON.parse(text()); if (Array.isArray(data.hidden)) root.hiddenHistory = data.hidden.filter(item => typeof item === "string"); }
            catch (_) { root.notificationActionError = I18n.tr("bar.error_read_history"); }
        }
        onSaveFailed: root.notificationActionError = I18n.tr("bar.error_save_history")
    }
    Process {
        id: notificationWriter
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.notificationActionError = text.trim() }
        onExited: exitCode => {
            root.notificationActionError = exitCode === 0 ? "" : I18n.tr("bar.error_notif_action");
            notificationDebounce.restart();
        }
    }
    Process {
        id: modeReader
        command: ["makoctl", "mode"]
        stdout: StdioCollector { onStreamFinished: root.dnd = text.split(/\s+/).includes("do-not-disturb") }
    }
    Process {
        id: activeReader
        command: ["makoctl", "list", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (!Array.isArray(data)) throw new Error("Invalid notification list");
                    root.notifications = data; root.notificationReadError = "";
                }
                catch (_) { root.notificationReadError = I18n.tr("bar.error_mako_read"); }
            }
        }
        onExited: exitCode => { if (exitCode !== 0) root.notificationReadError = I18n.tr("bar.mako_unavailable"); }
    }
    Process {
        id: historyReader
        command: ["makoctl", "history", "-j"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.history = JSON.parse(text); } catch (_) { root.history = []; } }
        }
    }
    // Mako emits property changes for notifications and DND. Read on events,
    // rather than spawning polling processes while the bar is idle.
    Process {
        command: ["gdbus", "monitor", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/fr/emersion/Mako"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const owner = data.match(/owned by (:[0-9]+\.[0-9]+)/);
                if (owner) root.notificationOwner = owner[1];
                if (data.includes("PropertiesChanged") || data.includes("owned by")) notificationDebounce.restart();
            }
        }
    }
    Component.onCompleted: { refreshLayout(); refreshNotifications(); }
}
