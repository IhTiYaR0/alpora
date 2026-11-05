import QtQuick
import ".."
import "../theme" as PolyTheme

Item {
    id: root
    property real charge: 1
    property bool charging: Session.batteryCharging
    property bool pluggedIn: !Session.onBattery
    readonly property color ink: pluggedIn ? Session.accent : Session.foreground
    implicitWidth: 25
    implicitHeight: 16
    Rectangle {
        x: 0; y: 1
        width: parent.width - 3
        height: parent.height - 2
        radius: 2.5
        color: "transparent"
        border.width: 1.4
        border.color: root.ink
        Rectangle {
            x: 3; y: 3
            width: Math.max(0, (parent.width - 6) * Math.min(1, Math.max(0, root.charge)))
            height: parent.height - 6
            radius: 0.8
            color: root.ink
        }
    }
    Rectangle {
        x: parent.width - 2; y: parent.height / 2 - 3
        width: 2; height: 6; radius: 1
        color: root.ink
    }
    Canvas {
        anchors.fill: parent
        visible: root.charging
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.scale(width / 25, height / 16);
            ctx.beginPath();
            ctx.moveTo(14, 0.5); ctx.lineTo(8, 9);
            ctx.lineTo(12, 9); ctx.lineTo(10, 15.5);
            ctx.lineTo(17, 6); ctx.lineTo(13, 6);
            ctx.closePath();
            ctx.lineWidth = 2.2;
            ctx.lineJoin = "round";
            ctx.strokeStyle = PolyTheme.Theme.color("#202628");
            ctx.stroke();
            ctx.fillStyle = PolyTheme.Theme.color("#edf2f4");
            ctx.fill();
        }
    }
}
