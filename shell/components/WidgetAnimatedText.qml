import QtQuick
import ".."

Text {
    id: root
    property string value: ""
    property bool motionActive: true
    property bool ready: false
    function sync(): void {
        change.stop();
        if (!ready || !motionActive || Motion.reduced || !WidgetState.values.animations) {
            text = value; opacity = 1; return;
        }
        change.start();
    }
    onValueChanged: sync()
    onMotionActiveChanged: if (!motionActive) { change.stop(); text = value; opacity = 1; }
    Component.onCompleted: { text = value; ready = true; }
    SequentialAnimation {
        id: change
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 100 }
        ScriptAction { script: root.text = root.value }
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
    }
    Connections {
        target: WidgetState
        function onValuesChanged(): void { if (!WidgetState.values.animations) { change.stop(); root.text = root.value; root.opacity = 1; } }
    }
    Connections {
        target: Motion
        function onReducedChanged(): void { if (Motion.reduced) { change.stop(); root.text = root.value; root.opacity = 1; } }
    }
}
