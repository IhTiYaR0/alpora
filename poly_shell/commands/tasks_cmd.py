"""Command handler for ALPORA Task Manager window and task queries."""
import json
import os
import subprocess
import time
from ..adapters.base import SafeRunner
from ..core.state import ConfigError, ROOT, update_session


def open_task_manager(paths, runtime_check_fn=None):
    if runtime_check_fn:
        runtime_check_fn()
    if not os.environ.get("WAYLAND_DISPLAY"):
        raise ConfigError("Open task manager inside Wayland session")
    entry = ROOT / "shell/task_manager.qml"
    ipc = ["quickshell", "ipc", "--path", str(entry), "call", "task-manager-app", "raiseWindow"]
    paths.runtime.mkdir(parents=True, exist_ok=True, mode=0o700)
    if SafeRunner.run(ipc, timeout=2.0).returncode == 0:
        return
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
    if SafeRunner.is_available("systemd-run"):
        cmd = ["systemd-run", "--user", "--quiet", "--collect",
               "--unit=poly-shell-task-manager", "--service-type=exec",
               "--description=ALPORA Task Manager"]
        cmd += ["--setenv=" + name + "=" + value for name, value in environment.items()]
        SafeRunner.run(cmd + ["quickshell", "--path", str(entry), "--no-duplicate"], timeout=8.0)
    else:
        env_copy = os.environ.copy()
        env_copy.update(environment)
        subprocess.Popen(["quickshell", "--path", str(entry), "--no-duplicate"], env=env_copy, start_new_session=True)

    for _ in range(50):
        if SafeRunner.run(ipc, timeout=1.5).returncode == 0:
            return
        time.sleep(.1)
    raise ConfigError("Task manager window failed to start.")


def handle_task_manager(paths, args, runtime_check_fn=None) -> int:
    open_task_manager(paths, runtime_check_fn=runtime_check_fn)
    return 0


def handle_tasks(paths, args) -> int:
    from .. import task_manager
    if args.kill:
        task_manager.kill_process(args.kill, sig=args.sig)
        print(json.dumps({"success": True, "killed": args.kill}))
    elif args.service:
        name, act = args.service
        task_manager.control_service(name, act)
        print(json.dumps({"success": True, "service": name, "action": act}))
    elif args.startup_toggle:
        name, state = args.startup_toggle
        enabled = state.lower() in ("on", "true", "1", "yes")
        task_manager.toggle_startup_item(name, enabled)
        print(json.dumps({"success": True, "item": name, "enabled": enabled}))
    else:
        tab = args.tab
        if tab == "processes":
            data = task_manager.get_processes()
        elif tab == "performance":
            data = task_manager.get_performance_data()
        elif tab == "startup":
            data = task_manager.get_startup_items()
        elif tab == "users":
            data = task_manager.get_user_sessions()
        elif tab == "details":
            data = task_manager.get_process_details()
        elif tab == "services":
            data = task_manager.get_services()
        else:
            data = {}
        print(json.dumps(data, ensure_ascii=False))
    return 0

