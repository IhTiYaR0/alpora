import json
import socket
import tempfile
import time
import unittest
from pathlib import Path

from poly_shell.contracts.base import ShellEventEnvelope, ResponseDTO
from poly_shell.core.ipc_server import IPCServer
from poly_shell.core.daemon import PolyShellDaemon


class TestIPCDaemon(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.sock_path = Path(self.temp_dir.name) / "test_ipc.sock"

    def tearDown(self):
        self.temp_dir.cleanup()

    def _create_connected_client(self, server: IPCServer) -> socket.socket:
        client = socket.socket(
            socket.AF_UNIX if hasattr(socket, "AF_UNIX") and server.socket_path else socket.AF_INET,
            socket.SOCK_STREAM,
        )
        if hasattr(socket, "AF_UNIX") and server.socket_path:
            client.connect(str(server.socket_path))
        else:
            host, port = server.endpoint_address.split(":")
            client.connect((host, int(port)))
        return client

    def test_ipc_server_ping_and_handlers(self):
        server = IPCServer(socket_path=self.sock_path)
        server.register_handler("test.echo", lambda params: {"echo": params.get("val")})
        server.start()
        self.assertTrue(server.is_running)

        try:
            client = self._create_connected_client(server)
            time.sleep(0.1)
            self.assertEqual(server.client_count, 1)

            # Test 1: ping
            ping_req = json.dumps({"id": "p-1", "action": "ping"}) + "\n"
            client.sendall(ping_req.encode("utf-8"))
            resp_line = client.makefile("r").readline()
            resp = json.loads(resp_line)
            self.assertTrue(resp.get("success"))
            self.assertEqual(resp.get("id"), "p-1")
            self.assertTrue(resp.get("data", {}).get("pong"))

            # Test 2: custom handler
            echo_req = json.dumps({"id": "e-2", "action": "test.echo", "params": {"val": 42}}) + "\n"
            client.sendall(echo_req.encode("utf-8"))
            resp_line = client.makefile("r").readline()
            resp = json.loads(resp_line)
            self.assertTrue(resp.get("success"))
            self.assertEqual(resp.get("data", {}).get("echo"), 42)

            # Test 3: unknown action
            bad_req = json.dumps({"id": "b-3", "action": "nonexistent"}) + "\n"
            client.sendall(bad_req.encode("utf-8"))
            resp_line = client.makefile("r").readline()
            resp = json.loads(resp_line)
            self.assertFalse(resp.get("success"))
            self.assertIn("Unknown action", resp.get("error", ""))

            client.close()
        finally:
            server.stop()
            self.assertFalse(server.is_running)

    def test_ipc_server_broadcast(self):
        server = IPCServer(socket_path=self.sock_path)
        server.start()

        try:
            client = self._create_connected_client(server)
            client_file = client.makefile("r")
            time.sleep(0.1)

            envelope = ShellEventEnvelope(
                domain="audio",
                event="volume_changed",
                data={"level": 75},
            )
            count = server.broadcast(envelope)
            self.assertEqual(count, 1)

            line = client_file.readline()
            event = json.loads(line)
            self.assertEqual(event.get("domain"), "audio")
            self.assertEqual(event.get("event"), "volume_changed")
            self.assertEqual(event.get("data", {}).get("level"), 75)

            client.close()
        finally:
            server.stop()

    def test_daemon_initialization_and_routes(self):
        daemon = PolyShellDaemon(socket_path=self.sock_path)
        self.assertFalse(daemon._running)

        daemon.start()
        self.assertTrue(daemon._running)
        self.assertTrue(daemon.ipc_server.is_running)

        try:
            client = self._create_connected_client(daemon.ipc_server)
            # Query system.health via IPC
            req = json.dumps({"id": "h-1", "action": "system.health"}) + "\n"
            client.sendall(req.encode("utf-8"))
            resp_line = client.makefile("r").readline()
            resp = json.loads(resp_line)
            self.assertTrue(resp.get("success"))
            self.assertIn("audio", resp.get("data", {}))
            self.assertIn("network", resp.get("data", {}))
            self.assertIn("power", resp.get("data", {}))

            # Query apps.snapshot via IPC (zero-spawn)
            req = json.dumps({"id": "a-1", "action": "apps.snapshot", "params": {"windows": []}}) + "\n"
            client.sendall(req.encode("utf-8"))
            resp_line = client.makefile("r").readline()
            resp = json.loads(resp_line)
            self.assertTrue(resp.get("success"))
            self.assertIn("processes", resp.get("data", {}))

            client.close()
        finally:
            daemon.stop()
            self.assertFalse(daemon._running)


if __name__ == "__main__":
    unittest.main()

