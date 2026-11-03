"""CLI command handler for ALPORA Phone Ecosystem and KDE Connect integration."""
from __future__ import annotations

import argparse
import json
import sys

from ..services.phone_service import PhoneService


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


def handle_phone(args: argparse.Namespace) -> int:
    """Dispatches `poly-shell phone <subcommand>`."""
    service = PhoneService()
    action = getattr(args, "phone_action", "list")

    if not service.health_check() and action != "guide":
        _safe_print("⚠️  Chưa phát hiện gói 'kdeconnect' trên hệ thống.", file=sys.stderr)
        _safe_print("   Để kết nối điện thoại (Android / iPhone) với ALPORA, vui lòng cài đặt:", file=sys.stderr)
        _safe_print("   👉 sudo pacman -S kdeconnect", file=sys.stderr)
        _safe_print("   Sau đó mở ứng dụng KDE Connect trên điện thoại để ghép nối thiết bị.\n", file=sys.stderr)
        if action in ("ring", "ping", "share-clipboard", "send-file"):
            return 1

    if action == "list":
        devices = service.get_devices(force_refresh=True)
        if getattr(args, "json", False):
            _safe_print(json.dumps([d.to_dict() for d in devices], ensure_ascii=False))
            return 0

        if not devices:
            _safe_print("📱 Danh sách thiết bị điện thoại ALPORA Connect:")
            _safe_print("   (Chưa có thiết bị nào được ghép nối hoặc đang trực tuyến)")
            _safe_print("\n💡 Hướng dẫn ghép nối:")
            _safe_print("   1. Cài app 'KDE Connect' từ Google Play (Android) hoặc App Store (iOS).")
            _safe_print("   2. Kết nối cùng mạng Wi-Fi với máy tính.")
            _safe_print("   3. Mở app trên điện thoại, chọn máy tính của bạn và bấm 'Pair'.")
            return 0

        _safe_print(f"📱 Danh sách thiết bị điện thoại ALPORA Connect ({len(devices)} thiết bị):")
        for dev in devices:
            status_icon = "🟢 Trực tuyến" if dev.is_reachable else "⚪ Ngoại tuyến"
            _safe_print(f"  • {dev.name:<24} [ID: {dev.id}] -> {status_icon}")
        return 0

    elif action == "status":
        state = service.get_state()
        if getattr(args, "json", False):
            _safe_print(state.to_json())
        else:
            status_text = "🟢 Sẵn sàng" if state.available else "⚪ Chưa cài đặt"
            _safe_print("==================================================")
            _safe_print(f"   ALPORA Phone Ecosystem: {status_text}")
            _safe_print("==================================================")
            _safe_print(f"  Số thiết bị đã ghép nối : {len(state.devices)}")
            active = service.get_active_device()
            _safe_print(f"  Thiết bị kích hoạt      : {active.name if active else 'Không có'}")
            _safe_print("==================================================")
        return 0

    elif action == "ring":
        dev_id = getattr(args, "device_id", None)
        success = service.ring_device(dev_id)
        if success:
            _safe_print("🔔 Đang phát chuông tìm điện thoại...")
            return 0
        else:
            _safe_print("Lỗi: Không thể phát chuông thiết bị. Hãy kiểm tra điện thoại có đang mở Wi-Fi không.", file=sys.stderr)
            return 1

    elif action == "ping":
        dev_id = getattr(args, "device_id", None)
        msg = getattr(args, "message", "ALPORA Ecosystem Connected") or "ALPORA Ecosystem Connected"
        success = service.send_ping(dev_id, message=msg)
        if success:
            _safe_print(f"📡 Đã gửi ping test tới điện thoại: '{msg}'")
            return 0
        else:
            _safe_print("Lỗi: Không thể gửi ping tới thiết bị.", file=sys.stderr)
            return 1

    elif action == "share-clipboard":
        dev_id = getattr(args, "device_id", None)
        text = getattr(args, "text", None)
        success = service.share_clipboard(text=text, device_id=dev_id)
        if success:
            _safe_print("📋 Đã đồng bộ clipboard từ ALPORA sang điện thoại thành công.")
            return 0
        else:
            _safe_print("Lỗi: Không thể chia sẻ clipboard sang điện thoại.", file=sys.stderr)
            return 1

    elif action == "send-file":
        file_path = getattr(args, "file", None)
        if not file_path:
            _safe_print("Lỗi: Vui lòng chỉ định đường dẫn tệp cần gửi.", file=sys.stderr)
            return 1
        dev_id = getattr(args, "device_id", None)
        success = service.send_file(file_path, device_id=dev_id)
        if success:
            _safe_print(f"📤 Đã gửi tệp '{file_path}' sang điện thoại thành công.")
            return 0
        else:
            _safe_print(f"Lỗi: Không thể gửi tệp '{file_path}' sang điện thoại.", file=sys.stderr)
            return 1

    return 0
