pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme

// Single-clock liquid surface; corner curvature preserves the button anchor. Content stays native and is never
// captured, resized or handed between a texture and the live controls.
Item {
    id: panel
    required property PanelMotion motion
    property Item sourceItem: null
    // Explicit screen-local position: Wayland layer surfaces do not provide
    // reliable global window positions for mapToGlobal/mapFromGlobal.
    required property point screenPosition
    property bool faceted: false
    property real cornerRadius: Session.visual.panelRadius
    property real edgeWidth: Session.visual.panelBorder
    property real shadowStrength: Session.visual.panelShadow / 20
    property color surfaceTop: Glass.panelTop
    property color surfaceBottom: Glass.panelBottom
    default property alias panelContent: fixedContent.data
    readonly property real time: motion.progress
    readonly property real surfaceX: 0
    readonly property real surfaceY: 0
    readonly property real surfaceWidth: width
    readonly property real surfaceHeight: height
    readonly property bool effectReady: liquid.status !== ShaderEffect.Error
    enabled: motion.opened
    function revealOpacity(item: Item): real { return 1; }

    property bool tracing: false
    property var traceFrames: []
    property real traceStart: 0
    function startTrace(): void {
        traceFrames = []; traceStart = Date.now(); tracing = true;
        traceTimeout.restart();
    }
    function finishTrace(): var {
        tracing = false; traceTimeout.stop(); return traceFrames;
    }
    Connections {
        target: panel.Window.window
        enabled: panel.tracing
        function onFrameSwapped(): void {
            if (panel.tracing && panel.traceFrames.length < 240)
                panel.traceFrames.push({ms: Date.now() - panel.traceStart,
                    progress: panel.time, width: panel.surfaceWidth,
                    height: panel.surfaceHeight, x: panel.surfaceX, y: panel.surfaceY});
        }
    }
    Timer { id: traceTimeout; interval: 2500; onTriggered: panel.tracing = false }

    readonly property point origin: {
        if (!sourceItem) return Qt.point(width / 2, -30);
        // Bar items have no scale/rotation. Read every ancestor position so
        // bindings also follow late Row/anchor layout (mapToItem alone does not).
        let sourceX = sourceItem.width / 2;
        let sourceY = sourceItem.height / 2;
        let item = sourceItem;
        while (item) {
            sourceX += item.x;
            sourceY += item.y;
            item = item.parent;
        }
        return Qt.point(Math.max(12, Math.min(width - 12, sourceX - screenPosition.x)),
            sourceY - screenPosition.y);
    }

    ShaderEffect {
        id: liquid
        anchors.fill: parent
        visible: panel.motion.presented
        readonly property real visualProgress: panel.time
        readonly property vector2d extent: Qt.vector2d(Math.max(1, width), Math.max(1, height))
        readonly property vector2d origin: Qt.vector2d(panel.origin.x, panel.origin.y)
        readonly property color topColor: panel.surfaceTop
        readonly property color bottomColor: panel.surfaceBottom
        readonly property color edgeColor: PolyTheme.Theme.color("#4b5850")
        readonly property real edgeWidth: panel.edgeWidth
        readonly property real shadowStrength: panel.shadowStrength
        readonly property real cornerRadius: panel.cornerRadius
        readonly property real cornerCut: panel.faceted ? Math.min(14, Math.max(3, panel.cornerRadius * 0.7)) : 0
        vertexShader: "shaders/liquid-alpine-v2.vert.qsb"
        fragmentShader: "shaders/liquid-alpine-v2.frag.qsb"
    }
    // Clip the native controls to the growing body without scaling or
    // relayout. The same clock also drives the shader and fade.
    Item {
        id: contentClip
        readonly property real expansion: 1 - Math.pow(1 - panel.time, 3)
        x: (panel.origin.x - 9) * (1 - expansion)
        y: (panel.origin.y - 12) * (1 - expansion)
        width: 18 + (panel.width - 18) * expansion
        height: 24 + (panel.height - 24) * expansion
        clip: true
        Item {
            id: fixedContent
            x: -contentClip.x
            y: -contentClip.y
            width: panel.width
            height: panel.height
            readonly property real reveal: Math.max(0, Math.min(1, (panel.time - 0.48) / 0.50))
            opacity: reveal * reveal * (3 - 2 * reveal)
        }
    }
}
