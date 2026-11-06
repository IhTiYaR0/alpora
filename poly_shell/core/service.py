"""Lifecycle-managed service interface and registry."""
from abc import ABC, abstractmethod
import logging
from typing import Any, Dict, Optional
from ..contracts.base import BaseDTO

logger = logging.getLogger(__name__)


class BaseService(ABC):
    """Abstract base class for all domain services."""

    def __init__(self, name: str):
        self._name = name
        self._running = False

    @property
    def name(self) -> str:
        return self._name

    @property
    def is_running(self) -> bool:
        return self._running

    def start(self) -> None:
        """Start or initialize service resources."""
        self._running = True

    def stop(self) -> None:
        """Release service resources and terminate workers."""
        self._running = False

    @abstractmethod
    def health_check(self) -> bool:
        """Return True if service dependencies and runners are healthy."""
        raise NotImplementedError

    @abstractmethod
    def get_state(self) -> BaseDTO:
        """Return strongly-typed DTO of current domain state."""
        raise NotImplementedError


class ServiceRegistry:
    """Singleton service registry providing dependency injection and lifecycle control."""

    _instance: Optional["ServiceRegistry"] = None

    def __init__(self):
        self._services: Dict[str, BaseService] = {}

    @classmethod
    def get_instance(cls) -> "ServiceRegistry":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def register(self, service: BaseService) -> None:
        if service.name in self._services:
            logger.warning("Overwriting registered service: %s", service.name)
        self._services[service.name] = service

    def get(self, name: str) -> Optional[BaseService]:
        return self._services.get(name)

    def all(self) -> Dict[str, BaseService]:
        return dict(self._services)

    def health_report(self) -> Dict[str, bool]:
        report = {}
        for name, s in self._services.items():
            try:
                report[name] = s.health_check()
            except Exception as exc:
                logger.error("Health check failed for %s: %s", name, exc)
                report[name] = False
        return report

    def shutdown_all(self) -> None:
        for name, s in self._services.items():
            try:
                s.stop()
            except Exception as exc:
                logger.error("Error stopping service %s: %s", name, exc)
        self._services.clear()

