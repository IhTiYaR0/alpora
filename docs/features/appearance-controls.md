# Poly settings application — 2026-10-20

The appearance page was extended on 2026-10-21: see
[per-element controls and validation](appearance-per-element.md) for the current
interface, additional settings and migration behavior. The original design and
validation history below describe the initial implementation.

The settings UI is a normal Wayland application, not a quick-settings subpage.
It runs `shell/settings.qml` in a separate Quickshell process and transient user
unit, `poly-shell-settings.service`. Its app ID is `poly-shell-settings` and its
desktop launcher is `~/.local/share/applications/poly-shell-settings.desktop`.
The quick-settings Settings button closes the popup and calls `poly-shell settings`.
Subsequent calls focus the same window. Launches are serialized by a runtime lock.

The installed Hyprland rule floats and centers the app at 1100×800 logical pixels;
QML also sets both minimum and maximum sizes to 1100×800. The header can be dragged.
This size is verified on the current 1920×1080, scale-1 display. Smaller work areas
and larger display scales are not validated for this fixed-size application.

## Settings center update — 2026-10-20

The app now opens on an overview matching `assets/reference/settings-center-approved.png`.
The implemented screenshot is `assets/reference/settings-center-implemented.png`.
A searchable, scrollable sidebar separates connectivity, desktop and system settings.
The overview uses real network, Bluetooth, monitor, sound and power state; it never
seeds mock devices. The Alpine glass cards, custom SVG ridge, icons and wallpaper
previews use static assets. Rounded image masks have no animation or redraw loop.

Wi-Fi supports known/open/personal networks and password entry using the existing
Quickshell service. Enterprise setup and new Bluetooth pairing retain the existing
terminal tools. Paired Bluetooth devices, sound devices, microphone, power profiles,
DND, Work/Vibe and appearance controls are connected. The monitor page reports
actual geometry and brightness; editing monitor layout/resolution is future work.
Input and peripheral sections reserve navigation space and say what is available;
they do not pretend unimplemented actions work.

The wallpaper chooser is parented to the settings window. `poly-shell wallpaper
[image]` validates the file, starts a replacement renderer in an independent transient user service, checks startup, atomically
saves `~/.config/poly-shell/wallpaper.json`, then retires the previous renderer.
Startup without an argument reuses the saved image; `--reset` restores Alpine.
Failed startup leaves the previous renderer/preferences intact; failed saving
stops the replacement service. Dashboard previews watch the saved preference.

The renderer must not be a detached child of the settings service: `setsid` does
not leave a systemd cgroup, so closing the app killed the wallpaper in the initial
implementation. Each renderer now uses its own `poly-shell-wallpaper-<id>.service`
with the current Wayland environment and journal logs. Live regression validation
applied the wallpaper through the GUI, checked its independent cgroup, closed the
settings app and reopened it: the same renderer PID remained alive throughout.
Login restoration continues to call `poly-shell wallpaper` with the saved image.

The compositor rule now also enforces min/max size 1100×800 and suppresses client
maximize/fullscreen requests. QML handles compositor-initiated maximize/fullscreen
changes by resetting both compositor states and the fixed geometry. Reopening
restores the separate floating window instead of creating a duplicate. Explicit
forced maximize, fullscreen and resize attempts were tested: final size 1100×800,
floating true, fullscreen/client state 0. No global key bindings were modified.
Installation upgrades the exact old managed rule and backs it up.

Validation: 62 Python tests passed; all changed QML and new components lint with
zero warnings. The full-project lint still reports the pre-existing PostReloadHook
metadata warning in NativeShortcut.qml. Live checks covered real pointer navigation,
all sections, native wallpaper chooser open/cancel, retained appearance draft across
navigation, cancellation without changing saved values and single-instance reopen.
Actual network reconnection/new pairing, monitor reconfiguration and suspend/resume
were not performed. Original appearance values were kept.

References: [Hyprland window rules](https://wiki.hypr.land/configuring/core/rules/window-rules/)
and [dispatchers](https://wiki.hypr.land/configuring/core/dispatchers/).

## Appearance interface

The Alpine palette, faceted mark, mountains, sage accents and matching vector
icons are shared with the desktop. Three actual navigation buttons select
rounding, transparency or blur. Cards group the controls; the right-side preview
shows the draft. The footer applies or cancels changes across all sections.
Close requests with a draft ask whether to discard it. Close while saving is
blocked so the app's Process object does not terminate an in-flight transaction.

The preview is illustrative, uses ordinary Qt Quick primitives and does not run
a blur shader. Desktop changes happen only on Apply; no processes or file writes
are triggered by slider movement. Reduced motion is respected by control effects.

## Supported values

| Setting | Range | Optimized default |
| --- | --- | --- |
| Window rounding | 0–32 px | 16 |
| Bar rounding | 0–20 px | 20 |
| Shell menu rounding | 0–32 px | 20 |
| Bar background opacity | 40–100% | 70% |
| Menu background opacity | 50–100% | 75% |
| Launcher background opacity | 75–100% | 96% |
| Active / inactive whole-window opacity | 60–100% each | 100% / 100% |
| Background blur | on / off | on |
| Blur size | 1–8 | 3 |
| Blur passes | 1–2 | 1 |

Shell material opacity changes background only. Compositor window opacity affects
whole application windows, including their text. At 100%, both ends of shell
material gradients are fully opaque. The launcher's compositor blur remains
disabled to retain the earlier input/performance fix. Native opaque app content
may hide background blur; increasing blur cannot make opaque content transparent.
The current bar height limits its radius to 20px. Popup rounding is now unified
with the other shell menus at 20px (the older center popup used 18px).

## Save and recovery

`visual.json` is independent of the Work/Vibe profiles and theme selection.
`poly_shell/visual.py` validates every key and exact numeric/boolean type before
interpolating any values into Lua. Unknown keys and out-of-range values fail.

The apply path uses the same file lock as mode/refresh operations. An expected
base value prevents stale drafts in another process from overwriting new settings.
It builds the next session before mutation, applies values to Hyprland via eval,
then reads back all six compositor options. Only after confirmation does it
atomically replace the generated Lua include, visual settings and finally the
QML session snapshot. A write or runtime error restores original files and the
previous saved compositor values. Rollback errors are explicitly reported.
This handles ordinary process/IO failures, not a guaranteed cross-file transaction
through a power loss or forced process kill.

The persistent include is `~/.config/hypr/poly-shell-appearance.lua`, sourced by
a small managed block at the end of `hyprland.lua`. Installation backs up the
original Lua configuration and preserves unrelated settings. A manually edited
managed block is not overwritten. Startup/refresh regenerates and reapplies the
saved controls. The GUI reports failures and leaves its draft available to retry.

Backup before implementation:
`~/.local/state/poly-shell/backups/appearance-controls-20261020-113119/`.
Additional compositor hook backups are under `backups/appearance-hook-*`.

## Validation

- 55 Python tests, including value/type/injection rejection, mode independence,
  stale-draft rejection, reset, runtime rejection, rollback at every persistence
  step, first-save cleanup, corrupt settings, native IPC reply types and hook
  installation/idempotence/manual-edit protection.
- All changed/new QML files lint without warnings. The historical full-project
  linter warning for the unrelated PostReloadHook metadata remains out of scope.
- Real pointer test: dragging a control changes the draft while saved files and
  effective state stay unchanged; Cancel restores it; Apply changes actual
  Hyprland rounding and persists it. The original values were restored after
  that controlled test. This first pointer test preceded the separate-window
  redesign; the final app was then visually inspected and its sections/save
  behavior were exercised in the live session.
- Final app is a normal mapped floating client with the expected app ID and
  1100×800 dimensions. It and the bar are active in separate systemd cgroups.
  Reopening keeps the existing app instance. The desktop entry validates.
- Hyprland reports no configuration errors. Both units have zero restarts.
- A short 3-second observation with the app open showed about 0.66% of one CPU
  core and no measured GPU engine time for each Quickshell process. This is an
  idle observation, not a guarantee under interaction or more expensive user
  settings. No forced redraw loop, full-screen overlay or live blur preview was
  added to the app.

Full login/logout, actual sleep/resume and smaller display geometries were not
performed. Existing Qt/Wayland text-input and portal diagnostics can appear;
there were no QML runtime errors in the final application.

Primary API references: [Hyprland configuration options](https://wiki.hypr.land/configuring/core/config-options/),
[Quickshell advanced options](https://quickshell.org/docs/v0.3.0/guide/advanced/),
[FloatingWindow](https://quickshell.org/docs/v0.3.2/types/Quickshell/FloatingWindow/).
