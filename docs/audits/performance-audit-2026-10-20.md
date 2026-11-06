# Performance audit, 2026-10-20

The reported constant desktop lag has not yet been reproduced or attributed to
one cause. A disconnected secondary display is not a diagnosis of the remaining
problem on the main display.

## Observations

- Main display: eDP-1, 1920×1080 at 60.008 Hz, scale 1. The initial idle sample
  also included an external 4K/30 Hz display; the later sample did not. These are
  different conditions, so their GPU percentages are not a controlled comparison.
- GPU: integrated AMD Radeon 610M, 512 MiB reserved VRAM, with shared system memory
  also in use. High reserved-VRAM occupancy alone does not establish a fault.
- Approximately 5 GiB RAM available. CPU, memory and IO pressure averages were
  zero; no active swap traffic or disk wait during the sample. No GPU reset or
  OOM event found in the inspected kernel logs. Hyprland reports no config errors.
- Latest four-second sample: main Quickshell 0.50% of one CPU core and 0.03% GPU
  graphics-engine time; Hyprland 4.71% CPU / 7.74% GPU; terminal 2.97% CPU /
  10.87% GPU. These short samples do not rule out intermittent stutters.
- Service-cgroup memory includes launched user applications and must not be
  presented as Quickshell's own memory usage. Main Quickshell RSS was 670 MiB.
- Calendar opening before the blur adjustment: p95 frame intervals 18/17 ms,
  maximum 35/33 ms. After: p95 18/17 ms, maximum 27/28 ms. This is compatible
  with approximately 60 Hz rendering and occasional missed frames; two trials
  do not establish that blur caused all reported lag.
- Existing Timeline rendering has no continuous idle frame timer. Six wallpaper
  textures preload; only the current blend pair is visible. The synthetic pointer
  drag attempt did not validate the popup position, so it is excluded as evidence.

## Applied changes

1. Saved and live compositor blur size reduced from 8 to 3, passes retained at 1.
   Prior preferences are backed up under
   `~/.local/state/poly-shell/backups/performance-20261020-175824`.
2. Launcher, quick settings, bar popups, desktop widgets and Timeline wallpaper
   now guard accesses to a removed screen. Disconnecting the secondary display
   produced null-screen errors in the existing log. Detached widgets stop their
   visibility work and panels cannot open against a missing screen. This fix is
   not evidence that hot-unplug errors caused constant lag.

No user applications or shell services were killed/restarted. QML changes loaded
through the existing live-reload mechanism.

## Validation and remaining uncertainty

`scripts/check`: 98 tests passed; strict QML lint passed. Live calendar checks
passed opening/closing endpoints, popup switching, rapid reversals, and closed
surface unmapping. Main shell IPC is ready with one display after reload.

Final calendar traces: p95 17/17 ms, maximum 29/21 ms. A separate launcher
immediate-input check failed 1 of 12 attempts: in the first US-layout trial,
typing 2 ms after the shortcut lost the first character (`irefox` instead of
`firefox`). Remaining US trials and all RU trials passed. This focus/input race
is unresolved; the full live input check must not be reported as passing.

Qt Wayland text-input focus warnings remain during panel focus transitions.
They are not established as a performance cause. Physical monitor reconnection
has not been tested after the null-screen guards. The user's current observation
of cursor/window versus panel stutter is still needed to target further tracing.

Raw samples and check output are in `performance-evidence/2026-10-20/`.
