# Central clock hover preview

Approved two-page reference: assets/reference/center-hover-approved.png.

The clock opens a 420×328 logical-pixel hover preview. My Day shows the live
current week (Monday first, today highlighted) and the existing focus timer with
start/pause/reset. It intentionally omits events and tasks. Music uses MusicPanel's
compact mode, retaining the same MusicState/MPRIS selection, real cover and
metadata, capability-guarded transport, seek control and live position. No player
produces the real empty state. Player position polling only runs while that
music page is active and playing, as in the full panel.

Tabs and arrows share BarState.centerPage with the full center. Clock click or
the footer promotes to the full center on the selected page. Hover has no keyboard
focus or outside-click interception. Leaving starts closing without a timer;
the source margin, gap bridge and active seek drag keep it usable. Full-panel
Escape/repeat-click behavior is retained. Actual full My Day and Music remain
700×550 and preserve the original layout and gesture handling.

New surfaces bind Session's semantic colors and shared theme components. Existing
MusicPanel theme role resolution remains live, with compact size overrides only.
Work/Vibe and geometry settings remain independent. A minute SystemClock supplies
the week/date, with no additional idle refresh loop.

Validation: scripts/check passed 104 tests and strict QML lint. Inspected live
My Day, idle Music and playing Music screenshots. Actual pointer checks passed
clock hover without keyboard focus; travel over y=46/50/54/58/65/100; both tabs;
focus start/pause/reset (original idle 5-minute timer restored); footer expansion
preserving Music; two repeated clock click cycles; pointer-away dismissal; seek
drag outside the popup and back; full-panel Escape; and hover regression for
notifications and quick controls.

A temporary local MPRIS fixture played no audio. Real UI clicks delivered Pause,
Play, Previous, Next and SetPosition to it. It was removed after verification;
no test media source remains. Browser/player compatibility beyond the existing
MPRIS contract is not asserted by these fixture checks.

Screenshots: /tmp/poly-center-day-live.png,
/tmp/poly-center-music-idle-live.png and /tmp/poly-center-music-playing-live.png.

## Hover gesture parity

The preview now uses the full center's horizontal wheel/trackpad axis detection,
18px accumulated threshold, one transition per gesture, ScrollEnd reset and
450ms idle reset for phase-less wheels. Native pages slide in a clipped Row
with the same reduced-motion-aware easing. Horizontal pointer drags use the
same 40px release threshold and overshoot resistance. Existing player seek
drags keep their grab and disable page gestures; page drags also keep the
preview open. No repeated idle timer is introduced.

Live synthetic horizontal-wheel input produced 0→1 and 1→0 transitions in the
running preview. A concurrent physical touchpad gesture also produced a
recorded 0→1 transition; this changed the page before the synthetic script's
final assertion, so that combined script run is not reported as a full pass.
Strict QML lint passed.
