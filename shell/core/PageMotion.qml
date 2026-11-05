import QtQuick
import ".."

QtObject {
    id: motion
    property string page: ""
    property bool enabled: true
    property real progress: 1
    readonly property real opacity: progress
    property NumberAnimation transition: NumberAnimation {
        target: motion; property: "progress"
        from: 0; to: 1
        duration: Motion.reduced ? 0 : 160
        easing.type: Easing.OutCubic
    }
    onPageChanged: { if (enabled) transition.restart(); else { transition.stop(); progress = 1; } }
    onEnabledChanged: if (!enabled) { transition.stop(); progress = 1; }
}
