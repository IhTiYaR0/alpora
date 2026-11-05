pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: overlay
    required property var modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore; exclusiveZone: 0
    color: "transparent"
    visible: ScreenshotState.active && (ScreenshotState.targetScreen === "" || ScreenshotState.targetScreen === (modelData ? modelData.name : ""))
    WlrLayershell.namespace: "poly-screenshot-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real startX: 0
    property real startY: 0
    property real currentX: 0
    property real currentY: 0
    property bool selecting: false
    property bool hasSelection: selWidth > 10 && selHeight > 10

    readonly property real selX: Math.min(startX, currentX)
    readonly property real selY: Math.min(startY, currentY)
    readonly property real selWidth: Math.abs(currentX - startX)
    readonly property real selHeight: Math.abs(currentY - startY)

    readonly property real globalX: (modelData ? modelData.x : 0) + selX
    readonly property real globalY: (modelData ? modelData.y : 0) + selY

    function clear(): void {
        selecting = false;
        startX = 0; startY = 0; currentX = 0; currentY = 0;
    }

    onVisibleChanged: {
        if (!visible) clear();
        else focusScope.forceActiveFocus();
    }

    Item {
        id: focusScope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ScreenshotState.close()
        Keys.onReturnPressed: {
            if (overlay.hasSelection)
                ScreenshotState.capture(Math.round(overlay.globalX), Math.round(overlay.globalY), Math.round(overlay.selWidth), Math.round(overlay.selHeight), false);
            else
                ScreenshotState.capture(modelData ? modelData.x : 0, modelData ? modelData.y : 0, modelData ? modelData.width : 1920, modelData ? modelData.height : 1080, false);
        }
        Keys.onSpacePressed: {
            // Select entire screen
            overlay.startX = 0; overlay.startY = 0;
            overlay.currentX = modelData ? modelData.width : 1920;
            overlay.currentY = modelData ? modelData.height : 1080;
            overlay.selecting = false;
        }

        // Darkened veil
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.38
        }

        // Mouse selection handler
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor

            onPressed: mouse => {
                overlay.startX = mouse.x;
                overlay.startY = mouse.y;
                overlay.currentX = mouse.x;
                overlay.currentY = mouse.y;
                overlay.selecting = true;
            }

            onPositionChanged: mouse => {
                if (overlay.selecting) {
                    overlay.currentX = Math.max(0, Math.min(width, mouse.x));
                    overlay.currentY = Math.max(0, Math.min(height, mouse.y));
                }
            }

            onReleased: {
                overlay.selecting = false;
            }
        }

        // Selected bounding box highlight
        Rectangle {
            visible: overlay.hasSelection
            x: overlay.selX
            y: overlay.selY
            width: overlay.selWidth
            height: overlay.selHeight
            color: "transparent"
            border.color: Session.accent
            border.width: 2

            // Dimension badge
            Rectangle {
                visible: parent.width > 80 && parent.height > 40
                anchors.left: parent.left
                anchors.bottom: parent.top
                anchors.bottomMargin: 6
                width: dimText.implicitWidth + 14
                height: 22
                radius: 4
                color: Session.surface
                border.color: Session.accent
                border.width: 1

                Text {
                    id: dimText
                    anchors.centerIn: parent
                    text: Math.round(overlay.selWidth) + " × " + Math.round(overlay.selHeight)
                    color: Session.foreground
                    font.family: Session.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            // Floating action toolbar
            Rectangle {
                id: toolbar
                visible: !overlay.selecting && overlay.hasSelection
                anchors.top: parent.bottom
                anchors.topMargin: 8
                anchors.right: parent.right
                height: 38
                width: toolLayout.implicitWidth + 16
                radius: 10
                color: Session.surface
                border.color: Session.accent
                border.width: 1

                RowLayout {
                    id: toolLayout
                    anchors.centerIn: parent
                    spacing: 8

                    AppearanceButton {
                        text: I18n.tr("common.copy")
                        symbol: "check"
                        primary: true
                        onClicked: ScreenshotState.capture(Math.round(overlay.globalX), Math.round(overlay.globalY), Math.round(overlay.selWidth), Math.round(overlay.selHeight), false)
                    }

                    AppearanceButton {
                        text: I18n.tr("common.save")
                        symbol: "download"
                        onClicked: ScreenshotState.capture(Math.round(overlay.globalX), Math.round(overlay.globalY), Math.round(overlay.selWidth), Math.round(overlay.selHeight), true)
                    }

                    AppearanceButton {
                        text: I18n.tr("common.cancel")
                        symbol: "close"
                        onClicked: ScreenshotState.close()
                    }
                }
            }
        }

        // Top guidance hint
        Rectangle {
            visible: !overlay.hasSelection
            anchors.top: parent.top
            anchors.topMargin: 24
            anchors.horizontalCenter: parent.horizontalCenter
            height: 34
            width: hintRow.implicitWidth + 24
            radius: 8
            color: Session.surface
            border.color: Session.accent
            border.width: 1

            RowLayout {
                id: hintRow
                anchors.centerIn: parent
                spacing: 12

                Text {
                    text: I18n.tr("screenshot.drag_hint")
                    color: Session.foreground
                    font.family: Session.fontFamily
                    font.pixelSize: 13
                }
            }
        }
    }
}
