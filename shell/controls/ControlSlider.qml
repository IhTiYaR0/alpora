import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls

Slider {
    id: control
    property color accent: Session.accent
    stepSize: 0.01
    wheelEnabled: true
    from: 0
    to: 1
    implicitHeight: 28
    leftPadding: 0
    rightPadding: 0
    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitHeight: 6
        width: control.availableWidth
        height: 6
        radius: 3
        color: PolyTheme.Theme.color("#424a48")
        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: 3
            color: control.accent
            opacity: control.enabled ? 1 : 0.35
        }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 14
        height: 14
        radius: 7
        color: control.pressed ? PolyTheme.Theme.color("#d5dfc9") : control.accent
        border.width: 1.4
        border.color: PolyTheme.Theme.color("#e5eadf")
        scale: Motion.reduced ? 1 : control.pressed ? 1.25 : control.hovered ? 1.1 : 1
        Behavior on scale { NumberAnimation { duration: Motion.responseMs; easing.type: Easing.OutBack } }
        Behavior on color { ColorAnimation { duration: Motion.responseMs } }
        opacity: control.enabled ? 1 : 0.35
    }
}
