pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 12
    RowLayout {
        Layout.fillWidth: true
        Icon { name: "sun"; Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
        Text { Layout.fillWidth: true; text: "Timeline"; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 15; font.weight: Font.Medium }
        Text { text: TimelineState.formatted; color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 18; font.weight: Font.Medium }
    }
    RowLayout {
        Layout.fillWidth: true
        Icon { name: "moon"; Layout.preferredWidth: 15; Layout.preferredHeight: 15 }
        Item { Layout.fillWidth: true }
        Icon { name: "sun"; Layout.preferredWidth: 17; Layout.preferredHeight: 17 }
        Item { Layout.fillWidth: true }
        Icon { name: "moon"; Layout.preferredWidth: 15; Layout.preferredHeight: 15 }
    }
    Slider {
        id: time
        Layout.fillWidth: true; Layout.preferredHeight: 24
        from: 0; to: 1440; stepSize: 1
        value: TimelineState.minute
        enabled: TimelineState.active && TimelineState.loaded
        wheelEnabled: true; live: true
        Accessible.name: I18n.tr("timeline.time_of_day_wallpaper")
        onMoved: TimelineState.move(value)
        onPressedChanged: { TimelineState.dragging = pressed; if (!pressed) TimelineState.commit(); }
        background: Rectangle {
            x: time.leftPadding; y: (time.height - height) / 2
            width: time.availableWidth; height: 8; radius: 4
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#192c55" }
                GradientStop { position: 0.23; color: "#c48ca4" }
                GradientStop { position: 0.36; color: "#e6d2a5" }
                GradientStop { position: 0.54; color: "#80bce0" }
                GradientStop { position: 0.77; color: "#edaa7f" }
                GradientStop { position: 0.9; color: "#665786" }
                GradientStop { position: 1; color: "#192c55" }
            }
        }
        handle: Rectangle {
            x: time.leftPadding + time.visualPosition * (time.availableWidth - width)
            y: (time.height - height) / 2
            width: 18; height: 18; radius: 9
            color: Session.accent; border.width: time.visualFocus ? 2 : 1; border.color: Session.foreground
        }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 0
        Repeater {
            model: ["00:00", "06:00", "12:00", "18:00", "24:00"]
            Text { required property string modelData; required property int index; Layout.fillWidth: true; text: modelData; horizontalAlignment: index === 0 ? Text.AlignLeft : index === 4 ? Text.AlignRight : Text.AlignHCenter; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10 }
        }
    }
    Text { Layout.fillWidth: true; visible: !!TimelineState.error; text: TimelineState.error; color: Session.muted; wrapMode: Text.Wrap; font.family: Session.fontFamily; font.pixelSize: 11 }
}
