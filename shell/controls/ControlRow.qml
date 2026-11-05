import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property string symbol
    required property string label
    property string deviceName: ""
    property bool showLabel: false
    property real value: 0
    property real minimum: 0
    property color accent: Session.accent
    property bool muted: false
    property bool hasMute: false
    property bool hasDetails: false
    property bool adjustable: true
    property string statusKind: ""
    property int statusLevel: 0
    readonly property bool dragging: slider.pressed
    signal adjusted(real value)
    signal muteRequested()
    signal detailsRequested()
    implicitHeight: hasDetails ? 62 : 44
    RowLayout {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.topMargin: 4
        spacing: 12
        Button {
            implicitWidth: 28; implicitHeight: 32
            enabled: root.adjustable && root.hasMute
            // A brightness icon is decorative but retains its full contrast.
            background: Item {}
            contentItem: Item {
                Icon { anchors.fill: parent; visible: !root.statusKind; name: root.symbol; opacity: root.adjustable ? 1 : 0.4 }
                StatusIcon { anchors.fill: parent; visible: !!root.statusKind; kind: root.statusKind; level: root.statusLevel }
            }
            Accessible.name: root.label + (root.muted ? " — " + I18n.tr("common.enable") : " — " + I18n.tr("common.disable"))
            onClicked: root.muteRequested()
        }
        Text {
            visible: root.showLabel
            Layout.preferredWidth: 68
            text: root.label
            color: Session.foreground
            font.family: Session.fontFamily; font.pixelSize: 12
            elide: Text.ElideRight
        }
        ControlSlider {
            id: slider
            Layout.fillWidth: true
            from: root.minimum
            value: root.value
            accent: root.accent
            enabled: root.adjustable
            opacity: root.muted ? 0.45 : 1
            Accessible.name: root.label
            onMoved: root.adjusted(value)
        }
        Text {
            Layout.preferredWidth: 32
            horizontalAlignment: Text.AlignRight
            text: root.adjustable ? Math.round(slider.value * 100) + "%" : "—"
            color: root.muted ? Session.muted : Session.foreground
            font.family: Session.fontFamily
            font.pixelSize: 11
        }
    }
    Button {
        id: deviceButton
        x: 40; y: 35; width: parent.width - 40; height: 23
        visible: root.hasDetails
        enabled: root.adjustable && root.hasDetails
        hoverEnabled: true
        Accessible.name: root.label + " — " + I18n.tr("quick.select_device")
        background: Rectangle {
            radius: 5
            color: deviceButton.down ? PolyTheme.Theme.color("#18ffffff") : (deviceButton.hovered ? PolyTheme.Theme.color("#10ffffff") : (root.hasDetails ? PolyTheme.Theme.color("#06ffffff") : "transparent"))
            border.width: deviceButton.visualFocus ? 1 : 0
            border.color: Session.accent
            Behavior on color { ColorAnimation { duration: Session.settings.reducedMotion ? 0 : 140 } }
        }
        contentItem: Item {
            Text {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 6; anchors.rightMargin: root.hasDetails ? 76 : 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.deviceName
                color: deviceButton.hovered ? Session.foreground : Session.muted
                Behavior on color { ColorAnimation { duration: Session.settings.reducedMotion ? 0 : 140 } }
                font.family: Session.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                visible: root.hasDetails; text: I18n.tr("common.select")
                color: root.accent; font.family: Session.fontFamily; font.pixelSize: 11
            }
            Icon {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 6
                visible: root.hasDetails; name: "chevron-right"
                width: 12; height: 12; opacity: deviceButton.hovered ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: Session.settings.reducedMotion ? 0 : 140 } }
            }
        }
        padding: 0
        onClicked: root.detailsRequested()
    }
}
