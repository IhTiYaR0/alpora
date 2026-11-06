//@ pragma AppId poly-shell-settings
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QSG_USE_SIMPLE_ANIMATION_DRIVER=1
//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import QtQuick
import "theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root
    property bool confirmClose: false
    property bool restoringWindow: false
    property string page: "overview"
    property string statusMessage: ""
    property var monitors: []
    property string wallpaperPath: Quickshell.env("POLY_SHELL_ASSETS") + "/wallpapers/alpine-dawn.png"
    readonly property url wallpaperUrl: "file://" + encodeURI(wallpaperPath).replace(/#/g, "%23").replace(/\?/g, "%3F")
    readonly property var navigation: [
        {group: I18n.tr("settings.group_main"), key: "overview", title: I18n.tr("settings.overview"), icon: "home", words: "general mode theme"},
        {group: "", key: "wifi", title: "Wi-Fi", icon: "wifi", words: "wifi internet network"},
        {group: "", key: "bluetooth", title: "Bluetooth", icon: "bluetooth", words: "bluetooth headphones"},
        {group: I18n.tr("settings.group_desktop"), key: "monitors", title: I18n.tr("settings.monitors"), icon: "monitor", words: "monitors screen resolution scale brightness"},
        {group: "", key: "wallpaper", title: I18n.tr("settings.themes_wallpaper"), icon: "wallpaper", words: "wallpaper background palette theme colors"},
        {group: "", key: "appearance", title: I18n.tr("settings.appearance"), icon: "palette", words: "appearance theme radius transparency blur"},
        {group: "", key: "widgets", title: I18n.tr("settings.widgets"), icon: "devices", words: "widgets clock weather music desktop companion gran"},
        {group: "", key: "panel", title: I18n.tr("settings.panel_menus"), icon: "panel", words: "panel bar menu"},
        {group: I18n.tr("settings.group_system"), key: "sound", title: I18n.tr("settings.sound"), icon: "volume", words: "sound volume microphone speakers audio"},
        {group: "", key: "power", title: I18n.tr("settings.power"), icon: "battery", words: "power battery energy profiles"},
        {group: "", key: "notifications", title: I18n.tr("settings.notifications"), icon: "bell", words: "notifications dnd alerts"},
        {group: "", key: "input", title: I18n.tr("shortcuts.title"), icon: "terminal", words: "keyboard shortcuts hotkeys bindings input"},
        {group: "", key: "touchpad", title: I18n.tr("settings.touchpad"), icon: "mouse", words: "touchpad pointer gestures tap speed sensitivity"},
        {group: "", key: "language", title: I18n.tr("settings.language"), icon: "globe", words: "language locale vietnamese english tieng viet ngon ngu"}
    ]
    readonly property string pageTitle: page === "modes" ? I18n.tr("settings.operating_mode") : page === "devices" ? I18n.tr("settings.devices") : (navigation.find(n => n.key === page) || {}).title || I18n.tr("settings.title")
    function navigate(next: string): void { if (root.page === "input" && next !== "input" && ShortcutsState.editingForm) {root.statusMessage=I18n.tr("settings.finish_editing_hint");return;} root.statusMessage=""; root.page = next; search.text = ""; root.statusMessage = ""; }
    function close(): void {
        if (AppearanceState.dirty || ThemeState.dirty || WidgetState.dirty || ShortcutsState.dirty || ShortcutsState.editingForm) {
            root.confirmClose = true;
        } else {
            settingsWindow.visible = false;
            settingsWindow.close();
            Qt.quit();
        }
    }
    function restoreWindow(): void {
        if (!Hyprland.usingLua || root.restoringWindow) return;
        root.restoringWindow = true;
        geometryRestore.restart();
    }
    Timer {
        id: geometryRestore
        interval: 0
        onTriggered: {
            Hyprland.dispatch('hl.dsp.window.fullscreen_state({window="class:^poly-shell-settings$",action="set",internal=0,client=0})');
            Hyprland.dispatch('hl.dsp.window.float({window="class:^poly-shell-settings$",action="set"})');
            Hyprland.dispatch('hl.dsp.window.resize({window="class:^poly-shell-settings$",x=1100,y=800,relative=false})');
            settingsWindow.maximized = false;
            settingsWindow.fullscreen = false;
            geometryCooldown.restart();
        }
    }
    Timer {
        id: geometryCooldown; interval: 200
        onTriggered: {
            root.restoringWindow = false;
            if (settingsWindow.maximized || settingsWindow.fullscreen) root.restoreWindow();
        }
    }
    function show(): void {
        settingsWindow.visible = true;
        settingsWindow.minimized = false;
        root.restoreWindow();
        Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.focus({ window = "class:^poly-shell-settings$" })' : 'focuswindow class:^poly-shell-settings$');
    }
    function setWallpaper(path: string): void {
        if (wallpaperWriter.running) return;
        root.statusMessage = I18n.tr("theme.applying");
        wallpaperWriter.command = [Session.controller, "wallpaper", path];
        wallpaperWriter.running = true;
    }
    IpcHandler {
        target: "settings-app"
        function raiseWindow(): void { root.show(); }
        function close(): void { root.close(); }
        function navigate(page: string): void { if (root.navigation.some(n => n.key === page) || ["modes", "devices"].includes(page)) root.navigate(page); }
        function status(): string { return JSON.stringify({page: root.page, monitors: root.monitors.length, message: root.statusMessage}); }
    }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/poly-shell/wallpaper.json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { const saved = JSON.parse(text()); if (typeof saved.image === "string") root.wallpaperPath = saved.image; } catch (_) {} }
    }
    Process {
        id: monitorReader
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector { onStreamFinished: { try { root.monitors = JSON.parse(text); } catch (_) { root.statusMessage = I18n.tr("settings.error_read_monitors"); } } }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event): void { if (["monitoradded", "monitoraddedv2", "monitorremoved", "configreloaded"].includes(event.name)) monitorRefresh.restart(); }
    }
    Timer { id: monitorRefresh; interval: 150; onTriggered: if (!monitorReader.running) monitorReader.running = true }
    Timer { interval: 5000; repeat: true; running: settingsWindow.visible && !settingsWindow.minimized; onTriggered: Desktop.request("status", "") }
    Process {
        id: wallpaperWriter
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.statusMessage = text.trim().replace(/^poly-shell: /, "") }
        onExited: exitCode => { if (exitCode === 0) root.statusMessage = I18n.tr("theme.wallpaper_saved"); else if (root.statusMessage === I18n.tr("theme.applying")) root.statusMessage = I18n.tr("theme.error_apply_wallpaper"); }
    }
    FileDialog {
        id: wallpaperDialog
        parentWindow: settingsWindow.contentItem.Window.window
        title: I18n.tr("theme.choose_wallpaper")
        nameFilters: [I18n.tr("theme.image_filter")]
        onAccepted: ThemeState.importImage(decodeURIComponent(String(selectedFile).replace(/^file:\/\//, "")))
    }
    Component.onCompleted: { monitorReader.running = true; Desktop.request("status", ""); }
    // qmllint disable uncreatable-type
    FloatingWindow {
        // qmllint enable uncreatable-type
        id: settingsWindow
        title: I18n.tr("settings.window_title")
        implicitWidth: 1100; implicitHeight: 800
        minimumSize: Qt.size(1100, 800); maximumSize: Qt.size(1100, 800)
        color: "transparent"; visible: true
        maximized: false; fullscreen: false
        onMaximizedChanged: if (maximized) root.restoreWindow()
        onFullscreenChanged: if (fullscreen) root.restoreWindow()
        onClosed: {
            if (AppearanceState.busy || ThemeState.busy || WidgetState.busy || ShortcutsState.busy || AppearanceState.dirty || ThemeState.dirty || WidgetState.dirty || ShortcutsState.dirty || ShortcutsState.editingForm || wallpaperWriter.running) { visible = true; if (!AppearanceState.busy && !ThemeState.busy && !WidgetState.busy && !ShortcutsState.busy && !wallpaperWriter.running) root.confirmClose = true; }
            else Qt.quit();
        }
        Shortcut { sequence: "Escape"; onActivated: { if (root.confirmClose) root.confirmClose = false; else if (search.text) search.clear(); else if (root.page !== "overview") root.navigate("overview"); else root.close(); } }
        Shortcut { sequence: "Ctrl+F"; onActivated: search.forceActiveFocus() }
        Rectangle {
            anchors.fill: parent; radius: 18
            gradient: Gradient { GradientStop { position: 0; color: PolyTheme.Theme.color("#242a32") } GradientStop { position: 1; color: PolyTheme.Theme.color("#1c242b") } }
            border.width: 1; border.color: PolyTheme.Theme.color("#7d8b9290")
        }
        RowLayout {
            anchors.fill: parent; anchors.margins: 1; spacing: 0
            Rectangle {
                Layout.preferredWidth: 210; Layout.fillHeight: true
                color: PolyTheme.Theme.color("#4a222a30")
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 10
                    Item {
                        Layout.fillWidth: true; Layout.preferredHeight: 70
                        MouseArea { anchors.fill: parent; onPressed: settingsWindow.startSystemMove() }
                        Row {
                            x: 11; y: 17; spacing: 14
                            FacetedMark { width: 31; height: 34 }
                            Column {
                                spacing: 5
                                Text { text: "ALPORA"; color: PolyTheme.Theme.color("#edf1f5"); font.family: Session.fontFamily; font.pixelSize: 22; font.letterSpacing: 2 }
                                Text { text: I18n.tr("settings.title"); color: PolyTheme.Theme.color("#c2c8d1"); font.family: Session.fontFamily; font.pixelSize: 12 }
                            }
                        }
                    }
                    TextField {
                        id: search
                        Layout.fillWidth: true; implicitHeight: 36
                        leftPadding: 37; rightPadding: 10
                        placeholderText: I18n.tr("settings.search_placeholder"); color: PolyTheme.Theme.color("#eef1f5"); placeholderTextColor: PolyTheme.Theme.color("#aeb7c1")
                        font.family: Session.fontFamily; font.pixelSize: 11; selectByMouse: true
                        background: Rectangle { radius: 11; color: PolyTheme.Theme.color("#503d4349"); border.width: 1; border.color: search.activeFocus ? PolyTheme.Theme.color("#a7be92") : PolyTheme.Theme.color("#50575b") }
                        Icon { x: 11; anchors.verticalCenter: parent.verticalCenter; name: "search"; width: 18; height: 18 }
                        onAccepted: { const found = root.navigation.find(n => (n.title + " " + n.words).toLowerCase().includes(text.trim().toLowerCase())); if (found) root.navigate(found.key); }
                    }
                    ScrollView {
                        id: navScroll
                        Layout.fillWidth: true; Layout.fillHeight: true
                        contentWidth: availableWidth; clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        Column {
                            width: navScroll.availableWidth; spacing: 2
                            Repeater {
                                model: root.navigation
                                Column {
                                    id: navEntry
                                    required property var modelData
                                    width: parent.width; spacing: 5
                                    visible: !search.text.trim() || (modelData.title + " " + modelData.words).toLowerCase().includes(search.text.trim().toLowerCase())
                                    Item {
                                        width: parent.width; height: navEntry.modelData.group ? 37 : 0
                                        visible: !!navEntry.modelData.group && !search.text
                                        Text { x: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; text: navEntry.modelData.group; color: PolyTheme.Theme.color("#a7b2af"); font.family: Session.fontFamily; font.pixelSize: 10; font.letterSpacing: 1.2 }
                                    }
                                    SettingsNav { width: parent.width; text: navEntry.modelData.title; symbol: navEntry.modelData.icon; selected: root.page === navEntry.modelData.key; onClicked: root.navigate(navEntry.modelData.key) }
                                }
                            }
                            Text { width: parent.width; topPadding: 14; text: I18n.tr("launcher.not_found"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 12; visible: !!search.text && !root.navigation.some(n => (n.title + " " + n.words).toLowerCase().includes(search.text.trim().toLowerCase())) }
                        }
                    }
                    SettingsCard {
                        Layout.fillWidth: true; Layout.preferredHeight: 64; padding: 12
                        TapHandler { onTapped: root.navigate("appearance") }
                        RowLayout {
                            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                            GemMark { Layout.preferredWidth: 23; Layout.preferredHeight: 30 }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 5
                                Text { text: PolyTheme.Theme.label; color: PolyTheme.Theme.color("#bbceaa"); font.family: Session.fontFamily; font.pixelSize: 12; font.letterSpacing: 1 }
                                Text { text: I18n.tr("settings.current_theme"); color: PolyTheme.Theme.color("#b4bec6"); font.family: Session.fontFamily; font.pixelSize: 10 }
                            }
                            Icon { name: "chevron-right"; Layout.preferredWidth: 14; Layout.preferredHeight: 14 }
                        }
                    }
                }
            }
            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: PolyTheme.Theme.color("#163d454a") }
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 24; spacing: 16
                Item {
                    Layout.fillWidth: true; Layout.preferredHeight: 90
                    Image { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 460; height: 90; source: Session.appearance.ridge ? "file://" + Session.appearance.ridge : "file://" + Quickshell.env("POLY_SHELL_ASSETS") + "/settings-ridge.svg"; fillMode: Image.PreserveAspectFit; verticalAlignment: Image.AlignBottom; opacity: 0.85 }
                    MouseArea { anchors.fill: parent; anchors.rightMargin: 52; onPressed: settingsWindow.startSystemMove() }
                    Column {
                        y: 8; spacing: 8
                        Text { text: root.pageTitle; color: PolyTheme.Theme.color("#f2f3f6"); font.family: Session.fontFamily; font.pixelSize: 28; font.weight: Font.Medium }
                        Text { text: root.page === "overview" ? I18n.tr("settings.subtitle_overview") : root.page === "wallpaper" ? I18n.tr("settings.subtitle_wallpaper") : root.page === "appearance" ? I18n.tr("settings.subtitle_appearance") : I18n.tr("settings.subtitle_generic"); color: PolyTheme.Theme.color("#bdc6d2"); font.family: Session.fontFamily; font.pixelSize: 13 }
                    }
                    IconButton { z: 10; anchors.right: parent.right; anchors.top: parent.top; symbol: "close"; hint: I18n.tr("settings.close_settings"); onClicked: root.close() }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: PolyTheme.Theme.color("#34545e62") }
                }
                SettingsOverview { Layout.fillWidth: true; Layout.fillHeight: true; visible: root.page === "overview"; monitors: root.monitors; wallpaper: root.wallpaperUrl; onNavigate: page => root.navigate(page) }
                Loader { Layout.fillWidth: true; Layout.fillHeight: true; visible: root.page === "appearance"; active: visible; sourceComponent: SettingsAppearance { wallpaper: root.wallpaperUrl } }
                Loader { Layout.fillWidth: true; Layout.fillHeight: true; visible: root.page === "widgets"; active: visible; sourceComponent: SettingsWidgets { wallpaper: root.wallpaperUrl } }
                Loader { Layout.fillWidth: true; Layout.fillHeight: true; visible: root.page === "input"; active: visible; sourceComponent: SettingsShortcuts {} }
                ThemePage { Layout.fillWidth: true; Layout.fillHeight: true; visible: root.page === "wallpaper"; onImportRequested: wallpaperDialog.open() }
                SettingsDetails {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    visible: !["overview", "appearance", "wallpaper", "widgets", "input"].includes(root.page)
                    page: root.page; monitors: root.monitors; wallpaper: root.wallpaperUrl
                    onNavigate: page => root.navigate(page)
                    onChooseWallpaper: wallpaperDialog.open()
                    onRestoreWallpaper: root.setWallpaper("--reset")
                }
                Text { Layout.fillWidth: true; visible: !!(root.statusMessage || Desktop.error || Session.error); text: root.statusMessage || Desktop.error || Session.error; color: PolyTheme.Theme.color("#e8c3aa"); font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap }
            }
        }
        Rectangle {
            anchors.fill: parent; color: PolyTheme.Theme.color("#b810181e"); visible: root.confirmClose
            MouseArea { anchors.fill: parent }
            SettingsCard {
                anchors.centerIn: parent; width: 430; height: 190
                Text { text: I18n.tr("settings.close_without_saving"); color: PolyTheme.Theme.color("#f0f2f5"); font.family: Session.fontFamily; font.pixelSize: 19 }
                Text { Layout.fillWidth: true; text: I18n.tr("settings.unsaved_warning"); color: PolyTheme.Theme.color("#c2c9d1"); font.family: Session.fontFamily; font.pixelSize: 13; wrapMode: Text.Wrap }
                RowLayout {
                    Layout.fillWidth: true
                    AppearanceButton { Layout.fillWidth: true; text: I18n.tr("settings.stay"); symbol: "chevron-left"; primary: true; onClicked: root.confirmClose = false }
                    AppearanceButton { Layout.fillWidth: true; text: I18n.tr("common.close"); symbol: "close"; onClicked: { settingsWindow.visible = false; settingsWindow.close(); Qt.quit(); } }
                }
            }
        }
    }
}
