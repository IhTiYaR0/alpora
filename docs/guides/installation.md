# Install & recover

For the new full Arch bootstrap, see [install.sh documentation](arch-installer.md).
This page describes the existing component-only installer.

ALPORA is currently a preview for an existing Hyprland session. Its technical
command, service names and configuration paths remain `poly-shell`.

## Requirements

The local baseline is Arch Linux, Hyprland 0.56.2 (Lua configuration), Quickshell
0.3.2 and Qt 6.12.0. Keep Qt and Quickshell compatible. The installer does not
install packages, a compositor, GPU drivers or a display manager.

The foundation needs Quickshell, Python 3, Hyprland, a user systemd session and
GLib D-Bus tools. Audio uses PipeWire/WirePlumber; network and Bluetooth use
NetworkManager and BlueZ. Install the tools for the functions you need from the
[program inventory](programs.md). Pillow is needed for wallpaper imports and
Timeline preparation. Development checks also require Node.js and qmllint.

## Try the desktop

Download or clone the repository, keep its checkout in a permanent location,
and open a terminal inside it. Installation creates symlinks into this checkout;
moving or deleting the checkout breaks those links.

```sh
./bin/poly-shell doctor
./bin/poly-shell install
./bin/poly-shell run
```

`doctor` reports required and optional tools. A binary being present does not
prove its service, permissions or hardware are available. `install` creates:

- `~/.local/bin/poly-shell` — command symlink.
- `~/.local/bin/alpora-fetch` — live system-card command symlink.
- `${XDG_CONFIG_HOME:-~/.config}/quickshell/poly-shell` — QML configuration link.
- A user `poly-shell.service` unit and a settings desktop entry.

Unrelated files at these paths are preserved; installation refuses conflicts.
Stop the foreground run with `Ctrl+C` before trying the managed service.

```sh
~/.local/bin/poly-shell start
~/.local/bin/poly-shell status
~/.local/bin/poly-shell settings
~/.local/bin/poly-shell logs
~/.local/bin/poly-shell stop
```

`start` does not remove the existing Waybar. To use the short command, put
`~/.local/bin` on your PATH.

The themed terminal card is available from any directory:

```sh
~/.local/bin/alpora-fetch
```

It follows live theme changes; exit with `q`, Escape or `Ctrl+C`. Use `--once`
for a snapshot. Repeating `./bin/poly-shell install` adds this link to an earlier
installation without replacing the Hyprland session. See the [system card guide](system-card.md)
and [installed file map](repository-layout.md).

## Optional integrations

For the backed-up Lua appearance include and settings window rules:

```sh
~/.local/bin/poly-shell appearance install
```

Read [appearance controls](appearance-controls.md) and [hotkeys](shortcuts.md)
before changing the existing Hyprland configuration. These integrations are
separate from the basic installation.

The current activation helper expects exactly one `waybar ...` command in
`~/.config/hypr/autostart.sh` (or its XDG configuration equivalent):

```sh
~/.local/bin/poly-shell activate
```

It backs up the file, wraps the launch with a readiness fallback, then stops
running Waybar instances. It refuses a layout it does not recognise. It does
not support arbitrary session startup configurations.

## Stop & restore

```sh
~/.local/bin/poly-shell deactivate
~/.local/bin/poly-shell stop
```

`deactivate` restores the managed Waybar launch. Theme application and Lua
appearance changes have separate backups; stopping the desktop does not undo
all toolkit, wallpaper or compositor styling. Follow [theme recovery](wallpaper-themes.md)
and [appearance recovery](appearance-controls.md) for those changes.

A clean uninstallation script `./uninstall.sh` is provided. Run `./uninstall.sh --help`
to inspect all available uninstallation options:
- `./uninstall.sh` removes symlinks and user services.
- `./uninstall.sh --restore-config` removes symlinks and restores the latest Hyprland configuration backup.
- `./uninstall.sh --purge` removes all links and cleans user configuration/state directories.

## Updating a checkout

Once a remote repository is configured, pull updates without discarding local edits:

```sh
git pull --ff-only
~/.local/bin/poly-shell restart
```

Read release notes before updating. A moving checkout is a development preview;
versioned release instructions will accompany published releases.
