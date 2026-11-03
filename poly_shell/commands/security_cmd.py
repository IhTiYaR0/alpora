"""CLI commands for ALPORA security auditing and system hardening."""
from __future__ import annotations

import argparse
import sys
from typing import Optional

from ..services.security_service import SecurityService


def _safe_print(text: str) -> None:
    """Print safely to stdout without crashing on restricted Windows encodings."""
    try:
        print(text)
    except UnicodeEncodeError:
        try:
            encoding = sys.stdout.encoding or "utf-8"
            clean_text = text.encode(encoding, errors="replace").decode(encoding)
            print(clean_text)
        except Exception:
            ascii_text = text.encode("ascii", errors="replace").decode("ascii")
            print(ascii_text)


def handle_security(args: argparse.Namespace) -> int:
    """Entry point for `poly-shell security` CLI subcommands."""
    service = SecurityService()
    action = getattr(args, "security_action", "status")

    if action in ("status", "audit"):
        audit = service.audit()
        _safe_print("=" * 60)
        _safe_print("          ALPORA OS System Security & Hardening Audit        ")
        _safe_print("=" * 60)
        _safe_print(f"Điểm bảo mật & hiệu năng: {audit.score}/100 [{audit.rating}]")
        _safe_print("-" * 60)
        _safe_print(f"  • Môi trường Wayland   : {'An toàn (Hyprland)' if audit.wayland_session else 'Nguy hiểm (X11)'}")
        _safe_print(f"  • Phân quyền IPC Socket: {'Khép kín (0o600)' if audit.ipc_socket_secure else 'Cần siết quyền'}")
        _safe_print(f"  • Tường lửa UFW        : {'Đang hoạt động' if audit.ufw_active else 'Chưa bật (Disabled)'}")
        _safe_print(f"  • AppArmor MAC         : {'Đã kích hoạt' if audit.apparmor_active else 'Chưa bật'}")
        _safe_print(f"  • Restrict Kernel Ptr  : kptr_restrict={audit.kptr_restrict} (khuyên dùng >= 1)")
        _safe_print(f"  • Restrict Dmesg Log   : dmesg_restrict={audit.dmesg_restrict} (khuyên dùng 1)")
        _safe_print(f"  • Unprivileged eBPF    : disabled={audit.unprivileged_bpf_disabled} (khuyên dùng 1)")
        _safe_print(f"  • VM Swappiness        : {audit.swappiness} (khuyên dùng <= 20 cho game)")
        _safe_print(f"  • VM Max Map Count     : {audit.max_map_count} (khuyên dùng >= 524288)")

        if audit.recommendations:
            _safe_print("-" * 60)
            _safe_print("Khuyến nghị tăng cường bảo mật:")
            for rec in audit.recommendations:
                _safe_print(f"  [!] {rec}")
            _safe_print("\nChạy 'poly-shell security harden' để xem các lệnh áp dụng tự động.")
        else:
            _safe_print("-" * 60)
            _safe_print("Hệ thống đạt chuẩn an toàn cao nhất của ALPORA OS!")
        _safe_print("=" * 60)
        return 0

    if action == "harden":
        commands = service.get_hardening_commands()
        _safe_print("=" * 60)
        _safe_print("    ALPORA OS Hardening Commands (Arch Linux Production)    ")
        _safe_print("=" * 60)
        _safe_print("Chạy các lệnh sau trong terminal để kích hoạt đầy đủ phòng thủ:")
        _safe_print("")
        for cmd in commands:
            _safe_print(cmd)
        _safe_print("=" * 60)
        return 0

    if action == "sysctl":
        _safe_print("# --- /etc/sysctl.d/99-alpora-security.conf ---")
        _safe_print(service.get_security_sysctl())
        _safe_print("# --- /etc/sysctl.d/99-alpora-performance.conf ---")
        _safe_print(service.get_performance_sysctl())
        return 0

    _safe_print(f"Lệnh security không xác định: {action}")
    return 1
