# Power profiles and airplane mode — 2026-10-19

Quick settings adds a power-profile chooser and airplane toggle. Profiles are read
from powerprofilesctl; unavailable services/profiles are disabled. The open popup
refreshes state, serializes changes and keeps action errors visible.

Airplane mode saves the rfkill software blocks, NM Wi-Fi/WWAN flags and Bluetooth
power before disabling radios. Off restores them. Failed application attempts roll
back; a failed recovery keeps airplane-restore.json for another recovery request.
The tile offers recovery when a saved transaction remains partially applied.
Hardware radio blocks are reported and require the physical switch/key.

Validation: 30 tests and QML lint pass. All three available profiles were applied
through the running shell controller and the original profile was restored. A real
on/off airplane cycle blocked every rfkill device, restored original NM flags and
rfkill blocks, left previously disabled Bluetooth off and reconnected Wi-Fi.
The profile chooser was opened by clicking its disclosure button and inspected.
Multiple physical adapters/hotplug remain hardware scenarios; unit coverage checks
reused device ids, rollback and retained recovery state. Native Qt Wayland focus
warnings from the existing session remain unrelated to these controls.
