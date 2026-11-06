"""Automated diagnostic bundle collector for tester triage."""
from __future__ import annotations

import io
import json
import os
import platform
import shutil
import subprocess
import tarfile
from datetime import datetime
from pathlib import Path
from typing import Any

from .hardware import detect_hardware_profile
from .programs import inventory


def sanitize_dict(data: dict[str, Any]) -> dict[str, Any]:
    """Return a shallow sanitized copy of a dictionary, masking secret keys."""
    sensitive_patterns = ("secret", "password", "token", "key", "credential", "auth")
    sanitized: dict[str, Any] = {}
    for key, value in data.items():
        if any(pat in key.lower() for pat in sensitive_patterns):
            sanitized[key] = "[REDACTED]"
        elif isinstance(value, dict):
            sanitized[key] = sanitize_dict(value)
        else:
            sanitized[key] = value
    return sanitized


def get_os_release() -> dict[str, str]:
    """Parse /etc/os-release if available, else platform info."""
    os_release = Path("/etc/os-release")
    result: dict[str, str] = {}
    if os_release.exists():
        try:
            for line in os_release.read_text(encoding="utf-8", errors="replace").splitlines():
                if "=" in line and not line.startswith("#"):
                    k, v = line.split("=", 1)
                    result[k.strip()] = v.strip().strip('"')
        except OSError:
            pass
    if not result:
        result = {
            "NAME": platform.system(),
            "RELEASE": platform.release(),
            "VERSION": platform.version(),
        }
    return result


def get_hyprland_monitors() -> list[Any] | str:
    """Query active monitors via hyprctl if available."""
    if not shutil.which("hyprctl"):
        return "hyprctl not installed"
    try:
        proc = subprocess.run(
            ["hyprctl", "monitors", "-j"],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            return json.loads(proc.stdout)
        return proc.stderr.strip() or "hyprctl exited with error"
    except Exception as exc:
        return f"failed to query monitors: {exc}"


def get_journal_logs(unit: str, lines: int = 100) -> str:
    """Retrieve recent journalctl logs for a user unit."""
    if not shutil.which("journalctl"):
        return "journalctl not available"
    try:
        proc = subprocess.run(
            ["journalctl", "--user", "-u", unit, "-n", str(lines), "--no-pager"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        return proc.stdout.strip() if proc.returncode == 0 else f"Failed to read logs: {proc.stderr.strip()}"
    except Exception as exc:
        return f"Error running journalctl: {exc}"


def collect_diagnostic_bundle(paths: Any, output_dir: Path | str | None = None) -> Path:
    """Collect non-sensitive logs, hardware state and versions into a tar.gz archive."""
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    bundle_name = f"alpora-diag-{timestamp}"

    target_dir = Path(output_dir) if output_dir else Path.cwd()
    target_dir.mkdir(parents=True, exist_ok=True)
    archive_path = target_dir / f"{bundle_name}.tar.gz"

    # 1. Environment & OS
    env_keys = (
        "WAYLAND_DISPLAY",
        "DISPLAY",
        "HYPRLAND_INSTANCE_SIGNATURE",
        "XDG_CURRENT_DESKTOP",
        "XDG_SESSION_TYPE",
        "XDG_CONFIG_HOME",
        "XDG_STATE_HOME",
        "XDG_DATA_HOME",
        "SHELL",
    )
    env_info = {k: os.environ.get(k, "not set") for k in env_keys}
    sys_info = {
        "timestamp": timestamp,
        "os_release": get_os_release(),
        "python_version": platform.python_version(),
        "environment": env_info,
        "hardware_profile": detect_hardware_profile(),
        "hyprland_monitors": get_hyprland_monitors(),
    }

    # 2. Programs inventory
    inv = inventory()

    # 3. Session state if exists
    session_data: dict[str, Any] = {}
    if hasattr(paths, "session") and paths.session.exists():
        try:
            with paths.session.open(encoding="utf-8") as f:
                raw_session = json.load(f)
                session_data = sanitize_dict(raw_session)
        except Exception as exc:
            session_data = {"error": f"Failed to read session: {exc}"}

    # 4. Logs
    poly_shell_logs = get_journal_logs("poly-shell.service", lines=120)
    settings_logs = get_journal_logs("poly-shell-settings.service", lines=80)

    # 5. Pack into tar.gz in memory then write to disk
    with tarfile.open(archive_path, "w:gz") as tar:
        def add_str_file(name: str, content: str):
            data = content.encode("utf-8")
            info = tarfile.TarInfo(name=f"{bundle_name}/{name}")
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))

        def add_json_file(name: str, obj: Any):
            content = json.dumps(obj, indent=2, ensure_ascii=False)
            add_str_file(name, content)

        add_json_file("system_info.json", sys_info)
        add_json_file("inventory.json", inv)
        add_json_file("session_state.json", session_data)
        add_str_file("poly-shell.log", poly_shell_logs)
        add_str_file("settings.log", settings_logs)

    return archive_path
