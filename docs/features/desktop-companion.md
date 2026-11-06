# Грань — desktop companion

Грань is a native articulated robot on the top bar, enabled by default for this
installation. Its beveled metal armor, painted panels and face display use the live
semantic accent, secondary, cool, surface and text colors, including Timeline's intermediate
palettes and imported themes. Work/Vibe and the ordinary widget configuration
remain independent.

Settings → Widgets contains a live preview, a visibility switch, **Активный
характер** and **Полёты по рабочему столу**. Active behavior favors walking, playing and stretching; calm behavior
includes more sitting and short naps. All choices save immediately to
`~/.config/poly-shell/companion.json`, shared by the shell and separate settings
process. Hovering the robot pauses its travel both on the bar and in flight, without a
tooltip. Ordinary short clicks greet the user; they no longer launch a trip or
throw the robot. Flights start autonomously when enabled.

The autonomous scheduler has eleven activities: walking, looking around,
stretching, checking its mechanisms, catching a crystal, balancing, sitting, napping, dancing,
charging and greeting. It chooses a different activity every few seconds. Audio
and battery reactions use MusicState and Session's native device state, including
ending a dance when playback stops and ending a charging reaction when charging
stops. The charging pose includes a small cable. It does not claim to monitor
application downloads or to synchronize dance steps with an audio spectrum.

## Detailed robot artwork

The companion is a humanoid robot with a softly beveled head, dark face display,
animated LED eyes and mouth, side sensors and an antenna. The torso has separate
armor planes, a recessed luminous core, service screws, vents, a battery pack,
a charge indicator and a ribbed neck and waist.

The bar figure is approximately 14% smaller than the original robot, with its
feet kept on the same bar baseline. A slightly larger head, rounded bright eyes,
a small smile and happy curved eyes during greeting/play give it a friendly
expression. Armor is tinted with the current semantic accent, with secondary
color cheek indicators. Hover interaction has no tooltip.

Both arms have a shoulder, upper-arm plate, elbow, forearm, wrist, palm, three
fingers and a thumb. Waving rotates the arm at the shoulder and elbow; mechanism
inspection folds the right arm toward the chassis. Both legs independently move
through a hip/knee/ankle chain with shin armor and treaded boots. The walk cycle
swings arms and legs in opposition. The figure remains upright when changing
direction; the face looks in the travel direction instead of mirroring its parts.

The entire drawing remains native QML and follows the semantic palette.
[Robot detail preview](../assets/reference/companion-robot-preview.png).
Joint smoothing uses `CompanionTween.qml`, sampled from the existing bounded
behavior clock. Shoulders retain 180 ms ease-in/out, flight blending 240 ms
ease-in/out and banking 130 ms linear interpolation. Continuously changing targets
do not restart native NumberAnimations. Greeting, play, dance and servicing use
the same 16 ms clock as travel; quiet poses retain the 33 ms clock. The vector
paths, materials and CurveRenderer are unchanged; no texture cache is used.

Controlled samples with widgets occluded reduced whole-shell CPU from about
40% to 11–12% of one core during greeting and from 44% to 16% during flight.
With all widgets exposed, whole-shell CPU remained about 38–40%; this change
does not resolve that separate cost. See [measurement conditions and raw data](performance-evidence/companion-tween-2026-10-22/README.md).

## Flight and desktop walking

Flights have their own immediately saved switch. Existing version-1 preferences
without that field continue to load. Destinations now include actual widget and
window top edges, plus the lower desktop edge. Raised destinations are preferred;
the robot lands, looks around, walks within the legal edge interval and visits
another surface. Every fourth visit returns to the bar. Low battery prevents
new trips and recalls the robot; disabling flights also recalls it smoothly.

`CompanionSurfaces.js` uses the configured widget rectangles and native Hyprland
client geometry, current workspace, pinned state, stacking priority and monitor
origin. Covered edge sections are removed, rounded corners have clearance, and
positions above a tiled window are restricted to the unused bar lane. A closed,
hidden or newly occluded support triggers a continuous departure. Source-relative
anchors follow a moved/resized window without teleporting between visible edge
fragments. A narrow support without room for both feet is excluded.

Window geometry refresh uses native IPC, with no `hyprctl` subprocess per frame.
While attached to or approaching a window, refresh is normally 100 ms and briefly
16 ms after geometry changes; other travel uses 400 ms. Refresh pauses at home,
while hidden and in reduced motion. Compositor events also request a refresh.
This is bounded sampling rather than compositor-frame synchronization.

Flight uses pixel-based speed, minimum-jerk easing, speed-based banking, a separate
final descent and blended thrusters/limbs. The walking phase advances with distance,
not wall-clock time. Two-link leg inverse kinematics keep ankles on a shared foot
baseline; stance feet remain level and returning feet lift. Landing briefly bends
the knees while preserving that baseline. Attached-window motion does not advance
the walking phase. The figure remains native and follows every theme.

[Standing on a widget](../assets/reference/companion-widget-standing.png).
[Standing on a window](../assets/reference/companion-window-standing.png).

## Picking up and throwing

Press any part of the robot, drag it and release. One padded hit box includes
the full figure, including hands and feet, on the bar and elsewhere on the
desktop. Approaching it pauses the route before the press so it cannot escape
under the pointer. Surrounding content receives normal input. A short click
only greets: it cannot accidentally launch a flight or create a throw. No hover
tooltip is displayed.

The press immediately freezes both autonomous flight and any existing recovery,
but a drag begins only after 4 logical pixels of movement. Until then the robot
holds its pressed pose without changing position. Holding still for at least
180 ms and releasing produces a gentle drop; slight jitter during a quick tap
does not count as a drag. The grip offset is preserved when dragging, including
when catching the robot during a rescue. Release processes the final pointer
position and clears the gesture; cancellation discards the throw velocity.

During a hold it hugs the pointer, swings its legs and tilts with hand movement.
Throw velocity comes from actual motion events, with stale velocity decaying if
the user holds still before release. A release produces a short ballistic fall,
with swept collision against the exposed support edges. Crossing an edge lands
on it with zero residual velocity. Missing every edge leads to engine braking
and self-righting. A fast throw additionally produces a
shake and a folded-arm expression before it resumes its route or returns home.
Rescue works even with autonomous flights disabled. Reduced motion disables
throw animation. Disabling/hiding the companion cancels any held gesture.

`CompanionThrow.js` clamps elapsed time, velocity, tilt and screen bounds and
substeps acceleration. It has no input hooks, processes or timers of its own.
A single UI timer drives the simulation at about 60 updates/s during interaction,
60 during travel/walking and 30 while resting on the bar. Simulation freezes while the robot is
hidden. Rescue hands its actual position back to the travel state machine.

[Hold, throw, rescue and reaction poses](../assets/reference/companion-throw-preview.png).

## Placement and lifecycle

`TopBar.qml` derives two free lanes from the actual workspace, clock, Timeline and
status geometry, and gives the larger lane to `DesktopCompanion.qml`. The visual
surface always remains a small, input-transparent native window. A separate small
transparent input surface has a padded hit box covering the full robot silhouette.
It follows the robot before a press, freezes its origin during the gesture and
converts local events back into screen coordinates. It has no painted items and no full-screen buffer. Keeping
input coordinates independent of the moving visual window prevents pointer jumps
when the robot is picked up. The native mouse press remains implicitly owned
until release/cancel; there is no keyboard focus or compositor focus grab.

This replaces the earlier fully click-through flight: the robot itself is now
interactive in flight so it can be caught. The area around it still passes all
input to applications and widgets. It uses the configured widget monitor, falling
back to the first connected monitor. A bar without enough home space hides it.

Bar panels leave the robot visible, moving and interactive. Hovering the robot
itself still pauses travel so it can be picked up.
Both surfaces hide and the timer pauses while disabled, while overview
is open, during sleep, on a DPMS-disabled monitor or a fullscreen workspace.
Global reduced motion immediately resets to a static robot at home. Resuming
motion does not catch up hidden time. No pointer polling, screen capture,
full-screen effect texture or particle emitter is used.

## Input regression correction

A native pointer audit reproduced a miss when pressing the feet. The previous
head/torso regions were narrower than the animated figure. Flight also kept
moving on hover, and a short click could launch the robot just as the user
tried to pick it up. The hit box, hover pause and click/drag split above correct
those three problems.

`scripts/check-companion-input --live` exercises six capture points, small tap
jitter with flights enabled, pausing in flight, actual zigzag drag, committed
compositor window coordinates, re-capture during rescue, stationary holds,
disabling during drag and normal bar interaction outside the companion. It
restores preferences and the pointer. Native strong-throw verification also
passed through braking, recovery, shake and the folded-arm reaction. These
checks also cover the redesigned surface-aware movement.

## Validation

- `scripts/check` runs the complete unit suite and strict QML lint. Companion
  simulations cover route continuity, exact foot planes, walking bounds, moving
  supports, changed occlusion fragments, disappearing targets, workspace and
  monitor coordinates, partial occlusion and swept drop collisions. Existing
  behavior, power/music, input and throw checks remain in place.
- A native offscreen QML test checks tween retarget continuity, settled values,
  the one-hour clock wrap, frozen time, linear interpolation and reduced motion.
- `scripts/check-companion-surfaces --live` uses a temporary Foot window and the
  actual mouse. It verifies widget and window landing, a gentle drop onto the
  window, carrying the passenger when moved, safe resizing and takeoff when
  closed. It restores focus, cursor and flight preferences.
- `scripts/check-companion-input --live` verifies the existing capture, hover,
  gesture cancellation, rescue and ordinary bar-input contracts. Rescue is
  explicitly exercised away from support edges, since dropping above an edge
  can now land instead.
- Native captures show the current robot standing on a widget and window.
  Physical multi-monitor hotplug and suspend were not forced. Geometry sampling
  can trail a moving window; it does not claim compositor-frame attachment.

Historical load captures predate this movement rewrite and do not establish its
current frame pacing or power cost. The exploratory flight load sample interrupted
by reload remains excluded in `performance-evidence/companion-2026-10-22/flight-load.json`.

Raw load captures: `performance-evidence/companion-2026-10-22/load.json`.
[Settings preview](../assets/reference/companion-settings.png).

IPC: `companion.status`, `companion.enable BOOL`, `companion.lively BOOL`, `companion.flights BOOL`,
`companion-SCREEN.status`, `companion-SCREEN.greet`, `companion-SCREEN.takeOff`
`companion-SCREEN.visitSurface ID` and `companion-SCREEN.returnHome`.
Status includes legal support intervals, the selected support and the foot plane.
