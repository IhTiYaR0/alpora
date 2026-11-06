# Two-level quick controls

Reference: assets/reference/quick-center-approved.png (the fuller two-state mockup).

The status button opens a compact quick-access panel immediately on hover, without an opening delay.
It contains output volume, brightness, Wi-Fi, Bluetooth, DND and an explicit
Open control center action. An input-only bridge covers the visual gap to the bar; the preview stays open
over either surface or during slider dragging. Leaving this area starts closing
immediately, with no timed delay.
Preview does not acquire keyboard focus or map the outside-click interceptor.
A button click promotes an existing preview instead of toggling it closed.

Full control center includes separate radio toggle and device-navigation hit
areas, output and input selectors, brightness, DND, night light, airplane mode,
power profiles, settings, lock, power confirmation and region screenshot.
All controls use existing live services, with unavailable/busy states preserved.
The full center retains outside-click, Escape and repeat-click dismissal.
The source-button liquid reveal remains; preview expansion animates only height.
Height follows content and is bounded by the monitor; smaller screens scroll.
Palette and mountain decoration follow the current theme, including Timeline.
There are no hover tooltips or new polling timers while panels are closed.

Validation: scripts/check passed 104 Python tests and strict QML lint. Live IPC
checks passed preview without keyboard focus, click promotion, navigation through
10 pages, pointer-away timeout and full-panel repeat-click dismissal. Preview
and full screenshots were inspected. Radio/audio/power state was not changed by
these checks. This is lifecycle and visual verification, not an FPS benchmark or
a full physical pointer/drag test. Existing Qt Wayland text-input warnings remain.

Backup before implementation:
~/.local/state/poly-shell/backups/quick-center-20261020/

Follow-up: removed the 420 ms close timer; strict QML lint passed.

## Shared-content expansion

Hover and full quick access now use ONE Column in QuickSettings. The old
QuickHoverContent remains on disk but is not instantiated here. Radio cards,
volume, brightness and DND retain their actual QML instances during promotion.
The microphone, power profile and bottom actions unfold through clipped height
changes, while the DND card and its single switch move into the three-card row.
QuickSwitchTile.compactProgress supplies continuous geometry for that switch.
There is no whole-panel fade, crossfade or blank frame between two views.

A single 320ms linear clock with smoothstep geometry drives these changes,
respecting reduced motion. The native Wayland window keeps a stable allocation;
only the visible body and input region follow content height. Ordinary endpoints
are 460×401 and 460×569. Shared colors, controls and device states remain live.
Strict QML lint passed. A single live expansion confirmed opacity=1 at both ends;
mini and full screenshots were inspected. No extended test suite was run.
