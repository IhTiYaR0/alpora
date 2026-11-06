# Input and responsiveness audit — 2026-10-19

Initial checks: Ryzen 5 7520U / Radeon 610M, 1920×1080 at 60 Hz;
11 GiB available RAM, no swap use, low CPU pressure, balanced power profile,
hardware amdgpu rendering. No recent kernel warnings or failed user services.
These observations do not rule out intermittent stutters or input problems.
The `powersave` governor under amd-pstate-epp with the balanced profile was not
treated as evidence of a fault; no power policy, kernel or driver was changed.

Changes:

- Persistent TopBar uses keyboard focus `None`, not `OnDemand`. It cannot retain
  application typing focus after a mouse interaction. Explicitly opened popups
  remain keyboard-modal until dismissed.
- Super+I and Super+M are compositor binds instead of Qt shortcuts on a panel
  that might not have focus. Like Super+R, they retain Hyprland's first-layout
  binding semantics, working on the same physical keys in US and RU.
- Popup initial focus is requested once on the next event-loop turn; the
  duplicate request and delayed 80 ms refocusing have been removed.
- Launcher retains lightweight grid slots for content sizing but creates
  complete AppTile controls, effects and icons only for the viewport plus one
  prefetched row. The small favorites set stays warm; closed search result
  cards unload after closing. App icons load
  asynchronously. Search, favorites and categories preserve their data.
- In the two-column app grid, Up/Down move by a row rather than one column.
  Both Return and keypad Enter activate the selected application.
- Compositor blur uses size 5 / passes 2 instead of size 6 / passes 3. Glass,
  panel reveal and click animations remain enabled.

Validation: 42 Python tests and QML lint; live Super+I/M/R roundtrips in both
layouts, restoring the virtual keyboard's original layout; typing `firefox`
immediately after opening; full installed-app list and wheel scrolling; no
application launched during the input test. Actual keyboard repeat behavior
and the user's specific intermittent issue still require a reproduction case.

An exploratory 4-panel replay measured average GPU busy 63.9% before vs 60.9%
after, with 100% peaks in both; shell CPU was 20.6% vs 22.9% of one core.
Idle shell CPU remained 0.3%. The desktop was not controlled, so these short
samples are NOT proof of an overall speedup or stable frame pacing. Further
profiling should target the exact interaction that still stutters.

Qt Wayland text-input focus warnings and some third-party SVG buffer warnings
still occur; they were not hidden by logging filters or declared resolved.
The pre-change Hyprland configuration is backed up at
`~/.local/state/poly-shell/backups/input-performance-before/hyprland.lua`.

## Immediate Super+R typing regression

The previous check waited before typing and did not cover the reported case.
One uninterrupted shortcut-plus-typing sequence reproduced the loss: `firefox`
became an empty query at 5ms event spacing and `x` at 10ms. Removing only the
process spawn was insufficient under repeated openings.

Super+R/I/M now use native `hyprland_global_shortcuts_v1` registrations rather
than starting `quickshell ipc`. The launcher keeps its transparent Wayland
surface and search focus target ready. At rest its pointer mask is empty and no
focus grab is active. A native `HyprlandFocusGrab` focuses the prepared surface
on opening without waiting for a rendered layer-state update. Its layer uses
stable `OnDemand` interactivity: combining the grab with changing Exclusive/None
interactivity caused a second race and was removed. The bar itself remains None.
Search state resets after close, or immediately on a rapid reopen; no delayed
clear can erase text after a new open. Search-result cards skip entrance staging.

`scripts/check-launcher-input --live` reproduces the exact event order in a
temporary Kitty input sink. It types without sleeping after Super+R, checks
the actual TextField text and focus over 12 attempts in US/RU at 2/5/10ms event
spacing, tests rapid reopen, restores the virtual keyboard layout and closes
only its own test window. No Return is sent and no app result is executed.
The native-grab revision passed all 12 immediate-input attempts in its first
full series and again 12/12 after a clean service restart, including rapid
reopen reset. Native Super+I/M roundtrips also pass. The per-screen IPC
`launcher-<monitor>.inputStatus` is diagnostic
only and never logs or intercepts input outside the launcher.

The installed Quickshell GlobalShortcut tooling metadata omits its PostReloadHook
dependency; qmllint still emits that upstream import warning. NativeShortcut
isolates unresolved-type suppression to the registration wrapper. Runtime
registration is verified with `hyprctl globalshortcuts`; no system package or
logging filters were changed to hide runtime errors.

References: [native shortcut dispatch](https://wiki.hypr.land/configuring/core/binds/globals/),
[focus-grab lifecycle](https://quickshell.org/docs/v0.2.1/types/Quickshell.Hyprland/HyprlandFocusGrab/).
