pragma ComponentBehavior: Bound
import QtQuick
import ".."
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root
    required property var modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore; exclusiveZone: 0
    color: "transparent"
    visible: !!modelData && TimelineState.active && TimelineState.loaded && !ThemeState.wallpaperTransitioning
    mask: Region {}
    WlrLayershell.namespace: "poly-timeline-wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    property var readyImages: ({})
    readonly property bool ready: TimelineState.stops.length === 6 && Object.keys(readyImages).length === 6
    onReadyChanged: if (modelData) TimelineState.wallpaperReady(modelData.name, ready)
    Connections {
        target: TimelineState
        function onActiveChanged(): void { if (!TimelineState.active) root.readyImages = ({}); }
    }
    function markReady(index: int, status: int): void {
        const next = Object.assign({}, readyImages);
        if (status === Image.Ready) next[index] = true;
        else delete next[index];
        readyImages = next;
    }
    // All six textures load once. Only two are visible, and no frame timer runs.
    Repeater {
        model: TimelineState.active ? TimelineState.stops : []
        Image {
            id: landscape
            required property int index
            required property var modelData
            anchors.fill: parent
            source: "file://" + modelData.image
            // Native-size decoding shares the image cache across 1080p/4K outputs.
            sourceSize: Qt.size(1672, 941)
            fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true
            asynchronous: true
            readonly property bool lower: index === TimelineState.segment.lower
            readonly property bool upper: index === TimelineState.segment.upper
            visible: root.ready && (lower || upper)
            z: upper ? 1 : 0
            opacity: upper ? TimelineState.segment.blend : 1
            onStatusChanged: root.markReady(index, status)
        }
    }
    IpcHandler {
        target: "timeline-wallpaper-" + (root.modelData ? root.modelData.name : "disconnected")
        function status(): string { return JSON.stringify({visible: root.visible, ready: root.ready, images: Object.keys(root.readyImages).length, width: root.width, height: root.height, segment: TimelineState.segment}); }
    }
}
