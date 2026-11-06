# Timeline theme

Select **Настройки → Темы и обои → Timeline · Время суток → Применить тему**.
A sun button appears next to the clock in the top bar only while this theme is
selected. Clicking it opens a compact popup with one 24-hour slider and time
labels. There are no image thumbnails or wallpaper choices in the popup.

Dragging the slider blends the desktop wallpaper directly between six registered
lighting states of one alpine lake scene. The system clock, widget placement and
behavior mode stay independent. Close by clicking outside or pressing Escape.
Wheel and keyboard changes also work. Time persists in
`~/.config/poly-shell/timeline.json` and is restored after reopening the popup,
restarting the shell, or selecting the theme again. Selecting a different theme
closes the popup and removes its button and background surface.

States: night 00:00, dawn 05:30, morning 08:00, day 13:00, sunset 18:30, dusk 21:00.
Dusk blends back to night at 24:00. The initial position is sunset (18:30).
Each lighting state has its own semantic palette. Shell colors interpolate with
the same smoothstep weights as the wallpaper while dragging. After release or
400 ms idle, the saved time, GTK/terminal colors, notification/lock styles, ridge
art and Hyprland borders update in one rollback-capable transaction. No wallpaper
renderer restarts and no system files are written for individual drag frames.
The existing automatic-colors switch is respected. Applications that cache their
configuration may require reopening to show saved colors.

All six images load once, with the same aspect ratio and dimensions (1672×941),
and blend as two GPU textures. A short smoothing animation follows the slider;
there is no idle render loop, video, subprocess per slider movement, or shell
restart. A static sunset renderer is the fallback while textures load. After every
monitor is ready, an acknowledged handover removes only that owned static
renderer, so it cannot cover the dynamic layer. Other wallpaper processes are
left alone by the handover. Switching to a normal theme launches its usual static
renderer again. The background takes no keyboard or pointer input. The
existing reduced-motion preference disables extra easing without breaking
manual slider control. Position writes are atomic, queued/coalesced, and reject
requests while a different theme is selected. Disk errors are shown in the popup.

Validation: 98 Python tests and strict QML lint; 1,441 minute positions and every
segment boundary checked, including the midnight wrap. Live isolated preview
confirmed six textures ready, endpoint transitions, saving and reopening. Main
shell validation also covers bar button, popup, real slider and switching themes.

## Image provenance and prompts

Built-in imagegen was used, not the API/CLI fallback. Base image:
`assets/wallpapers/alpine-dawn.png`, copied unchanged to
`assets/wallpapers/timeline/sunset.png`. Five lighting edits were saved beside it:
`night.png`, `dawn.png`, `morning.png`, `day.png`, `dusk.png`.

Shared final prompt: edit only lighting, sky illumination and celestial sun/moon
of the supplied alpine low-poly lake. Preserve the original camera, framing,
16:9 composition, mountain outlines/facets, trees, island, lake horizon and shore
edges; do not move, crop, simplify or add terrain. Preserve detailed illustration
style, crisp edges; no text, UI, borders or watermark. Pixel registration is the
target, although generated relighting can introduce small local variations.

Variant prompts:

- **Night:** midnight navy/slate blue, subtle stars, soft silver moon at the old
  sun location, silver reflection; no orange daylight, readable dark terrain.
- **Dawn:** 05:30, sun below horizon, lavender/rose mist, pale pink horizon,
  first pink mountain light, cool shadows.
- **Morning:** 08:00, clear pale blue sky, soft golden daylight, sun above the
  original horizon at upper right, remove the old sunset disk/reflection.
- **Day:** 13:00, bright blue sky, neutral daylight, sun out of frame, natural
  mountain/greenery color and blue/silver water; no sunset glow.
- **Dusk:** 21:00, no sun disk, violet/blue twilight, soft fading rose horizon,
  first faint stars, dusky shadows and lavender reflections.

CLI diagnostics: `poly-shell timeline get`,
`poly-shell timeline set '{"minute":1110}'`; the set command requires the active
theme to be Timeline. QML IPC target `timeline` exposes `status` and `setTime`.

Verified renderer readiness on 1920×1080 and 3840×2160 outputs; switching away
hides the icon, returning restores the saved minute, and acknowledged
static-to-dynamic wallpaper handover completes on both outputs.

Palette validation: Python and QML interpolation match at all 1,440 minute values;
night/day/sunset propagation, behavior-mode persistence, automatic-colors opt-out,
and rollback of all generated files/time after publication failure are tested.
