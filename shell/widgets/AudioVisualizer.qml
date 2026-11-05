import QtQuick
import ".."
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property int barsCount: 16
    property real barWidth: 3
    property real barSpacing: 2
    property real barRadius: 2
    property color activeColor: Session.accent
    property color inactiveColor: Glass.tint(Session.surface, 0.4)
    property bool active: MusicState.playing
    property real maxBarHeight: height

    implicitWidth: barsCount * barWidth + (barsCount - 1) * barSpacing
    implicitHeight: 28

    property var levels: []

    Component.onCompleted: {
        const initial = [];
        for (let i = 0; i < barsCount; ++i) initial.push(0.15);
        levels = initial;
    }

    Timer {
        id: animTimer
        interval: 66 // ~15 FPS: balanced fluidity with low interrupt rate
        running: root.active && root.visible && root.opacity > 0 && (!Session.settings || !Session.settings.reducedMotion)
        repeat: true
        onTriggered: {
            const time = Date.now() / 220.0;
            const cur = root.levels.length === root.barsCount ? root.levels.slice() : [];
            for (let i = 0; i < root.barsCount; ++i) {
                const norm = i / Math.max(1, root.barsCount - 1);
                // Multi-octave wave simulating audio spectrum (sub-bass higher amplitude, tapering off in treble)
                const s1 = Math.sin(time * 1.8 + i * 0.7);
                const s2 = Math.cos(time * 2.5 - i * 1.1);
                const s3 = Math.sin(time * 0.9 + i * 2.3);
                const raw = (s1 * 0.4 + s2 * 0.35 + s3 * 0.25 + 1.0) / 2.0;
                const freqWeight = Math.pow(1.0 - norm * 0.4, 0.8);
                cur[i] = Math.max(0.08, Math.min(1.0, raw * freqWeight));
            }
            root.levels = cur;
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.barSpacing

        Repeater {
            model: root.barsCount

            Rectangle {
                required property int index
                readonly property real targetLevel: (root.active && root.levels.length > index) ? root.levels[index] : 0.08
                width: root.barWidth
                height: Math.max(root.barRadius * 2, targetLevel * root.maxBarHeight)
                radius: root.barRadius
                color: root.active ? root.activeColor : root.inactiveColor
                opacity: root.active ? (0.65 + 0.35 * targetLevel) : 0.35

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }
                }
            }
        }
    }
}
