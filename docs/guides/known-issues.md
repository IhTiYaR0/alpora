# Preview limitations

ALPORA is a development preview. The current local baseline is Arch Linux,
Hyprland 0.56.2, Quickshell 0.3.2 and Qt 6.12.0 on a single 1920×1080 monitor.

- **Performance:** desktop widgets and companion animations have been optimized:
  in-memory Hyprland toplevel tracking replaced external hyprctl process spawns,
  fullscreen windows and overview trigger immediate widget occlusion, second-hand
  sweep rests 78% of each second, and the companion uses adaptive tick rates.
- **Hardware coverage:** physical suspend/resume, monitor hotplug, fractional
  scaling and new network/Bluetooth devices were not exhaustively exercised.
  A clean OS installation is still pending.
- **Installation:** `install.sh` supports Arch Linux and Arch-based derivatives
  (EndeavourOS, CachyOS, Manjaro, Garuda, etc.) with `--core-only` package filtering
  and `--ui-only` standalone UI mode for custom setups. A clean uninstaller (`uninstall.sh`)
  is provided with `--restore-config` and `--purge` options. Clean-OS installation
  and first login remain unvalidated. Optional Waybar handover expects a recognised
  `autostart.sh` layout.
- **Input:** the shortcut editor imports supported `hyprland.lua` bindings.
  Unsupported callbacks, submaps and mouse gestures remain external.
- **System settings:** Bluetooth pairing uses Bluetoothctl in a terminal.
  Enterprise Wi-Fi uses Nmtui. Monitor layout editing is not implemented.
  Hardware-dependent controls need the relevant service and permissions.
- **Language:** internationalisation (i18n) framework implemented with full support
  for English (`en`, baseline), Vietnamese (`vi`), and Russian (`ru`) with dynamic
  runtime switching and clean locale separation under `assets/locales/`.
- **Diagnostics:** Qt SVG, Wayland text-input and portal warnings remain. Old
  duplicate watcher processes were cleared by restarting; a long soak test has
  not established whether the underlying duplication can recur.

The last local full check passed 197 tests and strict QML lint. This is a local
validation record, not a hosted CI badge or a guarantee of every configuration.
See the [audit](code-audit-2026-10-22.md) and
[performance evidence](performance-evidence/companion-tween-2026-10-22/README.md).

Report reproducible failures with component, trigger, expected/actual behaviour,
versions and relevant redacted logs. Do not post Wi-Fi passwords, clipboard
contents, personal notes or entire unreviewed configuration directories.
