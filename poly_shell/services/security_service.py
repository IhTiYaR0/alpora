"""Security and System Hardening Audit Service for ALPORA Desktop."""
from __future__ import annotations

import logging
import os
from pathlib import Path
import shutil
import stat
from typing import Any, Dict, List, Optional

from ..adapters.base import SafeRunner
from ..contracts.hardware import SecurityAuditDTO
from ..core.service import BaseService

logger = logging.getLogger(__name__)


class SecurityService(BaseService):
    """Domain service auditing and recommending Linux security & kernel optimizations."""

    def __init__(self, socket_path: Optional[Path] = None):
        super().__init__("security")
        self.socket_path = socket_path

    def health_check(self) -> bool:
        """Health check returns True if the audit can complete."""
        try:
            self.audit()
            return True
        except Exception as exc:
            logger.error("Security health check failed: %s", exc)
            return False

    def get_state(self) -> SecurityAuditDTO:
        """Return the current security audit state DTO."""
        return self.audit()

    def _read_sysctl_int(self, param_path: str, default: int = 0) -> int:
        """Safely read an integer sysctl parameter from /proc/sys."""
        path = Path(param_path)
        if not path.exists():
            return default
        try:
            val = path.read_text(encoding="ascii").strip()
            return int(val)
        except (OSError, ValueError):
            return default

    def is_wayland_active(self) -> bool:
        """Return True if running in an isolated Wayland compositor session."""
        return bool(os.environ.get("WAYLAND_DISPLAY") or os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"))

    def is_ufw_active(self) -> bool:
        """Check if UFW firewall is active."""
        if not shutil.which("ufw"):
            return False
        res = SafeRunner.run(["ufw", "status"], timeout_sec=2.0)
        return "Status: active" in res.stdout or "Status: Active" in res.stdout

    def is_apparmor_active(self) -> bool:
        """Check if AppArmor Mandatory Access Control is loaded."""
        aa_param = Path("/sys/module/apparmor/parameters/enabled")
        if aa_param.exists():
            try:
                return aa_param.read_text(encoding="ascii").strip() == "Y"
            except OSError:
                pass
        if shutil.which("aa-status"):
            res = SafeRunner.run(["aa-status", "--enabled"], timeout_sec=2.0)
            return res.returncode == 0
        return False

    def is_socket_secure(self) -> bool:
        """Verify that the ALPORA IPC socket path has strict permissions (0o600 / 0o700)."""
        if not self.socket_path or not self.socket_path.exists():
            return True
        try:
            mode = stat.S_IMODE(self.socket_path.stat().st_mode)
            parent_mode = stat.S_IMODE(self.socket_path.parent.stat().st_mode)
            # Socket should not be world-readable or world-writable
            return (mode & 0o077) == 0 and (parent_mode & 0o077) == 0
        except OSError:
            return False

    def audit(self) -> SecurityAuditDTO:
        """Run an exhaustive security & multi-core performance audit."""
        score = 0
        recommendations: List[str] = []

        # 1. Wayland Session Isolation (+20)
        wayland = self.is_wayland_active()
        if wayland:
            score += 20
        else:
            recommendations.append("Đang chạy trên X11: Dễ bị keylogger/screen capture trộm. Hãy chuyển sang Wayland (Hyprland).")

        # 2. IPC Socket Permissions (+15)
        sock_secure = self.is_socket_secure()
        if sock_secure:
            score += 15
        else:
            recommendations.append("Quyền IPC socket chưa an toàn: Cần giới hạn chmod 600 cho socket và 700 cho thư mục.")

        # 3. UFW Firewall (+20)
        ufw_on = self.is_ufw_active()
        if ufw_on:
            score += 20
        else:
            recommendations.append("Tường lửa UFW chưa bật: Cần chạy 'sudo ufw default deny incoming && sudo ufw enable'.")

        # 4. AppArmor MAC (+15)
        apparmor_on = self.is_apparmor_active()
        if apparmor_on:
            score += 15
        else:
            recommendations.append("AppArmor chưa được kích hoạt: Thêm 'lsm=...apparmor' vào bootloader và bật apparmor.service.")

        # 5. Kernel Hardening Parameters (+15)
        kptr = self._read_sysctl_int("/proc/sys/kernel/kptr_restrict", default=0)
        dmesg = self._read_sysctl_int("/proc/sys/kernel/dmesg_restrict", default=0)
        bpf = self._read_sysctl_int("/proc/sys/kernel/unprivileged_bpf_disabled", default=0)

        kernel_pts = 0
        if kptr >= 1:
            kernel_pts += 5
        if dmesg >= 1:
            kernel_pts += 5
        if bpf >= 1:
            kernel_pts += 5
        score += kernel_pts

        if kernel_pts < 15:
            recommendations.append("Sysctl bảo mật nhân (kptr, dmesg, bpf) chưa kích hoạt: Nên áp dụng 99-alpora-security.conf.")

        # 6. Memory & Game Performance (+15)
        swappiness = self._read_sysctl_int("/proc/sys/vm/swappiness", default=60)
        max_map = self._read_sysctl_int("/proc/sys/vm/max_map_count", default=65530)

        perf_pts = 0
        if swappiness <= 20:
            perf_pts += 7
        if max_map >= 500000:
            perf_pts += 8
        score += perf_pts

        if perf_pts < 15:
            recommendations.append("Bộ nhớ và map_count cho game chưa tối ưu: Đặt vm.swappiness=10 và vm.max_map_count=1048576.")

        # Determine qualitative rating
        if score >= 85:
            rating = "Hardened (Phòng thủ vững chắc)"
        elif score >= 60:
            rating = "Moderate (Khá tốt, cần bổ sung)"
        else:
            rating = "Exposed (Cần tăng cường bảo mật ngay)"

        return SecurityAuditDTO(
            score=score,
            rating=rating,
            wayland_session=wayland,
            ufw_active=ufw_on,
            apparmor_active=apparmor_on,
            kptr_restrict=kptr,
            dmesg_restrict=dmesg,
            unprivileged_bpf_disabled=bpf,
            swappiness=swappiness,
            max_map_count=max_map,
            ipc_socket_secure=sock_secure,
            recommendations=recommendations,
        )

    def get_security_sysctl(self) -> str:
        """Return recommended sysctl hardening lines for Arch Linux."""
        return (
            "# ALPORA OS - Kernel Security Hardening\n"
            "kernel.dmesg_restrict = 1\n"
            "kernel.kptr_restrict = 2\n"
            "kernel.unprivileged_bpf_disabled = 1\n"
            "kernel.yama.ptrace_scope = 1\n"
            "fs.protected_fifos = 2\n"
            "fs.protected_regular = 2\n"
            "fs.protected_hardlinks = 1\n"
            "fs.protected_symlinks = 1\n"
            "fs.suid_dumpable = 0\n"
            "net.ipv4.tcp_syncookies = 1\n"
            "net.ipv4.conf.all.rp_filter = 1\n"
            "net.ipv4.conf.default.rp_filter = 1\n"
            "net.ipv4.conf.all.accept_redirects = 0\n"
            "net.ipv6.conf.all.accept_redirects = 0\n"
            "net.ipv4.conf.all.send_redirects = 0\n"
            "net.ipv4.conf.all.accept_source_route = 0\n"
            "net.ipv6.conf.all.accept_source_route = 0\n"
        )

    def get_performance_sysctl(self) -> str:
        """Return recommended multi-core and memory optimization sysctl lines."""
        return (
            "# ALPORA OS - Multi-Core CPU & Memory Optimization for Gaming\n"
            "vm.swappiness = 10\n"
            "vm.vfs_cache_pressure = 50\n"
            "vm.max_map_count = 1048576\n"
            "vm.dirty_ratio = 15\n"
            "vm.dirty_background_ratio = 5\n"
        )

    def get_hardening_commands(self) -> List[str]:
        """Return the exact sequence of bash commands to harden Arch Linux."""
        return [
            "# 1. Kích hoạt và cấu hình tường lửa UFW (chặn vào, mở ra, cho phép ALPORA Phone)",
            "sudo pacman -S --needed ufw apparmor irqbalance",
            "sudo ufw default deny incoming",
            "sudo ufw default allow outgoing",
            "sudo ufw allow 1714:1764/udp comment 'ALPORA Phone / KDE Connect'",
            "sudo ufw allow 1714:1764/tcp comment 'ALPORA Phone / KDE Connect'",
            "sudo systemctl enable --now ufw.service",
            "sudo systemctl enable --now apparmor.service",
            "sudo systemctl enable --now irqbalance.service",
            "# 2. Áp dụng sysctl bảo mật và tối ưu bộ nhớ cho game",
            "sudo tee /etc/sysctl.d/99-alpora-security.conf << 'EOF'\n" + self.get_security_sysctl() + "EOF",
            "sudo tee /etc/sysctl.d/99-alpora-performance.conf << 'EOF'\n" + self.get_performance_sysctl() + "EOF",
            "sudo sysctl --system",
        ]
