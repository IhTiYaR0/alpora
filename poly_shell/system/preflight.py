"""Pre-flight environment inspector for tester readiness and triage."""
from __future__ import annotations

import json
import os
import shutil
import tempfile
from pathlib import Path
from typing import Any

from ..adapters.hyprland import HyprlandAdapter
from .diagnostics import get_os_release
from .programs import inventory


def check_directory_writable(directory: Path) -> bool:
    """Verify that a directory exists and is writable (or can be created)."""
    try:
        directory.mkdir(parents=True, exist_ok=True)
        test_file = directory / f".write_test_{os.getpid()}"
        test_file.write_text("ok", encoding="utf-8")
        test_file.unlink(missing_ok=True)
        return True
    except (OSError, PermissionError):
        return False


def check_xdg_permissions(paths: Any) -> list[dict[str, Any]]:
    """Verify write permissions on required XDG configuration and state folders."""
    dirs_to_check = [
        ("Configuration", getattr(paths, "config", Path.home() / ".config/poly-shell")),
        ("State Data", getattr(paths, "state", Path.home() / ".local/state/poly-shell")),
        ("Runtime Socket", getattr(paths, "runtime", Path(tempfile.gettempdir()) / "poly-shell-runtime")),
    ]
    results = []
    for label, folder in dirs_to_check:
        path_obj = Path(folder)
        writable = check_directory_writable(path_obj)
        results.append({
            "name": label,
            "path": str(path_obj),
            "writable": writable,
        })
    return results


def check_compositor() -> dict[str, Any]:
    """Check Hyprland session and monitor configuration."""
    instance = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    wayland_display = os.environ.get("WAYLAND_DISPLAY", "")
    hyprctl_ready = HyprlandAdapter.is_available()
    monitors = HyprlandAdapter.get_monitors() if hyprctl_ready else []

    return {
        "inside_hyprland": bool(instance and wayland_display),
        "instance_signature": instance,
        "wayland_display": wayland_display,
        "hyprctl_available": hyprctl_ready,
        "monitors": monitors,
        "monitor_count": len(monitors),
    }


def run_preflight(paths: Any) -> dict[str, Any]:
    """Execute all pre-flight checks and return structured diagnostic status."""
    os_info = get_os_release()
    compositor_info = check_compositor()
    permissions_info = check_xdg_permissions(paths)
    prog_inventory = inventory()

    required_items = [p for p in prog_inventory if p.get("required")]
    optional_items = [p for p in prog_inventory if not p.get("required")]

    missing_required = [p for p in required_items if not p.get("available")]
    missing_optional = [p for p in optional_items if not p.get("available")]

    permissions_ok = all(d["writable"] for d in permissions_info)
    ready = (len(missing_required) == 0) and permissions_ok

    return {
        "ready": ready,
        "os": os_info,
        "compositor": compositor_info,
        "permissions": permissions_info,
        "tools": {
            "required_count": len(required_items),
            "required_available": len(required_items) - len(missing_required),
            "missing_required": missing_required,
            "optional_count": len(optional_items),
            "optional_available": len(optional_items) - len(missing_optional),
            "missing_optional": missing_optional,
        },
    }


def format_preflight_report(report: dict[str, Any]) -> str:
    """Format structured report into a readable terminal checklist."""
    lines: list[str] = []
    lines.append("=" * 60)
    lines.append("          ALPORA / POLY-SHELL PRE-FLIGHT CHECKLIST          ")
    lines.append("=" * 60)

    # 1. Operating System
    os_name = report["os"].get("PRETTY_NAME") or report["os"].get("NAME", "Linux")
    lines.append(f"\n[OS] {os_name}")

    # 2. Wayland / Hyprland
    comp = report["compositor"]
    if comp["inside_hyprland"]:
        mon_summary = f"{comp['monitor_count']} monitor(s) detected"
        lines.append(f"[OK] Hyprland Compositor: ACTIVE ({mon_summary})")
    else:
        status = "[WARN]" if comp["hyprctl_available"] else "[INFO]"
        lines.append(f"{status} Hyprland Compositor: NOT ACTIVE in current terminal")
        lines.append("     (Shell can be installed, but must be run inside a Hyprland Wayland session)")

    # 3. Permissions
    lines.append("\n[Storage & Permissions]")
    for perm in report["permissions"]:
        tag = "[OK]  " if perm["writable"] else "[FAIL]"
        lines.append(f"  {tag} {perm['name']:15}: {perm['path']}")

    # 4. Required Dependencies
    tools = report["tools"]
    lines.append(f"\n[Core Dependencies] ({tools['required_available']}/{tools['required_count']})")
    if not tools["missing_required"]:
        lines.append("  [OK]   All core shell packages are installed.")
    else:
        for item in tools["missing_required"]:
            lines.append(f"  [FAIL] Missing: {item['name']} (Package: {item['package']}) - {item['purpose']}")

    # 5. Optional Integrations
    lines.append(f"\n[Optional Integrations] ({tools['optional_available']}/{tools['optional_count']})")
    if not tools["missing_optional"]:
        lines.append("  [OK]   All optional integrations are present.")
    else:
        for item in tools["missing_optional"][:6]:
            lines.append(f"  [OPT]  {item['name']} ({item['package']}): {item['purpose']}")
        remaining = len(tools["missing_optional"]) - 6
        if remaining > 0:
            lines.append(f"  ... và {remaining} gói tùy chọn khác.")

    # 6. Final Recommendation
    lines.append("\n" + "=" * 60)
    if report["ready"]:
        lines.append("STATUS: READY FOR INSTALLATION / SHELL EXECUTION")
        lines.append("Gợi ý: Bạn có thể chạy './install/install.sh --ui-only' để kiểm thử an toàn.")
    else:
        lines.append("STATUS: INCOMPLETE PREREQUISITES")
        lines.append("Gợi ý: Cài đặt các gói cốt lõi bị [FAIL] trước khi khởi chạy shell.")
    lines.append("=" * 60)

    return "\n".join(lines)
