pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Quickshell registers the platform-specific PanelWindow at runtime. Its generated
// interface metadata marks the type uncreatable, which misleads static qmllint.
// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: bar

    required property var modelData
    screen: modelData
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: Session.settings.bar ? Session.settings.bar.height : 42
    color: Session.background
    visible: Session.loaded
    WlrLayershell.namespace: "poly-shell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property int activeWorkspace: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
    readonly property bool compact: width < 960

    Behavior on color {
        ColorAnimation { duration: Session.motionMs }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Session.surface
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 5

        ActionButton {
            text: I18n.tr("bar.apps")
            hint: I18n.tr("bar.open_apps")
            onClicked: Session.launch("launcher")
        }

        Repeater {
            model: Session.settings.bar ? Session.settings.bar.workspaceCount : 5
            ActionButton {
                required property int index
                readonly property int workspaceId: index + 1
                text: String(workspaceId)
                highlighted: bar.activeWorkspace === workspaceId
                hint: I18n.trWith("bar.workspace", {id: workspaceId})
                onClicked: Session.focusWorkspace(workspaceId)
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.leftMargin: 8
            text: Session.error ? I18n.tr("bar.error_prefix") + Session.error : (Hyprland.activeToplevel ? Hyprland.activeToplevel.title : "Poly Shell")
            color: Session.error ? PolyTheme.Theme.color("#f1aa9b") : Session.muted
            font.family: Session.settings.bar ? Session.settings.bar.fontFamily : "Noto Sans"
            font.pixelSize: Session.settings.bar ? Session.settings.bar.fontSize : 13
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        ActionButton {
            text: I18n.tr("bar.term")
            hint: I18n.tr("bar.open_terminal")
            visible: !bar.compact
            onClicked: Session.launch("terminal")
        }

        ActionButton {
            text: Session.profile.label || "Work"
            highlighted: true
            enabled: !Session.switching
            hint: I18n.tr("bar.toggle_mode")
            onClicked: Session.setMode("toggle")
        }

        ActionButton {
            text: !Session.audio ? "Audio —" : (Session.audio.muted ? "Muted" : "Vol " + Math.round(Session.audio.volume * 100) + "%")
            hint: I18n.tr("bar.audio_settings")
            onClicked: Session.launch("audio")
        }

        Text {
            visible: Session.battery && Session.battery.ready && Session.battery.isLaptopBattery
            text: Session.batteryPresent ? Session.batteryDescription : ""
            color: Session.foreground
            font.family: Session.settings.bar ? Session.settings.bar.fontFamily : "Noto Sans"
            font.pixelSize: Session.settings.bar ? Session.settings.bar.fontSize : 13
            Layout.leftMargin: 6
            Layout.rightMargin: 6
        }

        Text {
            text: Qt.formatDateTime(ClockState.date, bar.compact ? "HH:mm" : "ddd, d MMM  HH:mm")
            color: Session.foreground
            font.family: Session.settings.bar ? Session.settings.bar.fontFamily : "Noto Sans"
            font.pixelSize: Session.settings.bar ? Session.settings.bar.fontSize : 13
            Layout.leftMargin: 6
            Layout.rightMargin: 6
        }

        ActionButton {
            text: I18n.tr("bar.lock")
            hint: I18n.tr("bar.lock_screen")
            onClicked: Session.launch("lock")
        }
    }
}
