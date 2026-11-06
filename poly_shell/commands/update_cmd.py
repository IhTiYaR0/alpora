"""CLI command handler for ALPORA OS Update Center and Over-The-Air (OTA) patches."""
from __future__ import annotations

import argparse
import json
import sys

from ..services.update_service import UpdateService


def _safe_print(*args, file=None, **kwargs):
    """Prints message safely even in environments with restricted encodings (e.g. cp1252 on Windows)."""
    target = file or sys.stdout
    msg = " ".join(str(a) for a in args)
    try:
        print(msg, file=target, **kwargs)
    except UnicodeEncodeError:
        try:
            target.buffer.write((msg + "\n").encode("utf-8", errors="replace"))
        except Exception:
            print(msg.encode("ascii", errors="replace").decode("ascii"), file=target, **kwargs)


def handle_update(args: argparse.Namespace) -> int:
    """Dispatches `poly-shell update <subcommand>`."""
    service = UpdateService()
    action = getattr(args, "update_action", "check")

    if action == "check":
        _safe_print("[Kiểm tra] Đang kiểm tra bản cập nhật từ máy chủ ALPORA...")
        info = service.check_update(force=True)

        if getattr(args, "json", False):
            _safe_print(json.dumps(info, ensure_ascii=False))
            return 0

        _safe_print("==================================================")
        _safe_print("             ALPORA OS Update Center              ")
        _safe_print("==================================================")
        _safe_print(f"  Phiên bản hiện tại : {info['current_version']}")
        _safe_print(f"  Phiên bản mới nhất : {info['latest_version']}")

        if info["has_update"]:
            _safe_print("\n[Thông báo] ĐÃ TÌM THẤY BẢN CẬP NHẬT MỚI!")
            _safe_print(f"  Tiêu đề: {info['release_title']}")
            if info.get("published_at"):
                _safe_print(f"  Ngày phát hành: {info['published_at'][:10]}")
            if info.get("release_notes"):
                _safe_print(f"\nNội dung cập nhật (Changelog):")
                for line in info["release_notes"].splitlines()[:10]:
                    _safe_print(f"    {line}")
            if info.get("iso_download_url"):
                _safe_print(f"\nLink tải Live ISO mới: {info['iso_download_url']}")
            _safe_print("\nĐể tiến hành cập nhật ngay lập tức, chạy:")
            _safe_print("   poly-shell update apply\n")
        else:
            _safe_print("\n[OK] Hệ thống ALPORA của bạn đang ở phiên bản mới nhất!")
            _safe_print("==================================================")
        return 0

    elif action == "apply":
        _safe_print("[Cập nhật] Bắt đầu quá trình cập nhật ALPORA OS...")
        res = service.apply_update(branch=getattr(args, "branch", "main") or "main")
        if res.get("success"):
            _safe_print(f"[Thành công] {res.get('message', 'Cập nhật thành công!')}")
            if res.get("backup_path"):
                _safe_print(f"Đã tạo bản sao lưu an toàn tại: {res['backup_path']}")
            _safe_print("Đang làm mới giao diện và nạp lại cấu hình...")
            try:
                import subprocess
                subprocess.run(["systemctl", "--user", "restart", "poly-shell.service"], check=False)
            except Exception:
                pass
            return 0
        else:
            _safe_print(f"[Lỗi] Cập nhật thất bại: {res.get('error')}", file=sys.stderr)
            return 1

    elif action == "status":
        ver = service.get_current_version()
        _safe_print(f"ALPORA OS Version: {ver}")
        return 0

    return 0

