pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: tile
    required property string title
    required property string symbol
    property string subtitle: ""
    property bool active: false
    property bool details: false
    property bool compact: false
    property real compactProgress: compact ? 1 : 0
    property string statusKind: ""
    property int statusLevel: 0
    property bool statusBusy: false
    property bool statusWarning: false
    signal toggled()
    signal detailsRequested()
    implicitHeight: details ? 86 : 80 - 36 * compactProgress
    radius: 13
    color: toggle.hovered ? Glass.tint(Session.accent, 0.12) : Glass.tint(Session.surface, 0.40)
    border.width: toggle.visualFocus || detailButton.visualFocus ? 1.5 : 1
    border.color: toggle.visualFocus || detailButton.visualFocus ? Session.accent : Glass.tint(Session.accent, tile.active ? 0.40 : 0.19)
    Behavior on color { ColorAnimation { duration: Motion.responseMs } }
    Button {
        id: toggle
        anchors.fill: parent; anchors.rightMargin: tile.details ? 33 : 0
        hoverEnabled: true; padding: 0
        Accessible.name: tile.title + ", " + (tile.subtitle || (tile.active ? I18n.tr("common.enabled") : I18n.tr("common.disabled")))
        Accessible.checkable: true; Accessible.checked: tile.active
        background: Item {}
        contentItem: Item {
            opacity: tile.enabled ? 1 : 0.4
            RowLayout {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 12; anchors.rightMargin: 10 + (tile.details ? 0 : 36 * tile.compactProgress)
                anchors.top: parent.top; anchors.topMargin: tile.details ? 17 : 14 - 4 * tile.compactProgress
                spacing: 8
                Item {
                    Layout.preferredWidth: tile.details ? 25 : 21; Layout.preferredHeight: 25
                    Icon { anchors.fill: parent; name: tile.symbol; visible: !tile.statusKind }
                    StatusIcon { anchors.fill: parent; visible: !!tile.statusKind; kind: tile.statusKind; level: tile.statusLevel; busy: tile.statusBusy; warning: tile.statusWarning }
                }
                Text { Layout.fillWidth: true; text: tile.title; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11; elide: Text.ElideRight }
                Rectangle {
                    visible: tile.details
                    Layout.preferredWidth: 31; Layout.preferredHeight: 18; radius: 9
                    color: tile.active ? Session.accent : Glass.tint(Session.muted, 0.30)
                    Rectangle { x: tile.active ? 15 : 3; y: 3; width: 12; height: 12; radius: 6; color: tile.active ? Session.foreground : Session.muted; Behavior on x { NumberAnimation { duration: Motion.responseMs } } }
                }
            }
            Text {
                visible: tile.details
                anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 45; anchors.rightMargin: 10
                y: 46; height: 30; wrapMode: Text.Wrap; maximumLineCount: 2; text: tile.subtitle; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; elide: Text.ElideRight
            }
            Rectangle {
                visible: !tile.details
                x: (1 - tile.compactProgress) * (parent.width - width) / 2 + tile.compactProgress * (parent.width - width - 10)
                y: 49 - 36 * tile.compactProgress
                width: 32; height: 18; radius: 9
                color: tile.active ? Session.accent : Glass.tint(Session.muted, 0.30)
                Rectangle { x: tile.active ? 17 : 3; y: 3; width: 12; height: 12; radius: 6; color: tile.active ? Session.foreground : Session.muted; Behavior on x { NumberAnimation { duration: Motion.responseMs } } }
            }
        }
        onClicked: {
            AudioFeedback.playTock();
            tile.toggled();
        }
    }
    Button {
        id: detailButton
        visible: tile.details
        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: 33; hoverEnabled: true; padding: 0
        Accessible.name: tile.title + " — " + I18n.tr("quick.select_device")
        background: Rectangle {
            radius: 10; color: detailButton.hovered ? Glass.tint(Session.accent, 0.12) : "transparent"
            Rectangle { width: 1; height: parent.height - 28; anchors.verticalCenter: parent.verticalCenter; color: Glass.tint(Session.accent, 0.20) }
        }
        contentItem: Item { Icon { anchors.centerIn: parent; name: "chevron-right"; width: 15; height: 15 } }
        onClicked: tile.detailsRequested()
    }
}
