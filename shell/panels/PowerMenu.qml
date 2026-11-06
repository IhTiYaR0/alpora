pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: powerWindow
    required property var modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore; exclusiveZone: 0
    color: "transparent"
    visible: PowerState.active && (PowerState.targetScreen === "" || PowerState.targetScreen === (modelData ? modelData.name : ""))
    WlrLayershell.namespace: "poly-power-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible) focusScope.forceActiveFocus();
    }

    Item {
        id: focusScope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: PowerState.close()
        Keys.onPressed: event => {
            const k = event.text.toLowerCase();
            if (k === "l") PowerState.execute("lock");
            else if (k === "u" || k === "s") PowerState.execute("suspend");
            else if (k === "r") PowerState.execute("reboot");
            else if (k === "p") PowerState.execute("poweroff");
            else if (k === "e") PowerState.execute("logout");
        }

        // Darkened backdrop
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.45
            MouseArea {
                anchors.fill: parent
                onClicked: PowerState.close()
            }
        }

        // Centered modal dialog
        Item {
            anchors.centerIn: parent
            width: Math.min(680, parent.width - 40)
            height: 270

            SoftShadow {
                anchors.fill: parent
                cornerRadius: 22
                spread: 16
            }

            Rectangle {
                anchors.fill: parent
                radius: 22
                color: Glass.tint(Session.surface, 0.94)
                border.color: Glass.tint(Session.accent, 0.6)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 20

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: I18n.tr("power.title")
                            color: Session.foreground
                            font.family: Session.fontFamily
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        Text {
                            text: I18n.tr("common.esc_to_cancel")
                            color: Session.muted
                            font.family: Session.fontFamily
                            font.pixelSize: 12
                        }
                    }

                    // Action tiles row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        Repeater {
                            model: [
                                { action: "lock", label: I18n.tr("power.lock"), icon: "lock", key: "L" },
                                { action: "suspend", label: I18n.tr("power.suspend"), icon: "moon", key: "U" },
                                { action: "reboot", label: I18n.tr("power.reboot"), icon: "refresh", key: "R" },
                                { action: "poweroff", label: I18n.tr("power.poweroff"), icon: "power", key: "P" },
                                { action: "logout", label: I18n.tr("power.logout"), icon: "arrow-right", key: "E" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 14
                                color: tileHover.containsMouse ? Glass.tint(Session.accent, 0.18) : Glass.tint(Session.background, 0.5)
                                border.color: tileHover.containsMouse ? Session.accent : Glass.tint(Session.foreground, 0.1)
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: Motion.responseMs } }
                                Behavior on border.color { ColorAnimation { duration: Motion.responseMs } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Icon {
                                        name: modelData.icon
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                    }

                                    Text {
                                        text: modelData.label
                                        color: Session.foreground
                                        font.family: Session.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 22
                                        height: 18
                                        radius: 4
                                        color: Glass.tint(Session.foreground, 0.12)
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.key
                                            color: Session.muted
                                            font.family: Session.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                        }
                                    }
                                }

                                MouseArea {
                                    id: tileHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: PowerState.execute(modelData.action)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
