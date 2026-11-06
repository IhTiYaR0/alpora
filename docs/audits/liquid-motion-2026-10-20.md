# Liquid panel motion — 2026-10-20

Selected reference: demo 12, «Жидкое превращение».

All UnfoldPanel users (launcher, quick settings, calendar, notifications, tray,
Timeline) now share a small asymmetric bubble, expansion, and soft settling.
Opening takes 720 ms; closing reverses the same path in 460 ms. Cubic Hermite
segments share boundary tangents. Reduced motion uses zero durations.
The live text remains native at its final dimensions and fades in late enough
that it fits inside the expanding surface. No ShaderEffectSource, text scaling,
texture capture, or native/shader handoff is involved. One ShaderEffect draws
only the moving surface and a narrow analytical shadow. No timers run for the
animation after progress reaches its endpoint.

Panel windows include the bar button's vertical position so the initial bubble
is not clipped. Input regions still cover only the panel body. Existing dismissal,
focus management and the prepared launcher keyboard surface are preserved.
The owned Hyprland rule disables compositor animations for these panels to avoid
a second fade; blur remains disabled. Existing unrelated configuration is kept.

Validation: shader baking passed; scripts/check passed (104 tests plus strict
qmllint); hyprctl configerrors was empty after config-only reload. Calendar was
seen fully rendered, and a quick-settings intermediate bubble was captured.
The user was actively using their desktop and dismissed panels during checks;
there was no automated pointer, typing, workspace or repeated opening test.
The corrected top padding passed QML validation, but no complete visual run of
every individual popup was performed. Existing Qt Wayland text-input warnings
were observed; no liquid shader preparation errors occurred after shaders were
built and the QML configuration reloaded.

A 3.03-second passive sample with panels closed measured Quickshell CPU 0.66%
of one core and GPU gfx/compute 0.0%; total GPU mean 2.7%, median 0%. This is
short idle evidence, not an active animation frame-rate benchmark.

Backup: ~/.local/state/poly-shell/backups/liquid-motion-20261020/
Build shaders with scripts/build-shaders after changing GLSL sources.

## Origin correction

Replaced cross-layer mapToGlobal/mapFromGlobal with explicit screen-local body
positions. The bar anchor binding reads all ancestor x/y positions, so late Row
layout also updates the source. It no longer waits for a deferred global-position
snapshot. Passive IPC comparison confirmed button center equals body position
plus liquid origin: calendar (960,32), quick settings (1800.1484375,32), launcher
(47,32). No panel was opened or closed for this check. The 104 tests passed;
strict qmllint passed again after the final ancestor-position binding fix.

## Final synchronization fix

The experimental separate UniformAnimator/content animators were removed after
live validation exposed incorrect endpoint publication and premature content.
Final implementation uses one PanelMotion NumberAnimation for the shader, native
content clip/fade, and window mapping. The clip changes only its viewport; child
controls keep their native dimensions. Outline expansion is monotone without the
old intermediate stop/overshoot. Corners settle before native content fades in.
A narrow shader neck remains pinned to the bar-button center during expansion
and merges into the body at the end. Opening is 320 ms; closing is 200 ms.
There is no live texture capture, asynchronous visual handoff, or idle timer.

The 104 tests and strict QML validation passed. A live calendar cycle confirmed
opening progress 0.38125, settled progress 1, closing progress 0.6, and finally
progress 0 with presented=false. Screenshots confirmed content hidden during
initial expansion and visible at the settled endpoint. The passive frame-swap
trace of the earlier experimental version had irregular GUI signal intervals;
it does not establish a steady 60 FPS result for the final implementation.

## Launcher anchor curvature and shader cache

A launcher screenshot revealed that large blob corners displaced the visible
crest to the right despite the correct origin (screen 47,32). Corner radii now
respect the horizontal distance from the button anchor to each body edge, which
keeps the anchored neck connected to the expanding body. Both left corners are
limited for a left button; both right corners are limited for a right button.

A repeated screenshot initially still showed the old geometry: the live engine
was reusing the old shader URL after the binary changed. The build now emits
liquid-anchored.vert.qsb and liquid-anchored.frag.qsb; UnfoldPanel uses these new
URLs, forcing fresh shader loading without restarting the session. A new live
launcher capture at progress 0.365625 confirmed the left edge/crest directly
under its button instead of the old arc displaced far right. Shader baking and
strict qmllint passed. Future live shader changes must account for URL caching.

## Shared-window switching regression

Calendar, notifications, tray and Timeline shared an opened=true flag across
page changes, so changing blocks bypassed the liquid opening. Their displayed
page, geometry and source are now retained until the old motion reaches zero.
The latest requested page is then installed and opened from its own button.
The window remains mapped during this shared-page handoff; there is no separate
page fade competing with the panel animation. Newer requests supersede pending
destinations; returning to the old page reverses its current motion.

scripts/check-panel-switches --live passed all 30 directed pairs among calendar,
notifications, Timeline, tray, launcher and quick settings. Each pair checked
intermediate progress plus the settled endpoint; shared-page pairs additionally
checked the retained old closing page and the new opening page. Rapid queued
changes selected the last destination, and repeated clicks closed all six
blocks. Tests used IPC only: no pointer, key, workspace or device-setting actions.
These checks validate animation state/lifecycle, not visual FPS or click hitboxes.
The original panel selection was restored after the run. Evidence is stored in
docs/performance-evidence/panel-switches-2026-10-20/.

scripts/check passed (104 tests and strict qmllint). The older interactive bar
check was updated to account for shared close/open duration and its current Qt
animation implementation, but was not run on the user's active desktop.
