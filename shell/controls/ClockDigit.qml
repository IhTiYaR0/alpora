import QtQuick
import ".."

Item {
    id: root
    property string value: "0"
    property bool animated: true
    property int pixelSize: 64
    property string current: value
    property string previous: value
    property real progress: 1
    property bool ready: false
    width: 39; height: 82
    clip: true
    onValueChanged: {
        if (!ready) { current = value; previous = value; return; }
        roll.stop(); previous = current; current = value;
        if (animated) { progress = 0; roll.start(); }
        else progress = 1;
    }
    onAnimatedChanged: if (!animated) { roll.stop(); progress = 1; }
    Component.onCompleted: { current = value; previous = value; ready = true; }
    Text {
        width: parent.width; height: parent.height
        y: -root.progress * height * 0.72
        text: root.previous; opacity: 1 - root.progress
        color: Session.foreground; font.family: Session.displayFontFamily || Session.fontFamily
        font.pixelSize: root.pixelSize; font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    }
    Text {
        width: parent.width; height: parent.height
        y: (1 - root.progress) * height * 0.72
        text: root.current; opacity: root.progress
        color: Session.foreground; font.family: Session.displayFontFamily || Session.fontFamily
        font.pixelSize: root.pixelSize; font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    }
    NumberAnimation { id: roll; target: root; property: "progress"; to: 1; duration: 580; easing.type: Easing.OutExpo }
}
