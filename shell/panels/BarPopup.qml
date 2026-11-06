pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: popup
    required property var modelData
    required property var barWindow
    screen: modelData
    anchors { top: true; left: true }
    property bool preview: false
    readonly property bool clipboardModal: page === "clipboard" && !preview
    property real expansion: preview ? 0 : 1
    readonly property real expansionCurve: expansion * expansion * (3 - 2 * expansion)
    Behavior on expansion { NumberAnimation { duration: popup.opened && popup.reveal > 0 ? Motion.openMs : 0; easing.type: Easing.Linear } }
    readonly property bool pointerInside: panelHover.hovered || gapHover.hovered || (page === "calendar" ? barWindow.centerHovered : page === "notifications" ? barWindow.notificationHovered : page === "timeline" ? barWindow.timelineHovered : page === "clipboard" ? barWindow.clipboardHovered : barWindow.trayHovered) || (page === "calendar" && centerPanel.dragging)
    onPointerInsideChanged: updatePreviewClose()
    // Keyboard-opened panels arm dismissal once the pointer reaches them.
    property bool pointerDismissArmed: false
    function updatePreviewClose(): void {
        if (page !== BarState.popup) return;
        if (page === "clipboard" && !preview) return;
        if (opened && pointerInside) pointerDismissArmed = true;
        if (opened && (preview || pointerDismissArmed) && !pointerInside) Qt.callLater(popup.closePreviewOutside);
    }
    function closePreviewOutside(): void {
        pointerExit.check();
    }
    PointerExitGuard {
        id: pointerExit
        ownerToken:BarState.selection.name+"|"+BarState.selection.screen+"|"+String(!!BarState.selection.preview)
        enabledForClose: popup.opened && popup.page === BarState.popup
            && (popup.page !== "clipboard" || popup.preview) && (popup.preview || popup.pointerDismissArmed)
        pointerInside: popup.pointerInside
        barWindow: popup.barWindow
        sourceItem: popup.page === "calendar" ? popup.barWindow.clockSource
            : popup.page === "notifications" ? popup.barWindow.notificationSource
            : popup.page === "timeline" ? popup.barWindow.timelineSource : popup.page === "clipboard" ? popup.barWindow.clipboardSource : popup.barWindow.traySource
        screenOffset: Qt.point(popup.modelData ? popup.modelData.x : 0, popup.modelData ? popup.modelData.y : 0)
        panelBounds: Qt.rect(body.screenPosition.x, popup.restingY, popup.panelWidth, popup.panelHeight)
        onOutside: BarState.close()
    }
    onPreviewChanged: {
        updatePreviewClose();
        if (opened && !preview) focusDelay.restart();
    }
    Connections {
        target: BarState
        function onSelectionChanged(): void {
            if (popup.opened) popup.preview = !!BarState.selection.preview;
        }
    }
    readonly property real viewportWidth: modelData ? modelData.width : 0
    readonly property real viewportHeight: modelData ? modelData.height : 0
    readonly property real panelWidth: Math.max(0, Math.min(viewportWidth - 32, page === "clipboard" ? 380 + 100 * expansionCurve : page === "timeline" ? 440 : page === "calendar" ? 420 + 280 * expansionCurve : page === "notifications" ? 420 : Math.max(230, Math.min(6, overflowItems.length) * 36 + 32)))
    readonly property real panelHeight: Math.max(0, Math.min(viewportHeight - restingY - 16,
        (page === "clipboard" ? clipboardPreview.implicitHeight + 68 + (600 - clipboardPreview.implicitHeight - 68) * expansionCurve : page === "timeline" ? 194 : page === "calendar" ? 328 + 222 * expansionCurve : page === "notifications" ? notificationsPanel.previewHeight + 68 + (580 - notificationsPanel.previewHeight - 68) * expansionCurve : 100 + Math.ceil(overflowItems.length / 6) * 36) + (Session.visual.panelPadding - 16) * 2))
    readonly property real panelLeft: Math.max(16, Math.min(viewportWidth - panelWidth - 16,
        (page === "calendar" ? viewportWidth / 2 : retainedAnchorX) - panelWidth / 2))
    readonly property real windowWidth: page === "calendar" ? Math.min(700, viewportWidth - 32) : panelWidth
    readonly property real windowHeight: Math.min(viewportHeight - restingY - 16, page === "calendar" ? 550 + (Session.visual.panelPadding - 16) * 2 : page === "notifications" ? Math.max(580, notificationsPanel.previewHeight + 68) + (Session.visual.panelPadding - 16) * 2 : panelHeight)
    implicitWidth: clipboardModal ? viewportWidth : windowWidth + 32
    readonly property real topPadding: restingY
    implicitHeight: clipboardModal ? viewportHeight : windowHeight + topPadding + 16
    // qmllint disable missing-property
    margins { left: popup.clipboardModal ? 0 : Math.max(0, (popup.page === "calendar" ? popup.viewportWidth / 2 - popup.windowWidth / 2 : popup.panelLeft) - 16); top: 0 }
    // qmllint enable missing-property
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    readonly property bool opened: !!modelData && ["calendar", "notifications", "tray", "timeline", "clipboard"].includes(BarState.popup) && BarState.popupScreen === modelData.name
    Connections {
        target: body.Window.window
        function onFrameSwapped(): void { if (popup.opened) popup.grabReady = true; }
    }
    // Retain the page during the closing transition.
    property string page: "calendar"
    readonly property var overflowItems: barWindow.compact ? BarState.trayItems : BarState.hiddenTray
    readonly property bool keyboardActive: body.Window.active
    property bool focusEstablished: false
    onKeyboardActiveChanged: if (keyboardActive) focusEstablished = true
    property bool grabReady: false
    readonly property real reveal: panelMotion.progress
    readonly property real restingY: barWindow.topMargin + barWindow.barHeight + 10
    property real retainedAnchorX: width / 2
    function requestPage(): void {
        if (!opened) return;
        const changed = page !== BarState.popup;
        // Keep the old page, dimensions and source until its closing motion
        // completes. The latest requested page is then opened from its button.
        if (changed && panelMotion.progress > 0) return;
        if (changed && page === "timeline") TimelineState.commit();
        page = BarState.popup;
        const button = page === "calendar" ? barWindow.clockSource
            : page === "clipboard" ? barWindow.clipboardSource : page === "timeline" ? barWindow.timelineSource : page === "tray" ? barWindow.traySource : barWindow.notificationSource;
        retainedAnchorX = button.mapToItem(null, button.width / 2, 0).x;
        if (changed && page === "calendar") centerPanel.prepareOpen();
        if (page === "clipboard" && !preview) focusDelay.restart();
    }
    PanelMotion {
        id: panelMotion
        opened: popup.opened && popup.page === BarState.popup
        openDuration: Motion.openMs
        closeDuration: Motion.closeMs
        onProgressChanged: {
            if (progress === 0 && popup.opened && popup.page !== BarState.popup)
                Qt.callLater(popup.requestPage);
        }
    }
    IpcHandler {
        target: "bar-popup-" + (popup.modelData ? popup.modelData.name : "disconnected")
        function motionStatus(): string {
            return JSON.stringify({ opened: popup.opened, progress: popup.reveal,
                renderAnimating: panelMotion.renderAnimating, presented: panelMotion.presented,
                page: popup.page, width: body.surfaceWidth, height: body.surfaceHeight,
                clipboardCount: clipboardPanel.entries.length, clipboardQuery: clipboardPanel.query,
                clipboardSearchFocused: clipboardPanel.searchFocused, clipboardIndex: clipboardPanel.selectedIndex,
                clipboardPreviewCount: clipboardPreview.entries.length, clipboardModal: popup.clipboardModal,
                preview: popup.preview, pointerInside: popup.pointerInside, expansion: popup.expansion, previewCount: Math.min(notificationsPanel.entries.length, 2), centerPage: BarState.centerPage, musicDragging: centerPanel.dragging, requestedPage: BarState.popup, opening: panelMotion.opened,
                fullWidth: body.width, fullHeight: body.height, effectReady: body.effectReady,
                originX: body.origin.x, originY: body.origin.y, screenX: body.screenPosition.x, screenY: body.screenPosition.y,
                surfaceX: body.surfaceX, surfaceY: body.surfaceY, keyboardActive: popup.keyboardActive, focusEstablished: popup.focusEstablished });
        }
        function startMotionTrace(): void { body.startTrace(); }
        function stopMotionTrace(): string { return JSON.stringify(body.finishTrace()); }
    }
    // Reuse the mapped surface/context instead of recreating it on every open.
    // Closed panels are fully transparent and have an empty input region.
    visible: opened || panelMotion.presented
    mask: Region {
        x: popup.clipboardModal ? 0 : frame.x
        y: popup.clipboardModal ? 0 : popup.topPadding - 10
        width: !popup.opened ? 0 : popup.clipboardModal ? popup.width : popup.panelWidth
        height: !popup.opened ? 0 : popup.clipboardModal ? popup.height : popup.panelHeight + 10
    }
    WlrLayershell.namespace: "poly-panel-bar-popup" + (Motion.reduced ? "-static" : "")
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: !opened || BarState.selection.preview ? WlrKeyboardFocus.None
        : page === "clipboard" ? WlrKeyboardFocus.Exclusive
        : focusEstablished ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive

    onOpenedChanged: {
        pointerDismissArmed = opened && pointerInside;
        grabReady = false; focusEstablished = false;
        if (opened) {
            preview = !!BarState.selection.preview;
            requestPage();
            if (page === "calendar") centerPanel.prepareOpen();
            if (!preview) focusDelay.restart();
            updatePreviewClose();
        } else { focusDelay.stop(); if (page === "timeline") TimelineState.commit(); }
    }
    Connections {
        target: BarState
        function onPopupChanged(): void { popup.requestPage(); }
    }

    Timer { id: focusDelay; interval: 0; onTriggered: {
        if (popup.opened && !BarState.selection.preview) {
            body.forceActiveFocus();
            if (popup.page === "clipboard") clipboardPanel.prepareOpen();
        }
    } }
    // Exclusive keyboard layers need outside-click input on the same surface.
    // Only clipboard uses a full-screen transparent input region; its visual
    // panel stays anchored to the bar button at the configured dimensions.
    MouseArea {
        anchors.fill: parent
        enabled: popup.opened && popup.clipboardModal
        onPressed: mouse => {
            if (mouse.x < frame.x || mouse.x > frame.x + frame.width
                || mouse.y < frame.y || mouse.y > frame.y + frame.height)
                BarState.dismiss();
        }
    }
    Item {
        x: frame.x; y: popup.topPadding - 10; width: popup.panelWidth; height: 10
        visible: popup.opened
        HoverHandler { id: gapHover }
    }
    Item {
        id: frame
        width: popup.panelWidth; height: popup.panelHeight
        x: popup.clipboardModal ? popup.panelLeft : 16 + (popup.windowWidth - popup.panelWidth) / 2; y: popup.topPadding
        HoverHandler { id: panelHover }
        PanelReveal {
            target: body
            motion: panelMotion
        }

        UnfoldPanel {
            id: body
            anchors.fill: parent
            motion: panelMotion
            screenPosition: Qt.point(popup.panelLeft, popup.restingY)
            cornerRadius: Session.visual.panelRadius
            surfaceTop: Glass.panelTop
            surfaceBottom: Glass.panelBottom
            sourceItem: popup.page === "calendar" ? popup.barWindow.clockSource
                : popup.page === "clipboard" ? popup.barWindow.clipboardSource : popup.page === "timeline" ? popup.barWindow.timelineSource : popup.page === "tray" ? popup.barWindow.traySource : popup.barWindow.notificationSource
            focus: popup.opened && !BarState.selection.preview
            ColumnLayout {
                anchors.fill: parent; anchors.margins: Session.visual.panelPadding; spacing: 10
                RowLayout {
                    visible: !["calendar", "timeline"].includes(popup.page)
                    Layout.fillWidth: true
                    GemMark { Layout.preferredWidth: 16; Layout.preferredHeight: 19 }
                    Text {
                        Layout.fillWidth: true
                        text: popup.page === "clipboard" ? I18n.tr("popup.clipboard") : popup.page === "calendar" ? I18n.tr("popup.calendar") : (popup.page === "notifications" ? I18n.tr("popup.notifications") : I18n.tr("popup.tray"))
                        color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    BarButton { symbol: "close"; hint: I18n.tr("bar.close"); implicitWidth: 26; implicitHeight: 26; onClicked: BarState.close() }
                }
                ClipboardPanel {
                    id: clipboardPanel
                    visible: popup.page === "clipboard" && !popup.preview
                    Layout.fillWidth: true; Layout.fillHeight: true
                }
                ClipboardPreview {
                    id: clipboardPreview
                    visible: popup.page === "clipboard" && popup.preview
                    Layout.fillWidth: true; Layout.fillHeight: true
                    onExpandRequested: BarState.expandClipboard()
                }
                TimelinePanel { visible: popup.page === "timeline"; Layout.fillWidth: true; Layout.fillHeight: true }
                CenterPreview {
                    id: centerPreview
                    active: popup.opened && popup.page === "calendar"
                    visible: popup.page === "calendar" && popup.preview
                    Layout.fillWidth: true; Layout.fillHeight: true
                    onExpandRequested: BarState.expandCenter()
                }
                CenterPanel {
                    id: centerPanel
                    expansion: popup.expansionCurve
                    active: popup.opened && popup.page === "calendar"
                    visible: popup.page === "calendar" && !popup.preview
                    Layout.fillWidth: true; Layout.fillHeight: true
                    onExpandRequested: BarState.expandCenter()
                }
                NotificationsPreview {
                    id: notificationsPreview
                    visible: popup.page === "notifications" && popup.preview
                    Layout.fillWidth: true; Layout.fillHeight: true
                    onExpandRequested: BarState.expandNotifications()
                }
                NotificationsPanel {
                    id: notificationsPanel
                    expansion: popup.expansionCurve
                    visible: popup.page === "notifications" && !popup.preview
                    Layout.fillWidth: true; Layout.fillHeight: true
                    onExpandRequested: BarState.expandNotifications()
                }
                GridLayout {
                    visible: popup.page === "tray"
                    Layout.fillWidth: true
                    columns: 6; columnSpacing: 6; rowSpacing: 6
                    Repeater {
                        model: popup.overflowItems
                        TrayButton { required property var modelData; trayItem: modelData }
                    }
                }
                Text {
                    visible: popup.page === "tray" && popup.overflowItems.length === 0
                    text: I18n.tr("bar.all_icons_on_bar")
                    color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11
                }
                Item { visible: popup.page === "tray"; Layout.fillHeight: true }
            }
        }
    }
}

