"""Master daemon orchestrating IPC server, system services, and compositor streams."""
from __future__ import annotations

import logging
import os
from pathlib import Path
import threading
import time
from typing import Optional

from .ipc_server import IPCServer
from .service import ServiceRegistry
from ..adapters.hyprland import HyprlandAdapter
from ..contracts.base import ShellEventEnvelope
from ..services.audio_service import AudioService
from ..services.network_service import NetworkService
from ..services.power_service import PowerService
from ..services.metrics_service import MetricsService
from ..services.clipboard_service import ClipboardService
from ..services.game_mode import GameModeService
from ..services.phone_service import PhoneService
from ..services.security_service import SecurityService
from ..services.storage_service import StorageService
from ..services.dev_toolbox import DevToolboxService

logger = logging.getLogger(__name__)


class PolyShellDaemon:
    """Core long-running supervisor for desktop shell services and event distribution."""

    def __init__(self, socket_path: Optional[Path] = None):
        self.socket_path = socket_path
        self.ipc_server = IPCServer(socket_path=socket_path)
        self.registry = ServiceRegistry.get_instance()
        self._running = False
        self._event_thread: Optional[threading.Thread] = None

        # Setup standard domain services
        self.audio_service = AudioService()
        self.network_service = NetworkService()
        self.power_service = PowerService()
        self.metrics_service = MetricsService()
        self.clipboard_service = ClipboardService()
        self.gamemode_service = GameModeService()
        self.phone_service = PhoneService()
        self.security_service = SecurityService(socket_path=socket_path)
        self.storage_service = StorageService()
        self.dev_toolbox_service = DevToolboxService()

        self.registry.register(self.audio_service)
        self.registry.register(self.network_service)
        self.registry.register(self.power_service)
        self.registry.register(self.metrics_service)
        self.registry.register(self.clipboard_service)
        self.registry.register(self.gamemode_service)
        self.registry.register(self.phone_service)
        self.registry.register(self.security_service)
        self.registry.register(self.storage_service)
        self.registry.register(self.dev_toolbox_service)

        self._setup_ipc_handlers()

    def _setup_ipc_handlers(self) -> None:
        """Register RPC routes on the IPC server."""
        # Compositor endpoints (zero-fork queries)
        self.ipc_server.register_handler("compositor.workspaces", lambda _p: HyprlandAdapter.get_workspaces())
        self.ipc_server.register_handler("compositor.clients", lambda _p: HyprlandAdapter.get_clients())
        self.ipc_server.register_handler("compositor.monitors", lambda _p: HyprlandAdapter.get_monitors())
        self.ipc_server.register_handler(
            "compositor.dispatch",
            lambda p: HyprlandAdapter.dispatch(p.get("dispatcher", ""), p.get("arg", "")),
        )

        # Audio endpoints
        self.ipc_server.register_handler("audio.state", lambda _p: self.audio_service.get_state().to_dict())
        self.ipc_server.register_handler(
            "audio.set_volume",
            lambda p: self.audio_service.set_volume(int(p.get("percent", 50))),
        )
        self.ipc_server.register_handler("audio.toggle_mute", lambda _p: self.audio_service.toggle_mute())

        # Network endpoints
        self.ipc_server.register_handler("network.state", lambda _p: self.network_service.get_state().to_dict())
        self.ipc_server.register_handler(
            "network.set_wifi",
            lambda p: self.network_service.set_wifi_enabled(bool(p.get("enabled", True))),
        )

        # Power endpoints
        self.ipc_server.register_handler("power.state", lambda _p: self.power_service.get_state().to_dict())
        self.ipc_server.register_handler("power.toggle_caffeine", lambda _p: self.power_service.toggle_caffeine())

        # Metrics endpoints
        self.ipc_server.register_handler("metrics.snapshot", lambda _p: self.metrics_service.get_snapshot())

        # Clipboard endpoints
        self.ipc_server.register_handler("clipboard.state", lambda _p: self.clipboard_service.get_state().to_dict())
        self.ipc_server.register_handler("clipboard.items", lambda _p: self.clipboard_service.get_items())
        self.ipc_server.register_handler(
            "clipboard.action",
            lambda p: self.clipboard_service.perform_action(str(p.get("action", "")), str(p.get("id", ""))),
        )

        # Process / Running Apps endpoints (zero python interpreter spawn)
        try:
            from ..system.running_apps import snapshot as proc_snapshot, terminate as proc_terminate
            self.ipc_server.register_handler("apps.snapshot", lambda p: proc_snapshot(p.get("windows", [])))
            self.ipc_server.register_handler(
                "apps.signal",
                lambda p: proc_terminate(int(p.get("pid", 0)), int(p.get("start_ticks", 0)), str(p.get("sig", "TERM"))),
            )
        except ImportError:
            pass

        # Game Mode endpoints
        self.ipc_server.register_handler("gamemode.state", lambda _p: self.gamemode_service.get_state().to_dict())
        self.ipc_server.register_handler("gamemode.enable", lambda p: self.gamemode_service.enable(p.get("game")))
        self.ipc_server.register_handler("gamemode.disable", lambda _p: self.gamemode_service.disable())
        self.ipc_server.register_handler("gamemode.toggle", lambda p: self.gamemode_service.toggle(p.get("game")))
        self.ipc_server.register_handler("gamemode.hoyo", lambda p: self.gamemode_service.get_hoyoverse_preset(p.get("game", "zzz")))

        # Phone Ecosystem endpoints
        self.ipc_server.register_handler("phone.state", lambda _p: self.phone_service.get_state().to_dict())
        self.ipc_server.register_handler("phone.devices", lambda _p: [d.to_dict() for d in self.phone_service.get_devices()])
        self.ipc_server.register_handler("phone.ring", lambda p: self.phone_service.ring_device(p.get("device_id")))
        self.ipc_server.register_handler("phone.ping", lambda p: self.phone_service.send_ping(p.get("device_id"), p.get("message", "ALPORA Ping")))
        self.ipc_server.register_handler("phone.share_clipboard", lambda p: self.phone_service.share_clipboard(p.get("text"), p.get("device_id")))
        self.ipc_server.register_handler("phone.send_file", lambda p: self.phone_service.send_file(p.get("file_path", ""), p.get("device_id")))

        # Security & Hardening endpoints
        self.ipc_server.register_handler("security.audit", lambda _p: self.security_service.audit().to_dict())
        self.ipc_server.register_handler("security.hardening", lambda _p: self.security_service.get_hardening_commands())

        # Storage Guard & CleanGuard endpoints
        self.ipc_server.register_handler("storage.overview", lambda _p: self.storage_service.get_overview().to_dict())
        self.ipc_server.register_handler("storage.clean", lambda p: self.storage_service.clean(p.get("targets")).to_dict())
        self.ipc_server.register_handler(
            "storage.move",
            lambda p: self.storage_service.move_directory_library(p.get("source", ""), p.get("target", "")),
        )

        # Developer CLI Hub endpoints
        self.ipc_server.register_handler("dev.status", lambda _p: self.dev_toolbox_service.get_status().to_dict())
        self.ipc_server.register_handler("dev.install", lambda p: self.dev_toolbox_service.install_tool(p.get("tool", "")))
        self.ipc_server.register_handler("dev.remove", lambda p: self.dev_toolbox_service.remove_tool(p.get("tool", "")))
        self.ipc_server.register_handler("dev.doctor", lambda _p: self.dev_toolbox_service.doctor())

        # System health
        self.ipc_server.register_handler("system.health", lambda _p: self.registry.health_report())

    def start(self) -> None:
        """Start all services, IPC server, and compositor event watcher."""
        if self._running:
            return
        self._running = True

        for service in self.registry.all().values():
            service.start()

        self.ipc_server.start()

        self._event_thread = threading.Thread(
            target=self._hyprland_event_loop,
            name="Hyprland-Socket2-Watcher",
            daemon=True,
        )
        self._event_thread.start()
        logger.info("PolyShellDaemon initialized and running")

    def stop(self) -> None:
        """Gracefully terminate daemon and all child workers."""
        if not self._running:
            return
        self._running = False

        if self._event_thread and self._event_thread.is_alive():
            self._event_thread.join(timeout=2.0)

        self.ipc_server.stop()

        for service in self.registry.all().values():
            service.stop()

        logger.info("PolyShellDaemon stopped")

    def _hyprland_event_loop(self) -> None:
        """Watch Hyprland Socket2 stream with resilient auto-reconnect on reload/crash."""
        backoff = 0.5
        while self._running:
            if not HyprlandAdapter.is_available():
                time.sleep(1.0)
                continue

            try:
                for event_name, event_data in HyprlandAdapter.stream_events(stop_check=lambda: not self._running):
                    if not self._running:
                        break
                    backoff = 0.5  # Reset backoff on successful event stream
                    envelope = ShellEventEnvelope(
                        domain="compositor",
                        event=event_name,
                        data={"raw": event_data},
                    )
                    self.ipc_server.broadcast(envelope)
            except Exception as exc:
                logger.debug("Hyprland event stream disconnected: %s", exc)

            if not self._running:
                break

            time.sleep(backoff)
            backoff = min(backoff * 1.5, 5.0)  # Exponential backoff up to 5s

