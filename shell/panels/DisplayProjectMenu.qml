pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme" as PolyTheme

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root
    required property var modelData
    screen: modelData

    readonly property bool activeOnScreen: DisplayProjectState.opened && (!DisplayProjectState.screen || DisplayProjectState.screen === (modelData ? modelData.name : ""))

    anchors { top: true; bottom: true; right: true }
    width: 380
    color: "transparent"
    visible: motion.presented

    WlrLayershell.namespace: "poly-display-project"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.activeOnScreen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    PanelMotion {
        id: motion
        opened: root.activeOnScreen
        openDuration: Motion.openMs
        closeDuration: Motion.closeMs
    }

    // Dismiss on background click outside
    MouseArea {
        anchors.fill: parent
        onClicked: DisplayProjectState.close()
    }

    Item {
        id: panelContainer
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 344
        height: 520
        opacity: motion.progress
        transform: Translate {
            x: Motion.reduced ? 0 : (1 - motion.progress) * 48
        }

        SoftShadow {
            anchors.fill: parent
            cornerRadius: glass.radius
            spread: 8
            strength: Session.visual.panelShadow / 16
        }

        Rectangle {
            id: glass
            anchors.fill: parent
            radius: Math.min(24, Session.visual.panelRadius)
            border.width: Session.visual.panelBorder
            border.color: PolyTheme.Theme.withAlpha(Session.accent, 0.35)
            gradient: Gradient {
                GradientStop { position: 0; color: Glass.panelTop }
                GradientStop { position: 1; color: Glass.panelBottom }
            }

            // Keyboard navigation
            focus: true
            Keys.onEscapePressed: DisplayProjectState.close()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        spacing: 8
                        Rectangle {
                            width: 3; height: 16; radius: 1.5
                            color: Session.accent
                        }
                        Text {
                            text: I18n.tr("display_project.title").toUpperCase()
                            color: Session.foreground
                            font.family: Session.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                        }
                    }

                    Text {
                        Layout.leftMargin: 11
                        text: I18n.tr("display_project.subtitle")
                        color: Session.muted
                        font.family: Session.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                BarButton {
                    symbol: "close"
                    hint: I18n.tr("common.cancel")
                    onClicked: DisplayProjectState.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: PolyTheme.Theme.withAlpha(Session.muted, 0.20)
            }

            // Mode Selection List
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { mode: "internal", title: I18n.tr("display_project.pc_only"), desc: I18n.tr("display_project.pc_only_desc") },
                        { mode: "mirror",   title: I18n.tr("display_project.duplicate"), desc: I18n.tr("display_project.duplicate_desc") },
                        { mode: "extend",   title: I18n.tr("display_project.extend"), desc: I18n.tr("display_project.extend_desc") },
                        { mode: "external", title: I18n.tr("display_project.second_only"), desc: I18n.tr("display_project.second_only_desc") }
                    ]

                    Button {
                        id: card
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredHeight: 74
                        hoverEnabled: true
                        padding: 0
                        focusPolicy: Qt.NoFocus

                        readonly property bool isSelected: DisplayProjectState.currentMode === modelData.mode

                        background: Rectangle {
                            radius: Math.min(14, Session.visual.panelRadius)
                            color: card.isSelected
                                ? Glass.tint(Session.accent, 0.18)
                                : card.hovered
                                    ? Glass.tint(Session.accent, 0.08)
                                    : Glass.tint(Session.surface, 0.35)
                            border.width: card.isSelected ? 1.5 : 1
                            border.color: card.isSelected
                                ? Session.accent
                                : card.hovered
                                    ? Glass.tint(Session.accent, 0.35)
                                    : Glass.tint(Session.muted, 0.25)

                            Behavior on color { ColorAnimation { duration: Motion.responseMs } }
                            Behavior on border.color { ColorAnimation { duration: Motion.responseMs } }
                        }

                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 14
                            spacing: 12

                            // Custom Vector Visual Graphic
                            Item {
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 44

                                // 1. PC screen only
                                Item {
                                    anchors.fill: parent
                                    visible: card.modelData.mode === "internal"

                                    // Laptop (active)
                                    Rectangle {
                                        x: 4; y: 6; width: 28; height: 19; radius: 3
                                        color: Glass.tint(Session.accent, 0.25)
                                        border.width: 1.2; border.color: Session.accent
                                        Rectangle { anchors.centerIn: parent; width: 14; height: 8; radius: 1; color: Session.accent }
                                    }
                                    Rectangle {
                                        x: 0; y: 24; width: 36; height: 3; radius: 1.5
                                        color: Session.accent
                                    }

                                    // External Monitor (inactive/dim)
                                    Rectangle {
                                        x: 36; y: 4; width: 26; height: 20; radius: 3
                                        color: "transparent"
                                        border.width: 1; border.color: PolyTheme.Theme.withAlpha(Session.muted, 0.35)
                                    }
                                    Rectangle {
                                        x: 46; y: 24; width: 6; height: 4; radius: 1
                                        color: PolyTheme.Theme.withAlpha(Session.muted, 0.35)
                                    }
                                    Rectangle {
                                        x: 42; y: 27; width: 14; height: 2; radius: 1
                                        color: PolyTheme.Theme.withAlpha(Session.muted, 0.35)
                                    }
                                }

                                // 2. Duplicate
                                Item {
                                    anchors.fill: parent
                                    visible: card.modelData.mode === "mirror"

                                    // Laptop (active)
                                    Rectangle {
                                        x: 4; y: 6; width: 28; height: 19; radius: 3
                                        color: Glass.tint(Session.accent, 0.25)
                                        border.width: 1.2; border.color: Session.accent
                                        Rectangle { anchors.centerIn: parent; width: 12; height: 7; radius: 1; color: Session.accent }
                                    }
                                    Rectangle {
                                        x: 0; y: 24; width: 36; height: 3; radius: 1.5
                                        color: Session.accent
                                    }

                                    // External Monitor (active & mirrored)
                                    Rectangle {
                                        x: 36; y: 4; width: 26; height: 20; radius: 3
                                        color: Glass.tint(Session.accent, 0.25)
                                        border.width: 1.2; border.color: Session.accent
                                        Rectangle { anchors.centerIn: parent; width: 12; height: 7; radius: 1; color: Session.accent }
                                    }
                                    Rectangle {
                                        x: 46; y: 24; width: 6; height: 4; radius: 1
                                        color: Session.accent
                                    }
                                    Rectangle {
                                        x: 42; y: 27; width: 14; height: 2; radius: 1
                                        color: Session.accent
                                    }
                                }

                                // 3. Extend
                                Item {
                                    anchors.fill: parent
                                    visible: card.modelData.mode === "extend"

                                    // Laptop (active)
                                    Rectangle {
                                        x: 4; y: 6; width: 28; height: 19; radius: 3
                                        color: Glass.tint(Session.accent, 0.18)
                                        border.width: 1.2; border.color: Session.accent
                                        Rectangle { x: 3; y: 4; width: 10; height: 5; radius: 1; color: Session.accent }
                                    }
                                    Rectangle {
                                        x: 0; y: 24; width: 36; height: 3; radius: 1.5
                                        color: Session.accent
                                    }

                                    // Continuous bridge line spanning both displays
                                    Rectangle {
                                        x: 10; y: 15; width: 44; height: 2; radius: 1
                                        color: Session.accent
                                    }

                                    // External Monitor (extended)
                                    Rectangle {
                                        x: 36; y: 4; width: 26; height: 20; radius: 3
                                        color: Glass.tint(Session.accent, 0.18)
                                        border.width: 1.2; border.color: Session.accent
                                        Rectangle { x: 13; y: 4; width: 9; height: 5; radius: 1; color: Session.accent }
                                    }
                                    Rectangle {
                                        x: 46; y: 24; width: 6; height: 4; radius: 1
                                        color: Session.accent
                                    }
                                    Rectangle {
                                        x: 42; y: 27; width: 14; height: 2; radius: 1
                                        color: Session.accent
                                    }
                                }

                                // 4. Second screen only
                                Item {
                                    anchors.fill: parent
                                    visible: card.modelData.mode === "external"

                                    // Laptop (inactive/dim)
                                    Rectangle {
                                        x: 4; y: 6; width: 28; height: 19; radius: 3
                                        color: "transparent"
                                        border.width: 1; border.color: PolyTheme.Theme.withAlpha(Session.muted, 0.35)
                                    }
                                    Rectangle {
                                        x: 0; y: 24; width: 36; height: 3; radius: 1.5
                                        color: PolyTheme.Theme.withAlpha(Session.muted, 0.35)
                                    }

                                    // External Monitor (active & brilliant)
                                    Rectangle {
                                        x: 36; y: 4; width: 26; height: 20; radius: 3
                                        color: Glass.tint(Session.accent, 0.35)
                                        border.width: 1.4; border.color: Session.accent
                                        Rectangle { anchors.centerIn: parent; width: 16; height: 10; radius: 1.5; color: Session.accent }
                                    }
                                    Rectangle {
                                        x: 46; y: 24; width: 6; height: 4; radius: 1
                                        color: Session.accent
                                    }
                                    Rectangle {
                                        x: 42; y: 27; width: 14; height: 2; radius: 1
                                        color: Session.accent
                                    }
                                }
                            }

                            // Text details
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: card.modelData.title
                                    color: card.isSelected ? Session.foreground : PolyTheme.Theme.color("#d8dee9")
                                    font.family: Session.fontFamily
                                    font.pixelSize: 12
                                    font.weight: card.isSelected ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: card.modelData.desc
                                    color: Session.muted
                                    font.family: Session.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }

                            // Active check badge
                            Rectangle {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                radius: 10
                                color: card.isSelected ? Session.accent : "transparent"
                                border.width: card.isSelected ? 0 : 1
                                border.color: PolyTheme.Theme.withAlpha(Session.muted, 0.3)

                                Icon {
                                    anchors.centerIn: parent
                                    name: "check"
                                    width: 12; height: 12
                                    visible: card.isSelected
                                }
                            }
                        }

                        onClicked: DisplayProjectState.applyMode(modelData.mode)
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Bottom Notice / Status Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: 12
                color: Glass.tint(Session.surface, 0.50)
                border.width: 0.8
                border.color: PolyTheme.Theme.withAlpha(Session.accent, 0.20)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Icon {
                        name: DisplayProjectState.hasExternal ? "monitor" : "info"
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                    }

                    Text {
                        Layout.fillWidth: true
                        text: DisplayProjectState.hasExternal
                            ? I18n.tr("settings.monitors") + " (" + DisplayProjectState.monitors.length + ")"
                            : I18n.tr("display_project.no_external")
                        color: Session.muted
                        font.family: Session.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.preferredWidth: 54
                        Layout.preferredHeight: 22
                        radius: 6
                        color: Glass.tint(Session.accent, 0.15)
                        border.width: 0.6
                        border.color: Glass.tint(Session.accent, 0.3)

                        Text {
                            anchors.centerIn: parent
                            text: "Super+P"
                            color: Session.foreground
                            font.family: Session.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }
}
