# Desktop widgets

Three desktop widgets follow the selected theme: a decorated clock/date on the
left, weather and an MPRIS music player on the right. The approved composition is
`assets/reference/desktop-widgets-approved.png` (generated with built-in imagegen).
The artwork is native theme SVG, not a screenshot used as functional UI.
The implemented settings page and widgets are captured in
`assets/reference/desktop-widgets-implemented.png`.

Open **Настройки → Виджеты**. Select a widget and drag it on the desktop preview,
or use its horizontal/vertical controls. The switch enables that widget. Choose
a monitor, then **Применить**; **Отменить** discards the draft. A close prompt
protects unsaved changes. **Сбросить позиции** resets positions while retaining
the chosen city and widget switches. Overlapping placements are allowed so the
user controls the composition. Positions are clamped to the available display.

Layout is stored atomically in `~/.config/poly-shell/widgets.json`, independently
of mode, wallpaper and theme changes. Horizontal placement is a percentage of
available travel; vertical placement is a logical pixel offset below the bar.
Cards scale down on small displays. The selected monitor is remembered; if it is
disconnected, the first available monitor is used until it returns. Settings use
the same geometry functions as the desktop preview. Optimistic concurrency
rejects saving a stale draft over another editor's changes.

Widgets use three small Wayland **Bottom** surfaces, zero exclusive zone and no
keyboard focus. Each surface is limited to its card. Application windows remain
above them, and empty desktop space passes through pointer input.

Weather uses the [Open-Meteo forecast API](https://open-meteo.com/en/docs) and
[geocoding API](https://open-meteo.com/en/docs/geocoding-api), with a city selected
in settings. There is no IP location lookup. The initial city is Алматы, matching
the approved reference. Requests have an 8 second timeout; successful forecasts
are cached for 30 minutes. Offline mode keeps the last forecast for the same
coordinates, visibly marked as saved. A different city never displays the previous
city's forecast. Failed requests retry once a minute while weather is enabled.
Disabled weather stops periodic requests. The provider is credited on the card.

Music uses the existing shared `MusicState` / Quickshell MPRIS integration.
Metadata, album art, transport and seeking reflect the active player. Unsupported
controls are disabled. With no player, the card shows an honest empty state.
Position updates run once per second only while a visible card is playing.

Validation: 85 Python tests and strict QML lint; 135 geometry cases over five
display sizes including portrait, default weather/music separation, actual
preview dragging and atomic save propagation, live Open-Meteo city search and
forecast, and a temporary MPRIS test service confirming pause, next, previous
and seeking over D-Bus. The temporary player is removed after the check.

CLI: `poly-shell widgets get`, `widgets apply '{"values": ..., "expected": ...}'`,
`widgets search '{"city":"Алматы"}'`, `widgets weather`.


## Motion and rendering

Music uses a miniature record sleeve/turntable composition. Album art preloads
in two image slots and crossfades after decoding, preserving the previous cover
during loading. The cover/record stage responds to pointer movement. Vinyl and
its groove highlight rotate during playback; the tonearm engages/retracts with
actual MPRIS play/pause state. Missing art uses the theme ridge and music glyph.

The seek wave is a decorative playback indicator, not sampled audio or a spectrum
analyzer. Its amplitude settles on pause; phase updates at 12.5 Hz during exposed,
animated playback. Position polling remains once per second, and seeking commits
on pointer release instead of flooding the player with writes while dragging.
Keyboard/wheel seeking still commits directly. All controls retain capability
checks; no-player state disables transport and seeking. Geometry stays 370×190.

Validated against a temporary live MPRIS endpoint: album art, cover parallax,
pause/resume, next/previous and a 126-second seek. The fixture was then removed.
Native rotation and decorative movement pause while covered, asleep or under
reduced motion/widget animation settings. Palette roles remain theme-derived.

Weather has a small layered scene with floating celestial/cloud artwork, theme
ridge depth, stars, fog ribbons, rain/snow fields and restrained storm light.
WMO condition codes drive precipitation; current day/night comes from the
provider's `is_day`, independently of the clock's decorative local-hour scheme.
All colors, including the native moon shape, use semantic theme roles.

Hover a forecast day to preview its daytime condition in the
scene. Click pins that preview; click again unpins it. The scene explicitly says
“прогноз”, while the main temperature and condition remain labeled “Сейчас”.
Condition changes crossfade; the day cards lift and highlight. Current weather
returns after hover ends unless a day is pinned. Missing/stale data and refresh
behavior retain the existing provider/cache rules.

The weather scene shares one 20 Hz phase with its primary glyph; the background
glyph stays static. Forecast glyph timers run only during hover/focus. Decorative
movement, parallax, preview fades and refresh rotation obey animation/reduced
motion settings, sleep and card coverage. Live checks cover motion, hover,
pin/unpin and suspension under a covering window.

The clock now has a native layered scene: theme ridge artwork at two depths,
drifting fog bands, moving light and particles, a floating sun/crescent, and a
second marker orbiting it. Pointer movement adds depth to the scenery, and a tap
sends a light ripple across it. Sun/crescent choice uses local hour (06–19); it is
decorative rather than an astronomical sunrise calculation.

Each changed time digit rolls independently, including the small seconds field.
The colon breathes once per second and the lower minute track fills continuously.
A local SystemClock ticks once per second only while the clock is exposed and
awake; the shared minute clock remains the fallback while covered. Scene motion,
digit transitions and smooth sweeps obey widget animation settings and reduced
motion. Vibe increases fog travel while preserving the selected palette and
widget geometry. Rendering remains within the small clock surface, with no blur
passes or full-screen redraws added.

Settings → Widgets → «Анимации виджетов» controls time/metadata fades, moving
clouds, softly pulsing sunshine, precipitation and the music playback indicator.
The meter is a playback indicator, not an audio spectrum analyzer. Motion also
respects the existing reduced-motion setting. Existing layouts migrate with
animations enabled, preserving city and positions; the preference is saved only
when settings are applied. A new test covers migration and preference validation
(86 Python tests plus strict QML lint).

A compositor-event-driven client snapshot suspends decorative motion and music
position polling when a window covers at least 97% of a card on its workspace.
This is a geometric heuristic, not a compositor occlusion API; multiple partially
covering windows and translucent windows are not modeled precisely. No frame-rate
client polling is used. The layout is split into separate card surfaces so cloud
motion does not redraw a full-screen transparent buffer. Native Qt Shapes use
CurveRenderer for smooth diagonals without full-screen supersampling. Images in
widgets resolve their source sizes from actual dimensions and device pixel ratio,
with filtering for downscaling; the clock landscape retains its aspect ratio.

Validated live: animation switch off/on while preserving layout and city, card
positions in Hyprland's layer geometry, suspension on covered and resumption on
empty workspaces. A short covered-desktop sample showed about 1% of one CPU core
and 0% Quickshell GPU engine activity; machine-wide GPU usage includes other apps.
The installed Wayland metadata treats Margins as opaque, so a narrow documented
qmllint exception is required around grouped layer-shell margins only.

Weather movement is capped at 20 updates/s, and the playback indicator at 12.5,
to avoid driving full 60 Hz frame updates for tiny decorative changes. Widget
surfaces use `poly-desktop-widget`, outside the broad shell live-blur rule; their
translucent material retains the existing palette without continuous blur work.
