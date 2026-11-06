pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Layouts
SettingsCard {
    id: root
    property string title: ""
    property string subtitle: ""
    property string detail: ""
    property string symbol: "settings"
    property color tint: PolyTheme.Theme.color("#b7c99e")
    property bool showToggle: false
    property bool toggled: false
    property bool toggleAvailable: true
    signal clicked()
    signal toggleRequested()
    TapHandler { onTapped: eventPoint => { if (root.showToggle && eventPoint.position.x > root.width - 130) return; root.clicked(); } }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    border.color: hover.hovered ? PolyTheme.Theme.color("#73818a7d") : PolyTheme.Theme.color("#665f6566")
    RowLayout {
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 15
        SettingsBadge { symbol: root.symbol; tint: root.tint; Layout.preferredWidth: root.padding === 12 ? 36 : 48; Layout.preferredHeight: root.padding === 12 ? 40 : 50; Layout.alignment: Qt.AlignTop }
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 5
            Text { Layout.fillWidth: true; text: root.title; color: PolyTheme.Theme.color("#f0f1f4"); font.family: Session.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold }
            Text { Layout.fillWidth: true; visible: !!root.subtitle; text: root.subtitle; color: PolyTheme.Theme.color("#c3c8d0"); font.family: Session.fontFamily; font.pixelSize: root.padding === 12 ? 10 : 12; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
            Text { Layout.fillWidth: true; visible: !!root.detail; text: root.detail; color: PolyTheme.Theme.color("#afc99e"); font.family: Session.fontFamily; font.pixelSize: 11; elide: Text.ElideRight }
            Item { Layout.fillHeight: true }
        }
        SettingsToggle { visible: root.showToggle; checked: root.toggled; enabled: root.toggleAvailable; Accessible.name: root.title; onToggled: root.toggleRequested() }
        ToolButton {
            Layout.preferredWidth: 22; Layout.preferredHeight: 32
            Accessible.name: I18n.tr("common.open_colon") + " " + root.title
            background: Item {}
            contentItem: Icon { name: "chevron-right" }
            onClicked: root.clicked()
        }
    }
}
