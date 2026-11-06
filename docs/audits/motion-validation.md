# Panel motion — 2026-10-19

The current renderer lifecycle and performance policy are described in the
[2026-10-20 performance correction](performance-2026-10-20.md). It supersedes
the earlier always-mapped/always-prepared surface policy below.

## Selected study 03: Wings — 2026-10-20

The user selected Motion Lab 03 (two wings). Launcher, My Day, notifications,
tray overflow and quick settings now use the same stem-to-wings trajectory.
Opening is 520ms and closing 220ms; reduced motion remains immediate. The
shape-preserving Hermite curve and global quintic easing follow the approved
browser study. The start is captured from the actual bar button and retained
through reversals. Shared popup pages finish closing before changing layout.

`UnfoldPanel` uses a render-thread `UniformAnimator` and the baked
`shaders/wings.frag.qsb` resource inside the shell config root (resources outside
that root are intercepted by Quickshell's VFS). Controls remain at their final
size and position. A content texture supplies the moving rounded aperture;
ordinary controls render at rest. The effect has no blur/multipass filter and
its node stays prepared with zero output while idle. A shader failure falls
back to an immediately usable native panel. The existing Hyprland glass rule
continues to provide background blur.

The shell selects Qt's threaded render loop and
`QSG_USE_SIMPLE_ANIMATION_DRIVER=1` to keep GUI and render-thread animations
on elapsed time across multiple windows. Normal swap throttling is retained;
disabling it caused excessive redraws during the effect and was discarded.
Wayland/Hyprland still owns presentation.
This was retained after live comparison: the initial implementation yielded
roughly 10–16 window-swap callbacks during a 520ms opening; the revised effect
usually yielded 28–37. QML callback delivery can batch on the GUI thread: short
captures still included outliers up to 295ms. These callback counts/intervals
are diagnostics, **not proof of compositor FPS or a guarantee of no stutter**.
Do not report queued callback p95 values of 2–8ms as presentation latency.
GPU/compositor presentation under arbitrary desktop load remains unverified.

Validation:

- `check-wings-motion --live`: final geometry, closed endpoints, effect error
  state, shared-panel switching and rapid close/reopen passed on eDP-1 at 60Hz.
- Intermediate and open desktop captures verify that the stem is actually drawn
  before the full panel; this caught and fixed the initial VFS resource error.
- `check-launcher-input --live`: all 12 immediate US/RU input attempts passed,
  plus rapid reopen/search reset. The virtual keyboard layout was restored.
- Physical bar clicks (using runtime button bounds): launcher → calendar →
  quick settings → close passed. All popup windows now use on-demand keyboard
  focus with a native focus grab that includes the bar; exclusive layer focus
  had prevented the right bar button from receiving pointer events.
- A short 1.5-second closed-panel sample used approximately 2% of one CPU core;
  this is a spot check with the desktop running, not an isolated benchmark.
- Updated QML components pass lint without warnings. The full project's existing
  upstream `NativeShortcut` / `PostReloadHook` metadata warning is unchanged.
- 44 Python tests passed during this implementation.

The native frame sampler is opt-in and stops automatically. No perpetual
animation timer or self-updating capture is used while closed.

Qt references: [UniformAnimator](https://doc.qt.io/qt-6/qml-qtquick-uniformanimator.html),
[texture caching and input](https://doc.qt.io/qt-6/qml-qtquick-shadereffectsource.html).


## Current launcher: capsule → unfolding surface

The launcher now implements the approved four-stage reference with
`UnfoldPanel.qml`: a small rounded seed widens into the search capsule during
the first 30% of opening, then its lower edge expands to the full panel. The
vertical phase starts at 24%, providing a small overlap rather than a stop
between phases. Geometry uses cubic easing; opening is 360ms, closing 170ms.
The top-left anchor never moves. The sage border briefly catches light as the
lower edge expands; the reflection settles at the end.

Only the glass rectangles, their small shadow and an inset clip change size.
The application layout, text size, icons and input target remain full-size and
stationary. There is no live texture capture, effect shader, text scaling or
per-frame control layout. The inset rectangular clip stays within the rounded
surface corners; content is revealed behind the moving edge, not over it.
The search ancestor remains visible at zero opacity so the native focus grab
can accept typing immediately. Reduced motion goes straight to the final state.

`PanelMotion` now chooses animation duration from `Behavior.targetValue`, not
the separately updated `opened` binding. The previous binding ordering could
start opening with the closing duration (170ms), compressing the capsule phase.

`scripts/check-launcher-unfold --live` samples actual QML geometry through IPC:
fixed anchor, width-first capsule, monotonic opening, final dimensions, unchanged
search font size, rapid reversals and closed/reset state. Intermediate desktop
captures confirm the capsule, partially revealed cards and final rounded panel.
This check is separate from timing probes; screenshot/IPC capture overhead must
not be interpreted as presentation timing. Keyboard input and frame timing are
retested with the existing scripts described below.

Live capture after the duration correction (three cycles, no screenshot capture
running concurrently): launcher 157 samples, median 16.02ms, p95 16.82ms,
max 17.43ms, no intervals over 25ms. Immediate US/RU typing passed 12/12 and
rapid reopen cleared the search. Calendar p95/max 16.79/23.42ms, notifications
16.60/17.48ms, quick settings 16.97/48.85ms (four intervals over 25ms). These
are short GUI animation-driver diagnostics, not compositor FPS guarantees.
The existing upstream NativeShortcut metadata lint warning remains; the new
unfold components lint cleanly. The 44 Python tests pass.

Calendar/notifications and quick settings still use native `PanelReveal`
glide/scale; their appearance is not redesigned by this launcher change.

## Earlier native-glide revision and baseline

Previous revision: the original rounded panel glides 24px from its trigger,
scales from 94% to full size over 360ms, and becomes opaque over 180ms. Closing
takes 170ms. There is no corner/hexagonal mask, text rotation, or live offscreen
capture. PanelReveal now uses native OpacityAnimator, ScaleAnimator and YAnimator
on the real controls. Reduced motion sets all durations to zero. Click/hover
feedback is preserved; independent per-card entrance timelines are removed so
they do not compete with panel movement. Resting geometry/palette are unchanged.

Launcher, calendar/notifications and quick settings keep their mapped surfaces
ready with empty pointer masks while closed. Hidden panels are fully transparent;
only an opened panel requests keyboard input. This avoids repeated graphics
context/surface setup during opening. The launcher retains its separate native
focus-grab fix for immediate typing.

AppCatalog builds an optional raster cache outside the GUI process using the
selected GTK icon theme. Original third-party SVG files are never changed. The
cache key includes theme, resolved source path, source timestamp/size and raster
size; source/theme updates invalidate it. Cache failure falls back to original
icons. On this desktop 87 distinct installed-app icons resolve, using under 2MB
of cache. Search/cards load their PNG thumbnails asynchronously instead of
running complex SVG filters during reveal. Cache key behavior has unit tests.

`scripts/check-panel-motion --live` captures GUI animation-driver intervals via
FrameMetrics while cycling all four panels. The sampler is off by default and
has a 15-second safety timeout. This is not a compositor presentation/FPS trace.
An initial shader replay had p95 22.6ms and a 107.5ms maximum. Native movement
removed the offscreen pass, but the first trial alone did not improve timing;
cached surfaces and icons were added after measuring individual panels. Short
captures still have outliers and are not a promise of perfect 60Hz delivery.
Actual intermediate PPM screenshots verify visible movement, not just an end
state. Immediate US/RU typing is rechecked with check-launcher-input.

Final clean-restart capture (three open/close cycles per panel): launcher p95
16.93ms / max 48.62ms; calendar 16.76 / 44.01; notifications 16.82 / 22.50;
quick settings 16.69 / 16.95. None exceeded 50ms in that capture. This is a short
diagnostic sample, not a guarantee for every application/system load. All 12
immediate-input attempts and rapid-reopen reset passed after the changes;
44 Python tests pass. QML lint retains the documented upstream NativeShortcut
metadata warning, with no new motion-component lint errors. The service is
active with zero restarts and Hyprland reports no configuration errors.

The old shader sources/QSB files remain as historical assets and are no longer
loaded by any shell component. References:
[Qt Animator render-thread behavior](https://doc.qt.io/qt-6/qtquick-visualcanvas-scenegraph.html),
[frame interval diagnostic](https://doc.qt.io/qt-6/qml-qtquick-frameanimation.html).

Earlier validation below describes preceding revisions; it is kept as history,
not the current animation specification.

Historical validation in the live 1920×1080 Hyprland session:

- QML lint passes with zero warnings across all components; both shaders compile.
- Intermediate screenshots show the geometric reveal for launcher, quick settings and
  calendar, followed by the unchanged resting surfaces.
- Quick settings details remain clickable; Escape dismisses the panels.
- Launcher outside-click dismissal passes after animated opening.
- Reversing the launcher three times before the transition finishes settles into
  the requested state and then closes normally.
- Pointer tilt originally exposed a Qt crash during handler reparenting. Handlers
  now remain children of their controls and only pass coordinates to the transform.
  The final live checks complete with the service active and NRestarts=0.
- Existing Qt Wayland text-input focus warnings remain; no shader, binding or
  JavaScript errors were observed in the final run.

Multimonitor, non-GPU rendering and fractional scaling were not exercised.

## Glass and transition cleanup

- `Glass.qml` shares translucent materials across bar, launcher, calendar, music,
  quick settings and their cards. Foreground text/icon opacity is unchanged.
- The `poly-shell-glass` Lua layer rule enables backdrop blur only on poly-shell
  namespaces, excludes alpha <= 0.2 (backdrops/shadows), and disables compositor
  layer animations so they do not compete with the QML reveal.
- Shared Hyprland blur is set to size 6 / 3 passes / noise 0.012; these shared
  blur parameters also affect other windows that already use compositor blur.
- Entrance tracks now settle within 480ms of the 540ms opening; their geometry
  stays within the cell bounds. Pointer tilt smooths both direction components.
- Initial opening sets launcher height without competing resize animation;
  subsequent search-height changes animate normally. New result sets reset scroll.
- Switching calendar/notifications/tray updates the page even if the shared
  popup window was already open.
- Live checks cover empty/restored search, quick-settings/calendar/notification
  switching and rapid reversals. Final service is active with NRestarts=0.
- Full project check passes: 30 tests and zero QML lint warnings. Hyprland reports
  no configuration errors. Runtime was checked after restart, including fixing an
  attempted Behavior on a readonly tilt property before the final run.

Layer-rule reference: https://wiki.hypr.land/configuring/core/rules/layer-rules/
