# Center panel music page — 2026-10-19

The existing 700×550 center popup now contains My Day and Music in a horizontal
animated page strip. Bottom arrows, labeled tabs, drag and Alt+Left/Right provide navigation.
The selected page remains across popup closes and resets on a shell restart.
Scale, resolution and bar height were unchanged. The source backup is under
`~/.local/state/poly-shell/backups/20261019-124713-music-page/`.

## Verification

- QML lint passes with zero warnings.
- Real pointer drags switched in both directions. Navigation arrow and Alt+Left
  changed pages. Escape closed the panel after focusing its navigation buttons.
- Two temporary local D-Bus MPRIS services supplied distinct players. Real UI clicks
  reached play/pause, next/previous, player volume, shuffle and repeat methods/setters.
- Dragging the seek slider sent SetPosition; it did not accidentally change pages.
- Source selection switched player/metadata. A second source without seek, next,
  volume, shuffle or repeat support disabled those controls and showed cover fallback.
- Open player called Raise and closed the popup. Removing the temporary services
  returned the UI to its empty state; no test playback source remains.
- The fixture did not play audio and the session originally had no MPRIS players;
  no personal media state was changed. Actual browser/player compatibility beyond
  the installed Quickshell MPRIS contract remains application-specific.
- The known Qt Wayland text-input warnings still occur on focus changes. No new
  QML exception was observed in these interactions.

`~/.local/state/poly-shell/previews/music-mpris-check.png` is an integration-test
screenshot with temporary track metadata; it is not a real listening session.
`music-page-live.png` shows the final empty state after the services were removed.

The page controls an already running MPRIS-compatible player. It does not provide
music search, streaming, a playback queue editor or a bundled music library.

## Physical touchpad correction

The original mouse-drag checks did not validate physical two-finger scrolling.
The user reported that it still failed. Native SwipeView/Flickable snapping and
the added wheel handler were competing; mixed pixel/angle scaling also changed
sensitivity in the middle of a physical gesture.

CenterPanel now uses one animated Row rather than a native horizontal Flickable.
It accumulates pixel deltas, locks the gesture axis, commits at 18 logical pixels
and latches until ScrollEnd. A 450ms idle boundary is used only for phase-less
wheels. Vertical gestures pass to child lists. Pointer dragging has a separate
40px release threshold and does not steal an existing control's pointer grab.
Real touchpad events recorded by the running application showed transitions
0→1 at -19px and 1→0 at +18px without automated pointer movement. This is event
evidence, not a claim that synthetic mouse input validates physical touchpad feel.
QML lint passed after the change.

## Center layout refinement

Shared 52px header aligns the emblem, text and close button; the mountain motif
is smaller and less prominent. Calendar cells now form a fixed-height grid below
the month heading. The schedule column has slightly more width. Navigation is
grouped in one 34px footer. Music artwork is rounded at 200px and aligned with the
track/control group; utility controls use a compact 54px row. Both live pages were
visually inspected; the user's playback was not operated. QML lint passed. The
existing gesture-handling section was compared against the saved source unchanged.
