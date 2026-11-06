"""Command handler for ALPORA interactive demo and shell simulator."""
from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import sys

from ..core.state import ROOT, Paths
from ..system.demo_server import start_demo_server


def _safe_print(text: str) -> None:
    try:
        print(text)
    except (UnicodeEncodeError, OSError):
        try:
            sys.stdout.buffer.write((text + "\n").encode("utf-8", errors="replace"))
            sys.stdout.buffer.flush()
        except Exception:
            pass


def handle_demo(paths: Paths, args) -> int:
    """Entry point for `poly-shell demo` subcommand."""
    mode = getattr(args, "mode", "web")
    port = getattr(args, "port", 8080)
    no_browser = getattr(args, "no_browser", False)

    if mode == "native":
        quickshell = shutil.which("quickshell")
        if not quickshell:
            _safe_print("Lỗi: Quickshell chưa được cài đặt hoặc không có trong PATH.")
            _safe_print("  Bạn có thể chạy chế độ web demo với: poly-shell demo web")
            return 1

        demo_qml = ROOT / "shell" / "demos" / "DemoRunner.qml"
        if not demo_qml.is_file():
            _safe_print(f"Lỗi: Không tìm thấy file {demo_qml}")
            return 1

        env = os.environ.copy()
        env.update(
            POLY_SHELL_STATE=str(paths.session),
            POLY_SHELL_CTL=str(ROOT / "bin" / "poly-shell"),
            POLY_SHELL_ASSETS=str(ROOT / "assets"),
        )
        _safe_print("Đang khởi chạy ALPORA Native QML Demo Runner...")
        proc = subprocess.run([quickshell, "-p", str(demo_qml)], env=env)
        return proc.returncode

    # Mode web or server
    open_browser = (mode == "web") and (not no_browser)
    try:
        start_demo_server(paths=paths, port=port, open_browser=open_browser, blocking=True)
        return 0
    except (OSError, RuntimeError) as exc:
        print(f"poly-shell demo: {exc}", file=sys.stderr)
        return 1
