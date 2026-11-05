import QtQuick
import ".."

Scale {
    id: motion
    required property Item item
    property bool pressed: false
    property bool hovered: false
    property real hoverScale: 1.035
    property real pressScale: 0.94
    origin.x: item.width / 2
    origin.y: item.height / 2
    xScale: Motion.reduced ? 1 : pressed ? pressScale : hovered ? hoverScale : 1
    yScale: xScale
    Behavior on xScale {
        NumberAnimation {
            duration: Motion.responseMs
            easing.type: motion.pressed ? Easing.OutCubic : Easing.OutBack
            easing.overshoot: 0.8
        }
    }
}
