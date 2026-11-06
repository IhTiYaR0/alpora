pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as PolyTheme

Button {
    id: root
    required property string title
    required property string symbol
    property string detail: ""
    property string stateText: ""
    property bool active: false
    property bool connected: false
    property string statusKind: ""
    property int statusLevel: 0
    property bool statusBusy: false
    property bool statusWarning: false
    implicitHeight: stateText ? 94 : 78
    implicitWidth: 120
    padding: 9; hoverEnabled: true
    Accessible.name: title + ", " + detail + ", " + stateText
    Accessible.checkable: true; Accessible.checked: active
    background: Rectangle {
        radius: Math.min(Session.visual.panelRadius, height / 2)
        color: PolyTheme.Theme.mix(Session.background, Session.surface, root.hovered || root.down ? 0.90 : 0.56)
        border.color: root.visualFocus ? Session.foreground : Glass.tint(Session.accent, root.connected ? 0.55 : 0.30)
        border.width: root.visualFocus ? 1.5 : 0.8
        Behavior on color { ColorAnimation { duration: Motion.responseMs } }
    }
    contentItem: ColumnLayout {
        opacity: root.enabled ? 1 : 0.45
        spacing: 3
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 22
            Item {
                Layout.preferredWidth: 22; Layout.preferredHeight: 22
                Icon { anchors.fill: parent; visible: !root.statusKind; name: root.symbol }
                StatusIcon { anchors.fill: parent; visible: !!root.statusKind; kind: root.statusKind; level: root.statusLevel; busy: root.statusBusy; warning: root.statusWarning }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 17; radius: 8.5
                color: root.active ? Glass.tint(Session.accent, 0.45) : Glass.tint(Session.muted, 0.22)
                Rectangle {
                    x: root.active ? 17 : 3; y: 3; width: 11; height: 11; radius: 5.5
                    color: root.active ? Session.accent : Session.muted
                    Behavior on x { NumberAnimation { duration: Motion.responseMs } }
                }
            }
        }
        Text {
            Layout.fillWidth: true; text: root.title
            color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11; font.weight: Font.Medium
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true; text: root.detail
            color: root.connected ? Session.accent : Session.muted
            font.family: Session.fontFamily; font.pixelSize: 11
            elide: Text.ElideMiddle
        }
        Text {
            visible: !!root.stateText
            Layout.fillWidth: true; text: root.stateText
            color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10
            wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
        }
    }
}
