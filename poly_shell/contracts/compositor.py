"""Compositor, Window Management and Wellbeing DTOs."""
from dataclasses import dataclass, field
from typing import List, Tuple
from .base import BaseDTO


@dataclass
class WorkspaceDTO(BaseDTO):
    """Compositor workspace representation."""

    id: int
    name: str
    monitor: str = ""
    active: bool = False
    has_fullscreen: bool = False
    urgent: bool = False


@dataclass
class WindowDTO(BaseDTO):
    """Managed Wayland client window."""

    address: str
    title: str
    class_name: str
    workspace_id: int
    at: Tuple[int, int] = (0, 0)
    size: Tuple[int, int] = (0, 0)
    floating: bool = False
    focused: bool = False


@dataclass
class AppUsageDTO(BaseDTO):
    """Application usage duration record."""

    name: str
    seconds: int
    minutes: float = 0.0


@dataclass
class WellbeingSummaryDTO(BaseDTO):
    """Daily screen-time report."""

    date: str
    total_seconds: int
    total_minutes: float
    apps: List[AppUsageDTO] = field(default_factory=list)


@dataclass
class ProcessDTO(BaseDTO):
    """Task Manager process record."""

    pid: int
    name: str
    cpu_percent: float = 0.0
    memory_mb: float = 0.0
    memory_percent: float = 0.0
    user: str = ""
    status: str = "running"

