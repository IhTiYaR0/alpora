pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Layouts
Rectangle {
    id: root
    default property alias content: body.data
    property int padding: 18
    implicitHeight: body.implicitHeight + padding * 2
    radius: 15
    gradient: Gradient {
        GradientStop { position: 0; color: PolyTheme.Theme.color("#b33b4249") }
        GradientStop { position: 1; color: PolyTheme.Theme.color("#96262c32") }
    }
    border.width: 1; border.color: PolyTheme.Theme.color("#665f6566")
    ColumnLayout {
        id: body
        anchors.fill: parent; anchors.margins: root.padding; spacing: 14
    }
}
