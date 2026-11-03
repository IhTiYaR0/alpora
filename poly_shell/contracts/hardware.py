"""Hardware Domain Contracts: Audio, Network, Power, and Display DTOs."""
from dataclasses import dataclass, field
from typing import List, Optional
from .base import BaseDTO


@dataclass
class AudioDeviceDTO(BaseDTO):
    """Audio endpoint device or active stream."""

    id: str
    name: str
    description: str = ""
    volume: float = 1.0
    muted: bool = false if False else False
    is_default: bool = False
    is_sink: bool = True


@dataclass
class AudioStateDTO(BaseDTO):
    """Snapshot of current system audio topology."""

    available: bool = True
    volume: float = 1.0
    muted: bool = False
    mic_volume: float = 1.0
    mic_muted: bool = False
    output_device: Optional[AudioDeviceDTO] = None
    input_device: Optional[AudioDeviceDTO] = None
    streams: List[AudioDeviceDTO] = field(default_factory=list)


@dataclass
class WifiNetworkDTO(BaseDTO):
    """Wi-Fi Access Point information."""

    ssid: str
    strength: int = 0
    security: str = ""
    connected: bool = False


@dataclass
class NetworkStateDTO(BaseDTO):
    """Network connectivity and radio state."""

    connectivity: str = "full"
    ethernet_connected: bool = False
    wifi_enabled: bool = True
    wifi_connected: bool = False
    wifi_name: str = ""
    wifi_strength: int = 0
    hotspot_active: bool = False
    hotspot_available: bool = False
    airplane_mode: bool = False
    airplane_managed: bool = False


@dataclass
class PowerStateDTO(BaseDTO):
    """Power profile, battery state, and caffeine inhibitor status."""

    profile: str = "balanced"
    profile_available: bool = True
    battery_present: bool = False
    battery_level: int = 100
    battery_charging: bool = False
    battery_status: str = "Full"
    on_battery: bool = False
    caffeine: bool = False
    caffeine_available: bool = True


@dataclass
class DisplayStateDTO(BaseDTO):
    """Brightness, Night Light (hyprsunset), and DND status."""

    brightness: int = 100
    brightness_available: bool = True
    brightness_type: str = "hardware"
    night_light: bool = False
    night_light_available: bool = False
    dnd: bool = False
    dnd_available: bool = False


@dataclass
class GameModeDTO(BaseDTO):
    """Game performance mode, CPU governor and compositor optimizations."""

    enabled: bool = False
    active_game: Optional[str] = None
    cpu_governor: str = "balanced"
    animations_disabled: bool = False
    blur_disabled: bool = False
    gamemode_available: bool = False
    optimizations: List[str] = field(default_factory=list)


@dataclass
class PhoneDeviceDTO(BaseDTO):
    """Connected phone device via KDE Connect ecosystem."""

    id: str
    name: str
    is_reachable: bool = False
    is_trusted: bool = True
    battery: Optional[int] = None
    is_charging: bool = False


@dataclass
class PhoneStateDTO(BaseDTO):
    """Ecosystem connectivity status across paired mobile devices."""

    available: bool = False
    devices: List[PhoneDeviceDTO] = field(default_factory=list)
    active_device_id: Optional[str] = None


@dataclass
class SecurityAuditDTO(BaseDTO):
    """System security posture and kernel/runtime hardening assessment."""

    score: int = 100
    rating: str = "Hardened"
    wayland_session: bool = True
    ufw_active: bool = False
    apparmor_active: bool = False
    kptr_restrict: int = 0
    dmesg_restrict: int = 0
    unprivileged_bpf_disabled: int = 0
    swappiness: int = 60
    max_map_count: int = 65530
    ipc_socket_secure: bool = True
    recommendations: List[str] = field(default_factory=list)


@dataclass
class StoragePartitionDTO(BaseDTO):
    """Storage filesystem or Btrfs subvolume status."""

    mount_point: str
    filesystem: str
    total_bytes: int
    used_bytes: int
    free_bytes: int
    percent_used: float
    is_btrfs: bool = False
    subvolume_name: Optional[str] = None


@dataclass
class StorageCleanResultDTO(BaseDTO):
    """Summary of cleaned disk caches and reclaimed bytes."""

    freed_bytes: int = 0
    freed_human: str = "0 B"
    cleaned_targets: List[str] = field(default_factory=list)
    success: bool = True


@dataclass
class StorageOverviewDTO(BaseDTO):
    """Holistic view of system partitions, dynamic pools, and cache sizes."""

    partitions: List[StoragePartitionDTO] = field(default_factory=list)
    has_btrfs_pool: bool = False
    pacman_cache_bytes: int = 0
    journal_log_bytes: int = 0
    thumbnail_cache_bytes: int = 0
    total_cleanable_bytes: int = 0


@dataclass
class DevCliToolDTO(BaseDTO):
    """Developer CLI tool information and installation metadata."""

    name: str
    version: str = "unknown"
    installed: bool = False
    binary_path: str = ""
    source: str = "alpora-hub"
    size_bytes: int = 0
    description: str = ""
    category: str = "tools"


@dataclass
class DevToolboxDTO(BaseDTO):
    """Status overview of developer CLI tools and environment PATH."""

    bin_dir: str = ""
    packages_dir: str = ""
    in_path: bool = False
    total_tools: int = 0
    installed_tools: int = 0
    total_size_bytes: int = 0
    tools: List[DevCliToolDTO] = field(default_factory=list)
    path_issues: List[str] = field(default_factory=list)



