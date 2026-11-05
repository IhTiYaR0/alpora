pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../theme" as PolyTheme

Item {
    id: root
    readonly property var player: MusicState.player
    readonly property bool isOsd: OsdState.opened
    readonly property bool hasMedia: !!player && (player.isPlaying || (player.trackTitle && player.trackTitle.length > 0))
    readonly property bool isPlaying: !!player && player.isPlaying
    readonly property string trackTitle: player && player.trackTitle ? player.trackTitle : ""
    readonly property string trackArtist: player && player.trackArtist ? player.trackArtist : ""
    readonly property string displayTitle: trackTitle.length > 0
        ? (trackTitle + (trackArtist.length > 0 ? " · " + trackArtist : ""))
        : I18n.tr("music.untitled")

    readonly property bool active: isOsd || hasMedia
    visible: active
    implicitHeight: 28
    implicitWidth: isOsd ? 172 : (hasMedia ? Math.min(230, Math.max(88, contentLayout.implicitWidth + 20)) : 0)

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Motion.reduced ? 0 : 260
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.reduced ? 0 : 200
        }
    }
    opacity: active ? 1 : 0

    property real playbackPulse: 0
    Timer {
        interval: 80
        repeat: true
        running: !root.isOsd && root.hasMedia && root.isPlaying && root.visible && root.opacity > 0 && !ClockState.sleeping
        onTriggered: root.playbackPulse += 0.12
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: Math.min(14, Session.visual.barRadius)
        color: Glass.tint(Session.surface, root.isOsd ? 0.85 : (mouseArea.containsMouse ? 0.70 : 0.45))
        border.width: Session.visual.barBorder
        border.color: root.isOsd
            ? Glass.tint(Session.accent, 0.65)
            : (mouseArea.containsMouse ? Glass.tint(Session.accent, 0.42) : Glass.tint(Session.foreground, 0.08))

        Behavior on color { ColorAnimation { duration: Motion.responseMs } }
        Behavior on border.color { ColorAnimation { duration: Motion.responseMs } }

        // Dynamic Island / Smart Pill: OSD Mode (Volume / Brightness / Capslock / Mic)
        Row {
            id: osdLayout
            anchors.centerIn: parent
            spacing: 8
            height: parent.height
            visible: root.isOsd

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                name: OsdState.symbol
            }

            Text {
                visible: OsdState.isToggle
                anchors.verticalCenter: parent.verticalCenter
                text: OsdState.title + (OsdState.value > 0 ? " ON" : " OFF")
                color: Session.foreground
                font.family: Session.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            Row {
                visible: !OsdState.isToggle
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 70
                    height: 5
                    radius: 2.5
                    color: Glass.tint(Session.foreground, 0.18)
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: Math.min(parent.width, Math.max(0, parent.width * Math.min(1.0, OsdState.value)))
                        height: parent.height
                        radius: parent.radius
                        color: Session.accent
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(OsdState.value * 100) + "%"
                    color: Session.foreground
                    font.family: Session.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
            }
        }

        // Media Playback Mode (Visualizer Waveform + Title + Controls)
        Row {
            id: contentLayout
            anchors.centerIn: parent
            spacing: 8
            height: parent.height
            visible: !root.isOsd && root.hasMedia

            // 1. Audio Visualizer Wave (dải sóng âm thanh nhỏ)
            Item {
                id: waveBox
                width: 34
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                MusicWaveform {
                    anchors.fill: parent
                    phase: root.playbackPulse
                    progress: root.isPlaying ? 1.0 : 0.0
                    hasTrack: root.hasMedia
                    playing: root.isPlaying
                    animated: !Motion.reduced
                    playedColor: Session.accent
                    remainingColor: Session.muted
                }
            }

            // 2. Marquee / Scrolling Track Title (tên bài hát chạy chữ)
            Item {
                id: marqueeBox
                width: Math.min(125, Math.max(48, titleText.implicitWidth))
                height: parent.height
                clip: true
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: titleText
                    text: root.displayTitle
                    color: Session.foreground
                    font.family: Session.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter

                    readonly property real overflow: Math.max(0, implicitWidth - marqueeBox.width)
                    property real scrollOffset: 0
                    x: scrollOffset

                    SequentialAnimation on scrollOffset {
                        id: marqueeAnim
                        running: !root.isOsd && root.hasMedia && root.isPlaying && titleText.overflow > 0 && !Motion.reduced
                        loops: Animation.Infinite

                        PauseAnimation { duration: 1800 }
                        NumberAnimation {
                            to: -(titleText.overflow + 6)
                            duration: Math.max(1600, titleText.overflow * 38)
                            easing.type: Easing.Linear
                        }
                        PauseAnimation { duration: 1800 }
                        NumberAnimation {
                            to: 0
                            duration: Math.max(1600, titleText.overflow * 38)
                            easing.type: Easing.Linear
                        }
                    }

                    onOverflowChanged: {
                        if (overflow <= 0) scrollOffset = 0;
                    }
                }
            }

            // 3. Mini Play/Pause Indicator
            Item {
                id: playIconBox
                width: 14
                height: 14
                anchors.verticalCenter: parent.verticalCenter
                opacity: mouseArea.containsMouse ? 1 : 0.8
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Icon {
                    anchors.centerIn: parent
                    width: 13
                    height: 13
                    name: root.isPlaying ? "pause-dark" : "play-dark"
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor

            Accessible.name: root.isOsd ? OsdState.title : (I18n.tr("music.mini_player") + " · " + root.displayTitle)

            onClicked: (mouse) => {
                if (root.isOsd) return;
                if (mouse.button === Qt.RightButton) {
                    if (root.player && root.player.canGoNext) root.player.next();
                } else if (mouse.button === Qt.MiddleButton) {
                    if (root.player && root.player.canGoPrevious) root.player.previous();
                } else {
                    if (root.player && root.player.canTogglePlaying) root.player.togglePlaying();
                }
            }

            onWheel: (wheel) => {
                if (Session.sink && Session.sink.audio) {
                    const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                    Session.sink.audio.volume = Math.max(0, Math.min(1.5, Session.sink.audio.volume + step));
                }
            }
        }
    }
}
