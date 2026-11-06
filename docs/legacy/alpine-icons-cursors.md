# Alpine icons, cursor and typography

Installed user-local themes:

- `~/.local/share/icons/Poly-Alpine` links to repo-owned generated SVG assets.
  Standard and aliased folder/place names and six terminal/file-manager app names are covered;
  other app icons inherit MacTahoe-blue-dark, then Adwaita and hicolor.
- `~/.local/share/icons/Poly-Alpine-Cursors` links to the repo cursor theme.
  The complete Adwaita cursor artwork is copied without modification, preserving
  original sizes, hotspots and animated frames. This replaces the initial handmade
  arrow/hand/text designs. Atomic replacement never follows old fallback symlinks
  into the installed source theme. All states use the same proven cursor geometry.
- Noto Sans 11 / Noto Sans Mono 11 remain the shared interface/terminal fonts.

Source manifest: `assets/themes/alpine.json`. Rebuild with
`scripts/build-desktop-theme` and refresh with
`gtk-update-icon-cache -f -t ~/.local/share/icons/Poly-Alpine`.
Building uses the Python standard library and installed Adwaita assets; no downloads.

GTK3/GTK4 settings, GNOME interface settings, the systemd user environment and
`~/.config/hypr/desktop-theme.lua` select the new themes. Hyprland reload and
setcursor apply them in the live session; shell restart refreshes app icon lookup.

`~/.config/poly-shell/appearance.json` stores the theme ID independently of the
Work/Vibe mode. Session snapshots expose the resolved manifest as `appearance`.
Missing/invalid selections fall back to Alpine without rewriting the selection.
This is a foundation for multiple themes, not a complete toolkit theme switcher:
the GTK/terminal palette from the previous stage still needs coordinated generation
when additional themes are implemented. Mode palettes retain their prior behavior.

Validation: libXcursor successfully loads all three generated cursors; GTK4 resolves
folder icons to Poly-Alpine and Firefox to the inherited theme. Live launcher and
Nautilus screenshots confirm the new icons. Both mode-independence and safe-fallback
tests pass, alongside all 32 project tests and zero QML lint warnings. Hyprland has
no config errors; the shell is active with NRestarts=0.

Before-change settings are in `~/.local/state/poly-shell/backups/alpine-icons-before/`.
Original installed icon/cursor themes are unmodified.

V2 polish: stronger embossed folder glyphs, reduced facet contrast, specific
desktop/home/projects emblems, additional common aliases and a restrained gem
for ordinary directories. GTK resolves all standard home-directory names to local
assets. Home view was visually inspected with the refreshed theme. Previous v1
artwork is backed up in `~/.local/state/poly-shell/backups/alpine-assets-v1/`.
