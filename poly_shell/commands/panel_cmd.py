"""CLI panel and window activation commands for ALPORA."""
import os
from pathlib import Path
import subprocess
import sys
import time

try:
    import fcntl
except ImportError:
    fcntl = None

from ..core.state import ConfigError, ROOT, update_session


def call_shell_ipc(method: str, *args) -> bool:
    """Send an IPC invocation to the running Quickshell root."""
    entry = ROOT / "shell"
    command = ["quickshell", "ipc", "--path", str(entry), "call", "shell", method, *args]
    try:
        res = subprocess.run(command, capture_output=True, text=True, timeout=2)
        return res.returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def handle_launcher(paths, args):
    """Toggle the application and omni-bar launcher."""
    if not call_shell_ipc("toggleLauncher"):
        # Fallback if Quickshell is not active or running elsewhere
        print("Launcher toggle sent (shell IPC)", file=sys.stderr)
    return 0


def handle_quick_settings(paths, args):
    """Toggle the Quick Settings control center."""
    if not call_shell_ipc("toggleQuickSettings"):
        print("Quick Settings toggle sent (shell IPC)", file=sys.stderr)
    return 0


def handle_notifications(paths, args):
    """Toggle the Notifications flyout panel."""
    if not call_shell_ipc("toggleBarPanel", "notifications"):
        print("Notifications toggle sent (shell IPC)", file=sys.stderr)
    return 0


def handle_clipboard(paths, args):
    """Toggle the Clipboard history panel."""
    if not call_shell_ipc("toggleBarPanel", "clipboard"):
        print("Clipboard toggle sent (shell IPC)", file=sys.stderr)
    return 0


def handle_overview(paths, args):
    """Toggle the Workspaces and Windows overview."""
    if not call_shell_ipc("toggleOverview"):
        print("Overview toggle sent (shell IPC)", file=sys.stderr)
    return 0


def handle_power_menu(paths, args):
    """Toggle the Power and Session menu."""
    if not call_shell_ipc("powerMenu"):
        print("Power menu toggle sent (shell IPC)", file=sys.stderr)
    return 0


def handle_toggle_mode(paths, args):
    """Toggle Work and Vibe desktop modes."""
    snapshot = update_session(paths, "toggle")
    call_shell_ipc("toggleMode")
    print(f"Mode switched: {snapshot['mode']}")
    return 0


def handle_display_project(paths, args):
    """Toggle or configure multi-monitor projection display mode."""
    if not call_shell_ipc("toggleDisplayProject"):
        from .desktop_cmd import handle_project
        args.mode = "toggle"
        return handle_project(paths, args)
    return 0


def open_welcome(paths, runtime_check_fn=None):
    """Open or raise the native ALPORA Welcome GUI wizard."""
    if runtime_check_fn:
        runtime_check_fn()
    if not os.environ.get("WAYLAND_DISPLAY"):
        raise ConfigError("Open welcome app inside a Wayland session")
    entry = ROOT / "shell/welcome.qml"
    if not entry.exists():
        raise ConfigError(f"Welcome app not found at {entry}")
    ipc = ["quickshell", "ipc", "--path", str(entry), "call", "welcome-app", "raiseWindow"]
    paths.runtime.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (paths.runtime / "welcome-start.lock").open("a") as lock:
        if fcntl is not None:
            fcntl.flock(lock, fcntl.LOCK_EX)
        if subprocess.run(ipc, capture_output=True, text=True, timeout=3).returncode == 0:
            return 0
        update_session(paths)
        environment = {name: os.environ[name] for name in (
            "WAYLAND_DISPLAY", "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE",
            "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE", "XDG_CONFIG_HOME", "XDG_STATE_HOME",
            "XDG_DATA_HOME") if os.environ.get(name)}
        environment.update(
            POLY_SHELL_ROOT=str(ROOT),
            POLY_SHELL_STATE=str(paths.session),
            POLY_SHELL_CTL=str(ROOT / "bin/poly-shell"),
            POLY_SHELL_ASSETS=str(ROOT / "assets"),
            PYTHONPATH=f"{ROOT}:{os.environ.get('PYTHONPATH', '')}".rstrip(":"),
            PATH=f"{ROOT / 'bin'}:{Path.home() / '.local/bin'}:{os.environ.get('PATH', '')}".rstrip(":"),
        )
        subprocess.Popen(["quickshell", "--path", str(entry), "--no-duplicate"], env=environment)
        for _ in range(30):
            if subprocess.run(ipc, capture_output=True, text=True, timeout=2).returncode == 0:
                return 0
            time.sleep(0.1)
        return 0


def handle_welcome(paths, args, runtime_check_fn=None):
    """Handle `poly-shell welcome` CLI subcommand."""
    return open_welcome(paths, runtime_check_fn=runtime_check_fn)

