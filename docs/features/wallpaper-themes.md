# Wallpaper themes — 2026-10-20

The approved layout is `assets/reference/themes-wallpapers-approved.png`. The
whole-desktop comparison is `assets/reference/environment-themes-approved.png`.
The actual settings window is captured in `assets/reference/themes-implemented.png`.

## Collection and controls

The six bundled landscapes are Alpine Dawn, Moon Lake, Forest Mist, Warm Desert,
Northern Lights and Rose Sunset. `assets/themes/*.json` contains their coordinated,
art-directed palettes and five preview swatches. These keep the dark surfaces and
text readable while matching each landscape. Generation provenance and prompts
are in `assets/wallpapers/prompts.json`; all images are 1672×941 PNGs.

Settings → Themes and wallpapers displays two columns of cards, a draft desktop
preview, swatches and the “Colors from wallpaper” switch. Selection changes only
the preview. Apply changes the image and palette together. Cancel discards the
draft; closing with a draft asks before discarding. The settings application stays
an independent, fixed 1100×800 floating window.

“Own wallpaper” imports a PNG/JPEG/WebP, validates/decodes it using Pillow, copies
it to the private `~/.config/poly-shell/wallpapers` directory and extracts a
repeatable, contrast-oriented palette from a reduced, quantized pixel sample.
Removing the original source does not break the imported wallpaper. Duplicate
imports reuse the image hash and gallery entry. Private imports never enter the
repository. Disabling automatic colors retains the previous palette while the
wallpaper changes.

## Shared theme system

`Session.palette` prefers the selected appearance palette. Work/Vibe still owns
behavior/motion and retains its profile colors as a fallback before a visual theme
is selected. Theme changes preserve the current mode, visual geometry, application
commands, organizer data and hardware settings.

`shell/theme/Theme.qml` supplies semantic colors and resolves the older Alpine
material shades. Its explicitly imported module avoids stale implicit singleton
metadata during a live reload. The bar, popups, launcher, organizer/music, OSD,
settings, mountain shapes and crystal marks use these bindings. The generated
settings ridge and Hyprlock clock frame follow the chosen palette.

Application styling includes user GTK3/GTK4 palette imports, color directives in
the existing Kitty/Foot configs, named inherited folder/application icon themes,
Hyprland window borders, Mako and Hyprlock. Existing unrelated settings and config
symlinks are preserved. Cursor and third-party icon packages are not overwritten.
User-local icon links point into the repository-owned theme assets. Applications
that cache toolkit styles may need reopening; browser/IDE content with its own
independent theme remains controlled by that application.

## Theme-specific landscape shapes

Settings headers, menu/launcher ridges and the two clock decorations now use
`poly_shell/landscapes.py`: Alpine peaks, a twin moon ridge, forested foothills,
dunes/mesas, serrated glaciers and terraced coastal cliffs. Imported wallpapers
receive a stable profile variation. Palette colors are used directly for the
facets, so shape and color vary together while controls and geometry stay fixed.

The previous settings ridge was rewritten at a constant URL, which let Qt show
a cached image from the previous theme. New assets live under
`~/.local/state/poly-shell/landscapes/` with a digest of theme identity, palette
and renderer version in the filename. Settings, menus and clock decorations now
receive a different URL whenever their actual appearance changes. Refresh/mode
switches resolve the same saved assets. The assets are small static native SVGs;
there is no per-frame generator or extra blur effect.

Four regression tests verify six different geometries, semantic colors, cache-key
changes on recoloring, stable custom profiles, mode persistence and removal of new
assets during rollback. The suite now has 76 tests. A live GUI switch between Moon
Lake and Warm Desert confirmed both the header color and silhouette changed; the
previous selected theme was restored afterward.

## Apply and recovery

`poly-shell theme list`, `theme import '{"image":"/path/to/image.png"}'`, and
`theme apply '{"id":"moon-lake","colorsFromWallpaper":true}'` share the GUI backend.
Applying `alpine` restores the default collection palette and wallpaper.

The backend validates the theme and holds the same lock as mode/appearance writes.
It prepares toolkit, compositor and lockscreen text, saves original files and a
path-to-backup manifest under `~/.local/state/poly-shell/backups/theme-*`, writes
styles, applies runtime borders, starts the independent wallpaper service and
publishes the QML session last. Ordinary write/startup failures restore prior files,
borders and wallpaper. This is recovery from ordinary process/IO errors, not a
cross-file power-loss transaction. Icon notification is performed after commit;
a failed native settings notification is returned as a warning.

The wallpaper renderer stays in its own `poly-shell-wallpaper-*.service`; closing
settings cannot kill it. The existing Hyprland autostart restores the saved image.
The generated appearance include also sources the saved border palette on reload.

## Validation

- 72 Python tests: six complete palettes, custom image import/invalid input,
  deterministic extraction/deduplication, geometry and mode independence,
  disabled automatic colors, exact rollback at each theme-file write, renderer
  failure, final-publication failure, terminal setting preservation and prior
  wallpaper/appearance regressions.
- The full `scripts/check` passes. QML checks include the separate theme module.
  The existing GlobalShortcut/PostReloadHook metadata warning is suppressed only
  for the tiny NativeShortcut wrapper; all remaining QML retains strict import
  checks. The old source-comment workaround did not suppress that upstream issue.
- Live pointer click applied Moon Lake through the GUI. The actual compositor
  border gradient, selected icon theme, saved wallpaper and session palette match.
- Closing/reopening settings retained Moon Lake and the same independent renderer.
  Repeated forced maximize/fullscreen attempts return to 1100×800. The restoration
  handler is deferred and guarded, with a cooldown check to cover startup races.
- A settled 2-second observation measured one CPU tick (~0.5% of a CPU core) for
  the settings process; this is a short idle sample, not an interaction benchmark.
  No forced redraw, repeated palette sampling or continuous blur preview exists.
- The GTK4 palette parses, Foot accepts its config and Hyprland has no config errors.

A full logout/login and sleep/resume were not performed. Original source/control
backup: `~/.local/state/poly-shell/backups/wallpaper-themes-20261020-124657/`.
