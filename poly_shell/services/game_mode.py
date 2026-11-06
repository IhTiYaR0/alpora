"""Game Mode service for CPU governor tuning, Hyprland load reduction, and Hoyoverse gaming optimizations."""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path
import shutil
import subprocess
import time
from typing import Any, Dict, List, Optional

from ..adapters.base import SafeRunner
from ..contracts.hardware import GameModeDTO
from ..core.service import BaseService
from ..core.state import Paths

logger = logging.getLogger(__name__)

HOYOVERSE_PRESETS: Dict[str, Dict[str, Any]] = {
    "zzz": {
        "title": "Zenless Zone Zero (ZZZ)",
        "description": "Ultra-responsive combat profile with asynchronous DXVK pipeline caching and low-latency audio.",
        "aur_launcher": "aagl-gtk-bin (An Anime Game Launcher)",
        "env_vars": {
            "WINEESYNC": "1",
            "WINEFSYNC": "1",
            "DXVK_ASYNC": "1",
            "DXVK_STATE_CACHE": "1",
            "STAGING_SHARED_MEMORY": "1",
            "PULSE_LATENCY_MSEC": "30",
            "MESA_VK_WSI_PRESENT_MODE": "mailbox",
            "__GL_SHADER_DISK_CACHE": "1",
            "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP": "1",
        },
        "recommendations": [
            "Install 'aagl-gtk-bin' or 'anime-game-launcher' from AUR for automated patch management.",
            "Use Proton-GE or Wine-GE for direct DX11/DX12 translation.",
            "Set in-game display mode to 'Borderless Windowed' for optimal Hyprland Wayland tearing-free sync.",
        ],
    },
    "honkai": {
        "title": "Honkai: Star Rail (HSR)",
        "description": "Stable frame-rate profile with shader pre-caching and high-efficiency CPU scheduling.",
        "aur_launcher": "aagl-gtk-bin (The Honkai Star Rail Launcher)",
        "env_vars": {
            "WINEESYNC": "1",
            "WINEFSYNC": "1",
            "DXVK_ASYNC": "1",
            "DXVK_STATE_CACHE": "1",
            "STAGING_SHARED_MEMORY": "1",
            "PULSE_LATENCY_MSEC": "40",
            "MESA_VK_WSI_PRESENT_MODE": "mailbox",
            "DXVK_FRAME_RATE": "60",
        },
        "recommendations": [
            "Set FPS Limit to 60 or 120 according to your monitor refresh rate.",
            "Enable DXVK Async to eliminate first-load combat stuttering.",
            "Use GameMode to ensure CPU scheduler prioritizes the Star Rail main render thread.",
        ],
    },
    "genshin": {
        "title": "Genshin Impact",
        "description": "Open-world exploration profile with texture streaming optimizations.",
        "aur_launcher": "aagl-gtk-bin (An Anime Game Launcher)",
        "env_vars": {
            "WINEESYNC": "1",
            "WINEFSYNC": "1",
            "DXVK_ASYNC": "1",
            "DXVK_STATE_CACHE": "1",
            "MESA_VK_WSI_PRESENT_MODE": "mailbox",
        },
        "recommendations": [
            "Borderless Fullscreen recommended under Hyprland.",
            "Install 'gamemode' package for kernel-level CPU core pinning.",
        ],
    },
}


class GameModeService(BaseService):
    """Orchestrates gaming performance boosts and suspends compositor overhead."""

    def __init__(self, paths: Optional[Paths] = None):
        super().__init__("gamemode")
        self.paths = paths or Paths.current()

    def health_check(self) -> bool:
        return (
            SafeRunner.is_available("powerprofilesctl")
            or SafeRunner.is_available("gamemoded")
            or SafeRunner.is_available("hyprctl")
        )

    def _marker_path(self) -> Path:
        return self.paths.state / "gamemode.active"

    def get_state(self) -> GameModeDTO:
        marker = self._marker_path()
        is_active = marker.exists()
        active_game: Optional[str] = None

        if is_active:
            try:
                data = json.loads(marker.read_text(encoding="utf-8"))
                active_game = data.get("game")
            except Exception:
                active_game = None

        governor = "balanced"
        if SafeRunner.is_available("powerprofilesctl"):
            res = SafeRunner.run(["powerprofilesctl", "get"], timeout=2.0)
            if res.returncode == 0 and res.stdout.strip():
                governor = res.stdout.strip()

        optimizations: List[str] = []
        if is_active:
            optimizations.append("hyprland_animations_disabled")
            optimizations.append("hyprland_blur_disabled")
            optimizations.append("hyprland_drop_shadow_disabled")
            if governor == "performance":
                optimizations.append("cpu_governor_performance")
            if SafeRunner.is_available("gamemoded"):
                optimizations.append("feral_gamemode_active")

        return GameModeDTO(
            enabled=is_active,
            active_game=active_game,
            cpu_governor=governor,
            animations_disabled=is_active,
            blur_disabled=is_active,
            gamemode_available=SafeRunner.is_available("gamemoded"),
            optimizations=optimizations,
        )

    def enable(self, game_name: Optional[str] = None) -> bool:
        """Activates Game Mode, disables compositor eye-candy, and elevates CPU/GPU profiles."""
        marker = self._marker_path()
        self.paths.state.mkdir(parents=True, exist_ok=True)

        payload = {"game": game_name or "Generic Game", "started_at": time.time()}
        marker.write_text(json.dumps(payload), encoding="utf-8")

        # 1. Reduce compositor GPU/CPU overhead in Hyprland
        if SafeRunner.is_available("hyprctl"):
            SafeRunner.run(["hyprctl", "keyword", "animations:enabled", "0"], timeout=2.0)
            SafeRunner.run(["hyprctl", "keyword", "decoration:blur:enabled", "0"], timeout=2.0)
            SafeRunner.run(["hyprctl", "keyword", "decoration:drop_shadow", "0"], timeout=2.0)
            SafeRunner.run(["hyprctl", "keyword", "misc:vfr", "0"], timeout=2.0)

        # 2. Elevate CPU governor to maximum performance
        if SafeRunner.is_available("powerprofilesctl"):
            SafeRunner.run(["powerprofilesctl", "set", "performance"], timeout=2.0)

        # 3. Request Feral GameMode daemon if available
        if SafeRunner.is_available("gamemoded"):
            SafeRunner.run(["gamemoded", "-r"], timeout=2.0)

        logger.info("ALPORA Game Mode ENABLED for: %s", payload["game"])
        return True

    def disable(self) -> bool:
        """Deactivates Game Mode and restores compositor animations and balanced power."""
        marker = self._marker_path()
        if marker.exists():
            try:
                marker.unlink()
            except OSError:
                pass

        # 1. Restore Hyprland animations and blur
        if SafeRunner.is_available("hyprctl"):
            SafeRunner.run(["hyprctl", "keyword", "animations:enabled", "1"], timeout=2.0)
            SafeRunner.run(["hyprctl", "keyword", "decoration:blur:enabled", "1"], timeout=2.0)
            SafeRunner.run(["hyprctl", "keyword", "decoration:drop_shadow", "1"], timeout=2.0)
            SafeRunner.run(["hyprctl", "keyword", "misc:vfr", "1"], timeout=2.0)

        # 2. Revert CPU governor to balanced
        if SafeRunner.is_available("powerprofilesctl"):
            SafeRunner.run(["powerprofilesctl", "set", "balanced"], timeout=2.0)

        logger.info("ALPORA Game Mode DISABLED. Restored default compositor and CPU governor.")
        return True

    def toggle(self, game_name: Optional[str] = None) -> bool:
        """Toggles Game Mode on or off."""
        if self._marker_path().exists():
            self.disable()
            return False
        else:
            self.enable(game_name)
            return True

    @staticmethod
    def get_hoyoverse_preset(name: str) -> Dict[str, Any]:
        """Returns optimized environment variables and recommendations for a Hoyoverse title."""
        key = name.lower().strip()
        if key in ("zzz", "zenless", "zenlesszonezero", "zenless-zone-zero"):
            return HOYOVERSE_PRESETS["zzz"]
        elif key in ("honkai", "starrail", "hsr", "honkai-star-rail", "star-rail"):
            return HOYOVERSE_PRESETS["honkai"]
        elif key in ("genshin", "gi", "genshin-impact"):
            return HOYOVERSE_PRESETS["genshin"]
        return HOYOVERSE_PRESETS["zzz"]

    def launch_game(self, command_args: List[str], game_name: Optional[str] = None) -> int:
        """Launches a game command wrapped with Game Mode lifecycle and Hoyoverse optimizations."""
        preset = self.get_hoyoverse_preset(game_name or (command_args[0] if command_args else "zzz"))
        env = os.environ.copy()
        env.update(preset.get("env_vars", {}))

        self.enable(preset["title"])
        try:
            res = subprocess.run(command_args, env=env, check=False)
            return res.returncode
        finally:
            self.disable()

