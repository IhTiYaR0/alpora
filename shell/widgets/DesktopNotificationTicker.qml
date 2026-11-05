pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as PolyTheme

DesktopWidgetCard {
    id: root
    implicitWidth: 360
    implicitHeight: 140

    readonly property var notifications: BarState.notifications || []
    readonly property bool hasItems: notifications.length > 0

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        // Header: Ticker title + DND switch
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Icon {
                name: BarState.dnd ? "bell-muted" : "bell"
                width: 16
                height: 16
                color: BarState.dnd ? Session.muted : Session.accent
            }

            Text {
                text: I18n.tr("popup.notifications")
                color: Session.foreground
                font.family: Session.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Rectangle {
                visible: root.hasItems
                width: 18; height: 16; radius: 8
                color: Session.accent
                Text {
                    anchors.centerIn: parent
                    text: root.notifications.length.toString()
                    color: PolyTheme.Theme.color("#ffffff")
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }
            }

            Item { Layout.fillWidth: true }

            // DND Quick Toggle
            Rectangle {
                width: 54; height: 22; radius: 11
                color: BarState.dnd ? Glass.tint(Session.accent, 0.45) : Glass.tint(Session.surface, 0.6)
                border.width: 1
                border.color: BarState.dnd ? Session.accent : Glass.tint(Session.foreground, 0.12)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BarState.toggleDnd()
                }

                Text {
                    anchors.centerIn: parent
                    text: BarState.dnd ? "DND ON" : "DND"
                    color: BarState.dnd ? Session.foreground : Session.muted
                    font.family: Session.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Medium
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Glass.tint(Session.accent, 0.15)
        }

        // Body: Latest notification preview
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // When there are notifications
            ColumnLayout {
                anchors.fill: parent
                visible: root.hasItems
                spacing: 4

                Repeater {
                    model: root.notifications.slice(0, 1)
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: Glass.tint(Session.surface, 0.4)
                        border.width: 1
                        border.color: Glass.tint(Session.foreground, 0.1)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.appName || modelData.summary || "Notification"
                                    color: Session.foreground
                                    font.family: Session.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.body || modelData.summary || ""
                                    color: Session.muted
                                    font.family: Session.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }

                            // Dismiss button
                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: Glass.tint(Session.surface, 0.6)
                                border.width: 1; border.color: Glass.tint(Session.foreground, 0.1)

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: BarState.dismissNotification(modelData.id)
                                }

                                Icon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    width: 10; height: 10
                                    color: Session.muted
                                }
                            }
                        }
                    }
                }
            }

            // Quiet state
            Text {
                anchors.centerIn: parent
                visible: !root.hasItems
                text: I18n.tr("notification.all_quiet")
                color: Session.muted
                font.family: Session.fontFamily
                font.pixelSize: 11
            }
        }
    }
}

