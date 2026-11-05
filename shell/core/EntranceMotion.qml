import QtQuick
import ".."

QtObject {
    id: motion
    property bool shown: false
    property int order: 0
    property bool mounted: false
    property bool immediate: false
    // The parent panel now owns one render-thread transition. Running a second
    // timeline for every card causes layout/transform churn during that reveal.
    readonly property real progress: shown ? 1 : 0
    readonly property real opacity: Math.max(0, Math.min(1, progress * 1.3))
    // Keep overshoot inside the cell so clipped lists never cut off card edges.
    readonly property real pose: Math.max(0, Math.min(1, progress))
    readonly property real offset: 8 * (1 - pose)
    readonly property real lateral: 0
    readonly property real tilt: 0
    readonly property real scale: 0.985 + 0.015 * pose
}
