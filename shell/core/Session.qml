pragma Singleton

import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth
import "../logic/StatusLogic.js" as StatusLogic
import "../logic/AppearanceCatalog.js" as AppearanceCatalog

Singleton {
    id: root

    property bool loaded: false
    property string error: ""
    property var snapshot: ({})
    readonly property string mode: snapshot.mode || "work"
    readonly property var profile: snapshot.profile || ({})
    readonly property var settings: snapshot.settings || ({})
    readonly property var appearance: snapshot.appearance || ({})
    readonly property var visual: AppearanceCatalog.resolve(snapshot.visual, settings.bar)
    readonly property var palette: TimelineState.palette || appearance.palette || profile.palette || ({})
    readonly property color background: palette.background || "#181f27"
    readonly property color surface: palette.surface || "#26333d"
    readonly property color foreground: palette.text || "#edf2f4"
    readonly property color muted: palette.muted || "#a9bac5"
    readonly property color accent: palette.accent || "#a8d5bc"
    readonly property int motionMs: settings.reducedMotion ? 0 : (profile.motionMs || 0)
    readonly property string controller: Quickshell.env("POLY_SHELL_CTL") || "poly-shell"
    readonly property bool switching: modeWriter.running

    FontLoader {
        id: interFont
        source: Quickshell.env("POLY_SHELL_ASSETS") ? ("file://" + Quickshell.env("POLY_SHELL_ASSETS") + "/fonts/Inter-Variable.ttf") : ""
    }
    FontLoader {
        id: outfitFont
        source: Quickshell.env("POLY_SHELL_ASSETS") ? ("file://" + Quickshell.env("POLY_SHELL_ASSETS") + "/fonts/Outfit-Variable.ttf") : ""
    }
    FontLoader {
        id: monoFont
        source: Quickshell.env("POLY_SHELL_ASSETS") ? ("file://" + Quickshell.env("POLY_SHELL_ASSETS") + "/fonts/JetBrainsMono-Variable.ttf") : ""
    }
    FontLoader {
        id: nerdFont
        source: Quickshell.env("POLY_SHELL_ASSETS") ? ("file://" + Quickshell.env("POLY_SHELL_ASSETS") + "/fonts/SymbolsNerdFont-Regular.ttf") : ""
    }

    readonly property string defaultFontFamily: interFont.status === FontLoader.Ready ? interFont.name : "Inter, Noto Sans, sans-serif"
    readonly property string fontFamily: (settings.bar && settings.bar.fontFamily && settings.bar.fontFamily !== "Noto Sans") ? settings.bar.fontFamily : defaultFontFamily
    readonly property string displayFontFamily: outfitFont.status === FontLoader.Ready ? outfitFont.name : "Outfit, Inter, sans-serif"
    readonly property string monoFontFamily: monoFont.status === FontLoader.Ready ? monoFont.name : "JetBrains Mono, monospace"
    readonly property string symbolFontFamily: nerdFont.status === FontLoader.Ready ? nerdFont.name : "Symbols Nerd Font, monospace"
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var microphone: source && source.ready ? source.audio : null
    readonly property var pipewireNodes: Pipewire.nodes
    readonly property var outputs: (pipewireNodes && pipewireNodes.values) ? pipewireNodes.values.filter(node => node && !node.isStream && node.audio && node.isSink) : []
    readonly property var inputs: (pipewireNodes && pipewireNodes.values) ? pipewireNodes.values.filter(node => node && !node.isStream && node.audio && !node.isSink) : []
    readonly property var audioStreams: (pipewireNodes && pipewireNodes.values) ? pipewireNodes.values.filter(node => node && node.isStream && node.audio && node.isSink) : []
    readonly property var sink: Pipewire.defaultAudioSink
    property string lastSinkName: ""
    onSinkChanged: {
        const nextName = sink ? (sink.description || sink.nickname || sink.name || "") : "";
        if (lastSinkName && lastSinkName !== nextName) {
            const wasHeadphone = /headphone|headset|earphone|bluez|airpod|buds/i.test(lastSinkName);
            const isSpeaker = !nextName || /speaker|built-in|internal|analog-stereo/i.test(nextName);
            if (wasHeadphone && isSpeaker) {
                Quickshell.execDetached(["playerctl", "pause"]);
            }
        }
        lastSinkName = nextName;
    }
    readonly property var hardware: snapshot.hardware || ({deviceClass: "desktop", isLaptop: false, batteryAvailable: false, brightnessAvailable: false})
    readonly property bool isLaptop: hardware.isLaptop === true
    readonly property bool isDesktop: !isLaptop
    readonly property bool brightnessAvailable: hardware.brightnessAvailable !== false
    readonly property var battery: UPower.displayDevice
    readonly property bool batteryPresent: isLaptop && hardware.batteryAvailable !== false && !!battery && battery.ready && battery.isLaptopBattery
    readonly property bool batteryCharging: batteryPresent && battery.state === UPowerDeviceState.Charging
    onBatteryChargingChanged: if (batteryCharging) AudioFeedback.playTock()
    readonly property bool onBattery: UPower.onBattery
    readonly property string batteryStatus: !batteryPresent ? I18n.tr("power.ac")
        : batteryCharging ? I18n.tr("power.charging")
        : battery.state === UPowerDeviceState.FullyCharged ? I18n.tr("power.full")
        : !onBattery ? I18n.tr("power.plugged_idle")
        : I18n.tr("power.battery")
    readonly property string batteryDescription: (batteryPresent ? Math.round(battery.percentage * 100) + "% · " : "") + batteryStatus
    readonly property int focusedWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
    readonly property bool quickSettingsOpen: BarState.selection.name === "quick-settings"
    readonly property string quickSettingsScreen: quickSettingsOpen ? BarState.selection.screen : ""
    readonly property var networkDevices: Networking.devices
    readonly property var wifiDevice: (networkDevices && networkDevices.values) ? (
        networkDevices.values.find(device => device && device.type === DeviceType.Wifi && device.connected)
        || networkDevices.values.find(device => device && device.type === DeviceType.Wifi && device.state === ConnectionState.Connecting)
        || networkDevices.values.find(device => device && device.type === DeviceType.Wifi) || null
    ) : null
    readonly property var wifiNetwork: (wifiDevice && wifiDevice.networks && wifiDevice.networks.values) ? (wifiDevice.networks.values.find(network => network && network.connected) || null) : null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property var wiredDevice: (networkDevices && networkDevices.values) ? (networkDevices.values.find(device => device && device.type === DeviceType.Wired && device.connected) || null) : null
    readonly property var wifiObservation: ({
        wifiAvailable: !!wifiDevice, hardwareEnabled: Networking.wifiHardwareEnabled,
        wifiEnabled: wifiEnabled, connected: !!wifiDevice && wifiDevice.connected,
        connecting: !!wifiDevice && wifiDevice.state === ConnectionState.Connecting,
        strength: wifiNetwork ? wifiNetwork.signalStrength : 0,
        name: wifiNetwork ? wifiNetwork.name : "",
        wiredConnected: !!wiredDevice, connectivity: NetworkConnectivity.toString(Networking.connectivity)
    })
    readonly property var wifiStatus: StatusLogic.wifiStatus(wifiObservation)
    readonly property var networkStatus: StatusLogic.network(wifiObservation)
    readonly property var audioStatus: StatusLogic.audio(!!audio, audio ? audio.muted : false, audio ? audio.volume : 0)
    readonly property var bluetoothService: Bluetooth
    readonly property var bluetoothAdapter: bluetoothService ? bluetoothService.defaultAdapter : null
    readonly property bool bluetoothEnabled: bluetoothAdapter ? bluetoothAdapter.enabled : false
    readonly property var connectedBluetooth: (bluetoothEnabled && bluetoothAdapter && bluetoothAdapter.devices && bluetoothAdapter.devices.values) ? bluetoothAdapter.devices.values.filter(device => device && device.connected) : []
    readonly property string bluetoothDescription: !bluetoothAdapter ? I18n.tr("bluetooth.unavailable")
        : !bluetoothEnabled ? I18n.tr("bluetooth.off")
        : connectedBluetooth.length ? connectedBluetooth.map(device => device.name).join(", ")
        : I18n.tr("bluetooth.no_devices")

    // One subscription per shell, shared by every monitor. No periodic subprocesses.
    PwObjectTracker {
        objects: root.outputs.concat(root.inputs).concat(root.audioStreams)
    }

    FileView {
        id: sessionFile
        path: Quickshell.env("POLY_SHELL_STATE") || ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const next = JSON.parse(text());
                if (next.schemaVersion !== 1 || !next.profile || !next.settings)
                    throw new Error("Unsupported session data");
                root.snapshot = next;
                root.loaded = true;
                root.error = "";
            } catch (failure) {
                root.error = String(failure);
                console.error("Session data kept at last valid state:", root.error);
            }
        }
        onLoadFailed: {
            root.error = "Cannot load session data";
            console.error(root.error, path);
        }
    }

    Process {
        id: modeWriter
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    root.error = text.trim();
                    console.error(root.error);
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0)
                root.error = "Mode switch failed; see poly-shell logs";
        }
    }

    function setMode(next: string): void {
        if (modeWriter.running || !["work", "vibe", "toggle"].includes(next))
            return;
        root.error = "";
        modeWriter.command = [root.controller, "mode", next];
        modeWriter.running = true;
    }

    function launch(name: string): void {
        const command = settings.apps ? settings.apps[name] : null;
        if (command && command.length)
            Quickshell.execDetached(command);
    }

    function focusWorkspace(workspaceId: int): void {
        if (workspaceId < 1 || workspaceId > 10)
            return;
        Hyprland.dispatch(Hyprland.usingLua
            ? "hl.dsp.focus({ workspace = " + workspaceId + " })"
            : "workspace " + workspaceId);
    }

    function toggleQuickSettings(screenName: string): void {
        BarState.toggle("quick-settings", screenName);
        if (root.quickSettingsOpen)
            Desktop.request("status", "");
    }

    function selectOutput(node: var): void { Pipewire.preferredDefaultAudioSink = node; }
    function selectInput(node: var): void { Pipewire.preferredDefaultAudioSource = node; }

    function closeQuickSettings(): void { BarState.closeQuickSettings(); }
    function toggleWifi(): void { Networking.wifiEnabled = !Networking.wifiEnabled; }
    function toggleBluetooth(): void {
        if (root.bluetoothAdapter)
            Desktop.request("bluetooth", root.bluetoothEnabled ? "off" : "on");
    }
}
