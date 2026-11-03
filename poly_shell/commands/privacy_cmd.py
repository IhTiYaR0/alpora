"""CLI commands for ALPORA App Privacy and Sandboxing."""
from __future__ import annotations

import argparse
import sys

from ..services.privacy_service import PrivacyService


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


def handle_privacy(args: argparse.Namespace) -> int:
    """Entry point for `poly-shell privacy` subcommands."""
    service = PrivacyService()
    action = getattr(args, "privacy_action", "status")

    if action in ("status", "list", "audit"):
        report = service.audit()
        _safe_print("=" * 68)
        _safe_print("          ALPORA Application Privacy & Sandboxing Hub           ")
        _safe_print("=" * 68)
        _safe_print(f"{'Ứng dụng':<24} {'Mic':<6} {'Cam':<6} {'Mạng':<8} {'Cách ly Home'}")
        _safe_print("-" * 68)
        for app in report.apps:
            mic_str = "🟢" if app.has_mic else "⚪"
            cam_str = "🟢" if app.has_camera else "⚪"
            net_str = "🟢" if app.has_network else "⚪"
            home_str = "🔒 An toàn" if app.is_sandboxed else "⚠️ Toàn quyền"
            _safe_print(f"{app.app_name:<24} {mic_str:<6} {cam_str:<6} {net_str:<8} {home_str}")

        _safe_print("-" * 68)
        _safe_print(
            f"Tổng: {report.total_apps} ứng dụng | "
            f"🟢 Đã cách ly: {report.isolated_apps} | ⚠️ Cần rà soát: {report.exposed_apps}"
        )
        _safe_print("Chạy 'poly-shell privacy isolate <app_id>' để chặn quyền đọc thư mục riêng.")
        _safe_print("=" * 68)
        return 0

    if action == "isolate":
        target = getattr(args, "app", None)
        if not target:
            _safe_print("Lỗi: Vui lòng cung cấp ID ứng dụng cần cách ly (ví dụ: poly-shell privacy isolate com.discordapp.Discord).")
            return 1
        res = service.isolate_app(target)
        if res.get("success"):
            _safe_print(f"✅ {res.get('message')}")
            return 0
        else:
            _safe_print(f"❌ {res.get('error')}")
            return 1

    if action in ("allow", "revoke"):
        target = getattr(args, "app", None)
        perm = getattr(args, "permission", None)
        if not target or not perm:
            _safe_print(f"Lỗi: Cần cung cấp <app_id> và <permission> (mic, camera, network).")
            return 1
        res = service.set_permission(target, perm, allowed=(action == "allow"))
        if res.get("success"):
            _safe_print(f"✅ {res.get('message')}")
            return 0
        else:
            _safe_print(f"❌ {res.get('error')}")
            return 1

    _safe_print(f"Lệnh privacy không xác định: {action}")
    return 1

