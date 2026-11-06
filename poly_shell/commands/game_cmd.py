"""CLI command handler for ALPORA Game Mode and Hoyoverse gaming optimizations."""
from __future__ import annotations

import argparse
import json
import sys

from ..services.game_mode import GameModeService


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


def handle_game(args: argparse.Namespace) -> int:
    """Dispatches `poly-shell game <subcommand>`."""
    service = GameModeService()
    action = getattr(args, "game_action", "status")

    if action == "on":
        game_name = getattr(args, "game", None)
        service.enable(game_name)
        game_tag = f" [{game_name}]" if game_name else ""
        _safe_print(f"[ALPORA Game Mode] ĐÃ KÍCH HOẠT{game_tag}")
        _safe_print("   - Đã tạm dừng hoạt ảnh và hiệu ứng làm mờ kính (blur) của Hyprland")
        _safe_print("   - CPU Governor & Power Profile chuyển sang Performance mode")
        _safe_print("   - Dồn 100% GPU VRAM và render thread cho game")
        return 0

    elif action == "off":
        service.disable()
        _safe_print("[ALPORA Game Mode] ĐÃ TẮT")
        _safe_print("   - Đã khôi phục toàn bộ hiệu ứng hoạt ảnh mượt mà của Hyprland")
        _safe_print("   - CPU Governor & Power Profile chuyển về Balanced mode")
        return 0

    elif action == "toggle":
        is_on = service.toggle(getattr(args, "game", None))
        status_text = "ĐÃ KÍCH HOẠT" if is_on else "ĐÃ TẮT"
        _safe_print(f"[ALPORA Game Mode] {status_text}")
        return 0

    elif action == "status":
        state = service.get_state()
        if getattr(args, "json", False):
            _safe_print(state.to_json())
        else:
            status_badge = "[ON] ĐANG BẬT" if state.enabled else "[OFF] ĐANG TẮT"
            _safe_print("==================================================")
            _safe_print(f"       ALPORA Game Mode Status: {status_badge}")
            _safe_print("==================================================")
            _safe_print(f"  Game đang chạy     : {state.active_game or 'Không có'}")
            _safe_print(f"  CPU Governor       : {state.cpu_governor}")
            _safe_print(f"  Hyprland Blur      : {'Tắt (Tiết kiệm GPU)' if state.blur_disabled else 'Bật (Mặc định)'}")
            _safe_print(f"  Hyprland Animations: {'Tắt (0 frame lag)' if state.animations_disabled else 'Bật (Mặc định)'}")
            _safe_print(f"  Feral gamemoded    : {'Khả dụng' if state.gamemode_available else 'Chưa cài đặt (sudo pacman -S gamemode)'}")
            _safe_print("==================================================")
        return 0

    elif action == "hoyo":
        game_name = getattr(args, "target", "zzz") or "zzz"
        preset = service.get_hoyoverse_preset(game_name)
        _safe_print(f"\n[ALPORA Optimization Profile] {preset['title']}")
        _safe_print(f"   {preset['description']}\n")
        _safe_print("[Launcher khuyên dùng trên Arch Linux]")
        _safe_print(f"   AUR: {preset['aur_launcher']}")
        _safe_print(f"   Lệnh cài: yay -S {preset['aur_launcher'].split()[0]}\n")
        _safe_print("[Biến môi trường đồ họa tối ưu (DXVK Async & Wine Fsync)]")
        for k, v in preset.get("env_vars", {}).items():
            _safe_print(f"   export {k}={v}")
        _safe_print("\n[Khuyến nghị cài đặt]")
        for rec in preset.get("recommendations", []):
            _safe_print(f"   • {rec}")
        _safe_print()
        return 0

    elif action == "launch":
        cmd = getattr(args, "command", [])
        if not cmd:
            _safe_print("Lỗi: Vui lòng truyền câu lệnh hoặc đường dẫn file game cần chạy.", file=sys.stderr)
            return 1
        game_title = getattr(args, "game", None) or cmd[0]
        _safe_print(f"[ALPORA] Đang khởi chạy {game_title} trong Game Mode tối ưu...")
        return service.launch_game(cmd, game_title)

    return 0
