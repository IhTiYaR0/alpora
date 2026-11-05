import QtQuick
import ".."

Item {
    id: root
    property real phase: 0
    property real progress: 0
    property bool hasTrack: false
    property bool playing: false
    property bool animated: true
    property real activity: playing ? 1 : 0
    Behavior on activity { NumberAnimation { duration: root.animated ? 400 : 0; easing.type: Easing.OutCubic } }
    property color playedColor: Session.accent
    property color remainingColor: Session.muted
    function waveY(fraction: real): real {
        const envelope = Math.pow(Math.max(0, Math.sin(Math.PI * fraction)), 0.65);
        const amplitude = hasTrack ? 2 + 3 * activity : 0;
        return height / 2 + envelope * amplitude * (
            Math.sin(fraction * Math.PI * 16 - phase * 1.8) * 0.82
            + Math.sin(fraction * Math.PI * 24 - phase * 1.2) * 0.18);
    }
    onPhaseChanged: drawing.requestPaint()
    onProgressChanged: drawing.requestPaint()
    onHasTrackChanged: drawing.requestPaint()
    onPlayingChanged: drawing.requestPaint()
    onActivityChanged: drawing.requestPaint()
    onPlayedColorChanged: drawing.requestPaint()
    onRemainingColorChanged: drawing.requestPaint()
    Canvas {
        id: drawing
        anchors.fill: parent
        // Paint in item coordinates so the thin baseline aligns with the seek handle.
        canvasSize: Qt.size(width, height)
        onCanvasSizeChanged: requestPaint()
        onPaint: {
            if (width <= 0 || height <= 0) return;
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, canvasSize.width, canvasSize.height);
            ctx.scale(canvasSize.width / width, canvasSize.height / height);
            ctx.lineWidth = 1.4; ctx.lineCap = "round"; ctx.lineJoin = "round";
            ctx.beginPath();
            for (let x = 1; x <= width - 1; x += 2) {
                const y = root.waveY(x / width);
                if (x === 1) ctx.moveTo(x, y); else ctx.lineTo(x, y);
            }
            ctx.globalAlpha = 0.32; ctx.strokeStyle = root.remainingColor; ctx.stroke();
            ctx.save();
            ctx.beginPath(); ctx.rect(0, 0, Math.max(0, Math.min(1, root.progress)) * width, height); ctx.clip();
            ctx.beginPath();
            for (let x = 1; x <= width - 1; x += 2) {
                const y = root.waveY(x / width);
                if (x === 1) ctx.moveTo(x, y); else ctx.lineTo(x, y);
            }
            ctx.globalAlpha = 1; ctx.strokeStyle = root.playedColor; ctx.stroke();
            ctx.restore();
        }
    }
}
