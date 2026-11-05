pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Shapes
import "../theme" as PolyTheme

Item {
    id: root
    property bool animated: true
    property real pointerX: 0
    property real pointerY: 0
    property bool night: true
    property real phase: 0
    property real bloom: 0
    property real seconds: 0
    readonly property string ridge: Session.appearance.ridge ? "file://" + Session.appearance.ridge : ""
    readonly property real drift: Math.sin(phase * Math.PI * 2)
    readonly property real intensity: Session.mode === "vibe" ? 1.3 : 1
    clip: true
    NumberAnimation on phase {
        from: 0; to: 1; duration: 14000; loops: Animation.Infinite
        running: root.animated
    }
    function ripple(): void { pulse.restart(); }
    SequentialAnimation {
        id: pulse
        PropertyAction { target: root; property: "bloom"; value: 0 }
        NumberAnimation { target: root; property: "bloom"; to: 1; duration: 1100; easing.type: Easing.OutCubic }
        PropertyAction { target: root; property: "bloom"; value: 0 }
    }
    onAnimatedChanged: if (!animated) { pulse.stop(); bloom = 0; }
    Rectangle {
        x: parent.width - 126 + root.pointerX * 4; y: 16 + root.pointerY * 3 + root.drift * 3
        width: 82; height: 82; radius: 41
        color: Session.accent
        opacity: 0.025 + (root.animated ? (1 + root.drift) * 0.015 : 0)
        scale: 1 + root.drift * 0.1
    }
    Item {
        x: parent.width - 94 + root.pointerX * 7; y: 33 + root.pointerY * 4 + root.drift * 4
        width: 30; height: 30
        opacity: 0.8
        Rectangle {
            anchors.fill: parent; radius: 15
            visible: !root.night
            color: PolyTheme.Theme.secondary
        }
        Shape {
            anchors.fill: parent
            visible: root.night
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Session.foreground; strokeWidth: 0
                PathSvg { path: "M 22,2 A 14,14 0 1 0 28,23 A 13,13 0 0 1 22,2 Z" }
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 54; height: 54; radius: 27
            color: "transparent"
            border.width: 1; border.color: Glass.tint(Session.accent, 0.2)
            Item {
                anchors.centerIn: parent; width: 0; height: 0
                rotation: -90 + root.seconds * 360
                Rectangle { x: 25; y: -2; width: 4; height: 4; radius: 2; color: Session.accent }
            }
        }
    }
    Repeater {
        model: 11
        Rectangle {
            required property int index
            readonly property real wave: Math.sin(root.phase * Math.PI * 2 + index * 1.7)
            x: 162 + (index * 43) % Math.max(1, root.width - 186) + root.pointerX * 3
            y: 12 + (index * 17) % 90 + wave * 8
            width: index % 3 === 0 ? 3 : 2; height: width; rotation: 45
            color: index % 2 ? Session.accent : Session.foreground
            opacity: (root.night ? 0.22 : 0.1) + (root.animated ? (1 + wave) * 0.14 : 0)
        }
    }
    Image {
        x: 132 + root.pointerX * 5 - root.drift * 4; y: 56 + root.pointerY * 2
        width: parent.width - 130; height: 83; source: root.ridge
        sourceSize: Qt.size(640, 180)
        smooth: true; mipmap: true
        fillMode: Image.PreserveAspectFit; verticalAlignment: Image.AlignBottom; opacity: 0.26
    }
    Repeater {
        model: 3
        Rectangle {
            required property int index
            x: 105 + index * 38 + Math.sin(root.phase * Math.PI * 2 + index * 1.8) * (22 + index * 6) * root.intensity + root.pointerX * 7
            y: 97 + index * 15
            width: 230; height: 20 + index * 3; radius: height / 2
            opacity: 0.13 - index * 0.025
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.4; color: Session.muted }
                GradientStop { position: 0.65; color: Session.accent }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }
    Image {
        x: 153 + root.pointerX * 12 + root.drift * 3; y: 62 + root.pointerY * 5
        width: parent.width - 158; height: 98; source: root.ridge
        sourceSize: Qt.size(640, 230)
        smooth: true; mipmap: true
        fillMode: Image.PreserveAspectFit; verticalAlignment: Image.AlignBottom; opacity: 0.85
    }
    Rectangle {
        x: parent.width - 80 - width / 2; y: 78 - height / 2
        width: 250 * root.bloom; height: width; radius: width / 2
        color: "transparent"; border.width: 1; border.color: Session.accent
        opacity: root.bloom > 0 ? (1 - root.bloom) * 0.65 : 0
    }
}
