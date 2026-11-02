"""Persistent Unix Domain Socket IPC server for real-time shell communication."""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path
import select
import socket
import threading
import time
from typing import Any, Callable, Dict, Optional, Set

from ..contracts.base import ShellEventEnvelope, ResponseDTO

logger = logging.getLogger(__name__)


class IPCServer:
    """Non-blocking, multithreaded IPC server supporting request/response and push events."""

    def __init__(self, socket_path: Optional[Path] = None):
        self.socket_path = socket_path
        self._server_socket: Optional[socket.socket] = None
        self._clients: Set[socket.socket] = set()
        self._clients_lock = threading.Lock()
        self._handlers: Dict[str, Callable[[Dict[str, Any]], Any]] = {}
        self._running = False
        self._thread: Optional[threading.Thread] = None
        self._port: Optional[int] = None  # Used when falling back to AF_INET on Windows

    @property
    def is_running(self) -> bool:
        return self._running

    @property
    def client_count(self) -> int:
        with self._clients_lock:
            return len(self._clients)

    @property
    def endpoint_address(self) -> str:
        """Return socket path or TCP endpoint for client connection."""
        if self._port is not None:
            return f"127.0.0.1:{self._port}"
        if self.socket_path:
            return str(self.socket_path)
        return ""

    def register_handler(self, action: str, handler: Callable[[Dict[str, Any]], Any]) -> None:
        """Register an RPC action handler."""
        self._handlers[action] = handler

    def start(self) -> None:
        """Start listening on socket and run accept loop in worker thread."""
        if self._running:
            return

        if hasattr(socket, "AF_UNIX") and self.socket_path is not None:
            if self.socket_path.exists():
                try:
                    self.socket_path.unlink()
                except OSError as exc:
                    logger.warning("Failed to remove stale socket %s: %exc", self.socket_path, exc)

            self.socket_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            self._server_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self._server_socket.bind(str(self.socket_path))
            try:
                os.chmod(str(self.socket_path), 0o600)
            except OSError:
                pass
        else:
            # Fallback to local TCP loopback (for test environments without AF_UNIX)
            self._server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self._server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self._server_socket.bind(("127.0.0.1", 0))
            self._port = self._server_socket.getsockname()[1]

        self._server_socket.settimeout(2.0)
        self._server_socket.listen(10)
        self._running = True

        self._thread = threading.Thread(target=self._accept_loop, name="IPCServer-Accept", daemon=True)
        self._thread.start()
        logger.info("IPCServer listening on %s", self.endpoint_address)

    def stop(self) -> None:
        """Stop server and disconnect all clients."""
        if not self._running:
            return

        self._running = False
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2.0)

        with self._clients_lock:
            for client in list(self._clients):
                try:
                    client.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
                try:
                    client.close()
                except OSError:
                    pass
            self._clients.clear()

        if self._server_socket:
            try:
                self._server_socket.close()
            except OSError:
                pass
            self._server_socket = None

        if self.socket_path and self.socket_path.exists():
            try:
                self.socket_path.unlink()
            except OSError:
                pass

        logger.info("IPCServer stopped")

    def broadcast(self, envelope: ShellEventEnvelope) -> int:
        """Broadcast a push event to all connected clients. Return number of recipients."""
        payload = (envelope.to_json() + "\n").encode("utf-8")
        disconnections = []

        with self._clients_lock:
            active_clients = list(self._clients)

        sent_count = 0
        for client in active_clients:
            try:
                client.sendall(payload)
                sent_count += 1
            except (BrokenPipeError, ConnectionResetError, OSError):
                disconnections.append(client)

        if disconnections:
            with self._clients_lock:
                for dead_sock in disconnections:
                    self._clients.discard(dead_sock)
                    try:
                        dead_sock.close()
                    except OSError:
                        pass

        return sent_count

    def _accept_loop(self) -> None:
        while self._running and self._server_socket:
            try:
                client_sock, _ = self._server_socket.accept()
                client_sock.settimeout(None)
                with self._clients_lock:
                    self._clients.add(client_sock)
                worker = threading.Thread(
                    target=self._handle_client,
                    args=(client_sock,),
                    name=f"IPCClient-{id(client_sock)}",
                    daemon=True,
                )
                worker.start()
            except socket.timeout:
                continue
            except OSError:
                if not self._running:
                    break
                logger.debug("Socket accept failed while running")

    def _handle_client(self, client_sock: socket.socket) -> None:
        buffer = ""
        try:
            while self._running:
                data = client_sock.recv(4096)
                if not data:
                    break
                buffer += data.decode("utf-8", errors="replace")
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if not line:
                        continue
                    response = self._process_request(line)
                    if response is not None:
                        client_sock.sendall((json.dumps(response) + "\n").encode("utf-8"))
        except (ConnectionResetError, BrokenPipeError, OSError):
            pass
        finally:
            with self._clients_lock:
                self._clients.discard(client_sock)
            try:
                client_sock.close()
            except OSError:
                pass

    def _process_request(self, raw_line: str) -> Optional[Dict[str, Any]]:
        req_id = None
        try:
            req = json.loads(raw_line)
            if not isinstance(req, dict):
                return ResponseDTO(success=False, error="Invalid JSON request format").to_dict()

            req_id = req.get("id")
            action = req.get("action", "")
            params = req.get("params", {})

            if not action:
                resp = ResponseDTO(id=req_id, success=False, error="Missing action field")
                return resp.to_dict()

            if action == "ping":
                return ResponseDTO(id=req_id, success=True, data={"pong": True, "time": time.time()}).to_dict()

            handler = self._handlers.get(action)
            if handler is None:
                return ResponseDTO(id=req_id, success=False, error=f"Unknown action: '{action}'").to_dict()

            result = handler(params if isinstance(params, dict) else {})
            return ResponseDTO(id=req_id, success=True, data=result).to_dict()

        except Exception as exc:
            logger.exception("Error processing IPC request: %s", raw_line)
            return ResponseDTO(id=req_id, success=False, error=str(exc)).to_dict()
