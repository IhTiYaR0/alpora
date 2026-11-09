"""Lifecycle CLI. No shell interpolation and no system-wide package changes."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

from . import __version__
from .integration import fallback_panel, install, patch_autostart, restore_autostart
from .state import ConfigError, MODES, Paths, ROOT, current_mode, update_session
from .desktop import control, wallpaper, restore_desktop
from .organizer import organizer
from .indicators import show_indicator, sync_notifications
from .lockscreen import lock_date, sync_lockscreen
from .appearance import appearance_control, sync as sync_appearance
from .themes import theme_control
from .timeline import timeline_control
from .widgets import widgets_control
from .shortcuts import shortcuts_control
from .programs import inventory


def systemctl(*arguments, check=True, capture=False):
    return subprocess.run(["systemctl", "--user", *arguments], check=check,
                          capture_output=capture, text=True)


def runtime_check():
    if not shutil.which("quickshell"):
        raise ConfigError("quickshell is missing; install it using your package manager")
    result = subprocess.run(["quickshell", "--version"], capture_output=True, text=True, timeout=10)
    if result.returncode:
        raise ConfigError(
            "Quickshell cannot start. On Arch, complete sudo pacman -Syu first.\n"
            + (result.stderr or result.stdout).strip()
        )
    return result.stdout.strip() or result.stderr.strip()


def run(paths):
    runtime_check()
    if not os.environ.get("WAYLAND_DISPLAY"):
        raise ConfigError("Run inside a Wayland session")
    update_session(paths)
    sync_appearance(paths)
    sync_notifications(paths)
    sync_lockscreen(paths)
    paths.runtime.mkdir(mode=0o700, parents=True, exist_ok=True)
    ready = paths.runtime / "ready"
    with (paths.runtime / "instance.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise ConfigError("Poly Shell is already running") from exc
        ready.unlink(missing_ok=True)
        try:
            restore_desktop(paths)
        except (ConfigError, OSError, subprocess.SubprocessError) as exc:
            print(f"Night Light restore failed: {exc}", file=sys.stderr)
        environment = dict(os.environ, POLY_SHELL_STATE=str(paths.session),
                           POLY_SHELL_READY=str(ready), POLY_SHELL_CTL=str(ROOT / "bin/poly-shell"),
                           POLY_SHELL_ASSETS=str(ROOT / "assets"))
        process = subprocess.Popen(["quickshell", "--path", str(ROOT / "shell")], env=environment)
        stopping = False

        def stop(_signum, _frame):
            nonlocal stopping
            stopping = True
            if process.poll() is None:
                process.terminate()

        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        try:
            result = process.wait()
            return 0 if stopping else result
        finally:
            ready.unlink(missing_ok=True)


def start(paths):
    runtime_check()
    ready = paths.runtime / "ready"
    already_active = systemctl("is-active", "--quiet", "poly-shell.service", check=False).returncode == 0
    if not already_active:
        ready.unlink(missing_ok=True)
    # Whitelist session variables: never import arbitrary environment secrets.
    names = [name for name in ("WAYLAND_DISPLAY", "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE",
                              "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE", "XDG_CONFIG_HOME",
                              "XDG_STATE_HOME") if os.environ.get(name)]
    systemctl("import-environment", *names)
    systemctl("daemon-reload")
    systemctl("reset-failed", "poly-shell.service", check=False, capture=True)
    systemctl("start", "poly-shell.service")
    for _ in range(50):
        if ready.exists() and systemctl("is-active", "--quiet", "poly-shell.service", check=False).returncode == 0:
            print("Poly Shell is ready")
            return
        if systemctl("is-failed", "--quiet", "poly-shell.service", check=False).returncode == 0:
            break
        time.sleep(0.1)
    systemctl("stop", "poly-shell.service", check=False)
    raise ConfigError("Shell did not become ready; existing panel kept. See poly-shell logs")


def doctor(paths):
    ok = True
    print(f"Poly Shell {__version__}\nProject: {ROOT}")
    for item in inventory():
        status = "OK" if item['available'] else "MISSING" if item['required'] else "OPTIONAL MISSING"
        missing = [name for name,value in item['tools'].items() if not value]
        print(f"{status} {item['name']} [{item['package']}]: {item['purpose']}" + ("; missing: " + ", ".join(missing) if missing else ""))
        if item['required'] and not item['available']: ok = False
    if not shutil.which("foot") and not shutil.which("kitty"):
        print("OPTIONAL MISSING terminal: install foot or kitty, or configure apps.terminal")
    try:
        print("OK " + runtime_check())
    except ConfigError as exc:
        print("BLOCKED " + str(exc))
        ok = False
    print(f"Settings: {paths.config / 'settings.json'}")
    print(f"Saved session: {paths.session}")
    print(f"Wayland: {os.environ.get('WAYLAND_DISPLAY', 'not set')}")
    return 0 if ok else 1


def open_settings(paths):
    runtime_check()
    if not os.environ.get("WAYLAND_DISPLAY"):
        raise ConfigError("Открой настройки внутри сеанса Wayland")
    entry = ROOT / "shell/settings.qml"
    ipc = ["quickshell", "ipc", "--path", str(entry), "call", "settings-app", "raiseWindow"]
    paths.runtime.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (paths.runtime / "settings-start.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if subprocess.run(ipc, capture_output=True, text=True, timeout=3).returncode == 0:
            return
        update_session(paths)
        # A separate user unit keeps the settings app alive across bar restarts.
        environment = {name: os.environ[name] for name in (
            "WAYLAND_DISPLAY", "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE",
            "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE", "XDG_CONFIG_HOME", "XDG_STATE_HOME",
            "XDG_DATA_HOME") if os.environ.get(name)}
        environment.update(POLY_SHELL_STATE=str(paths.session),
                           POLY_SHELL_CTL=str(ROOT / "bin/poly-shell"),
                           POLY_SHELL_ASSETS=str(ROOT / "assets"))
        active = systemctl("is-active", "--quiet", "poly-shell-settings.service", check=False, capture=True)
        if active.returncode:
            command = ["systemd-run", "--user", "--quiet", "--collect",
                       "--unit=poly-shell-settings", "--service-type=exec",
                       "--description=Poly Shell Settings"]
            command += ["--setenv=" + name + "=" + value for name, value in environment.items()]
            result = subprocess.run(command + ["quickshell", "--path", str(entry), "--no-duplicate"],
                                    capture_output=True, text=True, timeout=10)
            if result.returncode:
                raise ConfigError("Не удалось открыть настройки: " + result.stderr.strip())
        for _ in range(60):
            if subprocess.run(ipc, capture_output=True, text=True, timeout=2).returncode == 0:
                return
            time.sleep(.1)
        raise ConfigError("Окно настроек не запустилось. См. journalctl --user -u poly-shell-settings")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Poly Shell foundation preview")
    parser.add_argument("--version", action="version", version=__version__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("init", "refresh", "doctor", "install", "run", "start", "stop", "restart", "status", "logs", "activate", "deactivate", "settings"):
        sub.add_parser(command)
    wallpaper_parser = sub.add_parser("wallpaper", help="apply and remember a static wallpaper")
    wallpaper_parser.add_argument("image", nargs="?")
    wallpaper_parser.add_argument("--reset", action="store_true")
    mode_parser = sub.add_parser("mode", help="read, set, or toggle the saved mode")
    mode_parser.add_argument("mode", nargs="?", choices=(*MODES, "toggle"))
    mode_parser.add_argument("--json", action="store_true")
    control_parser = sub.add_parser("control", help="desktop adapters for the quick settings panel")
    control_parser.add_argument("action", choices=("status", "brightness", "dnd", "nightlight", "bluetooth", "power-profile", "airplane"))
    control_parser.add_argument("value", nargs="?")
    theme_parser = sub.add_parser("theme", help="wallpaper-derived color themes")
    theme_parser.add_argument("action", choices=("list", "apply", "import"))
    theme_parser.add_argument("payload", nargs="?", default="{}")
    timeline_parser = sub.add_parser("timeline", help="saved time of day for the Timeline theme")
    timeline_parser.add_argument("action", choices=("get", "set", "ready"))
    timeline_parser.add_argument("payload", nargs="?", default="{}")
    widgets_parser = sub.add_parser("widgets", help="desktop widgets, layout and weather")
    widgets_parser.add_argument("action", choices=("get", "apply", "weather", "search"))
    widgets_parser.add_argument("payload", nargs="?", default="{}")
    shortcuts_parser = sub.add_parser("shortcuts", help="edit persistent Hyprland keyboard shortcuts")
    shortcuts_parser.add_argument("action", choices=("get", "apply"))
    shortcuts_parser.add_argument("payload", nargs="?", default="{}")
    assets_parser = sub.add_parser("assets", help="install pinned ALPORA icon and cursor themes")
    assets_parser.add_argument("action", choices=("install", "apply"))
    osd_parser = sub.add_parser("osd", help="show the current system value without changing it")
    osd_parser.add_argument("kind", choices=("volume", "microphone", "brightness"))
    sub.add_parser("lock-date", help="localized lockscreen date, without system locale dependencies")
    sub.add_parser("toolkit-refresh", help="refresh a cached file-manager palette after a theme change")
    appearance_parser = sub.add_parser("appearance", help="validated desktop appearance controls")
    appearance_parser.add_argument("action", choices=("get", "apply", "reset", "install"))
    appearance_parser.add_argument("payload", nargs="?", default="{}")
    organizer_parser = sub.add_parser("organizer", help="local calendar, tasks, notes and focus timer")
    organizer_parser.add_argument("action", choices=("get", "task-add", "event-add", "task-toggle", "item-remove", "note", "timer-start", "timer-pause", "timer-reset", "timer-duration"))
    organizer_parser.add_argument("payload", nargs="?", default="{}")
    args = parser.parse_args(argv)
    paths = Paths.current()
    try:
        if args.command in ("init", "refresh"):
            snapshot = update_session(paths)
            sync_appearance(paths)
            sync_notifications(paths)
            sync_lockscreen(paths)
            print(f"Session ready: {snapshot['mode']} ({paths.session})")
        elif args.command == "mode":
            if args.mode or args.json:
                snapshot = update_session(paths, args.mode)
                sync_notifications(paths)
                sync_lockscreen(paths)
                print(json.dumps(snapshot, ensure_ascii=False) if args.json else snapshot["mode"])
            else:
                print(current_mode(paths))
        elif args.command == "doctor":
            return doctor(paths)
        elif args.command == "control":
            print(json.dumps(control(paths, args.action, args.value)))
        elif args.command == "theme":
            try: payload = json.loads(args.payload)
            except ValueError as exc: raise ConfigError("Неверный JSON темы") from exc
            print(json.dumps(theme_control(paths, args.action, payload), ensure_ascii=False))
        elif args.command == "timeline":
            try: payload = json.loads(args.payload)
            except ValueError as exc: raise ConfigError("Неверный JSON Timeline") from exc
            print(json.dumps(timeline_control(paths, args.action, payload), ensure_ascii=False))
        elif args.command == "widgets":
            try: payload = json.loads(args.payload)
            except ValueError as exc: raise ConfigError("Неверный JSON виджетов") from exc
            if not isinstance(payload, dict): raise ConfigError("Неверный запрос виджетов")
            print(json.dumps(widgets_control(paths, args.action, payload), ensure_ascii=False))
        elif args.command == "shortcuts":
            try: payload = json.loads(args.payload)
            except ValueError as exc: raise ConfigError("Неверный JSON горячих клавиш") from exc
            print(json.dumps(shortcuts_control(paths,args.action,payload),ensure_ascii=False))
        elif args.command == "assets":
            from .desktop_assets import install as install_assets, apply as apply_assets
            result = install_assets(paths) if args.action == "install" else apply_assets(paths)
            print(json.dumps(result, ensure_ascii=False))
        elif args.command == "osd":
            show_indicator(args.kind)
        elif args.command == "lock-date":
            print(lock_date())
        elif args.command == "toolkit-refresh":
            from .toolkit_refresh import refresh, schedule
            result = refresh(paths)
            if result.get('busy'):
                schedule(paths)
            print(json.dumps(result))
        elif args.command == "organizer":
            try: payload = json.loads(args.payload)
            except ValueError as exc: raise ConfigError("Invalid organizer JSON") from exc
            print(json.dumps(organizer(paths, args.action, payload), ensure_ascii=False))
        elif args.command == "appearance":
            try: payload = json.loads(args.payload)
            except ValueError as exc: raise ConfigError("Неверный JSON внешнего вида") from exc
            print(json.dumps(appearance_control(paths, args.action, payload), ensure_ascii=False))
        elif args.command == "wallpaper":
            wallpaper(paths, args.image, reset=args.reset)
        elif args.command == "settings":
            open_settings(paths)
        elif args.command == "install":
            update_session(paths)
            install(paths)
        elif args.command == "run":
            return run(paths)
        elif args.command == "start":
            start(paths)
        elif args.command == "restart":
            systemctl("daemon-reload")
            systemctl("stop", "poly-shell.service")
            start(paths)
        elif args.command == "stop":
            systemctl("daemon-reload")
            systemctl("stop", "poly-shell.service")
        elif args.command == "status":
            return systemctl("status", "--no-pager", "poly-shell.service", check=False).returncode
        elif args.command == "logs":
            return subprocess.run(["journalctl", "--user", "-u", "poly-shell.service", "-n", "80", "--no-pager"]).returncode
        elif args.command == "activate":
            install(paths)
            try:
                start(paths)
                patch_autostart(paths)
            except Exception:
                systemctl("stop", "poly-shell.service", check=False)
                raise
            subprocess.run(["pkill", "-u", str(os.getuid()), "-x", "waybar"], check=False)
            print("Poly Shell active; use poly-shell deactivate to return to Waybar")
        elif args.command == "deactivate":
            restore_autostart(paths)
            systemctl("stop", "poly-shell.service", check=False)
            fallback_panel(paths)
            print("Waybar restored")
        return 0
    except (ConfigError, OSError, subprocess.SubprocessError) as exc:
        print(f"poly-shell: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
