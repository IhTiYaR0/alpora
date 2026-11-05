pragma ComponentBehavior: Bound
import QtQuick
import ".."
import Quickshell
import Quickshell.Wayland

// A predecoded, input-transparent bridge over awww's client startup latency.
// It lives below windows/widgets and releases its texture after the handoff.
// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root
    property bool showing: false
    property bool pendingStart: false
    property real progress: 0
    property point origin: Qt.point(0, 0)
    property size decodeSize: Qt.size(1920, 1080)
    property bool frontA: true
    property bool crossfadeMode: false
    readonly property var front: frontA ? textureA : textureB
    readonly property var staging: frontA ? textureB : textureA
    function prepare(path: string): void {
        staging.source = path.length ? "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F") : "";
    }
    function startAt(x: real, y: real): void {
        handoff.stop(); reveal.stop();
        crossfadeMode = false;
        frontA = !frontA;
        origin = Qt.point(x, y); progress = 0; showing = true;
        pendingStart = true;
        begin();
    }
    function crossfade(path: string): void {
        prepare(path);
        handoff.stop(); reveal.stop();
        crossfadeMode = true;
        frontA = !frontA;
        origin = Qt.point(width / 2, height / 2);
        progress = 0; showing = true;
        pendingStart = true;
        begin();
    }
    function begin(): void {
        if (!pendingStart || front.status !== Image.Ready) return;
        pendingStart = false;
        if (Motion.reduced) progress = 1;
        else reveal.start();
    }
    function clear(): void {
        handoff.stop(); reveal.stop();
        showing = false; pendingStart = false; crossfadeMode = false; front.source = "";
    }
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore; exclusiveZone: 0
    color: "transparent"
    visible: showing
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "poly-wallpaper-reveal"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    Image {
        id: textureA
        visible: false
        asynchronous: true
        sourceSize: root.decodeSize
        onStatusChanged: root.begin()
    }
    Image {
        id: textureB
        visible: false
        asynchronous: true
        sourceSize: root.decodeSize
        onStatusChanged: root.begin()
    }
    ShaderEffect {
        anchors.fill: parent
        property var source: root.front
        property size extent: Qt.size(width, height)
        property point origin: root.origin
        property real progress: root.progress
        property real sourceAspect: root.front.implicitWidth / Math.max(1, root.front.implicitHeight)
        fragmentShader: "shaders/wallpaper-reveal.frag.qsb"
    }
    NumberAnimation {
        id: reveal
        target: root; property: "progress"; from: 0; to: 1
        duration: root.crossfadeMode ? (Motion.reduced ? 0 : 250) : 1400
        easing.type: root.crossfadeMode ? Easing.InOutQuad : Easing.OutCubic
    }
    Timer { id: handoff; interval: root.crossfadeMode ? 350 : 1600; onTriggered: root.clear() }
    Connections {
        target: ThemeState
        function onMessageChanged(): void {
            if (root.showing && ThemeState.action === "apply" && (ThemeState.message === I18n.tr("theme.applied") || ThemeState.message === I18n.tr("theme.saved"))) handoff.restart();
        }
        function onErrorChanged(): void { if (root.showing && ThemeState.error.length) root.clear(); }
    }
    Connections {
        target: ClockState
        function onPreparingForSleep(): void { root.clear(); }
    }
}
