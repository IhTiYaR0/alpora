# Hover panel aligned with the full control center

The current hover design follows the actual full control center rather than
standalone HoverStatusTile/HoverControl visuals. Both views share QuickSwitchTile,
ControlRow and QuickActionButton, the same 16px padding, dividers, mountain header,
materials and semantic theme colors. The two radio cards sit above the controls;
DND uses a compact 44px full-width switch row. Ordinary panel dimensions are
460×409 logical pixels; height follows content and remains screen-bounded.

Wi-Fi shows the real SSID and strength through StatusIcon only (no percentage).
Bluetooth shows the connected device or service state. Radio arrows and output
selection expand the full center directly into the requested device page.
The rounded liquid outline uses the shared configured panelRadius. The exact
card radii and surface roles come from the components used in the full center.
Work/Vibe, theme/Timeline bindings and reduced motion remain independent.

Opening and closing still begin without hover timers. The existing pointer bridge
and drag handling are preserved, and preview does not take keyboard focus.
No extra polling, blur or texture buffers were introduced.

Validation: strict QML lint passed for all changed QML. Live checks passed hover,
travel into the popup, expansion into full center and dismissal on pointer leave.
Inspected /tmp/poly-full-current.png and /tmp/poly-hover-matched-full.png side by
side. No radio, audio or power settings were changed during verification.
