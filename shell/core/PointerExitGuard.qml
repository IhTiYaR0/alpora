import QtQuick
import ".."
import Quickshell.Io

Process {
    id: guard
    required property bool enabledForClose
    required property bool pointerInside
    required property var barWindow
    required property Item sourceItem
    required property point screenOffset
    required property rect panelBounds
    signal outside()
    // A cursor query can finish after the user switched or reopened a panel.
    // Its result belongs to the request's owner, never to the new selection.
    property string ownerToken: ""
    property int generation: 0
    property int queryGeneration: -1
    onOwnerTokenChanged: generation+=1
    onEnabledForCloseChanged: generation+=1

    function check(): void {
        if (enabledForClose && !pointerInside && !running) {queryGeneration=generation;running=true;}
    }

    onExited: {
        // If the new owner also requested an outside check while this process
        // was busy, sample again instead of using the previous owner's cursor.
        if (queryGeneration!==generation && enabledForClose && !pointerInside)
            Qt.callLater(guard.check);
    }
    command: ["hyprctl", "-j", "cursorpos"]
    stdout: StdioCollector {
        onStreamFinished: {
            if (guard.queryGeneration!==guard.generation || !guard.enabledForClose || guard.pointerInside) return;
            try {
                const cursor = JSON.parse(text);
                const x = cursor.x - guard.screenOffset.x;
                const y = cursor.y - guard.screenOffset.y;
                const source = guard.barWindow.buttonBounds(guard.sourceItem);
                const panel = guard.panelBounds;
                const onSource = x >= source.x && x <= source.x + source.width
                    && y >= source.y && y <= panel.y;
                const onPanel = x >= panel.x && x <= panel.x + panel.width
                    && y >= panel.y - 10 && y <= panel.y + panel.height;
                if (!onSource && !onPanel) guard.outside();
            } catch (failure) {
                console.warn("Cannot confirm panel pointer exit:", String(failure));
            }
        }
    }
}
