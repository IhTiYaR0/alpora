"""Command handler for color themes, Timeline transitions, widgets, and appearance."""
import json
from ..theming.appearance import appearance_control
from ..theming.desktop_assets import install as install_assets, apply as apply_assets
from ..core.state import ConfigError
from ..theming.themes import theme_control, extract_palette_from_image
from ..theming.timeline import timeline_control
from ..theming.toolkit_refresh import refresh as refresh_toolkit, schedule as schedule_toolkit
from ..system.widgets import widgets_control


def handle_theme(paths, args) -> int:
    try:
        payload = json.loads(args.payload)
    except ValueError as exc:
        raise ConfigError("Invalid theme JSON") from exc
    print(json.dumps(theme_control(paths, args.action, payload), ensure_ascii=False))
    return 0


def handle_timeline(paths, args) -> int:
    try:
        payload = json.loads(args.payload)
    except ValueError as exc:
        raise ConfigError("Invalid Timeline JSON") from exc
    print(json.dumps(timeline_control(paths, args.action, payload), ensure_ascii=False))
    return 0


def handle_widgets(paths, args) -> int:
    try:
        payload = json.loads(args.payload)
    except ValueError as exc:
        raise ConfigError("Invalid widgets JSON") from exc
    if not isinstance(payload, dict):
        raise ConfigError("Invalid widgets request")
    print(json.dumps(widgets_control(paths, args.action, payload), ensure_ascii=False))
    return 0


def handle_appearance(paths, args) -> int:
    try:
        payload = json.loads(args.payload)
    except ValueError as exc:
        raise ConfigError("Invalid appearance JSON") from exc
    print(json.dumps(appearance_control(paths, args.action, payload), ensure_ascii=False))
    return 0


def handle_palette_extract(paths, args) -> int:
    palette = extract_palette_from_image(args.image)
    print(json.dumps(palette, indent=2))
    return 0


def handle_assets(paths, args) -> int:
    result = install_assets(paths) if args.action == "install" else apply_assets(paths)
    print(json.dumps(result, ensure_ascii=False))
    return 0


def handle_toolkit_refresh(paths, args) -> int:
    result = refresh_toolkit(paths)
    if result.get('busy'):
        schedule_toolkit(paths)
    print(json.dumps(result))
    return 0

