pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: osd
    required property var modelData
    screen: modelData
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 140
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    readonly property bool opened: OsdState.opened && OsdState.screenName === modelData.name
    property real reveal: opened ? 1 : 0
    visible: opened || reveal > 0.001
    WlrLayershell.namespace: "poly-shell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    Behavior on reveal { NumberAnimation { duration: Motion.reduced ? 0 : osd.opened ? 200 : 140; easing.type: Easing.OutCubic } }
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 20 + 12 * (1 - osd.reveal)
        width: Math.min(330, osd.width - 32); height: 76
        opacity: osd.reveal
        SoftShadow { anchors.fill: parent; cornerRadius: 18; spread: 8 }
        Rectangle {
            anchors.fill: parent; radius: 18
            color: Glass.tint(Session.background, 0.86)
            border.width: 1; border.color: Glass.tint(Session.accent, 0.55)
            RowLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 14
                Icon { name: OsdState.symbol; Layout.preferredWidth: 26; Layout.preferredHeight: 26 }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 9
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: OsdState.title; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12; Layout.fillWidth: true }
                        Text {
                            text: OsdState.isToggle ? (OsdState.muted ? "OFF" : "ON") : (OsdState.muted ? I18n.tr("common.off") : Math.round(OsdState.value * 100) + "%")
                            color: OsdState.muted ? Session.muted : Session.accent
                            font.family: Session.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                    Rectangle {
                        visible: !OsdState.isToggle
                        Layout.fillWidth: true; Layout.preferredHeight: 5; radius: 3
                        color: Glass.tint(Session.foreground, 0.13)
                        Rectangle {
                            width: parent.width * (OsdState.muted ? 0 : Math.min(1, OsdState.value))
                            height: parent.height; radius: 3; color: Session.accent
                            Behavior on width { NumberAnimation { duration: Motion.reduced ? 0 : 100; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }
    }
}
