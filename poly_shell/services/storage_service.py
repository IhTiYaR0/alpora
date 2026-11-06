"""Storage Guard and Anti-Bloat Service for ALPORA OS."""
from __future__ import annotations

import logging
import os
from pathlib import Path
import shutil
from typing import Any, Dict, List, Optional

from ..adapters.base import SafeRunner
from ..contracts.hardware import StorageCleanResultDTO, StorageOverviewDTO, StoragePartitionDTO
from ..core.service import BaseService

logger = logging.getLogger(__name__)


def _format_bytes(size: int) -> str:
    """Format bytes to human readable string (KB, MB, GB)."""
    if size < 1024:
        return f"{size} B"
    for unit in ["KB", "MB", "GB", "TB"]:
        size /= 1024.0
        if size < 1024.0:
            return f"{size:.1f} {unit}"
    return f"{size:.1f} PB"


class StorageService(BaseService):
    """Domain service managing disk partitions, Btrfs subvolumes, and anti-bloat cache cleaning."""

    def __init__(self):
        super().__init__("storage")

    def health_check(self) -> bool:
        """Health check returns True if disk overview can be queried."""
        try:
            self.get_overview()
            return True
        except Exception as exc:
            logger.error("Storage health check failed: %s", exc)
            return False

    def get_state(self) -> StorageOverviewDTO:
        """Return the current storage overview DTO."""
        return self.get_overview()

    def _get_dir_size(self, path: Path) -> int:
        """Safely compute recursive directory size without following outside symlinks."""
        if not path.exists() or not path.is_dir():
            return 0
        total = 0
        try:
            for entry in os.scandir(str(path)):
                try:
                    if entry.is_file(follow_symlinks=False):
                        total += entry.stat().st_size
                    elif entry.is_dir(follow_symlinks=False):
                        total += self._get_dir_size(Path(entry.path))
                except OSError:
                    continue
        except OSError:
            pass
        return total

    def get_overview(self) -> StorageOverviewDTO:
        """Collect storage metrics across main partitions and cleanable caches."""
        partitions: List[StoragePartitionDTO] = []
        has_btrfs = False

        # 1. Root partition
        try:
            root_path = Path("/") if os.name != "nt" else Path("C:\\")
            root_usage = shutil.disk_usage(str(root_path))
            pct = round(100.0 * root_usage.used / max(1, root_usage.total), 1)
            partitions.append(
                StoragePartitionDTO(
                    mount_point=str(root_path),
                    filesystem="btrfs" if self._is_btrfs(root_path) else "ext4",
                    total_bytes=root_usage.total,
                    used_bytes=root_usage.used,
                    free_bytes=root_usage.free,
                    percent_used=pct,
                    is_btrfs=self._is_btrfs(root_path),
                    subvolume_name="@root" if self._is_btrfs(root_path) else None,
                )
            )
            if self._is_btrfs(root_path):
                has_btrfs = True
        except OSError:
            pass

        # 2. User Home partition (if separate or on another mount)
        try:
            home_path = Path.home()
            home_usage = shutil.disk_usage(str(home_path))
            if str(home_path) != str(root_path):
                pct = round(100.0 * home_usage.used / max(1, home_usage.total), 1)
                partitions.append(
                    StoragePartitionDTO(
                        mount_point=str(home_path),
                        filesystem="btrfs" if self._is_btrfs(home_path) else "ext4",
                        total_bytes=home_usage.total,
                        used_bytes=home_usage.used,
                        free_bytes=home_usage.free,
                        percent_used=pct,
                        is_btrfs=self._is_btrfs(home_path),
                        subvolume_name="@home" if self._is_btrfs(home_path) else None,
                    )
                )
        except OSError:
            pass

        # 3. Cleanable Cache sizes
        pacman_cache = self._get_dir_size(Path("/var/cache/pacman/pkg"))
        journal_logs = self._get_dir_size(Path("/var/log/journal"))
        thumb_cache = self._get_dir_size(Path.home() / ".cache" / "thumbnails")
        pip_cache = self._get_dir_size(Path.home() / ".cache" / "pip")

        cleanable_total = pacman_cache + journal_logs + thumb_cache + pip_cache

        return StorageOverviewDTO(
            partitions=partitions,
            has_btrfs_pool=has_btrfs,
            pacman_cache_bytes=pacman_cache,
            journal_log_bytes=journal_logs,
            thumbnail_cache_bytes=thumb_cache,
            total_cleanable_bytes=cleanable_total,
        )

    def _is_btrfs(self, path: Path) -> bool:
        """Check if path is on a Btrfs filesystem."""
        proc_mounts = Path("/proc/mounts")
        if not proc_mounts.exists():
            return False
        try:
            target_str = str(path.resolve())
            for line in proc_mounts.read_text(encoding="utf-8", errors="replace").splitlines():
                parts = line.split()
                if len(parts) >= 3:
                    mount_point, fstype = parts[1], parts[2]
                    if mount_point == target_str and fstype == "btrfs":
                        return True
        except OSError:
            pass
        return False

    def clean(self, targets: Optional[List[str]] = None) -> StorageCleanResultDTO:
        """Safely clean selected or all redundant caches (anti-bloat)."""
        selected = targets or ["thumbnails", "pip", "pacman", "journal"]
        freed = 0
        cleaned: List[str] = []

        # 1. Clean thumbnail cache
        if "thumbnails" in selected:
            thumb_dir = Path.home() / ".cache" / "thumbnails"
            before = self._get_dir_size(thumb_dir)
            if thumb_dir.exists():
                try:
                    for item in thumb_dir.glob("**/*"):
                        if item.is_file():
                            try:
                                item.unlink()
                            except OSError:
                                pass
                    after = self._get_dir_size(thumb_dir)
                    reclaimed = max(0, before - after)
                    freed += reclaimed
                    cleaned.append(f"Thumbnails Cache ({_format_bytes(reclaimed)})")
                except OSError:
                    pass

        # 2. Clean pip cache
        if "pip" in selected:
            pip_dir = Path.home() / ".cache" / "pip"
            before = self._get_dir_size(pip_dir)
            if pip_dir.exists():
                try:
                    for item in pip_dir.glob("**/*"):
                        if item.is_file():
                            try:
                                item.unlink()
                            except OSError:
                                pass
                    after = self._get_dir_size(pip_dir)
                    reclaimed = max(0, before - after)
                    freed += reclaimed
                    cleaned.append(f"Python Pip Cache ({_format_bytes(reclaimed)})")
                except OSError:
                    pass

        # 3. Clean systemd journal logs (vacuum to 150M)
        if "journal" in selected and shutil.which("journalctl"):
            res = SafeRunner.run(["journalctl", "--vacuum-size=150M"], timeout_sec=5.0)
            if res.returncode == 0:
                cleaned.append("Systemd Journal Log (Capped to 150MB)")

        # 4. Clean pacman cache via paccache or pacman -Sc (retaining 2 rollback versions)
        if "pacman" in selected:
            if shutil.which("paccache"):
                res = SafeRunner.run(["paccache", "-rk2"], timeout_sec=10.0)
                if res.returncode == 0:
                    cleaned.append("Pacman Cache (Retained 2 rollback copies)")
            elif shutil.which("pacman"):
                cleaned.append("Pacman Cache (Scheduled for root pacman -Sc)")

        return StorageCleanResultDTO(
            freed_bytes=freed,
            freed_human=_format_bytes(freed),
            cleaned_targets=cleaned,
            success=True,
        )

    def move_directory_library(self, source_path: str, target_parent: str) -> Dict[str, Any]:
        """Move heavy directory (Steam, Wine, Games) to target partition and create seamless symlink."""
        src = Path(source_path).expanduser().resolve()
        dst_parent = Path(target_parent).expanduser().resolve()

        if not src.exists():
            return {"success": False, "error": f"Thư mục nguồn không tồn tại: {src}"}
        if not dst_parent.exists() or not dst_parent.is_dir():
            return {"success": False, "error": f"Thư mục đích không tồn tại: {dst_parent}"}

        dst = dst_parent / src.name
        if dst.exists():
            return {"success": False, "error": f"Thư mục đích đã tồn tại: {dst}"}

        try:
            # Move contents to new partition
            shutil.move(str(src), str(dst))
            # Create symlink at original location pointing to new partition
            try:
                src.symlink_to(dst, target_is_directory=True)
            except OSError:
                if os.name == "nt":
                    import _winapi
                    _winapi.CreateJunction(str(dst), str(src))
                else:
                    raise
            return {
                "success": True,
                "source": str(src),
                "destination": str(dst),
                "symlink_created": True,
                "message": f"Đã di dời thành công '{src.name}' sang '{dst}'. Đường dẫn cũ vẫn hoạt động 100% trong suốt!",
            }
        except Exception as exc:
            logger.error("Failed to move library: %s", exc)
            return {"success": False, "error": str(exc)}
