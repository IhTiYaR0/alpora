pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root
    readonly property var playerModel: Mpris.players
    readonly property var players: (playerModel && playerModel.values) ? playerModel.values.filter(item => !!item) : []
    property string selectedName: ""
    readonly property var player: players.length ? (players.find(item => item && item.dbusName === selectedName) || players.find(item => item && item.isPlaying) || players[0]) : null
    function select(name: string): void { selectedName = name; }
    function formatTime(seconds: real): string {
        const value = Math.max(0, Math.floor(seconds || 0));
        const hours = Math.floor(value / 3600);
        return (hours ? hours + ":" : "") + (hours ? String(Math.floor(value / 60) % 60).padStart(2, "0") : Math.floor(value / 60)) + ":" + String(value % 60).padStart(2, "0");
    }
}
