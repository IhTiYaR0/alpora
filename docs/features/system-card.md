# ALPORA system card

The terminal card combines a faceted mountain mark with real Linux system data.
It is ALPORA's own Python renderer, inspired by neofetch's layout. Neither neofetch
nor fastfetch is required. It uses standard-library modules and terminal text,
not an image protocol or an additional GUI application.

## Launch

From the repository:

```sh
./bin/alpora-fetch
```

Both installation methods (`./install.sh` and `./bin/poly-shell install`) create
`~/.local/bin/alpora-fetch`, linked to this checkout. From any directory:

```sh
~/.local/bin/alpora-fetch
```

If `~/.local/bin` is already on your PATH, the short command is `alpora-fetch`.
The checkout must stay in place, just like the main `poly-shell` command.
Re-run the component installer to add the command to an earlier installation:

```sh
./bin/poly-shell install
```

This updates user-local links; it does not replace Hyprland configuration or
install system packages. Conflicting personal launchers are preserved and reported.

## Colours and controls

In an interactive terminal, the card stays in the foreground and follows the
current effective palette. The mountain facets, sun, lettering, border and swatches
update together. Saved custom palettes and Timeline's intermediate colours use
the same theme resolver as the desktop. Palette changes are checked twice a second;
system statistics update every five seconds. No background service is created.

- `q`, Escape or `Ctrl+C`: close the card and restore the terminal.
- `alpora-fetch --once`: print a snapshot and return to the prompt.
- `alpora-fetch --theme=moon-lake`: preview a fixed theme without applying it.
- `alpora-fetch --no-color`: plain text.

`NO_COLOR` disables colours. Redirecting output always prints one plain snapshot
and exits. Modern terminals such as Foot show the coloured half-block artwork;
the Linux console uses a plain-text fallback. The card uses an alternate terminal
screen while running, so its updates do not fill shell scrollback.

The data includes OS, running kernel, desktop environment, login shell, terminal
identifier, theme, memory usage and uptime. These values describe the user's
machine; installing ALPORA does not reproduce the author's hardware or statistics.
`./install.sh --preview` opens the same card without starting installation.

[Installation](arch-installer.md) · [Themes](wallpaper-themes.md) · [Documentation](README.md)
