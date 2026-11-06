pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell.Widgets
import Quickshell.Io

DesktopWidgetCard {
    id: root
    implicitWidth: 370; implicitHeight: 190
    readonly property var player: MusicState.player
    readonly property real length: player && player.lengthSupported ? Math.max(0, player.length) : 0
    readonly property bool living: animate && !ClockState.sleeping
    readonly property bool playing: !!player && player.isPlaying
    readonly property bool moving: living && playing
    property real tiltX: 0
    property real tiltY: 0
    Behavior on tiltX { NumberAnimation { duration: root.living ? 260 : 0; easing.type: Easing.OutCubic } }
    Behavior on tiltY { NumberAnimation { duration: root.living ? 260 : 0; easing.type: Easing.OutCubic } }
    property real position: 0
    property real playbackPulse: 0
    Timer { interval: 80; repeat: true; running: root.moving; onTriggered: root.playbackPulse += 0.05 }
    function updatePosition(): void { if (seek && seek.pressed) return; position = player && player.positionSupported ? Math.max(0, player.position) : 0; }
    onPlayerChanged: updatePosition()
    onMotionActiveChanged: if (motionActive) updatePosition()
    onLivingChanged: if (!living) { tiltX = 0; tiltY = 0; }
    Timer { interval: 1000; repeat: true; running: root.visible && root.motionActive && !ClockState.sleeping && root.playing; onTriggered: root.updatePosition() }
    Connections {
        target: root.player
        function onPositionChanged(): void { root.updatePosition(); }
        function onIsPlayingChanged(): void { root.updatePosition(); }
        function onTrackChanged(): void { root.updatePosition(); }
    }
    Item {
        id: artworkStage
        x: 18; y: 20; width: 124; height: 100
        transform: [
            Rotation { origin.x: 62; origin.y: 50; axis.x: 1; axis.y: 0; axis.z: 0; angle: root.living ? -root.tiltY * 6 : 0 },
            Rotation { origin.x: 62; origin.y: 50; axis.x: 0; axis.y: 1; axis.z: 0; angle: root.living ? root.tiltX * 9 : 0 }
        ]
        HoverHandler {
            onPointChanged: {
                if (!root.living) return;
                root.tiltX = Math.max(-1, Math.min(1, point.position.x / 62 - 1));
                root.tiltY = Math.max(-1, Math.min(1, point.position.y / 50 - 1));
            }
            onHoveredChanged: if (!hovered) { root.tiltX = 0; root.tiltY = 0; }
        }
        Rectangle {
            id: record
            x: 35; y: 5; width: 88; height: 88; radius: 44
            color: Session.background
            border.width: 1; border.color: Glass.tint(Session.muted, 0.25)
            RotationAnimator on rotation {
                from: 0; to: 360; duration: 9000; loops: Animation.Infinite
                running: !!root.player; paused: !!root.player && !root.moving
            }
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: 76 - index * 12; height: width; radius: width / 2
                    color: "transparent"; border.width: 1
                    border.color: Glass.tint(Session.foreground, index % 2 ? 0.09 : 0.045)
                }
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"; strokeWidth: 1.5
                    strokeColor: Glass.tint(Session.foreground, 0.16)
                    capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 44; centerY: 44; radiusX: 38; radiusY: 38; startAngle: 15; sweepAngle: 62 }
                }
            }
            ClippingRectangle {
                anchors.centerIn: parent
                width: 31; height: 31; radius: 15.5; color: Session.accent
                Image {
                    anchors.fill: parent
                    source: root.player ? root.player.trackArtUrl : ""
                    sourceSize: Qt.size(64,64); asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                }
                Rectangle { anchors.centerIn: parent; width: 5; height: 5; radius: 2.5; color: Session.background }
            }
        }
        ClippingRectangle {
            x: 0; y: 5; width: 88; height: 88
            radius: Math.min(14, Session.visual.widgetRadius); color: Session.surface
            Image {
                anchors.fill: parent; anchors.margins: 5
                source: Session.appearance.ridge ? "file://" + Session.appearance.ridge : ""
                fillMode: Image.PreserveAspectFit; verticalAlignment: Image.AlignBottom
                opacity: 0.7
            }
            Icon { anchors.centerIn: parent; width: 27; height: 27; name: "music"; visible: !cover.ready }
            MusicArtwork { id: cover; anchors.fill: parent; source: root.player ? root.player.trackArtUrl : ""; animated: root.living }
        }
        Item {
            x: 108; y: 0; width: 12; height: 76
            transformOrigin: Item.TopRight
            rotation: root.playing ? 9 : -17
            Behavior on rotation { NumberAnimation { duration: root.living ? 500 : 0; easing.type: Easing.OutCubic } }
            Rectangle { x: 6; width: 7; height: 7; radius: 3.5; color: Session.muted }
            Rectangle { x: 8; y: 4; width: 2; height: 53; radius: 1; color: Session.muted }
            Rectangle { x: 4; y: 53; width: 4; height: 14; radius: 1; rotation: 28; color: Session.foreground }
        }
    }
    Text { x: 153; y: 20; width: parent.width - 173; text: root.player ? (root.playing ? I18n.tr("music.now_playing") : I18n.tr("music.paused")) : I18n.tr("music.title"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; elide: Text.ElideRight }
    WidgetAnimatedText { x: 153; y: 41; width: parent.width - 173; value: root.player ? root.player.trackTitle || I18n.tr("music.untitled") : I18n.tr("music.your_rhythm"); motionActive: root.living; textFormat: Text.PlainText; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 15; font.weight: Font.Medium; elide: Text.ElideRight }
    WidgetAnimatedText { x: 153; y: 65; width: parent.width - 173; value: root.player ? root.player.trackArtist || root.player.identity : I18n.tr("music.play_track_in_player"); motionActive: root.living; textFormat: Text.PlainText; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; elide: Text.ElideRight }
    Row {
        x: root.width - 40; y: 21; spacing: 3
        visible: !!root.player && root.player.isPlaying
        Repeater {
            model: 3
            Rectangle {
                id: meter
                required property int index
                width: 3; height: root.animate ? 4 + (Math.sin(root.playbackPulse * (5 + index) + index) + 1) * (3 + index) : 5; y: 12 - height; radius: 1.5; color: Session.accent

            }
        }
    }
    Row {
        x: 153; y: 89; spacing: 16
        IconButton { width: 30; height: 30; symbol: "previous"; hint: I18n.tr("music.prev_track"); enabled: !!root.player && root.player.canControl && root.player.canGoPrevious; opacity: enabled ? 1 : 0.3; onClicked: if (root.player) root.player.previous() }
        Button {
            id: play
            width: 36; height: 36; padding: 0; hoverEnabled: true
            enabled: !!root.player && root.player.canControl && root.player.canTogglePlaying
            opacity: enabled ? 1 : 0.3
            transform: InteractionMotion { item: play; pressed: play.down; hovered: play.hovered }
            Accessible.name: root.player && root.player.isPlaying ? I18n.tr("music.pause") : I18n.tr("music.play")
            background: Rectangle { radius: 18; color: Session.accent; opacity: play.down ? 0.7 : 1; border.width: play.visualFocus ? 2 : 0; border.color: Session.foreground }
            contentItem: Item {
                Icon { anchors.centerIn: parent; width: 18; height: 18; name: "pause-dark"; opacity: root.player && root.player.isPlaying ? 1 : 0; Behavior on opacity { NumberAnimation { duration: root.living ? 180 : 0 } } }
                Icon { anchors.centerIn: parent; width: 18; height: 18; name: "play-dark"; opacity: root.player && root.player.isPlaying ? 0 : 1; Behavior on opacity { NumberAnimation { duration: root.living ? 180 : 0 } } }
            }
            onClicked: if (root.player) root.player.togglePlaying()
        }
        IconButton { width: 30; height: 30; symbol: "next"; hint: I18n.tr("music.next_track"); enabled: !!root.player && root.player.canControl && root.player.canGoNext; opacity: enabled ? 1 : 0.3; onClicked: if (root.player) root.player.next() }
    }
    ControlSlider {
        id: seek; x: 20; y: 135; width: parent.width - 40; height: 22
        property real pendingPosition: 0
        hoverEnabled: true
        from: 0; to: root.length > 0 ? root.length : 1; value: root.position; stepSize: 1
        enabled: !!root.player && root.player.canControl && root.player.canSeek && root.player.positionSupported && root.length > 0
        Accessible.name: I18n.tr("music.playback_position")
        onMoved: {
            pendingPosition = value;
            if (!pressed && enabled) root.player.position = value;
        }
        onPressedChanged: {
            if (pressed) pendingPosition = value;
            else if (enabled) root.player.position = Math.max(0, Math.min(pendingPosition, root.length));
        }
        background: MusicWaveform {
            id: wave
            x: seek.leftPadding; y: (seek.height - height) / 2
            width: seek.availableWidth; height: 24
            phase: root.playbackPulse
            progress: seek.visualPosition
            hasTrack: !!root.player
            playing: root.playing
            animated: root.living
        }
        handle: Rectangle {
            x: seek.leftPadding + seek.visualPosition * (seek.availableWidth - width)
            y: (seek.height - height) / 2
            width: 6; height: 6; radius: 3
            color: Session.accent
            border.width: seek.visualFocus ? 2 : 0; border.color: Session.foreground
            opacity: seek.enabled && (seek.hovered || seek.pressed || seek.visualFocus) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.living ? 120 : 0 } }
            scale: seek.pressed ? 1.25 : 1
            Behavior on scale { NumberAnimation { duration: root.living ? 140 : 0 } }
        }
    }
    Text { x: 20; y: 165; text: root.player && root.player.positionSupported ? MusicState.formatTime(root.position) : "—:—"; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10 }
    Text { anchors.right: parent.right; anchors.rightMargin: 20; y: 165; text: root.length > 0 ? MusicState.formatTime(root.length) : "—:—"; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10 }
    IpcHandler {
        target: "desktop-music"
        function status(): string { return JSON.stringify({available: !!root.player, playing: root.playing, animated: root.moving, phase: root.playbackPulse, title: root.player ? root.player.trackTitle : "", position: root.position, length: root.length, seekable: seek.enabled, tilt: [root.tiltX, root.tiltY], artworkReady: cover.ready}); }
    }
}
