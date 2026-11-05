import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray

Button {
    id: control
    required property var trayItem
    implicitWidth: 28; implicitHeight: 30
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    enabled: !!trayItem
    Accessible.name: trayItem ? (trayItem.tooltipTitle || trayItem.title || trayItem.id) : ""
    background: Rectangle {
        radius: 8
        color: control.down ? PolyTheme.Theme.color("#485149") : (control.hovered || control.visualFocus ? PolyTheme.Theme.color("#353e39") : "transparent")
        border.width: control.visualFocus ? 1 : 0
        border.color: PolyTheme.Theme.color("#a4b396")
        Behavior on color { ColorAnimation { duration: Motion.responseMs } }
    }
    contentItem: Item {
        Image {
            anchors.centerIn: parent
            source: control.trayItem ? control.trayItem.icon : ""
            width: 17; height: 17
            sourceSize.width: Math.ceil(width * Screen.devicePixelRatio * 2)
            sourceSize.height: Math.ceil(height * Screen.devicePixelRatio * 2)
            fillMode: Image.PreserveAspectFit
        }
        Rectangle { visible: !!control.trayItem && control.trayItem.status === Status.NeedsAttention; x: parent.width - 5; y: 2; width: 4; height: 4; radius: 2; color: PolyTheme.Theme.color("#b4c39e") }
    }
    QsMenuAnchor {
        id: menu
        anchor.item: control
        // Generated metadata loses the QFlags conversion accepted at runtime.
        // qmllint disable incompatible-type
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        // qmllint enable incompatible-type
        menu: control.trayItem ? control.trayItem.menu : null
    }
    function openMenu(): void { if (trayItem && trayItem.hasMenu) menu.open(); }
    onClicked: { if (!trayItem) return; if (trayItem.onlyMenu) openMenu(); else trayItem.activate(); }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => { if (!control.trayItem) return; if (mouse.button === Qt.MiddleButton) control.trayItem.secondaryActivate(); else control.openMenu(); }
    }
    WheelHandler {
        onWheel: event => {
            if (!control.trayItem) return;
            const horizontal = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y);
            control.trayItem.scroll(horizontal ? event.angleDelta.x : event.angleDelta.y, horizontal);
            event.accepted = true;
        }
    }
}
