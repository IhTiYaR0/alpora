#!/usr/bin/env python3
"""ALPORA process manager helper. Read current-user process data and safely signal selected processes."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import signal
import sys
from typing import Any

PROTECTED_NAMES = {
    "systemd", "hyprland", "quickshell", "poly-shell", "dbus-daemon",
    "pipewire", "wireplumber", "polkitd", "xdg-desktop-portal",
    "xdg-desktop-portal-hyprland", "xwayland", "kwin_wayland",
    "gnome-shell", "sway", "weston", "wayfire", "greetd", "sddm",
}
SECRET_ARG = re.compile(r"(?i)(password|passwd|token|secret|api[-_]?key|credential|authorization|cookie)")


def _app_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower()) or "application"


def _read_process(pid: int) -> dict[str, Any] | None:
    base = Path("/proc") / str(pid)
    try:
        stat = (base / "stat").read_text(encoding="utf-8", errors="replace")
        closing = stat.rfind(")")
        if closing < 0:
            return None
        name = stat[stat.find("(") + 1:closing]
        fields = stat[closing + 2:].split()
        state = fields[0]
        ppid = int(fields[1])
        start_ticks = int(fields[19])
        status = (base / "status").read_text(encoding="utf-8", errors="replace")
        uid_line = next((line for line in status.splitlines() if line.startswith("Uid:")), "")
        uid_values = uid_line.split()[1:]
        if len(uid_values) < 2:
            return None
        effective_uid = int(uid_values[1])
        try:
            raw_args = (base / "cmdline").read_bytes().split(b"\0")
            argv = [part.decode("utf-8", errors="replace") for part in raw_args if part]
        except OSError:
            argv = []
        try:
            executable = os.path.basename(os.readlink(base / "exe"))
        except OSError:
            executable = name
        command = _safe_command(argv, executable or name)
        lower_name = (name or executable).lower()
        return {
            "pid": pid, "ppid": ppid, "uid": effective_uid, "name": name or executable or str(pid),
            "exe": executable, "argv": argv, "command": command, "state": state,
            "startTicks": start_ticks, "threads": _thread_count(status),
            "protected": lower_name in PROTECTED_NAMES,
        }
    except (OSError, ValueError, IndexError):
        return None


def _thread_count(status: str) -> int:
    line = next((line for line in status.splitlines() if line.startswith("Threads:")), "")
    try:
        return int(line.split()[1])
    except (IndexError, ValueError):
        return 1


def _safe_command(argv: list[str], fallback: str) -> str:
    if not argv:
        return fallback
    safe: list[str] = []
    hide_next = False
    for arg in argv:
        if hide_next:
            safe.append("<redacted>")
            hide_next = False
            continue
        if SECRET_ARG.search(arg):
            if "=" in arg:
                key, _ = arg.split("=", 1)
                safe.append(key + "=<redacted>")
            elif ":" in arg and not arg.startswith("/"):
                key, _ = arg.split(":", 1)
                safe.append(key + ":<redacted>")
            else:
                safe.append(arg)
                if arg.startswith("-"):
                    hide_next = True
        else:
            safe.append(arg)
    rendered = " ".join(safe)
    rendered = re.sub(r"(?i)(https?://[^/:\s]+):[^/@\s]+@", r"\1:<redacted>@", rendered)
    return rendered[:300] + ("…" if len(rendered) > 300 else "")


def _ancestor_pids(start_pid: int) -> set[int]:
    seen: set[int] = set()
    current = start_pid
    for _ in range(80):
        if current <= 1 or current in seen:
            break
        seen.add(current)
        proc = _read_process(current)
        if not proc:
            break
        current = int(proc["ppid"])
    return seen


def _process_matches_app(proc: dict[str, Any], app_class: str) -> bool:
    tokens = [token for token in re.split(r"[^a-z0-9]+", app_class.lower()) if len(token) >= 3]
    if not tokens:
        return False
    # The last segment is useful for desktop IDs such as org.mozilla.firefox.
    tokens = list(dict.fromkeys(tokens + [tokens[-1]]))
    candidates = [str(proc.get("name", "")).lower(), str(proc.get("exe", "")).lower()]
    argv = proc.get("argv", [])
    if argv:
        candidates.append(os.path.basename(argv[0]).lower())
    command = " ".join(candidates)
    p_tokens = [token for token in re.split(r"[^a-z0-9]+", command) if len(token) >= 3]
    return any(token in p_tokens for token in tokens) or any(
        len(token) >= 5 and any(token in candidate or candidate in token for candidate in p_tokens)
        for token in tokens for candidate in p_tokens if len(candidate) >= 4
    )


def _descendant_distance(processes: dict[int, dict[str, Any]], pid: int, root_pid: int) -> int | None:
    current = pid
    seen: set[int] = set()
    for distance in range(80):
        if current == root_pid:
            return distance
        if current <= 1 or current in seen:
            return None
        seen.add(current)
        proc = processes.get(current)
        if not proc:
            return None
        current = int(proc["ppid"])
    return None


def snapshot(windows: list[dict[str, Any]]) -> dict[str, Any]:
    uid = os.getuid() if hasattr(os, "getuid") else 1000
    protected_pids = _ancestor_pids(os.getpid())
    records: dict[int, dict[str, Any]] = {}
    proc_root = Path("/proc")
    if not proc_root.exists():
        return {"ok": True, "uid": uid, "windows": windows, "processes": []}
    for path in proc_root.iterdir():
        if not path.name.isdigit():
            continue
        pid = int(path.name)
        if pid == os.getpid():
            continue
        proc = _read_process(pid)
        if proc and proc["uid"] == uid:
            proc["protected"] = bool(proc["protected"] or pid in protected_pids or proc["state"] == "Z")
            proc["canSignal"] = not proc["protected"] and pid > 1
            records[pid] = proc

    window_refs: list[dict[str, Any]] = []
    roots: list[dict[str, Any]] = []
    for win in windows:
        try:
            window_pid = int(win.get("pid", 0))
        except (TypeError, ValueError):
            continue
        if window_pid <= 1:
            continue
        app_class = str(win.get("appClass") or win.get("class") or "Application")
        key = _app_key(app_class)
        chain: list[dict[str, Any]] = []
        current = window_pid
        seen: set[int] = set()
        for _ in range(80):
            if current <= 1 or current in seen:
                break
            seen.add(current)
            proc = records.get(current)
            if not proc:
                break
            chain.append(proc)
            current = int(proc["ppid"])
        matches = [proc for proc in chain if _process_matches_app(proc, app_class)]
        # If a window belongs to a child renderer (e.g. Chromium), choose the
        # highest matching process in its own ancestry, not a global name match.
        root_proc = matches[-1] if matches else records.get(window_pid)
        root_pid = int(root_proc["pid"]) if root_proc else window_pid
        method = "name-match" if matches and root_pid != window_pid else "window-pid"
        display_name = str(win.get("appName") or app_class)
        roots.append({"appKey": key, "appName": display_name, "rootPid": root_pid,
                      "windowPid": window_pid, "method": method})
        window_refs.append({"pid": window_pid, "appKey": key, "appName": display_name,
                            "address": str(win.get("address", "")), "title": str(win.get("title", "")),
                            "rootPid": root_pid, "associationMethod": method})

    # A process may descend from multiple visible windows in the same application.
    # Choose the nearest matched app root and avoid claiming unrelated processes.
    app_roots: set[int] = set()
    for root in roots:
        app_roots.add(int(root["rootPid"]))
    window_pids = {int(item["pid"]) for item in window_refs}
    for proc in records.values():
        candidates: list[tuple[int, dict[str, Any]]] = []
        for root in roots:
            distance = _descendant_distance(records, int(proc["pid"]), int(root["rootPid"]))
            if distance is not None:
                candidates.append((distance, root))
        if candidates:
            distance, chosen = min(candidates, key=lambda item: item[0])
            proc["appKey"] = chosen["appKey"]
            proc["appName"] = chosen["appName"]
            proc["depth"] = distance
            proc["associationMethod"] = "window-pid" if proc["pid"] in window_pids else (
                "name-match" if int(proc["pid"]) == int(chosen["rootPid"]) and chosen["method"] == "name-match" else "process-tree")
        else:
            proc["appKey"] = ""
            proc["appName"] = ""
            proc["depth"] = 0
            proc["associationMethod"] = ""
        proc["appRoot"] = int(proc["pid"]) in app_roots
        argv_text = " ".join(proc.get("argv", [])).lower()
        if "--type=renderer" in argv_text or "renderer" in proc["name"].lower():
            proc["role"] = "renderer"
        elif "--type=gpu-process" in argv_text or "gpu-process" in argv_text:
            proc["role"] = "gpu"
        elif "--type=utility" in argv_text or "utility" in proc["name"].lower():
            proc["role"] = "utility"
        elif "--type=zygote" in argv_text or "zygote" in proc["name"].lower():
            proc["role"] = "zygote"
        elif "-contentproc" in argv_text or "web content" in proc["name"].lower():
            proc["role"] = "content"
        elif proc["appRoot"]:
            proc["role"] = "main"
        elif int(proc["pid"]) in window_pids:
            proc["role"] = "window"
        elif proc["appName"]:
            proc["role"] = "child"
        else:
            proc["role"] = "background"
        proc["parentName"] = records.get(int(proc["ppid"]), {}).get("name", "")
        # Raw argv is not sent to QML; only the redacted command string is exposed.
        proc.pop("argv", None)
        proc.pop("uid", None)

    processes = sorted(records.values(), key=lambda p: (not bool(p.get("appName")), p.get("appKey", ""), p.get("depth", 0), p["name"].lower(), p["pid"]))
    return {"ok": True, "uid": uid, "windows": window_refs, "processes": processes}


def terminate(pid: int, expected_start_ticks: int, sig: str) -> dict[str, Any]:
    if sig not in {"TERM", "KILL"}:
        raise ValueError("Only SIGTERM and SIGKILL are supported")
    if pid <= 1 or pid == os.getpid() or pid in _ancestor_pids(os.getpid()):
        raise ValueError("Refusing to signal a critical session process")
    proc = _read_process(pid)
    if proc is None:
        raise ProcessLookupError("Process no longer exists")
    if proc["uid"] != os.getuid():
        raise PermissionError("Only processes owned by the current user can be managed")
    if int(proc["startTicks"]) != expected_start_ticks:
        raise ProcessLookupError("Process identity changed; refresh the list before retrying")
    if proc["name"].lower() in PROTECTED_NAMES or proc["state"] == "Z":
        raise ValueError("Refusing to signal a protected session process or zombie")
    os.kill(pid, signal.SIGTERM if sig == "TERM" else signal.SIGKILL)
    return {"ok": True, "pid": pid, "signal": sig}


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    try:
        if not args:
            raise ValueError("Expected snapshot or signal")
        if args[0] == "snapshot":
            windows = json.loads(args[1]) if len(args) > 1 else []
            if not isinstance(windows, list):
                raise ValueError("Window references must be a JSON array")
            print(json.dumps(snapshot(windows), ensure_ascii=False))
            return 0
        if args[0] == "signal" and len(args) == 4:
            result = terminate(int(args[1]), int(args[2]), args[3])
            print(json.dumps(result, ensure_ascii=False))
            return 0
        raise ValueError("Usage: running_apps.py snapshot [WINDOWS_JSON] | signal PID START_TICKS TERM|KILL")
    except (ValueError, OSError, ProcessLookupError, PermissionError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False))
        print(f"running_apps.py: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
