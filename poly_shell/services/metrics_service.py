"""System and Developer Metrics Service for ALPORA Shell."""
from __future__ import annotations

from dataclasses import dataclass, field
import logging
import time
from typing import Any, Dict, List, Optional
from ..contracts.base import BaseDTO
from ..core.service import BaseService
from .developer_metrics import snapshot as get_raw_snapshot

logger = logging.getLogger(__name__)


@dataclass
class MetricsStateDTO(BaseDTO):
    """Container DTO for full developer system metrics."""
    sampled_at: float = 0.0
    hostname: str = ""
    cpu: Dict[str, Any] = field(default_factory=dict)
    memory: Dict[str, Any] = field(default_factory=dict)
    gpu: Dict[str, Any] = field(default_factory=dict)
    network: Dict[str, Any] = field(default_factory=dict)
    disk: Dict[str, Any] = field(default_factory=dict)
    uptime_seconds: int = 0
    processes_cpu: List[Dict[str, Any]] = field(default_factory=list)
    processes_memory: List[Dict[str, Any]] = field(default_factory=list)


class MetricsService(BaseService):
    """Domain service managing Linux system and hardware performance metrics."""

    def __init__(self, cache_ttl_sec: float = 2.0):
        super().__init__("metrics")
        self._cache_ttl = cache_ttl_sec
        self._last_snapshot: Optional[Dict[str, Any]] = None
        self._last_sampled_at: float = 0.0

    def health_check(self) -> bool:
        """Return True if system metrics can be sampled successfully."""
        try:
            data = self.get_snapshot()
            return isinstance(data, dict) and "cpu" in data
        except Exception as exc:
            logger.error("Metrics health check failed: %s", exc)
            return False

    def get_snapshot(self) -> Dict[str, Any]:
        """Return cached or fresh metrics snapshot."""
        now = time.time()
        if self._last_snapshot is None or (now - self._last_sampled_at) > self._cache_ttl:
            self._last_snapshot = get_raw_snapshot()
            self._last_sampled_at = now
        return self._last_snapshot

    def get_state(self) -> MetricsStateDTO:
        """Return strongly typed DTO of current system metrics."""
        snap = self.get_snapshot()
        return MetricsStateDTO(
            sampled_at=snap.get("sampled_at", 0.0),
            hostname=snap.get("hostname", ""),
            cpu=snap.get("cpu", {}),
            memory=snap.get("memory", {}),
            gpu=snap.get("gpu", {}),
            network=snap.get("network", {}),
            disk=snap.get("disk", {}),
            uptime_seconds=snap.get("uptime_seconds", 0),
            processes_cpu=snap.get("processes_cpu", []),
            processes_memory=snap.get("processes_memory", []),
        )
