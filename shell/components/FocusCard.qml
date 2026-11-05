pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Shapes

Rectangle {
    id: root
    property real expansion: 1
    implicitHeight: 56 + 60 * expansion
    radius: 13; color: Glass.tint(Session.surface, 0.4)
    border.width: 0.7; border.color: Glass.tint(Session.accent, 0.2)
    Icon { x: 12; y: 18 - 6 * root.expansion; name: "focus"; width: 18; height: 18 }
    Text { x: 38; y: 18 - 6 * root.expansion; text: I18n.tr("focus.title"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12 }
    Text { x: 110 - 48 * root.expansion; y: 14 + 39 * root.expansion; text: DayState.countdown; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 21; font.weight: Font.DemiBold }
    Text { x: 62; y: 80; opacity: root.expansion; text: DayState.running ? I18n.tr("focus.focus_time") : I18n.tr("focus.pomodoro"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 9 }
    Item {
        x: 12; y: 51; width: 43; height: 43; opacity: root.expansion
        Shape {
            anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeWidth: 4; strokeColor: Glass.tint(Session.muted, 0.3); fillColor: "transparent"; capStyle: ShapePath.RoundCap; PathAngleArc { centerX: 21.5; centerY: 21.5; radiusX: 18.5; radiusY: 18.5; startAngle: -90; sweepAngle: 360 } }
            ShapePath { strokeWidth: 4; strokeColor: Session.accent; fillColor: "transparent"; capStyle: ShapePath.RoundCap; PathAngleArc { centerX: 21.5; centerY: 21.5; radiusX: 18.5; radiusY: 18.5; startAngle: -90; sweepAngle: Math.max(1, 360 * DayState.progress) } }
        }
    }
    DayAction {
        x: parent.width - width - 40; y: 11 + 42 * root.expansion
        implicitWidth: 61; implicitHeight: 32; primary: true
        text: DayState.running ? I18n.tr("focus.pause") : DayState.remaining < DayState.data.timer.duration ? I18n.tr("focus.next") : I18n.tr("focus.start")
        enabled: DayState.loaded && !DayState.busy
        onClicked: DayState.request(DayState.running ? "timer-pause" : "timer-start", {})
    }
    BarButton { x: parent.width - 34; y: 12 + 41 * root.expansion; implicitWidth: 24; symbol: "refresh"; hint: I18n.tr("focus.reset_timer"); enabled: !DayState.busy; onClicked: DayState.request("timer-reset", {}) }
    ComboBox {
        id: duration
        x: parent.width - width - 12; y: 10
        width: 64; height: 24; opacity: root.expansion; enabled: root.expansion > 0.9 && !DayState.running
        model: [I18n.trWith("focus.minutes", {min: 25}), I18n.trWith("focus.minutes", {min: 50}), I18n.trWith("focus.minutes", {min: 5})]
        currentIndex: DayState.data.timer.duration === 3000 ? 1 : DayState.data.timer.duration === 300 ? 2 : 0
        padding: 5; rightPadding: 17
        background: Rectangle { radius: 7; color: Glass.tint(Session.accent, 0.08); border.width: duration.visualFocus ? 1 : 0; border.color: Session.accent }
        contentItem: Text { text: duration.displayText; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 9; verticalAlignment: Text.AlignVCenter }
        indicator: Icon { x: duration.width - width - 5; y: (duration.height - height) / 2; name: "chevron-down"; width: 9; height: 9 }
        popup: Popup {
            y: duration.height + 3; width: duration.width; padding: 4
            implicitHeight: durationList.contentHeight + 8
            background: Rectangle { radius: 8; color: Session.surface; border.width: 0.7; border.color: Session.accent }
            contentItem: ListView { id: durationList; implicitHeight: contentHeight; model: duration.delegateModel; currentIndex: duration.highlightedIndex }
        }
        delegate: ItemDelegate {
            id: option
            required property string modelData
            width: duration.width - 8; height: 27; text: modelData
            font.family: Session.fontFamily; font.pixelSize: 10; palette.text: Session.foreground
            background: Rectangle { radius: 5; color: option.hovered ? Glass.tint(Session.accent, 0.18) : "transparent" }
        }
        onActivated: DayState.request("timer-duration", {minutes: [25, 50, 5][currentIndex]})
    }
}
