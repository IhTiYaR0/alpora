pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    property string targetScreen: ""

    function open(screen: string): void {
        targetScreen = screen || (Quickshell.screens.length ? Quickshell.screens[0].name : "");
        active = true;
    }

    function close(): void {
        active = false;
    }

    function capture(x: int, y: int, w: int, h: int, saveToFile: bool): void {
        close();
        if (w <= 0 || h <= 0) return;
        const geo = x + "," + y + " " + w + "x" + h;
        if (saveToFile) {
            saveWorker.geo = geo;
            saveWorker.running = true;
        } else {
            copyWorker.geo = geo;
            copyWorker.running = true;
        }
    }

    Process {
        id: copyWorker
        property string geo: ""
        command: ["bash", "-c", "grim -g '" + geo + "' - | wl-copy --type image/png && notify-send 'ALPORA' 'Screenshot copied to clipboard'"]
    }

    Process {
        id: saveWorker
        property string geo: ""
        command: ["bash", "-c", "DIR=\"$(xdg-user-dir PICTURES)/Screenshots\"; mkdir -p \"$DIR\"; FILE=\"$DIR/ALPORA-$(date +%Y%m%d-%H%M%S).png\"; grim -g '" + geo + "' \"$FILE\" && wl-copy --type image/png < \"$FILE\" && notify-send 'ALPORA' \"Screenshot saved: $FILE\""]
    }
}
