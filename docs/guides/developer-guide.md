# ALPORA Developer Guide

This guide walks you through extending ALPORA with new themes, desktop widgets, QML components, and localized languages.

---

## 1. Architecture Overview

ALPORA is built with a reactive, decoupled architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                       QUICKSHELL (QML)                      │
│   TopBar · Dock · QuickSettings · Widgets · Notifications   │
│   Theme.qml · Session.qml · I18n.qml · WidgetGeometry.js    │
└──────────────┬──────────────────────────────▲───────────────┘
               │ Process execution (execve)   │ JSON file-watch
               │ poly-shell <cmd>             │ ~/.config/poly-shell/session.json
               ▼                              │
┌─────────────────────────────────────────────┴───────────────┐
│                      PYTHON BACKEND (poly_shell)            │
│   themes.py · widgets.py · hardware.py · developer_metrics  │
│   running_apps.py · shortcuts.py · appearance.py · state.py │
└──────────────┬──────────────────────────────┬───────────────┘
               │ D-Bus / Pipewire / UPower    │ IPC socket
               ▼                              ▼
┌──────────────────────────────┐ ┌────────────────────────────┐
│         LINUX SUBSYSTEM      │ │    HYPRLAND COMPOSITOR     │
└──────────────────────────────┘ └────────────────────────────┘
```

- **Frontend (`shell/`)**: Native QML components executed by Quickshell. All UI state is reactive. No periodic subprocess polling in components.
- **Backend (`poly_shell/`)**: Modular Python package managing file persistence, theme generation, IPC adapters, and system diagnostics.
- **Data flow**: The backend writes atomic JSON snapshots to `~/.config/poly-shell/session.json`. QML binds to this via `FileView { watchChanges: true }` in [`Session.qml`](file:///d:/code/alpora/shell/Session.qml).

---

## 2. Adding a New Theme

ALPORA generates complete system palettes (GTK, terminal, shell, notifications, lockscreen) from wallpaper images.

### Step 1: Add the Wallpaper Asset
Place the wallpaper image under `assets/wallpapers/<theme-name>/`:
```
assets/wallpapers/my-theme/
└── my-theme.jpg
```

### Step 2: Extract the Palette
Use the Python helper to extract semantic colors using Pillow:
```python
from pathlib import Path
from poly_shell.themes import extract_palette

wallpaper_path = Path("assets/wallpapers/my-theme/my-theme.jpg")
palette = extract_palette(wallpaper_path)
print(palette)
```

### Step 3: Define the Theme JSON
Create `assets/themes/<theme-name>.json`:
```json
{
  "name": "my-theme",
  "label": "My Theme",
  "wallpaper": "assets/wallpapers/my-theme/my-theme.jpg",
  "palette": {
    "accent": "#a8d5bc",
    "secondary": "#edb493",
    "cool": "#9cc8df",
    "background": "#1c2222",
    "surface": "#272d2d",
    "text": "#e7e9e5",
    "muted": "#8d9894"
  },
  "gtkTheme": "Adwaita-dark",
  "iconTheme": "Papirus-Dark"
}
```

### Step 4: Register in Whitelist
Add `<theme-name>` to `THEMES` whitelist in `poly_shell/themes.py` and `shell/logic/AppearanceCatalog.js`.

### Step 5: Test the Theme
```bash
poly-shell theme apply '{"theme": "my-theme"}'
```

---

## 3. Creating a New Desktop Widget

Desktop widgets reside on the wallpaper layer behind applications.

### Step 1: Backend Registration (`poly_shell/widgets.py`)
Add the widget key to `DEFAULTS` in `poly_shell/widgets.py`:
```python
DEFAULTS = {
    # ...
    "my_widget": {"enabled": True, "x": 100, "y": 200, "locked": False},
}
```
Update `validate()` to migrate legacy widget configurations without schema validation errors.

### Step 2: Widget Geometry (`shell/logic/WidgetGeometry.js`)
Register the widget size and bounding box in `shell/logic/WidgetGeometry.js`:
```javascript
const SIZES = {
    // ...
    my_widget: { width: 360, height: 180 },
};

function boundsForSize(name, screenWidth, screenHeight) {
    // Return maximum allowed x/y bounds
}
```

### Step 3: Create the QML Component
Create `shell/DesktopMyWidget.qml`:
```qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

DesktopWidgetCard {
    id: root
    implicitWidth: 360; implicitHeight: 180

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 14; spacing: 8
        Text {
            text: I18n.tr("widget.my_widget_title")
            color: Session.foreground
            font.family: Session.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        // Widget contents...
    }
}
```

### Step 4: Register in `shell/qmldir`
```text
DesktopMyWidget 1.0 DesktopMyWidget.qml
```

### Step 5: Wire into Desktop Container
In [`shell/DesktopWidgets.qml`](file:///d:/code/alpora/shell/DesktopWidgets.qml):
- Add `"my_widget"` to the `Variants` model list.
- Instantiate `DesktopMyWidget { visible: modelData === "my_widget" }`.

In [`shell/SettingsWidgets.qml`](file:///d:/code/alpora/shell/SettingsWidgets.qml):
- Add widget selection toggle button and thumbnail preview.

---

## 4. Component Design & Localization Standards

### 4.1 Theme Semantic Colors
Always resolve colors via `Session` or `Theme.color()`:
```qml
// CORRECT:
color: Session.foreground
color: Theme.color("#272d2d")
color: Glass.tint(Session.accent, 0.16)

// FORBIDDEN:
color: "#a8d5bc" // Hardcoded Sage (Alpine theme leak)
color: "#7e57c2" // Hardcoded Purple (Faceted theme leak)
```

### 4.2 Internationalization (`I18n.tr`)
Never display raw string literals to the user.
```qml
// CORRECT:
Text { text: I18n.tr("common.apply") }
Text { text: I18n.trWith("settings.zoom_level", { level: 100 }) }

// FORBIDDEN:
Text { text: "Apply" }
Text { text: "Применить" }
```

### 4.3 Adding New Translation Keys
Add the key across **all 4 supported locales**:
- [`assets/locales/en.json`](file:///d:/code/alpora/assets/locales/en.json) (Baseline)
- [`assets/locales/vi.json`](file:///d:/code/alpora/assets/locales/vi.json) (Vietnamese)
- [`assets/locales/ru.json`](file:///d:/code/alpora/assets/locales/ru.json) (Russian)
- [`assets/locales/es.json`](file:///d:/code/alpora/assets/locales/es.json) (Spanish)

Run the test suite to verify 100% key parity:
```bash
python -m unittest tests/test_i18n.py
```

---

## 5. Testing & Code Quality

ALPORA maintains a strict automated test suite:
- **Unit tests**: `python -m unittest discover tests`
- **Key individual tests**:
  - `python -m unittest tests/test_i18n.py`: Locale integrity & key parity.
  - `python -m unittest tests/test_widgets.py`: Layout persistence & widget migration.
  - `python -m unittest tests/test_desktop.py`: Action validation & backlight adapters.
  - `python -m unittest tests/test_running_apps.py`: Process tracking & signals.
  - `python -m unittest tests/test_appearance.py`: Atomic rollback on config failure.

Always ensure unit tests pass before committing changes.
