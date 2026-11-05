"""CLI command handlers for `poly-shell memory`."""
from __future__ import annotations

import argparse
import sys
from typing import Any

from ..services.memory_service import MemoryService


def _safe_print(text: str) -> None:
    try:
        sys.stdout.write(f"{text}\n")
        sys.stdout.flush()
    except (UnicodeEncodeError, OSError):
        pass


def handle_memory(args: argparse.Namespace) -> int:
    """Handle `poly-shell memory` CLI commands."""
    service = MemoryService()
    action = getattr(args, "action", "status")

    if action == "status":
        state = service.get_overview()
        _safe_print("==================================================")
        _safe_print("          ALPORA Memory & Anti-Thrashing Guard   ")
        _safe_print("==================================================")
        _safe_print(f"  • Physical RAM Total  : {state.total_mb} MB")
        _safe_print(f"  • RAM Used            : {state.used_mb} MB ({state.percent}%)")
        _safe_print(f"  • RAM Available       : {state.available_mb} MB")
        _safe_print(f"  • Cached / Buffers    : {state.cached_mb} MB")
        _safe_print("--------------------------------------------------")
        if state.has_zram:
            saved_mb = round(max(0, state.zram_orig_mb - state.zram_compr_mb), 1)
            _safe_print(f"  • zRAM Compression    : 🟢 KÍCH HOẠT (Zstandard)")
            _safe_print(f"  • Dữ liệu nén trong RAM: {state.zram_compr_mb} MB (từ {state.zram_orig_mb} MB gốc)")
            _safe_print(f"  • Tỷ lệ nén           : {state.zram_ratio}x (Tiết kiệm được ~{saved_mb} MB RAM)")
        else:
            _safe_print(f"  • zRAM Compression    : ⚠️ CHƯA BẬT (Dễ gây đơ máy khi đầy RAM!)")
            _safe_print(f"  • Swap hiện tại       : {state.swap_total_mb} MB (Dùng: {state.swap_used_mb} MB)")
            _safe_print(f"  💡 Chạy: poly-shell memory setup-zram để kích hoạt nén RAM tự động.")

        _safe_print("--------------------------------------------------")
        _safe_print(f"  • Áp lực bộ nhớ (PSI) : Some={state.psi_some_avg10}% | Full={state.psi_full_avg10}%")
        if state.is_thrashing:
            _safe_print("  ⚠️ CẢNH BÁO: Hệ thống đang bị nghẽn trang nhớ (Memory Thrashing)! Hãy chạy 'poly-shell memory drop'.")
        else:
            _safe_print("  🟢 Trạng thái hệ thống: Mượt mà (Zero thrashing)")

        if state.workspaces:
            _safe_print("--------------------------------------------------")
            _safe_print("  Phân bổ RAM theo từng Workspace (Hyprland):")
            for ws in state.workspaces:
                apps_preview = ", ".join(ws.apps[:3])
                if len(ws.apps) > 3:
                    apps_preview += f" (+{len(ws.apps)-3})"
                _safe_print(f"    [Workspace {ws.workspace_id}]: {ws.total_rss_mb} MB -> {apps_preview}")

        _safe_print("==================================================")
        return 0

    elif action in ("drop", "clean"):
        _safe_print("🧹 Đang thực hiện dọn dẹp và nén trang bộ nhớ RAM (Memory Compaction & Drop Caches)...")
        res = service.drop_caches()
        if res.get("dropped_caches") or res.get("compacted_memory"):
            _safe_print(f"✅ Đã dọn dẹp và chống phân mảnh RAM thành công!")
            _safe_print(f"   RAM khả dụng trước: {res['available_before_mb']} MB")
            _safe_print(f"   RAM khả dụng sau  : {res['available_after_mb']} MB")
            if res['reclaimed_mb'] > 0:
                _safe_print(f"   Giải phóng được    : +{res['reclaimed_mb']} MB RAM")
        else:
            _safe_print(f"ℹ️ Đã gửi tín hiệu sync. Để xóa sâu pagecache kernel, chạy: sudo poly-shell memory drop")
        return 0

    elif action == "eco":
        _safe_print("⚡ Đang kích hoạt chế độ EcoQoS (Hạ tải ứng dụng ở các Workspace nền)...")
        res = service.eco_optimize_workspaces()
        if res.get("success"):
            _safe_print(f"✅ Đã tối ưu hóa:")
            _safe_print(f"   • Workspace đang hoạt động : {res['active_workspace']} (Ưu tiên tối đa)")
            _safe_print(f"   • Ứng dụng nền đã hạ tải   : {res['throttled_count']} ứng dụng")
            for app in res.get("throttled_apps", []):
                _safe_print(f"     - {app}")
        else:
            _safe_print(f"❌ Lỗi: {res.get('error')}")
        return 0

    elif action == "setup-zram":
        _safe_print("==================================================")
        _safe_print("      CẤU HÌNH ALPORA zRAM MEMORY SHIELD          ")
        _safe_print("==================================================")
        _safe_print("zRAM sẽ nén bộ nhớ nhàn rỗi trong RAM với thuật toán Zstandard siêu tốc.")
        _safe_print("Dung lượng nén: 100% dung lượng RAM (Tương đương mở rộng 2x-3x RAM thực tế).")
        _safe_print("Đặc biệt: Ngăn chặn 100% hiện tượng đứng máy / đơ chuột khi mở nhiều ứng dụng!")
        _safe_print("--------------------------------------------------")
        _safe_print("Lệnh thiết lập tự động (Copy và dán vào Terminal):")
        _safe_print("")
        cmd = (
            "sudo pacman -S --needed --noconfirm zram-generator && \\\n"
            "sudo tee /etc/systemd/zram-generator.conf << 'EOF'\n" + service.get_zram_config() + "EOF\n"
            "sudo tee /etc/sysctl.d/99-alpora-performance.conf << 'EOF'\n" + service.get_performance_sysctl() + "EOF\n"
            "sudo systemctl daemon-reload && \\\n"
            "sudo systemctl restart systemd-zram-setup@zram0.service && \\\n"
            "sudo systemctl enable --now systemd-oomd.service && \\\n"
            "sudo sysctl --system"
        )
        _safe_print(cmd)
        _safe_print("--------------------------------------------------")
        return 0

    _safe_print(f"Hành động không hợp lệ: {action}. Các lựa chọn: status, drop, eco, setup-zram")
    return 1

