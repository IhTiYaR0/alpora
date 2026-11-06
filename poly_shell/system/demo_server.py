"""ALPORA Demo & Design Lab Micro-Server.
Lightweight, dependency-free local HTTP server serving the interactive web lab,
live system telemetry API, and IPC bridges for theme/mode switching.
"""
from __future__ import annotations

import http.server
import json
import os
from pathlib import Path
import platform
import socket
import socketserver
import sys
import threading
import time
import urllib.parse
import webbrowser
from typing import Any

from ..core.state import ROOT, Paths, read_object, update_session


def get_system_telemetry(paths: Paths) -> dict[str, Any]:
    """Gathers real system metrics and session state for the demo client."""
    session_data = {}
    if paths.session.is_file():
        try:
            session_data = read_object(paths.session)
        except Exception:
            pass

    # Read CPU load
    cpu_percent = 32
    try:
        if hasattr(os, "getloadavg"):
            load = os.getloadavg()[0]
            cpu_percent = min(100, max(5, int((load / (os.cpu_count() or 1)) * 100)))
    except Exception:
        pass

    # Read memory info from /proc/meminfo if on Linux
    ram_used_gb = 4.2
    ram_total_gb = 16.0
    meminfo_path = Path("/proc/meminfo")
    if meminfo_path.is_file():
        try:
            lines = meminfo_path.read_text(encoding="utf-8").splitlines()
            mem = {}
            for line in lines:
                parts = line.split(":")
                if len(parts) == 2:
                    mem[parts[0].strip()] = int(parts[1].split()[0])
            total_kb = mem.get("MemTotal", 16777216)
            avail_kb = mem.get("MemAvailable", total_kb // 2)
            ram_total_gb = round(total_kb / 1048576, 1)
            ram_used_gb = round((total_kb - avail_kb) / 1048576, 1)
        except Exception:
            pass

    # Read battery info if present
    battery_percent = 98
    battery_charging = False
    power_supply = Path("/sys/class/power_supply")
    if power_supply.is_dir():
        for bat in power_supply.glob("BAT*"):
            cap_file = bat / "capacity"
            status_file = bat / "status"
            if cap_file.is_file():
                try:
                    battery_percent = int(cap_file.read_text().strip())
                except Exception:
                    pass
            if status_file.is_file():
                try:
                    battery_charging = status_file.read_text().strip().lower() == "charging"
                except Exception:
                    pass
            break

    # Resolve active theme & mode
    current_mode = session_data.get("mode", "work")
    current_theme = session_data.get("appearance", {}).get("id", "alpine")

    return {
        "online": True,
        "platform": {
            "system": platform.system(),
            "node": platform.node(),
            "release": platform.release(),
        },
        "session": {
            "mode": current_mode,
            "theme": current_theme,
            "reducedMotion": session_data.get("settings", {}).get("reducedMotion", False),
        },
        "metrics": {
            "cpuPercent": cpu_percent,
            "ramUsedGb": ram_used_gb,
            "ramTotalGb": ram_total_gb,
            "batteryPercent": battery_percent,
            "batteryCharging": battery_charging,
        },
        "timestamp": time.time(),
    }


def get_available_themes() -> list[dict[str, Any]]:
    """Reads available themes and swatches from assets/themes/*.json."""
    themes_dir = ROOT / "assets" / "themes"
    results = []
    if not themes_dir.is_dir():
        return results

    for theme_file in sorted(themes_dir.glob("*.json")):
        try:
            data = read_object(theme_file)
            results.append({
                "id": data.get("id", theme_file.stem),
                "label": data.get("label", theme_file.stem.capitalize()),
                "wallpaper": data.get("wallpaper", ""),
                "palette": data.get("palette") or data.get("themePalette") or {},
                "swatches": data.get("swatches", []),
            })
        except Exception:
            continue
    return results


class DemoRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Serves the ALPORA demo static assets and REST endpoints."""

    def __init__(self, *args, paths: Paths | None = None, **kwargs):
        self.paths = paths or Paths.current()
        # Serve from repository root so assets and shell/demos are accessible
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)

        # Redirect root to shell/demos/web/index.html
        if parsed.path in ("/", "/index.html", "/demo", "/demo/"):
            self.send_response(302)
            self.send_header("Location", "/shell/demos/web/index.html")
            self.end_headers()
            return

        # REST API: /api/state
        if parsed.path == "/api/state":
            telemetry = get_system_telemetry(self.paths)
            self._send_json(telemetry)
            return

        # REST API: /api/themes
        if parsed.path == "/api/themes":
            themes = get_available_themes()
            self._send_json(themes)
            return

        super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)

        if parsed.path == "/api/action":
            content_len = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body.decode("utf-8"))
            except ValueError:
                self._send_json({"error": "Invalid JSON"}, status=400)
                return

            action = payload.get("action")
            value = payload.get("value")

            if action == "mode" and value in ("work", "vibe"):
                try:
                    update_session(self.paths, value)
                    self._send_json({"ok": True, "mode": value})
                except Exception as exc:
                    self._send_json({"error": str(exc)}, status=500)
                return

            self._send_json({"ok": True, "action": action, "value": value})
            return

        self._send_json({"error": "Not found"}, status=404)

    def _send_json(self, data: Any, status: int = 200) -> None:
        raw = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.end_headers()
        self.wfile.write(raw)

    def log_message(self, format: str, *args: Any) -> None:
        """Suppress noisy static asset log lines, print only API calls."""
        if any(prefix in args[0] for prefix in ("GET /api/", "POST /api/")):
            sys.stderr.write(f"[ALPORA Demo Server] {args[0]} -> {args[1]}\n")


class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True


def _safe_print(text: str) -> None:
    try:
        print(text)
    except (UnicodeEncodeError, OSError):
        try:
            sys.stdout.buffer.write((text + "\n").encode("utf-8", errors="replace"))
            sys.stdout.buffer.flush()
        except Exception:
            pass


def find_free_port(start_port: int = 8080) -> int:
    """Finds an open TCP port starting from start_port."""
    for port in range(start_port, start_port + 20):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            if sock.connect_ex(("127.0.0.1", port)) != 0:
                return port
    return start_port


def start_demo_server(
    paths: Paths | None = None,
    port: int = 8080,
    open_browser: bool = True,
    blocking: bool = True,
) -> tuple[ThreadedTCPServer, int]:
    """Starts the ALPORA demo HTTP server.
    
    Returns (server_instance, bound_port).
    """
    paths = paths or Paths.current()
    actual_port = find_free_port(port)

    def handler_factory(*args, **kwargs):
        return DemoRequestHandler(*args, paths=paths, **kwargs)

    server = ThreadedTCPServer(("127.0.0.1", actual_port), handler_factory)
    url = f"http://127.0.0.1:{actual_port}/shell/demos/web/index.html"  # NOSONAR - local loopback only

    _safe_print("=" * 68)
    _safe_print("      ALPORA Interactive Design Lab & Shell Simulator Server        ")
    _safe_print("=" * 68)
    _safe_print(f"  * URL:            {url}")
    _safe_print(f"  * Live Telemetry: http://127.0.0.1:{actual_port}/api/state")  # NOSONAR
    _safe_print(f"  * Serving from:   {ROOT}")
    _safe_print("  * Press Ctrl+C to stop the server.")
    _safe_print("=" * 68)

    if open_browser:
        threading.Timer(0.4, lambda: webbrowser.open(url)).start()

    if blocking:
        try:
            server.serve_forever()  # NOSONAR - local development simulation server
        except KeyboardInterrupt:
            print("\n[ALPORA Demo Server] Stopping server...")
        finally:
            server.shutdown()
            server.server_close()

    return server, actual_port
