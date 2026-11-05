pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: root
    spacing: 10
    property real expansion: 1
    property string page: "main"
    property string editing: ""
    property string localError: ""
    property bool waitingForAdd: false
    readonly property date selectedDate: calendar.selected
    readonly property var events: DayState.events(selectedDate)
    readonly property var tasks: DayState.tasks(selectedDate)
    function add(kind: string): void {
        editing = kind; page = "add"; titleField.text = ""; timeField.text = "09:00"; localError = "";
        Qt.callLater(() => titleField.forceActiveFocus());
    }
    function submit(): void {
        if (!titleField.text.trim()) { localError = I18n.tr("day.enter_title"); return; }
        if (editing === "event" && !/^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(timeField.text)) { localError = I18n.tr("day.enter_time_format"); return; }
        waitingForAdd = true;
        DayState.request(editing === "event" ? "event-add" : "task-add", {date: DayState.dateKey(selectedDate), title: titleField.text.trim(), time: timeField.text});
    }
    function openNote(): void { noteField.text = DayState.data.note; page = "note"; }
    Connections {
        target: DayState
        function onSaved(action): void {
            if (root.waitingForAdd && ["event-add", "task-add"].includes(action)) { root.waitingForAdd = false; root.page = "main"; }
        }
        function onErrorChanged(): void { if (DayState.error) root.waitingForAdd = false; }
    }
    PanelHeader {
        title: root.page === "main" ? I18n.tr("day.my_day") : (root.page === "note" ? I18n.tr("day.note") : (root.editing === "event" ? I18n.tr("day.new_event") : I18n.tr("day.new_task")))
        subtitle: root.selectedDate.toLocaleDateString(I18n.qtLocale, "dddd, d MMMM")
    }
    Text { visible: text.length > 0; Layout.fillWidth: true; text: root.localError || DayState.error; color: PolyTheme.Theme.color("#e2af95"); wrapMode: Text.Wrap; font.family: Session.fontFamily; font.pixelSize: 11 }
    RowLayout {
        visible: root.page === "main"
        Layout.fillWidth: true; Layout.fillHeight: true
        Layout.preferredHeight: 80 + 220 * root.expansion
        Layout.minimumHeight: 70 + 200 * root.expansion
        spacing: 10 * root.expansion
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.preferredWidth: 0.94
            radius: 13; color: Glass.tint(PolyTheme.Theme.color("#20282a"), 0.4); border.width: 0.7; border.color: PolyTheme.Theme.color("#36423c")
            CalendarCard {
                id: calendar
                anchors.fill: parent; anchors.margins: 12
                compact: true; showFooter: false; expansion: root.expansion
            }
        }
        ColumnLayout {
            visible: root.expansion > 0
            clip: true
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 0
            Layout.preferredWidth: 1.06 * root.expansion
            spacing: 10
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.preferredHeight: 1
                radius: 13; color: Glass.tint(PolyTheme.Theme.color("#222a2c"), 0.4); border.width: 0.7; border.color: PolyTheme.Theme.color("#36423c")
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Rectangle { implicitWidth: 3; implicitHeight: 14; radius: 2; color: PolyTheme.Theme.color("#c4a282") }
                        Text { Layout.fillWidth: true; text: Qt.formatDateTime(root.selectedDate, "yyyy-MM-dd") === Qt.formatDateTime(ClockState.date, "yyyy-MM-dd") ? I18n.tr("day.today") : root.selectedDate.toLocaleDateString(I18n.qtLocale, "d MMMM"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12 }
                        BarButton { symbol: "plus"; hint: I18n.tr("day.add_event"); implicitWidth: 24; implicitHeight: 24; onClicked: root.add("event") }
                    }
                    ScrollView {
                        Layout.fillWidth: true; Layout.fillHeight: true; contentWidth: availableWidth; clip: true
                        Column {
                            width: parent.width; spacing: 6
                            Text { visible: root.events.length === 0; width: parent.width; text: I18n.tr("day.no_events"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; lineHeight: 1.5 }
                            Repeater {
                                model: root.events
                                Rectangle {
                                    id: event
                                    required property var modelData
                                    width: parent.width; height: 42; radius: 9; color: Glass.tint(PolyTheme.Theme.color("#2d3634"), 0.5)
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 7; spacing: 7
                                        Text { text: event.modelData.time; color: PolyTheme.Theme.color("#d0b293"); font.family: Session.fontFamily; font.pixelSize: 11 }
                                        Rectangle { implicitWidth: 1; implicitHeight: 20; color: PolyTheme.Theme.color("#74634e") }
                                        Text { Layout.fillWidth: true; text: event.modelData.title; textFormat: Text.PlainText; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11; elide: Text.ElideRight }
                                        BarButton { symbol: "close"; hint: I18n.tr("day.remove_event"); implicitWidth: 22; implicitHeight: 24; onClicked: DayState.request("item-remove", {id: event.modelData.id}) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.preferredHeight: 1
                radius: 13; color: Glass.tint(PolyTheme.Theme.color("#222a2c"), 0.4); border.width: 0.7; border.color: PolyTheme.Theme.color("#36423c")
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Rectangle { implicitWidth: 3; implicitHeight: 14; radius: 2; color: PolyTheme.Theme.color("#9eaf8e") }
                        Text { Layout.fillWidth: true; text: I18n.tr("day.tasks"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12 }
                        BarButton { symbol: "plus"; hint: I18n.tr("day.add_task"); implicitWidth: 24; implicitHeight: 24; onClicked: root.add("task") }
                    }
                    ScrollView {
                        Layout.fillWidth: true; Layout.fillHeight: true; contentWidth: availableWidth; clip: true
                        Column {
                            width: parent.width; spacing: 6
                            Text { visible: root.tasks.length === 0; width: parent.width; text: I18n.tr("day.no_tasks"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; lineHeight: 1.5; wrapMode: Text.Wrap }
                            Repeater {
                                model: root.tasks
                                Rectangle {
                                    id: task
                                    required property var modelData
                                    width: parent.width; height: 36; radius: 9; color: Glass.tint(PolyTheme.Theme.color("#2d3634"), 0.5)
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 4; spacing: 3
                                        CheckBox {
                                            id: checkbox
                                            checked: task.modelData.done
                                            Accessible.name: task.modelData.title
                                            implicitWidth: 26; implicitHeight: 28; padding: 0
                                            indicator: Rectangle {
                                                x: 5; y: 6; width: 16; height: 16; radius: 4
                                                color: checkbox.checked ? PolyTheme.Theme.color("#a4b594") : "transparent"
                                                border.width: 1; border.color: checkbox.visualFocus || checkbox.hovered ? PolyTheme.Theme.color("#d1ddc1") : PolyTheme.Theme.color("#879581")
                                                Icon { visible: checkbox.checked; anchors.centerIn: parent; name: "check"; width: 12; height: 12 }
                                            }
                                            onClicked: DayState.request("task-toggle", {id: task.modelData.id})
                                        }
                                        Text { Layout.fillWidth: true; text: task.modelData.title; textFormat: Text.PlainText; color: task.modelData.done ? Session.muted : Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11; font.strikeout: task.modelData.done; elide: Text.ElideRight }
                                        BarButton { symbol: "close"; hint: I18n.tr("day.remove_task"); implicitWidth: 22; implicitHeight: 24; onClicked: DayState.request("item-remove", {id: task.modelData.id}) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    RowLayout {
        visible: root.page === "main"
        Layout.fillWidth: true; Layout.fillHeight: false
        Layout.preferredHeight: 56 + 60 * root.expansion; Layout.maximumHeight: 56 + 60 * root.expansion
        spacing: 10 * root.expansion
        FocusCard {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
            expansion: root.expansion
        }
        Rectangle {
            visible: root.expansion > 0; clip: true
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 0; Layout.preferredWidth: root.expansion
            radius: 13; color: Glass.tint(PolyTheme.Theme.color("#242d2d"), 0.4); border.width: 0.7; border.color: PolyTheme.Theme.color("#36423c")
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 7
                Text { text: I18n.tr("quick.quick_access"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12 }
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                    Repeater {
                        model: [{name: I18n.tr("day.notes"), icon: "note", action: "note"}, {name: I18n.tr("day.files"), icon: "folder", action: "files"}, {name: I18n.tr("day.terminal"), icon: "terminal", action: "terminal"}]
                        Button {
                            id: shortcut
                            required property var modelData
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Layout.preferredWidth: 1; Layout.minimumWidth: 0
                            hoverEnabled: true; padding: 3
                            Accessible.name: modelData.name
                            background: Rectangle {
                                radius: 10; color: shortcut.hovered || shortcut.visualFocus ? PolyTheme.Theme.color("#3b4840") : PolyTheme.Theme.color("#2b3534")
                                border.width: 0.7; border.color: shortcut.visualFocus ? PolyTheme.Theme.color("#a4b594") : PolyTheme.Theme.color("#3c4941")
                                Behavior on color { ColorAnimation { duration: Session.settings.reducedMotion ? 0 : 140 } }
                            }
                            contentItem: Column {
                                spacing: 5
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: shortcut.modelData.icon; width: 24; height: 24 }
                                Text { width: parent.width; text: shortcut.modelData.name; horizontalAlignment: Text.AlignHCenter; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 9 }
                            }
                            onClicked: {
                                if (modelData.action === "note") root.openNote();
                                else {
                                    BarState.close();
                                    if (modelData.action === "terminal") Session.launch("terminal");
                                    else Quickshell.execDetached(["xdg-open", Quickshell.env("HOME")]);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    ColumnLayout {
        visible: root.page === "add"
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
        Text { text: I18n.tr("day.date_prefix") + " " + root.selectedDate.toLocaleDateString(I18n.qtLocale, "d MMMM yyyy"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 12 }
        DayField { id: titleField; Layout.fillWidth: true; placeholderText: root.editing === "event" ? I18n.tr("day.event_name_placeholder") : I18n.tr("day.task_name_placeholder"); maximumLength: 200; onAccepted: root.submit(); Accessible.name: I18n.tr("day.title_field") }
        DayField { id: timeField; visible: root.editing === "event"; Layout.preferredWidth: 120; placeholderText: "09:30"; maximumLength: 5; onAccepted: root.submit(); Accessible.name: I18n.tr("day.time_field") }
        RowLayout {
            DayAction { text: I18n.tr("common.add"); primary: true; enabled: !root.waitingForAdd && DayState.loaded; onClicked: root.submit() }
            DayAction { text: I18n.tr("common.cancel"); onClicked: { root.page = "main"; root.localError = ""; } }
        }
        Item { Layout.fillHeight: true }
    }
    ColumnLayout {
        visible: root.page === "note"
        Layout.fillWidth: true; Layout.fillHeight: true
        ScrollView {
            Layout.fillWidth: true; Layout.fillHeight: true
            TextArea {
                id: noteField
                placeholderText: I18n.tr("day.note_placeholder")
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                textFormat: TextEdit.PlainText
                color: Session.foreground; placeholderTextColor: PolyTheme.Theme.color("#95a197")
                selectionColor: PolyTheme.Theme.color("#697d5d"); selectedTextColor: PolyTheme.Theme.color("#f0f3e9")
                font.family: Session.fontFamily; font.pixelSize: 12; padding: 12
                background: Rectangle { radius: 12; color: Glass.tint(PolyTheme.Theme.color("#20292a"), 0.45); border.width: 0.7; border.color: PolyTheme.Theme.color("#455249") }
                Accessible.name: I18n.tr("day.note")
                onTextChanged: if (root.page === "note" && text !== DayState.data.note) noteDebounce.restart()
            }
        }
        RowLayout {
            DayAction { text: I18n.tr("common.back"); onClicked: { if (noteField.text !== DayState.data.note) DayState.request("note", {text: noteField.text}); root.page = "main"; } }
            Text { text: DayState.error ? I18n.tr("day.save_error") : (noteField.text === DayState.data.note ? I18n.tr("day.saved") : I18n.tr("common.saving")); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11 }
        }
    }
    Timer { id: noteDebounce; interval: 600; onTriggered: DayState.request("note", {text: noteField.text}) }
}
