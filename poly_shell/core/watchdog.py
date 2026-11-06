"""Runtime Watchdog, Health Telemetry and Automatic Crash Recovery for ALPORA."""
from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime
import json
import os
from pathlib import Path
import platform
import sys
import threading
import time
import traceback
from typing import Any

from poly_shell.state import Paths


@dataclass
class ProcessTelemetry:
    pid: int
    name: str
    rss_mb: float
    threads_count: int
    status: str
    uptime_seconds: float
    cpu_percent: float | None = None


class ProcessMonitor:
    """Non-invasive monitoring of shell memory, threads and resource budgets."""

    @staticmethod
    def get_process_metrics(pid: int | None = None) -> ProcessTelemetry | None:
        target_pid = pid or os.getpid()
        proc_dir = Path(f"/proc/{target_pid}")
        if not proc_dir.exists():
            return None

        try:
            status_lines = (proc_dir / "status").read_text(encoding="utf-8", errors="replace").splitlines()
            status_map: dict[str, str] = {}
            for line in status_lines:
                if ":" in line:
                    k, v = line.split(":", 1)
                    status_map[k.strip()] = v.strip()

            name = status_map.get("Name", f"proc-{target_pid}")
            state = status_map.get("State", "Unknown").split()[0]
            threads = int(status_map.get("Threads", "1"))

            # VmRSS in kB
            vm_rss = status_map.get("VmRSS", "0 kB")
            rss_kb = int(vm_rss.split()[0]) if vm_rss and vm_rss.split()[0].isdigit() else 0
            rss_mb = round(rss_kb / 1024.0, 2)

            # Uptime calculation
            stat_tokens = (proc_dir / "stat").read_text(encoding="ascii", errors="replace").split()
            start_ticks = int(stat_tokens[21]) if len(stat_tokens) > 21 else 0
            clk_tck = os.sysconf("SC_CLK_TCK") if hasattr(os, "sysconf") else 100
            uptime = time.monotonic() - (start_ticks / clk_tck) if start_ticks else 0.0

            return ProcessTelemetry(
                pid=target_pid,
                name=name,
                rss_mb=rss_mb,
                threads_count=threads,
                status=state,
                uptime_seconds=max(0.0, round(uptime, 1)),
            )
        except (OSError, ValueError, IndexError):
            return None


class CrashReporter:
    """Interceptors for unhandled exceptions with state dumps and structured logging."""

    _installed = False

    @classmethod
    def install(cls, paths: Paths | None = None) -> None:
        if cls._installed:
            return
        cls._paths = paths or Paths.current()
        cls._original_excepthook = sys.excepthook
        sys.excepthook = cls._handle_exception

        if hasattr(threading, "excepthook"):
            cls._original_thread_hook = threading.excepthook
            threading.excepthook = cls._handle_thread_exception

        cls._installed = True

    @classmethod
    def _create_crash_dump(cls, exc_type: type[BaseException], exc_value: BaseException, tb: Any) -> Path:
        reports_dir = cls._paths.state / "crash_reports"
        reports_dir.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        dump_path = reports_dir / f"crash-{timestamp}-{os.getpid()}.json"

        telemetry = ProcessMonitor.get_process_metrics()
        report: dict[str, Any] = {
            "timestamp": datetime.now().isoformat(),
            "os": {
                "system": platform.system(),
                "release": platform.release(),
                "machine": platform.machine(),
            },
            "environment": {
                "XDG_CURRENT_DESKTOP": os.environ.get("XDG_CURRENT_DESKTOP", ""),
                "WAYLAND_DISPLAY": os.environ.get("WAYLAND_DISPLAY", ""),
                "HYPRLAND_INSTANCE_SIGNATURE": os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", ""),
            },
            "process": asdict(telemetry) if telemetry else None,
            "exception": {
                "type": getattr(exc_type, "__name__", str(exc_type)),
                "message": str(exc_value),
                "traceback": traceback.format_exception(exc_type, exc_value, tb),
            },
        }

        try:
            dump_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
        except OSError:
            pass
        return dump_path

    @classmethod
    def _handle_exception(cls, exc_type: type[BaseException], exc_value: BaseException, tb: Any) -> None:
        if issubclass(exc_type, KeyboardInterrupt):
            if cls._original_excepthook:
                cls._original_excepthook(exc_type, exc_value, tb)
            return

        dump_path = cls._create_crash_dump(exc_type, exc_value, tb)
        sys.stderr.write(
            f"\n[ALPORA CRITICAL CRASH] Unhandled {exc_type.__name__}: {exc_value}\n"
            f"Diagnostics state dumped to: {dump_path}\n\n"
        )
        if cls._original_excepthook:
            cls._original_excepthook(exc_type, exc_value, tb)

    @classmethod
    def _handle_thread_exception(cls, args: Any) -> None:
        cls._create_crash_dump(args.exc_type, args.exc_value, args.exc_traceback)
        sys.stderr.write(
            f"\n[ALPORA THREAD CRASH] Thread {args.thread.name} crashed: {args.exc_value}\n"
        )


class HeartbeatWatchdog:
    """Supervises Quickshell and IPC responsiveness. Detects UI stalls."""

    def __init__(self, heartbeat_timeout: float = 12.0) -> None:
        self.heartbeat_timeout = heartbeat_timeout
        self._last_heartbeat = time.monotonic()
        self._lock = threading.Lock()

    def beat(self) -> None:
        with self._lock:
            self._last_heartbeat = time.monotonic()

    def is_stalled(self) -> bool:
        with self._lock:
            return (time.monotonic() - self._last_heartbeat) > self.heartbeat_timeout

