# Poly Shell

A working-name project for a responsive Hyprland desktop with Work / Vibe profiles.
The current preview implements a compact low-poly panel and practical quick settings.

## Current preview

- Rounded 40 px top bar with an angled mountain clock inset, occupied-workspace dots,
  live keyboard layout and notifications/history from Mako.
- Real StatusNotifier tray: two inline items, overflow, activation, scrolling and
  native context menus. Empty trays add no placeholder application icons.
- Click the clock for My Day: calendar, local events and daily tasks, focus timer,
  autosaved note, Files and Terminal shortcuts. Add records using the + buttons.
  The timer supports 25/50/5 minutes, pause/resume/reset and survives shell restarts.
- Shared Wings reveal (Motion Lab 03), with 520ms opening / 220ms closing,
  rounded GPU aperture and stationary text; native controls render at rest.
- Separate animated quick settings popup, with a faceted mountain header and sage,
  peach and blue-green accents. It respects the compositor's logical pixel scale;
  no screen-width multiplier or monitor configuration changes are applied.
- Three controls: output volume, backlight brightness and microphone gain. Speaker
  and microphone icons mute/unmute; arrows/device labels open device selection.
- Wi-Fi radio and network selection, including a password form for WPA personal
  networks; Bluetooth radio handles software rfkill blocks and lists paired devices.
- Three power-profiles-daemon modes (where supported) and airplane mode with saved
  radio-state restoration, including an originally disabled Bluetooth adapter.
- Night Light at 4500 K, Mako Do Not Disturb, lock and confirmed restart/power-off.
- Sound opens Pavucontrol; Settings opens the separate Poly settings application.
- Work / Vibe profiles remain available through the CLI; no mode switch is shown.
- Named Quickshell config, a user systemd service, diagnostics and journal logs.
- Explicit, reversible Waybar handover after the shell reports readiness.

Night Light preference is restored when the shell starts. Brightness and notification
state refresh while the menu is open, with no closed-menu polling. Wi-Fi enterprise
setup opens Nmtui. New Bluetooth pairing opens Bluetoothctl in the configured terminal
so PIN/agent interaction is supported; an integrated pairing dialog is future work.

The static wallpaper is `../assets/wallpapers/alpine-dawn.png`. The approved design is
`../assets/reference/quick-settings-approved.png`; see [art provenance](artwork.md).
The live interface displays actual devices, charge and levels rather than mockup data.

## Requirements

See the [complete program and service inventory](programs.md), including file
manager, terminal, runtime dependencies and development-only tools.

Start with Arch Linux, Hyprland 0.56.x and Quickshell 0.3.2. Keep Arch fully updated:
installing a newer Quickshell with older Qt libraries can prevent it from loading.

Runtime: `quickshell`, `python`, `hyprland`, `kitty` or `foot`, `fuzzel`, `hyprlock`,
PipeWire / WirePlumber, UPower and a user systemd session. Quick settings additionally
uses NetworkManager (`nmcli`, `nmtui`), BlueZ (`bluetoothctl`), `rfkill`, `brightnessctl`,
`hyprsunset`, `mako`, `pavucontrol`, `power-profiles-daemon`, and `swaybg` for the static wallpaper. The session
needs access to its backlight and `/dev/rfkill` (normally provided by logind/udev).
Keep the current Waybar, hypridle, polkit agent and portals during development.

Development: Git, Node.js and the Qt tools in `/usr/lib/qt6/bin/`. Install
`python-pillow` for wallpaper import and Timeline image preparation. No npm build,
C++ compilation or external font/icon downloads are needed.

## Install and check

```sh
./bin/poly-shell doctor
./scripts/check
./bin/poly-shell install
```

`install` adds a launcher at `~/.local/bin/poly-shell`, links this checkout to
`$XDG_CONFIG_HOME/quickshell/poly-shell`, and writes a user systemd service.
It does not install packages, enable a display manager or change your Hyprland config.
Existing unrelated files at the install paths are not overwritten.

Ensure `~/.local/bin` is on PATH or use that full path in commands below.

## Run and activate

```sh
poly-shell run                 # Foreground development; Ctrl+C stops it
poly-shell start               # Managed preview; Waybar is still present
poly-shell logs
poly-shell stop
poly-shell activate            # Replace the current Waybar after readiness
poly-shell deactivate          # Restore the previous Waybar launch
```

Activation currently supports the existing setup: exactly one `waybar ...` line in
`$XDG_CONFIG_HOME/hypr/autostart.sh`. It creates a timestamped backup, wraps that line
with a startup fallback, and stops the user's running Waybar instances. Other autostart
commands and Hyprland keybindings are untouched. If there is no matching setup,
activation refuses to rewrite the file. The project is not a general dotfiles installer yet.

The service is started by the Hyprland autostart hook, not globally enabled for other
desktop sessions. It restarts after a crash, with a limit of three attempts in 30 seconds.
The fallback restores Waybar if the shell fails during login. After a later persistent
runtime failure, use `poly-shell deactivate` to restore Waybar.

## Workspace overview

**Three-finger swipe up** or **Super+Tab** opens a themed overview of workspaces
1–10 and other existing desks; a three-finger swipe down closes it. The overview
tracks finger travel in both directions, stays partially open when held, and
settles open/closed when released (including cancellation and flick momentum).
Wallpaper-backed cards reveal with app icons, a stable hover area and glass highlights.
Click a desk/window to open it, or drag a window onto another desk to move it
without switching. Arrows and Enter navigate; digits 1–9/0 switch directly.
Escape cancels a drag, then closes the overview. Thumbnails capture real windows
only while open; reduced motion and the current theme are respected.
See [behavior and live validation](workspace-overview.md).

## My Day

The clock opens the center panel; Escape and outside clicks close it. The bottom
arrows/tabs, a short horizontal two-finger scroll or drag, or Alt+Left / Alt+Right switch between My Day and
Music. The last page is remembered until the shell restarts. Select a date to
view its events/tasks. The month arrows navigate; clicking the month title returns
to today. Events and tasks can be added and removed; checkboxes complete tasks.
Notes save automatically. Data is local, without external calendar synchronization:
`$XDG_STATE_HOME/poly-shell/organizer.json` (normally `~/.local/state/poly-shell/organizer.json`).
Include this file in personal backups. Do not commit it with the public project.

The focus timer uses a saved wall-clock deadline, so closing the popup, restarting
the shell or suspending does not restart its countdown. At completion it shows
`Готово · отдохни`; this version does not play an alarm or send a reminder.
Files opens the system's home-folder handler; Terminal uses `settings.apps.terminal`.
The screenshot button is in quick settings, beside Settings. It closes the popup
before starting region selection via the existing `~/.config/hypr/screenshot.sh`.

Bar tray icons use the applications' supplied assets. Their menus follow the system
Qt menu theme. Notification history stays owned by Mako; the shell reads it and does
not replace the notification daemon. `gdbus` provides the notification change watch.

See [top bar and organizer validation](top-bar-validation.md).

## Bottom dock

Move the pointer to the bottom edge, near the center of the screen, to reveal
the dock. It hides when the pointer leaves. Favorites share their saved list
with the launcher; other running applications appear alongside them.

- Click to launch an application or focus its window. Repeated clicks cycle
  through that application's windows, including windows on other workspaces.
- Right-click for the window list and pin/unpin actions. Favorites are shared
  with the launcher. Middle-click invokes the desktop entry again; whether this
  creates another window is decided by the application.
- Scroll over an app with multiple windows to cycle them. Scroll the dock's
  horizontal strip if the screen cannot fit all its applications.
- The mountain mark opens the application launcher above the dock; the top-bar
  button and Super+R open the same menu at the top. Search and favorites are shared.
  The dock stays available under its launcher; Escape or an outside click closes
  the menu. Dots mark running apps;
  an accent pill marks the active one, and a badge counts multiple windows.

The glass, outlines and highlights follow the current theme and panel appearance.
Hover lifts the icon inside a stable button. Keyboard focus stays with the app.
The dock reserves no workspace space and stays suppressed during fullscreen,
workspace overview, sleep and other shell panels, except its own application
launcher. See [behavior and checks](dock.md).

## Clipboard history

Hover the clipboard button in the top bar for a compact preview of up to three
records. The preview keeps application keyboard focus, allows quick copying and
closes when the pointer leaves. Click the button or **Open all history** to expand
it into the searchable text/image history. **Super+V** opens the full version
directly. Choose a record with a click or Up/Down and Enter, then paste
with Ctrl+V in the original application. Escape or an outside click closes it.
Pin records to keep them at the top; the pinned filter narrows the list.
Clear history preserves pinned entries; each record can also be removed separately.
Pause stops recording new copies and persists across shell restarts.

History is local to `~/.local/state/poly-shell/clipboard` (or `$XDG_STATE_HOME`),
with private permissions. It stores up to 200 records / 64 MiB, 8 MiB per record,
and up to 50 pinned records. Text is restored byte for byte as UTF-8; supported
image payloads are PNG, JPEG, GIF and WebP. Password-manager copies marked
`CLIPBOARD_STATE=sensitive` are skipped. Unmarked text follows the normal history
policy. The primary selection is untouched. Requires `wl-clipboard` (`wl-paste`
and `wl-copy`); no external clipboard-history service is needed.

On this desktop, the previous floating-window shortcut moved to **Super+Shift+V**;
the Hyprland configuration was backed up before changing the bindings.
See [implementation and validation](clipboard-history.md).

## Music page

The Music page uses Quickshell's MPRIS service to control existing media players,
including browsers that expose MPRIS. It is a controller, not a streaming service.
It shows track/artist/album, cover art with a fallback, elapsed time and duration;
controls include play/pause, previous/next, seek, player volume, shuffle and repeat.
Only functions advertised by the selected player are enabled. A stream without a
known duration has no seek control. If several players are available, choose one
using the source buttons. The initial choice favors a playing source; pressing
play/pause pins that source so another playing application does not steal focus.
`Open player` uses the player's advertised Raise method.

The progress update timer runs only while the Music page is open and playing.
No player is launched, no audio is started and no sample track is seeded by the shell.
See [music validation](music-validation.md).

## Wallpaper themes

**Settings → Темы и обои** provides six coordinated landscape themes, a desktop
preview and a shared wallpaper/palette Apply button. Import personal images to
extract their colors; imports are kept privately in the user configuration.
Themes recolor the shell, borders, supported toolkit applications and lockscreen
without changing Work/Vibe or window geometry. Wallpaper rendering stays alive
when settings closes. Pillow (`python-pillow`) is needed for personal imports.

See [theme behavior, recovery and validation](wallpaper-themes.md).

## Settings and profiles

Settings → **Горячие клавиши** imports supported keyboard bindings from
`hyprland.lua`: search, add, edit, disable/delete and restore. Changes are checked
for conflicts, backed up and applied with rollback on failure. Unsupported callbacks,
submaps and mouse gestures stay in the original configuration. See the
[shortcut editor guide](shortcuts.md).

The quick-settings **Настройки** button opens an independent, centered floating
application (1100×800 logical pixels, fixed size). It is also available as
**Настройки Poly** in the launcher, or through `poly-shell settings`. Reopening
focuses the existing window. A separate user unit keeps it independent of bar
restarts; closing the app exits that unit.

The Alpine settings center opens on an overview with real connectivity, monitor,
audio and power status. A searchable sidebar provides Wi-Fi, Bluetooth, monitors,
wallpaper, appearance, sound, power and notification pages, plus room for future
input and peripheral controls. Wallpaper selection is saved for future sessions.
Monitor layout editing and integrated new-device Bluetooth pairing are future work.
The fixed-size floating window rejects maximize/fullscreen requests.

Appearance selects windows, bar, menus, widgets, launcher or notifications, with
rounding, opacity, outlines, shadows, applicable padding and animation controls.
Bar height and margins are editable; blur remains a shared control. A local
preview follows the draft. See [per-element appearance](appearance-per-element.md).
Changes stay in a draft until **Применить**; **Отменить**
discards the draft and **Исходный пресет** loads the optimized defaults into it.
The defaults also require Apply. An unsaved draft prompts before closing.
See [appearance controls and validation](appearance-controls.md).

Visual controls are stored in `~/.config/poly-shell/visual.json`, independently
of Work/Vibe and the theme manifest. `poly-shell appearance install` installs a
backed-up Lua include and the application's floating-window rule in the existing
Hyprland Lua configuration. `poly-shell install` installs the application launcher.

```sh
poly-shell mode               # Current mode
poly-shell mode work
poly-shell mode vibe
poly-shell mode toggle
poly-shell refresh            # Apply edited settings/profile files
poly-shell restart
poly-shell wallpaper         # Apply the bundled static wallpaper
```

Settings: `$XDG_CONFIG_HOME/poly-shell/settings.json` (default `~/.config/poly-shell`).
Commands are arrays such as `"terminal": ["foot"]`; they are not interpreted by a shell.
Foot is preferred when it is already installed; otherwise the initial default is Kitty.
The terminal setting also selects the host for Nmtui and Bluetoothctl. Existing Hyprland
terminal hotkeys are separate.

The shared `bar` settings control height, workspace count, font, margins and top offset.
`"reducedMotion": true` disables our shell's transitions.
Override individual fields in `~/.config/poly-shell/profiles/work.json` or `vibe.json`, e.g.:

```json
{"motionMs": 0, "palette": {"accent": "#a8d5bc"}}
```

The resolved snapshot lives in `$XDG_STATE_HOME/poly-shell/session.json`, with a schema
version, serialized writes and atomic replacement. Invalid settings cannot overwrite the
last valid snapshot. A corrupt saved snapshot is preserved and reported for recovery.

## Performance and validation

See the [current code audit and unresolved release issues](code-audit-2026-10-22.md).
The companion still has a significant measured rendering cost; the audit does not
claim a release-ready or warning-free runtime.

Closed calendar/control windows are unmapped. The launcher retains a ready
keyboard surface with compositor blur disabled. Its GPU effect and texture
updates stop while closed; the selected Wings curve runs in the vertex stage.
See the [desktop performance correction](performance-2026-10-20.md) for
measured results, hardware context and validation limits.

Window, audio and battery data use event subscriptions. One audio tracker and one
session watcher are shared across monitors. The clock wakes once per minute; no
per-frame processes are used. With quick settings open, a 2.5-second status refresh
reads external backlight / Mako changes; it stops when the menu closes.

`scripts/check` checks state persistence, concurrent profile changes, failed writes,
configuration validation and the reversible autostart transformation, then runs QML lint.
Live checks must additionally cover panel rendering, workspace switching, hotplug,
fractional scaling, keyboard navigation, mode persistence and idle CPU use on hardware.

See [the quick settings validation](quick-settings-validation.md) and
[the first foundation validation record](validation.md) for verified behavior,
the initial performance baseline and remaining hardware checks.

## Desktop companion

**Грань** is a detailed articulated robot living in a free lane of the top bar.
It lands and walks on exposed widget/window edges, follows moved windows, flies,
waves, checks its mechanisms and reacts
to music and charging using the current theme's
palette. Settings → Widgets controls visibility, flights and active/calm behavior, saved
immediately. It stops animating while hidden or when reduced motion is enabled.
See [behavior, placement and validation](desktop-companion.md).

## Living landscape

The optional **Живой пейзаж · интерактивные точки** mode is disabled by default.
Enable it in Settings → Widgets to turn wallpaper landmarks into controls:
hover light for appearance, hover water for music, click a peak for applications.
It includes reflected playback controls, soft glow and theme-specific placement
for all six landscapes and Timeline. The top bar and enabled desktop widgets stay
visible, including on empty workspaces. Settings → Widgets controls the landscape
and each ordinary widget independently. See [interaction, effects and validation](living-landscape.md).

## Roadmap

1. Validate more monitors, login/resume and fractional scales for the new popup.
2. Add integrated Bluetooth pairing and a full notification center.
3. Define behavior policies for modes, with explicit user overrides.
4. Extend the low-poly visual system to the remaining desktop tools.
5. Add distribution documentation, supported-version checks and release automation.

License and public release name will be chosen before publishing. Nothing is uploaded
by the installer or CLI.
