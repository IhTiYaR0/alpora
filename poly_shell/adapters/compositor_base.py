"""Abstract base interface for Wayland compositor adapters."""
from __future__ import annotations
from abc import ABC, abstractmethod
from typing import Any, Sequence


class BaseCompositorAdapter(ABC):
    """Abstract interface defining required compositor capabilities."""

    @classmethod
    @abstractmethod
    def is_available(cls) -> bool:
        """Check if compositor IPC tool is accessible."""
        raise NotImplementedError

    @classmethod
    @abstractmethod
    def get_monitors(cls) -> list[dict[str, Any]]:
        """Return list of active displays."""
        raise NotImplementedError

    @classmethod
    @abstractmethod
    def get_workspaces(cls) -> list[dict[str, Any]]:
        """Return list of workspaces."""
        raise NotImplementedError

    @classmethod
    @abstractmethod
    def get_clients(cls) -> list[dict[str, Any]]:
        """Return list of managed client windows."""
        raise NotImplementedError

    @classmethod
    @abstractmethod
    def dispatch(cls, command: str) -> bool:
        """Execute a compositor dispatch action (e.g. switch workspace, focus window)."""
        raise NotImplementedError

