import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Layouts

Item {
    id: root
    property string title: ""
    property string subtitle: ""
    implicitHeight: 52
    Layout.fillWidth: true
    Layout.preferredHeight: 52
    Layout.fillHeight: false
    MountainRidge {
        anchors.right: parent.right; anchors.rightMargin: 44
        anchors.bottom: parent.bottom
        width: Math.min(230, parent.width * 0.36); height: 34
        opacity: 0.5
    }
    RowLayout {
        anchors.fill: parent; anchors.bottomMargin: 5
        spacing: 10
        GemMark { Layout.preferredWidth: 20; Layout.preferredHeight: 28 }
        Column {
            Layout.fillWidth: true
            spacing: 3
            Text { width: parent.width; text: root.title; textFormat: Text.PlainText; elide: Text.ElideRight; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 19; font.weight: Font.Medium }
            Text { width: parent.width; text: root.subtitle; textFormat: Text.PlainText; elide: Text.ElideRight; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10 }
        }
        BarButton { symbol: "close"; hint: I18n.tr("common.close"); onClicked: BarState.close() }
    }
    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: PolyTheme.Theme.color("#354139") }
}
