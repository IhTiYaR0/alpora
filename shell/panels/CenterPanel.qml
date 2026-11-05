pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 8
    property bool active: false
    property real expansion: 1
    readonly property bool dragging: pageDrag.active || music.dragging
    signal expandRequested()
    property real scrollDistance: 0
    property real scrollVertical: 0
    property string scrollAxis: ""
    property bool scrollTriggered: false
    property real dragOffset: 0
    function resetScroll(): void { scrollDistance = 0; scrollVertical = 0; scrollAxis = ""; scrollTriggered = false; }
    onActiveChanged: if (!active) { resetScroll(); dragOffset = 0; }
    // Phase-less wheels need an idle boundary. A touchpad uses Begin/End instead.
    Timer { id: scrollPause; interval: 450; onTriggered: root.resetScroll() }
    function prepareOpen(): void {
        dayPanel.page = "main";
        dayPanel.localError = "";
        DayState.request("get", {});
    }
    Item {
        id: pages
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true
        readonly property int count: 2
        readonly property int currentIndex: BarState.centerPage
        readonly property bool interactive: dayPanel.page === "main" || currentIndex === 1
        function setCurrentIndex(index: int): void { BarState.centerPage = Math.max(0, Math.min(count - 1, index)); }
        function incrementCurrentIndex(): void { setCurrentIndex(currentIndex + 1); }
        function decrementCurrentIndex(): void { setCurrentIndex(currentIndex - 1); }
        Row {
            width: pages.width * 2; height: pages.height
            x: -pages.currentIndex * pages.width + root.dragOffset
            Behavior on x {
                enabled: !pageDrag.active && !Session.settings.reducedMotion
                NumberAnimation { duration: Motion.openMs; easing.type: Easing.OutQuint }
            }
            DayPanel { id: dayPanel; expansion: root.expansion; width: pages.width; height: pages.height }
            MusicPanel { id: music; expansion: root.expansion; width: pages.width; height: pages.height; active: root.active && pages.currentIndex === 1 }
        }
        DragHandler {
            id: pageDrag
            target: null
            enabled: root.active && pages.interactive
            xAxis.enabled: true; yAxis.enabled: false
            dragThreshold: 10
            // Controls that grab a drag (sliders, lists, text selection) retain it.
            grabPermissions: PointerHandler.ApprovesTakeOverByAnything
            property int origin: 0
            property real distance: 0
            onActiveChanged: {
                if (active) { origin = pages.currentIndex; distance = 0; root.dragOffset = 0; }
                else {
                    if (Math.abs(distance) >= 40)
                        pages.setCurrentIndex(origin + (distance < 0 ? 1 : -1));
                    root.dragOffset = 0;
                }
            }
            onTranslationChanged: {
                if (!active) return;
                distance = activeTranslation.x;
                const overshoot = (origin === 0 && activeTranslation.x > 0) || (origin === pages.count - 1 && activeTranslation.x < 0);
                root.dragOffset = Math.max(-pages.width * 0.4, Math.min(pages.width * 0.4, activeTranslation.x * (overshoot ? 0.15 : 1)));
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            enabled: root.active && pages.interactive
            onWheel: event => {
                if (event.phase === Qt.ScrollBegin) root.resetScroll();
                if (event.phase === Qt.ScrollEnd) {
                    const consumed = root.scrollAxis === "horizontal";
                    root.resetScroll(); scrollPause.stop(); event.accepted = consumed; return;
                }
                // Use the physical touchpad's pixel deltas consistently, without
                // switching to amplified angle deltas halfway through a gesture.
                const dx = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x / 8;
                const dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 8;
                if (dx === 0 && dy === 0) { event.accepted = false; return; }
                if (event.phase === Qt.NoScrollPhase) scrollPause.restart();
                else scrollPause.stop();
                root.scrollDistance += dx;
                root.scrollVertical += dy;
                if (!root.scrollAxis) {
                    if (Math.abs(root.scrollDistance) >= 6 && Math.abs(root.scrollDistance) > Math.abs(root.scrollVertical) * 1.15)
                        root.scrollAxis = "horizontal";
                    else if (Math.abs(root.scrollVertical) >= 6 && Math.abs(root.scrollVertical) > Math.abs(root.scrollDistance) * 1.15)
                        root.scrollAxis = "vertical";
                }
                event.accepted = root.scrollAxis === "horizontal";
                if (!event.accepted || root.scrollTriggered) return;
                if (Math.abs(root.scrollDistance) >= 18) {
                    const origin = pages.currentIndex;
                    pages.setCurrentIndex(origin + (root.scrollDistance < 0 ? 1 : -1));
                    console.info("Center gesture page", origin, pages.currentIndex, "pixels", root.scrollDistance);
                    root.scrollTriggered = true;
                }
            }
        }
    }
    Item {
        Layout.fillWidth: true; Layout.minimumHeight: 0; Layout.preferredHeight: 40 * (1 - root.expansion)
        clip: true
        SettingsRow { width: parent.width; height: 40; text: BarState.centerPage === 0 ? I18n.tr("center.open_panel") : I18n.tr("center.open_player"); symbol: BarState.centerPage === 0 ? "calendar" : "music"; enabled: root.expansion < 0.1; onClicked: root.expandRequested() }
    }
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 34; Layout.fillHeight: false
        radius: 11; color: Glass.tint(PolyTheme.Theme.color("#20292a"), 0.45)
        RowLayout {
            anchors.fill: parent; anchors.margins: 4
            spacing: 6
            BarButton {
                symbol: "chevron-left"; hint: I18n.tr("center.my_day")
                implicitWidth: 26; implicitHeight: 26
                enabled: pages.currentIndex > 0
                opacity: enabled ? 1 : 0.3
                onClicked: pages.decrementCurrentIndex()
            }
            Item { Layout.fillWidth: true }
            Repeater {
                model: [I18n.tr("center.my_day"), I18n.tr("music.title")]
                Button {
                    id: tab
                    transform: InteractionMotion { item: tab; pressed: tab.down; hovered: tab.hovered || tab.visualFocus; hoverScale: 1.02; pressScale: 0.96 }
                    required property int index
                    required property string modelData
                    implicitWidth: 88; implicitHeight: 26; padding: 0
                    hoverEnabled: true; focusPolicy: Qt.StrongFocus
                    Accessible.name: modelData
                    Accessible.role: Accessible.PageTab
                    Accessible.selected: pages.currentIndex === index
                    background: Rectangle {
                        radius: 8
                        color: pages.currentIndex === tab.index ? PolyTheme.Theme.color("#3a493c") : (tab.hovered ? PolyTheme.Theme.color("#303b35") : "transparent")
                        border.width: tab.visualFocus ? 1 : 0; border.color: PolyTheme.Theme.color("#a4b594")
                        Behavior on color { ColorAnimation { duration: Session.settings.reducedMotion ? 0 : 140 } }
                    }
                    contentItem: Text {
                        text: tab.modelData
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        color: pages.currentIndex === tab.index ? PolyTheme.Theme.color("#dce7d2") : Session.muted
                        font.family: Session.fontFamily; font.pixelSize: 11
                    }
                    onClicked: pages.setCurrentIndex(index)
                }
            }
            Item { Layout.fillWidth: true }
            BarButton {
                symbol: "chevron-right"; hint: I18n.tr("music.title")
                implicitWidth: 26; implicitHeight: 26
                enabled: pages.currentIndex < pages.count - 1
                opacity: enabled ? 1 : 0.3
                onClicked: pages.incrementCurrentIndex()
            }
        }
    }
    Shortcut { sequence: "Alt+Right"; enabled: root.active; onActivated: pages.incrementCurrentIndex() }
    Shortcut { sequence: "Alt+Left"; enabled: root.active; onActivated: pages.decrementCurrentIndex() }
}
