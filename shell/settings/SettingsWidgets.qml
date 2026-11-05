pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../logic/WidgetGeometry.js" as Geometry

ColumnLayout {
    id: root
    property url wallpaper: ""
    property string selected: "clock"
    property var cities: []
    property string searchError: ""
    readonly property var config: WidgetState.editing ? WidgetState.draft : WidgetState.values
    readonly property var monitor: Quickshell.screens.find(s => s.name === config.screen) || Quickshell.screens[0] || null
    readonly property real screenWidth: monitor ? monitor.width : 1920
    readonly property real screenHeight: monitor ? monitor.height : 1080
    readonly property real safeTop: (Session.settings.bar ? Session.settings.bar.top + Session.settings.bar.height : 52) + 20
    readonly property var chosen: config[selected]
    readonly property var selectedBox: Geometry.bounds(selected, chosen, screenWidth, screenHeight, safeTop)
    spacing: 12
    Component.onCompleted: WidgetState.begin()
    function title(kind: string): string {
        return kind === "clock" ? I18n.tr("center.clock")
            : kind === "weather" ? I18n.tr("center.weather")
            : kind === "music" ? I18n.tr("music.title")
            : kind === "developer" ? I18n.tr("widgets.developer")
            : I18n.tr("widgets.running_apps");
    }
    ScrollView {
        id: scroll
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth; spacing: 12
            RowLayout {
                Layout.fillWidth: true; spacing: 14
                CompanionSprite {
                    id: companionPreview
                    Layout.preferredWidth: 88; Layout.preferredHeight: 88
                    property real previewTime: 0
                    activity: "greet"; phase: previewTime
                    animated: CompanionState.enabled && !Motion.reduced
                    Timer { interval: 80; repeat: true; running: companionPreview.visible && companionPreview.animated; onTriggered: companionPreview.previewTime += 0.08 }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { text: I18n.tr("companion.title"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 15; font.weight: Font.Medium }
                    Text { Layout.fillWidth: true; text: I18n.tr("companion.desc"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 12; wrapMode: Text.Wrap }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Text { text: I18n.tr("companion.show_robot"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 13 }
                    Text { Layout.fillWidth: true; text: CompanionState.enabled ? I18n.tr("companion.on_desc") : I18n.tr("companion.off_desc"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap }
                }
                SettingsToggle { checked: CompanionState.enabled; enabled: CompanionState.loaded; Accessible.name: I18n.tr("companion.show_robot"); onToggled: CompanionState.setEnabled(checked) }
            }
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Text { text: I18n.tr("companion.active_nature"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12 }
                    Text { Layout.fillWidth: true; text: I18n.tr("companion.active_nature_desc"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap }
                }
                SettingsToggle { checked: CompanionState.lively; enabled: CompanionState.enabled; Accessible.name: I18n.tr("companion.active_nature"); onToggled: CompanionState.setLively(checked) }
            }
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Text { text: I18n.tr("companion.flights"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12 }
                    Text { Layout.fillWidth: true; text: I18n.tr("companion.flights_desc"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap }
                }
                SettingsToggle { checked: CompanionState.flights; enabled: CompanionState.enabled; Accessible.name: I18n.tr("companion.flights_accessible"); onToggled: CompanionState.setFlights(checked) }
            }
            Text { visible: !!CompanionState.error; Layout.fillWidth: true; text: CompanionState.error; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Session.accent; opacity: 0.15 }
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: I18n.tr("landscape.living_landscape_title"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 13 }
                SettingsToggle { checked: LandscapeState.enabled; Accessible.name: I18n.tr("landscape.living_landscape_accessible"); onToggled: LandscapeState.setEnabled(checked) }
            }
            Text { Layout.fillWidth: true; text: I18n.tr("widgets.landscape_hint"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 12; wrapMode: Text.Wrap }
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: I18n.tr("widgets.animations"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12 }
                SettingsToggle { checked: !!root.config.animations; enabled: !WidgetState.busy; Accessible.name: I18n.tr("widgets.animations"); onToggled: WidgetState.setAnimations(checked) }
            }
            Item {
                Layout.fillWidth: true; Layout.preferredHeight: 240
                Rectangle {
                    id: preview
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 2, parent.height * root.screenWidth / root.screenHeight)
                    height: width * root.screenHeight / root.screenWidth
                    radius: 10; color: Session.background; clip: true
                    readonly property real ratio: width / root.screenWidth
                    SettingsImage { anchors.fill: parent; radius: 10; source: root.wallpaper; sourceSize: Qt.size(900, 600) }
                    Rectangle { x: 5; y: 4; width: parent.width - 10; height: Math.max(5, 40 * preview.ratio); radius: 3; color: Session.surface; opacity: 0.9 }
                    Repeater {
                        model: ["clock", "weather", "music", "developer", "apps"]
                        Rectangle {
                            id: miniature
                            required property string modelData
                            readonly property var box: Geometry.bounds(modelData, root.config[modelData], root.screenWidth, root.screenHeight, root.safeTop)
                            x: box.x * preview.ratio; y: box.y * preview.ratio
                            width: box.width * preview.ratio; height: box.height * preview.ratio
                            radius: 5; color: Session.surface
                            opacity: root.config[modelData].enabled ? 0.96 : 0.38
                            border.width: root.selected === modelData ? 2 : 1
                            border.color: root.selected === modelData ? Session.accent : Session.muted
                            Image { anchors.fill: parent; anchors.margins: 5; source: Session.appearance.ridge ? "file://" + Session.appearance.ridge : ""; fillMode: Image.PreserveAspectFit; verticalAlignment: Image.AlignBottom; opacity: 0.5; visible: miniature.modelData !== "music" }
                            Text { anchors.centerIn: parent; text: miniature.modelData === "clock" ? "13:30" : root.title(miniature.modelData); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: Math.max(9, miniature.width * (miniature.modelData === "clock" ? 0.19 : 0.12)); font.weight: Font.Medium }
                            MouseArea {
                                anchors.fill: parent; cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                enabled: !WidgetState.busy
                                property real offsetX: 0
                                property real offsetY: 0
                                onPressed: mouse => { root.selected = miniature.modelData; offsetX = mouse.x; offsetY = mouse.y; }
                                onPositionChanged: mouse => {
                                    if (!pressed) return;
                                    const point = mapToItem(preview, mouse.x, mouse.y);
                                    WidgetState.move(miniature.modelData, Geometry.position(miniature.modelData,
                                        root.config[miniature.modelData], (point.x - offsetX) / preview.ratio,
                                        (point.y - offsetY) / preview.ratio, root.screenWidth, root.screenHeight, root.safeTop));
                                }
                            }
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: ["clock", "weather", "music", "developer", "apps"]
                    AppearanceButton { required property string modelData; Layout.fillWidth: true; text: root.title(modelData); symbol: modelData === "clock" ? "calendar" : modelData === "weather" ? "sun" : modelData === "music" ? "music" : modelData === "developer" ? "settings" : "overview"; selected: root.selected === modelData; onClicked: root.selected = modelData }
                }
                SettingsToggle { checked: root.chosen.enabled; enabled: !WidgetState.busy; Accessible.name: I18n.tr("widgets.show_prefix") + root.title(root.selected); onToggled: WidgetState.edit(root.selected, "enabled", checked) }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 20
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { text: I18n.trWith("widgets.horizontal", {value: root.chosen.x}); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11 }
                    ControlSlider { Layout.fillWidth: true; wheelEnabled: false; from: 0; to: 100; stepSize: 1; value: root.chosen.x; enabled: !WidgetState.busy; Accessible.name: I18n.tr("widgets.pos_horizontal"); onMoved: WidgetState.edit(root.selected, "x", Math.round(value)) }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { text: I18n.trWith("widgets.vertical", {value: Math.round((root.selectedBox.y - root.selectedBox.top) / root.selectedBox.scale)}); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11 }
                    ControlSlider { Layout.fillWidth: true; wheelEnabled: false; from: 0; to: Math.max(1, (root.screenHeight - root.selectedBox.top - root.selectedBox.margin - root.selectedBox.height) / root.selectedBox.scale); stepSize: 1; value: Math.min(root.chosen.y, to); enabled: !WidgetState.busy; Accessible.name: I18n.tr("widgets.pos_vertical"); onMoved: WidgetState.edit(root.selected, "y", Math.round(value)) }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: I18n.tr("widgets.monitor"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 12 }
                ComboBox {
                    id: monitorSelect
                    Layout.fillWidth: true
                    implicitHeight: 36
                    model: [I18n.tr("widgets.auto")].concat(Quickshell.screens.map(s => s.name))
                    currentIndex: Math.max(0, model.indexOf(root.config.screen))
                    enabled: !WidgetState.busy; Accessible.name: I18n.tr("widgets.monitor_accessible")
                    onActivated: index => WidgetState.setScreen(index ? model[index] : "")
                    background: Rectangle { radius: 8; color: Session.surface; border.width: 1; border.color: monitorSelect.visualFocus ? Session.accent : Session.muted; opacity: 0.7 }
                    contentItem: Text { leftPadding: 10; rightPadding: 26; text: monitorSelect.displayText; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                    indicator: Icon { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; name: "chevron-down" }
                }
                AppearanceButton { text: I18n.tr("widgets.reset_positions"); symbol: "refresh"; enabled: !WidgetState.busy; onClicked: WidgetState.reset() }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Session.accent; opacity: 0.2 }
            Text { text: I18n.trWith("widgets.weather_city", {city: root.config.location.name}); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12 }
            RowLayout {
                Layout.fillWidth: true
                TextField {
                    id: city; Layout.fillWidth: true; placeholderText: I18n.tr("widgets.city_name_placeholder"); color: Session.foreground
                    enabled: !citySearch.running && !WidgetState.busy
                    background: Rectangle { radius: 8; color: Session.surface; border.width: 1; border.color: city.activeFocus ? Session.accent : Session.muted; opacity: 0.7 }
                    onAccepted: findCity.clicked()
                }
                AppearanceButton {
                    id: findCity; text: citySearch.running ? I18n.tr("widgets.searching_city") : I18n.tr("widgets.search_city"); symbol: "search"
                    enabled: city.text.trim().length >= 2 && !citySearch.running && !WidgetState.busy
                    onClicked: {
                        if (!enabled) return;
                        root.searchError = ""; root.cities = [];
                        citySearch.command = [Session.controller, "widgets", "search", JSON.stringify({city: city.text})]; citySearch.running = true;
                    }
                }
            }
            Text { visible: !!root.searchError; text: root.searchError; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11 }
            Repeater {
                model: root.cities
                AppearanceButton { required property var modelData; Layout.fillWidth: true; text: modelData.name + " · " + modelData.description; symbol: "home"; enabled: !WidgetState.busy; onClicked: { WidgetState.setLocation(modelData); root.cities = []; city.text = ""; } }
            }
            Text { Layout.fillWidth: true; text: I18n.tr("widgets.sources_hint"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; wrapMode: Text.Wrap }
        }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 10
        Text { Layout.fillWidth: true; text: WidgetState.error || WidgetState.message || (WidgetState.dirty ? I18n.tr("common.unsaved_changes") : I18n.tr("common.all_saved")); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap }
        AppearanceButton { text: I18n.tr("common.cancel"); symbol: "close"; enabled: !WidgetState.busy && (WidgetState.dirty || !!WidgetState.error); onClicked: WidgetState.cancel() }
        AppearanceButton { text: WidgetState.busy ? I18n.tr("common.saving") : I18n.tr("common.apply"); symbol: "check"; primary: true; enabled: WidgetState.dirty && !WidgetState.busy; onClicked: WidgetState.apply() }
    }
    Process {
        id: citySearch
        stdout: StdioCollector { onStreamFinished: {
            try { root.cities = JSON.parse(text).results; if (!root.cities.length) root.searchError = I18n.tr("widgets.city_not_found"); }
            catch (_) { root.searchError = I18n.tr("widgets.error_city_list"); }
        } }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.searchError = text.trim().replace(/^poly-shell: /, "") }
    }
}
