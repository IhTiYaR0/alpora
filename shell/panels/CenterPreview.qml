pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    property bool active: false
    readonly property bool dragging: music.dragging || pageDrag.active
    property real scrollDistance: 0
    property real scrollVertical: 0
    property string scrollAxis: ""
    property bool scrollTriggered: false
    property real dragOffset: 0
    function resetScroll(): void { scrollDistance = 0; scrollVertical = 0; scrollAxis = ""; scrollTriggered = false; }
    onActiveChanged: if (!active) { resetScroll(); scrollPause.stop(); dragOffset = 0; }
    Timer { id: scrollPause; interval: 450; onTriggered: root.resetScroll() }
    signal expandRequested()
    spacing: 8
    Item {
        id: pages
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true
        readonly property int count: 2
        readonly property int currentIndex: BarState.centerPage
        readonly property bool interactive: !music.dragging
        function setCurrentIndex(index: int): void { BarState.centerPage = Math.max(0, Math.min(count - 1, index)); }
        Row {
            width: pages.width * 2; height: pages.height
            x: -pages.currentIndex * pages.width + root.dragOffset
            Behavior on x {
                enabled: !pageDrag.active && !Session.settings.reducedMotion
                NumberAnimation { duration: Motion.openMs; easing.type: Easing.OutQuint }
            }
        ColumnLayout {
            width: pages.width; height: pages.height
            spacing: 10
            PanelHeader {
                title: I18n.tr("center.my_day")
                subtitle: ClockState.date.toLocaleDateString(I18n.qtLocale, "dddd, d MMMM")
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                radius: 13; color: Glass.tint(Session.surface, 0.4)
                border.width: 0.7; border.color: Glass.tint(Session.accent, 0.2)
                RowLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 4
                    Repeater {
                        model: 7
                        ColumnLayout {
                            id: day
                            required property int index
                            readonly property date date: new Date(ClockState.date.getFullYear(), ClockState.date.getMonth(), ClockState.date.getDate() - (ClockState.date.getDay() + 6) % 7 + index)
                            readonly property bool today: date.toDateString() === ClockState.date.toDateString()
                            Layout.fillWidth: true; spacing: 8
                            Text {
                                Layout.fillWidth: true
                                text: (I18n.trArray("calendar.weekdays") || [])[day.index] || ""
                                horizontalAlignment: Text.AlignHCenter
                                font.family: Session.fontFamily; font.pixelSize: 10; color: Session.muted
                            }
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 28
                                radius: 8; color: day.today ? Session.accent : "transparent"
                                Text {
                                    anchors.centerIn: parent; text: day.date.getDate()
                                    color: day.today ? Session.background : Session.foreground
                                    font.family: Session.fontFamily; font.pixelSize: 12
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 56
                radius: 13; color: Glass.tint(Session.surface, 0.4)
                border.width: 0.7; border.color: Glass.tint(Session.accent, 0.2)
                RowLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 8
                    Icon { name: "focus"; Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
                    Text { text: I18n.tr("center.focus"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12 }
                    Text { Layout.fillWidth: true; text: DayState.countdown; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 20 }
                    DayAction {
                        primary: true; text: DayState.running ? I18n.tr("common.pause") : I18n.tr("center.start")
                        enabled: DayState.loaded && !DayState.busy
                        onClicked: DayState.request(DayState.running ? "timer-pause" : "timer-start", {})
                    }
                    BarButton {
                        symbol: "refresh"; hint: I18n.tr("focus.reset_timer"); implicitWidth: 24
                        enabled: DayState.loaded && !DayState.busy
                        onClicked: DayState.request("timer-reset", {})
                    }
                }
            }
            Text {
                visible: !!DayState.error; Layout.fillWidth: true
                text: DayState.error; wrapMode: Text.Wrap
                color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 10
            }
        }
        MusicPanel {
            id: music
            width: pages.width; height: pages.height
            compact: true
            active: root.active && pages.currentIndex === 1
        }
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
                    console.info("Center preview gesture page", origin, pages.currentIndex, "pixels", root.scrollDistance);
                    root.scrollTriggered = true;
                }
            }
        }
    }
    SettingsRow {
        Layout.fillWidth: true; Layout.preferredHeight: 40
        symbol: BarState.centerPage === 0 ? "calendar" : "music"
        text: BarState.centerPage === 0 ? I18n.tr("center.open_panel") : I18n.tr("center.open_player")
        onClicked: root.expandRequested()
    }
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 34
        radius: 11; color: Glass.tint(Session.background, 0.45)
        RowLayout {
            anchors.fill: parent; anchors.margins: 4; spacing: 6
            BarButton {
                symbol: "chevron-left"; hint: I18n.tr("center.my_day"); implicitWidth: 26; implicitHeight: 26
                enabled: BarState.centerPage > 0
                onClicked: BarState.centerPage = 0
            }
            Item { Layout.fillWidth: true }
            Repeater {
                model: [I18n.tr("center.my_day"), I18n.tr("music.title")]
                Button {
                    id: tab
                    required property int index
                    required property string modelData
                    implicitWidth: 88; implicitHeight: 26; padding: 0; hoverEnabled: true
                    Accessible.name: modelData; Accessible.role: Accessible.PageTab
                    Accessible.selected: BarState.centerPage === index
                    background: Rectangle {
                        radius: 8
                        color: BarState.centerPage === tab.index ? Glass.tint(Session.accent, 0.18) : tab.hovered ? Glass.tint(Session.accent, 0.08) : "transparent"
                        border.width: tab.visualFocus ? 1 : 0; border.color: Session.accent
                    }
                    contentItem: Text {
                        text: tab.modelData; color: BarState.centerPage === tab.index ? Session.foreground : Session.muted
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        font.family: Session.fontFamily; font.pixelSize: 11
                    }
                    onClicked: BarState.centerPage = index
                }
            }
            Item { Layout.fillWidth: true }
            BarButton {
                symbol: "chevron-right"; hint: I18n.tr("music.title"); implicitWidth: 26; implicitHeight: 26
                enabled: BarState.centerPage === 0
                onClicked: BarState.centerPage = 1
            }
        }
    }
}
