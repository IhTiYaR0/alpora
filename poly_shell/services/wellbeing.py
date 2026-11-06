"""Digital Wellbeing: Screen time and application usage tracking for ALPORA."""
from datetime import date, datetime
import json
import logging
from pathlib import Path
import time

from ..core.state import Paths, atomic_json, read_object

logger = logging.getLogger(__name__)


class WellbeingTracker:
    """Lightweight event-driven tracker for active application screen time."""

    def __init__(self, paths: Paths):
        self.paths = paths
        self.state_file = paths.state / "wellbeing.json"
        self._current_app = ""
        self._last_timestamp = time.time()

    def _today_key(self) -> str:
        return date.today().isoformat()

    def record_switch(self, app_class: str) -> None:
        """Record window switch and accumulate duration for the previously active app."""
        now = time.time()
        duration = max(0.0, now - self._last_timestamp)
        self._last_timestamp = now

        # Skip recording idle or empty switches (< 0.5s or duration > 30 mins which indicates sleep/idle)
        if self._current_app and 0.5 <= duration <= 1800.0:
            self._accumulate(self._current_app, duration)

        self._current_app = str(app_class).strip() if app_class else ""

    def _accumulate(self, app: str, duration: float) -> None:
        try:
            data = read_object(self.state_file) if self.state_file.exists() else {}
        except Exception:
            data = {}

        today = self._today_key()
        day_record = data.setdefault(today, {"total_seconds": 0, "apps": {}})
        day_record["total_seconds"] = int(day_record.get("total_seconds", 0) + duration)

        apps = day_record.setdefault("apps", {})
        apps[app] = int(apps.get(app, 0) + duration)

        # Retain last 14 days of history to prevent unbounded growth
        sorted_keys = sorted(data.keys())
        if len(sorted_keys) > 14:
            for old_key in sorted_keys[:-14]:
                data.pop(old_key, None)

        try:
            atomic_json(self.state_file, data)
        except Exception as exc:
            logger.warning("Failed to save wellbeing data: %s", exc)

    def get_summary(self, target_date: str = "") -> dict:
        """Return screen time summary for a given day (defaults to today)."""
        target = target_date or self._today_key()
        try:
            data = read_object(self.state_file) if self.state_file.exists() else {}
        except Exception:
            data = {}

        day_data = data.get(target, {"total_seconds": 0, "apps": {}})
        apps = day_data.get("apps", {})
        sorted_apps = sorted(apps.items(), key=lambda item: item[1], reverse=True)

        return {
            "date": target,
            "total_seconds": day_data.get("total_seconds", 0),
            "total_minutes": round(day_data.get("total_seconds", 0) / 60, 1),
            "apps": [{"name": k, "seconds": v, "minutes": round(v / 60, 1)} for k, v in sorted_apps]
        }

