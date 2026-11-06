# Repository and installed files

ALPORA is the public name. `poly-shell` remains the technical command, service
and data-directory name for compatibility. This repository is a permanent source
checkout, not a folder to delete after installation.

## Source layout

| Path | Purpose |
| --- | --- |
| `install.sh` | Full Arch package and session installer |
| `bin/poly-shell` | Main command and component installer |
| `bin/alpora-fetch` | Live terminal system card |
| `poly_shell/` | Python configuration, integrations and CLI modules |
| `shell/` | Quickshell QML, including settings, themes and compiled shaders |
| `assets/` | Wallpapers, palette definitions, icons and lockscreen materials |
| `integrations/` | Managed Hyprland Lua, idle, screenshot and installer helpers |
| `profiles/desktop.json` | Public reference defaults for missing preferences |
| `scripts/` | Setup entry point, asset builders and development checks |
| `tests/` | Automated Python and JavaScript-backed checks |
| `docs/` | Usage, recovery, limitations and media provenance |
| `docs/media/` | Actual desktop captures and original banner |
| `licenses/` | Notices for retained third-party materials |

## User installation

The default locations below follow XDG configuration, data and state overrides
where supported. Use your own home directory; no author's absolute home path is
required by the distributed session.

| Installed path | Purpose |
| --- | --- |
| `~/.local/bin/poly-shell` | Symlink to `bin/poly-shell` |
| `~/.local/bin/alpora-fetch` | Symlink to `bin/alpora-fetch` |
| `~/.config/quickshell/poly-shell` | Symlink to the QML source directory |
| `~/.config/systemd/user/poly-shell.service` | Supervised desktop process |
| `~/.local/share/applications/poly-shell-settings.desktop` | Settings launcher |
| `~/.config/hypr/` | Full install: managed Lua session, appearance, lock, idle and screenshot helpers |
| `~/.config/poly-shell/` | Preferences, custom themes and private desktop data |
| `~/.local/state/poly-shell/` | Generated theme state, backups and private installer logs |
| `~/.local/share/alpora/desktop-assets/` | Verified, versioned icon and cursor releases |
| `~/.local/share/icons/` | Installed theme links and ALPORA overlays |
| `~/.cache/alpora/downloads/` | Checksummed asset download cache |
| `~/.cache/poly-shell/` | Generated application-icon cache |

The component installer creates the command/QML links, service and settings
launcher. Full `install.sh` also prepares the session and its dependencies.
Neither method copies the author's notes, clipboard, accounts or private settings.

Do not rename or move the source checkout after setup. If you need to relocate it,
inspect existing symlinks, the generated service and desktop entry first; the
installer refuses conflicting targets rather than silently replacing them.

See [installation and recovery](installation.md), [Arch setup](arch-installer.md)
and [programs](programs.md) before removing generated files or restoring a session.
