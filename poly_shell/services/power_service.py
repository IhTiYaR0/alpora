"""Power and battery service managing power profiles and Caffeine idle inhibition."""
import logging
import os
import shutil
import subprocess
from typing import Optional
from ..core.service import BaseService
from ..adapters.base import SafeRunner
from ..contracts.hardware import PowerStateDTO
from ..core.state import Paths

logger = logging.getLogger(__name__)


class PowerService(BaseService):
    """Encapsulates system power profiles, battery state, and idle inhibitor."""

    def __init__(self, paths: Optional[Paths] = None):
        super().__init__("power")
        self.paths = paths or Paths.current()

    def health_check(self) -> bool:
        return SafeRunner.is_available("powerprofilesctl") or SafeRunner.is_available("upower")

    def get_state(self) -> PowerStateDTO:
        caffeine_file = self.paths.state / "caffeine.active"
        is_caffeine = caffeine_file.exists()
        current_profile = "balanced"
        if SafeRunner.is_available("powerprofilesctl"):
            res = SafeRunner.run(["powerprofilesctl", "get"], timeout=2.0)
            if res.returncode == 0 and res.stdout.strip():
                current_profile = res.stdout.strip()

        return PowerStateDTO(
            profile=current_profile,
            caffeine=is_caffeine,
            caffeine_available=True,
        )

    def set_caffeine(self, enabled: bool) -> bool:
        active_marker = self.paths.state / "caffeine.active"
        pid_file = self.paths.state / "caffeine.pid"
        self.paths.state.mkdir(parents=True, exist_ok=True)
        if enabled:
            if not active_marker.exists():
                active_marker.touch()
            if shutil.which("systemd-inhibit"):
                try:
                    proc = subprocess.Popen(
                        ["systemd-inhibit", "--what=idle:sleep", "--who=ALPORA", "--why=Caffeine active", "sleep", "infinity"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        start_new_session=True,
                    )
                    pid_file.write_text(str(proc.pid))
                except Exception as exc:
                    logger.warning("Failed to launch systemd-inhibit: %s", exc)
            return True
        else:
            if active_marker.exists():
                try:
                    active_marker.unlink()
                except OSError:
                    pass
            if pid_file.exists():
                try:
                    pid = int(pid_file.read_text().strip())
                    os.kill(pid, 15)
                except Exception:
                    pass
                try:
                    pid_file.unlink()
                except OSError:
                    pass
            return False

    def set_profile(self, profile: str) -> bool:
        safe_profiles = {"balanced", "power-saver", "performance"}
        if profile not in safe_profiles:
            return False
        res = SafeRunner.run(["powerprofilesctl", "set", profile], timeout=3.0)
        return res.returncode == 0

