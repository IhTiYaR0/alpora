import QtQuick
import ".."

Rotation {
    id: tilt
    required property Item item
    property real strength: 6
    property bool hovered: false
    property real pointerX: item.width / 2
    property real pointerY: item.height / 2
    property real dx: hovered ? (pointerX / Math.max(1, item.width) - 0.5) * 2 : 0
    property real dy: hovered ? (pointerY / Math.max(1, item.height) - 0.5) * 2 : 0
    Behavior on dx { NumberAnimation { duration: Motion.reduced ? 0 : 100; easing.type: Easing.OutCubic } }
    Behavior on dy { NumberAnimation { duration: Motion.reduced ? 0 : 100; easing.type: Easing.OutCubic } }
    origin.x: item.width / 2
    origin.y: item.height / 2
    axis.x: -dy
    axis.y: Math.abs(dx) + Math.abs(dy) < 0.001 ? 1 : dx
    axis.z: 0
    angle: Motion.reduced ? 0 : Math.min(1, Math.sqrt(dx * dx + dy * dy)) * strength
}
