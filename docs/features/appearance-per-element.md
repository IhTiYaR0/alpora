# Appearance by element — 2026-10-21

Implemented from `assets/reference/appearance-per-element-proposal-v1.png`.
Open **Settings → Внешний вид**. The existing 1100×800 floating settings
application now selects Windows, Bar, Menus, Widgets, Launcher or Notifications.
Controls accept sliders and typed numbers. A theme-aware preview follows the
draft; light/dark buttons change only its backdrop. The fixed footer remains
visible while the control list scrolls. Changing elements returns the list to top.

## Connected controls

| Element | Controls |
| --- | --- |
| Windows | Active/inactive whole-window opacity, rounding, outer workspace margin, inner gap per side |
| Bar | Background opacity, rounding, outline, shadow strength, height, independent left/right/top margins, reserved space below |
| Menus | Background opacity, rounding, internal padding, outline, shadow strength, open/close duration |
| Launcher | Independent background opacity, rounding, internal padding, outline, shadow strength, open/close duration |
| Widgets | Background opacity, rounding, outline, shadow strength, reveal duration, decorative-motion switch |
| Notifications | Background opacity, rounding, outline and padding for center cards and Mako popups; shadow for center cards |

The blur enable/size/pass controls remain **global**, explicitly labeled
«Общее размытие». Panel/launcher layer rules now use natural backdrop blur
(`xray = false`), replacing the previous wallpaper-only cache. Widgets
retain their separate namespace without compositor blur. Application opacity
affects text and icons as well as backgrounds. No independent application-content
blur preview is promised. Decoration/motion previews are illustrative, without
continuous offscreen blur rendering.

All colors use the live semantic palette, including Timeline intermediates.
Work/Vibe and theme selection stay independent of visual preferences.
Reduced motion takes precedence over configured durations; widget motion also
respects its existing switch in the Widgets page and coverage/sleep behavior.
The previous 92% menu-opacity floor was removed so saved opacity is effective.

## Persistence and compatibility

43 validated visual values are stored in the existing schemaVersion-1 visual.json.
Old files merge new defaults without being rewritten during reads. Existing bar
geometry in settings.json is preserved until explicitly saved through Appearance;
launcher rounding inherits the previous shared menu radius during migration.
Window rounding remains 0–32 px, bar rounding 0–20 px, other radii 0–32 px.
Outlines support 0–3 px and shadow intensity 0–100% (zero disables it).
Open/close durations support 0–800 ms (zero is immediate).

Reset Element touches only that element's fields; shared blur stays independent.
Cancel discards the whole draft. Apply validates the optimistic base, applies and
confirms compositor options, writes generated Lua/visual values/Mako styling and
publishes the session last. Notification-style writes participate in rollback.
Mako reload is best effort because the notification daemon is optional.

Liquid panel border width and shadow intensity are shader uniforms. Native card
shadows use bounded rectangles. Widgets have an 8px transparent surface gutter
for shadows while their original content bounds and pointer masks are preserved.
The supplied viewport dimensions and current layer architecture limit very large
shadows; no costly full-screen shadow/blur surface has been introduced.

## Verification

- 111 Python tests passed, including old geometry migration, new value/type
  rejection, preservation across modes, notification style output and rollback.
- `scripts/check` passed, including strict QML lint; shaders rebuilt successfully.
- Isolated offscreen real-QML check instantiated all six element pages and
  verified available fields, element-only reset and cancellation.
- Visually inspected the running settings app and corrected footer overflow at
  1100×800. Live saved/effective appearance values agree and the settings app
  reports no save error. Hyprland reports no configuration errors.
- No new runtime QML errors or missing-icon errors after the final corrections.
  Existing portal/text-input diagnostics still occur.

Not measured: fresh animation frame timing at all user-selected blur settings,
physical sleep/resume, fractional scales and smaller-monitor layouts. Initial
configuration backup: `~/.local/state/poly-shell/backups/element-appearance-20261021-161510/`.

## Wheel scrolling fix

Sliders embedded in Appearance, Widgets and system settings disable wheel input.
Mouse-wheel and touchpad scrolling reach the enclosing ScrollView instead of
changing the value under the pointer. Dragging, keyboard input and numeric fields
remain available. Quick-control popup sliders keep their existing wheel behavior.
Strict QML lint passed for the three changed settings components.

## Performance and application integration follow-up

See [settings, theme and natural-blur corrections](settings-followup-2026-10-21.md)
for terminal/settings rendering exceptions, native theme refresh, Wi-Fi icons,
launcher focus corrections and measured performance limits.

## Bar and window spacing

Bar controls now expose independent left/right margins (0–128 px), top margin
(0–64 px), and reserved space under the bar (0–128 px). Old shared barMargin
values migrate to both sides; the existing 8 px lower reserve is preserved.
Quick settings align to the right margin, launcher to the left; panels continue
to anchor next to the bar. Desktop widget safe bounds include the lower reserve.

Windows expose outer workspace margin (0–128 px) and inner gap (0–64 px per
side). Hyprland adds each neighboring window's inner gap, so a value of 5 means
a 10 px space between windows. These settings affect tiled windows; the outer
margin is measured from the usable workspace below the reserved bar area. Both
are written into the generated Lua include and verified through compositor CSS
gap readback, with the existing transactional rollback. Preview shows two windows
and their gap. Settings remain independent of themes and Work/Vibe.

Verified 124 Python tests and strict QML lint. Live apply/readback confirmed gaps
11/23 and bar geometry with asymmetric 34/52 margins, top 18 and bottom 24
(reserved bar height 82). Original spacing was restored after verification.
Visually checked the running Windows and Bar appearance pages at 1100×800.
