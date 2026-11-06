# Top bar and My Day — 2026-10-19

Implemented in the existing Arch/Hyprland session without changing monitor scale,
resolution, terminal bindings or the autostart handover. Bar remains 40 logical px;
My Day body is 700×550 px, constrained by available screen size.

## Checks

- 23 Python tests pass. Qt QML lint passes with zero warnings. A narrow metadata
  suppression covers QFlags for native menu anchor edges.
- Actual pointer clicks opened the clock panel, notifications, quick settings and
  tray overflow. Escape and outside-click dismissal passed.
- Four temporary StatusNotifier services exercised inline/overflow counts and
  removal; activation from inline and overflow delegates reached the test services.
  A native tray context-menu action also reached its service. Test services were
  then stopped; the tray returned to zero items.
- Layout button changed the real active keyboard layout and changed it back.
- Keyboard entry created an event and task through the UI. A pointer click checked
  the task. Temporary entries were removed after checks.
- A timer started and retained the same deadline through popup close and service
  restart. The pause button persisted its paused state. Timer was reset afterward.
- Note text autosaved and survived a service restart. The original note was restored.
- Unit tests cover simultaneous additions, invalid dates/times, literal note text,
  disk-write failure, preserved corrupt data and timer completion across wall time.

## Scope

- Events/tasks/notes are local; there is no remote calendar synchronization.
- Timer completion is displayed visually; no audible or desktop alarm is implemented.
- File/terminal shortcuts use xdg-open and the configured terminal. A screenshot uses
  the user's existing Hyprland screenshot script. These launch paths were inspected;
  no extra screenshot or app windows were left open during this check.
- Physical multimonitor/fractional-scale cases and suspend/resume were not exercised.
  The unit test models wall-clock timer progression across downtime.
- The existing Qt Wayland text-input warnings still occur around popup focus changes.
  These are not shell exceptions; do not claim a warning-free runtime.

Live previews are local, under `~/.local/state/poly-shell/previews/`:
`top-bar-live.png`, `day-panel-live.png`, `day-panel-detail.png`. The screenshots show
empty real records rather than seeded mock data. Personal organizer content remains
outside the repository. The initial backup is under
`~/.local/state/poly-shell/backups/20261019-121711-top-bar/source.tar.gz`.
