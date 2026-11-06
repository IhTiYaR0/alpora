import QtQuick
import ".."
import "../theme" as PolyTheme

// A finite glint and contact wave. No timers or animation loops while idle.
Item {
    id: light
    property bool hovered: false
    property bool pressed: false
    property real sweep: -0.5
    property real wave: 1
    clip: true
    visible: !Motion.reduced
    onHoveredChanged: if (hovered && !Motion.reduced) glint.restart()
    onPressedChanged: if (pressed && !Motion.reduced) contact.restart()
    NumberAnimation { id: glint; target: light; property: "sweep"; from: -0.5; to: 1.5; duration: 620; easing.type: Easing.InOutCubic }
    NumberAnimation { id: contact; target: light; property: "wave"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }
    Rectangle {
        x: light.sweep * light.width - width / 2
        y: -light.height
        width: Math.max(12, light.width * 0.28); height: light.height * 3
        rotation: 24
        opacity: light.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.responseMs } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: PolyTheme.Theme.color("#24d6e8bd") }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: light.wave * Math.max(light.width, light.height) * 2.3
        height: width; radius: width / 2
        color: PolyTheme.Theme.color("#0fbad497")
        border.width: 1.5; border.color: PolyTheme.Theme.color("#9db9d190")
        opacity: (1 - light.wave) * 0.65
    }
}
