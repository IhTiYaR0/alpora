import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Shapes

Button {
    id: control
    required property string symbol
    required property string title
    property string subtitle: "Off"
    property bool active: false
    property bool showDetails: false
    property string actionHint: ""
    property string statusKind: ""
    property int statusLevel: 0
    property bool statusBusy: false
    property bool statusWarning: false
    property bool entranceActive: true
    property int entranceOrder: 0
    signal detailsRequested()
    implicitHeight: 66
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: title + ", " + subtitle
    HoverHandler { id: tileHover; enabled: control.enabled }
    background: FacetSurface {
        accented: control.active
        baseColor: control.active
            ? (control.down ? Glass.tint(Session.accent, 0.40) : (tileHover.hovered ? Glass.tint(Session.accent, 0.30) : Glass.tint(Session.accent, 0.22)))
            : (control.down ? Glass.tint(Session.surface, 0.85) : (tileHover.hovered ? Glass.tint(Session.surface, 0.70) : Glass.tint(Session.surface, 0.50)))
        Behavior on baseColor { ColorAnimation { duration: Motion.responseMs } }
        border.width: control.visualFocus ? 1.5 : 0.7
        border.color: control.visualFocus ? Session.foreground : (control.active ? Session.accent : Glass.tint(Session.accent, 0.30))
    }
    contentItem: Item {
        opacity: control.enabled ? 1 : 0.4
        Icon { visible: !control.statusKind; x: 10; anchors.verticalCenter: parent.verticalCenter; name: control.symbol; width: 25; height: 25 }
        StatusIcon { visible: !!control.statusKind; x: 10; anchors.verticalCenter: parent.verticalCenter; kind: control.statusKind; level: control.statusLevel; busy: control.statusBusy; warning: control.statusWarning; width: 25; height: 25 }
        Column {
            x: 43
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - (control.showDetails ? 44 : 8)
            spacing: 3
            Text {
                width: parent.width
                text: control.title
                color: Session.foreground
                font.family: Session.settings.bar ? Session.settings.bar.fontFamily : "Noto Sans"
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: control.subtitle
                color: control.active ? Session.accent : Session.muted
                font.family: Session.settings.bar ? Session.settings.bar.fontFamily : "Noto Sans"
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }
    Button {
        id: detailsButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 1
        width: 35
        height: parent.height - 2
        visible: control.showDetails
        hoverEnabled: true
        padding: 0
        topInset: 0; bottomInset: 0; leftInset: 0; rightInset: 0
        focusPolicy: Qt.StrongFocus
        Accessible.name: control.title + " — " + I18n.tr("common.details")
        background: Item {
            Shape {
                preferredRendererType: Shape.CurveRenderer
                id: detailHighlight
                anchors.fill: parent
                opacity: detailsButton.down ? 0.16 : (detailsButton.hovered || detailsButton.visualFocus ? 0.09 : 0)
                Behavior on opacity { NumberAnimation { duration: Motion.responseMs } }
                ShapePath {
                    strokeWidth: 0; fillColor: Session.foreground
                    startX: 0; startY: 0
                    PathLine { x: detailHighlight.width - 13; y: 0 }
                    PathArc { x: detailHighlight.width; y: 13; radiusX: 13; radiusY: 13 }
                    PathLine { x: detailHighlight.width; y: detailHighlight.height - 13 }
                    PathArc { x: detailHighlight.width - 13; y: detailHighlight.height; radiusX: 13; radiusY: 13 }
                    PathLine { x: 0; y: detailHighlight.height }
                    PathLine { x: 0; y: 0 }
                }
            }
            Rectangle {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                width: 1; height: parent.height - 22
                color: detailsButton.visualFocus ? Session.foreground : Glass.tint(Session.accent, 0.25)
            }
        }
        contentItem: Item {
            Icon {
                anchors.centerIn: parent
                name: "chevron-right"; width: 16; height: 16
            }
        }
        onClicked: control.detailsRequested()
    }
}
