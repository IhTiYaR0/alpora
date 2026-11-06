"""Memory Shield and Anti-Thrashing Optimization Service for ALPORA OS."""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path
import shutil
from typing import Any, Dict, List, Optional

from ..adapters.base import SafeRunner
from ..adapters.hyprland import HyprlandAdapter
from ..contracts.hardware import MemoryStateDTO, WorkspaceMemoryDTO
from ..core.service import BaseService

logger = logging.getLogger(__name__)


class MemoryService(BaseService):
    """Domain service managing RAM, zRAM compression, kernel PSI thrashing detection, and workspace memory optimization."""

    def __init__(self):
        super().__init__("memory")

    def health_check(self) -> bool:
        """Health check returns True if /proc/meminfo is readable."""
        return Path("/proc/meminfo").exists()

    def get_state(self) -> MemoryStateDTO:
        """Return the current memory state DTO."""
        return self.get_overview()

    def get_overview(self) -> MemoryStateDTO:
        """Collect holistic memory metrics, zRAM stats, kernel PSI pressure, and workspace allocation."""
        meminfo = self._read_meminfo()
        total_kb = meminfo.get("MemTotal", 0)
        free_kb = meminfo.get("MemFree", 0)
        available_kb = meminfo.get("MemAvailable", free_kb)
        cached_kb = meminfo.get("Cached", 0) + meminfo.get("Buffers", 0)
        used_kb = max(0, total_kb - available_kb)

        swap_total_kb = meminfo.get("SwapTotal", 0)
        swap_free_kb = meminfo.get("SwapFree", 0)
        swap_used_kb = max(0, swap_total_kb - swap_free_kb)

        # zRAM statistics
        zram_info = self._read_zram_stats()

        # PSI (Pressure Stall Information)
        psi_info = self._read_psi()
        is_thrashing = psi_info["full_avg10"] > 5.0 or psi_info["some_avg10"] > 15.0

        # Workspace memory allocation via Hyprland
        workspaces = self._get_workspace_memory()

        return MemoryStateDTO(
            total_mb=round(total_kb / 1024.0, 1),
            used_mb=round(used_kb / 1024.0, 1),
            free_mb=round(free_kb / 1024.0, 1),
            available_mb=round(available_kb / 1024.0, 1),
            cached_mb=round(cached_kb / 1024.0, 1),
            percent=round((used_kb / total_kb) * 100.0, 1) if total_kb else 0.0,
            swap_total_mb=round(swap_total_kb / 1024.0, 1),
            swap_used_mb=round(swap_used_kb / 1024.0, 1),
            has_zram=zram_info["has_zram"],
            zram_orig_mb=zram_info["orig_mb"],
            zram_compr_mb=zram_info["compr_mb"],
            zram_ratio=zram_info["ratio"],
            psi_some_avg10=psi_info["some_avg10"],
            psi_full_avg10=psi_info["full_avg10"],
            is_thrashing=is_thrashing,
            workspaces=workspaces,
        )

    def _read_meminfo(self) -> Dict[str, int]:
        """Read and parse /proc/meminfo."""
        values: Dict[str, int] = {}
        path = Path("/proc/meminfo")
        if not path.exists():
            return values
        try:
            for line in path.read_text(encoding="ascii").splitlines():
                k, _, v = line.partition(":")
                if v.strip():
                    parts = v.split()
                    if parts and parts[0].isdigit():
                        values[k] = int(parts[0])
        except (OSError, ValueError):
            pass
        return values

    def _read_psi(self) -> Dict[str, float]:
        """Read Pressure Stall Information from /proc/pressure/memory."""
        result = {"some_avg10": 0.0, "full_avg10": 0.0}
        path = Path("/proc/pressure/memory")
        if not path.exists():
            return result
        try:
            for line in path.read_text(encoding="ascii").splitlines():
                parts = line.split()
                if not parts:
                    continue
                line_type = parts[0]
                for part in parts[1:]:
                    if part.startswith("avg10="):
                        val = float(part.split("=")[1])
                        if line_type == "some":
                            result["some_avg10"] = val
                        elif line_type == "full":
                            result["full_avg10"] = val
        except (OSError, ValueError):
            pass
        return result

    def _read_zram_stats(self) -> Dict[str, Any]:
        """Read zRAM device stats from sysfs."""
        result = {"has_zram": False, "orig_mb": 0.0, "compr_mb": 0.0, "ratio": 1.0}
        zram_dir = Path("/sys/block/zram0")
        if not zram_dir.exists():
            return result

        result["has_zram"] = True
        try:
            orig_bytes = int((zram_dir / "orig_data_size").read_text().strip())
            compr_bytes = int((zram_dir / "compr_data_size").read_text().strip())
            result["orig_mb"] = round(orig_bytes / (1024 * 1024), 1)
            result["compr_mb"] = round(compr_bytes / (1024 * 1024), 1)
            if compr_bytes > 0:
                result["ratio"] = round(orig_bytes / compr_bytes, 2)
        except (OSError, ValueError):
            pass
        return result

    def _get_workspace_memory(self) -> List[WorkspaceMemoryDTO]:
        """Map process memory (RSS) to active Hyprland workspaces."""
        workspaces_dict: Dict[int, Dict[str, Any]] = {}
        raw_clients = HyprlandAdapter.hyprctl(["clients", "-j"], timeout=3.0)
        if not raw_clients:
            return []

        try:
            clients = json.loads(raw_clients)
            for c in clients:
                ws_info = c.get("workspace", {})
                ws_id = ws_info.get("id", 1)
                pid = c.get("pid")
                title = c.get("initialClass") or c.get("class") or "App"

                if ws_id not in workspaces_dict:
                    workspaces_dict[ws_id] = {"rss_kb": 0, "apps": set()}

                workspaces_dict[ws_id]["apps"].add(title)
                if pid and pid > 0:
                    rss = self._get_process_rss_kb(pid)
                    workspaces_dict[ws_id]["rss_kb"] += rss
        except (json.JSONDecodeError, KeyError, TypeError):
            pass

        result = []
        for ws_id in sorted(workspaces_dict.keys()):
            info = workspaces_dict[ws_id]
            result.append(
                WorkspaceMemoryDTO(
                    workspace_id=ws_id,
                    total_rss_mb=round(info["rss_kb"] / 1024.0, 1),
                    app_count=len(info["apps"]),
                    apps=sorted(list(info["apps"])),
                )
            )
        return result

    def _get_process_rss_kb(self, pid: int) -> int:
        """Read Resident Set Size for a process from /proc/<pid>/status."""
        status_path = Path(f"/proc/{pid}/status")
        if not status_path.exists():
            return 0
        try:
            for line in status_path.read_text(encoding="ascii").splitlines():
                if line.startswith("VmRSS:"):
                    parts = line.split()
                    if len(parts) >= 2 and parts[1].isdigit():
                        return int(parts[1])
        except (OSError, ValueError):
            pass
        return 0

    def drop_caches(self) -> Dict[str, Any]:
        """Perform system pagecache and dentry cleanup and memory compaction."""
        mem_before = self._read_meminfo().get("MemAvailable", 0)

        # 1. Sync filesystems
        SafeRunner.run(["sync"], timeout=5.0)

        # 2. Drop pagecache, dentries and inodes if root, or via sudo
        dropped = False
        try:
            drop_path = Path("/proc/sys/vm/drop_caches")
            if os.access(str(drop_path), os.W_OK):
                drop_path.write_text("3\n")
                dropped = True
        except OSError:
            pass

        if not dropped and shutil.which("sudo"):
            res = SafeRunner.run(["sudo", "-n", "sh", "-c", "echo 3 > /proc/sys/vm/drop_caches"], timeout=5.0)
            dropped = (res.returncode == 0)

        # 3. Compact memory blocks (defragment free RAM)
        compacted = False
        try:
            compact_path = Path("/proc/sys/vm/compact_memory")
            if os.access(str(compact_path), os.W_OK):
                compact_path.write_text("1\n")
                compacted = True
        except OSError:
            pass

        if not compacted and shutil.which("sudo"):
            res = SafeRunner.run(["sudo", "-n", "sh", "-c", "echo 1 > /proc/sys/vm/compact_memory"], timeout=5.0)
            compacted = (res.returncode == 0)

        mem_after = self._read_meminfo().get("MemAvailable", 0)
        reclaimed_mb = round(max(0, mem_after - mem_before) / 1024.0, 1)

        return {
            "success": True,
            "dropped_caches": dropped,
            "compacted_memory": compacted,
            "reclaimed_mb": reclaimed_mb,
            "available_before_mb": round(mem_before / 1024.0, 1),
            "available_after_mb": round(mem_after / 1024.0, 1),
        }

    def get_zram_config(self) -> str:
        """Return /etc/systemd/zram-generator.conf content."""
        return (
            "# ALPORA OS - Zero-Thrashing Compressed RAM Swap Engine\n"
            "# Transparent in-memory Zstandard compression (2.5x-3x RAM expansion)\n"
            "[zram0]\n"
            "zram-size = ram * 1.0\n"
            "compression-algorithm = zstd\n"
            "swap-priority = 100\n"
        )

    def get_performance_sysctl(self) -> str:
        """Return recommended sysctl parameters for zRAM and zero-thrashing performance."""
        return (
            "# ALPORA OS - Zero-Thrashing zRAM & Low-Latency Desktop Memory Tuning\n"
            "# 1. Aggressively compress inactive memory into zRAM to preserve file cache\n"
            "vm.swappiness = 180\n"
            "# 2. Disable proactive memory watermarking boosts that trigger unnecessary scans\n"
            "vm.watermark_boost_factor = 0\n"
            "# 3. Scale memory watermarks to begin gentle reclaim before hard latency stalls\n"
            "vm.watermark_scale_factor = 125\n"
            "# 4. Read single pages with zero sequential read-ahead for instantaneous zRAM lookups\n"
            "vm.page-cluster = 0\n"
            "# 5. Retain dentries and directory caches in memory\n"
            "vm.vfs_cache_pressure = 50\n"
            "# 6. Support high mapping counts for Proton/Wine games and JetBrains JVMs\n"
            "vm.max_map_count = 1048576\n"
            "# 7. Balanced dirty pages flushing\n"
            "vm.dirty_ratio = 15\n"
            "vm.dirty_background_ratio = 5\n"
        )

    def eco_optimize_workspaces(self, active_workspace_id: Optional[int] = None) -> Dict[str, Any]:
        """Throttle inactive workspace applications to prevent background memory and CPU pressure."""
        if active_workspace_id is None:
            active_workspace_id = self._get_active_workspace_id()

        raw_clients = HyprlandAdapter.hyprctl(["clients", "-j"], timeout=3.0)
        if not raw_clients:
            return {"success": False, "error": "Hyprland is not responding"}

        throttled: List[str] = []
        prioritized: List[str] = []

        try:
            clients = json.loads(raw_clients)
            for c in clients:
                ws_id = c.get("workspace", {}).get("id", 1)
                pid = c.get("pid")
                title = c.get("initialClass") or c.get("class") or f"PID-{pid}"

                if not pid or pid <= 1:
                    continue

                if ws_id != active_workspace_id:
                    # Inactive workspace: set nice +10
                    try:
                        os.setpriority(os.PRIO_PROCESS, pid, 10)
                        throttled.append(f"{title} (ws:{ws_id})")
                    except OSError:
                        pass
                else:
                    # Active workspace: keep high responsiveness
                    try:
                        os.setpriority(os.PRIO_PROCESS, pid, 0)
                        prioritized.append(f"{title} (ws:{ws_id})")
                    except OSError:
                        pass
        except Exception as exc:
            logger.error("Error optimizing workspaces: %s", exc)

        return {
            "success": True,
            "active_workspace": active_workspace_id,
            "throttled_count": len(throttled),
            "prioritized_count": len(prioritized),
            "throttled_apps": throttled,
            "prioritized_apps": prioritized,
        }

    def _get_active_workspace_id(self) -> int:
        """Query currently focused workspace ID from Hyprland."""
        raw_monitors = HyprlandAdapter.hyprctl(["monitors", "-j"], timeout=3.0)
        if raw_monitors:
            try:
                monitors = json.loads(raw_monitors)
                if monitors and isinstance(monitors, list):
                    return monitors[0].get("activeWorkspace", {}).get("id", 1)
            except (json.JSONDecodeError, KeyError, IndexError):
                pass
        return 1

