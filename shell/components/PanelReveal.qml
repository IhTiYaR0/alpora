import QtQuick
import ".."

// Match Hyprland's polyPanel fade exactly; no movement or scaling.
Item {
    id: effect
    required property Item target
    required property PanelMotion motion
    enabled: false
    StateGroup {
        state: effect.motion.opened ? "open" : "closed"
        states: [
            State { name: "open"; PropertyChanges { effect.target.opacity: 1 } },
            State { name: "closed"; PropertyChanges { effect.target.opacity: 0 } }
        ]
        transitions: [
            Transition {
                to: "open"
                OpacityAnimator {
                    target: effect.target; duration: effect.motion.openDuration
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.panelCurve
                }
            },
            Transition {
                to: "closed"
                OpacityAnimator {
                    target: effect.target; duration: effect.motion.closeDuration
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.panelCurve
                }
            }
        ]
    }
}
