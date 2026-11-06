"""CLI commands for ALPORA Instant System Recovery and Btrfs Snapshots."""
from __future__ import annotations

import argparse
import sys

from ..services.snapshot_service import SnapshotService


def _safe_print(text: str) -> None:
    """Print safely to stdout without encoding issues on restricted terminals."""
    try:
        print(text)
    except UnicodeEncodeError:
        try:
            encoding = sys.stdout.encoding or "utf-8"
            print(text.encode(encoding, errors="replace").decode(encoding))
        except Exception:
            print(text.encode("ascii", errors="replace").decode("ascii"))


def handle_snapshot(args: argparse.Namespace) -> int:
    """Entry point for `poly-shell snapshot` subcommands."""
    service = SnapshotService()
    action = getattr(args, "snapshot_action", "list")

    if action == "list":
        ov = service.list_snapshots()
        _safe_print("=" * 65)
        _safe_print("         ALPORA Instant System Snapshots (Snapper Engine)         ")
        _safe_print("=" * 65)
        if not ov.snapshots:
            _safe_print("  Chưa có bản snapshot nào. Chạy 'poly-shell snapshot create' để tạo.")
        else:
            _safe_print(f"{'ID':<6} {'Thời gian':<20} {'Mô tả bản ghi':<35}")
            _safe_print("-" * 65)
            for s in ov.snapshots:
                _safe_print(f"#{s.id:<5} {s.date:<20} {s.description:<35}")
        _safe_print("-" * 65)
        _safe_print(f"Tổng cộng: {ov.count} bản sao lưu hệ thống khả dụng.")
        _safe_print("Khôi phục trong 5s trực tiếp tại màn hình boot hoặc qua Snapper.")
        _safe_print("=" * 65)
        return 0

    if action == "create":
        desc = getattr(args, "description", "Manual ALPORA Backup")
        res = service.create_snapshot(description=desc)
        if res.get("success"):
            _safe_print(f"[OK] {res.get('message')}")
            return 0
        else:
            _safe_print(f"[Lỗi] {res.get('error')}")
            return 1

    if action == "delete":
        snap_id = getattr(args, "id", None)
        if snap_id is None:
            _safe_print("Lỗi: Cần cung cấp ID snapshot (ví dụ: poly-shell snapshot delete 3).")
            return 1
        res = service.delete_snapshot(int(snap_id))
        if res.get("success"):
            _safe_print(f"[OK] {res.get('message')}")
            return 0
        else:
            _safe_print(f"[Lỗi] {res.get('error')}")
            return 1

    _safe_print(f"Lệnh snapshot không xác định: {action}")
    return 1

