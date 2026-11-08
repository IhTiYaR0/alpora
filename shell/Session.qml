pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth
import "StatusLogic.js" as StatusLogic
import "AppearanceCatalog.js" as AppearanceCatalog
import "AppLaunch.js" as AppLaunch

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
    readonly property string fontFamily: settings.bar ? settings.bar.fontFamily : "Noto Sans"
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var microphone: source && source.ready ? source.audio : null
    readonly property var pipewireNodes: Pipewire.nodes
    readonly property var outputs: pipewireNodes.values.filter(node => !node.isStream && node.audio && node.isSink)
    readonly property var inputs: pipewireNodes.values.filter(node => !node.isStream && node.audio && !node.isSink)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink && sink.ready ? sink.audio : null
    readonly property var battery: UPower.displayDevice
    readonly property bool batteryPresent: !!battery && battery.ready && battery.isLaptopBattery
    readonly property bool batteryCharging: batteryPresent && battery.state === UPowerDeviceState.Charging
    readonly property bool onBattery: UPower.onBattery
    readonly property string batteryStatus: !batteryPresent ? "Питание от сети"
        : batteryCharging ? "Заряжается"
        : battery.state === UPowerDeviceState.FullyCharged ? "Полностью заряжен"
        : !onBattery ? "Подключён к сети · зарядка приостановлена"
        : "Работа от батареи"
    readonly property string batteryDescription: (batteryPresent ? Math.round(battery.percentage * 100) + "% · " : "") + batteryStatus
    readonly property int focusedWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
    readonly property bool quickSettingsOpen: BarState.selection.name === "quick-settings"
    readonly property string quickSettingsScreen: quickSettingsOpen ? BarState.selection.screen : ""
    readonly property var networkDevices: Networking.devices
    readonly property var wifiDevice: networkDevices.values.find(device => device.type === DeviceType.Wifi && device.connected)
        || networkDevices.values.find(device => device.type === DeviceType.Wifi && device.state === ConnectionState.Connecting)
        || networkDevices.values.find(device => device.type === DeviceType.Wifi) || null
    readonly property var wifiNetwork: wifiDevice ? wifiDevice.networks.values.find(network => network.connected) || null : null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property var wiredDevice: networkDevices.values.find(device => device.type === DeviceType.Wired && device.connected) || null
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
    readonly property var bluetoothAdapter: bluetoothService.defaultAdapter
    readonly property bool bluetoothEnabled: bluetoothAdapter ? bluetoothAdapter.enabled : false
    readonly property var connectedBluetooth: bluetoothEnabled ? bluetoothAdapter.devices.values.filter(device => device.connected) : []
    readonly property string bluetoothDescription: !bluetoothAdapter ? "Bluetooth недоступен"
        : !bluetoothEnabled ? "Bluetooth выключен"
        : connectedBluetooth.length ? connectedBluetooth.map(device => device.name).join(", ")
        : "Bluetooth · Нет подключённых устройств"

    // One subscription per shell, shared by every monitor. No periodic subprocesses.
    PwObjectTracker {
        objects: root.outputs.concat(root.inputs)
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
            launchCommand("", command, "", appSlices[name] || "");
    }

    // Each app gets its own transient service in app.slice, so restarting or
    // OOM-killing the shell leaves it running. Must not contain "-".
    readonly property string appLauncherName: "alpora"
    // The lock screen is as essential as the shell, so it runs in session.slice
    // like GNOME's and KDE's; every other app stays in app.slice. Not a setting.
    readonly property var appSlices: ({lock: "session.slice"})

    function launchCommand(appId: string, argv: var, workingDirectory: string, slice: string): void {
        if (!argv || !argv.length)
            return;
        const random = Math.floor(Math.random() * 0x100000000).toString(16).padStart(8, "0");
        Quickshell.execDetached(AppLaunch.command(appLauncherName, appId, argv, random, workingDirectory, slice));
    }

    // Matches what Quickshell 0.3.2 runs for a desktop entry (command and Path=; field
    // codes dropped, Terminal= ignored), but started in the app's own unit.
    function launchEntry(entry: var): void {
        if (entry)
            launchCommand(entry.id, entry.command, entry.workingDirectory, "");
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
