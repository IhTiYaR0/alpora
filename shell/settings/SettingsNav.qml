pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Layouts
Button {
    id: root
    property string symbol: "home"
    property bool selected: false
    implicitHeight: 37
    hoverEnabled: true
    Accessible.name: text
    background: Rectangle {
        radius: 11
        gradient: Gradient {
            GradientStop { position: 0; color: root.selected ? PolyTheme.Theme.color("#647453") : root.hovered ? PolyTheme.Theme.color("#3b4245") : "transparent" }
            GradientStop { position: 1; color: root.selected ? PolyTheme.Theme.color("#48583f") : root.hovered ? PolyTheme.Theme.color("#30373a") : "transparent" }
        }
        border.width: root.selected || root.visualFocus ? 1 : 0
        border.color: root.visualFocus ? PolyTheme.Theme.color("#eef2e5") : PolyTheme.Theme.color("#a6bc8f")
    }
    contentItem: RowLayout {
        spacing: 15
        Icon { Layout.leftMargin: 13; Layout.preferredWidth: 21; Layout.preferredHeight: 21; name: root.symbol }
        Text { Layout.fillWidth: true; text: root.text; color: PolyTheme.Theme.color("#edf0f3"); font.family: Session.fontFamily; font.pixelSize: 12; elide: Text.ElideRight }
    }
}
