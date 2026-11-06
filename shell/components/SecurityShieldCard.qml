pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property int score: 95
    property string statusText: score >= 80 ? I18n.tr("security.status_protected") : (score >= 60 ? I18n.tr("security.status_attention") : I18n.tr("security.status_risk"))
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

                Icon {
                    anchors.centerIn: parent
                    name: root.score >= 80 ? "shield" : "shield-alert"
                    width: 18
                    height: 18
                    color: root.score >= 80 ? Session.accent : Session.muted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: I18n.tr("security.shield_title")
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

            RowLayout {
                spacing: 5
                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: root.waylandActive ? Session.accent : Glass.tint(Session.foreground, 0.4)
                }
                Text {
                    text: "Wayland: " + (root.waylandActive ? I18n.tr("security.wayland_isolated") : I18n.tr("security.wayland_x11"))
                    color: Session.muted
                    font.family: Session.fontFamily
                    font.pixelSize: 10
                }
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: 5
                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: root.firewallActive ? Session.accent : Glass.tint(Session.foreground, 0.4)
                }
                Text {
                    text: "UFW: " + (root.firewallActive ? I18n.tr("security.ufw_enabled") : I18n.tr("security.ufw_disabled"))
                    color: Session.muted
                    font.family: Session.fontFamily
                    font.pixelSize: 10
                }
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: 5
                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: Session.accent
                }
                Text {
                    text: "Socket: 0o600"
                    color: Session.muted
                    font.family: Session.fontFamily
                    font.pixelSize: 10
                }
            }
        }
    }
}
