"""Clipboard Domain Service for ALPORA Shell."""
from __future__ import annotations

from dataclasses import dataclass
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional
from ..contracts.base import BaseDTO
from ..core.service import BaseService
from .clipboard import History, directory

logger = logging.getLogger(__name__)


@dataclass
class ClipboardItemDTO(BaseDTO):
    """Single clipboard entry."""
    id: str = ""
    mime: str = ""
    preview: str = ""
    updated: float = 0.0
    pinned: bool = False


@dataclass
class ClipboardStateDTO(BaseDTO):
    """Current clipboard service status."""
    paused: bool = False
    item_count: int = 0
    pinned_count: int = 0


class ClipboardService(BaseService):
    """Domain service managing clipboard history, favorites, and pause state."""

    def __init__(self, storage_dir: Optional[Path] = None):
        super().__init__("clipboard")
        self._dir = storage_dir or directory()
        self._history: Optional[History] = None

    def _ensure_history(self) -> History:
        if self._history is None:
            self._history = History(self._dir)
        return self._history

    def stop(self) -> None:
        """Close database connection on stop."""
        super().stop()
        if self._history and getattr(self._history, "db", None):
            try:
                self._history.db.close()
            except Exception:
                pass
            self._history = None

    def health_check(self) -> bool:
        """Verify sqlite database connection and storage access."""
        try:
            h = self._ensure_history()
            return h.db is not None
        except Exception as exc:
            logger.error("Clipboard service health check failed: %s", exc)
            return False

    def get_state(self) -> ClipboardStateDTO:
        """Return current state summary."""
        try:
            h = self._ensure_history()
            cur = h.db.cursor()
            paused = h.paused
            total = cur.execute("SELECT count(*) FROM clips").fetchone()[0]
            pinned = cur.execute("SELECT count(*) FROM clips WHERE pinned=1").fetchone()[0]
            return ClipboardStateDTO(paused=paused, item_count=total, pinned_count=pinned)
        except Exception as exc:
            logger.error("Error retrieving clipboard state: %s", exc)
            return ClipboardStateDTO(paused=False, item_count=0, pinned_count=0)

    def get_items(self) -> List[Dict[str, Any]]:
        """Return list of recent clips."""
        try:
            h = self._ensure_history()
            return h.items()
        except Exception as exc:
            logger.error("Error listing clipboard items: %s", exc)
            return []

    def perform_action(self, action: str, item_id: str = "") -> None:
        """Execute clipboard action (pin, unpin, delete, clear, pause, resume)."""
        h = self._ensure_history()
        h.action(action, item_id)
