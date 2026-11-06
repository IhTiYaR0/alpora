"""Hyprland compositor communication adapter with Socket2 event streaming."""
from __future__ import annotations

import json
import os
from pathlib import Path
import socket
from typing import Any, Callable, Generator, Sequence

from .base import SafeRunner
from .compositor_base import BaseCompositorAdapter


class HyprlandAdapter(BaseCompositorAdapter):
    """Encapsulates interaction with Hyprland via hyprctl and Socket2."""

    @classmethod
    def is_available(cls) -> bool:
        return SafeRunner.is_available("hyprctl")

    @classmethod
    def dispatch(cls, command: str) -> bool:
        """Execute a hyprctl dispatch command."""
        output = cls.hyprctl(["dispatch", *command.split()], timeout=3.0)
        return "ok" in output.lower()

    @classmethod
    def get_socket2_path(cls) -> Path | None:
        """Resolve the path to Hyprland's event broadcast UNIX domain socket (.socket2.sock)."""
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
        if not sig:
            return None
        if "XDG_RUNTIME_DIR" in os.environ:
            runtime_dir = Path(os.environ["XDG_RUNTIME_DIR"])
        elif hasattr(os, "getuid"):
            runtime_dir = Path(f"/run/user/{os.getuid()}")
        else:
            return None
        candidate = runtime_dir / "hypr" / sig / ".socket2.sock"
        return candidate if candidate.exists() else None

    @classmethod
    def hyprctl(cls, args: Sequence[str], timeout: float = 5.0, check: bool = False) -> str:
        cmd = ["hyprctl", *args]
        proc = SafeRunner.run(cmd, timeout=timeout, check=check)
        return proc.stdout.strip()

    @classmethod
    def get_monitors(cls) -> list[dict[str, Any]]:
        """Return list of active monitors parsed from hyprctl monitors -j."""
        output = cls.hyprctl(["monitors", "-j"], timeout=3.0)
        if not output:
            return []
        try:
            parsed = json.loads(output)
            return parsed if isinstance(parsed, list) else []
        except (ValueError, TypeError):
            return []

    @classmethod
    def get_workspaces(cls) -> list[dict[str, Any]]:
        """Return list of active workspaces parsed from hyprctl workspaces -j."""
        output = cls.hyprctl(["workspaces", "-j"], timeout=3.0)
        if not output:
            return []
        try:
            parsed = json.loads(output)
            return parsed if isinstance(parsed, list) else []
        except (ValueError, TypeError):
            return []

    @classmethod
    def get_clients(cls) -> list[dict[str, Any]]:
        """Return list of open client windows parsed from hyprctl clients -j."""
        output = cls.hyprctl(["clients", "-j"], timeout=3.0)
        if not output:
            return []
        try:
            parsed = json.loads(output)
            return parsed if isinstance(parsed, list) else []
        except (ValueError, TypeError):
            return []

    @classmethod
    def dispatch(cls, dispatcher: str, arg: str = "") -> bool:
        """Call a Hyprland dispatcher."""
        cmd = ["dispatch", dispatcher]
        if arg:
            cmd.append(arg)
        proc = SafeRunner.run(["hyprctl", *cmd], timeout=3.0)
        return proc.returncode == 0

    @classmethod
    def stream_events(cls, stop_check: Callable[[], bool] | None = None) -> Generator[tuple[str, str], None, None]:
        """Stream real-time compositor events (event, data) from Socket2."""
        sock_path = cls.get_socket2_path()
        if not sock_path or not hasattr(socket, "AF_UNIX"):
            return

        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            sock.settimeout(2.0)
            sock.connect(str(sock_path))
            buffer = ""
            while True:
                if stop_check and stop_check():
                    break
                try:
                    chunk = sock.recv(4096).decode("utf-8", errors="replace")
                    if not chunk:
                        break
                    buffer += chunk
                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        line = line.strip()
                        if line and ">>" in line:
                            evt, data = line.split(">>", 1)
                            yield (evt.strip(), data.strip())
                except socket.timeout:
                    continue
        except OSError:
            pass
        finally:
            sock.close()
