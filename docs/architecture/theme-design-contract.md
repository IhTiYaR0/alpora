# Theme and mode compatibility

User requirement: future modes and multiple themes must remain supported as the
desktop appearance evolves. Alpine is one visual theme, not the only appearance.

For upcoming icon, cursor and typography implementation:

- Keep behavior modes (Work/Vibe) separate from visual themes. Changing either
  must not silently reset the other or change user application preferences.
- Resolve semantic colors, font families/sizes, icon theme, cursor theme/size,
  material alpha and motion from one effective theme description, with defaults.
- Use named, user-local theme assets. Preserve upstream icon/cursor packages;
  do not recolor or overwrite the installed system theme in place.
- Keep application icons recognizable and provide inherited missing-icon and
  cursor fallbacks. Theme switching must not affect application launching.
- Generate toolkit/terminal/compositor appearance from the same resolved palette,
  preserve unrelated settings and retain a recoverable previous state.
- Respect reduced motion and verify both existing Work/Vibe modes when wiring
  theme selection. A missing theme or asset must retain a usable appearance.

Current status: six wallpaper themes, private custom imports and a shared live QML
palette are implemented. Theme application coordinates shell materials, supported
application/toolkit styles, icon themes, terminal colors, compositor borders, Mako
and Hyprlock. Modes and geometry remain independent. See wallpaper-themes.md for
actual coverage, recovery behavior and remaining application-specific limits.

Hover controls also follow this contract: see faceted-hover-2026-10-20.md.
The user explicitly reaffirmed theme compatibility for all future UI work;
this standing requirement is recorded in the project AGENTS.md.
