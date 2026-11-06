"""Network domain service managing Wi-Fi, Ethernet, and Radio state."""
import logging
from ..core.service import BaseService
from ..adapters.network import NetworkAdapter
from ..contracts.hardware import NetworkStateDTO

logger = logging.getLogger(__name__)


class NetworkService(BaseService):
    """Encapsulates system network connectivity and radio devices."""

    def __init__(self):
        super().__init__("network")
        self._adapter = NetworkAdapter

    def health_check(self) -> bool:
        return self._adapter.is_nm_available() or self._adapter.is_rfkill_available()

    def get_state(self) -> NetworkStateDTO:
        radio = self._adapter.get_radio_status()
        return NetworkStateDTO(
            connectivity="full" if radio.get("wifi") else "none",
            wifi_enabled=radio.get("wifi", False),
            wifi_connected=radio.get("wifi", False),
        )

    def set_wifi(self, enabled: bool) -> bool:
        return self._adapter.set_wifi_enabled(enabled)

    def set_airplane(self, enabled: bool) -> bool:
        return self._adapter.block_rfkill("all", enabled)

