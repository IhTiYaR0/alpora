pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import Quickshell.Io
import "../logic/WidgetGeometry.js" as Geometry

DesktopWidgetCard {
    id: root
    implicitWidth: Geometry.size("weather").width
    implicitHeight: Geometry.size("weather").height
    readonly property var current: WeatherState.current
    readonly property bool living: animate && !ClockState.sleeping
    property int hoveredDay: -1
    property int pinnedDay: -1
    property real pointerX: 0
    property real pointerY: 0
    readonly property int previewIndex: hoveredDay >= 0 ? hoveredDay : pinnedDay
    readonly property var forecast: current ? WeatherState.data.forecast || [] : []
    readonly property var preview: previewIndex >= 0 && previewIndex < forecast.length ? forecast[previewIndex] : null
    Behavior on pointerX { NumberAnimation { duration: root.living ? 260 : 0; easing.type: Easing.OutCubic } }
    Behavior on pointerY { NumberAnimation { duration: root.living ? 260 : 0; easing.type: Easing.OutCubic } }
    onLivingChanged: if (!living) { pointerX = 0; pointerY = 0; }
    onCurrentChanged: { hoveredDay = -1; pinnedDay = -1; }
    HoverHandler {
        onPointChanged: {
            if (!root.living) return;
            root.pointerX = Math.max(-1, Math.min(1, point.position.x / root.width * 2 - 1));
            root.pointerY = Math.max(-1, Math.min(1, point.position.y / root.height * 2 - 1));
        }
        onHoveredChanged: if (!hovered) { root.pointerX = 0; root.pointerY = 0; }
    }
    Icon { x: 20; y: 19; width: 16; height: 16; name: "home" }
    Text {
        x: 44; y: 18; width: parent.width - 92
        text: WidgetState.values.location.name; elide: Text.ElideRight
        color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 13; font.weight: Font.Medium
    }
    WeatherScene {
        id: scene
        x: 145; y: 38; width: parent.width - 157; height: 85
        visible: !!root.current
        animated: root.living
        pointerX: root.pointerX; pointerY: root.pointerY
        code: root.preview ? root.preview.code : root.current ? root.current.weather_code : 3
        day: root.preview ? true : !!root.current && !!root.current.is_day
    }
    Text {
        x: 166; y: 37; width: parent.width - 198
        text: root.preview ? WeatherState.day(root.preview.day) + " · " + I18n.tr("weather.forecast") : root.current ? (root.current.is_day ? I18n.tr("weather.day") : I18n.tr("weather.night")) : ""
        color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 9
        elide: Text.ElideRight
    }
    Text {
        x: 21; y: 40
        text: I18n.tr("weather.now")
        color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 8
    }
    WidgetAnimatedText {
        x: 19; y: 43
        value: root.current ? Math.round(root.current.temperature_2m) + "°" : "—°"
        motionActive: root.living
        color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 46
    }
    Text {
        x: 21; y: 103; width: 160
        text: root.current ? WeatherState.label(root.current.weather_code) : WeatherState.busy ? I18n.tr("weather.loading") : I18n.tr("weather.no_data")
        color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; elide: Text.ElideRight
    }
    Rectangle { x: 20; y: 126; width: parent.width - 40; height: 1; color: Glass.tint(Session.accent, 0.22) }
    Row {
        x: 20; y: 137; spacing: 5
        Repeater {
            model: root.forecast
            Button {
                id: tile
                required property int index
                required property var modelData
                width: (root.width - 50) / 3; height: 47
                padding: 3; hoverEnabled: true
                Accessible.name: WeatherState.day(modelData.day) + ": " + WeatherState.label(modelData.code) + ", " + Math.round(modelData.high) + " / " + Math.round(modelData.low) + " " + I18n.tr("weather.degrees") + ". " + I18n.tr("weather.preview_forecast")
                onHoveredChanged: {
                    if (hovered) root.hoveredDay = index;
                    else if (root.hoveredDay === index) root.hoveredDay = -1;
                }
                onVisualFocusChanged: {
                    if (visualFocus) root.hoveredDay = index;
                    else if (!hovered && root.hoveredDay === index) root.hoveredDay = -1;
                }
                onClicked: root.pinnedDay = root.pinnedDay === index ? -1 : index
                transform: Translate {
                    y: tile.hovered || tile.visualFocus ? -3 : 0
                    Behavior on y { NumberAnimation { duration: root.living ? 180 : 0; easing.type: Easing.OutCubic } }
                }
                background: Rectangle {
                    radius: Math.min(12, Session.visual.widgetRadius)
                    color: Glass.tint(Session.accent, tile.hovered || tile.visualFocus ? 0.12 : 0.035)
                    border.width: 1
                    border.color: Glass.tint(Session.accent, root.previewIndex === tile.index ? 0.7 : 0.12)
                    Behavior on color { ColorAnimation { duration: root.living ? 180 : 0 } }
                    Behavior on border.color { ColorAnimation { duration: root.living ? 180 : 0 } }
                }
                contentItem: Item {
                    WeatherGlyph {
                        x: 1; y: 10; width: 27; height: 26
                        code: tile.modelData.code
                        animated: root.living && (tile.hovered || tile.visualFocus)
                    }
                    Text {
                        x: 33; y: 2; width: parent.width - 34
                        text: WeatherState.day(tile.modelData.day)
                        color: root.previewIndex === tile.index ? Session.foreground : Session.muted
                        font.family: Session.fontFamily; font.pixelSize: 10
                    }
                    Text {
                        x: 33; y: 23; width: parent.width - 34
                        text: Math.round(tile.modelData.high) + "° / " + Math.round(tile.modelData.low) + "°"
                        color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
    IconButton {
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
        width: 27; height: 27; symbol: "refresh"
        hint: WeatherState.error ? (WeatherState.data.stale ? I18n.tr("weather.saved_forecast") : "") + WeatherState.error : I18n.tr("weather.refresh_open_meteo")
        enabled: !WeatherState.busy; onClicked: WeatherState.refresh()
        RotationAnimator on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: WeatherState.busy && root.living }
    }
    IpcHandler {
        target: "desktop-weather"
        function status(): string { return JSON.stringify({animated: root.living, phase: scene.phase, currentCode: root.current ? root.current.weather_code : null, displayedCode: scene.code, day: scene.day, preview: root.previewIndex, pointer: [root.pointerX, root.pointerY], available: !!root.current}); }
        function preview(index: int): void { root.pinnedDay = index >= 0 && index < root.forecast.length ? index : -1; }
    }
}
