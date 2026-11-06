import QtQuick
import ".."

Item {
    id: root
    property url source
    property bool animated: true
    property bool frontA: true
    property bool initialized: false
    readonly property bool ready: (frontA ? a : b).status === Image.Ready && String(source).length > 0
    function load(): void {
        if (!String(source).length) { a.source = ""; b.source = ""; return; }
        const next = frontA ? b : a;
        next.source = source;
        if (next.status === Image.Ready) frontA = next === a;
    }
    onSourceChanged: if (initialized) load()
    Component.onCompleted: { initialized = true; load(); }
    Image {
        id: a
        anchors.fill: parent
        sourceSize: Qt.size(192, 192)
        asynchronous: true; smooth: true; mipmap: true; fillMode: Image.PreserveAspectCrop
        opacity: root.frontA && status === Image.Ready ? 1 : 0
        onStatusChanged: if (status === Image.Ready && String(source) === String(root.source)) root.frontA = true
        Behavior on opacity { NumberAnimation { duration: root.animated ? 420 : 0; easing.type: Easing.OutCubic } }
    }
    Image {
        id: b
        anchors.fill: parent
        sourceSize: Qt.size(192, 192)
        asynchronous: true; smooth: true; mipmap: true; fillMode: Image.PreserveAspectCrop
        opacity: !root.frontA && status === Image.Ready ? 1 : 0
        onStatusChanged: if (status === Image.Ready && String(source) === String(root.source)) root.frontA = false
        Behavior on opacity { NumberAnimation { duration: root.animated ? 420 : 0; easing.type: Easing.OutCubic } }
    }
}
