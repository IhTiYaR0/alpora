"""File and Directory Properties Inspector for ALPORA Desktop."""
from __future__ import annotations

import datetime
import hashlib
import logging
import mimetypes
import os
from pathlib import Path
import stat
from typing import Any, Dict, Optional

from .storage_service import _format_bytes

logger = logging.getLogger(__name__)


def compute_file_hashes(path: Path, max_bytes: int = 500 * 1024 * 1024) -> Dict[str, str]:
    """Calculate SHA256 and MD5 hashes in streaming 64KB blocks."""
    if not path.is_file():
        return {}
    if path.stat().st_size > max_bytes:
        return {"note": f"File vượt quá {_format_bytes(max_bytes)}, bỏ qua tính hash tự động"}

    sha256 = hashlib.sha256()
    md5 = hashlib.md5()
    try:
        with open(path, "rb") as f:
            while chunk := f.read(65536):
                sha256.update(chunk)
                md5.update(chunk)
        return {
            "sha256": sha256.hexdigest(),
            "md5": md5.hexdigest(),
        }
    except OSError as exc:
        return {"error": str(exc)}


class FileInspectorService:
    """Provides comprehensive file/folder properties matching and exceeding Windows Properties dialog."""

    @staticmethod
    def inspect(target_path: str, compute_hashes: bool = True) -> Dict[str, Any]:
        """Inspect file or directory metadata, sizes, permissions and checksums."""
        path = Path(target_path).expanduser().resolve()
        if not path.exists():
            return {"exists": False, "error": f"Không tìm thấy tệp hoặc thư mục: {path}"}

        st = path.stat()
        mode = st.st_mode
        is_dir = path.is_dir()

        mime, _ = mimetypes.guess_type(str(path))
        if is_dir:
            file_type = "Folder / Directory"
        else:
            file_type = mime or ("Executable Binary" if (mode & stat.S_IXUSR) else "Document / File")

        # Permissions representation
        perm_octal = oct(stat.S_IMODE(mode))
        perm_human = stat.filemode(mode)

        # Timestamps
        ctime = datetime.datetime.fromtimestamp(st.st_ctime).strftime("%Y-%m-%d %H:%M:%S")
        mtime = datetime.datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M:%S")

        # Recursive size calculation for directory
        total_size = st.st_size
        item_count = 0
        if is_dir:
            total_size = 0
            try:
                for entry in os.scandir(str(path)):
                    item_count += 1
                    try:
                        if entry.is_file(follow_symlinks=False):
                            total_size += entry.stat().st_size
                    except OSError:
                        pass
            except OSError:
                pass

        hashes = compute_file_hashes(path) if (not is_dir and compute_hashes) else {}

        return {
            "exists": True,
            "name": path.name,
            "path": str(path),
            "parent_dir": str(path.parent),
            "is_dir": is_dir,
            "file_type": file_type,
            "size_bytes": total_size,
            "size_human": _format_bytes(total_size),
            "item_count": item_count if is_dir else 1,
            "created_at": ctime,
            "modified_at": mtime,
            "permissions_octal": perm_octal,
            "permissions_human": perm_human,
            "hashes": hashes,
            "is_executable": bool(mode & stat.S_IXUSR),
            "is_hidden": path.name.startswith("."),
        }

