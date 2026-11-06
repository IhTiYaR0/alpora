pragma ComponentBehavior: Bound
import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../logic/CompanionLogic.js" as Logic
import "../logic/CompanionTravel.js" as Travel
import "../logic/CompanionThrow.js" as Throw
import "../logic/CompanionSurfaces.js" as Surfaces
import "../logic/WidgetGeometry.js" as Geometry

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: pet
    required property var modelData
    required property real railLeft
    required property real railRight
    required property real railBottom
    screen: modelData
    anchors { top: true; left: true }
    readonly property real extent: Math.max(24, Math.min(50, railBottom / 0.95 * 0.86))
    readonly property int normalWidth: Math.ceil(extent + 24)
    readonly property int normalHeight: Math.ceil(extent + 8)
    readonly property real monitorWidth: modelData ? modelData.width : 1920
    readonly property real monitorHeight: modelData ? modelData.height : 1080
    implicitWidth: normalWidth
    implicitHeight: normalHeight
    readonly property real minimumX: Math.ceil(railLeft)
    readonly property real maximumX: Math.floor(railRight - normalWidth)
    readonly property bool fits: maximumX >= minimumX
    readonly property real restingY: Math.max(0, Math.round(railBottom - extent * 0.98 - 4))
    readonly property real restingX: minimumX + Math.max(0, maximumX - minimumX) * behavior.position
    readonly property real freeWidth: Math.max(1, monitorWidth - normalWidth - 16)
    readonly property real freeHeight: Math.max(1, monitorHeight - normalHeight)
    readonly property bool away: !Motion.reduced && travel.mode !== "rail"
    readonly property bool tossing: toss.mode !== "idle"
    readonly property bool dragging: toss.mode === "grabbed"
    readonly property bool airborne: pressing ? false : tossing ? ["brake","recover"].includes(toss.mode) : away && !["floor","perch"].includes(travel.mode)
    readonly property real sceneX: tossing ? toss.x : away ? Math.max(0,Math.min(freeWidth+8,8+travel.x*freeWidth)) : restingX
    readonly property real sceneY: tossing ? toss.y : away ? Math.max(0,Math.min(freeHeight,travel.y*freeHeight)) : restingY
    readonly property real contentX: 0
    readonly property real contentY: 0
    readonly property real feetOffset: 4 + extent * .98
    readonly property var supportPixels: {
        const cfg=WidgetState.values;
        const widgets=["clock","weather","music"].filter(k=>cfg[k].enabled).map(k=> {
            const b=Geometry.bounds(k,cfg[k],monitorWidth,monitorHeight,
                Session.visual.barTop+Session.visual.barHeight+Math.max(20,Session.visual.barBottom+12));
            return Object.assign({id:"widget:"+k,kind:"widget",radius:Session.visual.widgetRadius},b);
        });
        const clients=Hyprland.toplevels.values.map(t=>t.lastIpcObject);
        const workspace=monitor && monitor.activeWorkspace?monitor.activeWorkspace.id:-1;
        return Surfaces.build(widgets,clients,{x:modelData?modelData.x:0,y:modelData?modelData.y:0,width:monitorWidth,height:monitorHeight},workspace,
            {width:normalWidth,height:normalHeight,extent:extent,feet:feetOffset},{left:railLeft,right:railRight,bottom:railBottom});
    }
    readonly property var supports: supportPixels.map(p=>({id:p.id,kind:p.kind,minX:(p.minX-8)/freeWidth,maxX:(p.maxX-8)/freeWidth,y:p.y/freeHeight,originX:((p.originX===undefined?p.minX:p.originX)-8)/freeWidth,width:(p.width===undefined?p.maxX-p.minX:p.width)/freeWidth}))
    readonly property var throwBounds: ({minX:8,maxX:freeWidth+8,maxY:freeHeight,surfaces:supportPixels})
    readonly property var travelContext: ({enabled:CompanionState.flights,lowBattery:lowBattery,lively:CompanionState.lively,
        surfaces:supports,width:freeWidth,height:freeHeight,homeX:Math.max(0,Math.min(1,(restingX-8)/freeWidth)),homeY:Math.max(0,Math.min(1,restingY/freeHeight))})
    property var travel: Travel.create(Date.now() % 4294967296)
    property var toss: Throw.create()
    // The visual window stays small and input-transparent throughout a drag.
    // A separate small input surface freezes its origin during each gesture.
    // qmllint disable missing-property
    margins { left: Math.round(pet.sceneX); top: Math.round(pet.sceneY) }
    // qmllint enable missing-property
    exclusionMode: ExclusionMode.Ignore; exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "poly-companion"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    readonly property string targetScreen: Quickshell.screens.find(s => s.name === WidgetState.values.screen)?.name || (Quickshell.screens.length ? Quickshell.screens[0].name : "")
    readonly property var monitor: modelData ? Hyprland.monitorFor(modelData) : null
    readonly property bool fullscreen: !!monitor && !!monitor.activeWorkspace && monitor.activeWorkspace.hasFullscreen
    readonly property bool screenAwake: !monitor || monitor.lastIpcObject.dpmsStatus !== false
    readonly property bool allowed: CompanionState.enabled && CompanionState.loaded && Session.loaded && !!modelData
        && modelData.name === targetScreen && fits && !ClockState.sleeping && screenAwake && !fullscreen
        && Session.mode !== "work" && !OverviewState.opened
    visible: allowed
    readonly property bool interactive: allowed
    onInteractiveChanged: if (!interactive) {cancelGesture();lastTick=0;}
    readonly property bool moving: interactive && !Motion.reduced
    readonly property string themeId: Session.appearance.id || ""
    onThemeIdChanged: react("greet")
    onAllowedChanged: if (!allowed) {cancelGesture();lastTick=0;}
    readonly property bool music: !!MusicState.player && MusicState.player.isPlaying
    readonly property bool lowBattery: Session.batteryPresent && Session.onBattery && Session.battery.percentage < 0.18
    readonly property var context: ({music:music,charging:Session.batteryCharging,lowBattery:lowBattery,lively:CompanionState.lively})
    property var behavior: Logic.create(Date.now() % 4294967296)
    readonly property string activity: Motion.reduced ? "sit" : pressing ? "grabbed" : tossing ? toss.mode : airborne ? "fly" : away ? travel.walking ? "walk" : behavior.activity === "walk" ? "look" : behavior.activity : behavior.activity
    readonly property string label: tossing ? I18n.tr("companion.playing") : away ? Travel.label(travel.mode) : Logic.labels()[activity] || I18n.tr("companion.near_you")
    property real gaitPhase: 0
    property real walkAmount: 0
    property real lastTick: 0
    property real geometryChangedAt: 0
    readonly property string attachedGeometry: {
        const p=supports.find(v=>v.id===travel.support);
        return p?JSON.stringify([p.originX,p.width,p.y,p.minX,p.maxX]):"";
    }
    onAttachedGeometryChanged: geometryChangedAt=Date.now()
    property bool held: false
    property bool pressing: false
    property bool suppressClick: false
    property bool processingDrag: false
    property string gestureEvent: ""
    property int gestureMoves: 0
    property real captureX: 0
    property real captureY: 0
    property real pressTime: 0
    property real pressRobotX: 0
    property real pressRobotY: 0
    readonly property rect hitBox: Qt.rect(Math.round(sceneX+6),Math.round(sceneY),Math.ceil(extent+12),Math.ceil(extent+12))
    property real pressPointerX: 0
    property real pressPointerY: 0
    property real gripX: 0
    property real gripY: 0
    function react(action: string): void {
        if (allowed && !Motion.reduced && !airborne && !tossing) behavior=Logic.react(behavior,action);
    }
    function takeOff(): void {
        if (moving && !tossing && !pressing) {held=false;travel=Travel.launch(travel,travelContext);}
    }
    function insideRobot(x: real,y: real): bool {
        return x>=hitBox.x && y>=hitBox.y && x<=hitBox.x+hitBox.width && y<=hitBox.y+hitBox.height;
    }
    function press(mouse: var): void {
        gestureEvent="press";gestureMoves=0;
        captureX=inputWindow.positionX;captureY=inputWindow.positionY;
        const x=mouse.x+captureX,y=mouse.y+captureY;
        pressRobotX=sceneX;pressRobotY=sceneY;pressTime=Date.now();
        pressPointerX=x;pressPointerY=y;
        gripX=x-pressRobotX;gripY=y-pressRobotY;
        pressing=true;held=true;suppressClick=false;
    }
    function dragPoint(mouse: var): void {
        if(!pressing || !moving || processingDrag)return;
        if(mouse.x===0 && mouse.y===0)return;
        processingDrag=true;gestureMoves++;
        const x=mouse.x+inputWindow.positionX,y=mouse.y+inputWindow.positionY;
        if(dragging || Math.hypot(x-pressPointerX,y-pressPointerY)>=4) {
            if(!dragging)toss=Throw.grab(pressRobotX,pressRobotY,pressTime);
            suppressClick=true;gestureEvent="drag";
            toss=Throw.move(toss,x-gripX,y-gripY,Date.now(),throwBounds);
        }
        processingDrag=false;
    }
    function releaseGesture(cancelled: bool): void {
        if(!pressing && !dragging){held=false;return;}
        const now=Date.now();
        gestureEvent=cancelled?"cancel":"release";
        if(dragging) {
            toss=Throw.release(toss,now,cancelled);
        } else if(!cancelled && moving && now-pressTime>=180) {
            // A deliberate stationary hold is a gentle drop, not a click.
            toss=Throw.release(Throw.grab(sceneX,sceneY,now),now,false);
            suppressClick=true;
        } else if(cancelled && tossing) {
            toss=Throw.release(Throw.grab(sceneX,sceneY,now),now,true);
        }
        pressing=false;
        held=!cancelled && !tossing && insideRobot(pointer.mouseX+inputWindow.positionX,pointer.mouseY+inputWindow.positionY);
    }
    function cancelGesture(): void {suppressClick=true;releaseGesture(true);}
    function finishThrow(): void {
        if (toss.mode === "landed") AudioFeedback.playTock();
        travel=toss.mode==="landed"?Travel.perchAt(travel,travelContext,toss.support,(toss.x-8)/freeWidth)
            :Travel.resumeAt(travel,travelContext,(toss.x-8)/freeWidth,toss.y/freeHeight);
        toss=Throw.create();
    }
    // Hyprland does not emit continuous geometry events while dragging windows.
    // Native IPC refresh only while travelling/attached; no spawned poll process.
    Timer {interval:pet.travel.support.indexOf("window:")===0?(pet.lastTick-pet.geometryChangedAt<350?33:120):500;repeat:true;running:pet.moving && pet.away;onTriggered:Hyprland.refreshToplevels()}
    Connections {
        target:Hyprland
        function onRawEvent(event): void {
            if(/^(openwindow|closewindow|movewindow|workspace|focusedmon|changefloatingmode|pin)/.test(event.name))Hyprland.refreshToplevels();
        }
    }
    Component.onCompleted: Hyprland.refreshToplevels()
    Connections {
        target: Motion
        function onReducedChanged(): void {
            if(Motion.reduced){pet.cancelGesture();pet.toss=Throw.create();pet.travel=Travel.create(17);}
        }
    }
    onMusicChanged: if(music) react("dance")
    onLowBatteryChanged: if(lowBattery) react("nap")
    Connections {
        target: Session
        function onBatteryChargingChanged(): void {if(Session.batteryCharging)pet.react("charge");}
    }
    Timer {
        interval: pet.tossing || pet.pressing || pet.away || ["walk","greet","catch","dance","service"].includes(pet.behavior.activity) ? 16 : ["sit","sleep","nap"].includes(pet.behavior.activity) ? 100 : 33; repeat: true
        running: pet.moving
        onTriggered: {
            const now=Date.now(),dt=pet.lastTick?Math.max(0,Math.min(.05,(now-pet.lastTick)/1000)):interval/1000;
            pet.lastTick=now;
            const oldX=pet.sceneX;
            const next=Logic.step(pet.behavior,dt,pet.context);
            if(pet.away || pet.tossing || pet.pressing || pet.held)next.position=pet.behavior.position;
            if(pet.held)next.age=Math.min(next.age,2.5);
            pet.behavior=next;
            if(pet.pressing && !pet.dragging) {
                // Pause existing flight/fall from the very first press.
            } else if(pet.tossing) {
                pet.toss=Throw.step(pet.toss,dt,pet.throwBounds);
                if(pet.toss.mode==="done" || pet.toss.mode==="landed")pet.finishThrow();
            } else if(!pet.held && !pet.pressing)pet.travel=Travel.step(pet.travel,dt,pet.travelContext);
            const walking=!pet.held && !pet.pressing && !pet.tossing && !pet.airborne &&
                (pet.away?pet.travel.walking:Math.abs(pet.sceneX-oldX)>.01);
            // Attached-window motion is not a step. Only locomotion advances gait.
            const distance=walking?(pet.away?26*dt*pet.travel.direction:pet.sceneX-oldX):0;
            pet.gaitPhase+=distance/Math.max(6,pet.extent/3)*Math.PI*2;
            pet.walkAmount+=(Number(walking)-pet.walkAmount)*(1-Math.exp(-14*dt));
        }
    }
    mask: Region {}
    CompanionSprite {
        id: sprite
        x:pet.contentX+12;y:pet.contentY+4;width:pet.extent;height:pet.extent
        gaitPhase:pet.gaitPhase;walkAmount:pet.walkAmount
        landing:pet.away && ["perch","floor"].includes(pet.travel.mode)?Math.max(0,1-pet.travel.age/.4):0
        activity:pet.activity;phase:pet.behavior.phase;age:pet.behavior.age
        interaction:pet.pressing?"grabbed":pet.tossing?pet.toss.mode:"";interactionTilt:pet.toss.angle
        flightBlend:pet.airborne?(pet.travel.mode==="land" && !pet.tossing?Math.max(0,1-pet.travel.age/.45):1):0
        flying:pet.airborne;flightBank:pet.travel.bank
        direction:pet.away?pet.travel.direction:pet.behavior.direction;animated:pet.moving;hovered:pointer.containsMouse
    }
    // A small transparent input surface follows the robot until a press.
    // It stays fixed during the gesture, avoiding coordinate feedback and a
    // full-screen transparent render target. Keyboard focus is never requested.
    // qmllint disable uncreatable-type
    PanelWindow {
        // qmllint enable uncreatable-type
        id: inputWindow
        screen: pet.modelData
        anchors {top:true;left:true}
        readonly property real positionX: pet.pressing?pet.captureX:Math.round(pet.sceneX)
        readonly property real positionY: pet.pressing?pet.captureY:Math.round(pet.sceneY)
        // Freeze this window's origin during the implicit Wayland pointer grab.
        // Mouse events outside its bounds still arrive until release; adding
        // that fixed origin gives screen coordinates without a full-screen buffer.
        // qmllint disable missing-property
        margins {left:inputWindow.positionX;top:inputWindow.positionY}
        // qmllint enable missing-property
        implicitWidth:pet.normalWidth
        implicitHeight:Math.max(pet.normalHeight,Math.ceil(pet.extent+12))
        visible: pet.allowed
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore;exclusiveZone:0
        WlrLayershell.namespace: "poly-companion-input"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {x:6;y:0;width:pet.interactive?pet.hitBox.width:0;height:pet.interactive?pet.hitBox.height:0}
        MouseArea {
            id: pointer
            anchors.fill: parent
            enabled:pet.interactive;hoverEnabled:true;acceptedButtons:Qt.LeftButton;preventStealing:true
            cursorShape:pressed?Qt.ClosedHandCursor:Qt.OpenHandCursor
            onEntered: {if(!pet.tossing){pet.held=true;pet.react("greet");}}
            onExited: if(!pet.pressing)pet.held=false
            onPressed: mouse=>pet.press(mouse)
            onPositionChanged: mouse=>{if(pressed)pet.dragPoint(mouse);else if(!pet.tossing)pet.held=pet.insideRobot(mouse.x+inputWindow.positionX,mouse.y+inputWindow.positionY); }
            onReleased: mouse=>{pet.dragPoint(mouse);pet.releaseGesture(false); }
            onCanceled: pet.cancelGesture()
            onClicked: {
                if(pet.suppressClick || pet.airborne || pet.tossing)return;
                pet.react("greet");
            }
        }
    }
    IpcHandler {
        target:"companion-"+(pet.modelData?pet.modelData.name:"disconnected")
        function status(): string {
            return JSON.stringify({visible:pet.visible,allowed:pet.allowed,ticking:pet.moving,activity:pet.activity,label:pet.label,
                actions:pet.behavior.actions,age:pet.behavior.age,phase:pet.behavior.phase,position:pet.behavior.position,direction:pet.behavior.direction,
                rail:{left:pet.railLeft,right:pet.railRight,bottom:pet.railBottom},
                supports:pet.supportPixels,feetY:pet.sceneY+pet.feetOffset,
                travel:{support:pet.travel.support,walking:pet.travel.walking,mode:pet.travel.mode,trips:pet.travel.trips,age:pet.travel.age,x:pet.travel.x,y:pet.travel.y},
                throwState:{mode:pet.toss.mode,vx:pet.toss.vx,vy:pet.toss.vy,strong:pet.toss.strong,angle:pet.toss.angle},
                dragging:pet.dragging,pressing:pet.pressing,hitBox:{x:pet.hitBox.x,y:pet.hitBox.y,width:pet.hitBox.width,height:pet.hitBox.height},pointerPressed:pointer.pressed,gestureEvent:pet.gestureEvent,gestureMoves:pet.gestureMoves,grip:{x:pet.gripX,y:pet.gripY},clickThrough:false,flying:pet.airborne,
                bounds:{x:Math.round(pet.sceneX),y:Math.round(pet.sceneY),width:pet.normalWidth,height:pet.normalHeight},
                surface:{width:pet.width,height:pet.height},inputSurface:{width:inputWindow.width,height:inputWindow.height},fits:pet.fits,held:pet.held,music:pet.music,charging:Session.batteryCharging,
                fullscreen:pet.fullscreen,reduced:Motion.reduced,theme:Session.appearance.id});
        }
        function greet(): void {pet.react("greet");}
        function takeOff(): void {pet.takeOff();}
        function visitSurface(id: string): void {
            if(!pet.moving || pet.tossing || !CompanionState.flights)return;
            const p=pet.supports.find(v=>v.id===id);
            if(!p)return;
            let s=Object.assign({},pet.travel);s.x=(pet.sceneX-8)/pet.freeWidth;s.y=pet.sceneY/pet.freeHeight;
            s.support=id;s.anchor=Travel.anchorFor(p,(p.minX+p.maxX)/2);
            Travel.leg(s,"fly",pet.travelContext,(p.minX+p.maxX)/2,Math.max(0,p.y-22/pet.freeHeight));
            pet.held=false;pet.travel=s;
        }
        function returnHome(): void {if(!pet.tossing)pet.travel=Travel.recall(pet.travel,pet.travelContext);}
    }
}
