pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Button {
    id: root
    required property string symbol
    required property string title
    property string subtitle: ""
    property bool active: false
    property string execCommand: ""
    property bool busy: false

    signal activated()

    implicitHeight: 64
    implicitWidth: 160
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: title + (subtitle ? ", " + subtitle : "")

    Process {
        id: runner
    }

    background: Rectangle {
        radius: Math.min(14, Session.visual.panelRadius)
        color: root.active
            ? Glass.tint(Session.accent, root.down ? 0.38 : (root.hovered ? 0.30 : 0.22))
            : Glass.tint(Session.surface, root.down ? 0.70 : (root.hovered ? 0.55 : 0.35))
        border.width: root.active ? 1.2 : Session.visual.panelBorder
        border.color: root.active
            ? Session.accent
            : (root.hovered ? Glass.tint(Session.foreground, 0.22) : Glass.tint(Session.foreground, 0.10))

        Behavior on color { ColorAnimation { duration: Motion.responseMs } }
        Behavior on border.color { ColorAnimation { duration: Motion.responseMs } }
    }

    contentItem: RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Icon Box
        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 8
            color: root.active ? Glass.tint(Session.accent, 0.5) : Glass.tint(Session.surface, 0.6)

            Icon {
                anchors.centerIn: parent
                name: root.symbol
                width: 20
                height: 20
            }
        }

        // Title and Subtitle
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Session.foreground
                font.family: Session.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                visible: root.subtitle.length > 0
                Layout.fillWidth: true
                text: root.subtitle
                color: root.active ? Session.accent : Session.muted
                font.family: Session.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }

    onClicked: {
        root.activated();
        if (root.execCommand && root.execCommand.length > 0) {
            runner.command = ["bash", "-c", root.execCommand];
            runner.running = true;
        }
    }
}
