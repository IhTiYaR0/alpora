pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as PolyTheme

Rectangle {
    id: row
    required property var entry
    property bool compact: false
    property bool selected: false
    signal activated()
    implicitHeight: compact ? (entry.image ? 76 : 68) : (entry.image ? 112 : 84)
    radius: Math.min(12, Session.visual.panelRadius)
    color: PolyTheme.Theme.withAlpha(Session.surface, rowHover.hovered ? 0.95 : 0.6)
    border.width: 1
    border.color: row.selected ? Session.accent : PolyTheme.Theme.withAlpha(Session.muted, 0.2)
    HoverHandler { id: rowHover }
    Button {
        anchors.fill: parent; anchors.rightMargin: row.compact ? 0 : 72
        padding: row.compact ? 10 : 12; hoverEnabled: true
        enabled: ClipboardState.ready && !ClipboardState.busy
        Accessible.name: I18n.tr("clipboard.copy_prefix") + " " + row.entry.preview.slice(0, 100)
        background: Item {}
        onClicked: { row.activated(); ClipboardState.request("copy", row.entry.id); }
        contentItem: RowLayout {
            spacing: 10
            Image {
                visible: !!row.entry.image
                source: row.entry.image
                sourceSize: Qt.size(160, 160)
                Layout.preferredWidth: row.compact ? 44 : 78; Layout.preferredHeight: row.compact ? 44 : 78
                fillMode: Image.PreserveAspectFit; asynchronous: true
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 5
                Text {
                    Layout.fillWidth: true
                    text: (row.entry.pinned ? I18n.tr("clipboard.pinned") + " · " : "") + (row.entry.image ? I18n.tr("clipboard.image") : I18n.tr("clipboard.text")) + " · " + Math.max(1, Math.round(row.entry.size / 1024)) + " " + I18n.tr("clipboard.kb")
                    color: row.entry.pinned ? Session.accent : Session.muted
                    font.family: Session.fontFamily; font.pixelSize: 10; elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: row.entry.preview; textFormat: Text.PlainText
                    color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12
                    wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideRight
                }
            }
        }
    }
    Row {
        visible: !row.compact
        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        BarButton {
            symbol: "pin"; highlighted: row.entry.pinned
            hint: row.entry.pinned ? I18n.tr("clipboard.unpin") : I18n.tr("clipboard.pin")
            enabled: ClipboardState.ready && !ClipboardState.busy
            onClicked: ClipboardState.request("pin", row.entry.id)
        }
        BarButton {
            symbol: "close"; hint: I18n.tr("clipboard.delete_entry")
            enabled: ClipboardState.ready && !ClipboardState.busy
            onClicked: ClipboardState.request("delete", row.entry.id)
        }
    }
}
