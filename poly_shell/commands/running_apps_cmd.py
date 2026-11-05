"""Command handler for ALPORA running apps snapshot & process signals."""
from __future__ import annotations
import argparse


def handle_running_apps(args: argparse.Namespace) -> int:
    from ..system.running_apps import main as running_apps_main
    action = getattr(args, "action", "") or "snapshot"
    subargs = getattr(args, "args", []) or []
    return running_apps_main([action, *subargs])


def handle_clipboard_serve() -> int:
    from ..services.clipboard import main as clipboard_main
    clipboard_main()
    return 0
