pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property int score: 95
    property string statusText: score >= 80 ? "Hệ thống được bảo vệ" : (score >= 60 ? "Cần lưu ý" : "Nguy cơ bảo mật")
    property bool firewallActive: true
    property bool waylandActive: true
    property bool apparmorActive: true

    signal auditRequested()
    signal hardenRequested()

    implicitHeight: 96
    radius: (Session.visual && Session.visual.panelRadius !== undefined) ? Session.visual.panelRadius : 14
    color: hoverHandler.hovered ? Glass.tint(Session.surface, 0.65) : Glass.tint(Session.surface, 0.45)
    border.width: 1
    border.color: hoverHandler.hovered ? Session.accent : (score >= 80 ? Glass.tint(Session.accent, 0.40) : Glass.tint(Session.muted, 0.25))

    HoverHandler { id: hoverHandler }
    TapHandler { onTapped: root.auditRequested() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: width / 2
                color: root.score >= 80 ? Glass.tint(Session.accent, 0.25) : Glass.tint(Session.muted, 0.20)
                border.width: 1.5
                border.color: root.score >= 80 ? Session.accent : Session.muted

                Text {
                    anchors.centerIn: parent
                    text: root.score >= 80 ? "🛡️" : "⚠️"
                    font.pixelSize: 16
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "ALPORA Security Shield"
                    color: Session.muted
                    font.family: Session.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                Text {
                    text: root.statusText
                    color: Session.foreground
                    font.family: Session.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }

            Rectangle {
                Layout.preferredHeight: 22
                Layout.preferredWidth: 58
                radius: 11
                color: Glass.tint(Session.accent, 0.20)
                border.width: 1
                border.color: Session.accent

                Text {
                    anchors.centerIn: parent
                    text: root.score + " / 100"
                    color: Session.foreground
                    font.family: Session.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Glass.tint(Session.foreground, 0.08)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Wayland: " + (root.waylandActive ? "🟢 Cô lập" : "🔴 X11")
                color: Session.muted
                font.family: Session.fontFamily
                font.pixelSize: 10
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "UFW: " + (root.firewallActive ? "🟢 Đang bật" : "⚪ Chưa bật")
                color: Session.muted
                font.family: Session.fontFamily
                font.pixelSize: 10
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Socket: 🟢 0o600"
                color: Session.muted
                font.family: Session.fontFamily
                font.pixelSize: 10
            }
        }
    }
}
