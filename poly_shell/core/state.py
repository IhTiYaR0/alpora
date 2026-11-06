"""Validated settings and atomic, serialized profile changes (standard library only)."""
from contextlib import contextmanager
from copy import deepcopy
from dataclasses import dataclass
try:
    import fcntl
except ImportError:
    fcntl = None
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
import threading

_candidate_root = Path(__file__).resolve().parents[2]
if os.environ.get("POLY_SHELL_ROOT"):
    ROOT = Path(os.environ["POLY_SHELL_ROOT"]).resolve()
elif (_candidate_root / "assets").exists():
    ROOT = _candidate_root
elif Path("/usr/share/alpora/assets").exists():
    ROOT = Path("/usr/share/alpora")
else:
    ROOT = _candidate_root
MODES = ("work", "vibe")


class ConfigError(ValueError):
    pass


@dataclass(frozen=True)
class Paths:
    config: Path
    state: Path
    runtime: Path

    @classmethod
    def current(cls):
        home = Path.home()
        uid = os.getuid() if hasattr(os, "getuid") else 1000
        return cls(
            Path(os.environ.get("XDG_CONFIG_HOME", home / ".config")) / "poly-shell",
            Path(os.environ.get("XDG_STATE_HOME", home / ".local/state")) / "poly-shell",
            Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{uid}")) / "poly-shell",
        )

    @property
    def session(self):
        return self.state / "session.json"


def read_object(path):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise ConfigError(f"Cannot read {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ConfigError(f"Expected a JSON object in {path}")
    return value


def atomic_json(path, value):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False, newline="") as stream:
            temporary = Path(stream.name)
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
            stream.flush()
        for attempt in range(10):
            try:
                os.replace(temporary, path)
                break
            except PermissionError:
                if attempt == 9: raise
                import time; time.sleep(0.01)
        if hasattr(os, "O_DIRECTORY"):
            descriptor = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(descriptor)
            finally:
                os.close(descriptor)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def merge(base, override):
    result = deepcopy(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = deepcopy(value)
    return result


def defaults():
    return {
        "schemaVersion": 1,
        "apps": {
            "terminal": ["foot" if shutil.which("foot") else "kitty"],
            "launcher": ["fuzzel"],
            "audio": ["pavucontrol"],
            "lock": ["hyprlock"],
            "network": ["nm-connection-editor"],
        },
        "bar": {"height": 40, "workspaceCount": 4, "fontFamily": "Inter", "fontSize": 13,
                "margin": 20, "top": 12, "uiScale": 1.0},
        "input": {
            "touchpad": {
                "tapToClick": True,
                "naturalScroll": True,
                "disableWhileTyping": True,
                "sensitivity": 0.0,
                "scrollFactor": 1.0,
            }
        },
        "reducedMotion": False,
        "locale": "en",
    }


def integer(value, minimum, maximum, name):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ConfigError(f"{name} must be an integer between {minimum} and {maximum}")


def settings_for(paths):
    target = paths.config / "settings.json"
    if not target.exists():
        atomic_json(target, defaults())
    data = merge(defaults(), read_object(target))
    if data.get("schemaVersion") != 1:
        raise ConfigError("Unsupported settings schemaVersion")
    apps = data.get("apps")
    if not isinstance(apps, dict):
        raise ConfigError("apps must be an object")
    for key in ("terminal", "launcher", "audio", "lock"):
        command = apps.get(key)
        if not isinstance(command, list) or not command or any(
            not isinstance(part, str) or not part or "\0" in part for part in command
        ):
            raise ConfigError(f"apps.{key} must be a nonempty array of command arguments")
    bar = data.get("bar")
    if not isinstance(bar, dict):
        raise ConfigError("bar must be an object")
    integer(bar.get("height"), 32, 80, "bar.height")
    integer(bar.get("workspaceCount"), 1, 10, "bar.workspaceCount")
    integer(bar.get("fontSize"), 10, 24, "bar.fontSize")
    integer(bar.get("margin"), 0, 64, "bar.margin")
    integer(bar.get("top"), 0, 64, "bar.top")
    scale = bar.get("uiScale", 1.0)
    if not isinstance(scale, (int, float)) or not 0.5 <= scale <= 3.0:
        bar["uiScale"] = 1.0
    else:
        bar["uiScale"] = round(float(scale), 2)
    inp = data.get("input", {})
    if not isinstance(inp, dict):
        data["input"] = defaults()["input"]
    else:
        touchpad = inp.get("touchpad", {})
        if not isinstance(touchpad, dict):
            inp["touchpad"] = defaults()["input"]["touchpad"]
        else:
            for b_key in ("tapToClick", "naturalScroll", "disableWhileTyping"):
                if type(touchpad.get(b_key)) is not bool:
                    touchpad[b_key] = True
            sens = touchpad.get("sensitivity", 0.0)
            touchpad["sensitivity"] = max(-1.0, min(1.0, float(sens))) if isinstance(sens, (int, float)) else 0.0
            factor = touchpad.get("scrollFactor", 1.0)
            touchpad["scrollFactor"] = max(0.1, min(3.0, float(factor))) if isinstance(factor, (int, float)) else 1.0
    if type(data.get("reducedMotion")) is not bool:
        raise ConfigError("reducedMotion must be true or false")
    from .i18n import supported_locales
    locale = data.get("locale", "en")
    if not isinstance(locale, str) or locale not in supported_locales():
        data["locale"] = "en"
    return data


def profile_for(paths, mode):
    if mode not in MODES:
        raise ConfigError(f"Unknown mode: {mode}")
    data = read_object(ROOT / "assets" / "profiles" / f"{mode}.json")
    override = paths.config / "profiles" / f"{mode}.json"
    if override.exists():
        data = merge(data, read_object(override))
    if not isinstance(data.get("label"), str) or not data["label"].strip():
        raise ConfigError("profile.label must be a nonempty string")
    palette = data.get("palette")
    if not isinstance(palette, dict):
        raise ConfigError("profile.palette must be an object")
    for key in ("background", "surface", "text", "muted", "accent"):
        if not isinstance(palette.get(key), str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", palette[key]):
            raise ConfigError(f"palette.{key} must be a #RRGGBB color")
    integer(data.get("motionMs"), 0, 300, "profile.motionMs")
    return data


_STATE_LOCK_LOCAL = threading.local()
_IN_PROCESS_LOCK = threading.RLock()


@contextmanager
def state_lock(paths):
    depth = getattr(_STATE_LOCK_LOCAL, "depth", 0)
    _STATE_LOCK_LOCAL.depth = depth + 1
    if depth > 0:
        try:
            yield
        finally:
            _STATE_LOCK_LOCAL.depth -= 1
        return

    with _IN_PROCESS_LOCK:
        paths.state.mkdir(mode=0o700, parents=True, exist_ok=True)
        with (paths.state / "state.lock").open("a") as stream:
            if fcntl is not None:
                fcntl.flock(stream, fcntl.LOCK_EX)
            try:
                yield
            finally:
                _STATE_LOCK_LOCAL.depth -= 1


def current_mode(paths):
    if not paths.session.exists():
        return "work"
    data = read_object(paths.session)
    if data.get("schemaVersion") != 1 or data.get("mode") not in MODES:
        raise ConfigError(f"Invalid saved session in {paths.session}; preserved for recovery")
    return data["mode"]


def appearance_for(paths):
    """Resolve visual assets separately from behavior modes, with safe fallback."""
    from ..theming.themes import resolve_appearance
    return resolve_appearance(paths)


def update_session(paths, requested=None):
    from ..theming.visual import visual_for
    from ..system.hardware import detect_hardware_profile
    with state_lock(paths):
        old = current_mode(paths)
        mode = ("vibe" if old == "work" else "work") if requested == "toggle" else (requested or old)
        snapshot = {
            "schemaVersion": 1,
            "mode": mode,
            "profile": profile_for(paths, mode),
            "settings": settings_for(paths),
            "hardware": detect_hardware_profile(),
            "appearance": appearance_for(paths),
            "visual": visual_for(paths),
        }
        atomic_json(paths.session, snapshot)
        return snapshot
