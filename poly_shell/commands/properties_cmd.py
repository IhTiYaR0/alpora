"""CLI command for ALPORA File and Folder Properties Inspector."""
from __future__ import annotations

import argparse
import sys

from ..services.file_inspector import FileInspectorService


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


def handle_properties(args: argparse.Namespace) -> int:
    """Display comprehensive file or directory properties matching Windows Properties."""
    target = getattr(args, "target", None)
    if not target:
        _safe_print("Lỗi: Vui lòng truyền đường dẫn file hoặc thư mục (ví dụ: poly-shell properties /path/to/file).")
        return 1

    info = FileInspectorService.inspect(target)
    if not info.get("exists"):
        _safe_print(f"❌ {info.get('error')}")
        return 1

    _safe_print("=" * 65)
    _safe_print(f"       ALPORA File Properties: {info['name']}        ")
    _safe_print("=" * 65)
    _safe_print(f"  • Tên đối tượng  : {info['name']}")
    _safe_print(f"  • Loại tệp (Type): {info['file_type']}")
    _safe_print(f"  • Vị trí (Path)  : {info['parent_dir']}")
    _safe_print(f"  • Dung lượng     : {info['size_human']} ({info['size_bytes']:,} bytes)")

    if info["is_dir"]:
        _safe_print(f"  • Số lượng tệp con: {info['item_count']} mục")

    _safe_print(f"  • Ngày khởi tạo  : {info['created_at']}")
    _safe_print(f"  • Chỉnh sửa cuối : {info['modified_at']}")
    _safe_print(f"  • Quyền truy cập : {info['permissions_human']} ({info['permissions_octal']})")

    if info.get("hashes"):
        _safe_print("-" * 65)
        _safe_print("  Kiểm tra tính toàn vẹn (Integrity & Checksums):")
        hashes = info["hashes"]
        if "sha256" in hashes:
            _safe_print(f"    - SHA-256 : {hashes['sha256']}")
        if "md5" in hashes:
            _safe_print(f"    - MD5     : {hashes['md5']}")
        if "note" in hashes:
            _safe_print(f"    - Ghi chú : {hashes['note']}")

    _safe_print("=" * 65)
    return 0
