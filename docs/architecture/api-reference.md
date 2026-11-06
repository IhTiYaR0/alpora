# ALPORA API Reference

This document provides a comprehensive specification of ALPORA's public interfaces, including Python CLI commands, Quickshell IPC endpoints, and the Theme semantic color contract.

---

## 1. Python CLI Interface (`poly-shell`)

The `poly-shell` command-line utility serves as the main controller for managing sessions, configuring settings, querying system status, and interfacing between external services and the Quickshell UI.

### 1.1 Lifecycle & Session Management

| Subcommand | Arguments | Description |
|:---|:---|:---|
| `init` / `refresh` | None | Regenerates session state (`session.json`), syncs visual appearance, notifications, and lockscreen. |
| `start` / `stop` / `restart` | None | Manages the background user service (`poly-shell.service`) via systemd. |
| `status` | None | Returns a human-readable summary of the current shell status, active mode, and display servers. |
| `doctor` | None | Runs diagnostic checks on required dependencies, compositor sockets, and file permissions. |
| `logs` | None | Views systemd journal logs for `poly-shell.service`. |
| `settings` | None | Launches or focuses the standalone `poly-shell-settings` window. |
| `mode` | `[work \| vibe \| toggle] [--json]` | Gets, sets, or toggles the session mode. Outputs raw mode string or complete JSON snapshot. |

### 1.2 Desktop Adapters (`poly-shell control`)

Provides hardware and system integration for Quick Settings and desktop widgets:

```bash
poly-shell control <action> [value]
```

- **`status`**: Queries current brightness percentage, DND mode status, night light activation, power profiles, and radio states. Returns a JSON dictionary.
- **`brightness <5..100>`**: Sets display backlight using `brightnessctl`.
- **`bluetooth <on | off>`**: Blocks/unblocks RFKILL and toggles bluetooth controller via `bluetoothctl`.
- **`dnd`**: Toggles Do Not Disturb mode via `makoctl mode -t do-not-disturb`.
- **`nightlight`**: Toggles screen color temperature (4500K) via `hyprsunset`.
- **`power-profile <power-saver | balanced | performance>`**: Switches active power profile via `powerprofilesctl`.
- **`airplane <on | off>`**: Atomically blocks/unblocks all wireless radios (`rfkill`), preserving previous state for recovery.

### 1.3 Desktop Appearance & Geometry (`poly-shell appearance`)

Controls window margins, gaps, border radius, panel opacity, and compositor blur:

```bash
poly-shell appearance <get | apply | reset | install> [payload_json]
```

- **`get`**: Returns current visual parameters dictionary.
- **`apply <json>`**: Atomically applies appearance settings (validates ranges for `windowGap`, `windowMargin`, `windowRadius`, `panelOpacity`, etc.), updates Hyprland runtime via IPC, and syncs `mako-theme.conf`.
- **`reset`**: Restores default appearance parameters.

### 1.4 Themes & Palette (`poly-shell theme`)

```bash
poly-shell theme <list | apply | import> [payload_json]
```

- **`list`**: Returns all available built-in and user-imported wallpaper themes.
- **`apply '{"theme": "<name>"}'`**: Loads theme JSON, recomputes palette, sets wallpaper, and syncs GTK/terminal palettes.
- **`import '{"path": "</path/to/image>"}'`**: Generates a new theme from a custom image using Pillow color extraction.

### 1.5 Desktop Widgets & Telemetry (`poly-shell widgets`)

```bash
poly-shell widgets <get | apply | weather | search | metrics> [payload_json]
```

- **`get`**: Returns coordinates, dimensions, and visibility flags for all desktop widgets (`clock`, `companion`, `music`, `weather`, `developer`, `apps`).
- **`apply <json>`**: Persists new widget layout and positions.
- **`weather`**: Queries Open-Meteo forecast cache.
- **`metrics`**: Returns a real-time snapshot of CPU, GPU, RAM, Disk, Network, and top processes (`poly_shell.developer_metrics`).

### 1.6 Keybindings & Shortcuts (`poly-shell shortcuts`)

```bash
poly-shell shortcuts <get | apply> [payload_json]
```

- **`get`**: Returns list of managed Hyprland keybindings.
- **`apply <json>`**: Validates keysyms against `libxkbcommon`, verifies no conflicting submaps, and generates atomic Hyprland bind configuration with rollback protection.

---

## 2. Quickshell IPC Interface (`Quickshell.IpcHandler`)

Quickshell exposes IPC targets accessible over the Wayland/Quickshell socket via `quickshell ipc <target> <method> [args...]`.

### 2.1 Core Shell Target (`target: "shell"`)

- **`status()`**: Returns serialized JSON string containing readiness, current mode, screen count, workspace ID, battery status, audio, and desktop status.
- **`mode(value: string)`**: Sets mode to `"work"`, `"vibe"`, or `"toggle"`.
- **`desktopAction(action: string, value: string)`**: Proxies validated control actions to `Desktop.request()`.
- **`eval(code: string)`**: Executes internal debugging expression (development only).

### 2.2 Top Bar Target (`target: "bar-<screen>"` & `target: "bar-popup-<screen>"`)

- **`popup(name: string)`**: Opens designated popup panel (`"day"`, `"music"`, `"notifications"`, `"clipboard"`, `"quick"`).
- **`closePopup()`**: Closes active popup.
- **`toggle(name: string)`**: Toggles specific popup.

### 2.3 Workspace Overview (`target: "overview"`)

- **`open()`**: Activates full-screen workspace overview and window expose view.
- **`close()`**: Exits overview.
- **`toggle()`**: Toggles overview.

### 2.4 Developer Metrics (`target: "developer-metrics"`)

- **`openDetails()`**: Opens full-screen detailed developer metrics modal panel.
- **`closeDetails()`**: Closes detailed metrics modal panel.
- **`refresh()`**: Triggers immediate telemetry sample.
- **`status()`**: Returns current polling rate, network throughput, and snapshot data.

### 2.5 Clipboard History (`target: "clipboard"`)

- **`open()`** / **`close()`** / **`toggle()`**: Controls clipboard history popup.
- **`clear()`**: Clears transient clipboard history.

---

## 3. Theme Semantic Color Contract (`Theme.color()`)

ALPORA enforces a strict semantic color contract defined in [`shell/theme/Theme.qml`](file:///d:/code/alpora/shell/theme/Theme.qml). Components **must never hardcode raw hex colors**. All visual materials resolve through `Theme.color(hexString)`.

### 3.1 Mapping Algorithm

The function converts the input reference color to HSV and luminance, mapping it to the active semantic palette:

```
                  ┌────────────────────────────────────────┐
                  │ Input Color Hex (e.g., "#272d2d")      │
                  └──────────────────┬─────────────────────┘
                                     │
                    Calculate Saturation, Hue, Lightness
                                     │
        ┌────────────────────────────┼────────────────────────────┐
        ▼                            ▼                            ▼
Saturation > 0.10 &           Light > 0.80                 Light <= 0.13
Light > 0.48:                 -> palette.text              -> mix(background, #000)
- Warm hue -> secondary       Light > 0.54
- Blue hue -> cool            -> palette.muted
- Else     -> accent          Light > 0.33
                              -> mix(surface, accent)
                              Light > 0.19
                              -> mix(background, surface)
```

### 3.2 Palette Contract Reference Table

| Evaluated Light Range | Semantic Palette Target | Usage Example |
|:---|:---|:---|
| `Light > 0.80` | `palette.text` | Primary body text, titles, headings |
| `0.54 < Light <= 0.80` | `palette.muted` | Secondary descriptions, timestamps, borders |
| `0.33 < Light <= 0.54` | `mix(surface, accent, t)` | Card hover outlines, interactive focus rings |
| `0.19 < Light <= 0.33` | `mix(background, surface, t)` | Primary surface cards, widget backgrounds |
| `0.13 < Light <= 0.19` | `mix(background, surface, t)` | Inset containers, text input backgrounds |
| `Light <= 0.13` | `mix(background, #000, 0.18)` | Deep modal backdrop shadows, scrim layers |

### 3.3 Golden Rules for Component Authors

1. **Always use `Theme.color("#rrggbb")`** for static color tokens or read directly from `Session.foreground`, `Session.muted`, `Session.accent`, `Session.background`.
2. **Never hardcode hex values directly into `color:` properties** without wrapping in `Theme.color()`, `Session.*`, or `Glass.tint()`.
3. **Respect reduced motion**: Check `Motion.reduced` or `Session.motionMs` for any transition animations.
4. **All user-facing strings must use `I18n.tr("key")`** with matching entries across `assets/locales/{en,vi,ru,es}.json`.
