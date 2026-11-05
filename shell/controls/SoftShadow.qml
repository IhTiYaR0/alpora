pragma ComponentBehavior: Bound
import QtQuick
import ".."

Item {
    id: root
    property real cornerRadius: 20
    property int spread: 9
    property real strength: 1
    visible: strength > 0
    opacity: Math.min(1, strength)
    Repeater {
        model: root.spread
        Rectangle {
            required property int index
            readonly property real expansion: (root.spread - index) * 1.1
            x: -expansion
            y: 2 - expansion
            width: root.width + expansion * 2
            height: root.height + expansion * 2
            radius: root.cornerRadius + expansion
            color: Qt.rgba(0, 0, 0, (0.012 + index * 0.001) * Math.max(1, root.strength))
            antialiasing: true
        }
    }
}
