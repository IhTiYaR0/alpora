"""Detect portable-device capabilities without probing or changing hardware."""
from __future__ import annotations

from pathlib import Path
import shutil

# SMBIOS chassis types known to describe portable systems: portable, laptop,
# notebook, sub-notebook, tablet, convertible and detachable.
_PORTABLE_CHASSIS_TYPES = {8, 9, 10, 14, 30, 31, 32}
# Types commonly used for fixed desktops/workstations. Types 0/1/2 are often
# unspecified, so those fall back to the presence of a battery.
_FIXED_CHASSIS_TYPES = {3, 4, 5, 6, 7, 13, *range(15, 30), 35, 36}


def _chassis_type(sys_root: Path) -> int | None:
    try:
        return int((sys_root / "class/dmi/id/chassis_type").read_text(encoding="ascii").strip())
    except (OSError, ValueError):
        return None


def _has_battery(sys_root: Path) -> bool:
    root = sys_root / "class/power_supply"
    try:
        devices = sorted(root.iterdir())
    except OSError:
        return False
    for device in devices:
        try:
            if (device / "type").read_text(encoding="ascii").strip().lower() == "battery":
                return True
        except OSError:
            continue
    return False


def _backlight_device(sys_root: Path) -> str | None:
    root = sys_root / "class/backlight"
    try:
        devices = sorted(root.iterdir())
    except OSError:
        return None
    for device in devices:
        try:
            maximum = int((device / "max_brightness").read_text(encoding="ascii").strip())
            _ = int((device / "brightness").read_text(encoding="ascii").strip())
            if maximum > 0:
                return device.name
        except (OSError, ValueError):
            continue
    return None


def detect_hardware_profile(
    sys_root: Path | str = Path("/sys"),
    brightnessctl: str | None = None,
) -> dict[str, object]:
    """Return a serializable device profile, recalculated at session startup.

    SMBIOS is preferred when it identifies a portable or fixed chassis. If it
    is missing/unspecified, an actual Linux power-supply battery is the fallback.
    Brightness is exposed only when the device is portable, a usable backlight
    exists, and brightnessctl is available to the current user.
    """
    root = Path(sys_root)
    battery_found = _has_battery(root)
    chassis = _chassis_type(root)
    if chassis in _PORTABLE_CHASSIS_TYPES:
        is_laptop = True
    elif chassis in _FIXED_CHASSIS_TYPES:
        is_laptop = False
    else:
        is_laptop = battery_found

    backlight = _backlight_device(root)
    brightness_tool = shutil.which("brightnessctl") if brightnessctl is None else brightnessctl
    return {
        "deviceClass": "laptop" if is_laptop else "desktop",
        "isLaptop": is_laptop,
        "batteryAvailable": bool(is_laptop and battery_found),
        "backlightName": backlight or "",
        "backlightAvailable": bool(backlight),
        "brightnessAvailable": bool(is_laptop and backlight and brightness_tool),
    }
