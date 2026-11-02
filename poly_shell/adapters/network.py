"""Networking and radio subsystem adapter using SafeRunner."""
from __future__ import annotations

import time
from typing import Any
from .base import SafeRunner


class NetworkAdapter:
    """Encapsulates interaction with NetworkManager, rfkill, and bluetoothctl."""

    _cached_radio: dict[str, bool] = {"wifi": False, "wwan": False}
    _radio_cached_at: float = 0.0

    @classmethod
    def is_nm_available(cls) -> bool:
        return SafeRunner.is_available("nmcli")

    @classmethod
    def is_rfkill_available(cls) -> bool:
        return SafeRunner.is_available("rfkill")

    @classmethod
    def is_bluetooth_available(cls) -> bool:
        return SafeRunner.is_available("bluetoothctl")

    @classmethod
    def get_radio_status(cls) -> dict[str, bool]:
        """Check Wi-Fi and WWAN radio status via nmcli with TTL caching."""
        now = time.monotonic()
        if (now - cls._radio_cached_at) < 1.0:
            return cls._cached_radio

        if not cls.is_nm_available():
            return {"wifi": False, "wwan": False}
        res = SafeRunner.run(["nmcli", "-t", "-f", "WIFI,WWAN", "radio"], timeout=3.0)
        if res.returncode == 0:
            parts = res.stdout.strip().split(":")
            if len(parts) == 2:
                cls._cached_radio = {
                    "wifi": parts[0].strip() == "enabled",
                    "wwan": parts[1].strip() == "enabled",
                }
                cls._radio_cached_at = now
                return cls._cached_radio
        return cls._cached_radio

    @classmethod
    def set_wifi_enabled(cls, enabled: bool) -> bool:
        """Enable or disable Wi-Fi radio via nmcli."""
        cls._radio_cached_at = 0.0
        arg = "on" if enabled else "off"
        res = SafeRunner.run(["nmcli", "radio", "wifi", arg], timeout=4.0)
        return res.returncode == 0

    @classmethod
    def block_rfkill(cls, identifier_or_all: str, block: bool) -> bool:
        """Block or unblock wireless devices via rfkill."""
        cls._radio_cached_at = 0.0
        action = "block" if block else "unblock"
        res = SafeRunner.run(["rfkill", action, str(identifier_or_all)], timeout=4.0)
        return res.returncode == 0
