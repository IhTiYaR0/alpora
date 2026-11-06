# Quick settings validation — 2026-10-19

Arch Linux, Hyprland 0.56.2 with Lua configuration, Quickshell 0.3.2, Qt 6.12.0.
Physical monitor eDP-1, 1920×1080 at scale 1; the monitor configuration was preserved.
Bar: 40 logical px, top offset 12; reserved area 60. Popup body: 390×516 logical px.

## Verified

- `scripts/check`: 18 automated tests pass; qmllint has zero warnings.
- Clean service restart reports ready with empty application/desktop error fields.
- Native SVG/QML geometry, mountain header, facets, three sliders and utility buttons
  render on the live desktop. The approved reference is retained separately.
- Real mouse clicks adjust speaker volume, microphone gain and backlight brightness.
- Real mouse clicks mute/unmute the microphone, toggle Mako DND, enable/disable
  Night Light, and select output/input pages showing actual PipeWire devices.
- Night Light is restored across a full service restart. Hyprsunset accepts 4500 K
  and the identity reset; its temperature query retains the previous configured
  temperature even after identity, so that query alone is not an enabled-state check.
- Bluetooth toggles on and back off, including rfkill unblock/block handling. Initially
  both platform and adapter software blocks were set; direct adapter writes failed.
- Wi-Fi details show the connected network and signal without changing the connection.
- Settings opens the internal settings page. Escape, Tab followed by Escape, and an
  outside mouse click dismiss the popup. A transparent modal backdrop handles outside
  clicks consistently with the popup's exclusive keyboard focus.
- Original radio state, DND, Night Light, volume, mute state, brightness, workspace and
  cursor position were restored after interaction checks.
- No Hyprland resolution/scale setting or terminal hotkey was changed.

## Limits and follow-up

- New secured Wi-Fi authentication, enterprise Nmtui setup and pairing new Bluetooth
  hardware need tests with suitable networks/devices. New Bluetooth pairing currently
  uses Bluetoothctl in a terminal, including PIN/agent support.
- Destructive power actions were not executed; the UI requires a separate confirmation.
  Locking the user's active session was not performed during automated interaction.
- Multiple monitors, new fractional-scale layouts, next login and suspend/resume remain
  hardware checks. The old foundation benchmark is not a measurement of this revision.
- Qt's Wayland text-input backend emits `disableSurface ... but ... is focused` warnings
  around focus transitions. They do not correspond to a shell exception; keyboard and
  outside-click interaction passed. Do not describe this as a warning-free runtime.

The local live preview is saved outside the repository under
`~/.local/state/poly-shell/previews/quick-settings-live.png` because it includes the
user's actual Wi-Fi name. Nothing was uploaded.
