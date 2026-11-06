pragma Singleton
import QtQuick
import ".."

QtObject {
    readonly property var panelCurve: [0.2, 0, 0.2, 1, 1, 1]
    readonly property bool reduced: !!Session.settings.reducedMotion
    readonly property int openMs: reduced ? 0 : Session.visual.panelOpenMs
    readonly property int unfoldMs: openMs
    readonly property int foldMs: closeMs
    readonly property int closeMs: reduced ? 0 : Session.visual.panelCloseMs
    readonly property int responseMs: reduced ? 0 : 120
    readonly property int resizeMs: reduced ? 0 : 180
}
