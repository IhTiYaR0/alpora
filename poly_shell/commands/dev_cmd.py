"""CLI commands for ALPORA Developer Toolbox and CLI Toolchain Hub."""
from __future__ import annotations

import argparse
import sys
from typing import Optional

from ..services.dev_toolbox import DevToolboxService, CURATED_CATALOG
from ..services.storage_service import _format_bytes


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


def handle_dev(args: argparse.Namespace) -> int:
    """Entry point for `poly-shell dev` subcommands."""
    service = DevToolboxService()
    action = getattr(args, "dev_action", "list")

    if action == "list":
        st = service.get_status()
        _safe_print("=" * 72)
        _safe_print("                   ALPORA Developer CLI Hub Registry                   ")
        _safe_print("=" * 72)
        _safe_print(f"{'Tool':<12} {'Trạng thái':<14} {'Nguồn (Source)':<15} {'Mô tả ngắn':<28}")
        _safe_print("-" * 72)
        for tool in st.tools:
            status_str = "🟢 Đã cài" if tool.installed else "⚪ Chưa cài"
            _safe_print(f"{tool.name:<12} {status_str:<14} {tool.source:<15} {tool.description:<28}")

        _safe_print("-" * 72)
        _safe_print(
            f"Tổng: {st.installed_tools}/{st.total_tools} tools đã kích hoạt | "
            f"Dung lượng chiếm dụng: {_format_bytes(st.total_size_bytes)}"
        )
        _safe_print(f"Thư mục binary tập trung: {st.bin_dir}")
        if not st.in_path:
            _safe_print("\n[!] Chú ý: Thư mục binary chưa có trong $PATH. Chạy 'poly-shell dev doctor'.")
        _safe_print("=" * 72)
        return 0

    if action == "install":
        tool_name = getattr(args, "tool", None)
        if not tool_name:
            _safe_print("Lỗi: Vui lòng chỉ định tên CLI tool cần cài đặt (ví dụ: poly-shell dev install lazygit).")
            _safe_print("Các tool có sẵn: " + ", ".join(CURATED_CATALOG.keys()))
            return 1
        res = service.install_tool(tool_name)
        if res.get("success"):
            _safe_print(f"✅ {res.get('message')}")
            return 0
        else:
            _safe_print(f"❌ {res.get('error')}")
            return 1

    if action == "remove":
        tool_name = getattr(args, "tool", None)
        if not tool_name:
            _safe_print("Lỗi: Vui lòng chỉ định tên CLI tool cần gỡ (ví dụ: poly-shell dev remove lazygit).")
            return 1
        res = service.remove_tool(tool_name)
        if res.get("success"):
            _safe_print(f"✅ {res.get('message')}")
            return 0
        else:
            _safe_print(f"❌ {res.get('error')}")
            return 1

    if action == "doctor":
        doc = service.doctor()
        _safe_print("=" * 65)
        _safe_print("             ALPORA Developer Environment Doctor                ")
        _safe_print("=" * 65)
        _safe_print(f"  • Thư mục Binary    : {doc['bin_dir']}")
        _safe_print(f"  • Trạng thái $PATH  : {'🟢 Đã kích hoạt trong $PATH' if doc['in_path'] else '🔴 Chưa có trong $PATH'}")

        if doc["cleaned_broken_links"]:
            _safe_print(f"  • Symlinks gãy đã tự dọn: {', '.join(doc['cleaned_broken_links'])}")
        else:
            _safe_print("  • Symlinks toàn vẹn : 🟢 Không có liên kết gãy")

        if not doc["in_path"]:
            _safe_print("\nCách kích hoạt vào shell của bạn:")
            _safe_print(f"  Thêm vào ~/.bashrc hoặc ~/.zshrc:")
            _safe_print(f"    {doc['export_command']}")
        else:
            _safe_print("\n✅ Môi trường CLI của bạn đạt trạng thái tối ưu nhất!")
        _safe_print("=" * 65)
        return 0

    if action == "export":
        out_file = getattr(args, "out", "alpora-dev-stack.json")
        res = service.export_stack(out_file)
        _safe_print(f"✅ Đã xuất cấu hình {res['installed_count']} developer tools sang file: {out_file}")
        return 0

    if action == "import":
        in_file = getattr(args, "file", None)
        if not in_file:
            _safe_print("Lỗi: Vui lòng truyền đường dẫn file profile (ví dụ: poly-shell dev import alpora-dev-stack.json).")
            return 1
        res = service.import_stack(in_file)
        if res.get("success"):
            _safe_print(f"✅ Đã nhập và cài đặt thành công {res.get('count')} tools từ {in_file}!")
            return 0
        else:
            _safe_print(f"❌ {res.get('error')}")
            return 1

    if action == "clone":
        src = getattr(args, "source", None)
        dst = getattr(args, "destination", None)
        if not src or not dst:
            _safe_print("Lỗi: Vui lòng truyền đủ <source> và <destination> để nhân bản reflink.")
            _safe_print("Ví dụ: poly-shell dev clone ./my-project ./my-project-copy")
            return 1
        res = service.clone_reflink(src, dst)
        if res.get("success"):
            _safe_print(f"✅ {res.get('message')}")
            return 0
        else:
            _safe_print(f"❌ {res.get('error')}")
            return 1

    _safe_print(f"Lệnh dev không xác định: {action}")
    return 1

