pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Effects

Item {
    id: root
    property alias source: picture.source
    property alias sourceSize: picture.sourceSize
    property real radius: 11
    Image {
        id: picture
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        smooth: true; mipmap: true
        layer.enabled: true
        layer.effect: MultiEffect { maskEnabled: true; maskSource: roundedMask }
    }
    Rectangle {
        id: roundedMask
        anchors.fill: parent
        radius: root.radius
        color: "white"
        layer.enabled: true
        visible: false
    }
}
