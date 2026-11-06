"""Apply appearance as a serialized transaction with runtime/readback rollback."""
import json
import os
import re
from datetime import datetime
from pathlib import Path
import subprocess
import tempfile

from ..core.state import (ConfigError, atomic_json, current_mode, profile_for, settings_for,
                    appearance_for, state_lock)
from .visual import DEFAULTS, validate, visual_for, lua_for


def generated_path(paths):
    return paths.config.parent / "hypr/poly-shell-appearance.lua"


HOOK_BEGIN = "-- BEGIN POLY SHELL APPEARANCE"
HOOK_END = "-- END POLY SHELL APPEARANCE"
HOOK = '''-- BEGIN POLY SHELL APPEARANCE
do
    local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
    local file = config .. "/hypr/poly-shell-appearance.lua"
    local handle = io.open(file, "r")
    if handle then handle:close(); dofile(file) end
end
-- END POLY SHELL APPEARANCE
'''
LEGACY_SETTINGS_RULE = '''-- Poly Shell settings: an independent, movable application window.
hl.window_rule({
    name = "poly-settings-window",
    match = { class = "^poly-shell-settings$" },
    float = true,
    size = { 1100, 800 },
    center = true,
})
'''
SETTINGS_RULE = '''-- Poly Shell settings: an independent, movable application window.
hl.window_rule({
    name = "poly-settings-window",
    match = { class = "^poly-shell-settings$" },
    float = true,
    size = { 1100, 800 },
    min_size = { 1100, 800 },
    max_size = { 1100, 800 },
    suppress_event = "maximize fullscreen fullscreenoutput",
    maximize = false,
    fullscreen = false,
    center = true,
})
'''

PANEL_RULE_BEGIN = "-- BEGIN POLY SHELL PANEL MOTION"
LEGACY_PANEL_RULE = '''-- BEGIN POLY SHELL PANEL MOTION
-- Qt draws the liquid morph; disable compositor animation to avoid a second fade.
hl.curve("polyPanel", { type = "bezier", points = { {0.2, 0}, {0.2, 1} } })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3.4, bezier = "polyPanel", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.0, bezier = "polyPanel", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 3.4, bezier = "polyPanel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2.0, bezier = "polyPanel" })
hl.layer_rule({
    name = "poly-shell-native-panels",
    match = { namespace = "^poly-panel-(bar-popup|quick-settings)$" },
    no_anim = true, blur = false,
})
hl.layer_rule({
    name = "poly-shell-static-panels",
    match = { namespace = "^poly-panel-(bar-popup|quick-settings)-static$" },
    no_anim = true, blur = false,
})
hl.layer_rule({
    name = "poly-shell-dismissal-input",
    match = { namespace = "^poly-panel-dismiss$" },
    no_anim = true, blur = false,
})
-- END POLY SHELL PANEL MOTION
'''

PANEL_RULE = '''-- BEGIN POLY SHELL PANEL MOTION
-- Qt draws the liquid morph; disable compositor animation to avoid a second fade.
hl.curve("polyPanel", { type = "bezier", points = { {0.2, 0}, {0.2, 1} } })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3.4, bezier = "polyPanel", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.0, bezier = "polyPanel", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 3.4, bezier = "polyPanel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2.0, bezier = "polyPanel" })
hl.layer_rule({
    name = "poly-shell-native-panels",
    match = { namespace = "^poly-panel-(bar-popup|quick-settings)$" },
    no_anim = true, blur = true, ignore_alpha = 0.05, xray = false,
})
hl.layer_rule({
    name = "poly-shell-static-panels",
    match = { namespace = "^poly-panel-(bar-popup|quick-settings)-static$" },
    no_anim = true, blur = true, ignore_alpha = 0.05, xray = false,
})
hl.layer_rule({
    name = "poly-shell-launcher-glass",
    match = { namespace = "^poly-shell-launcher$" },
    no_anim = true, blur = true, ignore_alpha = 0.05, xray = false,
})
hl.layer_rule({
    name = "poly-shell-dismissal-input",
    match = { namespace = "^poly-panel-dismiss$" },
    no_anim = true, blur = false,
})
-- END POLY SHELL PANEL MOTION
'''


# Recognize the previously generated wallpaper-only blur block for migration.
CACHED_PANEL_RULE = PANEL_RULE.replace("xray = false", "xray = true")

THEME_REVEAL_RULE = '''-- BEGIN POLY SHELL THEME REVEAL
-- Qt owns these transitions, including the first frame after a click/drop.
hl.layer_rule({
    name = "poly-shell-theme-reveal",
    match = { namespace = "^poly-(wallpaper-reveal|theme-picker|desktop-input)$" },
    no_anim = true, blur = false,
})
-- END POLY SHELL THEME REVEAL
'''


def install_hook(paths):
    """Add one reversible include, preserving the rest of the compositor config."""
    with state_lock(paths):
        target = paths.config.parent / "hypr/hyprland.lua"
        if not target.is_file():
            raise ConfigError("hyprland.lua not found; appearance hook not installed / Не найден hyprland.lua")
        original = target.read_text()
        if HOOK_BEGIN in original or HOOK_END in original:
            start = original.find(HOOK_BEGIN)
            end = original.find(HOOK_END, max(0, start))
            block = original[start:end + len(HOOK_END)] if start >= 0 and end >= 0 else ""
            # Accept formatting-only changes while retaining the user's block.
            if re.sub(r"[\s;]+", "", block) != re.sub(r"[\s;]+", "", HOOK):
                raise ConfigError("Appearance hook modified manually / вручную; file preserved")
            updated = original
        else:
            updated = original.rstrip() + "\n\n" + HOOK
        if LEGACY_SETTINGS_RULE in updated:
            updated = updated.replace(LEGACY_SETTINGS_RULE, SETTINGS_RULE)
        if 'name = "poly-settings-window"' not in updated:
            updated = updated.rstrip() + "\n\n" + SETTINGS_RULE
        if LEGACY_PANEL_RULE in updated:
            updated = updated.replace(LEGACY_PANEL_RULE, PANEL_RULE)
        if CACHED_PANEL_RULE in updated:
            updated = updated.replace(CACHED_PANEL_RULE, PANEL_RULE)
        if PANEL_RULE_BEGIN not in updated:
            updated = updated.rstrip() + "\n\n" + PANEL_RULE
        elif PANEL_RULE not in updated:
            raise ConfigError("Panel animation rules modified manually / вручную; file preserved")
        if "-- BEGIN POLY SHELL THEME REVEAL" not in updated:
            updated = updated.rstrip() + "\n\n" + THEME_REVEAL_RULE
        if updated == original:
            return {"installed": True}
        backup = paths.state / "backups" / ("appearance-hook-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f")) / "hyprland.lua"
        atomic_text(backup, original)
        atomic_text(generated_path(paths), lua_for(visual_for(paths)))
        atomic_text(target, updated)
        return {"installed": True, "backup": str(backup)}


def atomic_text(path, text):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False, newline="") as stream:
            temporary = Path(stream.name)
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        if hasattr(os, "O_DIRECTORY"):
            descriptor = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(descriptor)
            finally:
                os.close(descriptor)
    finally:
        if temporary:
            temporary.unlink(missing_ok=True)


def hypr(*args):
    from ..adapters.base import SafeRunner
    result = SafeRunner.run(["hyprctl", *args], timeout=5.0)
    if result.returncode:
        raise ConfigError((result.stderr or result.stdout).strip() or "Hyprland unavailable / Hyprland недоступен")
    return result.stdout


def runtime_apply(values):
    if not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        raise ConfigError("Apply is only available inside Hyprland session / сеанса Hyprland")
    # hyprctl treats an argument beginning with '--' as a CLI option, even
    # when that argument is Lua source. Keep the file header out of IPC.
    code = "\n".join(lua_for(values).splitlines()[1:])
    reply = hypr("eval", code).strip()
    if reply != "ok":
        raise ConfigError("Hyprland rejected settings: " + reply)
    expected = {
        "decoration:rounding": values["windowRadius"],
        "decoration:active_opacity": values["activeOpacity"] / 100,
        "decoration:inactive_opacity": values["inactiveOpacity"] / 100,
        "decoration:blur:enabled": int(values["blurEnabled"]),
        "decoration:blur:size": values["blurSize"],
        "decoration:blur:passes": values["blurPasses"],
        "render:new_render_scheduling": 1,
        "general:gaps_in": values["windowGap"],
        "general:gaps_out": values["windowMargin"],
    }
    for option, wanted in expected.items():
        data = json.loads(hypr("-j", "getoption", option))
        if option.startswith("general:gaps_"):
            # Hyprland returns gap values as a CSS-style TRBL list.
            parts = data.get("css", "").split()
            if not 1 <= len(parts) <= 4 or any(part != str(wanted) for part in parts):
                raise ConfigError(f"Hyprland did not confirm / не подтвердил value {option}")
            continue
        actual = data.get("int", data.get("float", data.get("bool")))
        if not isinstance(actual, (int, float)) or abs(actual - wanted) > 0.001:
            raise ConfigError(f"Hyprland did not confirm / не подтвердил value {option}")


def apply(paths, patch, expected=None):
    # One lock is shared with mode/refresh operations, so unrelated state survives.
    with state_lock(paths):
        old = visual_for(paths)
        if expected is not None and validate(expected) != old:
            raise ConfigError("Settings changed in another window / в другом окне. Reopen section.")
        value = validate(old | patch) if isinstance(patch, dict) else validate(patch)
        snapshot = {"schemaVersion": 1, "mode": current_mode(paths),
                    "settings": settings_for(paths), "appearance": appearance_for(paths),
                    "visual": value}
        snapshot["profile"] = profile_for(paths, snapshot["mode"])
        from ..system.indicators import mako_style
        notification_style = mako_style(snapshot)
        notification_file = paths.state / "mako-theme.conf"
        config = paths.config / "visual.json"
        generated = generated_path(paths)
        # Persist the original files before any mutation, for exact rollback.
        originals = {p: p.read_text(encoding="utf-8") if p.exists() else None
                     for p in (config, generated, notification_file, paths.session)}
        try:
            runtime_apply(value)
            atomic_text(generated, lua_for(value))
            atomic_json(config, {"schemaVersion": 1, "values": value})
            atomic_text(notification_file, notification_style)
            # Publish to QML last; all durable configuration is ready by then.
            atomic_json(paths.session, snapshot)
        except (ConfigError, OSError, ValueError, subprocess.SubprocessError) as failure:
            failures = []
            for path, original in originals.items():
                try:
                    if original is None:
                        path.unlink(missing_ok=True)
                    elif not path.exists() or path.read_text(encoding="utf-8") != original:
                        atomic_text(path, original)
                except OSError as exc:
                    failures.append(str(exc))
            try:
                runtime_apply(old)
            except (ConfigError, OSError, ValueError, subprocess.SubprocessError) as exc:
                failures.append(str(exc))
            detail = ("; Rollback error: " + "; ".join(failures)) if failures else ""
            raise ConfigError(f"Changes not saved / не сохранены: {failure}{detail}") from failure
        try:
            subprocess.run(["makoctl", "reload"], capture_output=True, timeout=3, check=False)
        except (OSError, subprocess.SubprocessError):
            pass  # Mako is optional; saved style is used on its next start.
        return {"values": value, "defaults": dict(DEFAULTS), "saved": True}


def sync(paths):
    """Generate the persistent include at start/refresh; do not rewrite the user's config."""
    with state_lock(paths):
        value = visual_for(paths)
        target = generated_path(paths)
        text = lua_for(value)
        if not target.exists() or target.read_text() != text:
            atomic_text(target, text)
        if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
            runtime_apply(value)


def appearance_control(paths, action, payload):
    if action == "install":
        return install_hook(paths)
    if action == "get":
        with state_lock(paths):
            return {"values": visual_for(paths), "defaults": dict(DEFAULTS)}
    if not isinstance(payload, dict) or set(payload) - {"values", "expected"}:
        raise ConfigError("Invalid appearance settings request / Неверный запрос настроек")
    return apply(paths, dict(DEFAULTS) if action == "reset" else payload.get("values"),
                 payload.get("expected"))
