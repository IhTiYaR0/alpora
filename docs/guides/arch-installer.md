# ALPORA installer for Arch Linux

`install.sh` is the first complete-session bootstrap for **Arch Linux**.
It is implemented and locally tested at the configuration level; a real clean
Arch installation has **not yet been performed**. It is not ready to be described
as universally tested or suitable for every existing desktop.

Run it as your normal user from a permanent checkout:

```sh
./install.sh --dry-run
./install.sh
```

`--dry-run` prints the plan without installing packages, downloading assets or
writing configuration. The normal run invokes sudo for package/system-service
actions; it does not run the entire installer as root.

## What it installs

1. A complete Arch upgrade and the explicit package list in `install.sh`, using
   `pacman -Syu --needed`. Pacman keeps its usual transaction prompts.
2. Hyprland, Quickshell, Qt runtime, Python, GTK, audio/network/Bluetooth tools,
   portals, fonts, notifications, lock/idle tools, terminals, Nautilus and Firefox.
3. Pinned Papirus/Bibata assets and the six ALPORA icon overlays.
4. A backed-up Lua session configuration, default shortcuts, screenshot helper,
   native overview gestures and the themed lockscreen.
5. User-local `poly-shell` and `alpora-fetch` commands, desktop service and Hyprland-session startup. It prepares
   themes for the next login without reloading the running desktop or launching
   wallpaper renderers during setup.
6. NetworkManager and Bluetooth services, user audio units, and a power profile
   daemon when TLP is not already enabled.

## Existing configurations

A personal `hyprland.lua` or `hyprland.conf` requires explicit consent before
replacement. An interactive run asks once; a noninteractive run refuses unless
`--replace-config` is given. The complete Hyprland directory is copied, preserving
symlinks, to a timestamped `arch-install-*` backup before session files change.
Only session files are replaced; unrelated files remain. A legacy `.conf` is
removed from the active path only after being backed up. Modified session helpers
are also protected on repeat installation.

If setup fails while writing the session, the previous directory is restored.
Later steps have their own backups. This is **not** an atomic rollback of a full
system upgrade: packages, enabled services and completed asset installations
can remain after a later failure. The installer reports the backup location.

`--skip-packages` is for development with dependencies already installed. It is
not a promise that missing runtime dependencies will work.

`--minimal` (or `--core-only`) installs only the core compositor, shell, audio, and portal packages (~28 packages),
skipping bundled third-party applications (Firefox, Nautilus, Kitty, Foot, Fuzzel, Pavucontrol).

`--ignore-distro-check` (or `--force-distro`) bypasses Arch distro detection in case you are on an unlisted Arch spin
or derivative and want to use pacman to install packages.

`--ui-only` installs the standalone ALPORA UI shell (panel, widgets, companion, and settings)
without altering existing Hyprland configurations or installing packages. This is ideal
for custom Arch kernels (linux-zen, linux-lts, linux-hardened, etc.), personal configurations,
or other distributions. Launch with `poly-shell run` or add `exec-once = poly-shell run` to
your existing configuration.

## Uninstallation & recovery

To cleanly remove ALPORA user links and services:

```sh
./uninstall.sh --dry-run             # Preview changes
./uninstall.sh                       # Remove symlinks and user service
./uninstall.sh --restore-config      # Remove links and restore latest Hyprland backup
./uninstall.sh --purge               # Remove links and purge user config directories
```

## First login

Log out and select Hyprland in an existing display manager, or start `Hyprland`
from a TTY. No GPU driver, bootloader or display manager is installed or changed.
Working networking, an Arch user account and sudo access are prerequisites.
Do not run the full installer over the current development session just to check it.

Default controls include Super+Return/Q (Foot), Super+E (Nautilus), Super+B
(Firefox), Super+R (launcher), Super+I (quick settings), Super+Tab (overview),
Super+V (clipboard), Super+L (lock), Super+1–0 (workspaces) and Print (region capture).
Keyboard layout defaults to US/RU with Super+Space switching.

## Validation so far

See the [new-user validation record](install-validation-2026-10-22.md) for the
real isolated asset/configuration runs, separate UID, spaced paths, repeated setup
and Wayland interface smoke check. Full package installation and systemd service
activation remain outside that check.


Tests cover clean user configuration, repeat setup, replacement consent,
backup contents, symlink preservation on failure, protected manual changes,
production setup orchestration and offline theme generation. The latter verifies
that running compositor/wallpaper operations are not invoked. Dependency
installation and service activation are mocked in those tests, not declared tested
on a new OS. Bash and Lua syntax have been checked. The current package names
were checked against the local Arch package database.

The next release gate is an actual disposable clean Arch installation, including
first login, services, lock/unlock and recovery. Root package operations were not
executed on the author's working system in this implementation pass.

## Guided installation and the reference desktop

An interactive `./install.sh` opens a dependency-free terminal welcome with the
ALPORA mountain mark, palette swatches and a seven-theme chooser. It works before
Python/Qt are installed, including a text fallback for plain terminals. Each
completed phase reflects real work; the interface uses elapsed time rather than
invented download percentages. Pacman remains visible for package conflicts,
transaction review and sudo authentication.

The six phases are Arch preparation, icons/cursor, session backup, desktop
configuration, theme integration and verification of next-login files. Progress
is animated only in an interactive terminal. `NO_COLOR=1` suppresses colour;
redirected output stays plain. Installation logs are private files under
`~/.local/state/poly-shell/install-logs`, including package output and phase/failure
records. They are diagnostic records, not a claim of system-wide rollback.

Try the real chooser without changing the machine:

```sh
./install.sh --dry-run --wizard
```

To show only the designed terminal welcome, without package lists, logs or
installation actions:

```sh
./install.sh --preview --theme=northern-lights
./install.sh --preview --wizard  # With interactive landscape selection
```

With Python available, preview displays the ALPORA system card: a faceted mountain
mark beside real OS, kernel, desktop, shell, terminal, memory and uptime data.
Run `./bin/alpora-fetch` directly for the card without installer text. The default
uses the active palette, including custom and Timeline colours; `--theme=ID`
previews a named landscape without applying it. Narrow terminals stack the logo
above the card. This is an independent, dependency-free renderer inspired by
neofetch's layout; it does not install or invoke neofetch.

In an interactive terminal the card stays in the foreground and checks the
effective palette every half-second. It redraws when the palette or terminal size
changes; system statistics refresh every five seconds. There is no animation,
child watcher or background service. Exit with `q`, Escape or `Ctrl+C`. The cursor
and terminal settings are restored on exit, including SIGTERM. `--theme=ID` pins
the preview to that landscape. `--once` prints one snapshot and exits; redirected
output is always a single plain-text snapshot.

The welcome uses the landscape's semantic accent and secondary colours from
`assets/themes/*.json`. It falls back to console colours without Python, and
plain text with `NO_COLOR` or redirected output. Preview exits before any
platform checks, package actions, log creation or configuration writes.

Select a theme directly for an unattended plan:

```sh
./install.sh --dry-run --theme=northern-lights
```

The same `--theme=ID` option applies to a real installation. Without a theme flag
or interactive selection, the saved theme is kept, or Alpine Dawn is used on a
new account.

`profiles/desktop.json` is the versioned public reference preset. It contains
reviewed appearance values from the author's desktop: 20 px window/panel rounding,
75% panel/widget opacity, 40 px bar, margins, animation timings, widget positions,
robot/flight preferences and disabled wallpaper hotspots. Compositor blur is off
in this preset, matching the measured development configuration. It does not
copy private settings wholesale. Missing preference files are seeded; existing
preferences remain untouched. Repeat installation therefore preserves custom
layouts and cities rather than silently forcing the screenshot layout.

The reference composition targets 1920×1080 at scale 1. Other resolutions use
the existing responsive layout. Hardware status, battery, weather location,
installed applications and third-party app internals naturally differ. The preset
uses the public default weather location (Almaty), editable in settings; it does
not copy the author's city, notes, clipboard, passwords or account data.

The final check validates generated session/lock/notification files, visual and
widget data, command links, the service, the QML entry point, the system-card
module and the wallpaper path before reporting completion. See the
[installed file map](repository-layout.md). It does not
replace a real first-login test. A clean disposable Arch validation remains pending.
