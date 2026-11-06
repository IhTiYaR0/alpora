"""Audio domain service managing WirePlumber/PipeWire endpoints and MPRIS."""
import logging
from ..core.service import BaseService
from ..adapters.audio import AudioAdapter
from ..contracts.hardware import AudioStateDTO, AudioDeviceDTO

logger = logging.getLogger(__name__)


class AudioService(BaseService):
    """Encapsulates system audio controls and volume queries."""

    def __init__(self):
        super().__init__("audio")
        self._adapter = AudioAdapter

    def health_check(self) -> bool:
        return self._adapter.is_available()

    def get_state(self) -> AudioStateDTO:
        available = self.health_check()
        volume = self._adapter.get_volume() if available else 0.0
        return AudioStateDTO(
            available=available,
            volume=volume,
            muted=False,
            output_device=AudioDeviceDTO(
                id="@DEFAULT_AUDIO_SINK@",
                name="Default Output",
                volume=volume,
                is_default=True,
                is_sink=True,
            ) if available else None,
        )

    def set_volume(self, percent: int) -> bool:
        return self._adapter.set_volume(percent)

    def toggle_mute(self) -> bool:
        return self._adapter.toggle_mute()

    def player_control(self, action: str) -> bool:
        return self._adapter.player_control(action)

