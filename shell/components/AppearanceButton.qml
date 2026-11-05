pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: button
    property string symbol: "check"
    property bool primary: false
    property bool selected: false
    implicitHeight: 42
    implicitWidth: content.implicitWidth + 28
    leftPadding: 14; rightPadding: 14
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    background: Rectangle {
        radius: 11
        color: button.primary ? (button.down ? PolyTheme.Theme.color("#879b7c") : button.hovered ? PolyTheme.Theme.color("#becdad") : PolyTheme.Theme.color("#a9b99a"))
            : button.selected ? PolyTheme.Theme.color("#46563f") : button.down ? PolyTheme.Theme.color("#424c4f") : button.hovered ? PolyTheme.Theme.color("#3b454a") : PolyTheme.Theme.color("#30363d")
        border.width: button.visualFocus ? 2 : 1
        border.color: button.primary ? PolyTheme.Theme.color("#c7d2ba") : button.selected || button.visualFocus ? PolyTheme.Theme.color("#819675") : PolyTheme.Theme.color("#50595d")
        opacity: button.enabled ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: Motion.responseMs } }
    }
    contentItem: RowLayout {
        id: content
        spacing: 9
        opacity: button.enabled ? 1 : 0.4
        Icon { name: button.symbol; Layout.preferredWidth: 17; Layout.preferredHeight: 17 }
        Text {
            Layout.fillWidth: true
            text: button.text; color: button.primary ? PolyTheme.Theme.color("#202b24") : Session.foreground
            font.family: Session.fontFamily; font.pixelSize: 12; font.weight: button.primary ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }
    }
}
