pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    signal importRequested()
    readonly property var selected: ThemeState.selected
    readonly property var previewPalette: selected && ThemeState.automatic ? selected.palette : Session.palette
    readonly property color previewAccent: previewPalette.accent || Session.accent
    readonly property color previewSurface: previewPalette.surface || Session.surface
    readonly property color previewBackground: previewPalette.background || Session.background
    function fileUrl(path: string): string { return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F"); }
    spacing: 12
    RowLayout {
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
        SettingsCard {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 470
            padding: 12
            RowLayout {
                Layout.fillWidth: true; spacing: 9
                Icon { name: "wallpaper"; Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
                Text { Layout.fillWidth: true; text: I18n.tr("theme.collection"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold }
                AppearanceButton { text: I18n.tr("theme.custom_wallpaper"); symbol: "plus"; implicitHeight: 32; enabled: !ThemeState.busy; onClicked: root.importRequested() }
            }
            ScrollView {
                id: galleryScroll
                Layout.fillWidth: true; Layout.fillHeight: true
                contentWidth: availableWidth; clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                GridLayout {
                    width: galleryScroll.availableWidth; columns: 2; columnSpacing: 9; rowSpacing: 9
                    Repeater {
                        model: ThemeState.items
                        Button {
                            id: tile
                            required property var modelData
                            Layout.fillWidth: true; Layout.preferredWidth: (galleryScroll.availableWidth - 9) / 2
                            Layout.preferredHeight: 158
                            hoverEnabled: true
                            enabled: !ThemeState.busy
                            padding: 5
                            Accessible.name: modelData.label
                            onClicked: ThemeState.select(modelData.id)
                            background: Rectangle {
                                radius: 12
                                color: tile.modelData.id === ThemeState.selectedId ? Qt.rgba(root.previewAccent.r, root.previewAccent.g, root.previewAccent.b, 0.08) : PolyTheme.Theme.color("#262e36")
                                border.width: tile.modelData.id === ThemeState.selectedId || tile.visualFocus ? 2 : 1
                                border.color: tile.modelData.id === ThemeState.selectedId || tile.visualFocus ? root.previewAccent : tile.hovered ? Session.muted : PolyTheme.Theme.color("#485361")
                            }
                            contentItem: ColumnLayout {
                                spacing: 5
                                Item {
                                    Layout.fillWidth: true; Layout.preferredHeight: 103
                                    SettingsImage { anchors.fill: parent; radius: 8; source: root.fileUrl(tile.modelData.image); sourceSize: Qt.size(440, 230) }
                                    Rectangle {
                                        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
                                        width: 22; height: 22; radius: 11; color: root.previewAccent
                                        visible: tile.modelData.id === ThemeState.selectedId
                                        Icon { anchors.centerIn: parent; name: "check"; width: 14; height: 14 }
                                    }
                                }
                                Text { Layout.fillWidth: true; Layout.leftMargin: 4; text: tile.modelData.label; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11; elide: Text.ElideRight; textFormat: Text.PlainText }
                                Row {
                                    Layout.leftMargin: 4; spacing: 7
                                    Repeater {
                                        model: tile.modelData.swatches
                                        Rectangle { required property string modelData; width: 13; height: 13; radius: 6.5; color: modelData; border.width: 0.6; border.color: "#50ffffff" }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        SettingsCard {
            Layout.preferredWidth: 332; Layout.fillHeight: true; padding: 14
            RowLayout {
                Layout.fillWidth: true; spacing: 9
                Icon { name: "monitor"; Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
                Text { Layout.fillWidth: true; text: I18n.tr("theme.preview"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold }
            }
            Item {
                id: previewCanvas
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 210
                readonly property string targetSource: root.selected ? root.fileUrl(root.selected.image) : ""
                property string activeSourceA: targetSource
                property string activeSourceB: ""
                property bool showingA: true
                onTargetSourceChanged: {
                    if (showingA) {
                        activeSourceB = targetSource;
                        showingA = false;
                    } else {
                        activeSourceA = targetSource;
                        showingA = true;
                    }
                }
                SettingsImage {
                    anchors.fill: parent
                    source: previewCanvas.activeSourceA
                    sourceSize: Qt.size(660, 600)
                    opacity: previewCanvas.showingA ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.reduced ? 0 : 250; easing.type: Easing.InOutQuad } }
                }
                SettingsImage {
                    anchors.fill: parent
                    source: previewCanvas.activeSourceB
                    sourceSize: Qt.size(660, 600)
                    opacity: previewCanvas.showingA ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: Motion.reduced ? 0 : 250; easing.type: Easing.InOutQuad } }
                }
                Rectangle {
                    x: 7; y: 10; width: parent.width - 14; height: 20; radius: 8
                    color: Qt.rgba(root.previewBackground.r,root.previewBackground.g,root.previewBackground.b,0.93)
                    Behavior on color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } }
                    Row { x: 7; anchors.verticalCenter: parent.verticalCenter; spacing: 4; Repeater { model: 3; Rectangle { width: 4; height: 4; radius: 2; color: root.previewAccent; Behavior on color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } } } } }
                    Text { anchors.centerIn: parent; text: "12:30"; color: root.previewPalette.text || Session.foreground; font.family: Session.fontFamily; font.pixelSize: 8; Behavior on color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } } }
                    Icon { name: "wifi"; width: 10; height: 10; anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter }
                }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 12; y: 47
                    width: 134; height: 146; radius: 12
                    color: Qt.rgba(root.previewBackground.r,root.previewBackground.g,root.previewBackground.b,0.93)
                    border.width: 1; border.color: root.previewAccent
                    Behavior on color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } }
                    Behavior on border.color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } }
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 11; spacing: 11
                        Text { text: I18n.tr("theme.quick_settings"); color: root.previewPalette.text || Session.foreground; font.family: Session.fontFamily; font.pixelSize: 9; Behavior on color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } } }
                        Repeater {
                            model: ["volume", "sun", "microphone"]
                            RowLayout {
                                id: previewControl
                                required property string modelData
                                Layout.fillWidth: true; spacing: 7
                                Icon { name: previewControl.modelData; Layout.preferredWidth: 13; Layout.preferredHeight: 13 }
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 4; radius: 2; color: root.previewSurface
                                    Behavior on color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } }
                                    Rectangle { width: parent.width * 0.7; height: 4; radius: 2; color: root.previewAccent; Behavior on color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } } }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 7
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 28; radius: 6; color: root.previewSurface; Behavior on color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } }; Icon { anchors.centerIn: parent; name: "wifi"; width: 15; height: 15 } }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 28; radius: 6; color: root.previewSurface; Behavior on color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } }; Icon { anchors.centerIn: parent; name: "bluetooth"; width: 15; height: 15 } }
                        }
                    }
                }
                Rectangle {
                    x: 12; y: parent.height - 108; width: 151; height: 88; radius: 9
                    color: Qt.rgba(root.previewSurface.r,root.previewSurface.g,root.previewSurface.b,0.95)
                    border.width: 1; border.color: Qt.rgba(root.previewAccent.r,root.previewAccent.g,root.previewAccent.b,0.4)
                    Behavior on color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } }
                    Behavior on border.color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } }
                    Column { anchors.fill: parent; anchors.margins: 10; spacing: 9
                        Text { text: I18n.tr("theme.app_window"); color: root.previewPalette.text || Session.foreground; font.family: Session.fontFamily; font.pixelSize: 9; Behavior on color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } } }
                        Rectangle { width: 100; height: 4; radius: 2; color: root.previewAccent; Behavior on color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } } }
                        Rectangle { width: 73; height: 4; radius: 2; color: root.previewPalette.muted || Session.muted; opacity: 0.5; Behavior on color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } } }
                        Rectangle { width: 90; height: 4; radius: 2; color: root.previewPalette.muted || Session.muted; opacity: 0.5; Behavior on color { ColorAnimation { duration: Motion.reduced ? 0 : 250 } } }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 5
                Text { Layout.fillWidth: true; text: root.selected ? root.selected.label : I18n.tr("theme.loading"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 18; font.weight: Font.DemiBold; elide: Text.ElideRight; textFormat: Text.PlainText }
                Text { text: I18n.tr("theme.palette_label"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 12 }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 60; radius: 10; color: PolyTheme.Theme.color("#26303d"); border.width: 1; border.color: PolyTheme.Theme.color("#49586d")
                RowLayout { anchors.fill: parent; anchors.margins: 8; spacing: 7
                    Repeater { model: root.selected ? root.selected.swatches : []; Rectangle { required property string modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: 8; color: modelData; border.width: 0.6; border.color: "#50ffffff" } }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 9
                Icon { name: "palette"; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { text: I18n.tr("theme.palette_colors"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12 }
                    Text { Layout.fillWidth: true; text: I18n.tr("theme.palette_applies"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; wrapMode: Text.Wrap }
                }
                SettingsToggle { checked: ThemeState.automatic; enabled: !ThemeState.busy; Accessible.name: I18n.tr("theme.palette_colors"); onToggled: ThemeState.automatic = checked }
            }
        }
    }
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: PolyTheme.Theme.color("#4a545d") }
    RowLayout {
        Layout.fillWidth: true; Layout.preferredHeight: 43; spacing: 10
        Icon { name: ThemeState.dirty ? "note" : "check"; Layout.preferredWidth: 18; Layout.preferredHeight: 18; opacity: 0.7 }
        Text { Layout.fillWidth: true; text: ThemeState.error || ThemeState.message || I18n.tr("theme.hint"); color: ThemeState.error ? PolyTheme.Theme.color("#f4b7a0") : Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; wrapMode: Text.Wrap }
        AppearanceButton { text: I18n.tr("common.cancel"); symbol: "close"; enabled: ThemeState.dirty && !ThemeState.busy; onClicked: ThemeState.cancel() }
        AppearanceButton { text: ThemeState.busy ? I18n.tr("theme.applying") : I18n.tr("theme.apply"); symbol: "check"; primary: true; enabled: ThemeState.dirty && !ThemeState.busy; onClicked: ThemeState.apply() }
    }
}
