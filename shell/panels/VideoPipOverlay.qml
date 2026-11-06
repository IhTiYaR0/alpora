pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme" as PolyTheme

PanelWindow {
    id: pipWindow
    required property var modelData
    screen: modelData

    anchors {
        top: false
        bottom: true
        left: false
        right: true
    }
    margins {
        bottom: 40
        right: 24
    }

    width: Math.max(280, Math.min(800, VideoPipState.pipWidth))
    height: Math.max(180, Math.min(900, VideoPipState.pipHeight))
    color: "transparent"
    visible: VideoPipState.open && (VideoPipState.activeScreen === "" || VideoPipState.activeScreen === (modelData ? modelData.name : ""))

    WlrLayershell.namespace: "poly-video-pip"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Main Card Surface
    Rectangle {
        id: card
        anchors.fill: parent
        radius: Math.min(20, Session.visual.panelRadius)
        color: Glass.tint(Session.surface, VideoPipState.opacityLevel * 0.92)
        border.width: Session.visual.panelBorder
        border.color: Glass.tint(Session.accent, 0.35)
        clip: true

        Behavior on color { ColorAnimation { duration: Motion.responseMs } }
        Behavior on border.color { ColorAnimation { duration: Motion.responseMs } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // 1. Header & Controls
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Icon {
                    name: "video"
                    width: 18
                    height: 18
                    color: Session.accent
                }

                Text {
                    text: "Video PiP"
                    color: Session.foreground
                    font.family: Session.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                Item { Layout.fillWidth: true }

                // Aspect Ratio Toggle: 9:16 (Shorts/TikTok) <-> 16:9 (YouTube)
                Rectangle {
                    width: 62
                    height: 24
                    radius: 12
                    color: Glass.tint(Session.surface, 0.6)
                    border.width: 1
                    border.color: Glass.tint(Session.foreground, 0.15)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: VideoPipState.toggleMode()
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Icon {
                            name: VideoPipState.mode === "vertical" ? "devices" : "monitor"
                            width: 12
                            height: 12
                            color: Session.foreground
                        }
                        Text {
                            text: VideoPipState.mode === "vertical" ? "9:16" : "16:9"
                            color: Session.foreground
                            font.family: Session.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }
                }

                // Size Presets: S, M, L
                Row {
                    spacing: 3
                    Repeater {
                        model: ["S", "M", "L"]
                        Rectangle {
                            required property string modelData
                            width: 20
                            height: 24
                            radius: 4
                            color: Glass.tint(Session.surface, 0.5)
                            border.width: 1
                            border.color: Glass.tint(Session.foreground, 0.1)

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: VideoPipState.setSizePreset(modelData)
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: Session.muted
                                font.family: Session.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }
                    }
                }

                // Launch external floating browser window
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: Glass.tint(Session.surface, 0.5)
                    border.width: 1
                    border.color: Glass.tint(Session.foreground, 0.12)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: VideoPipState.launchFloatingWindow()
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: "window"
                        width: 12
                        height: 12
                        color: Session.foreground
                    }
                }

                // Close Button
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: Glass.tint(Session.surface, 0.5)
                    border.width: 1
                    border.color: Glass.tint(Session.foreground, 0.12)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: VideoPipState.close()
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: "close"
                        width: 12
                        height: 12
                        color: Session.foreground
                    }
                }
            }

            // 2. Platform Selector Pills
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { key: "tiktok", label: "TikTok", icon: "video", mode: "vertical" },
                        { key: "shorts", label: "Shorts", icon: "pip", mode: "vertical" },
                        { key: "youtube", label: "YouTube", icon: "play-dark", mode: "landscape" }
                    ]

                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        height: 28
                        radius: 8
                        color: VideoPipState.targetApp === modelData.key
                            ? Glass.tint(Session.accent, 0.35)
                            : Glass.tint(Session.surface, 0.5)
                        border.width: 1
                        border.color: VideoPipState.targetApp === modelData.key
                            ? Session.accent
                            : Glass.tint(Session.foreground, 0.12)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: VideoPipState.openApp(modelData.key)
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Icon {
                                name: modelData.icon
                                width: 13
                                height: 13
                                color: VideoPipState.targetApp === modelData.key ? Session.foreground : Session.muted
                            }
                            Text {
                                text: modelData.label
                                color: VideoPipState.targetApp === modelData.key ? Session.foreground : Session.muted
                                font.family: Session.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }

            // 3. Central Media / Video Area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: Glass.tint(Session.background, 0.6)
                border.width: 1
                border.color: Glass.tint(Session.foreground, 0.08)
                clip: true

                // A. When media is playing
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    visible: VideoPipState.hasMedia

                    // Thumbnail / Art
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: Glass.tint(Session.surface, 0.4)
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: VideoPipState.player ? VideoPipState.player.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: "video"
                            width: 36
                            height: 36
                            color: Session.muted
                            visible: !VideoPipState.player || !VideoPipState.player.trackArtUrl
                        }
                    }

                    // Title & Artist
                    Text {
                        Layout.fillWidth: true
                        text: VideoPipState.player && VideoPipState.player.trackTitle ? VideoPipState.player.trackTitle : "Video Stream"
                        color: Session.foreground
                        font.family: Session.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: VideoPipState.player && VideoPipState.player.trackArtist ? VideoPipState.player.trackArtist : VideoPipState.targetApp.toUpperCase()
                        color: Session.muted
                        font.family: Session.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    // Playback Controls
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // -10s
                        Rectangle {
                            width: 30; height: 30; radius: 15
                            color: Glass.tint(Session.surface, 0.6)
                            border.width: 1; border.color: Glass.tint(Session.foreground, 0.1)
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (VideoPipState.player && VideoPipState.player.canSeek) VideoPipState.player.position -= 10
                            }
                            Text { anchors.centerIn: parent; text: "-10s"; color: Session.foreground; font.pixelSize: 9 }
                        }

                        // Play/Pause
                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: 15
                            color: Session.accent

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (VideoPipState.player) VideoPipState.player.togglePlaying()
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 5
                                Icon {
                                    name: VideoPipState.player && VideoPipState.player.isPlaying ? "pause-dark" : "play-dark"
                                    width: 14
                                    height: 14
                                    color: PolyTheme.Theme.color("#ffffff")
                                }
                                Text {
                                    text: VideoPipState.player && VideoPipState.player.isPlaying ? "Pause" : "Play"
                                    color: PolyTheme.Theme.color("#ffffff")
                                    font.family: Session.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        // +10s
                        Rectangle {
                            width: 30; height: 30; radius: 15
                            color: Glass.tint(Session.surface, 0.6)
                            border.width: 1; border.color: Glass.tint(Session.foreground, 0.1)
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (VideoPipState.player && VideoPipState.player.canSeek) VideoPipState.player.position += 10
                            }
                            Text { anchors.centerIn: parent; text: "+10s"; color: Session.foreground; font.pixelSize: 9 }
                        }
                    }
                }

                // B. Empty State / Quick Launch prompt
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    width: parent.width - 32
                    visible: !VideoPipState.hasMedia

                    Icon {
                        Layout.alignment: Qt.AlignHCenter
                        name: "video"
                        width: 42
                        height: 42
                        color: Session.accent
                    }

                    Text {
                        Layout.fillWidth: true
                        text: I18n.trWith("pip.browse_hint", {app: (VideoPipState.targetApp === "tiktok" ? "TikTok" : (VideoPipState.targetApp === "shorts" ? "YouTube Shorts" : "YouTube"))})
                        horizontalAlignment: Text.AlignHCenter
                        color: Session.foreground
                        font.family: Session.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: I18n.tr("pip.window_hint")
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: Session.muted
                        font.family: Session.fontFamily
                        font.pixelSize: 11
                        lineHeight: 1.3
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 160
                        Layout.preferredHeight: 34
                        radius: 17
                        color: Session.accent

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: VideoPipState.launchFloatingWindow()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: I18n.tr("pip.launch_window")
                            color: Session.background
                            font.family: Session.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            // 4. Footer & Drag Resize Grip
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: Math.round(pipWindow.width) + " × " + Math.round(pipWindow.height) + " px"
                    color: Session.muted
                    font.family: Session.fontFamily
                    font.pixelSize: 10
                }

                Item { Layout.fillWidth: true }

                // Interactive Corner Resize Grip Handle
                Rectangle {
                    width: 18
                    height: 18
                    radius: 4
                    color: Glass.tint(Session.foreground, 0.12)

                    MouseArea {
                        id: resizeHandle
                        anchors.fill: parent
                        cursorShape: Qt.SizeFDiagCursor
                        property real startX: 0
                        property real startY: 0
                        property real startW: 0
                        property real startH: 0

                        onPressed: mouse => {
                            startX = mouse.x;
                            startY = mouse.y;
                            startW = VideoPipState.pipWidth;
                            startH = VideoPipState.pipHeight;
                        }

                        onPositionChanged: mouse => {
                            if (pressed) {
                                const dx = mouse.x - startX;
                                const dy = mouse.y - startY;
                                VideoPipState.pipWidth = Math.max(260, Math.min(800, startW + dx));
                                VideoPipState.pipHeight = Math.max(160, Math.min(900, startH + dy));
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "◢"
                        color: Session.muted
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
}

