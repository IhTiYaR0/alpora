# Poly Alpine application styling

The user-local desktop theme uses the shell's graphite, sage and amber palette.

- Hyprland: 16px corners, 2px sage-to-amber active border, muted inactive border,
  22px soft shadows; existing blur and tiling gaps retained.
- GTK3: `~/.local/share/themes/Poly-Alpine/gtk-3.0/gtk.css`, based on the installed
  Adwaita dark resource, with semantic palette and control overrides.
- GTK4/libadwaita: `~/.config/gtk-4.0/poly-alpine.css`, imported at the end of the
  existing `gtk-Dark.css`. Existing light/dark files, assets and symlinks preserved.
- Kitty: shared palette in `~/.config/hypr/kitty.conf`; ordinary Kitty launches
  include it via `~/.config/kitty/kitty.conf`.
- Foot: matching ANSI palette and 92% opaque graphite background in
  `~/.config/foot/foot.ini`, using the installed Foot 1.28 `colors-dark` format.
- Qt Widgets: existing GTK3 platform-theme plugin + Fusion, configured in
  Hyprland and the systemd user environment. A compiled Qt6 probe confirms dark
  background #323232, text #e7e9e5 and sage selection #a9b99a. Qt's native dark
  background differs slightly from GTK's graphite; no global Qt stylesheet is used.

Settings use Noto Sans 11 / Noto Sans Mono 11, prefer-dark and green accent.
Icon and cursor themes were preserved for the later icon/cursor styling stage.

Validation: GTK3 theme, full GTK4 stylesheet and palette parse without errors;
Foot config check passes; Kitty parser resolves the shared graphite palette;
Hyprland reports no configuration errors. Nautilus was opened and visually
inspected with the new palette. The shell service remains active.

Some running apps need reopening to load their new palette/environment. Apps
with their own themes (Electron, browsers, IDEs) and sandboxed apps may require
separate per-app styling; toolkit settings do not override their content themes.

Before-change backup: `~/.local/state/poly-shell/backups/alpine-apps-before/`
contains Hyprland, GTK3, GTK4 and Kitty files plus `interface.dconf`. Foot's config
and the Poly-Alpine GTK3 theme were newly created. Restore individual files from
the backup as needed; do not replace a whole config directory after later edits.
