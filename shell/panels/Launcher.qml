pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: launcher
    required property var modelData
    required property var barWindow
    screen: modelData
    // Keep the keyboard surface mapped for shortcut-following input, but
    // bound the blur buffer to the panel while open and to 1×1 while closed. A resize preserves
    // prepared focus; unmapping loses the first keys during the mapping roundtrip.
    anchors { top: !launcher.bottomOrigin; bottom: launcher.bottomOrigin; left: true }
    implicitWidth: presented && modelData ? Math.min(modelData.width, Math.min(500, modelData.width - (bottomOrigin ? 32 : 16)) + (bottomOrigin ? 16 : Math.max(8, barWindow.outerMargin)) + 16) : 1
    implicitHeight: presented && modelData ? Math.min(modelData.height, (bottomOrigin ? bottomInset : restingY) + 700 + 16) : 1
    // Retain placement through the closing animation. Dock geometry is captured
    // in screen-local logical pixels at activation, independently per monitor.
    property bool bottomOrigin: false
    property var dockAnchor: ({x: 0, y: 0, width: 1, height: 1})
    readonly property real bottomInset: modelData ? Math.max(16, modelData.height - dockAnchor.y + 12) : 16
    readonly property real panelLeft: bottomOrigin && modelData
        ? Math.max(16, Math.min(modelData.width - frame.width - 16, dockAnchor.x + dockAnchor.width / 2 - frame.width / 2)) : frame.x
    // qmllint disable missing-property
    margins.left: bottomOrigin ? Math.max(0, panelLeft - 16) : 0
    // qmllint enable missing-property
    function updatePlacement(): void {
        if (!opened) return;
        if (BarState.selection.origin === "dock") {
            dockAnchor = BarState.selection.anchor;
            bottomOrigin = true;
        } else bottomOrigin = false;
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    readonly property bool opened: !!modelData && BarState.popup === "launcher" && BarState.popupScreen === modelData.name
    property bool preview: false
    property real expansion: preview ? 0 : 1
    readonly property real expansionCurve: expansion * expansion * (3 - 2 * expansion)
    Behavior on expansion { NumberAnimation { duration: launcher.opened && launcher.reveal > 0 && !Motion.reduced ? Session.visual.launcherOpenMs : 0; easing.type: Easing.Linear } }
    readonly property bool pointerInside: frameHover.hovered || gapHover.hovered || (!bottomOrigin && barWindow.launcherHovered) || (viewport && viewport.dragging)
    readonly property bool singleColumn: preview && query.trim().length > 0
    readonly property int columnCount: singleColumn ? 1 : 2
    readonly property real rowHeight: 58 + 16 * expansionCurve
    // Keyboard-opened panels arm dismissal once the pointer reaches them.
    property bool pointerDismissArmed: false
    function updatePreviewClose(): void {
        if (bottomOrigin && !preview) return;
        if (opened && pointerInside) pointerDismissArmed = true;
        if (opened && (preview || pointerDismissArmed) && !pointerInside) Qt.callLater(launcher.closePreviewOutside);
    }
    function closePreviewOutside(): void {
        // Native focus changes can deliver leave before enter on another surface.
        // Confirm the pointer once, rather than adding a timed hover delay.
        if (((opened && (preview || pointerDismissArmed) && !pointerInside) || barWindow.launcherPreviewBlocked) && !pointerCheck.running) pointerCheck.running = true;
    }
    function confirmPreviewOutside(text: string): void {
        try {
            const cursor = JSON.parse(text);
            const x = cursor.x - (modelData ? modelData.x : 0);
            const y = cursor.y - (modelData ? modelData.y : 0);
            barWindow.rearmLauncherHover(x, y);
            if (!opened || (bottomOrigin && !preview) || (!preview && !pointerDismissArmed)) return;
            const source = barWindow.buttonBounds(barWindow.launcherSource);
            const onSource = x >= source.x && x <= source.x + source.width
                && y >= source.y && y <= restingY;
            const onPanel = x >= frame.x && x <= frame.x + frame.width
                && y >= restingY - 20 && y <= frame.y + frame.height;
            if (!onSource && !onPanel && !pointerInside) close();
        } catch (_) { if (opened && (preview || pointerDismissArmed) && !pointerInside) close(); }
    }
    Process {
        id: pointerCheck
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector { onStreamFinished: launcher.confirmPreviewOutside(text) }
    }
    onPointerInsideChanged: updatePreviewClose()
    Connections {
        target: BarState
        function onSelectionChanged(): void {
            if (launcher.opened) {
                launcher.updatePlacement();
                launcher.preview = !!BarState.selection.preview;
                search.forceActiveFocus(Qt.ShortcutFocusReason);
            }
        }
    }
    readonly property bool keyboardActive: frame.Window.active
    property bool grabReady: true
    readonly property real reveal: panelMotion.progress
    readonly property bool presented: panelMotion.presented
    readonly property real restingY: barWindow.topMargin + barWindow.barHeight + 10
    PanelMotion {
        id: panelMotion
        opened: launcher.opened
        openDuration: Motion.reduced ? 0 : Session.visual.launcherOpenMs
        closeDuration: Motion.reduced ? 0 : Session.visual.launcherCloseMs
    }
    property string query: ""
    property string category: ""
    property bool allApps: false
    property int selectedIndex: 0
    readonly property bool browsing: allApps || query.trim().length > 0 || category.length > 0
    readonly property var results: AppCatalog.results(query, category)
    readonly property var shown: browsing ? results : AppCatalog.favorites
    readonly property Flickable viewport: scroll.contentItem as Flickable

    // Power-user instant parsing (Calculator, Terminal, Web search)
    readonly property string trimmedQuery: query.trim()
    readonly property bool isCommand: trimmedQuery.startsWith(">") || trimmedQuery.startsWith("$")
    readonly property string commandText: isCommand ? trimmedQuery.replace(/^[>\$]\s*/, "") : ""
    readonly property var directWebMatch: trimmedQuery.match(/^\?\s*(.+)$/)
    readonly property var keywordWebMatch: trimmedQuery.match(/^(g|gh|yt|w)\s+(.+)$/i)
    readonly property var webMatch: directWebMatch ? ["? " + directWebMatch[1], "g", directWebMatch[1]] : keywordWebMatch
    readonly property string webEngine: webMatch ? webMatch[1].toLowerCase() : ""
    readonly property string webTerm: webMatch ? webMatch[2] : ""

    function evaluateConversion(expr: string): string {
        if (!expr) return "";
        const m = expr.trim().match(/^([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z\$€£¥]+)\s*(?:in|to|=|as)\s*([a-zA-Z\$€£¥]+)$/i);
        if (!m) return "";
        const val = parseFloat(m[1]);
        const fromU = m[2].toLowerCase();
        const toU = m[3].toLowerCase();
        if (isNaN(val)) return "";

        // Currency rates (USD base)
        const curRates = {
            usd: 1.0, "$": 1.0,
            eur: 0.92, "€": 0.92,
            gbp: 0.79, "£": 0.79,
            jpy: 152.0, "¥": 152.0,
            vnd: 25400.0,
            cny: 7.23,
            cad: 1.39,
            aud: 1.52
        };
        if (curRates[fromU] !== undefined && curRates[toU] !== undefined) {
            const inUsd = val / curRates[fromU];
            const converted = inUsd * curRates[toU];
            const formatted = converted >= 100 ? converted.toFixed(2) : converted.toFixed(4).replace(/\.?0+$/, "");
            return formatted + " " + toU.toUpperCase();
        }

        // Length
        const lenMeters = {
            km: 1000, m: 1, cm: 0.01, mm: 0.001,
            mi: 1609.344, miles: 1609.344,
            ft: 0.3048, feet: 0.3048,
            in: 0.0254, inch: 0.0254, inches: 0.0254
        };
        if (lenMeters[fromU] !== undefined && lenMeters[toU] !== undefined) {
            const inMeters = val * lenMeters[fromU];
            const converted = inMeters / lenMeters[toU];
            return (Math.abs(converted - Math.round(converted)) < 1e-6 ? Math.round(converted) : converted.toFixed(3).replace(/\.?0+$/, "")) + " " + toU;
        }

        // Mass
        const massKg = {
            kg: 1, g: 0.001, mg: 0.000001,
            lb: 0.45359237, lbs: 0.45359237,
            oz: 0.0283495
        };
        if (massKg[fromU] !== undefined && massKg[toU] !== undefined) {
            const inKg = val * massKg[fromU];
            const converted = inKg / massKg[toU];
            return (Math.abs(converted - Math.round(converted)) < 1e-6 ? Math.round(converted) : converted.toFixed(3).replace(/\.?0+$/, "")) + " " + toU;
        }

        // Temperature
        if ((fromU === "c" || fromU === "celsius") && (toU === "f" || toU === "fahrenheit")) {
            return ((val * 9 / 5) + 32).toFixed(1).replace(/\.0$/, "") + " °F";
        }
        if ((fromU === "f" || fromU === "fahrenheit") && (toU === "c" || toU === "celsius")) {
            return (((val - 32) * 5 / 9)).toFixed(1).replace(/\.0$/, "") + " °C";
        }
        return "";
    }

    function evaluateMath(expr: string): string {
        if (!expr || expr.length < 2) return "";
        const clean = expr.trim().replace(/\^/g, "**").replace(/\bpi\b/gi, "Math.PI").replace(/\be\b/gi, "Math.E");
        if (!/^[0-9\s\+\-\*\/\%\.\(\)\,\*\*\s]|Math\.(sin|cos|tan|sqrt|pow|abs|round|floor|ceil|log|PI|E)/i.test(clean))
            return "";
        if (!/[\+\-\*\/\%\^]|(sin|cos|tan|sqrt|abs|log)/i.test(expr))
            return "";
        try {
            const fn = new Function("Math", "return (" + clean + ");");
            const res = fn(Math);
            if (typeof res === "number" && isFinite(res)) {
                return Math.abs(res - Math.round(res)) < 1e-9 ? Math.round(res).toString() : res.toFixed(4).replace(/\.?0+$/, "");
            }
        } catch (_) {}
        return "";
    }
    readonly property string conversionResult: isCommand || webMatch ? "" : evaluateConversion(trimmedQuery)
    readonly property string mathResult: isCommand || webMatch ? "" : (conversionResult.length > 0 ? conversionResult : evaluateMath(trimmedQuery))

    function activateAction(): void {
        if (mathResult.length > 0) {
            Quickshell.execDetached(["wl-copy", mathResult]);
            close();
        } else if (isCommand && commandText.length > 0) {
            Quickshell.execDetached(Session.settings.apps.terminal.concat(["-e", "bash", "-c", commandText + "; echo; read -p 'Press Enter to exit...'"]));
            close();
        } else if (webMatch) {
            const urls = {
                g: "https://www.google.com/search?q=",
                gh: "https://github.com/search?q=",
                yt: "https://www.youtube.com/results?search_query=",
                w: "https://en.wikipedia.org/wiki/Special:Search?search="
            };
            const u = (urls[webEngine] || urls.g) + encodeURIComponent(webTerm);
            Quickshell.execDetached(["xdg-open", u]);
            close();
        } else if (shown.length) {
            launch(shown[selectedIndex]);
        }
    }
    IpcHandler {
        target: "launcher-" + (launcher.modelData ? launcher.modelData.name : "disconnected")
        function inputStatus(): string {
            return JSON.stringify({ opened: launcher.opened, origin: launcher.bottomOrigin ? "dock" : "top", text: search.text, query: launcher.query, focused: search.activeFocus, windowActive: frame.Window.active, progress: launcher.reveal, preview: launcher.preview, selectedIndex: launcher.selectedIndex, count: launcher.shown.length, pointerInside: launcher.pointerInside, names: launcher.shown.map(entry => entry.name) });
        }
        function motionStatus(): string {
            return JSON.stringify({ opened: launcher.opened, progress: launcher.reveal,
                preview: launcher.preview, origin: launcher.bottomOrigin ? "dock" : "top", width: frame.surfaceWidth, height: frame.surfaceHeight,
                surfaceX: frame.surfaceX, surfaceY: frame.surfaceY, duration: panelMotion.openDuration,
                fullWidth: frame.width, fullHeight: frame.height, effectReady: frame.effectReady,
                originX: frame.origin.x, originY: frame.origin.y, screenX: frame.screenPosition.x, screenY: frame.screenPosition.y,
                x: frame.x, y: frame.y, fontSize: search.font.pixelSize });
        }
        function startMotionTrace(): void { frame.startTrace(); }
        function stopMotionTrace(): string { return JSON.stringify(frame.finishTrace()); }
    }
    function close(): void { BarState.close(); }
    function launch(entry: var): void { entry.execute(); close(); }
    function moveSelection(delta: int): void {
        selectedIndex = Math.max(0, Math.min(shown.length - 1, selectedIndex + delta));
        const rowY = Math.floor(selectedIndex / columnCount) * rowHeight;
        const flick = scroll.contentItem as Flickable;
        if (flick) flick.contentY = Math.max(0, Math.min(rowY, scroll.contentHeight - scroll.availableHeight));
    }
    onShownChanged: {
        selectedIndex = 0;
        const flick = scroll.contentItem as Flickable;
        if (flick) flick.contentY = 0;
    }
    onOpenedChanged: {
        pointerDismissArmed = opened && pointerInside;
        if (opened) {
            updatePlacement();
            preview = !!BarState.selection.preview;
            // Rapid close/reopen must not append to the previous search.
            if (resetAfterClose.running) {
                search.clear(); query = ""; category = ""; allApps = false; selectedIndex = 0;
            }
            resetAfterClose.stop();
            search.forceActiveFocus(Qt.ShortcutFocusReason);
            updatePreviewClose();
        } else resetAfterClose.restart();
    }
    Timer {
        id: resetAfterClose
        interval: panelMotion.closeDuration + 16
        onTriggered: {
            if (launcher.opened) return;
            search.clear(); launcher.query = ""; launcher.category = "";
            launcher.allApps = false; launcher.selectedIndex = 0;
            // Prepare the persistent shortcut surface at its default origin
            // after the dock's closing frames finish, before the next Super+R.
            launcher.bottomOrigin = false;
            search.forceActiveFocus(Qt.ShortcutFocusReason);
        }
    }
    // Keep a transparent 1x1 surface ready while closed, with no input region.
    visible: true
    mask: Region {
        x: launcher.bottomOrigin || BarState.selection.preview ? frame.x : 0
        y: launcher.bottomOrigin ? frame.y : BarState.selection.preview ? launcher.restingY - 20 : launcher.barWindow.topMargin + launcher.barWindow.barHeight
        width: launcher.opened ? (launcher.bottomOrigin || BarState.selection.preview ? frame.width : launcher.width) : 0
        height: launcher.opened ? (launcher.bottomOrigin ? frame.height : BarState.selection.preview ? frame.height + 20 : Math.max(0, launcher.height - y)) : 0
    }
    WlrLayershell.namespace: "poly-shell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    // Keep interactivity stable; the native grab below switches focus without
    // waiting for a newly rendered layer-surface state commit.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    MouseArea {
        id: backdrop
        anchors.fill: parent
        anchors.topMargin: launcher.barWindow.topMargin + launcher.barWindow.barHeight
        enabled: launcher.opened && !launcher.preview && !launcher.bottomOrigin
        onPressed: mouse => {
            const p = frame.mapFromItem(this, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > frame.width || p.y > frame.height) launcher.close();
        }
    }
    Item {
        x: frame.x; y: launcher.bottomOrigin ? frame.y + frame.height : launcher.restingY - 20; width: frame.width; height: 20
        visible: launcher.opened
        HoverHandler { id: gapHover }
    }
    // Geometry proxy for UnfoldPanel's screen-local reveal origin. The dock's
    // real button lives on another layer surface and stays available below.
    Item {
        id: dockSource
        visible: false
        x: launcher.dockAnchor.x; y: launcher.dockAnchor.y
        width: launcher.dockAnchor.width; height: launcher.dockAnchor.height
    }
    UnfoldPanel {
        id: frame
        HoverHandler { id: frameHover }
        motion: panelMotion
        cornerRadius: Session.visual.launcherRadius
        edgeWidth: Session.visual.launcherBorder
        shadowStrength: Session.visual.launcherShadow / 20
        surfaceTop: Glass.launcherTop
        surfaceBottom: Glass.launcherBottom
        sourceItem: launcher.bottomOrigin ? dockSource : launcher.barWindow.launcherSource
        screenPosition: launcher.bottomOrigin && launcher.modelData
            ? Qt.point(launcher.panelLeft, launcher.modelData.height - launcher.bottomInset - frame.height) : Qt.point(frame.x, frame.y)
        x: launcher.bottomOrigin ? 16 : Math.min(launcher.barWindow.outerMargin, Math.max(8, (launcher.modelData ? launcher.modelData.width : 1) - width - 8))
        y: launcher.bottomOrigin ? launcher.height - launcher.bottomInset - height : launcher.restingY
        width: Math.min(400 + 100 * launcher.expansionCurve, (launcher.modelData ? launcher.modelData.width : 1) - (launcher.bottomOrigin ? 32 : 16))
        height: Math.max(0, Math.min(700, (launcher.modelData ? launcher.modelData.height : 0)
            - (launcher.bottomOrigin ? launcher.bottomInset + 16 : y + 20), contentLayout.implicitHeight + Session.visual.launcherPadding * 2))
        Behavior on height { enabled: launcher.opened && panelMotion.progress >= 1 && launcher.expansion >= 1; NumberAnimation { duration: Motion.resizeMs; easing.type: Easing.OutCubic } }
        ColumnLayout {
            id: contentLayout
            anchors.fill: parent; anchors.margins: Session.visual.launcherPadding - 4 + 4 * launcher.expansionCurve; spacing: 8 + 4 * launcher.expansionCurve
            TextField {
                id: search
                // Retain the focus target even while the transparent window is
                // idle; hiding an ancestor would invalidate this prepared focus.
                focus: true
                Layout.fillWidth: true; Layout.preferredHeight: 42 + 6 * launcher.expansionCurve
                placeholderText: I18n.tr("launcher.search")
                onTextChanged: launcher.query = text
                color: Session.foreground; placeholderTextColor: Session.muted
                font.family: Session.fontFamily; font.pixelSize: 14
                leftPadding: 42; rightPadding: 12
                Accessible.name: I18n.tr("launcher.search")
                background: Rectangle { radius: 13; color: Glass.tint(Session.surface, 0.6); border.width: search.activeFocus ? 2 : 1; border.color: search.activeFocus ? Session.accent : Glass.tint(Session.muted, 0.3) }
                Icon { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; name: "search" }
                Keys.onDownPressed: launcher.moveSelection(launcher.columnCount)
                Keys.onUpPressed: launcher.moveSelection(-launcher.columnCount)
                Keys.onLeftPressed: event => { if (event.modifiers & Qt.AltModifier) { launcher.moveSelection(-1); event.accepted = true; } else event.accepted = false; }
                Keys.onRightPressed: event => { if (event.modifiers & Qt.AltModifier) { launcher.moveSelection(1); event.accepted = true; } else event.accepted = false; }
                Keys.onReturnPressed: launcher.activateAction()
                Keys.onEnterPressed: launcher.activateAction()
            }

            // Quick Calculator Instant Card
            Rectangle {
                visible: launcher.mathResult.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                radius: 12
                color: Glass.tint(Session.surface, 0.75)
                border.color: Session.accent
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Icon { name: "calculator"; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "= " + launcher.mathResult
                            color: Session.accent
                            font.family: Session.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                        }
                        Text {
                            text: I18n.tr("launcher.copy_clipboard")
                            color: Session.muted
                            font.family: Session.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: launcher.activateAction()
                }
            }

            // Quick Command Runner Instant Card
            Rectangle {
                visible: launcher.isCommand && launcher.commandText.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                radius: 12
                color: Glass.tint(Session.surface, 0.75)
                border.color: Session.accent
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Icon { name: "terminal"; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: launcher.commandText
                            color: Session.foreground
                            font.family: Session.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: I18n.trWith("launcher.run_command", {cmd: launcher.commandText})
                            color: Session.muted
                            font.family: Session.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: launcher.activateAction()
                }
            }

            // Quick Web Search Instant Card
            Rectangle {
                visible: !!launcher.webMatch
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                radius: 12
                color: Glass.tint(Session.surface, 0.75)
                border.color: Session.accent
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Icon { name: "globe"; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: launcher.webTerm
                            color: Session.foreground
                            font.family: Session.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: I18n.trWith("launcher.search_web", {
                                engine: ({g: "Google", gh: "GitHub", yt: "YouTube", w: "Wikipedia"})[launcher.webEngine] || "Web",
                                term: launcher.webTerm
                            })
                            color: Session.muted
                            font.family: Session.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: launcher.activateAction()
                }
            }

            // Quick Macro Actions Row
            RowLayout {
                visible: !launcher.query.trim() && !launcher.browsing
                Layout.fillWidth: true
                spacing: 8

                MacroActionTile {
                    Layout.fillWidth: true
                    title: "Terminal"
                    subtitle: "Super+Enter"
                    symbol: "terminal"
                    execCommand: "foot || alacritty || kitty"
                    onActivated: launcher.close()
                }

                MacroActionTile {
                    Layout.fillWidth: true
                    title: "Task Mgr"
                    subtitle: "Ctrl+Esc"
                    symbol: "developer"
                    execCommand: "poly-shell task-manager || btop"
                    onActivated: launcher.close()
                }

                MacroActionTile {
                    Layout.fillWidth: true
                    title: "Lock"
                    subtitle: "Super+L"
                    symbol: "lock"
                    execCommand: "loginctl lock-session"
                    onActivated: launcher.close()
                }
            }

            Item {
                Layout.fillWidth: true; Layout.preferredHeight: 22
                MountainRidge { anchors.right: parent.right; width: 240; height: 30; opacity: 0.65 }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Glass.tint(Session.surface, 0.8) }
            }
            RowLayout {
                id: sectionHeading
                opacity: frame.revealOpacity(sectionHeading)
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: launcher.query.trim() ? I18n.tr("launcher.search_results") + (launcher.preview ? " · " + launcher.shown.length : "") : launcher.category ? (AppCatalog.categories.find(item => item.id === launcher.category)?.name || "") : launcher.allApps ? I18n.tr("launcher.all_apps") : I18n.tr("launcher.favorites")
                    color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 13; font.weight: Font.Medium
                }
                Button {
                    id: back
                    visible: launcher.browsing
                    text: I18n.tr("common.back")
                    onClicked: { search.clear(); launcher.category = ""; launcher.allApps = false; search.forceActiveFocus(); }
                    contentItem: Text { text: back.text; color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 11 }
                    background: Rectangle { radius: 6; color: Glass.tint(Session.surface, 0.75) }
                }
            }
            ScrollView {
                id: scroll
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumHeight: 0
                Layout.preferredHeight: Math.min(appContent.implicitHeight, (launcher.query.trim() ? 222 : 106) + 594 * launcher.expansionCurve)
                padding: 0
                contentWidth: availableWidth
                clip: true
                Column {
                    id: appContent
                    width: scroll.availableWidth; spacing: 12 * launcher.expansionCurve
                    Item {
                        id: appGrid
                        readonly property bool searching: !!launcher.query.trim()
                        readonly property real miniHeight: searching ? Math.max(0, launcher.shown.length * 58 - 10) : Math.max(0, Math.ceil(Math.min(4, launcher.shown.length) / 2) * 58 - 10)
                        readonly property real fullHeight: Math.max(0, Math.ceil(launcher.shown.length / 2) * 74 - 10)
                        width: parent.width; implicitHeight: miniHeight + (fullHeight - miniHeight) * launcher.expansionCurve
                        height: implicitHeight; clip: true
                        Repeater {
                            model: launcher.shown
                            Item {
                                id: tileSlot
                                required property var modelData
                                required property int index
                                readonly property real p: launcher.expansionCurve
                                readonly property real miniX: appGrid.searching ? 0 : index % 2 * (appGrid.width + 10) / 2
                                readonly property real miniY: appGrid.searching ? index * 58 : Math.floor(index / 2) * 58
                                x: miniX + (index % 2 * (appGrid.width + 10) / 2 - miniX) * p
                                y: miniY + (Math.floor(index / 2) * 74 - miniY) * p
                                width: appGrid.searching ? appGrid.width + ((appGrid.width - 10) / 2 - appGrid.width) * p : (appGrid.width - 10) / 2
                                height: 48 + 16 * p
                                opacity: !appGrid.searching && index >= 4 ? p : 1
                                Loader {
                                    anchors.fill: parent
                                    active: launcher.presented && (!launcher.viewport || (tileSlot.y + tileSlot.height >= launcher.viewport.contentY - 74 && tileSlot.y <= launcher.viewport.contentY + scroll.availableHeight + 74))
                                    sourceComponent: AppTile {
                                        entry: tileSlot.modelData; expansion: launcher.expansionCurve
                                        entranceActive: launcher.opened; animateEntrance: false
                                        selected: search.activeFocus && launcher.selectedIndex === tileSlot.index
                                        onLaunchRequested: launcher.launch(entry)
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        width: parent.width; visible: !launcher.shown.length
                        text: launcher.browsing ? I18n.tr("launcher.not_found_hint") : I18n.tr("launcher.empty_favorites_hint")
                        wrapMode: Text.Wrap; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 12
                    }
                    Item {
                        visible: !launcher.browsing
                        width: parent.width; height: categories.implicitHeight * launcher.expansionCurve; clip: true
                    GridLayout {
                        id: categories
                        width: parent.width; columns: 2; columnSpacing: 10; rowSpacing: 8
                        Repeater {
                            model: AppCatalog.categories
                            SettingsRow {
                                id: categoryRow
                                required property var modelData
                                required property int index
                                opacity: frame.revealOpacity(categoryRow)
                                entranceActive: launcher.opened && !launcher.browsing; entranceOrder: index + 4
                                Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredHeight: 42
                                symbol: modelData.icon; text: modelData.name
                                onClicked: { launcher.category = modelData.id; search.forceActiveFocus(); }
                            }
                        }
                    }
                    }
                }
            }
            Item {
                Layout.fillWidth: true; Layout.minimumHeight: 0
                Layout.preferredHeight: 40 * (launcher.browsing ? 1 - launcher.expansionCurve : 1)
                clip: true
            SettingsRow {
                width: parent.width; height: 40
                symbol: "settings"; text: I18n.tr("launcher.all_apps"); subtitle: I18n.trWith("launcher.installed_count", {count: AppCatalog.entries.length})
                onClicked: { BarState.expandLauncher(); launcher.allApps = true; launcher.category = ""; search.clear(); search.forceActiveFocus(); }
            }
            }
            Item {
                Layout.fillWidth: true; Layout.minimumHeight: 0
                Layout.preferredHeight: launcher.query.trim() ? 12 * (1 - launcher.expansionCurve) : 0
                clip: true
            Text {
                width: parent.width
                text: I18n.tr("launcher.footer_hint")
                color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
            }
            Text { visible: AppCatalog.error.length > 0; text: AppCatalog.error; color: Session.palette.urgent || Session.accent; font.family: Session.fontFamily; font.pixelSize: 10; Layout.fillWidth: true; wrapMode: Text.Wrap }
        }
    }
}
