import QtQuick
import ".."
import "../theme" as PolyTheme
Rectangle {
    id: root
    property string symbol: "settings"
    property color tint: PolyTheme.Theme.color("#afc49a")
    implicitWidth: 48; implicitHeight: 50
    radius: 13
    color: Qt.rgba(tint.r, tint.g, tint.b, 0.13)
    border.width: 1; border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.36)
    Icon { anchors.centerIn: parent; name: root.symbol === "gem" ? "palette" : root.symbol; visible: root.symbol !== "gem"; width: 25; height: 25 }
    GemMark { anchors.centerIn: parent; width: 27; height: 34; visible: root.symbol === "gem" }
}
