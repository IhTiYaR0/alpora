"""Command handler for Hyprland persistent keyboard shortcuts."""
import json
from ..services.shortcuts import shortcuts_control
from ..core.state import ConfigError


def handle_shortcuts(paths, args) -> int:
    try:
        payload = json.loads(args.payload)
    except ValueError as exc:
        raise ConfigError("Invalid shortcuts JSON") from exc
    print(json.dumps(shortcuts_control(paths, args.action, payload), ensure_ascii=False))
    return 0

