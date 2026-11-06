pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Layouts

ColumnLayout {
    id: root
    signal expandRequested()
    readonly property var entries: ClipboardState.entries.slice(0, 3)
    spacing: 8
    Text {
        Layout.fillWidth: true
        text: ClipboardState.error || (ClipboardState.paused ? I18n.tr("clipboard.history_paused") : I18n.trWith("clipboard.history_count", {count: ClipboardState.entries.length}))
        textFormat: Text.PlainText; elide: Text.ElideRight
        color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10
    }
    Repeater {
        model: root.entries
        ClipboardEntry {
            required property var modelData
            entry: modelData; compact: true
            Layout.fillWidth: true; Layout.preferredHeight: implicitHeight
        }
    }
    Text {
        visible: root.entries.length === 0
        Layout.fillWidth: true; Layout.preferredHeight: 64
        text: I18n.tr("clipboard.empty_hint")
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 12
    }
    SettingsRow {
        Layout.fillWidth: true; Layout.preferredHeight: 40
        text: I18n.tr("clipboard.open_all"); symbol: "clipboard"
        onClicked: root.expandRequested()
    }
}
