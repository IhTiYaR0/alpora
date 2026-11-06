import QtQuick
import ".."

// Sample a retargetable tween from the companion's existing clock. Avoid costly
// per-frame NumberAnimation restarts and keep joint updates on the travel clock.
// This object owns no timer or animation driver.
QtObject {
    id: tween
    required property real clock
    required property real targetValue
    property int duration: 180
    property bool easeInOut: true
    property bool enabled: true
    property bool initialized: false
    property real startTime: 0
    property real from: 0
    property real destination: 0
    readonly property real value: {
        if (!initialized || !enabled || duration <= 0) return targetValue;
        // CompanionLogic bounds its phase to one hour, including during flight.
        const elapsed = (clock - startTime + 3600) % 3600;
        const t = Math.max(0, Math.min(1, elapsed * 1000 / duration));
        const progress = !easeInOut ? t : t < .5 ? 2*t*t : 1-Math.pow(-2*t+2,2)/2;
        return from + (destination-from)*progress;
    }
    function snap(): void {
        from = targetValue; destination = targetValue; startTime = clock;
    }
    onTargetValueChanged: {
        if (!initialized) return;
        const current = value;
        from = current; destination = targetValue; startTime = clock;
    }
    onEnabledChanged: if (initialized) snap()
    Component.onCompleted: { snap(); initialized = true; }
}
