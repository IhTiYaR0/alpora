# Desktop performance correction — 2026-10-20

## Outcome

The GPU was the primary bottleneck in this session, not a memory shortage or
CPU saturation. AMD Radeon 610M was repeatedly reporting 99–100% busy while
approximately 12 GiB RAM remained available, swap was unused and CPU was mostly
idle. Briefly stopping only Poly Shell made GPU busy readings mostly fall to zero.
The previous shell architecture therefore materially contributed to the slowdown.

The tested desktop is a 1920×1080, 60Hz eDP-1 display at scale 1, using amdgpu.
There were no observed GPU reset/timeout messages in the current boot. No kernel,
driver, package, display-scale or CPU/GPU clock modifications were needed.

## Final implementation

- Calendar/notification/tray and quick-settings windows unmap after closing.
- The launcher retains its mapped keyboard surface for immediate Super+R input.
  A launcher-specific Hyprland rule disables compositor blur for this surface.
  Its background is denser, using the same palette, to preserve legibility.
- The shader is invisible while idle and its content texture is updated only
  during movement. Stationary panels render their actual controls directly.
- Wings curve interpolation and fade terms execute in the vertex shader rather
  than in every fragment invocation. The quad itself follows the moving rounded
  surface, avoiding rasterization of the entire final panel during the stem phase.
  The approved study 03, 520ms/220ms timing, rounded edges and fixed-size text remain.
- A native focus grab first targets the popup alone. Only after the window
  receives keyboard focus is the bar added to the allowed input surfaces. This
  avoids an ambiguous initial focus target while allowing one-click switching.
  Hidden calendar/control windows request no keyboard focus.
- Hyprland blur uses size 3 / one pass instead of size 5 / two passes. Shell layer
  blur uses the xray optimization; shadow range is 12 instead of 22.
- Power profile changed from power-saver to balanced. The user can still change
  the profile normally; no policy forces it on subsequent mode switches.
- Kitty's configured background is opaque for new windows. A Kitty-only no_blur /
  force_rgbx rule also removes transparency compositing from the already running
  terminal without terminating its programs or resetting its text.

## Measurements and limits

Initial short per-process DRM counter sampling attributed approximately 50.5%
gfx-engine busy time to Hyprland. The final 8.05-second closed-menu sample was
11.85% for Hyprland and 0.10% for Quickshell; Quickshell CPU was 1.37% of one core.
The full-screen Kitty/Codex terminal was active throughout these checks. Its final
gfx-engine reading was 13.62%. Total driver GPU-busy samples still varied, with a
42% mean in that final sample; **the desktop was not GPU-idle**.

These are short observations during an interactive session, not an isolated
benchmark or a guarantee under other workloads. Process DRM-engine counters and
the driver's instantaneous total GPU busy gauge are different measures.

Before the correction, panel captures produced around 11–12 intermediate window
frames per 520ms opening with p95 intervals around 34–35ms. The final captures:

```text
launcher [{"frames": 30, "p95Ms": 18, "maxMs": 23}, {"frames": 30, "p95Ms": 17, "maxMs": 32}]
calendar [{"frames": 30, "p95Ms": 18, "maxMs": 25}, {"frames": 24, "p95Ms": 17, "maxMs": 25}]
notifications [{"frames": 26, "p95Ms": 17, "maxMs": 32}, {"frames": 26, "p95Ms": 18, "maxMs": 21}]
quick-settings [{"frames": 25, "p95Ms": 17, "maxMs": 25}, {"frames": 25, "p95Ms": 17, "maxMs": 38}]
PASS endpoints, popup switching, rapid reversals
PASS closed calendar/control surfaces are unmapped
```

The passive callbacks do not force frames. They indicate substantially better
window update cadence, but can be delayed by the GUI thread and are not direct
compositor presentation timestamps. Occasional 21–38ms gaps remain in the short
capture; do not call the result guaranteed perfect 60fps.

## Verification

- 44 Python tests passed.
- Changed QML components lint cleanly; the previously documented upstream
  NativeShortcut/PostReloadHook metadata warning is separate from these changes.
- Baked vertex and fragment shaders compile with the installed Qt shader tool.
- Immediate US/RU input: 12/12 passed, including rapid close/reopen search reset.
- Physical clicks: launcher → calendar → quick settings → close passed.
- Rapid reversals, shared popup switching, final geometry and the absence of
  mapped closed calendar/control surfaces passed.
- An intermediate desktop capture confirmed the optimized stem is visibly drawn.
- Hyprland reports no configuration errors. Poly Shell is active, with zero
  automatic service restarts in the final service instance.

Read-only counter sampler: `scripts/check-render-load --seconds 8`.
Live interaction checks require `--live` and should run sequentially. Never
interpret an idle capture taken concurrently with panel exercises as idle data.

## Backups and references

Original settings and renderer backups are under:
`~/.local/state/poly-shell/backups/performance-20261020-024351/`.
The saved environment record identifies the previous power profile. Backups
include the original Hyprland and Kitty settings and original fragment effect.
Desktop screenshots were kept in /tmp, not committed into project documentation.

Primary references:

- [Hyprland performance](https://wiki.hypr.land/0.56.0/Configuring/Advanced-and-Cool/Performance/)
- [Hyprland window rules](https://wiki.hypr.land/configuring/core/rules/window-rules/)
- [Hyprland layer rules](https://wiki.hypr.land/configuring/core/rules/layer-rules/)
- [Kitty configuration and transparency cost](https://sw.kovidgoyal.net/kitty/conf/)
- [Qt texture sources and input behavior](https://doc.qt.io/qt-6/qml-qtquick-shadereffectsource.html)
