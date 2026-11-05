pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: card
    required property var notification
    property bool archived: false
    property bool compact: false
    property real detailProgress: compact ? 0 : 1
    readonly property var actions: archived ? [] : Object.keys(notification.actions || {}).map(key => ({ key: key, label: String(notification.actions[key]).trim() || (key === "default" ? I18n.tr("notification.action_default") : I18n.tr("notification.action_fallback")) }))
    implicitHeight: details.implicitHeight + Session.visual.notificationPadding * 2
    radius: Session.visual.notificationRadius
    color: Glass.tint(Session.surface, Session.visual.notificationOpacity / 100)
    border.width: Session.visual.notificationBorder
    border.color: notification.urgency === "critical" ? PolyTheme.Theme.color("#d18e82") : Glass.tint(Session.accent, 0.2)
    SoftShadow { anchors.fill: parent; z: -1; cornerRadius: card.radius; spread: 3; strength: Session.visual.notificationShadow / 20 }
    ColumnLayout {
        id: details
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.margins: Session.visual.notificationPadding; spacing: 0
        RowLayout {
            Layout.fillWidth: true; Layout.bottomMargin: 7; spacing: 8 * card.detailProgress
            Image {
                id: appIcon
                Layout.preferredWidth: 20 * card.detailProgress; Layout.preferredHeight: 12 + 8 * card.detailProgress
                visible: status === Image.Ready; opacity: card.detailProgress
                source: card.notification.app_icon ? (card.notification.app_icon.startsWith("/") ? "file://" + card.notification.app_icon : Quickshell.iconPath(card.notification.app_icon, true)) : ""
                sourceSize.width: 40; sourceSize.height: 40; fillMode: Image.PreserveAspectFit
            }
            Text { Layout.fillWidth: true; text: card.notification.app_name || I18n.tr("dock.app_fallback"); textFormat: Text.PlainText; color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 10; elide: Text.ElideRight }
            Text { visible: card.archived; text: I18n.tr("notification.history"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 9 }
            BarButton { visible: !card.archived; opacity: card.detailProgress; Layout.preferredWidth: 24 * card.detailProgress; Layout.preferredHeight: 12 + 12 * card.detailProgress; symbol: "close"; hint: I18n.tr("notification.dismiss"); implicitWidth: 24; implicitHeight: 24; enabled: !BarState.notificationBusy; onClicked: BarState.dismissNotification(card.notification.id) }
        }
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(15, summaryText.implicitHeight) + Math.max(0, summaryText.implicitHeight - 15) * card.detailProgress
            clip: true
            Text {
                id: summaryText
                width: parent.width; text: card.notification.summary || ""; textFormat: Text.PlainText
                color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12
                font.weight: Font.Medium; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight
            }
        }
        Item {
            Layout.fillWidth: true; Layout.topMargin: 7 * card.detailProgress; Layout.preferredHeight: bodyText.implicitHeight * card.detailProgress
            visible: bodyText.text.length > 0
            clip: true
            Text {
                id: bodyText
                width: parent.width; text: (card.notification.body || "").replace(/<[^>]*>/g, "")
                textFormat: Text.PlainText; color: Session.muted; font.family: Session.fontFamily
                font.pixelSize: 11; wrapMode: Text.Wrap; maximumLineCount: 7; elide: Text.ElideRight
            }
        }
        Item {
            Layout.fillWidth: true; Layout.topMargin: 7 * card.detailProgress; Layout.preferredHeight: actionFlow.implicitHeight * card.detailProgress
            visible: card.actions.length > 0; clip: true
        Flow {
            id: actionFlow
            width: parent.width
            spacing: 6
            Repeater {
                model: card.actions
                DayAction {
                    required property var modelData
                    text: modelData.label; implicitHeight: 29
                    enabled: !BarState.notificationBusy
                    onClicked: BarState.invokeNotification(card.notification.id, modelData.key)
                }
            }
        }
        }
    }
}
