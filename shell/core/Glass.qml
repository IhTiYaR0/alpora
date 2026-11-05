pragma Singleton
import QtQuick
import ".."

QtObject {
    // Only the material is translucent. Text, icons and focus rings stay crisp.
    readonly property color barTop: materialTop(Session.visual.barOpacity)
    readonly property color barBottom: materialBottom(Session.visual.barOpacity)
    readonly property color panelTop: materialTop(Session.visual.panelOpacity)
    readonly property color panelBottom: materialBottom(Session.visual.panelOpacity)
    readonly property color launcherTop: materialTop(Session.visual.launcherOpacity)
    readonly property color launcherBottom: materialBottom(Session.visual.launcherOpacity)
    function materialTop(percent: real): color { return tint(Session.surface, percent / 100); }
    function materialBottom(percent: real): color { return tint(Session.background, percent / 100); }
    function gradientAlpha(percent: real, falloff: real): real {
        const alpha = percent / 100;
        return Math.max(0, alpha - (1 - alpha) * falloff);
    }
    function tint(value: color, alpha: real): color {
        return Qt.rgba(value.r, value.g, value.b, alpha);
    }
}
