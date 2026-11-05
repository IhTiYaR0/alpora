pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as PolyTheme

DesktopWidgetCard {
    id: root
    implicitWidth: 380
    implicitHeight: 200

    readonly property var events: (DayState.data && DayState.data.events) ? DayState.data.events : []
    readonly property var tasks: (DayState.data && DayState.data.tasks) ? DayState.data.tasks : []
    readonly property string dateString: Qt.formatDateTime(ClockState.date, "dddd, d MMMM")

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        // Header: Day title + task summary
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Icon {
                name: "calendar"
                width: 20
                height: 20
                color: Session.accent
            }

            Column {
                Layout.fillWidth: true
                Text {
                    text: root.dateString
                    color: Session.foreground
                    font.family: Session.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Text {
                    text: root.tasks.length > 0
                        ? I18n.trWith("day.tasks_pending", {count: root.tasks.filter(t => !t.done).length})
                        : I18n.tr("center.my_day")
                    color: Session.muted
                    font.family: Session.fontFamily
                    font.pixelSize: 10
                }
            }

            // Quick add / view button
            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: Glass.tint(Session.surface, 0.6)
                border.width: 1
                border.color: Glass.tint(Session.foreground, 0.12)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BarState.toggle("calendar", "")
                }

                Icon {
                    anchors.centerIn: parent
                    name: "chevron-right"
                    width: 12
                    height: 12
                    color: Session.foreground
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Glass.tint(Session.accent, 0.18)
        }

        // Body: Tasks & Events list
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: root.tasks.slice(0, 3)

            delegate: Rectangle {
                id: taskRow
                required property var modelData
                width: ListView.view.width
                height: 32
                radius: 6
                color: Glass.tint(Session.surface, 0.45)
                border.width: 1
                border.color: modelData.done ? Glass.tint(Session.foreground, 0.05) : Glass.tint(Session.foreground, 0.12)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    // Checkbox
                    Rectangle {
                        width: 16
                        height: 16
                        radius: 4
                        color: taskRow.modelData.done ? Session.accent : "transparent"
                        border.width: 1.2
                        border.color: taskRow.modelData.done ? Session.accent : Session.muted

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: DayState.request("task-toggle", {id: taskRow.modelData.id})
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: "check"
                            width: 10
                            height: 10
                            color: PolyTheme.Theme.color("#ffffff")
                            visible: taskRow.modelData.done
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: taskRow.modelData.title || ""
                        color: taskRow.modelData.done ? Session.muted : Session.foreground
                        font.family: Session.fontFamily
                        font.pixelSize: 11
                        font.strikeout: taskRow.modelData.done
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Empty state when no tasks
        Text {
            visible: root.tasks.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: I18n.tr("common.all_saved")
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Session.muted
            font.family: Session.fontFamily
            font.pixelSize: 11
        }
    }
}

