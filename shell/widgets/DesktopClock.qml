pragma ComponentBehavior: Bound
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

DesktopWidgetCard {
    id: root
    implicitWidth: 460; implicitHeight: 200
    readonly property bool living: animate && !ClockState.sleeping
    readonly property bool ticking: motionActive && visible && !ClockState.sleeping
    readonly property date now: ticking ? secondsClock.date : ClockState.date
    readonly property string digits: Qt.formatDateTime(now, "HHmm")
    readonly property int second: now.getSeconds()
    property real pointerX: 0
    property real pointerY: 0
    property real sweep: second / 60
    Behavior on pointerX { NumberAnimation { duration: root.living ? 340 : 0; easing.type: Easing.OutCubic } }
    Behavior on pointerY { NumberAnimation { duration: root.living ? 340 : 0; easing.type: Easing.OutCubic } }
    SystemClock { id: secondsClock; precision: SystemClock.Seconds; enabled: root.ticking }
    function syncSweep(): void {
        secondMotion.stop();
        if (!living) { sweep = second / 60; return; }
        if (second === 0) sweep = 0;
        secondMotion.from = sweep;
        secondMotion.to = (second + 1) / 60;
        secondMotion.start();
    }
    onSecondChanged: syncSweep()
    onLivingChanged: {
        syncSweep();
        if (!living) { pointerX = 0; pointerY = 0; }
    }
    NumberAnimation { id: secondMotion; target: root; property: "sweep"; duration: pointer.hovered ? 600 : 220; easing.type: Easing.OutQuad }
    HoverHandler {
        id: pointer
        onPointChanged: {
            if (!root.living) return;
            root.pointerX = Math.max(-1, Math.min(1, point.position.x / root.width * 2 - 1));
            root.pointerY = Math.max(-1, Math.min(1, point.position.y / root.height * 2 - 1));
        }
        onHoveredChanged: if (!hovered) { root.pointerX = 0; root.pointerY = 0; }
    }
    TapHandler { onTapped: if (root.living) landscape.ripple() }
    ClockLandscape {
        id: landscape
        x: 10; y: 6; width: parent.width - 20; height: 154
        animated: root.living
        pointerX: root.pointerX; pointerY: root.pointerY
        seconds: root.sweep
        night: root.now.getHours() < 6 || root.now.getHours() >= 19
    }
    Text {
        x: 26; y: 23
        text: root.now.toLocaleDateString(I18n.qtLocale, "dddd").toUpperCase()
        color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 11; font.letterSpacing: 1.5
    }
    Row {
        x: 23; y: 48
        Repeater {
            model: 5
            Item {
                required property int index
                width: index === 2 ? 17 : 39; height: 82
                ClockDigit {
                    anchors.fill: parent
                    visible: parent.index !== 2
                    value: root.digits.charAt(parent.index < 2 ? parent.index : parent.index - 1)
                    animated: root.living
                }
                Column {
                    anchors.centerIn: parent
                    visible: parent.index === 2; spacing: 10
                    opacity: root.living ? (root.second % 2 ? 0.35 : 0.9) : 0.8
                    Behavior on opacity { NumberAnimation { duration: root.living ? 800 : 0; easing.type: Easing.InOutSine } }
                    Repeater { model: 2; Rectangle { width: 5; height: 5; radius: 2.5; color: Session.accent } }
                }
            }
        }
    }
    Row {
        x: 27; y: 130; spacing: 5
        Row {
            Repeater {
                model: 2
                ClockDigit {
                    required property int index
                    width: 8; height: 16; pixelSize: 11
                    value: String(root.second).padStart(2, "0").charAt(index)
                    animated: root.living
                }
            }
        }
        Text { text: I18n.tr("common.seconds_short"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10 }
    }
    Rectangle {
        x: 26; y: parent.height - 46; width: parent.width - 52; height: 1
        color: Glass.tint(Session.accent, 0.18)
        Rectangle { width: parent.width * root.sweep; height: 1; color: Session.accent; opacity: 0.8 }
        Rectangle { x: parent.width * root.sweep - 2; y: -2; width: 5; height: 5; radius: 2.5; color: Session.foreground }
    }
    Text {
        x: 26; anchors.bottom: parent.bottom; anchors.bottomMargin: 17
        text: root.now.toLocaleDateString(I18n.qtLocale, "d MMMM yyyy")
        color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 13
    }
    IpcHandler {
        target: "desktop-clock"
        function status(): string { return JSON.stringify({animated: root.living, ticking: root.ticking, second: root.second, phase: landscape.phase, sweep: root.sweep, digits: root.digits, pointer: [root.pointerX, root.pointerY]}); }
    }
}
