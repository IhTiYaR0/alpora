pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Shapes
import "../theme" as PolyTheme

// A small articulated field robot. Static native geometry, one external clock,
// semantic metal/paint/LED materials; no bitmap animation or full-screen effect.
Item {
    id: bot
    property string activity: "sit"
    property real phase: 0
    property real age: 0
    property int direction: 1
    property bool animated: true
    property bool hovered: false
    property bool flying: false
    property real flightBank: 0
    property real gaitPhase: phase * 5
    property real walkAmount: walking ? 1 : 0
    property real landing: 0
    property real flightBlend: flying ? 1 : 0
    readonly property real bank: bankTween.value
    CompanionTween { id: flightTween; clock: bot.phase; targetValue: bot.flightBlend; duration: 240; enabled: bot.animated }
    CompanionTween { id: bankTween; clock: bot.phase; targetValue: bot.flightBank; duration: 130; easeInOut: false; enabled: bot.animated }
    readonly property real blendedFlight: flightTween.value
    property string interaction: ""
    property real interactionTilt: 0
    readonly property real time: animated ? phase : 0
    readonly property bool walking: animated && activity === "walk"
    readonly property bool dancing: animated && activity === "dance"
    readonly property bool sleeping: activity === "nap"
    readonly property bool cheerful: !["grabbed","fall","shake","annoyed"].includes(interaction) && !sleeping && (hovered || activity === "greet" || activity === "catch" || dancing || flying)
    readonly property bool servicing: activity === "service"
    readonly property real stride: animated ? Math.sin(gaitPhase) * walkAmount : 0
    readonly property real beat: dancing ? Math.sin(time * 8) : 0
    readonly property real blink: interaction === "annoyed" ? 0.5 : sleeping ? 0.12 : animated && time % 5.4 > 5.23 ? 0.12 : 1
    readonly property real gaze: activity === "look" ? Math.sin(time * 1.7) * 2 : hovered ? 0 : direction * 0.7
    readonly property color metal: PolyTheme.Theme.mix(Session.foreground, Session.accent, 0.35)
    readonly property color metalLight: PolyTheme.Theme.mix(Session.foreground, Session.accent, 0.10)
    readonly property color metalShade: PolyTheme.Theme.mix(Session.accent, Session.surface, 0.38)
    readonly property color paint: Session.accent
    readonly property color paintShade: PolyTheme.Theme.mix(Session.accent, Session.surface, 0.44)
    readonly property color chassis: PolyTheme.Theme.mix(Session.background, Session.surface, 0.24)
    readonly property color seam: PolyTheme.Theme.mix(Session.surface, Session.foreground, 0.14)
    readonly property color led: PolyTheme.Theme.mix(Session.accent, Session.foreground, 0.25)
    readonly property color warm: PolyTheme.Theme.secondary
    readonly property color edge: PolyTheme.Theme.withAlpha(Session.background, 0.64)
    implicitWidth: 100; implicitHeight: 100
    Item {
        width: 100; height: 100; scale: Math.min(bot.width / 100, bot.height / 100)
        transformOrigin: Item.TopLeft
        Rectangle { visible: !bot.flying && !bot.interaction; x: 33; y: 98; width: 38; height: 1.5; radius: 1.5; color: PolyTheme.Theme.withAlpha(Session.background, 0.28) }
        Item {
            id: robot
            width: 100; height: 100
            y: bot.landing * 3 + (bot.dancing ? -Math.abs(bot.beat) * 2 : 0)
            rotation: bot.interaction ? bot.interactionTilt : bot.blendedFlight > .01 ? bot.bank * bot.blendedFlight : 0
            // Two-link inverse kinematics: ankle targets share a fixed floor
            // baseline. The stance foot travels backwards at walking speed;
            // only the returning foot lifts. Hip and knee solve that target.
            Repeater {
                model: 2
                Item {
                    id: leg
                    required property int index
                    readonly property real cycle: ((bot.gaitPhase / (Math.PI * 2) + index * .5) % 1 + 1) % 1
                    readonly property real stepX: (cycle < .6 ? 10 - 20 * cycle / .6 : -10 + 20 * (cycle - .6) / .4) * bot.walkAmount
                    readonly property real lift: cycle < .6 ? 0 : Math.sin((cycle - .6) / .4 * Math.PI) * 6 * bot.walkAmount
                    readonly property real ankleX: stepX + bot.blendedFlight * (index ? 3 : -3)
                    readonly property real ankleY: 20 - lift - robot.y - bot.blendedFlight * 5
                    readonly property real distance: Math.max(3.1,Math.min(22.99,Math.hypot(ankleX,ankleY)))
                    readonly property real knee: Math.acos((distance * distance - 269) / 260)
                    readonly property real hip: Math.atan2(ankleX,ankleY) - Math.atan2((index ? -13 : 13) * Math.sin(knee),10 + 13 * Math.cos(knee))
                    readonly property real hipAngle: -hip * 180 / Math.PI + (bot.interaction === "grabbed" ? Math.sin(bot.time*7)*(index ? -9 : 9) : 0)
                    readonly property real kneeAngle: (index ? 1 : -1) * knee * 180 / Math.PI
                    x: index ? 53 : 36; y: 72; width: 15; height: 28
                    transform: Rotation {origin.x:7.5;origin.y:0;angle:leg.hipAngle}
                    Rectangle {x:4;y:0;width:8;height:11;radius:2;color:bot.chassis;border.width:.65;border.color:bot.edge}
                    Rectangle {x:5.5;y:1;width:2;height:8;radius:.8;color:bot.metalShade}
                    Item {
                        x:0;y:10;width:15;height:19
                        transform: Rotation {origin.x:7.5;origin.y:0;angle:leg.kneeAngle}
                        Rectangle {x:3;y:-3;width:10;height:9;radius:4.5;color:bot.seam;border.width:.6;border.color:bot.edge}
                        Rectangle {x:5.5;y:-.5;width:5;height:4;radius:2;color:bot.paintShade}
                        Shape {
                            x:3;y:3;width:10;height:11;preferredRendererType:Shape.CurveRenderer
                            ShapePath {strokeWidth:.65;strokeColor:bot.edge;fillColor:bot.metal;PathSvg {path:"M1 0 L8 0 L10 3 L8 10 L1 10 L0 3 Z"}}
                            ShapePath {strokeWidth:0;fillColor:bot.metalShade;PathSvg {path:"M8 0 L10 3 L8 10 L5 9 L6 3 Z"}}
                            ShapePath {strokeWidth:0;fillColor:bot.paint;PathSvg {path:"M3 2 L6 2 L5 7 L3 7 Z"}}
                        }
                        Item {
                            x:0;y:13;width:17;height:6
                            transform:Rotation {origin.x:7.5;origin.y:0;angle:-(leg.hipAngle+leg.kneeAngle)*(1-bot.blendedFlight)}
                            Rectangle {x:5;y:0;width:6;height:3;radius:1;color:bot.chassis}
                            Shape {
                                width:17;height:6;preferredRendererType:Shape.CurveRenderer
                                ShapePath {strokeWidth:.65;strokeColor:bot.edge;fillColor:bot.metalShade;PathSvg {path:"M3 0 L12 0 L16 3 L16 6 L0 6 L0 3 Z"}}
                                ShapePath {strokeWidth:0;fillColor:bot.metal;PathSvg {path:"M3 0 L12 0 L16 3 L2 3 Z"}}
                                ShapePath {strokeWidth:.8;strokeColor:bot.chassis;fillColor:"transparent";PathSvg {path:"M1 5 L15 5 M11 2 L12 4 M7 2 L8 4"}}
                            }
                        }
                    }
                }
            }
            // Fold-out thruster pods and two bounded flame shapes. They stay
            // inside the small character surface and share its bounded animation clock.
            Repeater {
                model: 2
                Item {
                    required property int index
                    visible: opacity > .01; opacity: bot.blendedFlight
                    x: index ? 67 : 26; y: 53; width: 9; height: 43
                    Shape {
                        width: 9; height: 18; preferredRendererType: Shape.CurveRenderer
                        ShapePath { strokeWidth: 0.7; strokeColor: bot.edge; fillColor: bot.metalShade; PathSvg { path: "M2 0 L7 0 L9 5 L8 15 L6 18 L2 18 L0 14 L0 5 Z" } }
                        ShapePath { strokeWidth: 0; fillColor: bot.paint; PathSvg { path: "M2 2 L5 2 L5 13 L2 13 Z" } }
                        ShapePath { strokeWidth: 1; strokeColor: bot.chassis; fillColor: "transparent"; PathSvg { path: "M1 14 L8 14 M2 16 L7 16" } }
                    }
                    Shape {
                        x: 0; y: 18; width: 9; height: 24
                        scale: bot.animated ? 0.9 + Math.sin(bot.time * 17) * 0.1 : 1
                        transformOrigin: Item.Top
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath { strokeWidth: 0; fillColor: PolyTheme.Theme.withAlpha(bot.led, 0.32); PathSvg { path: "M0 0 L9 0 L7 12 L4.5 24 L2 12 Z" } }
                        ShapePath { strokeWidth: 0; fillColor: bot.led; PathSvg { path: "M2 0 L7 0 L6 9 L4.5 17 L3 9 Z" } }
                        ShapePath { strokeWidth: 0; fillColor: bot.metalLight; PathSvg { path: "M3.5 0 L5.5 0 L4.5 9 Z" } }
                    }
                }
            }
            // Hip drive, flexible waist and side-mounted battery pack.
            Rectangle { x: 35; y: 68; width: 34; height: 7; radius: 2; color: bot.chassis; border.width: 0.7; border.color: bot.edge }
            Repeater {
                model: 4
                Rectangle { required property int index; x: 42 + index * 5; y: 69; width: 2; height: 4; radius: 0.5; color: bot.metalShade }
            }
            Rectangle { x: 29; y: 47; width: 7; height: 19; radius: 2; color: bot.paintShade; border.width: 0.7; border.color: bot.edge }
            Rectangle { x: 30; y: 49; width: 2; height: 10; radius: 0.7; color: bot.warm }
            Shape {
                x: 33; y: 42; width: 37; height: 28; preferredRendererType: Shape.CurveRenderer
                ShapePath { strokeWidth: 0.8; strokeColor: bot.edge; fillColor: bot.metal; PathSvg { path: "M7 0 L29 0 Q34 0 37 7 L34 23 Q32 28 27 28 L9 28 Q4 28 2 23 L0 8 Q1 3 7 0 Z" } }
                ShapePath { strokeWidth: 0; fillColor: bot.metalLight; PathSvg { path: "M6 0 L30 0 L25 5 L8 5 L2 10 L0 7 Z" } }
                ShapePath { strokeWidth: 0; fillColor: bot.metalShade; PathSvg { path: "M30 0 L37 7 L34 24 L29 28 L27 20 L29 9 L25 5 Z" } }
                ShapePath { strokeWidth: 0; fillColor: bot.paintShade; PathSvg { path: "M3 9 L9 6 L26 6 L30 10 L27 20 L9 20 L5 17 Z" } }
                ShapePath { strokeWidth: 0; fillColor: bot.paint; PathSvg { path: "M9 6 L20 6 L17 19 L9 20 L5 17 L3 9 Z" } }
                ShapePath { strokeWidth: 0.65; strokeColor: bot.seam; fillColor: "transparent"; PathSvg { path: "M8 23 L26 23 M7 3 L8 5 M30 22 L32 23" } }
            }
            // Recessed core with an illuminated diamond and a charge meter.
            Rectangle { x: 44; y: 49; width: 13; height: 13; radius: 4; color: bot.chassis; border.width: 1; border.color: bot.seam }
            Shape {
                x: 47; y: 51; width: 7; height: 9; preferredRendererType: Shape.CurveRenderer
                opacity: bot.animated ? 0.76 + Math.sin(bot.time * (bot.activity === "charge" ? 5 : 2)) * 0.18 : 1
                ShapePath { strokeWidth: 0; fillColor: bot.led; PathSvg { path: "M3.5 0 L7 4.5 L3.5 9 L0 4.5 Z" } }
                ShapePath { strokeWidth: 0; fillColor: bot.metalLight; PathSvg { path: "M3.5 0 L3.5 9 L0 4.5 Z" } }
            }
            Repeater {
                model: 3
                Rectangle { required property int index; x: 60; y: 49 + index * 3; width: 4; height: 1.1; radius: 0.5; color: bot.seam }
            }
            Rectangle { x: 43; y: 65; width: 15; height: 1.5; radius: 0.7; color: bot.chassis }
            Rectangle { x: 44; y: 65; width: bot.activity === "charge" ? 3 + (Math.sin(bot.time * 2) + 1) * 5 : 10; height: 1.5; radius: 0.7; color: bot.activity === "charge" ? bot.led : bot.paintShade }
            Repeater {
                model: 2
                Rectangle { required property int index; x: index ? 63 : 38; y: 63; width: 2; height: 2; radius: 1; color: bot.chassis; Rectangle { x: 0.5; y: 0.7; width: 1; height: 0.5; color: bot.metalShade } }
            }
            // Arms are real shoulder -> elbow -> wrist -> finger chains.
            Repeater {
                model: 2
                Item {
                    id: arm
                    required property int index
                    readonly property bool active: index === 1
                    readonly property real shoulderAngle: bot.interaction === "grabbed" ? (index ? 65 : -65) + Math.sin(bot.time*8)*4
                        : bot.interaction === "fall" ? (index ? -118 : 118)
                        : bot.interaction === "annoyed" ? (index ? 75 : -75)
                        : bot.interaction === "shake" ? Math.sin(bot.time*30)*(index ? -16 : 16)
                        : bot.flying ? (index ? -36 : 36) + Math.sin(bot.time * 3) * 3 : !active ? 6 - bot.stride * 20 + bot.beat * 18 - (bot.activity === "stretch" ? 115 : 0)
                        : bot.activity === "greet" ? -148 + Math.sin(bot.time * 7) * 13
                        : bot.activity === "catch" ? -115 + Math.sin(bot.time * 3) * 15
                        : bot.servicing ? -65 : bot.activity === "stretch" ? -145
                        : bot.activity === "charge" ? -63 : bot.dancing ? -45 + bot.beat * 30 : -6 + bot.stride * 20
                    x: index ? 68 : 21; y: 43; width: 12; height: 34
                    CompanionTween { id: shoulderTween; clock: bot.phase; targetValue: arm.shoulderAngle; enabled: bot.animated }
                    transform: Rotation { origin.x: 6; origin.y: 5; angle: shoulderTween.value }
                    Rectangle { x: 1; y: 0; width: 10; height: 11; radius: 4.5; color: bot.seam; border.width: 0.8; border.color: bot.edge }
                    Rectangle { x: 3.5; y: 2.5; width: 5; height: 5; radius: 2.5; color: bot.paintShade; border.width: 0.55; border.color: bot.metalShade }
                    Shape {
                        x: 1; y: 6; width: 10; height: 12; preferredRendererType: Shape.CurveRenderer
                        ShapePath { strokeWidth: 0.65; strokeColor: bot.edge; fillColor: bot.metal; PathSvg { path: "M1 0 L8 0 L10 3 L8 12 L2 12 L0 3 Z" } }
                        ShapePath { strokeWidth: 0; fillColor: bot.metalShade; PathSvg { path: "M8 0 L10 3 L8 12 L5 11 L6 3 Z" } }
                        ShapePath { strokeWidth: 0.8; strokeColor: bot.paint; fillColor: "transparent"; PathSvg { path: "M3 3 L3 8" } }
                    }
                    Item {
                        id: forearm
                        x: 1; y: 15; width: 11; height: 22
                        transform: Rotation { origin.x: 5; origin.y: 3; angle: ["grabbed","annoyed"].includes(bot.interaction) ? (arm.index ? 75 : -75) : arm.active && bot.servicing ? -88 + Math.sin(bot.time * 4) * 12 : arm.active && bot.activity === "greet" ? -12 : bot.dancing ? bot.beat * 20 : -8 }
                        Rectangle { x: 1; y: 0; width: 9; height: 7; radius: 3.5; color: bot.chassis; border.width: 0.6; border.color: bot.metalShade }
                        Rectangle { x: 3.5; y: 1.7; width: 4; height: 3.5; radius: 1.7; color: bot.seam }
                        Shape {
                            x: 0; y: 4; width: 11; height: 10; preferredRendererType: Shape.CurveRenderer
                            ShapePath { strokeWidth: 0.65; strokeColor: bot.edge; fillColor: bot.paint; PathSvg { path: "M1 0 L9 0 L11 3 L9 10 L2 10 L0 3 Z" } }
                            ShapePath { strokeWidth: 0; fillColor: bot.paintShade; PathSvg { path: "M9 0 L11 3 L9 10 L6 10 L7 2 Z" } }
                            ShapePath { strokeWidth: 0.65; strokeColor: bot.metalLight; fillColor: "transparent"; PathSvg { path: "M2 2 L5 2 M2 4 L5 4" } }
                        }
                        Rectangle { x: 3; y: 13; width: 5; height: 3; radius: 1; color: bot.chassis }
                        Rectangle { x: 1; y: 15; width: 9; height: 5; radius: 1.5; color: bot.metalShade; border.width: 0.65; border.color: bot.edge }
                        Rectangle { x: 3; y: 16; width: 5; height: 2; radius: 0.6; color: bot.paintShade }
                        Repeater {
                            model: 3
                            Rectangle { required property int index; x: 1.2 + index * 3; y: 19; width: 2.3; height: 4; radius: 0.8; color: bot.metal; border.width: 0.45; border.color: bot.edge }
                        }
                        Rectangle { x: -1; y: 15; width: 2.5; height: 5; radius: 1; rotation: 24; color: bot.metal; border.width: 0.5; border.color: bot.edge }
                    }
                }
            }
            // Ribbed neck and a large beveled head, separate from the body.
            Rectangle { x: 46; y: 35; width: 11; height: 9; radius: 2; color: bot.chassis; border.width: 0.7; border.color: bot.edge }
            Repeater { model: 2; Rectangle { required property int index; x: 47; y: 38 + index * 2.5; width: 9; height: 1; color: bot.metalShade } }
            Item {
                id: head
                x: 27; y: bot.sleeping ? 12 : 8; width: 49; height: 31
                scale: 1.08; transformOrigin: Item.Bottom
                transform: Rotation { origin.x: 24; origin.y: 30; angle: bot.sleeping ? 11 : bot.servicing ? -7 : ["look","balance"].includes(bot.activity) ? Math.sin(bot.time * 1.3) * 7 : bot.hovered ? -5 : bot.beat * 4 }
                Rectangle { x: 24; y: -4; width: 2; height: 6; radius: 1; color: bot.metalShade }
                Rectangle { x: 22.5; y: -7; width: 5; height: 4.5; radius: 2; color: bot.activity === "charge" ? bot.warm : bot.led; border.width: 0.65; border.color: bot.edge }
                Shape {
                    anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
                    ShapePath { strokeWidth: 0.85; strokeColor: bot.edge; fillColor: bot.metal; PathSvg { path: "M9 0 L39 0 Q45 0 48 7 L49 22 Q49 30 40 31 L9 31 Q0 31 0 23 L0 9 Q0 1 9 0 Z" } }
                    ShapePath { strokeWidth: 0; fillColor: bot.metalLight; PathSvg { path: "M9 0 L39 0 L41 4 L10 4 L4 9 L0 9 Q0 1 9 0 Z" } }
                    ShapePath { strokeWidth: 0; fillColor: bot.metalShade; PathSvg { path: "M39 0 Q45 0 48 7 L49 22 Q49 30 40 31 L39 26 L43 20 L42 8 L37 4 Z" } }
                    ShapePath { strokeWidth: 0; fillColor: bot.paintShade; PathSvg { path: "M0 22 L7 27 L39 26 L40 31 L9 31 Q0 31 0 23 Z" } }
                }
                // Side sensors and tiny service screws.
                Rectangle { x: -3; y: 10; width: 5; height: 12; radius: 2; color: bot.seam; border.width: 0.6; border.color: bot.edge }
                Rectangle { x: -2; y: 13; width: 2; height: 5; radius: 1; color: bot.warm }
                Rectangle { x: 47; y: 10; width: 4; height: 11; radius: 1.5; color: bot.seam; border.width: 0.6; border.color: bot.edge }
                Rectangle { x: 48; y: 12; width: 1; height: 6; radius: 0.5; color: bot.led }
                Rectangle { x: 5; y: 6; width: 38; height: 19; radius: 5; color: bot.chassis; border.width: 0.8; border.color: bot.seam }
                Rectangle { x: 7; y: 8; width: 34; height: 2; radius: 1; color: PolyTheme.Theme.withAlpha(bot.metalLight, 0.10) }
                Repeater {
                    model: 2
                    Item {
                        required property int index
                        x: (index ? 28 : 11) + bot.gaze; y: 10.5; width: 9; height: 10
                        Rectangle { width: 8.5; height: 9.5 * bot.blink; anchors.verticalCenter: parent.verticalCenter; radius: 4; color: bot.led; visible: !bot.cheerful || bot.blink < 0.5 }
                        Shape {
                            anchors.fill: parent; visible: bot.cheerful && bot.blink > 0.5
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath { strokeWidth: 1.7; capStyle: ShapePath.RoundCap; strokeColor: bot.led; fillColor: "transparent"; PathSvg { path: "M1 6.5 Q4.5 0 8 6.5" } }
                        }
                        Rectangle { x: 1.2; y: 1.2; width: 2; height: 2; radius: 0.7; color: bot.metalLight; visible: bot.blink > 0.5 && !bot.cheerful }
                    }
                }
                Repeater {
                    model: 2
                    Rectangle { required property int index; x: index ? 35 : 9; y: 21; width: 4; height: 1.6; radius: 0.8; color: bot.warm; opacity: bot.cheerful ? 0.65 : 0.27 }
                }
                Shape {
                    x: 20; y: 20; width: 9; height: 4; preferredRendererType: Shape.CurveRenderer
                    ShapePath { strokeWidth: 0.9; strokeColor: bot.led; fillColor: "transparent"; PathSvg { path: ["grabbed","fall"].includes(bot.interaction) ? "M3 0 Q1 0 1 2 Q1 4 4 4 Q7 4 7 2 Q7 0 3 0 Z" : bot.interaction === "annoyed" ? "M2 2 L7 2" : bot.sleeping ? "M1 2 L7 2" : bot.cheerful ? "M1 0 Q4.5 5 8 0" : "M2 1 Q4.5 3.5 7 1" } }
                }
                Repeater { model: 2; Rectangle { required property int index; x: index ? 39 : 8; y: 27; width: 2; height: 1.5; radius: 0.7; color: bot.chassis } }
            }
        }
        // Prop belongs to the same body clock and reacts only to actual charging.
        Shape {
            visible: bot.activity === "charge"
            x: 77; y: 57; width: 18; height: 29; preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeWidth: 1.6; strokeColor: bot.warm; fillColor: "transparent"; PathSvg { path: "M0 0 Q16 4 8 13 Q1 23 16 24" } }
            ShapePath { strokeWidth: 0.65; strokeColor: bot.edge; fillColor: bot.metal; PathSvg { path: "M12 20 L18 20 L18 27 L12 27 Z M18 21 L21 21 L21 23 L18 23 Z M18 25 L21 25 L21 27 L18 27 Z" } }
        }
        Shape {
            visible: bot.activity === "catch"
            x: 82; y: 6 + Math.sin(bot.time * 3) * 3; width: 10; height: 14; rotation: bot.time * 22
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeWidth: 0.6; strokeColor: bot.edge; fillColor: bot.warm; PathSvg { path: "M5 0 L10 7 L5 14 L0 7 Z" } }
            ShapePath { strokeWidth: 0; fillColor: bot.metalLight; PathSvg { path: "M5 0 L5 14 L0 7 Z" } }
        }
        Text { x: 79; y: 9; text: bot.sleeping ? "z" : bot.dancing ? "♪" : ""; color: bot.led; font.family: Session.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold }
    }
}
