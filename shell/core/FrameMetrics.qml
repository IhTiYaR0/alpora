pragma Singleton
import QtQuick
import ".."
import Quickshell

// Opt-in GUI animation-driver timing, not a claim about compositor presentation.
// Completely stopped outside an explicit diagnostic capture.
Singleton {
    id: metrics
    property var intervals: []
    property bool capturing: false
    function start(): void { capturing = false; intervals = []; capturing = true; timeout.restart(); }
    function finish(): string {
        capturing = false;
        timeout.stop();
        const values = intervals.slice().sort((a, b) => a - b);
        const quantile = p => values.length ? values[Math.min(values.length - 1, Math.floor((values.length - 1) * p))] : 0;
        return JSON.stringify({ samples: values.length, medianMs: quantile(0.5), p95Ms: quantile(0.95), maxMs: quantile(1), over25ms: values.filter(v => v > 25).length, over50ms: values.filter(v => v > 50).length });
    }
    FrameAnimation {
        id: sampler
        running: metrics.capturing
        onTriggered: {
            if (currentFrame > 1 && metrics.intervals.length < 10000)
                metrics.intervals.push(frameTime * 1000);
        }
    }
    Timer { id: timeout; interval: 15000; onTriggered: metrics.capturing = false }
}
