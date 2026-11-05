pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Layouts

ColumnLayout {
    id: root
    signal expandRequested()
    readonly property var entries: BarState.notifications.map(item => ({item: item, archived: false}))
        .concat(BarState.visibleHistory.map(item => ({item: item, archived: true}))).slice(0, 2)
    spacing: 8
    SettingsRow {
        Layout.fillWidth: true; Layout.preferredHeight: 54
        symbol: BarState.dnd ? "bell-muted" : "bell"
        text: I18n.tr("notification.dnd")
        subtitle: BarState.dnd ? I18n.tr("notification.dnd_on_desc") : I18n.tr("notification.dnd_off_desc")
        selected: BarState.dnd; enabled: !BarState.notificationBusy
        onClicked: BarState.toggleDnd()
    }
    Text {
        visible: !!BarState.notificationError; text: BarState.notificationError
        Layout.fillWidth: true; color: Session.foreground; font.family: Session.fontFamily
        font.pixelSize: 10; wrapMode: Text.Wrap
    }
    Text {
        visible: root.entries.length > 0
        text: BarState.notifications.length ? I18n.trWith("notification.active_count", {count: BarState.notifications.length}) : I18n.trWith("notification.history_count", {count: BarState.visibleHistory.length})
        color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10
    }
    Repeater {
        model: root.entries
        NotificationCard {
            required property var modelData
            Layout.fillWidth: true; Layout.preferredHeight: implicitHeight
            notification: modelData.item; archived: modelData.archived; compact: true
        }
    }
    Text {
        visible: root.entries.length === 0
        Layout.fillWidth: true; Layout.preferredHeight: 54
        text: I18n.tr("notification.all_quiet"); color: Session.muted; font.family: Session.fontFamily
        font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    }
    SettingsRow {
        Layout.fillWidth: true; Layout.preferredHeight: 40
        text: I18n.tr("notification.open_all"); symbol: "bell"
        onClicked: root.expandRequested()
    }
}
