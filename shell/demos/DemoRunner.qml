//@ pragma AppId alpora-demo-runner
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QSG_USE_SIMPLE_ANIMATION_DRIVER=1
//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../theme" as PolyTheme
import "../controls"
import "../widgets"

ShellRoot {
    id: root
    property string activeTheme: Session.appearance.id || "alpine"
    property int currentSpeed: 1
    property real animationProgress: 0
    property string activeStudy: "slide"

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: demoWindow
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "alpora-demo-runner"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            Shortcut {
                sequence: "Escape"
                onActivated: Qt.quit()
            }

            Rectangle {
                anchors.fill: parent
                color: "#99000000"

                MouseArea {
                    anchors.fill: parent
                    onClicked: Qt.quit()
                }

                // Centered Sandbox Card
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(1060, parent.width - 40)
                    height: Math.min(680, parent.height - 40)
                    radius: 20
                    color: Session.surface
                    border.width: 1
                    border.color: Glass.tint(Session.accent, 0.25)
                    clip: true

                    MouseArea { anchors.fill: parent } // Prevent backdrop close

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 16

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: 10
                                color: Glass.tint(Session.accent, 0.18)
                                Text {
                                    anchors.centerIn: parent
                                    text: "ALP"
                                    color: Session.accent
                                    font.family: Session.monoFontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "ALPORA Native Motion & Shell Sandbox"
                                    color: Session.foreground
                                    font.family: Session.displayFontFamily
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                }
                                Text {
                                    text: "Native Qt6/Quickshell Wayland environment · Press Esc to exit"
                                    color: Session.muted
                                    font.family: Session.fontFamily
                                    font.pixelSize: 11
                                }
                            }

                            Button {
                                text: "Đóng [Esc]"
                                onClicked: Qt.quit()
                            }
                        }

                        // Main Preview Deck
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 18

                            // Left Column: Interactive Widget & Canvas
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 16
                                color: Session.background
                                border.width: 1
                                border.color: Glass.tint(Session.accent, 0.12)
                                clip: true

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 20

                                    // Clock Digit Preview
                                    Row {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 8
                                        ClockDigit { value: "1"; pixelSize: 48 }
                                        ClockDigit { value: "4"; pixelSize: 48 }
                                        Text { text: ":"; color: Session.accent; font.pixelSize: 42; font.family: Session.displayFontFamily }
                                        ClockDigit { value: "2"; pixelSize: 48 }
                                        ClockDigit { value: "0"; pixelSize: 48 }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "Font Display: " + Session.displayFontFamily + " · UI: " + Session.fontFamily
                                        color: Session.muted
                                        font.family: Session.monoFontFamily
                                        font.pixelSize: 10
                                    }

                                    // Animated Test Target Panel
                                    Rectangle {
                                        id: targetPanel
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 280
                                        height: 140
                                        radius: 14
                                        color: Glass.tint(Session.surface, 0.9)
                                        border.width: 1
                                        border.color: Glass.tint(Session.accent, 0.3)
                                        opacity: root.animationProgress
                                        transform: [
                                            Translate { y: (1 - root.animationProgress) * (root.activeStudy === "spring" ? -40 : -20) },
                                            Scale {
                                                x: root.activeStudy === "pop" ? (0.9 + 0.1 * root.animationProgress) : 1
                                                y: root.activeStudy === "pop" ? (0.9 + 0.1 * root.animationProgress) : 1
                                            }
                                        ]

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Text {
                                                text: "Motion: " + root.activeStudy.toUpperCase()
                                                color: Session.foreground
                                                font.family: Session.displayFontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                            }
                                            Text {
                                                text: "Progress: " + Math.round(root.animationProgress * 100) + "%"
                                                color: Session.accent
                                                font.family: Session.monoFontFamily
                                                font.pixelSize: 11
                                            }
                                        }
                                    }
                                }
                            }

                            // Right Column: Study Selection Grid
                            Rectangle {
                                Layout.preferredWidth: 320
                                Layout.fillHeight: true
                                radius: 16
                                color: Glass.tint(Session.background, 0.5)
                                border.width: 1
                                border.color: Glass.tint(Session.accent, 0.1)
                                clip: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 8

                                    Text {
                                        text: "Chọn hiệu ứng chuyển động:"
                                        color: Session.foreground
                                        font.family: Session.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }

                                    ScrollView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Flow {
                                            width: parent.width
                                            spacing: 6

                                            Repeater {
                                                model: [
                                                    "slide", "curtain", "origin", "pop",
                                                    "spring", "morph", "center", "iris",
                                                    "depth", "hinge", "fold", "liquid",
                                                    "outline", "cascade", "slit", "travel"
                                                ]

                                                delegate: Button {
                                                    required property string modelData
                                                    text: modelData
                                                    highlighted: root.activeStudy === modelData
                                                    onClicked: {
                                                        root.activeStudy = modelData
                                                        animRunner.restart()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Button {
                                        Layout.fillWidth: true
                                        text: "↻ Chạy thử lại"
                                        onClicked: animRunner.restart()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            NumberAnimation {
                id: animRunner
                target: root
                property: "animationProgress"
                from: 0
                to: 1
                duration: root.activeStudy === "spring" ? 720 : 540
                easing.type: root.activeStudy === "spring" ? Easing.OutBack : Easing.OutCubic
                running: true
            }
        }
    }
}

