"""Phone ecosystem service integrating KDE Connect for device pairing, notifications, and clipboard sync."""
from __future__ import annotations

import logging
from pathlib import Path
import re
import time
from typing import List, Optional

from ..adapters.base import SafeRunner
from ..contracts.hardware import PhoneDeviceDTO, PhoneStateDTO
from ..core.service import BaseService
from ..core.state import Paths

logger = logging.getLogger(__name__)


class PhoneService(BaseService):
    """Provides mobile phone ecosystem features (battery, ring phone, clipboard sharing)."""

    _cached_devices: List[PhoneDeviceDTO] = []
    _devices_cached_at: float = 0.0

    def __init__(self, paths: Optional[Paths] = None):
        super().__init__("phone")
        self.paths = paths or Paths.current()

    def health_check(self) -> bool:
        """Returns True if kdeconnect-cli is available on the system."""
        return SafeRunner.is_available("kdeconnect-cli")

    def get_devices(self, force_refresh: bool = False) -> List[PhoneDeviceDTO]:
        """Lists paired and reachable phone devices via kdeconnect-cli with TTL caching."""
        if not self.health_check():
            return []

        now = time.monotonic()
        if not force_refresh and (now - self._devices_cached_at) < 2.0:
            return self._cached_devices

        res = SafeRunner.run(["kdeconnect-cli", "-l"], timeout=3.0)
        devices: List[PhoneDeviceDTO] = []

        if res.returncode == 0 and res.stdout.strip():
            for line in res.stdout.strip().splitlines():
                line = line.strip()
                # Format: "- DeviceName: 12345678abcdef (reachable)" or "- DeviceName: 123456 (paired and reachable)"
                match = re.match(r"^-\s*(.*?):\s*([a-zA-Z0-9_-]+)\s*(?:\((.*?)\))?$", line)
                if match:
                    name = match.group(1).strip()
                    dev_id = match.group(2).strip()
                    status_str = (match.group(3) or "").lower()
                    is_reachable = "reachable" in status_str
                    is_trusted = "paired" in status_str or True

                    devices.append(
                        PhoneDeviceDTO(
                            id=dev_id,
                            name=name,
                            is_reachable=is_reachable,
                            is_trusted=is_trusted,
                            battery=None,
                            is_charging=False,
                        )
                    )

        self._cached_devices = devices
        self._devices_cached_at = now
        return devices

    def get_active_device(self) -> Optional[PhoneDeviceDTO]:
        """Returns the first reachable phone device, or the first paired device."""
        devices = self.get_devices()
        for dev in devices:
            if dev.is_reachable:
                return dev
        return devices[0] if devices else None

    def get_state(self) -> PhoneStateDTO:
        """Returns a snapshot DTO of the phone ecosystem status."""
        devices = self.get_devices()
        active = self.get_active_device()
        return PhoneStateDTO(
            available=self.health_check(),
            devices=devices,
            active_device_id=active.id if active else None,
        )

    def ring_device(self, device_id: Optional[str] = None) -> bool:
        """Rings the specified phone (or active phone) to help locate it."""
        if not self.health_check():
            logger.warning("kdeconnect-cli not found. Cannot ring device.")
            return False

        dev_id = device_id or (self.get_active_device().id if self.get_active_device() else None)
        if not dev_id:
            logger.warning("No paired or reachable phone found to ring.")
            return False

        res = SafeRunner.run(["kdeconnect-cli", "--device", dev_id, "--ring"], timeout=3.0)
        return res.returncode == 0

    def send_ping(self, device_id: Optional[str] = None, message: str = "ALPORA Connected") -> bool:
        """Sends a ping test notification to the phone."""
        if not self.health_check():
            return False

        dev_id = device_id or (self.get_active_device().id if self.get_active_device() else None)
        if not dev_id:
            return False

        res = SafeRunner.run(["kdeconnect-cli", "--device", dev_id, "--ping-msg", message], timeout=3.0)
        return res.returncode == 0

    def share_clipboard(self, text: Optional[str] = None, device_id: Optional[str] = None) -> bool:
        """Syncs given text (or current desktop clipboard) to the phone."""
        if not self.health_check():
            return False

        dev_id = device_id or (self.get_active_device().id if self.get_active_device() else None)
        if not dev_id:
            return False

        content = text
        if content is None and SafeRunner.is_available("wl-paste"):
            res = SafeRunner.run(["wl-paste", "--no-newline"], timeout=2.0)
            if res.returncode == 0:
                content = res.stdout

        if not content:
            logger.warning("Clipboard is empty; nothing to share.")
            return False

        res = SafeRunner.run(["kdeconnect-cli", "--device", dev_id, "--share-text", str(content)], timeout=3.0)
        return res.returncode == 0

    def send_file(self, file_path: str | Path, device_id: Optional[str] = None) -> bool:
        """Shares a file wirelessly to the paired phone."""
        if not self.health_check():
            return False

        path = Path(file_path).expanduser().resolve()
        if not path.is_file():
            logger.warning("Target file %s does not exist.", path)
            return False

        dev_id = device_id or (self.get_active_device().id if self.get_active_device() else None)
        if not dev_id:
            return False

        res = SafeRunner.run(["kdeconnect-cli", "--device", dev_id, "--share", str(path)], timeout=5.0)
        return res.returncode == 0
