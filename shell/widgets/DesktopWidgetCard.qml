import QtQuick
import ".."
import "../theme" as PolyTheme

Rectangle {
    id: root
    property bool motionActive: true
    readonly property bool animate: motionActive && visible && !!WidgetState.values.animations && Session.visual.widgetAnimations && !Motion.reduced
    property real reveal: 0
    opacity: reveal
    Component.onCompleted: reveal = 1
    Behavior on reveal { NumberAnimation { duration: root.animate ? Session.visual.widgetFadeMs : 0; easing.type: Easing.OutCubic } }
    SoftShadow { anchors.fill: parent; z: -1; cornerRadius: root.radius; spread: 5; strength: Session.visual.widgetShadow / 20 }
    HoverHandler { id: hover }
    radius: Session.visual.widgetRadius
    antialiasing: true
    gradient: Gradient {
        GradientStop { position: 0; color: Glass.materialTop(Session.visual.widgetOpacity); Behavior on color { ColorAnimation { duration: root.animate ? 360 : 0 } } }
        GradientStop { position: 1; color: Glass.materialBottom(Session.visual.widgetOpacity); Behavior on color { ColorAnimation { duration: root.animate ? 360 : 0 } } }
    }
    border.width: Session.visual.widgetBorder
    border.color: hover.hovered ? Session.accent : Glass.tint(Session.foreground, 0.22)
    Behavior on border.color { ColorAnimation { duration: root.animate ? 180 : 0 } }
}
