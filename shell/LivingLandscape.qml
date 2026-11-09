pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "LandscapeGeometry.js" as Scene

// The Bottom layer puts all interaction behind real application windows.
// This surface also owns the existing desktop right-click menu. It never
// appears above applications; a single pointer observer handles all exits.
// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root
    required property var modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore; exclusiveZone: 0
    color: "transparent"
    readonly property var scene: Scene.layout(Session.appearance.id || "alpine", TimelineState.shownMinute, width, height)
    readonly property real fit: scene.scale
    readonly property bool allowed: LandscapeState.enabled && LandscapeState.loaded && Session.loaded && !ClockState.sleeping && !OverviewState.opened && !BarState.selection.name && !ThemeState.busy
    visible: !!modelData && LandscapeState.enabled && LandscapeState.loaded && Session.loaded
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "poly-living-landscape"
    // Hover previews never own typing; the app search requests it after a click
    // and releases it as soon as the app menu closes.
    WlrLayershell.keyboardFocus: active === "apps" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    property string active: ""
    property string fading: ""
    property real reveal: active.length ? 1 : 0
    readonly property string shown: active.length ? active : fading
    readonly property bool animate: allowed && active === "music" && !!MusicState.player && MusicState.player.isPlaying && !Motion.reduced
    property real phase: 0
    property string search: ""
    property string lastExit: ""
    readonly property var appChoices: search.length ? AppCatalog.results(search, "").slice(0,6) : (AppCatalog.favorites.length ? AppCatalog.favorites : AppCatalog.entries).slice(0,6)
    readonly property var themes: ThemeState.items
    function bounds(item: Item): var {
        const point = item.mapToItem(null, 0, 0);
        return {x: point.x, y: point.y, width: item.width * fit, height: item.height * fit};
    }
    function open(kind: string): void {
        if (!allowed || active === kind) return;
        active = kind; fading = kind;
        if (kind === "light") Desktop.request("status", "");
    }
    function close(): void { active = ""; search = ""; }
    function updatePointer(): void {
        if (!pointer.hovered) { lastExit = "surface leave"; close(); return; }
        const x = pointer.point.position.x, y = pointer.point.position.y;
        // An invalid/reset HandlerPoint is not a cursor motion to a corner.
        if (x === 0 && y === 0) return;
        const inside = item => x >= item.x && y >= item.y && x <= item.x + item.width && y <= item.y + item.height;
        if (inside(lightTrigger)) open("light");
        else if (inside(musicTrigger)) open("music");
        else if (active.length && !inside(active === "light" ? lightStage : active === "music" ? musicStage : peakStage)) { lastExit = "position " + x + "," + y; close(); }
    }
    function launch(entry: var): void { close(); Session.launchEntry(entry); }
    onAllowedChanged: if (!allowed) close()
    Connections {
        target: Session
        function onAppearanceChanged(): void { root.close(); }
    }
    Behavior on reveal {
        NumberAnimation { duration: Motion.reduced ? 0 : root.active.length ? 260 : 180; easing.type: Easing.OutCubic }
    }
    NumberAnimation on phase {
        from: 0; to: Math.PI * 200; duration: 300000; loops: Animation.Infinite
        running: root.animate
    }
    HoverHandler {
        id: pointer
        enabled: root.allowed
        // Qt resets HandlerPoint to (0,0) briefly when crossing child controls.
        // Read the settled position at this event's end, without a hover timer.
        onPointChanged: Qt.callLater(root.updatePointer)
        onHoveredChanged: Qt.callLater(root.updatePointer)
    }
    mask: DesktopInputRegion { screenData: root.modelData; inputEnabled: root.allowed }
    // Right-click retains the existing theme wheel even inside a landmark.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: mouse => { root.close(); LandscapeState.themeRequested(root.modelData.name, mouse.x, mouse.y); }
    }
    Item {
        id: lightTrigger
        x: root.scene.light.x - width / 2; y: root.scene.light.y - height / 2
        width: 88 * root.fit; height: width
        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: root.open("light"); onClicked: root.open("light") }
    }
    Item {
        id: peakTrigger
        x: root.scene.peak.x - width / 2; y: root.scene.peak.y - height / 2
        width: 68 * root.fit; height: width
        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.active === "apps" ? root.close() : root.open("apps") }
    }
    Item {
        id: musicTrigger
        x: root.scene.music.x - width / 2; y: root.scene.music.y - height / 2
        width: 180 * root.fit; height: 60 * root.fit
        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: root.open("music"); onClicked: root.open("music") }
    }
    // Quiet discovery points are deliberately static. No idle frame timer.
    Repeater {
        model: ["light", "peak", "music"]
        Item {
            id: beacon
            required property string modelData
            readonly property var spot: root.scene[modelData]
            x: spot.x - 15; y: spot.y - 15; width: 30; height: 30
            visible: root.allowed && root.active.length === 0
            Rectangle { anchors.centerIn: parent; width: 26; height: 26; radius: 13; color: Glass.tint(Session.accent, 0.06) }
            Rectangle { anchors.centerIn: parent; width: 13; height: 13; radius: 6.5; color: Glass.tint(Session.accent, 0.13) }
            Rectangle { anchors.centerIn: parent; width: 5; height: 5; radius: 2.5; color: Session.accent; border.width: 0.5; border.color: Session.foreground }
        }
    }
    Item {
        id: lightStage
        x: root.scene.light.x - 195 * root.fit; y: root.scene.light.y - 215 * root.fit
        width: 420 * root.fit; height: 410 * root.fit
        visible: root.shown === "light" && root.reveal > 0
        opacity: root.shown === "light" ? root.reveal : 0
        enabled: root.active === "light"
        Item {
            width: 420; height: 410; scale: root.fit; transformOrigin: Item.TopLeft
            Repeater {
                model: 12
                Rectangle {
                    required property int index
                    x: 195 - width/2; y: 215 - height/2
                    width: 160 - index * 10; height: width; radius: width/2
                    color: Glass.tint(Session.accent, 0.013)
                }
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"; strokeColor: Glass.tint(Session.accent, 0.7); strokeWidth: 1
                    PathAngleArc { centerX: 195; centerY: 215; radiusX: 151; radiusY: 151; startAngle: -106; sweepAngle: 142 * root.reveal }
                }
            }
            Repeater {
                model: [
                    {symbol:"sun", label:"Яркость", action:"brightness"},
                    {symbol:"wallpaper", label:"Темы и обои", action:"themes"},
                    {symbol:"moon", label:"Ночной свет", action:"night"},
                    {symbol:"settings", label:"Настройки", action:"settings"},
                    {symbol:"lock", label:"Заблокировать", action:"lock"}
                ]
                LandscapeButton {
                    id: sunButton
                    required property int index
                    required property var modelData
                    readonly property real angle: (-99 + index * 32) * Math.PI / 180
                    x: 195 + Math.cos(angle) * (126 + 25 * root.reveal) - width/2
                    y: 215 + Math.sin(angle) * (126 + 25 * root.reveal) - height/2
                    symbol: modelData.symbol; hint: modelData.label
                    selected: modelData.action === "night" && Desktop.data.nightLight
                    enabled: modelData.action !== "night" || Desktop.data.nightLightAvailable
                    onClicked: {
                        if (modelData.action === "brightness") brightness.forceActiveFocus();
                        else if (modelData.action === "themes") { root.close(); LandscapeState.themeRequested(root.modelData.name, root.scene.light.x, root.scene.light.y); }
                        else if (modelData.action === "night") Desktop.request("nightlight", "");
                        else if (modelData.action === "settings") { root.close(); Quickshell.execDetached([Session.controller,"settings"]); }
                        else if (modelData.action === "lock") { root.close(); Session.launch("lock"); }
                    }
                }
            }
            Rectangle {
                x: 5; y: 60; width: 164; height: 58; radius: Math.min(16, Session.visual.panelRadius)
                color: Glass.tint(Session.surface, 0.9); border.width: 0.8; border.color: Glass.tint(Session.accent,0.4)
                Text { x: 13; y: 8; text: "Яркость · " + Desktop.data.brightness + "%"; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11 }
                ControlSlider {
                    id: brightness
                    x: 13; y: 29; width: 138; height: 20
                    from: 5; to: 100; stepSize: 1; value: Desktop.data.brightness
                    enabled: Desktop.data.brightnessAvailable
                    Accessible.name: "Яркость экрана"
                    onMoved: Desktop.request("brightness", String(Math.round(value)))
                }
            }
            Row {
                x: 5; y: 130; spacing: 6
                Repeater {
                    model: root.themes
                    Button {
                        id: swatch
                        required property var modelData
                        width: 20; height: 20; hoverEnabled: true
                        Accessible.name: modelData.label
                        ToolTip.visible: hovered; ToolTip.text: modelData.label
                        background: Rectangle { radius: 10; color: swatch.modelData.palette.accent; border.width: Session.appearance.id === swatch.modelData.id ? 2 : 0.6; border.color: Session.foreground }
                        onClicked: if (!ThemeState.busy) { root.close(); ThemeState.request("apply", {id: modelData.id, colorsFromWallpaper: ThemeState.baseAutomatic}); }
                    }
                }
            }
            Text { x: 5; y: 166; text: root.scene.name + " · оформление"; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11; style: Text.Outline; styleColor: Glass.tint(Session.background, 0.8) }
            Text { x: 5; y: 292; width: 175; text: Desktop.error || ThemeState.error; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap; visible: text.length > 0 }
        }
    }
    Item {
        id: musicStage
        x: root.scene.music.x - 240 * root.fit; y: root.scene.music.y - 155 * root.fit
        width: 480 * root.fit; height: 300 * root.fit
        visible: root.shown === "music" && root.reveal > 0
        opacity: root.shown === "music" ? root.reveal : 0
        enabled: root.active === "music"
        Item {
            width: 480; height: 300; scale: root.fit; transformOrigin: Item.TopLeft
            Item {
                id: musicContent
                width: 480; height: 155
                Text { x: 25; y: 2; width: 430; horizontalAlignment: Text.AlignHCenter; text: MusicState.player ? MusicState.player.trackTitle || "Без названия" : "Музыка у воды"; textFormat: Text.PlainText; elide: Text.ElideRight; font.family: Session.fontFamily; font.pixelSize: 19; font.weight: Font.Medium; color: Session.foreground; style: Text.Outline; styleColor: Glass.tint(Session.background, 0.8) }
                Text { x: 25; y: 30; width: 430; horizontalAlignment: Text.AlignHCenter; text: MusicState.player ? MusicState.player.trackArtist || MusicState.player.identity : "Включи трек в любимом плеере"; textFormat: Text.PlainText; elide: Text.ElideRight; font.family: Session.fontFamily; font.pixelSize: 12; color: Session.foreground; style: Text.Outline; styleColor: Glass.tint(Session.background, 0.8) }
                Row {
                    x: (parent.width-width)/2; y: 60; spacing: 18
                    LandscapeButton { symbol: "previous"; hint: "Предыдущий трек"; enabled: !!MusicState.player && MusicState.player.canControl && MusicState.player.canGoPrevious; onClicked: MusicState.player.previous() }
                    LandscapeButton { id: playButton; width: 50; height: 50; selected: true; symbol: MusicState.player && MusicState.player.isPlaying ? "pause-dark" : "play-dark"; hint: MusicState.player && MusicState.player.isPlaying ? "Пауза" : "Воспроизвести"; enabled: !!MusicState.player && MusicState.player.canControl && MusicState.player.canTogglePlaying; onClicked: MusicState.player.togglePlaying() }
                    LandscapeButton { symbol: "next"; hint: "Следующий трек"; enabled: !!MusicState.player && MusicState.player.canControl && MusicState.player.canGoNext; onClicked: MusicState.player.next() }
                }
                Item {
                    x: 0; y: 108; width: 480; height: 47
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true; shadowColor: Glass.tint(Session.accent, 0.5)
                        shadowBlur: 0.75; shadowVerticalOffset: 1
                    }
                    Repeater {
                    model: 69
                    Item {
                        id: waveBar
                        required property int index
                        readonly property real distance: Math.abs((index - 34)/34)
                        readonly property real wave: (0.5 + 0.5 * Math.sin(index * 0.71 + root.phase * 2.1)) * (0.65 + 0.35 * Math.cos(index * 0.29 - root.phase))
                        readonly property real amplitude: MusicState.player && MusicState.player.isPlaying ? (Motion.reduced ? 0.4 : wave) : 0.07
                        x: 33 + index * 6; y: 38; width: 3
                        height: 3 + Math.pow(1-distance, 0.7) * 36 * amplitude
                        Rectangle { x: -3; y: -waveBar.height - 3; width: 9; height: waveBar.height + 6; radius: 4; color: Glass.tint(Session.accent, 0.07) }
                        Rectangle { y: -waveBar.height; width: 3; height: waveBar.height; radius: 1.5; color: Session.accent }
                    }
                    }
                }
                Rectangle { x: 25; y: 146; width: 430; height: 1; color: Glass.tint(Session.accent, 0.3) }
            }
            ShaderEffectSource {
                id: reflectionSource
                sourceItem: musicContent; sourceRect: Qt.rect(0,0,480,155)
                textureSize: Qt.size(960,310)
                hideSource: false; live: root.active === "music"
                visible: false
            }
            ShaderEffect {
                x: 0; y: 151; width: 480; height: 105
                visible: root.scene.water
                property var source: reflectionSource
                property real phase: root.phase
                property real motion: Motion.reduced ? 0 : 1
                fragmentShader: Qt.resolvedUrl("shaders/landscape-reflection.frag.qsb")
            }
            Text { x: 0; y: 254; width: 480; horizontalAlignment: Text.AlignHCenter; text: root.scene.water ? "" : "Ритм песков"; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11 }
        }
    }
    Item {
        id: peakStage
        x: root.scene.peak.x - 250 * root.fit; y: root.scene.peak.y - 230 * root.fit
        width: 500 * root.fit; height: 340 * root.fit
        visible: root.shown === "apps" && root.reveal > 0
        opacity: root.shown === "apps" ? root.reveal : 0
        enabled: root.active === "apps"
        Item {
            width: 500; height: 340; scale: root.fit; transformOrigin: Item.TopLeft
            Shape {
                anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"; strokeColor: Glass.tint(Session.accent, 0.65); strokeWidth: 1
                    PathAngleArc { centerX: 250; centerY: 230; radiusX: 188; radiusY: 170; startAngle: -156; sweepAngle: 132 * root.reveal }
                }
            }
            Repeater {
                model: root.appChoices
                LandscapeButton {
                    required property int index
                    required property var modelData
                    readonly property real angle: (-156 + index * 132 / Math.max(1, root.appChoices.length-1)) * Math.PI/180
                    x: 250 + Math.cos(angle) * (165 + 23 * root.reveal) - width/2
                    y: 230 + Math.sin(angle) * (147 + 23 * root.reveal) - height/2
                    width: 52; height: 52; imageSource: AppCatalog.iconSource(modelData); hint: modelData.name
                    onClicked: root.launch(modelData)
                }
            }
            TextField {
                id: searchField
                x: 110; y: 256; width: 280; height: 38
                placeholderText: "Найти приложение"; text: root.search
                color: Session.foreground; placeholderTextColor: Session.muted
                font.family: Session.fontFamily; font.pixelSize: 12
                leftPadding: 16; rightPadding: 16; selectByMouse: true
                background: Rectangle { radius: 19; color: Glass.tint(Session.surface, 0.92); border.width: 1; border.color: Glass.tint(searchField.activeFocus ? Session.accent : Session.muted, 0.65) }
                onTextEdited: root.search = text
                onAccepted: if (root.appChoices.length) root.launch(root.appChoices[0])
                Keys.onEscapePressed: root.close()
            }
            Text { x: 100; y: 307; width: 300; horizontalAlignment: Text.AlignHCenter; text: root.search.length && !root.appChoices.length ? "Ничего не найдено" : "Вершина · приложения"; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11; style: Text.Outline; styleColor: Glass.tint(Session.background, 0.8) }
        }
    }
    IpcHandler {
        target: "landscape-" + (root.modelData ? root.modelData.name : "disconnected")
        function status(): string { return JSON.stringify({allowed:root.allowed, active:root.active, reveal:root.reveal, scene:root.scene, width:root.width, height:root.height, apps:root.appChoices.map(e=>({id:e.id,name:e.name})), search:root.search, focused:searchField.activeFocus, lastExit:root.lastExit, pointer:{x:pointer.point.position.x,y:pointer.point.position.y,hovered:pointer.hovered}, controls:{search:root.bounds(searchField),play:root.bounds(playButton),brightness:root.bounds(brightness)}, animated:root.animate}); }
        function show(kind: string): void { if (["light","music","apps"].includes(kind)) root.open(kind); }
        function close(): void { root.close(); }
    }
}
