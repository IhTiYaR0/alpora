import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Effects

Button {
    id: control
    property string symbol: "terminal"
    property string hint: ""
    property url imageSource: ""
    property bool selected: false
    implicitWidth: 46; implicitHeight: 46
    hoverEnabled: true
    Accessible.name: hint
    opacity: enabled ? 1 : 0.35
    scale: Motion.reduced ? 1 : down ? 0.93 : hovered ? 1.09 : 1
    Behavior on scale { NumberAnimation { duration: Motion.responseMs; easing.type: Easing.OutCubic } }
    background: Rectangle {
        radius: width / 2
        color: control.selected ? Session.accent : Glass.tint(Session.surface, control.hovered ? 0.94 : 0.83)
        border.width: control.hovered || control.visualFocus ? 1.4 : 0.8
        border.color: Glass.tint(control.hovered || control.visualFocus ? Session.foreground : Session.accent, control.hovered ? 0.85 : 0.4)
        layer.enabled: control.hovered && !Motion.reduced
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Glass.tint(Session.accent, 0.35); shadowBlur: 0.6; shadowVerticalOffset: 0 }
    }
    contentItem: Item {
        Icon { anchors.centerIn: parent; width: 22; height: 22; name: control.symbol; visible: !control.imageSource.toString().length }
        Image { anchors.centerIn: parent; width: 26; height: 26; source: control.imageSource; sourceSize: Qt.size(64,64); visible: control.imageSource.toString().length > 0 }
    }
    ToolTip.visible: hovered && hint.length > 0
    ToolTip.text: hint
    ToolTip.delay: 0
}
