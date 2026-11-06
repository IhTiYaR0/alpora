pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme

Item {
    id: root
    property int code: 0
    property bool day: true
    property bool animated: true
    property int renderedCode: code
    property bool renderedDay: day
    property bool ready: false
    function sync(): void {
        crossfade.stop();
        if (!ready || !animated) { renderedCode = code; renderedDay = day; opacity = 1; return; }
        crossfade.restart();
    }
    onCodeChanged: sync()
    onDayChanged: sync()
    onAnimatedChanged: if (!animated) { crossfade.stop(); renderedCode = code; renderedDay = day; opacity = 1; }
    Component.onCompleted: ready = true
    SequentialAnimation {
        id: crossfade
        NumberAnimation { target: root; property: "opacity"; to: 0.35; duration: 75 }
        ScriptAction { script: { root.renderedCode = root.code; root.renderedDay = root.day; } }
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 190; easing.type: Easing.OutCubic }
    }
    property real pointerX: 0
    property real pointerY: 0
    property real phase: 0
    readonly property bool snow: (renderedCode >= 71 && renderedCode <= 77) || renderedCode === 85 || renderedCode === 86
    readonly property bool rain: (renderedCode >= 51 && renderedCode <= 67) || (renderedCode >= 80 && renderedCode <= 82) || renderedCode >= 95
    readonly property bool fog: renderedCode === 45 || renderedCode === 48
    readonly property bool storm: renderedCode >= 95
    readonly property bool activeEffects: root.rain || root.snow || root.fog || root.storm || root.pointerX !== 0 || root.pointerY !== 0
    Timer {
        interval: 90
        repeat: true
        running: root.animated && root.visible && (root.activeEffects || Session.mode === "vibe")
        onTriggered: root.phase += 0.075
    }
    Rectangle {
        x: 60 + root.pointerX * 5; y: 3
        width: 110; height: 110; radius: 55
        color: root.renderedDay ? PolyTheme.Theme.secondary : PolyTheme.Theme.cool
        opacity: (root.storm ? 0.025 : 0.045) + (root.animated ? Math.sin(root.phase * 0.8) * 0.015 : 0)
        scale: 1 + Math.sin(root.phase * 0.5) * 0.06
    }
    Repeater {
        model: !root.renderedDay && root.renderedCode < 3 ? 8 : 0
        Rectangle {
            required property int index
            x: 12 + index * 23 + root.pointerX * 3
            y: 10 + (index * 13) % 45 + Math.sin(root.phase + index) * 2
            width: index % 3 ? 2 : 3; height: width; rotation: 45
            color: Session.foreground
            opacity: 0.2 + (root.animated ? (1 + Math.sin(root.phase * 1.5 + index)) * 0.22 : 0)
        }
    }
    WeatherGlyph {
        x: 8 + Math.sin(root.phase * 0.4) * 9 - root.pointerX * 4
        y: 15; width: 110; height: 70
        code: 3; visible: root.renderedCode >= 2
        opacity: 0.2
    }
    Image {
        x: 0 + root.pointerX * 3; y: 56 + root.pointerY * 2
        width: parent.width; height: 55
        source: Session.appearance.ridge ? "file://" + Session.appearance.ridge : ""
        sourceSize: Qt.size(440, 130)
        smooth: true; mipmap: true; fillMode: Image.PreserveAspectFit
        verticalAlignment: Image.AlignBottom; opacity: 0.3
    }
    Item {
        x: 59 + Math.sin(root.phase * 0.65) * 6 + root.pointerX * 10
        y: -2 + Math.sin(root.phase * 0.9) * 3 + root.pointerY * 5
        width: 120; height: 100
        Item {
            visible: root.renderedDay && root.renderedCode < 3
            x: 81; y: 41
            rotation: root.phase * 5
            Repeater {
                model: 8
                Item {
                    required property int index
                    rotation: index * 45
                    Rectangle { x: 43; y: -1; width: 8; height: 2; radius: 1; color: PolyTheme.Theme.secondary; opacity: 0.35 }
                }
            }
        }
        WeatherGlyph {
            anchors.fill: parent
            code: root.renderedCode; day: root.renderedDay
            animated: root.animated
            externalTime: root.phase
        }
    }
    Repeater {
        model: root.rain || root.snow ? 12 : 0
        Rectangle {
            required property int index
            readonly property real fall: ((root.phase + index * 0.173) % (root.snow ? 3.4 : 0.9)) / (root.snow ? 3.4 : 0.9)
            x: 10 + index * 16 + (root.snow ? Math.sin(root.phase + index) * 7 : -fall * 9)
            y: 48 + fall * 66
            width: root.snow ? 3 : 1.5; height: root.snow ? 3 : 9
            radius: 1; rotation: root.snow ? root.phase * 20 + index * 45 : 18
            color: root.snow ? Session.foreground : PolyTheme.Theme.cool
            opacity: Math.sin(fall * Math.PI) * 0.6
        }
    }
    Repeater {
        model: root.fog ? 4 : 2
        Rectangle {
            required property int index
            x: -15 + Math.sin(root.phase * 0.45 + index * 2) * 18 + root.pointerX * 5
            y: (root.fog ? 38 : 83) + index * 12
            width: root.width + 30; height: root.fog ? 9 : 2; radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.4; color: Glass.tint(Session.muted, root.fog ? 0.25 : 0.18) }
                GradientStop { position: 0.7; color: Glass.tint(Session.accent, root.fog ? 0.2 : 0.08) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }
    Rectangle {
        anchors.fill: parent; radius: 15
        color: Session.foreground
        opacity: root.storm && root.animated && (root.phase % 6 < 0.1 || (root.phase % 6 > 0.24 && root.phase % 6 < 0.32)) ? 0.08 : 0
    }
}
