from dataclasses import dataclass
import tempfile
import unittest
from poly_shell.core.service import BaseService, ServiceRegistry
from poly_shell.contracts.base import BaseDTO
from poly_shell.services import MetricsService, ClipboardService


@dataclass
class MockDTO(BaseDTO):
    active: bool = True


class MockService(BaseService):
    def health_check(self) -> bool:
        return True

    def get_state(self) -> MockDTO:
        return MockDTO(active=self.is_running)


class TestServiceCore(unittest.TestCase):
    def setUp(self):
        self.registry = ServiceRegistry()

    def test_service_lifecycle_and_registry(self):
        svc = MockService("mock")
        self.assertFalse(svc.is_running)

        svc.start()
        self.assertTrue(svc.is_running)

        self.registry.register(svc)
        retrieved = self.registry.get("mock")
        self.assertIsNotNone(retrieved)
        self.assertEqual(retrieved.name, "mock")

        report = self.registry.health_report()
        self.assertTrue(report.get("mock"))

        state = retrieved.get_state()
        self.assertTrue(state.active)

        self.registry.shutdown_all()
        self.assertEqual(len(self.registry.all()), 0)

    def test_metrics_service(self):
        svc = MetricsService()
        self.assertEqual(svc.name, "metrics")
        self.assertTrue(svc.health_check())
        snap = svc.get_snapshot()
        self.assertIn("cpu", snap)
        self.assertIn("memory", snap)
        dto = svc.get_state()
        self.assertIsNotNone(dto.hostname)
        self.assertIn("percent", dto.cpu)

    def test_clipboard_service(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            from pathlib import Path
            svc = ClipboardService(storage_dir=Path(tmp_dir))
            try:
                self.assertEqual(svc.name, "clipboard")
                self.assertTrue(svc.health_check())
                state = svc.get_state()
                self.assertEqual(state.item_count, 0)
                self.assertFalse(state.paused)
                # 'pause' toggles paused state
                svc.perform_action("pause")
                self.assertTrue(svc.get_state().paused)
                svc.perform_action("pause")
                self.assertFalse(svc.get_state().paused)
            finally:
                svc.stop()


if __name__ == "__main__":
    unittest.main()
