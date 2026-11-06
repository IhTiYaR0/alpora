pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Layouts

Rectangle {
    id: card
    property string title: ""
    property string description: ""
    property string symbol: "settings"
    default property alias fields: fields.data
    implicitHeight: contents.implicitHeight + 28
    radius: 17
    color: PolyTheme.Theme.color("#30363c")
    border.width: 1; border.color: PolyTheme.Theme.color("#51595b")
    ColumnLayout {
        id: contents
        x: 14; y: 14; width: parent.width - 28; spacing: 10
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32
                radius: 12; color: PolyTheme.Theme.color("#414c43"); border.width: 1; border.color: PolyTheme.Theme.color("#65785b")
                Icon { anchors.centerIn: parent; name: card.symbol; width: 23; height: 23 }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                Text { Layout.fillWidth: true; text: card.title; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold }
                Text { Layout.fillWidth: true; visible: !!card.description; text: card.description; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap }
            }
        }
        ColumnLayout { id: fields; Layout.fillWidth: true; spacing: 8 }
    }
}
