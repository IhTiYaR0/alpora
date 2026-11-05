pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls

Item {
    id: root
    required property string label
    required property string symbol
    property string detail: ""
    property real value: 0
    property real minimum: 0
    property bool adjustable: true
    property bool muted: false
    property bool hasMute: false
    property string statusKind: ""
    property int statusLevel: 0
    readonly property bool dragging: slider.pressed
    signal adjusted(real value)
    signal muteRequested()
    implicitHeight: 68
    Button {
        id: iconButton
        x: 4; y: 15; width: 34; height: 34; padding: 0
        enabled: root.hasMute && root.adjustable
        Accessible.name: root.muted ? I18n.tr("audio.unmute") : I18n.tr("audio.mute")
        background: Rectangle { visible: iconButton.hovered || iconButton.visualFocus; radius: Math.min(Session.visual.panelRadius, height / 2); color: Glass.tint(Session.accent, 0.10); border.width: 1; border.color: iconButton.visualFocus ? Session.accent : "transparent" }
        contentItem: Item {
            Icon { anchors.fill: parent; anchors.margins: 2; visible: !root.statusKind; name: root.symbol; opacity: root.adjustable ? 1 : 0.4 }
            StatusIcon { anchors.fill: parent; anchors.margins: 2; visible: !!root.statusKind; kind: root.statusKind; level: root.statusLevel }
        }
        onClicked: root.muteRequested()
    }
    Text {
        x: 49; y: 3; width: root.width - x - 55
        text: root.label; color: Session.foreground
        font.family: Session.fontFamily; font.pixelSize: 13; font.weight: Font.Medium
        elide: Text.ElideRight
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 4; y: 3
        text: root.adjustable ? Math.round(slider.value * 100) + "%" : "—"
        color: root.muted ? Session.muted : Session.foreground
        font.family: Session.fontFamily; font.pixelSize: 13
    }
    Text {
        x: 49; y: 23; width: root.width - x - 4
        text: root.detail; color: Session.muted
        font.family: Session.fontFamily; font.pixelSize: 11
        elide: Text.ElideMiddle
    }
    Slider {
        id: slider
        x: 49; y: 40; width: root.width - x - 4; height: 30
        enabled: root.adjustable; opacity: root.adjustable ? (root.muted ? 0.45 : 1) : 0.35
        from: root.minimum; to: 1; value: root.value; stepSize: 0.01
        wheelEnabled: true; leftPadding: 7; rightPadding: 7
        Accessible.name: root.label
        onMoved: root.adjusted(value)
        background: Rectangle {
            x: slider.leftPadding; y: slider.availableHeight / 2 - 3
            width: slider.availableWidth; height: 6; radius: 3
            color: Glass.tint(Session.muted, 0.22)
            Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 3; color: Session.accent }
        }
        handle: Item {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.availableHeight / 2 - 8
            width: 14; height: 16
            scale: slider.pressed ? 1.13 : 1
            Behavior on scale { NumberAnimation { duration: Motion.responseMs } }
            Rectangle {
                anchors.fill: parent
                radius: Math.min(Session.visual.panelRadius, width / 2)
                border.width: slider.visualFocus ? 2 : 1
                border.color: Session.foreground
                color: Session.accent
            }

        }
    }
}
