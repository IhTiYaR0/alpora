# Changelog

## [v1.0.0] — 2026-11-03 — Official First Release

The first production-ready release of **ALPORA OS**: a coordinated, fluid Wayland desktop operating environment built on Arch Linux, Hyprland, and Quickshell.

### Key Highlights & Superpowers

#### Security Shield & System Hardening (Windows Defender Equivalent)
- **Visual Security Hub**: Integrated `SecurityShieldCard.qml` into Quick Settings with 1-click audit action.
- **Kernel & Network Hardening**: Built-in sysctl security profile (`99-alpora-security.conf`) enabling ASLR, BPF JIT, TCP SYN cookies, and UFW firewall enforcement.
- **Gaming & Low Latency Optimization**: Kernel tuning (`99-alpora-performance.conf`) optimizing `vm.max_map_count` for Steam Proton and irqbalance for smooth multitasking.
- **Application Privacy Sandbox**: Flatpak permission manager (`poly-shell privacy status/isolate/allow/revoke`) to control camera, microphone, and filesystem access.

#### Storage Guard & Seamless Drive Mental Model ("C: vs D: Drive")
- **Transparent Compression**: Btrfs ZSTD level 3 filesystem compression saving 20-35% disk space automatically.
- **Non-Breaking Data Moves**: Move games, code, and downloads across disks (`poly-shell storage move`) without breaking shortcuts, configs, or application paths.
- **File Properties Inspector**: Native `poly-shell properties <path>` revealing allocated vs logical disk size, permissions, and SHA-256/MD5 integrity checksums.
- **Storage Maintenance**: Automated journald log capping (`150M`) and one-click cleanup (`poly-shell storage clean`).

#### Instant System Recovery (5-Second Rollback)
- **Btrfs Snapper Snapshots**: Integrated `snapper` and `snap-pac` (`poly-shell snapshot list/create/delete`).
- **Bootloader Recovery**: Automatic snapshot creation before and after any package update, allowing 5-second boot rollback if an update ever fails.

#### Centralized Developer CLI Hub
- **Isolated User Space**: Managed developer tools in `~/.alpora/dev/bin` without sudo requirements or global PATH pollution.
- **Tool Management**: Standardized catalog (`uv`, `bun`, `pnpm`, `lazygit`, `ripgrep`, etc.) via `poly-shell dev list/install/remove/doctor/export/import`.
- **Reflink CoW Cloning**: Instant 0-byte project duplication (`poly-shell dev clone <src> <dst>`) on Btrfs.

#### OTA Update Center & Distribution
- **Windows-Style Update Flow**: `poly-shell update check/status/apply` with GitHub Releases integration.
- **Cloud ISO Builder**: Automated GitHub Actions workflow compiling official bootable Arch Linux Live ISO images with offline `alpora-install`.
- **Vietnamese IME & Windows App Compatibility**: Native Fcitx5 Bamboo and Wine presets (Zalo, UltraViewer, Notepad++).

---

## [0.1.0-dev] — Development Preview

- Added `--ui-only` standalone UI mode to `install.sh` and `bootstrap.py`: installs the ALPORA shell panel, widgets, and themes without altering existing Hyprland configurations or requiring Arch package management.
- Broadened installer platform support to Arch-based distributions (EndeavourOS, CachyOS, Manjaro, Garuda, Artix, ArcoLinux, Archcraft) and custom kernels via `ID_LIKE` and derivative detection.
- Added `--core-only` flag to `install.sh` separating core compositor/shell packages from optional bundled applications (Firefox, Nautilus, Kitty, Foot, Fuzzel, Pavucontrol).
- Added `uninstall.sh` with `--dry-run`, `--restore-config`, and `--purge` flags to cleanly stop user units, remove installed links/files, and restore previous Hyprland configuration backups.
- Added lightweight internationalisation (i18n) framework supporting English (system baseline), Vietnamese, and Russian with dynamic runtime switching, zero-cost memory table lookups, and JSON locale files in `assets/locales/`.
- Optimized desktop widget and companion CPU consumption: eliminated external `hyprctl` process spawning via in-memory `Hyprland.toplevels` tracking, added immediate occlusion on fullscreen windows and overview, throttled clock second sweep to rest 78% of each second, made weather particle timers conditional on active effects, and introduced adaptive tick rates for companion resting states.
- Validated production configuration in isolated UID 1000/1001 profiles, real asset downloads, spaced paths, repeat setup and a separate software Wayland display; documented the remaining clean-OS gate.
- Fixed first-start QIcon worker loading in launcher/dock, enabling active-but-disabled network/Bluetooth services, and preflighting settings-launcher conflicts before installation writes.

- Added ALPORA Fetch: a faceted terminal system card that follows active/custom/Timeline palettes, supports snapshots and restores terminal state on exit.
- Refreshed the working-desktop screenshots and native theme-switching video with the live system card.
- Included `alpora-fetch` in both installation methods, verified its installed link and QML/service files, and added the missing `xdg-user-dirs` screenshot dependency.
- Updated both README languages, installed-file map, application inventory and first-login commands.

- Reworked the English/Russian README around a working-desktop hero, six landscape palettes, a real theme-switching recording and direct installation guidance.

- Added a guided terminal installer with theme selection, real phase timing, private logs and next-login file verification.
- Added a versioned ALPORA reference preset for missing preferences, preserving existing user data.

- Added pinned Papirus/Bibata installation, consistent GTK/compositor cursor settings and theme-aware folder overlays.
- Added an Arch install.sh preview with package installation, backed-up session defaults and offline theme preparation. Clean-OS validation is pending.

- Introduced ALPORA as the public name, retaining `poly-shell` command and data compatibility.
- Added a landscape banner, English/Russian project pages and current desktop screenshots.
- Added installation/recovery documentation, contribution guidance and third-party notices.
- Existing desktop includes coordinated themes and Timeline, panel controls, launcher,
  dock, workspace overview, organiser, clipboard history and desktop widgets.
- Added settings management of supported Lua hotkeys and robot visibility/flight preferences.
- Fixed robot pausing when bar panels open; changed joint smoothing to use its existing clock.
- Latest local baseline: 197 tests and strict QML lint; known performance and hardware
  validation limits remain documented. No stable release has been published.
