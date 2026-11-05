pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris

ColumnLayout {
    id: root
    property bool active: false
    property bool compact: false
    property real expansion: compact ? 0 : 1
    readonly property bool dragging: seek.pressed
    readonly property var player: MusicState.player
    property real position: 0
    function updatePosition(): void { position = player && player.positionSupported ? Math.max(0, player.position) : 0; }
    readonly property real length: player && player.lengthSupported ? Math.max(0, player.length) : 0
    readonly property bool seekable: !!player && player.canControl && player.canSeek && player.positionSupported && length > 0
    spacing: 8 + 4 * expansion
    Timer { interval: 500; repeat: true; running: root.active && !!root.player && root.player.isPlaying; onTriggered: root.updatePosition() }
    onActiveChanged: if (active) updatePosition()
    onPlayerChanged: updatePosition()
    Connections {
        target: root.player
        function onPositionChanged(): void { root.updatePosition(); }
        function onIsPlayingChanged(): void { root.updatePosition(); }
    }
    PanelHeader {
        title: I18n.tr("music.title")
        subtitle: root.player ? root.player.identity : I18n.tr("music.default_subtitle")
    }
    Rectangle {
        visible: !root.player
        Layout.fillWidth: true; Layout.fillHeight: true
        radius: 15; color: Glass.tint(PolyTheme.Theme.color("#20292a"), 0.4); border.width: 0.7; border.color: PolyTheme.Theme.color("#3b4840")
        Column {
            anchors.centerIn: parent; width: parent.width - 60; spacing: 8 + 9 * root.expansion
            ClippingRectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 38 + 46 * root.expansion; height: width; radius: 10 + 12 * root.expansion; color: PolyTheme.Theme.color("#344238")
                Icon { anchors.centerIn: parent; name: "music"; width: 22 + 14 * root.expansion; height: width }
            }
            Text { width: parent.width; text: I18n.tr("music.empty_title"); horizontalAlignment: Text.AlignHCenter; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 13 + 5 * root.expansion }
            Text { width: parent.width; text: I18n.tr("music.empty_desc"); horizontalAlignment: Text.AlignHCenter; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10 + 2 * root.expansion; wrapMode: Text.Wrap; lineHeight: 1.5 }
        }
    }
    Rectangle {
        visible: !!root.player
        Layout.fillWidth: true; Layout.fillHeight: true
        radius: 15; color: Glass.tint(PolyTheme.Theme.color("#20292a"), 0.4); border.width: 0.7; border.color: PolyTheme.Theme.color("#3b4840")
        RowLayout {
            anchors.fill: parent; anchors.margins: 10 + 12 * root.expansion; spacing: 12 + 12 * root.expansion
            ClippingRectangle {
                id: artwork
                Layout.preferredWidth: 76 + 124 * root.expansion; Layout.preferredHeight: 88 + 112 * root.expansion
                radius: 15; color: PolyTheme.Theme.color("#344137"); border.width: 1; border.color: PolyTheme.Theme.color("#61715b")
                Image {
                    id: cover
                    anchors.fill: parent
                    anchors.margins: 1
                    source: root.player ? root.player.trackArtUrl : ""
                    asynchronous: true
                    sourceSize.width: 512; sourceSize.height: 512
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
                Icon { anchors.centerIn: parent; name: "music"; width: 54; height: 54; visible: cover.status !== Image.Ready }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                spacing: 3 + 6 * root.expansion
                Text {
                    Layout.fillWidth: true
                    text: root.player ? (root.player.trackTitle || I18n.tr("music.untitled")) : ""
                    textFormat: Text.PlainText; color: Session.foreground
                    font.family: Session.fontFamily; font.pixelSize: 13 + 8 * root.expansion; font.weight: Font.Medium
                    wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                }
                Text { Layout.fillWidth: true; text: root.player ? (root.player.trackArtist || I18n.tr("music.unknown_artist")) : ""; textFormat: Text.PlainText; color: PolyTheme.Theme.color("#b1bfa6"); font.family: Session.fontFamily; font.pixelSize: 11 + 2 * root.expansion; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; visible: text.length > 0; text: root.player ? root.player.trackAlbum : ""; textFormat: Text.PlainText; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; elide: Text.ElideRight }
                Item { Layout.preferredHeight: 5 * root.expansion }
                Slider {
                    id: seek
                    property real pendingPosition: 0
                    Layout.fillWidth: true; implicitHeight: 24
                    from: 0; to: Math.max(1, root.length)
                    value: pressed ? pendingPosition : (root.length > 0 ? Math.min(root.position, to) : 0)
                    enabled: root.seekable
                    opacity: enabled ? 1 : 0.45
                    Accessible.name: I18n.tr("music.playback_position")
                    onMoved: {
                        pendingPosition = value;
                        if (!pressed && root.seekable) root.player.position = value;
                    }
                    onPressedChanged: {
                        if (pressed) pendingPosition = value;
                        else if (root.seekable) root.player.position = Math.max(0, Math.min(pendingPosition, root.length));
                    }
                    background: Rectangle {
                        x: seek.leftPadding; y: (seek.height - height) / 2
                        width: seek.availableWidth; height: 4; radius: 2; color: PolyTheme.Theme.color("#465248")
                        Rectangle { width: seek.visualPosition * parent.width; height: parent.height; radius: 2; color: PolyTheme.Theme.color("#a8bb97") }
                    }
                    handle: Rectangle {
                        x: seek.leftPadding + seek.visualPosition * (seek.availableWidth - width)
                        y: (seek.height - height) / 2
                        width: 10; height: 10; radius: 5; color: PolyTheme.Theme.color("#c4d2b3")
                        visible: seek.enabled
                        border.width: seek.visualFocus ? 2 : 0; border.color: Session.foreground
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: root.player && root.player.positionSupported ? MusicState.formatTime(seek.pressed ? seek.pendingPosition : root.position) : "—:—"; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10 }
                    Item { Layout.fillWidth: true }
                    AudioVisualizer {
                        visible: root.expansion > 0.4
                        barsCount: 12
                        barWidth: 2.5
                        barSpacing: 2
                        implicitHeight: 14
                    }
                    Item { Layout.fillWidth: true }
                    Text { text: root.length > 0 ? MusicState.formatTime(root.length) : "—:—"; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10 }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10
                    BarButton { symbol: "previous"; hint: I18n.tr("music.prev_track"); implicitWidth: 36; implicitHeight: 36; enabled: !!root.player && root.player.canControl && root.player.canGoPrevious; opacity: enabled ? 1 : 0.3; onClicked: if (root.player) root.player.previous() }
                    Button {
                        id: play
                        implicitWidth: 32 + 20 * root.expansion; implicitHeight: 32 + 20 * root.expansion; padding: 0; hoverEnabled: true
                        enabled: !!root.player && root.player.canControl && root.player.canTogglePlaying
                        Accessible.name: root.player && root.player.isPlaying ? I18n.tr("music.pause") : I18n.tr("music.play")
                        background: Rectangle { radius: 17; color: play.down ? PolyTheme.Theme.color("#7f966f") : (play.hovered ? PolyTheme.Theme.color("#b6c8a3") : PolyTheme.Theme.color("#9baf86")); border.width: play.visualFocus ? 2 : 0; border.color: Session.foreground; opacity: play.enabled ? 1 : 0.4; Behavior on color { ColorAnimation { duration: Session.settings.reducedMotion ? 0 : 140 } } }
                        contentItem: Item { Icon { anchors.centerIn: parent; name: root.player && root.player.isPlaying ? "pause-dark" : "play-dark"; width: 23; height: 23 } }
                        onClicked: if (root.player) { MusicState.select(root.player.dbusName); root.player.togglePlaying(); }
                    }
                    BarButton { symbol: "next"; hint: I18n.tr("music.next_track"); implicitWidth: 36; implicitHeight: 36; enabled: !!root.player && root.player.canControl && root.player.canGoNext; opacity: enabled ? 1 : 0.3; onClicked: if (root.player) root.player.next() }
                }
            }
        }
    }
    Rectangle {
        visible: !!root.player
        Layout.fillWidth: true; Layout.preferredHeight: 54 * root.expansion; Layout.maximumHeight: 54 * root.expansion; Layout.minimumHeight: 0; Layout.fillHeight: false; clip: true
        radius: 12; color: Glass.tint(PolyTheme.Theme.color("#293431"), 0.45)
        RowLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 10
            BarButton {
                symbol: "shuffle"; hint: I18n.tr("music.shuffle")
                enabled: !!root.player && root.player.canControl && root.player.shuffleSupported
                marked: !!root.player && root.player.shuffleSupported && root.player.shuffle
                opacity: enabled ? 1 : 0.3
                onClicked: if (root.player) root.player.shuffle = !root.player.shuffle
            }
            BarButton {
                symbol: root.player && root.player.loopState === MprisLoopState.Track ? "repeat-one" : "repeat"
                hint: I18n.tr("music.repeat_prefix") + (!root.player || root.player.loopState === MprisLoopState.None ? I18n.tr("music.repeat_off") : (root.player.loopState === MprisLoopState.Track ? I18n.tr("music.repeat_track") : I18n.tr("music.repeat_playlist")))
                enabled: !!root.player && root.player.canControl && root.player.loopSupported
                marked: !!root.player && root.player.loopState !== MprisLoopState.None
                opacity: enabled ? 1 : 0.3
                onClicked: if (root.player) root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : (root.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
            }
            Item { Layout.fillWidth: true }
            Icon { name: "volume"; Layout.preferredWidth: 16; Layout.preferredHeight: 16; opacity: playerVolume.enabled ? 1 : 0.3 }
            ControlSlider {
                id: playerVolume
                Layout.preferredWidth: 128
                enabled: !!root.player && root.player.canControl && root.player.volumeSupported
                opacity: enabled ? 1 : 0.3
                value: root.player && root.player.volumeSupported ? Math.min(1, root.player.volume) : 0
                Accessible.name: I18n.tr("music.player_volume")
                onMoved: if (root.player && root.player.canControl && root.player.volumeSupported) root.player.volume = value
            }
            DayAction { text: I18n.tr("music.open_player"); enabled: !!root.player && root.player.canRaise; onClicked: { if (root.player) root.player.raise(); BarState.close(); } }
        }
    }
    ScrollView {
        visible: MusicState.players.length > 1
        Layout.fillWidth: true; Layout.preferredHeight: 34 * root.expansion; Layout.maximumHeight: 34 * root.expansion; Layout.minimumHeight: 0; Layout.fillHeight: false; clip: true
        contentHeight: availableHeight
        Row {
            spacing: 6
            Repeater {
                model: MusicState.players
                DayAction { required property var modelData; text: modelData ? modelData.identity : ""; primary: !!modelData && root.player === modelData; onClicked: if (modelData) MusicState.select(modelData.dbusName) }
            }
        }
    }
}
