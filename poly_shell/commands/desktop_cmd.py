"""Command handler for desktop controls, wallpaper, OSD, lockscreen, and system integration."""
import json
import subprocess
from ..adapters.base import SafeRunner
from ..system.desktop import control, wallpaper
from ..system.indicators import show_indicator
from ..system.lockscreen import lock_date
from ..core.state import ConfigError, ROOT


def handle_control(paths, args) -> int:
    CONTROL_ACTIONS = {
        "status": "status", "brightness": "brightness", "dnd": "dnd",
        "nightlight": "nightlight", "bluetooth": "bluetooth",
        "power-profile": "power-profile", "airplane": "airplane",
        "hotspot": "hotspot", "wifi-connect": "wifi-connect",
        "ui-scale": "ui-scale", "touchpad": "touchpad", "font": "font",
        "caffeine": "caffeine", "gamemode": "gamemode", "phone": "phone",
        "locale": "locale"
    }
    safe_action = CONTROL_ACTIONS.get(args.action)
    if not safe_action:
        raise ConfigError(f"Unknown control action: {args.action}")
    print(json.dumps(control(paths, safe_action, args.value)))
    return 0


def handle_wallpaper(paths, args) -> int:
    if args.image and (str(args.image).startswith('-') or any(c in str(args.image) for c in ('\x00', '\r', '\n'))):
        raise ConfigError("Invalid wallpaper argument")
    wallpaper(paths, args.image, reset=args.reset)
    return 0


def handle_project(paths, args) -> int:
    from pathlib import Path
    ALLOWED_MODES = {
        "toggle": "toggle", "open": "open", "close": "close",
        "internal": "internal", "mirror": "mirror",
        "extend": "extend", "external": "external"
    }
    safe_mode = ALLOWED_MODES.get(args.mode, "toggle")
    entries = [ROOT / "shell", Path.home() / ".config/quickshell/poly-shell"]
    for entry in entries:
        if safe_mode in ("toggle", "open", "close"):
            cmd = ["quickshell", "ipc", "--path", str(entry), "call", "display-project", safe_mode]
        else:
            cmd = ["quickshell", "ipc", "--path", str(entry), "call", "display-project", "setMode", safe_mode]
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=2)
            if res.returncode == 0:
                print(f"Display projection: {safe_mode}")
                return 0
        except (OSError, subprocess.SubprocessError):
            continue
    raise ConfigError("Cannot connect to running Poly Shell for display projection")


def handle_dotfiles(paths, args) -> int:
    script = (ROOT / "scripts/stow-dotfiles.sh").resolve()
    if args.action in ("status", "check"):
        cmd_action = "status"
    elif args.action in ("link", "stow", "apply"):
        cmd_action = "link"
    elif args.action in ("unlink", "unstow", "delete"):
        cmd_action = "unlink"
    elif args.action == "restow":
        cmd_action = "restow"
    else:
        raise ConfigError(f"Invalid dotfiles action: {args.action}")
    return subprocess.run(["bash", "--", str(script), cmd_action], check=False).returncode


def handle_windows_drives(paths, args) -> int:
    from ..system.windows_fs import detect_windows_drives, mount_drive, unmount_drive, normalize_windows_path
    if args.action == "list":
        print(json.dumps(detect_windows_drives(), ensure_ascii=False))
    elif args.action == "mount":
        print(json.dumps({"mountpoint": mount_drive(args.target)}, ensure_ascii=False))
    elif args.action == "unmount":
        print(json.dumps({"success": unmount_drive(args.target)}, ensure_ascii=False))
    elif args.action == "normalize-path":
        print(normalize_windows_path(args.target))
    return 0


def handle_osd(paths, args) -> int:
    if args.kind in ("capslock", "numlock", "airplane"):
        state_val = getattr(args, 'state', 'on') == 'on'
        SafeRunner.run(['quickshell', 'ipc', '--path', str(ROOT / 'shell'), 'call', 'shell', 'showToggleOsd', args.kind, "true" if state_val else "false"], timeout=3.0)
    else:
        OSD_MAP = {'brightness': 'brightness', 'volume': 'volume', 'microphone': 'microphone'}
        safe_kind = OSD_MAP.get(args.kind)
        if not safe_kind:
            raise ConfigError(f"Invalid OSD indicator: {args.kind}")
        show_indicator(safe_kind)
    return 0


def handle_lock_date(paths, args) -> int:
    print(lock_date())
    return 0


def handle_lock_media(paths, args) -> int:
    from ..system.lock_media import handle_cli
    handle_cli(args.field)
    return 0

