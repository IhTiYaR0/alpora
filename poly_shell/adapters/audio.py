"""Audio subsystem adapter for volume and player control via SafeRunner."""
from __future__ import annotations

import time
from typing import Sequence
from .base import SafeRunner


class AudioAdapter:
    """Encapsulates system audio controls (wpctl, pactl, playerctl)."""

    _cached_volume: float = 0.0
    _volume_cached_at: float = 0.0

    @classmethod
    def is_available(cls) -> bool:
        return SafeRunner.is_available("wpctl") or SafeRunner.is_available("pactl")

    @classmethod
    def get_volume(cls) -> float:
        """Query default sink volume (0.0 to 1.0) using wpctl with TTL caching."""
        if not SafeRunner.is_available("wpctl"):
            return 0.0

        now = time.monotonic()
        if (now - cls._volume_cached_at) < 0.25:
            return cls._cached_volume
        res = SafeRunner.run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], timeout=3.0)
        if res.returncode == 0 and res.stdout.strip():
            parts = res.stdout.strip().split()
            if len(parts) >= 2:
                try:
                    vol = float(parts[1])
                    cls._cached_volume = vol
                    cls._volume_cached_at = now
                    return vol
                except ValueError:
                    pass
        return cls._cached_volume

    @classmethod
    def set_volume(cls, percent: int) -> bool:
        """Set default sink volume (0 to 150%)."""
        val = max(0, min(150, int(percent)))
        cls._cached_volume = val / 100.0
        cls._volume_cached_at = time.monotonic()
        res = SafeRunner.run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{val}%"], timeout=3.0)
        return res.returncode == 0

    @classmethod
    def toggle_mute(cls) -> bool:
        """Toggle mute on default audio sink."""
        cls._volume_cached_at = 0.0  # invalidate cache
        res = SafeRunner.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"], timeout=3.0)
        return res.returncode == 0

    @classmethod
    def player_control(cls, action: str) -> bool:
        """Send playback command via playerctl (play-pause, next, previous, stop)."""
        safe_actions = {"play-pause", "next", "previous", "play", "pause", "stop"}
        if action not in safe_actions:
            return False
        res = SafeRunner.run(["playerctl", action], timeout=3.0)
        return res.returncode == 0
