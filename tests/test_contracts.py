import json
import unittest

from poly_shell.contracts import (
    BaseDTO,
    ShellEventEnvelope,
    ResponseDTO,
    AudioDeviceDTO,
    AudioStateDTO,
    NetworkStateDTO,
    PowerStateDTO,
    DisplayStateDTO,
    WorkspaceDTO,
    WindowDTO,
    WellbeingSummaryDTO,
    AppUsageDTO,
)


class TestContracts(unittest.TestCase):
    def test_base_dto_serialization_and_deserialization(self):
        envelope = ShellEventEnvelope(
            domain="audio",
            event="volume_changed",
            data={"volume": 0.75, "muted": False},
        )
        as_dict = envelope.to_dict()
        self.assertEqual(as_dict["domain"], "audio")
        self.assertEqual(as_dict["event"], "volume_changed")
        self.assertEqual(as_dict["data"]["volume"], 0.75)

        raw_json = envelope.to_json()
        parsed = json.loads(raw_json)
        self.assertEqual(parsed["domain"], "audio")

    def test_from_dict_forward_compatibility(self):
        # Even if a future QML/backend adds extra fields, from_dict must not raise TypeError
        raw_data = {
            "id": "sink-1",
            "name": "Headphones",
            "volume": 0.85,
            "muted": False,
            "future_unsupported_field": "test_value",
        }
        device = AudioDeviceDTO.from_dict(raw_data)
        self.assertEqual(device.name, "Headphones")
        self.assertEqual(device.volume, 0.85)
        self.assertFalse(hasattr(device, "future_unsupported_field"))

    def test_response_dto_success_and_error(self):
        resp_ok = ResponseDTO(success=True, data={"token": "abc"})
        self.assertTrue(resp_ok.success)
        self.assertIsNone(resp_ok.error)

        resp_err = ResponseDTO(success=False, error="Device offline", code=404)
        self.assertFalse(resp_err.success)
        self.assertEqual(resp_err.error, "Device offline")
        self.assertEqual(resp_err.code, 404)

    def test_hardware_dtos_structure(self):
        net = NetworkStateDTO(
            connectivity="full",
            wifi_enabled=True,
            wifi_connected=True,
            wifi_name="HomeNetwork",
            wifi_strength=92,
        )
        self.assertEqual(net.wifi_strength, 92)
        self.assertTrue(net.wifi_connected)

        power = PowerStateDTO(caffeine=True, profile="performance")
        self.assertTrue(power.caffeine)
        self.assertEqual(power.profile, "performance")

        disp = DisplayStateDTO(brightness=80, night_light=True)
        self.assertEqual(disp.brightness, 80)
        self.assertTrue(disp.night_light)

    def test_compositor_and_wellbeing_dtos(self):
        ws = WorkspaceDTO(id=1, name="1", active=True, urgent=False)
        self.assertEqual(ws.id, 1)
        self.assertTrue(ws.active)

        win = WindowDTO(
            address="0x12345",
            title="Terminal",
            class_name="kitty",
            workspace_id=1,
            at=(10, 10),
            size=(800, 600),
            focused=True,
        )
        self.assertEqual(win.class_name, "kitty")
        self.assertTrue(win.focused)

        report = WellbeingSummaryDTO(
            date="2026-10-29",
            total_seconds=3600,
            total_minutes=60.0,
            apps=[AppUsageDTO(name="kitty", seconds=3600, minutes=60.0)],
        )
        self.assertEqual(report.total_minutes, 60.0)
        self.assertEqual(len(report.apps), 1)


if __name__ == "__main__":
    unittest.main()

