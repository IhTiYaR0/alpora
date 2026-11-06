# Top bar rebuild, 2026-10-20

The Alpine landscape and theme palette remain. Panel state, focus ownership,
transitions and status presentation have been rebuilt.

## Behavior

- `BarState.selection` publishes a panel name and monitor together. Quick settings
  and other panels share this selection, preventing two logical panels opening
  together. Disconnecting the selected monitor dismisses the selection.
- One focus grab per monitor owns the current panel. A newly mapped small panel
  waits for its first frame; the bar remains an allowed click destination. Escape
  is coordinated by one application shortcut, including when a bar click owns focus.
  Repeated clicks close the active panel. Escape returns from a settings subpage
  to its main page, then closes it. Outside clicks dismiss the panel.
- Calendar, notifications, tray and Timeline share a bounded popup window; quick
  settings also uses a bounded window. Shadow padding is 16 logical pixels.
  Closed panels remove their input regions and unmap. A transparent, unanimated
  dismissal surface below the panels catches background clicks without blur or
  visible content. The prepared launcher's
  existing keyboard surface remains mapped for immediate search input.
- No hover tooltips remain anywhere in this shell or its settings components.
  Visible labels and accessibility names remain.

## Rendering

The former Wings shader, live content texture and geometry morph are no longer
used by `UnfoldPanel`. Bounded panels have no QML opening/closing animation.
Hyprland fades their cached surfaces over 340 ms in / 200 ms out, with the
`polyPanel` curve. Their separate `poly-panel-*` namespaces avoid the existing
broad glass/no-animation rule. Live backdrop blur is disabled on these panels;
material opacity is at least 92% for legibility. The bar retains its material and uses the overlay layer so its navigation
buttons remain reachable while another overlay panel is mapped. It accepts
keyboard focus only while a panel is open.

Launcher appearance now matches the compositor fade: 340 ms opening, 200 ms
closing, and the same cubic curve (0.2, 0), (0.2, 1), with no translation. Text is not scaled or tilted. Internal page changes fade for
160 ms, and this secondary transition is disabled during initial panel mapping.
Reduced motion selects compositor namespaces with `no_anim = true` and disables
Qt animation durations.

`appearance.install_hook` adds the native panel rules on new installations.
The live system had an existing reformatted appearance hook which the installer
correctly refused to overwrite; that hook was preserved and only the separate
panel-motion block was appended. Existing layer fade animation leaves also
inherit the new durations. No service or user application was restarted.

## Observed status

`Session` derives the status cluster from Quickshell's NetworkManager, PipeWire,
Bluetooth and UPower services. Wi-Fi enabled does not mean connected. Disabled,
hardware-blocked, unavailable, connecting and disconnected states are distinct.
Connected Wi-Fi displays signal strength; a wired connection takes precedence in
the bar. Internet access is only claimed when the service reports Full; Unknown
is labelled unverified. Signal strength is a fraction from 0 to 1, as documented
in [Quickshell's source](https://github.com/quickshell-mirror/quickshell/blob/master/src/network/wifi.hpp).

Audio distinguishes no sink, mute, zero volume and volume levels. Bluetooth shows
adapter power and actual connected devices. Battery fill, charging and external
power follow UPower. Device-state tests use synthetic observations, without
turning off the user's network or changing audio settings.

## Verification

- `scripts/check`: 104 Python tests and strict QML lint.
- `scripts/check-bar-panels --live` passed the final full run: opt-in real pointer and keyboard checks on an
  empty workspace, restoring the workspace and cursor afterward. Covers all
  panel types, switching by bar buttons, repeat-click dismissal, outside clicks,
  Escape, settings subpages and rapid changes.
- Native compositor fades do not generate Quickshell frame swaps on every frame.
  Zero moving Qt trace samples are expected for them; they are not a compositor
  frame-rate measurement. Launcher swaps remain observable in its Qt trace; the
  final full run recorded p95 27 ms / maximum 31 ms, so this is not a claim of
  flawless 60 Hz launcher animation under every workload.
- Earlier Qt-driven prototypes showed frame intervals of 30–56 ms and were
  replaced. Their timings are not results for the final compositor fade.

Backup: `~/.local/state/poly-shell/backups/bar-rebuild-20261020-204109/`.
The compositor API is documented in [Hyprland animations](https://wiki.hypr.land/configuring/core/animations/)
and [layer rules](https://wiki.hypr.land/configuring/core/rules/layer-rules/).

Immediate-input stress check: 11 of 12 attempts passed. One RU 5 ms attempt
produced mixed text (`аfox`); the test is not considered passed. This was run on
the user's active desktop, so input interference and a layout/focus race have
not been distinguished. No further automated input runs were started.

After the user reported panels not opening during the checks, all interactive
checks were stopped. Quick settings was opened once and left open. Both live
IPC and a desktop screenshot confirmed the visible panel with keyboard focus.
The screenshot remains local at `/tmp/poly-bar-current-open.png`.

A four-second sample during the user's active manual review showed Quickshell
at 28.77% of one CPU core / 28.85% graphics-engine time, and compositor graphics
at 54.27%. Panels were closed by the end of that sample. This is NOT an idle
baseline, does not establish a leak, and must not be used to claim that system
lag is fully resolved. The user confirmed the panel is visible and is checking
it manually; automated interaction and QML reloads were stopped.

## Follow-up: shared panels failed to stay visible

The user subsequently reported that calendar, Timeline and notifications did not
open reliably. The shared Hyprland focus grab now applies only to the prepared
launcher; regular panels acquire initial keyboard focus through layer-shell and
then use OnDemand mode. Their separate dismissal surface handles outside clicks.
Thus a stale grab cancellation cannot dismiss a newly selected regular panel.

`UnfoldPanel` no longer constructs `PanelReveal` at all for compositor-managed
panels. Their native content is directly visible while open, without zero-duration
render-thread state transitions or a second opacity controller.

Validation: 104 tests and QML lint passed. Without mouse injection or workspace
switching, calendar, Timeline and notifications were each opened on the current
desktop and confirmed visible in screenshots and IPC. Calendar was left open.
This verifies visual opening, not a new full interactive stress run.

## Unified motion follow-up

The launcher, calendar, Timeline, notifications and quick settings now share a
fade-only transition: 340 ms opening / 200 ms closing and identical Bezier
control points. Launcher scaling and translation were removed. Bar controls use
the same 120 ms color feedback; decorative glints, contact waves, button scaling
and launcher-logo spin were removed from the bar controls. QML validation and
104 tests passed. No automated mouse or workspace interaction was run.
