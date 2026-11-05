import QtQuick
import ".."

QtObject {
    id: motion
    required property bool opened
    property int openDuration: Motion.openMs
    property int closeDuration: Motion.closeMs
    readonly property bool presented: opened || progress > 0
    readonly property bool renderAnimating: progress > 0 && progress < 1
    // One clock drives the outline, clipping, content and window lifetime.
    property real progress: opened ? 1 : 0
    Behavior on progress {
        id: progressBehavior
        enabled: !ClockState.sleeping
        NumberAnimation {
            duration: progressBehavior.targetValue > 0 ? motion.openDuration : motion.closeDuration
            easing.type: Easing.Linear
        }
    }
}
