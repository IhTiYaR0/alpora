pragma ComponentBehavior: Bound
import QtQuick
import ".."
import Quickshell
import "../logic/WidgetGeometry.js" as Geometry

// Both desktop input surfaces must leave widget cards reachable even when
// remapped above them within the same Wayland Bottom layer.
Region {
    id: root
    required property var screenData
    property bool inputEnabled: true
    readonly property var config: WidgetState.values
    readonly property string targetScreen: Quickshell.screens.find(s => s.name === config.screen)?.name || (Quickshell.screens.length ? Quickshell.screens[0].name : "")
    readonly property bool widgetsVisible: !!screenData && Session.loaded && WidgetState.loaded && screenData.name === targetScreen
    readonly property real safeTop: Session.visual.barTop + Session.visual.barHeight + Math.max(20, Session.visual.barBottom + 12)
    readonly property var clockBox: box("clock")
    readonly property var weatherBox: box("weather")
    readonly property var musicBox: box("music")
    function box(kind: string): var {
        return Geometry.bounds(kind, config[kind], screenData ? screenData.width : 0, screenData ? screenData.height : 0, safeTop);
    }
    width: inputEnabled && screenData ? screenData.width : 0
    height: inputEnabled && screenData ? screenData.height : 0
    Region {
        intersection: Intersection.Subtract
        x: Math.round(root.clockBox.x); y: Math.round(root.clockBox.y)
        width: root.widgetsVisible && root.config.clock.enabled ? Math.ceil(root.clockBox.width) : 0
        height: root.widgetsVisible && root.config.clock.enabled ? Math.ceil(root.clockBox.height) : 0
    }
    Region {
        intersection: Intersection.Subtract
        x: Math.round(root.weatherBox.x); y: Math.round(root.weatherBox.y)
        width: root.widgetsVisible && root.config.weather.enabled ? Math.ceil(root.weatherBox.width) : 0
        height: root.widgetsVisible && root.config.weather.enabled ? Math.ceil(root.weatherBox.height) : 0
    }
    Region {
        intersection: Intersection.Subtract
        x: Math.round(root.musicBox.x); y: Math.round(root.musicBox.y)
        width: root.widgetsVisible && root.config.music.enabled ? Math.ceil(root.musicBox.width) : 0
        height: root.widgetsVisible && root.config.music.enabled ? Math.ceil(root.musicBox.height) : 0
    }
}
