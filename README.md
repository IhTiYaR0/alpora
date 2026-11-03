<p align="center">
  <img src="docs/media/alpora-banner.svg" width="100%" alt="ALPORA — A different view">
</p>

<p align="center">
  <a href="#the-desktop">The desktop</a> &nbsp; / &nbsp;
  <a href="#landscapes">Landscapes</a> &nbsp; / &nbsp;
  <a href="#install">Install</a> &nbsp; / &nbsp;
  <a href="docs/README.md">Docs</a> &nbsp; / &nbsp;
  <a href="docs/README.ru.md">Русский</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/ARCH_LINUX-HYPRLAND-b8cba1?style=flat-square&amp;labelColor=202829" alt="Arch Linux / Hyprland">
  <img src="https://img.shields.io/badge/RELEASE-v1.0.0-58a6ff?style=flat-square&amp;labelColor=202829" alt="ALPORA OS v1.0.0">
  <a href="LICENSE"><img src="https://img.shields.io/badge/LICENSE-MIT-a4c5c5?style=flat-square&amp;labelColor=202829" alt="MIT license"></a>
</p>

<p align="center"><b>Mountains at sunrise. A lake after dark. A desktop that follows the landscape.</b></p>

ALPORA is a coordinated Hyprland environment for Arch Linux. Faceted scenery,
soft glass, matching application colours and a small travelling robot give the
desktop its own character. Built with Quickshell, native QML and Python.

<a id="the-desktop"></a>
## 01 &nbsp; A place to make your own

[![ALPORA Alpine Dawn: Nautilus, live system card in Foot, themed folders, dock and widgets](docs/media/showcase-alpine.png)](docs/media/showcase-alpine.png)

<p align="center"><sub>ALPINE DAWN &nbsp; · &nbsp; Nautilus + ALPORA Fetch in Foot &nbsp; · &nbsp; Papirus + Bibata &nbsp; · &nbsp; 1920 × 1080</sub></p>

A mountain-framed panel above your windows. A dock when you need it. Clock,
weather and music on the desktop. Controls, applications and a workspace overview
within reach, with an independent settings app to shape the details.

<a id="landscapes"></a>
## 02 &nbsp; Six landscapes. One desktop.

Choose a scene and carry its palette through the panel, widgets, folders,
window borders and supported applications. Work/Vibe behaviour stays independent.

[![Actual ALPORA theme switching: Alpine Dawn to Moon Lake to Northern Lights](docs/media/theme-switching.gif)](docs/media/theme-switching.mp4)

<p align="center"><sub>REAL SCREEN RECORDING &nbsp; · &nbsp; The landscape and open system card change together &nbsp; · &nbsp; <a href="docs/media/theme-switching.mp4">Open video</a></sub></p>

<table>
  <tr>
    <td width="50%"><a href="docs/media/palette-alpine.png"><img src="docs/media/palette-alpine.png" alt="Alpine Dawn desktop"></a><br><b>01 / Alpine Dawn</b><br><sub>Sage accents. Warm light. Still water.</sub></td>
    <td width="50%"><a href="docs/media/palette-moon-lake.png"><img src="docs/media/palette-moon-lake.png" alt="Moon Lake desktop"></a><br><b>02 / Moon Lake</b><br><sub>Midnight blue and a touch of lavender.</sub></td>
  </tr>
  <tr>
    <td><a href="docs/media/palette-forest-mist.png"><img src="docs/media/palette-forest-mist.png" alt="Forest Mist desktop"></a><br><b>03 / Forest Mist</b><br><sub>Deep greens. Quiet, distant ridges.</sub></td>
    <td><a href="docs/media/palette-warm-desert.png"><img src="docs/media/palette-warm-desert.png" alt="Warm Desert desktop"></a><br><b>04 / Warm Desert</b><br><sub>Ochre dunes and sun-warmed surfaces.</sub></td>
  </tr>
  <tr>
    <td><a href="docs/media/palette-northern-lights.png"><img src="docs/media/palette-northern-lights.png" alt="Northern Lights desktop"></a><br><b>05 / Northern Lights</b><br><sub>Glacial blues under a turquoise sky.</sub></td>
    <td><a href="docs/media/palette-rose-sunset.png"><img src="docs/media/palette-rose-sunset.png" alt="Rose Sunset desktop"></a><br><b>06 / Rose Sunset</b><br><sub>Dusty pink, coastal cliffs and evening light.</sub></td>
  </tr>
</table>

**A seventh option: Timeline.** Explore landscapes for different times of day.
You can also import your own wallpaper and extract its palette.
[Theme controls →](docs/features/wallpaper-themes.md)

## 03 &nbsp; The small things belong together

<table>
  <tr>
    <td width="50%"><a href="docs/media/theme-orbit.png"><img src="docs/media/theme-orbit.png" alt="ALPORA circular theme switcher"></a><br><b>A little orbit of possibilities.</b><br><sub>The circular theme switcher, on the actual desktop.</sub></td>
    <td width="50%"><a href="docs/media/settings-appearance.png"><img src="docs/media/settings-appearance.png" alt="ALPORA appearance settings"></a><br><b>Make the details yours.</b><br><sub>Opacity, rounding, spacing and motion, with saved drafts.</sub></td>
  </tr>
</table>

| Your desktop | The details |
| :--- | :--- |
| **Move between ideas** | Workspace overview, application search, shared favourites and an edge-revealed dock. |
| **Keep a little structure** | Calendar, local tasks, notes and a focus timer. No account needed for the organiser. |
| **Stay in control** | Quick settings for sound, connectivity and supported hardware, plus notification and clipboard history. |
| **Play something** | Music widgets and controls connect to real MPRIS players. |
| **Meet Грань** | A small articulated robot that walks, flies, lands on exposed window/widget edges and can be picked up. Optional, like its flights. |
| **Choose your finish** | Papirus application icons, palette-matched folders, Bibata Modern Ice and editable Lua hotkeys. |
| **ALPORA Fetch** | A faceted mountain and real system data in your terminal. The open card follows the desktop palette. [Moon Lake view](docs/media/showcase-moon.png). |

Reduced motion is supported. Desktop widgets and the robot have visibility
controls. Optional interactive wallpaper landmarks start disabled. The current
application interface is primarily Russian.

<a id="install"></a>
## 04 &nbsp; From a terminal to your landscape

**Arch Linux · a normal user account · working internet · sudo access.**
Download or clone this repository into a permanent directory, then open a terminal
inside it. The installer creates links into the checkout, so keep that directory.

```sh
# One-line online installer (auto-clones and runs interactive setup)
curl -fsSL https://raw.githubusercontent.com/pnam-it309/alpora/main/install/get.sh | bash
```

Or clone manually:

```sh
git clone https://github.com/pnam-it309/alpora.git
cd alpora

./install/install.sh --preview          # Live system card without installing; q to exit
./install/install.sh --dry-run --wizard  # Explore the chooser and installation plan
./install/install.sh                    # Install ALPORA and choose your first landscape
```

For the neofetch-style system card with ALPORA's faceted mountain and your active
palette, run `./bin/alpora-fetch`. It reads real system data, needs no installation
and follows theme changes in the open terminal, including Timeline. Exit with
`q`, Escape or `Ctrl+C`; use `./bin/alpora-fetch --once` for a static snapshot.
Preview a fixed landscape with `./bin/alpora-fetch --theme=moon-lake`.
No background service is created.

The guided terminal installer handles packages, verified icon/cursor downloads,
configuration backups, the reference preset and session startup. It shows real
phases and elapsed time. Pacman and sudo keep their normal prompts. A personal
Hyprland configuration requires consent before replacement.

After installation, log out and select **Hyprland**, or start it from a TTY.
The installer leaves your GPU driver, bootloader and display manager alone.

In your new session, open settings and the system card shown in the screenshot:

```sh
~/.local/bin/poly-shell status
~/.local/bin/poly-shell settings
~/.local/bin/alpora-fetch
```

With `~/.local/bin` on your `PATH`, use the short commands `poly-shell` and
`alpora-fetch`. The card opens on request. The sample folders and Nautilus/Foot
window arrangement are a demonstration composition; files and system readings
will be your own.
[System card](docs/features/system-card.md) · [Installed files and source layout](docs/architecture/repository-layout.md)

| Want to… | Use |
| :--- | :--- |
| Choose a theme directly | `./install/install.sh --theme=northern-lights` |
| Install standalone UI shell only | `./install/install.sh --ui-only` |
| Install core shell (skip bundled apps) | `./install/install.sh --core-only` |
| Read the full installation plan | `./install/install.sh --dry-run` |
| Cleanly uninstall ALPORA | `./install/uninstall.sh` (or `./install/uninstall.sh --restore-config`) |
| Understand backups and recovery | [Installer guide](docs/guides/arch-installer.md) |
| Add only the desktop components | [Component installation](docs/guides/installation.md) |
| See every application and dependency | [Programs & services](docs/guides/programs.md) |

<details>
<summary><b>Compatibility & current preview limits</b></summary>

The checked local baseline is Arch Linux, Hyprland **0.56.2**, Quickshell **0.3.2**
and Qt **6.12.0**. The installer supports Arch Linux and Arch-based derivatives
(EndeavourOS, CachyOS, Manjaro, Garuda, Artix, ArcoLinux, Archcraft) as well as custom
kernels. For users wishing to preserve existing personal Hyprland setups or use other
distributions, `--ui-only` installs only the standalone ALPORA shell panel and widgets.
An official `./install/uninstall.sh` script is provided to cleanly revert symlinks, systemd user
services, and restore prior Hyprland configuration backups. Full first login on a clean
Arch system remains pending. The reference composition targets 1920×1080 at scale 1;
other displays use the existing adaptive layout and need further validation.

Existing preferences are preserved. A fresh account receives the reviewed
ALPORA preset, rather than the author's notes, clipboard, accounts or location.
Hardware status, weather, app lists and third-party application internals vary.

Animated widgets and companion timers have been optimized for idle CPU efficiency.
The shell supports English (baseline), Vietnamese, and Russian via the i18n framework.
Suspend/resume, monitor hotplug and more device combinations remain to be checked.
Bluetooth pairing uses a terminal helper; monitor layout editing is pending.

The last local check passed **197 tests and strict QML lint**. These are local
results, not a hosted CI claim. Read the [known issues](docs/guides/known-issues.md),
[new-user validation](docs/audits/install-validation-2026-10-22.md) and [code audit](docs/audits/code-audit-2026-10-22.md).

</details>

## 05 &nbsp; Find your way around

| Shortcut | Action |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>Return</kbd> | Terminal |
| <kbd>Super</kbd> + <kbd>E</kbd> | Files |
| <kbd>Super</kbd> + <kbd>R</kbd> | Applications |
| <kbd>Super</kbd> + <kbd>I</kbd> | Quick settings |
| <kbd>Super</kbd> + <kbd>Tab</kbd> | Workspace overview |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>V</kbd> | Toggle floating window |
| <kbd>Super</kbd> + left / right mouse drag | Move / resize a window |

These are the bundled session defaults. Change supported bindings in Settings →
**Горячие клавиши**. The technical command and configuration namespace remain
`poly-shell` to preserve compatibility.

[Documentation](docs/README.md) &nbsp; / &nbsp; [Hotkeys](docs/guides/shortcuts.md) &nbsp; / &nbsp;
[Themes](docs/features/wallpaper-themes.md) &nbsp; / &nbsp; [Robot](docs/features/desktop-companion.md) &nbsp; / &nbsp;
[Contributing](.github/CONTRIBUTING.md) &nbsp; / &nbsp; [Changelog](docs/CHANGELOG.md)

---

<p align="center"><b>ALPORA</b> &nbsp; — &nbsp; A different view.</p>
<p align="center"><sub>Created by IhTiYaR0 · Built with Hyprland, Quickshell, Qt and Python</sub></p>

Original code and authored vectors: [MIT](LICENSE). Papirus, Bibata and the
historical Adwaita assets retain their upstream licenses. Landscapes were made
with OpenAI's image generation tool. [Credits & third-party notices](licenses/THIRD_PARTY_NOTICES.md) ·
[Capture provenance & presentation references](docs/media/README.md).
