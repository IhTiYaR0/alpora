"""Windows filesystem and drive integration for Alpora.

Provides discovery and unprivileged mounting/unmounting of Windows partitions
(NTFS, FAT32, exFAT) and Windows path normalization.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

from ..core.state import ConfigError

SUPPORTED_FSTYPES = {"ntfs", "vfat", "fat32", "fat16", "exfat", "msdos"}


def normalize_windows_path(path: str) -> str:
    """Convert a Windows-formatted path to standard POSIX path."""
    if not isinstance(path, str):
        return ""
    cleaned = path.strip().replace('"', '')
    # Handle drive letter e.g. C:\Users or D:/Data
    drive_match = re.match(r"^([a-zA-Z]):[\\/](.*)$", cleaned)
    if drive_match:
        letter, rest = drive_match.group(1).lower(), drive_match.group(2).replace("\\", "/")
        # Common Linux mount points for Windows partitions: /run/media/$USER/<Label> or /mnt/<drive>
        user = os.environ.get("USER", "")
        media_root = Path(f"/run/media/{user}") if user else Path("/run/media")
        mnt_candidate = Path(f"/mnt/{letter}")
        if mnt_candidate.is_dir():
            return str(mnt_candidate / rest)
        if media_root.is_dir():
            for child in media_root.iterdir():
                if child.is_dir() and (child.name.lower() == letter or child.name.lower().startswith(f"windows-{letter}")):
                    return str(child / rest)
        return f"/mnt/{letter}/{rest}"
    # Relative or unrooted path with backslashes
    return cleaned.replace("\\", "/")


def detect_windows_drives(mock_json: str = None) -> list:
    """Detect all attached Windows-compatible storage partitions (NTFS, FAT, exFAT)."""
    if mock_json is not None:
        raw = mock_json
    else:
        if not shutil.which("lsblk"):
            return []
        try:
            res = subprocess.run(
                ["lsblk", "-J", "-o", "NAME,FSTYPE,LABEL,MOUNTPOINT,SIZE,UUID"],
                capture_output=True, text=True, timeout=5, check=True
            )
            raw = res.stdout
        except (subprocess.SubprocessError, OSError):
            return []

    try:
        data = json.loads(raw)
    except (ValueError, TypeError):
        return []

    devices = []

    def _traverse(node):
        fstype = (node.get("fstype") or "").lower()
        if fstype in SUPPORTED_FSTYPES:
            name = node.get("name", "")
            devices.append({
                "device": f"/dev/{name}" if not name.startswith("/dev/") else name,
                "name": name,
                "fstype": fstype,
                "label": node.get("label") or name,
                "mountpoint": node.get("mountpoint") or "",
                "size": node.get("size") or "",
                "uuid": node.get("uuid") or "",
                "mounted": bool(node.get("mountpoint")),
            })
        for child in node.get("children", []):
            _traverse(child)

    for dev in data.get("blockdevices", []):
        _traverse(dev)

    return devices


def mount_drive(device: str) -> str:
    """Mount a Windows partition via udisksctl (no sudo needed). Returns mount point."""
    if not isinstance(device, str) or not re.match(r"^/dev/[a-zA-Z0-9_\-]+$", device):
        raise ConfigError(f"Invalid device path: {device}")
    if not shutil.which("udisksctl"):
        raise ConfigError("udisksctl is not installed. Please install udisks2 package.")

    try:
        res = subprocess.run(
            ["udisksctl", "mount", "-b", device, "--no-user-interaction"],
            capture_output=True, text=True, timeout=10
        )
        if res.returncode != 0:
            err = res.stderr.strip() or res.stdout.strip()
            raise ConfigError(f"Failed to mount {device}: {err}")
        # Parse output e.g. "Mounted /dev/sdb1 at /run/media/user/Data."
        match = re.search(r"Mounted\s+\S+\s+at\s+(\S+)", res.stdout)
        return match.group(1).rstrip(".") if match else "mounted"
    except (subprocess.SubprocessError, OSError) as exc:
        raise ConfigError(f"Error mounting {device}: {exc}") from exc


def unmount_drive(device: str) -> bool:
    """Unmount a Windows partition via udisksctl (no sudo needed)."""
    if not isinstance(device, str) or not re.match(r"^/dev/[a-zA-Z0-9_\-]+$", device):
        raise ConfigError(f"Invalid device path: {device}")
    if not shutil.which("udisksctl"):
        raise ConfigError("udisksctl is not installed. Please install udisks2 package.")

    try:
        res = subprocess.run(
            ["udisksctl", "unmount", "-b", device, "--no-user-interaction"],
            capture_output=True, text=True, timeout=10
        )
        if res.returncode != 0:
            err = res.stderr.strip() or res.stdout.strip()
            raise ConfigError(f"Failed to unmount {device}: {err}")
        return True
    except (subprocess.SubprocessError, OSError) as exc:
        raise ConfigError(f"Error unmounting {device}: {exc}") from exc
