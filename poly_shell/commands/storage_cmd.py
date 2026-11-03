"""CLI commands for ALPORA Storage Guard and Anti-Bloat management."""
from __future__ import annotations

import argparse
import sys
from typing import Optional

from ..services.storage_service import StorageService, _format_bytes


def _safe_print(text: str) -> None:
    """Print safely to stdout without encoding exceptions on Windows."""
    try:
        print(text)
    except UnicodeEncodeError:
        try:
            encoding = sys.stdout.encoding or "utf-8"
            print(text.encode(encoding, errors="replace").decode(encoding))
        except Exception:
            print(text.encode("ascii", errors="replace").decode("ascii"))


def handle_storage(args: argparse.Namespace) -> int:
    """Entry point for `poly-shell storage` subcommands."""
    service = StorageService()
    action = getattr(args, "storage_action", "status")

    if action in ("status", "overview"):
        ov = service.get_overview()
        _safe_print("=" * 65)
        _safe_print("            ALPORA Storage Guard & Partition Status              ")
        _safe_print("=" * 65)
        for part in ov.partitions:
            fs_info = f"[{part.filesystem.upper()}]"
            sub_info = f"Subvolume: {part.subvolume_name}" if part.subvolume_name else "Phân vùng truyền thống"
            _safe_print(f"  • Điểm gắn (Mount): {part.mount_point:<12} {fs_info:<8} ({sub_info})")
            _safe_print(
                f"    Dung lượng: {part.percent_used}% dùng ("
                f"{_format_bytes(part.used_bytes)} / {_format_bytes(part.total_bytes)}) - "
                f"Trống: {_format_bytes(part.free_bytes)}"
            )

        _safe_print("-" * 65)
        _safe_print("  Dung lượng rác & Cache có thể dọn dẹp (Cleanable):")
        _safe_print(f"    - Pacman Cache   : {_format_bytes(ov.pacman_cache_bytes)}")
        _safe_print(f"    - Systemd Journal: {_format_bytes(ov.journal_log_bytes)}")
        _safe_print(f"    - Thumbnails     : {_format_bytes(ov.thumbnail_cache_bytes)}")
        _safe_print(f"    => Tổng cộng có thể giải phóng: {_format_bytes(ov.total_cleanable_bytes)}")
        _safe_print("-" * 65)
        _safe_print("Chạy 'poly-shell storage clean' để dọn dẹp triệt để không phình ổ!")
        _safe_print("=" * 65)
        return 0

    if action == "clean":
        _safe_print("Đang tiến hành dọn dẹp các vùng cache phình to...")
        res = service.clean()
        _safe_print("=" * 65)
        _safe_print(f"✅ ALPORA CleanGuard: Đã giải phóng {res.freed_human} thành công!")
        _safe_print("-" * 65)
        for target in res.cleaned_targets:
            _safe_print(f"  • {target}")
        _safe_print("=" * 65)
        return 0

    if action == "move":
        src = getattr(args, "source", None)
        dst = getattr(args, "target", None)
        if not src or not dst:
            _safe_print("Lỗi: Cần truyền đủ <source_dir> và <target_parent_dir>.")
            _safe_print("Ví dụ: poly-shell storage move ~/.local/share/Steam /mnt/data2")
            return 1
        res = service.move_directory_library(src, dst)
        if res.get("success"):
            _safe_print(f"✅ {res.get('message')}")
            return 0
        else:
            _safe_print(f"❌ Lỗi di dời: {res.get('error')}")
            return 1

    _safe_print(f"Lệnh storage không xác định: {action}")
    return 1

