import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls

TextField {
    id: control
    implicitHeight: 38
    padding: 11
    color: Session.foreground
    placeholderTextColor: PolyTheme.Theme.color("#95a197")
    selectionColor: PolyTheme.Theme.color("#697d5d")
    selectedTextColor: PolyTheme.Theme.color("#f0f3e9")
    font.family: Session.fontFamily
    font.pixelSize: 12
    background: Rectangle {
        radius: 10; color: Glass.tint(PolyTheme.Theme.color("#20292a"), 0.45)
        border.width: control.activeFocus ? 1.2 : 0.7
        border.color: control.activeFocus ? PolyTheme.Theme.color("#a4b594") : PolyTheme.Theme.color("#455249")
    }
}
